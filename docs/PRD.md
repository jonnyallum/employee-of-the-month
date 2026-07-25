# Product requirements document

Version: 0.1 planning baseline  
Date: 25 July 2026  
Status: Proposed, not approved for implementation

## Product statement

Employee of the Month is an Android-first app that lets a small organisation
run one fair, confidential and repeatable monthly recognition cycle without
buying an HR suite or rebuilding a poll every month.

## Problem statement

Small organisations often run employee of the month through paper slips,
messages, email or a generic form. These methods make participation, duplicate
prevention, privacy, tallying, ties, reminders and record retention manual.
Large recognition platforms solve more problems than these teams have and add
cost and setup burden.

The product must make the monthly process easy for the administrator while
giving employees credible reasons to trust the ballot and result.

## Personas

### Organisation owner

Creates the organisation, controls administrators, owns account and deletion
decisions, and is responsible for programme policy.

### Programme administrator

Manages the participant roster, criteria, cycle dates, eligibility, moderation,
turnout, closing and winner reveal. An administrator cannot retrieve voter
identities through normal application APIs.

### Employee member

Joins an organisation, sees the programme rules and eligible colleagues, casts
or withdraws one nomination, controls notification preferences and sees the
revealed winner.

### Invited participant

Exists on the roster and may receive nominations before accepting an account
invitation. They cannot vote until their invitation is accepted and linked to
an authenticated user.

## Goals

1. Let a new owner create an organisation, add five participants and open a
   valid cycle in under 10 minutes.
2. Let an invited employee cast a valid nomination in under 60 seconds after
   sign-in.
3. Enforce tenant isolation, one vote, no self-vote, cycle state and winner
   integrity in Postgres.
4. Keep voter identity out of administrator screens, exports, notifications,
   analytics and audit event payloads.
5. Reach at least 50% second-cycle creation among activated closed-beta
   organisations.

## Non-goals

- **Performance management.** Votes must not produce performance ratings,
  promotion advice or disciplinary evidence.
- **Rewards fulfilment.** V1 does not buy, issue or account for prizes, points,
  gift cards or cash.
- **Full HR system.** No payroll, leave, timesheets, applicant tracking or
  employee record system.
- **Social recognition feed.** Continuous public praise is a separate product
  behaviour and is not needed to validate monthly cycles.
- **AI decision-making.** No model ranks employees, scores reasons or selects a
  winner.
- **Anonymous public polling.** Every vote belongs internally to an eligible
  authenticated participant, even though the identity is kept confidential
  from programme administrators.

## Scope assumptions

- Initial market: UK organisations with 5 to 100 workers.
- Initial platform: Android phones and tablets.
- Release model: free closed beta, then a limited production release.
- One organisation may have many administrators.
- A data model may support users belonging to multiple organisations, but the
  v1 interface may optimise for one active organisation.
- Calendar periods and closing times use the organisation's IANA timezone.
- Default retention for raw nominations is 12 months. Owners may choose 3, 6,
  12, 24 or indefinite retention. The choice and its implications must be
  visible to members.

## Core user journeys

### Journey A: create and open a programme

1. Owner verifies their email and creates an organisation.
2. Owner sets organisation name, timezone and programme criteria.
3. Owner adds participants by name and email.
4. Each participant receives a single-use invitation with an expiry.
5. Owner creates the current month's draft cycle.
6. Owner reviews eligible voters and recipients, open/close dates and
   confidentiality copy.
7. Owner opens the cycle.
8. Eligible members receive a generic notification.

### Journey B: join and nominate

1. Employee opens a valid invitation link.
2. Employee verifies the invited email and accepts membership.
3. App shows the current open cycle, criteria and confidentiality explanation.
4. Employee selects an eligible colleague other than themselves.
5. Employee may add a reason of up to 500 characters.
6. App confirms the nominee and warns that no live result will be shown.
7. Employee submits.
8. Database accepts exactly one ballot for that cycle.
9. Employee sees their own choice and may withdraw it while the cycle is open.

### Journey C: close, resolve and reveal

1. Administrator sees turnout as a count and percentage, never a named
   non-voter list after reminders have been sent.
2. Administrator closes the cycle.
3. The server computes standings from active ballots.
4. If there is no vote, reveal is blocked.
5. If there is a clear leader, only that participant may be revealed.
6. If leaders are tied, the administrator chooses only from the tied leaders
   and must record a tie decision note.
7. Administrator previews the result card and reveal copy.
8. Administrator reveals the winner.
9. Members receive a generic result notification and can open the result card.

### Journey D: leave and delete

1. A member can leave an organisation from settings.
2. The product explains which past public winner record may remain and why.
3. A user can request account deletion in the app.
4. The same request is possible from a public web page.
5. If the user is the only organisation owner, deletion is blocked until they
   transfer ownership or delete the organisation.
6. Active sessions and device tokens are revoked before the auth identity is
   deleted.

## Functional requirements

### P0: launch requirements

#### Authentication and invitations

**FR-AUTH-01: email authentication**

- Support verified email sign-up and sign-in.
- Persist sessions in secure mobile storage.
- Handle foreground/background token refresh.
- Provide password reset or passwordless recovery through an app link.

Acceptance:

- Given an unverified address, when the user tries to enter an organisation,
  then access is refused and a resend-verification action is available.
- Given a signed-out returning user, when they authenticate, then their session
  survives a normal app restart.
- Given a revoked session, when a protected request is made, then the app clears
  local state and returns to sign-in.

**FR-AUTH-02: single-use invitation**

- Invitations bind organisation, participant and intended email.
- Store only a cryptographic hash of the invitation token.
- Default expiry is seven days.
- Accepting an invitation atomically links the participant to the authenticated
  user and consumes the token.

Acceptance:

- A used, expired, wrong-email or wrong-organisation token is rejected.
- Replaying a successfully used token does not create a second membership.
- Administrators can revoke and reissue an invitation.

#### Organisation and roles

**FR-ORG-01: organisation creation**

- A verified user can create an organisation with a unique ID, name and IANA
  timezone.
- The creator becomes owner in the same transaction.

**FR-ORG-02: role enforcement**

- Roles are `owner`, `admin` and `member`.
- Only owners manage owners and organisation deletion.
- Owners and admins manage roster and cycles.
- Members read allowed programme data and manage only their own ballot and
  preferences.
- Authorisation must derive from database membership, never editable user
  metadata.

#### Participants and eligibility

**FR-ROSTER-01: participant record**

- A participant can exist before an app account.
- Store display name, optional team, avatar, active state, `can_vote` and
  `can_receive`.
- Email used for invitation is administrator-only and never included in ballot
  APIs.

**FR-ROSTER-02: eligibility**

- Inactive participants cannot vote or receive.
- Voters need an accepted account link and `can_vote = true`.
- Nominees need `can_receive = true`.
- Eligibility changes after a cycle opens must be logged.
- A participant removed after winning does not erase the winner snapshot.

#### Cycle management

**FR-CYCLE-01: monthly uniqueness**

- One cycle per organisation per calendar month.
- `period_month` is normalised to the first day of the month.
- Statuses are `draft`, `open`, `closed` and `revealed`.

**FR-CYCLE-02: legal transitions**

- Allowed moves: draft to open, open to closed, closed to open, closed to
  revealed.
- Revealed is terminal.
- Opening validates at least two active recipients and one eligible voter who
  has somebody else to nominate.

**FR-CYCLE-03: criteria and dates**

- Each cycle snapshots the criteria shown to voters.
- Store open and close timestamps in UTC and render in organisation timezone.
- V1 supports manual open and close. Automatic close is P1.

#### Ballot

**FR-BALLOT-01: confidential nomination**

- One active or hidden nomination slot per voter per cycle.
- No self-nomination.
- Nominee and voter must belong to the same organisation as the cycle.
- Only an open cycle accepts inserts, edits or withdrawal.
- Reason is optional, trimmed and capped at 500 characters.

**FR-BALLOT-02: own ballot**

- A member may retrieve only their own ballot row.
- A member may withdraw and then recast while the cycle is open.
- Nominee reassignment is implemented as withdrawal and new cast, not mutation
  of a recorded ballot.

**FR-BALLOT-03: administrator confidentiality**

- Administrators can retrieve nomination IDs, nominee, reason, status and
  moderation fields only through a purpose-built function or API.
- That response must not contain voter ID, voter email, participant ID of the
  voter, timestamps precise enough to infer a voter in a small group, or
  request metadata.
- Raw nomination table selection is not granted to administrators.

#### Moderation

**FR-MOD-01: hide and restore**

- An administrator can hide an inappropriate reason or ballot.
- Hiding requires a reason and records moderator and time.
- A hidden ballot keeps the voter's slot and is excluded from turnout and
  tally.
- Restoring is possible before reveal and is logged.

**FR-MOD-02: content guidance**

- Before free-text entry, tell users not to include health, disciplinary,
  union, protected-characteristic or other sensitive personal information.
- Provide a report-to-admin route.

#### Tally and reveal

**FR-RESULT-01: no live standings**

- While open, all member and administrator product APIs return no ranking.
- Administrators may see turnout only.

**FR-RESULT-02: deterministic tally**

- Count active ballots only.
- Sort by count descending, then display name for stable display.
- Use shared ranks for ties.
- Tally calculation is covered by unit and database tests.

**FR-RESULT-03: winner integrity**

- A clear leader is the only valid winner.
- A tie returns no automatic winner.
- Tie selection is limited to joint leaders and requires an audit note.
- A zero-ballot cycle cannot be revealed.
- Reveal snapshots winner participant ID, display name and count.

#### Notifications

**FR-NOTIFY-01: permission timing**

- Ask for Android notification permission only after the user joins and sees
  the benefit.
- The core workflow works when permission is denied.

**FR-NOTIFY-02: minimal content**

- Notification content does not name a nominee, voter or non-voter.
- Required events: cycle opened, reminder before close and winner revealed.
- Respect per-user push and email preferences.
- Reminder jobs are idempotent.

#### History and reporting

**FR-HISTORY-01: winner history**

- Members see revealed month, winner name, count and approved reason excerpt or
  announcement copy.
- Do not expose all-time rankings in v1.

**FR-REPORT-01: turnout**

- Administrators see eligible count, counted ballots and turnout percentage.
- During an open cycle, the system may privately determine who needs a reminder,
  but the interface does not become an employee monitoring dashboard.

#### Privacy and account controls

**FR-PRIV-01: retention**

- Organisation retention applies only to raw nominations in revealed cycles.
- Draft, open and closed cycles are never purged.
- Purge keeps the winner snapshot and aggregate cycle record.
- Purge jobs support dry run, audit output and idempotency.

**FR-PRIV-02: subject export**

- A user export contains their profile, memberships, their own reason text and
  reason text about them where disclosure is lawful.
- Never disclose who wrote text about another person.

**FR-PRIV-03: account deletion**

- Provide in-app and web initiation.
- Revoke sessions and device tokens.
- Remove or anonymise personal records according to documented retention and
  controller instructions.
- Preserve only records with a documented lawful retention reason.

**FR-PRIV-04: organisation deletion**

- Owner confirms organisation name and a second destructive action.
- Deletion is queued with a short recovery window in beta, then cascades tenant
  data.
- The app must state what is recoverable and for how long.

### P1: fast follow

- CSV roster import with preview and row-level errors.
- Automatic close at `closes_at`.
- Configurable reason requirement and minimum length.
- Previous-winner cooldown.
- Multiple teams and team-specific eligibility.
- Branded result card export using the system share sheet.
- In-app notification inbox.
- Organisation switching.
- Admin cycle templates.
- Accessibility preference for reduced motion and enhanced contrast beyond OS
  defaults.
- Web admin companion for owners who prefer a desktop.

### P2: future considerations

- Multiple award categories and team awards.
- Continuous peer recognition.
- Slack and Microsoft Teams integrations.
- HRIS roster sync.
- iOS release.
- Localisation.
- SSO and SCIM.
- Reward fulfilment.
- Paid plans.

## Data requirements

### Data collected in v1

- Account email and auth records.
- Organisation name and timezone.
- Participant display name, optional team and optional avatar.
- Membership and role.
- Cycle configuration and criteria.
- Confidential nomination selection and optional reason.
- Moderation, audit, notification preference and delivery state.
- Device push token.
- Minimal product events without ballot content.

### Data deliberately not collected

- Date of birth, home address, phone number or emergency contacts.
- Device contacts, precise location, microphone, camera or background location.
- Salary, attendance, productivity, health, disciplinary or diversity data.
- Advertising identifiers.
- Nomination content in analytics or crash reports.

## Quality requirements

### Security

- Every exposed table has RLS and explicit grants.
- No client contains a service role or secret key.
- Sensitive write operations use guarded database functions with explicit
  authorisation and revoked public execute rights.
- Cross-tenant foreign keys or trigger guards protect every relationship.
- Security and performance advisors produce no unresolved critical findings.

### Performance

- Warm app home usable in under 2 seconds on a mid-range Android device under a
  reasonable 4G connection.
- Nominee list remains responsive at 500 participants.
- Ballot submission shows a deterministic pending state and prevents double
  taps.
- Offline state explains that submission needs a connection. No ballot is
  represented as accepted until the server confirms it.

### Accessibility

- Meet WCAG 2.1 AA for relevant mobile content.
- All actions have accessible names, roles, state and error announcements.
- Text supports Android font scaling without clipped core actions.
- Touch targets are at least 48 by 48 density-independent pixels.
- Colour never carries state alone.

### Reliability

- All scheduled jobs are idempotent.
- Retries cannot create duplicate invitations, nominations or notifications.
- Database migrations are forward-only and tested from a clean project.
- Crash-free user rate target is at least 99.5% in closed testing.

## Success metrics and event definitions

No event includes nominee ID, voter ID, reason text or employee email.

| Metric | Definition | Event/data |
|---|---|---|
| Owner activation | Organisation created and first cycle opened within 24 hours | `organisation_created`, `cycle_opened` |
| Invite acceptance | Accepted invitations / delivered invitations | invitation state |
| Voter activation | Members who cast first valid nomination / eligible joined voters | aggregate database query |
| Cycle turnout | Counted ballots / eligible linked voters at close | cycle aggregate |
| Core completion time | Open ballot screen to confirmed valid cast | coarse client timings |
| Repeat programme use | Organisation opens a second distinct month | cycle records |
| Reliability | Crash-free users and sessions | Play Android vitals / approved crash tool |
| Support burden | Support requests per activated organisation | support log |

## Release criteria

V1 is ready for closed testing only when:

- every P0 acceptance criterion has an automated or documented manual test;
- destructive privacy workflows have been tested against seeded data;
- RLS tests cover owner, admin, member, other tenant, signed-out and service
  contexts;
- no normal admin API can return a voter identity;
- a signed release AAB targets API 36 and passes 16 KB page-size checks;
- privacy policy, deletion page and Play Data safety answers match actual SDK
  behaviour;
- internal testing has no open P0 or P1 defects.

Production access additionally requires the closed-testing threshold applicable
to the Play developer account, a production-readiness review and explicit
approval.

## Open questions

Blocking decisions are tracked in `docs/DECISIONS.md` and Gate 0 of
`KANBAN.md`.

1. Final app and Play developer names.
2. Package name.
3. Organisation or personal Play developer account and its verification state.
4. Whether the beta default retention should be 12 months or shorter.
5. Whether reason text remains optional or becomes configurable in v1.
6. Whether programme administrators should be allowed to see nomination
   reasons before voting closes. Recommendation: no.
7. Legal review of controller/processor roles, terms, privacy wording and
   employment-use disclaimer.
