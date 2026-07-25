# Foundation build record

Date: 25 July 2026

Branch: `agent/standalone-app-planning`

Authority: local implementation approved by Jonny; no cloud deployment or
store submission authorised.

## Delivered in the build kick-off

- Replaced the pre-build Expo SDK 56 assumption with the current stable Expo
  SDK 57 baseline.
- Added an Android-first Expo Router shell with the provisional package and URL
  scheme `uk.co.jonnyai.employeeofthemonth`.
- Added an initial synthetic-data home screen and accessible 58dp primary
  action. No real employee data is present.
- Added a pure TypeScript recognition engine adapted from biz-os P08:
  cycle periods, legal transitions, separate voting/receiving eligibility,
  one-ballot and self-vote refusals, reason limits, turnout, tally, shared
  ranks, hidden standings and deterministic tie handling.
- Added strict TypeScript, Biome checks and 15 Node tests.
- Added lazy Supabase client creation backed by React Native AsyncStorage.
- Added validation that accepts only a public Supabase key and rejects
  service-role or legacy JWT-shaped keys.
- Pinned Supabase CLI 2.109.1 and initialised local Postgres 17 configuration.
- Added a least-privilege GitHub Actions workflow on Node 22.13.

## Verification evidence

The following commands passed locally:

```text
npm run check
  TypeScript: passed
  Biome: passed
  Tests: 15 passed, 0 failed

npm run doctor
  Expo Doctor: 17/17 checks passed

npx expo export --platform android --output-dir dist/android
  Android bundle: passed, 1 Hermes bundle produced

npx expo install --check
  Dependencies: compatible after patch alignment

GitHub Actions run 30164124076
  Hosted Node 22 quality job: passed in 1m2s
```

The local runtime was Node 25.2.1. CI deliberately uses Node 22.13.1, the
lowest supported SDK 57 baseline, to catch compatibility drift.

## Dependency review

`npm audit` reports zero critical and zero high findings. Eleven moderate
findings remain in Expo's native configuration dependency tree. npm's proposed
forced resolution is an obsolete Expo 46 downgrade, so no unsafe automatic
rewrite was applied. Recheck this upstream set on each dependency update and
before release.

## Environment limits found

- Docker CLI is installed, but the Docker Desktop Linux engine is not running.
  `supabase start` therefore cannot replay or test migrations yet.
- Java 17 is installed.
- Android SDK, `adb` and `sdkmanager` are not available on `PATH`, so an
  emulator debug build and screenshot are not yet valid evidence.
- No hosted Supabase, Firebase, EAS or Play Console resource was created.
- No secret or real employee data was added.

## Next safe tranche

1. Finish secret/dependency CI checks and obtain the first hosted green run.
2. Start Docker Desktop, replay the blank local Supabase environment, then
   write the schema threat model and exposure matrix before any migration.
3. Install Android Studio/API 36 tooling and produce the synthetic-data debug
   build evidence.
4. Add route groups and error/loading boundaries.
5. Implement the first database slice only after its RLS and function tests are
   written alongside it.

---

# Hosted development project link

Date: 25 July 2026

Authority: Jonny created the Supabase development project and loaded its
credentials into jvault. No schema, table, policy or function was created, and
no production or store resource was touched.

## What was done

- Added `scripts/with-vault.ps1`, which runs any command with the jvault
  project's secrets injected as environment variables. It takes the passphrase
  from `JVAULT_PASSPHRASE` or the DPAPI-protected passphrase file, prints key
  names only, and removes both the temporary export file and the injected
  variables afterwards. No secret value reaches the console, the repository or
  a durable file.
- Added `scripts/verify-supabase.ps1`, which proves the hosted project is
  correctly configured and reachable without printing a credential.
- Linked the repository to the development project. The link artefacts live in
  `supabase/.temp`, which is already git-ignored.

The project reference is deliberately not recorded here. It lives in jvault
project `employee-of-the-month-dev` alongside the URL, publishable key,
database password and CLI access token.

## Verification evidence

```text
scripts\verify-supabase.ps1
  [PASS] SUPABASE_PROJECT_REF present
  [PASS] EXPO_PUBLIC_SUPABASE_URL present
  [PASS] EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY present
  [PASS] URL matches project ref
  [PASS] key is a modern publishable key
  [PASS] key is not a secret key
  [PASS] key is not a legacy JWT
  [PASS] Data API authenticates publishable key - HTTP 404 PGRST205
  [PASS] Auth API reachable - email signup enabled, autoconfirm off
  [PASS] remote migration history readable - {"migrations":[]}

supabase migration list --linked   ->  no migrations
supabase inspect db table-stats    ->  no tables
```

The project is `ACTIVE_HEALTHY` on Postgres 17.6.1.147 in its own organisation,
separate from the biz-os Supabase account. That separation satisfies `D-001`,
and it also means the biz-os Supabase MCP connector cannot see this project;
all work here goes through the CLI with the jvault access token.

`mailer_autoconfirm` is false, so email verification is on as `FR-AUTH-01`
requires. Refresh token rotation is on.

## Two deliberate checks worth recording

The publishable key held in jvault was compared against the project's own key
list through the management API and matches the project's current publishable
key. It is not a secret key, not a service-role key and not a legacy JWT.

The database password was confirmed to no longer match the fragment that an
earlier masked vault listing exposed, so the rotation did take effect. It is
14 characters with mixed case, digits and symbols. That is acceptable for a
development project. Production should use a generated password of 32 or more
characters.

## A verification trap found and fixed

The first version of the check probed `GET /rest/v1/` and reported failure.
That endpoint is the PostgREST OpenAPI spec and Supabase returns `401` for it
even with a valid publishable key, so the check was wrong rather than the
credential. Requesting a table that cannot exist is the reliable probe: a
valid key returns `404 PGRST205` from PostgREST, while a request with no key
returns a bodyless gateway `401`. The two are unambiguous.

`scripts/verify-supabase.ps1` also avoids `2>$null` on the Supabase CLI.
Redirecting a native executable's stderr in Windows PowerShell 5.1 wraps each
line in an `ErrorRecord` and reports a false failure even on exit code 0.

## Findings raised as board cards

- `INF-003` is now a blocker for invitation work, not just a nicety. The
  project uses the default Supabase mail service, capped at two emails per hour
  and deliverable only to project members. Invitation and verification journeys
  cannot be exercised end to end until custom SMTP exists.
- `INF-011`: the Auth configuration is still at its defaults. Password minimum
  length is 6 with no required character classes, leaked-password protection is
  off, and it is the only open security advisor. `site_url` is
  `http://localhost:3000` and the redirect allow list is empty, neither of
  which suits a mobile app.
- `INF-012`: the project was created in `eu-west-1` (Ireland), not the
  recommended `eu-west-2` (London). A region cannot be changed after creation.
  This is harmless for development but the production region needs a deliberate
  decision.
- `INF-013`: the project still carries its generated default name rather than
  `employee-of-the-month-dev`.

## Still not done

No migration was written or applied. The remote database is an empty Postgres
instance, which is the correct state until `DB-001` produces the schema threat
model and exposure matrix.

---

# Auth and mail configuration

Date: 25 July 2026

Authority: Jonny approved changing the development project's Auth settings,
including the redirect configuration, and chose to reuse an existing Resend key
rather than create a dedicated one.

Both changes were made as scripts rather than dashboard clicks, so the intended
state is reviewable in the repository, the reasoning sits next to the values,
and the change can be replayed against a future preview or production project.
Both scripts are idempotent, support `-WhatIf`, and read every value back from
the API after writing rather than trusting the write.

## Auth baseline

`scripts/apply-auth-config.ps1` moved four settings off their defaults:

| Setting | Before | After |
|---|---|---|
| `password_min_length` | 6 | 12 |
| `password_required_characters` | none | lower, upper and digit |
| `site_url` | `http://localhost:3000` | the app's own scheme |
| `uri_allow_list` | empty | app scheme plus local web dev |

Symbols are deliberately not required. At a 12-character minimum they cost more
in abandoned mobile sign-ups than they add in entropy.

Expo Go's `exp://` URLs are deliberately absent from the redirect allow list,
because allowing them means a wildcard over a host we do not control, and the
allow list is what prevents an open redirect. This product needs a native
development build for FCM in any case, and the custom scheme works there.

The allow list must be revisited when `INF-009` settles the App Link host.

### One setting could not be applied

Leaked-password protection is refused with `402 Payment Required`. Supabase
gates HaveIBeenPwned behind the Pro plan and this project is on Free. It is
the project's only open security advisor and it closes when the project moves
to Pro, which `ARCHITECTURE.md` already requires before real closed testing.

Worth recording: the management API applies a `PATCH` atomically, so including
that one field silently prevented the other four from being written. The script
now sends plan-gated fields separately and reports them as skipped, so one
unavailable feature cannot quietly block a whole security baseline.

## Auth mail

`scripts/apply-smtp-config.ps1` moved auth mail to Resend. The built-in
Supabase mailer allows two messages an hour and delivers only to members of the
Supabase project, so it cannot support invitation or verification journeys at
all.

| Setting | Value |
|---|---|
| Host and port | `smtp.resend.com`, 587 |
| Sender | `recognition@jonnyai.co.uk` as `Employee of the Month` |
| Per-address frequency | one message per 60 seconds |
| Project rate limit | 100 per hour, up from 2 |

The script validates the key against the Resend API and confirms the sending
domain exists before writing anything, so a dead key cannot be installed
silently.

### What the domain check found

The shared `jonnyai.co.uk` domain reports `partially_failed`, which looks
alarming until the individual records are read. DKIM and SPF are both verified
and only the inbound `Receiving MX` record fails. That affects receiving mail,
not sending it, and this product does not receive mail. Sending is healthy.

Separately, the copy of the Resend key held in jvault project `bizos` is dead:
Resend answers `401` for it. Every other copy works. That is a biz-os problem
rather than one for this product, but it is the reason this script verifies the
key rather than assuming a vault entry is live.

### The shared credential was replaced the same day

The first configuration reused the `jonnyai` Resend key, which meant this
product's sign-up would break whenever another product rotated its key. Jonny
then created a dedicated `employee-of-the-month-dev` key on the same Resend
account and stored it in this product's vault project, and the configuration was
moved onto it. The account and sending domain are still shared, so an
account-level suspension would still affect several products, but the credential
is now independent, which was the part that mattered.

The key is full-access rather than sending-only, so it can also list and create
Resend API keys. That is more privilege than an SMTP sender needs, and more than
belongs in a project's auth configuration. Resend cannot narrow an existing key,
so `INF-014` covers creating a restricted replacement.
`scripts/apply-smtp-config.ps1` warns on every run while the key is
over-privileged, so the warning disappearing is the evidence that card is done.

### A PATCH that quietly undid the whole configuration

Swapping the credential looked like it should be a one-field write, since
`smtp_pass` is the only thing changing. Sending only `smtp_pass` cleared
`smtp_host`, `smtp_port`, `smtp_user`, `smtp_admin_email`, `smtp_sender_name`
and reset `rate_limit_email_sent` to 2. Supabase treats the SMTP block as a
unit, so omitting a field is read as clearing it rather than leaving it alone.

The project silently reverted to the built-in mailer and its two-per-hour cap.
Nothing errored. It was caught only because the script reads every value back
after writing instead of trusting the write, which is the argument for doing
that as a habit rather than when it feels warranted.

`scripts/apply-smtp-config.ps1` now always sends the complete desired set. It
also gained `-SetPassword`, because the management API never returns
`smtp_pass`, so a credential rotation is invisible to a diff and would otherwise
be skipped as a no-op.

### Not yet proved

No message has been sent. `INF-003` stays open until a real synthetic
verification message has been sent and received, which needs a recipient
address and explicit approval.

---

# First schema: DB-002 and DB-003

Date: 25 July 2026

Authority: `DB-001` signed off, which is what permits a migration to exist. No
migration has been applied to any hosted project. Everything below happened
against a local Postgres 17 container.

## What exists now

Two forward-only migrations, replaying from an empty database:

- `20260725184346_identity_and_roster.sql`: the `private` schema, shared trigger
  functions, then profiles, organisations, organisation_members, participants
  and organisation_invitations.
- `20260725184758_recognition_cycles_and_ballots.sql`: recognition cycles,
  nominations, ballot events, settings, audit events, device push tokens,
  notification deliveries and privacy requests.

Every table is created **fail-closed**: RLS enabled, no policy, no grant. There
is no window in which a table exists and is reachable. `DB-005` and `DB-006`
then open exactly what the exposure matrix allows.

## Invariants that are now structural rather than intended

Tenant coherence is a key, not a check. Child rows reference their parent
through a composite `(organisation_id, id)` key, so a nomination cannot point at
a cycle in another organisation even from a direct SQL session with the service
role. Invariant 1 has to survive a mistake in a trusted function, not only a
hostile client.

Two rules moved from application logic into CHECK constraints, because a
constraint cannot be forgotten by whoever writes the next function:

- **No self-nomination.** This needed a design change. The architecture stored
  only `nominator_user_id`, which would have made the comparison cross-row and
  therefore trigger work. Storing `nominator_participant_id` alongside it turns
  the rule into `nominee_participant_id <> nominator_participant_id`, a plain
  row-level check. A trigger then asserts that the participant genuinely belongs
  to the nominating user, which closes the obvious workaround of passing
  somebody else's participant id.
- **Winner data if and only if revealed.** Members can read
  `recognition_cycles`, so the threat model's claim that no window exists where
  a populated winner sits on an unrevealed cycle depended entirely on how the
  reveal function was written. As a constraint it is now true regardless.

## Evidence

```text
supabase db reset      x2, both applying both migrations from empty
supabase test db       33 of 33 pgTAP assertions pass, both times
supabase db lint       No schema errors found
```

The suite is `supabase/tests/001_schema_invariants.test.sql` and asserts what
the schema **refuses**, not what it accepts: cross-tenant references, tenant
walking by update, duplicate ballots, self-nomination, a nominator participant
belonging to someone else, two live invitations for one participant, a plaintext
token, an un-normalised email, a period that is not a month start, a winner on
an unrevealed cycle, a reveal with no winner, a moderation with no reason, and a
reason over the limit.

It also asserts the exposure baseline directly: every public table has RLS on,
and `anon` and `authenticated` hold zero table grants and zero column grants.
The single most important line checks that `recognition_nominations` is
unreachable by any client role. If a grant ever appears there, T1 is open.

## A wrong assumption, caught by testing it

The migration first used `FORCE ROW LEVEL SECURITY` on every table, then dropped
it on the reasoning that FORCE would break the `SECURITY DEFINER` trigger that
creates profile rows.

**That reasoning was wrong.** Checking `pg_roles` showed `postgres` and
`service_role` both carry `BYPASSRLS`, so they ignore RLS and FORCE alike.
Enabling FORCE on `profiles` and inserting an auth user confirmed it: the
trigger still wrote the profile.

The correct conclusion is different and duller. FORCE is a **no-op** on this
platform, because every role that writes outside policies has `BYPASSRLS`, and
`anon` and `authenticated` own nothing. So it neither protects nor breaks
anything. It stays omitted, but now for the real reason: a clause that looks
like a control while changing no outcome invites the belief that something is
guarded when the guard is elsewhere. The migration comment records the
verification rather than the guess.

What actually closes the Data API is ENABLE plus the absence of a grant, and
that was confirmed too: `authenticated` selecting from `profiles` returns
`permission denied for table profiles`.

## Also corrected

The first pgTAP run reported `Looks like you planned 31 tests but ran 33`. Every
assertion passed, so it would have been easy to treat as noise. It is not: the
plan is what catches a suite that silently stopped running rather than silently
passing, and a plan that drifts from the real count makes that alarm useless.
Counted and corrected to 33.

## Still not done

No policy exists yet, so nothing is reachable by a client. That is `DB-005` and
`DB-006`, and their role-based tests are where the confidentiality claims get
tested as an actual member and an actual administrator rather than structurally.
Nothing has touched the hosted development project.
