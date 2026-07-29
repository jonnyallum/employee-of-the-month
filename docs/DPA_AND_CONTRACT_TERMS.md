# Data processing agreement and customer terms

**Status: draft for solicitor review. Not executed, not offered to anybody.**

This is the document `D-026` and `D-029` said had to exist before the first
customer. It is written by the person who built the product, not by a lawyer,
and it is deliberately explicit about the reasoning so that counsel can see what
each clause is trying to achieve and rewrite it properly rather than guess.

Two parts, because they answer different questions:

- **Part A** is the Article 28(3) processor schedule. It answers "on what terms
  do we hold the customer's employee data".
- **Part B** is the permitted-use covenant. It answers "what is the customer
  contractually forbidden from doing with the results", which is a different
  problem and, on the analysis in `D-029`, the more dangerous one.

Part C lists the points where I know the drafting is thin, so counsel is not
left to find them.

Throughout: **we** are Employee of the Month (the supplier). **The customer** is
the employer who runs a recognition programme. **A participant** is one of the
customer's employees named on the roster.

---

# Part A — Processor schedule (UK GDPR Article 28(3))

## A1. Roles

The customer is the **controller**. We are the **processor**.

This is not a label of convenience. It follows from the customer deciding who is
on the roster, when a cycle opens and closes, what the criteria say, how long
reasons are kept, and what happens to a result. We decide none of those.

**Article 28(10) is self-executing**, so it is worth saying plainly what would
change the answer: if we ever determined the purposes or the essential means of
processing employee data, we would become a controller for that processing by
operation of law and not by agreement, whatever this document said. Schedule A8
exists precisely because two of the product's fixed characteristics sit close to
that line.

We are an independent **controller** for a small, separate set of processing:
account records for the individuals who administer the service, billing, service
security logging, and product telemetry that is not linked to a participant.
That processing is outside this schedule and covered by our own privacy notice.

## A2. Subject matter, duration, nature and purpose

| | |
|---|---|
| **Subject matter** | Operation of a monthly peer recognition programme. |
| **Duration** | The term of the customer agreement, plus the deletion window in A9. |
| **Nature** | Collection, storage, organisation, retrieval, aggregation, erasure and transmission by electronic means. |
| **Purpose** | Enabling employees to nominate a colleague, counting ballots, announcing a winner, and giving administrators counts and moderation tools. Nothing else. |

## A3. Types of personal data

- **Identity and contact**: name, work email address, display name, optional
  team name.
- **Account**: authentication credentials held by our authentication
  subprocessor, sign-in timestamps.
- **Programme participation**: that a named person cast a ballot in a named
  cycle; roster eligibility flags; role within the organisation.
- **Ballot content**: the chosen colleague, a required category tag, and an
  optional free-text note of up to 250 characters.
- **Outcome**: winner name and nomination count per cycle, per-nominee tallies,
  turnout counts.
- **Rights records**: subject access and erasure requests and their state.

**Special category data (Article 9): not requested, not required, and not
reliably preventable.** The free-text note is the exposure. A colleague may
write "covered my shift while I was having chemotherapy" without being asked to
and without anybody wanting them to. The product's mitigations are set out in
`docs/LEGAL_AND_PRIVACY.md` and are, in short: a required category tag so the
note is optional rather than the only way to say anything (`D-032`), a warning
above the field rather than below it (`D-031`), moderator hide and redact powers
that work after a result is announced (`D-030`), and retention that removes the
text (`D-027`).

Counsel should assume this data will occasionally be present and advise on the
customer's Article 9 condition accordingly, most likely
**DPA 2018 Schedule 1 Part 1 paragraph 1** (employment) with an appropriate
policy document. Drafting that assumes it will never occur would be drafting for
a product that does not exist.

## A4. Categories of data subject

Employees, workers and contractors of the customer who are placed on the roster.
This includes people who **never use the service**: a participant can be
nominated, and can be named as a winner, without having signed in.

## A5. Our obligations

We shall:

**(a) Process only on documented instructions.** The customer's documented
instructions are this schedule, the customer agreement, and the choices the
customer makes in the product. We will inform the customer immediately if we
consider an instruction infringes UK GDPR or other data protection law, and may
suspend the affected processing until it is resolved.

**(b) Ensure confidentiality.** Every person we authorise to access customer
personal data is under a written confidentiality obligation that survives the
end of their engagement.

**(c) Take Article 32 measures.** See A6.

**(d) Engage sub-processors only as set out in A7.**

**(e) Assist with data subject rights.** The product does most of this without
our involvement: a participant can export their own record and request erasure
from within the app. Where a request needs our help, we will provide it taking
into account the nature of processing and the information available to us.

Two limits the customer must understand before it signs, because they will
otherwise be discovered during a live request:

- **We cannot tell a participant who nominated them.** This is a deliberate
  design property, not a system limitation, and it is the promise the product
  is built on. An export returns what a person wrote with the nominee named,
  and what was written about them with the author removed.
- **We cannot reconstruct a disputed individual ballot after a cycle closes.**
  An audit trail capable of doing so would be the exact disclosure the product
  exists to prevent (`D-024`).

Counsel: the interaction between this and a participant's Article 15 right to
"any available information as to the source" is one of the open questions in
Part C.

**(f) Assist with Articles 32 to 36.** Including personal data breach
notification, data protection impact assessments and prior consultation. We
will notify the customer without undue delay and in any event within
**24 hours** of becoming aware of a personal data breach affecting its data,
with the information available at that time and updates as it emerges.

**(g) Delete or return.** See A9.

**(h) Demonstrate compliance.** See A10.

## A6. Security measures

The technical measures below are the ones a customer's security reviewer will
ask about, stated as they are actually implemented rather than as a list of
aspirations. The full design is in `docs/SCHEMA_THREAT_MODEL.md`, which is
available to customers under NDA.

- **Tenant isolation is enforced in the database, not in application code.**
  Every table has row level security enabled, and tenancy is a composite key
  rather than a check that application code has to remember to apply.
- **Every table starts with no client access at all.** Access is opened
  deliberately, column by column, and the exposure surface is pinned by an
  automated test that fails if a column or a table is added to it. The ballot
  table itself has no client grant of any kind.
- **The voter's identity is withheld by the shape of the interface.** No
  administrator-facing function returns anything that names a nominator; that
  is asserted by name in the test suite rather than left to review.
- **Encryption** in transit (TLS 1.2+) and at rest.
- **Authentication** uses PKCE; sessions are held in the device keystore.
- **Access on our side** is limited to named individuals, and is logged.
- **Backups** are encrypted, retained for 7 days, and restoration is tested.

**What we do not claim.** We hold a technical ability to read customer data,
because somebody has to be able to operate and repair the service. The product
does not offer end-to-end encryption and does not claim to. Any statement that
"nobody can see your nomination" is false at our layer and is not made in our
customer-facing copy (`D-031`).

## A7. Sub-processors

The customer gives general written authorisation to the sub-processors below. We
will give **30 days' notice** before adding or replacing one, during which the
customer may object on reasonable data protection grounds; if the objection
cannot be resolved, the customer may terminate the affected service without
penalty.

| Sub-processor | Purpose | Data | Location |
|---|---|---|---|
| Supabase | Database, authentication, file storage, serverless functions | All of A3 | London (`eu-west-2`) for production, per `D-034` |
| Resend | Transactional email (invitations, notifications) | Name, email address | See A8 |
| Expo / Google Firebase Cloud Messaging | Push notifications | Device token, notification content | See A8 |

Each sub-processor is bound by terms materially equivalent to this schedule, and
we remain fully liable for their performance.

**Residency caveat, stated deliberately.** Production data is stored in London.
That is not the same as "your data never leaves the UK", and we do not say that
it does, because support and engineering staff at our sub-processors may access
systems from outside the UK. `D-034` records this as an open item: the claim
will not be made in any customer-facing material until sub-processor support
access has been audited. Counsel should treat the transfer position as
**unresolved** and advise on the appropriate transfer mechanism (UK IDTA or the
Addendum to the EU SCCs) once that audit is done.

## A8. Schedule of pre-set characteristics

**This schedule is the point of the whole document.** It exists because of
EDPB Guidelines 07/2020, under which the duration of storage and the categories
of recipient are *essential means* reserved to the controller, and two of the
three characteristics below touch them. The answer is not that these are
technical details, because they are not. It is that the customer selects them
knowingly from what is offered.

The customer confirms that it has assessed each of the following as controller,
that each is a choice it makes rather than a constraint we impose, and that it
is satisfied each is appropriate for its own purposes:

**1. Ballot confidentiality (recipients).** No interface discloses who nominated
whom. Administrators see results, per-nominee tallies and turnout counts, never
a voter. This cannot be turned on or off. The customer confirms it does not
require, and will not require, the identity of voters.

**2. Retention of nomination content (duration).** The customer selects from
3, 6, 12 or 24 months, or indefinite. Default 12. At that point the free-text
note and the link between the nominator and the person they chose are both
removed.

**3. Retention of the residual ballot record (duration).** After the above, a
record that a named person voted in a named cycle survives, because the
one-vote-per-person guarantee depends on it. The customer selects 12, 24, 36 or
60 months, or indefinite, for how long that record is kept. Default 24.

**4. Hidden leaderboard (means).** No live standings are shown to anybody while
a cycle is open. This cannot be turned on or off.

**5. Small-team warnings.** Where a team is small enough that a ballot may be
deducible from the result, the product warns the administrator before the cycle
opens and warns the voter before they vote, and tells the voter they need not
vote. This cannot be turned off.

The customer further confirms it has considered whether characteristics 2 and 3
are consistent with its own retention schedule, and that selecting **indefinite**
for either is a decision it makes under Article 5(1)(e) and must be able to
justify.

## A9. Deletion and return

On termination, at the customer's election:

- **Return**: a structured export in machine-readable form, available for
  **30 days** after termination.
- **Deletion**: all customer personal data deleted within **30 days**, with
  backups purged within a further **35 days** in line with the backup cycle.

If the customer makes no election within 30 days, we will delete. Silence should
not preserve employee data indefinitely.

We may retain data where required by law, limited to what the law requires and
for no longer.

## A10. Audit

We will make available the information necessary to demonstrate compliance,
including our own DPIA, our security documentation, and the schema threat model.

The customer may audit no more than **once in any 12 months** on 30 days' notice
and at its own cost, except following a personal data breach affecting its data,
when it may audit immediately and we bear the cost.

---

# Part B — Permitted use covenant

This is `D-029`. It is drafted as a **covenant with an indemnity and a
suspension right, not a disclaimer**, and counsel should preserve that
distinction. A disclaimer allocates loss after the event. The problem here is
that the customer's own lawful basis collapses if it does the forbidden thing,
so the object is to stop it happening, and a term the customer has actively
promised to comply with is stronger evidence than a limitation buried in a
schedule.

## B1. Permitted purpose

The customer may use the service **only** to recognise and celebrate employee
contribution.

## B2. Prohibited uses

The customer shall not use, and shall not permit any person to use, the service
or any output of it as a factor, input, evidence or justification in:

- pay, bonus, commission or any other financial reward decision;
- promotion, demotion, grading, levelling or succession;
- redundancy selection or any scoring or matrix used for it;
- performance management, capability, probation or any formal review;
- disciplinary proceedings;
- recruitment, retention, or the renewal or non-renewal of any contract;
- allocation of shifts, hours, duties, training or development opportunities;
- any other decision producing legal effects concerning an individual or
  similarly significantly affecting them.

**The prohibition applies equally to non-participation.** The customer shall not
treat any individual detrimentally, or advantageously, by reference to whether
they cast a ballot, how often they did so, whether they were ever nominated, or
whether they declined to take part.

This paragraph is not padding. Without it we would have prohibited punishing the
loser and permitted punishing the person who declined to vote, which is the more
likely abuse and the one this product is otherwise well designed to prevent — it
knows exactly who did not vote, and no interface will tell anybody.

## B3. Why this is here

Set out for the customer, because a covenant somebody understands is one they
are more likely to keep.

**It protects the customer's own lawful basis.** The customer will almost
certainly rely on Article 6(1)(f) legitimate interests. The limb that decides
this product is reasonable expectations, and nobody who nominates a colleague
for covering a shift expects it to surface in a redundancy matrix. Using the
service for the purposes in B2 defeats the balancing test, and the customer, not
us, is the one relying on it.

**And it is an Equality Act exposure.** A peer popularity vote correlates with
visibility, not performance. Part-time staff, people returning from family
leave, disabled employees, remote workers and night-shift workers all
systematically receive fewer nominations for reasons that have nothing to do
with contribution. Using that as a criterion for a detriment is a section 19
indirect discrimination claim with the statistical evidence built in. Redundancy
criteria have been required to be objective and verifiable since
*Williams v Compair Maxam* [1982] ICR 156.

## B4. Indemnity

The customer indemnifies us against all losses, liabilities, costs and expenses
arising from any breach of B2, including claims by its own employees or former
employees and any regulatory action.

## B5. Suspension

We may suspend the service immediately on becoming aware of a credible
allegation of breach of B2, and terminate if it is not remedied within 14 days.
We will not exercise this right unreasonably, but we will exercise it: continuing
to supply a tool being used to score people for redundancy would make us a
participant in the harm.

## B6. Transparency to participants

The customer shall tell participants, before or at the point they first take
part, that the programme is not used for the purposes in B2. A promise the
people affected never hear does not help the customer's balancing test.

---

# Part C — Questions for counsel

Where I know the drafting is thin. Listed so these are not found by accident.

1. **Article 15 and the source of the data.** A participant asks who nominated
   them. We refuse, relying on the rights-of-others limb and on
   **DPA 2018 Schedule 2 Part 3 paragraph 16**. Is that sound as a *standing*
   design position rather than a case-by-case assessment, given the exemption is
   framed around individual requests? An earlier ruling in this project read the
   same reasoning across to the Article 14(2)(f) source-disclosure duty, and I
   have flagged that read-across as contestable rather than settled.

2. **Retaining a winner's name after erasure.** `D-023` keeps the winner name
   and count after a participant erases their account, on the basis that the
   announcement is a historic fact about the organisation. `D-028` makes that
   the customer's decision rather than ours and gives them a redaction tool.
   Does the split hold, and is the default — retain — the right one? This is
   flagged as contestable in `docs/LEGAL_ANSWERS.md`.

3. **The residual ballot record.** After retention expires we keep "this person
   voted in this cycle" until the period in A8.3. `D-036` records a deliberate
   departure from advice that said the record should die with the cycle: taken
   literally that would delete the award history the product exists to create.
   Is the departure defensible, and is 24 months the right default?

4. **Article 9 and the free-text note.** Is
   DPA 2018 Schedule 1 Part 1 paragraph 1 the right condition for the customer,
   and does it need an appropriate policy document naming this processing? Is
   there anything more we should be doing given that we know the risk exists and
   have chosen to keep a free-text field at all?

5. **Works councils and consultation.** Nothing in this document addresses
   employee representative consultation before a programme launches. Should it,
   and does it change for customers with recognised unions?

6. **International transfers.** Unresolved pending the sub-processor support
   access audit in A7. Which mechanism, and does the answer change per
   sub-processor?

7. **Liability and the indemnity in B4.** Uncapped as drafted, which will not
   survive a first enterprise negotiation. Where should the cap sit, and should
   the B2 indemnity sit outside the general cap?

8. **Is a covenant the right instrument for B2 at all,** or should this be a
   condition of the licence, so that breach terminates the right to use the
   software rather than sounding only in damages?
