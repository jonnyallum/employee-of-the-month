-- DB-006: grants and policies for the recognition tables.
--
-- The shortest migration in the project and the most important one, because
-- most of it is deliberately absent. Six of the eight tables below receive no
-- grant at all.
--
-- The temptation with a table like recognition_nominations is to grant SELECT
-- and write a clever policy: admins see rows but not certain columns, or rows
-- only after close. Every version of that is weaker than granting nothing,
-- because it means PostgREST can reach the table and the only thing standing
-- between an administrator and a voter identity is the correctness of an
-- expression. Column privileges cannot vary by cycle state, and a policy cannot
-- hide a column at all. So: no grant. The only route is a function whose return
-- type physically cannot carry the voter.

-- ---------------------------------------------------------------------------
-- recognition_cycles: members read their organisation's cycles
-- ---------------------------------------------------------------------------
--
-- Full-column SELECT, including the winner columns, which is safe only because
-- DB-003 constrains winner data to exist if and only if status is 'revealed'.
-- Without that constraint this grant would break FR-RESULT-01 for as long as a
-- gap existed between writing a winner and flipping the status.

grant select on public.recognition_cycles to authenticated;

create policy recognition_cycles_select_member
  on public.recognition_cycles for select to authenticated
  using (private.is_org_member(organisation_id));

-- Cycle creation, transition and reveal are guarded functions with optimistic
-- concurrency, so no INSERT or UPDATE grant exists here.

-- ---------------------------------------------------------------------------
-- recognition_settings: the transparency subset
-- ---------------------------------------------------------------------------
--
-- Retention is a promise made to employees about their own data, so members can
-- read it rather than having to take it on trust. Operational fields stay out.

grant select (
  organisation_id,
  retention_months,
  criteria_template
) on public.recognition_settings to authenticated;

create policy recognition_settings_select_member
  on public.recognition_settings for select to authenticated
  using (private.is_org_member(organisation_id));

-- ---------------------------------------------------------------------------
-- Everything below receives NO grant
-- ---------------------------------------------------------------------------
--
-- recognition_nominations     T1. Holds nominator_user_id. Not readable by
--                             members, admins or owners through any table
--                             route. Guarded functions only, from DB-010.
-- recognition_ballot_events   Cycle-level activity. Nothing here is needed by a
--                             client, and volume plus timing is itself a signal.
-- audit_events                Actor and entity references invite inference.
--                             Administrator views come from a shaped function.
-- device_push_tokens          Personal data. Registration and revocation are
--                             functions, so no read case exists.
-- notification_deliveries     Server bookkeeping.
-- privacy_requests            A subject's request state is returned by a
--                             function that cannot disclose another subject's.
--
-- No policies are written for these. A policy would suggest the table is
-- reachable and filtered; it is not reachable.

-- ---------------------------------------------------------------------------
-- Re-assert the closed default
-- ---------------------------------------------------------------------------
--
-- Nothing above granted anything to anon, but stating it means a future
-- migration that adds a table cannot quietly inherit an open default, and the
-- invariant test that counts anon grants stays meaningful.

revoke all on all tables in schema public from anon;
revoke all on all functions in schema public from public, anon, authenticated;
