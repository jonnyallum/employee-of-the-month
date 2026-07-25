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
