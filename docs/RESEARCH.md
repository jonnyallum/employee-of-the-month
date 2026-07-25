# Research and product strategy

Research date: 25 July 2026

## Executive conclusion

There is a credible gap between generic polling tools and large employee
recognition suites.

Generic forms are quick and cheap, but they make a monthly programme manual:
somebody must rebuild the roster, enforce one response, close the ballot, count
votes, resolve ties, announce the result and retain or erase the data. Large
recognition platforms automate much more, but their breadth, reward catalogues,
integrations and per-user pricing are excessive for a small team that wants one
well-run monthly award.

The product should occupy the narrow middle:

> A private, mobile-first employee of the month programme that a small team can
> start in minutes and trust every month.

This is deliberately not a complete HR system or rewards marketplace.

## Target market

### Initial beachhead

- UK organisations with 5 to 100 workers.
- Frontline, shift, field, care, facilities, retail, hospitality, trades and
  mixed desk/non-desk teams.
- An owner, office manager, people lead or team manager runs the programme.
- The organisation does not want to buy or deploy a full HR suite.
- Staff need to participate from personal or shared Android devices.

### Jobs to be done

**Programme owner**

- Set up a fair programme without spreadsheets or a new HR platform.
- Invite a roster, open a monthly cycle and know who has participated.
- Close voting, resolve a genuine tie and announce a defensible result.
- Demonstrate what is private, what is visible and how long records are kept.

**Employee**

- Join with little friction.
- See who is eligible and the criteria that matter.
- Nominate one colleague privately and optionally explain why.
- Trust that live results cannot steer later votes.
- See the winner and the approved recognition message.

## Competitive landscape

Ratings describe fit for the initial 5 to 100 person target, not overall
product quality.

| Capability | Proposed app | Google Forms / manual poll | Recognize | Bonusly | Nectar | Assembly |
|---|---|---|---|---|---|---|
| Purpose-built monthly cycle | Strong | Weak | Strong | Adequate | Strong | Adequate |
| Fast setup for a small team | Strong | Strong | Adequate | Adequate | Weak | Adequate |
| One vote and no self-vote enforced server-side | Strong | Weak | Adequate | Weak | Adequate | Weak |
| Secret ballot with no live influence | Strong | Weak | Strong | Weak | Adequate | Weak |
| Mobile-first participation | Strong | Adequate, web only | Strong | Strong | Strong | Strong |
| Rewards catalogue | Absent in v1 | Absent | Strong | Strong | Strong | Strong |
| Broad recognition feed | Absent in v1 | Absent | Strong | Strong | Strong | Strong |
| Admin burden | Low | High every month | Medium | Medium | Medium | Medium |
| Entry price | Free beta | Usually free | Paid / sales-led | Free for small teams, paid tiers | Quote-led | Published per-member tiers |
| Product complexity | Low | Low initially, high operationally | High | Medium | High | High |

### Direct and adjacent products

**Recognize**

- Its nominations feature explicitly supports secret voting and employee of the
  month use cases.
- It is the closest functional benchmark.
- It also includes rewards, badges, incentives and broader programme
  management, leaving room for a much narrower self-serve product.

**Bonusly**

- Strong mobile support and peer-to-peer recognition.
- Its published free plan supports up to eight users, with a Team plan listed at
  $30 per user per year at the time of research.
- It competes for general recognition behaviour, not for the simplest monthly
  ballot.

**Nectar**

- Includes peer recognition, rewards, nomination programmes, analytics, HRIS,
  SSO and frontline bundles.
- Its official pricing page is quote-led.
- This is a broad mid-market platform and a future expansion threat, not the
  initial product model to copy.

**Assembly**

- Offers recognition, engagement, awards and rewards.
- Its published annual tiers have historically started around $2 per member per
  month, with higher engagement tiers.
- Its breadth makes it more capable but also heavier than the proposed product.

**Google Forms, Microsoft Forms, Woobox and general polling**

- These are the strongest substitutes because they are familiar and often
  free.
- They can collect a vote, but they do not own a durable monthly state machine,
  employee eligibility, confidential tallying, repeatable reminders, winner
  history, privacy exports or erasure.
- Woobox now has a purpose-built employee of the month poll template. Its
  advertised live results are easy to set up but conflict with our fairness
  position because early votes can influence later ones.

### Positioning map

| | Narrow programme | Broad recognition suite |
|---|---|---|
| Self-serve SMB | **Proposed app** | Bonusly, Assembly |
| Sales-led mid-market / enterprise | Recognize nominations | Nectar, Awardco, Workhuman |

## Evidence that changes the design

Recognition is not automatically positive. Poorly administered schemes can
feel arbitrary, exclusive or performative.

The CIPD evidence review identifies three core principles: make rewards fit the
work, link them consistently to performance and administer them in a way people
see as fair. Gallup reports that perceived inequity in recognition undermines
inclusion and trust. SHRM's 2026 review of employee of the month programmes
highlights common failures: a single winner can exclude consistent
contributors, monthly recognition is delayed, generic praise lacks meaning and
cross-role comparison can be unfair.

These findings produce concrete product requirements:

- Never show live standings while voting is open.
- Let the organisation publish clear criteria before the cycle opens.
- Prompt for a specific reason, but do not make long prose the price of voting
  in v1.
- Make eligibility and exclusions visible to administrators and auditable.
- Record tie decisions rather than silently allowing an administrator to pick.
- Report turnout, not individual voter choices.
- Do not claim that the programme measures performance or chooses who deserves
  promotion, pay or disciplinary action.
- Add broader and team-based awards only after validating the core monthly
  workflow.

## Product principles

1. **Fair by construction.** Rules live in database constraints and guarded
   functions, not only in the interface.
2. **Confidential, not falsely anonymous.** The system needs an internal voter
   identifier to enforce one vote, but administrators do not receive it through
   normal APIs or exports.
3. **No influence during voting.** Counts and rankings remain hidden until the
   cycle is closed.
4. **Specific recognition.** Criteria and a short reason prompt make the result
   more meaningful than a name on a badge.
5. **One job done well.** Avoid HRIS, payroll, performance management, points
   wallets and reward fulfilment in v1.
6. **Frontline usable.** Core participation must work on a modest Android phone,
   one-handed and on an unreliable connection.
7. **Privacy is visible.** Explain ballot confidentiality, retention and user
   rights in the product rather than hiding them in legal text.

## Recommended v1 scope

### Include

- Organisation creation and one-time invitation links.
- Owner, administrator and member roles.
- Participant roster with separate vote and receive eligibility.
- One calendar-month cycle with draft, open, closed and revealed states.
- One confidential nomination per eligible voter, with withdrawal and recast
  while open.
- Optional reason, maximum 500 characters.
- Clear programme criteria.
- No self-nomination.
- Hidden standings until closed.
- Deterministic tally and tied-leader handling.
- Winner reveal, history and a shareable in-app result card.
- Generic push and email reminders for non-voters who have opted in.
- Admin turnout, audit history, retention settings and privacy workflows.
- In-app and web account deletion routes required by Google Play.

### Exclude

- Cash, gift cards, points, prize fulfilment or payroll integration.
- Continuous social recognition feed.
- Public anonymous join codes.
- Slack, Teams, HRIS or payroll integrations.
- AI scoring, sentiment analysis or winner selection.
- iOS release, although the architecture should not block it.
- Multiple simultaneous award categories.
- Public leaderboards or all-time rankings.
- Paid plans or in-app subscriptions during validation.

## Monetisation hypothesis

V1 should be a free closed beta. It is too early to add Google Play Billing or
create a web-paid entitlement model before activation and repeat-cycle
retention are known.

After validation, test:

- Free: one organisation, up to 10 active participants, core monthly cycle.
- Team: approximately £19 per organisation per month including 50 active
  participants, reminders, branding and exports.
- Additional participant bands rather than a confusing per-seat invoice.

No paid entitlement should be implemented until the payments policy and
regional service-fee model are reviewed at that time. Google Play policy
currently treats cloud and business productivity features as digital services.

## Success hypotheses

### Activation

- At least 60% of beta organisation owners create a cycle within 24 hours.
- Median time from verified sign-in to open cycle is under 10 minutes.
- At least 70% of invited, eligible employees join.

### Core value

- At least 65% of eligible voters nominate in an open beta cycle.
- At least 80% of cast nominations complete without a support request.
- At least 50% of activated organisations start a second monthly cycle.

### Trust and quality

- Zero cross-organisation data exposures.
- Zero duplicate or self-nominations accepted by the database.
- Zero voter identities in administrator exports, notifications or analytics.
- Crash-free user rate of at least 99.5% during closed testing.
- Fewer than 2% of notification sends produce a duplicate reminder in one
  cycle.

These are hypotheses for a 10 to 20 organisation beta, not market benchmarks.

## Risks and responses

| Risk | Why it matters | Planned response |
|---|---|---|
| Popularity and proximity bias | Voting can favour visible or well-connected staff | Criteria, hidden live results, reasons, eligibility audit and future team/category options |
| False anonymity claim | Voter IDs exist internally for ballot integrity | Use "confidential"; block admin access to voter identity through tables, RPCs and exports |
| Low monthly repeat use | Novelty may fade after one cycle | Measure second-cycle creation before building rewards or integrations |
| Manual roster setup | Admin may abandon onboarding | CSV import is P1; v1 supports fast add and invitation flows |
| Free-text personal data | Reasons can contain sensitive information | 500-character cap, content prompt, moderation, retention and erasure |
| Employer misuse | Results could be treated as performance evidence | Product copy and terms state the app is recognition, not performance management |
| Generic poll substitution | Free forms already collect votes | Win on repeatability, trust, reminders, history and low admin effort |
| Play review delay | Account verification, testing and policy work can block release | Treat Play Console setup and closed testing as early work, not a launch-week task |

## Indicative operating cost

At the researched prices:

| Service | Validation | Production starting point |
|---|---:|---:|
| Supabase | Free for development, but projects pause after inactivity | Pro from $25/month |
| Expo EAS | Free includes limited Android builds and store submission tooling | Starter $19/month if queue/build demand justifies it |
| Firebase Cloud Messaging | No-cost product | No-cost product, subject to service limits |
| Resend | Free up to 3,000 emails/month and 100/day | Pro $20/month if needed |
| Google developer registration | One-time account fee, verify exact Play Console charge | One-time |

Production should not rely on a Supabase free project because pausing and lack of
backups are unacceptable for an active employee programme.

## Sources

All sources were accessed on 25 July 2026.

### Product and market

- [Recognize nominations instructions](https://faq.recognizeapp.com/hc/en-us/articles/360020522372-Nominations-Step-by-Step-Instructions)
- [Bonusly pricing](https://bonusly.com/pricing)
- [Bonusly subscription details](https://help.bonus.ly/en/articles/13320193-paying-for-bonusly-subscriptions)
- [Nectar pricing and capabilities](https://nectarhr.com/pricing)
- [Assembly pricing](https://blogs.joinassembly.com/pricing)
- [Assembly awards](https://help.joinassembly.com/en/articles/10435729-setting-up-and-giving-awards)
- [Woobox employee of the month template](https://woobox.com/templates/polls/employee-of-the-month-vote)

### Recognition evidence

- [CIPD incentives and recognition evidence review](https://www.cipd.org/en/knowledge/evidence-reviews/evidence-financial-incentives/)
- [Gallup on equitable recognition](https://www.gallup.com/workplace/392660/playing-favorites-employee-recognition.aspx)
- [SHRM on employee of the month programme limits](https://www.shrm.org/in/topics-tools/news/blogs/why-employee-of-the-month-programs-often-miss-what-employees-value-most)

### Platform and operating costs

- [Expo pricing](https://expo.dev/pricing)
- [Supabase pricing](https://supabase.com/pricing)
- [Firebase pricing](https://firebase.google.com/pricing)
- [Resend pricing](https://resend.com/pricing)

## Research limitations

- Public pricing changes frequently and enterprise products often hide it.
- Marketing pages show available features, not implementation quality.
- No primary customer interviews have yet been conducted.
- Google Play search does not expose a clear, established Android category for
  a dedicated employee of the month app. That is an opportunity, but it also
  means demand must be proven rather than assumed.
