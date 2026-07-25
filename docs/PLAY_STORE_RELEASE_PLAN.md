# Google Play release plan

Version: 0.1  
Research date: 25 July 2026  
Status: Proposed

## Release strategy

Ship in four controlled stages:

1. Local and emulator verification.
2. Play internal testing with named devices and accounts.
3. Play closed testing with real organisations.
4. Production release with a small country scope and staged rollout.

No public production submission is authorised by this document.

## Time-sensitive Google Play requirements

### Target API

- New apps currently need to target at least Android 15, API level 35.
- From 31 August 2026, new apps and updates must target Android 16, API level
  36.
- This project will target and compile against API 36 from its first build so it
  does not launch immediately into a mandatory upgrade.

### 16 KB memory pages

Since 1 November 2025, new apps and updates targeting Android 15 or later must
support 16 KB memory pages. React Native supports this, but every native
dependency in the final AAB must be checked.

### Developer and package verification

- A commercial app should use an organisation Play developer account where the
  legal entity and required D-U-N-S record are ready.
- Organisation accounts require a website and verified public contact details.
- Effective 30 September 2026, Play packages must be registered to a verified
  developer. Google may auto-register eligible Play packages, but this must be
  confirmed in Play Console.
- The package name is permanent after first upload. Reserve it only after the
  legal publisher and brand are agreed.

### Testing requirement

Personal developer accounts created after 13 November 2023 must currently run a
closed test with at least 12 continuously opted-in testers for 14 days before
applying for production access. The tester count, account type and current
Console requirement must be checked in the actual account before scheduling.

Even if an organisation account is not subject to that gate, this project will
run at least a 14-day closed test.

## Proposed app identity

These are working values, not final registrations.

| Item | Proposal | Constraint |
|---|---|---|
| App name | `Employee of the Month` | Confirm Play title length and distinctiveness |
| Short descriptor | `Private monthly team voting` | Use in listing, not package |
| Package name | `uk.co.jonnyai.employeeofthemonth` | Must be approved and registered before upload |
| URL scheme | `uk.co.jonnyai.employeeofthemonth` | Must match app-link plan |
| Developer name | `JonnyAI` or legal organisation name | Must match verified publisher decision |
| Category | Business | Confirm at listing setup |
| Initial countries | United Kingdom only | Expand after beta evidence |
| Content rating | Expected Everyone | Complete questionnaire from actual content |

Before first upload, verify that the package has never been used and that the
domain association can be served from an HTTPS JonnyAI property.

## Account readiness

### Organisation account checklist

- [ ] Legal entity selected.
- [ ] D-U-N-S number exists and matches legal name and address.
- [ ] Public website is live and can be verified.
- [ ] Developer email is role-based and monitored.
- [ ] Developer phone is verified.
- [ ] Contact details match the payments profile.
- [ ] Two-step verification is enforced for every Console user.
- [ ] Least-privilege Play Console roles are assigned.
- [ ] Current Android developer verification is complete.
- [ ] Package registration status is recorded.

Do not create a new personal publisher account merely to move faster. Account
type cannot be treated as a disposable implementation detail.

## Build and signing

- Produce an Android App Bundle (`.aab`).
- Use Play App Signing.
- Let Google generate the app signing key unless a documented cross-store
  signing requirement exists.
- Create a separate upload key.
- Store the upload key and recovery material in the approved secret vault, not
  Git, shared drives or build logs.
- Register the Play app-signing certificate fingerprints with any provider that
  validates Android signing, including app links or OAuth.
- Enable release provenance where supported.
- Use monotonically increasing integer `versionCode`.
- Use semantic user-facing `versionName`, beginning with `0.1.0` for internal
  testing and `1.0.0` only when production criteria are met.

## Android configuration

- `compileSdkVersion`: 36
- `targetSdkVersion`: 36
- proposed `minSdkVersion`: 24, Android 7, matching Expo SDK 57 support
- Edge-to-edge layout enabled and tested.
- Predictive back tested on Android 16.
- Adaptive icon with foreground and background assets.
- No unsupported orientation lock on large screens.
- No exact alarm permission.
- No contacts, location, microphone, camera, phone or SMS permissions.
- Request `POST_NOTIFICATIONS` in context on Android 13+.

Run the AAB through bundle inspection and a 16 KB compatible device or emulator
before every release candidate.

## Policy and privacy pack

### Required public pages

Host over HTTPS with stable URLs:

- Privacy notice.
- Terms of service.
- Account and data deletion request page.
- Support page and contact.
- Security contact or vulnerability-reporting route.

The deletion page must name the app or developer, be easy to find and let a
former user initiate deletion without reinstalling the app.

### In-app privacy controls

- Settings > Privacy > Download my data.
- Settings > Privacy > Delete account.
- Settings > Organisation > Leave organisation.
- Owner-only organisation deletion.
- Notification preference and device token revocation.
- Clear retention explanation.
- Clear statement: voting is confidential, not technically anonymous.

### Data safety working inventory

The final form must be generated from the release artefact and every included
SDK. This table is a planning baseline.

| Data type | Collected | Shared | Purpose | User deletion |
|---|---|---|---|---|
| Email address | Yes | Auth/email processors | Account management, invitations, security | Yes, subject to documented retention |
| User ID | Yes | Service processors | Account and organisation membership | Yes/anonymised |
| Name | Yes | Organisation members inside tenant | App functionality and recognition | Yes; winner snapshot may have documented retention |
| User content: nomination reason | Yes | Nominee/admin after permitted stage | App functionality, moderation | Yes under retention/rights workflow |
| Photos: optional avatar | Optional | Organisation members inside tenant | App functionality | Yes |
| App interactions | Minimal | No advertising party | Product operation and measurement | Aggregated or deleted |
| Crash logs | If crash SDK enabled | Crash processor | Reliability | Per processor policy |
| Device or other IDs: FCM token | Yes | Google FCM | Notifications | Yes/revoked |
| Purchase history | No in v1 | No | Not applicable | Not applicable |
| Location, contacts, health, financial data | No | No | Not applicable | Not applicable |

Definitions of "collected" and "shared" in the Play form can differ from
ordinary language. Re-evaluate each processor and SDK immediately before form
submission.

### Data handling controls

- TLS in transit.
- Supabase-managed encryption at rest, documented rather than overstated.
- No advertising SDK.
- No ballot content in telemetry.
- Data deletion and retention are functional before closed testing.
- Privacy policy matches actual behaviour and named processors.
- Customer organisation has controller instructions and an appropriate DPA.

## Account deletion requirement

Because the app creates user accounts:

1. Provide an in-app path to initiate deletion.
2. Provide a functional web deletion resource in Play Console.
3. Delete associated user data unless a clearly disclosed lawful reason
   requires retention.
4. Explain any required ownership transfer or subscription cancellation.
5. Make retained categories and retention periods clear.
6. Test the full request, verification, revocation, deletion and confirmation
   path.

## Payments

V1 has no payment, subscription, external purchase link or locked paid feature.

Before monetisation:

- Recheck the then-current Play Payments policy.
- Decide whether Android access is sold through Play Billing, an eligible
  alternative programme or a compliant consumption-only B2B model.
- Model service fees and regional rules.
- Add cancellation and subscription-management routes.
- Update Data safety, terms and listing copy.

Do not add a website checkout button inside the Play-distributed app without a
specific policy decision.

## Store listing proposal

### Title

Employee of the Month

### Short description

Run fair, private monthly team nominations from any Android phone.

### Full description draft

Employee of the Month gives small teams a simple way to recognise great work
without paper slips, spreadsheets or a complicated HR platform.

Create a team, invite colleagues and open a monthly nomination round. Each
eligible person can nominate one colleague. Self-nominations and duplicate
votes are blocked, and live results stay hidden until voting closes.

For team members:

- join through a secure invitation;
- see clear recognition criteria;
- nominate one eligible colleague;
- add a short reason;
- change your mind while voting remains open;
- see the winner after the result is revealed.

For programme administrators:

- manage the roster and eligibility;
- open and close monthly cycles;
- monitor aggregate turnout;
- handle inappropriate content;
- resolve genuine ties with an audit note;
- control retention and privacy requests.

Ballots are confidential. Administrators do not receive voter identities
through normal app screens or exports.

Employee of the Month is a recognition tool. It is not a performance,
disciplinary, payroll or promotion system.

### Listing assets

- High-resolution app icon.
- Feature graphic.
- At least six phone screenshots:
  1. current open cycle and criteria;
  2. nominee list;
  3. nomination confirmation;
  4. confidential ballot explanation;
  5. revealed winner card;
  6. admin cycle overview.
- One 7-inch and one 10-inch tablet set if Play requires or strongly prompts
  them for the selected device catalogue.
- Privacy policy and support links.

Screenshots must use synthetic names and organisations. Never use beta customer
or employee data.

## Testing tracks

### Local and pre-Play

- API 24, 33, 35 and 36 emulators.
- At least one low/mid-range physical Android phone.
- Large font, TalkBack, dark mode, rotation and tablet/resizable emulator.
- Poor network, offline, process death and notification denial.

### Internal testing

Audience: project team and trusted technical testers.

Exit criteria:

- Install and update through Play.
- Auth app links work from Gmail and browser.
- Push works on a physical device.
- No P0/P1 defects.
- Crash-free smoke suite.
- Account deletion completes.

### Closed testing

Audience: at least 12 engaged testers and preferably 3 to 5 real organisations,
expanded to 10 to 20 organisations before production.

Run for at least 14 continuous days. Testers must:

- join by invitation;
- complete one real or synthetic monthly cycle;
- try denied notification permission;
- test withdrawal and recast;
- submit structured feedback;
- include at least one owner and multiple members per organisation.

Exit criteria:

- Store-required tester threshold is satisfied.
- At least two full cycle transitions have been observed.
- Crash-free users at least 99.5%.
- No unresolved privacy, tenant isolation or ballot integrity issue.
- Activation and turnout hypotheses have enough data for a go/no-go decision.
- Support and deletion routes respond within stated time.

### Production

- United Kingdom only.
- 10% staged rollout for at least 48 hours.
- 25%, 50% and 100% only after Android vitals and support review.
- Halt for any P0 security/privacy defect or a crash rate above the agreed
  threshold.

## Pre-launch review pack

- Signed AAB and checksum.
- Dependency and licence inventory.
- Permissions report.
- Data safety evidence matrix.
- Privacy and deletion URLs.
- Content rating answers.
- Target audience declaration.
- Ads declaration: no ads.
- App access instructions and reviewer test account.
- Release notes.
- Test report and known limitations.
- Support runbook.
- Rollback and emergency unpublish procedure.

## Operational launch checks

- Production Supabase project is on a backed-up paid plan.
- Database migrations are applied and verified.
- Cron jobs have heartbeats and failure alerts.
- Resend domain has SPF, DKIM and DMARC.
- FCM key is least privilege and stored in server secrets.
- Support inbox is monitored.
- Privacy requests have an owner and due-date process.
- Status page or incident message route exists.
- App version and minimum supported version are remotely visible.
- No production data appears in logs, screenshots or test fixtures.

## Sources

Accessed 25 July 2026:

- [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-GB_ALL)
- [Google Play target API policy](https://support.google.com/googleplay/android-developer/answer/16561298?hl=en)
- [Android 16 KB page-size requirement](https://developer.android.com/guide/practices/page-sizes)
- [Play account testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
- [Play Data safety form](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Play payments policy](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en)
- [Play organisation account requirements](https://support.google.com/googleplay/android-developer/answer/13634885?hl=en)
- [Developer identity verification](https://support.google.com/googleplay/android-developer/answer/10841920?hl=en)
- [Play package registration](https://support.google.com/googleplay/android-developer/answer/16984799?hl=en-EN)
- [ICO data minimisation](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/data-protection-principles/a-guide-to-the-data-protection-principles/data-minimisation/)
- [ICO storage limitation](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/data-protection-principles/a-guide-to-the-data-protection-principles/storage-limitation/)
- [ICO worker data guidance](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/employment/)

## Policy watch

Google Play billing, service fees, developer verification and target API rules
are actively changing in 2026. Re-run a policy review:

- before the first closed-test upload;
- before applying for production;
- before adding payment;
- before expanding outside the UK;
- after adding any SDK that handles user data.
