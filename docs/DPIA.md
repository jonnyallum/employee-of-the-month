# Data protection impact assessment

**Employee of the Month** · Version 1.0 draft · 29 July 2026
**Status: draft for solicitor review. Not signed off.**

## About this document

`D-033` said the threat model was not a DPIA and that assuming otherwise would
be a mistake. It supplies perhaps 40% of one. `docs/SCHEMA_THREAT_MODEL.md`
assesses risks to the **system**; this assesses risks to **individuals**, which
is a different exercise with different content: necessity and proportionality,
harms rather than control failures, consultation under Article 35(9), and a
named person signing it.

It is annexed to this document rather than submitted as it.

### Do we actually have to do this?

**No, and we have done it anyway.** We are the processor. Article 35 places the
DPIA duty on the controller, which is the employer. Saying so plainly is more
useful than implying an obligation that does not exist.

We have done it because the design decisions in `docs/DECISIONS.md` were taken
on risk grounds and ought to be written up as such; because every enterprise
data protection officer will ask for one and "we are only the processor" is a
poor answer to a buyer; and because Article 28(3)(f) requires us to assist the
customer with its own Article 35 obligations, which is easier to do from a
completed assessment than from memory.

The **model DPIA the customer completes** is a separate document:
`docs/DPIA_MODEL_FOR_CUSTOMERS.md`. This one is ours.

---

## 1. Screening: is this high risk?

### 1.1 Article 35(3) is not squarely met

Stating this rather than glossing over it, because it shows the threshold was
understood rather than assumed.

| Article 35(3) limb | Met? |
|---|---|
| **(a)** Systematic and extensive evaluation based on automated processing, including profiling, on which decisions producing legal effects or similarly significantly affecting the person are based | **No.** There is no automated decision-making. A human administrator reveals the result, and `D-007` and Part B of the customer terms forbid using the output for any decision that would produce such effects. |
| **(b)** Processing on a **large scale** of special category or criminal offence data | **No.** Special category data may appear incidentally in a free-text note; it is not sought, not required, and not processed on a large scale on any reading of Recital 91. |
| **(c)** Systematic monitoring of a publicly accessible area on a large scale | **No.** |

### 1.2 But WP248 puts us over, on four criteria

The ICO treats two or more of the WP248 rev.01 criteria as indicating likely
high risk. We meet four.

| Criterion | Assessment |
|---|---|
| **1. Evaluation or scoring** | **Conceded.** A peer nomination is an evaluation of a colleague, and the tally is a score. It would be possible to argue that a celebration is not an evaluation. Arguing it reads as defensive and costs nothing to give up. |
| **4. Sensitive data or data of a highly personal nature** | **Yes**, on both halves. Special category data may appear in the free-text note. Separately, and regardless of Article 9, a recorded opinion by one named colleague about another is data of a highly personal nature in its own right. |
| **7. Vulnerable data subjects** | **Yes, and this is the decisive one.** WP248 names employees explicitly, because of the imbalance of power in the employment relationship. Everyone in scope is an employee of the customer. |
| **9. Preventing data subjects from exercising a right** | **Yes, by design.** We will not tell a participant who nominated them. That is the promise the product exists to keep, and it is also a constraint on their Article 15 rights. Recording it here rather than only in the terms. |

Criterion 3 (systematic monitoring) is arguable: the system necessarily records
who voted, and turnout is reported to administrators. It is not counted above
because the monitoring is of participation in a voluntary scheme rather than of
work, and no interface discloses who did or did not take part. Counsel may
disagree; it does not change the conclusion.

**Conclusion: high risk, and a DPIA is warranted.**

---

## 2. The processing

### 2.1 What happens

An employer places its people on a roster. Each month it opens a cycle. Any
eligible employee may nominate one colleague, choosing from a fixed vocabulary
of five behaviour tags and optionally adding a note of up to 250 characters.
Nominations close. An administrator reviews the notes, may hide or redact any of
them, and reveals a winner. The winner's name and count are recorded against the
month.

### 2.2 Data, subjects and recipients

Set out in Part A sections A3 and A4 of `docs/DPA_AND_CONTRACT_TERMS.md`, and
not repeated here.

**Recipients** are the customer's own administrators, and our sub-processors
(Supabase, Resend, Expo/Firebase). No third party receives participant data.
There is no advertising, no analytics tied to a participant, no data sale, and
no model training on customer content.

### 2.3 Where we are the controller

A short list, all of it low risk and none of it about participants:

- Account and contact records for the individuals who administer a customer.
- Billing records.
- Security and availability logs.
- Aggregate product telemetry not linked to a participant.

This processing does not on its own meet any Article 35 threshold. It is
recorded for completeness.

---

## 3. Necessity and proportionality

The question is not whether recognition is nice. It is whether each piece of
personal data is necessary for the stated purpose, and whether a less intrusive
route was available. `docs/DECISIONS.md` is the working record of that being
asked repeatedly during the build.

| Data | Necessary because | Less intrusive option considered |
|---|---|---|
| Name and email | A person must be identifiable to be nominated and to sign in | None: the product cannot function anonymously |
| **That a named person voted** | The one-vote-per-person guarantee depends on it, and a voter must be able to withdraw and recast | None found. This is retained after the rest is purged, for this reason alone |
| **Nominator-to-nominee link** | Needed while a cycle is live, to support recast and to block a second ballot | **Yes, and adopted.** `D-027`: severed at retention, because after reveal nothing needs it. What survived otherwise was a permanent map of who thought what about whom |
| Free-text note | Not necessary. Retained because a bare tag is a poor way to thank somebody | **Yes, and adopted.** `D-032` made the note optional behind a required tag, reducing how often anything is written at all |
| Winner name and count | The purpose of the exercise is a public thank you | Retained after erasure; `D-028` gives the controller a redaction tool |
| Per-nominee tallies | An administrator needs to see the month was not decided by two votes | Snapshotted at reveal so the underlying ballots can be destroyed (`D-027`) |
| Turnout | Tells an administrator whether the programme is working | Counts only. There is deliberately no interface that names a non-voter |

**Proportionality of the retention design.** Two dials, not one. The note and
the nominee link go at the customer's chosen retention (default 12 months). The
residual "this person voted" record goes at a second, longer period (default 24
months, `D-036`). Splitting them means the more sensitive data has the shorter
life, which is the right way round and was not true of the original design.

**Function creep is contractually foreclosed**, not merely discouraged: Part B
of the customer terms prohibits use for pay, promotion, redundancy, performance
management, discipline and shift allocation, and prohibits it equally in respect
of non-participation.

---

## 4. Risks to individuals

Harms to people, not control failures. Likelihood and severity are judged
before mitigation; residual risk is judged after.

### R1 — A voter is identified in a small team

**Harm:** A colleague works out who nominated whom, or who did not nominate
them. In a workplace this is a relationship harm and can be a retaliation harm.

**Why it is real:** Arithmetic, not a control failure. With two eligible voters
an administrator who voted can subtract their own ballot and the other person's
choice follows with certainty. Between three and seven it is often recoverable.
No amount of access control fixes this.

**Inherent risk: high.**

**Measures:** `D-022` warns the administrator before a cycle opens below eight
eligible voters. `D-035` warns the **voter**, before they vote, and tells them
they do not have to. The warning states a level, never a headcount, so it cannot
itself leak roster eligibility. No interface returns a precise nomination
timestamp, which in a small team identifies a voter as effectively as a name.

**Residual: medium.** It cannot be engineered away. It can only be disclosed
honestly to the person deciding whether to take part, which is what `D-035`
does.

### R2 — Special category data ends up in a free-text note

**Harm:** A person's health, religion, sexual orientation or family
circumstances become visible to an administrator, and enter the employer's
records, because a well-meaning colleague mentioned it in a thank you.

**Inherent risk: high.**

**Measures, in order of how much they actually help:**

1. `D-032`, the only one that reduces how often it happens: a required tag means
   most people no longer need to write anything.
2. The note is capped at 250 characters. A paragraph is where disclosures live.
3. `D-031` moved the warning above the field. It used to sit in the character
   counter, which people read after they have finished typing.
4. `D-030` gives moderators hide **and redact**, and both work after a result is
   announced, because that is exactly when somebody notices.
5. `D-027` removes the text at retention.

**Residual: medium.** A free-text field that people can type into will
occasionally receive things nobody wanted. The customer needs an Article 9
condition on the assumption that it will.

### R3 — Results are used for pay, promotion or redundancy

**Harm:** Economic detriment on a basis that correlates with visibility rather
than contribution. Part-time staff, people returning from family leave, disabled
employees, remote and night-shift workers all systematically receive fewer
nominations. Section 19 Equality Act 2010 indirect discrimination, with the
statistics built in.

**Inherent risk: high.**

**Measures:** `D-007` states it as a product position. Part B of the customer
terms makes it a covenant with an indemnity and a suspension right, and requires
the customer to tell participants. The product provides no export shaped for
performance review and no per-person history across cycles.

**Residual: medium.** We cannot see inside the customer's HR process. This is a
contractual and transparency control, not a technical one, and it should not be
presented as though it were technical.

### R4 — Somebody is penalised for not taking part

**Harm:** The quieter version of R3, and more likely. The system knows exactly
who did not vote.

**Measures:** No interface names a non-voter, to anybody, ever. Turnout is
counts only. Part B prohibits detriment by reference to non-participation as an
equal limb rather than an afterthought.

**Residual: low**, on the product side. The remaining exposure is a manager
inferring participation socially, which no software controls.

### R5 — A person's name survives their erasure request

**Harm:** Somebody asks to be erased and finds their name still recorded.

**Inherent risk: medium.**

**Measures:** `D-037`, found while building the deletion worker rather than by
review: the tally snapshot named every participant of every revealed month, so
an erased person's name would have survived in the standings of every month they
were on the roster. It is now replaced with "A former colleague" while the count
stays, so a past month still adds up.

The **winner** name deliberately survives (`D-023`), because the announcement is
a historic fact about the organisation. `D-028` makes that the customer's
decision rather than ours and gives them a redaction tool with three modes.

**Residual: low**, but see Part C question 2 of the customer terms: whether
retention of a winner's name after erasure is defensible at all is flagged as
contestable and is a question for counsel, not a settled position.

### R6 — Ballot confidentiality is broken by compulsion or compromise

**Harm:** Who voted for whom is disclosed under a court order, or by somebody
who compromises our trusted role.

**Measures:** `D-027` is the substantive answer: after retention the link does
not exist to be disclosed. Before that it does. `D-003` requires the word
"confidential" rather than "anonymous", and `D-031` corrected copy that had said
"nobody" could see a nomination to say "nobody in your organisation", with our
own technical access and the court-order case stated.

**Residual: medium before retention, low after.** We hold a technical ability to
read this data and say so rather than implying otherwise.

### R7 — Participation is not really voluntary

**Harm:** An employee feels obliged to take part because their employer is
watching, which is the WP248 vulnerability made concrete.

**Measures:** `D-035`'s warning ends by telling the voter they do not have to
vote, because a warning that leaves somebody no action to take is decoration.
Part B, B6 requires the customer to tell participants the programme is not used
for the purposes in B2.

**Residual: medium.** The power imbalance is inherent to the employment
relationship and is not ours to fix. It is the reason this is a high-risk
processing operation.

### R8 — Breach exposing opinions about colleagues

**Harm:** Disclosure of who thought what about whom across an organisation.

**Measures:** Set out in A6 of the customer terms. The ones that bear on this
specific harm rather than on security generally: the ballot table has no client
grant of any kind, the exposure surface is pinned by an automated test that
fails if a column is added to it, and no administrator-facing function returns
anything that names a nominator — asserted by name in the test suite rather than
left to code review.

**Residual: low to medium.**

---

## 5. Consultation

**Article 35(9): we have not sought the views of data subjects.**

Recording the reason rather than leaving the section blank, because a blank
section reads as an oversight and this was a decision.

There are no customers and therefore no participants to consult. Consulting
people who do not use the product would produce views about a hypothetical.

**Committed:** we will seek participants' views at the first pilot deployment,
before general availability, and specifically on R1 (whether the small-team
warning is understood and acted on) and R7 (whether participation felt
voluntary). This assessment will be updated with what they say, including if
they say something inconvenient.

**Not consulted and arguably should be:** employee representatives and
recognised unions. Part C question 5 of the customer terms raises this.

**No prior consultation with the ICO under Article 36** is proposed, because
residual risk is not assessed as remaining high after mitigation. If counsel
disagrees with any "medium" residual above, that conclusion changes.

---

## 6. Data protection officer

**Not appointed.** Article 37(1) is not met: we are not a public authority, our
core activities do not consist of regular and systematic monitoring on a large
scale, and they do not consist of large-scale processing of special category
data. "Core activities" is the operative phrase — recognition is the core
activity, and special category data is an incidental and unwanted by-product of
it.

This will be reviewed if the customer base grows materially. Given a product
whose data subjects are, by definition, vulnerable, a voluntary appointment may
become the right answer before it becomes the required one.

---

## 7. Outcome

| | |
|---|---|
| **Risk after measures** | Medium |
| **Article 36 prior consultation required** | No |
| **Proceed** | Yes, subject to the open items below |

**Open items that must close before the first customer:**

1. Solicitor review of this document and of
   `docs/DPA_AND_CONTRACT_TERMS.md`, including the eight questions in Part C.
2. Production project created in London (`D-034`).
3. Sub-processor support-access audit, which decides both the transfer mechanism
   and whether any residency claim can be made at all.
4. ~~The retention purge and the deletion worker are written and tested but
   nothing schedules them.~~ **Closed 29 July 2026.** Both run daily under
   pg_cron, at 03:00 and 03:30 UTC. What remains is operational rather than
   design: somebody has to look at `private.retention_job_health`, because a job
   that silently stopped running is the failure mode that matters when the
   privacy notice keeps making the promise either way.

**Annexes:** `docs/SCHEMA_THREAT_MODEL.md`, `docs/DECISIONS.md`,
`docs/DPA_AND_CONTRACT_TERMS.md`.

---

## 8. Sign-off

| | |
|---|---|
| Assessment prepared by | Claude (drafted), for Jonny Allum |
| Reviewed by | *Solicitor review pending* |
| Approved by | *Not signed off* |
| Date | — |
| Review due | On the earlier of: first customer, or 12 months |

This document is unsigned on purpose. `D-033` said a DPIA needs named sign-off,
and signing it before a solicitor has read it would defeat the point of writing
it.
