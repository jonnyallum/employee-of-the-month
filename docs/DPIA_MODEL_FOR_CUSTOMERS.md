# Model DPIA and legitimate interests assessment

**For customers of Employee of the Month** · Version 1.0 draft · 29 July 2026
**Status: draft for solicitor review. Not yet issued to anybody.**

## How to use this

You are the **controller**. We are the processor. That means the Article 35
assessment is yours and we cannot do it for you — your workforce, your reasons,
your risk appetite.

What we can do is fill in everything that is the same for every customer, and
mark clearly where you have to think. That is what this is.

- **Text in normal type** is ours. It describes how the product works and is
  accurate as at the version above. You may adopt it.
- **Text in bold marked `[YOUR ANSWER]`** cannot be answered by us and must not
  be left as it stands.

Two documents in one, because Part 2 is load-bearing for Part 1: if your
legitimate interests assessment fails, your DPIA has no lawful basis to assess.

Annex `docs/SCHEMA_THREAT_MODEL.md` (available under NDA) and our own DPIA to
whatever you produce.

**This is not legal advice.** It is a supplier being useful. Have your own
adviser check it.

---

# Part 1 — Model DPIA

## 1.1 Do you need one?

Almost certainly yes.

Article 35(3) is probably **not** squarely met on these facts: there is no
automated decision-making, and special category data is not processed on a large
scale. Saying so in your DPIA is a good thing — it shows you understood the
threshold rather than assuming it.

But the WP248 rev.01 criteria are met on at least four counts, and the ICO
treats two as indicating likely high risk:

- **Evaluation or scoring.** A peer nomination evaluates a colleague.
- **Data of a highly personal nature.** A recorded opinion by one named
  colleague about another, and possibly special category data in a free-text
  note.
- **Vulnerable data subjects.** WP248 names employees explicitly, because of the
  power imbalance in the employment relationship. This is the decisive one and
  it applies to every customer.
- **Preventing the exercise of a right.** The product will not tell a
  participant who nominated them.

Our own analysis is in `docs/DPIA.md` and you may rely on it as a starting
point.

## 1.2 Describe the processing

**Nature, scope, context and purposes.** Adopt from section 2 of our DPIA, then
add:

- **[YOUR ANSWER]** How many people will be on the roster, and are any of them
  agency workers, contractors or under 18?
- **[YOUR ANSWER]** Is participation genuinely voluntary, and how will you make
  that credible to somebody who reports to the person running the programme?
- **[YOUR ANSWER]** What are you actually trying to achieve — retention,
  morale, making frontline work visible? Write down the real reason. It is the
  thing your Article 6(1)(f) assessment stands or falls on.
- **[YOUR ANSWER]** Will you run it indefinitely or trial it? A time-limited
  trial with a review is easier to justify.

## 1.3 Necessity and proportionality

Section 3 of our DPIA sets out, field by field, why each item is needed and what
less intrusive option was considered and adopted. You may adopt that analysis.

What you must add:

- **[YOUR ANSWER]** Why a recognition scheme that records personal data at all,
  rather than an anonymous suggestion box or a manager simply saying thank you.
  This is the question a regulator asks first and it deserves a real answer.
- **[YOUR ANSWER]** Your retention selections and why. The product gives you two
  dials: how long the note and the nominator-to-nominee link are kept (3, 6, 12
  or 24 months, or indefinite; default 12), and how long the residual record
  that a named person voted is kept (12, 24, 36 or 60 months, or indefinite;
  default 24). **If you select indefinite for either, you must be able to
  justify it under Article 5(1)(e), and we cannot justify it for you.**
- **[YOUR ANSWER]** Who will be an administrator, and why those people. They can
  read every free-text note after a cycle closes.

## 1.4 Risks to individuals

Risks **R1 to R8** in section 4 of our DPIA apply to you, with the measures we
have built. Read them; do not adopt them without reading, because two of them
have residual risk that lands on you rather than on us.

Add these, which are yours alone:

| | Risk | Why it is yours |
|---|---|---|
| **C1** | An employee feels obliged to take part | Depends on your culture and on who is asking, not on our software |
| **C2** | The result is used, informally, in a decision about somebody | Contractually prohibited, but you control whether it happens |
| **C3** | A manager infers who did not vote and treats them differently | The product names non-voters to nobody. Social inference is beyond it |
| **C4** | Results correlate with visibility, disadvantaging part-time, remote, night-shift or returning staff | This is an Equality Act exposure. **[YOUR ANSWER]** How will you monitor it? |
| **C5** | The scheme becomes a popularity contest that demoralises the people it excludes | A real harm even where it is not a legal one |

**[YOUR ANSWER] for each: likelihood, severity, and what you will do about it.**

C4 deserves particular attention. If you never look at who wins, you will not
know whether your scheme systematically favours the visible. Consider reviewing
the pattern of winners annually against your workforce profile.

## 1.5 Consultation (Article 35(9))

**[YOUR ANSWER]** You must seek the views of data subjects or their
representatives, or record why not.

Our strong suggestion: actually do it here. A recognition scheme imposed on
people without asking is off to a poor start on its own terms, quite apart from
Article 35(9). If you recognise a union, consult it. If you have an employee
forum, use it.

**[YOUR ANSWER]** Record what you were told, including anything inconvenient,
and what you changed.

## 1.6 Sign-off

**[YOUR ANSWER]** Named individual, role, date, and a review date. An unsigned
DPIA is not a DPIA.

If your residual risk is still high after mitigation, you must consult the ICO
under Article 36 before you start. On our analysis it should not be, but that is
your assessment to make.

---

# Part 2 — Model legitimate interests assessment

You will almost certainly rely on **Article 6(1)(f)**. Consent does not work
here: an employer cannot ordinarily obtain freely given consent from an
employee, for exactly the power-imbalance reason that makes this high risk in
the first place. Contract does not work either, because a recognition scheme is
not necessary for performance of the employment contract.

So it is legitimate interests, and legitimate interests requires the three-part
test below, documented before you start.

**A separate Article 9 condition is needed** for any special category data that
arrives in a free-text note. Article 6(1)(f) does not cover it. The likely
condition is **DPA 2018 Schedule 1 Part 1 paragraph 1** (employment, social
security and social protection), which requires an **appropriate policy
document**. Ask your adviser whether yours covers this processing.

## 2.1 Purpose test — is there a legitimate interest?

**[YOUR ANSWER]** State the interest.

Ours would be: improving morale, retention and the visibility of good work,
particularly for frontline staff whose contribution is less visible than
desk-based colleagues'. That is a genuine commercial interest and also a benefit
to the people concerned, which helps.

- **[YOUR ANSWER]** Who benefits, and how much?
- **[YOUR ANSWER]** Would anything be lost if you did not do it? "It would be
  nice" is a weak answer. "Our frontline turnover is 40% and exit interviews
  cite feeling invisible" is a strong one.

## 2.2 Necessity test — is the processing necessary?

**[YOUR ANSWER]** Could you achieve the same result with less personal data?

Be honest here, because the honest answer is quite good: a scheme where people
nominate a colleague by name cannot work without recording who was nominated.
The question is really about the *surrounding* data, and the product has already
narrowed that for you — the nominator-to-nominee link is destroyed at retention,
per-nominee tallies are frozen so the underlying ballots can be deleted, and the
free-text note is optional behind a required category tag.

- **[YOUR ANSWER]** Have you selected the shortest retention you can live with?

## 2.3 Balancing test — do the individual's rights override?

This is the limb that decides it. Work through it properly.

**Reasonable expectations.** Somebody nominating a colleague for covering a
shift expects a thank you. They do not expect it in a redundancy matrix. This is
why the permitted-use covenant in Part B of the customer terms matters to *your*
lawful basis and not only to ours: **if you use the output for pay, promotion,
redundancy, performance management or discipline, this test fails and your
lawful basis fails with it.**

- **[YOUR ANSWER]** Will you tell people, before they first take part, what the
  scheme is and is not used for? (Clause B6 requires this. It is also the single
  cheapest thing you can do for this test.)

**Likely impact.**

- Positive for most participants.
- Negative for somebody identified as having voted a particular way in a small
  team. **[YOUR ANSWER]** How many eligible voters will you have? Below eight,
  the product warns both you and the voter, and you should read `R1` in our DPIA
  before proceeding.
- Negative for somebody whose health or personal circumstances end up in a note
  written by a well-meaning colleague.

**Power imbalance.** Acknowledge it rather than assert it away. Your employees
are, in WP248 terms, vulnerable data subjects. **[YOUR ANSWER]** What makes
opting out genuinely safe for somebody who reports to the person running the
scheme?

**Safeguards you can point to.** All of these are built in and none requires you
to configure anything:

- No interface discloses who nominated whom.
- No live standings while a cycle is open.
- Warnings to both administrator and voter where the team is small enough for a
  ballot to be deducible, and the voter is told they need not vote.
- A required behaviour tag so the free-text note is optional.
- A warning above the note field, not below it.
- Moderator hide and redact, working after a result is announced.
- Self-service export and erasure for every participant.
- Automatic destruction of the nominator-to-nominee link at your chosen
  retention.

**Safeguards you must add:**

- **[YOUR ANSWER]** Transparency: how and when you tell people.
- **[YOUR ANSWER]** Opt-out: how somebody declines without it being noticed.
- **[YOUR ANSWER]** Objection: how you handle an Article 21 objection, and who
  decides.
- **[YOUR ANSWER]** Equality monitoring: see C4 above.

## 2.4 Outcome

**[YOUR ANSWER]** Does the legitimate interest apply? Record the conclusion, the
date, and who reached it.

If the answer is yes only on the assumption that you never use the results for
employment decisions, **write that assumption down**. It is the condition your
lawful basis depends on, and the person who inherits your job needs to know it
was a condition and not a preference.

---

## Change log

| Version | Date | Change |
|---|---|---|
| 1.0 draft | 29 July 2026 | First draft. Not reviewed by a solicitor. |
