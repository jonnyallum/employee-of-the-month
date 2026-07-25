# Employee of the Month

An Android-first team recognition app for running a fair, private and
low-friction employee of the month programme.

## Project status

**Planning gate only. No application implementation has started.**

The repository currently contains the evidence, product requirements,
architecture and delivery board that must be agreed before scaffolding the app.
The initial target is a free UK closed beta for small and medium-sized teams.

## Planning pack

- [Research and product strategy](docs/RESEARCH.md)
- [Product requirements](docs/PRD.md)
- [Technical architecture](docs/ARCHITECTURE.md)
- [Google Play release plan](docs/PLAY_STORE_RELEASE_PLAN.md)
- [Decision log](docs/DECISIONS.md)
- [Delivery Kanban](KANBAN.md)

## Proposed stack

- Expo SDK 56 and React Native 0.85
- TypeScript
- Supabase Auth, Postgres, Row Level Security, Storage, Edge Functions and Cron
- Firebase Cloud Messaging for Android push notifications
- Google Play App Bundles with Play App Signing

The stack is proposed, not yet installed. Package versions will be pinned and
committed only after Gate 0 in the Kanban is approved.

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
