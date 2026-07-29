# Decision log

Date: 25 July 2026

## Build approval

Jonny authorised the local implementation kick-off on 25 July 2026.

The recommended product defaults in this document are accepted as build
hypotheses. Legal publisher verification, D-U-N-S evidence and the final Play
Console account remain required before the first Play app record or upload.
No production deployment or store submission was authorised.

## How to use this file

Accepted decisions become architecture constraints. Proposed decisions may be
changed before implementation. Blocking decisions must be resolved in Gate 0 of
the Kanban.

## Accepted planning decisions

These decisions are accepted for the planning baseline, not as authorisation to
deploy.

### D-001: standalone runtime

**Decision:** The app has its own repository, Supabase project, auth users,
schema, secrets and release pipeline. It does not call biz-os at runtime.

**Reason:** A product sold independently needs independent tenancy, lifecycle
and failure boundaries.

### D-002: preserve database-enforced rules

**Decision:** One cycle, one vote, no self-vote, state transitions,
cross-organisation isolation and winner integrity are database invariants.

**Reason:** Client-only checks are bypassable and can disagree across app
versions.

### D-003: call the ballot confidential

**Decision:** Product copy uses "confidential", not "anonymous".

**Reason:** The system stores an internal voter identifier to enforce
eligibility and one vote. Administrators do not receive that identity through
normal screens, APIs or exports, but claiming technical anonymity would be
misleading.

### D-004: no live standings

**Decision:** No ranking or count by nominee is visible while voting is open.

**Reason:** Early results influence later voters and make the scheme less fair.

### D-005: free validation release

**Decision:** No paid plan, purchase link, subscription or reward transaction in
v1.

**Reason:** Repeat monthly use and willingness to pay have not been validated.
This also avoids premature billing-policy complexity.

### D-006: Android first

**Decision:** Release Android before iOS. Keep shared React Native architecture
portable.

**Reason:** The stated goal is Google Play, and one platform keeps the first
validation cycle tight.

### D-007: recognition only

**Decision:** The app does not calculate performance, promotion, pay or
disciplinary outcomes.

**Reason:** Popularity voting is not a defensible performance-management
instrument and would materially increase employment and privacy risk.

### D-008: direct FCM proposed

**Decision:** Attempt native FCM tokens and HTTP v1 delivery from a trusted
function before considering Expo Push Service.

**Reason:** This gives control over payload and processor flow. A spike must
prove the Edge runtime path before it becomes final.

## Proposed product decisions

### D-009: target customer

**Proposal:** UK teams with 5 to 100 workers, especially frontline and mixed
desk/non-desk workforces.

**Why:** They experience the manual-poll problem and are least well served by
large HR suites.

**Blocking:** Yes. Confirm before writing listing copy or onboarding.

### D-010: app and developer identity

**Proposal:**

- App: `Employee of the Month`
- Developer: verified JonnyAI legal entity
- Package: `uk.co.jonnyai.employeeofthemonth`

**Blocking:** Yes. Package and publisher choices become hard to reverse after
the first Play upload.

### D-011: publisher account type

**Proposal:** Use an organisation Play developer account.

**Why:** This is a commercial business product. Organisation verification and
public details should be established early.

**Blocking:** Yes. Confirm existing account, D-U-N-S, website and verification.

### D-012: default retention

**Proposal:** Keep raw nominations for 12 months by default, then purge after a
revealed cycle passes the cutoff. Keep the public winner snapshot until the
organisation deletes it or a rights decision requires change.

**Alternative:** Default to indefinite retention as biz-os currently does.

**Recommendation:** Twelve months is a clearer privacy-by-default position for
a standalone service. The customer may choose a shorter or indefinite setting
with a visible explanation.

**Blocking:** Legal review before beta.

### D-013: reason field

**Proposal:** Optional in v1, maximum 500 characters, with a prompt for specific
behaviour and a warning against sensitive personal data.

**Alternative:** Require a minimum-length reason.

**Recommendation:** Keep optional for the first beta and measure completion and
quality. Add configurable required reasons as P1.

**Blocking:** No.

### D-014: admin access to reasons

**Proposal:** Administrators can moderate reasons only after voting closes,
unless a member reports a reason. They still do not receive voter identity.

**Why:** In a small team, precise submission time and writing can make a ballot
inferable. Deferring broad access improves confidentiality.

**Blocking:** Yes for API shape.

### D-015: tie policy

**Proposal:** The system does not invent a tie-break. An admin selects one of
the tied leaders and records a visible decision note.

**Alternative:** Share the award.

**Recommendation:** Support a single selected winner in v1 to preserve the
product promise, but design the schema so shared winners can be added later.

**Blocking:** No.

### D-016: user deletion and winner history

**Proposal:** Delete or anonymise membership and ballot data, but retain a
revealed winner name snapshot when the customer has a documented lawful
retention reason and has disclosed it.

**Blocking:** Yes. Requires legal wording and operational process.

## Accepted 25 July 2026, from the schema threat model

`docs/SCHEMA_THREAT_MODEL.md` raised four questions that the schema cannot
answer on its own. Jonny decided the first explicitly and signed off the
document, which accepts the recommendations on the other three.

### D-022: warn below eight eligible voters

**Decision:** When an organisation has fewer than eight eligible, account-linked
voters, the product warns before a cycle opens that individual votes may be
inferable. It does not block the cycle.

**Why:** Ballot confidentiality is arithmetic, not policy. With one voter the
single counted ballot is theirs. With two, an administrator who voted subtracts
their own and the other person's choice follows with certainty. Between three
and seven it is not certain but is often recoverable, because any tally where
the remaining ballots land on one nominee attributes all of them at once, and
that outcome is common in a small group.

`D-003` already commits to saying "confidential" rather than "anonymous". This
extends the same honesty to the case where even confidentiality is thin. A team
of five running the programme knowingly is a legitimate customer. Implying a
protection the maths does not support is not.

Eight is a judgement rather than a proof, which is why it is written down here
to be argued with rather than buried in a constant.

**Implemented:** `assessConfidentiality` in `src/domain/recognition/engine.ts`,
with the threshold as `CONFIDENTIALITY_WARNING_THRESHOLD` and five tests
covering the boundary, the determined cases and non-integer input. The
requirement is `FR-CYCLE-04`.

### D-023: erasure keeps the winner name and count only

**Decision:** When a user is erased, a retained winner snapshot keeps the
display name and nomination count. Their reason text does not survive with it.

**Why:** `D-016` justifies keeping a winner record as an organisational fact.
Free text is personal data with no equivalent justification, and it is the part
most likely to carry something sensitive.

### D-024: audit events identify the cycle, never the voter

**Decision:** A nomination-cast audit event records the cycle and not the
nominator, accepting that a disputed individual ballot cannot be investigated
after the fact.

**Why:** An audit trail that can reconstruct who voted for whom is the exact
disclosure the product exists to prevent. Investigability is the lesser value.
This must be stated in the terms rather than discovered during a dispute.

### D-025: purpose-made database roles before production

**Decision:** Edge Functions may use the service role in development. Before
production they move to roles holding rights only to the tables each function
needs.

**Why:** The service role bypasses RLS entirely, so every function currently
carries the blast radius of the whole database. Acceptable while the data is
synthetic, not once it is real.

## Explicitly rejected for v1

### D-017: public join codes

Rejected because reusable codes make roster and eligibility abuse easier.
Use expiring single-use invitations.

### D-018: admin-visible voter list

Rejected. The reminder worker may privately identify eligible non-voters to
send a message, but the normal admin interface receives aggregate turnout.

### D-019: AI winner selection

Rejected. It would introduce opaque employment inferences and unnecessary data
processing.

### D-020: live leaderboard

Rejected. It undermines independent voting.

### D-021: rewards marketplace

Rejected until the repeat-cycle value is proven. It adds payment, tax, fraud,
fulfilment and support scope.

## Accepted 28 July 2026, from the legal determinations

`docs/LEGAL_ANSWERS.md` v0.2 answered the eight questions in
`docs/LEGAL_QUESTIONS_SIMPLE.md` and closed the four that were left open in
`docs/LEGAL_AND_PRIVACY.md` section 10. These are the product consequences.

**None of these has been reviewed by a solicitor.** They are held as build
decisions on the reasoning recorded in `LEGAL_ANSWERS.md`, which cites its
authorities so each can be checked rather than rebuilt. `D-028` and the Article
14 reasoning in `D-031` are the two flagged as genuinely contestable and are the
two to put in front of counsel first.

### D-026: we remain a processor, and say so in a schedule

**Decision:** Keep the controller/processor split in `LEGAL_AND_PRIVACY.md`
section 1. Add a "pre-set characteristics" schedule to the DPA listing ballot
confidentiality, the retention menu and the hidden leaderboard, with the
customer confirming it has assessed them as controller.

**Why:** Under EDPB Guidelines 07/2020 the duration of storage and the
categories of recipient are *essential* means reserved to the controller, and
two of our three constraints touch them. The answer is not that they are
technical details — they are not — but that the customer selects them
knowingly from what is offered. A schedule converts "the supplier imposed it"
into "the controller chose it". Article 28(10) makes getting this wrong
self-executing, so it is worth a clause rather than an argument.

**Implemented:** Drafted, in `docs/DPA_AND_CONTRACT_TERMS.md` Part A. The
pre-set characteristics schedule is A8 and carries five items rather than the
three this decision named: ballot confidentiality, nomination retention,
residual retention (added by `D-036`), the hidden leaderboard, and the
small-team warnings. Each is stated as a choice the customer confirms it has
assessed, and A8 closes by making the customer acknowledge that selecting
indefinite retention is its own Article 5(1)(e) call. Not executed, not offered
to anybody, and it needs a solicitor.

### D-027: severing the nominator-to-nominee link at purge

**Decision:** At reveal, write a per-nominee tally snapshot to the cycle. At
purge, clear the reason text *and* the nominee link, stamping `purged_at`, with
`check ((purged_at is null) = (nominee_participant_id is not null))`.

**Why:** After a cycle is revealed and the text is gone, nothing needs to know
that a particular person chose a particular colleague. The winner snapshot, the
turnout and the tallies all stand without it, so Article 5(1)(c) is not
satisfied by keeping it. The stronger reason is ours rather than the law's: what
survives the purge today is a permanent map of who thought what about whom with
the words removed but the meaning intact, which is the artefact `D-024` already
decided must not exist. The one-vote guard is
`unique (organisation_id, cycle_id, nominator_user_id)` and is unaffected.

**Implemented:** Yes, in
`supabase/migrations/20260728221500_sever_nominator_link_at_purge.sql`, once the
pgTAP suite could actually be run. `reveal_winner` now writes a `tally_snapshot`
in the same transaction that sets `status = 'revealed'`;
`purge_expired_nominations` clears `reason` and `nominee_participant_id` together
and stamps `purged_at`; the coherence constraint is as specified verbatim.
`get_closed_standings` reads the snapshot when one exists and computes live
otherwise, so a cycle closed but not yet revealed is unaffected.

Two things the write-up did not anticipate, both found by building it:

- **Standings had to be snapshotted for cycles revealed before this migration**,
  not only for new ones. Their links still existed at deploy time but would have
  been destroyed by the first purge, silently blanking the standings of every
  month revealed to date. The migration backfills them. Verified by nulling the
  snapshots on seeded revealed cycles and re-running the backfill statement.
- **`get_admin_nominations` had to exclude purged rows.** Its inner join to
  `participants` would have dropped them anyway; saying so explicitly stops that
  being an accident of the query plan.

Verified end to end against a real purge: three links severed, three reasons
cleared, three nominators kept, and `get_closed_standings` returning the
identical ranking afterwards. Suite at 325 assertions, `db lint` clean.

**Not implemented, and separated deliberately:** the ruling's closing clause,
"give the residual row an end date... the row should die with the cycle". The
row already cascades on cycle, organisation and nominator deletion, so it dies
with the cycle structurally — but nothing in the product ever deletes a cycle,
so that end date is never reached in practice. Closing it properly means
choosing how long a revealed cycle itself lives, which is a controller decision
about retention rather than a bug, and it needs turnout snapshotted onto the
cycle first because `get_cycle_turnout` still counts the residual rows. Carried
as `D-036`.

### D-036: how long a revealed cycle itself lives

**Status:** open, needs Jonny and then the customer. Not a coding decision yet.

**The gap:** `D-027` leaves a residual ballot row carrying `nominator_user_id`
and `purged_at` — no nominee, no reason. It is the record that a named person
voted in a named month, retained indefinitely, because no cycle is ever deleted.
"Retained indefinitely" is the phrase the ruling warns is hard to defend.

**Why it is not just a delete:** the residual row is still doing two jobs. It
backs the one-vote guard, which is moot once a cycle is revealed and cannot be
reopened, and it backs `get_cycle_turnout`, which is not moot — turnout is
reported for historic cycles. Deleting the rows without first snapshotting
turnout onto `recognition_cycles` would rewrite historic turnout to zero, which
is the same mistake the tally snapshot exists to prevent.

**The shape of the fix:** snapshot turnout at reveal alongside the tally, then a
second-stage purge that deletes residual rows for cycles older than a
customer-set cycle-retention period, defaulting to something conservative. Both
stages want to be in the same scheduled job.

**Decision taken:** a new `residual_retention_months` on `recognition_settings`,
same shape as `retention_months` and defaulting to **24 months**, measured from
when the row was severed rather than from reveal. Null means indefinite, which
is consistent with `D-012` already allowing a controller to choose indefinite
retention of the far more sensitive reason text. The objection the review raised
was that we retained forever *by design with no option*, not that a controller
may never choose it. Existing rows are set to 24 explicitly by the migration
rather than left on the behaviour this decision exists to end.

**Deviation from the ruling, deliberate.** The ruling said the row "should die
with the cycle". Taken literally that means deleting revealed cycles, which
destroys the winner name, the standings and the award history that `D-023` says
survives even an erasure request. The substance of the ruling is that retention
must not be indefinite. The cycle lives; the ballot rows do not. Flagged for
counsel as a departure from the letter of the advice.

**Implemented:** `supabase/migrations/20260729110000_residual_retention_and_turnout_snapshot.sql`.
`purge_expired_nominations` now returns a `stage` column and runs two stages:
`severed` at `retention_months`, `deleted` at `residual_retention_months` after
severing. Stage two refuses to run on a cycle with no turnout snapshot, because
the failure that matters is destroying a figure, not leaving a row.

**Found while building, and worth recording separately:** `get_cycle_turnout`
counted eligible voters from the *live* roster, so hiring or deactivating
somebody today silently rewrote the turnout percentage of every past month — a
number an administrator may already have reported to their board. Reveal now
freezes `turnout_eligible` and `turnout_ballots`, backfilled for existing
revealed cycles. That is a correctness fix that happened to be a precondition
for this decision rather than a consequence of it.

Suite 325 → 337 assertions.

### D-037: erasure scrubs the standings, but not the award

**Decision:** When an erasure request is carried out, the person's entry in
every `tally_snapshot` has its `display_name` replaced with "A former colleague"
and its `participant_id` nulled, while the count stays. `winner_name` and
`winner_nominations` are left alone.

**Why:** `D-027` added a tally snapshot naming every participant of every
revealed month. That was necessary to let the nominee link be purged, but it
created a second problem nobody had ruled on: an erased person's name would
survive in the standings of every month they were ever on the roster. `D-023`
decided a *winner's* name survives erasure and `D-028` gives the controller a
way to redact even that, so the winner case is covered by a considered position.
A non-winner who came third has no award to justify keeping their name, and
nothing covered that case. Found while writing the deletion worker, not by
review.

The count stays because removing the entry entirely would make a past month stop
adding up, and an inconsistent historic record invites exactly the "did you
tamper with this?" question `D-030` was written to be able to answer. The
wording matches `redact_winner_snapshot` so the two redactions read as the same
act rather than as two different bugs.

**Implemented:** `process_deletion_requests` in
`supabase/migrations/20260729120000_deletion_worker.sql`, with four assertions in
`supabase/tests/012_deletion_worker.test.sql` covering the scrub, the surviving
counts, the shared wording, and that nobody else is touched.

### PRV-010: the deletion worker

**Decision:** `process_deletion_requests(dry_run)`, service-role only, carries
out queued erasure requests. Dry run by default, in the same shape as
`purge_expired_nominations`.

**Why it was not simply "delete the user":** `participants.user_id` is
`ON DELETE SET NULL`, not cascade. Deleting the auth user leaves the roster row
standing with the person's display name on it. An erasure that leaves the name
behind is not an erasure, so participant rows are deleted explicitly and first.
This was a live gap: the product has been offering erasure, recording the
request, and never carrying it out.

**Sole ownership is re-checked, not trusted.** `request_account_deletion` blocks
a sole active owner, but ownership can change in both directions between asking
and processing. A request that cannot proceed is marked `refused` with a reason
rather than left in the queue, because a request that silently sits in `received`
is how a statutory deadline gets missed.

**What survives, deliberately:** the winner name and count (`D-023`), the audit
event with `actor_user_id` nulled (`D-024`), and the `privacy_requests` row
itself with `user_id` nulled, which is why that column was made nullable. The
worker reports when an award record has been retained so the operator can tell
the person rather than leaving them to discover it.

**Depends on the snapshots.** Deleting a participant cascades their ballots, as
nominator and as nominee. Revealed cycles are unaffected only because `D-027`
froze the tally and `D-036` froze turnout. Without those, an erasure would have
quietly rewritten the results of every month the person voted in.

**Implemented:** the migration above, 24 assertions in
`supabase/tests/012_deletion_worker.test.sql`. Suite 337 → 361.

**Scheduled:** `supabase/migrations/20260729160000_schedule_retention_and_deletion.sql`.
pg_cron, daily, 03:30 UTC, half an hour after the retention purge so the two are
not competing for locks on the same rows and erasure runs after the purge has
finished its pass. Both jobs pass the destructive argument explicitly, because
`dry_run` defaults to true so that a careless caller does nothing — which means
a scheduled caller has to say `false` out loud. Four assertions in
`009_privacy.test.sql` cover both jobs existing and active, both running for
real rather than dry, and the operator health view being unreachable by a
client.

### D-038: the exposure surface is pinned per column, not per table

**Found, not decided.** A leak introduced by `D-027` and `D-036` and caught only
when the privacy notice could not read a different new column.

**What happened:** `recognition_cycles` carried a **table-level** SELECT grant
to `authenticated`. A table-level grant covers columns added afterwards. So
`tally_snapshot` (`D-027`) and `turnout_eligible` / `turnout_ballots` (`D-036`)
became readable by every member the moment they were created — no migration
said so, and no test failed.

**What was exposed:** `tally_snapshot` is the per-nominee standings of every
revealed cycle, which `D-004` hides while a cycle is open and which
`get_closed_standings` gates to owners and admins afterwards. A member could
read the column and skip the function entirely. `turnout_*` are the figures
behind `get_cycle_turnout`, which has an explicit assertion that a plain member
cannot see turnout — the columns contradicted the function. Neither exposes who
voted for whom.

**Why the guard missed it:** `001_schema_invariants.test.sql` pinned the
exposed **tables** by name, and both columns were on a table that was already
and legitimately exposed. The threat model's stated approach is to open a column
at a time; the test only ever enforced that at table granularity, so the two
were not the same rule.

**How it was actually noticed,** which is worth recording because it was luck
rather than method: `D-036` also added `residual_retention_months` to
`recognition_settings`, and the privacy notice could not read it. Chasing *that*
grant surfaced the full column list, and the three open columns on
`recognition_cycles` were sitting in it. The fail-closed default worked exactly
as designed for the settings table and did nothing for the cycles table,
because one had column grants and the other had a table grant.

**A column-level REVOKE does not fix this.** Postgres accepts
`revoke select (col) on t from role` and reports `REVOKE`, but a table-level
privilege still implies access to every column, so the grant survives and the
leak stays open. Verified before writing the migration. The only thing that
works is revoking the table privilege and re-granting the columns explicitly.

**Also closed while the grant was being rewritten:** `revealed_by`, which names
the administrator who revealed a result. It predates this leak and was
previously readable. No client code selects it and it is the only column on the
table that identifies a person, so leaving it open merely because it happened to
be open would have been the same mistake in a slower form.

**Implemented:**
`supabase/migrations/20260729150000_close_cycle_snapshot_columns.sql`, plus two
new assertions in `001_schema_invariants.test.sql`: the full readable surface
pinned as 44 `table.column` pairs, and a named check on the four withheld
columns. The per-column assertion is deliberately verbose — the verbosity is the
mechanism, because a new column now has to be justified in a diff.

Behaviourally verified as a member: `permission denied` on both
`tally_snapshot` and `turnout_ballots`, with ordinary cycle reads unaffected.
Suite 366 → 368.

### D-028: the customer, not us, decides whether a winner survives erasure

**Decision:** Keep the winner snapshot by default (`D-016`, `D-023`), and give
administrators `redact_winner_snapshot` with three outcomes — initials, "A
former colleague", or no name. The nomination count and the fact of a revealed
result survive every mode. The roster link goes in every mode.

**Why:** Erasure here runs through an Article 21(1) objection, where the
controller must *demonstrate* compelling legitimate grounds that override the
individual. That balance belongs to the employer, and a processor that cannot
carry out the controller's decision either way is the actual exposure. Three
modes rather than two because the middle one usually satisfies the person while
leaving the record coherent. The link must go with the name or the name could be
recovered by a join, which would make the whole thing cosmetic.

**Contestable.** An employee could plausibly persuade the ICO that a former
employer has no compelling ground to keep her name at all. What makes the
position survivable is that it was disclosed before she took part and that the
employer can undo it, not the strength of the argument.

**Implemented:** `redact_winner_snapshot` in
`supabase/migrations/20260728203000_legal_redaction_and_voter_notice.sql`, with
tests in `supabase/tests/011_legal_redaction.test.sql`. Deletion flow copy in
`src/app/privacy.tsx` now routes the person to their employer before they
delete.

### D-029: contractual prohibition on performance use

**Decision:** The customer terms carry a permitted-use covenant, an indemnity
and a suspension right, not a disclaimer. It catches non-participation as well
as results.

**Why:** Two independent reasons. It is load-bearing for the customer's Article
6(1)(f) basis, because reasonable expectations is the limb that decides this
product and nobody nominating a colleague expects it in a redundancy matrix.
And a peer popularity vote correlates with visibility rather than performance,
which makes it a section 19 Equality Act indirect discrimination claim waiting
to happen — part-time staff, people returning from family leave, disabled
employees, remote and night-shift workers all systematically lose it.
*Williams v Compair Maxam* has required objective, verifiable redundancy
criteria since 1982.

It must catch non-participation or we have banned punishing the loser and
permitted punishing the person who declined to vote, which is the more likely
abuse and the one the product is otherwise good at preventing.

**Implemented:** Drafted, in `docs/DPA_AND_CONTRACT_TERMS.md` Part B. Covenant
(B2), the reasoning given to the customer rather than kept to ourselves (B3),
indemnity (B4), suspension (B5), and a requirement that the customer tells
participants (B6) — a promise the affected people never hear does not help the
balancing test. The non-participation limb is drafted as an equal prohibition
rather than an afterthought. Not executed, and it needs a solicitor; Part C
question 8 asks whether this should be a licence condition rather than a
covenant.

### D-030: moderation must be able to delete, and must work after reveal

**Decision:** `moderate_nomination` gains a `redact` action that clears the
reason text permanently and is permitted after a cycle is revealed. Hide and
restore keep their existing pre-reveal-only rule.

**Why:** Hiding is a display control. Article 9(1) prohibits special category
processing outright and none of the 9(2) conditions is available when a
colleague volunteers health information about a third party — not consent, not
employment obligations, not manifestly-made-public. So the content is unlawful
from the moment it is written and cannot be made lawful afterwards; it has to
leave storage. The old function also refused all moderation once a cycle was
revealed, which meant the one category of content that must always be removable
became permanent on a schedule. Redaction is safe to allow post-reveal because
it removes words and never a ballot, so no count moves and no published result
changes.

The moderation reason must not become the new home for the text just removed.
The interface warns on that field.

**Implemented:** the migration above, with eight assertions in
`011_legal_redaction.test.sql` covering storage, the audit trail and the
post-reveal case.

### D-031: the privacy notice says what is true

**Decision:** Three corrections in `src/app/privacy.tsx`, and the sensitive-data
warning moves above the reason field in `src/app/index.tsx`.

- "Who can see your nomination: **nobody**" becomes "nobody in your
  organisation", with our own technical access and the court-order case stated.
- "We will **never** tell you who wrote it" becomes "will not normally".
- Retention wording now says the ballot record outlives the text.

Plus the Article 13 items that were missing: the lawful basis named, the right
to object given its own card as Article 21(4) requires, participation stated as
voluntary, and the ICO named as the complaint route.

**Why:** The first sentence was contradicted by `LEGAL_AND_PRIVACY.md`
section 3 and by the threat model — a disprovable claim whose disproof we wrote
ourselves. The second was too absolute: withholding the author rests on the
third party exemption in Schedule 2 Part 3 paragraph 16 of the DPA 2018, which
is a balancing exemption that can be displaced by consent or reasonableness, so
"never" forecloses a judgment the statute requires. The warning moved because
in the character counter it arrives after somebody has finished typing.

**Contestable, in one part.** Withholding the source from the *nominee* engages
Article 14(2)(f), a proactive transparency duty, and paragraph 16 is drafted as
a restriction on Article 15 access. Reading it across is a sound argument, not
an automatic one; Article 14(5)(b) supports it as a second limb. This is the
point where confidentiality to the nominator and transparency to the nominee
actually conflict, and it needs counsel.

**Implemented:** copy changes shipped. DSAR runbook recording the paragraph 16
reasoning still to write.

### D-032: structured tags instead of a free-text essay box

**Decision:** Built. A required tag and a short optional note replace the essay
box. Jonny took the product call on 29 July 2026.

**Why:** Not a legal requirement, and the highest-value change available for the
Article 9 problem. People write essays in essay boxes. Every mitigation in
`D-030` is a remedy after the fact; this is the only one that reduces how often
the fact occurs. Left unscheduled because it changes the feel of the product and
that is a decision to take deliberately rather than on legal advice alone.

**The vocabulary,** narrowed from the sketch in this decision:

    helped_colleague        Helped a colleague
    helped_customer         Looked after a customer
    improved_how_we_work    Improved how we work
    shared_knowledge        Shared what they know
    steady_under_pressure   Steady when it counted

The original sketch included "went above and beyond". It was dropped. Every tag
must describe something a person *did*; "went above and beyond" describes how
somebody *was*, and a vocabulary that invites comment on who a person is makes
the Article 9 problem worse rather than better. That is the test each entry has
to pass, and it is the reason there is no "overcame adversity" or "great
attitude" in the list.

**What is now required, and what is not.** The tag is mandatory and the note is
genuinely optional. That inverts the previous behaviour: the client used to
refuse a nomination with no reason ("Add a short reason for your nomination")
while the database accepted one, so the essay box was in practice compulsory.
The note also drops from 500 characters to 250 — a paragraph is where the
disclosures live, and a sentence is enough to say what somebody did.

**`unspecified` is a sixth value that is not a tag.** Ballots written before
this change have no tag, and there is no honest mapping from free text to one.
Back-filling them as `helped_colleague` would be inventing data about real
people, so they take `unspecified`, which the check constraint accepts and
`cast_nomination` refuses. It can only ever mean "written before D-032". The
column carries it as a default so a fixture or a future admin tool that says
nothing gets the honest answer rather than an error; that cannot weaken the
requirement, because clients have no INSERT grant on the table at all and
`cast_nomination` is the only path by which a ballot is ever created.

**The tag survives the retention purge, the reason does not.** Once `D-027` has
severed the nominee link, "somebody was thanked for looking after a customer"
identifies nobody, and keeping it lets an organisation see what its people
actually value over years without retaining anything about a named person.

**Implemented:** `supabase/migrations/20260729130000_structured_nomination_tags.sql`
(`cast_nomination`, `get_admin_nominations`, `get_my_nomination`,
`export_my_data`), `NOMINATION_TAGS` and `nominationTagLabel` in
`src/domain/recognition/engine.ts`, chip picker in `src/app/index.tsx`. Suite
361 → 366 assertions plus two new unit tests. The tag is included in the subject
access export, and the `reasons_written_about_me` filter was widened from
`reason is not null`, which would otherwise have silently omitted a tag-only
nomination from a person's own export.

**Note for the administrator's view:** `get_admin_nominations` gained a column,
which changed the shape pinned by the first assertion in
`006_admin_turnout_and_reveal.test.sql`. That assertion exists so a change like
this is deliberate rather than accidental, and updating it in the same commit is
the intended workflow rather than a nuisance.

### D-033: two DPIAs, and the threat model is an annex

**Decision:** Complete our own DPIA for the processing where we are controller,
and publish a model DPIA and model legitimate interests assessment as customer
collateral. Annex `SCHEMA_THREAT_MODEL.md` to both rather than submitting it as
one.

**Why:** Article 35(3) is not squarely met — say so in the DPIA, it shows the
threshold was understood — but WP248 puts us over on at least three counts, of
which vulnerable data subjects is decisive: employees are named in the guidance
because of the employment power imbalance. Concede the evaluation-or-scoring
criterion rather than arguing it; arguing reads as defensive and costs nothing
to give up.

The threat model supplies perhaps 40% of a DPIA, not the 90% previously assumed.
It assesses risks to the *system*. A DPIA assesses risks to *individuals*, and
needs necessity and proportionality, harms rather than control failures,
consultation under Article 35(9) or a recorded reason for skipping it, and named
sign-off. `DECISIONS.md` is an unusually good source for the necessity section.

The customer's own DPIA is theirs and we cannot discharge it. The model is
commercial advantage as much as compliance: every enterprise DPO will ask.

**Implemented:** `docs/DPIA.md` (ours) and `docs/DPIA_MODEL_FOR_CUSTOMERS.md`
(model DPIA plus model LIA). Both draft, neither signed off.

Three things this write-up did not anticipate:

- **Our own Article 35 duty does not exist.** We are the processor; the duty is
  the controller's. The document says so in its second section rather than
  implying an obligation we do not have, and gives the three real reasons for
  doing it anyway: the decisions were taken on risk grounds and deserve writing
  up, every enterprise DPO asks, and Article 28(3)(f) requires us to assist.
- **A fifth WP248 criterion was conceded.** This decision named three. Criterion
  9, preventing the exercise of a right, applies squarely: we will not tell a
  participant who nominated them. Recording it in the DPIA rather than only in
  the terms is more honest, and costs nothing given the conclusion was already
  "high risk".
- **The consultation section is the one most likely to be skipped, so it is
  written out in full.** Article 35(9) is not satisfied, the reason is that
  there are no participants yet, and the commitment to consult at first pilot
  names which two risks to ask about. A blank section reads as an oversight;
  this was a decision.

The model LIA states plainly that the customer's Article 6(1)(f) basis fails if
it uses results for employment decisions, which makes `D-029` load-bearing for
the customer rather than merely protective of us. That is the point `D-029`
already made, now said to the party it constrains.

### D-034: production region is London

**Decision:** Create the production Supabase project in `eu-west-2` (London),
before onboarding anyone. Closes `INF-012`.

**Why:** There is no data localisation requirement in UK law and Ireland is
lawful — EEA transfers are covered by adequacy carried across by the 2019 EU
Exit Regulations and now sitting in Articles 45A and 47A UK GDPR. So this is not
a legal decision. It is that the region cannot change after the project is
created, the choice is free today, and the downside is asymmetric: UK public
sector, NHS and financial services buyers apply "is it held in the UK?" as a
hard filter, and losing on it means a migration with live employee data at the
worst possible moment.

**Caveat:** do not claim "your data never leaves the UK" until subprocessor
support access has been audited. Storage region is the easy half; where Supabase,
Resend and Firebase support staff sit is the real question, and an inaccurate
residency claim would be worse than saying nothing given `D-003`.

### D-035: warn the voter, not only the administrator

**Decision:** The nomination screen warns the voter, before they vote, when the
team is small enough that their ballot may be deducible. It says they do not
have to vote. `get_cycle_confidentiality` returns a level and never a headcount.

**Why:** `D-022` warns the administrator before a cycle opens, which is
necessary and not sufficient — the person who can be identified from the result
is the voter, and until now the voter was never told. Article 5(1)(a) fairness
is judged by what the data subject understood when their data was collected,
which is the moment they press submit, not a notice emailed at onboarding.

A level rather than a count because `can_vote` and `user_id` are withheld from
the client's column grant, so the arithmetic has to run server-side, and because
"you may be identifiable" is the whole of what a voter needs in order to decide.
Handing them a headcount would leak roster eligibility to make a warning
marginally more precise.

It ends by saying they do not have to vote because a warning that leaves
somebody no action to take is decoration.

**Implemented:** `voterConfidentialityMessage` and `voterConfidentialityNotice`
in `src/domain/recognition/engine.ts` with five tests asserting the copy agrees
with `assessConfidentiality` at every count; `get_cycle_confidentiality` in the
migration; banner in `src/app/index.tsx`.

## Gate 0 sign-off record

Complete this table before scaffolding.

| Decision | Chosen value | Approved by | Date |
|---|---|---|---|
| Target customer | UK organisations with 5 to 100 workers | Jonny | 25 July 2026 |
| App name | Employee of the Month, working identity | Jonny | 25 July 2026 |
| Package name | `uk.co.jonnyai.employeeofthemonth`, provisional until first Play upload | Jonny | 25 July 2026 |
| Legal publisher | JonnyAI working identity; legal entity verification pending | Jonny | 25 July 2026 |
| Play account type/status | Organisation account recommended; evidence pending before Play setup | Jonny | 25 July 2026 |
| Default retention | 12 months, subject to legal review | Jonny | 25 July 2026 |
| Admin reason access | After close, except reported content | Jonny | 25 July 2026 |
| Deletion/winner retention rule | Recommended D-016 treatment, subject to legal review | Jonny | 25 July 2026 |
| Beta organisation target | 3 to 5 in closed test, expand towards 10 to 20 | Jonny | 25 July 2026 |
| Build start authorised | Yes, local foundation and application implementation | Jonny | 25 July 2026 |

The two rows above marked "subject to legal review" — default retention and the
deletion/winner retention rule — were answered on 28 July 2026 by
`docs/LEGAL_ANSWERS.md` and are now carried by `D-026` and `D-028`. The
retention menu stands; the winner rule stands only with the customer able to
override it, which is what `D-028` builds. Neither has been seen by a solicitor,
and the sign-off row stays open until one has seen them.
