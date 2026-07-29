-- Closes a leak introduced by D-027 and D-036.
--
-- Both migrations added columns to `recognition_cycles`. That table carries a
-- **table-level** SELECT grant to `authenticated`, and a table-level grant
-- covers columns added later. So `tally_snapshot`, `turnout_eligible` and
-- `turnout_ballots` became readable by every member the moment they were
-- created, without any migration saying so.
--
-- What that exposed:
--
--   * `tally_snapshot` holds every participant's name and nomination count for
--     every revealed cycle. That is the full standings, which `D-004` keeps
--     hidden while a cycle is open and which `get_closed_standings` gates to
--     owners and admins afterwards. A member could read the column directly and
--     skip the function.
--   * `turnout_eligible` and `turnout_ballots` are the figures behind
--     `get_cycle_turnout`, which has an explicit test asserting that a plain
--     member cannot see turnout. The columns contradicted the function.
--
-- Neither exposes who voted for whom. Both hand a member information the
-- product deliberately reserves to administrators.
--
-- The fix cannot be a column-level REVOKE. Postgres will accept the statement
-- and report REVOKE, but a table-level privilege still implies access to every
-- column, so the grant survives and the leak stays open. Verified before
-- writing this: the only thing that works is to revoke the table privilege and
-- re-grant the columns explicitly, which is what the threat model intended for
-- this table in the first place.

revoke select on public.recognition_cycles from authenticated;

grant select (
  id,
  organisation_id,
  period_month,
  status,
  criteria,
  version,
  leaderboard_mode,
  opens_at,
  closes_at,
  revealed_at,
  winner_participant_id,
  winner_name,
  winner_nominations,
  tie_decision_note,
  created_at,
  updated_at
) on public.recognition_cycles to authenticated;

-- Withheld deliberately, and each for its own reason:
--
--   tally_snapshot     the standings; admin-only via get_closed_standings
--   turnout_eligible   turnout; admin-only via get_cycle_turnout
--   turnout_ballots    the same
--   revealed_by        names the administrator who revealed a result. This one
--                      predates the leak above and was previously readable. No
--                      client code selects it, and it is the only column on
--                      this table that identifies a person, so it is being
--                      closed while the grant is being rewritten rather than
--                      left open because it happened to be open before.

comment on column public.recognition_cycles.tally_snapshot is
  'Per-nominee counts, written at reveal. This is what lets the nominee link be '
  'purged later without erasing the standings of every past month. Not granted '
  'to any client: it is the full standings, which get_closed_standings gates to '
  'owners and admins.';
