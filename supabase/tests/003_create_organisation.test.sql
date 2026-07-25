-- DB-007 tests: create_organisation.
--
-- The function's whole reason to exist is atomicity and authorisation, so the
-- tests are about who may call it, what it refuses, and what the database looks
-- like afterwards. A test that only proved "it returns a uuid" would miss every
-- way this can go wrong.

begin;

create extension if not exists pgtap;

select plan(23);

insert into auth.users (id, email, email_confirmed_at) values
  ('30000000-0000-0000-0000-000000000001', 'verified@test.example', now()),
  ('30000000-0000-0000-0000-000000000002', 'unverified@test.example', null);

-- ---------------------------------------------------------------------------
-- Who may call it
-- ---------------------------------------------------------------------------

select ok(
  not has_function_privilege('anon', 'public.create_organisation(text, text)', 'execute'),
  'anon cannot execute create_organisation'
);

select ok(
  has_function_privilege('authenticated', 'public.create_organisation(text, text)', 'execute'),
  'authenticated can execute create_organisation'
);

set local role anon;
select throws_ok(
  $$select public.create_organisation('Sneaky Ltd', 'Europe/London')$$,
  '42501',
  null,
  'a signed-out caller is refused'
);
reset role;

set local role authenticated;

-- Authenticated at the database level but with no JWT, so auth.uid() is null.
-- Worth its own case: it is the shape a misconfigured client produces.
select throws_ok(
  $$select public.create_organisation('No Claims Ltd', 'Europe/London')$$,
  '42501',
  null,
  'an authenticated role with no user claim is refused'
);

set local request.jwt.claims =
  '{"sub":"30000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.create_organisation('Unverified Ltd', 'Europe/London')$$,
  '42501',
  null,
  'an unverified email cannot create an organisation'
);

-- ---------------------------------------------------------------------------
-- What it refuses
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"30000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.create_organisation('   ', 'Europe/London')$$,
  '22023',
  null,
  'a whitespace-only name is refused'
);

select throws_ok(
  $$select public.create_organisation(null, 'Europe/London')$$,
  '22023',
  null,
  'a null name is refused rather than becoming an empty organisation'
);

select throws_ok(
  $$select public.create_organisation('Bad Zone Ltd', 'Mars/Olympus')$$,
  '22023',
  null,
  'an unknown timezone is refused with a product error, not a constraint name'
);

select is(
  (select count(*)::int from public.organisations),
  0,
  'no organisation survives any of those refusals'
);

-- ---------------------------------------------------------------------------
-- The happy path, checked row by row
-- ---------------------------------------------------------------------------

select lives_ok(
  $$select public.create_organisation('  Alpha Ltd  ', 'Europe/London')$$,
  'a verified user can create an organisation'
);

reset role;

select is(
  (select count(*)::int from public.organisations),
  1,
  'exactly one organisation exists'
);

select is(
  (select name from public.organisations),
  'Alpha Ltd',
  'the name is trimmed on the way in'
);

select is(
  (select timezone from public.organisations),
  'Europe/London',
  'the timezone is stored'
);

select is(
  (select created_by from public.organisations),
  '30000000-0000-0000-0000-000000000001'::uuid,
  'the creator is recorded'
);

select is(
  (select role from public.organisation_members),
  'owner',
  'the creator becomes owner in the same transaction'
);

select is(
  (select status from public.organisation_members),
  'active',
  'and is active immediately'
);

-- Without this the owner cannot vote in or receive nominations from their own
-- programme, which for a five-person team quietly removes a fifth of the roster.
select is(
  (select count(*)::int from public.participants),
  1,
  'the creator is placed on the roster'
);

select is(
  (
    select p.display_name from public.participants p
  ),
  'verified',
  'the roster name falls back to the profile name, never blank'
);

select is(
  (select count(*)::int from public.recognition_settings),
  1,
  'programme settings exist from the start, so no screen sees them missing'
);

select is(
  (select retention_months from public.recognition_settings),
  12,
  'retention defaults to the privacy-by-default 12 months of D-012'
);

select is(
  (select action from public.audit_events),
  'organisation_created',
  'creation is audited'
);

-- ---------------------------------------------------------------------------
-- A second organisation by the same user is allowed and stays separate.
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"30000000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok(
  $$select public.create_organisation('Second Ltd', 'Europe/Dublin')$$,
  'the same user may own more than one organisation'
);
reset role;

select is(
  (select count(distinct organisation_id)::int from public.participants),
  2,
  'each organisation gets its own roster entry rather than sharing one'
);

select * from finish();

rollback;
