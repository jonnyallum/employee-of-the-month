# Employee of the Month

An Android-first team recognition app for running a fair, private and
low-friction employee of the month programme.

## Project status

**Foundation build started on 25 July 2026.**

The repository contains the planning pack plus an Expo Android application
shell, a tested recognition rules engine, strict local quality gates and local
Supabase configuration. The initial target remains a free UK closed beta for
small and medium-sized teams.

A dedicated Supabase development project now exists and the repository is
linked to it, but its database is still empty: no schema, policy or function
has been created. No Play Store application has been created.

## Planning pack

- [Research and product strategy](docs/RESEARCH.md)
- [Product requirements](docs/PRD.md)
- [Technical architecture](docs/ARCHITECTURE.md)
- [Google Play release plan](docs/PLAY_STORE_RELEASE_PLAN.md)
- [Decision log](docs/DECISIONS.md)
- [Foundation build record](docs/BUILD_LOG.md)
- [Delivery Kanban](KANBAN.md)

## Implemented foundation

- Expo SDK 57 and React Native 0.86
- React 19.2 and strict TypeScript 6
- Supabase Auth, Postgres, Row Level Security, Storage, Edge Functions and Cron
- Biome, Node test runner and GitHub Actions quality gates
- Google Play App Bundles with Play App Signing

Firebase Cloud Messaging and release signing remain planned work.

## Local development

Requirements:

- Node.js 22.13 or newer;
- npm;
- Android Studio and an API 36 emulator for native device work;
- Docker Desktop running before starting local Supabase.

Install and verify:

```powershell
npm ci
npm run check
npm run doctor
```

Start the app:

```powershell
npm start
```

Copy `.env.example` to a local ignored environment file only when a Supabase
project is available. The app accepts a project URL and publishable key. A
service-role key must never be placed in the Expo environment.

## Hosted development project

Credentials for the development Supabase project live in the `jvault` project
`employee-of-the-month-dev`. They are never committed, written to `.env` or
printed. Run tooling through the vault runner instead, which injects them for
the duration of one command and reports key names only:

```powershell
npm run db:verify
```

```powershell
npm run db:link
```

`scripts/with-vault.ps1` will run anything the same way, so the app can be
started against the hosted project without an environment file:

```powershell
powershell -NoProfile -File .\scripts\with-vault.ps1 npm start
```

`npm run db:verify` checks that the URL matches the project reference, that the
key is a publishable key rather than a secret or legacy JWT, that the Data and
Auth APIs answer, and that the remote migration history is what the repository
expects. Run it before any database work.

## Source module

The product is derived from the `P08 Employee Recognition` module in biz-os.
The standalone app will reuse its tested domain rules, including:

- one cycle per organisation per calendar month;
- one nomination per eligible voter;
- no self-nomination;
- no live standings while voting is open;
- an explicit `draft -> open -> closed -> revealed` state machine;
- deterministic tally and tie handling;
- winner snapshots that survive later roster changes;
- retention, export and erasure workflows.

The standalone product will not depend on biz-os at runtime. It will own its
organisation, participant, invitation and role model.

## Working rules

- UK English and plain language.
- No secrets or service-account files in Git.
- No production deployment or Play Store submission without explicit approval.
- Privacy, security and ballot integrity are release gates, not backlog polish.
- The Kanban is the execution source of truth.
