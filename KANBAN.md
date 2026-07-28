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
| [x] | INF-003 | P0 | Ops/Eng | 1 | INF-002 | Auth mail moved off the built-in Supabase mailer, which allowed only two messages an hour and delivered only to project members. Now sends through Resend on `jonnyai.co.uk`, whose DKIM and SPF records are verified, at `recognition@jonnyai.co.uk` as `Employee of the Month`, one message per address per 60 seconds and 100 per hour project wide. Applied by `scripts/apply-smtp-config.ps1`, which refuses to install a credential Resend rejects. Uses this product's own `RESEND_API_KEY`, a distinct key rather than a copy of a shared one, so another product's rotation cannot break sign-up here. A real email was sent to a live address on 25 July 2026 and Resend records it `delivered` at 19:05:44 UTC, meaning the receiving server accepted it. The full SMTP path was also proved independently by `scripts/probe-smtp.ps1`, which authenticates and offers the envelope but quits before `DATA`: credentials, sender and recipient are all accepted. Repeatable via `scripts/send-test-email.ps1`, which requires an explicit recipient. The message was received and acted on: Jonny opened it and followed the confirmation link, which produced a valid confirmed session. Auth mail therefore works end to end from send to confirmation. Note the subject is `Confirm your email address` rather than a magic link, because `create_user` was set and the address was new to the project, which is part of why it was hard to spot. Inbox placement across providers is `INF-016`, and the confirmation link's redirect is `INF-009`. |
| [x] | INF-014 | P1 | Eng/Sec | 0.5 | INF-003 | Sending-only Resend key created by Jonny and installed as the SMTP credential. Verified restricted: it returns 401 on every read endpoint, including `/api-keys`, and 422 on a `POST /emails` with an invalid body, which proves send permission without sending anything. The over-privilege warning in `apply-smtp-config.ps1` is now silent, which is the evidence. Imported to jvault by file rather than `--value`, so the key never entered a command line or process list. |
| [ ] | INF-015 | P1 | Ops/Sec | 0.25 | INF-014 | Delete the now-superseded full-access Resend key named `employee-of-the-month-dev`, created 25 July 2026 at 18:15. It is no longer used by anything but still grants full read and key-creation rights on the Resend account. An unused credential is only a liability. |
| [ ] | INF-016 | P0 | Eng/Ops | 1 | INF-003 | Deliverability, before invitations carry any weight. A test message was accepted by the receiving server but the recipient could not find it, which is the failure mode that matters: invitation mail is the only route a new employee has into the programme, so spam placement is a functional defect rather than a marketing concern. Needs a DMARC policy for `jonnyai.co.uk`, a sender name recipients will recognise, a plain-text alternative part alongside the HTML, and a seed test across Gmail, Outlook and at least one corporate filter. Evidence: an inbox screenshot per provider, not a provider-side `delivered` status. |
| [ ] | INF-017 | P1 | Eng | 1 | INF-003, DB-003 | Record Resend delivery webhooks into `notification_deliveries` so an operator can answer "what happened to that message" without a credential that can read the whole Resend account. Today that question could only be answered by borrowing another product's full-access key, which is exactly what `INF-014` set out to avoid. `jvault` project `jonnyai-web` already holds a `RESEND_WEBHOOK_SECRET` pattern to follow. |
| [ ] | INF-004 | P0 | Ops | 1 | PRE-012 | Create Firebase Android project matching final package ID. No Analytics product enabled by default. |
| [ ] | INF-005 | P0 | Eng/Ops | 2 | INF-004, FND-010 | Configure native FCM development credentials and obtain a device token on physical hardware. |
| [ ] | INF-006 | P0 | Eng | 2 | INF-005, INF-002 | Spike one generic FCM HTTP v1 message from a Supabase Edge Function. Secret stays server-side; receipt is recorded. |
| [x] | INF-007 | P0 | Eng | 1 | INF-001, FND-005 | Separate `database` job in `.github/workflows/ci.yml` starts the local Supabase stack, replays every migration from empty, runs the SQL suites, then **replays and re-runs a second time**, which is what catches a migration that only works against a database where an earlier version once ran. No secret is used: the local stack mints throwaway keys, so CI never touches the hosted project. `db lint` is pinned to `--level warning --fail-on warning`, because without `--fail-on` it reports findings and still exits 0, which would make the step decorative. Hosted run `30172989614` green in 3m55s, and the log confirms the work genuinely happened rather than being skipped: all six migrations applied three separate times, `Files=3, Tests=92` passing twice, `No schema errors found`. |
| [x] | INF-018 | P0 | Eng | 0.25 | INF-007 | CI trigger fixed to include `agent/**` pushes. When PR #1 merged, the `pull_request` event stopped firing and the only remaining filter was `push` to `main`, so eleven commits of schema and security work ran with no checks at all. This is the worst shape a CI gap takes: a failing run is loud, but a run that never happens is indistinguishable from a green one on the branch view, and nothing reports it. |
| [ ] | INF-008 | P0 | Ops | 1 | PRE-012 | Confirm public HTTPS host for privacy, terms, deletion and app-link association pages. No page is deployed yet without approval. |
| [ ] | INF-009 | P0 | Eng/Ops | 2 | INF-008, FND-002 | Android App Links over HTTPS, with the custom scheme kept only as a fallback. **Raised in priority by a real failure:** a signup confirmation link resolved to `http://uk.co.jonnyai.employeeofthemonth//#access_token=...`, because a custom scheme is rewritten by mail clients and browsers and has no handler on a desktop. Two problems, not one. First, it does not work outside a device with the app installed. Second, and worse, **a custom scheme is not exclusive**: any installed app may register the same scheme and receive whatever the link carries. For a product whose premise is ballot confidentiality, an interception route into the auth flow is not acceptable. App Links are verified against `assetlinks.json` on a domain we control, cannot be claimed by another app, and degrade to a web page when the app is absent. Needs the Play signing fingerprint, so it cannot be finalised before `PLY-*`. |
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
| [x] | UI-CONF-01 | P0 | Eng/Design | 1 | DOM-004, ADM-cycle screens | `FR-CYCLE-04` warning live on the administrator screen, which is where it belongs: `can_vote` is withheld from the roster grant, so only an administrator can obtain the eligible-voter count, via `get_cycle_turnout`. Rendered as a full card with `accessibilityRole="alert"`, not help text, because `D-022` is about not implying a protection the arithmetic cannot support and a footnote implies exactly that. Two levels of wording, with the stronger one for two voters or fewer. Verified in a browser against the seed: Alpha shows the warning at four eligible voters. |
| [x] | DB-001 | P0 | Eng | 2 | INF-001, PRE-013 | `docs/SCHEMA_THREAT_MODEL.md` **signed off by Jonny on 25 July 2026**, unblocking `DB-002` onwards. Contains assets ranked by harm, trust boundaries, six actors, a per-table Data API exposure matrix, the guarded function surface with its hardening rules, ten threats with controls and stated residual risk, the six-role test matrix and eleven named tests. Key decisions: `recognition_nominations` gets no client grant at all rather than a restrictive policy, `participants` is granted as a column subset withholding `user_id` and `can_vote`, and the admin response truncates timestamps to the day and orders by name rather than time. All four open questions resolved as `D-022` to `D-025`. Note recorded in the document: both sign-off rows carry the same name, so no independent review has happened; `DB-018` and a re-review by someone who did not write it are release gates before real employee data. |
| [x] | DB-002 | P0 | Eng | 2 | DB-001 | `20260725184346_identity_and_roster.sql`: `private` schema, shared trigger functions, then profiles, organisations, organisation_members, participants and organisation_invitations. Every table created fail-closed, RLS enabled with no policy and no grant, so no window exists where a table is reachable before `DB-005` opens it. Tenant coherence is structural: invitations reach participants through a composite `(organisation_id, id)` key, so a cross-tenant reference is impossible even for the service role. `organisation_id` immutability enforced by trigger. Profiles are bootstrapped from an `auth.users` trigger, without which the table could never be populated, since the exposure matrix grants no INSERT. Clean replay from empty passes twice; `supabase db lint` clean. |
| [x] | DB-003 | P0 | Eng | 2 | DB-001, DOM-002 | `20260725184758_recognition_cycles_and_ballots.sql`: cycles, nominations, ballot events, settings, audit, push tokens, deliveries and privacy requests, all fail-closed. Two invariants are CHECK constraints rather than trigger logic, so a future function author cannot forget them: no self-nomination, and winner data existing if and only if the cycle is revealed. The second is what makes the threat model's "no window where a populated winner is visible on an unrevealed cycle" structurally true rather than a promise about the reveal function. `recognition_ballot_events` deliberately has no actor column, per `D-024`. Clean replay passes twice. |
| [x] | DB-004 | P0 | Eng/Sec | 2 | DB-002 | `20260725191805_rls_helpers.sql`: `current_user_id`, `is_org_member`, `has_org_role`, `participant_for_user`. All `SECURITY DEFINER` so a policy on `organisation_members` can ask about membership without recursing into the table it protects, and all `STABLE`, read-only, `search_path` pinned, taking the user from `auth.uid()` rather than an argument so nobody can ask on another's behalf. Membership is read live, so a departed member loses access on the next request rather than at token expiry. **Correction:** the threat model claimed `authenticated` would hold no `USAGE` on `private`; policy expressions are evaluated with the caller's privileges, so that was unimplementable. `USAGE` plus `EXECUTE` on only the two policy-referenced helpers is granted. The real control is the exposed-schema list, verified: `rpc/is_org_member` returns `PGRST202`. |
| [x] | DB-005 | P0 | Eng/Sec | 3 | DB-002, DB-004 | `20260725191809_identity_grants_and_policies.sql`: the first migration that makes anything reachable. `profiles` own-row select plus a `display_name`-only update grant; `organisations` and `organisation_members` readable by active members; `participants` granted as a seven-column subset that withholds `user_id`, `can_vote` and timestamps; `organisation_invitations` granted nothing at all. Every update policy carries both `USING` and `WITH CHECK`. Covered by 33 role-based assertions in `supabase/tests/002_rls_policies.test.sql` across signed-out, member, admin, owner, departed member and other-tenant owner. |
| [x] | DB-006 | P0 | Eng/Sec | 3 | DB-003, DB-004 | `20260725191812_recognition_grants_and_policies.sql`: `recognition_cycles` readable by members, `recognition_settings` as a three-column transparency subset, and **no grant at all** on nominations, ballot events, audit events, push tokens, deliveries or privacy requests. Proven at the SQL layer and through PostgREST that member, admin and owner are each refused `42501` on `recognition_nominations`, including a bare `count(*)`, which would otherwise leak live turnout. |
| [x] | DB-007 | P0 | Eng | 2 | DB-002, DB-005 | `20260725195839_create_organisation.sql`, the first thing a client may write. One transaction produces four rows that must exist together: the organisation, the creator's ownership, the creator's roster entry and the programme settings. A grant cannot express "and also make me the owner", and a client doing this in four requests can fail after the first and leave an organisation nobody can administer. Verified email required, read from `auth.users` rather than a JWT claim. The owner is taken from `auth.uid()`, never an argument. Refusals return product error codes rather than constraint names. First function in `public`, so `EXECUTE` is revoked from `PUBLIC` and `anon` and granted only to `authenticated`; confirmed through PostgREST that anon gets `42501` rather than `404`, and that the `private` helpers still return `404`. 23 assertions covering caller identity, every refusal, and the resulting rows one by one. |
| [x] | DB-008 | P0 | Eng/Sec | 3 | DB-002, DB-005 | `20260725201701_invitations.sql`: `create_invitation`, `revoke_invitation`, `accept_invitation`. An invitation is an identity, so the design assumes the token will leak. Only a SHA-256 hash is stored, so a database read yields nothing usable. The token is bound to an intended email verified against `auth.users`, which is what makes a leaked token worthless and what makes it safe for an admin to hold one. 256 bits from `gen_random_bytes`, so guessing is not a threat and expiry can be days. Acceptance consumes the token, links the participant and creates membership in one transaction with `for update`, so concurrent redemptions cannot both pass; if the participant was linked meanwhile, the consumption rolls back too rather than burning the invitation for nothing. Reissue revokes the previous token first, so an intercepted earlier email dies immediately. The organisation is derived from the participant row, never a parameter. 30 assertions covering wrong email, unverified account, replay, revocation, reissue, cross-tenant and non-member. |
| [x] | DB-009 | P0 | Eng/Sec | 2 | DB-003, DB-006, DOM-002 | `20260725202654_cycle_lifecycle.sql`: `create_cycle` and `transition_cycle`. The state machine is already a table constraint; the function adds the two things a constraint cannot do. `expected_version` is mandatory, so two administrators pressing close on the same screen produce a deterministic `40001` rather than a silent lost update. Opening validates `FR-CYCLE-02`: at least two eligible recipients and one eligible voter, refused at the point of opening rather than discovered at close with no result. `revealed` is unreachable here by design. A mid-month date is normalised rather than rejected. **Bug found by test:** `now()` is constant within a transaction, so opening and closing in one stamped both with the same instant and broke the `closes_at > opens_at` constraint; both stamps now use `clock_timestamp()`, which is also the more honest value. |
| [x] | DB-010 | P0 | Eng/Sec | 3 | DB-003, DB-006, DOM-002 | `20260725202658_ballot_cast_and_withdraw.sql`: `cast_nomination` and `withdraw_nomination`. The voter comes from `auth.uid()`, never an argument, so nobody can vote on another person's behalf. The ballot row is locked for the transaction, so a double tap cannot produce two. An idempotency key returns the original ballot on retry rather than erroring, which is what makes a client retry after a dropped connection safe. Withdrawing marks the row rather than deleting it, so the voter keeps their single slot and a recast reuses it: withdraw-then-vote-again cannot become two ballots. A nominee in another tenant is indistinguishable from one that does not exist. **Bug found by test:** the `idempotency_key` parameter collided with the column of the same name and raised `42702`; parameters are now qualified with the function name so the RPC argument names still match the fields they set. |
| [x] | DB-011 | P0 | Eng/Sec | 2 | DB-010 | `get_my_nomination` is scoped to `auth.uid()` by construction and takes no voter argument, so no call shape exists that returns another person's ballot: not a wrong one, not a guessed one, none. The return type omits `nominator_user_id` even though the caller is the nominator, so a future change to the caller cannot start returning identity by accident. Asserted by having two different voters make the identical call and receive their own ballots, and a third who has not voted receive nothing rather than somebody else's. |
| [x] | DB-012 | P0 | Eng/Sec | 3 | DB-010, PRE-013 | `get_admin_nominations` and `moderate_nomination`. The return type does the work: a policy can filter rows but cannot hide a column, so voter identity is simply absent from the declared output and no bug in the body can leak it. Timestamps are truncated to the day and results ordered by nominee name, never by time, because a time-ordered list hands back the sequence that truncation exists to remove. `D-014` enforced: reasons are unavailable while voting is open. **The contract test asserts the exact result signature by name**, so adding a column has to change the signature, which is visible in review. Hiding requires a recorded reason and an actor, and a revealed cycle can no longer be moderated. |
| [x] | DB-013 | P0 | Eng | 2 | DB-010, DOM-003 | `get_closed_standings` and `reveal_winner`, both reading `private.cycle_tally`, the single definition of the tally, so an administrator cannot be shown one result and have another revealed. Standings refuse while open rather than returning empty, because an empty set is indistinguishable from nobody having voted, which is itself information. Reveal recomputes rather than trusting the caller: a clear leader cannot be overridden, a tie must be resolved from among the joint leaders and carry a note, and a cycle with no ballots cannot be revealed. Status and winner snapshot are written together, so the winner-if-and-only-if-revealed constraint holds. |
| [x] | DB-014 | P0 | Eng | 2 | DB-010 | `get_cycle_turnout` returns eligible count, counted ballots and a percentage. Nothing else, and there is deliberately no variant returning who has or has not voted: the reminder job may privately identify non-voters in order to message them, but no interface may, because that turns a recognition programme into an attendance monitor. Asserted that the result type contains no `user_id`. Hidden and withdrawn ballots are excluded, so moderation does not inflate participation. |
| [ ] | DB-015 | P0 | Eng/Sec | 2 | DB-008..014 | Create audit event functions and safe metadata allowlist. Ballot events identify cycle only. |
| [x] | DB-016 | P0 | Eng | 1 | DB-002..015 | `src/types/database.ts` generated from the local schema and committed, covering every table and all fourteen guarded functions. CI regenerates and runs `git diff --exit-code`, so a schema change without a regenerated file fails the build. Without it the types drift silently: the schema moves, the checked-in file does not, and TypeScript keeps confirming a shape the database no longer has, which only surfaces at runtime. The check was verified to fail on a deliberately altered file rather than assumed to work. The file is excluded from Biome, because formatting generated output would make the drift comparison fail permanently. Bonus assurance: the generated `get_admin_nominations` type contains no nominator field and no precise timestamp, so the confidentiality contract is now also expressed in the app's own types. |
| [ ] | DB-017 | P0 | Eng/Sec | 2 | DB-005..015 | Run Supabase security/performance advisors and fix critical/high findings. Evidence stored without project secrets. |
| [ ] | DB-018 | P0 | Sec | 3 | DB-005..017 | Adversarial Data API review: IDOR, cross-tenant, function execute, view bypass, JWT staleness and service-key exposure. Zero P0/P1 findings. |
| [x] | DB-019 | P0 | Eng | 2 | DB-003 | `supabase/seed.sql`: two organisations, six roles across owner/admin/member, a participant who can be nominated but cannot vote, one on the roster with no account plus a live invitation, and four cycles covering revealed-with-a-clear-winner, revealed-after-a-tie, closed-awaiting-reveal and open-partially-voted, with a hidden and a withdrawn ballot. Months are relative to the current one so the fixture never rots into four historic cycles and nothing open. **Refuses to run off a local stack**, verified: the guard checks the well-known local demo JWT secret, so `db reset --linked` cannot write invented employees into a real project. Every address is on a reserved `.example` domain, so a stray invitation can reach nobody. `007_seed_integrity.test.sql` asserts the seed means what it says, after the first version carried a tie decision note on a cycle that was not tied. |
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
| [>] | AUT-001 | P0 | Eng | 2 | FND-008, INF-002 | Supabase React Native client initialised with AsyncStorage, refresh handling and `processLock`. Now pinned to **PKCE** rather than the default implicit flow: a real signup link returned the access and refresh tokens in the URL fragment, where they land in the address bar, browser history and anything that logs a URL. Those tokens had to be revoked. PKCE returns a single-use code that is worthless without the verifier in this client's storage. Remaining: session lifecycle tests, and the deep-link handler once `INF-009` settles App Links. |
| [x] | AUT-002 | P0 | Eng/Design | 2 | AUT-001, FND-007 | Sign-in, sign-up and sign-out work end to end against the local stack, verified in a browser. Sign-in failures return the same wording whether the address is unknown or the password wrong, so the screen cannot be used to discover which colleagues have accounts. Sign-up deliberately shows Supabase's own message instead, because it explains the password rules the person must satisfy and reveals nothing they did not already type. Errors carry `accessibilityRole="alert"`. |
| [>] | AUT-003 | P0 | Eng | 2 | AUT-001, INF-009 | The invitation link carries its token as a query parameter, read with `useLocalSearchParams`. The route guard exempts `/invite` while signed out, because redirecting an invited person to sign-in would throw the token away. Verified on web from a real emailed link. Remaining: the Android App Link and the cold, warm and already-running cases, which depend on `INF-009`. |
| [x] | AUT-004 | P0 | Eng | 2 | AUT-003, DB-008 | `src/app/invite.tsx`. Opens from the emailed link, offers create-account or sign-in, then accepts automatically once a session exists, so the person never has to understand that two separate things happened. Every refusal has its own wording driven by the database's product code: invalid, expired, consumed, revoked, wrong email, unverified, already a member, already claimed. The wrong-email message deliberately does not name the invited address, because whoever holds the link may not be the person it was sent to. **Verified end to end in a browser**: emailed link opened, account created, invitation accepted, landed on the member screen able to vote, roster entry linked and token consumed. |
| [ ] | AUT-005 | P0 | Eng/Product | 2 | AUT-002, DB-007 | Build owner organisation setup for name, timezone and initial criteria. Valid cycle-ready organisation is created. |
| [ ] | AUT-006 | P0 | Eng/Sec | 1 | AUT-001 | Handle revoked/expired sessions and secure sign-out. Local cached private data and push token binding are cleared. |
| [ ] | AUT-007 | P0 | QA | 2 | AUT-002..006 | Auth matrix on API 24, 33 and 36 physical/emulated devices. Evidence covers process death and email-link browsers. |

## Phase 50: member experience

| Status | ID | Pri | Owner | Est. | Depends | Outcome and completion evidence |
|---|---|---:|---|---:|---|---|
| [ ] | MEM-001 | P0 | Design/Product | 2 | PRD, FND-007 | Finalise member flow wireframes and copy for empty, draft, open, voted, closed and revealed states. Accessibility annotations included. |
| [>] | MEM-002 | P0 | Eng | 2 | MEM-001, AUT-004, DB-009 | `src/app/index.tsx` renders the current cycle with its criteria and month, choosing an open cycle over the most recent so a member between cycles sees the last result rather than an empty screen. Distinct states for no organisation, no cycle, open, already voted, not eligible to vote, closed and revealed, including the tie decision note. Remaining: rendering dates in the organisation's timezone rather than the device's. |
| [>] | MEM-003 | P0 | Eng | 2 | MEM-001, DB-002 | Nominee list renders eligible colleagues with their team, self excluded. Self-exclusion needed a new function: `participants.user_id` is withheld from the client grant, so the app cannot identify its own row from the table. `get_my_participant` returns the caller's own entry only, taking the user from `auth.uid()`. Confirmed in a browser that the signed-in member does not appear in their own list. Remaining: search and the 500-person responsiveness check. |
| [>] | MEM-004 | P0 | Eng/Design | 2 | MEM-003, DB-010 | Reason field capped at 500 with a live counter and the sensitive-data warning `FR-MOD-02` requires. Double taps are prevented by a submitting flag and by an idempotency key stable for the cycle and voter, so a retry after a dropped connection returns the original ballot rather than being refused as a second one. Selection shows a tick as well as a colour change, because colour must never carry state alone. Remaining: an explicit confirmation step before submitting. |
| [>] | MEM-005 | P0 | Eng | 2 | MEM-004, DB-011 | Own-ballot receipt, withdrawal and recast all work, verified in a browser and then checked in the database: after withdraw-then-recast the voter still holds exactly one ballot in the cycle, recorded as `recast` rather than a second `cast`. Refusals come from the function's own error hints mapped to product wording, never from message text, and an unrecognised code falls back to a neutral sentence rather than showing a Postgres error. Remaining: the closed-cycle refusal path exercised in the interface. |
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
| [>] | ADM-002 | P0 | Eng | 3 | ADM-001, DB-002, DB-008 | `src/app/roster.tsx` plus `get_roster`, `add_participant` and `update_participant`. The member column grant withholds `user_id` and `can_vote` from every client, administrators included, so roster management is a shaped admin-only surface rather than a table write. `get_roster` returns `has_account` as a boolean rather than the user id: whether somebody has joined is roster state an administrator needs, the auth identity behind it is not, and a boolean cannot be joined to anything. Verified in a browser against the seed, including that the nominate-only participant's vote toggle is genuinely off and the unlinked participant's is disabled with the reason stated. Remaining: CSV import and editing names. |
| [>] | ADM-003 | P0 | Eng | 2 | ADM-001, DB-009 | Invitations can be created from the roster screen, reissuing where one already exists. The raw token is deliberately discarded rather than shown: a token is a working identity for the invited person, and rendering it in an administrator's browser puts it in screenshots and scroll-back while still not reaching the person it belongs to. **Onboarding is therefore incomplete until `COM-001` sends the email**, and the screen says so plainly rather than appearing to have worked. |
| [>] | ADM-004 | P0 | Eng | 2 | ADM-003 | Cycle create, open and close from the administrator screen, each passing the version the screen was rendered with so a concurrent change is refused rather than silently overwritten. Verified end to end in a browser: created, opened, closed, and the version incremented at each step. Remaining: scheduled open and close times. |
| [ ] | ADM-005 | P0 | Eng | 2 | DB-014, ADM-003 | Build aggregate turnout display. Screen and accessibility tree contain no named non-voter list. |
| [x] | ADM-006 | P0 | Eng | 2 | DB-012, PRE-013 | Turnout shown as eligible, counted and percentage, and nothing else. Verified against the seed at four eligible and two voted. While a cycle is open the screen states plainly that no standings exist for anybody, rather than leaving an empty space that looks like a loading failure. |
| [>] | ADM-007 | P0 | Eng | 2 | DB-013, ADM-004 | Moderation view lists nominations with reason, status and a date only, ordered by nominee name. Hide and restore work and disappear once a cycle is revealed. The screen states that who wrote each one is not recorded and cannot be retrieved, which is true rather than reassurance. Remaining: an operator-entered moderation reason instead of the current fixed wording. |
| [x] | ADM-008 | P0 | Eng | 2 | ADM-007 | Standings appear only once closed, with shared competition ranks. Verified in a browser: two people tied on one nomination each both rank 1 and the next rank is 3. |
| [x] | ADM-009 | P0 | Eng | 2 | ADM-007, ADM-008 | Reveal implemented including the tie path. A tie disables the reveal action until a joint leader is chosen and a note written, and the note is stored with the result. Verified end to end: a genuine tie in the seed was resolved, revealed, and the reasoning then appeared on the member screen alongside the winner. |
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
| [>] | PRV-001 | P0 | Legal/Product | 3 | PRE-013, PRE-015 | `docs/LEGAL_AND_PRIVACY.md` drafted from the engineering side, so a solicitor reviews facts rather than assumptions: controller/processor analysis with the strongest counter-arguments listed rather than hidden, a data inventory taken from the live schema, lawful basis, the special-category free-text risk, and eight specific questions for the reviewer. **Not legal advice and not complete until a qualified person signs it off.** |
| [>] | PRV-002 | P0 | Legal/Product | 3 | PRV-001 | Draft privacy notice, employment-use disclaimer and subprocessor list in `docs/LEGAL_AND_PRIVACY.md`, written against what the code actually does. Every claim is traceable to a named file, and the confidentiality wording deliberately says confidential rather than anonymous because `nominator_user_id` exists. Terms and the DPA itself are not written, because each depends on answers to the open questions. Solicitor review pending. |
| [x] | PRV-003 | P0 | Eng | 2 | DB-003, PRE-013 | Per-organisation `retention_months` with a 12-month privacy-by-default, constrained to 3, 6, 12, 24 or null for indefinite, which `D-012` permits as an explicit choice. Members can read the current policy: it is in the three-column transparency grant on `recognition_settings`, so retention is a promise employees can check rather than take on trust. |
| [x] | PRV-004 | P0 | Eng/Sec | 3 | PRV-003, DB-015 | `purge_expired_nominations(dry_run)`, defaulting to a dry run, because a purge that deletes by default is one keystroke from an accident. Only revealed cycles past their retention period; draft, open and closed are never touched. It clears the reason text and keeps the ballot row, so the count that decided a past result stays verifiable and nothing can be re-cast into a revealed cycle. The winner snapshot survives, which works only because `DB-003` made it plain columns with no foreign key. `SECURITY DEFINER` and granted to `service_role`, so the scheduled job can run it **without** `service_role` holding delete rights on the ballot table. Nine assertions including idempotency on a second run. |
| [x] | PRV-005 | P0 | Eng/Legal | 3 | DB-003, PRV-001 | `export_my_data()`. The asymmetry is the point: what the subject wrote comes back with the nominee named, because they chose that person; what was written about them comes back with no author, ever. A subject access request must not become a way to learn who nominated you, and the return shape has nowhere to put an author. Reasons about the subject are also withheld while a cycle is open, since a live export would be the standings leak by another route. Asserted that the author's name, email and user id appear nowhere in the output. |
| [>] | PRV-006 | P0 | Eng/Legal | 3 | DB-003, PRV-001 | `request_account_deletion()` with the sole-owner block: the last active owner of an organisation cannot delete their account, because it would strand every colleague in a programme nobody can administer. Idempotent, since a person pressing delete twice means one deletion. `get_my_privacy_requests()` returns the caller's own requests and nobody else's. Remaining: the worker that performs the erasure, session and token revocation before auth deletion, and leaving an organisation. |
| [ ] | PRV-007 | P0 | Eng/Ops | 2 | PRV-006, INF-008 | Build public deletion request page and verified request endpoint. Former user can initiate without app installation. |
| [x] | PRV-008 | P0 | Eng | 2 | PRV-006 | `transfer_ownership`, `leave_organisation` and `delete_organisation`. Granting ownership does not demote the caller, so a mistyped transfer can never leave an organisation ownerless. Leaving unlinks the roster entry immediately rather than waiting for a token to expire, while keeping the row because past results point at it. Deletion is soft with a 30-day recovery window and requires the organisation's name typed back, **compared in the database** so a modified client cannot skip it. 23 assertions. **Found while writing it:** the policies on participants, cycles, members and settings were written before soft deletion existed and checked only membership, so a deleted organisation's data stayed readable everywhere except the organisations list. All four now check liveness. |
| [ ] | PRV-009 | P0 | Product/Eng | 1 | PRV-002..008 | Build in-app Privacy centre: confidentiality, retention, export, leave and delete. Copy matches actual behaviour. |
| [ ] | PRV-010 | P0 | QA/Legal | 3 | PRV-004..009 | Run privacy workflow rehearsal from request to completion, including retained winner record explanation. Evidence is synthetic. |
| [>] | COM-001 | P0 | Eng/Ops | 2 | INF-003, DB-008 | Invitation email implemented as the `send-invitation` Edge Function, so the token is created, sent and discarded server-side and never reaches the browser. Authorisation is not reimplemented: the function calls `create_invitation` with the caller's own JWT, so a bug there cannot grant more than the caller already had. Verified end to end locally, including that a plain member is refused, an unauthenticated request gets 401, the emailed token accepts once and a replay returns `invitation_consumed`. Idempotency keyed on the invitation id, logs redact email addresses. Both transports are a single fetch with no mail library. **Remaining:** the local transport exercises the function and the template but not Resend itself, which is `INF-016`, and SPF/DKIM/DMARC verification before production. |
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
