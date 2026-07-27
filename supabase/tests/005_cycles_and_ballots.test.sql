-- DB-009, DB-010 and DB-011 tests: the cycle lifecycle and the ballot.
--
-- This is the first suite where a whole product journey runs end to end: create
-- an organisation, open a cycle, cast, withdraw, recast, close. The refusals
-- matter more than the journey.

begin;

create extension if not exists pgtap;

select plan(37);


-- The seed in supabase/seed.sql has already run against this database. This
-- suite asserts absolute counts and creates its own fixtures, so it starts from
-- an empty slate instead. Both deletes are inside the transaction and are undone
-- by the rollback at the end, so the seed survives for the next file.
--
-- Deleting organisations cascades to members, participants, cycles, ballots,
-- invitations and settings; deleting users cascades to profiles.
delete from public.organisations;
delete from auth.users;

insert into auth.users (id, email, email_confirmed_at) values
  ('50000000-0000-0000-0000-000000000001', 'ana@alpha.test', now()),
  ('50000000-0000-0000-0000-000000000002', 'ben@alpha.test', now()),
  ('50000000-0000-0000-0000-000000000003', 'cara@alpha.test', now()),
  ('50000000-0000-0000-0000-000000000004', 'nonvoter@alpha.test', now()),
  ('50000000-0000-0000-0000-000000000009', 'outsider@beta.test', now());

insert into public.organisations (id, name, timezone) values
  ('5a000000-0000-0000-0000-00000000000a', 'Alpha Ltd', 'Europe/London'),
  ('5b000000-0000-0000-0000-00000000000b', 'Beta Ltd', 'Europe/London');

insert into public.organisation_members (organisation_id, user_id, role, status) values
  ('5a000000-0000-0000-0000-00000000000a', '50000000-0000-0000-0000-000000000001', 'owner', 'active'),
  ('5a000000-0000-0000-0000-00000000000a', '50000000-0000-0000-0000-000000000002', 'member', 'active'),
  ('5a000000-0000-0000-0000-00000000000a', '50000000-0000-0000-0000-000000000003', 'member', 'active'),
  ('5a000000-0000-0000-0000-00000000000a', '50000000-0000-0000-0000-000000000004', 'member', 'active'),
  ('5b000000-0000-0000-0000-00000000000b', '50000000-0000-0000-0000-000000000009', 'owner', 'active');

insert into public.participants
  (id, organisation_id, user_id, display_name, active, can_vote, can_receive) values
  ('5a000000-0000-0000-0000-0000000000a1', '5a000000-0000-0000-0000-00000000000a',
   '50000000-0000-0000-0000-000000000001', 'Ana', true, true, true),
  ('5a000000-0000-0000-0000-0000000000a2', '5a000000-0000-0000-0000-00000000000a',
   '50000000-0000-0000-0000-000000000002', 'Ben', true, true, true),
  ('5a000000-0000-0000-0000-0000000000a3', '5a000000-0000-0000-0000-00000000000a',
   '50000000-0000-0000-0000-000000000003', 'Cara', true, true, true),
  -- Can receive but not vote, which is the pair the roster keeps separate.
  ('5a000000-0000-0000-0000-0000000000a4', '5a000000-0000-0000-0000-00000000000a',
   '50000000-0000-0000-0000-000000000004', 'Dee', true, false, true),
  ('5a000000-0000-0000-0000-0000000000a5', '5a000000-0000-0000-0000-00000000000a',
   null, 'Inactive', false, true, true),
  ('5b000000-0000-0000-0000-0000000000b1', '5b000000-0000-0000-0000-00000000000b',
   '50000000-0000-0000-0000-000000000009', 'Outsider', true, true, true);

set local role authenticated;

-- ---------------------------------------------------------------------------
-- create_cycle
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.create_cycle('5a000000-0000-0000-0000-00000000000a', '2026-07-01')$$,
  '42501',
  null,
  'a plain member cannot create a cycle'
);

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000009","role":"authenticated"}';
select throws_ok(
  $$select public.create_cycle('5a000000-0000-0000-0000-00000000000a', '2026-07-01')$$,
  '42501',
  null,
  'another tenant''s owner cannot create a cycle here'
);

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.create_cycle('5a000000-0000-0000-0000-00000000000a', '2026-07-01',
      null, now(), now() - interval '1 day')$$,
  '22023',
  null,
  'a cycle cannot be created closing before it opens'
);

create temporary table cyc as
select public.create_cycle(
  '5a000000-0000-0000-0000-00000000000a', '2026-07-15', 'Helped a colleague.') as id;

reset role;

select is(
  (select period_month from public.recognition_cycles),
  '2026-07-01'::date,
  'a mid-month date is normalised to the month rather than refused'
);

select is(
  (select status from public.recognition_cycles),
  'draft',
  'a new cycle starts as a draft'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.create_cycle('5a000000-0000-0000-0000-00000000000a', '2026-07-01')$$,
  '23505',
  null,
  'a second cycle in the same month is refused'
);

-- ---------------------------------------------------------------------------
-- transition_cycle
-- ---------------------------------------------------------------------------

select throws_ok(
  $$select public.transition_cycle((select id from cyc), 99, 'open')$$,
  '40001',
  null,
  'a stale expected_version is refused, so two admins cannot overwrite'
);

select throws_ok(
  $$select public.transition_cycle((select id from cyc), 1, 'closed')$$,
  '22023',
  null,
  'a draft cannot jump straight to closed'
);

select throws_ok(
  $$select public.transition_cycle((select id from cyc), 1, 'revealed')$$,
  '22023',
  null,
  'revealing is not reachable from transition_cycle'
);

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.transition_cycle((select id from cyc), 1, 'open')$$,
  '42501',
  null,
  'a plain member cannot open a cycle'
);

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000001","role":"authenticated"}';
select is(
  (select public.transition_cycle((select id from cyc), 1, 'open')),
  2,
  'opening succeeds and returns the new version'
);

reset role;
select ok(
  (select opens_at is not null from public.recognition_cycles),
  'opening stamps opens_at when it was not set in advance'
);

-- ---------------------------------------------------------------------------
-- cast_nomination
-- ---------------------------------------------------------------------------

set local role authenticated;

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000009","role":"authenticated"}';
select throws_ok(
  $$select public.cast_nomination((select id from cyc),
      '5a000000-0000-0000-0000-0000000000a2')$$,
  '42501',
  null,
  'a member of another organisation cannot vote in this cycle'
);

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000004","role":"authenticated"}';
select throws_ok(
  $$select public.cast_nomination((select id from cyc),
      '5a000000-0000-0000-0000-0000000000a2')$$,
  '42501',
  null,
  'somebody who can receive but not vote is refused'
);

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000003","role":"authenticated"}';

select throws_ok(
  $$select public.cast_nomination((select id from cyc),
      '5a000000-0000-0000-0000-0000000000a3')$$,
  '22023',
  null,
  'self-nomination is refused by the function as well as the constraint'
);

select throws_ok(
  $$select public.cast_nomination((select id from cyc),
      '5b000000-0000-0000-0000-0000000000b1')$$,
  '42501',
  null,
  'a nominee in another organisation is indistinguishable from one that does not exist'
);

select throws_ok(
  $$select public.cast_nomination((select id from cyc),
      '5a000000-0000-0000-0000-0000000000a5')$$,
  '22023',
  null,
  'an inactive nominee is refused'
);

select throws_ok(
  $$select public.cast_nomination((select id from cyc),
      '5a000000-0000-0000-0000-0000000000a2', repeat('x', 501))$$,
  '22023',
  null,
  'a reason over 500 characters is refused'
);

select lives_ok(
  $$select public.cast_nomination((select id from cyc),
      '5a000000-0000-0000-0000-0000000000a2', '  Covered   a hard   handover. ')$$,
  'an eligible voter can nominate an eligible colleague'
);

reset role;

select is(
  (select reason from public.recognition_nominations),
  'Covered a hard handover.',
  'the reason is normalised, so identical text cannot differ by whitespace'
);

select is(
  (select count(*)::int from public.recognition_ballot_events
   where event_type = 'cast'),
  1,
  'a cast is recorded as a cycle-level event'
);

select is(
  (select count(*)::int from public.recognition_ballot_events
   where organisation_id is not null),
  1,
  'and that event names no actor, per D-024'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000003","role":"authenticated"}';

select throws_ok(
  $$select public.cast_nomination((select id from cyc),
      '5a000000-0000-0000-0000-0000000000a1')$$,
  '23505',
  null,
  'a second nomination in the same cycle is refused'
);

-- ---------------------------------------------------------------------------
-- Idempotency: a retried request must not become a second ballot
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000002","role":"authenticated"}';

create temporary table first_try as
select public.cast_nomination((select id from cyc),
  '5a000000-0000-0000-0000-0000000000a3', 'Steady all month.', 'retry-key-1') as id;

create temporary table second_try as
select public.cast_nomination((select id from cyc),
  '5a000000-0000-0000-0000-0000000000a3', 'Steady all month.', 'retry-key-1') as id;

select is(
  (select id from second_try),
  (select id from first_try),
  'resending the same idempotency key returns the original ballot'
);

reset role;

select is(
  (select count(*)::int from public.recognition_nominations),
  2,
  'and creates no second ballot'
);

-- ---------------------------------------------------------------------------
-- get_my_nomination
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000003","role":"authenticated"}';

select is(
  (select nominee_display_name from public.get_my_nomination((select id from cyc))),
  'Ben',
  'a voter can read their own ballot'
);

-- The function takes no voter argument, so this is the strongest available
-- statement of isolation: a different caller gets a different answer from the
-- identical call.
set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000002","role":"authenticated"}';
select is(
  (select nominee_display_name from public.get_my_nomination((select id from cyc))),
  'Cara',
  'the identical call returns a different voter''s own ballot, never another''s'
);

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000001","role":"authenticated"}';
select is(
  (select count(*)::int from public.get_my_nomination((select id from cyc))),
  0,
  'somebody who has not voted sees nothing, not somebody else''s ballot'
);

-- ---------------------------------------------------------------------------
-- Withdraw and recast
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000003","role":"authenticated"}';

select lives_ok(
  $$select public.withdraw_nomination((select id from cyc))$$,
  'a voter can withdraw while the cycle is open'
);

select is(
  (select count(*)::int from public.get_my_nomination((select id from cyc))),
  0,
  'a withdrawn ballot no longer reads back'
);

select throws_ok(
  $$select public.withdraw_nomination((select id from cyc))$$,
  '22023',
  null,
  'withdrawing twice is refused'
);

select lives_ok(
  $$select public.cast_nomination((select id from cyc),
      '5a000000-0000-0000-0000-0000000000a1', 'Changed my mind.')$$,
  'a voter can vote again after withdrawing'
);

reset role;

-- The whole point of withdrawing rather than deleting: one slot per voter, so
-- withdraw-then-recast cannot become two ballots.
select is(
  (select count(*)::int from public.recognition_nominations
   where nominator_user_id = '50000000-0000-0000-0000-000000000003'),
  1,
  'a recast reuses the single slot rather than creating a second ballot'
);

select is(
  (select count(*)::int from public.recognition_ballot_events
   where event_type = 'recast'),
  1,
  'the recast is recorded'
);

-- ---------------------------------------------------------------------------
-- Closing stops everything
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000001","role":"authenticated"}';

select is(
  (select public.transition_cycle((select id from cyc), 2, 'closed')),
  3,
  'an admin can close the cycle'
);

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.cast_nomination((select id from cyc),
      '5a000000-0000-0000-0000-0000000000a2')$$,
  '22023',
  null,
  'nominating after close is refused'
);

set local request.jwt.claims =
  '{"sub":"50000000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select public.withdraw_nomination((select id from cyc))$$,
  '22023',
  null,
  'withdrawing after close is refused'
);

reset role;

select * from finish();

rollback;
