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
