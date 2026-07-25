/**
 * Pure recognition rules shared by screens, edge functions and tests.
 * Adapted from the biz-os P08 Employee Recognition engine on 25 July 2026.
 *
 * These checks improve the user experience. Database constraints and RLS must
 * enforce the same tenant, eligibility and one-ballot invariants independently.
 */

export const CYCLE_STATUSES = ['draft', 'open', 'closed', 'revealed'] as const;
export type CycleStatus = (typeof CYCLE_STATUSES)[number];

export const LEADERBOARD_MODES = ['hidden', 'top_three', 'full'] as const;
export type LeaderboardMode = (typeof LEADERBOARD_MODES)[number];

export const REASON_MAX_LENGTH = 500;
export const SHORTLIST_SIZE = 3;

export interface CycleLike {
  id: string;
  periodMonth: string;
  status: string;
  leaderboardMode: string;
}

export interface ParticipantLike {
  id: string;
  userId: string | null;
  canVote: boolean;
  canReceive: boolean;
}

export interface NamedParticipant extends ParticipantLike {
  name: string;
  team: string;
  avatarUrl?: string;
}

export interface NominationLike {
  id: string;
  cycleId: string;
  nominatorUserId: string;
  nomineeParticipantId: string;
  reason: string;
  status: 'active' | 'hidden';
}

export interface TallyEntry {
  participantId: string;
  name: string;
  team: string;
  avatarUrl: string;
  nominations: number;
  sharePct: number;
  rank: number;
}

export interface Turnout {
  cast: number;
  canVote: number;
  turnoutPct: number;
}

const MONTH_NAMES = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
] as const;

export function periodKey(isoDate: string): string {
  return `${isoDate.slice(0, 7)}-01`;
}

export function isPeriodKey(period: string): boolean {
  return /^\d{4}-(0[1-9]|1[0-2])-01$/.test(period);
}

export function periodLabel(period: string): string {
  if (!isPeriodKey(period)) return period;
  const year = period.slice(0, 4);
  const monthIndex = Number(period.slice(5, 7)) - 1;
  return `${MONTH_NAMES[monthIndex]} ${year}`;
}

export function currentCycle<T extends CycleLike>(
  cycles: readonly T[],
): T | null {
  const newestFirst = [...cycles].sort((left, right) =>
    right.periodMonth.localeCompare(left.periodMonth),
  );
  return (
    newestFirst.find((cycle) => cycle.status === 'open') ??
    newestFirst[0] ??
    null
  );
}

export const CYCLE_TRANSITIONS: Record<CycleStatus, readonly CycleStatus[]> = {
  draft: ['open'],
  open: ['closed'],
  closed: ['open', 'revealed'],
  revealed: [],
};

export function isCycleStatus(value: string): value is CycleStatus {
  return (CYCLE_STATUSES as readonly string[]).includes(value);
}

export function canTransition(from: string, to: string): boolean {
  if (!isCycleStatus(from) || !isCycleStatus(to)) return false;
  return CYCLE_TRANSITIONS[from].includes(to);
}

export function transitionRefusal(from: string, to: string): string | null {
  if (!isCycleStatus(from))
    return `"${from}" is not a recognition cycle state.`;
  if (!isCycleStatus(to)) return `"${to}" is not a recognition cycle state.`;
  if (from === to || canTransition(from, to)) return null;
  if (from === 'revealed') {
    return 'This result is final. Start a new month instead of reopening it.';
  }
  if (to === 'revealed') {
    return from === 'open'
      ? 'Close nominations before revealing the result.'
      : 'Open and close nominations before revealing the result.';
  }
  return `A ${from} cycle cannot become ${to}.`;
}

export function acceptsNominations(cycle: CycleLike | null): boolean {
  return cycle?.status === 'open';
}

export function participantForUser<T extends ParticipantLike>(
  participants: readonly T[],
  userId: string | null,
): T | null {
  if (!userId) return null;
  return (
    participants.find((participant) => participant.userId === userId) ?? null
  );
}

export function nominatableFor<T extends ParticipantLike>(
  participants: readonly T[],
  voterUserId: string | null,
): T[] {
  const voter = participantForUser(participants, voterUserId);
  return participants.filter(
    (participant) => participant.canReceive && participant.id !== voter?.id,
  );
}

export function existingNomination<T extends NominationLike>(
  nominations: readonly T[],
  cycleId: string,
  voterUserId: string | null,
): T | null {
  if (!voterUserId) return null;
  return (
    nominations.find(
      (nomination) =>
        nomination.cycleId === cycleId &&
        nomination.nominatorUserId === voterUserId,
    ) ?? null
  );
}

export function normaliseReason(reason: string): string {
  return reason.trim().replace(/\s+/g, ' ');
}

export interface NominationAttempt {
  cycle: CycleLike | null;
  participants: readonly ParticipantLike[];
  nominations: readonly NominationLike[];
  voterUserId: string | null;
  nomineeParticipantId: string;
  reason: string;
}

export function nominationRefusal(attempt: NominationAttempt): string | null {
  const {
    cycle,
    participants,
    nominations,
    voterUserId,
    nomineeParticipantId,
  } = attempt;

  if (!voterUserId) return 'Sign in before making a nomination.';
  if (!cycle) return 'There is no recognition cycle for this month.';
  if (!acceptsNominations(cycle)) return 'Nominations are not open.';

  const voter = participantForUser(participants, voterUserId);
  if (!voter) return 'Your account is not on this organisation’s roster.';
  if (!voter.canVote) return 'You are not eligible to vote in this cycle.';

  const nominee = participants.find(
    (participant) => participant.id === nomineeParticipantId,
  );
  if (!nominee) return 'That colleague is not on this organisation’s roster.';
  if (!nominee.canReceive) {
    return 'That colleague is not eligible to receive nominations.';
  }
  if (nominee.id === voter.id) return 'You cannot nominate yourself.';
  if (existingNomination(nominations, cycle.id, voterUserId)) {
    return 'You have already nominated someone this month.';
  }

  const reason = normaliseReason(attempt.reason);
  if (!reason) return 'Add a short reason for your nomination.';
  if (reason.length > REASON_MAX_LENGTH) {
    return `Keep the reason to ${REASON_MAX_LENGTH} characters or fewer.`;
  }

  return null;
}

export function countedNominations<T extends NominationLike>(
  nominations: readonly T[],
  cycleId: string,
): T[] {
  return nominations.filter(
    (nomination) =>
      nomination.cycleId === cycleId && nomination.status === 'active',
  );
}

export function turnout(
  participants: readonly ParticipantLike[],
  nominations: readonly NominationLike[],
  cycleId: string,
): Turnout {
  const voters = new Set(
    participants
      .filter((participant) => participant.canVote && participant.userId)
      .map((participant) => participant.userId),
  );
  const votersWhoCast = new Set(
    countedNominations(nominations, cycleId)
      .map((nomination) => nomination.nominatorUserId)
      .filter((userId) => voters.has(userId)),
  );
  const canVote = voters.size;
  const cast = votersWhoCast.size;

  return {
    cast,
    canVote,
    turnoutPct: canVote === 0 ? 0 : Math.round((cast / canVote) * 100),
  };
}

export function tally(
  participants: readonly NamedParticipant[],
  nominations: readonly NominationLike[],
  cycleId: string,
): TallyEntry[] {
  const counted = countedNominations(nominations, cycleId);
  const total = counted.length;
  const counts = new Map<string, number>();

  for (const nomination of counted) {
    counts.set(
      nomination.nomineeParticipantId,
      (counts.get(nomination.nomineeParticipantId) ?? 0) + 1,
    );
  }

  const ordered = participants
    .filter((participant) => participant.canReceive)
    .map((participant) => ({
      participantId: participant.id,
      name: participant.name,
      team: participant.team,
      avatarUrl: participant.avatarUrl ?? '',
      nominations: counts.get(participant.id) ?? 0,
      sharePct:
        total === 0
          ? 0
          : Math.round(((counts.get(participant.id) ?? 0) / total) * 100),
      rank: 0,
    }))
    .sort(
      (left, right) =>
        right.nominations - left.nominations ||
        left.name.localeCompare(right.name),
    );

  let previousNominations: number | null = null;
  let previousRank = 0;
  return ordered.map((entry, index) => {
    const rank =
      entry.nominations === previousNominations ? previousRank : index + 1;
    previousNominations = entry.nominations;
    previousRank = rank;
    return { ...entry, rank };
  });
}

export function leaders(entries: readonly TallyEntry[]): TallyEntry[] {
  const highest = entries[0]?.nominations ?? 0;
  if (highest === 0) return [];
  return entries.filter((entry) => entry.nominations === highest);
}

export function winnerOf(entries: readonly TallyEntry[]): TallyEntry | null {
  const firstPlace = leaders(entries);
  return firstPlace.length === 1 ? (firstPlace[0] ?? null) : null;
}

export function visibleLeaderboard(
  entries: readonly TallyEntry[],
  mode: string,
  status: string,
): TallyEntry[] {
  if (status !== 'revealed' || mode === 'hidden') return [];
  if (mode === 'top_three') {
    return entries.filter((entry) => entry.rank <= SHORTLIST_SIZE);
  }
  return mode === 'full' ? [...entries] : [];
}
