-- DB-005: grants and policies for the identity and roster tables.
--
-- This is the first migration that makes anything reachable. Until now every
-- table was created with RLS on and no grant, so the Data API could not touch
-- it at all. What follows opens exactly the rows and columns in the exposure
-- matrix of docs/SCHEMA_THREAT_MODEL.md, and nothing else.
--
-- Two habits throughout:
--   * grants come before policies in the reading order, because a grant is what
--     decides whether PostgREST can reach a table at all and a policy only
--     filters afterwards. A table with no grant is unreachable whatever its
--     policies say, which is the stronger position;
--   * every UPDATE policy carries both USING and WITH CHECK. USING alone
--     controls which rows may be targeted, and would still let a caller edit a
--     row into a shape they could not have created.
--
-- anon receives nothing anywhere. It is not mentioned again.

-- ---------------------------------------------------------------------------
-- profiles: a user manages their own display name and sees nobody else's
-- ---------------------------------------------------------------------------

grant select on public.profiles to authenticated;

-- Column-scoped on purpose. A whole-table UPDATE would let a caller rewrite
-- created_at, and there is no reason for the client to touch anything but the
-- name.
grant update (display_name) on public.profiles to authenticated;

create policy profiles_select_own
  on public.profiles for select to authenticated
  using (user_id = (select auth.uid()));

create policy profiles_update_own
  on public.profiles for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- No INSERT and no DELETE. Rows are created by the auth.users trigger and
-- removed by cascade when the account goes.

-- ---------------------------------------------------------------------------
-- organisations: readable by active members
-- ---------------------------------------------------------------------------

grant select on public.organisations to authenticated;

create policy organisations_select_member
  on public.organisations for select to authenticated
  using (deleted_at is null and private.is_org_member(id));

-- Creation is transactional and must also make the creator an owner, so it is
-- a function in DB-007 rather than an INSERT grant. Renaming and deletion are
-- owner operations and are likewise functions.

-- ---------------------------------------------------------------------------
-- organisation_members: roles are visible inside a tenant
-- ---------------------------------------------------------------------------

grant select on public.organisation_members to authenticated;

create policy organisation_members_select_same_org
  on public.organisation_members for select to authenticated
  using (private.is_org_member(organisation_id));

-- Deliberately no UPDATE grant. If a member could update this table, changing
-- their own role to 'owner' would be a single request. Role changes are
-- functions that check the caller's own role first.

-- ---------------------------------------------------------------------------
-- participants: the nominee list, as a column subset
-- ---------------------------------------------------------------------------
--
-- The withheld columns are the point of this grant, so they are listed here
-- rather than left as an absence to be noticed:
--
--   user_id     withheld so a member cannot join a roster name to an auth
--               identity. Not a voter leak by itself, but the first half of one.
--   can_vote    withheld because knowing who is eligible to vote narrows the
--               set of possible authors of any given reason.
--   timestamps  withheld as needless metadata about when someone joined or left.
--
-- PostgREST honours column privileges and returns an error for a withheld
-- column rather than quietly dropping it, so a client asking for user_id fails
-- loudly instead of appearing to work.

grant select (
  id,
  organisation_id,
  display_name,
  team,
  avatar_path,
  active,
  can_receive
) on public.participants to authenticated;

create policy participants_select_active_in_org
  on public.participants for select to authenticated
  using (active and private.is_org_member(organisation_id));

-- Roster management is an administrator function, not a table grant, because
-- eligibility changes after a cycle opens have to be logged.

-- ---------------------------------------------------------------------------
-- organisation_invitations: no grant, on purpose
-- ---------------------------------------------------------------------------
--
-- Holds token_hash and email_normalised. A read of this table is a list of
-- every employee's email address, and no client use case needs it. Redemption
-- is a guarded function in DB-008. There is no policy below because a policy
-- would imply the table is reachable and merely filtered. It is not reachable.
