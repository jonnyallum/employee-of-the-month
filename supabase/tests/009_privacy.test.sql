-- PRV-004, PRV-005, PRV-006.
--
-- The export test that matters is not that a subject gets their data. It is
-- that the export cannot be used to learn who nominated them, which is the one
-- way a lawful right could be turned into the disclosure this product exists to
-- prevent.

begin;

create extension if not exists pgtap;

select plan(33);

delete from public.organisations;
delete from auth.users;

insert into auth.users (id, email, email_confirmed_at) values
  ('90000000-0000-0000-0000-000000000001', 'owner@alpha.test', now()),
  ('90000000-0000-0000-0000-000000000002', 'subject@alpha.test', now()),
  ('90000000-0000-0000-0000-000000000003', 'author@alpha.test', now()),
  ('90000000-0000-0000-0000-000000000004', 'coowner@alpha.test', now());

insert into public.organisations (id, name, timezone) values
  ('9a000000-0000-0000-0000-00000000000a', 'Alpha Ltd', 'Europe/London');

insert into public.organisation_members (organisation_id, user_id, role, status) values
  ('9a000000-0000-0000-0000-00000000000a', '90000000-0000-0000-0000-000000000001', 'owner', 'active'),
  ('9a000000-0000-0000-0000-00000000000a', '90000000-0000-0000-0000-000000000002', 'member', 'active'),
  ('9a000000-0000-0000-0000-00000000000a', '90000000-0000-0000-0000-000000000003', 'member', 'active');

insert into public.participants (id, organisation_id, user_id, display_name) values
  ('9a000000-0000-0000-0000-0000000000a1', '9a000000-0000-0000-0000-00000000000a',
   '90000000-0000-0000-0000-000000000001', 'The Owner'),
  ('9a000000-0000-0000-0000-0000000000a2', '9a000000-0000-0000-0000-00000000000a',
   '90000000-0000-0000-0000-000000000002', 'The Subject'),
  ('9a000000-0000-0000-0000-0000000000a3', '9a000000-0000-0000-0000-00000000000a',
   '90000000-0000-0000-0000-000000000003', 'The Author');

insert into public.recognition_settings (organisation_id, retention_months) values
  ('9a000000-0000-0000-0000-00000000000a', 12);

-- A revealed cycle old enough to purge, and one revealed yesterday.
insert into public.recognition_cycles
  (id, organisation_id, period_month, status, version,
   winner_participant_id, winner_name, winner_nominations, revealed_at)
values
  ('9a000000-0000-0000-0000-0000000000c1', '9a000000-0000-0000-0000-00000000000a',
   '2024-01-01', 'revealed', 4, '9a000000-0000-0000-0000-0000000000a2',
   'The Subject', 1, now() - interval '20 months'),
  ('9a000000-0000-0000-0000-0000000000c2', '9a000000-0000-0000-0000-00000000000a',
   '2026-05-01', 'revealed', 4, '9a000000-0000-0000-0000-0000000000a2',
   'The Subject', 1, now() - interval '1 day');

-- These cycles are inserted directly rather than through reveal_winner, so they
-- carry the snapshot that reveal would have written (D-027). Without it the
-- purge below would be testing against a cycle whose standings were already
-- absent, and would pass whether or not the snapshot works.
update public.recognition_cycles
set tally_snapshot = jsonb_build_array(
      jsonb_build_object(
        'participant_id', '9a000000-0000-0000-0000-0000000000a2'::uuid,
        'display_name', 'The Subject',
        'nominations', 1))
where id in ('9a000000-0000-0000-0000-0000000000c1',
             '9a000000-0000-0000-0000-0000000000c2');

-- And an open one, which must never be purged.
insert into public.recognition_cycles
  (id, organisation_id, period_month, status, version)
values
  ('9a000000-0000-0000-0000-0000000000c3', '9a000000-0000-0000-0000-00000000000a',
   '2026-07-01', 'open', 2);

insert into public.recognition_nominations
  (organisation_id, cycle_id, nominator_user_id, nominator_participant_id,
   nominee_participant_id, reason)
values
  -- Old, purgeable. Written by the author about the subject.
  ('9a000000-0000-0000-0000-00000000000a', '9a000000-0000-0000-0000-0000000000c1',
   '90000000-0000-0000-0000-000000000003', '9a000000-0000-0000-0000-0000000000a3',
   '9a000000-0000-0000-0000-0000000000a2', 'Old reason about the subject.'),
  -- Recent, must survive.
  ('9a000000-0000-0000-0000-00000000000a', '9a000000-0000-0000-0000-0000000000c2',
   '90000000-0000-0000-0000-000000000003', '9a000000-0000-0000-0000-0000000000a3',
   '9a000000-0000-0000-0000-0000000000a2', 'Recent reason about the subject.'),
  -- Open cycle, must survive.
  ('9a000000-0000-0000-0000-00000000000a', '9a000000-0000-0000-0000-0000000000c3',
   '90000000-0000-0000-0000-000000000003', '9a000000-0000-0000-0000-0000000000a3',
   '9a000000-0000-0000-0000-0000000000a2', 'Live reason about the subject.'),
  -- Written BY the subject, so it belongs in their export with the nominee.
  ('9a000000-0000-0000-0000-00000000000a', '9a000000-0000-0000-0000-0000000000c3',
   '90000000-0000-0000-0000-000000000002', '9a000000-0000-0000-0000-0000000000a2',
   '9a000000-0000-0000-0000-0000000000a1', 'The subject wrote this about the owner.');

-- ---------------------------------------------------------------------------
-- PRV-005: the export, and what it must never contain
-- ---------------------------------------------------------------------------

select ok(
  not has_function_privilege('anon', 'public.export_my_data()', 'execute'),
  'anon cannot export anything'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"90000000-0000-0000-0000-000000000002","role":"authenticated"}';

-- The assertion this whole file exists for. Nowhere in the export may the
-- author of a reason about the subject appear, in any form.
select ok(
  public.export_my_data()::text not like '%author@alpha.test%',
  'the export never contains the email of somebody who nominated the subject'
);

select ok(
  public.export_my_data()::text not like '%The Author%',
  'nor their name'
);

select ok(
  public.export_my_data()::text not like '%90000000-0000-0000-0000-000000000003%',
  'nor their user id'
);

-- Three reasons exist about the subject: two on revealed cycles and one on the
-- open cycle. Only the open one is withheld, so two come back.
select is(
  jsonb_array_length(public.export_my_data() -> 'reasons_written_about_me'),
  2,
  'reasons about the subject are returned from revealed cycles'
);

-- The live one is excluded. Returning it would turn an export into a feed of
-- nominations arriving during an open cycle.
select ok(
  public.export_my_data()::text not like '%Live reason about the subject%',
  'a reason from an open cycle is withheld until voting closes'
);

select ok(
  public.export_my_data()::text like '%Recent reason about the subject%',
  'a reason from a revealed cycle is included'
);

-- The asymmetry: what the subject wrote comes back WITH the nominee named,
-- because they chose that person and already know.
select is(
  public.export_my_data() -> 'nominations_i_made' -> 0 ->> 'nominee',
  'The Owner',
  'what the subject wrote is returned with the nominee named'
);

select is(
  public.export_my_data() -> 'account' ->> 'email',
  'subject@alpha.test',
  'the export contains the subject''s own account'
);

select is(
  jsonb_array_length(public.export_my_data() -> 'awards_i_won'),
  2,
  'awards the subject won are included'
);

-- ---------------------------------------------------------------------------
-- PRV-006: deletion requests
-- ---------------------------------------------------------------------------

select lives_ok(
  $$select public.request_account_deletion()$$,
  'a member can request deletion'
);

-- Counted with the role reset: privacy_requests has no client grant, and a
-- test that could read it directly would mean that had stopped being true.
reset role;
select is(
  (select count(*)::int from public.privacy_requests
   where user_id = '90000000-0000-0000-0000-000000000002'),
  1,
  'the request is recorded'
);
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"90000000-0000-0000-0000-000000000002","role":"authenticated"}';

-- Pressing a delete button twice means one deletion, not two.
select lives_ok(
  $$select public.request_account_deletion()$$,
  'asking twice is allowed'
);

reset role;
select is(
  (select count(*)::int from public.privacy_requests
   where user_id = '90000000-0000-0000-0000-000000000002'),
  1,
  'and does not queue a second request'
);
set local role authenticated;

-- The sole owner would strand everybody else in an organisation nobody can
-- administer.
set local request.jwt.claims =
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.request_account_deletion()$$,
  '22023',
  null,
  'the only owner cannot delete their account'
);

reset role;

insert into public.organisation_members (organisation_id, user_id, role, status)
values ('9a000000-0000-0000-0000-00000000000a',
        '90000000-0000-0000-0000-000000000004', 'owner', 'active');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}';

select lives_ok(
  $$select public.request_account_deletion()$$,
  'once a second owner exists, the first may leave'
);

select is(
  (select count(*)::int from public.get_my_privacy_requests()),
  1,
  'a caller sees their own requests'
);

set local request.jwt.claims =
  '{"sub":"90000000-0000-0000-0000-000000000003","role":"authenticated"}';

select is(
  (select count(*)::int from public.get_my_privacy_requests()),
  0,
  'and nobody else''s'
);

reset role;

-- ---------------------------------------------------------------------------
-- PRV-004: the purge
-- ---------------------------------------------------------------------------

select ok(
  not has_function_privilege('authenticated', 'public.purge_expired_nominations(boolean)', 'execute'),
  'no client can run the purge, not even an owner'
);

-- A dry run must change nothing. A purge that deletes by default is one
-- keystroke from an accident.
select is(
  (select count(*)::int from public.purge_expired_nominations(true)),
  1,
  'the dry run reports exactly the one cycle past its retention period'
);

select is(
  (select count(*)::int from public.recognition_nominations where reason is not null),
  4,
  'and changed nothing'
);

select lives_ok(
  $$select * from public.purge_expired_nominations(false)$$,
  'the live purge runs'
);

select is(
  (select reason from public.recognition_nominations
   where cycle_id = '9a000000-0000-0000-0000-0000000000c1'),
  null,
  'the expired reason is gone'
);

select is(
  (select count(*)::int from public.recognition_nominations where reason is not null),
  3,
  'and only that one, so recent and live cycles are untouched'
);

-- The reason this is a snapshot with no foreign key, decided back in DB-003.
select is(
  (select winner_name from public.recognition_cycles
   where id = '9a000000-0000-0000-0000-0000000000c1'),
  'The Subject',
  'the winner snapshot survives the purge of the ballots that produced it'
);

select is(
  (select count(*)::int from public.recognition_nominations
   where cycle_id = '9a000000-0000-0000-0000-0000000000c1'),
  1,
  'the ballot row remains, so turnout and the one-vote guard still hold'
);

-- ---------------------------------------------------------------------------
-- PRV-004a / D-027: the purge severs the link, not just the words
-- ---------------------------------------------------------------------------
--
-- What used to survive a purge was a permanent map of who chose whom with the
-- words removed and the meaning intact. That is the artefact D-024 says must
-- not exist, so the link goes too.

select is(
  (select nominee_participant_id from public.recognition_nominations
   where cycle_id = '9a000000-0000-0000-0000-0000000000c1'),
  null,
  'the purge severs the nominator-to-nominee link, not only the reason (D-027)'
);

select isnt(
  (select purged_at from public.recognition_nominations
   where cycle_id = '9a000000-0000-0000-0000-0000000000c1'),
  null,
  'and stamps when it happened'
);

-- The one-vote guard is unique (organisation_id, cycle_id, nominator_user_id).
-- If the purge cleared that too, a purged cycle could be voted in twice.
select is(
  (select nominator_user_id from public.recognition_nominations
   where cycle_id = '9a000000-0000-0000-0000-0000000000c1'),
  '90000000-0000-0000-0000-000000000003'::uuid,
  'the nominator survives, because the one-vote guard depends on it'
);

-- The reason this was hard: standings are computed from the links, so severing
-- them would rewrite the history of every past month to zero unless reveal had
-- already recorded the counts.
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}';

select is(
  (select nominations from public.get_closed_standings(
     '9a000000-0000-0000-0000-0000000000c1')
   where display_name = 'The Subject'),
  1,
  'and the standings survive it, because reveal snapshotted them (D-027)'
);

reset role;

-- A row cannot be half purged. Either the link is there and the stamp is not,
-- or the reverse.
select throws_ok(
  $$update public.recognition_nominations
    set purged_at = now()
    where cycle_id = '9a000000-0000-0000-0000-0000000000c2'$$,
  '23514',
  null,
  'a purge stamp without severing the link is rejected'
);

select throws_ok(
  $$update public.recognition_nominations
    set nominee_participant_id = null
    where cycle_id = '9a000000-0000-0000-0000-0000000000c2'$$,
  '23514',
  null,
  'and severing the link without stamping it is rejected'
);

-- Running it again must find nothing, or a scheduled job would rewrite history
-- and re-audit the same purge every night.
select is(
  (select count(*)::int from public.purge_expired_nominations(false)),
  0,
  'running the purge again finds nothing, so the job is idempotent'
);

select * from finish();

rollback;
