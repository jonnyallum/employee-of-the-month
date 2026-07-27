/**
 * Administrator calls.
 *
 * Every one of these is a guarded function rather than a table write, because
 * every one enforces something a grant cannot express: a legal transition, a
 * version check, a recomputed tally, or a return shape that must not contain
 * the voter.
 *
 * Note what is missing. There is no call that returns who has or has not voted,
 * and no call that returns standings while a cycle is open. Both are absent
 * from the database too. If a screen ever appears to need one, the answer is
 * that the screen is wrong.
 */

import { getSupabaseClient } from '@/lib/supabase';

export interface Turnout {
  eligibleVoters: number;
  ballotsCounted: number;
  turnoutPercent: number;
}

export interface Standing {
  participantId: string;
  displayName: string;
  nominations: number;
  rank: number;
}

export interface AdminNomination {
  id: string;
  nomineeDisplayName: string;
  reason: string | null;
  status: string;
  moderationReason: string | null;
  createdDate: string;
}

export async function loadTurnout(cycleId: string): Promise<Turnout | null> {
  const client = getSupabaseClient();
  const { data, error } = await client.rpc('get_cycle_turnout', {
    target_cycle_id: cycleId,
  });
  if (error) throw error;

  const row = (data ?? [])[0];
  if (!row) return null;
  return {
    eligibleVoters: row.eligible_voters,
    ballotsCounted: row.ballots_counted,
    turnoutPercent: row.turnout_percent,
  };
}

/** Refused by the database while the cycle is open, which is the point. */
export async function loadStandings(cycleId: string): Promise<Standing[]> {
  const client = getSupabaseClient();
  const { data, error } = await client.rpc('get_closed_standings', {
    target_cycle_id: cycleId,
  });
  if (error) throw error;

  return (data ?? []).map((row) => ({
    participantId: row.participant_id,
    displayName: row.display_name,
    nominations: row.nominations,
    rank: row.rank,
  }));
}

export async function loadAdminNominations(
  cycleId: string,
): Promise<AdminNomination[]> {
  const client = getSupabaseClient();
  const { data, error } = await client.rpc('get_admin_nominations', {
    target_cycle_id: cycleId,
  });
  if (error) throw error;

  return (data ?? []).map((row) => ({
    id: row.id,
    nomineeDisplayName: row.nominee_display_name,
    reason: row.reason,
    status: row.status,
    moderationReason: row.moderation_reason,
    createdDate: row.created_date,
  }));
}

export async function createCycle(
  organisationId: string,
  period: string,
  criteria: string,
): Promise<string> {
  const client = getSupabaseClient();
  const trimmed = criteria.trim();
  const { data, error } = await client.rpc('create_cycle', {
    target_organisation_id: organisationId,
    period,
    ...(trimmed === '' ? {} : { criteria: trimmed }),
  });
  if (error) throw error;
  return data as string;
}

/**
 * The version is not optional. Passing the one the screen was rendered with is
 * what turns two administrators acting at once into a clear refusal instead of
 * a silent overwrite.
 */
export async function transitionCycle(
  cycleId: string,
  expectedVersion: number,
  nextStatus: 'open' | 'closed',
): Promise<number> {
  const client = getSupabaseClient();
  const { data, error } = await client.rpc('transition_cycle', {
    target_cycle_id: cycleId,
    expected_version: expectedVersion,
    next_status: nextStatus,
  });
  if (error) throw error;
  return data as number;
}

export async function revealWinner(input: {
  cycleId: string;
  expectedVersion: number;
  tiedParticipantId?: string;
  decisionNote?: string;
}): Promise<void> {
  const client = getSupabaseClient();
  const { error } = await client.rpc('reveal_winner', {
    target_cycle_id: input.cycleId,
    expected_version: input.expectedVersion,
    ...(input.tiedParticipantId
      ? { tied_participant_id: input.tiedParticipantId }
      : {}),
    ...(input.decisionNote ? { decision_note: input.decisionNote } : {}),
  });
  if (error) throw error;
}

export async function moderateNomination(
  nominationId: string,
  action: 'hide' | 'restore',
  reason: string,
): Promise<void> {
  const client = getSupabaseClient();
  const { error } = await client.rpc('moderate_nomination', {
    target_nomination_id: nominationId,
    action,
    moderation_reason: reason,
  });
  if (error) throw error;
}

const MESSAGES: Record<string, string> = {
  permission_denied: 'You do not have access to this.',
  stale_version:
    'Somebody else changed this cycle while you were looking at it. Reload and try again.',
  illegal_transition: 'That is not a valid next step for this cycle.',
  cycle_revealed: 'This result is final and can no longer be changed.',
  cycle_not_closed: 'Close nominations before revealing the result.',
  cycle_still_open: 'That is not available until voting has closed.',
  not_enough_recipients:
    'At least two people must be eligible to receive a nomination.',
  no_eligible_voters: 'At least one person must be able to vote.',
  no_ballots: 'Nobody was nominated, so there is no result to reveal.',
  clear_leader: 'There is a clear winner, so another cannot be chosen.',
  tie_requires_choice: 'This month is tied. Choose one of the joint leaders.',
  tie_note_required: 'Record why you chose this person before revealing.',
  tie_resolution_invalid: 'That person is not one of the joint leaders.',
  cycle_exists: 'A cycle already exists for that month.',
  reason_required: 'Give a reason for hiding this nomination.',
  use_reveal_winner: 'Use the reveal action to publish a result.',
  send_failed:
    'The invitation was created but the email could not be sent. Try again.',
  already_linked: 'That person already has an account.',
  invalid_email: 'That email address does not look right.',
};

export function describeAdminError(error: unknown): string {
  const hint =
    typeof error === 'object' && error !== null && 'hint' in error
      ? String((error as { hint?: unknown }).hint ?? '')
      : '';
  return MESSAGES[hint] ?? 'Something went wrong. Please try again.';
}

export interface RosterEntry {
  id: string;
  displayName: string;
  team: string | null;
  active: boolean;
  canVote: boolean;
  canReceive: boolean;
  hasAccount: boolean;
  invitedEmail: string | null;
  invitationExpiresAt: string | null;
}

export async function loadRoster(
  organisationId: string,
): Promise<RosterEntry[]> {
  const client = getSupabaseClient();
  const { data, error } = await client.rpc('get_roster', {
    target_organisation_id: organisationId,
  });
  if (error) throw error;

  return (data ?? []).map((row) => ({
    id: row.id,
    displayName: row.display_name,
    team: row.team,
    active: row.active,
    canVote: row.can_vote,
    canReceive: row.can_receive,
    hasAccount: row.has_account,
    invitedEmail: row.invited_email,
    invitationExpiresAt: row.invitation_expires_at,
  }));
}

export async function addParticipant(
  organisationId: string,
  displayName: string,
  team: string,
): Promise<void> {
  const client = getSupabaseClient();
  const trimmedTeam = team.trim();
  const { error } = await client.rpc('add_participant', {
    target_organisation_id: organisationId,
    display_name: displayName,
    ...(trimmedTeam === '' ? {} : { team: trimmedTeam }),
  });
  if (error) throw error;
}

export async function updateParticipant(
  participantId: string,
  next: { active: boolean; canVote: boolean; canReceive: boolean },
): Promise<void> {
  const client = getSupabaseClient();
  const { error } = await client.rpc('update_participant', {
    target_participant_id: participantId,
    active: next.active,
    can_vote: next.canVote,
    can_receive: next.canReceive,
  });
  if (error) throw error;
}

/**
 * Asks the server to create an invitation and email it.
 *
 * This calls an Edge Function rather than the RPC directly, and the reason is
 * the token. `create_invitation` returns the only readable copy; if the browser
 * called it, that token would exist in the client, in devtools and in anything
 * that captures a response. The function creates it, emails it and discards it,
 * and the caller learns only when it expires.
 *
 * Authorisation is unchanged: the function calls the same RPC with this user's
 * own JWT, so the database applies the same owner-or-admin check.
 */
export async function inviteParticipant(
  participantId: string,
  email: string,
): Promise<{ expiresAt: string; alreadySent: boolean }> {
  const client = getSupabaseClient();
  const { data, error } = await client.functions.invoke('send-invitation', {
    body: { participantId, email: email.trim().toLowerCase() },
  });

  if (error) {
    // The function forwards the database's own product code, so the same
    // wording is shown whether the refusal came from here or from a direct call.
    const context = (error as { context?: { hint?: string } }).context;
    throw { hint: context?.hint ?? 'send_failed' };
  }

  return {
    expiresAt: String(data?.expiresAt ?? ''),
    alreadySent: Boolean(data?.alreadySent),
  };
}
