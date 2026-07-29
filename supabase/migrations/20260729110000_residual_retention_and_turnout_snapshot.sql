-- D-036: give the residual ballot row an end date.
--
-- D-027 severed the nominee link at purge but left the row: a permanent record
-- that a named person voted in a named month, kept forever because nothing in
-- the product ever deletes a cycle. "Retained indefinitely" is the phrase the
-- legal review warned is hard to defend, so the row now has a death date the
-- customer chooses.
--
-- The residual row is still doing one job that matters, which is why this could
-- not simply be a delete: `get_cycle_turnout` counts those rows. Deleting them
-- would rewrite historic turnout to zero, which is exactly the mistake the
-- tally snapshot was added to prevent. So turnout is snapshotted first.
--
-- Deviation from the ruling, deliberate and recorded: the ruling said the row
-- "should die with the cycle". Taken literally that means deleting revealed
-- cycles, which would destroy the winner name, the standings and the award
-- history that D-023 says survives even an erasure request. The substance of
-- the ruling is that retention must not be indefinite, and that is what this
-- delivers. The cycle lives; the ballot rows do not.

-- ---------------------------------------------------------------------------
-- Turnout becomes a snapshot
-- ---------------------------------------------------------------------------
--
-- This also fixes a bug that predates D-036. `get_cycle_turnout` computes
-- eligible voters from the CURRENT roster, so hiring or deactivating somebody
-- today silently rewrites the turnout percentage of every past month. A figure
-- an administrator may have reported to their board should not move because
-- somebody left.

alter table public.recognition_cycles
  add column if not exists turnout_eligible integer,
  add column if not exists turnout_ballots integer;

comment on column public.recognition_cycles.turnout_eligible is
  'Eligible voters as at reveal. Frozen because turnout computed from the live '
  'roster changes retrospectively when anybody joins or leaves.';

comment on column public.recognition_cycles.turnout_ballots is
  'Counted ballots as at reveal. Outlives the ballot rows, which D-036 deletes '
  'once past the residual retention period.';

-- ---------------------------------------------------------------------------
-- The customer chooses how long the residual row lives
-- ---------------------------------------------------------------------------
--
-- Same shape as `retention_months`, including allowing null for indefinite.
-- That is consistent with D-012, which already lets a controller choose
-- indefinite retention of the far more sensitive reason text. The objection the
-- review raised was that we retained forever by design with no option, not that
-- a controller may never choose it. Defaulted to 24 months so the safe answer
-- is the one nobody has to think about.

alter table public.recognition_settings
  add column if not exists residual_retention_months integer default 24;

alter table public.recognition_settings
  drop constraint if exists recognition_settings_residual_retention;

alter table public.recognition_settings
  add constraint recognition_settings_residual_retention
  check (residual_retention_months is null
         or residual_retention_months in (12, 24, 36, 60));

comment on column public.recognition_settings.residual_retention_months is
  'How long the purged ballot row survives after its reason and nominee link '
  'were removed. Null means indefinite, which is the controller''s call to '
  'defend under Article 5(1)(e).';

-- Existing rows predate the column default, so set them explicitly rather than
-- leaving live customers on the indefinite behaviour this migration exists to
-- end.
update public.recognition_settings
set residual_retention_months = 24
where residual_retention_months is null;

-- ---------------------------------------------------------------------------
-- Reveal records turnout alongside the tally
-- ---------------------------------------------------------------------------

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
  snapshot jsonb;
  eligible integer;
  counted integer;
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

  select max(t.nominations) into top_count
  from private.cycle_tally(target_cycle_id) t;

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

  -- D-027: the tally, taken while the links still exist.
  select jsonb_agg(jsonb_build_object(
           'participant_id', t.participant_id,
           'display_name', t.display_name,
           'nominations', t.nominations
         ) order by t.nominations desc, t.display_name)
    into snapshot
  from private.cycle_tally(target_cycle_id) t;

  -- D-036: turnout, taken for the same reason and against the roster as it
  -- stood, not as it will stand whenever somebody next asks.
  select count(*) into eligible
  from public.participants p
  where p.organisation_id = cyc.organisation_id
    and p.active and p.can_vote and p.user_id is not null;

  select count(*) into counted
  from public.recognition_nominations n
  where n.cycle_id = target_cycle_id and n.status = 'active';

  update public.recognition_cycles c
  set status = 'revealed',
      version = c.version + 1,
      winner_participant_id = chosen,
      winner_name = chosen_name,
      winner_nominations = top_count,
      tally_snapshot = snapshot,
      turnout_eligible = eligible,
      turnout_ballots = counted,
      tie_decision_note = case when leader_count > 1
                               then trim(decision_note) else null end,
      revealed_at = clock_timestamp(),
      revealed_by = caller
  where c.id = target_cycle_id;

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

revoke all on function public.reveal_winner(uuid, integer, uuid, text) from public, anon;
grant execute on function public.reveal_winner(uuid, integer, uuid, text) to authenticated;

-- Backfill, for the same reason D-027 backfilled the tally: the ballot rows
-- still exist now and will not once the second purge stage runs.
update public.recognition_cycles c
set turnout_eligible = coalesce(c.turnout_eligible, (
      select count(*) from public.participants p
      where p.organisation_id = c.organisation_id
        and p.active and p.can_vote and p.user_id is not null)),
    turnout_ballots = coalesce(c.turnout_ballots, (
      select count(*) from public.recognition_nominations n
      where n.cycle_id = c.id and n.status = 'active'))
where c.status = 'revealed'
  and (c.turnout_eligible is null or c.turnout_ballots is null);

-- ---------------------------------------------------------------------------
-- Turnout reads the snapshot once one exists
-- ---------------------------------------------------------------------------

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

  if cyc.turnout_eligible is not null and cyc.turnout_ballots is not null then
    eligible := cyc.turnout_eligible;
    counted := cyc.turnout_ballots;
  else
    -- A live or closed cycle has no snapshot yet, and should not: turnout is
    -- meant to move while voting is open.
    select count(*) into eligible
    from public.participants p
    where p.organisation_id = cyc.organisation_id
      and p.active and p.can_vote and p.user_id is not null;

    select count(*) into counted
    from public.recognition_nominations n
    where n.cycle_id = target_cycle_id and n.status = 'active';
  end if;

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
-- The purge gains a second stage
-- ---------------------------------------------------------------------------
--
-- Stage one severs, stage two deletes. They are separate because they answer
-- different questions and run on different clocks: the reason text and the
-- nominee link go at `retention_months`, and the residual row goes at
-- `residual_retention_months` measured from when it was severed.
--
-- The return type gains a `stage` column, so this is a drop and recreate rather
-- than a replace, and the grants are reapplied below.

drop function if exists public.purge_expired_nominations(boolean);

create function public.purge_expired_nominations(
  dry_run boolean default true
)
returns table (
  stage text,
  organisation_id uuid,
  cycle_id uuid,
  period_month date,
  nominations_affected integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected integer;
  target record;
begin
  -- Stage one: sever the reason and the nominee link (D-027).
  for target in
    select c.id, c.organisation_id, c.period_month
    from public.recognition_cycles c
    join public.recognition_settings s
      on s.organisation_id = c.organisation_id
    where c.status = 'revealed'
      and c.revealed_at is not null
      and s.retention_months is not null
      and c.revealed_at < now() - (s.retention_months * interval '1 month')
      and exists (
        select 1 from public.recognition_nominations n
        where n.cycle_id = c.id and n.purged_at is null
      )
  loop
    select count(*) into affected
    from public.recognition_nominations n
    where n.cycle_id = target.id and n.purged_at is null;

    if not dry_run then
      update public.recognition_nominations n
      set reason = null,
          nominee_participant_id = null,
          purged_at = clock_timestamp()
      where n.cycle_id = target.id and n.purged_at is null;

      insert into public.audit_events
        (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
      values (target.organisation_id, null, 'retention_purge', 'cycle',
              target.id::text,
              jsonb_build_object('nominations_affected', affected,
                                 'link_severed', true));
    end if;

    stage := 'severed';
    organisation_id := target.organisation_id;
    cycle_id := target.id;
    period_month := target.period_month;
    nominations_affected := affected;
    return next;
  end loop;

  -- Stage two: delete the residual row (D-036).
  --
  -- Guarded on the turnout snapshot existing. If it does not, deleting the rows
  -- would take historic turnout to zero, so the safe failure is to leave the
  -- rows alone and let somebody notice, rather than to destroy the figure.
  for target in
    select c.id, c.organisation_id, c.period_month
    from public.recognition_cycles c
    join public.recognition_settings s
      on s.organisation_id = c.organisation_id
    where c.status = 'revealed'
      and s.residual_retention_months is not null
      and c.turnout_ballots is not null
      and exists (
        select 1 from public.recognition_nominations n
        where n.cycle_id = c.id
          and n.purged_at is not null
          and n.purged_at
              < now() - (s.residual_retention_months * interval '1 month')
      )
  loop
    select count(*) into affected
    from public.recognition_nominations n
    join public.recognition_settings s
      on s.organisation_id = n.organisation_id
    where n.cycle_id = target.id
      and n.purged_at is not null
      and n.purged_at < now() - (s.residual_retention_months * interval '1 month');

    if not dry_run then
      delete from public.recognition_nominations n
      using public.recognition_settings s
      where s.organisation_id = n.organisation_id
        and n.cycle_id = target.id
        and n.purged_at is not null
        and n.purged_at
            < now() - (s.residual_retention_months * interval '1 month');

      insert into public.audit_events
        (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
      values (target.organisation_id, null, 'residual_deleted', 'cycle',
              target.id::text,
              jsonb_build_object('nominations_affected', affected));
    end if;

    stage := 'deleted';
    organisation_id := target.organisation_id;
    cycle_id := target.id;
    period_month := target.period_month;
    nominations_affected := affected;
    return next;
  end loop;
end;
$$;

revoke all on function public.purge_expired_nominations(boolean)
  from public, anon, authenticated;
grant execute on function public.purge_expired_nominations(boolean) to service_role;

comment on function public.purge_expired_nominations(boolean) is
  'Two stages. Severed: reason and nominee link cleared at retention_months '
  '(D-027). Deleted: the residual row removed at residual_retention_months '
  'after severing (D-036). Stage two refuses to run without a turnout snapshot.';
