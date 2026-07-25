-- DB-004: membership and role helpers for RLS policies.
--
-- Every helper is SECURITY DEFINER for one specific reason: policies on
-- organisation_members need to ask "is this user a member", and a policy that
-- queries the very table it protects recurses forever. Running as the owner
-- bypasses RLS inside the helper and breaks the cycle.
--
-- That power is contained deliberately:
--   * they live in `private`, which is not in the API's exposed schema list, so
--     PostgREST will not serve them as RPC no matter what is granted;
--   * they are STABLE and read-only, so a definer function cannot be turned
--     into a write primitive;
--   * search_path is pinned empty with every reference schema-qualified;
--   * they take the user from auth.uid() rather than an argument, so a caller
--     cannot ask a question on somebody else's behalf.
--
-- A policy expression IS subject to the querying role's privileges. A caller
-- referencing one of these through a policy must therefore hold EXECUTE on the
-- function and USAGE on the schema, or every query on the protected table fails
-- with "permission denied for function".
--
-- This was initially got wrong. An experiment appeared to show that policies
-- needed no such grant, but the throwaway function in that experiment still
-- carried Postgres's default EXECUTE for PUBLIC, which these do not: the revoke
-- at the bottom of this file removes it. The experiment therefore proved nothing
-- and the real behaviour only surfaced when the RLS tests ran.
--
-- Granting USAGE on `private` does not expose anything. PostgREST serves only
-- the schemas listed in its exposed-schemas setting, which is `public` and
-- `graphql_public`, so nothing here is reachable as an RPC no matter what is
-- granted. The exposed-schema list is the control; the grants below are only
-- what makes policy evaluation legal.

-- auth.uid() wrapped once so every policy reads the same way and there is a
-- single place to change if the claim source ever moves.
create or replace function private.current_user_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid();
$$;

comment on function private.current_user_id() is
  'The authenticated user, from the verified JWT. Never from user metadata, '
  'which the user can edit.';

-- Active membership only. A suspended or departed member keeps their row for
-- audit purposes but must stop passing this check immediately.
create or replace function private.is_org_member(org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organisation_members m
    where m.organisation_id = org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
  );
$$;

comment on function private.is_org_member(uuid) is
  'Reads membership live on every request. This is what makes removing someone '
  'take effect immediately rather than when their access token expires, which '
  'can be up to an hour later.';

create or replace function private.has_org_role(org uuid, roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organisation_members m
    where m.organisation_id = org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.role = any(roles)
  );
$$;

comment on function private.has_org_role(uuid, text[]) is
  'Role check against the membership table. Roles are never read from JWT '
  'claims: a token minted before a demotion would still assert the old role.';

-- The caller's own participant row in an organisation. Needed because the
-- client column grant on participants deliberately withholds user_id, so a
-- member cannot identify their own roster entry from the table alone.
create or replace function private.participant_for_user(org uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.participants p
  where p.organisation_id = org
    and p.user_id = (select auth.uid())
    and p.left_at is null
  limit 1;
$$;

comment on function private.participant_for_user(uuid) is
  'The caller''s own participant id. Takes the user from auth.uid(), never an '
  'argument, so it cannot be asked about anybody else.';

-- Strip Postgres's default EXECUTE for PUBLIC first, which would otherwise make
-- every helper callable by anon, then grant back only what policy evaluation
-- actually requires.
revoke all on all functions in schema private from public, anon, authenticated;
revoke usage on schema private from public, anon;

-- USAGE is needed for EXECUTE to be usable at all. anon is excluded: no policy
-- grants anon anything, so it never needs to evaluate one of these.
grant usage on schema private to authenticated;

-- Only the two helpers that appear inside a policy expression. current_user_id
-- and participant_for_user are called from SECURITY DEFINER functions, which
-- run as their owner and so need no privilege from the caller. Granting them
-- here would widen the surface for no benefit.
grant execute on function private.is_org_member(uuid) to authenticated;
grant execute on function private.has_org_role(uuid, text[]) to authenticated;
