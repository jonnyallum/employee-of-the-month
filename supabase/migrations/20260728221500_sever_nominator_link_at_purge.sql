-- D-027: sever the nominator-to-nominee link at purge.
--
-- What survives the purge today is a permanent map of who thought what about
-- whom, with the words removed and the meaning intact. `D-024` already decided
-- that artefact must not exist, so the purge was only doing half its job.
--
-- Three things have to move together, which is why this was deferred rather
-- than written blind:
--
--   1. The nominee link becomes nullable, so it can be cleared.
--   2. Standings must survive that, so reveal now snapshots the per-nominee
--      tally onto the cycle. Without this, purging would silently rewrite the
--      history of every past month to all-zeroes.
--   3. `purged_at` records the fact, and a constraint keeps the two in step so
--      a half-purged row cannot exist.
--
-- What is deliberately NOT removed: `nominator_user_id`. The one-vote guard is
-- `unique (organisation_id, cycle_id, nominator_user_id)` and it has to keep
-- working, so the fact that somebody voted survives. What goes is who they
-- chose, which is the part that made it a map.

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------

alter table public.recognition_cycles
  add column if not exists tally_snapshot jsonb;

comment on column public.recognition_cycles.tally_snapshot is
  'Per-nominee counts, written at reveal. This is what lets the nominee link be '
  'purged later without erasing the standings of every past month.';

alter table public.recognition_nominations
  add column if not exists purged_at timestamptz;

alter table public.recognition_nominations
  alter column nominee_participant_id drop not null;

-- The two must agree. A row with a nominee and a purge stamp, or with neither,
-- is a half-finished purge and should be impossible rather than merely unlikely.
alter table public.recognition_nominations
  drop constraint if exists recognition_nominations_purge_coherent;

alter table public.recognition_nominations
  add constraint recognition_nominations_purge_coherent
  check ((purged_at is null) = (nominee_participant_id is not null));

comment on column public.recognition_nominations.purged_at is
  'Set when the reason and the nominee link were cleared. nominator_user_id '
  'survives, because the one-vote unique constraint depends on it: the fact of '
  'a ballot remains, the choice does not.';

-- ---------------------------------------------------------------------------
-- Reveal now snapshots the tally
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

  -- D-027. Taken now, while the links still exist, because after the purge the
  -- counts cannot be recomputed. Names are stored alongside the ids so the
  -- standings still read properly once a participant is deleted.
  select jsonb_agg(jsonb_build_object(
           'participant_id', t.participant_id,
           'display_name', t.display_name,
           'nominations', t.nominations
         ) order by t.nominations desc, t.display_name)
    into snapshot
  from private.cycle_tally(target_cycle_id) t;

  update public.recognition_cycles c
  set status = 'revealed',
      version = c.version + 1,
      winner_participant_id = chosen,
      winner_name = chosen_name,
      winner_nominations = top_count,
      tally_snapshot = snapshot,
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

-- ---------------------------------------------------------------------------
-- Backfill
-- ---------------------------------------------------------------------------
--
-- Cycles revealed before this migration have no snapshot. Their links still
-- exist, so the tally can still be computed - but only until the first purge
-- runs, after which it is gone for good. Take it now, while it is still
-- possible. Without this, deploying D-027 and then running the purge would
-- silently blank the standings of every month revealed to date.

update public.recognition_cycles c
set tally_snapshot = (
  select jsonb_agg(jsonb_build_object(
           'participant_id', t.participant_id,
           'display_name', t.display_name,
           'nominations', t.nominations
         ) order by t.nominations desc, t.display_name)
  from private.cycle_tally(c.id) t
)
where c.status = 'revealed'
  and c.tally_snapshot is null;

-- ---------------------------------------------------------------------------
-- Standings read the snapshot once one exists
-- ---------------------------------------------------------------------------
--
-- A closed cycle has no snapshot yet, so it still computes live. A revealed one
-- reads what was recorded at reveal, which is the only thing that still works
-- after a purge.

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

  if cyc.tally_snapshot is not null then
    return query
      select (e ->> 'participant_id')::uuid,
             e ->> 'display_name',
             (e ->> 'nominations')::integer,
             rank() over (order by (e ->> 'nominations')::integer desc)::integer
      from jsonb_array_elements(cyc.tally_snapshot) e
      order by (e ->> 'nominations')::integer desc, e ->> 'display_name';
    return;
  end if;

  return query
    select t.participant_id, t.display_name, t.nominations,
           rank() over (order by t.nominations desc)::integer
    from private.cycle_tally(target_cycle_id) t
    order by t.nominations desc, t.display_name;
end;
$$;

revoke all on function public.get_closed_standings(uuid) from public, anon;
grant execute on function public.get_closed_standings(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- The purge now severs the link
-- ---------------------------------------------------------------------------

create or replace function public.purge_expired_nominations(
  dry_run boolean default true
)
returns table (
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
  for target in
    select c.id, c.organisation_id, c.period_month
    from public.recognition_cycles c
    join public.recognition_settings s
      on s.organisation_id = c.organisation_id
    where c.status = 'revealed'
      and c.revealed_at is not null
      and s.retention_months is not null
      and c.revealed_at < now() - (s.retention_months * interval '1 month')
      -- Now keyed on purged_at rather than on the reason being null. A cycle
      -- where every reason happened to be blank still has links to sever, and
      -- the old test would have skipped it.
      and exists (
        select 1 from public.recognition_nominations n
        where n.cycle_id = c.id and n.purged_at is null
      )
  loop
    select count(*) into affected
    from public.recognition_nominations n
    where n.cycle_id = target.id and n.purged_at is null;

    if not dry_run then
      -- The reason and the choice both go. nominator_user_id stays, because the
      -- one-vote unique constraint depends on it: the fact of a ballot is kept,
      -- the map of who chose whom is not.
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

-- ---------------------------------------------------------------------------
-- The moderation view skips purged rows
-- ---------------------------------------------------------------------------
--
-- A purged row has no reason and no nominee, so there is nothing to moderate
-- and nothing to display. Its inner join to participants would drop it anyway;
-- excluding it explicitly says why.

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
      and n.purged_at is null
    order by p.display_name, n.id;
end;
$$;

revoke all on function public.get_admin_nominations(uuid) from public, anon;
grant execute on function public.get_admin_nominations(uuid) to authenticated;
