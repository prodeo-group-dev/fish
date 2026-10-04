# Omniview v2 — Backlog (Tasks, Dependency-Ordered)

**Status:** draft, 2026-10-04. The **T** and **O** steps of the second
SPUTO. **Planning only: build, Terraform apply and deploy stay suspended
until Femi says otherwise**, so every build row below is *Not started —
suspended*. Companions:
`docs/Omniview_v2_Software_Requirements_Specification.md` (`FR-OV-*`,
`NFR-OV-*`, decisions `D1`–`D20`), `docs/Omniview_v2_Use_Cases.md`.
This document **fleshes out Waves 7 and 8** of `docs/Omniview_Backlog.md`
(whose rows 7.0 and 8.0 were "needs its own SPUTO"; this is that pass).
Waves 0–4 there are unchanged except 3.5 and 3.6 as already revised.

**Protocol:** claim a row (session + date) as its own small commit before
starting; mark `Done` with a commit reference; never edit another
session's row. Only CM pushes, merges and deploys. Work in another
service's repo needs a row in that repo's COORDINATION file and a message
to its session through the proper channel. Every row names **every** peer
dependency, not the most salient one. Front-end work for client-facing
screens goes through WEB (Omniview's own operator console is exempt).

**Peers:** CM (infra, secrets, review/push/deploy), GL, EA, WEB sessions;
Femi (decisions, DNS, Terraform apply); a solicitor and a statistician
(external, via Femi).

---

## Wave 7A: decide (no code; unblocks everything after it)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 7A.0 | Full SPUTO pass for Product Support (this document set) | Omniview | — | **Done 2026-10-04** (draft, pending Femi's review) |
| 7A.1 | Femi decides the Support-blocking items: D1 (retire interim thread view), D2 (EA's old operator threads), D5 (ticket model; attachments out), D12 (email allowed?), D13 (operator authentication), D17 (ticket data protection, with solicitor), D18 (abuse controls) | Femi (+ solicitor for D17) | 7A.0 | Open |
| 7A.2 | CM + EA confirm D3: Omniview verifies Cognito JWTs and calls EA `/me`, including which Cognito audience WEB's token carries and the `OMNIVIEW_JWT_*` values | CM, EA | 7A.0 | Open |
| 7A.3 | WEB confirms D4: the widget calls Omniview directly, plus Omniview's origin and CORS needs | WEB | 7A.0 | Open |

## Wave 7B: foundation (suspended)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 7B.1 | Remove the write path (backlog 3.6): the reply POST proxy, the reply box in the ported frontend, their tests | Omniview | Femi: resume build | Not started, suspended |
| 7B.2 | Read-only enforcement test: outbound gateways expose no write method (NFR-OV-6). Omniview's own database repositories are exempt; the test covers gateways to other services only | Omniview | 7B.1 | Not started, suspended |
| 7B.3 | Rework `omniview.tf`: a database on the shared RDS (own DB, the manual 5-step creation procedure applies), secrets, `OMNIVIEW_JWT_*`, security group, an ALB/WAF rate rule. The apply must be **targeted** (state has drifted; a full plan would replace the Jenkins admin password) and is Femi's | CM, Femi | 7A.1 (D13, D18), 7A.2 | Not started, suspended |
| 7B.4 | Persistence: Exposed + Flyway, small bounded pool (NFR-OV-11), tickets and replies tables, migration verified against a fresh database | Omniview | 7B.3 (a database to point at; local work can use Postgres) | Not started, suspended |
| 7B.5 | Inbound auth module: Cognito JWT verification (no defaults) + EA `/me` gateway, 3-way outcome (member / not member / EA unavailable), **fails closed**; every `/me` field declared explicitly (EA DTO strict-decoding rule: never `ignoreUnknownKeys`) | Omniview | 7A.2 | Not started, suspended |
| 7B.6 | Security baseline for an internet-facing service: CORS limited to WEB's origin, request body and field limits, per-tenant ticket quota, strict CSP on the console (NFR-OV-8, 10) | Omniview | 7B.5 | Not started, suspended |

## Wave 7C: Product Support live (suspended)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 7C.1 | Ticket domain (states Open/Answered/Closed, invariants) and use cases, test-first | Omniview | 7B.4 | Not started, suspended |
| 7C.2 | Owner-Admin ticket API (UC-OV-5, 8, 10): create, list own, read replies. **Adversarial tenant-isolation tests**: another tenant's id, a tampered tenant claim, a non-Owner Admin, EA down | Omniview | 7B.5, 7B.6, 7C.1 | Not started, suspended |
| 7C.3 | Operator ticket API and console view (UC-OV-6): queue, thread, reply, close; tenant-name lookup read-only from EA; text rendered as text | Omniview | 7C.1, 7B.6 | Not started, suspended |
| 7C.4 | Email notification (only if D12 = yes): SES sender and templates; a new ticket to a support mailbox, a reply to the Owner Admin | Omniview, CM (SES identity) | 7A.1 (D12), 7C.2 | Not started, suspended |
| 7C.5 | Retention, export and erasure of ticket content (FR-OV-S13) | Omniview | 7A.1 (D17), 7C.1 | Not started, suspended |
| 7C.6 | **WEB widget:** an Owner Admin raises a ticket and polls replies; an employee sees "ask your Owner Admin" and keeps EA chat (UC-OV-5, 8, 10) | **WEB** | 7C.2 deployed, 7A.3 | Not started, suspended (request via WEB session) |
| 7C.7 | **EA:** stop accepting new tenant posts to the operator thread once WEB switches; no change to `/me`; tenancy-internal chat untouched | **EA** | 7C.6, D1/D2 | Not started, suspended |
| 7C.8 | Backups and a tested restore for the ticket database (NFR-OV-12) | CM | 7B.3 | Not started, suspended |
| 7C.9 | Deploy, then verify live including attempts to cross tenants, forge a tenant claim and replay an expired token | CM, Omniview | 7B.3 applied, Jenkins PAT, DNS records (Femi), 7C.2, 7C.3 | Not started, suspended |
| 7C.10 | WEB retires `/operator` (backlog 3.5) after at least one real operating cycle on tickets | WEB | 7C.9, 7C.6 | Not started, suspended |

## Wave 8A: Market decisions and legal (mostly not code; starts in parallel with Wave 7)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 8A.1 | Femi decides D6 (debt definition, segment list), D7 (gold source, price, date), D14 (unit = Tenant, as-of date), D15 (staff definition), D20 (audience, role separation) | Femi | 7A.0 | Open |
| 8A.2 | Cohort method, minimum sample sizes and concentration threshold set with a statistician (D8) | Femi + statistician | 8A.1 | Open |
| 8A.3 | Consent wording and mechanism; the registering body's confidentiality rules (D9) | Femi + solicitor | — | Open |

## Wave 8B: Market build (suspended; needs Wave 8A and work in three other repos)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 8B.1 | **EA:** consent record (versioned, revocable, Owner Admin only), its routes, and an operator-only route listing consenting tenant ids with counts (D16) | **EA** | 8A.3 | Not started, suspended |
| 8B.2 | **WEB:** consent screen for the Owner Admin (UC-OV-9) | **WEB** | 8B.1 | Not started, suspended |
| 8B.3 | **GL:** as-at-date balance sheet (today it uses all posted activity) | **GL** | 8A.1 (D14) | Not started, suspended |
| 8B.4 | **GL:** explicit debt flag on liability accounts, seeded Loans Payable flagged, a coverage count (FR-OV-M3a) | **GL** | 8A.1 (D6) | Not started, suspended |
| 8B.5 | **GL design, then build:** an operator-only, totals-only aggregate route. Takes an allow-list of tenant ids, a rate table and a date; sums each tenant's Companies; converts to gold; applies cohort, concentration and complementary suppression **inside GL**; returns the whole table (market and segments) as totals and counts only; audited; never logs per-tenant values (NFR-OV-9). **It must be its own route with its own authorization for Omniview's identity: GL's existing service-account bypass skips the tenant check and must not be reused** | **GL** | 8B.3, 8B.4, 8A.2 (D8), 8B.1, D10 | Not started, suspended |
| 8B.6 | Gold rate table and its maintenance screen (UC-OV-11); report refuses a date with no rate | Omniview | 8A.1 (D7), 7B.4 | Not started, suspended |
| 8B.7 | Market report API and view (UC-OV-7, 12): the labels, the suppressed-cell display, a response-shape guard that rejects anything per-tenant from GL | Omniview | 8B.5, 8B.6, 8B.1 | Not started, suspended |
| 8B.8 | **Adversarial non-identification suite:** differencing across time and consent churn, complementary suppression, the allow-list count, dominance, small cells, logs and error text. Statistician reviews the cases | GL, Omniview, statistician | 8B.5, 8B.7 | Not started, suspended |
| 8B.9 | Authorize Omniview as a caller of the GL route (identity, secret, env) | CM, GL | 8B.5 | Not started, suspended |
| 8B.10 | Deploy and verify live with real consenting tenants | CM, Omniview, GL | 8B.1–8B.9, Wave 7C deployed | Not started, suspended |

## Wave 9: parked, with reasons

| # | Item | Why parked |
|---|---|---|
| 9.1 | Education Runtime status (`docs/omniview-er-status-sputo`, unmerged) | Femi: ER is an industry sub-segment; its own SPUTO later |
| 9.2 | Stored snapshots and trends | Revocation and differencing make this risky (FR-OV-M9) |
| 9.3 | Consolidation of intercompany balances inside one tenant | GL has none; reports state the limit until it exists |
| 9.4 | Attachments on tickets | An upload surface on an internet-facing service; large risk, little value for v2 (D5) |
| 9.5 | Real operator identity system | Only if D13 chooses to keep the token bridge |

---

## Dependency chain

```
7A.1 (Femi) ─┬─> 7B.3 (CM + Femi apply) ─> 7B.4 ─> 7C.1 ─> 7C.2 ─> 7C.6 (WEB) ─> 7C.9 ─> 7C.10
7A.2 (CM/EA) ─┴─> 7B.5 ─> 7B.6 ─────────────┘     7C.1 ─> 7C.3 ───────────────┘
7A.3 (WEB) ────────────────────────────────> 7C.6
7B.1 ─> 7B.2   (independent of the rest of 7B)

8A.1/8A.2/8A.3 (Femi, statistician, solicitor)
  8A.3 ─> 8B.1 (EA) ─> 8B.2 (WEB)
  8A.1 ─> 8B.3, 8B.4 (GL) ─┐
  8A.2 ─────────────────────┴─> 8B.5 (GL, needs 8B.1) ─> 8B.9 ─> 8B.7 <─ 8B.6 ─> 8B.8 ─> 8B.10
```

## What can move while the build is suspended

Planning only, none of it code: Femi's decisions in 7A.1 and 8A.1;
CM + EA + WEB confirming D3 and D4 (7A.2, 7A.3); starting the solicitor
and statistician conversations (8A.2, 8A.3); and the GL session writing
its design for 8B.5, which is the longest pole and the riskiest piece.

## Recommended order, with reasons

1. **Wave 7 (Support) before Wave 8 (Market).** Agreed with the seed. Support needs no change in any other service's code (D3 is a pattern that already exists), unblocks retiring `/operator`, and delivers value alone. Market needs new code in GL, EA and WEB, a consent mechanism that does not exist, a statistician and a solicitor.
2. **Start 8A (decisions and legal) alongside Wave 7**, because it is the slowest and depends on people, not engineering.
3. **Inside Market, liabilities-to-equity before debt-to-equity** (FR-OV-M3a): the first needs no new account concept in GL, the second needs the debt flag and coverage.
4. **Never ship Market without 8B.8.** A report that works but cannot be shown to resist differencing is the outcome the SRS ranks worst.
