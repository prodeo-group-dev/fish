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
EA (D3, **DECIDED by Femi:** "Definitely.. It is where the owner Admin lives. The dashboard there is his"; CM proposed it and EA's feasibility view supports it).

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
2. **Omniview owns its own data:** support tickets and replies, (a currency rate table is deferred to the treasury phase, §11), and optionally report snapshots. Nothing else.
3. **EA is not Omniview.** EA is the tenancy's own mini-Omniview; owner-and-staff communication continues there unchanged. Product support to Prodeo Capital is a separate channel.
4. **Only a tenant's Owner Admin raises a ticket.** Employees do not.
5. **FiSH pulls; Omniview never pushes** a reply or notification into FiSH or a tenancy.
6. **Resolving a ticket changes only Omniview's own record.**
7. **Non-identification is sacrosanct.** No cohort size ever waives it. (NFR-OV-7)
8. **Reports are unaudited.** Prodeo Capital is engaged as accountants, not auditors.
9. ~~**Gold is the base currency** for Prodeo Capital's market analysis.~~ **DEFERRED.** Femi: "It is not required now" and "This leaving the area of accounting and into the treasury management and investment analysis space... and that will be done later." Market Support reports in accounting terms with **fiat as the unit** (FR-OV-M18); translating to gold or any common factor belongs to a later Treasury & Investment Analysis phase (§11).
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
Omniview --GET operator---> EA   (tenant overview; tenant + staff counts; consenting tenant list)
Omniview --GET (new)------> GL   (operator-only, totals-only aggregate; does not exist yet)
GL --GET (new, private)--> EA consent route   (GL reads the consenting set itself; the caller supplies nothing)
Omniview --GET /health----> GL, POP, SOP, IM, HR
Omniview --own DB---------> tickets, replies, (optional) snapshots
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
| FR-OV-S8 | Ticket states: Open, Answered, Closed (an Owner Admin follow-up on an Answered ticket reopens it) **A reply on a CLOSED ticket is unspecified (WEB's gap 5): decided by D38.** | PROPOSED |
| FR-OV-S9 | The Owner Admin check happens **in the relay (EA), before anything reaches Omniview**: EA verifies the user's token, confirms they are Owner Admin of the tenant concerned, and sends Omniview the tenant id and the **opaque user id only** (name or email only if operators actually need them, a data-protection decision under D17, since each field widens scope). Omniview accepts these only from an authenticated relay, never from any other caller | PROPOSED |
| FR-OV-S10 | The relay returns an Owner Admin only tickets of tenants they are Owner Admin of; every other ticket is invisible to them, including its existence. Omniview additionally scopes every read by the tenant id the relay supplies | PROPOSED |
| FR-OV-S14 | The relay is a pass-through: **it stores no ticket content** (no copy in EA's database or logs beyond metadata such as ids and timestamps). Tickets live only in Omniview (FR-OV-S3) **The relay must also not log or return raw exception or response-body text (EA feedback):** deserialization errors in EA's gateways carry the exception message, which can quote a fragment of the JSON and so possibly ticket text. The relay uses fixed error codes only. | PROPOSED |
| FR-OV-S15 | If Omniview is unreachable the relay fails closed with a clear error and the widget keeps the draft; it never falls back to EA's old operator-thread store for new tickets **Contract line (WEB feedback, 2026-10-04): the relay returns a distinguishable 503 with an error code** (not a generic failure), so the widget can say "Support is temporarily unavailable; your message was not sent and your text is kept" instead of a wrong "check your connection". | PROPOSED |
| FR-OV-S16 | Abuse controls sit at the **public edge** (the relay): per-tenant ticket quota, body and field size limits. Omniview repeats the size limits defensively. The platform has no rate limiting today, so the relay's limits are new work in EA **Split (EA feedback):** EA has no rate limiting today and runs a single instance, so an in-memory limit there is per instance. **Omniview owns the authoritative per-tenant quota**; EA enforces size and burst limits and passes Omniview's 429 and `Retry-After` through. | PROPOSED |
| FR-OV-S17 | **Unread marker (WEB feedback).** A server-side read marker for tickets, held by the relay's contract, so unread state survives devices. A browser-local "last seen" works only per device. The widget polls every ~15s while open and slowly (60-120s, paused when the tab is hidden) while closed **Held in Omniview (EA feedback):** keyed by tenant and reader user, because EA stores no ticket content; EA only relays a cheap unread route. | PROPOSED |
| FR-OV-S18 | **Legacy-thread cutover rule (WEB feedback).** From the day the widget switches, new messages go only to tickets. EA's existing operator threads become read-only for tenants. Because Omniview cannot write into EA (NFR-OV-6), WEB's `/operator` must remain the reply surface for any legacy thread still awaiting an answer; it is retired only once those are closed or deliberately abandoned, not merely when tickets go live. Without the rule, a tenant could write in one place and be answered in the other (D1/D2) | PROPOSED |
| FR-OV-S19 | The widget ships **with or after** the relay's routes, never before, and without a feature flag. It shows which tenant a ticket is raised for ("Raising for: <tenant name>"), follows the tenant the user is currently working in, and clears its state when the tenant changes (a WEB-side fix: a previous tenant's thread must never appear under another) WEB's "Raising for: <tenant name>" comes from the tenant name WEB already holds from `/me`, not from the ticket, so after a rename the two can differ and nothing breaks. | PROPOSED |
| FR-OV-S20 | **Idempotent create and reply (WEB feedback).** The relay accepts a client-supplied idempotency key on create and reply and forwards it to Omniview, which honours it, so a retry after an ambiguous failure cannot raise two tickets. Delivery is **at-least-once with the key (EA feedback)**: on a timeout the request may have landed, so a retry is safe because Omniview dedupes by key, not because nothing was persisted, and the widget words it that way **WEB's gap 4:** the same key with a **different body** is a `409 idempotency_key_reused` (Omniview's answer, a new code in EA's catalogue, so lockstep, FR-OV-S23); the dedupe window is **Omniview's to set, PROPOSED at no less than 24 hours** (confirmed to EA). | PROPOSED |
| FR-OV-S21 | **Machine-readable error codes (WEB feedback).** The relay returns codes the widget can tell apart without parsing prose: 401 (session expired); 403 `not_owner_admin`; 403 `support_terms_required` (one code, not 409; it refers to the **support terms only**, D35); 404 `ticket_not_found` (including another tenant's ticket, so existence is never leaked); 400 validation (empty or over-length body); 429 `rate_limited` or `quota_exceeded` with `Retry-After`; and 503 `support_unavailable` for Omniview or the relay being unreachable, distinct from a generic 500 or 502 **Mapping (EA feedback):** EA's existing `authorizeTenantOwnerAdmin` answers 403 with the code "forbidden" (the same for a non-member), so the new routes need their own mapping: a non-member of the tenant, or a member who is not its Owner Admin, is 403 `not_owner_admin`; 404 is only for a ticket id that is not the caller's. **The code list is an enumerated, stable contract (WEB feedback):** WEB maps each code to its own wording, so codes are not added, renamed or removed without the lockstep pattern of FR-OV-S23, and the widget treats an **unknown** code with a generic "something went wrong, your text is kept". | PROPOSED |
| FR-OV-S22 | **Body constraints (WEB feedback).** Tickets and replies are **plain text**; a maximum length is stated by the relay so the widget can enforce it; **attachments are out for v2** (D5). Omniview and the widget render the text as text, never as HTML (NFR-OV-10) **Length unit (WEB's gap 7, settled in EA's Draft 2): UTF-16 code units**, the unit JavaScript's and Kotlin's `String.length` both measure, taken after trimming, maximum 4,000, with the 16 KiB byte cap separate, so a message WEB's counter accepts is never refused for length (an emoji counts as 2). This supersedes an earlier proposal of Unicode code points. | PROPOSED |
| FR-OV-S23 | **Relay compatibility (WEB feedback).** The new routes are additive: the existing support-thread routes stay until the widget has moved, because WEB deploys independently; any contract-breaking change follows the lockstep pattern used for the Creditor-to-Supplier rename (field diff first, coordinated window). The relay's CORS allows WEB's origin (`capital.theprodeogroup.com`) with the `Authorization` header and GET/POST; a missing CORS rule has broken a route before | PROPOSED |
| FR-OV-S24 | **Replies persist and are never lost.** Tickets and replies are stored durably in Omniview and stay readable for the life of the ticket (until erased under retention, FR-OV-S13) | PROPOSED (for Femi) |
| FR-OV-S25 | **Unread indicator on every FiSH screen, not only inside the chat.** The app can ask the relay cheaply for an unread count (builds on FR-OV-S17), so an Owner Admin sees a reply wherever they are in FiSH. EA (the relay's unread route) and WEB (the indicator) each own a part | PROPOSED (for Femi) |
| FR-OV-S26 | **Pull timing is stated.** FiSH pulls and Omniview never pushes, so the worst-case delay between an operator's reply and the Owner Admin seeing it is a stated requirement, met by a polling interval or a long poll. Proposed target for Femi: the unread count refreshes within about a minute while FiSH is open **A short in-memory TTL cache of the unread COUNT only (no content) in the relay is compatible with FR-OV-S14 and spares one EA-to-Omniview call per open session per minute (EA feedback).** | PROPOSED (the number is Femi's) |
| FR-OV-S27 | **A flaky connection never loses or duplicates a ticket or reply:** retry with idempotent submit (FR-OV-S20) and the draft kept on failure (FR-OV-S15) | PROPOSED |
| FR-OV-S28 | **History is ordered and searchable** for both the Owner Admin and the operator | PROPOSED (for Femi) |
| FR-OV-S29 | **Operators see an "awaiting reply" queue with ageing**, so nothing sits unanswered. With no email, this is the safety net on Prodeo's side. Service-level targets for how quickly a ticket is answered are OPEN | PROPOSED (targets OPEN) |
| FR-OV-S30 | **Recorded limitation:** with no email, a reply is seen only when the Owner Admin next opens FiSH. The product states response-time expectations to the tenant (wording OPEN). In-app or PWA notifications later are NOT decided | DECIDED (limitation) / OPEN (wording) |
| FR-OV-S31 | **Product Support MUST alert Prodeo staff to a new ticket (REQUIRED; D34).** Femi: "That is the incomplete build I have been complaining about." A console queue plus an unread badge is not enough: a ticket system nobody is told about is an unfinished loop. "No email" (D12) was about **tenants**; alerting Prodeo's own staff is not a tenant email and needs no internet egress. Also an alert when a ticket has been **awaiting a reply for N hours** (N is Femi's). The alert carries **no ticket text** (ticket id, tenant name, age only). The channel and who is on call are open (D34) | REQUIRED (channel OPEN) |
| FR-OV-S32 | **Workflow completeness (Femi's principle, 2026-10-04).** Every workflow in this system states, before it is built: **who is told, what happens if nobody acts, and how it closes.** The check across the current plan is in section 14; a workflow that fails it is an incomplete build | REQUIRED |
| FR-OV-S11 | An ordinary employee who opens the chat is told to ask their Owner Admin, and keeps EA's internal chat. The relay rejects an employee's ticket in any case; hiding the control is a courtesy | PROPOSED |
| FR-OV-S12 | A ticket carries `tenantId` as a reference only; Omniview does not look the tenant up: **the relay supplies the tenant's display name on each create call** (EA has it; PROPOSED, EA feedback), at the cost that the stored label can go stale after a rename; the tenant id is always shown with it | DECIDED (reference-only) / PROPOSED (name lookup) |
| FR-OV-S13 | Ticket content is stored with a retention period and can be exported or erased on a verified request (D17) | PROPOSED |

**Notifications (D12, DECIDED).** Femi: "The chat should be robust enough to be effective communication" and "An in app chat is priortised over emails or phonecalls". The in-app chat is **the** channel for Product Support: no email on reply and no phone, at least for now. Email, and the SES path with its controlled egress, is **deferred, not forbidden**; Femi did not rule it out forever.

**Honest limitation.** With no email, a reply is seen only when the Owner Admin next opens FiSH (FR-OV-S30). Response-time expectations therefore belong in the product, and in-app or PWA notifications later are **not decided**. The chat has to be robust enough to carry that weight, which is why FR-OV-S24..S30 exist.

---

## 4. Market Support

| ID | Requirement | Status |
|---|---|---|
| FR-OV-M1 | Report number of tenants and number of staff. **CHALLENGE (D15):** "staff" can only mean *active system users* (EA Memberships); HR is single-tenant per deployment and holds payroll records, so it cannot give a platform-wide count. Reports label it "staff with FiSH access" **Source under EA's route draft (SRS 13.3):** both counts are computed inside EA and reach GL in the consenting-tenants response, so GL applies the same cohort, concentration and suppression rules to them as to every other figure. Omniview never reads them from EA directly for a report. (The operator's identifiable tenant overview, UC-OV-2, is a separate view and unaffected.) **Revised (D40, EA Draft 2): the staff figure is per-Company `activeStaff` summed by GL over its own cohort and labelled "staff seats" (active assignments), not people; EA's pre-aggregated and distinct-people figures were removed from v1 and may return later from EA over a cohort EA controls.** | DECIDED / PROPOSED (definition) |
| FR-OV-M2 | Capitalisation = aggregate shareholders' funds from standard balance-sheet figures. (GL's `totalEquity` includes computed retained earnings) | DECIDED |
| FR-OV-M3 | Leverage as **one ratio: total liabilities to shareholders' funds** (D6, DECIDED: Femi, "Yes, one ratio"; the two ratios named earlier coincide and "debt" means liabilities), a ratio of aggregate totals within each currency, never an average of per-tenant ratios | DECIDED |
| FR-OV-M3a | ~~Debt-to-equity needs an explicit debt designation in GL.~~ **DROPPED (D6, DECIDED):** debt means liabilities, so there is one ratio and no debt flag is needed in GL. GL's existing `totalLiabilities` and `totalEquity` are enough | DROPPED |
| FR-OV-M4 | Whole market and by segment. **Industry attaches to each Company, not the tenant (D14, verified: EA stores it per Company)**, so a segment is built from Companies. Industry is a segment dimension (DECIDED); jurisdiction and tenant segment PROPOSED | DECIDED / PROPOSED |
| FR-OV-M5 | ~~All fiat translated to gold; gold is the base currency.~~ **DEFERRED** (Femi: "It is not required now" and "This leaving the area of accounting and into the treasury management and investment analysis space... and that will be done later.") Reports are in accounting terms, **fiat as the unit, per currency** (FR-OV-M18, PROPOSED). Gold or any common factor is the treasury phase's job (§11) | DEFERRED |
| FR-OV-M5a | **CHALLENGE (D10, D14).** *Gold translation inside GL is deferred with gold (§11).* What stays: cohort and concentration rules are applied **at the source, inside GL**, on per-tenant, per-currency values that never leave GL, so a figure is judged where the per-tenant data is. GL's figures are per-Company in each Company's own currency, which is also why a cross-currency total needs translation first. GL reads the consenting set from EA itself (FR-OV-M8); the caller supplies no list | PROPOSED (call shape DECIDED by D22) |
| FR-OV-M5b | **CHALLENGE (D14).** The market unit is the **Tenant**, not the Company: GL sums a tenant's Companies before any cohort or concentration test. Consolidation does not exist, so intercompany balances inside one tenant can double count; reports state this limitation until it is addressed | PROPOSED |
| FR-OV-M5c | **CHALLENGE (D14).** Balances are as at one common date for the whole report (PROPOSED: month-end). GL has no as-of parameter today, so this is new GL work. Mixing each tenant's own latest balance would misstate the market | PROPOSED |
| FR-OV-M6 | Every figure obeys NFR-OV-7, **including the tenant and staff counts** (a segment with two tenants reveals both) | DECIDED |
| FR-OV-M7 | Every report carries an "unaudited, compiled from tenants' own books, no audit assurance" label, the as-at date, and the currency of each figure | DECIDED (label) |
| FR-OV-M8 | **CHALLENGE (D16, D22).** Only tenants whose Owner Admin has granted consent are included. Consent is a tenant-owned, versioned, revocable record in EA (new). **GL determines the consenting set itself** by reading it from EA at call time; the caller cannot choose, narrow or vary it. A caller-supplied allow-list would let anyone request totals for two lists that differ by one tenant and subtract, which defeats NFR-OV-7 **Consent text and its version come from EA, not hardcoded in WEB**, so a legal rewording (D9) needs no WEB deploy; the Owner Admin is re-asked when the version changes; existing Owner Admins have no record and are gated on first use (WEB feedback). **Record shape (EA feedback):** append-only and effective-dated (accepted or revoked, user, version, recorded-at), **per tenant, not per user**, so GL can derive cohorts from history. **Undefined today:** consent after an Owner-Admin ownership change (EA has exactly one Owner Admin per tenant; transfer is future), a question for Femi and the solicitor (D9). **This is consent to market-aggregate inclusion only: optional, revocable, and never a condition of any service.** Acceptance of the support terms (needed to process ticket text, and the only thing that may gate raising a ticket) is a separate record (D35). **Consent copy is content (WEB feedback):** both consent texts (support terms, market-aggregate) are served by EA with a version; "fixed codes only" (FR-OV-S14) concerns error messages, not this copy. **EA contract needs for both consents:** read the current text and version, read the Owner Admin's accepted version, accept, and, for the market consent only, **revoke**. Because the market consent is optional and revocable, the Owner Admin needs a reachable place to read its state and revoke it (D36). | PROPOSED (call shape DECIDED by D22) |
| FR-OV-M9 | **CHALLENGE (D11).** Reports are computed fresh each time and not stored by default. A stored snapshot freezes a tenant's contribution after it revokes consent and gives an attacker successive totals to subtract (§7.1). If trends are wanted later, store only values that already passed every test, with revocation handling designed first | PROPOSED |
| FR-OV-M10 | A suppressed cell is a normal, displayed state ("insufficient cohort"), not an error. Before launch the platform has no real tenants, so most cells will be suppressed for some time | PROPOSED |
| FR-OV-M11 | **Report dates are a fixed menu (month-end only), and cohort churn is controlled.** A caller cannot pick arbitrary pairs of dates, because when the consenting set changes between two dates (a tenant consents or revokes) the difference between their totals isolates that tenant. Beyond fixed dates: consent changes take effect at the next period boundary (**PROPOSED rule, D33: a report for month-end date D uses the consent recorded **before 00:00 UTC on the 1st of D's month**, computed by EA from its history; EA said "next boundary" must be stated**), and GL withholds a figure for a date when its cohort differs from the cohort of any previously published date by at least one but fewer than the minimum number of tenants. This needs GL to keep its own record of published cohorts (new GL-owned state, not tenant data; but it is **reporting state living in the ledger engine, a coupling cost** the GL design must weigh against alternatives, such as limiting consent changes so the rule is rarely needed) **GL's recommendation (D29): a stateless variant.** GL recomputes the cohort for every menu date up to the report date from EA's effective-dated consent history and applies the rule against all of them, whether or not they were ever requested. Stricter than "previously published", it needs no reporting state in the ledger engine, but EA must expose effective-dated history and past cohorts must be immutable. A GL-owned table would have to store tenant-id sets (a set difference cannot be done with hashes), which is sensitive data in the ledger engine and is best avoided. | PROPOSED |
| FR-OV-M12 | **DEFERRED to the treasury phase (§11):** published-rate rules. Full text preserved in §11 | DEFERRED |
| FR-OV-M13 | **Cohort and concentration tests apply at both tenant level and company level, the stricter governing.** A multi-industry tenant appears in each of its industries, so an industry cell can be dominated by one Company even when no tenant dominates the market | DECIDED (D14: Femi, "test both tenant and company") |
| FR-OV-M14 | **DEFERRED to the treasury phase (§11):** daily rate download. Full text preserved in §11 | DEFERRED |
| FR-OV-M15 | **DEFERRED to the treasury phase (§11):** rate provenance. Full text preserved in §11 | DEFERRED |
| FR-OV-M16 | **DEFERRED to the treasury phase (§11):** missed-day rule for rates. Full text preserved in §11 | DEFERRED |
| FR-OV-M17 | **DEFERRED to the treasury phase (§11):** gold as an analytics-only currency. Full text preserved in §11 | DEFERRED |
| FR-OV-M18 | **Per-currency reporting (DECIDED, D28: Femi, "which is what we do currently").** Without gold there is no common unit, so Market Support reports **per currency, as each Company's books are kept, with no cross-currency totals**, until the treasury phase can translate to a common factor. Cohort and concentration tests apply per currency; a tenant with Companies in several currencies counts in each. Tenant and staff counts are currency-neutral. Leverage (total liabilities to shareholders' funds) is a ratio of per-currency aggregate totals, never an average across currencies | DECIDED (D28) |
| FR-OV-M19 | **Small cells suppress more.** Splitting by currency, then by segment, makes cohorts smaller, so many cells will read "insufficient cohort" for a long time and an uncommon currency may never publish. That is correct behaviour (FR-OV-M10); "whole market" means the whole market within one currency | DECIDED (follows from D28) |
| FR-OV-M20 | **Complementary suppression (GL feedback; the most important gap).** The whole-market figure minus the sum of the other published industry cells recovers a single suppressed cell, especially when most tenants are single-industry. Suppression alone is not enough: when one cell of a partition is suppressed, **another must be suppressed too**, or no total is published beside the segments. Needs its own design and tests that try it | PROPOSED |
| FR-OV-M21 | **One uniform suppression reason.** Every suppressed cell reads the same "insufficient cohort", whatever the cause. A distinct "dominated by one tenant" would reveal dominance; likewise an unknown segment value must be indistinguishable from an empty one | PROPOSED |
| FR-OV-M22 | **D8's default is no publication.** Thresholds live only in GL's own configuration, never in the request, and an unset threshold refuses everything (no zero defaults). Changing a threshold is audited | PROPOSED |
| FR-OV-M23 | **Cohort counting rule (GL feedback).** Only Companies that appear in both EA's list and GL's own tenant mapping count (GL still has `companies.tenant_id`); only Companies with at least one posted entry on or before the report date; Companies in an unreportable state (lines in a currency other than the Company's base currency, which GL's money arithmetic rejects) are excluded **before** cohorts are sized, not made to error; a Company with a non-zero Suspense balance is ineligible or has Suspense excluded and the report says so (D30). Zero-balance participants would otherwise inflate cohort size and concentration headroom | PROPOSED |
| FR-OV-M24 | **Restatement lag (GL feedback).** GL has no posted-at timestamp, so a backdated entry posted after month-end changes a historical figure that was already "published". A month-end is reported only after a grace lag of N days (D31), rather than requiring closed periods, because most tenants never close them | PROPOSED (N is Femi's) |
| FR-OV-M25 | **Equity and the ratio (GL feedback).** Leverage matches GL's own BalanceSheet exactly (total equity = equity accounts plus all-time revenue minus expense; negative cash is **not** reclassified to liabilities), and the report says so. Wording is **"total equity (net assets)"**, not "shareholders' funds", which is wrong for non-profit and individual books. When aggregate equity is zero or negative the ratio is suppressed and concentration is computed on positive contributors only (a statistician's rule under D8) | PROPOSED |
| FR-OV-M26 | **Fixed failure vocabulary on the GL route (GL feedback).** Every failure is one fixed code, never a value and never a figure in its place: `not_configured` (thresholds unset; the UI says "market reports not configured"), a fixed "temporarily unavailable" 503 (EA unreachable or undecodable, or the operator-access log cannot be written), a fixed 400 "date not available" (not a menu date, future, or inside the grace lag). Every failure also writes **one fixed-format log line carrying no values**, so a monitor can alert on it (D39). A suppressed cell always reads the same "insufficient cohort" (FR-OV-M21) | PROPOSED |

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
| NFR-OV-7 | **Non-identification.** No per-tenant figure or breakdown anywhere: view, API, export, log, stored snapshot. Cohort minimum determined statistically; plus a concentration rule (the stricter test governs); plus suppression that defeats differencing. Enforced in code, with tests that *try to defeat it*. Tenants' permission first **"Published" means shown to anyone (Femi: "We do not publish anything"; CM's reading, PENDING):** reports are internal, generated on demand, with nothing stored or sent outside. So the cohort-churn and differencing controls apply to what an operator is **shown**, because an operator who views a report before and after a revocation can subtract to isolate that tenant. | DECIDED |
| NFR-OV-8 | **Never internet-facing.** Reachable only on Prodeo's private network; **inbound** callers are the relaying FiSH service and operators over private access, never a tenant's browser. No public hostname, listener rule or certificate. Calls into it are authenticated service-to-service and size-limited. (Corrected 2026-10-04, replacing a wrong earlier "inbound is internet-facing" requirement) | DECIDED |
| NFR-OV-9 | A new privileged read path in GL is audited, returns totals only, enforces cohort and concentration at source, and never logs per-tenant intermediate values | PROPOSED |
| NFR-OV-10 | **Tickets are untrusted input rendered in the operator's browser**, even though they now arrive through a relay over a private network: the text is still authored by a tenant. The operator console holds the operator token in browser storage, so a stored script in a ticket would steal a token that reads every tenant. Ticket text is always rendered as text (the ported component already does), the console sets a strict Content-Security-Policy, and the operator token is kept out of long-lived storage | PROPOSED |
| NFR-OV-11 | Omniview's database connection pool is small and bounded; a stateful service must not repeat the shared-RDS connection exhaustion | PROPOSED |
| NFR-OV-12 | Backups and a tested restore for the ticket database | PROPOSED |
| NFR-OV-13 | Each ticket and reply records who raised/answered it (Owner Admin identity as asserted by the relay, or named operator) for attribution | PROPOSED |
| NFR-OV-14 | Service-to-service authentication between the relay and Omniview: a Cognito service-account credential with its own audience, verified by Omniview (no defaults), plus network restriction to the relay's security group. Network position alone is not authentication **Service-only routes fail closed (EA finding, 2026-10-04).** A route group meant for one service caller is authenticated by that service's provider **only**, using a **service-principal validator** (no email claim, no Membership lookup), and it **fails closed** (the group is not registered, or answers 503) when that service's audience is not configured. It never falls back to the human verifier. EA's current wiring passes `glServiceVerifier ?: verifier`, so an unset GL audience silently makes the "GL service" provider the human verifier, the same audience as every tenant user's token: a GL-only route built on it would be callable by **any tenant user with a valid token**. Harmless today only because every provider shares the human validator. The same rule binds every service-to-service pair here: Omniview verifying EA, GL verifying Omniview, and EA verifying GL. **GL has the same fall-back (GL's finding, 2026-10-04), latent and not exploitable today:** its wiring defaults each service verifier to the human one, so an unset audience makes that provider the human verifier, and service providers skip the membership check. It is masked only because the shared wrapper tries the human provider first; there is no service-only route group in GL yet. Order-dependent masking is not a guard. | PROPOSED |
| NFR-OV-15 | Operators reach Omniview only by private access (D4); the console is never exposed on the shared public load balancer | DECIDED (private) / OPEN (how) |
| NFR-OV-17 | **Network exposure and authorization of the GL aggregate route (GL feedback).** GL sits behind a public ALB, so a new operator route there is internet-addressable and gated only by a token, which cuts against never-internet-facing for the one route that exposes cross-tenant data. It needs a private path or an ALB rule blocking its path prefix (CM, 7B.3). Omniview's identity must be a **separate named authentication provider used only on this route**: GL's shared authentication list lets service-account callers bypass the tenant check, so adding Omniview there would let its token reach every GL route. The route has its own platform-operator authorization check **Its provider fails closed when unconfigured and never falls back to a shared or human verifier (NFR-OV-14).** **Requirements for Omniview's provider in GL (GL feedback):** its verifier is a required, non-null parameter with no default and no fall-back to the human verifier; if its audience is unset the route group is not registered (or answers 503); the provider is used only on the aggregate route group and is never added to the shared authentication list; the validator checks that the token is a service principal and carries the Omniview identity; and a test asserts that a **human Cognito token gets 401 on the aggregate route with the audience both configured and unconfigured**. | PROPOSED |
| NFR-OV-18 | **Operator-access log (GL feedback).** GL's audit entry requires a tenant and a Company, so it cannot describe a platform-level read. A separate small log records operator, report date, segment and outcome counts only, never values. GL recommends it **fails closed** (if the audit write fails, no figure is served), consistent with Femi's fail-closed decision on the audit trail; his call (D32). A service token identifies Omniview, not which human operator: Omniview passes an operator id that GL records but cannot verify, a stated limitation | PROPOSED |
| NFR-OV-16 | **DEFERRED to the treasury phase (§11):** controlled egress for a daily rate download. Full text preserved in §11. Omniview needs no outbound internet access for Product Support or accounting-terms Market Support | DEFERRED |

---

## 7. Data

| Data | Owner |
|---|---|
| Tenants, staff (Memberships), KYB, Owner Admin identity, **consent record (new)** | EA |
| Balance-sheet figures | GL (aggregate-only access, new) |
| Tickets and replies | **Omniview** |
| Currency rate table | **Deferred** to the treasury phase (§11) |
| Report snapshots | None by default (D11) |

### 7.1 Non-identification, in design terms

The seed lists three defences. The evidence adds the attacks they must
answer, so the tests have something to try:

1. **Small cells.** A tenant or staff count for a segment of one or two. Cohort minimum applies to counts as well as money.
2. **Dominance.** One tenant holding most of a total identifies it by size. Concentration rule on the per-currency tenant value (computed at source).
3. **Complementary suppression.** If a segment is suppressed but the whole market and the other segments are shown, the suppressed one is recoverable by subtraction. Suppression must cascade.
4. **Differencing over time.** A tenant joins, leaves or revokes consent, and two successive reports differ by exactly its contribution. No stored history by default (FR-OV-M9), and the consenting set is part of what must not be inferable.
5. **Differencing through the consenting set and the request parameters.** The *count of consenting tenants* is itself a figure and falls under the cohort rule. The set must be fixed by GL from EA, never chosen by the caller, or two calls with lists differing by one tenant would isolate it. Any parameter a caller can vary (date, segment, rates) must likewise not be able to isolate a tenant: dates and segments come from fixed menus, and suppression applies to every combination.
6. **Logs and errors.** Per-tenant intermediate values inside GL, in logs, traces or error messages.
7. **Varying the date.** Totals at two dates, with a cohort that changed between them, isolate the tenant that joined or left (FR-OV-M11). Month-end-only dates, period-boundary consent changes and GL's churn rule answer it.
8. *(Varying a rate is a treasury-phase concern, deferred with gold, §11.)*

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

**Update:** Femi has since confirmed every reading CM relayed (D6, D14, D28), so no decision below is currently PENDING. Still open for him: D12 (email on reply), D15 (staff definition), D20 (report audience, role separation), D24 (staff by industry); D8 stays parked as the launch gate.

Numbering follows the **corrected seed** (PR #61) for D1–D11: D3 and D4
changed meaning there. D12–D25 are new in this pass. "Evidence" says what
the code shows; "Recommendation" is mine, not agreed.

| # | Decision | Evidence / Recommendation | Owner |
|---|---|---|---|
| D1 | Retire the interim read-only EA thread view when tickets exist | Recommend yes, once D2 is settled; it duplicates a channel that moves | Femi |
| D2 | What happens to EA's existing operator-thread messages | Recommend leave as read-only legacy in EA; do not migrate content authored under different rules | Femi |
| D3 | Which FiSH service relays tickets to Omniview, and how it authenticates to Omniview privately | **Femi: "Definitely.. It is where the owner Admin lives. The dashboard there is his" (DECIDED): EA is the relay.** Reasoning: EA is where the Owner Admin lives and the dashboard there is theirs. It is supported by EA's own feasibility view (small-medium; the same shape as its Approvals Queue; it already authenticates the Owner Admin through `/me` and `authorizeTenantOwnerAdmin`; it stores nothing). WEB cannot be the relay (no backend). Authentication to Omniview: a Cognito service-account audience for the relay, a **required** verifier that **fails closed** when unconfigured (NFR-OV-14), plus a security-group restriction. EA stays not-Omniview: the relay stores nothing (FR-OV-S14). **EA now owns the route-contract doc; WEB and GL finalise against it** | Settled |
| D4 | How operators reach a private Omniview | **OPEN, CM's lane.** The shared load balancer is public, so Omniview needs another path: a VPN, an SSM port-forward, or another internal-only route. It also decides what "the operator opens the console" means for a growing ops team, and when WEB's `/operator` can be retired (it is public today). Not designed here | CM + Femi |
| D5 | Ticket model: fields, visibility, attachments, retention, notifications | Proposal in the Use Cases; attachments **out for v2** (an upload surface carrying tenant files is a large risk for little value) **WEB sizing (2026-10-04):** one flat thread per tenant is a small repoint of the existing chat client; real tickets (several per tenant, each with its own thread and status) are a new list / open / new-ticket view, medium. Femi's choice. Proposals if tickets: show "Raising for: <tenant name>"; optionally carry the selected companyId as context. | Omniview + Femi |
| D6 | What counts as debt; segment list beyond industry | **Femi: "Yes, one ratio" (DECIDED).** One leverage ratio, **total liabilities to shareholders' funds**; the two ratios named earlier coincide, and "debt" means liabilities. So FR-OV-M3a's "no debt designation" problem and the GL debt flag (8B.4) are dropped. The segment list beyond industry is still open | Settled (segment list open) |
| D7 | Gold price source, which price, as-of date | **DEFERRED** (§11) | Treasury phase |
| D8 | Cohort method, values, concentration threshold | **Femi: "This will be determined later" (DECIDED: parked).** The structure in §7.1 stays; the numbers wait for a statistician. **It is a launch gate:** no market figure may be published until the numbers are set, since NFR-OV-7 cannot be enforced without them | Femi + statistician, later |
| D9 | Tenants' permission: wording, mechanism, registering body's rules | A consent record does not exist (§2.2); this decision also creates EA work (D16) | Femi + solicitor |
| D10 | Where aggregates are computed | **GL**, reading the consenting set from EA itself (FR-OV-M5a, M8, D22); a route with its own authorization, not publicly reachable beyond gating | GL + Omniview + CM |
| D11 | Store snapshots or compute fresh | **Compute fresh** (FR-OV-M9) | Omniview |
| D12 | May an Owner Admin be emailed about a reply? Who sends | **Femi: "The chat should be robust enough to be effective communication" and "An in app chat is priortised over emails or phonecalls". (DECIDED).** The in-app chat is the channel for Product Support; **no email on reply and no phone for now**. Email and the SES path are **deferred, not forbidden**. Consequences: the email/SES path is dropped from Wave 7 (7C.4) and from the egress discussion; chat-robustness requirements FR-OV-S24..S30 (PROPOSED, for Femi); the limitation that a reply is seen only when the Owner Admin next opens FiSH is recorded (FR-OV-S30). WEB's evidence (a PWA with no push and a 15-minute idle sign-out) is why the unread indicator and the robustness requirements matter | Settled; robustness requirements for Femi |
| D13 | Operator authentication | The token bridge was accepted for a handful of operators reading status. It now guards a queue of tenant free text plus market data. Private access (D4) adds a network layer; it does not replace operator identity. Recommend deciding before Product Support goes live whether operators move to a Cognito group; calls to EA's operator routes still need EA's tokens or an EA change | Femi + CM + EA |
| D14 | Market unit, as-of date, currency basis | **Femi: the unit being the tenant and one common month-end is "doable but it is the company that determines the industry", and "test both tenant and company" (DECIDED).** Verified: `industryType` is stored **per Company** in EA (migration V13); GL has no industry field. So industry segments are built from Companies, a multi-industry tenant appears in each of its industries, and the **minimum-cohort and concentration tests apply at both tenant level and company level, the stricter governing** (FR-OV-M13). Staff by industry is D24 (open) | Settled |
| D15 | Definition of "staff" | Active EA Memberships, labelled "staff with FiSH access" **EA detail:** the Owner Admin holds an owner assignment at every Company, so "distinct active Memberships" counts the owner (decide whether the owner is staff); count ACTIVE only (Memberships are ACTIVE, PENDING or REVOKED); and decide whether a person who is staff in two tenants counts once (by user) or once per tenant. | Femi |
| D16 | Consent: who owns the record, how revocation works | EA owns it (tenant data); Owner Admin grants/revokes; wording versioned; revocation excludes the tenant from the next report | Femi + EA |
| D17 | Ticket data protection: lawful basis, retention, erasure/export, hosting location | Tickets hold tenant free text, possibly personal data, across several jurisdictions, in one UK-region database | Femi + solicitor |
| D18 | Abuse controls at the public edge | The relay (EA) is now the public edge for support: per-tenant ticket quota, size limits (FR-OV-S16). The platform has no rate limiting anywhere, so this is new work in EA; Omniview repeats size limits defensively | EA + CM |
| D19 | Order of Support vs Market | Agree: Support first | Femi |
| D20 | Who receives market reports, and must operator roles be separated | See §7.2 | Femi |
| D21 | Does the relay have a quota-free path for Prodeo's own staff to open a ticket on a tenant's behalf (for example after a phone call)? | Recommend no for v2: an operator creating a ticket would be a different actor and a different trust path. Operators answer; tenants raise | Femi |
| D22 | The shape of the GL aggregate call, and NFR-OV-6's wording | **Femi: "Agree" with option A (DECIDED).** A GET whose request is only a fixed report date and a segment; GL reads the consenting set from EA itself, so no allow-list comes from the caller (rates are deferred with gold, §11). NFR-OV-6 stays GET-only. Options B and C are closed. Consequences: GL gains a read dependency on an EA consent route (8B.1), and needs a private path to EA's operator route, which is public today (7B.3) | Settled |
| D23a | **DEFERRED to the treasury phase (§11):** gold in `common`. Femi's earlier decisions are preserved there, not lost | Treasury phase |
| D23b | **DEFERRED to the treasury phase (§11):** daily rate download, Omniview-owned rate store. Femi's earlier decisions are preserved there, not lost | Treasury phase |
| D24 | Staff by industry | Staff are assigned **per Company** through Membership assignments in EA, so "staff by industry" needs a rule: count a member once per industry they are assigned in, or once per tenant in a primary industry, or count assignments rather than people. Whole-market staff is unaffected (distinct active Memberships, D15). Recommend counting distinct people per industry, and saying so on the report **See D40 (GL's finding): where staff are counted changes the answer.** | Femi |
| D25 | **DEFERRED to the treasury phase (§11):** gold unit and precision. Femi's earlier decisions are preserved there, not lost | Treasury phase |
| D26 | **DEFERRED to the treasury phase (§11):** rate provider, licence and cost. Femi's earlier decisions are preserved there, not lost | Treasury phase |
| D27 | **DEFERRED to the treasury phase (§11):** which currencies are downloaded. Femi's earlier decisions are preserved there, not lost | Treasury phase |
| D28 | The unit for Market Support without gold | **Femi: per-currency reporting is "what we do currently" (DECIDED).** Report per currency, no cross-currency totals, until the deferred treasury phase can translate to a common factor (FR-OV-M18). On translation: "Currency translation is very important in this project but that is for later." The alternatives (one reporting currency; single-currency tenants only) are closed. Cost, accepted: smaller cohorts and more suppression (FR-OV-M19). Femi also agreed the lighter near-term scope: no new outbound path, no extra service identity, no change to `common` | Settled |
| D29 | Mechanism of the cohort-churn rule (FR-OV-M11) | **GL recommends (B) stateless:** recompute cohorts for every menu date up to the report date from EA's effective-dated consent history; stricter than "previously published"; no ledger-engine state; EA must expose effective-dated history and past cohorts must be immutable. **(A)** GL-owned table of tenant-id sets: avoid. **(D)** freeze the consenting set per reporting year, consent changes effective only at the year boundary: the rule rarely fires, but a revocation is honoured late, which is a legal question **EA's draft (SRS 13.3):** EA applies the consent history exactly but keeps no effective-dated tenant status or Company creation date, so past cohorts are reproducible only if the cohort for date D is defined as the consent at D's boundary (from EA) intersected with the Companies that have posted activity on or before D (from GL), ignoring tenant status (D37). | Femi, EA, GL |
| D30 | Report definitions and eligibility (GL feedback) | (a) Non-zero **Suspense** (3910, "not yet classified"): the Company is ineligible, or Suspense is excluded and the report says so. (b) **Overdrafts:** follow GL's BalanceSheet exactly (matches what the tenant sees) or apply the IAS 1 reclass; recommend matching it and stating it. (c) **NON_PROFIT and INDIVIDUAL:** label "total equity (net assets)"; for a credit union such as Purse, member shares are often liabilities (IAS 32), so decide whether they need special treatment, and whether `Company.clientType` becomes a segment dimension. (d) Negative aggregate equity: ratio suppressed, concentration on positive contributors only (statistician, D8) | Femi (+ an accountant) |
| D31 | Restatement grace lag N (FR-OV-M24) | A month-end is reported only after N days, because a backdated entry can change a published figure | Femi |
| D32 | Operator-access log fails closed? (NFR-OV-18) | GL recommends yes: if the audit write fails, no figure is served | Femi |
| D33 | The consent boundary rule and the timing of a revocation | EA says "next boundary" must be stated. **PROPOSED:** a report for month-end date D uses the consent recorded **before 00:00 UTC on the 1st of D's month** (UTC, EA's recorded-at). The tension: a revocation made mid-month would then still be honoured only from the next month's report, yet reports are computed fresh (FR-OV-M9), so a tenant that revokes expects to be excluded from anything not yet published. Whether revocation applies immediately or at the boundary is a legal question **GL confirms the rule works for the stateless churn variant (D29), since GL recomputes each menu date's cohort from EA's effective-dated history.** **Femi: "We do not publish anything" (CM's reading, PENDING his confirmation):** reports are internal and generated on demand, so there is no published report to purge on a revocation. **Option 1 (CM's reading):** a report uses the consent in effect when it is **generated**, a revocation applies from the next view, and no snapshots are stored (this resolves D11 the same way). **Option 2 (the boundary rule above):** consent as at 00:00 UTC on the 1st of the report month, so a revocation takes effect at the next month's report. **Tension, stated plainly:** with Option 1 a revocation is honoured at once (the legally friendlier reading), but it makes the cohort change at any moment, so the churn rule must compare against **every consent state within a trailing window**, and a mid-window revocation withholds the affected figures until the exposure passes; Option 2 bounds the number of cohort states per report date but delays honouring a revocation. EA's effective-dated history makes either computable. **Recommendation, if Femi confirms the reading: Option 1**, with the trailing window set by the statistician (D8). | Femi + solicitor, EA |
| D34 | How Prodeo's support learns of a new ticket (FR-OV-S31) | **Femi: "That is the incomplete build I have been complaining about" (DECIDED in substance): Product Support MUST alert Prodeo staff to a new ticket**; a console queue plus unread badge alone is not enough. Framing corrected: D12's "no email" concerned tenants; alerting Prodeo's own staff is not a tenant email and does not need internet egress. **CM PROPOSAL (not decided):** Omniview publishes a "new ticket" event, and a "ticket awaiting reply for N hours" event, to an SNS topic over a private VPC interface endpoint, and AWS delivers it to Prodeo's support mailbox (SMS or a chat webhook later); the message carries no ticket text (ticket id, tenant name, age only); cost is small and it is CM's lane. **Remaining for Femi: the channel (mailbox, SMS, both) and who is on call** | Femi, CM |
| D35 | Consent bundling: two purposes, not one | **Femi's reaction to the bundling: "Why would that be a thing"**: nobody intended a tenant to have to accept market-report use to raise a support ticket; the coupling was an artefact of the first draft's single consent record. **Treated as DECIDED unless Femi says otherwise** (CM's reading of that reaction): two SEPARATE versioned records, **(a) support terms** (needed to process ticket text; may gate raising a ticket) and **(b) market-aggregate inclusion** (optional, revocable, never a condition of any service). EA holds both. The legal wording and mechanism stay open (D9, solicitor) | Settled in design; wording with Femi + solicitor |
| D36 | Where the Owner Admin revokes the market consent (WEB feedback) | The market consent is optional and revocable, so WEB needs a reachable place to show its current state and revoke it. WEB has no settings or privacy page today, so this is a small new surface. The natural home is the Owner Admin's Administration area, not buried in the chat widget. Placement is open | Femi |
| D38 | Ticket closure policy (found by the completeness check, section 14) | Who closes a ticket and when; whether an Answered ticket auto-closes after N days without an Owner Admin response; and what a reply on a **CLOSED** ticket does (WEB's gap 5): either it reopens within N days, or it is rejected with 409 `ticket_closed` and the widget offers "start a new ticket". Proposed: operators close; an Owner Admin reply on CLOSED reopens within N days, else a new ticket; N is Femi's **EA's Draft 2 already carries `ticket_closed` (409, PROPOSED) for a reply on a CLOSED ticket, which is the "start a new ticket" branch of this decision.** | Femi |
| D39 | Passive monitors with no alert (section 14) | The platform-health strip tells nobody unless someone looks, and a relay that cannot reach Omniview tells no one in Prodeo. Whether the alert channel chosen for D34 is reused for "a service is down" and for a rising rate of `support_unavailable`, and who owns those alarms (CM) | Femi, CM |
| D40 | Where staff are counted (GL's gap 2) | EA's pre-aggregated fields `distinctPeople` and `staffByIndustry` cover EA's **full** consenting set, not GL's smaller eligible cohort (posted activity, Suspense and currency exclusions), so two inconsistent cohorts exist and can be differenced. **Option A (GL's recommendation):** leave staff out of the GL route for v1 and serve them from EA over a cohort EA controls, which puts suppression logic in a second place. **Option B (PROPOSED, my lean):** EA returns only **per-Company `activeStaff`**, and GL aggregates over **its own** cohort, so staff counts get the same cohort and suppression as every other figure in one place. Cost of B: staff are counted as seats (active assignments per Company), not as distinct people across tenants; de-duplicating people across tenants is dropped for v1 (D15, D24) **ALIGNED (2026-10-04):** EA's Draft 2 removed `distinctPeople`, `staffByIndustry` and tenant-level staff from the GL route for v1 and kept per-Company `activeStaff`; GL agrees: it sums per-Company `activeStaff` over its own cohort, the label says "seats", not people, and the same cohort, concentration and suppression rules apply. Femi to confirm staff as seats. | Femi, GL, EA |
| D37 | Recomputing a past report (EA's limit, SRS 13.3) | EA stores no effective-dated tenant status and no Company creation date, so a past report recomputed now would use today's status and today's Companies, and a Company added or a tenant suspended later would appear or vanish. **PROPOSED:** define the cohort for report date D as the market consent recorded before 00:00 UTC on the 1st of D's month (EA's history, exact) **intersected with** the Companies that have posted activity on or before D (GL's history, exact, FR-OV-M23), and **do not use tenant status at all**: a closed tenant that had consented stays in the reports of the dates it was active, which is historically correct. `industryType` stays current-only; if a Company's industry changes, recomputed past reports re-segment it. Accept that, or snapshot industry per period. EA's alternative is to schedule a small history addition. GL to confirm **EA notes (2026-10-04):** if this is accepted, EA's contract section 4 wording "only the tenant's current status" becomes "no status filter"; EA will revise it when D37 is decided. And `industryType` is **not** immutable in EA today (a repeat company-registration call overwrites it; EA reported this to CM as a separate bug), so treat it as current-only until a guard lands; once it does, no industry snapshot is needed. **GL CONFIRMS it works (2026-10-04):** "posted activity on or before D" is reproducible from the entry date, counting only POSTED, SYSTEM and REVERSED entries; it is monotone in D, and GL never deletes Companies. Remaining non-reproducibility is the restatement caveat (a backdated entry posted later can add a Company to a past cohort; the grace lag of D31 narrows it without closing it). **Two changes GL asked for, adopted here:** (1) **GL, not EA, supplies the tenant-to-Company mapping** (from its own `companies.tenant_id`), and EA supplies only the consenting tenant set and `industryType` by Company, which removes the "current Companies only" limit for the financial cohort; (2) tenant status is ignored. **Consequence for Femi:** a closed or suspended tenant that had consented keeps contributing to recomputed reports. **GL's industry gap:** because `industryType` is current-only, requesting the same report date before and after a Company changes industry shows the cells shifting by exactly that Company, which GL's stateless rule cannot see across requests. It closes if EA's pending guard makes industry immutable once set; a legitimate change would otherwise need effective-dated industry history, or an explicit acceptance of the channel. **EA (Draft 2): the industry-immutability bug fix is in progress under CM review; once it lands `industryType` is truly immutable and no industry snapshot is needed.** | Omniview, GL, EA, Femi |

---

## 10. Risks

The seed's six stand with its correction applied (risk 2 is now "intake
crosses a trust boundary", not "internet-facing intake"): a new privileged
read path in GL; the intake crossing a trust boundary; a stateful service
on a shared RDS with a September connection incident; the operator-token
bridge; drifted Terraform state; and non-identification failure as the
worst outcome. Additions from this pass:

7. **Stored script via ticket text** (NFR-OV-10). It does not depend on Omniview being public: tenant-authored text reaches an operator's browser either way.
8. **Hidden coupling:** Market Support needs work in GL (route, as-of, per-currency tables), EA (consent) and legal, none of which Omniview controls; schedule risk is mostly outside this repo. Support now also needs EA (the relay), so Wave 7 is no longer "no change in any other service".
9. **Launch-time emptiness:** with few or no real tenants, every market figure is suppressed; the product must still look correct (FR-OV-M10).
10. **Support-channel regression:** moving Owner Admin support out of EA changes what employees can do today (FR-OV-S11).
11. **EA becomes the public edge for support.** The relay is internet-facing even though Omniview is not, so it needs the quota, size limits and Owner-Admin gate (FR-OV-S9, S16) and must never store ticket content (FR-OV-S14). A relay that quietly keeps a copy would recreate the tenancy-data-in-another-system problem this design avoids. **Availability blast radius (EA feedback):** EA is the authentication substrate every service calls, runs a single task and has no rate limiting, so the support routes need their own limits, a short timeout on the call to Omniview, and a fast 503, so a slow Omniview cannot take EA's other routes with it.
12. **Private access is an operational cost.** A VPN or port-forward for every operator (a team is being hired) is friction; a lazy workaround that exposes the console would break the decision. D4 must produce something operators will actually use.
13. *(The rate-provider, egress, licence and circular-call risks moved to §11 with the treasury phase.)*


---

## 11. Treasury & Investment Analysis (DEFERRED: a separate later SPUTO)

Femi: "It is not required now" and "This leaving the area of accounting and into the treasury management and investment analysis space... and that will be done later." So all gold, rate and cross-currency translation work is **off the critical path** of Product Support and Market Support, and gets its own SPUTO later (like Education Runtime status). Recorded here so that pass starts informed. Nothing in this section is to be built now.

### 11.1 Direction Femi gave earlier, held for later

- **Gold is analysis-only; client reporting stays fiat** ("Gold is not used for client reporting. Fiat is. However for investment analysis, any financial statement from any jurisdiction can be translated to a common factor (i.e Gold)").
- **D23a:** gold is defined in the `common` repo with `Money` and the other currencies ("We have a common folder where money is placed").
- **D23b:** Omniview downloads the rates **daily** and stores them ("Omniview downloads and stores the rates"; "Daily rates has to be downloaded by Omniview"); GL reads the one published rate for a report date from Omniview.

### 11.2 Findings preserved (verified 2026-10-04)

- `XAU`'s JDK default fraction digits are **-1**, and `common/Money.kt` does `setScale(currency.defaultFractionDigits, HALF_EVEN)`, so `Money(123.456, XAU)` becomes `1.2E+2` (120). Gold needs an explicit unit and precision rule in `common` first (troy ounce vs grams; decimal places).
- `common` is a **source library** consumed by GL/SOP/POP/IM/HR: it can hold the currency model and the precision rule, **not rate data**, and a change to it is a wide change to review as one. Keep it minimal and additive, as an analytics-only currency that cannot be a Company base currency or appear in WEB's currency lists.
- The earlier argument that a gold series would serve GL's IAS 21 handling is **withdrawn**: gold is analysis-only; GL's client foreign exchange (fiat) is a separate concern.

### 11.3 Design costs and requirements preserved for the later pass

- **A caller-supplied rate is a free parameter:** varying one currency's rate and watching the total move reveals that currency's subtotal, and a single tenant holding it. So GL must read the one published rate itself, never accept it from the caller.
- **Circular request chain:** Omniview calls GL, which calls Omniview back for the rate. The rate read must be a separate lightweight route with its own timeout; a published rate is immutable for its date, so GL can cache it. It adds a private GL-to-Omniview path and a third service identity, and makes GL's aggregate route depend on Omniview being up.
- **Outbound internet:** a daily download needs a controlled, allow-listed egress path from Omniview's private network (private subnets with NAT or an allow-listed proxy), costed by CM, while Omniview stays private inbound.
- **A scheduled job:** the first in Omniview; it needs failure alerting. **Provenance:** source, retrieval time, raw value, a bounds check against the previous day, audited corrections, a published report never silently recomputed, maintainers and report readers as separate roles. **Missed day:** only the month-end closing rate matters; if that day's download failed the report for that date stays unavailable until backfilled or corrected, never estimated or carried forward.
- **Open for that pass:** provider(s), licence for commercial use by an accountancy firm, cost (D26); all currencies or only those in use (D27); gold unit and precision (D25).

### 11.4 Deferred requirements and decisions, verbatim as they stood

| Item | Text |
|---|---|
| FR-OV-M12 | **Rates are published data, not parameters.** Omniview's rate table has exactly one effective rate per currency per report date, is append-only, and each correction carries an audited reason and never silently changes a report already published. GL accepts only the published rate for the date, and rejects a value outside validated bounds. **D23b, DECIDED: Omniview owns the rate values.** The people who maintain or correct rates and the people who read reports should be different roles (D20), since someone who can do both could craft a rate and read the result PROPOSED |
| FR-OV-M14 | **Daily rate download (DECIDED, D23b).** Omniview downloads rates once a day from an external provider (D26) over HTTPS, through a controlled egress path, as a scheduled job. The job alerts on failure (this is the first scheduled job in a service that has none, so it needs its own monitoring) DECIDED / PROPOSED (mechanics) |
| FR-OV-M15 | **Rate provenance.** Each stored rate records its source, retrieval time and raw value; each is checked against the previous day's value within a bound and rejected for review if it falls outside; corrections are audited and never silently recompute a published report PROPOSED |
| FR-OV-M16 | **A missed day.** Reports use fixed month-end dates (FR-OV-M11), so only the month-end closing rate truly matters. If that day's download failed, the report for that date is unavailable until the rate is backfilled from the provider's historical data or entered as an audited manual correction. A rate is never estimated or carried forward silently PROPOSED |
| FR-OV-M17 | **Gold is analytics-only.** When gold is defined in `common` (D23a) it must not be selectable as a Company base currency or appear in WEB's currency lists, and no client-facing report shows gold. Client reports stay fiat DECIDED (scoping) / PROPOSED (guardrail) |
| NFR-OV-16 | **Controlled egress.** Omniview makes outbound calls to the rate provider (and SES if D12 says so) only through an explicit, allow-listed egress path from its private network (private subnets with NAT or an allow-listed proxy), costed by CM. Never-internet-facing concerns inbound exposure; outbound internet access is a separate, deliberate and narrow exception PROPOSED |
| D7 | Gold price source, which price, as-of date Recommend closing rate at the report date, source named on every report Femi |
| D23a | **The currency model: where gold is defined** **Femi: "We have a common folder where money is placed." (DECIDED.)** Gold is defined in the `common` repo with `Money` and the other currency definitions. **Verified need:** `XAU` has -1 default fraction digits in the JDK, so `Money(123.456, XAU)` rounds to 120 today; `common` needs an explicit unit and precision rule (D25, backlog 8B.4a). `common` is consumed as source by GL/SOP/POP/IM/HR, so this is a wide change reviewed as one Settled; detail in D25 |
| D23b | **Where the rate values live** **Femi: "Omniview downloads and stores the rates" and "Daily rates has to be downloaded by Omniview" (DECIDED).** Omniview owns the rate values, downloads them **daily** from an external source and stores them; GL reads the one published rate for the report date from Omniview. CM's GL-holds-rates proposal is withdrawn, and the layering concern is overridden by this decision. **Costs, stated rather than hidden:** a private GL-to-Omniview read path (7B.3) and a third service identity (8B.9); GL's aggregate route depends on Omniview being up, and because Omniview calls GL which calls Omniview back within one request, the rate read must be a separate lightweight route with its own timeout (a published rate is immutable for its date, so GL can safely cache it); and **Omniview now makes outbound internet calls** while staying private, so it needs a controlled egress path (FR-OV-M14, NFR-OV-16). **Scoping fact (Femi): gold is not used for client reporting; fiat is.** Gold translation exists so that any financial statement from any jurisdiction can be put on a common factor for Prodeo's investment and market analysis (FR-OV-M17). The earlier IAS 21 argument is withdrawn: GL's client foreign-exchange handling (fiat) is a separate concern and does not share this table. Cohort-churn rule (FR-OV-M11) unchanged Settled |
| D25 | Gold unit and precision, and who changes `common` Which gold unit (troy ounce, as `XAU` means, or grams) and how many decimal places, written as an explicit rule in `common` (FR-OV-M5; the home in `common` is DECIDED, D23a). A change to `Money`'s currency handling touches all five consumers of `common`, so it is a wide change that needs reviewing as one, not a mechanical edit. **Gold is analytics-only, so keep the change minimal and additive**: define it as an analytics currency that cannot be chosen as a Company base currency or appear in client currency lists (FR-OV-M17), rather than adding it to the set clients can use. Owner is unassigned (the GL session by default); CM coordinates Femi, GL, CM |
| D26 | Rate provider(s), data licence and cost Which provider supplies fiat and gold rates, whether its terms allow commercial use by an accountancy firm (and storing the series), the cost, and whether a second source is kept as a cross-check. A licence decision as much as a technical one Femi (+ solicitor for the licence) |
| D27 | Which currencies are downloaded All currencies the provider offers, or only those in use by consenting Companies' books plus gold. Femi's wording ("any financial statement from any jurisdiction") reads as all; storing only what is used is smaller and cheaper. Note the platform's existing rule that only some currencies are onboarded for client books, which does not bind a rate table that serves analysis Femi |

Also deferred, in the other documents: UC-OV-11 (the daily rate job), backlog items 8B.4a and 8B.6 to 8B.6c and the rate-related parts of 7B.3 and 8B.9, collected as Wave 10 of `Omniview_v2_Backlog.md`.

---

## 12. Peer feedback log

Planning-level feedback from the other sessions, recorded with its source, so requirements trace to who asked for them.

### 12.1 WEB, 2026-10-04 (feasibility of the tenant widget)

- **Size depends on the ticket model (D5).** A flat thread per tenant is a repoint; real tickets are a new view. Recorded in D5.
- **Owner Admin of several tenants needs no picker:** the widget already follows the selected tenant and `isOwnerAdmin` is per tenant, so being Owner Admin of A and staff in B behaves correctly. Recorded as FR-OV-S19. WEB also found a tenant-switch state bug in the current widget, to be fixed in that build.
- **Unread and polling:** FR-OV-S17. **D12 (now DECIDED: in-app chat, no email):** no push, 15-minute idle sign-out (recorded in D12).
- **Fail closed and keep the draft** is workable: the draft is already cleared only on success and is kept in memory only, not persisted across sign-out. The relay needs a distinguishable code (FR-OV-S15).
- **Consent screen** is feasible as a blocking step before the first ticket; text and version from EA (FR-OV-M8).
- **Cutover gap found:** two places an operator might look and a tenant might write (FR-OV-S18). This also corrects an earlier simplification: retiring `/operator` is gated on legacy threads being resolved, not only on tickets being live (backlog 7C.10).
- **Sequencing:** the widget ships with or after EA's routes, no feature flag (FR-OV-S19).
- **Contract needs written down** (idempotency, machine-readable error codes, body limits, additive routes with CORS): FR-OV-S20..S23. WEB's baseline of today's support thread, for new routes to match where sensible: path-scoped `/tenants/{tenantId}/...`, `Authorization: Bearer <Cognito ID token>` only (no `X-Tenant-Id`), errors shaped `{error, detail?}`, messages `{id, tenantId, senderId, fromOperator, body, sentAt}` oldest first. If tickets: create, a lightweight list, read with an optional `after` cursor, reply, a tiny unread-summary route and a read marker; name the direction field once and do not rename it silently. All are assumptions to re-confirm with whoever owns EA, not a design of EA's routes.
- **Dependency:** WEB builds only against real EA routes, so EA's contract is the gating item, and EA has no owner (`Omniview_v2_EA_Request.md`).

### 12.2 GL, 2026-10-04 (feasibility of the aggregate route, backlog 8B.5)

Source: the GL session's design-only view, from `balance_sheet.kt`, `trial_balance.kt`, `account_balances.kt`, `journal_entry.kt`, the V2 schema, `Auth.kt` and `AuditLogEntry`. A GL route is feasible and GL is the right place for it (it alone holds balances; anywhere else means exporting per-tenant figures). Nothing built or claimed.

- **As-at date is small work.** `journal_entries.entry_date` is a real date column and `JournalEntry.date` maps to it, so it suffices. Reversals behave correctly as at a date (an as-at date between an original and its reversal shows the original, which is correct). Retained earnings is computed from all revenue minus expense with no period close, so a date filter works unchanged. For the tenant-facing balance sheet it is a few lines (an optional as-at date on the use case), which also benefits WEB.
- **Do not reuse that path for the aggregate.** It loads every entry and runs one query per entry for its lines (N+1). Use a repository method that does one grouped SQL sum per Company (lines joined to entries, periods and accounts, by date, status and account type, grouped by type and side), run read-only, with a concurrency limit, so the aggregate never holds per-tenant data longer than the sum.
- **Currency:** lines carry their own currency and GL's money addition throws on a mix, so an off-base Company is excluded before cohorting (FR-OV-M23).
- **Unit:** agree, state the limitation. GL has no intercompany marker, and double counting inflates assets and liabilities together, so the **ratio** is biased, not just the totals (FR-OV-M23, FR-OV-M25).
- **Equity:** total equity is the right base and aggregating by account type is template-independent. Caveats become FR-OV-M23/M25 and D30.
- **Where the logic lives:** a new isolated package with nothing in the core ledger depending on it, so it can be extracted later; pure functions over (tenant, company, currency, segment, values) with cohort, concentration and suppression policy as constructor parameters read only from GL's own config; a redacting `toString` on value-carrying classes; exception messages carry no values; tests that try to defeat it (two-call subtraction, partition subtraction, differencing across dates, and "no per-tenant value appears in captured log output"). Tracing does not exist today; flag it for when it arrives.
- **GL reading EA** is the weakest part and is an assumption to re-confirm. GL's contract needs have been passed to the EA session (see `Omniview_v2_EA_Request.md`): a dedicated internal route callable only by a GL service identity; request a report date; EA applies the consent boundary and returns the consenting set; per tenant, its Companies with nullable industry; no names; strict decoding; no caching; unreachable means 503 and nothing published; effective-dated consent history.
- **Follow-up finding, 2026-10-04: GL has the same latent fall-back as EA** (see NFR-OV-14). `installFishJwtAuth` is called with each service verifier as `serviceVerifier ?: verifier` and its parameters default to the human verifier (kept so about 25 test fixtures need no change); the builders return null when an audience variable is unset. It is not live because every authenticated route goes through the one shared wrapper that lists the human provider first, and there is no service-only route group. Reordering that list, or adding such a group, would turn it into the hole EA found. GL cannot see which service-audience variables are actually set in production (no AWS access); that is CM's to read. Cleaning up the four existing providers is separate from 8B.5 and is a wide, test-heavy change (backlog 8B.9a). **Verified live by CM on 2026-10-04 (backlog 8B.9b):** GL's four service providers each have an audience set (GL confirmed the unsuffixed one is SOP's), so nothing is masked today; today's safety comes from every audience being set, which still leaves the latent point for any future provider (Omniview's) and for the 8B.9a clean-up; EA does not set its GL audience, so EA's GL provider is the human verifier now, harmlessly, because no EA route is service-only. No live exposure in either; the hazard is only for a future service-only route.
- **Sizing, unconfirmed:** (A) the as-at aggregate repository method with an integration test; (B) the pure cohort and suppression domain with defeat tests, the biggest piece; (C) the route, Omniview's provider and the operator log; (D) the EA gateway, blocked on EA's contract. A and B can proceed against a fake EA port. Nothing ships before D8's numbers exist. GL would claim a coordination row before starting.
- **Needs from Femi:** D30, D31, D32 and whether NON_PROFIT member shares need special treatment. **From CM:** Omniview's service identity at GL, GL's at EA, the private path or ALB block, and where the threshold config lives. **From whoever owns EA:** the contract above.

### 12.3 EA, 2026-10-04 (feasibility of the relay, consent record and consenting-tenants route)

Source: the EA session's design-only view, from `Omniview_v2_EA_Request.md` and EA's code. All three are feasible; nothing blocks EA structurally; the gaps are mostly in the contract.

- **Relay (7B.7): small-medium.** Same shape as EA's Approvals Queue: Owner-Admin routes behind `authorizeTenantOwnerAdmin`, a gateway using the existing Cognito service-account pattern (the Education Runtime client already does), storing nothing. **Every** gateway failure (unreachable, non-2xx, unparseable) maps to 503 `support_unavailable`, never to the legacy thread.
- **Corrections to this SRS:** idempotency is at-least-once, not "nothing persisted" (FR-OV-S20); one `support_terms_required` code, 403 (FR-OV-S21); the unread marker and the authoritative quota live in Omniview (FR-OV-S17, S16).
- **Gap found:** nothing alerts support to a new ticket once email is gone (FR-OV-S31, D34).
- **Consent record: small-medium.** New table, Owner-Admin routes, text and version served by EA; append-only and effective-dated (FR-OV-M8). Ownership change is undefined (D9).
- **Consenting-tenants route is bigger than a scaffolded slot, and corrects an earlier assumption.** EA's inbound GL service-auth provider slot exists but its validator is the **human** one (requires an email claim and an active Membership), so a client-credentials token would be rejected today, and EA's authentication also accepts POP, SOP, IM and HR. It needs a service-principal validator, a route group authenticated by the GL provider **only**, and tests. EA will verify that an unset GL audience fails closed (a fall-back to the human verifier would be a security hole) before anything is built.
- **Security finding, written into NFR-OV-14:** with `EA_JWT_SERVICE_AUDIENCE_GL` unset, EA's wiring (`glServiceVerifier ?: verifier`) makes the GL provider the **human** verifier, so a GL-only route would be callable by any tenant user with a valid token. The contract therefore requires service-only route groups to fail closed when the audience is not configured, to use a service-principal validator, and never to fall back. The same rule applies to every service-to-service pair in this design.
- **Staff detail:** D15 above. **"Next boundary" must be stated:** D33.
- **One user, several tenants works:** routes are path-scoped, the gate is per tenant, `/me` returns every tenant with its own owner flag. Consent, tickets and unread are per tenant (two tenants, two consents); WEB must send the tenant of the Company in view; staff-of-B is correctly rejected.
- **Ownership offered:** EA can own the route-contract doc (D3 is now DECIDED, so EA owns it). It needs D5, D1/D2, the boundary rule (D33), D15/D24, and Omniview's private service API plus a Cognito app client from CM. EA will claim a coordination row before editing any shared doc and will not push or merge.

### 12.4 EA, 2026-10-04 (second round: wording checks against r14)

- **Consent bundling** (the most important): two purposes, D35; the ticket-route code is now `support_terms_required`.
- **Identity crossing the boundary:** the opaque user id only (FR-OV-S9, D17).
- **Logging and errors:** fixed error codes only, never raw exception or response text (FR-OV-S14).
- **Error mapping:** EA's existing owner gate answers "forbidden"; the new routes map a non-member to 403 `not_owner_admin` and 404 only for a ticket id (FR-OV-S21).
- **Tenant name:** supplied by the relay on create, accepting a stale label after a rename (FR-OV-S12), instead of an extra EA route for Omniview to call.
- **Polling and blast radius:** a short TTL cache of the unread count only (FR-OV-S26); risk 11 gains the availability point (EA is the authentication substrate every service calls).
- **D33 semantics:** UTC, consent recorded before 00:00 UTC on the 1st of the report month.

### 12.5 WEB, 2026-10-04 (second round: reading SRS 12.4)

Nothing in 12.4 hurts WEB. Recorded:

- **Two consents (D35)** accepted as clearer: the ticket flow is gated only by `support_terms_required`; the market consent is a separate, optional, never-blocking screen.
- **Tenant name from the relay, opaque user id, 403 `not_owner_admin` and 404 only for a ticket id** all fit WEB. The widget treats `not_owner_admin` as the "ask your Owner Admin" text, which also covers a membership revoked mid-session. Message styling (mine versus theirs) uses the direction field, so WEB needs no sender identity in ticket messages.
- **Fixed codes make the list a contract:** enumerated and stable, with a generic fallback for an unknown code (FR-OV-S21).
- **Unread cache:** the badge may lag by up to the TTL, acceptable (FR-OV-S26).
- **Consent copy is content, not error text, and both consents need read and record routes** (FR-OV-M8). A reachable place to revoke the market consent is a small new WEB surface (D36).
- **Sizing unchanged:** the ticket model (D5) is still the swing factor.

---

## 13. EA route contracts and Omniview's private API

### 13.1 The EA contract (EA-owned)

Per D3, the EA session owns the route-contract doc. **DRAFT 1** was written 2026-10-04 (design only, nothing built): EA repo, branch `docs/omniview-v2-ea-route-contracts`, `docs/Omniview_v2_EA_Route_Contracts.md` at SHA `16f5d31` (not pushed; CM merges). Read it with `git -C EA show docs/omniview-v2-ea-route-contracts:docs/Omniview_v2_EA_Route_Contracts.md`. It fixes: tenant ticket routes under `/tenants/{tenantId}/support/*` (create, list, read messages with an `after` cursor, reply, read marker, unread count), Owner Admin only, with a required `Idempotency-Key` forwarded to Omniview, plain-text bodies (4,000 characters proposed), the direction field named `fromSupport`; two separate consent records under `/consents` (support terms, and market-aggregate with a revoke route); a GL-only `GET /api/internal/consenting-tenants?reportDate=` that uses a service-principal validator and fails closed when GL's audience is unset; support-route-only limits and short timeouts to Omniview; and an enumerated, stable error catalogue of twelve codes. **Draft 2** (EA, 2026-10-04, folding in WEB's seven gaps and GL's four) is on FiSH branch `docs/omniview-v2-ea-route-contracts-r2` (`195d7ce`, local; CM merges) and supersedes Draft 1. This SRS is the requirements source it was written against; where the two ever differ, EA's doc governs route shapes and codes and this SRS governs behaviour and decisions.

### 13.2 Omniview's private ticket API (PROPOSED; the contract EA calls)

EA's draft assumed this API. It does not exist yet; this is the proposed shape, for Omniview to confirm when build resumes. **Authentication:** a Cognito service-account token for EA's client, verified by Omniview with a required verifier that fails closed when unconfigured (NFR-OV-14); only that client; never reachable from a tenant browser.

| Route (under `/internal`) | Body or query | Success | Notes |
|---|---|---|---|
| `POST /internal/tickets` | `{tenantId, tenantName, userId, companyId?, body}`, header `Idempotency-Key` | `201` ticket summary | Omniview dedupes by key per tenant (retention window OPEN); `tenantName` is stored as a label |
| `GET /internal/tenants/{tenantId}/tickets?reader={userId}` | none | `200` summaries, most recent activity first | `hasUnread` is computed for the reader |
| `GET /internal/tenants/{tenantId}/tickets/{ticketId}/messages?after=` | optional cursor | `200` messages, oldest first | scoped by the tenantId EA supplies |
| `POST /internal/tenants/{tenantId}/tickets/{ticketId}/messages` | `{userId, body}`, header `Idempotency-Key` | `201` message | a reply on an Answered ticket reopens it (FR-OV-S8) |
| `POST /internal/tenants/{tenantId}/tickets/{ticketId}/read` | `{userId}` | `204` | the read marker, per tenant and reader |
| `GET /internal/tenants/{tenantId}/unread?reader={userId}` | none | `200 {unreadCount, hasUnread, latestReplyAt?}` | a cheap poll |

- **Shapes mirror EA's section 2:** ticket summary `{id, tenantId, status, companyId?, createdAt, lastActivityAt, hasUnread}` with status `OPEN`, `ANSWERED` or `CLOSED`; message `{id, ticketId, tenantId, senderId?, fromSupport, body, sentAt}`. **PROPOSED:** an operator's name is never returned on the tenant-facing side (`fromSupport` only); operators are named only inside Omniview. **Reconciled with EA\'s Draft 2:** the ticket summary carries `subject` (plain text derived by Omniview from the first message, whitespace collapsed, at most 80 UTF-16 code units), not the `preview` proposed in 13.4; create returns `{ticket, message}`; the messages route defaults to the **latest** page with `before` or `after` (not both); Omniview answers `409 ticket_closed` (a reply on a CLOSED ticket, D38) and `409 idempotency_key_reused` (the same key with a different body), which EA passes through.
- **Errors to EA:** 404 `ticket_not_found` (also for another tenant's ticket), 400 `validation_failed`, 429 `quota_exceeded` with `Retry-After`, 401 or 403 for a bad service credential, and 5xx; EA maps anything else to `503 support_unavailable`.
- **Ownership:** Omniview owns the **authoritative per-tenant quota** (the numbers are OPEN, D18; proposal: a cap on open tickets and on messages per day) and the **read marker**, keyed by tenant and reader user (confirming EA's assumption).
- **Limits repeated defensively:** body 4,000 characters and 16 KiB per request. **Timeouts:** every handler answers well inside EA's 3 second read and 5 second write budgets; nothing long-running sits on this path.

### 13.3 Decisions and consequences from the draft

- **Staff fields stay in the GL response.** Counts are computed inside EA so no user id reaches GL, and GL applies the same rules to tenant and staff counts as to everything else (FR-OV-M1). Per-tenant and per-company staff values are per-tenant data in GL's hands for the length of the computation, protected by NFR-OV-7 and NFR-OV-9. The detail is still D15 and D24. **Revised by GL's finding (D40):** the pre-aggregated staff fields cover EA's full consenting set rather than GL's eligible cohort. Proposed: EA returns per-Company `activeStaff` only and GL aggregates over its own cohort.
- **`industryType` is a closed enum decoded strictly (GL):** a new industry value is a **lockstep change** in EA and GL, not merely "additive"; the contract must say so.
- **GL has no service identity at EA today (GL):** it needs a new Cognito client, a token provider and a separate HTTP client that logs nothing; every failure maps to 503 and nothing is published. GL also supplies the tenant-to-Company mapping itself (D37).
- **EA's stated limit (no effective-dated tenant status, no Company creation date)** matters because GL's stateless churn variant (D29) assumes past cohorts can be recomputed. Proposed resolution and its cost: D37.
- **Prerequisites EA names:** D34 (new-ticket alerting) must be settled before the legacy tenant POST is retired, because that ends today's operator email; the new `Idempotency-Key` request header must be added to EA's CORS allow-list for WEB's origin; a version bump's effect on an old consent (default: it lapses until re-accepted) and ownership-change carry-over are legal questions (D9, D33).
- **EA's proposed build order** (when build resumes): consent routes, edge protections, the Omniview gateway and ticket routes, the service-principal validator and GL route, then legacy POST retirement. Sizing is in EA's doc, section 11.

### 13.4 WEB's review of DRAFT 1 (2026-10-04) and Omniview's side

WEB's earlier points are covered. Seven gaps, three of which touch Omniview's own API because EA proxies its shapes. All PROPOSED, to be settled by EA and Omniview in lockstep:

1. **Ticket summary has no label, so the list needs one request per ticket.** Settled in EA's Draft 2: the summary carries `subject`, derived by Omniview from the first message (at most 80 UTF-16 code units); the `preview` proposed earlier is dropped. A free-text subject chosen by the user remains the alternative under D5.
2. **`Retry-After` is unreadable cross-origin** without `Access-Control-Expose-Headers`. Put `retryAfterSeconds` in the 429 body as well (Omniview does so for `quota_exceeded`; EA for `rate_limited`).
3. **The messages cursor returns the oldest 100, with no way to get the latest, and no truncation signal.** Add `limit`, a `before` cursor (older) alongside `after` (newer), and `hasMore` on the list and message responses.
4. **Same key, different body, and the dedupe window:** `409 idempotency_key_reused`; window 24 hours (FR-OV-S20).
5. **A reply on a CLOSED ticket:** D38.
6. **Create should also return the first message:** `POST /internal/tickets` returns `{ticket, message}` (EA's Draft 2).
7. **Body length unit:** UTF-16 code units (FR-OV-S22, settled in EA's Draft 2).

---

## 14. Workflow completeness check (Femi's principle, 2026-10-04)

Femi: a ticket system nobody is told about is "the incomplete build I have been complaining about". Every workflow must state **who is told, what happens if nobody acts, and how it closes** (FR-OV-S32). This is the check across the current plan; a "gap" is an open decision, not a silent assumption.

| # | Workflow | Who is told | If nobody acts | How it closes | Gap / decision |
|---|---|---|---|---|---|
| 1 | Owner Admin raises a ticket | Prodeo staff by an alert (FR-OV-S31); the tenant sees "sent" | Ageing queue and an "awaiting N hours" alert (FR-OV-S29, S31) | An operator replies (Answered) and closes it | Alert channel and on-call (D34); closure policy (D38) |
| 2 | Operator replies | The Owner Admin, by the unread indicator on every FiSH screen (FR-OV-S25); no email (D12) | The reply sits unread; operators should see answered-but-unread ageing (PROPOSED) | Owner Admin follow-up reopens, or an operator closes after N days | An Owner Admin who never opens FiSH is an accepted limitation (FR-OV-S30); closure (D38) |
| 3 | Follow-up on an Answered or Closed ticket | Operators, by the same alert path | Ageing as in 1 | As in 1 | A reply on CLOSED (D38) |
| 4 | Support terms change version | The Owner Admin is re-asked at the next ticket | Raising a ticket is blocked until accepted | Acceptance recorded | Wording and mechanism (D9) |
| 5 | Market consent granted or withdrawn | The Owner Admin sees the state | Nothing needed | Takes effect at the next generation or boundary | Timing (D33, PENDING); where to revoke (D36) |
| 6 | Market report generation | The operator sees a figure, "insufficient cohort", or "not configured" | If the thresholds are unset nothing is shown (fails closed) | n/a | Who sets thresholds and when: D8 (a statistician), a launch gate |
| 7 | A message on a legacy EA operator thread | Operators, today by EA's email and WEB's `/operator` | It stays unanswered if nobody looks; the email is the only alert | Closed when drained (D1/D2) | EA's legacy POST is retired only after D34 is settled |
| 8 | Retention, export and erasure of ticket content | The requesting Owner Admin | A request goes unhandled | A verified request is executed and confirmed | Who handles it and how it is verified (D17, open) |
| 9 | An operator joins or leaves | n/a | A leaver keeps access | Their token or access is revoked | The offboarding steps (D13, D4); a leaver's access is a security item, not only an HR one |
| 10 | A service goes down (the health strip) | Nobody, unless someone looks | A down service goes unnoticed | n/a | D39: passive, no alert |
| 11 | The relay cannot reach Omniview | The tenant sees "support is temporarily unavailable, your text is kept" | Nobody in Prodeo is told | n/a | D39: an alarm on the rate of `support_unavailable` |
| 12 | A tenant hits its ticket quota or rate limit | The tenant gets a 429 | Nobody is told | n/a | Optional: operators may want a signal of abuse (D39) |
| 13 | A daily rate download fails | Deferred with the treasury phase (section 11) | Already specified there: failure alerting, missed-day rule | Backfill or audited correction | Carried into that SPUTO |

### 14.1 GL's application of the principle to the aggregate route (GL, 2026-10-04)

Every case fails closed, and nothing is ever served in place of a figure.

| # | Case | Who is told | If nobody acts | How it closes |
|---|---|---|---|---|
| 1 | Thresholds unset (D8 gate) | The operator, via the fixed `not_configured`, shown as "market reports not configured"; no figures, no partial data | Nothing is ever shown; there is no timer or fallback | Thresholds are set in GL's config (a CM task-definition change, audited); each request re-reads config, so no code redeploy is needed. It leaks nothing about tenants |
| 2 | EA unreachable, slow, non-2xx or undecodable | The operator, via a fixed "temporarily unavailable" 503; GL logs route, status, duration and request id (never a body) for a D39 monitor | The operator retries; nothing is cached, so a stale set is never used | When EA answers |
| 3 | The operator-access log cannot be written (D32, fail closed) | The operator, via the same fixed 503; the only record is the server ERROR log, since the access log cannot record its own failure, which is why the D39 monitor matters here | The route stays closed to figures | When the database is healthy again |
| 4 | Report date is not a valid menu date (not month-end, future, inside the grace lag) | The operator, via a fixed 400 "date not available"; recorded as a row in the access log | n/a | The operator picks a valid date |
| 5 | A cell is suppressed (insufficient cohort, including complementary suppression) | Shown as the one uniform "insufficient cohort" (FR-OV-M21) | It stays suppressed, which is correct behaviour, not a fault | When more tenants consent, or consents change so the rule clears at a later date |
| 6 | Omniview's identity is not configured, or a human token is presented | Nobody operational: the route group is not registered (503) or answers 401; CM sees a configuration error at deploy time (8B.9b) | n/a | CM sets the audience |

Not covered here: whether anyone is actively watching the logs. That is D39, the passive-monitor design. GL guarantees only that every failure writes one fixed-format log line carrying no values, so a monitor can alert on it (FR-OV-M26).