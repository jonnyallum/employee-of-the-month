# Eight questions for the solicitor

Version: 0.1
Date: 28 July 2026

A plain-language companion to `docs/LEGAL_AND_PRIVACY.md`. That document has the
detail and the evidence; this one is what to actually put in front of somebody.

## What the product is, in four sentences

An employer runs a monthly "employee of the month" vote. Staff each nominate one
colleague and can write a short reason. Managers see the result and how many
people voted, but **not who voted for whom**, and that is enforced by the
database rather than by policy. We provide the software; the employer decides
who takes part.

---

## 1. Are we the processor, or are we secretly a controller?

**Our position:** the employer is the controller. They pick the people, the
rules and the outcome. We just run the software.

**Why it might be wrong:** we do impose some things a customer cannot switch
off. Managers can never see who voted. Retention can only be 3, 6, 12 or 24
months, or forever. Nobody can see who is winning while voting is open.

**The question:** does refusing to let a customer turn those off make us a
controller?

---

## 2. We keep a record of who voted. Is that all right?

We have to store it, otherwise we cannot stop somebody voting twice. Nobody in
the customer's organisation can ever see it.

After the retention period we delete what people **wrote**, but we keep the row
saying that a vote happened, because that is what makes an old result still add
up.

**The question:** is keeping the link between a person and their old vote
defensible once the words are gone?

---

## 3. If somebody deletes their account, we still say they won

If Sarah won March and later deletes her account, we keep "March 2026: Sarah,
4 nominations". The employer announced it at the time and it is part of the
company's history. We do not keep anything anybody wrote about her.

**The question:** can we keep that after erasure, and what do we have to tell
people up front? **We think this is the most likely thing to be challenged.**

---

## 4. Should we ban using this for pay and promotions?

The product produces no score or ranking, and we have decided it never will.
But nothing stops a manager printing the winners list and using it in an
appraisal.

**The question:** should the customer contract flatly forbid using results in
performance reviews, pay, promotion, redundancy or disciplinary decisions? We
think yes, and that it is also what makes our "legitimate interests" argument
stand up.

---

## 5. People will type things they should not

There is a free-text box for "why you are nominating them". Somebody will
eventually write "she covered for me while I was having treatment", which is
health information about a third person.

We already warn people right above the box, let managers hide a nomination with
a recorded reason, and stop managers reading any of it until voting closes.

**The question:** is that enough, or do we need something stronger in the
contract or in the product?

---

## 6. Do we need a DPIA?

We think yes. It is employee data, there is a power imbalance between employer
and staff, and colleagues are supplying opinions about each other.

**The question:** do you agree, and can we build it from the security document
we already have?

---

## 7. Does the data have to be in the UK?

It is currently in Ireland. Our customers are UK employers. **The region cannot
be changed after a project is created**, so this is a decision we should make
before real customers, not after.

**The question:** does UK data need to stay in the UK for this kind of product,
or is Ireland fine?

---

## 8. Is our wording honest?

We deliberately say **confidential**, never **anonymous**, because we do store
who voted.

We also warn managers when a team is small, because with only two or three
voters a manager can work out how somebody voted just from the result, and no
software can prevent that.

**The question:** is the draft privacy notice accurate, and are we saying enough
about the small-team problem?

---

## What we are not asking you to do

We are not asking you to check the software. We are asking whether the things it
does are lawful, and whether what we say about them is accurate.

If it helps, `docs/LEGAL_AND_PRIVACY.md` lists exactly what data exists and
where, taken from the live system rather than from a template.
