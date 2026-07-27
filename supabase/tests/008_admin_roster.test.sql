-- Roster management tests.
--
-- The interesting question here is not whether an administrator can edit a
-- roster. It is what the roster surface hands back, and to whom.

begin;

create extension if not exists pgtap;

select plan(17);

delete from public.organisations;
delete from auth.users;

insert into auth.users (id, email, email_confirmed_at) values
  ('70000000-0000-0000-0000-000000000001', 'owner@alpha.test', now()),
  ('70000000-0000-0000-0000-000000000002', 'member@alpha.test', now()),
  ('70000000-0000-0000-0000-000000000009', 'outsider@beta.test', now());

insert into public.organisations (id, name, timezone) values
  ('7a000000-0000-0000-0000-00000000000a', 'Alpha Ltd', 'Europe/London'),
  ('7b000000-0000-0000-0000-00000000000b', 'Beta Ltd', 'Europe/London');

insert into public.organisation_members (organisation_id, user_id, role, status) values
  ('7a000000-0000-0000-0000-00000000000a', '70000000-0000-0000-0000-000000000001', 'owner', 'active'),
  ('7a000000-0000-0000-0000-00000000000a', '70000000-0000-0000-0000-000000000002', 'member', 'active'),
  ('7b000000-0000-0000-0000-00000000000b', '70000000-0000-0000-0000-000000000009', 'owner', 'active');

insert into public.participants (id, organisation_id, user_id, display_name) values
  ('7a000000-0000-0000-0000-0000000000a1', '7a000000-0000-0000-0000-00000000000a',
   '70000000-0000-0000-0000-000000000001', 'The Owner'),
  ('7a000000-0000-0000-0000-0000000000a2', '7a000000-0000-0000-0000-00000000000a',
   null, 'Not Yet Joined');

-- ---------------------------------------------------------------------------
-- The shape of the roster surface
-- ---------------------------------------------------------------------------
--
-- An administrator legitimately sees can_vote, because they set it. What must
-- never appear is the auth identity behind a roster entry: whether somebody has
-- joined is roster state, but the user id is not, and a boolean cannot be
-- joined to anything.

select ok(
  (select pg_get_function_result(p.oid) not like '%user_id%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_roster'),
  'the roster returns no auth identity, only whether an account exists'
);

select ok(
  (select pg_get_function_result(p.oid) like '%has_account boolean%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_roster'),
  'joined state is a boolean, which cannot be joined to anything'
);

-- ---------------------------------------------------------------------------
-- Who may use it
-- ---------------------------------------------------------------------------

select ok(
  not has_function_privilege('anon', 'public.get_roster(uuid)', 'execute'),
  'anon cannot read a roster'
);

set local role authenticated;

set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000002","role":"authenticated"}';

select throws_ok(
  $$select * from public.get_roster('7a000000-0000-0000-0000-00000000000a')$$,
  '42501',
  null,
  'a plain member cannot read the management roster, so can_vote stays hidden from them'
);

select throws_ok(
  $$select public.add_participant('7a000000-0000-0000-0000-00000000000a', 'Sneaky')$$,
  '42501',
  null,
  'a plain member cannot add anybody'
);

select throws_ok(
  $$select public.update_participant('7a000000-0000-0000-0000-0000000000a1', true, false, true)$$,
  '42501',
  null,
  'a plain member cannot change eligibility'
);

set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000009","role":"authenticated"}';

select throws_ok(
  $$select * from public.get_roster('7a000000-0000-0000-0000-00000000000a')$$,
  '42501',
  null,
  'another tenant''s owner cannot read this roster'
);

select throws_ok(
  $$select public.update_participant('7a000000-0000-0000-0000-0000000000a1', false, false, false)$$,
  '42501',
  null,
  'another tenant''s owner cannot change this roster, and cannot tell the id is real'
);

-- ---------------------------------------------------------------------------
-- What an administrator can do
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000001","role":"authenticated"}';

select is(
  (select count(*)::int from public.get_roster('7a000000-0000-0000-0000-00000000000a')),
  2,
  'an owner sees the roster'
);

select is(
  (select has_account from public.get_roster('7a000000-0000-0000-0000-00000000000a')
   where display_name = 'Not Yet Joined'),
  false,
  'somebody without an account is shown as not joined'
);

select throws_ok(
  $$select public.add_participant('7a000000-0000-0000-0000-00000000000a', '   ')$$,
  '22023',
  null,
  'a blank name is refused'
);

select lives_ok(
  $$select public.add_participant('7a000000-0000-0000-0000-00000000000a', '  Newcomer  ', ' Nights ')$$,
  'an owner can add somebody'
);

reset role;

select is(
  (select display_name from public.participants where team = 'Nights'),
  'Newcomer',
  'the name and team are trimmed on the way in'
);

select is(
  (select count(*)::int from public.participants
   where organisation_id = '7a000000-0000-0000-0000-00000000000a'
     and active and can_vote and can_receive),
  3,
  'a new participant starts active and fully eligible'
);

-- ---------------------------------------------------------------------------
-- Eligibility changes are logged, because FR-ROSTER-02 requires it
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000001","role":"authenticated"}';

select lives_ok(
  $$select public.update_participant('7a000000-0000-0000-0000-0000000000a1', true, false, true)$$,
  'an owner can remove somebody''s vote'
);

reset role;

select is(
  (select can_vote from public.participants
   where id = '7a000000-0000-0000-0000-0000000000a1'),
  false,
  'the change took effect'
);

-- Recording only that something changed would be useless in a dispute about a
-- cycle, which is exactly when this gets read.
select is(
  (select metadata -> 'can_vote' from public.audit_events
   where action = 'participant_updated'),
  '[true, false]'::jsonb,
  'the audit records the old and new value, not merely that a change happened'
);

select * from finish();

rollback;
