-- Invariant tests for DB-002 and DB-003.
--
-- These assert that the schema REFUSES things. A suite that only proves the
-- happy path proves nothing about a security boundary, because every threat in
-- docs/SCHEMA_THREAT_MODEL.md is about the unintended path.
--
-- Role-based RLS tests belong to DB-005 and DB-006, once policies exist. What
-- is testable now is structure: fail-closed exposure, tenant coherence,
-- immutability and the constraints that carry an invariant.
--
--   npm run db:test

begin;

-- Created inside the transaction so it rolls back with everything else and
-- never reaches a deployed database.
create extension if not exists pgtap;

-- Must match the assertion count exactly. A plan is not bureaucracy: it is what
-- catches a test that silently stopped running rather than silently passing.
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

-- ---------------------------------------------------------------------------
-- Fail-closed exposure
-- ---------------------------------------------------------------------------

select is(
  (
    select count(*)::int
    from pg_tables
    where schemaname = 'public' and not rowsecurity
  ),
  0,
  'every public table has row level security enabled'
);

select is(
  (
    select count(*)::int
    from information_schema.role_table_grants
    where table_schema = 'public' and grantee = 'anon'
  ),
  0,
  'anon holds no table grant anywhere'
);

select is(
  (
    select count(*)::int
    from information_schema.role_column_grants
    where table_schema = 'public' and grantee = 'anon'
  ),
  0,
  'anon holds no column grant anywhere'
);

-- Pins the whole exposure surface by name. Any table that gains a grant without
-- this list being updated fails here, which is the point: the failure mode this
-- guards against is a future migration granting something reasonable-looking on
-- a table the threat model deliberately left closed.
select is(
  (
    select string_agg(distinct table_name, ',' order by table_name)
    from information_schema.role_column_grants
    where table_schema = 'public' and grantee = 'authenticated'
  ),
  'organisation_members,organisations,participants,profiles,'
    || 'recognition_cycles,recognition_settings',
  'exactly six tables are reachable by a client, and no others'
);

-- The two withheld columns are what stop a member joining a roster name to an
-- auth identity, and what stop the eligible-voter set narrowing the possible
-- authors of a reason.
select is(
  (
    select count(*)::int
    from information_schema.role_column_grants
    where table_schema = 'public'
      and table_name = 'participants'
      and grantee = 'authenticated'
      and column_name in ('user_id', 'can_vote')
  ),
  0,
  'participants never exposes user_id or can_vote to a client'
);

select is(
  (
    select count(*)::int
    from information_schema.role_column_grants
    where table_schema = 'public'
      and table_name = 'profiles'
      and grantee = 'authenticated'
      and privilege_type = 'UPDATE'
      and column_name <> 'display_name'
  ),
  0,
  'profiles is writable only in the display_name column'
);

select ok(
  not has_schema_privilege('anon', 'private', 'usage'),
  'anon cannot use the private schema'
);

-- authenticated DOES hold USAGE on private, because policy expressions are
-- evaluated with the caller's privileges and would otherwise fail. That is not
-- exposure: PostgREST serves only its configured schemas, and private is not
-- one. What must stay true is that the grant is narrow, so assert the exact set
-- of helpers a client can execute.
select is(
  (
    select string_agg(p.proname, ',' order by p.proname)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
      and has_function_privilege('authenticated', p.oid, 'execute')
  ),
  'has_org_role,is_org_member,org_is_live',
  'a client can execute only the three policy helpers in private, nothing else'
);

-- The trusted server role is pinned too. BYPASSRLS exempts it from policies but
-- grants it nothing, so its reach is exactly this list. Anything added here is a
-- deliberate widening of what a compromised server function could touch, and in
-- particular the ballot table must never appear.
select is(
  (
    select string_agg(
      table_name || ':' || privilege_type, ', '
      order by table_name, privilege_type)
    from information_schema.role_table_grants
    where table_schema = 'public'
      and grantee = 'service_role'
      and privilege_type in ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
  ),
  'audit_events:INSERT, notification_deliveries:INSERT, '
    || 'notification_deliveries:SELECT, notification_deliveries:UPDATE',
  'the trusted server role can write only delivery records and audit entries'
);

-- The single most important line in the schema. If a grant ever appears here,
-- T1 is open and the product promise is broken.
select is(
  (
    select count(*)::int
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'recognition_nominations'
      and grantee in ('anon', 'authenticated')
  ),
  0,
  'recognition_nominations is unreachable by any client role'
);

-- ---------------------------------------------------------------------------
-- Fixtures. Two organisations, so cross-tenant attempts are testable.
-- ---------------------------------------------------------------------------

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a001', 'ana@example.com'),
  ('00000000-0000-0000-0000-00000000a002', 'ben@example.com'),
  ('00000000-0000-0000-0000-00000000b001', 'cara@example.com');

insert into public.organisations (id, name, timezone, created_by) values
  ('00000000-0000-0000-0000-0000000000a1', 'Alpha Ltd', 'Europe/London',
   '00000000-0000-0000-0000-00000000a001'),
  ('00000000-0000-0000-0000-0000000000b1', 'Beta Ltd', 'Europe/London',
   '00000000-0000-0000-0000-00000000b001');

insert into public.participants (id, organisation_id, user_id, display_name) values
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000a1',
   '00000000-0000-0000-0000-00000000a001', 'Ana'),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a1',
   '00000000-0000-0000-0000-00000000a002', 'Ben'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000b1',
   '00000000-0000-0000-0000-00000000b001', 'Cara');

insert into public.recognition_cycles (id, organisation_id, period_month, status) values
  ('00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-0000000000a1',
   '2026-07-01', 'open'),
  ('00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-0000000000b1',
   '2026-07-01', 'open');

-- ---------------------------------------------------------------------------
-- profiles bootstrap
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int from public.profiles),
  3,
  'a profile is created automatically for every new auth user'
);

select is(
  (select display_name from public.profiles
   where user_id = '00000000-0000-0000-0000-00000000a001'),
  'ana',
  'display name falls back to the email local part, never empty'
);

-- ---------------------------------------------------------------------------
-- organisations
-- ---------------------------------------------------------------------------

select throws_ok(
  $$insert into public.organisations (name, timezone)
    values ('Bad Zone Ltd', 'Mars/Olympus')$$,
  '23514',
  null,
  'an unknown IANA timezone is refused'
);

select lives_ok(
  $$insert into public.organisations (name, timezone)
    values ('Good Zone Ltd', 'Australia/Eucla')$$,
  'an unusual but real timezone is accepted'
);

select throws_ok(
  $$insert into public.organisations (name, timezone) values ('   ', 'Europe/London')$$,
  '23514',
  null,
  'a whitespace-only organisation name is refused'
);

-- ---------------------------------------------------------------------------
-- Tenant coherence and immutability
-- ---------------------------------------------------------------------------

select throws_ok(
  $$update public.participants
    set organisation_id = '00000000-0000-0000-0000-0000000000b1'
    where id = '00000000-0000-0000-0000-0000000000a2'$$,
  '23514',
  null,
  'a participant cannot be walked into another tenant by update'
);

select throws_ok(
  $$update public.recognition_cycles
    set organisation_id = '00000000-0000-0000-0000-0000000000b1'
    where id = '00000000-0000-0000-0000-0000000000a4'$$,
  '23514',
  null,
  'a cycle cannot be walked into another tenant by update'
);

select throws_ok(
  $$insert into public.participants (organisation_id, user_id, display_name)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-00000000a001', 'Ana again')$$,
  '23505',
  null,
  'one live participant link per user per organisation'
);

-- ---------------------------------------------------------------------------
-- Invitations
-- ---------------------------------------------------------------------------

select throws_ok(
  $$insert into public.organisation_invitations
      (organisation_id, participant_id, email_normalised, token_hash, expires_at)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000b2',
            'cara@example.com', repeat('a', 64), now() + interval '7 days')$$,
  '23503',
  null,
  'an invitation cannot reference a participant in another organisation'
);

select throws_ok(
  $$insert into public.organisation_invitations
      (organisation_id, participant_id, email_normalised, token_hash, expires_at)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000a3',
            'ben@example.com', 'not-a-sha256-digest', now() + interval '7 days')$$,
  '23514',
  null,
  'a token that is not a SHA-256 digest is refused, so no plaintext can be stored'
);

select throws_ok(
  $$insert into public.organisation_invitations
      (organisation_id, participant_id, email_normalised, token_hash, expires_at)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000a3',
            'Ben@Example.com', repeat('b', 64), now() + interval '7 days')$$,
  '23514',
  null,
  'an un-normalised email is refused rather than silently stored twice'
);

select lives_ok(
  $$insert into public.organisation_invitations
      (organisation_id, participant_id, email_normalised, token_hash, expires_at)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000a3',
            'ben@example.com', repeat('c', 64), now() + interval '7 days')$$,
  'a well-formed invitation is accepted'
);

select throws_ok(
  $$insert into public.organisation_invitations
      (organisation_id, participant_id, email_normalised, token_hash, expires_at)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000a3',
            'ben@example.com', repeat('d', 64), now() + interval '7 days')$$,
  '23505',
  null,
  'reissuing cannot leave two live tokens for the same participant'
);

-- ---------------------------------------------------------------------------
-- Cycles
-- ---------------------------------------------------------------------------

select throws_ok(
  $$insert into public.recognition_cycles (organisation_id, period_month)
    values ('00000000-0000-0000-0000-0000000000a1', '2026-08-15')$$,
  '23514',
  null,
  'a period that is not the first of a month is refused'
);

select throws_ok(
  $$insert into public.recognition_cycles (organisation_id, period_month)
    values ('00000000-0000-0000-0000-0000000000a1', '2026-07-01')$$,
  '23505',
  null,
  'one cycle per organisation per calendar month'
);

select lives_ok(
  $$insert into public.recognition_cycles (organisation_id, period_month)
    values ('00000000-0000-0000-0000-0000000000b1', '2026-08-01')$$,
  'the same month in a different organisation is fine'
);

-- FR-RESULT-01. Winner data must not be able to exist on an unrevealed cycle,
-- because members can read this table.
select throws_ok(
  $$update public.recognition_cycles
    set winner_participant_id = '00000000-0000-0000-0000-0000000000a3',
        winner_name = 'Ben', winner_nominations = 2
    where id = '00000000-0000-0000-0000-0000000000a4'$$,
  '23514',
  null,
  'a winner cannot be recorded while the cycle is not revealed'
);

select throws_ok(
  $$update public.recognition_cycles set status = 'revealed'
    where id = '00000000-0000-0000-0000-0000000000a4'$$,
  '23514',
  null,
  'a cycle cannot be revealed with no winner recorded'
);

select lives_ok(
  $$update public.recognition_cycles
    set status = 'revealed',
        winner_participant_id = '00000000-0000-0000-0000-0000000000a3',
        winner_name = 'Ben', winner_nominations = 2, revealed_at = now()
    where id = '00000000-0000-0000-0000-0000000000a4'$$,
  'status and winner recorded together is the only accepted shape'
);

select throws_ok(
  $$insert into public.recognition_cycles
      (organisation_id, period_month, opens_at, closes_at)
    values ('00000000-0000-0000-0000-0000000000a1', '2026-09-01',
            now(), now() - interval '1 day')$$,
  '23514',
  null,
  'a cycle cannot close before it opens'
);

-- ---------------------------------------------------------------------------
-- Ballots
-- ---------------------------------------------------------------------------

insert into public.recognition_cycles (id, organisation_id, period_month, status)
values ('00000000-0000-0000-0000-0000000000a5',
        '00000000-0000-0000-0000-0000000000a1', '2026-06-01', 'open');

select throws_ok(
  $$insert into public.recognition_nominations
      (organisation_id, cycle_id, nominator_user_id,
       nominator_participant_id, nominee_participant_id)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000a5',
            '00000000-0000-0000-0000-00000000a001',
            '00000000-0000-0000-0000-0000000000a2',
            '00000000-0000-0000-0000-0000000000a2')$$,
  '23514',
  null,
  'self-nomination is refused by constraint, not by application code'
);

-- Passing somebody else's participant id is the obvious way to sidestep the
-- self-vote check, so it must fail on its own.
select throws_ok(
  $$insert into public.recognition_nominations
      (organisation_id, cycle_id, nominator_user_id,
       nominator_participant_id, nominee_participant_id)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000a5',
            '00000000-0000-0000-0000-00000000a001',
            '00000000-0000-0000-0000-0000000000a3',
            '00000000-0000-0000-0000-0000000000a2')$$,
  '23514',
  null,
  'the nominator participant must belong to the nominating user'
);

select throws_ok(
  $$insert into public.recognition_nominations
      (organisation_id, cycle_id, nominator_user_id,
       nominator_participant_id, nominee_participant_id)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000a5',
            '00000000-0000-0000-0000-00000000a001',
            '00000000-0000-0000-0000-0000000000a2',
            '00000000-0000-0000-0000-0000000000b2')$$,
  '23503',
  null,
  'a nominee in another organisation is refused'
);

select lives_ok(
  $$insert into public.recognition_nominations
      (organisation_id, cycle_id, nominator_user_id,
       nominator_participant_id, nominee_participant_id, reason)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000a5',
            '00000000-0000-0000-0000-00000000a001',
            '00000000-0000-0000-0000-0000000000a2',
            '00000000-0000-0000-0000-0000000000a3',
            'Covered a difficult handover.')$$,
  'a valid ballot is accepted'
);

select throws_ok(
  $$insert into public.recognition_nominations
      (organisation_id, cycle_id, nominator_user_id,
       nominator_participant_id, nominee_participant_id)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000a5',
            '00000000-0000-0000-0000-00000000a001',
            '00000000-0000-0000-0000-0000000000a2',
            '00000000-0000-0000-0000-0000000000a3')$$,
  '23505',
  null,
  'a second ballot from the same voter in the same cycle is refused'
);

select throws_ok(
  $$update public.recognition_nominations set status = 'hidden'
    where cycle_id = '00000000-0000-0000-0000-0000000000a5'$$,
  '23514',
  null,
  'hiding a ballot without a moderator and a reason is refused'
);

select throws_ok(
  $$insert into public.recognition_nominations
      (organisation_id, cycle_id, nominator_user_id,
       nominator_participant_id, nominee_participant_id, reason)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000a5',
            '00000000-0000-0000-0000-00000000a002',
            '00000000-0000-0000-0000-0000000000a3',
            '00000000-0000-0000-0000-0000000000a2',
            repeat('x', 501))$$,
  '23514',
  null,
  'a reason over 500 characters is refused'
);

select * from finish();

rollback;
