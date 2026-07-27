-- DB-012, DB-013, DB-014: the administrator's view of a cycle.
--
-- This is where the product promise is either kept or broken. An administrator
-- legitimately needs to moderate content, see turnout and reveal a winner. None
-- of those needs require knowing who voted for whom, and this migration is the
-- proof that they can be provided without it.
--
-- The recurring technique is that the RETURN TYPE does the work. A policy can
-- filter rows but cannot hide a column; a function's declared output can simply
-- not contain the field. If voter identity is not in the type, no bug in the
-- body can leak it, and a future change that tries to has to alter the
-- signature, which is visible in review.

-- ---------------------------------------------------------------------------
-- The tally, computed in exactly one place
-- ---------------------------------------------------------------------------
--
-- Both the standings view and the reveal need the same counts, and the reveal
-- validates a winner against them. If they were computed separately they could
-- disagree, and an administrator would be shown one result and told another was
-- revealed. One definition removes that possibility.
--
-- It lives in `private` and performs no authorisation of its own: every caller
-- is a function that has already established who is asking.

create or replace function private.cycle_tally(target_cycle_id uuid)
returns table (participant_id uuid, display_name text, nominations integer)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.display_name, count(n.id)::integer
  from public.recognition_cycles c
  join public.participants p
    on p.organisation_id = c.organisation_id
   and p.can_receive
  left join public.recognition_nominations n
    on n.nominee_participant_id = p.id
   and n.cycle_id = c.id
   and n.status = 'active'
  where c.id = target_cycle_id
  group by p.id, p.display_name;
$$;

comment on function private.cycle_tally(uuid) is
  'Counts active ballots per eligible recipient. The single definition of the '
  'tally, so standings and reveal cannot disagree.';

-- Postgres grants EXECUTE to PUBLIC on every new function, and the blanket
-- revoke in the DB-004 migration only covered the functions that existed then.
-- Without this line `authenticated` could call the raw tally directly, which
-- returns per-nominee counts and would hand a member live standings while
-- voting is open. The exposure test in 001 caught it by name.
--
-- Nothing needs the grant: this is only ever called from SECURITY DEFINER
-- functions, which run as their owner.
revoke all on function private.cycle_tally(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- get_cycle_turnout (DB-014)
-- ---------------------------------------------------------------------------
--
-- FR-REPORT-01. Counts only. There is deliberately no variant that returns who
-- has or has not voted: the reminder job in COM-* may privately identify
-- non-voters in order to message them, but no interface may, because that turns
-- a recognition programme into an attendance monitor.

create or replace function public.get_cycle_turnout(target_cycle_id uuid)
returns table (
  eligible_voters integer,
  ballots_counted integer,
  turnout_percent integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  cyc record;
  eligible integer;
  counted integer;
begin
  select * into cyc from public.recognition_cycles c where c.id = target_cycle_id;

  if cyc.id is null
     or not private.has_org_role(cyc.organisation_id, array['owner', 'admin']) then
    raise exception 'cycle not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select count(*) into eligible
  from public.participants p
  where p.organisation_id = cyc.organisation_id
    and p.active and p.can_vote and p.user_id is not null;

  -- Hidden and withdrawn ballots are excluded, so a moderated ballot counts for
  -- nothing rather than inflating participation.
  select count(*) into counted
  from public.recognition_nominations n
  where n.cycle_id = target_cycle_id and n.status = 'active';

  return query select
    eligible,
    counted,
    case when eligible = 0 then 0
         else round((counted::numeric / eligible) * 100)::integer end;
end;
$$;

revoke all on function public.get_cycle_turnout(uuid) from public, anon;
grant execute on function public.get_cycle_turnout(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- get_admin_nominations (DB-012)
-- ---------------------------------------------------------------------------
--
-- The single most sensitive shape in the schema. Defined by what it excludes:
--
--   NOT returned: nominator_user_id, nominator_participant_id, created_at,
--                 updated_at, or any ordering that reflects insertion sequence.
--
-- created_date is truncated to the day. This is not decoration. In a team of
-- five, a timestamp accurate to the second, combined with knowing who was at
-- their desk, identifies an author. Results are ordered by nominee name then
-- nomination id, never by time, because a time-ordered list hands back exactly
-- the sequence that truncation was meant to remove.
--
-- D-014: reasons are not available while voting is open. In a small team the
-- act of a reason appearing shortly after a person was seen using their phone
-- is itself a signal, and there is no product need for live access.

create or replace function public.get_admin_nominations(target_cycle_id uuid)
returns table (
  id uuid,
  nominee_participant_id uuid,
  nominee_display_name text,
  reason text,
  status text,
  moderated_at timestamptz,
  moderation_reason text,
  created_date date
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  cyc record;
begin
  select * into cyc from public.recognition_cycles c where c.id = target_cycle_id;

  if cyc.id is null
     or not private.has_org_role(cyc.organisation_id, array['owner', 'admin']) then
    raise exception 'cycle not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if cyc.status in ('draft', 'open') then
    raise exception 'nomination reasons are available once voting has closed'
      using errcode = '22023', hint = 'cycle_still_open';
  end if;

  return query
    select n.id,
           n.nominee_participant_id,
           p.display_name,
           n.reason,
           n.status,
           n.moderated_at,
           n.moderation_reason,
           n.created_at::date
    from public.recognition_nominations n
    join public.participants p
      on p.id = n.nominee_participant_id
     and p.organisation_id = n.organisation_id
    where n.cycle_id = target_cycle_id
      and n.status <> 'withdrawn'
    order by p.display_name, n.id;
end;
$$;

comment on function public.get_admin_nominations(uuid) is
  'Moderation view. Its return type contains no voter reference and no precise '
  'timestamp, and it orders by name rather than time, so the sequence of '
  'voting cannot be reconstructed. See T1 and T2 in the threat model.';

revoke all on function public.get_admin_nominations(uuid) from public, anon;
grant execute on function public.get_admin_nominations(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- moderate_nomination (DB-012)
-- ---------------------------------------------------------------------------

create or replace function public.moderate_nomination(
  target_nomination_id uuid,
  action text,
  moderation_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  nom record;
  cyc record;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select * into nom
  from public.recognition_nominations n
  where n.id = target_nomination_id
  for update;

  if nom.id is null
     or not private.has_org_role(nom.organisation_id, array['owner', 'admin']) then
    raise exception 'nomination not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select * into cyc
  from public.recognition_cycles c where c.id = nom.cycle_id;

  -- A revealed result is a published fact. Changing what counted after the
  -- announcement would make the result unverifiable.
  if cyc.status = 'revealed' then
    raise exception 'this result has been revealed and can no longer be changed'
      using errcode = '22023', hint = 'cycle_revealed';
  end if;

  if action not in ('hide', 'restore') then
    raise exception 'action must be hide or restore'
      using errcode = '22023', hint = 'invalid_action';
  end if;

  if action = 'hide' then
    -- Required by the table constraint as well. Checked here to return a
    -- product error rather than a constraint name, and because a moderation
    -- with no recorded reason is an unexplained disappearance.
    if char_length(trim(coalesce(moderate_nomination.moderation_reason, ''))) = 0 then
      raise exception 'a reason is required when hiding a nomination'
        using errcode = '22023', hint = 'reason_required';
    end if;

    if nom.status <> 'active' then
      raise exception 'only an active nomination can be hidden'
        using errcode = '22023', hint = 'not_active';
    end if;

    update public.recognition_nominations n
    set status = 'hidden',
        moderated_by = caller,
        moderated_at = clock_timestamp(),
        moderation_reason = trim(moderate_nomination.moderation_reason)
    where n.id = target_nomination_id;
  else
    if nom.status <> 'hidden' then
      raise exception 'only a hidden nomination can be restored'
        using errcode = '22023', hint = 'not_hidden';
    end if;

    update public.recognition_nominations n
    set status = 'active',
        moderated_by = caller,
        moderated_at = clock_timestamp(),
        moderation_reason = trim(moderate_nomination.moderation_reason)
    where n.id = target_nomination_id;
  end if;

  insert into public.recognition_ballot_events
    (organisation_id, cycle_id, event_type)
  values (nom.organisation_id, nom.cycle_id,
          case when action = 'hide' then 'hidden' else 'restored' end);

  -- The audit entry names the cycle and the moderator, never the voter.
  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (nom.organisation_id, caller, 'nomination_moderated', 'cycle',
          nom.cycle_id::text, jsonb_build_object('action', action));
end;
$$;

revoke all on function public.moderate_nomination(uuid, text, text) from public, anon;
grant execute on function public.moderate_nomination(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- get_closed_standings (DB-013)
-- ---------------------------------------------------------------------------
--
-- FR-RESULT-01 forbids any ranking while a cycle is open, so this refuses
-- outright rather than returning an empty set: an empty result would be
-- indistinguishable from "nobody has voted", which is itself information.

create or replace function public.get_closed_standings(target_cycle_id uuid)
returns table (
  participant_id uuid,
  display_name text,
  nominations integer,
  rank integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  cyc record;
begin
  select * into cyc from public.recognition_cycles c where c.id = target_cycle_id;

  if cyc.id is null
     or not private.has_org_role(cyc.organisation_id, array['owner', 'admin']) then
    raise exception 'cycle not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if cyc.status in ('draft', 'open') then
    raise exception 'standings are not available while voting is open'
      using errcode = '22023', hint = 'cycle_still_open';
  end if;

  return query
    select t.participant_id,
           t.display_name,
           t.nominations,
           -- Shared competition ranks, matching the domain engine: two people
           -- tied on first are both rank 1 and the next is rank 3.
           rank() over (order by t.nominations desc)::integer
    from private.cycle_tally(target_cycle_id) t
    order by t.nominations desc, t.display_name;
end;
$$;

revoke all on function public.get_closed_standings(uuid) from public, anon;
grant execute on function public.get_closed_standings(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- reveal_winner (DB-013)
-- ---------------------------------------------------------------------------
--
-- Recomputes the tally inside its own transaction rather than trusting anything
-- the caller passes. The caller may name a winner, but only to break a tie, and
-- only from among the joint leaders. A clear leader cannot be overridden.

create or replace function public.reveal_winner(
  target_cycle_id uuid,
  expected_version integer,
  tied_participant_id uuid default null,
  decision_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  cyc record;
  top_count integer;
  leader_count integer;
  chosen uuid;
  chosen_name text;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select * into cyc
  from public.recognition_cycles c where c.id = target_cycle_id
  for update;

  if cyc.id is null
     or not private.has_org_role(cyc.organisation_id, array['owner', 'admin']) then
    raise exception 'cycle not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if cyc.version <> expected_version then
    raise exception 'this cycle changed since you loaded it'
      using errcode = '40001', hint = 'stale_version';
  end if;

  if cyc.status = 'revealed' then
    raise exception 'this result has already been revealed'
      using errcode = '22023', hint = 'cycle_revealed';
  end if;

  if cyc.status <> 'closed' then
    raise exception 'close nominations before revealing the result'
      using errcode = '22023', hint = 'cycle_not_closed';
  end if;

  -- The authoritative tally, from the one definition that standings also use,
  -- so an administrator cannot be shown one result and have another revealed.
  select max(t.nominations) into top_count
  from private.cycle_tally(target_cycle_id) t;

  -- FR-RESULT-03. A cycle nobody voted in has no winner, and inventing one
  -- would make the award meaningless.
  if top_count is null or top_count = 0 then
    raise exception 'nobody was nominated, so there is no result to reveal'
      using errcode = '22023', hint = 'no_ballots';
  end if;

  select count(*) into leader_count
  from private.cycle_tally(target_cycle_id) t
  where t.nominations = top_count;

  if leader_count = 1 then
    select t.participant_id, t.display_name into chosen, chosen_name
    from private.cycle_tally(target_cycle_id) t
    where t.nominations = top_count;

    -- A clear leader cannot be overridden. Allowing it would let an
    -- administrator quietly choose a different winner, which is the failure the
    -- whole product exists to avoid.
    if tied_participant_id is not null and tied_participant_id <> chosen then
      raise exception 'there is a clear winner, so another cannot be chosen'
        using errcode = '22023', hint = 'clear_leader';
    end if;
  else
    if tied_participant_id is null then
      raise exception 'this cycle is tied, so a winner must be chosen from the leaders'
        using errcode = '22023', hint = 'tie_requires_choice';
    end if;

    if char_length(trim(coalesce(decision_note, ''))) = 0 then
      raise exception 'a tie decision must be recorded with a note'
        using errcode = '22023', hint = 'tie_note_required';
    end if;

    select t.participant_id, t.display_name into chosen, chosen_name
    from private.cycle_tally(target_cycle_id) t
    where t.nominations = top_count
      and t.participant_id = tied_participant_id;

    if chosen is null then
      raise exception 'the chosen winner is not one of the joint leaders'
        using errcode = '22023', hint = 'tie_resolution_invalid';
    end if;
  end if;

  -- Status and the winner snapshot are written together, which the table
  -- constraint requires and which is what makes "no window where a populated
  -- winner sits on an unrevealed cycle" structurally true.
  update public.recognition_cycles c
  set status = 'revealed',
      version = c.version + 1,
      winner_participant_id = chosen,
      winner_name = chosen_name,
      winner_nominations = top_count,
      tie_decision_note = case when leader_count > 1
                               then trim(decision_note) else null end,
      revealed_at = clock_timestamp(),
      revealed_by = caller
  where c.id = target_cycle_id;

  -- A winner is public inside the organisation, so naming them here discloses
  -- nothing that the reveal itself does not.
  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (cyc.organisation_id, caller, 'winner_revealed', 'cycle',
          target_cycle_id::text,
          jsonb_build_object('winner_name', chosen_name,
                             'nominations', top_count,
                             'was_tie', leader_count > 1));

  return chosen;
end;
$$;

comment on function public.reveal_winner(uuid, integer, uuid, text) is
  'Recomputes the tally itself rather than trusting the caller. A clear leader '
  'cannot be overridden; a tie must be resolved from among the joint leaders '
  'and carry a decision note; a cycle with no ballots cannot be revealed.';

revoke all on function public.reveal_winner(uuid, integer, uuid, text) from public, anon;
grant execute on function public.reveal_winner(uuid, integer, uuid, text) to authenticated;
