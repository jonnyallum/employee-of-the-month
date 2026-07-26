-- get_my_participant: the caller's own roster entry.
--
-- Needed by the nominee list. `participants.user_id` is deliberately withheld
-- from the client column grant, so a member cannot identify their own row from
-- the table, which also means the app cannot filter itself out of the list of
-- people to nominate.
--
-- The database refuses a self-nomination regardless, so this is not a security
-- control. It exists so the interface does not offer a choice that will be
-- rejected, which is a worse experience than not offering it.
--
-- It returns the caller's own row only, taking the user from auth.uid() rather
-- than an argument, so it cannot be asked about anybody else. `can_vote` is
-- included because it is the caller's own eligibility: knowing whether YOU can
-- vote reveals nothing about who else can, which is what the column grant
-- withholds.

create or replace function public.get_my_participant(
  target_organisation_id uuid
)
returns table (
  id uuid,
  display_name text,
  team text,
  can_vote boolean,
  can_receive boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.display_name, p.team, p.can_vote, p.can_receive
  from public.participants p
  where p.organisation_id = target_organisation_id
    and p.user_id = (select auth.uid())
    and p.active
    and p.left_at is null;
$$;

comment on function public.get_my_participant(uuid) is
  'The caller''s own roster entry. Takes the user from auth.uid(), never an '
  'argument. Returns the caller''s own can_vote, which discloses nothing about '
  'anybody else''s eligibility.';

revoke all on function public.get_my_participant(uuid) from public, anon;
grant execute on function public.get_my_participant(uuid) to authenticated;
