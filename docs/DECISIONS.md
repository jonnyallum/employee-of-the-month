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
