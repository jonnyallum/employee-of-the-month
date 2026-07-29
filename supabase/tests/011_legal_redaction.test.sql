-- D-028, D-030 and D-035 tests: the three controls the legal determinations
-- required, and the properties that make them worth having.
--
-- The assertions that matter most here are the negative ones. Redaction is only
-- a remedy if the text is actually gone from storage, and it is only a remedy
-- for special category content if it still works after a cycle is revealed —
-- which is precisely when the old function refused. Both are pinned below so a
-- future change to moderate_nomination fails by name rather than by nobody
-- noticing.

begin;

create extension if not exists pgtap;

select plan(31);

-- Same approach as 006: this file asserts absolute state and builds its own
-- fixtures, so it clears the seed inside the transaction and the rollback puts
-- it back for the next file.
delete from public.organisations;
delete from auth.users;

insert into auth.users (id, email, email_confirmed_at) values
  ('70000000-0000-0000-0000-000000000001', 'olive@omega.test', now()),
  ('70000000-0000-0000-0000-000000000002', 'pat@omega.test', now()),
  ('70000000-0000-0000-0000-000000000003', 'quinn@omega.test', now()),
  ('70000000-0000-0000-0000-000000000004', 'raj@omega.test', now()),
  ('70000000-0000-0000-0000-000000000009', 'stranger@sigma.test', now());

insert into public.organisations (id, name, timezone) values
  ('7a000000-0000-0000-0000-00000000000a', 'Omega Ltd', 'Europe/London'),
  ('7b000000-0000-0000-0000-00000000000b', 'Sigma Ltd', 'Europe/London');

insert into public.organisation_members (organisation_id, user_id, role, status) values
  ('7a000000-0000-0000-0000-00000000000a', '70000000-0000-0000-0000-000000000001', 'owner', 'active'),
  ('7a000000-0000-0000-0000-00000000000a', '70000000-0000-0000-0000-000000000002', 'member', 'active'),
  ('7a000000-0000-0000-0000-00000000000a', '70000000-0000-0000-0000-000000000003', 'member', 'active'),
  ('7a000000-0000-0000-0000-00000000000a', '70000000-0000-0000-0000-000000000004', 'member', 'active'),
  ('7b000000-0000-0000-0000-00000000000b', '70000000-0000-0000-0000-000000000009', 'owner', 'active');

insert into public.participants
  (id, organisation_id, user_id, display_name, active, can_vote, can_receive) values
  ('7a000000-0000-0000-0000-0000000000a1', '7a000000-0000-0000-0000-00000000000a',
   '70000000-0000-0000-0000-000000000001', 'Olive Okonkwo', true, true, true),
  ('7a000000-0000-0000-0000-0000000000a2', '7a000000-0000-0000-0000-00000000000a',
   '70000000-0000-0000-0000-000000000002', 'Pat Price', true, true, true),
  ('7a000000-0000-0000-0000-0000000000a3', '7a000000-0000-0000-0000-00000000000a',
   '70000000-0000-0000-0000-000000000003', 'Quinn', true, true, true),
  ('7a000000-0000-0000-0000-0000000000a4', '7a000000-0000-0000-0000-00000000000a',
   '70000000-0000-0000-0000-000000000004', 'Raj Patel', true, true, true);

-- An open cycle for moderation before reveal, and a revealed one for the cases
-- that only arise after a result is published.
insert into public.recognition_cycles
  (id, organisation_id, period_month, status, version) values
  ('7a000000-0000-0000-0000-0000000000c1', '7a000000-0000-0000-0000-00000000000a',
   '2026-07-01', 'open', 1);

insert into public.recognition_cycles
  (id, organisation_id, period_month, status, version,
   winner_participant_id, winner_name, winner_nominations, revealed_at) values
  ('7a000000-0000-0000-0000-0000000000c2', '7a000000-0000-0000-0000-00000000000a',
   '2026-06-01', 'revealed', 2,
   '7a000000-0000-0000-0000-0000000000a2', 'Pat Price', 2, now() - interval '20 days');

insert into public.recognition_nominations
  (id, organisation_id, cycle_id, nominator_user_id, nominator_participant_id,
   nominee_participant_id, reason) values
  -- The case the whole of D-030 exists for: health information about a third
  -- party, volunteered by a colleague, in an open cycle.
  ('7a000000-0000-0000-0000-0000000000e1', '7a000000-0000-0000-0000-00000000000a',
   '7a000000-0000-0000-0000-0000000000c1', '70000000-0000-0000-0000-000000000001',
   '7a000000-0000-0000-0000-0000000000a1', '7a000000-0000-0000-0000-0000000000a2',
   'She covered my shifts while I was having treatment.'),
  ('7a000000-0000-0000-0000-0000000000e2', '7a000000-0000-0000-0000-00000000000a',
   '7a000000-0000-0000-0000-0000000000c1', '70000000-0000-0000-0000-000000000003',
   '7a000000-0000-0000-0000-0000000000a3', '7a000000-0000-0000-0000-0000000000a2',
   'Fixed the rota nobody else would touch.'),
  -- The same problem, discovered after the result was announced. Under the old
  -- function this text could never be removed.
  ('7a000000-0000-0000-0000-0000000000e3', '7a000000-0000-0000-0000-00000000000a',
   '7a000000-0000-0000-0000-0000000000c2', '70000000-0000-0000-0000-000000000004',
   '7a000000-0000-0000-0000-0000000000a4', '7a000000-0000-0000-0000-0000000000a2',
   'Carried the team through my disciplinary.');

-- ---------------------------------------------------------------------------
-- D-030: redaction removes the text, not the ballot
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000001","role":"authenticated"}';

select lives_ok(
  $$select public.moderate_nomination(
      '7a000000-0000-0000-0000-0000000000e1', 'redact',
      'Contained health information about a colleague.')$$,
  'an admin can redact a nomination with a recorded reason'
);

reset role;

select is(
  (select reason from public.recognition_nominations
   where id = '7a000000-0000-0000-0000-0000000000e1'),
  null,
  'the text is gone from storage, not merely hidden from a screen'
);

select is(
  (select status from public.recognition_nominations
   where id = '7a000000-0000-0000-0000-0000000000e1'),
  'active',
  'the ballot still counts: the person did vote, whatever words they used'
);

select is(
  (select count(*)::int from public.recognition_nominations
   where cycle_id = '7a000000-0000-0000-0000-0000000000c1'),
  2,
  'and no row was deleted, so the tally is unchanged'
);

select is(
  (select moderation_reason from public.recognition_nominations
   where id = '7a000000-0000-0000-0000-0000000000e1'),
  'Contained health information about a colleague.',
  'the moderator supplies their own reason'
);

select ok(
  (select moderation_reason not like '%treatment%'
   from public.recognition_nominations
   where id = '7a000000-0000-0000-0000-0000000000e1'),
  'and the removed text is not written back into the audit field'
);

select is(
  (select count(*)::int from public.recognition_ballot_events
   where cycle_id = '7a000000-0000-0000-0000-0000000000c1'
     and event_type = 'redacted'),
  1,
  'a redaction is recorded as a ballot event'
);

select ok(
  (select count(*) = 0 from public.audit_events
   where action = 'nomination_moderated'
     and metadata::text like '%treatment%'),
  'and the audit trail never carries the content that was removed'
);

-- ---------------------------------------------------------------------------
-- The reason redaction exists: it has to survive the reveal
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.moderate_nomination(
      '7a000000-0000-0000-0000-0000000000e3', 'hide', 'Too late.')$$,
  '22023',
  null,
  'hiding is still refused after reveal, because it would change what counted'
);

select lives_ok(
  $$select public.moderate_nomination(
      '7a000000-0000-0000-0000-0000000000e3', 'redact',
      'Disciplinary information about a colleague.')$$,
  'but redaction is permitted after reveal: unlawful content has no expiry date'
);

reset role;

select is(
  (select reason from public.recognition_nominations
   where id = '7a000000-0000-0000-0000-0000000000e3'),
  null,
  'the post-reveal text is gone too'
);

select is(
  (select winner_nominations from public.recognition_cycles
   where id = '7a000000-0000-0000-0000-0000000000c2'),
  2,
  'and the announced result is untouched, which is why this is allowed at all'
);

-- ---------------------------------------------------------------------------
-- D-030 refusals
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.moderate_nomination(
      '7a000000-0000-0000-0000-0000000000e2', 'redact', '   ')$$,
  '22023',
  null,
  'redacting without a reason is refused, so nothing vanishes unexplained'
);

select throws_ok(
  $$select public.moderate_nomination(
      '7a000000-0000-0000-0000-0000000000e1', 'redact', 'Again.')$$,
  '22023',
  null,
  'redacting twice is refused rather than silently doing nothing'
);

select throws_ok(
  $$select public.moderate_nomination(
      '7a000000-0000-0000-0000-0000000000e2', 'delete', 'Whatever.')$$,
  '22023',
  null,
  'an unknown action is refused'
);

-- A plain member has no moderation powers, and the refusal must not confirm
-- that the nomination exists.
set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000003","role":"authenticated"}';

select throws_ok(
  $$select public.moderate_nomination(
      '7a000000-0000-0000-0000-0000000000e2', 'redact', 'I would rather not.')$$,
  '42501',
  null,
  'a member cannot redact'
);

set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000009","role":"authenticated"}';

select throws_ok(
  $$select public.moderate_nomination(
      '7a000000-0000-0000-0000-0000000000e2', 'redact', 'Curious.')$$,
  '42501',
  null,
  'and neither can an owner of another organisation'
);

-- ---------------------------------------------------------------------------
-- D-028: the customer can act on an erasure request
-- ---------------------------------------------------------------------------

set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000001","role":"authenticated"}';

select lives_ok(
  $$select public.redact_winner_snapshot(
      '7a000000-0000-0000-0000-0000000000c2', 'initials',
      'Erasure request from the former employee.')$$,
  'an admin can redact an announced winner to initials'
);

reset role;

select is(
  (select winner_name from public.recognition_cycles
   where id = '7a000000-0000-0000-0000-0000000000c2'),
  'P.P.',
  'the name reduces to initials'
);

select is(
  (select winner_participant_id from public.recognition_cycles
   where id = '7a000000-0000-0000-0000-0000000000c2'),
  null,
  'and the roster link goes, or the name could be recovered by a join'
);

select is(
  (select winner_nominations from public.recognition_cycles
   where id = '7a000000-0000-0000-0000-0000000000c2'),
  2,
  'the count survives every mode: it is the result, not the person'
);

select is(
  (select status from public.recognition_cycles
   where id = '7a000000-0000-0000-0000-0000000000c2'),
  'revealed',
  'and the cycle is still a revealed cycle with a winner'
);

select is(
  (select count(*)::int from public.audit_events
   where action = 'winner_redacted'
     and entity_id = '7a000000-0000-0000-0000-0000000000c2'),
  1,
  'the redaction is recorded, so it cannot be mistaken for tampering'
);

-- A single-word display name cannot produce meaningful initials, and 'Q.' is
-- not a redaction. The function falls back rather than pretending.
insert into public.recognition_cycles
  (id, organisation_id, period_month, status, version,
   winner_participant_id, winner_name, winner_nominations, revealed_at) values
  ('7a000000-0000-0000-0000-0000000000c3', '7a000000-0000-0000-0000-00000000000a',
   '2026-05-01', 'revealed', 2,
   '7a000000-0000-0000-0000-0000000000a3', 'Quinn', 1, now() - interval '50 days');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000001","role":"authenticated"}';

select lives_ok(
  $$select public.redact_winner_snapshot(
      '7a000000-0000-0000-0000-0000000000c3', 'initials', 'Erasure request.')$$,
  'a one-word name can still be redacted'
);

reset role;

select is(
  (select winner_name from public.recognition_cycles
   where id = '7a000000-0000-0000-0000-0000000000c3'),
  'A former colleague',
  'and falls back rather than storing a useless single initial'
);

-- ---------------------------------------------------------------------------
-- D-028 refusals
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.redact_winner_snapshot(
      '7a000000-0000-0000-0000-0000000000c1', 'remove', 'No winner yet.')$$,
  '22023',
  null,
  'a cycle with no announced winner has nothing to redact'
);

select throws_ok(
  $$select public.redact_winner_snapshot(
      '7a000000-0000-0000-0000-0000000000c3', 'initials', '  ')$$,
  '22023',
  null,
  'redacting a winner without a reason is refused'
);

set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000003","role":"authenticated"}';

select throws_ok(
  $$select public.redact_winner_snapshot(
      '7a000000-0000-0000-0000-0000000000c3', 'remove', 'Trying it on.')$$,
  '42501',
  null,
  'a member cannot rewrite an announced result'
);

-- ---------------------------------------------------------------------------
-- D-035: the voter is told, without being handed the roster
-- ---------------------------------------------------------------------------

select is(
  public.get_cycle_confidentiality('7a000000-0000-0000-0000-0000000000c1'),
  'weak',
  'four eligible voters is a weak confidentiality warning for the voter'
);

select ok(
  (select pg_get_function_result(p.oid) = 'text'
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_cycle_confidentiality'),
  'and it returns a level only, never the headcount it was derived from'
);

set local request.jwt.claims =
  '{"sub":"70000000-0000-0000-0000-000000000009","role":"authenticated"}';

select throws_ok(
  $$select public.get_cycle_confidentiality('7a000000-0000-0000-0000-0000000000c1')$$,
  '42501',
  null,
  'an outsider cannot probe another organisation for its size'
);

select * from finish();

rollback;
