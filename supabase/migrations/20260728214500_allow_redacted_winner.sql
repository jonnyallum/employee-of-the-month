-- Let a revealed winner be redacted.
--
-- `redact_winner_snapshot` (D-028) severs `winner_participant_id` so the name
-- cannot be recovered by joining back to the roster. The constraint written in
-- DB-003 refused that: it required the participant link to be present whenever
-- status was 'revealed', so every redaction failed with 23514.
--
-- Two correct rules collided. The constraint exists to make FR-RESULT-01
-- structurally true, so that no winner data can sit on a cycle that has not been
-- revealed. That guarantee is untouched here. What it also asserted, without
-- meaning to, was that a revealed winner must remain *identifiable* forever,
-- which is the opposite of what an Article 21 objection requires.
--
-- The public fact of a result is the name and the count. The roster link is an
-- internal convenience, and it is exactly the thing redaction has to remove. So
-- the link becomes optional on a revealed cycle and stays forbidden on an
-- unrevealed one.
--
-- Found by running the tests rather than by reading them: 011 asserted the
-- redaction worked, and it could not have.

alter table public.recognition_cycles
  drop constraint if exists recognition_cycles_winner_only_when_revealed;

alter table public.recognition_cycles
  add constraint recognition_cycles_winner_only_when_revealed
  check (
    (
      status = 'revealed'
      -- The published fact. Still mandatory: a revealed cycle always announced
      -- somebody, even after the person behind the name has been redacted.
      and winner_name is not null
      and winner_nominations is not null
      and revealed_at is not null
      -- winner_participant_id is deliberately absent from this list. It may be
      -- present (normal) or null (redacted under D-028).
    )
    or (
      status <> 'revealed'
      and winner_participant_id is null
      and winner_name is null
      and winner_nominations is null
      and revealed_at is null
      and tie_decision_note is null
    )
  );
