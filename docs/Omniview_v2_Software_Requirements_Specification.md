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
2. **Omniview owns its own data:** support tickets and replies, the gold rate table, and optionally report snapshots. Nothing else.
3. **EA is not Omniview.** EA is the tenancy's own mini-Omniview; owner-and-staff communication continues there unchanged. Product support to Prodeo Capital is a separate channel.
4. **Only a tenant's Owner Admin raises a ticket.** Employees do not.
5. **FiSH pulls; Omniview never pushes** a reply or notification into FiSH or a tenancy.
6. **Resolving a ticket changes only Omniview's own record.**
7. **Non-identification is sacrosanct.** No cohort size ever waives it. (NFR-OV-7)
8. **Reports are unaudited.** Prodeo Capital is engaged as accountants, not auditors.
9. **Gold is the base currency** for Prodeo Capital's market analysis.

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
Owner Admin --browser (WEB widget)--> Omniview   ticket in; replies PULLED by the widget
Operator    --browser-------------> Omniview
Omniview --GET /me--------> EA   (verify the caller is OWNER_ADMIN of tenant X)
Omniview --GET operator---> EA   (tenant overview; tenant + staff counts; consenting tenant list)
Omniview --GET (new)------> GL   (operator-only, totals-only aggregate; does not exist yet)
Omniview --GET /health----> GL, POP, SOP, IM, HR
Omniview --own DB---------> tickets, replies, gold rates, (optional) snapshots
```

### 2.2 Verified starting facts (read 2026-10-04)

- **WEB has no backend.** It is a static React PWA calling every service directly with the user's Cognito token. So the chat widget can only reach Omniview directly from the browser; "proxied via WEB" (seed open decision 3/4) is not an available option.
- **A proven pattern exists for authenticating a human at a sibling.** POP/SOP/IM/GL verify a Cognito JWT against configured issuer, audience and JWKS (no defaults), then ask EA `GET /me` with the caller's own token. `/me` carries `tenants[].tenantId` and `tenants[].isOwnerAdmin` (exactly one Owner Admin per tenant), from active Memberships only. Omniview can prove "Owner Admin of tenant X" with no EA change.
- **GL has no cross-tenant read path.** Every query is keyed by `companyId`, behind a tenant check. The only multi-caller exception is service-account callers, which skip the EA check.
- **GL's ledger unit is the Company, not the Tenant.** A tenant has many Companies (the Purse example is one Tenant with four), each in its own base currency.
- **GL has no balance-sheet as-of date** (it uses all posted activity), **no "debt" concept** (only LIABILITY accounts, classified CURRENT/NON_CURRENT; a seeded "Loans Payable" 2100 exists in most templates but users can add arbitrary liability accounts), and an unpersisted `Borrowing` aggregate.
- **No consent mechanism exists anywhere** for a tenant to permit aggregate use of its data (no table, column or route in EA, GL or WEB; only a plan in `docs/Women_SME_Support_Build_Brief.md`).
- **HR is single-tenant per deployment** and holds payroll employees, not logins. EA's `staffCount` is active Memberships.
- **EA's existing support chat** lets any active Membership post, emails the operator on a post, and emails the last sender on an operator reply.

### 2.3 Constraints

Same as §1.2, plus: deploys through CM only; infrastructure applies are
Femi's (the Terraform state has drifted, so any apply is targeted with a
reviewed plan); the shared RDS instance has a history of connection
exhaustion, so Omniview's pool stays small.

---

## 3. Product Support

| ID | Requirement | Status |
|---|---|---|
| FR-OV-S1 | A chat started inside FiSH by a tenant's Owner Admin creates a ticket owned by Omniview | DECIDED |
| FR-OV-S2 | A Prodeo operator triages and answers tickets from Omniview | DECIDED |
| FR-OV-S3 | Tickets and replies live in Omniview's own database, never written into EA or any service | DECIDED |
| FR-OV-S4 | The Owner Admin sees replies in the FiSH chat, pulled from Omniview | DECIDED |
| FR-OV-S5 | EA's tenancy-internal communication is unchanged and separate | DECIDED |
| FR-OV-S6 | Disposition of EA's existing operator-thread messages | OPEN (D2) |
| FR-OV-S7 | Closing a ticket changes only Omniview's own record | DECIDED |
| FR-OV-S8 | Ticket states: Open, Answered, Closed (an Owner Admin follow-up on an Answered ticket reopens it) | PROPOSED |
| FR-OV-S9 | **CHALLENGE.** The tenant on a ticket is derived server-side from the verified caller (`/me`), never trusted from the request. The caller supplies *which of their owned tenants* only if they own more than one, and the server checks it against `/me` | PROPOSED |
| FR-OV-S10 | An Owner Admin can list and read only tickets of tenants they are Owner Admin of; every other ticket is invisible to them, including its existence | PROPOSED |
| FR-OV-S11 | An ordinary employee who opens the chat is told to ask their Owner Admin, and keeps EA's internal chat | PROPOSED |
| FR-OV-S12 | A ticket carries `tenantId` as a reference only; Omniview never resolves it into tenancy data beyond the tenant's name for display | DECIDED (reference-only) / PROPOSED (name lookup) |
| FR-OV-S13 | Ticket content is stored with a retention period and can be exported or erased on a verified request (D17) | PROPOSED |

**CHALLENGE on notifications (D12).** The seed says Omniview never pushes
a notification. Today EA *emails* the other party on every message. If
"no push" includes email, an Owner Admin learns of a reply only by
opening FiSH, which for a support channel is a real usability cost. If
email is allowed, it is a message to a person's mailbox, not a write into
FiSH or tenancy data. I recommend allowing email to the Owner Admin (and
to a Prodeo support mailbox on a new ticket), because it writes nothing
into any tenancy; but this is Femi's call, so it is a decision, not an
assumption.

---

## 4. Market Support

| ID | Requirement | Status |
|---|---|---|
| FR-OV-M1 | Report number of tenants and number of staff. **CHALLENGE (D15):** "staff" can only mean *active system users* (EA Memberships); HR is single-tenant per deployment and holds payroll records, so it cannot give a platform-wide count. Reports label it "staff with FiSH access" | DECIDED / PROPOSED (definition) |
| FR-OV-M2 | Capitalisation = aggregate shareholders' funds from standard balance-sheet figures. (GL's `totalEquity` includes computed retained earnings) | DECIDED |
| FR-OV-M3 | Leverage as **both** liabilities-to-equity and debt-to-equity, each a ratio of aggregate totals, never an average of per-tenant ratios | DECIDED (ratio-of-totals PROPOSED) |
| FR-OV-M3a | **CHALLENGE (D6).** Liabilities-to-equity is computable from GL's existing `totalLiabilities`/`totalEquity`. Debt-to-equity is **not reliably computable today**: GL has no "debt" designation, and inferring it from account code or name is a heuristic users can defeat. v2 therefore sequences: liabilities-to-equity first; debt-to-equity once GL has an explicit debt designation (PROPOSED: a flag on LIABILITY accounts, set by the seeded Loans Payable accounts and settable by the tenant) and reports coverage (share of cohort that has it set). This does not drop Femi's "both"; it states what "both" requires | DECIDED (both) / PROPOSED (sequencing) |
| FR-OV-M4 | Whole market and by segment. Industry is a segment dimension (DECIDED); jurisdiction and tenant segment PROPOSED | DECIDED / PROPOSED |
| FR-OV-M5 | All fiat translated to gold; gold is the base currency | DECIDED |
| FR-OV-M5a | **CHALLENGE (D10, D14).** Gold translation happens inside GL, using a rate table Omniview passes with the request, so the cohort and concentration rules are applied to *gold-converted* per-tenant values at the source and those values never leave GL. (GL's figures are per-Company in each Company's own currency, so converting after the fact in Omniview would break the concentration rule, which needs comparable per-tenant values.) | PROPOSED |
| FR-OV-M5b | **CHALLENGE (D14).** The market unit is the **Tenant**, not the Company: GL sums a tenant's Companies before any cohort or concentration test. Consolidation does not exist, so intercompany balances inside one tenant can double count; reports state this limitation until it is addressed | PROPOSED |
| FR-OV-M5c | **CHALLENGE (D14).** Balances are as at one common date for the whole report (PROPOSED: month-end, using the closing rate that day). GL has no as-of parameter today, so this is new GL work. Mixing each tenant's own latest balance would misstate the market | PROPOSED |
| FR-OV-M6 | Every figure obeys NFR-OV-7, **including the tenant and staff counts** (a segment with two tenants reveals both) | DECIDED |
| FR-OV-M7 | Every report carries an "unaudited, compiled from tenants' own books, no audit assurance" label, plus the gold rate, its source and the date used | DECIDED |
| FR-OV-M8 | **CHALLENGE (D16).** Only tenants whose Owner Admin has granted consent are included. Consent is a tenant-owned, versioned, revocable record in EA (new); Omniview obtains the consenting tenant list from EA and passes it to GL as an allow-list | PROPOSED |
| FR-OV-M9 | **CHALLENGE (D11).** Reports are computed fresh each time and not stored by default. A stored snapshot freezes a tenant's contribution after it revokes consent and gives an attacker successive totals to subtract (§7.1). If trends are wanted later, store only values that already passed every test, with revocation handling designed first | PROPOSED |
| FR-OV-M10 | A suppressed cell is a normal, displayed state ("insufficient cohort"), not an error. Before launch the platform has no real tenants, so most cells will be suppressed for some time | PROPOSED |

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
| NFR-OV-6 | Read-only toward every other service; verified by a test that outbound gateways expose no write method | DECIDED |
| NFR-OV-7 | **Non-identification.** No per-tenant figure or breakdown anywhere: view, API, export, log, stored snapshot. Cohort minimum determined statistically; plus a concentration rule (the stricter test governs); plus suppression that defeats differencing. Enforced in code, with tests that *try to defeat it*. Tenants' permission first | DECIDED |
| NFR-OV-8 | Inbound is internet-facing: real authentication, rate limiting, input and body-size limits. **CHALLENGE:** the platform has no rate limiting anywhere today (production-readiness assessment), so this is new platform work, not a setting | PROPOSED |
| NFR-OV-9 | A new privileged read path in GL is audited, returns totals only, enforces cohort and concentration at source, and never logs per-tenant intermediate values | PROPOSED |
| NFR-OV-10 | **CHALLENGE: tickets are untrusted input rendered in the operator's browser.** The operator console holds the operator token in browser storage, so a stored script in a ticket would steal a token that reads every tenant. Ticket text is always rendered as text (the ported component already does), the console sets a strict Content-Security-Policy, and the operator token is kept out of long-lived storage | PROPOSED |
| NFR-OV-11 | Omniview's database connection pool is small and bounded; a stateful service must not repeat the shared-RDS connection exhaustion | PROPOSED |
| NFR-OV-12 | Backups and a tested restore for the ticket database | PROPOSED |
| NFR-OV-13 | Each ticket and reply records who raised/answered it (Owner Admin identity or named operator) for attribution | PROPOSED |

---

## 7. Data

| Data | Owner |
|---|---|
| Tenants, staff (Memberships), KYB, Owner Admin identity, **consent record (new)** | EA |
| Balance-sheet figures | GL (aggregate-only access, new) |
| Tickets and replies | **Omniview** |
| Gold rate table | **Omniview** |
| Report snapshots | None by default (D11) |

### 7.1 Non-identification, in design terms

The seed lists three defences. The evidence adds the attacks they must
answer, so the tests have something to try:

1. **Small cells.** A tenant or staff count for a segment of one or two. Cohort minimum applies to counts as well as money.
2. **Dominance.** One tenant holding most of a total identifies it by size. Concentration rule on the gold-converted tenant value (computed at source).
3. **Complementary suppression.** If a segment is suppressed but the whole market and the other segments are shown, the suppressed one is recoverable by subtraction. Suppression must cascade.
4. **Differencing over time.** A tenant joins, leaves or revokes consent, and two successive reports differ by exactly its contribution. No stored history by default (FR-OV-M9), and the consenting set is part of what must not be inferable.
5. **Differencing through the allow-list itself.** Passing GL a consent list makes the *count of consenting tenants* a figure; it falls under the cohort rule too.
6. **Logs and errors.** Per-tenant intermediate values inside GL, in logs, traces or error messages.

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
`EA/.../MeRoutes.kt`, `Dtos.kt` (`isOwnerAdmin`), `OperatorTenantOverviewRoutes.kt`
(`staffCount` = active Memberships), `MessageRoutes.kt`,
`SubmitToOperatorThreadUseCase.kt`, `ReplyToOperatorThreadUseCase.kt`
(email on each side), `Auth.kt` (`authorizeOperator`, `authorizeTenantMember`).
`HR/.../Application.kt` (`HR_EA_TENANT_ID`), `HR V1__baseline.sql`.
`POP/.../Auth.kt` (JWT env, `EaMembershipGateway`). `WEB/package.json`,
`config.ts`, `SupportChatWidget.tsx`, `supportThread.ts`. Consent: grep
across EA/GL/WEB/HR/POP/SOP/IM found none.

---

## 9. Open decisions

Seed decisions 1–11 keep their numbers. D12–D20 are new. "Evidence"
says what the code shows; "Recommendation" is mine, not agreed.

| # | Decision | Evidence / Recommendation | Owner |
|---|---|---|---|
| D1 | Retire the interim read-only EA thread view when tickets exist | Recommend yes, once D2 is settled; it duplicates a channel that moves | Femi |
| D2 | What happens to EA's existing operator-thread messages | Recommend leave as read-only legacy in EA; do not migrate content authored under different rules | Femi |
| D3 | How the Owner Admin authenticates into Omniview | **Resolved by evidence to one viable option:** Cognito JWT checked by Omniview, then EA `/me`, exactly as GL/POP/SOP/IM/HR do. A WEB proxy cannot exist (WEB has no backend). Needs `OMNIVIEW_JWT_*` env (no defaults) and Cognito audience wiring | CM + EA to confirm |
| D4 | Does the chat call Omniview directly or through WEB | **Directly from the browser**; the widget is WEB's code, the call is Omniview's. Omniview must allow WEB's origin (CORS) | WEB + Omniview |
| D5 | Ticket model: fields, visibility, attachments, retention, notifications | Proposal in the Use Cases; attachments **out for v2** (an upload surface on an internet-facing service is a large risk for little value) | Omniview + Femi |
| D6 | What counts as debt; segment list beyond industry | See FR-OV-M3a. Recommend an explicit debt flag on liability accounts; do not infer from names | Femi, then GL |
| D7 | Gold price source, which price, as-of date | Recommend closing rate at the report date, source named on every report | Femi |
| D8 | Cohort method, values, concentration threshold | Structure fixed in §7.1; numbers need a statistician | Femi + statistician |
| D9 | Tenants' permission: wording, mechanism, registering body's rules | A consent record does not exist (§2.2); this decision also creates EA work (D16) | Femi + solicitor |
| D10 | Where aggregates are computed | **GL**, with allow-list and rate table supplied by Omniview (FR-OV-M5a) | GL + Omniview + CM |
| D11 | Store snapshots or compute fresh | **Compute fresh** (FR-OV-M9) | Omniview |
| D12 | May Omniview email an Owner Admin about a reply (and a support mailbox about a new ticket)? | See §3. Recommend yes: it writes nothing into any tenancy | Femi |
| D13 | Operator authentication | The token bridge was accepted for a handful of operators reading status. It now guards a queue of tenant free text plus market data. Recommend deciding before Product Support goes live whether to move operators to a Cognito group (Omniview will already verify Cognito tokens for Owner Admins). Calls to EA's operator routes still need EA's tokens or an EA change | Femi + CM + EA |
| D14 | Market unit, as-of date, currency basis | Tenant (not Company); one common as-of date; GL converts. Consolidation is a known limit | Femi + GL |
| D15 | Definition of "staff" | Active EA Memberships, labelled "staff with FiSH access" | Femi |
| D16 | Consent: who owns the record, how revocation works | EA owns it (tenant data); Owner Admin grants/revokes; wording versioned; revocation excludes the tenant from the next report | Femi + EA |
| D17 | Ticket data protection: lawful basis, retention, erasure/export, hosting location | Tickets hold tenant free text, possibly personal data, across several jurisdictions, in one UK-region database | Femi + solicitor |
| D18 | Rate limiting and abuse controls for the internet-facing intake | None exists on the platform. Recommend a per-tenant ticket quota in the app and a WAF/ALB rate rule via CM | CM + Omniview |
| D19 | Order of Support vs Market | Agree: Support first | Femi |
| D20 | Who receives market reports, and must operator roles be separated | See §7.2 | Femi |

---

## 10. Risks (the seed's six, with additions)

The seed's six stand (new privileged GL read path; internet-facing
intake; a stateful service on a shared RDS with a September connection
incident; the operator-token bridge; drifted Terraform state; and
non-identification failure as the worst outcome). Additions from this
pass:

7. **Stored script via ticket text** (NFR-OV-10).
8. **Hidden coupling:** Market Support needs work in GL (route, as-of, debt flag, FX), EA (consent) and legal, none of which Omniview controls; schedule risk is mostly outside this repo.
9. **Launch-time emptiness:** with few or no real tenants, every market figure is suppressed; the product must still look correct (FR-OV-M10).
10. **Support-channel regression:** moving Owner Admin support out of EA changes what employees can do today (FR-OV-S11).
