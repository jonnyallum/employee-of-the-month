-- PRV-008: ownership transfer, leaving, and organisation deletion.
--
-- These are the ways out. `request_account_deletion` deliberately blocks the
-- last active owner, which is correct and also a dead end unless there is a way
-- to stop being the last owner. This is that way.
--
-- Every one of them is destructive or close to it, so each refuses more than it
-- allows.

-- ---------------------------------------------------------------------------
-- transfer_ownership
-- ---------------------------------------------------------------------------
--
-- Promotes an existing active member to owner. It does not demote the caller:
-- an organisation may have several owners, and losing ownership should be a
-- separate, deliberate act rather than a side effect of granting it. That also
-- means a mistyped transfer never leaves an organisation ownerless.

create or replace function public.transfer_ownership(
  target_organisation_id uuid,
  new_owner_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  -- Only an owner may create another owner. An admin cannot promote themselves
  -- or anybody else, which keeps the top of the hierarchy closed.
  if not private.has_org_role(target_organisation_id, array['owner']) then
    raise exception 'only an owner can transfer ownership'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if new_owner_user_id = caller then
    raise exception 'you are already an owner'
      using errcode = '22023', hint = 'already_owner';
  end if;

  update public.organisation_members m
  set role = 'owner'
  where m.organisation_id = target_organisation_id
    and m.user_id = new_owner_user_id
    and m.status = 'active';

  -- Deliberately refuses rather than silently doing nothing. A transfer that
  -- appears to succeed and does not is how an organisation ends up with one
  -- owner who then cannot delete their account.
  if not found then
    raise exception 'that person is not an active member of this organisation'
      using errcode = '22023', hint = 'not_a_member';
  end if;

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (target_organisation_id, caller, 'ownership_granted', 'user',
          new_owner_user_id::text, jsonb_build_object('role', 'owner'));
end;
$$;

revoke all on function public.transfer_ownership(uuid, uuid) from public, anon;
grant execute on function public.transfer_ownership(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- leave_organisation
-- ---------------------------------------------------------------------------
--
-- Journey D. Leaving marks the membership `left` and unlinks the roster entry,
-- so the person stops being able to vote immediately, on the next request,
-- without waiting for a token to expire.
--
-- What survives, and why:
--   * ballots already cast stay counted, because withdrawing them after the
--     fact would silently change a result other people have seen;
--   * the roster entry itself stays, with `left_at` set, because a nomination
--     points at it and a past result names it.

create or replace function public.leave_organisation(target_organisation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  other_owners integer;
  is_owner boolean;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select exists (
    select 1 from public.organisation_members m
    where m.organisation_id = target_organisation_id
      and m.user_id = caller and m.role = 'owner' and m.status = 'active'
  ) into is_owner;

  if not private.is_org_member(target_organisation_id) then
    raise exception 'you are not a member of this organisation'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  -- Same reasoning as account deletion: the last owner leaving strands
  -- everybody else in a programme nobody can administer or close.
  if is_owner then
    select count(*) into other_owners
    from public.organisation_members m
    where m.organisation_id = target_organisation_id
      and m.user_id <> caller and m.role = 'owner' and m.status = 'active';

    if other_owners = 0 then
      raise exception
        'transfer ownership before leaving, or delete the organisation'
        using errcode = '22023', hint = 'sole_owner';
    end if;
  end if;

  update public.organisation_members m
  set status = 'left'
  where m.organisation_id = target_organisation_id and m.user_id = caller;

  -- Unlinking is what actually stops them voting. The row stays so that past
  -- nominations and results still have something to point at.
  update public.participants p
  set user_id = null, left_at = now(), active = false,
      can_vote = false, can_receive = false
  where p.organisation_id = target_organisation_id and p.user_id = caller;

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id)
  values (target_organisation_id, caller, 'member_left', 'user', caller::text);
end;
$$;

revoke all on function public.leave_organisation(uuid) from public, anon;
grant execute on function public.leave_organisation(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- delete_organisation
-- ---------------------------------------------------------------------------
--
-- FR-PRIV-04. The most destructive thing in the product, so it asks for the
-- organisation's name to be typed back. That is not ceremony: it is the only
-- confirmation that cannot be satisfied by clicking through a dialog, and the
-- comparison happens in the database rather than the client so a modified app
-- cannot skip it.
--
-- Deletion is a soft delete plus a recovery window. Beta customers will delete
-- the wrong thing, and a cascade is not reversible. Everything else already
-- filters on `deleted_at is null`, so the organisation disappears from every
-- screen the moment this runs.

create or replace function public.delete_organisation(
  target_organisation_id uuid,
  confirm_name text
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  actual_name text;
  recovery_until timestamptz;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if not private.has_org_role(target_organisation_id, array['owner']) then
    raise exception 'only an owner can delete an organisation'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select o.name into actual_name
  from public.organisations o
  where o.id = target_organisation_id and o.deleted_at is null;

  if actual_name is null then
    raise exception 'organisation not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  -- Compared here, not in the client, so a modified app cannot skip it.
  if lower(trim(coalesce(confirm_name, ''))) <> lower(actual_name) then
    raise exception 'the name you typed does not match'
      using errcode = '22023', hint = 'name_mismatch';
  end if;

  recovery_until := now() + interval '30 days';

  update public.organisations o
  set deleted_at = now()
  where o.id = target_organisation_id;

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (target_organisation_id, caller, 'organisation_deleted', 'organisation',
          target_organisation_id::text,
          jsonb_build_object('recoverable_until', recovery_until));

  return recovery_until;
end;
$$;

comment on function public.delete_organisation(uuid, text) is
  'Soft-deletes an organisation after the owner types its name back. The name '
  'is compared in the database, so a modified client cannot skip the '
  'confirmation. A hard cascade happens after the recovery window.';

revoke all on function public.delete_organisation(uuid, text) from public, anon;
grant execute on function public.delete_organisation(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Members must lose access the moment an organisation is deleted
-- ---------------------------------------------------------------------------
--
-- `organisations` already filters on `deleted_at is null`, but the other
-- policies were written before soft deletion existed and check only membership,
-- so a deleted organisation's roster, cycles and settings would all remain
-- readable. Found by asking what each policy does after a delete, rather than
-- by a test failing.

create or replace function private.org_is_live(org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.organisations o
    where o.id = org and o.deleted_at is null
  );
$$;

revoke all on function private.org_is_live(uuid) from public, anon, authenticated;
grant execute on function private.org_is_live(uuid) to authenticated;

drop policy if exists participants_select_active_in_org on public.participants;
create policy participants_select_active_in_org
  on public.participants for select to authenticated
  using (
    active
    and private.is_org_member(organisation_id)
    and private.org_is_live(organisation_id)
  );

drop policy if exists recognition_cycles_select_member on public.recognition_cycles;
create policy recognition_cycles_select_member
  on public.recognition_cycles for select to authenticated
  using (
    private.is_org_member(organisation_id)
    and private.org_is_live(organisation_id)
  );

drop policy if exists organisation_members_select_same_org on public.organisation_members;
create policy organisation_members_select_same_org
  on public.organisation_members for select to authenticated
  using (
    private.is_org_member(organisation_id)
    and private.org_is_live(organisation_id)
  );

drop policy if exists recognition_settings_select_member on public.recognition_settings;
create policy recognition_settings_select_member
  on public.recognition_settings for select to authenticated
  using (
    private.is_org_member(organisation_id)
    and private.org_is_live(organisation_id)
  );
