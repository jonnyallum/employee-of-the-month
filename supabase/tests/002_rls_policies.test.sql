-- Role-based RLS tests for DB-005 and DB-006.
--
-- 001 proves the schema's structure. This file proves its behaviour, by
-- becoming each actor in turn and asking what they can actually reach. Those
-- are different questions: a correct grant list with a wrong policy still leaks.
--
-- Every operation is exercised as signed out, a member, an admin, an owner, and
-- a member of a DIFFERENT organisation. The last one is the one that matters
-- most and the easiest to forget, because everything looks correct until
-- somebody else's tenant is asked for by id.
--
-- Personas are simulated the way PostgREST does it: assume the `authenticated`
-- role and set the JWT claims that auth.uid() reads. Nothing here trusts the
-- application layer, because in production nothing can.

begin;

create extension if not exists pgtap;

select plan(33);


-- The seed in supabase/seed.sql has already run against this database. This
-- suite asserts absolute counts and creates its own fixtures, so it starts from
-- an empty slate instead. Both deletes are inside the transaction and are undone
-- by the rollback at the end, so the seed survives for the next file.
--
-- Deleting organisations cascades to members, participants, cycles, ballots,
-- invitations and settings; deleting users cascades to profiles.
delete from public.organisations;
delete from auth.users;

-- ---------------------------------------------------------------------------
-- Fixtures, created as the migration role before any persona is assumed.
--
-- Alpha: Ana (owner), Ben (admin), Cara (member)
-- Beta:  Dev (owner). Same shape, different tenant, used for every isolation
--        assertion.
-- ---------------------------------------------------------------------------

insert into auth.users (id, email) values
  ('10000000-0000-0000-0000-000000000001', 'ana@alpha.test'),
  ('10000000-0000-0000-0000-000000000002', 'ben@alpha.test'),
  ('10000000-0000-0000-0000-000000000003', 'cara@alpha.test'),
  ('10000000-0000-0000-0000-000000000004', 'erin@alpha.test'),
  ('20000000-0000-0000-0000-000000000001', 'dev@beta.test');

insert into public.organisations (id, name, timezone) values
  ('1a000000-0000-0000-0000-00000000000a', 'Alpha Ltd', 'Europe/London'),
  ('2b000000-0000-0000-0000-00000000000b', 'Beta Ltd', 'Europe/London');

insert into public.organisation_members (organisation_id, user_id, role, status) values
  ('1a000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000001', 'owner', 'active'),
  ('1a000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000002', 'admin', 'active'),
  ('1a000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000003', 'member', 'active'),
  -- Erin has left. She must be treated as an outsider immediately, not when her
  -- access token happens to expire.
  ('1a000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000004', 'member', 'left'),
  ('2b000000-0000-0000-0000-00000000000b', '20000000-0000-0000-0000-000000000001', 'owner', 'active');

insert into public.participants
  (id, organisation_id, user_id, display_name, active, can_vote, can_receive) values
  ('1a000000-0000-0000-0000-0000000000a1', '1a000000-0000-0000-0000-00000000000a',
   '10000000-0000-0000-0000-000000000001', 'Ana', true, true, true),
  ('1a000000-0000-0000-0000-0000000000a2', '1a000000-0000-0000-0000-00000000000a',
   '10000000-0000-0000-0000-000000000002', 'Ben', true, true, true),
  ('1a000000-0000-0000-0000-0000000000a3', '1a000000-0000-0000-0000-00000000000a',
   '10000000-0000-0000-0000-000000000003', 'Cara', true, false, true),
  ('1a000000-0000-0000-0000-0000000000a4', '1a000000-0000-0000-0000-00000000000a',
   null, 'Dara (invited)', false, true, true),
  ('2b000000-0000-0000-0000-0000000000b1', '2b000000-0000-0000-0000-00000000000b',
   '20000000-0000-0000-0000-000000000001', 'Dev', true, true, true);

insert into public.recognition_cycles (id, organisation_id, period_month, status, criteria) values
  ('1a000000-0000-0000-0000-0000000000c1', '1a000000-0000-0000-0000-00000000000a',
   '2026-07-01', 'open', 'Went out of their way for a colleague.'),
  ('2b000000-0000-0000-0000-0000000000c2', '2b000000-0000-0000-0000-00000000000b',
   '2026-07-01', 'open', 'Beta criteria.');

insert into public.recognition_settings (organisation_id) values
  ('1a000000-0000-0000-0000-00000000000a'),
  ('2b000000-0000-0000-0000-00000000000b');

-- Cara nominates Ben. This is the row every assertion below tries and fails to
-- reach.
insert into public.recognition_nominations
  (organisation_id, cycle_id, nominator_user_id,
   nominator_participant_id, nominee_participant_id, reason)
values
  ('1a000000-0000-0000-0000-00000000000a', '1a000000-0000-0000-0000-0000000000c1',
   '10000000-0000-0000-0000-000000000003',
   '1a000000-0000-0000-0000-0000000000a3',
   '1a000000-0000-0000-0000-0000000000a2',
   'Stayed late to finish a customer handover.');

insert into public.organisation_invitations
  (organisation_id, participant_id, email_normalised, token_hash, expires_at)
values
  ('1a000000-0000-0000-0000-00000000000a', '1a000000-0000-0000-0000-0000000000a4',
   'dara@alpha.test', repeat('e', 64), now() + interval '7 days');

-- ---------------------------------------------------------------------------
-- Signed out. anon should reach nothing at all.
-- ---------------------------------------------------------------------------

set local role anon;

select throws_ok(
  'select * from public.organisations',
  '42501',
  null,
  'signed out: organisations refused outright, not merely filtered'
);

select throws_ok(
  'select * from public.participants',
  '42501',
  null,
  'signed out: participants refused'
);

select throws_ok(
  'select * from public.recognition_cycles',
  '42501',
  null,
  'signed out: cycles refused'
);

select throws_ok(
  'select * from public.recognition_nominations',
  '42501',
  null,
  'signed out: ballots refused'
);

reset role;

-- ---------------------------------------------------------------------------
-- T1. The central promise, asked as every role that might expect an answer.
-- ---------------------------------------------------------------------------

set local role authenticated;

set local request.jwt.claims =
  '{"sub":"10000000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok(
  'select * from public.recognition_nominations',
  '42501',
  null,
  'a member cannot read the ballot table, not even the ballot they cast'
);

set local request.jwt.claims =
  '{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  'select * from public.recognition_nominations',
  '42501',
  null,
  'an ADMIN cannot read the ballot table'
);

select throws_ok(
  'select nominator_user_id from public.recognition_nominations',
  '42501',
  null,
  'an admin cannot reach the voter column by naming it directly'
);

select throws_ok(
  'select count(*) from public.recognition_nominations',
  '42501',
  null,
  'an admin cannot even count ballots, which would leak turnout live'
);

set local request.jwt.claims =
  '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  'select * from public.recognition_nominations',
  '42501',
  null,
  'an OWNER cannot read the ballot table either'
);

-- ---------------------------------------------------------------------------
-- Withheld columns. A refusal, not a silent omission.
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"10000000-0000-0000-0000-000000000003","role":"authenticated"}';

select throws_ok(
  'select user_id from public.participants',
  '42501',
  null,
  'a member asking for participants.user_id is refused, not quietly given null'
);

select throws_ok(
  'select can_vote from public.participants',
  '42501',
  null,
  'a member cannot read who is eligible to vote'
);

select lives_ok(
  'select id, display_name, can_receive from public.participants',
  'the granted participant columns still work'
);

-- ---------------------------------------------------------------------------
-- Tenant isolation.
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int from public.organisations),
  1,
  'a member sees exactly one organisation, their own'
);

select is(
  (select name from public.organisations),
  'Alpha Ltd',
  'and it is the right one'
);

select is(
  (
    select count(*)::int from public.organisations
    where id = '2b000000-0000-0000-0000-00000000000b'
  ),
  0,
  'asking for another tenant by id returns nothing rather than erroring'
);

select is(
  (select count(*)::int from public.participants),
  3,
  'roster shows the three active participants, not the inactive invitee'
);

select is(
  (select count(*)::int from public.recognition_cycles),
  1,
  'a member sees only their own organisation''s cycle'
);

select is(
  (select count(*)::int from public.organisation_members),
  4,
  'membership is visible inside the tenant, including the departed row'
);

-- Now as Beta's owner, who is a full owner in their own tenant and a nobody in
-- Alpha's.
set local request.jwt.claims =
  '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated"}';

select is(
  (select count(*)::int from public.participants),
  1,
  'another tenant''s owner sees only their own roster'
);

select is(
  (
    select count(*)::int from public.recognition_cycles
    where organisation_id = '1a000000-0000-0000-0000-00000000000a'
  ),
  0,
  'another tenant''s owner cannot read Alpha''s cycle by id'
);

select is(
  (select count(*)::int from public.organisation_members
   where organisation_id = '1a000000-0000-0000-0000-00000000000a'),
  0,
  'another tenant''s owner cannot enumerate Alpha''s members'
);

-- ---------------------------------------------------------------------------
-- Membership is read live. A departed member is out immediately.
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"10000000-0000-0000-0000-000000000004","role":"authenticated"}';

select is(
  (select count(*)::int from public.organisations),
  0,
  'a member whose status is left sees nothing, without waiting for token expiry'
);

select is(
  (select count(*)::int from public.participants),
  0,
  'and reaches no roster'
);

-- ---------------------------------------------------------------------------
-- profiles: own row only, and writable only where intended.
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"10000000-0000-0000-0000-000000000003","role":"authenticated"}';

select is(
  (select count(*)::int from public.profiles),
  1,
  'a user sees exactly one profile, their own'
);

select is(
  (select user_id from public.profiles),
  '10000000-0000-0000-0000-000000000003'::uuid,
  'and it is theirs'
);

select lives_ok(
  $$update public.profiles set display_name = 'Cara R.'
    where user_id = '10000000-0000-0000-0000-000000000003'$$,
  'a user can rename themselves'
);

select is(
  (
    select count(*)::int from public.profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  0,
  'another user''s profile is invisible'
);

-- The row is invisible to this caller, so the statement is allowed to run and
-- simply matches nothing. Silence is not proof, so the value is checked
-- afterwards from outside the policy rather than trusting the row count.
select lives_ok(
  $$update public.profiles set display_name = 'hacked'
    where user_id = '10000000-0000-0000-0000-000000000001'$$,
  'an update aimed at another user is accepted but matches no row'
);

-- ---------------------------------------------------------------------------
-- Tables that were left closed must have stayed closed.
-- ---------------------------------------------------------------------------

select throws_ok(
  'select * from public.organisation_invitations',
  '42501',
  null,
  'invitations stay unreachable, so the employee email list is not a query away'
);

select throws_ok(
  'select * from public.audit_events',
  '42501',
  null,
  'audit events stay unreachable'
);

select throws_ok(
  'select * from public.device_push_tokens',
  '42501',
  null,
  'push tokens stay unreachable'
);

reset role;

-- Checked from outside any policy, which is the only way to know the earlier
-- attempt truly did nothing rather than being hidden from its own author.
select is(
  (
    select display_name from public.profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  'ana',
  'the targeted user''s name is genuinely unchanged'
);

-- The nominator is still recorded, so confidentiality here is a property of the
-- exposure rules rather than of the data being absent. Worth asserting: if a
-- future change ever dropped the column, the one-vote and eligibility rules
-- would silently stop working.
select is(
  (
    select count(*)::int from public.recognition_nominations
    where nominator_user_id = '10000000-0000-0000-0000-000000000003'
  ),
  1,
  'the ballot and its voter link do exist, and are simply unreachable'
);

select * from finish();

rollback;
