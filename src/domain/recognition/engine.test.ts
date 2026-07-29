import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  assessConfidentiality,
  assessRosterConfidentiality,
  CONFIDENTIALITY_WARNING_THRESHOLD,
  CYCLE_TRANSITIONS,
  type CycleLike,
  canTransition,
  currentCycle,
  eligibleVoterIds,
  leaders,
  type NamedParticipant,
  NOMINATION_TAGS,
  type NominationLike,
  nominatableFor,
  nominationRefusal,
  nominationTagLabel,
  normaliseReason,
  type ParticipantLike,
  periodKey,
  periodLabel,
  REASON_MAX_LENGTH,
  type TallyEntry,
  tally,
  transitionRefusal,
  turnout,
  visibleLeaderboard,
  voterConfidentialityNotice,
  voterRosterConfidentialityNotice,
  winnerOf,
} from './engine';

function participant(
  id: string,
  overrides: Partial<ParticipantLike> = {},
): ParticipantLike {
  return {
    id,
    userId: `user-${id}`,
    canVote: true,
    canReceive: true,
    ...overrides,
  };
}

function named(
  id: string,
  name: string,
  overrides: Partial<NamedParticipant> = {},
): NamedParticipant {
  return {
    ...participant(id),
    name,
    team: 'Operations',
    ...overrides,
  };
}

function standing(
  participantId: string,
  name: string,
  rank: number,
): TallyEntry {
  return {
    participantId,
    name,
    team: 'Operations',
    avatarUrl: '',
    nominations: 0,
    sharePct: 0,
    rank,
  };
}

function cycle(overrides: Partial<CycleLike> = {}): CycleLike {
  return {
    id: 'cycle-july',
    periodMonth: '2026-07-01',
    status: 'open',
    leaderboardMode: 'hidden',
    ...overrides,
  };
}

function nomination(
  voter: string,
  nominee: string,
  overrides: Partial<NominationLike> = {},
): NominationLike {
  return {
    id: `nomination-${voter}`,
    cycleId: 'cycle-july',
    nominatorUserId: `user-${voter}`,
    nomineeParticipantId: nominee,
    reason: 'Consistently helped the team.',
    status: 'active',
    ...overrides,
  };
}

const roster = [
  participant('a'),
  participant('b'),
  participant('c', { canVote: false }),
  participant('d', { canReceive: false }),
];

function attempt(
  overrides: Partial<Parameters<typeof nominationRefusal>[0]> = {},
) {
  return {
    cycle: cycle(),
    participants: roster,
    nominations: [] as NominationLike[],
    voterUserId: 'user-a',
    nomineeParticipantId: 'b',
    tag: 'helped_customer',
    reason: 'Carried a difficult customer handover.',
    ...overrides,
  };
}

test('period helpers keep the written calendar month', () => {
  assert.equal(periodKey('2026-07-01T00:30:00+01:00'), '2026-07-01');
  assert.equal(periodLabel('2026-07-01'), 'July 2026');
  assert.equal(periodLabel('not-a-period'), 'not-a-period');
});

test('the newest open cycle wins, otherwise the newest cycle does', () => {
  const june = cycle({ id: 'june', periodMonth: '2026-06-01', status: 'open' });
  const july = cycle({
    id: 'july',
    periodMonth: '2026-07-01',
    status: 'draft',
  });
  assert.equal(currentCycle([july, june])?.id, 'june');
  assert.equal(currentCycle([july])?.id, 'july');
  assert.equal(currentCycle([]), null);
});

test('revealed cycles are terminal and reveal requires a closed cycle', () => {
  assert.deepEqual(CYCLE_TRANSITIONS.revealed, []);
  assert.equal(canTransition('closed', 'revealed'), true);
  assert.equal(canTransition('open', 'revealed'), false);
  assert.match(
    transitionRefusal('open', 'revealed') ?? '',
    /Close nominations/,
  );
  assert.match(transitionRefusal('revealed', 'open') ?? '', /final/);
});

test('voting and receiving eligibility remain separate', () => {
  assert.deepEqual(
    nominatableFor(roster, 'user-a').map((entry) => entry.id),
    ['b', 'c'],
  );
  assert.equal(
    nominationRefusal(attempt({ voterUserId: 'user-c' })),
    'You are not eligible to vote in this cycle.',
  );
  assert.equal(
    nominationRefusal(attempt({ nomineeParticipantId: 'd' })),
    'That colleague is not eligible to receive nominations.',
  );
});

test('ballot guard blocks self-voting and a second ballot', () => {
  assert.equal(
    nominationRefusal(attempt({ nomineeParticipantId: 'a' })),
    'You cannot nominate yourself.',
  );
  assert.equal(
    nominationRefusal(attempt({ nominations: [nomination('a', 'b')] })),
    'You have already nominated someone this month.',
  );
});

test('ballot guard requires an open cycle, identity and useful reason', () => {
  assert.equal(nominationRefusal(attempt()), null);
  assert.equal(
    nominationRefusal(attempt({ voterUserId: null })),
    'Sign in before making a nomination.',
  );
  assert.equal(
    nominationRefusal(attempt({ cycle: cycle({ status: 'closed' }) })),
    'Nominations are not open.',
  );
  assert.equal(
    nominationRefusal(attempt({ reason: '   ' })),
    null,
    'the note is optional now that the tag carries the meaning (D-032)',
  );
  assert.match(
    nominationRefusal(attempt({ reason: 'x'.repeat(REASON_MAX_LENGTH + 1) })) ??
      '',
    /250 characters/,
  );
});

test('a nomination must say what the person did (D-032)', () => {
  assert.equal(
    nominationRefusal(attempt({ tag: '' })),
    'Choose what this person did.',
  );
  assert.equal(
    nominationRefusal(attempt({ tag: 'went_above_and_beyond' })),
    'Choose what this person did.',
    'a tag outside the vocabulary is refused rather than sent to the database',
  );
  // The legacy value marks ballots written before tags existed. Offering it as
  // a choice would make "not recorded" a thing somebody could deliberately say.
  assert.equal(
    nominationRefusal(attempt({ tag: 'unspecified' })),
    'Choose what this person did.',
  );
  const offered: string[] = NOMINATION_TAGS.map((option) => option.value);
  assert.ok(
    !offered.includes('unspecified'),
    'unspecified is never offered to a voter',
  );
});

test('the tag vocabulary describes behaviour, never a person', () => {
  for (const option of NOMINATION_TAGS) {
    assert.equal(
      nominationRefusal(attempt({ tag: option.value })),
      null,
      option.value + ' is accepted',
    );
    assert.equal(nominationTagLabel(option.value), option.label);
  }
  // A pre-D-032 ballot has to render as something. A raw slug or a blank cell
  // both read as a bug.
  assert.equal(nominationTagLabel('unspecified'), 'Not recorded');
});

test('reason normalisation is deterministic', () => {
  assert.equal(
    normaliseReason('  Helped   across\nthree teams. '),
    'Helped across three teams.',
  );
});

test('turnout counts unique eligible voters and excludes hidden ballots', () => {
  const result = turnout(
    roster,
    [
      nomination('a', 'b'),
      nomination('a', 'c', { id: 'duplicate' }),
      nomination('b', 'a', { status: 'hidden' }),
      nomination('c', 'a'),
    ],
    'cycle-july',
  );
  assert.deepEqual(result, { cast: 1, canVote: 3, turnoutPct: 33 });
});

test('tally excludes hidden ballots and assigns shared competition ranks', () => {
  const entries = tally(
    [named('a', 'Amira'), named('b', 'Ben'), named('c', 'Chloe')],
    [
      nomination('a', 'b'),
      nomination('b', 'c'),
      nomination('c', 'a', { status: 'hidden' }),
    ],
    'cycle-july',
  );

  assert.deepEqual(
    entries.map(({ name, nominations, rank }) => ({
      name,
      nominations,
      rank,
    })),
    [
      { name: 'Ben', nominations: 1, rank: 1 },
      { name: 'Chloe', nominations: 1, rank: 1 },
      { name: 'Amira', nominations: 0, rank: 3 },
    ],
  );
  assert.equal(leaders(entries).length, 2);
  assert.equal(winnerOf(entries), null);
});

test('a unique highest tally produces a winner', () => {
  const entries = tally(
    [named('a', 'Amira'), named('b', 'Ben')],
    [nomination('a', 'b'), nomination('c', 'b'), nomination('b', 'a')],
    'cycle-july',
  );
  assert.equal(winnerOf(entries)?.participantId, 'b');
});

test('leaderboards stay hidden until reveal and top-three includes ties', () => {
  const entries = [
    standing('a', 'Amira', 1),
    standing('b', 'Ben', 2),
    standing('c', 'Chloe', 3),
    standing('d', 'Dara', 3),
    standing('e', 'Eli', 5),
  ];

  assert.equal(visibleLeaderboard(entries, 'full', 'closed').length, 0);
  assert.equal(visibleLeaderboard(entries, 'hidden', 'revealed').length, 0);
  assert.equal(visibleLeaderboard(entries, 'top_three', 'revealed').length, 4);
  assert.equal(visibleLeaderboard(entries, 'full', 'revealed').length, 5);
});

test('confidentiality is called determined only where arithmetic settles it', () => {
  // One voter: the counted ballot is theirs. Two: an administrator who voted
  // subtracts their own and the remainder is the other person's, with
  // certainty. Three is where certainty stops, so it must not claim otherwise.
  for (const count of [0, 1, 2]) {
    assert.equal(
      assessConfidentiality(count).level,
      'determined',
      `n=${count}`,
    );
  }
  assert.equal(assessConfidentiality(3).level, 'weak');
});

test('confidentiality warns below the threshold and stops at it', () => {
  for (let count = 0; count < CONFIDENTIALITY_WARNING_THRESHOLD; count += 1) {
    const assessment = assessConfidentiality(count);
    assert.equal(assessment.warn, true, `n=${count} should warn`);
    assert.notEqual(assessment.message, null, `n=${count} needs wording`);
  }

  // The boundary itself must be quiet, otherwise the threshold is really 9.
  const atThreshold = assessConfidentiality(CONFIDENTIALITY_WARNING_THRESHOLD);
  assert.equal(atThreshold.level, 'standard');
  assert.equal(atThreshold.warn, false);
  assert.equal(atThreshold.message, null);
  assert.equal(assessConfidentiality(250).warn, false);
});

test('confidentiality tolerates counts that are not whole positive numbers', () => {
  assert.equal(assessConfidentiality(-4).eligibleVoters, 0);
  assert.equal(assessConfidentiality(8.9).eligibleVoters, 8);
  assert.equal(assessConfidentiality(8.9).warn, false);
  assert.equal(assessConfidentiality(Number.NaN).eligibleVoters, 0);
  assert.equal(assessConfidentiality(Number.POSITIVE_INFINITY).warn, true);
});

test('roster confidentiality counts only linked, vote-eligible participants', () => {
  const mixedRoster = [
    participant('a'),
    participant('b'),
    participant('c', { canVote: false }), // ineligible
    participant('d', { userId: null }), // invited, never accepted
    participant('e', { canVote: false, userId: null }),
  ];

  assert.equal(eligibleVoterIds(mixedRoster).size, 2);

  // Five roster entries look reassuring. Only two can actually vote, and it is
  // the voters that determine whether a ballot can be deduced.
  const assessment = assessRosterConfidentiality(mixedRoster);
  assert.equal(assessment.eligibleVoters, 2);
  assert.equal(assessment.level, 'determined');
  assert.equal(assessment.warn, true);
});

test('a roster large enough to be quiet stays quiet', () => {
  const wideRoster = Array.from({ length: 8 }, (_, index) =>
    participant(`p${index}`),
  );
  assert.equal(assessRosterConfidentiality(wideRoster).warn, false);
});

// D-035. The administrator warning is not enough on its own: the person whose
// ballot can be deduced is the voter, and the voter is the one who was never
// told. These assert that the voter-facing wording exists wherever the
// administrator-facing one does, and stays silent wherever it does not.
test('the voter is warned on exactly the same arithmetic as the administrator', () => {
  for (let count = 0; count <= 12; count += 1) {
    const admin = assessConfidentiality(count);
    const voter = voterConfidentialityNotice(count);

    assert.equal(voter.warn, admin.warn, `n=${count} must agree on warning`);
    assert.equal(voter.level, admin.level, `n=${count} must agree on level`);
    assert.equal(
      voter.eligibleVoters,
      admin.eligibleVoters,
      `n=${count} must agree on the count`,
    );
  }
});

test('the voter warning speaks to the voter and offers them a way out', () => {
  for (const count of [0, 1, 2, 3, 7]) {
    const message = voterConfidentialityNotice(count).message;
    assert.notEqual(message, null, `n=${count} needs wording`);

    // Addressed to the person at risk, not about them. "You" is the whole
    // point of this decision; without it this is just the admin copy again.
    assert.ok(
      message?.includes('how you voted'),
      `n=${count} must address the voter directly`,
    );

    // A warning that leaves somebody no action to take is decoration.
    assert.ok(
      message?.includes('do not have to vote'),
      `n=${count} must leave the voter an option`,
    );
  }
});

test('the voter warning distinguishes certainty from likelihood', () => {
  // With two or fewer voters the deduction is arithmetic, not probability, and
  // the copy must not soften it into "may be possible".
  assert.ok(voterConfidentialityNotice(2).message?.includes('can work out'));
  assert.ok(voterConfidentialityNotice(5).message?.includes('may be possible'));
});

test('a voter in a large enough team is not warned', () => {
  const atThreshold = voterConfidentialityNotice(
    CONFIDENTIALITY_WARNING_THRESHOLD,
  );
  assert.equal(atThreshold.warn, false);
  assert.equal(atThreshold.message, null);
  assert.equal(voterConfidentialityNotice(40).message, null);
});

test('voter roster notice counts only linked, vote-eligible participants', () => {
  const mixedRoster = [
    participant('a'),
    participant('b'),
    participant('c', { canVote: false }),
    participant('d', { userId: null }),
  ];

  const notice = voterRosterConfidentialityNotice(mixedRoster);
  assert.equal(notice.eligibleVoters, 2);
  assert.equal(notice.warn, true);
  assert.ok(notice.message?.includes('do not have to vote'));
});
