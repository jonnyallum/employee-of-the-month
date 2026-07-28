# Privacy, data protection and terms

Version: 0.1 draft for legal review
Date: 28 July 2026
Status: **Not legal advice. Drafted by the engineering side to describe what the
system actually does, so a solicitor reviews facts rather than assumptions.**

Covers `PRV-001` and `PRV-002`. Neither card is complete until a qualified
person has reviewed this and the outcome is recorded in `docs/DECISIONS.md`.

## How to read this

Every factual claim below is traceable to code in this repository, and the
relevant file is named. Where the law is unsettled or the answer depends on a
commercial decision, that is said plainly rather than resolved with confident
wording.

Three things make this product unusual enough that a template privacy notice
would be actively wrong:

1. It processes **workplace opinion about identifiable colleagues**, which is
   personal data about the nominee as well as the nominator.
2. It makes a **confidentiality promise that is technically enforced** and that
   can be verified against the schema. Overclaiming it would be a
   misrepresentation; underclaiming it wastes the main protection.
3. The customer organisation, not the operator, decides who is on the roster and
   why the programme runs, which drives the controller analysis below.

---

## 1. Controller and processor

### The intended model

| Processing | Role | Reasoning |
|---|---|---|
| Running a recognition programme: roster, cycles, ballots, results | Customer organisation is **controller**; the operator is **processor** | The customer decides who participates, what the criteria are, when a cycle opens and what happens to the result. The operator has no say in any of it. |
| Account, authentication, security logs, billing, product operation | Operator is **controller** | The operator decides to keep these, for its own purposes, and the customer cannot instruct otherwise. |

This split is normal for B2B SaaS, but it is worth stating that it is a
**conclusion, not a given**. The operator does make some decisions that shape
processing, and a reviewer should test whether they cross into controllership:

- The operator decides that ballots are confidential and that administrators
  cannot see voter identity. A customer cannot switch this off.
- The operator sets a 12-month default retention, and constrains the choices to
  3, 6, 12, 24 or indefinite.
- The operator decides that no ranking exists while a cycle is open.

These are product design choices rather than purposes, and the usual reading is
that a processor may determine technical means. They are listed because they are
the strongest arguments against the intended model, and a reviewer should see
them rather than discover them.

### Question for the reviewer

Does constraining retention to a fixed set of options, and refusing to let a
customer disable ballot confidentiality, affect the processor analysis? The
engineering position is that these are means rather than purposes, and that the
customer remains free to choose the programme, the people and the outcome.

---

## 2. What is actually processed

Taken from the live schema, not from a template. Table names are real.

### Personal data about an identified individual

| Data | Where | Notes |
|---|---|---|
| Email address | `auth.users`, `organisation_invitations.email_normalised` | Invitation email is admin-only and never in a ballot API |
| Display name | `profiles`, `participants.display_name` | Roster names are visible to colleagues in the same organisation |
| Team | `participants.team` | Optional, free text, set by an administrator |
| Avatar | `participants.avatar_path` | Private bucket, signed short-lived reads |
| Membership and role | `organisation_members` | Visible to colleagues in the same organisation |
| Eligibility flags | `participants.can_vote`, `can_receive`, `active` | Withheld from members; visible to administrators, who set them |
| **Who nominated whom** | `recognition_nominations.nominator_user_id` | See section 3. Stored, never exposed |
| **Free-text reason** | `recognition_nominations.reason` | Opinion about a named colleague. The highest-risk field in the product |
| Winner record | `recognition_cycles.winner_name`, `winner_nominations` | A snapshot, deliberately not a foreign key, so it survives roster changes and erasure |
| Device push token | `device_push_tokens.token` | Personal data. No client read path |
| Audit and delivery records | `audit_events`, `notification_deliveries` | Actor and action; no ballot content |

### Deliberately not collected

Date of birth, home address, phone number, emergency contacts, device contacts,
precise location, microphone, camera, background location, salary, attendance,
productivity, health, disciplinary records, diversity data, advertising
identifiers. There is no column for any of them, which is a stronger statement
than a policy sentence.

### The special-category problem

The product does not ask for special-category data. It cannot stop somebody
typing it into a 500-character free-text box: "covered for me while I was having
treatment" is health data about the nominee, volunteered by a third party.

Mitigations in the product today:

- A warning immediately above the field, before typing, not buried in terms
  (`src/app/index.tsx`).
- Administrator moderation with hide and restore, each requiring a recorded
  reason (`moderate_nomination`).
- Reasons unavailable to administrators until a cycle closes (`D-014`), so live
  content cannot be browsed.

**This is a real residual risk and should not be written away.** A reviewer
should decide whether it needs an explicit prohibition in the customer terms, an
obligation on the customer to instruct staff, or a DPIA in its own right.

---

## 3. The confidentiality claim, stated precisely

The product says **confidential**, never anonymous. `D-003` records why, and the
distinction matters legally as well as ethically.

**What is true, and enforced in the database:**

- `recognition_nominations` has no grant to any client role. A member, an
  administrator and an owner are each refused. Even `count(*)` is refused.
  Asserted in `supabase/tests/002_rls_policies.test.sql`.
- The administrator-facing function returns no nominator field, no precise
  timestamp, and orders by nominee name rather than time. Its exact return shape
  is asserted by a contract test in `006_admin_turnout_and_reveal.test.sql`.
- Turnout is counts only. No function anywhere returns who has or has not voted.
- A subject access request returns what somebody wrote with the nominee named,
  and what was written about them with no author
  (`export_my_data`, tested in `009_privacy.test.sql`).

**What is not true, and must not be claimed:**

- It is not anonymous. `nominator_user_id` exists, because one-vote and
  eligibility enforcement require it. A court order, a database administrator or
  the operator's own trusted server role could reach it.
- In a small team it can be **inferred** regardless of the schema. With two
  eligible voters an administrator who voted can deduce the other ballot by
  subtraction. The product warns below eight eligible voters (`D-022`,
  `FR-CYCLE-04`) and the warning is on screen, not in a footnote.

Any privacy notice that says "anonymous" would be inaccurate. The wording in
section 6 is deliberately narrower.

---

## 4. Lawful basis

For the customer as controller, the likely basis is **legitimate interests**:
running a voluntary internal recognition scheme. Consent is a poor fit in an
employment relationship because it is rarely freely given, and the scheme is not
necessary for the employment contract.

A legitimate interests assessment should cover, at minimum:

- Participation is voluntary and a member can decline to vote with no
  consequence recorded anywhere. **True today**: no function records or exposes
  who did not vote.
- The programme is not used for performance management, pay, promotion or
  discipline. **`D-007` prohibits this and the product produces no rating.** The
  customer terms should carry the same prohibition, because the product cannot
  enforce what a customer does with a result.
- Data is minimal and retained for a limited period by default.

For the operator as controller of account and security data, legitimate
interests in operating and securing the service is the conventional basis.

### Question for the reviewer

Should the customer terms **contractually prohibit** using results in
performance, pay, promotion or disciplinary decisions? The engineering position
is yes: the product refuses to produce a rating, but nothing stops a manager
misusing a winner list, and the prohibition is what makes the legitimate
interests assessment hold.

---

## 5. Retention and erasure

| Data | Default | Configurable | Enforced by |
|---|---|---|---|
| Nomination reason text | 12 months after reveal | 3, 6, 12, 24 months, or indefinite | `purge_expired_nominations` |
| Ballot rows | Retained | No | Kept so a past result stays verifiable |
| Winner snapshot | Retained until the organisation deletes it | No | Plain columns, no foreign key |
| Account and profile | Until deletion is requested and processed | n/a | `request_account_deletion` |

Two points a reviewer should be aware of:

**The ballot row survives the purge.** Only the reason text is cleared. The row
is kept because the count is what makes a historic result verifiable, and
because removing it would free the one-vote slot and allow a ballot to be cast
into a revealed cycle. A reviewer should confirm that retaining
`nominator_user_id` beyond the reason text is defensible; the engineering
justification is integrity of a published result.

**The winner snapshot outlives erasure.** `D-016` retains the winner's display
name and nomination count after an account is erased, on the basis that a past
award is an organisational fact the employer announced. Reason text does not
survive (`D-023`). This is the most likely point of challenge in the whole
document and needs an explicit legal position.

---

## 6. Privacy notice, draft wording

For the customer to give to employees. Deliberately short and specific.

> **Employee of the Month: how your information is used**
>
> Your employer runs this recognition scheme and decides who takes part. We
> provide the software.
>
> **What we hold about you:** your name, your work email address, your team if
> your employer records one, and whether you are eligible to nominate or be
> nominated. If you take part, we hold the colleague you nominated and anything
> you wrote about them.
>
> **Who can see your nomination:** nobody. Your employer's administrators can
> see how many people voted and the result. They cannot see who you nominated,
> and no screen, export or report in this product will tell them. We keep an
> internal record of who voted so that everyone votes once and nobody votes
> twice; that record is not available to your employer.
>
> **This is confidential, not anonymous.** In a small team it may still be
> possible to work out how someone voted from the result alone. We warn your
> administrator when a team is small enough for that to be likely.
>
> **What people write about you:** if a colleague nominates you, the reason they
> gave may be shown to your administrator once voting closes, and to you if you
> ask for a copy of your data. We will never tell you who wrote it.
>
> **Please do not include** health information, disciplinary matters, or
> anything sensitive about a colleague when you write a reason.
>
> **How long we keep it:** your employer chooses, up to a maximum they set. By
> default the reasons people wrote are deleted 12 months after a result is
> announced. The record that you won a month is kept.
>
> **Your rights:** you can ask for a copy of your information, ask us to correct
> it, or ask for your account to be deleted, from inside the app or from
> [deletion page URL]. Deleting your account does not remove a past public
> result announcing that you won.
>
> **Notifications** contain no names and no nomination content.

---

## 7. Subprocessors

Real, as deployed. Each needs a data processing agreement in place before real
employee data.

| Subprocessor | Purpose | Data | Location |
|---|---|---|---|
| Supabase | Database, authentication, storage, functions | All application data | Development project is `eu-west-1` Ireland. **Production region is an open decision, `INF-012`** |
| Resend | Transactional email: invitations, verification | Email address, invitation link | Sending domain `jonnyai.co.uk` |
| Google (Firebase Cloud Messaging) | Push notifications | Device token, generic message | Not yet configured, `INF-004` |
| Expo / EAS | Build and distribution | No employee data at runtime | Build-time only |
| GitHub | Source control and CI | No employee data. CI uses a throwaway local database | |

A reviewer should confirm whether the production region must be UK rather than
EU for the target market, and whether an EU location requires anything
additional for UK customers post-Brexit. That is a commercial and legal
decision, not an engineering one, and it cannot be changed after a Supabase
project is created.

---

## 8. Employment-use disclaimer, draft

For the customer terms.

> This service records voluntary peer recognition. It is not a performance
> management, appraisal, promotion, pay or disciplinary tool, and it produces no
> rating, score or ranking of any individual.
>
> You agree not to use results from this service as evidence in any performance,
> pay, promotion, redundancy or disciplinary process, and not to require any
> employee to take part.
>
> Popularity in a peer vote is not a measure of performance, and using it as one
> may expose you to discrimination and unfair treatment claims. Those risks are
> yours, not ours.

The final sentence is deliberately blunt. A reviewer may soften it; the
engineering view is that the risk is real and a customer should meet it in plain
words rather than in a definitions clause.

---

## 9. DPIA

A DPIA is likely required. Not because the product is high-risk by design, but
because the ICO's criteria are met on several counts and a reasonable regulator
would expect one:

- systematic processing of employee personal data;
- evaluation or scoring of individuals is **arguable**, since a vote count is
  produced, even though it is not a performance measure;
- data about identifiable people supplied by third parties, namely colleagues'
  opinions;
- a power imbalance between employer and employee, which is the standard reason
  workplace processing attracts scrutiny.

The engineering recommendation is to complete one before closed beta rather than
argue it is unnecessary. Most of the input already exists in
`docs/SCHEMA_THREAT_MODEL.md`, which documents the risks, the controls and the
residual risk in the form a DPIA asks for.

---

## 10. What a reviewer should decide

1. Does the controller/processor split in section 1 hold, given the product
   constraints listed there?
2. Is retaining `nominator_user_id` after the reason text is purged defensible?
3. Is the retained winner snapshot after erasure defensible, and what wording is
   needed for it?
4. Should misuse for performance, pay or discipline be contractually prohibited?
5. Is a DPIA required, and does the threat model supply enough of it?
6. Does the production region need to be UK?
7. Is the free-text special-category risk adequately mitigated by a warning,
   moderation and deferred access, or is more needed?
8. Is the confidentiality wording in section 6 accurate and not overclaiming?

## 11. What is not written yet

Terms of service, the data processing agreement itself, and the cookie or
tracking position, which is currently trivial because the product has no
analytics and no advertising identifiers. Those follow once the questions above
are answered, since each depends on them.
