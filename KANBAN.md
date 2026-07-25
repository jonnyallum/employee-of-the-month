# Employee of the Month delivery Kanban

Baseline date: 25 July 2026  
Board owner: Product and engineering  
Current phase: Gate G1 foundation
Implementation authorised: **Yes, by Jonny on 25 July 2026**

## Board rules

### Status markers

- `[ ]` Not started
- `[>]` In progress
- `[x]` Done and evidenced
- `[!]` Blocked
- `[-]` Removed from scope with reason

### Priority

- `P0`: release blocker
- `P1`: high-value fast follow
- `P2`: later option

### Estimate

Estimates are ideal engineering days for one experienced contributor after
dependencies are ready. They are not elapsed promises.

- `0.5`: half day
- `1`: one day
- `2`: two days
- `3`: three days
- `5`: one working week
- `8`: must be split before starting

### Card contract

Every card has:

- one outcome;
- named dependencies;
- an evidence artefact;
- testable completion criteria;
- no hidden production deployment.

If a card grows beyond five ideal days, split it before work continues.

## Definition of ready

A build card can move to in progress only when:

- every dependency is done;
- acceptance criteria are unambiguous;
- required account or secret access exists;
- design states include loading, empty, error, denied and success;
- privacy and security impact has been considered;
- no unrelated user changes would be overwritten.

## Definition of done

A code card is done only when:

- implementation and tests are committed;
- type check, lint and relevant automated tests pass;
- a reviewer has checked security and accessibility where applicable;
- documentation and generated types are current;
- no secret, customer data or employee data appears in the diff;
- manual evidence is attached or referenced for device-only behaviour;
- the Kanban status and follow-on cards are updated.

## Release gates

| Gate | Exit condition | Current state |
|---|---|---|
| G0 Product authority | Recommended defaults accepted and local build authorised; final Play identity remains a release-account task | Passed 25 July 2026 |
| G1 Foundation | Reproducible Expo app, CI and local Supabase | In progress |
| G2 Data security | Schema, RLS, guarded RPCs and adversarial tests pass | Not started |
| G3 Core workflow | Owner and member complete a cycle end to end | Not started |
| G4 Privacy and delivery | Deletion, retention, reminders and policy pages work | Not started |
| G5 Internal quality | Release AAB passes device, accessibility and security checks | Not started |
| G6 Closed beta | Play closed test and product hypotheses reviewed | Not started |
| G7 Production | Policy pack approved and staged rollout authorised | Not started |

## Critical path

`G0 decisions -> repository scaffold -> Supabase schema -> RLS/RPC security ->
auth/invitations -> roster -> cycle -> ballot -> tally/reveal -> privacy ->
release AAB -> internal test -> 14-day closed beta -> production decision`

Push notifications, CSV import and visual polish must not delay proof of a
secure end-to-end ballot unless a release gate explicitly requires them.

## Phase 00: research and pre-build authority

No application code, dependency scaffold, cloud project or Play app should be
created before `PRE-013` is complete.

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [x] | PRE-001 | P0 | Product | 1 | None | Inspect the standalone repository. Evidence: repository state recorded; only README existed. |
| [x] | PRE-002 | P0 | Product/Eng | 2 | None | Inspect biz-os P08 design, engine, tests and migrations. Evidence: reusable invariants and standalone changes recorded in PRD and architecture. |
| [x] | PRE-003 | P0 | Product | 2 | None | Research direct, adjacent and substitute products. Evidence: dated matrix and sources in `docs/RESEARCH.md`. |
| [x] | PRE-004 | P0 | Product | 1 | None | Research recognition fairness and programme failure modes. Evidence: CIPD, Gallup and SHRM findings translated into requirements. |
| [x] | PRE-005 | P0 | Eng | 1 | None | Research Android, Expo, Supabase and notification constraints. Evidence: dated architecture references. |
| [x] | PRE-006 | P0 | Product/Ops | 1 | None | Research current Play policy, account, testing, deletion and API deadlines. Evidence: `docs/PLAY_STORE_RELEASE_PLAN.md`. |
| [x] | PRE-007 | P0 | Product | 2 | PRE-001..006 | Write PRD with P0/P1/P2 requirements and release criteria. Evidence: `docs/PRD.md`. |
| [x] | PRE-008 | P0 | Eng | 2 | PRE-002, PRE-005 | Write standalone architecture and security boundaries. Evidence: `docs/ARCHITECTURE.md`. |
| [x] | PRE-009 | P0 | Product/Eng | 2 | PRE-007, PRE-008 | Create dependency-ordered Kanban. Evidence: this file. |
| [x] | PRE-010 | P0 | Product | 0.5 | PRE-007 | Target accepted for build baseline: UK 5 to 100 person organisations, including frontline teams. Evidence: D-009 and build approval record. |
| [x] | PRE-011 | P0 | Product/Brand | 1 | PRE-003 | Working app identity accepted for local build: Employee of the Month, with final listing sense-check retained in PLY-002/005. |
| [>] | PRE-012 | P0 | Product/Ops | 1 | PRE-011 | Working package `uk.co.jonnyai.employeeofthemonth` accepted for local builds. Legal publisher, Play account, D-U-N-S and verification evidence remain required before PLY-002. |
| [x] | PRE-013 | P0 | Product | 0.5 | PRE-010, PRE-011 | Recommended retention, reason access and deletion defaults accepted as implementation hypotheses, subject to PRV-001 legal review. |
| [x] | PRE-014 | P0 | Product | 0.5 | PRE-013 | Jonny explicitly authorised implementation start on 25 July 2026. |
| [ ] | PRE-015 | P0 | Product/Research | 3 | PRE-010 | Interview five programme owners and eight employees. Done when notes are anonymised, themes are synthesised and any P0 requirement change is logged. |
| [ ] | PRE-016 | P0 | Product | 1 | PRE-015 | Revalidate activation, turnout and second-cycle success thresholds. Evidence: amended PRD or explicit no-change note. |

## Phase 10: repository and application foundation

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [x] | FND-001 | P0 | Eng | 1 | PRE-014 | Expo SDK 57 TypeScript app scaffolded from the current official template, replacing the superseded SDK 56 planning baseline. Exact dependency versions and lockfile recorded; Expo Doctor passes 17/17. Evidence: `package.json`, `package-lock.json`, `docs/BUILD_LOG.md`. |
| [x] | FND-002 | P0 | Eng | 1 | FND-001 | Package `uk.co.jonnyai.employeeofthemonth`, matching URL scheme, API 36 SDK baseline, Expo minimum API 24, adaptive icon placeholders and predictive back are configured. Android export passes. |
| [x] | FND-003 | P0 | Eng | 1 | FND-001 | `src/app`, `src/domain`, `src/lib` and `src/theme` boundaries and `@/*` path alias established. Domain tests run without route imports. |
| [>] | FND-004 | P0 | Eng | 1 | FND-001 | Biome formatting/lint, strict TypeScript and Node tests pass locally. Deliberate CI failure proof remains before completion. |
| [x] | FND-005 | P0 | Eng | 2 | FND-004 | Least-privilege GitHub Actions workflow runs on pinned Node 22.13 with locked install, checks, Doctor and Android bundle proof. Hosted run `30164124076` passed; deprecated action runtime warning removed in the follow-up. |
| [>] | FND-006 | P0 | Eng/Sec | 1 | FND-001 | `.gitignore` and names-only `.env.example` added; direct dependency audit has zero high/critical findings. Secret scanning and dependency review workflow remain. |
| [>] | FND-007 | P0 | Design/Eng | 2 | FND-003 | Initial colour, spacing and radius tokens plus 58dp primary action implemented. Typography, motion and recorded AA contrast evidence remain. |
| [>] | FND-008 | P0 | Eng | 2 | FND-003, FND-007 | Root Expo Router stack and safe-area shell added. Auth/member/admin groups, boundaries and route smoke tests remain. |
| [>] | FND-009 | P0 | Eng | 1 | FND-005 | Public Supabase URL/key validation and tests added, including service-role/JWT rejection. Environment profiles and production start gate remain. |
| [!] | FND-010 | P0 | Eng/Ops | 1 | FND-002 | Android JavaScript bundle exports successfully. Native debug build and screenshot blocked locally because Android SDK/emulator tooling is not installed or on `PATH`. |
| [ ] | FND-011 | P1 | Eng | 1 | FND-005 | Add dependency licence inventory and prohibited-licence check. Output is stored as CI artefact. |
| [ ] | FND-012 | P1 | Eng | 1 | FND-004 | Add a component catalogue route available only in non-production builds. Empty/loading/error states are visible. |

### Gate G1 exit

- `FND-001` through `FND-010` done.
- Clean checkout installs reproducibly.
- API 36 debug app launches on emulator.
- CI is green and contains no secret.

## Phase 20: service and environment foundation

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [x] | INF-001 | P0 | Eng | 1 | PRE-014 | Supabase CLI 2.109.1 pinned, local config initialised for Postgres 17, and the local stack now starts. Docker engine 29.1.5 running; `supabase db reset` replays every migration from an empty database and `supabase db lint` reports no schema errors. |
| [x] | INF-002 | P0 | Ops | 1 | PRE-012 | Dedicated Supabase development project created in its own account and organisation `employee-of-the-month-dev`, separate from the biz-os Supabase account, satisfying `D-001`. Repository linked and reachability proved: publishable key authenticates the Data API, Auth API answers, migration history is empty and no table exists. Evidence: `scripts/verify-supabase.ps1` all-pass output in `docs/BUILD_LOG.md`. Reference and credentials live in jvault project `employee-of-the-month-dev`, not in this repository. |
| [>] | INF-003 | P0 | Ops/Eng | 1 | INF-002 | Auth mail moved off the built-in Supabase mailer, which allowed only two messages an hour and delivered only to project members. Now sends through Resend on `jonnyai.co.uk`, whose DKIM and SPF records are verified, at `recognition@jonnyai.co.uk` as `Employee of the Month`, one message per address per 60 seconds and 100 per hour project wide. Applied by `scripts/apply-smtp-config.ps1`, which refuses to install a credential Resend rejects. Uses this product's own `RESEND_API_KEY`, a distinct key rather than a copy of a shared one, so another product's rotation cannot break sign-up here. A real magic-link email was sent to a live address on 25 July 2026 and Supabase returned `HTTP 200` in 2.1 seconds, which means it accepted the request and handed the message to Resend; a rejected credential or sender fails with a 5xx here instead. Repeatable via `scripts/send-test-email.ps1`, which requires an explicit recipient. **Remaining:** human confirmation that the message arrived, which folder it landed in, and that the sender renders as expected. Inbox placement, spam filtering and DMARC alignment are not observable from the sending side. |
| [x] | INF-014 | P1 | Eng/Sec | 0.5 | INF-003 | Sending-only Resend key created by Jonny and installed as the SMTP credential. Verified restricted: it returns 401 on every read endpoint, including `/api-keys`, and 422 on a `POST /emails` with an invalid body, which proves send permission without sending anything. The over-privilege warning in `apply-smtp-config.ps1` is now silent, which is the evidence. Imported to jvault by file rather than `--value`, so the key never entered a command line or process list. |
| [ ] | INF-015 | P1 | Ops/Sec | 0.25 | INF-014 | Delete the now-superseded full-access Resend key named `employee-of-the-month-dev`, created 25 July 2026 at 18:15. It is no longer used by anything but still grants full read and key-creation rights on the Resend account. An unused credential is only a liability. |
| [ ] | INF-004 | P0 | Ops | 1 | PRE-012 | Create Firebase Android project matching final package ID. No Analytics product enabled by default. |
| [ ] | INF-005 | P0 | Eng/Ops | 2 | INF-004, FND-010 | Configure native FCM development credentials and obtain a device token on physical hardware. |
| [ ] | INF-006 | P0 | Eng | 2 | INF-005, INF-002 | Spike one generic FCM HTTP v1 message from a Supabase Edge Function. Secret stays server-side; receipt is recorded. |
| [ ] | INF-007 | P0 | Eng | 1 | INF-001, FND-005 | Extend CI to start local Supabase, replay migrations and run SQL tests. Clean replay passes twice. |
| [ ] | INF-008 | P0 | Ops | 1 | PRE-012 | Confirm public HTTPS host for privacy, terms, deletion and app-link association pages. No page is deployed yet without approval. |
| [ ] | INF-009 | P0 | Eng/Ops | 1 | INF-008, FND-002 | Specify Android App Links and fallback custom scheme. Test association file locally and document Play signing fingerprint dependency. |
| [ ] | INF-010 | P1 | Ops | 1 | INF-002 | Set spend cap, usage alerts, backup expectations and named service owner. Evidence: redacted operations checklist. |
| [>] | INF-011 | P0 | Eng/Sec | 0.5 | INF-002 | Development Auth configuration moved off its defaults by `scripts/apply-auth-config.ps1`, which is idempotent, reads every value back after writing and reports the diff. Applied: password minimum length 6 to 12, lower/upper/digit classes required, `site_url` from `http://localhost:3000` to the app scheme, and a redirect allow list of `uk.co.jonnyai.employeeofthemonth://**` plus `http://localhost:8081/**`. Expo Go's `exp://` was deliberately excluded because it needs a wildcard over a host we do not control. **Not applied:** leaked-password protection returns `402 Payment Required`, since Supabase gates HaveIBeenPwned behind Pro. It stays the only open security advisor and closes when the project moves to Pro, which `ARCHITECTURE.md` already requires before real closed testing. Revisit the allow list when `INF-009` fixes the App Link host. |
| [ ] | INF-012 | P0 | Ops | 0.5 | INF-002 | Decide the production Supabase region deliberately. The development project was created in `eu-west-1` (Ireland), not the recommended `eu-west-2` (London), and a project region cannot be changed after creation. Confirm whether Ireland is acceptable for UK customer data and latency, or create production in London. Evidence: recorded decision in `docs/DECISIONS.md`. |
| [ ] | INF-013 | P2 | Ops | 0.5 | INF-002 | Rename the development project from its generated default name to `employee-of-the-month-dev` so the dashboard matches the organisation and jvault naming. |

## Phase 30: domain model, database and security

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [x] | DOM-001 | P0 | Eng | 2 | FND-003, PRE-002 | Pure period, state, eligibility, turnout, tally, rank, visibility and tie rules adapted from biz-os. Fifteen foundation tests pass with environment checks. |
| [>] | DOM-002 | P0 | Eng/Product | 1 | DOM-001, PRE-013 | Separate `can_vote` and `can_receive` rules and boundary tests added. Organisation timezone and reveal tie-note enforcement remain for the database/API slice. |
| [ ] | DOM-003 | P0 | Eng | 1 | DOM-001 | Add property or table-driven tests for ranks, ties, zero ballots and order stability. Mutating input does not affect result. |
| [x] | DOM-004 | P0 | Eng/Product | 0.5 | DOM-001, DB-001 | `FR-CYCLE-04` small-electorate warning implemented as pure rules: `assessConfidentiality`, `assessRosterConfidentiality`, `eligibleVoterIds` and `CONFIDENTIALITY_WARNING_THRESHOLD` in `src/domain/recognition/engine.ts`. Graded `determined` at two or fewer voters, where an administrator who voted can subtract their own ballot with certainty, `weak` from three to seven, `standard` at eight and above. Counts only account-linked, vote-eligible participants, so a large roster of unaccepted invitations cannot look safe. Five tests cover the boundary in both directions, the determined cases, mixed rosters and non-integer input. Twenty engine tests pass. |
| [ ] | UI-CONF-01 | P0 | Eng/Design | 1 | DOM-004, ADM-cycle screens | Surface the `FR-CYCLE-04` warning in the cycle-open flow and in member-facing confidentiality copy. It must be a first-class part of the screen, not help text, must state the `determined` case plainly, and must not block opening. Evidence: screenshots at seven and at eight eligible voters, plus a screen-reader announcement check. |
| [x] | DB-001 | P0 | Eng | 2 | INF-001, PRE-013 | `docs/SCHEMA_THREAT_MODEL.md` **signed off by Jonny on 25 July 2026**, unblocking `DB-002` onwards. Contains assets ranked by harm, trust boundaries, six actors, a per-table Data API exposure matrix, the guarded function surface with its hardening rules, ten threats with controls and stated residual risk, the six-role test matrix and eleven named tests. Key decisions: `recognition_nominations` gets no client grant at all rather than a restrictive policy, `participants` is granted as a column subset withholding `user_id` and `can_vote`, and the admin response truncates timestamps to the day and orders by name rather than time. All four open questions resolved as `D-022` to `D-025`. Note recorded in the document: both sign-off rows carry the same name, so no independent review has happened; `DB-018` and a re-review by someone who did not write it are release gates before real employee data. |
| [x] | DB-002 | P0 | Eng | 2 | DB-001 | `20260725184346_identity_and_roster.sql`: `private` schema, shared trigger functions, then profiles, organisations, organisation_members, participants and organisation_invitations. Every table created fail-closed, RLS enabled with no policy and no grant, so no window exists where a table is reachable before `DB-005` opens it. Tenant coherence is structural: invitations reach participants through a composite `(organisation_id, id)` key, so a cross-tenant reference is impossible even for the service role. `organisation_id` immutability enforced by trigger. Profiles are bootstrapped from an `auth.users` trigger, without which the table could never be populated, since the exposure matrix grants no INSERT. Clean replay from empty passes twice; `supabase db lint` clean. |
| [x] | DB-003 | P0 | Eng | 2 | DB-001, DOM-002 | `20260725184758_recognition_cycles_and_ballots.sql`: cycles, nominations, ballot events, settings, audit, push tokens, deliveries and privacy requests, all fail-closed. Two invariants are CHECK constraints rather than trigger logic, so a future function author cannot forget them: no self-nomination, and winner data existing if and only if the cycle is revealed. The second is what makes the threat model's "no window where a populated winner is visible on an unrevealed cycle" structurally true rather than a promise about the reveal function. `recognition_ballot_events` deliberately has no actor column, per `D-024`. Clean replay passes twice. |
| [x] | DB-004 | P0 | Eng/Sec | 2 | DB-002 | `20260725191805_rls_helpers.sql`: `current_user_id`, `is_org_member`, `has_org_role`, `participant_for_user`. All `SECURITY DEFINER` so a policy on `organisation_members` can ask about membership without recursing into the table it protects, and all `STABLE`, read-only, `search_path` pinned, taking the user from `auth.uid()` rather than an argument so nobody can ask on another's behalf. Membership is read live, so a departed member loses access on the next request rather than at token expiry. **Correction:** the threat model claimed `authenticated` would hold no `USAGE` on `private`; policy expressions are evaluated with the caller's privileges, so that was unimplementable. `USAGE` plus `EXECUTE` on only the two policy-referenced helpers is granted. The real control is the exposed-schema list, verified: `rpc/is_org_member` returns `PGRST202`. |
| [x] | DB-005 | P0 | Eng/Sec | 3 | DB-002, DB-004 | `20260725191809_identity_grants_and_policies.sql`: the first migration that makes anything reachable. `profiles` own-row select plus a `display_name`-only update grant; `organisations` and `organisation_members` readable by active members; `participants` granted as a seven-column subset that withholds `user_id`, `can_vote` and timestamps; `organisation_invitations` granted nothing at all. Every update policy carries both `USING` and `WITH CHECK`. Covered by 33 role-based assertions in `supabase/tests/002_rls_policies.test.sql` across signed-out, member, admin, owner, departed member and other-tenant owner. |
| [x] | DB-006 | P0 | Eng/Sec | 3 | DB-003, DB-004 | `20260725191812_recognition_grants_and_policies.sql`: `recognition_cycles` readable by members, `recognition_settings` as a three-column transparency subset, and **no grant at all** on nominations, ballot events, audit events, push tokens, deliveries or privacy requests. Proven at the SQL layer and through PostgREST that member, admin and owner are each refused `42501` on `recognition_nominations`, including a bare `count(*)`, which would otherwise leak live turnout. |
| [ ] | DB-007 | P0 | Eng | 2 | DB-002, DB-005 | Implement transactional `create_organisation`. Creator becomes owner; partial failure leaves no orphan. |
| [ ] | DB-008 | P0 | Eng/Sec | 3 | DB-002, DB-005 | Implement invite create, revoke, reissue and accept. Token hash, expiry, intended email and replay tests pass. |
| [ ] | DB-009 | P0 | Eng/Sec | 2 | DB-003, DB-006, DOM-002 | Implement guarded cycle create and transition with expected version. Illegal/racing transitions fail deterministically. |
| [ ] | DB-010 | P0 | Eng/Sec | 3 | DB-003, DB-006, DOM-002 | Implement cast/withdraw functions. Direct and RPC attempts prove one vote, no self-vote, same tenant and open state. |
| [ ] | DB-011 | P0 | Eng/Sec | 2 | DB-010 | Implement `get_my_nomination`; another member cannot infer or retrieve it. |
| [ ] | DB-012 | P0 | Eng/Sec | 3 | DB-010, PRE-013 | Implement confidentiality-safe admin moderation API. Contract test proves no voter field or precise identifying timestamp exists. |
| [ ] | DB-013 | P0 | Eng | 2 | DB-010, DOM-003 | Implement closed standings and reveal function. Clear leader, tied leader, note requirement and zero-vote tests pass. |
| [ ] | DB-014 | P0 | Eng | 2 | DB-010 | Implement aggregate turnout API with eligibility snapshot rules. It never returns a named voter/non-voter list. |
| [ ] | DB-015 | P0 | Eng/Sec | 2 | DB-008..014 | Create audit event functions and safe metadata allowlist. Ballot events identify cycle only. |
| [ ] | DB-016 | P0 | Eng | 1 | DB-002..015 | Generate TypeScript database types and add drift check to CI. Uncommitted type drift fails. |
| [ ] | DB-017 | P0 | Eng/Sec | 2 | DB-005..015 | Run Supabase security/performance advisors and fix critical/high findings. Evidence stored without project secrets. |
| [ ] | DB-018 | P0 | Sec | 3 | DB-005..017 | Adversarial Data API review: IDOR, cross-tenant, function execute, view bypass, JWT staleness and service-key exposure. Zero P0/P1 findings. |
| [ ] | DB-019 | P0 | Eng | 2 | DB-003 | Create deterministic synthetic seed for two organisations, roles, invited users, open/closed/tied/revealed cycles. No real data. |
| [ ] | DB-020 | P1 | Eng | 2 | DB-003, DB-017 | Add query-plan checks for 500 and 10,000 participant/nominations fixtures. Add missing/partial indexes with evidence. |

### Gate G2 exit

- `DOM-001` through `DOM-003` and `DB-001` through `DB-019` done.
- Clean schema replay and all SQL tests pass.
- No client/admin path can reveal another user's voter identity.
- No cross-tenant read or write succeeds.
- Advisors and adversarial review have no critical/high unresolved issue.

## Phase 40: authentication and onboarding

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [ ] | AUT-001 | P0 | Eng | 2 | FND-008, INF-002 | Initialise Supabase React Native client with current supported storage and refresh handling. Session lifecycle tests pass. |
| [ ] | AUT-002 | P0 | Eng/Design | 2 | AUT-001, FND-007 | Build sign-up, sign-in, sign-out and verification states. Errors do not disclose whether unrelated accounts exist. |
| [ ] | AUT-003 | P0 | Eng | 2 | AUT-001, INF-009 | Implement recovery and invitation app-link parsing. Cold, warm and already-running app tests pass. |
| [ ] | AUT-004 | P0 | Eng | 2 | AUT-003, DB-008 | Build invite acceptance flow with expired, used, revoked and wrong-email states. Acceptance is idempotent. |
| [ ] | AUT-005 | P0 | Eng/Product | 2 | AUT-002, DB-007 | Build owner organisation setup for name, timezone and initial criteria. Valid cycle-ready organisation is created. |
| [ ] | AUT-006 | P0 | Eng/Sec | 1 | AUT-001 | Handle revoked/expired sessions and secure sign-out. Local cached private data and push token binding are cleared. |
| [ ] | AUT-007 | P0 | QA | 2 | AUT-002..006 | Auth matrix on API 24, 33 and 36 physical/emulated devices. Evidence covers process death and email-link browsers. |

## Phase 50: member experience

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [ ] | MEM-001 | P0 | Design/Product | 2 | PRD, FND-007 | Finalise member flow wireframes and copy for empty, draft, open, voted, closed and revealed states. Accessibility annotations included. |
| [ ] | MEM-002 | P0 | Eng | 2 | MEM-001, AUT-004, DB-009 | Build current-cycle home with criteria, local dates, status and privacy explanation. Correct across timezones. |
| [ ] | MEM-003 | P0 | Eng | 2 | MEM-001, DB-002 | Build searchable eligible nominee list with avatars/team and self excluded. Responsive with 500 synthetic people. |
| [ ] | MEM-004 | P0 | Eng/Design | 2 | MEM-003, DB-010 | Build nomination reason and confirmation flow. 500-character cap, sensitive-data guidance and double-tap prevention work. |
| [ ] | MEM-005 | P0 | Eng | 2 | MEM-004, DB-011 | Build own-ballot receipt, withdrawal and recast. Closed-cycle attempts show server-derived refusal. |
| [ ] | MEM-006 | P0 | Eng | 1 | MEM-004 | Add offline/slow-network behaviour. No offline vote appears successful; retry is safe and idempotent. |
| [ ] | MEM-007 | P0 | Eng | 2 | MEM-002, DB-013 | Build closed/revealed states and winner history. No standings API is called while open. |
| [ ] | MEM-008 | P0 | Eng/Design | 2 | MEM-007 | Build accessible in-app winner card with synthetic share preview. Native image sharing stays P1. |
| [ ] | MEM-009 | P0 | Eng | 1 | AUT-001 | Add notification preference settings and permission rationale. Denial does not block any core screen. |
| [ ] | MEM-010 | P0 | QA | 3 | MEM-002..009 | End-to-end member tests: invite, open cycle, self denial, cast, duplicate denial, withdraw, recast, close and reveal. |
| [ ] | MEM-011 | P1 | Eng | 2 | MEM-003 | Add recently nominated/search convenience without creating popularity rankings or leaking vote history. |

## Phase 60: administrator experience

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [ ] | ADM-001 | P0 | Design/Product | 2 | PRD, PRE-013 | Finalise administrator information architecture and confidentiality copy. It never promises access to voter identities. |
| [ ] | ADM-002 | P0 | Eng | 3 | ADM-001, DB-002, DB-008 | Build roster add/edit/deactivate, eligibility and invite lifecycle. Risky changes require confirmation and are audited. |
| [ ] | ADM-003 | P0 | Eng | 2 | ADM-001, DB-009 | Build draft cycle create/review with period, criteria, dates and eligibility summary. Invalid setup cannot open. |
| [ ] | ADM-004 | P0 | Eng | 2 | ADM-003 | Build open, close and reopen actions using expected version. Two-admin race test gives one winner and one clear refresh message. |
| [ ] | ADM-005 | P0 | Eng | 2 | DB-014, ADM-003 | Build aggregate turnout display. Screen and accessibility tree contain no named non-voter list. |
| [ ] | ADM-006 | P0 | Eng | 2 | DB-012, PRE-013 | Build post-close moderation queue and reported-content exception. No voter identity or precise timestamp is rendered/logged. |
| [ ] | ADM-007 | P0 | Eng | 2 | DB-013, ADM-004 | Build standings after close and reveal preview. Open-state deep link receives no results. |
| [ ] | ADM-008 | P0 | Eng | 2 | ADM-007 | Build tie resolver limited to joint leaders with required note. Clear winner cannot be overridden. |
| [ ] | ADM-009 | P0 | Eng | 2 | ADM-007, ADM-008 | Build reveal confirmation and terminal revealed state. Winner snapshot remains after participant deactivation. |
| [ ] | ADM-010 | P0 | Eng | 2 | DB-015 | Build safe audit timeline for cycle/roster actions. Ballot cast lines contain cycle only. |
| [ ] | ADM-011 | P0 | QA/Sec | 3 | ADM-002..010 | Admin end-to-end and confidentiality test on a three-person organisation. Reviewer cannot infer voter through payload inspection. |
| [ ] | ADM-012 | P1 | Eng | 3 | ADM-002 | Add CSV roster import with preview, normalisation, duplicates and per-row errors. It never creates auth links by silent email match. |

### Gate G3 exit

- Auth, member and administrator P0 cards complete.
- Two synthetic organisations complete independent cycles.
- Clear, tied and zero-vote outcomes behave as specified.
- Confidentiality review passes on a three-person organisation.

## Phase 70: privacy, governance and communications

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [ ] | PRV-001 | P0 | Legal/Product | 3 | PRE-013, PRE-015 | Confirm controller/processor model, lawful instructions, employment-use disclaimer and whether a DPIA template is required. Written review logged. |
| [ ] | PRV-002 | P0 | Legal/Product | 3 | PRV-001 | Draft privacy notice, terms, DPA and subprocessor list for actual architecture. No generic claims unsupported by the product. |
| [ ] | PRV-003 | P0 | Eng | 2 | DB-003, PRE-013 | Implement per-organisation retention setting and safe default. Members can read the current policy. |
| [ ] | PRV-004 | P0 | Eng/Sec | 3 | PRV-003, DB-015 | Implement dry-run and live retention purge for revealed cycles only. Synthetic tests preserve winner snapshot and active work. |
| [ ] | PRV-005 | P0 | Eng/Legal | 3 | DB-003, PRV-001 | Implement subject export with asymmetric confidentiality rules. Test proves authors of reasons about others are not disclosed. |
| [ ] | PRV-006 | P0 | Eng/Legal | 3 | DB-003, PRV-001 | Implement leave organisation and account deletion state machine, including sole-owner block and session revocation. |
| [ ] | PRV-007 | P0 | Eng/Ops | 2 | PRV-006, INF-008 | Build public deletion request page and verified request endpoint. Former user can initiate without app installation. |
| [ ] | PRV-008 | P0 | Eng | 2 | PRV-006 | Implement owner transfer and organisation deletion with recovery-window decision. Cascades verified on seeded data. |
| [ ] | PRV-009 | P0 | Product/Eng | 1 | PRV-002..008 | Build in-app Privacy centre: confidentiality, retention, export, leave and delete. Copy matches actual behaviour. |
| [ ] | PRV-010 | P0 | QA/Legal | 3 | PRV-004..009 | Run privacy workflow rehearsal from request to completion, including retained winner record explanation. Evidence is synthetic. |
| [ ] | COM-001 | P0 | Eng/Ops | 2 | INF-003, DB-008 | Implement invitation email through trusted function with idempotency and redacted logs. SPF/DKIM/DMARC test passes before production. |
| [ ] | COM-002 | P0 | Eng | 2 | INF-006, MEM-009 | Register/rotate/revoke native FCM tokens. Unregistered token response disables the token. |
| [ ] | COM-003 | P0 | Eng/Product | 3 | COM-002, DB-014 | Implement cycle-open, non-voter reminder and winner-revealed jobs. Payload is generic; per-user preferences and idempotency pass. |
| [ ] | COM-004 | P0 | Eng | 1 | COM-003 | Add delivery receipt and retry policy with bounded attempts. A retry never sends two logical reminders. |
| [ ] | COM-005 | P0 | QA | 2 | COM-003, COM-004 | Physical-device notification matrix: permission granted/denied, token rotation, lock screen, deep link, stale cycle and sign-out. |
| [ ] | COM-006 | P1 | Eng | 2 | COM-003 | Add optional transactional email reminders with the same preference and idempotency rules. |

### Gate G4 exit

- Public and in-app deletion paths work.
- Retention, export and organisation deletion are tested.
- Legal/policy copy matches actual data flows.
- Notifications are generic, optional and idempotent.

## Phase 80: security, accessibility and quality

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [ ] | SEC-001 | P0 | Sec/Eng | 2 | G4 | Update threat model for final app, functions, links, notifications and deletion. Every high threat has an implemented control. |
| [ ] | SEC-002 | P0 | Sec | 3 | SEC-001 | Mobile and API security review against OWASP MASVS-relevant controls and tenant abuse cases. No open P0/P1 finding. |
| [ ] | SEC-003 | P0 | Eng | 1 | FND-006, G4 | Generate dependency SBOM, audit packages and review native SDK data collection. Accepted exceptions have owners/dates. |
| [ ] | SEC-004 | P0 | Eng/Ops | 1 | INF-002, G4 | Verify production secrets, key scope, rotation procedure and no client service key. Secret scanning is green. |
| [ ] | SEC-005 | P0 | Eng/Sec | 1 | SEC-002 | Add rate limits/abuse controls for auth, invitations, casts, reports and deletion requests. Legitimate flows still pass. |
| [ ] | A11Y-001 | P0 | QA/Design | 3 | G4 | TalkBack audit of all P0 journeys. Focus order, names, roles, state and errors are correct. |
| [ ] | A11Y-002 | P0 | QA/Design | 2 | G4 | Font scaling, colour contrast, touch target, motion and colour-only state audit. No clipped core action at maximum supported font. |
| [ ] | QA-001 | P0 | Eng/QA | 2 | G4 | Test API 24, 33, 35 and 36; phone, resizable/tablet, light/dark and portrait/landscape where supported. |
| [ ] | QA-002 | P0 | QA | 2 | G4 | Network matrix: offline, high latency, timeout, 401, 403, 409, 429 and 5xx. No false success or infinite spinner. |
| [ ] | QA-003 | P0 | QA | 2 | G4 | Lifecycle matrix: process death, background token refresh, update install, clock/timezone change and notification deep link. |
| [ ] | QA-004 | P0 | Eng/QA | 2 | G4 | Performance test at 500 participants and 10,000 historic nominations. Home and nominee list meet budgets. |
| [ ] | QA-005 | P0 | QA | 2 | G4 | Run full Maestro critical suite from clean accounts against preview. All tests repeat three times without flake. |
| [ ] | QA-006 | P0 | Eng | 1 | QA-001 | Build release AAB targeting API 36. `expo-doctor`, Android lint and build checks pass. |
| [ ] | QA-007 | P0 | Eng | 1 | QA-006 | Inspect AAB for permissions, signing, exported components and 16 KB native library support. Evidence attached. |
| [ ] | QA-008 | P0 | Product/QA | 1 | QA-005..007 | Triage all defects. Zero open P0/P1; accepted P2 items appear in this board. |

### Gate G5 exit

- Security and accessibility reviews pass.
- Release AAB targets API 36 and supports 16 KB pages.
- No P0/P1 defect.
- Critical E2E suite is repeatable.

## Phase 90: Play Console and internal release

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [ ] | PLY-001 | P0 | Ops | 2 | PRE-012 | Complete/verify organisation Play developer account, public details, 2FA and least-privilege users. |
| [ ] | PLY-002 | P0 | Ops/Product | 1 | PLY-001, PRE-011 | Create Play app and register final package. Confirm Android developer verification status before first upload. |
| [ ] | PLY-003 | P0 | Ops/Eng | 1 | PLY-002, QA-006 | Enrol in Play App Signing, create separate upload key and place it in approved vault. Record fingerprints, not private material. |
| [ ] | PLY-004 | P0 | Design/Product | 3 | PRE-011, G4 | Produce icon, feature graphic and phone/tablet screenshots with synthetic data. Assets meet current Play dimensions. |
| [ ] | PLY-005 | P0 | Product | 2 | PLY-004, PRV-002 | Finalise title, descriptions, category, contact, privacy and support URLs. Listing makes no unsupported claim. |
| [ ] | PLY-006 | P0 | Product/Legal | 2 | PLY-005, SEC-003 | Complete Data safety evidence from final SDK/data inventory. Independent review matches actual traffic. |
| [ ] | PLY-007 | P0 | Product/Legal | 1 | PLY-005 | Complete ads, target audience, content rating, app access and account deletion declarations. Reviewer instructions use a safe test tenant. |
| [ ] | PLY-008 | P0 | Eng/Ops | 1 | PLY-003, QA-007 | Upload signed AAB to internal track. Install and update through Play on two physical devices. |
| [ ] | PLY-009 | P0 | QA | 2 | PLY-008 | Review Play pre-launch report and Android vitals. Fix or explicitly disposition every issue. |
| [ ] | PLY-010 | P0 | Ops | 1 | PLY-008 | Verify app links using Play signing certificate and production association file. Email invite opens installed app. |
| [ ] | PLY-011 | P0 | Product/QA | 2 | PLY-008..010 | Run internal test script with at least five accounts across two organisations. No P0/P1 issue. |

## Phase 100: closed beta

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [ ] | BET-001 | P0 | Product | 2 | PRE-015, G5 | Recruit at least 12 engaged testers and 3 to 5 organisations. Consent, contact and device mix recorded securely. |
| [ ] | BET-002 | P0 | Product/Ops | 1 | BET-001, PLY-011 | Create closed track, tester group, opt-in link and feedback route. Confirm current Console production-access requirement. |
| [ ] | BET-003 | P0 | Product | 1 | BET-002 | Publish beta onboarding, test script, confidentiality limits and support expectations. |
| [ ] | BET-004 | P0 | Ops/Eng | 14 elapsed days | BET-003 | Run at least 14 continuous days. Monitor crash-free users, jobs, auth mail, push, support and privacy requests daily. |
| [ ] | BET-005 | P0 | Product/Data | 2 | BET-004 | Analyse activation, invite acceptance, turnout, completion time and second-cycle intent using content-free metrics. |
| [ ] | BET-006 | P0 | Product/Research | 3 | BET-004 | Interview at least three owners and six employees. Test fairness, confidentiality and willingness-to-pay understanding. |
| [ ] | BET-007 | P0 | Eng/QA | 3 | BET-004 | Resolve beta P0/P1 defects and repeat regression suite. Ship closed-track update if needed. |
| [ ] | BET-008 | P0 | Product | 1 | BET-005..007 | Write go/pivot/stop memo against PRD thresholds. No vanity metric substitutes for repeat-cycle evidence. |
| [ ] | BET-009 | P0 | Ops/Product | 1 | BET-004, BET-008 | Apply for production access if the actual Play account requires it and evidence supports readiness. |

### Gate G6 exit

- Applicable tester count and duration satisfied.
- At least one complete cycle observed per beta organisation where practical.
- No open privacy, tenant or ballot-integrity issue.
- Product decision memo recommends production with evidence.

## Phase 110: production release

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [ ] | REL-001 | P0 | Eng/Ops | 2 | G6 | Provision production Supabase Pro project and replay verified migrations. Backups, alerts and spend cap confirmed. |
| [ ] | REL-002 | P0 | Ops/Sec | 1 | REL-001 | Configure production SMTP, FCM and app-link secrets through vault-backed process. Rotation test documented. |
| [ ] | REL-003 | P0 | Product/Legal | 1 | G6, PLY-006 | Recheck Play policy, privacy, Data safety and account deletion against final binary and current rules. |
| [ ] | REL-004 | P0 | Eng/QA | 2 | REL-001..003 | Run production smoke with synthetic tenant, then erase it. No production employee data used. |
| [ ] | REL-005 | P0 | Ops | 1 | REL-004 | Prepare release notes, support runbook, incident contacts, rollback and unpublish procedure. |
| [ ] | REL-006 | P0 | Product | 0.5 | REL-005 | Obtain explicit production submission approval. Approval includes UK-only and staged percentages. |
| [ ] | REL-007 | P0 | Ops | 0.5 | REL-006 | Submit production release at 10% UK rollout. Record Play review state and artefact version. |
| [ ] | REL-008 | P0 | Ops/Eng | 2 elapsed days | REL-007 | Hold 10% for at least 48 hours while reviewing vitals, jobs, delivery and support. Halt thresholds enforced. |
| [ ] | REL-009 | P0 | Product/Ops | 1 | REL-008 | Approve 25%, 50% and 100% stages separately with evidence at each stage. |
| [ ] | REL-010 | P0 | Product | 1 | REL-009 | Publish launch report with installs, activation, errors, support and next decision. No employee-level data. |

## Phase 120: post-launch learning and P1 backlog

Start these only after production evidence or an explicit beta decision.

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [ ] | P1-001 | P1 | Product | 2 | BET-008 | Decide whether CSV import solves a measured onboarding problem; activate `ADM-012` only if yes. |
| [ ] | P1-002 | P1 | Product/Eng | 3 | BET-008 | Design automatic close with timezone, retry and administrator override. No automatic reveal. |
| [ ] | P1-003 | P1 | Product | 2 | BET-006 | Test required reasons and minimum length against turnout and quality before building configuration. |
| [ ] | P1-004 | P1 | Product | 2 | BET-006 | Test previous-winner cooldown and team award demand. Document fairness trade-offs. |
| [ ] | P1-005 | P1 | Eng/Design | 3 | MEM-008 | Add native shareable winner image without storage permission. Synthetic screenshot tests pass. |
| [ ] | P1-006 | P1 | Eng | 3 | COM-003 | Add in-app notification inbox with retention and read state. No ballot content. |
| [ ] | P1-007 | P1 | Product/Eng | 5 | Evidence | Add web administrator companion only if owners demonstrate desktop need. Same APIs/RLS, no second backend. |
| [ ] | P1-008 | P1 | Product/Legal | 5 | Repeat-cycle and WTP evidence | Decide monetisation and complete a fresh Play billing/policy review before any paywall code. |
| [ ] | P1-009 | P2 | Product | 5 | Multi-org evidence | Add organisation switcher while preserving tenant cache isolation. |
| [ ] | P1-010 | P2 | Product/Eng | 8 | Validated demand | Explore multiple award categories. Split before implementation. |

## Stop-the-line conditions

Pause release work immediately if any of these occur:

- cross-organisation data access;
- self or duplicate nomination accepted;
- voter identity exposed to another member or normal administrator API;
- ballot content appears in logs, analytics, push or email;
- account deletion cannot revoke access;
- package, signing key or publisher ownership is uncertain;
- Play Data safety declaration differs from observed SDK traffic;
- a production migration is not reproducible from Git;
- a high-severity dependency or credential exposure has no mitigation.

Resume only after root cause, impact, fix, regression test and decision owner are
recorded.

## Board metrics

Track weekly once implementation is authorised:

- cards completed by phase, not raw story points;
- blocked-card age;
- escaped P0/P1 defects;
- automated critical-flow coverage;
- RLS adversarial cases passed;
- build reproducibility;
- beta owner activation and second-cycle creation;
- beta eligible-voter turnout;
- crash-free users;
- privacy request completion time.

Do not use lines of code, number of screens or notification sends as success
metrics.
