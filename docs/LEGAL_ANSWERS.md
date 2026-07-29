# Legal determinations

Version: 0.2 — determinations, superseding the 0.1 analysis
Date: 28 July 2026
Answers: `docs/LEGAL_QUESTIONS_SIMPLE.md`, questions 1–8
Law stated as at 28 July 2026: UK GDPR and the Data Protection Act 2018, as
amended by the Data (Use and Access) Act 2025 (most provisions commenced
5 February 2026; section 164A complaints duty commences 19 June 2026).

---

## Status of this document

**I am not a solicitor and this is not legal advice.** You have asked for
answers rather than options, and for the product decisions to be made rather
than listed. That is what this is. Every determination below states the
authority it rests on, so a solicitor can check the reasoning rather than
rebuild it, and so you can see exactly which sentence to challenge if they
disagree.

Two of these are genuinely contestable and I have marked them **CONTESTABLE**
with the counter-argument set out. The other six I would be comfortable
building on now and defending later.

Product decisions arising are recorded as `D-026` to `D-033` in
`docs/DECISIONS.md`, in the same form as every other decision in this project,
so they can be argued with rather than buried here.

### The determinations

| # | Question | Determination | Confidence |
|---|---|---|---|
| 1 | Processor or controller? | **Processor.** Fix by contract, not architecture | High |
| 2 | Keep who voted after purge? | **Yes for the fact, no for the link.** Sever it | High |
| 3 | Winner survives erasure? | **Yes, but only as the customer's decision** | **CONTESTABLE** |
| 4 | Ban use in pay and promotion? | **Yes.** Covenant, indemnity, suspension right | High |
| 5 | Free text and health data | **Not adequate today.** Three changes required | High |
| 6 | DPIA needed? | **Yes.** Two of them. Threat model is an annex | High |
| 7 | UK or Ireland? | **Ireland is lawful. Build in London anyway** | High |
| 8 | Is the wording honest? | **No, in two sentences.** Both fixed below | **CONTESTABLE** on Art 14 |

---

## 1. Are we the processor, or are we secretly a controller?

### Determination

**You are a processor for the recognition programme, and a controller for
accounts, authentication, security logging and billing. The split in section 1
of `LEGAL_AND_PRIVACY.md` is correct and you should proceed on it.**

### Authority

The operative provision is **Article 4(7) UK GDPR**: a controller is the person
who "determines the purposes and means" of processing. The trap is **Article
28(10)**, which converts a processor into a controller "in respect of that
processing" if it infringes the Regulation by determining purposes and means —
so getting this wrong is self-executing, not something a regulator has to
argue for.

The distinction that decides your case is in the **EDPB Guidelines 07/2020 on
the concepts of controller and processor** (adopted 7 July 2021), which split
"means" into two:

- **essential means** — the type of personal data processed, the duration of
  storage, the categories of recipient, the categories of data subject. These
  are reserved to the controller;
- **non-essential means** — the practical and technical how. These may be
  determined by the processor.

Apply that to your three constraints honestly, because two of them are not the
easy case your document assumes.

**"No ranking exists while a cycle is open."** Non-essential. This is sequencing
inside your own software and affects no category of data, recipient or subject.
Not arguable against you.

**"Retention is limited to 3, 6, 12, 24 or indefinite."** Duration of storage is
named in the guidelines as an *essential* means. But you do not determine it —
you offer a menu and the customer selects from it. Constraining an option set is
what every SaaS product does; the controller still makes the choice and the
choice is the instruction. Defensible, and the product should not change. What
must change is how you *describe* it: you offer retention options, the customer
selects, and the selection is a documented instruction under **Article
28(3)(a)**.

**"Administrators can never see who voted."** This is the one that is actually
arguable, because categories of recipient is also an essential means and you are
removing one. Your answer is not that it is a technical detail — it plainly is
not — but that it is a **defining characteristic of the product being
purchased**. A customer buying a confidential ballot is buying the
confidentiality. A shredder manufacturer does not become a controller because
the shredder will not un-shred. The EDPB guidelines expressly contemplate that a
processor may offer a standardised service on a take-it-or-leave-it basis
provided the controller decides, knowingly, to use it.

### What makes it hold

Not a better argument — a clause. Add to the DPA:

> **Pre-set characteristics.** The Service is provided with the characteristics
> described in Schedule [X]. The Customer confirms that it has reviewed those
> characteristics and, having assessed them against its own requirements as
> Controller, instructs the Supplier to process personal data on that basis. The
> Customer acknowledges that the Supplier does not offer a configuration in
> which ballot confidentiality is disabled, and that the Customer's selection of
> a retention period from those offered constitutes its documented instruction
> as to the period of storage.

Schedule X lists all three constraints in plain words. This converts "the
supplier imposed it" into "the controller chose it, from what was offered,
knowingly", which is the whole game.

### If this is wrong

The downside is smaller than it feels. Joint controllership for the recognition
programme would require you to have your own lawful basis, your own Article 13
notice and your own accountability records for it — all of which you have
substantially drafted. It would cost a fortnight and some embarrassment. It is
not existential. Do not over-engineer against it.

**Product decision:** `D-026`. No code change. DPA clause required before the
first customer.

---

## 2. We keep a record of who voted. Is that all right?

### Determination

**Keeping the fact that a person voted: lawful and necessary, keep it. Keeping
the link between that person and the colleague they chose, after the reason text
has been purged: not defensible on the current design. Sever it at purge.**

### Authority

Two principles, and note that neither is about confidentiality — this is a data
minimisation problem, not a security one.

**Article 5(1)(c), data minimisation.** Personal data must be limited to what is
necessary in relation to the purposes. Necessity is judged against whether a
less intrusive means was available that would achieve the same purpose.

**Article 5(1)(e), storage limitation.** Data must be kept in identifiable form
no longer than is necessary for the purposes.

The fact of a ballot passes both easily. Without it there is no way to enforce
one vote per person, and one vote per person is the integrity of the whole
scheme. There is no less intrusive alternative in a system where the voter can
withdraw and re-cast, because you must be able to find their existing ballot.

The nominator-to-nominee link fails the necessity test **after reveal**. Ask what
the stated purpose — "a historic result must still add up" — actually requires:

- the winner's name and count: already stored separately on
  `recognition_cycles`, deliberately as a snapshot with no foreign key;
- turnout: a count;
- per-nominee tallies for `get_closed_standings`: an aggregate.

None of those require knowing that a particular person chose a particular
colleague in March 2025. That link is needed while the cycle is live, to support
withdraw and re-cast and to block a second ballot, and it stops being needed the
moment the cycle is revealed and the text is purged. A less intrusive means
exists, therefore Article 5(1)(c) is not satisfied by the current design.

### There is a second reason, and it is the better one

Right now, `purge_expired_nominations` clears `reason` and leaves the row. What
survives is a complete, permanent, queryable map of who thought what about whom,
stripped of the words but not of the meaning. That is precisely the artefact the
product exists to promise does not exist in usable form — and it is the artefact
that would be produced on a court order, or read by anyone who compromised the
trusted role.

`D-024` already accepts that a disputed individual ballot cannot be investigated
after the fact, on the basis that "an audit trail that can reconstruct who voted
for whom is the exact disclosure the product exists to prevent". The purge
behaviour contradicts that decision. Fixing it is not a legal concession; it is
making the code agree with a decision you already made.

### The design

At reveal, `reveal_winner` writes a per-nominee tally snapshot to the cycle
alongside the winner columns, in the same transaction that already sets
`status = 'revealed'`.

At purge, `purge_expired_nominations` clears `reason` **and** severs
`nominee_participant_id`, stamping `purged_at`. The nominee column becomes
nullable with a check constraint tying it to `purged_at`, so a live row can
never lose its nominee and a purged row can never keep one:

```sql
constraint recognition_nominations_purge_coherent
  check ((purged_at is null) = (nominee_participant_id is not null))
```

The one-vote guard is unaffected: it is
`unique (organisation_id, cycle_id, nominator_user_id)` and does not involve the
nominee. A re-cast into a revealed cycle remains impossible for the same reason
it is impossible today.

Give the residual row an end date. "Retained indefinitely" is a hard phrase to
defend in any context, and the row should die with the cycle.

**Product decision:** `D-027`. Schema and function change. Deferred to a card
rather than written blind — it alters a `NOT NULL` constraint and two tested
functions, and the pgTAP suite cannot run in this environment. It should not be
merged without `supabase db reset && supabase test db` passing.

---

## 3. If somebody deletes their account, we still say they won

### Determination — **CONTESTABLE**

**Retaining the winner name and count after erasure is defensible. Deciding
unilaterally to retain it is not. The retention must be the customer's decision,
disclosed before participation, and reversible by the customer on request.**

You asked the wrong question. "Can we keep that after erasure?" is not your call
— you are the processor and the employer is the controller. What you must get
right is that the product lets the controller carry out either decision, and
that nobody is surprised.

### Authority

The route a person takes is **Article 17(1)(c)**: erasure where the data subject
objects under **Article 21(1)** and there are no overriding legitimate grounds.
Article 21(1) then sets the test — the controller may continue only if it
demonstrates **"compelling legitimate grounds for the processing which override
the interests, rights and freedoms of the data subject"**.

Three things follow that matter to your design.

**"Compelling" is a raised bar.** It is deliberately higher than the ordinary
Article 6(1)(f) balancing test the employer already passed when the person
participated. Winning the first test does not win the second.

**The burden is on the controller.** Article 21(1) says the controller must
*demonstrate* the grounds. Silence loses. This is why the position has to be
written down in advance rather than improvised when the request arrives.

**None of the Article 17(3) exemptions apply.** Freedom of expression, legal
obligation, public health, archiving in the public interest, legal claims — a
workplace recognition scheme is none of them. Do not try to use 17(3)(d)
(archiving in the public interest or historical research); it is for genuine
public-interest archives and the argument would not survive contact with a
regulator.

### What supports retention

- The award was **announced at the time**. It is already in circulation in
  emails, meetings and on walls. Data protection law does not generally require
  the rewriting of accurate historical records, and erasing the row does not
  un-announce it.
- The retained data is **minimal**: a display name and an integer. No opinion,
  no free text. `D-023` is doing real work here and you should say so explicitly
  in the LIA.
- The record is **positive and non-detrimental**. Not decisive, but the harm
  calculus is genuinely different from a retained disciplinary record, and
  proportionality is part of the Article 21 balance.

### What undermines it

- The person has left. An employer's interest in retaining a former employee's
  name in a voluntary morale scheme is *convenient*, not obviously *compelling*.
- "It is part of the company's history" is a sentiment. It is not a legal
  ground and it should not appear in the contract in that form.
- Do not argue that "Sarah, 4 nominations" is anonymised once the account is
  gone. **Recital 26** makes identifiability the test, by any means reasonably
  likely to be used, by the controller *or another person*. Her former
  colleagues identify her instantly. Putting that argument in writing anywhere
  would be actively harmful to you.

### Why it is contestable

An employee could plausibly persuade the ICO that a former employer has no
compelling ground to keep her name in a recognition system she has asked to be
erased from. I think the disclosure-in-advance and the minimality of the data
win it, but I would not tell you that outcome is certain, and the honest answer
is that this is the one to put in front of a solicitor first.

What makes it survivable is not the strength of the argument. It is that the
employer, not you, makes the call, and that the person was told before they took
part.

### The design

1. **An administrator can redact a winner record** without deleting the cycle.
   A function, callable from the admin screen, with a recorded reason, like
   moderation. Not a support ticket to you.
2. **Three outcomes, not two.** Keep the name / replace it with initials /
   replace it with "a former colleague". The middle option is usually what
   actually satisfies the person and it keeps the record coherent. The nomination
   count and the fact the cycle had a winner survive in every case.
3. **Told twice.** Before participating, in the notice; and again inside the
   account deletion flow, at the moment of the decision, routing them to the
   employer rather than to you.
4. **In the DPA:** you action erasure or redaction of a winner record on
   documented instruction from the customer within a stated period, and in the
   absence of instruction the record is retained.

Do all four and the position becomes: retained by default, disclosed in advance,
overridable by the controller on request. That is defensible. The current
position — retained by you, with no visible way to undo it — is the one that
gets challenged, and your document is right that it will be.

**Product decision:** `D-028`. Implemented: `redact_winner_snapshot`. Deletion
flow copy also changed.

---

## 4. Should we ban using this for pay and promotions?

### Determination

**Yes. In the body of the terms, as a covenant, with an indemnity and a
suspension right. Not as a disclaimer.**

This is the least contestable answer in the document, and there are two
independent reasons. Your paperwork has the first and undersells the second.

### It is load-bearing for the lawful basis

The customer's basis is **Article 6(1)(f)**, legitimate interests, which
requires the three-part test the ICO sets out: purpose, necessity, and balance.
The limb that decides this product is **reasonable expectations**, which
**Recital 47** makes central — the interests of the controller may be overridden
where "the data subject does not reasonably expect further processing".

An employee nominating a colleague for a bit of recognition does not reasonably
expect that vote to appear in a redundancy scoring matrix. If it can, the
balance tips and the lawful basis fails — not just for the winner, but for
everyone whose data is in the system. The prohibition is not bolted onto the
LIA; it is a component of it. State it in exactly those terms in the model LIA
you give customers.

### It is an employment law landmine, and that is the larger exposure

A peer popularity vote measures visibility, not performance. The people who
systematically lose it are:

- part-time workers and those returning from family leave — fewer colleagues,
  less contact;
- disabled employees, and anyone with health-related absence;
- remote, night shift, field and warehouse staff, against office staff;
- new starters, agency workers, and anyone in a small or unglamorous team.

Every one of those maps onto a protected characteristic or a protected
employment status. Use that vote in a promotion or redundancy decision and you
have a textbook **section 19 Equality Act 2010** indirect discrimination claim:
a provision, criterion or practice applied to everyone, putting a protected
group at a particular disadvantage, which the employer must then justify as a
proportionate means of achieving a legitimate aim. Justifying a popularity
contest as a proportionate means of selecting for redundancy is not a case
anybody wants to run.

Alongside it: **section 98(4) Employment Rights Act 1996** on the fairness of
dismissal, and the long-standing requirement from ***Williams v Compair Maxam***
[1982] ICR 156 (EAT) that redundancy selection criteria be objective and
capable of independent verification. A peer vote is neither. Add the
**Part-time Workers (Prevention of Less Favourable Treatment) Regulations 2000**
for the part-time cohort specifically.

That risk sits with the customer. Yours is being named in disclosure, described
in a tribunal judgment, and having to explain it to every prospect afterwards.

### Drafting

Keep the blunt sentence in section 8 of `LEGAL_AND_PRIVACY.md`. Move it out of a
disclaimer and into a covenant with teeth:

> **Permitted use.** The Customer shall not, and shall not permit any of its
> personnel to, use Results, nomination counts, or participation or
> non-participation in the Service as an input to, or as evidence in, any
> performance appraisal, pay, bonus, promotion, demotion, redundancy selection,
> disciplinary or capability process, and shall not require any individual to
> participate. The Customer shall instruct its personnel accordingly and is
> responsible for their compliance.
>
> **Indemnity.** The Customer shall indemnify the Supplier against all losses
> arising from any claim by an employee or worker of the Customer to the extent
> caused by a breach of the clause above.
>
> **Suspension.** The Supplier may suspend the Service where it becomes aware
> of a breach of the clause above.

Three notes. The covenant must catch **non-participation** as well as results,
or you have banned punishing the loser and permitted punishing the person who
declined to vote — which is the more likely abuse and the one your product is
otherwise excellent at preventing. The indemnity is what makes the customer's
legal team read the clause. The suspension right is what stops a regulator
asking why you kept invoicing a customer you knew was misusing it.

And know the limit: a contractual ban protects you if you prohibit, disclose and
act on what you find. It does not protect you if you know and carry on. Build
the third one into account management, not just the contract.

**Product decision:** `D-029`. Contract only. No code change.

---

## 5. People will type things they should not

### Determination

**Not adequate today. There is a defect in the control you are relying on most,
and the frame in your document is wrong.**

### The defect

`moderate_nomination` does not delete anything. Hiding sets `status = 'hidden'`
and records a moderation reason; the text stays in the row. Worse, the function
**refuses any moderation after reveal** — so once a cycle is revealed, unlawful
content cannot be removed through the product at all.

That matters more than it looks. Hiding is a display control. The problem is not
display, it is **storage**: processing began when the text was written, and a
hidden row is still processing. "We stopped showing it" is not an answer to a
regulator, and "we could not remove it because the cycle was revealed" is worse.

### Why "mitigate it" is the wrong frame

**Article 9(1)** prohibits the processing of special category data outright
unless a condition in **Article 9(2)** applies, and for UK purposes many of
those also require a **DPA 2018 Schedule 1** condition. Work through what is
available to an employer when a colleague volunteers health information about a
third party:

- **9(2)(a) explicit consent** — from the *nominee*, who did not write it, does
  not know it exists and was never asked. Dead on arrival.
- **9(2)(b) employment and social security obligations** — requires processing
  necessary for obligations under employment law, plus a Schedule 1 Part 1
  condition. A voluntary morale scheme is not an employment law obligation.
- **9(2)(e) manifestly made public by the data subject** — the colleague made it
  public, not the data subject. Fails on its face.
- **9(2)(f) legal claims**, **9(2)(c) vital interests**, **9(2)(g) substantial
  public interest** — none apply.

There is no condition. If Article 9 data lands in that box, the processing is
unlawful and **cannot be made lawful retrospectively**. The objective is
therefore prevent, then remove fast. Not mitigate and monitor.

That sounds alarming; it is also ordinary. Every free-text field in every HR
system has this problem. A regulator's interest is not whether it ever happens.
It is whether you designed to reduce it, and whether you had a working route to
get rid of it when it did. You have the first and not the second.

### Assessment of what exists

| Control | Assessment |
|---|---|
| Warning by the field | Good instinct, wrong position — it is **below** the box, in the character counter, not above it as `LEGAL_AND_PRIVACY.md` claims. People have finished typing by then. |
| Deferred admin access until close (`D-014`) | Reduces browsing. Does not reduce storage. Does not answer Article 9. |
| Moderation with recorded reason | Non-destructive, and blocked after reveal. Does not answer Article 9. |
| No column for health, salary, absence | Strong. Keep it and cite it in the DPIA as designed-in minimisation. |

### Required changes

1. **A destructive `redact` action.** Clears `reason` permanently, keeps the
   row and the audit trail of who removed it and why, and — critically —
   **works after reveal**, because unlawful content does not become lawful when
   a cycle closes.
2. **The moderation reason field must not become the new home for the content
   the administrator just removed.** Warn on that input in the admin UI.
3. **Move the warning above the field.** Before typing, not after.
4. **A route for the nominee.** The person the text is *about* currently cannot
   see it or ask for its removal except by subject access request, by which time
   their manager has read it. At minimum, state the route in the notice; a
   product control is better.
5. **A customer obligation** in the terms to instruct staff not to include
   health, disciplinary or other sensitive information, and to moderate promptly
   when notified. This puts the Article 9 exposure where the controller sits.
6. **Name it in the DPIA** as an accepted residual risk with an owner and a
   review date. Regulators are markedly more forgiving of a risk you identified
   than one they identified for you.

### On the 500-character box

Not a legal requirement, but the highest-value change available: structured tags
("went above and beyond", "helped a colleague", "fixed something nobody
noticed") with a short optional free text. People write essays in essay boxes.
Recorded as a decision but not blocking.

**Verdict on the question as asked:** the current mitigations are proportionate
for a closed beta **once redaction exists and the warning moves**. Items 4 and 5
before general availability.

**Product decisions:** `D-030` (redact action — implemented), `D-031` (warning
placement — implemented), `D-032` (structured tags — accepted, not scheduled).

---

## 6. Do we need a DPIA?

### Determination

**Yes. Two of them. And the threat model is an annex to a DPIA, not a DPIA.**

### Authority

**Article 35(3)** lists the three cases where a DPIA is mandatory, and you meet
none of them squarely: no systematic and extensive automated evaluation
producing legal or similarly significant effects; no large-scale processing of
Article 9 data by design; no systematic monitoring of a publicly accessible
area. So it is not automatically triggered on the face of the Regulation. Say so
in the DPIA — showing you understood the threshold and did one anyway is worth
something.

It is triggered on the screening criteria. **Article 29 Working Party guidance
WP248 rev.01**, endorsed by the EDPB and retained in UK guidance, lists nine
factors and treats two or more as indicating a DPIA. You meet at least three:

- **Vulnerable data subjects.** Employees are named explicitly in WP248, on the
  basis of the imbalance of power in the employment relationship. This factor
  alone would persuade most reviewers.
- **Data of a highly personal nature.** Colleagues' opinions about named
  individuals, with a foreseeable risk of Article 9 content in free text.
- **Evaluation or scoring.** Arguable, as your document says. A vote count is
  produced. **Concede this one.** Conceding costs nothing and arguing it reads
  as defensive.

Add **Article 35(1)**'s own trigger — processing likely to result in a high risk
to rights and freedoms — and the answer is settled.

### Two DPIAs

**The customer's**, for the recognition programme. This is the controller's
obligation and you cannot discharge it for them. What you should do — and this
is commercial advantage, not just compliance — is publish a **model DPIA** and a
**model legitimate interests assessment** the customer completes with their own
numbers. Every enterprise data protection officer will ask. Handing them over
pre-drafted removes weeks from the sales cycle and frames the analysis on your
terms.

**Yours**, for the processing where you are the controller: accounts,
authentication, security logs, billing. Smaller, conventional, and required for
your own **Article 5(2)** accountability record.

### Can it be built from the threat model?

Partly — call it 40%, not the 90% your document implies. The two documents
answer different questions. `SCHEMA_THREAT_MODEL.md` is a security threat model:
risks to the *system* and the controls that address them. A DPIA assesses risks
to *individuals* — the distress of an inferred ballot, the career harm of a
misused result, the exposure of a health disclosure. Same product, different
axis.

Transfers directly: the description of processing, the data inventory, the
controls, the residual risk register format. That is real, and it puts you ahead
of most teams at this stage.

Must be written fresh, per **Article 35(7)**:

- **necessity and proportionality** — why this processing, why this much, what
  less intrusive alternatives were considered and rejected. `DECISIONS.md` is an
  unusually good source; most teams reconstruct this from memory and it shows;
- **risks to individuals**, as harms to people rather than failures of controls,
  with likelihood and severity;
- **consultation with data subjects or their representatives**, or a recorded
  reason for not consulting — **Article 35(9)**, routinely skipped and routinely
  picked up;
- **sign-off**, named and dated, with DPO advice if one is appointed.

**Product decision:** `D-033`. Own DPIA plus model DPIA and model LIA as
customer collateral, before closed beta.

---

## 7. Does the data have to be in the UK?

### Determination

**No. There is no data localisation requirement in UK law and Ireland is
lawful. Create the production project in London anyway, before the first
customer, because the decision is irreversible and the cost of being wrong is
asymmetric.**

### Authority

There is no localisation rule in UK data protection law. Any supplier
questionnaire implying one is stating a procurement preference, not a legal
requirement.

Transfers from the UK to Ireland are covered by adequacy. The mechanism: the
Secretary of State makes adequacy regulations under what was **section 17A DPA
2018**, and existing EU adequacy findings — including the EEA states — were
carried across by the transitional provisions in the **Data Protection, Privacy
and Electronic Communications (Amendments etc) (EU Exit) Regulations 2019**. The
DUAA 2025 has since restructured this into new **Articles 45A and 47A UK GDPR**,
with Schedule 9 preserving regulations made under the old sections. Net effect
for you: no transfer risk assessment, no IDTA, no addendum. For these purposes
it behaves as a domestic transfer.

The reverse direction is also settled for the term of any contract you sign now.
The European Commission renewed its adequacy decisions for the UK in **January
2026**, following its assessment of the DUAA, with a sunset clause running to
**27 December 2031**. That matters because your UK staff will access data held
in Ireland, and the answer is that it is fine.

**On the question as asked: Ireland is lawful and you are not exposed.**

### Why London anyway

Three reasons, none of them legal.

**Procurement.** UK public sector, NHS, local government, financial services and
a good number of large private employers put "is the data held in the UK?" on
their supplier questionnaire, frequently as a hard filter applied by someone with
no authority to grant an exception. You will not win the argument that the
question is legally illiterate. You will lose the deal, repeatedly, and never
find out why.

**Irreversibility.** The region cannot change after the project is created. When
a decision is irreversible, free today, and asymmetric in its downside, take the
lower-regret option. Ireland costs you a migration with live employee data on it
the first time a buyer insists, which is the worst possible moment to do one.

**Coherence.** Your entire privacy posture is precision — confidential not
anonymous, warn about small teams, do not overclaim. "Your data stays in the UK"
is then a sentence you can simply say.

### The caveat, which matters given question 8

Do not write "your data never leaves the UK" until you know what your
subprocessors do. Storage region is the easy half; **support and engineering
access** is the real question, and under **Article 28(2) and 28(4)** you are
responsible for your sub-processors' arrangements. Before making any residency
claim in the notice or in marketing:

- read the Supabase DPA and establish where support access originates and what
  transfer mechanism covers it;
- do the same for Resend;
- do the same for Firebase Cloud Messaging when `INF-004` is configured — a
  US-headquartered provider, so state the mechanism explicitly;
- list each in the subprocessor table with its location and mechanism.

Then write a sentence that is true. Given your stated standards, an inaccurate
residency claim would be worse than saying nothing.

**Product decision:** `D-034`. Production project in `eu-west-2` (London).
Blocking, and first, because it cannot be undone.

---

## 8. Is our wording honest?

### Determination

**The framing is right and two specific sentences are not true. Both are fixed
below. Four Article 13 items are missing, and there is an Article 14 problem
your documents have not noticed.**

### Sentence one: "Who can see your nomination: nobody"

Not accurate, and your own section 3 proves it — a court order, a database
administrator, or your trusted server role can reach `nominator_user_id`. You
cannot have both. As drafted, the notice is contradicted by an internal document
in the same repository, dated and signed off. That is the worst combination: a
disprovable assertion whose disproof you wrote yourself, and the first sentence a
claimant's solicitor would put to you.

It is also the one place where the precision that characterises the whole project
failed. Replaced with:

> **Who can see your nomination:** nobody in your organisation. Your employer's
> administrators can see how many people voted and who won. They cannot see who
> you nominated, and no screen, export or report in this app will show them. A
> small number of our own technical staff can reach the underlying database when
> they need to fix a fault or investigate a security problem; that access is
> controlled and logged. We would also have to disclose it if we were legally
> required to, such as by a court order.

Longer, and true. It costs nothing, because "nobody in your organisation" is the
promise anyone actually cares about. No employee has ever worried about your
on-call engineer. Every employee worries about their manager.

### Sentence two: "We will never tell you who wrote it"

Too absolute, and the correct position is more interesting than the wrong one.

The right hook is **DPA 2018, Schedule 2, Part 3, paragraph 16**: the Article
15(1)–(3) subject access rights do not oblige a controller to disclose
information to the extent that doing so would involve disclosing information
relating to **another individual who can be identified from it**. That is
squarely your case, and it supports your position in the overwhelming majority
of requests.

But paragraph 16(2) makes it a **balancing exemption, not a prohibition**. The
obligation revives where the other individual has consented, or where it is
**reasonable to disclose without their consent** — and paragraph 16(3) directs
you to factors including any duty of confidentiality owed to that person, steps
taken to seek their consent, whether they are capable of giving it, and any
express refusal. "Never" forecloses a judgment the statute requires you to make
case by case. Replaced with:

> We will not normally tell you who wrote it. If we are ever legally required
> to, we will explain why.

And write a short DSAR runbook recording that you apply Schedule 2 Part 3
paragraph 16 and the factors you weigh. Having the runbook is most of the answer
when challenged.

### The Article 14 problem — **CONTESTABLE**

Almost all of your thinking is about the nominator. But the **nominee** is a
data subject whose personal data — an opinion about them — was obtained from
someone other than themselves. That engages **Article 14**, which requires
telling them, at Article 14(2)(f), **the source the data came from**.

You deliberately do not. I think you are right, and I think paragraph 16 supports
withholding it, since the source *is* the other individual's identity. But note
what is actually happening: Article 14 is a proactive transparency duty, while
paragraph 16 is drafted as a restriction on Article 15 access. Reading the
Article 15 exemption across to discharge an Article 14 duty is a sound argument,
not an automatic one, and the cleaner belt-and-braces position also invokes
**Article 14(5)(b)** (disproportionate effort or serious impairment of the
purposes) — the purpose here being confidentiality itself, which naming the
source would destroy.

This is the point where your two promises actually conflict: confidentiality to
the nominator, transparency to the nominee. It is the most interesting question
in the product and the one most likely to be got wrong by someone reading
quickly. **Take this one to counsel specifically**, and until then record the
reasoning in `DECISIONS.md` rather than leaving it implicit in a function
signature.

### Missing from the notice

Required by **Articles 13 and 14**, absent from the draft:

1. **The lawful basis, named** — Article 13(1)(c). Say "legitimate interests"
   and say whose, and state the interest pursued (Article 13(1)(d)).
2. **The right to object, given prominence** — **Article 21(4)** requires that
   where processing rests on legitimate interests, the right to object is
   brought to the data subject's attention **explicitly, separately from any
   other information, and clearly**. A line in a list at the end does not
   satisfy that. Give it its own heading.
3. **That participation is voluntary, stated loudly.** Your product is genuinely
   excellent here — nothing records or exposes who did not vote — and the notice
   barely mentions it. It belongs near the top: "You do not have to take part.
   Nobody will be told whether you voted, and there is no record anywhere in
   this app of who did not."
4. **The right to complain to the ICO** — Article 13(2)(d), with a link. Note
   also that from **19 June 2026**, section 164A DPA 2018 (inserted by the DUAA)
   requires controllers to acknowledge data protection complaints within 30 days
   and respond without undue delay. Check your own process and the customer's
   both meet it.

Also add: where the data is held, per question 7; and correct the retention
wording, which currently implies everything about a vote is deleted at the
retention period. It is not. Say: "We keep a record that you voted, without
anything you wrote, for as long as the result exists."

### The small-team warning

The wording is fine. **The delivery is wrong.**

`assessConfidentiality` warns the **administrator**, before a cycle opens, below
eight eligible voters (`D-022`). But the person whose ballot may be inferred is
the **voter**, and they are not the person being warned. A sentence in a privacy
notice emailed at onboarding does not discharge the fairness and transparency
duty in **Article 5(1)(a)**, which is judged by what the data subject actually
understood at the point their data was collected.

Put it on screen for the voter, at the moment of voting:

> Your team is small enough that it may be possible to work out how you voted
> from the result. We cannot prevent that. You do not have to vote.

Three sentences and one conditional render. It converts your best-documented
decision into a control that protects the person it was written for. Of
everything in this document, it is the change I would be proudest of shipping.

**Product decisions:** `D-031` (notice corrections — implemented), `D-035`
(voter-facing confidentiality warning — implemented), Article 14 reasoning
recorded pending counsel.

---

## What was changed in the product

Implemented in this pass, tested where the test suite can run in this
environment:

| Change | Where | Tested |
|---|---|---|
| Voter-facing small-team warning | `src/domain/recognition/engine.ts`, `src/app/index.tsx` | Yes — `npm test` |
| Sensitive-data warning moved above the field | `src/app/index.tsx` | n/a |
| Privacy notice corrections | `src/app/privacy.tsx` | n/a |
| Destructive `redact` moderation action, permitted post-reveal | `supabase/migrations/20260728_legal_redaction.sql` | **No — see below** |
| `redact_winner_snapshot` with three outcomes | same migration | **No — see below** |
| Decision records `D-026`–`D-035` | `docs/DECISIONS.md` | n/a |

**The SQL has not been executed.** There is no Postgres, Docker or Supabase CLI
in this environment, so `supabase db reset` and `supabase test db` could not
run. A pgTAP test file is included alongside the migration in the project's
existing style. Do not merge either until the suite passes locally. I have not
pretended otherwise and you should not assume it works because it is written.

**Deferred deliberately:** `D-027`, severing the nominator-to-nominee link at
purge. It alters a `NOT NULL` constraint and two functions with existing
contract tests, and writing that blind into a repository with this standard of
test coverage would be worse than leaving a specified card. The design is in
section 2 and it is ready to implement.

---

## Do this in order

**Before closed beta**

1. Production Supabase project in London. First, because it is irreversible.
2. Run the SQL suite; merge the redaction migration once green.
3. Ship the notice and warning changes.
4. Permitted use covenant, indemnity and suspension right into the terms.
5. Your own DPIA; model DPIA and model LIA as customer collateral.

**Before real employee data**

6. Instruct a data protection solicitor with employment crossover. Give them
   this document, `LEGAL_AND_PRIVACY.md`, and flag questions 3 and the Article
   14 point in 8 as the two you want argued rather than confirmed.
7. DPAs signed with Supabase, Resend and Google; subprocessor access locations
   audited before any residency claim is made.
8. Schedule X pre-set characteristics clause into the DPA.
9. DSAR runbook, recording the Schedule 2 Part 3 paragraph 16 reasoning.
10. Article 13 and 14 gaps closed in the notice.
11. `D-027` implemented.

**Accepted, not scheduled**

12. Structured tags instead of a 500-character free-text box (`D-032`).

---

## What I could not answer

- **Whether your DPA drafting is adequate.** There is no DPA in the repository
  to review.
- **Whether the Article 14 source-withholding position holds.** Analysis given,
  reasoning sound, needs a human who carries insurance.
- **Whether your customers' own DPIAs will pass.** Not knowable from here, which
  is the argument for the model DPIA.
- **Anything about Play Store policy or consumer law.** Outside the eight
  questions and not examined.

---

## Sources

Statute and guidance relied on: UK GDPR Articles 4(7), 5(1)(a), 5(1)(c),
5(1)(e), 5(2), 6(1)(f), 9(1)–(2), 13, 14, 15, 17, 21, 28, 35, 45A; Recitals 26
and 47; Data Protection Act 2018 Schedule 1, Schedule 2 Part 3 paragraph 16, and
section 164A as inserted by the Data (Use and Access) Act 2025; Equality Act
2010 section 19; Employment Rights Act 1996 section 98(4); *Williams v Compair
Maxam* [1982] ICR 156 (EAT); Part-time Workers (Prevention of Less Favourable
Treatment) Regulations 2000; EDPB Guidelines 07/2020 on controller and
processor; Article 29 Working Party WP248 rev.01; Data Protection, Privacy and
Electronic Communications (Amendments etc) (EU Exit) Regulations 2019.

Current position verified against:

- [Data Protection Act 2018, Schedule 2 (legislation.gov.uk)](https://www.legislation.gov.uk/ukpga/2018/12/schedule/2)
- [A guide to the data protection exemptions (ICO)](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/exemptions/a-guide-to-the-data-protection-exemptions/)
- [The Data (Use and Access) Act 2025 — what does it mean for organisations? (ICO)](https://ico.org.uk/about-the-ico/what-we-do/legislation-we-cover/data-use-and-access-act-2025/the-data-use-and-access-act-2025-what-does-it-mean-for-organisations/)
- [Commencement of the data protection provisions in the DUAA (DLA Piper)](https://privacymatters.dlapiper.com/2026/02/uk-commencement-of-the-data-protection-provisions-in-the-data-use-and-access-act/)
- [Commission renewed adequacy decisions for data transfers to the UK (eucrim)](https://eucrim.eu/news/commission-renewed-adequacy-decisions-for-data-transfers-to-the-uk/)
- [Receiving personal information from the EEA (ICO)](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/international-transfers/receiving-personal-information-from-the-eea/)
- [The Data Protection, Privacy and Electronic Communications (Amendments etc) (EU Exit) Regulations 2019](https://www.legislation.gov.uk/uksi/2019/419/schedule/2/paragraph/23/made?view=plain)

Product facts verified against `docs/LEGAL_AND_PRIVACY.md`,
`docs/SCHEMA_THREAT_MODEL.md`, `docs/DECISIONS.md`,
`src/domain/recognition/engine.ts`, `src/app/index.tsx`, `src/app/privacy.tsx`,
`supabase/migrations/20260725184758_recognition_cycles_and_ballots.sql`,
`supabase/migrations/20260725205913_admin_moderation_turnout_and_reveal.sql` and
`supabase/migrations/20260728010124_privacy_export_purge_deletion.sql`.
