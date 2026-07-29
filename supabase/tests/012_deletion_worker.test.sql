-- PRV-010: the deletion worker.
--
-- The assertion that matters most in this file is not that the account goes. It
-- is that the person's name goes with it — from the roster, and from the tally
-- snapshot that D-027 added, which names every participant of every revealed
-- month and would otherwise quietly outlive the erasure.

begin;

create extension if not exists pgtap;

select plan(24);

delete from public.organisations;
delete from auth.users;

insert into auth.users (id, email, email_confirmed_at) values
  ('c0000000-0000-0000-0000-000000000001', 'owner@alpha.test', now()),
  ('c0000000-0000-0000-0000-000000000002', 'coowner@alpha.test', now()),
  ('c0000000-0000-0000-0000-000000000003', 'leaver@alpha.test', now()),
  ('c0000000-0000-0000-0000-000000000004', 'stayer@alpha.test', now()),
  ('c0000000-0000-0000-0000-000000000009', 'sole@beta.test', now());

insert into public.organisations (id, name, timezone) values
  ('ca000000-0000-0000-0000-00000000000a', 'Alpha Ltd', 'Europe/London'),
  ('cb000000-0000-0000-0000-00000000000b', 'Beta Ltd', 'Europe/London');

insert into public.organisation_members (organisation_id, user_id, role, status) values
  ('ca000000-0000-0000-0000-00000000000a', 'c0000000-0000-0000-0000-000000000001', 'owner', 'active'),
  ('ca000000-0000-0000-0000-00000000000a', 'c0000000-0000-0000-0000-000000000002', 'owner', 'active'),
  ('ca000000-0000-0000-0000-00000000000a', 'c0000000-0000-0000-0000-000000000003', 'member', 'active'),
  ('ca000000-0000-0000-0000-00000000000a', 'c0000000-0000-0000-0000-000000000004', 'member', 'active'),
  ('cb000000-0000-0000-0000-00000000000b', 'c0000000-0000-0000-0000-000000000009', 'owner', 'active');

insert into public.participants (id, organisation_id, user_id, display_name) values
  ('ca000000-0000-0000-0000-0000000000a1', 'ca000000-0000-0000-0000-00000000000a',
   'c0000000-0000-0000-0000-000000000001', 'The Owner'),
  ('ca000000-0000-0000-0000-0000000000a3', 'ca000000-0000-0000-0000-00000000000a',
   'c0000000-0000-0000-0000-000000000003', 'Priya Leaver'),
  ('ca000000-0000-0000-0000-0000000000a4', 'ca000000-0000-0000-0000-00000000000a',
   'c0000000-0000-0000-0000-000000000004', 'Sam Stayer');

-- A revealed month that Priya won, with a tally naming both her and Sam.
insert into public.recognition_cycles
  (id, organisation_id, period_month, status, version,
   winner_participant_id, winner_name, winner_nominations, revealed_at,
   turnout_eligible, turnout_ballots, tally_snapshot)
values
  ('cc000000-0000-0000-0000-0000000000c1', 'ca000000-0000-0000-0000-00000000000a',
   '2026-05-01', 'revealed', 4, 'ca000000-0000-0000-0000-0000000000a3',
   'Priya Leaver', 2, now() - interval '2 days', 3, 3,
   jsonb_build_array(
     jsonb_build_object('participant_id', 'ca000000-0000-0000-0000-0000000000a3'::uuid,
                        'display_name', 'Priya Leaver', 'nominations', 2),
     jsonb_build_object('participant_id', 'ca000000-0000-0000-0000-0000000000a4'::uuid,
                        'display_name', 'Sam Stayer', 'nominations', 1)));

-- ---------------------------------------------------------------------------
-- Who may run it
-- ---------------------------------------------------------------------------

select ok(
  not has_function_privilege('anon', 'public.process_deletion_requests(boolean)', 'execute'),
  'anon cannot run the deletion worker'
);

select ok(
  not has_function_privilege('authenticated', 'public.process_deletion_requests(boolean)', 'execute'),
  'and neither can a signed-in user, not even an owner'
);

select ok(
  has_function_privilege('service_role', 'public.process_deletion_requests(boolean)', 'execute'),
  'only the trusted role can'
);

-- ---------------------------------------------------------------------------
-- Queue two requests: an ordinary member, and a sole owner
-- ---------------------------------------------------------------------------

set local role authenticated;

set local request.jwt.claims =
  '{"sub":"c0000000-0000-0000-0000-000000000003","role":"authenticated"}';
select lives_ok(
  $$select public.request_account_deletion()$$,
  'the leaver requests deletion'
);

set local request.jwt.claims =
  '{"sub":"c0000000-0000-0000-0000-000000000009","role":"authenticated"}';
select throws_ok(
  $$select public.request_account_deletion()$$,
  '22023',
  null,
  'a sole owner is blocked at request time'
);

reset role;

-- Queued directly, to prove the worker re-checks rather than trusting that the
-- request-time block held. Ownership can change between asking and processing.
insert into public.privacy_requests (user_id, request_type, state, due_at)
values ('c0000000-0000-0000-0000-000000000009', 'deletion', 'received',
        now() + interval '30 days');

-- ---------------------------------------------------------------------------
-- The dry run
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int from public.process_deletion_requests(true)),
  2,
  'the dry run reports both queued requests'
);

select is(
  (select count(*)::int from auth.users
   where id = 'c0000000-0000-0000-0000-000000000003'),
  1,
  'and erases nobody'
);

select is(
  (select outcome from public.process_deletion_requests(true)
   where subject_user_id = 'c0000000-0000-0000-0000-000000000009'),
  'refused_sole_owner',
  'the sole owner is refused, not skipped, so the deadline cannot pass unseen'
);

select is(
  (select detail from public.process_deletion_requests(true)
   where subject_user_id = 'c0000000-0000-0000-0000-000000000003'),
  '1 award record(s) retained under D-023',
  'and the leaver is told a winner record will survive them'
);

-- ---------------------------------------------------------------------------
-- The live run
-- ---------------------------------------------------------------------------

select lives_ok(
  $$select * from public.process_deletion_requests(false)$$,
  'the live run executes'
);

select is(
  (select count(*)::int from auth.users
   where id = 'c0000000-0000-0000-0000-000000000003'),
  0,
  'the account is gone'
);

select is(
  (select count(*)::int from public.participants
   where display_name = 'Priya Leaver'),
  0,
  'the roster entry is gone, not merely detached from the account'
);

select is(
  (select count(*)::int from public.organisation_members
   where user_id = 'c0000000-0000-0000-0000-000000000003'),
  0,
  'and the membership with it'
);

-- The assertion this file exists for.
select ok(
  (select tally_snapshot::text not like '%Priya Leaver%'
   from public.recognition_cycles
   where id = 'cc000000-0000-0000-0000-0000000000c1'),
  'the erased name is scrubbed from the tally snapshot (D-027 leak)'
);

select is(
  (select sum((e ->> 'nominations')::int)::int
   from public.recognition_cycles c,
        lateral jsonb_array_elements(c.tally_snapshot) e
   where c.id = 'cc000000-0000-0000-0000-0000000000c1'),
  3,
  'but the counts stay, so a past month still adds up'
);

select is(
  (select e ->> 'display_name'
   from public.recognition_cycles c,
        lateral jsonb_array_elements(c.tally_snapshot) e
   where c.id = 'cc000000-0000-0000-0000-0000000000c1'
     and (e ->> 'nominations')::int = 2),
  'A former colleague',
  'replaced with the same wording the winner redaction uses'
);

select ok(
  (select tally_snapshot::text like '%Sam Stayer%'
   from public.recognition_cycles
   where id = 'cc000000-0000-0000-0000-0000000000c1'),
  'and nobody else is touched'
);

-- D-023: the award survives. That is a decided position, not an oversight, and
-- D-028 is the route if the controller decides otherwise.
select is(
  (select winner_name from public.recognition_cycles
   where id = 'cc000000-0000-0000-0000-0000000000c1'),
  'Priya Leaver',
  'the winner name survives erasure, as D-023 decided'
);

select is(
  (select turnout_ballots from public.recognition_cycles
   where id = 'cc000000-0000-0000-0000-0000000000c1'),
  3,
  'and turnout is unmoved, because D-036 froze it before the ballots went'
);

-- ---------------------------------------------------------------------------
-- The paper trail
-- ---------------------------------------------------------------------------

select is(
  (select state from public.privacy_requests
   where request_type = 'deletion' and operator_note like 'Erased.%'),
  'completed',
  'the request is marked completed'
);

select is(
  (select user_id from public.privacy_requests
   where request_type = 'deletion' and operator_note like 'Erased.%'),
  null,
  'and survives the erasure it records, with the subject nulled out'
);

select is(
  (select state from public.privacy_requests
   where user_id = 'c0000000-0000-0000-0000-000000000009'),
  'refused',
  'the sole owner request is recorded as refused with a reason'
);

select is(
  (select count(*)::int from public.audit_events where action = 'account_erased'),
  1,
  'the erasure is audited'
);

-- Idempotence. A scheduled job runs nightly; the second night must find only
-- the refusal, which stays refused rather than being retried forever.
select is(
  (select count(*)::int from public.process_deletion_requests(false)),
  0,
  'running it again finds nothing left to do'
);

select * from finish();

rollback;
