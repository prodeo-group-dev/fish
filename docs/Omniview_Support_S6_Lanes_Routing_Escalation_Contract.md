# Omniview Support, Wave S6: specialist lanes, routing, escalation and playbooks

**Status:** DRAFT 1, 2026-10-06, written by the Omniview session for CM, Femi, EA and the Education Runtime owner. Backlog rows
S6.1 to S6.4 in `docs/Omniview_Support_Model_Backlog.md`; requirements FR-SUP-A9, FR-SUP-I1 to I3 and UC-SUP-3, UC-SUP-20.
**Built and tested on Omniview's side** (fish-er-omniview branch `feat/omniview-support-s5`, which now also carries S6; migrations V12 to V14,
awaiting CM). It is **entirely operator-side**: no route EA, WEB or any other service serves or calls changes, no new infrastructure,
no new environment variable, and a tenant sees nothing different except, if an operator chooses, one plain reply on their own ticket.

## 0. What it is for

Different questions need different people: a verification deadline is a support operator's, a period that will not close is an
accountant's, a tax question is a tax specialist's for that country, a school's admissions problem is the Education owner's. S6 lets the
team say **who answers what** as data, sends each ticket to the right lane automatically, lets an operator **hand a ticket over** with
a proper note and a clock, and gives each industry a **playbook** so the operator knows what is usually asked and who to ask.

## 1. Lanes and routing (S6.1)

A **lane** has a key, a name, a tier (**L1** a support operator, **L2** the engineer who owns a service, **L3** a specialist), an
**owner** and a **backup** (names or roles, free plain text: a specialist need not use the console and is reached by the staff alert),
and a description. A **routing rule** has a priority (1 to 1,000; lower is tried first), a lane, and any of: family, industry, country,
module, and "this severity or worse". Every condition set must match; an unset one matches anything. **The first enabled rule whose lane is
still active wins.** No rule matching leaves the ticket without a lane.

**When routing runs:** at ticket creation (from the context EA and WEB already send: industry and module) and again when triage changes the
family, severity or country. It is recorded in the ticket's history as the actor `routing` with "routing rule N". **A lane a person chose is
never changed by routing**; clearing the lane (choosing "let routing decide") hands the decision back.

**Country.** A ticket carries no country (that lives in the ledger's Company), so an operator sets it at triage. A rule on country then lets a
tax ticket go to that country's lane: put a rule such as "tax-statutory and IE goes to `tax-ie`" **above** the general tax rule.

**Starter set (V12).** Lanes `general`, `access`, `onboarding`, `accounting-close` (L3), `tax` (L3), `security` (L3) and `education` (L2), and rules, in
order: security, tax, period end, migration, access, SCHOOL industry (so a school's tax or security question still goes to the specialist),
getting started, verification, and a catch-all to `general`. **Owners and backups are not named**: who covers each lane is Femi's to say (SD12), and
until then the console shows "not named yet".

**Rules for changing it.** A lane cannot be retired while an enabled rule routes to it; a rule cannot point at a missing or retired lane; every change is in
the operator access log. A **dry run** ("which lane would this go to?") shows the lane and the rule without changing anything.

## 2. Escalation (S6.2)

An operator hands a ticket to an **L2 or L3 lane** with a **handoff note** (what was asked, what was tried, the request ids; required, plain text, up to
2,000 characters). The ticket moves to that lane, **stays one thread**, and the tenant is told nothing unless the operator ticks *also tell the
business*, which posts a plain reply on their ticket ("we have passed this to a specialist, who is now looking at it") **and counts as support's answer for
the response clock**, which is why it is a choice, not automatic. One open escalation per ticket.

- **Told:** a staff alert (ESCALATED) through the existing outbox names the lane and the tenant's name; it carries no ticket text and no handoff note.
- **Its own clock:** in working time (08:00 to 18:00 UK, Monday to Friday). **Provisional defaults: an L2 lane eight working hours, an L3 lane twenty (two
  working days). The support model gives no figures, so these are for Femi to confirm.**
- **If nobody acts:** past its time the escalation is flagged **once**, one staff alert (ESCALATION_BREACH) is raised, and the ticket shows in the queue's
  attention view. The ticket is not moved, because a specialist may be mid-answer; the people who sent it can see it has stalled.
- **Ending:** the specialist **returns** it to support with a note, or marks it **resolved** with a note. Either puts the ticket back in the lane it came from, as a
  person's choice (routing will not move it), and the L1 owner closes it. Closing a ticket ends any escalation still open on it.

## 3. Industry playbooks (S6.3)

One live playbook per industry (industry is EA's closed set today, GENERIC and SCHOOL). It holds plain-text **common questions and how to answer them**, the
**owning service** (whose owner is the L2), the **lane to escalate to** (its owner and backup show beside it) and the **help articles** to point people at. It
appears in a **Playbook** tab on any ticket whose context names that industry. Editing is in place and logged. **No content is seeded**: a playbook full of
product answers that have since changed is worse than none, so **the Education Runtime owner writes the School playbook** (admissions, guardian fee
billing, timetabling) and keeps it current. Nothing in a playbook reaches a tenant.

## 4. The tax lane and the professional-judgement flag (S6.4, SD4)

Tax questions route by the rules above (a general `tax` lane, and a lane per country as the team creates them, each with a rule on country). The lane's
specialist uses the country's tax and currency document under `docs/<country>/` as the reference.

An operator can mark a ticket **needs a professional judgement** when the honest answer would be a judgement about the business's own accounts or tax
rather than an explanation of the product. The console then shows a plain banner: support explains the product and how to do something in it, does not advise,
says so plainly, and a **separate engagement by Prodeo Capital's accountants** is how that help is given. The mark is in the ticket's history and is operator-only.
**Omniview ships no wording for tenants about this.** Whatever is said to a business about a paid engagement is a legal and commercial matter (SD4 says take legal
advice before offering it as part of the subscription), so the words are Prodeo's to write, as a canned reply if wanted.

## 5. Routes (operator token, all under `/operator`)

`GET/POST /lanes`, `POST /lanes/{key}/update`, `POST /lanes/{key}/retire`; `GET/POST /routing-rules`, `POST /routing-rules/{id}/update`,
`DELETE /routing-rules/{id}`, `POST /routing-rules/test`; `GET/POST /tickets/{id}/escalations`, `POST /tickets/{id}/escalations/finish`;
`GET/POST /playbooks`, `GET /playbooks/for-industry/{industry}`, `POST /playbooks/{id}/update`, `POST /playbooks/{id}/retire`. Triage gains two optional fields:
`jurisdiction` (an empty string clears it) and `judgement`. The operator ticket shape gains `laneRouted`, `jurisdiction`, `judgement`, `escalatedTo`,
`escalationDueAt` and `escalationStalled`. **None of this appears on any `/internal` route**, so the relay and WEB are unaffected.

## 6. Decisions and asks

1. **Femi: name each lane's owner and backup (SD12).** Until then every lane shows "not named yet" and the staff alert goes to the one support mailbox.
2. **Femi: confirm or change the escalation clocks** (L2 eight working hours, L3 twenty).
3. **Education Runtime owner: write the School playbook** in the console (Playbooks tab). It is the first one, and UC-SUP-20 depends on it.
4. **Tax specialists: say which countries need their own lane first** (UK, Ireland and Nigeria are the live ones). Each is a lane and a rule, no deploy.
5. **Wording for a tenant who needs a professional judgement** is Prodeo's to write, with legal advice (SD4). Omniview ships none.
6. **Not built:** automatic assignment of a ticket to a named person from the lane's owner (owners are labels, not console users); an on-call roster (S5 and
   SD12); paging a specialist other than by the support mailbox. Each waits on there being more than one operator.

## 7. What changes in production

Three additive migrations: V12 (lanes, routing rules, and two columns on tickets, seeded with the starter set), V13 (escalations, two new alert kinds), V14 (playbooks, one
column on tickets). The seed means **every new ticket is given a lane from the first deploy** (at worst `general`); existing tickets are not changed.
Nothing for CM to configure.
