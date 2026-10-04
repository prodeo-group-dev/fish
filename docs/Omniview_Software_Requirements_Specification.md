# Omniview — Software Requirements Specification

**Status:** draft, 2026-10-03. Companion to `docs/Omniview_Extraction_DDD_Design.md`
(the architecture/extraction design, already agreed with CM and the
EA-fork session) — this document formalizes that agreed design into
requirements form; it does not re-open anything already decided there
(repo name, domain, auth mechanism, data-ownership seam).

---

## 1. Introduction

### 1.1 Purpose

This SRS defines the functional and non-functional requirements for
**Omniview**, the Prodeo Group's cross-platform operator oversight
console. It guides the initial build (repo `fish-er-omniview`) and
serves as the baseline Femi, CM, and the EA-fork session are building
against.

### 1.2 Scope — the problem this solves

**The problem, stated plainly:** there is no single place to see how
the whole platform is doing. Today, answering "is everything healthy,
which Tenants need attention, what's in the support queue" means
checking EA's `/operator` page for Tenant/support status, separately
checking each service's own `/health` endpoint or AWS console for
reachability, and having no visibility into ER/Education Runtime at
all from any of it. As the platform has grown from one service to
eleven repos across two product families (FiSH and ER), this
fragmentation has grown with it — and Prodeo is actively hiring an
operations team who will need this view and currently have nowhere to
get it.

**What Omniview is:** *"where I oversee everything in the
FiSH+ERverse"* (direct instruction, 2026-10-03) — a single,
operator-facing console giving cross-service, cross-tenant visibility
platform-wide. Internal tooling only; never client-facing, the same
"strictly for management and support" boundary the original operator
overview inside EA was built under.

**What Omniview is not:** a second system of record for any *other service's* data.
Omniview owns exactly one domain of its own: Prodeo Capital's product-support
tickets (§3.5, added 2026-10-04). Every sibling service keeps owning its own data; Omniview calls out
and aggregates/presents, never absorbs. It is also explicitly not
(yet) a financial-data or deep business-data surface — see §3.4 and
the DDD design's own staged-phase framing.

In scope for this SRS: the three capabilities that exist today inside
EA and are being extracted out (platform health, cross-tenant
overview, read-only operator messaging), plus the console itself (sign-in,
layout). Out of scope: any new data source beyond what already exists
(ER/Education Runtime status, GL financial signals — both explicitly
future work, not designed here).

### 1.3 Definitions, Acronyms and Abbreviations

| Term | Definition |
|---|---|
| Operator | Prodeo's own platform management/support staff (today: Femi alone; an ops team is being hired) — never a Tenant's own staff |
| Tenant | A FiSH/ER customer organization, as EA already models it |
| Sibling service | Any of GL, POP, SOP, IM, HR, EA, ER/Education Runtime — the services Omniview observes but never owns data for |
| Operator token | `X-Operator-Token`, EA's existing interim per-operator auth bridge (`EA_OPERATOR_TOKENS`) — reused, not replaced, by Omniview |
| FiSH+ERverse | The user's own term for the combined FiSH (financial/GL-rooted) and ER (Education/operations-rooted) platform family Omniview oversees |

### 1.4 References

- `docs/Omniview_Extraction_DDD_Design.md` — the architecture this SRS formalizes; read first for the *why* behind every design call referenced here.
- `EA/EA_Development_Backlog.md` item 09 — the original "operator's own half moved to Omniview, not the Tenant's own send/read surface" boundary.
- `docs/Tenancy_Administration_Extraction_DDD_Design.md` — the precedent extraction this one's structured after.

### 1.5 Overview

Section 2 describes Omniview at a product level. Section 3 states
functional requirements by capability. Section 4 covers data
requirements (what's read, never owned). Section 5 covers external
interfaces (every sibling Omniview calls). Section 6 covers
non-functional requirements. Section 7 holds open items.

---

## 2. Overall Description

### 2.1 Product Perspective

Omniview is a new, standalone sibling service — not a module inside
any existing one. It sits *above* every other service, observing
them, rather than beside them in the usual peer-to-peer calling
pattern:

```
flowchart TD
  Op[Operator, browser] --> OV[Omniview backend]
  OV -->|forwards operator token| EA[EA /operator/*]
  OV -->|public, unauthenticated| GL[GL /health]
  OV -->|public, unauthenticated| POP[POP /health]
  OV -->|public, unauthenticated| SOP[SOP /health]
  OV -->|public, unauthenticated| IM[IM /health]
  OV -->|public, unauthenticated| HR[HR /health]
```

Every arrow out of Omniview is read-only, **by design, not just today**:
Omniview may read from FiSH but never writes back into another service
(Femi's direct decision, 2026-10-04). It issues only `GET` requests to
any sibling; no `POST`/`PUT`/`PATCH`/`DELETE` path to EA or any other
sibling exists or may be added (NFR-OV-6). The earlier plan for the
operator to reply by writing into EA (FR-OV-10) is superseded.

**It is not Omniview's business to write into any tenancy's data**
(Femi, 2026-10-04). Nothing in a tenancy is ever altered by Omniview:
not KYB status, not messages, not staff, not the ledger. A ticket may
carry a tenant ID as a reference, but that is Omniview's own record, not
a change to the tenancy. Two consequences:

- **FiSH pulls, Omniview never pushes.** FiSH's chat calls Omniview to
  raise a ticket and reads the replies back from Omniview. Omniview
  never pushes a reply or a notification into a tenant's side.
- **Resolving a ticket changes only Omniview's own record.** Any change a
  ticket calls for in a tenancy is made by whoever owns that data, never
  by Omniview.

**Product support is Omniview's own (Femi, 2026-10-04):** a chat started
inside FiSH by a tenant's Owner Admin is ticketed in Omniview (only the
Owner Admin raises a ticket; Femi, 2026-10-04) and answered
by a Prodeo Capital operator from Omniview (§3.5). That data is
Omniview's own, in Omniview's own database, so it is not a write into
another service. It also gives Omniview its first *callers*: FiSH's chat
reaches Omniview to raise a ticket and to read replies back.

**EA is not Omniview.** EA is the *tenancy's* own mini-Omniview: the
communication between a tenant's owner and staff continues in EA,
unchanged. Product support to Prodeo Capital is a separate channel and
lives in Omniview.

### 2.2 Product Functions (Summary)

| Capability | Primary function |
|---|---|
| Platform Health | At-a-glance reachability for GL/POP/SOP/IM/HR |
| Platform Overview | Every Tenant's onboarding/KYB/support status at once |
| Operator Messaging (interim) | Read-only view of EA's existing operator threads, until Product Support replaces it |
| Product Support (draft) | Tickets raised from inside FiSH by a tenant's Owner Admin are owned by Omniview and answered by Prodeo operators from it (§3.5) |
| Console | Sign-in (operator token entry), layout hosting the above |

### 2.3 User Classes and Characteristics

| User class | Description | Technical proficiency |
|---|---|---|
| Platform operator | Prodeo's own management/support staff; views cross-tenant, cross-service status; triages and answers product-support tickets (§3.5, draft) | Moderate — internal staff, not a general public user |

There is exactly one user class. Unlike every client-facing FiSH/ER
product, Omniview has no Tenant-side user at all — that's the whole
point of the EA/Omniview split (§1.2; *"EA is for each tenancy"*).

### 2.4 Operating Environment

- Cloud-first SaaS, AWS (ECS/Fargate), same infrastructure shape as every sibling.
- Kotlin/Ktor/Exposed backend, matching the established platform stack — no new technology introduced.
- Desktop-first (an operator's own workstation); no stated mobile requirement, unlike client-facing products.
- Domain `omniview.theprodeogroup.com`.

### 2.5 Design and Implementation Constraints

- **Never a second system of record for another service's data.** Every requirement in §3 except §3.5 is read-through to a sibling's own data; Omniview persists nothing of another service's domain state (§4). The one thing it persists is its own product-support tickets (§3.5), which no other service owns.
- **No new auth mechanism.** Reuses EA's existing operator-token bridge end-to-end — resolved 2026-10-03 after a real design correction (a service-account approach was proposed, then withdrawn once it was shown to undo per-operator attribution; see DDD design §1).
- **No EA-side code changes required.** EA's existing `/operator/*` routes are called as-is.
- Must not introduce any new financial/revenue/transaction data surface — the same boundary the original operator overview inside EA was built under.

### 2.6 Assumptions and Dependencies

- EA's `/operator/tenants`, `/operator/support-threads`, `/operator/tenants/{tenantId}/support-thread/messages` routes remain stable and reachable — Omniview has no fallback if EA is down (its own platform-health check would simply show EA as unreachable, same as any other sibling).
- GL/POP/SOP/IM/HR's public `/health` endpoints stay unauthenticated, as they are today.
- An operator already holds (or is issued) a valid EA operator token — Omniview does not provision or rotate these; that stays EA's own `EA_OPERATOR_TOKENS` secret.

---

## 3. System Features (Functional Requirements)

Each requirement is `FR-OV-<n>`, priority per MoSCoW (M = Must, S =
Should, C = Could).

### 3.1 Platform Health

| ID | Requirement | Priority |
|---|---|---|
| FR-OV-1 | System shall check GL, POP, SOP, IM, HR reachability in parallel, not sequentially | M |
| FR-OV-2 | System shall treat GL specially: liveness determined by the presence of an `X-Request-Id` response header on its `/api` root (GL's own `/health` is deliberately ALB-only, unreachable publicly), not by HTTP status | M |
| FR-OV-3 | System shall treat a non-2xx response, a connection failure, or a timeout as "down," each distinguishable in the response (`detail` field) | M |
| FR-OV-4 | System shall report per-service latency when reachable | S |
| FR-OV-5 | System shall report a service with no configured URL as down without attempting a call | S |

### 3.2 Platform Overview

| ID | Requirement | Priority |
|---|---|---|
| FR-OV-6 | System shall show every Tenant at once: name, status, segment, KYB status, phone-verification status, company count, staff count, support-message count, awaiting-reply flag | M |
| FR-OV-7 | System shall source this data by calling EA's existing `GET /operator/tenants`, forwarding the operator's own token — never by querying EA's database directly or duplicating its schema | M |
| FR-OV-8 | System shall display no revenue, transaction, or other financial/business data in this view | M |

### 3.3 Operator Messaging (read-only)

| ID | Requirement | Priority |
|---|---|---|
| FR-OV-9 | System shall list every Tenant's operator-thread messages, grouped by Tenant, most recent first | M |
| FR-OV-10 | ~~System shall let the operator reply within a Tenant's thread~~ **SUPERSEDED 2026-10-04.** Replies are never written into EA. Product-support replies live in Omniview's own ticket store (FR-OV-S3). ID retained for traceability | S |
| FR-OV-11 | System shall source thread data via EA's existing `GET /operator/support-threads` only, forwarding the operator's own token — Omniview holds no message data of its own and issues no write to EA | M |

### 3.4 Explicitly Out of Scope

Per the DDD design's staged-phase framing (2026-09-19 original
instruction: *"start with lightweight health, grow into ER status,
then GL financial data as need for support and data analysis
increases"*):

| ID | Requirement | Priority |
|---|---|---|
| FR-OV-12 | ER/Education Runtime status data | **Future** — not designed, not built |
| FR-OV-13 | GL or any sibling's financial/revenue data | **Future** — not designed, not built. The first slice is aggregate-only market reporting (§3.6, draft) |

These are named here only so a future SRS revision has an explicit
anchor point — building either without a fresh design pass is
out of scope for this document.

### 3.5 Product Support Ticketing (DRAFT, 2026-10-04 — needs its own SPUTO pass before any build)

Direction from Femi: *"Omniview is where tenant support will live. The
chat initiated from inside FiSH by a tenant or an employee will be
ticketed for response and responded to from the Omniview side."* Also:
*"EA is a mini-Omniview for the tenancy. That communication must
continue. However product support must come to Prodeo Capital."*
Clarified by Femi in the same exchange: *"Only the Owner Admin raises a
call to the Omniview"*; the "tenant or an employee" wording in the first
quote is superseded by this.

| ID | Requirement | Priority |
|---|---|---|
| FR-OV-S1 | A chat started inside FiSH by a tenant's Owner Admin shall create a support ticket owned by Omniview. **Only the Owner Admin raises a ticket; employees do not** (Femi, 2026-10-04) | Draft |
| FR-OV-S2 | A Prodeo operator shall triage and answer tickets from Omniview | Draft |
| FR-OV-S3 | Tickets and replies shall be stored in Omniview's own database, never written into EA or any other FiSH service (NFR-OV-6) | Draft |
| FR-OV-S4 | The person who raised a ticket shall see the replies in the FiSH chat, read back from Omniview. FiSH pulls the reply; Omniview never pushes a reply or notification into FiSH or any tenancy | Draft |
| FR-OV-S5 | EA's tenancy-internal communication (owner and staff of one tenant) shall be unchanged and not conflated with product support: two separate channels | Draft |
| FR-OV-S7 | Closing or resolving a ticket shall change only Omniview's own ticket record. Any change a ticket calls for in a tenancy's data is made by the service that owns it, never by Omniview | Draft |
| FR-OV-S6 | Disposition of EA's existing operator-thread messages (migrate history, or leave as legacy) is OPEN; see §7.1 | Open |

Decided: only a tenant's Owner Admin raises tickets (Femi, 2026-10-04).
Not designed yet: ticket states and ownership, authentication of the
Owner Admin caller, notifications, retention
and privacy, and SLAs. Those are the SPUTO pass's job; none are assumed here.

### 3.6 Market Reporting: aggregate, non-identifying (DRAFT, 2026-10-04 — needs its own SPUTO pass before any build)

Direction from Femi: Omniview can generate for Prodeo Capital a report
summary: the number of tenants, the number of staff, the capitalisation
of the market and the leverage of the market. They are **aggregate,
non-identifying reports**. Read-only throughout (NFR-OV-6).

| ID | Requirement | Status |
|---|---|---|
| FR-OV-M1 | Report the number of tenants and the number of staff, from EA's existing operator overview (both already available per tenant, summed) | Draft |
| FR-OV-M2 | Capitalisation of the market = aggregate shareholders' funds, taken from standard balance-sheet figures | **Decided** (Femi) |
| FR-OV-M3 | Leverage of the market is reported as **both** ratios, each analysed as an aggregate across the entire SME market: total liabilities to equity, and debt to equity. Each is a ratio of aggregate totals (aggregate liabilities or debt over aggregate shareholders' funds), never an average of per-tenant ratios, so no per-tenant figure is ever needed (NFR-OV-7) | **Decided** (Femi: both; ratio-of-totals is CM's reading of "aggregate", to be confirmed) |
| FR-OV-M4 | Every report is available for the whole market and for a segment | **Decided** (Femi: "both") |
| FR-OV-M5 | All fiat currencies are translated into gold value; **gold is the base currency for Prodeo Capital's market analysis** | **Decided** (Femi) |
| FR-OV-M6 | Every published figure obeys NFR-OV-7 (non-identification), with no exceptions | **Sacrosanct** (Femi) |

**Open, not assumed:**
- *What counts as "debt"* for the debt-to-equity ratio (borrowings only, or interest-bearing items more broadly), and which balance-sheet lines make up "liabilities" and "shareholders' funds".
- *Segment dimensions:* what a segment is (jurisdiction, tenant segment, industry, others).
- *Gold translation:* which gold price source, which price (spot or a published fix), and as of which date. Suggested starting point: the closing rate at the balance-sheet date, which is how balance-sheet items are translated in accounting. Each report should show the rate used, since gold-denominated values move with the gold price alone.
- *Where the aggregates are computed.* CM's recommendation: GL computes per-currency totals behind a new operator-only route that returns totals only and applies the minimum-cohort rule at the source, so Omniview never holds any tenant's own figures; Omniview then translates to gold from its own rate table. GL has no operator concept and no cross-tenant read route today, so this is new design in GL, not in Omniview alone.
- *Minimum cohort size:* to be **determined statistically (minimum sample sizes)**, per Femi. The method and the resulting numbers are for the SPUTO pass, ideally with a statistician's input. This pass must also set the concentration rule (the largest share one tenant may hold of a published total), since a statistical minimum alone does not prevent identification. No number is assumed here. Separately, **tenants' permission for aggregate use will be taken** (Femi, 2026-10-04); the mechanism and wording (for example the terms an Owner Admin accepts) are for the legal pass and are not designed here.
- *Whether Omniview stores report snapshots* (aggregate figures only, never per-tenant) to show trends.

---

## 4. Data Requirements

Omniview's own persistence (if any) is limited to its own operational
concerns — **never** another service's domain data:

| Data | Owned by | Omniview's relationship |
|---|---|---|
| Tenant/Membership/KYB status | EA | Read-through, via API call, never cached beyond the request/response |
| Existing operator-thread messages | EA | Read-through only, via API call, interim. No write-through; disposition open (FR-OV-S6) |
| Product-support tickets and replies | **Omniview** | Omniview-owned, in its own database (§3.5, draft) |
| Market aggregates (tenant and staff counts, equity, leverage) | EA and GL | Read-only. Aggregates only, never per-tenant (NFR-OV-7). Source and where computed are open (§3.6) |
| Gold price series | **Omniview** (own data) | Omniview-owned rate table used to translate fiat to gold (§3.6, draft) |
| Service health | N/A (derived) | Computed fresh on each request, not stored |
| Operator token | Operator's own browser (entered at sign-in) | Held client-side for the session, forwarded per-request — see §7.1 for the open question on exactly how |

**Omniview-owned data (new 2026-10-04):** product-support tickets and
replies (§3.5) live in Omniview's own database, so Omniview is no longer
stateless. This is the only data Omniview owns; everything else stays
read-through. Any further Omniview-owned state (an acknowledged-alert flag,
a saved filter) is still a separate, scoped decision, per this project's
"minimal builds" discipline.

---

## 5. External Interface Requirements

| Interface | Direction | Purpose |
|---|---|---|
| EA `/operator/tenants` | Outbound | Platform overview (FR-OV-6/7) |
| EA `GET /operator/support-threads` | Outbound (read-only) | Operator messaging (FR-OV-9/11). `POST /operator/tenants/{id}/support-thread/messages` is **not** used by Omniview (FR-OV-10 withdrawn) |
| GL `/api` (root, `X-Request-Id`-based check) | Outbound | Health (FR-OV-2) |
| POP, SOP, IM, HR `/health` | Outbound | Health (FR-OV-1/3/4) |
| Omniview's own `/operator-health`, `/operator-overview`, `/operator-messages` (naming TBD, see §7.2) | Inbound | The browser console's own calls to its backend |

Omniview now has one inbound interface (new 2026-10-04, draft): FiSH's
chat reaches Omniview to raise a ticket and to read replies back
(FR-OV-S1/S4). Whether that goes through WEB, EA, or directly, and how the
caller is authenticated, is open (§7.1). No other service calls into
Omniview.

---

## 6. Non-Functional Requirements

| ID | Requirement |
|---|---|
| NFR-OV-1 | Health checks across all five services shall complete in roughly the time of the single slowest check, not their sum (parallel execution, already built — `coroutineScope`/`async`) |
| NFR-OV-2 | Per-operator action attribution and individual token revocation shall be preserved end-to-end for every EA-calling capability — the explicit reason the service-account approach was rejected (DDD design §1) |
| NFR-OV-3 | No EA-side route, auth mechanism, or schema change required to ship this — a constraint, not just a nicety, agreed directly with the EA-fork session |
| NFR-OV-4 | No new financial/business data of any kind surfaced in this release (§3.4) |
| NFR-OV-7 | **Non-identification is sacrosanct (Femi, 2026-10-04).** Every figure Omniview publishes about the market shall be an aggregate that identifies no tenant. There shall be no per-tenant figure or breakdown anywhere: not in any view, API, export, log or stored snapshot. Each published figure shall cover at least a minimum number of tenants, **determined statistically (minimum sample sizes), not chosen arbitrarily** (Femi, 2026-10-04); anything below it is suppressed. A statistical minimum makes an estimate reliable, but it does not by itself make a figure non-identifying, because one dominant tenant can reveal itself in a large cohort. So a concentration rule applies as well (no single tenant may account for more than a set share of a published total), and the stricter of the two tests governs. Suppression shall also defeat differencing, so that a total and its segments can never be combined to derive a small segment. Enforced in code with tests, not by convention. Tenants' permission for aggregate use shall be taken before any report is shown (Femi, 2026-10-04). **No cohort is ever large enough to waive these rules**: even with a hundred million tenants, the concentration rule, the suppression rule and the ban on per-tenant breakdowns still apply in full | Draft |
| NFR-OV-6 | Omniview shall be strictly read-only toward every other FiSH service: its outbound gateways issue only `GET`, and no write method (`POST`/`PUT`/`PATCH`/`DELETE`) to any sibling shall exist in its code. Its only writes are to its own support-ticket database (§3.5). Omniview shall never write into any tenancy's data (Femi: it is not its business); a ticket may reference a tenant ID, nothing in a tenancy is altered. Verified by a test asserting the gateways expose no write operation, and enforced in review. Added 2026-10-04 on Femi's direct decision |
| NFR-OV-5 | Deployed the same way every sibling is (ECS/Fargate, Jenkins CI/CD) — no bespoke infrastructure |

---

## 7. Appendices

### 7.1 Open Issues / TBDs

- **How an operator's EA token gets into Omniview.** Candidate (not yet built): Omniview's own sign-in gate asks for the same EA operator token directly, mirroring WEB's existing pattern — one more hop on the existing "bridge until real identities exist" mechanism, not a new one. See DDD design §4.3.
- **Disposition of EA's existing operator-thread messages** (FR-OV-S6): migrate history into Omniview, or leave as legacy. Not decided. EA's tenancy-internal communication is unaffected either way.
- **Product-support ticketing design (§3.5):** ticket model and states, how an Owner Admin caller authenticates into Omniview (Cognito directly, or proxied through WEB/EA), whether the chat widget calls Omniview directly or via WEB/EA, notifications, retention, privacy and data residency, SLAs. Needs its own SPUTO pass.
- **Exact Omniview-side route names** for the browser-facing API (§5's "naming TBD") — not yet designed; see the Use Case document's own flows for the shape these need to support.

### 7.2 Traceability to the DDD Design

Every FR-OV requirement in §3 traces to a decision already made and
agreed in `docs/Omniview_Extraction_DDD_Design.md`:

- FR-OV-1 through FR-OV-5 → DDD §0/§2 item 1, `PlatformHealthGateway` (the one clean, zero-dependency move).
- FR-OV-6 through FR-OV-11 → DDD §1's resolved auth mechanism and "one real seam" — the gateway-via-token-forwarding pattern, not a data migration.
- FR-OV-12/13 → DDD §2's explicit staged-phase boundary.
