-- DB-019: the seed has to mean what it says.
--
-- Unlike every other suite here, this one asserts against data that already
-- exists rather than fixtures it creates, because the seed is what developers
-- build screens against and what demos run on.
--
-- It exists because the first version of the seed carried a tie decision note on
-- a cycle that was not tied. Nothing failed. The constraint was satisfied,
-- because the stored winner count matched the actual leader, and only the story
-- was wrong. A screen built against it would have shown a resolved tie where the
-- data had a clear leader, which is exactly the case most likely to hide a bug
-- in tie handling.
--
-- Fixture data that quietly contradicts itself is worse than none: it teaches
-- the wrong shape and it makes a real defect look normal.

begin;

create extension if not exists pgtap;

select plan(16);

-- ---------------------------------------------------------------------------
-- It is present, and it is synthetic
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int from public.organisations),
  2,
  'the seed created two organisations'
);

-- Every seeded address is on a reserved example domain. RFC 2606 guarantees
-- those can never be registered, so a stray invitation cannot reach a person.
select is(
  (select count(*)::int from auth.users
   where email not like '%@%.example'),
  0,
  'every seeded email is on a reserved example domain and can reach nobody'
);

select is(
  (select count(*)::int from auth.identities),
  (select count(*)::int from auth.users),
  'every seeded user has an identity, so they can actually sign in locally'
);

select is(
  (select count(*)::int from public.profiles),
  (select count(*)::int from auth.users),
  'and a profile, created by the trigger rather than by the seed'
);

-- ---------------------------------------------------------------------------
-- Every cycle state a screen has to handle is present
-- ---------------------------------------------------------------------------

select is(
  (select string_agg(distinct status, ',' order by status)
   from public.recognition_cycles),
  'closed,open,revealed',
  'the seed covers open, closed and revealed cycles'
);

select is(
  (select count(*)::int from public.recognition_cycles
   where tie_decision_note is not null),
  1,
  'exactly one cycle was revealed after a tie'
);

-- ---------------------------------------------------------------------------
-- The claims match the ballots
-- ---------------------------------------------------------------------------

-- The assertion that would have caught the original mistake.
select is(
  (select count(*)::int
   from public.recognition_cycles c,
        lateral private.cycle_tally(c.id) t
   where c.tie_decision_note is not null
     and t.nominations = c.winner_nominations),
  2,
  'the cycle with a tie note really does have two people on the winning count'
);

select is(
  (select count(*)::int
   from public.recognition_cycles c
   where c.status = 'revealed'
     and c.winner_nominations <> (
       select max(t.nominations) from private.cycle_tally(c.id) t
     )),
  0,
  'every revealed winner holds the top count in its own tally'
);

select is(
  (select count(*)::int
   from public.recognition_cycles c
   join public.participants p on p.id = c.winner_participant_id
   where c.status = 'revealed' and c.winner_name <> p.display_name),
  0,
  'every snapshotted winner name matches the participant it points at'
);

select is(
  (select count(*)::int from public.recognition_cycles
   where status <> 'revealed' and winner_participant_id is not null),
  0,
  'no unrevealed cycle carries winner data'
);

-- ---------------------------------------------------------------------------
-- The awkward cases a uniform fixture would hide
-- ---------------------------------------------------------------------------

select ok(
  (select count(*) from public.participants where not can_vote) > 0,
  'somebody can be nominated but cannot vote, so eligibility is not uniform'
);

select ok(
  (select count(*) from public.participants where user_id is null) > 0,
  'somebody is on the roster without an account, so the invited state is real'
);

select ok(
  (select count(*) from public.organisation_invitations
   where accepted_at is null and revoked_at is null and expires_at > now()) > 0,
  'a live invitation exists for the acceptance flow to work against'
);

select ok(
  (select count(*) from public.recognition_nominations where status = 'hidden') > 0,
  'a moderated ballot exists, so moderation views have something to show'
);

select ok(
  (select count(*) from public.recognition_nominations where status = 'withdrawn') > 0,
  'a withdrawn ballot exists, so the single-slot rule is visible'
);

-- Beta has two eligible voters, which assessConfidentiality grades 'determined'.
-- Keeping a too-small organisation in the seed means the FR-CYCLE-04 warning is
-- seen during development rather than only in a unit test.
select is(
  (select count(*)::int from public.participants p
   join public.organisations o on o.id = p.organisation_id
   where o.name = 'Beta Studio' and p.can_vote and p.user_id is not null),
  2,
  'the second organisation is small enough to trigger the confidentiality warning'
);

select * from finish();

rollback;
