-- DB-009: cycle creation and state transitions.
--
-- The state machine is already a constraint at the table level. What a function
-- adds is the two things a constraint cannot do: refuse to open a cycle that
-- cannot produce a fair ballot, and stop two administrators overwriting each
-- other.

-- ---------------------------------------------------------------------------
-- create_cycle
-- ---------------------------------------------------------------------------

create or replace function public.create_cycle(
  target_organisation_id uuid,
  period date,
  criteria text default null,
  opens_at timestamptz default null,
  closes_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  normalised date;
  new_id uuid;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if not private.has_org_role(target_organisation_id, array['owner', 'admin']) then
    -- Identical error for "not an admin" and "no such organisation", so this
    -- cannot be used to discover which organisation ids exist.
    raise exception 'not permitted for this organisation'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  -- Normalise rather than reject a mid-month date. A caller passing the 15th
  -- means that month, and the table constraint requires the first, so doing it
  -- for them removes a pointless error without weakening the invariant.
  normalised := date_trunc('month', period)::date;

  if closes_at is not null and opens_at is not null and closes_at <= opens_at then
    raise exception 'a cycle cannot close before it opens'
      using errcode = '22023', hint = 'invalid_window';
  end if;

  begin
    insert into public.recognition_cycles
      (organisation_id, period_month, status, criteria, opens_at, closes_at)
    values (target_organisation_id, normalised, 'draft', criteria, opens_at, closes_at)
    returning id into new_id;
  exception when unique_violation then
    raise exception 'a cycle already exists for that month'
      using errcode = '23505', hint = 'cycle_exists';
  end;

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (target_organisation_id, caller, 'cycle_created', 'cycle', new_id::text,
          jsonb_build_object('period_month', normalised));

  return new_id;
end;
$$;

revoke all on function public.create_cycle(uuid, date, text, timestamptz, timestamptz)
  from public, anon;
grant execute on function public.create_cycle(uuid, date, text, timestamptz, timestamptz)
  to authenticated;

-- ---------------------------------------------------------------------------
-- transition_cycle
-- ---------------------------------------------------------------------------
--
-- expected_version is not optional. Two administrators looking at the same
-- screen can both press close, or one can close while the other reopens, and
-- without it the second write silently wins. With it the second caller gets a
-- deterministic failure and can be shown what actually happened.
--
-- 'revealed' is deliberately not reachable from here. Revealing requires
-- computing standings and validating a winner, which is DB-013.

create or replace function public.transition_cycle(
  target_cycle_id uuid,
  expected_version integer,
  next_status text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  cyc record;
  eligible_recipients integer;
  eligible_voters integer;
  new_version integer;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select * into cyc
  from public.recognition_cycles c
  where c.id = target_cycle_id
  for update;

  if cyc.id is null
     or not private.has_org_role(cyc.organisation_id, array['owner', 'admin']) then
    raise exception 'cycle not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if cyc.version <> expected_version then
    raise exception
      'this cycle changed since you loaded it (expected version %, found %)',
      expected_version, cyc.version
      using errcode = '40001', hint = 'stale_version';
  end if;

  if next_status = 'revealed' then
    raise exception 'use reveal_winner to reveal a result'
      using errcode = '22023', hint = 'use_reveal_winner';
  end if;

  -- The legal moves, matching CYCLE_TRANSITIONS in the domain engine. Kept
  -- explicit here rather than inferred, because this is the authoritative copy
  -- and the TypeScript one exists only to give earlier, clearer messages.
  if not (
       (cyc.status = 'draft'  and next_status = 'open')
    or (cyc.status = 'open'   and next_status = 'closed')
    or (cyc.status = 'closed' and next_status = 'open')
  ) then
    if cyc.status = 'revealed' then
      raise exception 'a revealed result is final'
        using errcode = '22023', hint = 'cycle_revealed';
    end if;
    raise exception 'a % cycle cannot become %', cyc.status, next_status
      using errcode = '22023', hint = 'illegal_transition';
  end if;

  -- FR-CYCLE-02. Opening a cycle nobody can vote in, or where the only
  -- nominee is the only voter, produces a ballot that cannot be fair. Better
  -- refused at the point of opening than discovered at close with no result.
  if next_status = 'open' then
    select count(*) into eligible_recipients
    from public.participants p
    where p.organisation_id = cyc.organisation_id
      and p.active and p.can_receive;

    select count(*) into eligible_voters
    from public.participants p
    where p.organisation_id = cyc.organisation_id
      and p.active and p.can_vote and p.user_id is not null;

    if eligible_recipients < 2 then
      raise exception 'at least two people must be eligible to receive a nomination'
        using errcode = '22023', hint = 'not_enough_recipients';
    end if;

    if eligible_voters < 1 then
      raise exception 'at least one person must be able to vote'
        using errcode = '22023', hint = 'no_eligible_voters';
    end if;
  end if;

  -- clock_timestamp(), not now(). now() returns the transaction start time and
  -- is therefore identical for every statement in a transaction, so opening and
  -- closing within one would stamp both with the same instant and violate the
  -- closes_at > opens_at constraint. It is also the more honest value: these
  -- record when the action happened, not when its transaction began.
  if next_status = 'closed' and cyc.opens_at is not null
     and clock_timestamp() <= cyc.opens_at then
    raise exception 'this cycle is not open yet, so it cannot be closed'
      using errcode = '22023', hint = 'not_yet_open';
  end if;

  update public.recognition_cycles c
  set status = next_status,
      version = c.version + 1,
      opens_at = case
        when next_status = 'open' and c.opens_at is null
        then clock_timestamp() else c.opens_at end,
      closes_at = case
        when next_status = 'closed' and c.closes_at is null
        then clock_timestamp() else c.closes_at end
  where c.id = target_cycle_id
  returning c.version into new_version;

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (cyc.organisation_id, caller, 'cycle_transitioned', 'cycle',
          target_cycle_id::text,
          jsonb_build_object('from', cyc.status, 'to', next_status));

  return new_version;
end;
$$;

comment on function public.transition_cycle(uuid, integer, text) is
  'Moves a cycle between states, refusing a stale expected_version so two '
  'administrators cannot overwrite each other. Opening validates that a fair '
  'ballot is possible. Revealing is reveal_winner, not this.';

revoke all on function public.transition_cycle(uuid, integer, text) from public, anon;
grant execute on function public.transition_cycle(uuid, integer, text) to authenticated;
