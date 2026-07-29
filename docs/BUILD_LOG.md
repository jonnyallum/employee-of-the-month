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

---

# Restricted mail credential and the first real send

Date: 25 July 2026

Authority: Jonny supplied a sending-only Resend key and a recipient address for
the `INF-003` test.

## A check that would have rejected the better credential

`scripts/apply-smtp-config.ps1` proved a key was alive by listing Resend
domains. That looked reasonable and was wrong. A key restricted to "Sending
access" cannot read anything, so every `GET` returns `401`. The script would
therefore have refused the correctly scoped credential while continuing to
accept the over-privileged one it was written to warn about.

This is worth naming as a category, not just a bug. A validation that tests a
capability the credential is not supposed to have will always reward the
credential with too much privilege.

The probe now exercises the permission actually required. `POST /emails` with an
empty body evaluates authentication before the payload, so `401` means the key
is dead and `400` or `422` means it authenticated and only the body was
rejected. Nothing is sent. Distinguishing those two was also how the new key was
confirmed as genuinely restricted rather than simply broken, since both look
identical from a `GET`.

One assurance was lost in the trade: a restricted key cannot confirm the sending
domain exists. That check now comes from the send test instead, which is a
better source of truth anyway because it exercises delivery rather than
configuration. Worth paying for a credential that cannot read the account.

## Key handling

The key arrived as a plaintext file. It was moved into jvault with
`jvault import` from a temporary file rather than `jvault add --value`, so it
never appeared in a command line, a process list or shell history. The temporary
file is deleted in a `finally` block. Its shape was checked before use without
printing it.

Verified restricted after installation: `401` on `/domains`, `/api-keys` and
`/emails` reads, `422` on a send attempt with an invalid body. The
over-privilege warning in `apply-smtp-config.ps1` is now silent, which is the
evidence for `INF-014`.

## The send

`scripts/send-test-email.ps1` sends exactly one magic-link email. It takes the
recipient as a required argument with no default, because a script that can send
real mail to a real person should not be runnable absent-mindedly. It uses the
publishable key over HTTPS, which is the path the Android app itself will take,
so a pass means the app's verification mail works rather than only that the SMTP
settings parse. Magic link rather than sign-up avoids inventing a password that
would then need storing or discarding.

```text
POST /auth/v1/otp  ->  HTTP 200 in 2.1s
```

A `200` means Supabase accepted the request and handed the message to Resend. A
rejected credential or unverified sender fails with a `5xx` at this point rather
than succeeding quietly, which is what makes the result meaningful.

## What this does not prove

Delivery. Inbox placement, spam filtering and DMARC alignment are not observable
from the sending side, so `INF-003` stays open until a human confirms the message
arrived, in which folder, and that the sender renders as expected. Claiming the
card complete on a `200` would be reporting the wrong thing.

## Raised

`INF-015`: the full-access Resend key created earlier the same day is now
superseded and unused, but still grants full read and key-creation rights on the
account. An unused credential is only a liability.

Also outstanding: the plaintext key file at
`C:\Users\jonny\Desktop\Projects\resender.txt` still exists. The value is safely
in jvault, so the file is now redundant and should be deleted. It was left in
place rather than removed, because deleting a file this session did not create is
the owner's call.

---

# RLS: DB-004, DB-005 and DB-006

Date: 25 July 2026

This is the point where the product's central promise stops being a design
intention and becomes something a database enforces. Three migrations and a
second test suite that asks each actor, in turn, what they can actually reach.

## What is now reachable

Six tables, and nothing else:

| Table | Client access |
|---|---|
| `profiles` | own row; update restricted to the `display_name` column |
| `organisations` | active members, excluding soft-deleted |
| `organisation_members` | rows inside the caller's organisations |
| `participants` | seven columns, active rows, own organisations |
| `recognition_cycles` | own organisations, all columns |
| `recognition_settings` | three transparency columns |

Everything else has no grant: invitations, nominations, ballot events, audit
events, push tokens, deliveries and privacy requests.

`participants` withholds `user_id`, `can_vote` and its timestamps. PostgREST
honours column privileges by refusing rather than silently dropping, so a client
asking for `user_id` gets an error instead of something that looks like it
worked.

## Proof, as each actor

`supabase/tests/002_rls_policies.test.sql` assumes the `authenticated` role and
sets the JWT claims that `auth.uid()` reads, which is exactly what PostgREST
does. Two organisations exist so tenant isolation is testable, and Cara's real
ballot for Ben is the row every assertion tries and fails to reach.

The assertions that matter most:

- a member, an **admin** and an **owner** are each refused `42501` on
  `recognition_nominations`;
- an admin naming `nominator_user_id` directly is refused;
- an admin running a bare `count(*)` is refused, which would otherwise leak live
  turnout and break `FR-RESULT-01`;
- another tenant's owner sees none of Alpha's roster, cycles or members when
  asking by id;
- a member whose status is `left` reaches nothing at all, immediately;
- the ballot row and its `nominator_user_id` genuinely still exist. The
  confidentiality is a property of the exposure rules, not of the data being
  absent, and asserting that keeps the distinction honest.

Totals: 36 structural assertions in 001, 33 role assertions in 002, all passing
after a clean replay.

## A wrong control, caught by implementing it

The signed threat model stated that `authenticated` would hold no `USAGE` on the
`private` schema. That is unimplementable. RLS policy expressions are evaluated
with the **caller's** privileges, so a policy calling `private.is_org_member`
needs the querying role to hold `EXECUTE` on the function and `USAGE` on the
schema. Without both, every query on a protected table fails with
`permission denied for function`.

Worse than the error is how it was nearly missed. An experiment run beforehand
appeared to prove that policies needed no such grant. It was wrong, because the
throwaway function in the experiment still carried Postgres's default `EXECUTE`
for `PUBLIC`, which the real helpers do not: the migration revokes it. The
experiment did not isolate the variable it claimed to test, so it produced a
confident and false result. The RLS tests caught it minutes later.

That is the second time this session that reasoning about Postgres produced a
plausible wrong answer, after `FORCE ROW LEVEL SECURITY`. The pattern is worth
naming: an experiment that does not control for defaults tests the defaults.

## The corrected control

`authenticated` holds `USAGE` on `private` and `EXECUTE` on exactly the two
helpers that appear inside a policy. The two called only from `SECURITY DEFINER`
functions are not granted, because a definer function runs as its owner and
needs nothing from the caller.

The protection comes from the exposed-schema list rather than the grants, and
that was verified at the real API boundary rather than assumed:

```text
POST /rest/v1/rpc/is_org_member
  -> 404 PGRST202, "searched for the function public.is_org_member ... no matches"

GET /rest/v1/recognition_nominations
  -> 42501, permission denied for table recognition_nominations

GET /rest/v1/participants
  -> 42501, permission denied for table participants
```

PostgREST searched `public` only. The threat model has been corrected in place,
because a control that is asserted but never exercised is worth nothing, and this
one sat in a signed document.

## The exposure surface is now pinned by a test

`001` previously asserted that no client role held any grant, which was true
before `DB-005` and is now meaningless. It has been replaced with assertions
that name the six reachable tables exactly, confirm `participants` never exposes
`user_id` or `can_vote`, confirm `profiles` is writable only in `display_name`,
and confirm a client can execute only the two policy helpers in `private`.

A future migration that grants something reasonable-looking on a closed table
now fails the suite rather than passing quietly. That is the failure mode worth
defending against, because it will look like an ordinary feature at review time.

## Still not done

Guarded functions, `DB-007` onwards. Nothing can currently be written by a
client at all, which is the correct state: creating an organisation, accepting an
invitation and casting a ballot are all transactional and all need to enforce
rules a grant cannot express.

---

# Chasing a test email that did arrive

Date: 25 July 2026

The recipient reported no message. The `HTTP 200` recorded earlier proved only
that Supabase accepted the request, so it was not evidence of much. Three checks,
cheapest first.

## What was checked

**Supabase auth logs** returned no rows through the management analytics
endpoint. Not conclusive either way, and not worth more effort with better
signals available.

**The SMTP path, directly.** `scripts/probe-smtp.ps1` walks the conversation to
Resend: greeting, `EHLO`, `STARTTLS`, `AUTH LOGIN`, `MAIL FROM`, `RCPT TO`, then
`QUIT`. `DATA` is never issued, so nothing is sent. It exists to separate three
failures that look identical from outside: rejected credentials, a sender address
the provider will not accept, and a refused recipient.

```text
235 Authentication successful
250 Accepted        (MAIL FROM recognition@jonnyai.co.uk)
250 Accepted        (RCPT TO the recipient)
TLS 1.3
```

All clean, which moved the question past configuration entirely.

**The provider's own delivery log** settled it:

```text
2026-07-25 19:05:44 UTC  subject='Confirm your email address'  status=delivered
```

The message was delivered. Two things most likely hid it: the subject is
`Confirm your email address` rather than anything mentioning a magic link,
because `create_user` was set and the address was new to the project, so Supabase
used its signup template; and the sender `Employee of the Month
<recognition@jonnyai.co.uk>` is an unfamiliar name to the recipient's mail
provider, which is exactly what gets filed to spam or promotions.

## The card stays open, and should

`delivered` means the receiving server accepted the message at the SMTP boundary.
It does not mean the message reached an inbox: a provider can accept and then
file to spam, and that decision is invisible from the sending side. `INF-003`
asks for a received message, so it stays open until a human sees it.

This distinction is worth keeping. Treating `delivered` as proof of receipt is
how a product ships with invitations that quietly land in spam, which for this
product breaks the only route a new employee has into the programme.

## An operational consequence of the restricted key

The delivery log could not be read with this product's own credential, because
`INF-014` deliberately restricted it to sending. The answer came from the shared
full-access key on the same Resend account.

That is a real cost of least privilege rather than an argument against it, but it
should not depend on borrowing another product's credential. The durable fix is
delivery webhooks recording events into `notification_deliveries`, which the
architecture already anticipates, so operators can answer "what happened to that
message" without holding a key that can read the whole account.

## Raised

`INF-016`: deliverability work before invitations carry real weight. DMARC policy
for `jonnyai.co.uk`, a recognisable sender name, and a plain-text alternative
part. Invitation mail is the only way into the product for a new employee, so
spam placement is a functional defect and not a marketing concern.

## Postscript: it had arrived

Jonny found the message and followed the confirmation link, which produced a
valid confirmed session. Auth mail therefore works end to end, from send to
confirmed account, and `INF-003` is closed.

---

# Tokens in a URL, and a scheme that cannot be trusted

Date: 25 July 2026

Following that confirmation link failed, and the failure was worth more than the
success would have been.

## What the link produced

```text
http://uk.co.jonnyai.employeeofthemonth//#access_token=...&refresh_token=...&type=signup
```

Three separate problems are visible in that one line.

### 1. The tokens are in the URL

Under the implicit flow, a confirmation link hands back the access token and
refresh token in the URL fragment. They land in the address bar, in browser
history, in any screenshot, and in anything that logs or forwards a URL. In this
case they were pasted into a chat window, which is exactly the class of accident
the design should not permit in the first place.

Both were revoked immediately with a global sign-out, which invalidates every
refresh token for that user rather than only the pasted session. The access
token was confirmed dead afterwards rather than assumed dead.

The fix is `flowType: 'pkce'` on the Supabase client, now set. PKCE returns a
single-use `code` which is worthless without the verifier held in the app's own
storage, so nothing sensitive travels in a URL at all. The default is implicit,
so this had to be chosen deliberately.

### 2. The custom scheme was rewritten

`uk.co.jonnyai.employeeofthemonth://` became
`http://uk.co.jonnyai.employeeofthemonth//`. Mail clients and browsers rewrite
non-http schemes, and on a desktop there is no handler for it regardless. This
was always going to fail: there is no installed Android app yet, since `FND-010`
is blocked on Android tooling.

### 3. The real problem: a custom scheme is not exclusive

This is the one that matters. **Any app on the device may register the same
custom scheme.** Under the implicit flow that means a hostile app can receive a
link carrying a live session. It is an interception route directly into the auth
flow, on a product whose entire premise is that ballots stay confidential.

Android App Links do not have this weakness. They are HTTPS URLs verified
against an `assetlinks.json` file on a domain we control, so no other app can
claim them, and they degrade to a web page when the app is not installed.
`INF-009` has been re-scoped and re-prioritised accordingly, and the custom
scheme is demoted to a fallback rather than the primary route.

PKCE also blunts the interception risk on its own, because a stolen `code` is
useless without the verifier. The two controls belong together: App Links stop
the redirect being captured, PKCE ensures capturing it achieves nothing.

## What this says about the earlier decision

`INF-011` set `site_url` to the raw custom scheme, and it was applied and
recorded as a pass because the value read back correctly from the API. It did,
and the setting was still wrong. Reading a value back proves it was stored, not
that it works, and this is a case where nothing short of clicking a real link
would have shown the difference.

---

# DB-007: the first write a client is allowed

Date: 25 July 2026

`create_organisation` is the entry point to the product and the first thing any
client can write. Everything before this was readable or nothing.

It is a function rather than an INSERT grant because four rows have to appear
together or not at all: the organisation, the creator's ownership, the creator's
roster entry and the programme settings. A grant cannot express "and also make
me the owner", and a client doing it in four requests can fail after the first
and leave an organisation that nobody can administer and nobody can delete.

## Decisions inside it

The creator is placed on the roster. Without that the owner cannot vote in or
receive nominations from their own programme, which in a five-person team
quietly removes a fifth of the roster for a reason no user could work out.

Settings are created immediately, so no screen ever has to distinguish "not
configured yet" from "configured to the default".

Refusals raise product error codes rather than letting a constraint fire, so the
client sees `invalid_timezone` instead of a constraint name. The table trigger
still catches an unknown zone if anything reaches it another way; this is a
better message, not a replacement control.

The verified-email check reads `auth.users.email_confirmed_at` rather than a JWT
claim, consistent with every other authorisation decision in the schema.

## Evidence

92 assertions now pass across three suites. The 23 for this function cover who
may call it, every refusal, and the resulting rows one at a time rather than
just that a uuid came back.

Checked at the real API boundary as well as in SQL:

```text
POST /rest/v1/rpc/create_organisation  as anon  -> 42501 permission denied
POST /rest/v1/rpc/is_org_member        as anon  -> 404   still not exposed
```

The distinction matters. `42501` proves the function is published and locked,
where `404` would have meant it was never reachable and the grant was untested.

---

# CI that actually runs (INF-007, INF-018)

Date: 25 July 2026

## The job

A separate `database` job starts the local Supabase stack, replays every
migration from an empty database, runs the SQL suites, then replays and re-runs
a second time. The second pass is the whole point: a migration that only works
against a database where an earlier version once ran passes once and fails
there.

It is kept apart from the `quality` job so a lint failure reports in seconds
rather than waiting behind container startup.

No secret is used anywhere in it. The local stack mints its own throwaway keys,
so CI never needs access to the hosted project, and a compromised workflow
cannot reach real data.

## A step that would have proved nothing

`supabase db lint` reports its findings and still exits 0 unless `--fail-on` is
passed. As first written, the lint step would have passed whatever it found.
It is now `--level warning --fail-on warning`, which the schema meets today.

Every command in the chain was run locally in the exact order CI uses before
being committed, rather than assumed to work.

## The worse problem underneath

The first push produced no run at all.

PR #1 had been merged, which stopped the `pull_request` event firing, and the
only other trigger was `push` to `main`. Eleven commits had therefore landed on
the working branch with no checks whatsoever: the threat model, all five schema
migrations, the RLS layer, the PKCE fix and `create_organisation`.

This is the worst shape a CI gap can take. A failing run is loud. A run that
never happens looks exactly like a green one on the branch view, and nothing
announces it. The trigger now includes `agent/**`.

Worth generalising: a green tick means the checks that ran passed. It says
nothing about checks that did not run, and the two are easy to confuse at a
glance.

## Evidence

Run `30172989614`, both jobs green in 3m55s. The log was read rather than the
badge trusted, because the failure mode above is precisely a green result that
means less than it appears:

```text
Applying migration ... x6, three separate times
  (initial start, first reset, second reset)
Files=3, Tests=92   PASS
Files=3, Tests=92   PASS   (after the second replay)
No schema errors found
```

## Still not merged

`main` contains only the original kick-off and the PR #1 merge. All of today's
work sits on `agent/standalone-app-planning`, unmerged. Opening a pull request
publishes to the repository, so that decision is left to the owner.

---

# DB-008: invitations

Date: 25 July 2026

An invitation is an identity. It is the only route into an organisation, which
makes a working token the most valuable thing in the schema, so the design
assumes it will leak and asks what happens then.

## Four properties, each enforced rather than assumed

**Only a hash is stored.** A read of `organisation_invitations`, by anyone
including a database operator, yields nothing usable. A test asserts the stored
value is not the token and is its SHA-256, because that property silently
disappearing would hand over a working invitation for every pending employee.

**The token is bound to an intended email**, verified against `auth.users`
rather than anything the caller supplied. This is what makes a leaked token
worthless, and it is also what makes `create_invitation` safe to return the raw
token to an admin: holding it achieves nothing without the mailbox.

**Acceptance is one transaction**, with the invitation row locked `for update`.
Consuming, linking and admitting happen together. If the participant turns out
to have been linked in the meantime, the consumption rolls back too, so the
invitation stays usable instead of being burnt for nothing.

**Reissue revokes first.** Otherwise an intercepted earlier email would still be
redeemable, which is the whole reason reissue exists.

## A failing test that turned out to be a design fault

The revocation test expected a wrong-email error and got "invitation was
withdrawn". The test was wrong, but the reason it was wrong was more
interesting: the state checks ran before the email check, so anyone holding an
intercepted token could learn whether it had been withdrawn, used or was still
live.

That discloses another person's account lifecycle to precisely the party who
should learn nothing. The checks are now ordered so the email binding is
evaluated first, and a non-recipient learns one thing only: that the token is
not theirs. The intended recipient still gets accurate, useful errors.

Both cases are now asserted, so the ordering cannot regress silently.

## Other deliberate choices

A missing token and a wrong token raise the same error, so the function cannot
be used to probe for valid tokens. `revoke_invitation` answers identically for
an invitation that does not exist and one belonging to another tenant, for the
same reason.

Acceptance always creates a plain `member`. Nothing about an invitation can
confer admin rights, which keeps role escalation out of the onboarding path
entirely.

## Evidence

`Files=4, Tests=122` passing after a clean replay. The 30 for this migration
cover the wrong-email binding, an unverified account, replay, revocation,
reissue, cross-tenant attempts and a non-member caller.

---

# DB-009, DB-010, DB-011: the cycle and the ballot

Date: 25 July 2026

An organisation can now run a complete ballot: create a cycle, open it, cast,
withdraw, recast, close. This is the first point where the thing behaves like the
product rather than like infrastructure.

## What the functions add that constraints cannot

The table already refuses a self-nomination, a second ballot per voter, a
cross-tenant nominee and an incoherent nominator link. Those hold against direct
SQL. The functions carry the rules that depend on state and identity instead of
shape:

- the cycle must be open **now**;
- the voter must be eligible **now**;
- the voter is `auth.uid()`, never an argument, so nobody votes for anybody else;
- `expected_version` on every transition, so two administrators pressing close
  on the same screen produce a deterministic `40001` rather than a lost update;
- opening validates `FR-CYCLE-02`, refusing a cycle that cannot produce a fair
  ballot at the moment of opening rather than at close with no result.

Withdrawing marks the row rather than deleting it. The voter keeps their single
slot and a recast reuses it, which is what stops withdraw-then-vote-again
becoming two ballots.

## Two bugs the tests found

**`42702`, ambiguous column reference.** The `idempotency_key` parameter shares
its name with the column it sets, and an unqualified reference inside a statement
that also has the table in scope is rejected. Parameters are now qualified with
the function name. Renaming them would also have worked, at the cost of an RPC
whose argument names no longer match the fields they set.

**`now()` is constant within a transaction.** Opening and closing a cycle in one
transaction stamped `opens_at` and `closes_at` with the identical instant and
violated the `closes_at > opens_at` constraint. Both now use `clock_timestamp()`,
which advances within a transaction and is the more honest value anyway: these
record when the action happened, not when its transaction began.

The second is the more interesting one. In production those are separate
requests, so it would not have fired in normal use. It would have waited for
some batch or backfill that did both at once, which is exactly when nobody is
watching.

## get_my_nomination

The only client read path into the ballot table, and it takes no voter argument.
There is no call shape that returns another person's ballot: not a wrong one, not
a guessed one, none. The return type omits `nominator_user_id` even though the
caller is the nominator, so a future change to the caller cannot start returning
identity by accident.

Asserted by having two different voters make the identical call and each receive
their own ballot, and a third who has not voted receive nothing rather than
somebody else's.

## Evidence

`Files=5, Tests=159` passing after a clean replay.

---

# DB-012, DB-013, DB-014: the administrator's view

Date: 25 July 2026

This is where the product promise is either kept or broken. An administrator
legitimately needs to moderate content, see turnout and reveal a winner. None of
those require knowing who voted for whom, and this migration is the proof that
they can be provided without it.

## The technique: let the return type do the work

A policy can filter rows but cannot hide a column. A function's declared output
can simply not contain the field. If voter identity is not in the type, no bug in
the body can leak it, and a future change that tries has to alter the signature,
which is visible in review.

So the most important assertion in the project is a contract test pinning the
exact result signature of `get_admin_nominations` by name. It fails if a column
is added, rather than relying on somebody noticing.

What an administrator gets: nomination id, nominee, reason, status, moderation
fields, and a date. What they never get: any nominator reference, any precise
timestamp, or any ordering that reflects insertion sequence. Results come back
ordered by nominee name, because a time-ordered list hands back exactly the
sequence that day-truncation exists to remove.

## One definition of the tally

`get_closed_standings` and `reveal_winner` both read `private.cycle_tally`. If
they counted separately they could disagree, and an administrator would be shown
one result while another was revealed. One definition removes the possibility
rather than making it unlikely.

`reveal_winner` recomputes rather than trusting the caller. A clear leader cannot
be overridden, which is the failure the whole product exists to avoid. A tie must
be resolved from among the joint leaders and carry a note. A cycle nobody voted
in cannot be revealed at all.

Standings refuse while a cycle is open rather than returning an empty set,
because empty is indistinguishable from nobody having voted, which is itself
information.

## Turnout has no named variant, on purpose

`get_cycle_turnout` returns three numbers. There is deliberately no function
returning who has or has not voted. The reminder job may privately identify
non-voters in order to message them; no interface may, because that turns a
recognition programme into an attendance monitor.

## The exposure test earned its keep

Adding `private.cycle_tally` broke the assertion in `001` that pins which private
functions a client may execute. Postgres grants `EXECUTE` to `PUBLIC` on every
new function, and the blanket revoke in the `DB-004` migration only covered the
functions that existed at the time.

So `authenticated` could call the raw tally directly. It returns per-nominee
counts, which would have handed a member live standings while voting was open
and broken `FR-RESULT-01`.

Not reachable as an RPC, since `private` is not an exposed schema, so this was a
second line rather than an open door. But it is exactly the quiet regression the
test was written for, and it was caught by name within a minute of being
introduced. A blanket revoke only ever covers the past: every new function in
`private` needs its own.

## Evidence

`Files=6, Tests=200` passing after a clean replay. A full cycle now runs end to
end: create an organisation, invite, accept, open, vote, moderate, close, tally
and reveal, including a tie and a zero-ballot case.

---

# DB-016 and a CI defect of my own making

Date: 25 July 2026

## Duplicate CI runs

Adding the `agent/**` push trigger fixed the gap where eleven commits ran with no
checks, and introduced a smaller one: every commit on a branch with an open pull
request then ran the whole suite twice, once per event.

Fixed with a concurrency group keyed on the **commit** rather than the ref, so a
push and a pull_request event for the same commit collapse into one run.
`cancel-in-progress` also stops a superseded run finishing after the commit that
replaced it, which matters more than the wasted minutes: a stale green arriving
after a newer failure is the last thing anyone sees.

## Generated database types

`src/types/database.ts` is generated from the local schema and committed. It
covers every table and all fourteen guarded functions.

CI regenerates it and runs `git diff --exit-code`. Without that, types drift
silently: the schema moves, the checked-in file does not, and TypeScript
cheerfully keeps confirming a shape the database no longer has. That failure is
invisible until runtime, which is the worst place to meet it.

The check was verified to fail on a deliberately altered file before being
trusted. After `supabase db lint` turned out to exit 0 while reporting findings,
assuming a check works is not something worth repeating.

## Why the generated file is excluded from Biome

Biome wanted to reformat it. Doing so would make the drift comparison fail
permanently, because CI compares against raw generator output. Generated files
should not be formatted by hand or by tool, so it is excluded and the committed
bytes stay identical to what the generator produces.

## An unplanned benefit

The generated `get_admin_nominations` type contains no nominator field and no
precise timestamp. The confidentiality contract that the SQL tests assert is now
also expressed in the types the app compiles against, so a screen that tries to
display a voter will not type-check.

---

# DB-019: a seed that means what it says

Date: 25 July 2026

`supabase/seed.sql` now builds two organisations with six people, mixed roles,
a participant who can be nominated but cannot vote, one on the roster with no
account and a live invitation, and four cycles: revealed with a clear winner,
revealed after a tie, closed awaiting reveal, and open partially voted, with a
hidden and a withdrawn ballot among them.

Months are relative to the current one. The structure is what is deterministic,
not the dates, so the fixture cannot rot into four historic cycles and nothing
open.

## Two safety properties

It **refuses to run off a local stack**. `supabase db reset --linked` resets a
remote database and then runs this file; the reset is the greater danger, but a
seed that would happily write invented employees into a real project should not
depend on the operator noticing. The guard checks the well-known local demo JWT
secret, which a hosted project does not have. Verified by running the file with
the setting overridden and watching it refuse.

Every seeded address is on a reserved `.example` domain. RFC 2606 guarantees
those can never be registered, so a stray invitation cannot reach a real person.

## The mistake worth recording

The first version carried a tie decision note on a cycle that was not tied. Ben
had two nominations, Eli had one.

Nothing failed. The constraint was satisfied, because the stored winner count
matched the actual leader, and only the story was wrong. A screen built against
it would have shown a resolved tie on a cycle with a clear leader, which is
exactly the case most likely to hide a bug in tie handling.

The arrangement turns out to be constrained: with four eligible voters and no
self-voting, a genuine two-two tie between Ben and Eli requires Ben's votes to
come from Ana and Eli, and Eli's from Cara and Ben. Any other pairing produces a
clear leader. That is now stated in the file, because it is not obvious and the
next person to edit the ballots will otherwise break it again.

`007_seed_integrity.test.sql` exists as a result. It asserts the seed is
internally coherent: that a tie note implies two people on the winning count,
that every revealed winner holds the top of its own tally, that the snapshotted
name matches the participant it points at, and that no unrevealed cycle carries
winner data. Fixture data that quietly contradicts itself is worse than none,
because it teaches the wrong shape and makes a real defect look normal.

## The seed broke the existing suites, correctly

Four test files began failing or aborting once seeded data existed, because they
asserted absolute counts and used single-row subqueries that had only ever seen
their own fixtures.

The fix is that each functional suite now deletes the seeded organisations and
users at the start of its transaction, which the rollback undoes. Tests should
depend on what they create, not on what happens to be lying around, and this
makes that explicit rather than accidental. `007` is the exception, since
asserting against the seed is its whole purpose.

## Evidence

`Files=7, Tests=216` passing, across two consecutive replays from empty.

---

# The first working screens

Date: 26 July 2026

A member can now sign in, see the current cycle, nominate a colleague, read
their own ballot back, withdraw it and vote again. Verified by doing it in a
browser against the local stack and then checking the database, not by asserting
it.

## Verified without an Android device

`FND-010` is still blocked on Android tooling, but Expo builds for web and
`react-native-web` is already a dependency, so the whole flow runs in the
browser pane. That is not a substitute for a device build, and layout, gestures
and notifications still need one. It is enough to prove the data path, the
guards and the states are real.

## What was checked, in order

Signed out, the guard redirected to sign-in. Signed in as a seeded member and
the screen showed her organisation, the July cycle, its criteria, and her own
existing nomination with the reason from the seed. Withdrew it and the nominee
list appeared with five colleagues and, importantly, without her. Selected
someone else, added a reason, submitted, and the receipt came back with the new
choice.

Then, in the database: one ballot for that voter in that cycle, recorded as a
`recast` rather than a second `cast`. That is the invariant the withdraw design
exists to protect, and the interface honoured it.

## Two things the client could not do, and why that was right

**The app cannot identify its own roster entry.** `participants.user_id` is
withheld from the client column grant, which is what stops a member joining a
name to an auth identity. It also means the nominee list cannot filter the
signed-in user out. Rather than widening the grant, this added
`get_my_participant`, which returns the caller's own row only and takes the user
from `auth.uid()`. The database refuses a self-nomination regardless, so this is
about not offering a choice that would be rejected.

**The app cannot compute the small-electorate warning.** `can_vote` is withheld
too, so a member cannot count eligible voters. That is correct, and it places
`UI-CONF-01` on the administrator screen, where `get_cycle_turnout` already
returns the eligible count.

## Three failures worth recording

**The generated types were not wired in.** `getSupabaseClient` returned an
untyped client, so every query compiled against nothing. Typing it with the
generated `Database` produced twenty errors immediately, all real.

**A concatenated select string silently defeated inference.** Splitting a select
across two string literals for line length degraded the result type to an error
type, and every field access on it stopped being checked. It has to be one
unbroken literal.

**Sign-in returned 500 from a NULL.** The seeded users could not authenticate:
`Database error querying schema`. GoTrue scans `confirmation_token` and its
siblings into non-nullable Go strings, so a NULL breaks the query before the
password is ever compared. They are nullable in the schema, which is why the
seed left them unset. Empty strings, which GoTrue's own signup path writes, fix
it.

That last one is worth remembering: the error names whichever column it reached
first, which sends you looking at confirmation rather than at every nullable
string column on the table.

## Not done

Sign-up, verification resend and recovery. Timezone-correct dates. Search on the
nominee list. An explicit confirmation step before submitting. Everything
administrator-facing.

---

# The administrator screen, and a bug that mattered

Date: 26 July 2026

An owner can now create a cycle, open it, watch turnout, close it, moderate what
was written, see standings and reveal a winner including a tie. Driven in a
browser against the seed, not asserted.

## The confidentiality warning finally has a home

`UI-CONF-01` sat open because the member screen cannot compute it: `can_vote` is
withheld from the roster grant, so a member cannot count eligible voters. That
was the correct answer all along. The count is available to an administrator
through `get_cycle_turnout`, so the warning belongs there.

It renders as a full card with `accessibilityRole="alert"`, not help text.
`D-022` is about not implying a protection the arithmetic cannot support, and a
footnote implies exactly that. Verified against the seed: Alpha has four eligible
voters and shows the warning.

## Verified by doing it

Opened the July cycle and turnout read four eligible, two voted, fifty per cent,
matching the seed exactly. While open, the screen said plainly that no standings
exist for anybody rather than showing an empty panel that looks like a failure.

Closed it, and standings appeared with shared competition ranks: two people tied
on one nomination each, both rank 1, next rank 3. The tie path engaged, the
reveal action stayed disabled until a joint leader was chosen and a note written,
and afterwards the member screen showed the winner and the reasoning.

The nominations list showed reasons ordered by nominee name with a date and no
time, and the moderation controls disappeared once the cycle was revealed.

## The bug

The administrator link appeared for a plain member.

`listMemberships` selected from `organisation_members` filtered only by
`status = 'active'`, on the assumption that RLS would return the caller's own
row. It does not. The policy deliberately permits reading every membership in
the caller's organisations, because roles are legitimately visible inside a
tenant. So the query returned all five colleagues and the screen read the first
row's role as its own.

Nothing was exposed that the policy did not already allow, and pressing the link
would have achieved nothing, because every function behind it checks the caller's
role in the database. It was a display fault, not a breach.

The lesson is the part worth keeping: **what RLS returns and what belongs to the
caller are not the same set**, and for this table they are deliberately
different. A query that needs "mine" has to say so. Fixed by filtering on the
signed-in user id.

It is also a good argument for having built the screen rather than reasoning
about it. Nothing in the tests would have caught this, because the tests assert
what the database returns, and the database was right.

## Not done

Roster management, invitations from the interface, scheduled open and close
times, and an operator-entered moderation reason rather than the current fixed
wording.

---

# Roster management, and the invitation gap

Date: 26 July 2026

An administrator can now add people, set eligibility and create invitations from
the interface. Onboarding a new organisation no longer needs SQL, with one real
exception described below.

## Why the roster needed new functions

The client column grant on `participants` withholds `user_id` and `can_vote`
from every authenticated caller, administrators included. That is right for the
list a member sees and it makes managing a roster impossible through the table,
so management became a shaped admin-only surface.

Showing an administrator `can_vote` deserves stating, since `T2` gives it as a
reason to withhold the column from members. An administrator sets eligibility.
They cannot run a programme without knowing who can vote in it, and they already
receive reasons once a cycle closes. Withholding it from them would protect
nothing and make the job impossible. What they still never receive is which
eligible voter wrote which reason, and that boundary is unchanged.

`get_roster` returns `has_account` as a boolean rather than the user id. Whether
somebody has joined is roster state an administrator needs; the auth identity
behind it is not, and a boolean cannot be joined to anything.

## The invitation token is deliberately thrown away

`create_invitation` returns the only readable copy of the token, and the screen
discards it.

A token is a working identity for the invited person. Rendering one in an
administrator's browser puts it in screenshots, in scroll-back and in anything
that captures the page, and the invited person still does not have it. The only
sensible consumer is the trusted mail function of `COM-001`.

So **onboarding is incomplete**: an invitation can be created and nobody can
accept it, because nothing sends the email. The screen says exactly that rather
than reporting success and leaving somebody to discover it. A token on screen
would have made this demo work today and been the wrong thing to build.

## A small honesty in the interface

An unlinked participant shows `Can vote` as on, because the stored flag is true,
with the toggle disabled and the reason written next to it. The alternative was
showing it off, which would misrepresent what the database holds. The flag is
set; the account linkage is what is missing, and saying so is more useful than a
switch that silently lies in either direction.

## Verified

Read the roster against the seed and checked the toggle states rather than the
labels: the nominate-only participant's vote switch is genuinely off, and the
unlinked participant's is disabled. Added somebody through the form and they
appeared with no account and an invite action. 233 assertions pass, including 17
new ones covering who may read a roster, who may change eligibility, and that
the audit records the old and new value rather than merely that something
changed.

---

# COM-001: the invitation email

Date: 26 July 2026

Onboarding is complete. An owner invites somebody from the roster screen, the
email arrives with a working link, and that person signs up and joins. Proved end
to end against the local stack, including that a replayed token is refused.

## Why an Edge Function rather than the RPC

`create_invitation` returns the only readable copy of the token. If the browser
called it, that token would exist in the client, in devtools and in anything
that captures a response, and the invited person still would not have it. The
function creates it, emails it and discards it; the caller learns only when it
expires.

Authorisation is not reimplemented. The function calls the same RPC with the
**caller's own JWT**, so the database applies the same owner-or-admin check as
everywhere else. A bug in that file cannot grant anybody more than they already
had, which is the reason to do it that way rather than checking a role in
TypeScript. Confirmed: a plain member gets `permission_denied`, an unauthenticated
request gets `401`, and only the owner succeeded.

## Three faults, each hiding the next

**`service_role` could not write anything.** Every table gave it `REFERENCES`,
`TRIGGER` and `TRUNCATE` and no DML, so the first server-side write failed with
`42501`. The trap is that `BYPASSRLS` and a table privilege are different things:
the attribute exempts a role from *policies*, and without a `GRANT` there is
nothing to be exempt from. Every test had passed because nothing server-side had
tried to write yet.

Fixed with a migration granting exactly two tables and only the verbs used, not
`grant all on all tables`. Handing the trusted role the ballot table would move
away from `D-025`, not toward it. `001` now pins that surface too, so the next
addition is a visible decision.

**My own error handling hid it.** The claim insert treated *any* failure as
"already sent", so a broken delivery record reported success and no email was
sent. Only a `23505` means already sent; anything else is a fault and now says
so.

**My logging hid the next one.** The send failure logged `error.name`, which is
the word "Error" for almost everything. Logging the message properly needed care,
because an SMTP error usually quotes the envelope: addresses are stripped before
anything is written, which is what `COM-001` means by redacted logs.

The real message was then obvious: the mail library refused to authenticate over
a plaintext connection to the local catcher.

## No mail library

Both transports are now a single `fetch`: Resend's HTTP API in production, the
local catcher's send endpoint in development. A dependency inside a function
that handles invitation tokens is a dependency with access to invitation tokens,
and the one tried first would not talk to a local catcher at all.

Being straight about the trade: the local transport exercises this function, the
template and the token flow. It does not exercise Resend. Only a real send does,
which is `INF-016`.

## Verified

Owner invited; the message arrived at the catcher from
`recognition@jonnyai.co.uk` with the right subject and a 64-character token in
the link. The invited person signed up, accepted, and became a linked active
member. Replaying the same token returned `invitation_consumed`. The delivery
record shows `sent` against an idempotency key derived from the invitation.

---

# AUT-004: accepting an invitation

Date: 26 July 2026

The last manual step is gone. An invited person opens the emailed link, creates
an account and is in, without ever seeing a token or knowing that acceptance was
a separate operation.

## Two details that shape the screen

**The route guard has to let it through.** Everything else redirects a signed-out
visitor to sign-in, which for this route would discard the token in the query
string. `/invite` is exempt and handles its own authentication.

**Acceptance happens on the session, not on a button.** The screen offers
create-account or sign-in; the moment a session exists, the effect accepts. The
person is not asked to understand that two things happened, which is the only
reason the two-step nature is invisible.

## Refusal wording

Every failure has its own sentence, driven by the product code the database
returns rather than by message text. The wrong-email case deliberately does not
name the invited address: whoever is holding the link may not be the person it
was sent to, and naming them would tell an interceptor who works there.

## Verified

A real emailed link, opened in a browser: account created, invitation accepted,
landed on the member screen with the nominee list showing colleagues and not
himself, and no administrator link. In the database the roster entry is linked,
membership is `member` and `active`, and no live invitation remains.

## An aside worth recording

Two earlier attempts to drive this in the browser produced no effect at all, and
the temptation was to assume the screen was broken. Checking the database showed
no account had been created and the auth service had received nothing, so the
click had never reached the handler rather than the flow having failed. The
distinction mattered: the code was fine and the interaction was not.

The `supabase` CLI later refused to spawn subprocesses (`uv_spawn`), so the seed
was restored by running the file through `psql` directly. `007` had already
failed loudly at that point, correctly, because the database no longer matched
the seed after the walkthrough.

---

# Privacy: export, purge and deletion

Date: 28 July 2026

Three functions where the promises stop being copy. Each has a rule that is easy
to get subtly wrong in a way nobody notices until it matters.

## The export is asymmetric, and that is the whole design

What the subject **wrote** comes back with the nominee named, because they chose
that person and already know. What was written **about** them comes back with no
author, ever. The return shape has nowhere to put one.

Without that asymmetry a subject access request becomes a way to learn who
nominated you: a lawful right turned into exactly the disclosure the product
exists to prevent. The tests assert the author's name, email and user id appear
nowhere in the output, rather than asserting the happy path.

Reasons about the subject are also withheld while a cycle is open. A live export
would be a feed of nominations arriving, which is the standings leak by another
route.

## The purge keeps the row and removes the text

Only revealed cycles past their retention period. Draft, open and closed are
never touched, because purging work in progress destroys a live programme.

It clears the reason and keeps the ballot row. The count is what makes a past
result verifiable, and deleting rows would also free the unique slot, letting
somebody cast into a revealed cycle.

The winner snapshot survives, which works only because `DB-003` made those plain
columns with no foreign key. A decision taken three days ago for a different
reason is what makes this safe now.

`dry_run` defaults to true. A purge that deletes by default is one keystroke from
an accident.

## A grant avoided

The purge is `SECURITY DEFINER` and granted to `service_role`, so the scheduled
job can run it **without** `service_role` holding delete rights on the ballot
table. The trusted role's reach stays exactly where `DB-005` left it: two tables,
four verbs. A compromised server function can call this and nothing else.

## Three failures, all mine, none in the schema

`INSERT is not allowed in a non-volatile function`: the export was marked
`stable` while recording that an export happened. The audit entry is worth
keeping, so the function is volatile.

Then two test bugs. One expected a single reason where two genuinely qualified.
The other read `privacy_requests` directly while acting as `authenticated` and
got `permission denied` — which is the table behaving correctly, since it has no
client grant. The test now resets the role to count rows, and the fact that it
had to is itself the proof.

## Evidence

`Files=9, Tests=261` passing. The purge assertions include running it twice and
finding nothing the second time, because a scheduled job that re-purges every
night would rewrite the audit trail indefinitely.

---

# The Privacy centre, and the legal drafts

Date: 28 July 2026

## What a person can now do about their own data

`src/app/privacy.tsx` makes the functions reachable: read the confidentiality
position, see the organisation's actual retention setting rather than a generic
sentence, download an export, leave, and request deletion behind a typed
confirmation. A pending request replaces the form, so a second one cannot be
queued from the interface either.

The confidentiality wording is the same claim the legal draft makes, and it says
**confidential, not anonymous**, with the small-team caveat stated on screen. It
would have been easy to write something warmer and untrue.

## Honest status

The screen type-checks, lints and is wired to tested functions. It has **not**
been driven in a browser. Repeated attempts to sign in through the automated
browser did not register the click, while the same credentials authenticate
fine against the API, so the blocker is the automation rather than the screen.
`PRV-009` stays in progress until somebody clicks through it by hand.

Saying it is done because the code looks right would be exactly the habit the
rest of this log argues against.

## The legal drafts

`docs/LEGAL_AND_PRIVACY.md` is written from the engineering side so a solicitor
reviews facts rather than assumptions. Every claim names the file that makes it
true.

Three deliberate choices in how it is written:

It **argues against its own conclusion**. The processor analysis lists the
strongest reasons the operator might be a controller, because a reviewer who
finds those on their own will trust nothing else in the document.

It states the confidentiality claim **precisely**, separating what the schema
enforces from what it cannot. Anonymity is not claimed anywhere, because
`nominator_user_id` exists.

It names the residual risks rather than resolving them with confident wording:
free-text special-category data, retaining the nominator link after purging the
reason, and the winner snapshot surviving erasure. The last is the most likely
point of challenge in the product, and it is flagged as such rather than buried.

Eight questions are put to the reviewer, and a DPIA is recommended rather than
argued away.

---

# The schema reaches the hosted project, and DB-017 advisors

Date: 28 July 2026

Jonny reauthorised Supabase, which put the development project in reach for the
first time. All fifteen migrations are now applied to it and the advisors have
run against the real schema rather than a local container.

## Getting there took three detours, all environmental

`supabase migration list --linked` returned 403
`LegacyDbConfigLoginRoleStatusError`. The access token is fine: the same token
lists the project through the management API. It is the CLI's login-role
provisioning step that this account cannot perform, so every `--linked` command
is unusable and a direct database URL is the way round it.

`db.<ref>.supabase.co` would not connect. Direct Postgres connections are
IPv6-only and this machine has no route, which surfaces as a bare
"Failed to connect" naming nothing. The session pooler on
`aws-0-eu-west-1.pooler.supabase.com:5432` works. Port matters: 5432 is session
mode, 6543 is transaction mode and cannot run migrations.

`db push` then failed with `uv_spawn`, the same subprocess error that stopped
`db reset` earlier. `migration up --db-url` does less shelling out and applied
all fifteen cleanly.

Worth admitting: the connection probe was written with `2>&1` on a native
executable, which in PowerShell 5.1 wraps stderr in an `ErrorRecord` and reports
failure on success. That exact trap is documented in this very file from three
days ago, and I walked into it anyway.

## What the advisors actually found

Thirty findings, and almost all of them are the design being reported back.

**Seven INFO, "RLS enabled, no policy":** `recognition_nominations`,
`organisation_invitations`, `audit_events`, `device_push_tokens`,
`notification_deliveries`, `privacy_requests`, `recognition_ballot_events`.

These are precisely the seven tables the threat model closes deliberately. The
advisor's usual concern is that RLS without a policy means an unreachable table
somebody forgot about. Here it is the intent, and it is stronger than the
advisor can see, because those tables also have **no grant** to any client role.
A policy would be the weaker position: it would mean PostgREST could reach the
table and only an expression stood in the way. Accepted, by design.

**Twenty-two WARN, "signed-in users can execute SECURITY DEFINER function":**
every guarded function.

Also the architecture. Nothing writes through a table grant; everything goes
through a definer function that validates the caller internally. The warning is
worth reading rather than dismissing, because it is exactly the list a reviewer
should audit, and each one is covered by role-based tests that assert what it
refuses. Accepted, with the tests as the evidence.

**One WARN worth acting on:** leaked password protection disabled. Enabling it
returned **402 Payment Required** — it is a Pro-plan feature and this project is
on the free tier.

That is a real finding rather than a configuration slip. It joins the existing
argument for Pro before closed testing, alongside backups and the free-tier
pause, and it means the advisor list cannot be brought to zero on the current
plan. Recorded rather than quietly left failing.

## Not proved by any of this

The hosted database now has the schema. Nothing has exercised it: no user, no
organisation, no ballot. The 284 assertions all ran locally. Running them
against a hosted project is a different question and is not something to do
casually, since the suites delete organisations and users as their first act.

---

# Android: the SDK was never missing

Date: 28 July 2026

`FND-010` sat blocked for days on "Android SDK not available". It was available
the whole time, at `%LOCALAPPDATA%\Android\Sdk`, with `android-36`, build-tools
36.1.0, platform-tools, two NDKs, the emulator and an AVD already set up.

The only thing wrong was that `ANDROID_HOME` had never been set, so Expo Doctor
reported the SDK as absent and that was taken at face value. Setting it, at User
scope so it survives a reboot, moved Doctor from 16/17 to 17/17 and let
`expo prebuild` generate the native project first time.

Worth naming the mistake: "tool reports X missing" was recorded as "X is
missing" without checking. The check took one command.

## What blocks the APK now

Gradle compiles Java and Kotlin, then fails in the native step:

```text
ninja: error: manifest 'build.ninja' still dirty after 100 tries
```

`LongPathsEnabled` is `0`. Native object files nest under
`.cxx/tools/debug/arm64-v8a/CMakeFiles/...`, which takes absolute paths beyond
the 260-character limit, so ninja cannot stat or write them and its manifest
never settles. It surfaces as a retry loop rather than a path error, which is
why it is worth writing down.

The fix is an administrator registry change, which is a system setting and not
something to make on somebody's machine unasked. The alternative is building
from a short path such as `C:\eotm`.

## Three process mistakes in one build

**A broken `&&` chain hid the first attempt.** `grep` for `targetSdk` found
nothing, returned 1, and short-circuited the rest of the line. I concluded gradle
had never started. It had, and was still running twenty minutes later.

**A second build then collided with the first** and reported `BUILD FAILED`
with a lock timeout, which was reported as the build failing. It was two builds
fighting.

**A task notification said "exit code 0" when the build had failed.** The pipe
to `tail` masked gradle's exit code. Looking for the actual APK is what caught
it, and looking for the artefact rather than trusting the status is the habit
worth keeping.

---

# Verifying the legal-response migration

Date: 28 July 2026

The legal work arrived with an honest caveat: the migration and its 31 pgTAP
assertions had never been executed, because that machine had no Postgres. This
machine does.

## The migration was right; a constraint of mine refused it

Three assertions failed immediately, all on `redact_winner_snapshot`:

```text
23514: new row for relation "recognition_cycles"
violates check constraint "recognition_cycles_winner_only_when_revealed"
```

The redaction severs `winner_participant_id` so a redacted name cannot be
recovered by joining back to the roster. The constraint written in `DB-003`
required that link to be present whenever `status = 'revealed'`, so every
redaction failed.

Two correct rules collided. The constraint exists to make `FR-RESULT-01`
structurally true: no winner data may sit on a cycle that has not been revealed.
That guarantee is untouched. What it *also* asserted, without anybody intending
it, was that a revealed winner must remain identifiable forever — which is the
opposite of what an Article 21 objection requires.

The public fact of a result is the name and the count. The roster link is an
internal convenience and precisely the thing redaction has to remove. So it is
now optional on a revealed cycle and still forbidden on an unrevealed one.

## Why this is worth recording

The constraint was written three days ago for a good reason and was correct then.
It became wrong when the product acquired an obligation that did not exist yet.
Nothing was wrong with either decision; the conflict only existed once both were
true, and only running the tests surfaced it.

It also vindicates the caveat. Shipping that migration unverified would have
produced a redaction feature that always failed, in the one area where failing
quietly is least acceptable.

## Result

`Files=11, Tests=315` passing, across two consecutive replays from empty.
`db lint` clean. Types regenerated. Typecheck, lint and 25 domain tests pass.

Biome also had to be told to ignore `android/` and `ios/`: `expo prebuild`
generates CMake JSON in there and it was producing 1,511 lint errors from files
nobody wrote.
