/**
 * Every call the member experience makes.
 *
 * Reads go through the Data API, which RLS scopes to the caller's own
 * organisations, so none of these queries filter by tenant themselves. Writes
 * go through guarded functions, because none of them are expressible as a
 * grant. Both are deliberate: a query here that started filtering by tenant in
 * JavaScript would be hiding the fact that the database already does it, and a
 * write that went direct to a table would be bypassing rules the schema cannot
 * enforce on an INSERT alone.
 */

import { getSupabaseClient } from '@/lib/supabase';

export interface Membership {
  organisationId: string;
  organisationName: string;
  timezone: string;
  role: 'owner' | 'admin' | 'member';
}

export interface Cycle {
  id: string;
  periodMonth: string;
  status: 'draft' | 'open' | 'closed' | 'revealed';
  criteria: string | null;
  version: number;
  winnerName: string | null;
  winnerNominations: number | null;
  tieDecisionNote: string | null;
}

export interface Nominee {
  id: string;
  displayName: string;
  team: string | null;
}

export interface MyNomination {
  id: string;
  nomineeParticipantId: string;
  nomineeDisplayName: string;
  reason: string | null;
  status: string;
}

/**
 * The caller's own organisations and roles.
 *
 * The `user_id` filter is essential and was missing at first. RLS on
 * organisation_members permits reading every membership row in the caller's
 * organisations, not only their own, because roles are legitimately visible
 * inside a tenant. Without the filter this returned all five colleagues and the
 * screen took the first row's role as the caller's, which showed a plain member
 * an administrator link.
 *
 * Nothing was exposed that the policy did not already allow. The bug was the
 * assumption that "what RLS returns" and "what is mine" are the same set, which
 * for this table they deliberately are not.
 */
export async function listMemberships(userId: string): Promise<Membership[]> {
  const client = getSupabaseClient();
  const { data, error } = await client
    .from('organisation_members')
    .select('role, organisations(id, name, timezone)')
    .eq('user_id', userId)
    .eq('status', 'active');

  if (error) throw error;

  return (data ?? [])
    .filter((row) => row.organisations)
    .map((row) => ({
      organisationId: row.organisations.id,
      organisationName: row.organisations.name,
      timezone: row.organisations.timezone,
      role: row.role as Membership['role'],
    }));
}

/**
 * The cycle to show. An open cycle always wins; otherwise the most recent one,
 * so a member between cycles sees the last result rather than an empty screen.
 */
export async function loadCurrentCycle(
  organisationId: string,
): Promise<Cycle | null> {
  const client = getSupabaseClient();
  // One unbroken string literal. Supabase infers the row type from the select
  // text, and concatenating it defeats that inference entirely: the result
  // degrades to an error type and every field access stops being checked.
  const { data, error } = await client
    .from('recognition_cycles')
    .select(
      'id, period_month, status, criteria, version, winner_name, winner_nominations, tie_decision_note',
    )
    .eq('organisation_id', organisationId)
    .order('period_month', { ascending: false });

  if (error) throw error;

  const chosen = data?.find((row) => row.status === 'open') ?? data?.[0];
  if (!chosen) return null;

  return {
    id: chosen.id,
    periodMonth: chosen.period_month,
    status: chosen.status as Cycle['status'],
    criteria: chosen.criteria,
    version: chosen.version,
    winnerName: chosen.winner_name,
    winnerNominations: chosen.winner_nominations,
    tieDecisionNote: chosen.tie_decision_note,
  };
}

/**
 * The roster, as the client is permitted to see it. `user_id` and `can_vote`
 * are not in the column grant, so the caller's own entry cannot be identified
 * from this list. Excluding themselves from the nominee list is therefore done
 * with the participant id from `getMyParticipantId`, not by matching users.
 */
export async function listNominees(organisationId: string): Promise<Nominee[]> {
  const client = getSupabaseClient();
  const { data, error } = await client
    .from('participants')
    .select('id, display_name, team')
    .eq('organisation_id', organisationId)
    .eq('can_receive', true)
    .order('display_name');

  if (error) throw error;
  return (data ?? []).map((row) => ({
    id: row.id,
    displayName: row.display_name,
    team: row.team,
  }));
}

export async function loadMyNomination(
  cycleId: string,
): Promise<MyNomination | null> {
  const client = getSupabaseClient();
  const { data, error } = await client.rpc('get_my_nomination', {
    target_cycle_id: cycleId,
  });

  if (error) throw error;
  const row = (data ?? [])[0];
  if (!row) return null;

  return {
    id: row.id,
    nomineeParticipantId: row.nominee_participant_id,
    nomineeDisplayName: row.nominee_display_name,
    reason: row.reason,
    status: row.status,
  };
}

export async function castNomination(input: {
  cycleId: string;
  nomineeParticipantId: string;
  reason: string;
  idempotencyKey: string;
}): Promise<void> {
  const client = getSupabaseClient();
  const trimmed = input.reason.trim();

  // The reason is optional, and under exactOptionalPropertyTypes an absent
  // argument is not the same as one set to undefined. Omitting the key lets the
  // function's own default apply rather than sending a null the RPC would have
  // to interpret.
  const { error } = await client.rpc('cast_nomination', {
    target_cycle_id: input.cycleId,
    nominee_participant_id: input.nomineeParticipantId,
    idempotency_key: input.idempotencyKey,
    ...(trimmed === '' ? {} : { reason: trimmed }),
  });
  if (error) throw error;
}

export async function withdrawNomination(cycleId: string): Promise<void> {
  const client = getSupabaseClient();
  const { error } = await client.rpc('withdraw_nomination', {
    target_cycle_id: cycleId,
  });
  if (error) throw error;
}

/**
 * Turns a database error into something a person can act on.
 *
 * The functions raise a `hint` carrying a stable product code precisely so the
 * client does not have to match on message text, which changes. Anything
 * unrecognised falls back to a neutral sentence rather than showing a Postgres
 * error, which would leak schema detail and help nobody.
 */
const MESSAGES: Record<string, string> = {
  permission_denied: 'You do not have access to this.',
  cycle_not_open: 'Nominations are not open.',
  already_nominated: 'You have already nominated someone this month.',
  self_nomination: 'You cannot nominate yourself.',
  not_eligible_to_vote: 'You are not eligible to vote in this cycle.',
  nominee_not_eligible:
    'That colleague is not eligible to receive nominations.',
  nominee_not_found: 'That colleague is not on the roster.',
  not_on_roster: 'You are not on this organisation’s roster.',
  no_nomination: 'You have no nomination to withdraw.',
  reason_too_long: 'Keep the reason to 500 characters or fewer.',
};

export function describeError(error: unknown): string {
  const hint =
    typeof error === 'object' && error !== null && 'hint' in error
      ? String((error as { hint?: unknown }).hint ?? '')
      : '';

  return MESSAGES[hint] ?? 'Something went wrong. Please try again.';
}
