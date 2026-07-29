-- DB-012, DB-013, DB-014 tests: the administrator's view.
--
-- The first assertion in this file is the most important one in the project. It
-- pins the exact column list an administrator receives for nominations. If a
-- future change adds the voter to that shape, this fails, and it fails by name
-- rather than by someone noticing.

begin;

create extension if not exists pgtap;

select plan(49);


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
  ('60000000-0000-0000-0000-000000000001', 'ana@alpha.test', now()),
  ('60000000-0000-0000-0000-000000000002', 'ben@alpha.test', now()),
  ('60000000-0000-0000-0000-000000000003', 'cara@alpha.test', now()),
  ('60000000-0000-0000-0000-000000000004', 'dee@alpha.test', now()),
  ('60000000-0000-0000-0000-000000000009', 'outsider@beta.test', now());

insert into public.organisations (id, name, timezone) values
  ('6a000000-0000-0000-0000-00000000000a', 'Alpha Ltd', 'Europe/London'),
  ('6b000000-0000-0000-0000-00000000000b', 'Beta Ltd', 'Europe/London');

insert into public.organisation_members (organisation_id, user_id, role, status) values
  ('6a000000-0000-0000-0000-00000000000a', '60000000-0000-0000-0000-000000000001', 'owner', 'active'),
  ('6a000000-0000-0000-0000-00000000000a', '60000000-0000-0000-0000-000000000002', 'member', 'active'),
  ('6a000000-0000-0000-0000-00000000000a', '60000000-0000-0000-0000-000000000003', 'member', 'active'),
  ('6a000000-0000-0000-0000-00000000000a', '60000000-0000-0000-0000-000000000004', 'member', 'active'),
  ('6b000000-0000-0000-0000-00000000000b', '60000000-0000-0000-0000-000000000009', 'owner', 'active');

insert into public.participants
  (id, organisation_id, user_id, display_name, active, can_vote, can_receive) values
  ('6a000000-0000-0000-0000-0000000000a1', '6a000000-0000-0000-0000-00000000000a',
   '60000000-0000-0000-0000-000000000001', 'Ana', true, true, true),
  ('6a000000-0000-0000-0000-0000000000a2', '6a000000-0000-0000-0000-00000000000a',
   '60000000-0000-0000-0000-000000000002', 'Ben', true, true, true),
  ('6a000000-0000-0000-0000-0000000000a3', '6a000000-0000-0000-0000-00000000000a',
   '60000000-0000-0000-0000-000000000003', 'Cara', true, true, true),
  ('6a000000-0000-0000-0000-0000000000a4', '6a000000-0000-0000-0000-00000000000a',
   '60000000-0000-0000-0000-000000000004', 'Dee', true, true, true);

insert into public.recognition_cycles (id, organisation_id, period_month, status, version) values
  ('6a000000-0000-0000-0000-0000000000c1', '6a000000-0000-0000-0000-00000000000a',
   '2026-07-01', 'open', 1);

-- Ana and Cara both nominate Ben. Dee nominates Cara. Ben has 2, Cara has 1.
insert into public.recognition_nominations
  (organisation_id, cycle_id, nominator_user_id, nominator_participant_id,
   nominee_participant_id, reason) values
  ('6a000000-0000-0000-0000-00000000000a', '6a000000-0000-0000-0000-0000000000c1',
   '60000000-0000-0000-0000-000000000001', '6a000000-0000-0000-0000-0000000000a1',
   '6a000000-0000-0000-0000-0000000000a2', 'Ana on Ben.'),
  ('6a000000-0000-0000-0000-00000000000a', '6a000000-0000-0000-0000-0000000000c1',
   '60000000-0000-0000-0000-000000000003', '6a000000-0000-0000-0000-0000000000a3',
   '6a000000-0000-0000-0000-0000000000a2', 'Cara on Ben.'),
  ('6a000000-0000-0000-0000-00000000000a', '6a000000-0000-0000-0000-0000000000c1',
   '60000000-0000-0000-0000-000000000004', '6a000000-0000-0000-0000-0000000000a4',
   '6a000000-0000-0000-0000-0000000000a3', 'Dee on Cara.');

-- ---------------------------------------------------------------------------
-- The contract that carries the whole product promise
-- ---------------------------------------------------------------------------

select is(
  (select pg_get_function_result(p.oid)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_admin_nominations'),
  'TABLE(id uuid, nominee_participant_id uuid, nominee_display_name text, '
    || 'tag text, reason text, status text, '
    || 'moderated_at timestamp with time zone, '
    || 'moderation_reason text, created_date date)',
  'the admin nomination shape is exactly this, and gains a column only on purpose'
);

select ok(
  (select pg_get_function_result(p.oid) not like '%nominator%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_admin_nominations'),
  'no administrator-facing function returns anything named nominator'
);

select ok(
  (select pg_get_function_result(p.oid) not like '%created_at%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_admin_nominations'),
  'and no precise creation timestamp, which in a small team identifies a voter'
);

select ok(
  (select pg_get_function_result(p.oid) not like '%user_id%'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_cycle_turnout'),
  'turnout returns counts only, never a person'
);

set local role authenticated;

-- ---------------------------------------------------------------------------
-- Nothing is available while voting is open
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"60000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select * from public.get_admin_nominations('6a000000-0000-0000-0000-0000000000c1')$$,
  '22023',
  null,
  'an admin cannot read reasons while voting is open (D-014)'
);

select throws_ok(
  $$select * from public.get_closed_standings('6a000000-0000-0000-0000-0000000000c1')$$,
  '22023',
  null,
  'standings are refused while voting is open, not returned empty'
);

-- Turnout is the one thing an admin may see live, and only as counts.
select is(
  (select ballots_counted from public.get_cycle_turnout('6a000000-0000-0000-0000-0000000000c1')),
  3,
  'turnout is available while open'
);

select is(
  (select turnout_percent from public.get_cycle_turnout('6a000000-0000-0000-0000-0000000000c1')),
  75,
  'and is a percentage of eligible voters'
);

-- ---------------------------------------------------------------------------
-- Who may ask
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"60000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_cycle_turnout('6a000000-0000-0000-0000-0000000000c1')$$,
  '42501',
  null,
  'a plain member cannot see turnout'
);

set local request.jwt.claims =
  '{"sub":"60000000-0000-0000-0000-000000000009","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_admin_nominations('6a000000-0000-0000-0000-0000000000c1')$$,
  '42501',
  null,
  'another tenant''s owner cannot read this cycle''s nominations'
);

select throws_ok(
  $$select public.reveal_winner('6a000000-0000-0000-0000-0000000000c1', 1)$$,
  '42501',
  null,
  'and cannot reveal it'
);

-- ---------------------------------------------------------------------------
-- Reveal refuses before close
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"60000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.reveal_winner('6a000000-0000-0000-0000-0000000000c1', 1)$$,
  '22023',
  null,
  'an open cycle cannot be revealed'
);

select is(
  (select public.transition_cycle('6a000000-0000-0000-0000-0000000000c1', 1, 'closed')),
  2,
  'the cycle closes'
);

select throws_ok(
  $$select public.reveal_winner('6a000000-0000-0000-0000-0000000000c1', 1)$$,
  '40001',
  null,
  'revealing with a stale version is refused'
);

-- ---------------------------------------------------------------------------
-- The moderation view, once closed
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int from public.get_admin_nominations('6a000000-0000-0000-0000-0000000000c1')),
  3,
  'an admin can now read the nominations'
);

-- Ordered by nominee name, never by time. A time-ordered list would hand back
-- the voting sequence that day-truncation exists to remove.
select is(
  (select string_agg(nominee_display_name, ',')
   from public.get_admin_nominations('6a000000-0000-0000-0000-0000000000c1')),
  'Ben,Ben,Cara',
  'results are ordered by nominee name rather than by when they arrived'
);

select is(
  (select count(distinct created_date)::int
   from public.get_admin_nominations('6a000000-0000-0000-0000-0000000000c1')),
  1,
  'timestamps are reduced to a date, so submission order cannot be recovered'
);

-- ---------------------------------------------------------------------------
-- Standings
-- ---------------------------------------------------------------------------

select is(
  (select nominations from public.get_closed_standings('6a000000-0000-0000-0000-0000000000c1')
   where display_name = 'Ben'),
  2,
  'standings count active ballots'
);

select is(
  (select rank from public.get_closed_standings('6a000000-0000-0000-0000-0000000000c1')
   where display_name = 'Ben'),
  1,
  'the leader ranks first'
);

select is(
  (select nominations from public.get_closed_standings('6a000000-0000-0000-0000-0000000000c1')
   where display_name = 'Ana'),
  0,
  'somebody with no nominations still appears, with zero'
);

-- ---------------------------------------------------------------------------
-- Moderation
-- ---------------------------------------------------------------------------

select throws_ok(
  $$select public.moderate_nomination(
      (select id from public.get_admin_nominations('6a000000-0000-0000-0000-0000000000c1') limit 1),
      'hide', '   ')$$,
  '22023',
  null,
  'hiding without a reason is refused, so nothing disappears unexplained'
);

select throws_ok(
  $$select public.moderate_nomination(
      (select id from public.get_admin_nominations('6a000000-0000-0000-0000-0000000000c1') limit 1),
      'delete', 'because')$$,
  '22023',
  null,
  'an unknown moderation action is refused'
);

create temporary table hidden_one as
select id from public.get_admin_nominations('6a000000-0000-0000-0000-0000000000c1')
where nominee_display_name = 'Ben' limit 1;

select lives_ok(
  $$select public.moderate_nomination((select id from hidden_one),
      'hide', 'Contained personal health information.')$$,
  'an admin can hide a nomination with a recorded reason'
);

select is(
  (select ballots_counted from public.get_cycle_turnout('6a000000-0000-0000-0000-0000000000c1')),
  2,
  'a hidden ballot stops counting toward turnout'
);

select is(
  (select nominations from public.get_closed_standings('6a000000-0000-0000-0000-0000000000c1')
   where display_name = 'Ben'),
  1,
  'and stops counting toward the tally'
);

select lives_ok(
  $$select public.moderate_nomination((select id from hidden_one), 'restore', 'Reviewed, allowed.')$$,
  'and can be restored'
);

select is(
  (select nominations from public.get_closed_standings('6a000000-0000-0000-0000-0000000000c1')
   where display_name = 'Ben'),
  2,
  'restoring puts it back in the tally'
);

-- ---------------------------------------------------------------------------
-- Reveal: the winner cannot be chosen when there is a clear leader
-- ---------------------------------------------------------------------------

select throws_ok(
  $$select public.reveal_winner('6a000000-0000-0000-0000-0000000000c1', 2,
      '6a000000-0000-0000-0000-0000000000a3', 'I prefer Cara.')$$,
  '22023',
  null,
  'a clear leader cannot be overridden by an administrator'
);

select is(
  (select public.reveal_winner('6a000000-0000-0000-0000-0000000000c1', 2)),
  '6a000000-0000-0000-0000-0000000000a2'::uuid,
  'the clear leader is revealed'
);

reset role;

select is(
  (select winner_name from public.recognition_cycles
   where id = '6a000000-0000-0000-0000-0000000000c1'),
  'Ben',
  'the winner name is snapshotted, so a later roster change cannot rewrite it'
);

select is(
  (select winner_nominations from public.recognition_cycles
   where id = '6a000000-0000-0000-0000-0000000000c1'),
  2,
  'with the count that won'
);

select is(
  (select status from public.recognition_cycles
   where id = '6a000000-0000-0000-0000-0000000000c1'),
  'revealed',
  'and the status moved in the same write'
);

-- D-027. The whole tally, not just the winner, has to be recorded at reveal.
-- After the purge severs the nominee links it cannot be recomputed, so if it is
-- not written here it is lost.

select is(
  (select jsonb_array_length(tally_snapshot) from public.recognition_cycles
   where id = '6a000000-0000-0000-0000-0000000000c1'),
  4,
  'reveal snapshots all four participants, not only the winner (D-027)'
);

select is(
  (select (e ->> 'nominations')::int
   from public.recognition_cycles c,
        lateral jsonb_array_elements(c.tally_snapshot) e
   where c.id = '6a000000-0000-0000-0000-0000000000c1'
     and e ->> 'display_name' = 'Ben'),
  2,
  'with the counts as they stood'
);

select is(
  (select (e ->> 'nominations')::int
   from public.recognition_cycles c,
        lateral jsonb_array_elements(c.tally_snapshot) e
   where c.id = '6a000000-0000-0000-0000-0000000000c1'
     and e ->> 'display_name' = 'Ana'),
  0,
  'including the people nobody nominated, so the standings still read honestly'
);

-- The hidden-then-restored ballot above proves moderation feeds the tally. The
-- snapshot must reflect the final state, not an intermediate one.
select is(
  (select sum((e ->> 'nominations')::int)::int
   from public.recognition_cycles c,
        lateral jsonb_array_elements(c.tally_snapshot) e
   where c.id = '6a000000-0000-0000-0000-0000000000c1'),
  3,
  'and the totals match the three ballots that actually counted'
);

-- D-036. Turnout is snapshotted for the same reason as the tally: the ballot
-- rows it counts are deleted once past their residual retention period.

select is(
  (select turnout_eligible from public.recognition_cycles
   where id = '6a000000-0000-0000-0000-0000000000c1'),
  4,
  'reveal freezes the eligible voter count (D-036)'
);

select is(
  (select turnout_ballots from public.recognition_cycles
   where id = '6a000000-0000-0000-0000-0000000000c1'),
  3,
  'and the ballots that counted'
);

-- This also fixes a bug that predates D-036: turnout was computed from the live
-- roster, so hiring somebody today rewrote the turnout percentage an
-- administrator may already have reported for a month that is closed.
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"60000000-0000-0000-0000-000000000001","role":"authenticated"}';

select is(
  (select turnout_percent from public.get_cycle_turnout(
     '6a000000-0000-0000-0000-0000000000c1')),
  75,
  'turnout reads 3 of 4'
);

reset role;

insert into auth.users (id, email, email_confirmed_at) values
  ('60000000-0000-0000-0000-000000000005', 'eve@alpha.test', now());

insert into public.participants
  (organisation_id, user_id, display_name, active, can_vote, can_receive)
values ('6a000000-0000-0000-0000-00000000000a',
        '60000000-0000-0000-0000-000000000005', 'Eve', true, true, true);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"60000000-0000-0000-0000-000000000001","role":"authenticated"}';

select is(
  (select turnout_percent from public.get_cycle_turnout(
     '6a000000-0000-0000-0000-0000000000c1')),
  75,
  'and a later hire does not retrospectively rewrite it (D-036)'
);

reset role;

-- ---------------------------------------------------------------------------
-- Revealed is terminal
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"60000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.reveal_winner('6a000000-0000-0000-0000-0000000000c1', 3)$$,
  '22023',
  null,
  'a revealed cycle cannot be revealed again'
);

select throws_ok(
  $$select public.transition_cycle('6a000000-0000-0000-0000-0000000000c1', 3, 'open')$$,
  '22023',
  null,
  'a revealed cycle cannot be reopened'
);

select throws_ok(
  $$select public.moderate_nomination((select id from hidden_one), 'hide', 'Too late.')$$,
  '22023',
  null,
  'what counted cannot be changed after the result is public'
);

-- ---------------------------------------------------------------------------
-- A tie, and a cycle nobody voted in
-- ---------------------------------------------------------------------------

reset role;

insert into public.recognition_cycles (id, organisation_id, period_month, status, version)
values ('6a000000-0000-0000-0000-0000000000c2', '6a000000-0000-0000-0000-00000000000a',
        '2026-06-01', 'closed', 1);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"60000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.reveal_winner('6a000000-0000-0000-0000-0000000000c2', 1)$$,
  '22023',
  null,
  'a cycle with no ballots cannot be revealed'
);

reset role;

-- One each for Ben and Cara: a genuine tie.
insert into public.recognition_nominations
  (organisation_id, cycle_id, nominator_user_id, nominator_participant_id,
   nominee_participant_id) values
  ('6a000000-0000-0000-0000-00000000000a', '6a000000-0000-0000-0000-0000000000c2',
   '60000000-0000-0000-0000-000000000001', '6a000000-0000-0000-0000-0000000000a1',
   '6a000000-0000-0000-0000-0000000000a2'),
  ('6a000000-0000-0000-0000-00000000000a', '6a000000-0000-0000-0000-0000000000c2',
   '60000000-0000-0000-0000-000000000004', '6a000000-0000-0000-0000-0000000000a4',
   '6a000000-0000-0000-0000-0000000000a3');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"60000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.reveal_winner('6a000000-0000-0000-0000-0000000000c2', 1)$$,
  '22023',
  null,
  'a tie cannot resolve itself'
);

select throws_ok(
  $$select public.reveal_winner('6a000000-0000-0000-0000-0000000000c2', 1,
      '6a000000-0000-0000-0000-0000000000a2', '  ')$$,
  '22023',
  null,
  'a tie decision without a note is refused'
);

select throws_ok(
  $$select public.reveal_winner('6a000000-0000-0000-0000-0000000000c2', 1,
      '6a000000-0000-0000-0000-0000000000a1', 'Ana is nice.')$$,
  '22023',
  null,
  'the chosen winner must be one of the joint leaders'
);

select is(
  (select public.reveal_winner('6a000000-0000-0000-0000-0000000000c2', 1,
      '6a000000-0000-0000-0000-0000000000a3', 'Longest service, agreed with the team.')),
  '6a000000-0000-0000-0000-0000000000a3'::uuid,
  'a joint leader can be chosen when the note is recorded'
);

reset role;

select is(
  (select tie_decision_note from public.recognition_cycles
   where id = '6a000000-0000-0000-0000-0000000000c2'),
  'Longest service, agreed with the team.',
  'and the reasoning is kept with the result'
);

select * from finish();

rollback;
