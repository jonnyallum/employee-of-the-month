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
