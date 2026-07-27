-- Roster management for administrators.
--
-- The client column grant on `participants` withholds `user_id` and `can_vote`
-- from every authenticated caller, administrators included. That is right for
-- the roster list a member sees, and it makes managing the roster impossible
-- through the table, so management is a shaped admin-only surface instead.
--
-- On deliberately showing an administrator `can_vote`, which T2 gives as a
-- reason to withhold it from members:
--
--   An administrator sets eligibility. They cannot manage a programme without
--   knowing who can vote in it, and they already receive reasons once a cycle
--   closes. Withholding it here would protect nothing while making the job
--   impossible, and pretending otherwise would be theatre.
--
--   What they still never receive is which of those eligible voters wrote which
--   reason. That is the boundary, and it is unchanged.
--
-- `has_account` is returned as a boolean rather than the user id. Whether
-- somebody has accepted their invitation is roster state an administrator needs;
-- the auth identity behind it is not, and a boolean cannot be joined to
-- anything.

-- ---------------------------------------------------------------------------
-- get_roster
-- ---------------------------------------------------------------------------

create or replace function public.get_roster(target_organisation_id uuid)
returns table (
  id uuid,
  display_name text,
  team text,
  active boolean,
  can_vote boolean,
  can_receive boolean,
  has_account boolean,
  invited_email text,
  invitation_expires_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.has_org_role(target_organisation_id, array['owner', 'admin']) then
    raise exception 'not permitted for this organisation'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  return query
    select p.id,
           p.display_name,
           p.team,
           p.active,
           p.can_vote,
           p.can_receive,
           (p.user_id is not null),
           i.email_normalised,
           i.expires_at
    from public.participants p
    left join public.organisation_invitations i
      on i.organisation_id = p.organisation_id
     and i.participant_id = p.id
     and i.accepted_at is null
     and i.revoked_at is null
    where p.organisation_id = target_organisation_id
      and p.left_at is null
    order by p.active desc, p.display_name;
end;
$$;

revoke all on function public.get_roster(uuid) from public, anon;
grant execute on function public.get_roster(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- add_participant
-- ---------------------------------------------------------------------------

create or replace function public.add_participant(
  target_organisation_id uuid,
  display_name text,
  team text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  new_id uuid;
  cleaned_name text;
  cleaned_team text;
begin
  if caller is null
     or not private.has_org_role(target_organisation_id, array['owner', 'admin']) then
    raise exception 'not permitted for this organisation'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  cleaned_name := trim(coalesce(add_participant.display_name, ''));
  cleaned_team := nullif(trim(coalesce(add_participant.team, '')), '');

  if cleaned_name = '' then
    raise exception 'a name is required'
      using errcode = '22023', hint = 'name_required';
  end if;

  insert into public.participants
    (organisation_id, display_name, team, active, can_vote, can_receive)
  values (target_organisation_id, cleaned_name, cleaned_team, true, true, true)
  returning id into new_id;

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id)
  values (target_organisation_id, caller, 'participant_added', 'participant',
          new_id::text);

  return new_id;
end;
$$;

revoke all on function public.add_participant(uuid, text, text) from public, anon;
grant execute on function public.add_participant(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- update_participant
-- ---------------------------------------------------------------------------
--
-- FR-ROSTER-02 requires eligibility changes after a cycle opens to be logged,
-- so the audit entry records what changed rather than merely that something did.
-- A participant who is deactivated after winning keeps their winner snapshot,
-- because that column is not a foreign key.

create or replace function public.update_participant(
  target_participant_id uuid,
  active boolean,
  can_vote boolean,
  can_receive boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  existing record;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select * into existing
  from public.participants p
  where p.id = target_participant_id
  for update;

  -- Same error for a participant that does not exist and one in another tenant,
  -- so this cannot be used to discover which ids are real.
  if existing.id is null
     or not private.has_org_role(existing.organisation_id, array['owner', 'admin']) then
    raise exception 'participant not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  update public.participants p
  set active = update_participant.active,
      can_vote = update_participant.can_vote,
      can_receive = update_participant.can_receive
  where p.id = target_participant_id;

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (existing.organisation_id, caller, 'participant_updated', 'participant',
          target_participant_id::text,
          jsonb_build_object(
            'active', jsonb_build_array(existing.active, update_participant.active),
            'can_vote', jsonb_build_array(existing.can_vote, update_participant.can_vote),
            'can_receive', jsonb_build_array(existing.can_receive, update_participant.can_receive)
          ));
end;
$$;

revoke all on function public.update_participant(uuid, boolean, boolean, boolean)
  from public, anon;
grant execute on function public.update_participant(uuid, boolean, boolean, boolean)
  to authenticated;
