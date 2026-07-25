-- DB-002: identity, organisation and roster tables.
--
-- Implements the identity half of docs/SCHEMA_THREAT_MODEL.md. Recognition
-- tables are DB-003. Grants and policies are DB-005: this migration creates
-- every table in a FAIL-CLOSED state, with RLS enabled and no policy, so there
-- is never a moment where a table exists and is reachable. DB-005 then opens
-- exactly what the exposure matrix allows and nothing else.
--
-- Tenant coherence is structural rather than checked. Every child table carries
-- organisation_id and refers to its parent through a composite key
-- (organisation_id, id), so a row physically cannot point at another tenant's
-- row. That holds for direct SQL and for the service role, which is the point:
-- invariant 1 must survive a mistake in a trusted function, not only a hostile
-- client.

-- A note on FORCE ROW LEVEL SECURITY, which is deliberately not used here.
--
-- FORCE extends RLS to the table owner. On this platform it is a no-op, which
-- was checked against the database rather than reasoned about:
--
--   * postgres and service_role both carry BYPASSRLS, so they ignore RLS and
--     FORCE alike. A SECURITY DEFINER function owned by postgres still writes
--     freely under FORCE, which was confirmed by enabling FORCE on profiles and
--     watching the new-user trigger insert successfully anyway.
--   * anon and authenticated own nothing here, so owner-directed behaviour
--     never applies to them.
--
-- So FORCE would neither protect anything nor break anything. It is omitted
-- because a clause that looks like a control but changes no outcome is worse
-- than its absence: it invites the belief that something is guarded when the
-- guard is elsewhere.
--
-- ENABLE plus the absence of a grant is what actually closes the Data API, and
-- that was confirmed too: authenticated selecting from profiles returns
-- "permission denied for table profiles".

-- Schema for helpers that must never be reachable through the Data API. It is
-- created here so later migrations have somewhere safe to put things. Nothing
-- is granted USAGE on it, which is what keeps it unreachable.
create schema if not exists private;

revoke all on schema private from public;
revoke usage on schema private from anon, authenticated;

comment on schema private is
  'Not exposed to the Data API. Policy helpers and internal functions only. '
  'Never grant USAGE to anon or authenticated.';

-- ---------------------------------------------------------------------------
-- Shared trigger functions
-- ---------------------------------------------------------------------------

-- search_path is pinned empty and every reference is schema-qualified, so a
-- caller cannot shadow a referenced object with a temporary one.
create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Invariant 2: organisation_id is immutable after insert. Without this, a row
-- can be walked from one tenant into another by update, which defeats every
-- policy that trusts the column.
create or replace function private.forbid_organisation_change()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.organisation_id is distinct from old.organisation_id then
    raise exception
      'organisation_id is immutable (table %)', tg_table_name
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

-- A CHECK constraint cannot consult pg_timezone_names, because the lookup is
-- not immutable. A trigger can, and rejecting an unknown timezone at write time
-- is what stops a cycle rendering its dates in a zone that does not exist.
create or replace function private.assert_known_timezone()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not exists (
    select 1 from pg_catalog.pg_timezone_names where name = new.timezone
  ) then
    raise exception 'unknown IANA timezone: %', new.timezone
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null
    constraint profiles_display_name_length
    check (char_length(display_name) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Account-level display name. Co-worker names come from participants, so no '
  'cross-user read of this table is required.';

alter table public.profiles enable row level security;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

-- The exposure matrix grants SELECT and UPDATE on profiles but not INSERT, so
-- without this the table could never be populated. Creating the row alongside
-- the auth user also means no code path has to cope with a signed-in user that
-- has no profile.
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id, display_name)
  values (
    new.id,
    -- Never trust user metadata for authorisation, but a display name is not
    -- an authorisation decision. Fall back to the local part of the email so
    -- the value is always present and never empty.
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'New member'
    )
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------
-- organisations
-- ---------------------------------------------------------------------------

create table public.organisations (
  id uuid primary key default gen_random_uuid(),
  name text not null
    constraint organisations_name_length
    check (char_length(trim(name)) between 1 and 100),
  timezone text not null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

comment on table public.organisations is 'Tenant boundary.';

alter table public.organisations enable row level security;

create trigger organisations_set_updated_at
  before update on public.organisations
  for each row execute function private.set_updated_at();

create trigger organisations_assert_timezone
  before insert or update of timezone on public.organisations
  for each row execute function private.assert_known_timezone();

-- ---------------------------------------------------------------------------
-- organisation_members
-- ---------------------------------------------------------------------------

create table public.organisation_members (
  organisation_id uuid not null
    references public.organisations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null
    constraint organisation_members_role
    check (role in ('owner', 'admin', 'member')),
  status text not null default 'active'
    constraint organisation_members_status
    check (status in ('active', 'suspended', 'left')),
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (organisation_id, user_id)
);

comment on table public.organisation_members is
  'The only source of authorisation. Never authorise from JWT claims or '
  'raw_user_meta_data: claims go stale for up to an hour and metadata is '
  'user-editable. Reading this table live is what makes removal take effect '
  'on the next request.';

alter table public.organisation_members enable row level security;

create trigger organisation_members_set_updated_at
  before update on public.organisation_members
  for each row execute function private.set_updated_at();

-- organisation_id is part of the primary key here, but an update can still
-- change a primary key, so the same immutability rule applies.
create trigger organisation_members_organisation_immutable
  before update on public.organisation_members
  for each row execute function private.forbid_organisation_change();

-- Every policy asks "which organisations is this user in", so the lookup is
-- user-first. The primary key is organisation-first and cannot serve it.
create index organisation_members_user_idx
  on public.organisation_members (user_id, organisation_id)
  where status = 'active';

-- ---------------------------------------------------------------------------
-- participants
-- ---------------------------------------------------------------------------

create table public.participants (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null
    references public.organisations (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  display_name text not null
    constraint participants_display_name_length
    check (char_length(trim(display_name)) between 1 and 80),
  team text
    constraint participants_team_length
    check (team is null or char_length(trim(team)) between 1 and 80),
  avatar_path text,
  active boolean not null default true,
  can_vote boolean not null default true,
  can_receive boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  left_at timestamptz,

  -- The composite target every child table points at. Without it, a child row
  -- could reference a participant in a different tenant.
  constraint participants_tenant_key unique (organisation_id, id)
);

comment on table public.participants is
  'Programme roster. A participant exists before an account and may receive '
  'nominations while still invited.';

comment on column public.participants.user_id is
  'Set only by guarded invitation acceptance. Withheld from the client column '
  'grant so a member cannot join a roster name to an auth identity.';

comment on column public.participants.can_vote is
  'Withheld from the client column grant: knowing who is eligible to vote '
  'narrows the set of possible authors of a given reason.';

alter table public.participants enable row level security;

create trigger participants_set_updated_at
  before update on public.participants
  for each row execute function private.set_updated_at();

create trigger participants_organisation_immutable
  before update on public.participants
  for each row execute function private.forbid_organisation_change();

-- One live link per user per organisation. Partial, so historic rows left
-- behind by someone who left do not block them rejoining later.
create unique index participants_one_active_link_idx
  on public.participants (organisation_id, user_id)
  where user_id is not null and left_at is null;

create index participants_roster_idx
  on public.participants (organisation_id)
  where active;

create index participants_user_idx
  on public.participants (user_id)
  where user_id is not null;

-- ---------------------------------------------------------------------------
-- organisation_invitations
-- ---------------------------------------------------------------------------

create table public.organisation_invitations (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null
    references public.organisations (id) on delete cascade,
  participant_id uuid not null,
  email_normalised text not null
    constraint organisation_invitations_email_shape
    check (
      email_normalised = lower(trim(email_normalised))
      and char_length(email_normalised) between 3 and 320
      and position('@' in email_normalised) > 1
    ),
  -- Only ever a SHA-256 hex digest. Storing a usable token would mean a read
  -- of this table yields account takeover of every invited identity.
  token_hash text not null unique
    constraint organisation_invitations_token_hash_shape
    check (token_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),

  -- Tenant coherence: the participant must belong to the same organisation as
  -- the invitation. Enforced by the key, not by a check in application code.
  constraint organisation_invitations_participant_fk
    foreign key (organisation_id, participant_id)
    references public.participants (organisation_id, id) on delete cascade,

  -- An invitation cannot be both accepted and revoked.
  constraint organisation_invitations_terminal_state
    check (accepted_at is null or revoked_at is null)
);

comment on table public.organisation_invitations is
  'Single-use invitations. Holds email_normalised and token_hash, so no client '
  'role receives any grant on this table. Redemption is a guarded function.';

alter table public.organisation_invitations enable row level security;

-- At most one outstanding invitation per participant, so reissuing cannot
-- leave two live tokens for the same person.
create unique index organisation_invitations_one_live_idx
  on public.organisation_invitations (organisation_id, participant_id)
  where accepted_at is null and revoked_at is null;

create index organisation_invitations_org_idx
  on public.organisation_invitations (organisation_id);

-- Supports the hourly expiry job without scanning consumed invitations.
create index organisation_invitations_expiry_idx
  on public.organisation_invitations (expires_at)
  where accepted_at is null and revoked_at is null;

-- ---------------------------------------------------------------------------
-- Fail closed
-- ---------------------------------------------------------------------------

-- Supabase no longer auto-exposes new tables, but stating it is cheap and means
-- the migration is correct even if that default is ever reverted or the schema
-- is replayed onto an older project. DB-005 grants back exactly what the
-- exposure matrix allows.
revoke all on all tables in schema public from anon, authenticated;

-- Postgres grants EXECUTE on new functions to PUBLIC by default, which would
-- make every helper reachable by an unauthenticated caller.
revoke all on all functions in schema private from public, anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
