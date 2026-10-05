# Omniview Support Model: Backlog (Tasks, Dependency-Ordered)

**SPUTO, steps T and O.** Companions: `docs/Omniview_Support_Model_SRS.md` (`FR-SUP-*`, `NFR-SUP-*`,
decisions `SD1`-`SD13`), `docs/Omniview_Support_Model_Use_Cases.md` (`UC-SUP-*`).
**Status:** decisions SD1 to SD13 accepted at their recommended defaults, 2026-10-05 (Femi: "Lets do it").
**Wave S1 is the work in progress;** every other wave below is planning only and not started. Wave S0 is
Product Support v1, which is being brought live now (`docs/Omniview_v2_Backlog.md`, support go-live plan).

**Protocol** (as everywhere in this project): claim a row in the right coordination file before starting;
only CM pushes, merges and deploys; work in another service's repo goes through that service's session;
tenant-facing screens go through the WEB session (Omniview's own operator console is exempt); every row
names every peer dependency; every workflow passes the completeness check before it is built (FR-OV-S32).

**Peers:** CM (infrastructure, secrets, review, deploys), EA (the relay and the tenancy facts), WEB (tenant
screens), GL and the other services (diagnostic and read endpoints, only where a wave needs them),
Education Runtime (the first industry lane), Femi (decisions, on-call), a solicitor (data and privacy).

Sizing is qualitative (S, M, L), not a date.

---

## The shortest useful path

1. **Wave S1** needs nothing from another team and makes every operator faster the day it ships.
2. **Wave S2** gives the operator the tenant's shape (Companies, industry, jurisdiction, modules) beside every ticket; it is the foundation of S3 to S7.
3. **Wave S3** removes the predictable tickets (how-to, access) before they are raised.
4. Waves S4 to S6 build the incident, onboarding and specialist capabilities on top.
5. **Wave S7** (diagnostic access) waits for Femi's SD1 answer. **Wave S9** (billing) waits for a subscription system that does not exist yet.

---

## Wave S0: Product Support v1 (in flight)

| # | Item | Owner | Status |
|---|---|---|---|
| S0.1 | Ticket core: raise, reply, read marker, unread, close, idempotent retries, per-tenant quota, staff alerts, awaiting-reply ageing, operator console, private-only service | Omniview, EA, WEB, CM | Built and approved; first image waits on Femi's database and secret steps (see `docs/Omniview_v2_Backlog.md`) |
| S0.2 | Runbook: completeness table as built, erasure and export, first-boot logs | Omniview | Written (`docs/Omniview_Support_Operations_Runbook.md`) |

## Wave S1: Operator effectiveness (Omniview only, no peer dependency)

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| S1.1 | **Ticket fields**: family and sub-category (the catalogue), severity P1-P4 with a reason, tags, lane, owner (assignee), change history of each (FR-SUP-A2, A3, A5) | Omniview | S0.1 | M | Not started |
| S1.2 | **Internal notes** on a ticket, never returned through the relay (FR-SUP-A6); the relay's strict shapes are unchanged | Omniview | S1.1 | S | Not started |
| S1.3 | **Search and filters** across tickets: tenant, family, severity, status, owner, age, text (FR-SUP-A8) | Omniview | S1.1 | M | Not started |
| S1.4 | **Macros**: versioned canned replies with placeholders, by family and language; insert in the reply box (FR-SUP-A7) | Omniview | S1.1 | M | Not started |
| S1.5 | **SLA clocks and alerts** per severity within the published hours; alerts at half the target and at breach, through the existing outbox (FR-SUP-A4, J2); published hours and response wording as a setting (FR-SUP-K3) | Omniview | S1.1, SD2 | M | Not started |
| S1.6 | **Operator access log**: every ticket read, card open, export and close by named operator, append-only, viewable by Femi (FR-SUP-F4). Built **now**, before the tenant card exists | Omniview | S0.1 | S | Not started |
| S1.7 | **Metrics view v1**: volume by family and severity, first-response and resolution against targets, backlog age, reopen rate, workload per operator (FR-SUP-J1) | Omniview | S1.1, S1.5 | M | Not started |
| S1.8 | **Satisfaction rating** on closure: the field and the operator view; the tenant-side prompt rides on S3 (SD10) | Omniview, WEB | S1.1, SD10 | S | Not started |
| S1.9 | **Merge and link** tickets; **feedback** as a ticket kind, counted (FR-SUP-A10, J4) | Omniview | S1.1 | S | Not started |
| S1.10 | **Assignment worklists**: "mine", "unassigned", "breaching soon"; on-call roster setting (SD12) | Omniview | S1.1, S1.5 | S | Not started |

## Wave S2: Tenant context

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| S2.1 | **Support read contract with EA**: one operator-service, read-only route returning a tenant's status, segment, verification states and deadline, Owner Admin, each Company with jurisdiction, currency, industry, enabled modules and staff counts per role. Written by EA, checked by Omniview; no ledger data (FR-SUP-B1, B2, B4) | EA, Omniview | S0.1 | M | Not started |
| S2.2 | **Context captured at ticket creation**: Company, screen or module, app version, jurisdiction and industry, added to the relay's create call. A **lockstep contract change** across EA, WEB and Omniview (strict decoding means a new field breaks the old side) (FR-SUP-B3) | EA, WEB, Omniview | S2.1 | M | Not started |
| S2.3 | **Tenant card** in the operator console, assembled on demand with short timeouts and graceful gaps; every open logged (S1.6) (UC-SUP-2) | Omniview | S2.1, S1.6 | M | Not started |
| S2.4 | **Operator credential for EA**: a service identity for Omniview calling EA read routes (today Omniview forwards a human token); a separate named provider, fail-closed (NFR-SUP-6) | CM, EA, Omniview | S2.1 | M | Not started |
| S2.5 | **Customer-visible hours and response wording** in the widget (FR-SUP-K3) | WEB | S1.5 | S | Not started |

## Wave S3: Self-serve and deflection

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| S3.1 | **Knowledge base** in Omniview: authoring, versions, category, jurisdiction, industry, language, owner and review date (FR-SUP-C1, C4); SD11 decides owners | Omniview | S1.1 | M | Not started |
| S3.2 | **Pull route** for articles and **help screen** in FiSH (through the relay; Omniview never pushes) | EA, WEB, Omniview | S3.1 | M | Not started |
| S3.3 | **Suggested answers** while typing a ticket, and articles viewed attached to the ticket (FR-SUP-C2, UC-SUP-6) | WEB, Omniview | S3.2 | M | Not started |
| S3.4 | **Access explainer**: "Why can't I see this?" answered from the real grants with the exact fix (FR-SUP-C3, UC-SUP-5); an EA feature that also feeds the operator card | EA, WEB | S2.1 | M | Not started |
| S3.5 | **Promote a reply** into a macro or article, with an owner review (FR-SUP-C5) | Omniview | S3.1, S1.4 | S | Not started |
| S3.6 | **Satisfaction prompt** on closure in the widget (S1.8) | WEB | S1.8, S3.2 | S | Not started |

## Wave S4: Notices, incidents and problems

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| S4.1 | **Platform notices**: authoring, targeting by module, jurisdiction, industry and an explicit set of tenants, effective and expiry dates; pulled by FiSH through the relay and shown in the app (FR-SUP-D1, UC-SUP-11) | Omniview, EA, WEB | S2.1 | L | Not started |
| S4.2 | **Incident records**: declare, severity, affected services, linked tickets, updates, closing notice, post-incident note (FR-SUP-D2, UC-SUP-9); alerts to on-call through the outbox | Omniview | S4.1, S1.5 | M | Not started |
| S4.3 | **Problem records** linking tickets to an owning service's backlog item, and the closing loop to every linked ticket (FR-SUP-D4, UC-SUP-10) | Omniview | S1.9 | M | Not started |
| S4.4 | **Change notices by jurisdiction** with effective dates and the macro and article updates (FR-SUP-D3) | Omniview, tax specialists | S4.1, S3.1 | S | Not started |
| S4.5 | **Public status page**: a separate tiny public thing, up or down per service (SD8) | CM | SD8 | M | Not started |

## Wave S5: Onboarding and proactive support

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| S5.1 | **Onboarding progress** derived read-only from EA and GL (Company registered, verification, chart of accounts, first posting, staff invited, period opened) (FR-SUP-E1) | EA, GL, Omniview | S2.3 | M | Not started |
| S5.2 | **Health signals and worklist**: onboarding idle, verification deadline near, no posting after go-live, period left open, repeated posting failures (FR-SUP-E2) | Omniview | S5.1 | M | Not started |
| S5.3 | **Outreach by notice, and operator-initiated threads under SD9's narrow rule**; logged and rate-limited (FR-SUP-E3, UC-SUP-7) | Omniview, EA, WEB | S5.2, S4.1, SD9 | M | Not started |
| S5.4 | **Month-end load forecast** from the close calendar (FR-SUP-E4) | Omniview | S5.1 | S | Not started |
| S5.5 | **Migration case template** and the opening-figures checklist, linked to the CSV upload design when it is built (UC-SUP-8) | Omniview, GL | S1.4 | S | Not started |

## Wave S6: Specialist lanes and routing

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| S6.1 | **Routing rules** by family, industry, jurisdiction, module and severity to lanes, each with an owner and a backup (FR-SUP-I1); lane owners named (SD12) | Omniview, Femi | S2.3, S1.1 | M | Not started |
| S6.2 | **Escalation with handoff notes** and its own ageing clock (FR-SUP-A9, UC-SUP-3) | Omniview | S6.1, S1.5 | M | Not started |
| S6.3 | **Industry playbooks**: School first with the Education owner as L2 (FR-SUP-I2, UC-SUP-20) | Education Runtime, Omniview | S6.1, S3.1 | M | Not started |
| S6.4 | **Tax lane per jurisdiction**, using the existing tax and currency docs as the reference, with the professional-judgement flag (SD4) (FR-SUP-I3) | Tax specialists, Omniview | S6.1, SD4 | M | Not started |

## Wave S7: Consent-gated diagnostic access (waits for SD1)

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| S7.1 | **Diagnostic grant record**: per ticket, per Company, time-boxed, read-only, named operator, revocable, self-expiring; the Owner Admin's accept screen. EA is the natural holder (it holds consent records and knows the grants) (FR-SUP-F2) | EA, WEB | SD1 (B), S2.1 | L | Not started |
| S7.2 | **Diagnostic endpoints** in each service: tenant-and-Company-scoped, read-only, **status and reasons, not figures**; one template, built service by service, each checking the grant (FR-SUP-F5) | GL, POP, SOP, IM, HR, Education Runtime | S7.1 | L | Not started |
| S7.3 | **Diagnostic view** in the operator console and the **log of every read** (FR-SUP-F2, F4, UC-SUP-12) | Omniview | S7.1, S7.2, S1.6 | M | Not started |
| S7.4 | **Review** of the whole path by CM at the highest effort; a threat model first (cross-tenant scoping, expiry, replay of a grant) | CM | S7.1-S7.3 | M | Not started |

## Wave S8: Data requests and exit

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| S8.1 | **Verified-request workflow** as a ticket kind with identity check, approval and execution steps, each logged (FR-SUP-G1, UC-SUP-14) | Omniview | S1.1, S1.6 | M | Not started |
| S8.2 | **Retention schedule and automatic enforcement** once SD13 is answered with the solicitor (FR-SUP-G3) | Omniview, solicitor | SD13 | M | Not started |
| S8.3 | **Exit procedure** across services (final export, retention, deletion, confirmation) (FR-SUP-G2, UC-SUP-17) | CM, all services | S9.1 | L | Not started |
| S8.4 | **Residency statement** per tenant: where its ticket data lives (FR-SUP-G4) | CM, solicitor | SD13 | S | Not started |

## Wave S9: Entitlements and billing support (gated on a subscription system)

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| S9.1 | **Scope the subscription and billing system** (plans, trial, invoices, payment failure, suspension, cancellation); outside Omniview, a prerequisite for this wave (SD3) | Femi, new bounded context | none | L | Not started |
| S9.2 | **Plan-aware entitlement** (hours, response targets, channels, named contact) in routing and SLA (FR-SUP-H1) | Omniview | S9.1, S1.5 | M | Not started |
| S9.3 | **Subscription state on the card**, billing ticket links, suspended-tenant ticket rule (FR-SUP-H2, H3, UC-SUP-16) | Omniview, EA | S9.1, S2.3 | M | Not started |

## Wave S10: Channels and language (gated on market entry and volume)

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| S10.1 | **French**: operator macros, articles and widget text for Guinea and Côte d'Ivoire (SD6); a precondition to onboarding them | Omniview, WEB | S3.1, S1.4 | M | Not started |
| S10.2 | **One further channel** at a time (SD7), each satisfying the completeness rule and the one-thread-per-ticket model | Omniview, CM | S1.10 | L | Not started |
| S10.3 | **In-app and device notifications** for a reply (the recorded limitation, FR-OV-S30) | WEB | S3.2 | M | Not started |

---

## Decisions each wave needs from Femi

| Wave | Needs | Recommended default |
|---|---|---|
| S1 | SD2 (severity, targets, hours), SD10 (rating), SD12 (on-call) | Accept the SRS section 5 targets; yes to the rating; Femi on-call for now |
| S2 | SD1 (only to confirm that no business data appears) | A: no business data on the card |
| S3 | SD11 (article owners) | Operators author; tax specialists own tax articles |
| S4 | SD8 (status page) | Notices in the app now; a separate public status page later |
| S5 | SD9 (outreach) | Narrow operator-initiated threads on deadline-driven signals only |
| S6 | SD4 (professional boundary), SD12 | Support explains the product; judgement is a separate engagement |
| S7 | SD1 (B) | B designed, built after S2 and S3 prove out |
| S8 | SD13 | Keep until erased on a verified request; set the schedule with the solicitor |
| S9 | SD3 | One default entitlement until a subscription system is scoped |
| S10 | SD6, SD7 | French before onboarding GN or CI; one channel at a time |

## Risks to the order

* **S2 depends on EA**, which is also carrying the security release and the support relay; sequence the read contract after the relay is live.
* **S2.2 is a lockstep change.** Strict decoding means a new field breaks whichever side deploys first; the contract and deploy order are agreed before code, as the relay was.
* **S7 touches every service.** Do not start it before a threat model and CM's highest-effort review are planned.
* **S9 and S8.3 cannot be finished without a subscription lifecycle.** Do not simulate one inside Omniview.
