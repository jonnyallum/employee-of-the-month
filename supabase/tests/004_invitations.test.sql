-- DB-008 tests: invitation create, reissue, revoke and accept.
--
-- An invitation is an identity, so these tests are mostly about refusal. The
-- ones that matter are the wrong-email binding, the replay, and the reissue:
-- each is a route to an account that should not exist.

begin;

create extension if not exists pgtap;

select plan(30);


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
  ('40000000-0000-0000-0000-000000000001', 'owner@alpha.test', now()),
  ('40000000-0000-0000-0000-000000000002', 'invitee@alpha.test', now()),
  ('40000000-0000-0000-0000-000000000003', 'stranger@alpha.test', now()),
  ('40000000-0000-0000-0000-000000000004', 'unverified@alpha.test', null),
  ('40000000-0000-0000-0000-000000000005', 'outsider@beta.test', now()),
  ('40000000-0000-0000-0000-000000000006', 'another@alpha.test', now());

-- Two organisations, so cross-tenant attempts are testable.
insert into public.organisations (id, name, timezone) values
  ('4a000000-0000-0000-0000-00000000000a', 'Alpha Ltd', 'Europe/London'),
  ('4b000000-0000-0000-0000-00000000000b', 'Beta Ltd', 'Europe/London');

insert into public.organisation_members (organisation_id, user_id, role, status) values
  ('4a000000-0000-0000-0000-00000000000a', '40000000-0000-0000-0000-000000000001', 'owner', 'active'),
  ('4b000000-0000-0000-0000-00000000000b', '40000000-0000-0000-0000-000000000005', 'owner', 'active');

insert into public.participants (id, organisation_id, user_id, display_name, active) values
  ('4a000000-0000-0000-0000-0000000000a1', '4a000000-0000-0000-0000-00000000000a',
   '40000000-0000-0000-0000-000000000001', 'The Owner', true),
  ('4a000000-0000-0000-0000-0000000000a2', '4a000000-0000-0000-0000-00000000000a',
   null, 'Invitee', true),
  ('4a000000-0000-0000-0000-0000000000a3', '4a000000-0000-0000-0000-00000000000a',
   null, 'Another Invitee', true),
  ('4a000000-0000-0000-0000-0000000000a4', '4a000000-0000-0000-0000-00000000000a',
   null, 'Inactive Person', false);

-- ---------------------------------------------------------------------------
-- Who may create one
-- ---------------------------------------------------------------------------

select ok(
  not has_function_privilege('anon', 'public.create_invitation(uuid, text, interval)', 'execute'),
  'anon cannot create invitations'
);

select ok(
  not has_function_privilege('anon', 'public.accept_invitation(text)', 'execute'),
  'anon cannot accept invitations'
);

set local role authenticated;

set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select public.create_invitation('4a000000-0000-0000-0000-0000000000a2', 'x@alpha.test')$$,
  '42501',
  null,
  'a non-member cannot invite'
);

-- The outsider is a full owner in their own tenant, which is exactly the case a
-- naive role check would let through.
set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000005","role":"authenticated"}';
select throws_ok(
  $$select public.create_invitation('4a000000-0000-0000-0000-0000000000a2', 'x@alpha.test')$$,
  '42501',
  null,
  'another tenant''s owner cannot invite into this organisation'
);

set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.create_invitation('4a000000-0000-0000-0000-0000000000a1', 'x@alpha.test')$$,
  '23505',
  null,
  'a participant who already has an account cannot be invited again'
);

select throws_ok(
  $$select public.create_invitation('4a000000-0000-0000-0000-0000000000a4', 'x@alpha.test')$$,
  '22023',
  null,
  'an inactive participant cannot be invited'
);

select throws_ok(
  $$select public.create_invitation('4a000000-0000-0000-0000-0000000000a2', 'not-an-email')$$,
  '22023',
  null,
  'a malformed email is refused'
);

select throws_ok(
  $$select public.create_invitation(
      '4a000000-0000-0000-0000-0000000000a2', 'x@alpha.test', interval '-1 day')$$,
  '22023',
  null,
  'an expiry in the past is refused'
);

-- ---------------------------------------------------------------------------
-- What a created invitation looks like
-- ---------------------------------------------------------------------------

create temporary table issued as
select * from public.create_invitation(
  '4a000000-0000-0000-0000-0000000000a2', '  Invitee@Alpha.TEST  ');

select is(
  (select length(token) from issued),
  64,
  'the token is 32 bytes of hex, so guessing is not a threat'
);

reset role;

select is(
  (select email_normalised from public.organisation_invitations),
  'invitee@alpha.test',
  'the invited email is normalised, so case cannot create a mismatch later'
);

-- The whole point of hashing. If this ever fails, a database read hands over
-- working invitations for every pending employee.
select is(
  (select count(*)::int from public.organisation_invitations i, issued
   where i.token_hash = issued.token),
  0,
  'the stored value is not the token itself'
);

select is(
  (select i.token_hash from public.organisation_invitations i),
  (select encode(extensions.digest(token, 'sha256'), 'hex') from issued),
  'the stored value is the SHA-256 of the token'
);

select ok(
  (select expires_at from issued) > now() + interval '6 days',
  'the default expiry is seven days'
);

-- ---------------------------------------------------------------------------
-- Accepting: every refusal before the success
-- ---------------------------------------------------------------------------

set local role authenticated;

set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.accept_invitation('deadbeef')$$,
  '22023',
  null,
  'a token that does not exist is refused, and looks the same as a wrong one'
);

-- The binding that makes an intercepted token worthless.
set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select public.accept_invitation((select token from issued))$$,
  '42501',
  null,
  'a valid token is refused for the wrong email address'
);

set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000004","role":"authenticated"}';
select throws_ok(
  $$select public.accept_invitation((select token from issued))$$,
  '42501',
  null,
  'an unverified account cannot accept, even with the right token'
);

-- ---------------------------------------------------------------------------
-- The happy path
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000002","role":"authenticated"}';
select lives_ok(
  $$select public.accept_invitation((select token from issued))$$,
  'the intended recipient can accept'
);

reset role;

select is(
  (select user_id from public.participants
   where id = '4a000000-0000-0000-0000-0000000000a2'),
  '40000000-0000-0000-0000-000000000002'::uuid,
  'the participant is linked to the accepting account'
);

select is(
  (select role from public.organisation_members
   where user_id = '40000000-0000-0000-0000-000000000002'),
  'member',
  'membership is created as a plain member, never an admin'
);

select ok(
  (select accepted_at is not null from public.organisation_invitations),
  'the token is consumed'
);

-- ---------------------------------------------------------------------------
-- Replay
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.accept_invitation((select token from issued))$$,
  '22023',
  null,
  'replaying a used token is refused'
);
reset role;

select is(
  (select count(*)::int from public.organisation_members
   where user_id = '40000000-0000-0000-0000-000000000002'),
  1,
  'and no second membership was created'
);

-- ---------------------------------------------------------------------------
-- Reissue and revoke
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000001","role":"authenticated"}';

create temporary table first_issue as
select * from public.create_invitation(
  '4a000000-0000-0000-0000-0000000000a3', 'another@alpha.test');

create temporary table second_issue as
select * from public.create_invitation(
  '4a000000-0000-0000-0000-0000000000a3', 'another@alpha.test');

reset role;

select isnt(
  (select token from first_issue),
  (select token from second_issue),
  'reissuing produces a different token'
);

select ok(
  (select revoked_at is not null from public.organisation_invitations
   where id = (select invitation_id from first_issue)),
  'reissuing revokes the previous invitation, so an intercepted email dies'
);

select is(
  (select count(*)::int from public.organisation_invitations
   where participant_id = '4a000000-0000-0000-0000-0000000000a3'
     and accepted_at is null and revoked_at is null),
  1,
  'exactly one live invitation exists per participant'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000005","role":"authenticated"}';
select throws_ok(
  $$select public.revoke_invitation((select invitation_id from second_issue))$$,
  '42501',
  null,
  'another tenant''s owner cannot revoke an invitation, and cannot tell it exists'
);

set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok(
  $$select public.revoke_invitation((select invitation_id from second_issue))$$,
  'an admin can revoke'
);

-- The intended recipient of a revoked invitation is told it was withdrawn,
-- which is accurate and useful to them.
set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000006","role":"authenticated"}';
select throws_ok(
  $$select public.accept_invitation((select token from second_issue))$$,
  '22023',
  null,
  'the intended recipient of a revoked token is refused'
);

-- Anybody else is told only that the token is not theirs. They learn nothing
-- about whether it was withdrawn, used or still live, which would otherwise
-- disclose another person''s account lifecycle to whoever intercepted it.
set local request.jwt.claims =
  '{"sub":"40000000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select public.accept_invitation((select token from second_issue))$$,
  '42501',
  null,
  'a non-recipient learns nothing about a revoked invitation''s state'
);

reset role;

select is(
  (select count(*)::int from public.audit_events where action = 'invitation_accepted'),
  1,
  'acceptance is audited exactly once'
);

select * from finish();

rollback;
