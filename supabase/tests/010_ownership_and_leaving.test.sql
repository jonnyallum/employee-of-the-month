-- PRV-008: ownership transfer, leaving and organisation deletion.
--
-- These are the exits, and the reason they need testing is that each one can
-- strand somebody: an organisation with no owner, a member who still votes
-- after leaving, or a deleted organisation whose data is still readable.

begin;

create extension if not exists pgtap;

select plan(23);

delete from public.organisations;
delete from auth.users;

insert into auth.users (id, email, email_confirmed_at) values
  ('a0000000-0000-0000-0000-000000000001', 'owner@alpha.test', now()),
  ('a0000000-0000-0000-0000-000000000002', 'member@alpha.test', now()),
  ('a0000000-0000-0000-0000-000000000003', 'admin@alpha.test', now()),
  ('a0000000-0000-0000-0000-000000000009', 'outsider@beta.test', now());

insert into public.organisations (id, name, timezone) values
  ('aa000000-0000-0000-0000-00000000000a', 'Alpha Ltd', 'Europe/London'),
  ('ab000000-0000-0000-0000-00000000000b', 'Beta Ltd', 'Europe/London');

insert into public.organisation_members (organisation_id, user_id, role, status) values
  ('aa000000-0000-0000-0000-00000000000a', 'a0000000-0000-0000-0000-000000000001', 'owner', 'active'),
  ('aa000000-0000-0000-0000-00000000000a', 'a0000000-0000-0000-0000-000000000002', 'member', 'active'),
  ('aa000000-0000-0000-0000-00000000000a', 'a0000000-0000-0000-0000-000000000003', 'admin', 'active'),
  ('ab000000-0000-0000-0000-00000000000b', 'a0000000-0000-0000-0000-000000000009', 'owner', 'active');

insert into public.participants (id, organisation_id, user_id, display_name) values
  ('aa000000-0000-0000-0000-0000000000a1', 'aa000000-0000-0000-0000-00000000000a',
   'a0000000-0000-0000-0000-000000000001', 'The Owner'),
  ('aa000000-0000-0000-0000-0000000000a2', 'aa000000-0000-0000-0000-00000000000a',
   'a0000000-0000-0000-0000-000000000002', 'The Member'),
  ('aa000000-0000-0000-0000-0000000000a3', 'aa000000-0000-0000-0000-00000000000a',
   'a0000000-0000-0000-0000-000000000003', 'The Admin');

insert into public.recognition_settings (organisation_id) values
  ('aa000000-0000-0000-0000-00000000000a');

set local role authenticated;

-- ---------------------------------------------------------------------------
-- Ownership is the closed top of the hierarchy
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"a0000000-0000-0000-0000-000000000003","role":"authenticated"}';

-- The case worth having: an admin is powerful, and must still not be able to
-- make themselves or anybody else an owner.
select throws_ok(
  $$select public.transfer_ownership('aa000000-0000-0000-0000-00000000000a',
      'a0000000-0000-0000-0000-000000000003')$$,
  '42501',
  null,
  'an admin cannot promote anybody to owner, including themselves'
);

set local request.jwt.claims =
  '{"sub":"a0000000-0000-0000-0000-000000000009","role":"authenticated"}';
select throws_ok(
  $$select public.transfer_ownership('aa000000-0000-0000-0000-00000000000a',
      'a0000000-0000-0000-0000-000000000002')$$,
  '42501',
  null,
  'another tenant''s owner cannot grant ownership here'
);

set local request.jwt.claims =
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.transfer_ownership('aa000000-0000-0000-0000-00000000000a',
      'a0000000-0000-0000-0000-000000000009')$$,
  '22023',
  null,
  'somebody who is not a member cannot be made an owner'
);

-- ---------------------------------------------------------------------------
-- The sole owner is trapped until they transfer
-- ---------------------------------------------------------------------------

select throws_ok(
  $$select public.request_account_deletion()$$,
  '22023',
  null,
  'the sole owner cannot delete their account'
);

select throws_ok(
  $$select public.leave_organisation('aa000000-0000-0000-0000-00000000000a')$$,
  '22023',
  null,
  'and cannot leave either, for the same reason'
);

select lives_ok(
  $$select public.transfer_ownership('aa000000-0000-0000-0000-00000000000a',
      'a0000000-0000-0000-0000-000000000002')$$,
  'the owner can promote a member'
);

reset role;

select is(
  (select role from public.organisation_members
   where user_id = 'a0000000-0000-0000-0000-000000000002'),
  'owner',
  'the member is now an owner'
);

-- Granting ownership must not remove it. A mistyped transfer that demoted the
-- caller could leave an organisation with nobody who can administer it.
select is(
  (select role from public.organisation_members
   where user_id = 'a0000000-0000-0000-0000-000000000001'),
  'owner',
  'and the original owner still is one, so a transfer cannot strand anybody'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';

select lives_ok(
  $$select public.leave_organisation('aa000000-0000-0000-0000-00000000000a')$$,
  'now a second owner exists, the first can leave'
);

reset role;

select is(
  (select status from public.organisation_members
   where user_id = 'a0000000-0000-0000-0000-000000000001'),
  'left',
  'their membership is marked left'
);

-- Unlinking is what actually stops them voting, rather than waiting for a token
-- to expire.
select is(
  (select user_id from public.participants
   where id = 'aa000000-0000-0000-0000-0000000000a1'),
  null,
  'their roster entry is unlinked immediately'
);

select is(
  (select count(*)::int from public.participants
   where id = 'aa000000-0000-0000-0000-0000000000a1'),
  1,
  'but the roster entry survives, because past results point at it'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';

select is(
  (select count(*)::int from public.organisations),
  0,
  'and they can no longer see the organisation at all'
);

-- ---------------------------------------------------------------------------
-- Deleting an organisation
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"a0000000-0000-0000-0000-000000000003","role":"authenticated"}';

select throws_ok(
  $$select public.delete_organisation('aa000000-0000-0000-0000-00000000000a', 'Alpha Ltd')$$,
  '42501',
  null,
  'an admin cannot delete an organisation'
);

set local request.jwt.claims =
  '{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated"}';

-- The confirmation is checked in the database, so a modified client cannot
-- click past it.
select throws_ok(
  $$select public.delete_organisation('aa000000-0000-0000-0000-00000000000a', 'alpha')$$,
  '22023',
  null,
  'a near-miss on the name is refused'
);

select throws_ok(
  $$select public.delete_organisation('aa000000-0000-0000-0000-00000000000a', '')$$,
  '22023',
  null,
  'an empty confirmation is refused'
);

select lives_ok(
  $$select public.delete_organisation('aa000000-0000-0000-0000-00000000000a', '  alpha ltd  ')$$,
  'the owner can delete it by typing the name, case and spacing forgiven'
);

-- ---------------------------------------------------------------------------
-- A deleted organisation must disappear everywhere, not just from one screen
-- ---------------------------------------------------------------------------
--
-- The policies on the other tables were written before soft deletion existed
-- and checked only membership. Without the liveness check they would each keep
-- returning rows.

select is(
  (select count(*)::int from public.organisations),
  0,
  'the organisation is gone from the list'
);

select is(
  (select count(*)::int from public.participants),
  0,
  'the roster is unreachable'
);

select is(
  (select count(*)::int from public.recognition_cycles),
  0,
  'cycles are unreachable'
);

select is(
  (select count(*)::int from public.organisation_members),
  0,
  'membership is unreachable'
);

select is(
  (select count(*)::int from public.recognition_settings),
  0,
  'settings are unreachable'
);

reset role;

-- Soft, not hard. A beta customer will delete the wrong thing, and a cascade
-- cannot be undone.
select is(
  (select count(*)::int from public.organisations
   where id = 'aa000000-0000-0000-0000-00000000000a' and deleted_at is not null),
  1,
  'the data still exists behind the scenes for the recovery window'
);

select * from finish();

rollback;
