-- DB-010 and DB-011: casting, withdrawing and reading your own ballot.
--
-- The table already refuses a self-nomination, a second ballot per voter, a
-- cross-tenant nominee and an incoherent nominator link. Those are constraints
-- and they hold against direct SQL. What these functions add is everything that
-- depends on state rather than shape: the cycle must be open, the voter must be
-- eligible right now, and a recast must reuse the voter's single slot rather
-- than creating a second one.
--
-- Note what is absent: no function here tells anyone how anybody else voted,
-- and get_my_nomination is scoped to auth.uid() rather than taking a voter as
-- an argument, so there is no shape of call that returns another person's
-- ballot.

-- ---------------------------------------------------------------------------
-- cast_nomination
-- ---------------------------------------------------------------------------

create or replace function public.cast_nomination(
  target_cycle_id uuid,
  nominee_participant_id uuid,
  reason text default null,
  idempotency_key text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  cyc record;
  voter_participant uuid;
  voter_can_vote boolean;
  nominee record;
  existing record;
  cleaned_reason text;
  ballot_id uuid;
  was_recast boolean := false;
begin
  if caller is null then
    raise exception 'sign in before making a nomination'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select * into cyc
  from public.recognition_cycles c
  where c.id = target_cycle_id;

  -- Membership is checked before anything about the cycle is revealed, so a
  -- stranger with a guessed cycle id learns nothing about whether it exists.
  if cyc.id is null or not private.is_org_member(cyc.organisation_id) then
    raise exception 'cycle not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if cyc.status <> 'open' then
    raise exception 'nominations are not open'
      using errcode = '22023', hint = 'cycle_not_open';
  end if;

  select p.id, p.can_vote into voter_participant, voter_can_vote
  from public.participants p
  where p.organisation_id = cyc.organisation_id
    and p.user_id = caller
    and p.active
    and p.left_at is null;

  if voter_participant is null then
    raise exception 'you are not on this organisation''s roster'
      using errcode = '42501', hint = 'not_on_roster';
  end if;

  if not voter_can_vote then
    raise exception 'you are not eligible to vote in this cycle'
      using errcode = '42501', hint = 'not_eligible_to_vote';
  end if;

  select p.* into nominee
  from public.participants p
  where p.id = nominee_participant_id
    and p.organisation_id = cyc.organisation_id;

  -- Same error for a nominee in another tenant and one that does not exist, so
  -- this cannot be used to test whether a participant id is real.
  if nominee.id is null then
    raise exception 'that colleague is not on this organisation''s roster'
      using errcode = '42501', hint = 'nominee_not_found';
  end if;

  if not (nominee.active and nominee.can_receive) then
    raise exception 'that colleague is not eligible to receive nominations'
      using errcode = '22023', hint = 'nominee_not_eligible';
  end if;

  if nominee.id = voter_participant then
    raise exception 'you cannot nominate yourself'
      using errcode = '22023', hint = 'self_nomination';
  end if;

  cleaned_reason := nullif(regexp_replace(trim(coalesce(reason, '')), '\s+', ' ', 'g'), '');
  if cleaned_reason is not null and char_length(cleaned_reason) > 500 then
    raise exception 'keep the reason to 500 characters or fewer'
      using errcode = '22023', hint = 'reason_too_long';
  end if;

  -- The voter's single slot, locked for the rest of the transaction so a
  -- double-tap cannot produce two ballots.
  select * into existing
  from public.recognition_nominations n
  where n.organisation_id = cyc.organisation_id
    and n.cycle_id = target_cycle_id
    and n.nominator_user_id = caller
  for update;

  -- A retry after a dropped connection resends the same key. Returning the
  -- original ballot rather than an error is what makes the client's retry safe.
  -- Parameters here are qualified with the function name throughout. Several
  -- share a name with a column of recognition_nominations, and an unqualified
  -- reference inside a statement that also has the table in scope is rejected
  -- as ambiguous. Renaming the parameters would have avoided it, at the cost of
  -- an RPC whose argument names no longer match the field they set.
  if existing.id is not null
     and cast_nomination.idempotency_key is not null
     and existing.idempotency_key is not distinct from cast_nomination.idempotency_key then
    return existing.id;
  end if;

  if existing.id is not null and existing.status = 'active' then
    raise exception 'you have already nominated someone this month'
      using errcode = '23505', hint = 'already_nominated';
  end if;

  if existing.id is null then
    insert into public.recognition_nominations
      (organisation_id, cycle_id, nominator_user_id, nominator_participant_id,
       nominee_participant_id, reason, status, idempotency_key)
    values (cyc.organisation_id, target_cycle_id, caller, voter_participant,
            nominee.id, cleaned_reason, 'active', cast_nomination.idempotency_key)
    returning id into ballot_id;
  else
    -- Recast. Reusing the withdrawn row keeps one slot per voter, which is what
    -- makes "withdraw then vote again" impossible to turn into two ballots.
    update public.recognition_nominations n
    set nominee_participant_id = nominee.id,
        reason = cleaned_reason,
        status = 'active',
        idempotency_key = coalesce(cast_nomination.idempotency_key, n.idempotency_key),
        moderated_by = null,
        moderated_at = null,
        moderation_reason = null
    where n.id = existing.id
    returning n.id into ballot_id;
    was_recast := true;
  end if;

  -- Cycle-level only, with no actor, per D-024.
  insert into public.recognition_ballot_events
    (organisation_id, cycle_id, event_type)
  values (cyc.organisation_id, target_cycle_id,
          case when was_recast then 'recast' else 'cast' end);

  return ballot_id;
end;
$$;

comment on function public.cast_nomination(uuid, uuid, text, text) is
  'Casts or recasts the caller''s single ballot. The voter is taken from '
  'auth.uid(), never an argument, so nobody can vote on another person''s '
  'behalf.';

revoke all on function public.cast_nomination(uuid, uuid, text, text) from public, anon;
grant execute on function public.cast_nomination(uuid, uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- withdraw_nomination
-- ---------------------------------------------------------------------------
--
-- Withdrawing marks the row rather than deleting it, so the voter keeps their
-- slot and the unique constraint continues to hold. A withdrawn ballot is
-- excluded from turnout and tally by the status filter, so it counts for
-- nothing while still preventing a second one.

create or replace function public.withdraw_nomination(target_cycle_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  cyc record;
  existing record;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select * into cyc
  from public.recognition_cycles c where c.id = target_cycle_id;

  if cyc.id is null or not private.is_org_member(cyc.organisation_id) then
    raise exception 'cycle not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if cyc.status <> 'open' then
    raise exception 'nominations are closed, so this can no longer be changed'
      using errcode = '22023', hint = 'cycle_not_open';
  end if;

  select * into existing
  from public.recognition_nominations n
  where n.organisation_id = cyc.organisation_id
    and n.cycle_id = target_cycle_id
    and n.nominator_user_id = caller
  for update;

  if existing.id is null or existing.status <> 'active' then
    raise exception 'you have no nomination to withdraw'
      using errcode = '22023', hint = 'no_nomination';
  end if;

  update public.recognition_nominations
  set status = 'withdrawn'
  where id = existing.id;

  insert into public.recognition_ballot_events
    (organisation_id, cycle_id, event_type)
  values (cyc.organisation_id, target_cycle_id, 'withdrawn');
end;
$$;

revoke all on function public.withdraw_nomination(uuid) from public, anon;
grant execute on function public.withdraw_nomination(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- get_my_nomination (DB-011)
-- ---------------------------------------------------------------------------
--
-- The only read path into the ballot table available to any client, and it is
-- scoped to auth.uid() by construction. It takes no voter argument, so there is
-- no call that returns somebody else's ballot: not a wrong one, not a guessed
-- one, none.
--
-- The return type omits nominator_user_id even though the caller is the
-- nominator. Shaping the type to carry only what the screen needs means a
-- future change to the caller cannot accidentally start returning identity.

create or replace function public.get_my_nomination(target_cycle_id uuid)
returns table (
  id uuid,
  nominee_participant_id uuid,
  nominee_display_name text,
  reason text,
  status text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select n.id,
         n.nominee_participant_id,
         p.display_name,
         n.reason,
         n.status,
         n.created_at
  from public.recognition_nominations n
  join public.participants p
    on p.id = n.nominee_participant_id
   and p.organisation_id = n.organisation_id
  where n.cycle_id = target_cycle_id
    and n.nominator_user_id = (select auth.uid())
    and n.status <> 'withdrawn';
$$;

comment on function public.get_my_nomination(uuid) is
  'Returns only the caller''s own ballot. Takes no voter argument, so no call '
  'shape exists that could return another person''s.';

revoke all on function public.get_my_nomination(uuid) from public, anon;
grant execute on function public.get_my_nomination(uuid) to authenticated;
