# Omniview v2 — Software Requirements Specification

**Status:** draft, 2026-10-04. The completed SRS for Omniview's second
SPUTO pass, built on CM's seed (`docs/Omniview_SPUTO_v2_Seed.md`, FiSH
PR #60). **Planning only: build, Terraform apply and deploy remain
suspended** until Femi says otherwise. Companions:
`docs/Omniview_v2_Use_Cases.md`, `docs/Omniview_v2_Backlog.md`.

**Labels, kept from the seed.** **DECIDED** = Femi said it.
**PROPOSED** = a suggestion, not agreed. **OPEN** = not decided.
**CHALLENGE** marks a place where I tested the seed against the code
(read 2026-10-04, references in §8) and the evidence changes, narrows or
adds to it. Nothing marked CHALLENGE overrides a DECIDED statement; each
says what Femi's decision requires in practice and asks the question that
follows. Where this document and the 2026-10-03 documents differ, this
one reflects the newer direction.

**Revision 2026-10-04 (same day): never internet-facing.** Femi: *"IT CAN
NEVER BE INTERNET FACING."* The first draft of this SRS, like the seed it
was built on, had tenants' browsers calling Omniview directly. That is
ruled out, and the corrected seed (FiSH PR #61) now says so. This
revision removes every direct tenant-to-Omniview path: tickets arrive
**only through a FiSH service over the private network**, and replies are
pulled back the same way. Everything in §3, §5, §6, §9 and the use cases
that depended on the old shape has been redone. The relay service is
PROPOSED to be EA (CM's proposal, supported by the evidence below), and is
still Femi's to confirm.

---

## 1. Introduction and Scope

### 1.1 Purpose (DECIDED)

Omniview is Prodeo Capital's read-only view across all tenancies, for two
purposes: **Product Support** (a tenant's Owner Admin raises a ticket from
inside FiSH; a Prodeo operator answers it from Omniview) and **Market
Support** (aggregate, non-identifying market reports for Prodeo Capital).
The health strip and the tenant overview stay as supporting tools.

### 1.2 Principles (all DECIDED)

1. **Read-only toward every other FiSH service.** Omniview reads; it never writes into any tenancy's data ("It is NOT Omniview's business to write into any tenancy's data"). It writes only to its own database. (NFR-OV-6)
2. **Omniview owns its own data:** support tickets and replies, the daily currency rate table (gold and fiat, downloaded and stored by Omniview), and optionally report snapshots. Nothing else.
3. **EA is not Omniview.** EA is the tenancy's own mini-Omniview; owner-and-staff communication continues there unchanged. Product support to Prodeo Capital is a separate channel.
4. **Only a tenant's Owner Admin raises a ticket.** Employees do not.
5. **FiSH pulls; Omniview never pushes** a reply or notification into FiSH or a tenancy.
6. **Resolving a ticket changes only Omniview's own record.**
7. **Non-identification is sacrosanct.** No cohort size ever waives it. (NFR-OV-7)
8. **Reports are unaudited.** Prodeo Capital is engaged as accountants, not auditors.
9. **Gold is the base currency** for Prodeo Capital's market analysis.
10. **Omniview is never internet-facing.** It is reachable only on Prodeo's private network. A tenant's browser never reaches it: a ticket arrives only through a FiSH service, over the private network, and replies come back the same way. No public hostname, no public listener rule, no public certificate. (NFR-OV-8)

### 1.3 The problem, restated for v2

Product support today runs through EA: any active Membership in a tenant
can post to an operator thread, the operator replies through EA's
operator routes, and EA emails each side. That puts Prodeo's own support
queue inside a tenancy's own communication system, and lets any employee
(not only the owner) raise a call. Meanwhile Prodeo Capital has no way
to describe the SME market it serves: how many tenants, how many staff,
how capitalised, how leveraged. v2 gives each a home in Omniview,
without Omniview ever touching tenancy data.

### 1.4 In scope, deferred, out of scope

| In scope | Deferred | Out of scope |
|---|---|---|
| Product Support tickets | **Education Runtime status** (an industry sub-segment; its own SPUTO. `docs/omniview-er-status-sputo` stays unmerged) | Any per-tenant financial figure, ever |
| Market reports: tenants, staff, shareholders' funds, leverage | Per-industry specialisations beyond the generic segment | Any write into EA, GL or another service |
| Health strip, tenant overview (supporting) | A real operator identity system (see D13: raised from "parked" to "decide") | Audit assurance |

### 1.5 Actors

Tenant **Owner Admin** (raises tickets, reads replies, grants consent);
Prodeo **operator** (answers tickets, views health, overview, reports);
Prodeo Capital as consumer of market reports. **CHALLENGE (D20):** who
reads the reports is not stated, and it changes the rules (§7.1).

---

## 2. Overall Description

### 2.1 Context

```
Owner Admin --FiSH chat--> EA (public, existing; authenticates the Owner Admin)
EA --private network, service-to-service auth--> Omniview   (ticket in; replies PULLED back the same way)
Operator --private access only--> Omniview   (how: OPEN, D4)
                (never a tenant browser to Omniview)
Omniview --HTTPS, controlled egress, DAILY--> rate provider   (downloads currency and gold rates; Omniview stays private inbound)
Omniview --GET operator---> EA   (tenant overview; tenant + staff counts; consenting tenant list)
Omniview --GET (new)------> GL   (operator-only, totals-only aggregate; does not exist yet)
GL --GET (new, private)--> EA consent route, and Omniview published-rate route   (GL fetches both itself; the caller supplies neither)
Omniview --GET /health----> GL, POP, SOP, IM, HR
Omniview --own DB---------> tickets, replies, gold rates, (optional) snapshots
```

### 2.2 Verified starting facts (read 2026-10-04)

- **WEB has no backend of its own**, but it already calls EA, GL, POP, SOP, IM and HR directly as its backends, all public, with the user's Cognito token. So the relay cannot be WEB; it must be one of those public FiSH services.
- **EA already authenticates exactly the caller we need.** `GET /me` carries `tenants[].tenantId` and `tenants[].isOwnerAdmin` (exactly one Owner Admin per tenant), from active Memberships only, and EA has an Owner-Admin gate (`authorizeTenantOwnerAdmin`) that GL also mirrors. EA also already hosts the tenant-side support chat and the email notifications. An EA relay therefore needs no new identity logic, and Omniview needs none at all.
- **Service-to-service authentication is an established pattern here.** POP, SOP, IM and HR call GL and each other with Cognito service-account credentials (a distinct audience per caller). Omniview verifying an `ea` service credential is the same pattern, not a new mechanism.
- **GL has no cross-tenant read path.** Every query is keyed by `companyId`, behind a tenant check. The only multi-caller exception is service-account callers, which skip the EA check.
- **GL's ledger unit is the Company, not the Tenant.** A tenant has many Companies (the Purse example is one Tenant with four), each in its own base currency.
- **GL has no balance-sheet as-of date** (it uses all posted activity), **no "debt" concept** (only LIABILITY accounts, classified CURRENT/NON_CURRENT; a seeded "Loans Payable" 2100 exists in most templates but users can add arbitrary liability accounts), and an unpersisted `Borrowing` aggregate.
- **No consent mechanism exists anywhere** for a tenant to permit aggregate use of its data (no table, column or route in EA, GL or WEB; only a plan in `docs/Women_SME_Support_Build_Brief.md`).
- **HR is single-tenant per deployment** and holds payroll employees, not logins. EA's `staffCount` is active Memberships.
- **EA's existing support chat** lets any active Membership post, emails the operator on a post, and emails the last sender on an operator reply.

### 2.3 Constraints

Same as §1.2, plus: deploys through CM only; infrastructure applies are
Femi's (the Terraform state has drifted, so any apply is targeted with a
reviewed plan); **private network only** (principle 10): the shared load
balancer is public, so Omniview cannot sit behind it, and the previously
merged `omniview.tf` (public ALB rule, certificate and DNS) was reverted
for that reason; the shared RDS instance has a history of connection
exhaustion, so Omniview's pool stays small.

---

## 3. Product Support

| ID | Requirement | Status |
|---|---|---|
| FR-OV-S1 | A chat started inside FiSH by a tenant's Owner Admin creates a ticket owned by Omniview, **delivered by a FiSH service over the private network, never by a tenant's browser** | DECIDED |
| FR-OV-S2 | A Prodeo operator triages and answers tickets from Omniview | DECIDED |
| FR-OV-S3 | Tickets and replies live in Omniview's own database, never written into EA or any service | DECIDED |
| FR-OV-S4 | The Owner Admin sees replies in the FiSH chat, pulled from Omniview **through the same relay**. Omniview never pushes | DECIDED |
| FR-OV-S5 | EA's tenancy-internal communication is unchanged and separate | DECIDED |
| FR-OV-S6 | Disposition of EA's existing operator-thread messages | OPEN (D2) |
| FR-OV-S7 | Closing a ticket changes only Omniview's own record | DECIDED |
| FR-OV-S8 | Ticket states: Open, Answered, Closed (an Owner Admin follow-up on an Answered ticket reopens it) | PROPOSED |
| FR-OV-S9 | The Owner Admin check happens **in the relay (EA), before anything reaches Omniview**: EA verifies the user's token, confirms they are Owner Admin of the tenant concerned, and sends Omniview the tenant id and the user's identity. Omniview accepts these only from an authenticated relay, never from any other caller | PROPOSED |
| FR-OV-S10 | The relay returns an Owner Admin only tickets of tenants they are Owner Admin of; every other ticket is invisible to them, including its existence. Omniview additionally scopes every read by the tenant id the relay supplies | PROPOSED |
| FR-OV-S14 | The relay is a pass-through: **it stores no ticket content** (no copy in EA's database or logs beyond metadata such as ids and timestamps). Tickets live only in Omniview (FR-OV-S3) | PROPOSED |
| FR-OV-S15 | If Omniview is unreachable the relay fails closed with a clear error and the widget keeps the draft; it never falls back to EA's old operator-thread store for new tickets | PROPOSED |
| FR-OV-S16 | Abuse controls sit at the **public edge** (the relay): per-tenant ticket quota, body and field size limits. Omniview repeats the size limits defensively. The platform has no rate limiting today, so the relay's limits are new work in EA | PROPOSED |
| FR-OV-S11 | An ordinary employee who opens the chat is told to ask their Owner Admin, and keeps EA's internal chat. The relay rejects an employee's ticket in any case; hiding the control is a courtesy | PROPOSED |
| FR-OV-S12 | A ticket carries `tenantId` as a reference only; Omniview never resolves it into tenancy data beyond the tenant's name for display | DECIDED (reference-only) / PROPOSED (name lookup) |
| FR-OV-S13 | Ticket content is stored with a retention period and can be exported or erased on a verified request (D17) | PROPOSED |

**CHALLENGE on notifications (D12).** The seed says Omniview never pushes
a notification. Today EA *emails* the other party on every message. If
"no push" includes email, an Owner Admin learns of a reply only by
opening FiSH, which for a support channel is a real usability cost. If
email is allowed, it is a message to a person's mailbox, not a write into
FiSH or tenancy data. I recommend allowing it (a bare "you have a reply",
no ticket text), because it writes nothing into any tenancy; but this is
Femi's call, so it is a decision, not an assumption. **Private-network
consequence:** if Omniview sends the email it needs controlled outbound
access to SES from its private subnets (CM); the alternative is the relay
(EA, which already has an email gateway) sending it after noticing a reply,
which needs the relay to poll Omniview. Both keep Omniview off the
internet inbound.

---

## 4. Market Support

| ID | Requirement | Status |
|---|---|---|
| FR-OV-M1 | Report number of tenants and number of staff. **CHALLENGE (D15):** "staff" can only mean *active system users* (EA Memberships); HR is single-tenant per deployment and holds payroll records, so it cannot give a platform-wide count. Reports label it "staff with FiSH access" | DECIDED / PROPOSED (definition) |
| FR-OV-M2 | Capitalisation = aggregate shareholders' funds from standard balance-sheet figures. (GL's `totalEquity` includes computed retained earnings) | DECIDED |
| FR-OV-M3 | Leverage as **both** liabilities-to-equity and debt-to-equity, each a ratio of aggregate totals, never an average of per-tenant ratios | DECIDED (ratio-of-totals PROPOSED) |
| FR-OV-M3a | **CHALLENGE (D6).** Liabilities-to-equity is computable from GL's existing `totalLiabilities`/`totalEquity`. Debt-to-equity is **not reliably computable today**: GL has no "debt" designation, and inferring it from account code or name is a heuristic users can defeat. v2 therefore sequences: liabilities-to-equity first; debt-to-equity once GL has an explicit debt designation (PROPOSED: a flag on LIABILITY accounts, set by the seeded Loans Payable accounts and settable by the tenant) and reports coverage (share of cohort that has it set). This does not drop Femi's "both"; it states what "both" requires. **Update, D6: Femi answered "liabilities".** If CM's reading is confirmed there is one ratio, total liabilities to shareholders' funds, and the debt problem and the GL debt flag fall away; this requirement is kept until he confirms | DECIDED (both) / PROPOSED (sequencing) |
| FR-OV-M4 | Whole market and by segment. **Industry attaches to each Company, not the tenant (D14, verified: EA stores it per Company)**, so a segment is built from Companies. Industry is a segment dimension (DECIDED); jurisdiction and tenant segment PROPOSED | DECIDED / PROPOSED |
| FR-OV-M5 | All fiat translated to gold; gold is the base currency. **Gold is not used for client reporting; fiat is** (Femi). It exists only so any statement from any jurisdiction can be translated to a common factor for Prodeo's investment and market analysis (FR-OV-M17). **Gold needs an explicit precision rule in `common` before it can be a `Money` currency (D23a DECIDED, D25)** | DECIDED |
| FR-OV-M5a | **CHALLENGE (D10, D14, D23a, D23b).** Gold translation happens inside GL, so the cohort and concentration rules are applied to *gold-converted* per-tenant values at the source and those values never leave GL. (GL's figures are per-Company in each Company's own currency, so converting after the fact in Omniview would break the concentration rule.) **The caller never supplies rates:** GL reads the published rate for the report date itself from Omniview's rate table (FR-OV-M12). A caller-supplied rate is a free parameter: varying one currency's rate and watching the gold total move reveals that currency's subtotal, and if one tenant holds that currency, that tenant's value | PROPOSED (call shape DECIDED by D22) |
| FR-OV-M5b | **CHALLENGE (D14).** The market unit is the **Tenant**, not the Company: GL sums a tenant's Companies before any cohort or concentration test. Consolidation does not exist, so intercompany balances inside one tenant can double count; reports state this limitation until it is addressed | PROPOSED |
| FR-OV-M5c | **CHALLENGE (D14).** Balances are as at one common date for the whole report (PROPOSED: month-end, using the closing rate that day). GL has no as-of parameter today, so this is new GL work. Mixing each tenant's own latest balance would misstate the market | PROPOSED |
| FR-OV-M6 | Every figure obeys NFR-OV-7, **including the tenant and staff counts** (a segment with two tenants reveals both) | DECIDED |
| FR-OV-M7 | Every report carries an "unaudited, compiled from tenants' own books, no audit assurance" label, plus the gold rate, its source and the date used | DECIDED |
| FR-OV-M8 | **CHALLENGE (D16, D22).** Only tenants whose Owner Admin has granted consent are included. Consent is a tenant-owned, versioned, revocable record in EA (new). **GL determines the consenting set itself** by reading it from EA at call time; the caller cannot choose, narrow or vary it. A caller-supplied allow-list would let anyone request totals for two lists that differ by one tenant and subtract, which defeats NFR-OV-7 | PROPOSED (call shape DECIDED by D22) |
| FR-OV-M9 | **CHALLENGE (D11).** Reports are computed fresh each time and not stored by default. A stored snapshot freezes a tenant's contribution after it revokes consent and gives an attacker successive totals to subtract (§7.1). If trends are wanted later, store only values that already passed every test, with revocation handling designed first | PROPOSED |
| FR-OV-M10 | A suppressed cell is a normal, displayed state ("insufficient cohort"), not an error. Before launch the platform has no real tenants, so most cells will be suppressed for some time | PROPOSED |
| FR-OV-M11 | **Report dates are a fixed menu (month-end only), and cohort churn is controlled.** A caller cannot pick arbitrary pairs of dates, because when the consenting set changes between two dates (a tenant consents or revokes) the difference between their totals isolates that tenant. Beyond fixed dates: consent changes take effect at the next period boundary, and GL withholds a figure for a date when its cohort differs from the cohort of any previously published date by at least one but fewer than the minimum number of tenants. This needs GL to keep its own record of published cohorts (new GL-owned state, not tenant data; but it is **reporting state living in the ledger engine, a coupling cost** the GL design must weigh against alternatives, such as limiting consent changes so the rule is rarely needed) | PROPOSED |
| FR-OV-M12 | **Rates are published data, not parameters.** Omniview's rate table has exactly one effective rate per currency per report date, is append-only, and each correction carries an audited reason and never silently changes a report already published. GL accepts only the published rate for the date, and rejects a value outside validated bounds. **D23b, DECIDED: Omniview owns the rate values.** The people who maintain or correct rates and the people who read reports should be different roles (D20), since someone who can do both could craft a rate and read the result | PROPOSED |
| FR-OV-M13 | **Cohort and concentration tests apply at both tenant level and company level, the stricter governing.** A multi-industry tenant appears in each of its industries, so an industry cell can be dominated by one Company even when no tenant dominates the market | PROPOSED (D14 reading PENDING) |
| FR-OV-M14 | **Daily rate download (DECIDED, D23b).** Omniview downloads rates once a day from an external provider (D26) over HTTPS, through a controlled egress path, as a scheduled job. The job alerts on failure (this is the first scheduled job in a service that has none, so it needs its own monitoring) | DECIDED / PROPOSED (mechanics) |
| FR-OV-M15 | **Rate provenance.** Each stored rate records its source, retrieval time and raw value; each is checked against the previous day's value within a bound and rejected for review if it falls outside; corrections are audited and never silently recompute a published report | PROPOSED |
| FR-OV-M16 | **A missed day.** Reports use fixed month-end dates (FR-OV-M11), so only the month-end closing rate truly matters. If that day's download failed, the report for that date is unavailable until the rate is backfilled from the provider's historical data or entered as an audited manual correction. A rate is never estimated or carried forward silently | PROPOSED |
| FR-OV-M17 | **Gold is analytics-only.** When gold is defined in `common` (D23a) it must not be selectable as a Company base currency or appear in WEB's currency lists, and no client-facing report shows gold. Client reports stay fiat | DECIDED (scoping) / PROPOSED (guardrail) |

---

## 5. Supporting tools (retained)

| ID | Requirement | Status |
|---|---|---|
| FR-OV-1..5 | Platform health: parallel checks, GL via its `X-Request-Id`, latency, unconfigured = down (built, merged, not live) | Built |
| FR-OV-6..8 | Tenant overview from EA `GET /operator/tenants`, no financial data | Built |
| FR-OV-9, 11 | Read-only view of EA's existing operator threads (interim) | Built; **retire when tickets exist? D1** |
| FR-OV-10 | Operator reply written into EA | **WITHDRAWN.** The merged proxy and reply box are removed (backlog 3.6) |

---

## 6. Non-functional requirements

| ID | Requirement | Status |
|---|---|---|
| NFR-OV-1..4 | As in the 2026-10-03 SRS (parallel health, per-operator attribution, no EA-side change required for the supporting tools, no financial data in the overview) | Kept. NFR-OV-3 is narrowed: v2 *does* need EA changes (consent record, §4 FR-OV-M8), none of them for the supporting tools |
| NFR-OV-5 | Deployed the same way every sibling is (ECS/Fargate, Jenkins CI/CD) | Kept (CM restored this ID) |
| NFR-OV-6 | Read-only toward every other service; verified by a test that outbound gateways expose no write method. **The one call that seemed to need a POST (the GL aggregate) is settled by D22; the rule stays GET-only, confirmed by D22 (DECIDED)** | DECIDED |
| NFR-OV-7 | **Non-identification.** No per-tenant figure or breakdown anywhere: view, API, export, log, stored snapshot. Cohort minimum determined statistically; plus a concentration rule (the stricter test governs); plus suppression that defeats differencing. Enforced in code, with tests that *try to defeat it*. Tenants' permission first | DECIDED |
| NFR-OV-8 | **Never internet-facing.** Reachable only on Prodeo's private network; **inbound** callers are the relaying FiSH service, GL (read-only, to fetch a published rate, FR-OV-M12, D23b DECIDED) and operators over private access, never a tenant's browser. No public hostname, listener rule or certificate. Calls into it are authenticated service-to-service and size-limited. (Corrected 2026-10-04, replacing a wrong earlier "inbound is internet-facing" requirement) | DECIDED |
| NFR-OV-9 | A new privileged read path in GL is audited, returns totals only, enforces cohort and concentration at source, and never logs per-tenant intermediate values | PROPOSED |
| NFR-OV-10 | **Tickets are untrusted input rendered in the operator's browser**, even though they now arrive through a relay over a private network: the text is still authored by a tenant. The operator console holds the operator token in browser storage, so a stored script in a ticket would steal a token that reads every tenant. Ticket text is always rendered as text (the ported component already does), the console sets a strict Content-Security-Policy, and the operator token is kept out of long-lived storage | PROPOSED |
| NFR-OV-11 | Omniview's database connection pool is small and bounded; a stateful service must not repeat the shared-RDS connection exhaustion | PROPOSED |
| NFR-OV-12 | Backups and a tested restore for the ticket database | PROPOSED |
| NFR-OV-13 | Each ticket and reply records who raised/answered it (Owner Admin identity as asserted by the relay, or named operator) for attribution | PROPOSED |
| NFR-OV-14 | Service-to-service authentication between the relay and Omniview: a Cognito service-account credential with its own audience, verified by Omniview (no defaults), plus network restriction to the relay's security group. Network position alone is not authentication | PROPOSED |
| NFR-OV-15 | Operators reach Omniview only by private access (D4); the console is never exposed on the shared public load balancer | DECIDED (private) / OPEN (how) |
| NFR-OV-16 | **Controlled egress.** Omniview makes outbound calls to the rate provider (and SES if D12 says so) only through an explicit, allow-listed egress path from its private network (private subnets with NAT or an allow-listed proxy), costed by CM. Never-internet-facing concerns inbound exposure; outbound internet access is a separate, deliberate and narrow exception | PROPOSED |

---

## 7. Data

| Data | Owner |
|---|---|
| Tenants, staff (Memberships), KYB, Owner Admin identity, **consent record (new)** | EA |
| Balance-sheet figures | GL (aggregate-only access, new) |
| Tickets and replies | **Omniview** |
| Currency rate table (downloaded daily from an external provider, stored with provenance) | **Omniview** |
| Report snapshots | None by default (D11) |

### 7.1 Non-identification, in design terms

The seed lists three defences. The evidence adds the attacks they must
answer, so the tests have something to try:

1. **Small cells.** A tenant or staff count for a segment of one or two. Cohort minimum applies to counts as well as money.
2. **Dominance.** One tenant holding most of a total identifies it by size. Concentration rule on the gold-converted tenant value (computed at source).
3. **Complementary suppression.** If a segment is suppressed but the whole market and the other segments are shown, the suppressed one is recoverable by subtraction. Suppression must cascade.
4. **Differencing over time.** A tenant joins, leaves or revokes consent, and two successive reports differ by exactly its contribution. No stored history by default (FR-OV-M9), and the consenting set is part of what must not be inferable.
5. **Differencing through the consenting set and the request parameters.** The *count of consenting tenants* is itself a figure and falls under the cohort rule. The set must be fixed by GL from EA, never chosen by the caller, or two calls with lists differing by one tenant would isolate it. Any parameter a caller can vary (date, segment, rates) must likewise not be able to isolate a tenant: dates and segments come from fixed menus, and suppression applies to every combination.
6. **Logs and errors.** Per-tenant intermediate values inside GL, in logs, traces or error messages.
7. **Varying the date.** Totals at two dates, with a cohort that changed between them, isolate the tenant that joined or left (FR-OV-M11). Month-end-only dates, period-boundary consent changes and GL's churn rule answer it.
8. **Varying the rate.** A caller-chosen rate exposes a single-currency tenant (FR-OV-M5a, M12). Answered by GL reading the one published rate itself.

Setting the numeric thresholds is a statistician's job; this SRS sets
the structure and the tests, not the numbers (D8).

### 7.2 Two audiences, one tension (D20)

An operator can already see every tenant by name in the overview, so
non-identification in the *report* protects against something other than
an operator reading it. It matters if reports are **published or shared**
(a registering body, investors, a press note), and it matters because an
operator who can see both a report and an overview could reconstruct.
The SRS therefore asks (D20): who receives these reports, and may the
same operators see both the overview and the reports, or should those
roles be separate?

---

## 8. Evidence (read 2026-10-04)

`GL/.../domain/ledger/account_type.kt`, `account_classification.kt`,
`chart_of_accounts_template.kt` (Loans Payable 2100; INDIVIDUAL "Loans"
2000; NON_PROFIT none), `borrowing.kt` (domain only), `balance_sheet.kt`
(`totalLiabilities`, `totalEquity`, computed retained earnings),
`ComputeBalanceSheetUseCase.kt` (all posted entries, no date),
`ledger_tables.kt` (`companyId`-scoped), `company.kt` (`tenantId`,
`baseCurrency`), GL `Auth.kt` (`authorizeTenant`, service-account bypass).
`EA/.../MeRoutes.kt`, `Dtos.kt` (`isOwnerAdmin`), EA `Auth.kt` (`authorizeTenantOwnerAdmin`), `OperatorTenantOverviewRoutes.kt`
(`staffCount` = active Memberships), `MessageRoutes.kt`,
`SubmitToOperatorThreadUseCase.kt`, `ReplyToOperatorThreadUseCase.kt`
(email on each side), `Auth.kt` (`authorizeOperator`, `authorizeTenantMember`).
`HR/.../Application.kt` (`HR_EA_TENANT_ID`), `HR V1__baseline.sql`.
`POP/.../Auth.kt` (JWT env, `EaMembershipGateway`). `WEB/package.json`,
`config.ts`, `SupportChatWidget.tsx`, `supportThread.ts`. Consent: grep
across EA/GL/WEB/HR/POP/SOP/IM found none.

---

## 9. Open decisions

**Femi's answers, 2026-10-04, relayed by CM.** Statuses below: **DECIDED** means Femi's own words, quoted; **PENDING** means CM's reading of those words, which Femi has been asked to confirm and which nothing should be built on until he does.

Numbering follows the **corrected seed** (PR #61) for D1–D11: D3 and D4
changed meaning there. D12–D25 are new in this pass. "Evidence" says what
the code shows; "Recommendation" is mine, not agreed.

| # | Decision | Evidence / Recommendation | Owner |
|---|---|---|---|
| D1 | Retire the interim read-only EA thread view when tickets exist | Recommend yes, once D2 is settled; it duplicates a channel that moves | Femi |
| D2 | What happens to EA's existing operator-thread messages | Recommend leave as read-only legacy in EA; do not migrate content authored under different rules | Femi |
| D3 | Which FiSH service relays tickets to Omniview, and how it authenticates to Omniview privately | **Recommend EA** (CM's proposal; the evidence agrees): EA already authenticates the Owner Admin (`/me`, `authorizeTenantOwnerAdmin`), knows the tenant, hosts today's support chat and has an email gateway. WEB cannot (no backend). Authentication to Omniview: a Cognito service-account credential with its own audience, the pattern POP/SOP/IM/HR use to call GL, plus a security-group restriction (NFR-OV-14). EA stays not-Omniview: the relay stores nothing (FR-OV-S14). The alternative, a small dedicated gateway service, adds a deployable for no gain today | CM + EA, then Femi |
| D4 | How operators reach a private Omniview | **OPEN, CM's lane.** The shared load balancer is public, so Omniview needs another path: a VPN, an SSM port-forward, or another internal-only route. It also decides what "the operator opens the console" means for a growing ops team, and when WEB's `/operator` can be retired (it is public today). Not designed here | CM + Femi |
| D5 | Ticket model: fields, visibility, attachments, retention, notifications | Proposal in the Use Cases; attachments **out for v2** (an upload surface carrying tenant files is a large risk for little value) | Omniview + Femi |
| D6 | What counts as debt; segment list beyond industry | **Femi: "liabilities" (DECIDED).** CM's reading, **PENDING**: there is no separate debt measure; one leverage ratio, **total liabilities to shareholders' funds** (the two ratios named earlier coincide). If confirmed, FR-OV-M3a's "no debt designation" problem disappears and no GL debt flag is needed (8B.4). Segment list beyond industry: still open | Femi to confirm |
| D7 | Gold price source, which price, as-of date | Recommend closing rate at the report date, source named on every report | Femi |
| D8 | Cohort method, values, concentration threshold | **Femi: "This will be determined later" (DECIDED: parked).** The structure in §7.1 stays; the numbers wait for a statistician. **It is a launch gate:** no market figure may be published until the numbers are set, since NFR-OV-7 cannot be enforced without them | Femi + statistician, later |
| D9 | Tenants' permission: wording, mechanism, registering body's rules | A consent record does not exist (§2.2); this decision also creates EA work (D16) | Femi + solicitor |
| D10 | Where aggregates are computed | **GL**, reading the consenting set from EA and the published rate from Omniview itself (FR-OV-M5a, M8, M12, D22, D23b); a route with its own authorization, not publicly reachable beyond gating | GL + Omniview + CM |
| D11 | Store snapshots or compute fresh | **Compute fresh** (FR-OV-M9) | Omniview |
| D12 | May an Owner Admin be emailed about a reply? Who sends | See §3. Recommend yes, a bare "you have a reply" with no ticket text. Sender is either Omniview (needs controlled SES egress from private subnets) or the relay (needs to poll). Both keep Omniview off the internet inbound | Femi, then CM + EA |
| D13 | Operator authentication | The token bridge was accepted for a handful of operators reading status. It now guards a queue of tenant free text plus market data. Private access (D4) adds a network layer; it does not replace operator identity. Recommend deciding before Product Support goes live whether operators move to a Cognito group; calls to EA's operator routes still need EA's tokens or an EA change | Femi + CM + EA |
| D14 | Market unit, as-of date, currency basis | **Femi: the unit being the tenant and one common month-end is "doable but it is the company that determines the industry" (DECIDED).** Verified: `industryType` is stored **per Company** in EA (migration V13); GL has no industry field. CM's reading, **PENDING**: industry attaches to each Company (a tenant may own Companies in different industries), so industry segments are built from Companies and a multi-industry tenant appears in each of its industries; cohort and concentration tests apply at **both tenant and company level, the stricter governing** (FR-OV-M13). Open sub-question: D24 (staff by industry) | Femi to confirm |
| D15 | Definition of "staff" | Active EA Memberships, labelled "staff with FiSH access" | Femi |
| D16 | Consent: who owns the record, how revocation works | EA owns it (tenant data); Owner Admin grants/revokes; wording versioned; revocation excludes the tenant from the next report | Femi + EA |
| D17 | Ticket data protection: lawful basis, retention, erasure/export, hosting location | Tickets hold tenant free text, possibly personal data, across several jurisdictions, in one UK-region database | Femi + solicitor |
| D18 | Abuse controls at the public edge | The relay (EA) is now the public edge for support: per-tenant ticket quota, size limits (FR-OV-S16). The platform has no rate limiting anywhere, so this is new work in EA; Omniview repeats size limits defensively | EA + CM |
| D19 | Order of Support vs Market | Agree: Support first | Femi |
| D20 | Who receives market reports, and must operator roles be separated | See §7.2 | Femi |
| D21 | Does the relay have a quota-free path for Prodeo's own staff to open a ticket on a tenant's behalf (for example after a phone call)? | Recommend no for v2: an operator creating a ticket would be a different actor and a different trust path. Operators answer; tenants raise | Femi |
| D22 | The shape of the GL aggregate call, and NFR-OV-6's wording | **Femi: "Agree" with option A (DECIDED).** A GET whose request is only a fixed report date and a segment; GL reads the consenting set from EA itself and the published rate itself, so no allow-list and no rate come from the caller. NFR-OV-6 stays GET-only. Options B and C are closed. Consequences: GL gains a read dependency on an EA consent route (8B.1), and needs a private path to EA's operator route, which is public today (7B.3) | Settled |
| D23a | **The currency model: where gold is defined** | **Femi: "We have a common folder where money is placed." (DECIDED.)** Gold is defined in the `common` repo with `Money` and the other currency definitions. **Verified need:** `XAU` has -1 default fraction digits in the JDK, so `Money(123.456, XAU)` rounds to 120 today; `common` needs an explicit unit and precision rule (D25, backlog 8B.4a). `common` is consumed as source by GL/SOP/POP/IM/HR, so this is a wide change reviewed as one | Settled; detail in D25 |
| D23b | **Where the rate values live** | **Femi: "Omniview downloads and stores the rates" and "Daily rates has to be downloaded by Omniview" (DECIDED).** Omniview owns the rate values, downloads them **daily** from an external source and stores them; GL reads the one published rate for the report date from Omniview. CM's GL-holds-rates proposal is withdrawn, and the layering concern is overridden by this decision. **Costs, stated rather than hidden:** a private GL-to-Omniview read path (7B.3) and a third service identity (8B.9); GL's aggregate route depends on Omniview being up, and because Omniview calls GL which calls Omniview back within one request, the rate read must be a separate lightweight route with its own timeout (a published rate is immutable for its date, so GL can safely cache it); and **Omniview now makes outbound internet calls** while staying private, so it needs a controlled egress path (FR-OV-M14, NFR-OV-16). **Scoping fact (Femi): gold is not used for client reporting; fiat is.** Gold translation exists so that any financial statement from any jurisdiction can be put on a common factor for Prodeo's investment and market analysis (FR-OV-M17). The earlier IAS 21 argument is withdrawn: GL's client foreign-exchange handling (fiat) is a separate concern and does not share this table. Cohort-churn rule (FR-OV-M11) unchanged | Settled |
| D24 | Staff by industry | Staff are assigned **per Company** through Membership assignments in EA, so "staff by industry" needs a rule: count a member once per industry they are assigned in, or once per tenant in a primary industry, or count assignments rather than people. Whole-market staff is unaffected (distinct active Memberships, D15). Recommend counting distinct people per industry, and saying so on the report | Femi |
| D25 | Gold unit and precision, and who changes `common` | Which gold unit (troy ounce, as `XAU` means, or grams) and how many decimal places, written as an explicit rule in `common` (FR-OV-M5; the home in `common` is DECIDED, D23a). A change to `Money`'s currency handling touches all five consumers of `common`, so it is a wide change that needs reviewing as one, not a mechanical edit. **Gold is analytics-only, so keep the change minimal and additive**: define it as an analytics currency that cannot be chosen as a Company base currency or appear in client currency lists (FR-OV-M17), rather than adding it to the set clients can use. Owner is unassigned (the GL session by default); CM coordinates | Femi, GL, CM |
| D26 | Rate provider(s), data licence and cost | Which provider supplies fiat and gold rates, whether its terms allow commercial use by an accountancy firm (and storing the series), the cost, and whether a second source is kept as a cross-check. A licence decision as much as a technical one | Femi (+ solicitor for the licence) |
| D27 | Which currencies are downloaded | All currencies the provider offers, or only those in use by consenting Companies' books plus gold. Femi's wording ("any financial statement from any jurisdiction") reads as all; storing only what is used is smaller and cheaper. Note the platform's existing rule that only some currencies are onboarded for client books, which does not bind a rate table that serves analysis | Femi |

---

## 10. Risks

The seed's six stand with its correction applied (risk 2 is now "intake
crosses a trust boundary", not "internet-facing intake"): a new privileged
read path in GL; the intake crossing a trust boundary; a stateful service
on a shared RDS with a September connection incident; the operator-token
bridge; drifted Terraform state; and non-identification failure as the
worst outcome. Additions from this pass:

7. **Stored script via ticket text** (NFR-OV-10). It does not depend on Omniview being public: tenant-authored text reaches an operator's browser either way.
8. **Hidden coupling:** Market Support needs work in GL (route, as-of, debt flag, FX), EA (consent) and legal, none of which Omniview controls; schedule risk is mostly outside this repo. Support now also needs EA (the relay), so Wave 7 is no longer "no change in any other service".
9. **Launch-time emptiness:** with few or no real tenants, every market figure is suppressed; the product must still look correct (FR-OV-M10).
10. **Support-channel regression:** moving Owner Admin support out of EA changes what employees can do today (FR-OV-S11).
11. **EA becomes the public edge for support.** The relay is internet-facing even though Omniview is not, so it needs the quota, size limits and Owner-Admin gate (FR-OV-S9, S16) and must never store ticket content (FR-OV-S14). A relay that quietly keeps a copy would recreate the tenancy-data-in-another-system problem this design avoids.
12. **Private access is an operational cost.** A VPN or port-forward for every operator (a team is being hired) is friction; a lazy workaround that exposes the console would break the decision. D4 must produce something operators will actually use.
13. **A rate-provider dependency Omniview did not have.** A daily external download brings a licence question (D26), a failure mode (a missed month-end, FR-OV-M16), a provenance duty (FR-OV-M15), a controlled egress path to build and cost (NFR-OV-16), and a circular request chain (Omniview to GL back to Omniview for the rate). Each is manageable; together they are real work in a service that today is nearly stateless.
