-- DB-003: recognition cycles, ballots, settings, audit, delivery and privacy.
--
-- Continues docs/SCHEMA_THREAT_MODEL.md. Same rules as DB-002: every table is
-- created fail-closed with RLS on and no policy, and every child row is tied to
-- its parent through a composite (organisation_id, id) key so it cannot point
-- across tenants.
--
-- Two invariants are expressed as CHECK constraints rather than trigger logic,
-- because a constraint cannot be forgotten by a future function author:
--   * invariant 8, no self-nomination
--   * invariants 10 and 12, winner data exists if and only if the cycle is
--     revealed
-- See the notes at each one.

-- ---------------------------------------------------------------------------
-- recognition_cycles
-- ---------------------------------------------------------------------------

create table public.recognition_cycles (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null
    references public.organisations (id) on delete cascade,

  -- Invariant 3. Normalised to the first of the month so "one cycle per month"
  -- is a unique index rather than an application convention.
  period_month date not null
    constraint recognition_cycles_period_is_month_start
    check (period_month = date_trunc('month', period_month)::date),

  status text not null default 'draft'
    constraint recognition_cycles_status
    check (status in ('draft', 'open', 'closed', 'revealed')),

  criteria text
    constraint recognition_cycles_criteria_length
    check (criteria is null or char_length(criteria) <= 2000),

  -- Fixed to 'hidden' in v1 by D-004. The column exists so a later change does
  -- not need a migration on a live table, not because it is configurable now.
  leaderboard_mode text not null default 'hidden'
    constraint recognition_cycles_leaderboard_mode
    check (leaderboard_mode in ('hidden', 'top_three', 'full')),

  opens_at timestamptz,
  closes_at timestamptz,

  -- Optimistic concurrency. Two administrators closing and reopening over each
  -- other becomes a deterministic failure instead of a lost update.
  version integer not null default 1
    constraint recognition_cycles_version_positive check (version >= 1),

  -- Deliberately NOT a foreign key. This is a snapshot: removing a participant
  -- from the roster must not erase or rewrite a past result.
  winner_participant_id uuid,
  winner_name text,
  winner_nominations integer
    constraint recognition_cycles_winner_count_positive
    check (winner_nominations is null or winner_nominations > 0),
  tie_decision_note text,
  revealed_at timestamptz,
  revealed_by uuid references auth.users (id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Invariant 3.
  constraint recognition_cycles_one_per_month
    unique (organisation_id, period_month),
  -- Composite target for ballots.
  constraint recognition_cycles_tenant_key unique (organisation_id, id),

  constraint recognition_cycles_window_ordered
    check (opens_at is null or closes_at is null or closes_at > opens_at),

  -- This is what makes the "no window in which a populated winner is visible on
  -- an unrevealed cycle" argument in the threat model structurally true rather
  -- than a promise about how the reveal function happens to be written. Members
  -- can read this table, so if winner columns could be populated before status
  -- flipped, FR-RESULT-01 would break for exactly as long as that gap lasted.
  constraint recognition_cycles_winner_only_when_revealed
    check (
      (
        status = 'revealed'
        and winner_participant_id is not null
        and winner_name is not null
        and winner_nominations is not null
        and revealed_at is not null
      )
      or (
        status <> 'revealed'
        and winner_participant_id is null
        and winner_name is null
        and winner_nominations is null
        and revealed_at is null
        and tie_decision_note is null
      )
    )
);

comment on table public.recognition_cycles is
  'One per organisation per calendar month. Winner columns are readable by '
  'members, which is safe only because a CHECK constraint ties their presence '
  'to the revealed status.';

comment on column public.recognition_cycles.winner_participant_id is
  'Snapshot reference, intentionally not a foreign key. A participant deleted '
  'later must not cascade into a historic result.';

alter table public.recognition_cycles enable row level security;

create trigger recognition_cycles_set_updated_at
  before update on public.recognition_cycles
  for each row execute function private.set_updated_at();

create trigger recognition_cycles_organisation_immutable
  before update on public.recognition_cycles
  for each row execute function private.forbid_organisation_change();

create index recognition_cycles_org_period_idx
  on public.recognition_cycles (organisation_id, period_month desc);

create index recognition_cycles_open_idx
  on public.recognition_cycles (closes_at)
  where status = 'open';

-- ---------------------------------------------------------------------------
-- recognition_nominations
-- ---------------------------------------------------------------------------
--
-- The table the whole threat model is about. No client role receives any grant
-- on it, including administrators. Reachable only through guarded functions.

create table public.recognition_nominations (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null
    references public.organisations (id) on delete cascade,
  cycle_id uuid not null,

  -- Integrity key. Enforces one ballot per voter and is never returned by any
  -- administrator-facing API.
  nominator_user_id uuid not null references auth.users (id) on delete cascade,

  -- Stored alongside the user id so that "no self-nomination" is a row-level
  -- CHECK rather than a trigger that reads another table. A constraint cannot
  -- be bypassed by a future function that forgets to call the check.
  nominator_participant_id uuid not null,
  nominee_participant_id uuid not null,

  reason text
    constraint recognition_nominations_reason_length
    check (reason is null or char_length(reason) <= 500),

  status text not null default 'active'
    constraint recognition_nominations_status
    check (status in ('active', 'hidden', 'withdrawn')),

  moderated_by uuid references auth.users (id) on delete set null,
  moderated_at timestamptz,
  moderation_reason text,

  -- Makes a retry after a dropped connection safe. Without it, a client that
  -- never saw the response can produce a second ballot.
  idempotency_key text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Tenant coherence for every end of the ballot.
  constraint recognition_nominations_cycle_fk
    foreign key (organisation_id, cycle_id)
    references public.recognition_cycles (organisation_id, id) on delete cascade,
  constraint recognition_nominations_nominator_fk
    foreign key (organisation_id, nominator_participant_id)
    references public.participants (organisation_id, id) on delete cascade,
  constraint recognition_nominations_nominee_fk
    foreign key (organisation_id, nominee_participant_id)
    references public.participants (organisation_id, id) on delete cascade,

  -- Invariant 9: one slot per voter per cycle. A recast updates this row rather
  -- than inserting a second, so the constraint holds throughout.
  constraint recognition_nominations_one_per_voter
    unique (organisation_id, cycle_id, nominator_user_id),

  -- Invariant 8.
  constraint recognition_nominations_no_self_vote
    check (nominee_participant_id <> nominator_participant_id),

  -- Hiding is a governance act and must carry a reason and an actor, so a
  -- moderated ballot can never be an unexplained disappearance.
  constraint recognition_nominations_moderation_complete
    check (
      status <> 'hidden'
      or (
        moderated_by is not null
        and moderated_at is not null
        and char_length(trim(coalesce(moderation_reason, ''))) > 0
      )
    )
);

comment on table public.recognition_nominations is
  'Confidential ballots. NO client role receives a grant on this table, not '
  'even admin or owner. The only route is a guarded function whose return '
  'shape excludes voter identity. See T1 in docs/SCHEMA_THREAT_MODEL.md.';

comment on column public.recognition_nominations.created_at is
  'Stored for integrity but never returned at this precision to an '
  'administrator. In a small team a precise timestamp identifies the voter.';

alter table public.recognition_nominations enable row level security;

create trigger recognition_nominations_set_updated_at
  before update on public.recognition_nominations
  for each row execute function private.set_updated_at();

create trigger recognition_nominations_organisation_immutable
  before update on public.recognition_nominations
  for each row execute function private.forbid_organisation_change();

-- The nominator's participant row must actually belong to the nominator. The
-- CHECK above compares two participant ids; this is what stops a caller passing
-- somebody else's participant id to sidestep it.
create or replace function private.assert_nominator_link()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.participants p
    where p.id = new.nominator_participant_id
      and p.organisation_id = new.organisation_id
      and p.user_id = new.nominator_user_id
  ) then
    raise exception
      'nominator_participant_id does not belong to nominator_user_id'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger recognition_nominations_assert_nominator
  before insert or update of nominator_participant_id, nominator_user_id
  on public.recognition_nominations
  for each row execute function private.assert_nominator_link();

create index recognition_nominations_tally_idx
  on public.recognition_nominations (cycle_id, nominee_participant_id)
  where status = 'active';

create unique index recognition_nominations_idempotency_idx
  on public.recognition_nominations (organisation_id, cycle_id, idempotency_key)
  where idempotency_key is not null;

-- ---------------------------------------------------------------------------
-- recognition_ballot_events
-- ---------------------------------------------------------------------------
--
-- Deliberately does NOT record who acted. D-024 accepted that a disputed
-- individual ballot cannot be investigated afterwards, on the grounds that an
-- audit trail able to reconstruct who voted for whom is the exact disclosure
-- this product exists to prevent. What remains useful is cycle-level activity:
-- how much recasting happened, and when, without naming anybody.

create table public.recognition_ballot_events (
  id bigint generated always as identity primary key,
  organisation_id uuid not null
    references public.organisations (id) on delete cascade,
  cycle_id uuid not null,
  event_type text not null
    constraint recognition_ballot_events_type
    check (event_type in ('cast', 'recast', 'withdrawn', 'hidden', 'restored')),
  occurred_at timestamptz not null default now(),

  constraint recognition_ballot_events_cycle_fk
    foreign key (organisation_id, cycle_id)
    references public.recognition_cycles (organisation_id, id) on delete cascade
);

comment on table public.recognition_ballot_events is
  'Cycle-level ballot activity with no actor column, by decision D-024. Adding '
  'a voter reference here would reintroduce the disclosure the ballot tables '
  'are designed to prevent.';

alter table public.recognition_ballot_events enable row level security;

create index recognition_ballot_events_cycle_idx
  on public.recognition_ballot_events (cycle_id, occurred_at);

-- ---------------------------------------------------------------------------
-- recognition_settings
-- ---------------------------------------------------------------------------

create table public.recognition_settings (
  organisation_id uuid primary key
    references public.organisations (id) on delete cascade,

  -- Null means indefinite retention, which D-012 allows as an explicit choice.
  -- The default is 12 months, the privacy-by-default position.
  retention_months integer default 12
    constraint recognition_settings_retention
    check (retention_months is null or retention_months in (3, 6, 12, 24)),

  push_reminders_default boolean not null default true,
  email_reminders_default boolean not null default true,
  criteria_template text
    constraint recognition_settings_criteria_length
    check (criteria_template is null or char_length(criteria_template) <= 2000),
  last_purge_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.recognition_settings enable row level security;

create trigger recognition_settings_set_updated_at
  before update on public.recognition_settings
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- audit_events
-- ---------------------------------------------------------------------------

create table public.audit_events (
  id bigint generated always as identity primary key,
  organisation_id uuid not null
    references public.organisations (id) on delete cascade,
  actor_user_id uuid references auth.users (id) on delete set null,
  action text not null
    constraint audit_events_action_length
    check (char_length(action) between 1 and 100),
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

comment on table public.audit_events is
  'Safe metadata only. A nomination-cast event identifies the cycle, never the '
  'voter or nominee. Winner reveal may name the winner, because that result is '
  'public inside the organisation. Enforced by the allowlist in DB-015.';

alter table public.audit_events enable row level security;

create index audit_events_org_idx
  on public.audit_events (organisation_id, occurred_at desc);

-- ---------------------------------------------------------------------------
-- device_push_tokens
-- ---------------------------------------------------------------------------

create table public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  organisation_id uuid references public.organisations (id) on delete cascade,
  token text not null unique,
  platform text not null default 'android'
    constraint device_push_tokens_platform
    check (platform in ('android', 'ios')),
  app_version text,
  last_seen_at timestamptz not null default now(),
  disabled_at timestamptz,
  last_result text,
  created_at timestamptz not null default now()
);

comment on table public.device_push_tokens is
  'Push tokens are personal data. No client grant: registration and revocation '
  'are functions.';

alter table public.device_push_tokens enable row level security;

create index device_push_tokens_user_idx
  on public.device_push_tokens (user_id)
  where disabled_at is null;

-- ---------------------------------------------------------------------------
-- notification_deliveries
-- ---------------------------------------------------------------------------

create table public.notification_deliveries (
  id bigint generated always as identity primary key,
  idempotency_key text not null unique,
  event_type text not null,
  user_id uuid references auth.users (id) on delete cascade,
  cycle_id uuid,
  channel text not null
    constraint notification_deliveries_channel
    check (channel in ('push', 'email')),
  attempt integer not null default 1,
  result text,
  error_code text,
  created_at timestamptz not null default now()
);

comment on table public.notification_deliveries is
  'Delivery bookkeeping. Carries no nomination or winner content. The unique '
  'idempotency key is what makes a retried reminder job safe to re-run.';

alter table public.notification_deliveries enable row level security;

-- ---------------------------------------------------------------------------
-- privacy_requests
-- ---------------------------------------------------------------------------

create table public.privacy_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  request_type text not null
    constraint privacy_requests_type
    check (request_type in ('export', 'deletion', 'rectification')),
  state text not null default 'received'
    constraint privacy_requests_state
    check (state in ('received', 'in_progress', 'completed', 'refused')),
  received_at timestamptz not null default now(),
  due_at timestamptz,
  completed_at timestamptz,
  operator_note text
);

comment on table public.privacy_requests is
  'Makes rights workflows traceable in the product. Does not replace a legal '
  'case system. user_id is nullable so a completed record survives the erasure '
  'it describes.';

alter table public.privacy_requests enable row level security;

create index privacy_requests_open_idx
  on public.privacy_requests (state, due_at)
  where state in ('received', 'in_progress');

-- ---------------------------------------------------------------------------
-- Fail closed
-- ---------------------------------------------------------------------------

revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
