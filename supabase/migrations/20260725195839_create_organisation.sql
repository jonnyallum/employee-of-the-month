-- DB-007: create_organisation, the first thing a client is allowed to write.
--
-- Until now no client could write anything at all. This is the entry point to
-- the whole product, and it is a function rather than an INSERT grant because
-- FR-ORG-01 requires four rows to appear together or not at all: the
-- organisation, the creator's ownership, the creator's roster entry, and the
-- programme settings. A grant cannot express "and also make me the owner", and
-- a client doing it in four requests can fail after the first and leave an
-- organisation nobody can administer.
--
-- This is the first function in `public`, because only exposed schemas are
-- reachable as RPC. Everything in `private` stays unreachable. The hardening is
-- therefore stricter here than anywhere so far:
--   * SECURITY DEFINER, so it can write tables the caller has no grant on;
--   * search_path pinned empty, every reference schema-qualified;
--   * EXECUTE revoked from PUBLIC and anon, granted only to authenticated;
--   * the owner is taken from auth.uid(), never from an argument.

create or replace function public.create_organisation(
  organisation_name text,
  organisation_timezone text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  caller_email text;
  caller_confirmed timestamptz;
  caller_name text;
  new_id uuid;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  -- FR-ORG-01 requires a verified user. Reading the confirmation from
  -- auth.users rather than trusting a JWT claim keeps this consistent with
  -- every other authorisation decision in the schema.
  select u.email, u.email_confirmed_at
    into caller_email, caller_confirmed
  from auth.users u
  where u.id = caller;

  if caller_confirmed is null then
    raise exception 'email must be verified before creating an organisation'
      using errcode = '42501', hint = 'email_not_verified';
  end if;

  -- Trim once here so the stored value and the length constraint agree, rather
  -- than relying on the client to have done it.
  organisation_name := trim(coalesce(organisation_name, ''));
  organisation_timezone := trim(coalesce(organisation_timezone, ''));

  if organisation_name = '' then
    raise exception 'organisation name is required'
      using errcode = '22023', hint = 'name_required';
  end if;

  -- The timezone trigger on the table would catch an unknown zone anyway, but
  -- raising here produces a product error code instead of a constraint name.
  if not exists (
    select 1 from pg_catalog.pg_timezone_names where name = organisation_timezone
  ) then
    raise exception 'unknown timezone: %', organisation_timezone
      using errcode = '22023', hint = 'invalid_timezone';
  end if;

  insert into public.organisations (name, timezone, created_by)
  values (organisation_name, organisation_timezone, caller)
  returning id into new_id;

  insert into public.organisation_members (organisation_id, user_id, role, status)
  values (new_id, caller, 'owner', 'active');

  -- The creator joins the roster too. Without this the owner cannot vote or be
  -- nominated in their own programme, and the first cycle of a small team would
  -- be missing a participant for no reason a user could understand.
  select p.display_name into caller_name
  from public.profiles p where p.user_id = caller;

  insert into public.participants
    (organisation_id, user_id, display_name, active, can_vote, can_receive)
  values (
    new_id,
    caller,
    coalesce(nullif(trim(caller_name), ''), split_part(coalesce(caller_email, ''), '@', 1), 'Owner'),
    true, true, true
  );

  -- Defaults exist from the moment the organisation does, so no screen has to
  -- cope with settings that are absent rather than merely unchanged.
  insert into public.recognition_settings (organisation_id) values (new_id);

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id)
  values (new_id, caller, 'organisation_created', 'organisation', new_id::text);

  return new_id;
end;
$$;

comment on function public.create_organisation(text, text) is
  'Creates an organisation and makes the caller its owner in one transaction. '
  'Partial failure leaves nothing behind, so an organisation without an owner '
  'cannot exist.';

-- Postgres grants EXECUTE to PUBLIC by default, which would make this callable
-- by anon. Revoke first, then grant narrowly.
revoke all on function public.create_organisation(text, text) from public, anon;
grant execute on function public.create_organisation(text, text) to authenticated;
