-- Schedules the retention purge and the deletion worker.
--
-- Both were written, tested and then left sitting there. A retention policy
-- that nothing runs is not a retention policy, it is a claim in a privacy
-- notice — and this product's notice already tells members their data is
-- deleted after a period the customer chose. The DPIA lists this as an open
-- item that must close before the first customer. This closes it.
--
-- Cadence and times are decisions rather than defaults, so they are recorded
-- here rather than only in a crontab expression:
--
--   * **Daily, not monthly.** Nothing here is time-critical to the hour, but a
--     monthly job leaves data up to 30 days past the retention the customer
--     selected and the notice promised. Daily makes the promise approximately
--     true instead of approximately false.
--   * **Erasure daily for a different reason.** Article 12(3) allows a month,
--     and the request record carries a 30-day due date, but the standard is
--     "without undue delay". A queue drained nightly meets that; a queue
--     drained when somebody remembers does not.
--   * **03:00 and 03:30 UTC.** Quiet for a UK working population, and half an
--     hour apart so the deletion worker is not competing with the purge for
--     locks on the same rows. Erasure runs second on purpose: it deletes
--     participants, which cascades ballots, and it is tidier to let the purge
--     finish its pass first.
--
-- Both are invoked with the destructive argument explicitly. `dry_run` defaults
-- to true on `purge_expired_nominations` precisely so that a careless caller
-- does nothing, which means a scheduled caller has to say `false` out loud.

create extension if not exists pg_cron;

-- pg_cron runs jobs as the user that scheduled them. These are SECURITY DEFINER
-- functions owned by postgres, so the scheduled job carries the privileges the
-- functions need without service_role credentials living in a cron entry.

-- Unscheduling first makes this migration safe to re-run, and safe to edit and
-- re-apply, which matters more than usual for a job that deletes things.
do $$
begin
  perform cron.unschedule('eotm-retention-purge');
exception when others then
  null;
end $$;

do $$
begin
  perform cron.unschedule('eotm-process-deletions');
exception when others then
  null;
end $$;

select cron.schedule(
  'eotm-retention-purge',
  '0 3 * * *',
  $$select public.purge_expired_nominations(false)$$
);

select cron.schedule(
  'eotm-process-deletions',
  '30 3 * * *',
  $$select public.process_deletion_requests(false)$$
);

-- ---------------------------------------------------------------------------
-- Making the jobs answerable
-- ---------------------------------------------------------------------------
--
-- A scheduled job that fails silently is worse than no scheduled job, because
-- the privacy notice keeps making the promise either way. `cron.job_run_details`
-- records every run, but it is not reachable by anything that would notice.
--
-- This view is for an operator, not for a customer: it is left ungranted, in
-- the same way as everything else in this schema, so reaching it requires the
-- trusted role deliberately.

create or replace view private.retention_job_health as
select j.jobname,
       d.status,
       d.start_time,
       d.end_time,
       d.return_message
from cron.job j
left join cron.job_run_details d on d.jobid = j.jobid
where j.jobname in ('eotm-retention-purge', 'eotm-process-deletions')
order by d.start_time desc nulls last;

comment on view private.retention_job_health is
  'Last runs of the two retention jobs. Operator-facing. A job that silently '
  'stopped running is the failure mode that matters here, because the privacy '
  'notice keeps promising deletion either way.';

revoke all on private.retention_job_health from public, anon, authenticated;
