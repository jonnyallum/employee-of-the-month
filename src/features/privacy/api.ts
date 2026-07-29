/**
 * The rights a person can exercise on their own data.
 *
 * All four are guarded functions. None of these tables has a client grant, and
 * that is deliberate: `privacy_requests` in particular must not be readable
 * across users, so "my requests" is a function scoped to auth.uid() rather than
 * a policy on a table anybody can query.
 */

import { getSupabaseClient } from '@/lib/supabase';

export interface PrivacyRequest {
  id: string;
  requestType: string;
  state: string;
  receivedAt: string;
  dueAt: string | null;
  completedAt: string | null;
}

/** Returns the whole export as JSON. Shape is documented in FR-PRIV-02. */
export async function exportMyData(): Promise<unknown> {
  const client = getSupabaseClient();
  const { data, error } = await client.rpc('export_my_data');
  if (error) throw error;
  return data;
}

export async function listMyPrivacyRequests(): Promise<PrivacyRequest[]> {
  const client = getSupabaseClient();
  const { data, error } = await client.rpc('get_my_privacy_requests');
  if (error) throw error;

  return (data ?? []).map((row) => ({
    id: row.id,
    requestType: row.request_type,
    state: row.state,
    receivedAt: row.received_at,
    dueAt: row.due_at,
    completedAt: row.completed_at,
  }));
}

export async function requestAccountDeletion(): Promise<string> {
  const client = getSupabaseClient();
  const { data, error } = await client.rpc('request_account_deletion');
  if (error) throw error;
  return data as string;
}

export async function leaveOrganisation(organisationId: string): Promise<void> {
  const client = getSupabaseClient();
  const { error } = await client.rpc('leave_organisation', {
    target_organisation_id: organisationId,
  });
  if (error) throw error;
}

export interface RetentionPolicy {
  retentionMonths: number | null;
  /** D-036. The residual ballot record has its own, longer period. */
  residualRetentionMonths: number | null;
}

export async function loadRetention(
  organisationId: string,
): Promise<RetentionPolicy | null> {
  const client = getSupabaseClient();
  const { data, error } = await client
    .from('recognition_settings')
    .select('retention_months, residual_retention_months')
    .eq('organisation_id', organisationId)
    .maybeSingle();

  if (error) throw error;
  if (!data) return null;
  return {
    retentionMonths: data.retention_months,
    residualRetentionMonths: data.residual_retention_months,
  };
}

const MESSAGES: Record<string, string> = {
  sole_owner:
    'You are the only owner. Make somebody else an owner first, or delete the organisation.',
  permission_denied: 'You do not have access to this.',
};

export function describePrivacyError(error: unknown): string {
  const hint =
    typeof error === 'object' && error !== null && 'hint' in error
      ? String((error as { hint?: unknown }).hint ?? '')
      : '';
  return MESSAGES[hint] ?? 'Something went wrong. Please try again.';
}
