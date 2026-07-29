-- PRV-010: the deletion worker.
--
-- `request_account_deletion` records a request and nothing carries it out. The
-- product has been promising erasure and queueing it, which is the gap this
-- closes.
--
-- Two things make this harder than "delete the user":
--
--   1. `participants.user_id` is ON DELETE SET NULL, not cascade. Deleting the
--      auth user leaves the roster row standing with the person's display name
--      on it. Erasure that leaves the name behind is not erasure, so the
--      participant rows are deleted explicitly and first.
--
--   2. `tally_snapshot`, added by D-027, names every participant in every
--      revealed cycle. Left alone, an erased person's name survives in the
--      standings of every month they were ever on the roster. D-023 decided a
--      *winner's* name survives erasure, and D-028 gives the controller a way
--      to redact even that - but a non-winner has no award to justify keeping
--      their name, so nothing covers this. It is scrubbed here.
--
-- What deliberately survives, per D-023: `winner_name` and `winner_nominations`
-- on a cycle the person won. The worker reports when that has happened so the
-- operator can tell them, and D-028's `redact_winner_snapshot` is the route if
-- the controller decides otherwise.

create or replace function public.process_deletion_requests(
  dry_run boolean default true
)
returns table (
  request_id uuid,
  subject_user_id uuid,
  outcome text,
  detail text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  req record;
  stranded text;
  wins integer;
  participants_removed integer;
  orgs uuid[];
begin
  for req in
    select p.id, p.user_id
    from public.privacy_requests p
    where p.request_type = 'deletion'
      and p.state in ('received', 'in_progress')
      and p.user_id is not null
    order by p.received_at
  loop
    -- Re-checked rather than trusted from request time. Ownership can change
    -- between asking and being processed, in both directions: somebody who was
    -- blocked at request time may now be free to go, and somebody who was free
    -- may have become the last owner standing.
    select string_agg(o.name, ', ') into stranded
    from public.organisation_members m
    join public.organisations o on o.id = m.organisation_id
    where m.user_id = req.user_id
      and m.role = 'owner'
      and m.status = 'active'
      and not exists (
        select 1 from public.organisation_members other
        where other.organisation_id = m.organisation_id
          and other.user_id <> req.user_id
          and other.role = 'owner'
          and other.status = 'active'
      );

    if stranded is not null then
      -- Refused, not skipped. A request that silently sits in the queue is how
      -- a statutory deadline gets missed.
      if not dry_run then
        update public.privacy_requests
        set state = 'refused',
            completed_at = clock_timestamp(),
            operator_note = 'Sole active owner of ' || stranded
              || '. Ownership must be transferred before erasure.'
        where id = req.id;
      end if;

      request_id := req.id;
      subject_user_id := req.user_id;
      outcome := 'refused_sole_owner';
      detail := stranded;
      return next;
      continue;
    end if;

    select array_agg(distinct m.organisation_id) into orgs
    from public.organisation_members m
    where m.user_id = req.user_id;

    select count(*) into wins
    from public.recognition_cycles c
    join public.participants p on p.id = c.winner_participant_id
    where p.user_id = req.user_id and c.status = 'revealed';

    select count(*) into participants_removed
    from public.participants p
    where p.user_id = req.user_id;

    if not dry_run then
      -- Audit first, while the organisations are still known. actor_user_id is
      -- ON DELETE SET NULL, so the event survives the person it describes.
      insert into public.audit_events
        (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
      select unnest(coalesce(orgs, '{}')), null, 'account_erased', 'user',
             req.user_id::text,
             jsonb_build_object('participants_removed', participants_removed,
                                'winner_records_retained', wins);

      -- The standings scrub. The count stays so the arithmetic of a past month
      -- still adds up; only the name and the id go.
      update public.recognition_cycles c
      set tally_snapshot = (
        select jsonb_agg(
          case when (e ->> 'participant_id')::uuid in (
                 select p.id from public.participants p
                 where p.user_id = req.user_id)
               then jsonb_build_object(
                      'participant_id', null,
                      'display_name', 'A former colleague',
                      'nominations', (e ->> 'nominations')::integer)
               else e end
          order by (e ->> 'nominations')::integer desc, e ->> 'display_name')
        from jsonb_array_elements(c.tally_snapshot) e)
      where c.tally_snapshot is not null
        and exists (
          select 1
          from jsonb_array_elements(c.tally_snapshot) e
          join public.participants p
            on p.id = (e ->> 'participant_id')::uuid
          where p.user_id = req.user_id);

      -- Explicitly, because the FK sets null rather than cascading. This also
      -- cascades their ballots, as nominator and as nominee. Revealed cycles
      -- are unaffected: their tallies and turnout were frozen at reveal, which
      -- is the reason D-027 and D-036 snapshotted them.
      delete from public.participants p where p.user_id = req.user_id;

      -- Cascades organisation_members, profiles, push tokens and delivery
      -- records; sets audit, invitation and reveal attributions to null.
      delete from auth.users u where u.id = req.user_id;

      -- privacy_requests.user_id is ON DELETE SET NULL, so this row survives
      -- the erasure it records. Addressed by id for that reason.
      update public.privacy_requests
      set state = 'completed',
          completed_at = clock_timestamp(),
          operator_note = case when wins > 0
            then 'Erased. ' || wins || ' award record(s) retained under D-023; '
                 || 'redact separately if the controller decides otherwise.'
            else 'Erased.' end
      where id = req.id;
    end if;

    request_id := req.id;
    subject_user_id := req.user_id;
    outcome := 'erased';
    detail := case when wins > 0
      then wins || ' award record(s) retained under D-023'
      else 'nothing retained' end;
    return next;
  end loop;
end;
$$;

revoke all on function public.process_deletion_requests(boolean)
  from public, anon, authenticated;
grant execute on function public.process_deletion_requests(boolean) to service_role;

comment on function public.process_deletion_requests(boolean) is
  'PRV-010. Carries out queued erasure requests. Deletes participant rows '
  'explicitly because the FK sets null rather than cascading, and scrubs the '
  'person from every tally snapshot. Retains winner name and count per D-023 '
  'and reports when it has. Refuses a sole active owner rather than stranding '
  'their colleagues.';
