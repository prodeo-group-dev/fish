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

**Revised 2026-10-04: never internet-facing** (Femi: "IT CAN NEVER BE
INTERNET FACING"; corrected seed, FiSH PR #61). Omniview is private-network
only; tickets reach it only through a FiSH service (PROPOSED: EA relays;
D3). Waves 7A–7C below are reshaped around that: no public hostname,
listener rule or certificate, no JWT verification inside Omniview, and a
new EA task for the relay.

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
| 7A.0 | Full SPUTO pass for Product Support (this document set) | Omniview | — | **Done 2026-10-04**, revised same day for the private-only rule (draft, pending Femi's review) |
| 7A.1 | Femi decides the Support-blocking items: D1 (retire interim thread view), D2 (EA's old operator threads), D5 (ticket model; attachments out), D12 (email, and who sends), D13 (operator authentication), D17 (ticket data protection, with solicitor), D21 | Femi (+ solicitor for D17) | 7A.0 | Open |
| 7A.2 | Confirm **D3**: EA as the relay, and service-to-service authentication to Omniview (a Cognito service-account audience for EA, plus a security-group restriction) | CM, EA, then Femi | 7A.0 | Open |
| 7A.3 | **D4: how operators reach a private Omniview** (VPN, SSM port-forward, or another internal-only path). The shared load balancer is public, so this needs a different path; it also decides when WEB's public `/operator` can be retired | CM, Femi | 7A.0 | Open |
| 7A.4 | WEB confirms the widget now calls **EA's** ticket routes (a repoint of the existing support-chat client), never Omniview | WEB | 7A.2 | Open |

## Wave 7B: foundation (suspended)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 7B.1 | Remove the write path (backlog 3.6): the reply POST proxy, the reply box in the ported frontend, their tests | Omniview | Femi: resume build | Not started, suspended |
| 7B.2 | Read-only enforcement test: outbound gateways expose no write method (NFR-OV-6). Omniview's own database repositories are exempt; the test covers gateways to other services only | Omniview | 7B.1 | Not started, suspended |
| 7B.3 | **Private-only** `omniview.tf`: no public ALB rule, certificate or DNS name (the earlier version was reverted for exactly that). An internal path for the relay and for operators (D4), a database on the shared RDS (own DB, the manual 5-step creation procedure), secrets, a security group admitting only the relay's group and the operator access path. Controlled outbound access for its calls to EA/GL/health endpoints (and SES if D12 says Omniview sends). **Also, for Wave 8: a private path from GL to EA's operator route (a public service today), with the same not-reachable-beyond-gating treatment.** (A GL-to-Omniview rate read and a controlled egress for a rate download are deferred with the treasury phase, Wave 10.) The apply must be **targeted** (state has drifted; a full plan would replace the Jenkins admin password) and is Femi's | CM, Femi | 7A.2, 7A.3 | Not started, suspended |
| 7B.4 | Persistence: Exposed + Flyway, small bounded pool (NFR-OV-11), tickets and replies tables, migration verified against a fresh database | Omniview | 7B.3 (a database to point at; local work can use Postgres) | Not started, suspended |
| 7B.5 | **Service-to-service authentication** for inbound calls (NFR-OV-14): verify a Cognito service-account credential with the relay's audience (no defaults), fail closed. **No human JWT verification and no `/me` call inside Omniview** | Omniview | 7A.2 | Not started, suspended |
| 7B.6 | Console and input hardening: strict CSP on the operator console, text-only rendering of ticket content, body and field size limits (NFR-OV-8, 10). No CORS configuration is needed because no browser calls Omniview from another origin | Omniview | 7B.5 | Not started, suspended |
| 7B.7 | **EA relay routes** (EA session): Owner-Admin ticket create / list / read routes that verify the Owner Admin with EA's existing gate, apply the per-tenant quota and size limits, call Omniview privately as a service, **store no ticket content**, and fail closed when Omniview is unreachable (FR-OV-S9, S14, S15, S16). EA's existing tenancy-internal chat is untouched | **EA** | 7A.2, 7B.5 (the contract to call), 7A.1 (D1, D2, D18) | Not started, suspended |

## Wave 7C: Product Support live (suspended)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 7C.1 | Ticket domain (states Open/Answered/Closed, invariants) and use cases, test-first | Omniview | 7B.4 | Not started, suspended |
| 7C.2 | Internal ticket API for the relay (UC-OV-5, 8): create, list a tenant's tickets, read replies. **Adversarial tests:** a call without the service credential, a credential with the wrong audience, a request for another tenant's ticket id, a forged tenant id from a non-relay caller | Omniview | 7B.5, 7B.6, 7C.1 | Not started, suspended |
| 7C.3 | Operator ticket API and console view (UC-OV-6): queue, thread, reply, close; tenant-name lookup read-only from EA; text rendered as text | Omniview | 7C.1, 7B.6 | Not started, suspended |
| 7C.4 | Email notification (only if D12 = yes): sender per D12 (Omniview via SES, or the relay), bare "you have a reply" content | Omniview or EA, CM (SES identity, egress) | 7A.1 (D12), 7C.2 | Not started, suspended |
| 7C.5 | Retention, export and erasure of ticket content (FR-OV-S13) | Omniview | 7A.1 (D17), 7C.1 | Not started, suspended |
| 7C.6 | **WEB widget:** an Owner Admin raises a ticket and reads replies **through EA's ticket routes**; an employee sees "ask your Owner Admin" and keeps EA chat (UC-OV-5, 8, 10) | **WEB** | 7B.7 deployed, 7A.4 **Ships with or after 7B.7's routes, no feature flag; fixes the tenant-switch state bug; needs from EA: ticket model (D5), create/list/read shapes, a distinguishable 503 code, a server-side unread marker, consent text/version routes (WEB feedback, SRS 12.1).** | Not started, suspended (request via WEB session) |
| 7C.7 | **EA:** once WEB switches, stop accepting new tenant posts to the legacy operator thread; leave `/me` and tenancy-internal chat unchanged (D1/D2) | **EA** | 7C.6 | Not started, suspended |
| 7C.8 | Backups and a tested restore for the ticket database (NFR-OV-12) | CM | 7B.3 | Not started, suspended |
| 7C.9 | Deploy, then verify live: tickets flow only through the relay; **prove Omniview is unreachable from outside** (no public listener, no public DNS, nothing answering from the internet); a forged or missing service credential is refused; an expired Owner-Admin token never reaches Omniview | CM, Omniview, EA | 7B.3 applied, Jenkins PAT, 7B.7, 7C.2, 7C.3, the operator access path from 7A.3 working | Not started, suspended |
| 7C.10 | WEB retires its public `/operator` (backlog 3.5) after at least one real operating cycle on tickets, **and only once operators can actually reach Omniview privately** | WEB | 7C.9, 7C.6, 7A.3 **Also gated on legacy EA operator threads being closed or abandoned (FR-OV-S18): `/operator` is the only reply surface for them, since Omniview cannot write into EA.** | Not started, suspended |

## Wave 8A: Market decisions and legal (mostly not code; starts in parallel with Wave 7)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 8A.1 | Femi decides D15 (staff definition), D20 (audience, role separation), D24 (staff by industry) | Femi | 7A.0 | **Answered 2026-10-04:** D6 (one ratio, total liabilities to shareholders' funds), D14 (tenant and company tests, stricter governs), D22, D28. D7, D23a/b, D25-D27 are deferred to the treasury phase. Still open: D15, D20, D24; D12 (email) is in 7A.1; D8 stays parked as the launch gate |
| 8A.2 | Cohort method, minimum sample sizes and concentration threshold set with a statistician (D8) | Femi + statistician | 8A.1 | **Parked by Femi: "This will be determined later."** Structure stays; **launch gate:** no market figure is published until the numbers exist |
| 8A.3 | Consent wording and mechanism; the registering body's confidentiality rules (D9) | Femi + solicitor | — | Open |

## Wave 8B: Market build (suspended; needs Wave 8A and work in three other repos)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 8B.1 | **EA:** consent record (versioned, revocable, Owner Admin only), its routes, and an operator-only route listing consenting tenant ids with counts (D16), **and per consenting tenant its Companies with each Company's industry (`industryType` is per-Company in EA; GL has none) and per-Company staff assignment counts**, so industry segments can be built (D14, D24). **Readable by GL's service identity as well as Omniview's** (D22) | **EA** | 8A.3 | Not started, suspended |
| 8B.2 | **WEB:** consent screen for the Owner Admin (UC-OV-9) | **WEB** | 8B.1 | Not started, suspended |
| 8B.3 | **GL:** as-at-date balance sheet (today it uses all posted activity) | **GL** | 8A.1 (D14) | Not started, suspended |
| 8B.4 | ~~**GL:** explicit debt flag on liability accounts, seeded Loans Payable flagged, a coverage count (FR-OV-M3a)~~ | **GL** | 8A.1 (D6) | **DROPPED 2026-10-04:** Femi, D6: one ratio, total liabilities to shareholders' funds; debt means liabilities, so no debt flag is needed |
| 8B.5 | **GL design, then build:** an operator-only, totals-only aggregate route, **a GET** (D22). Takes **only a fixed report date and a segment**; **reads the consenting set from EA itself** (so no allow-list comes from the caller); sums each tenant's Companies and **builds industry segments from Companies** (a multi-industry tenant appears in each, D14, DECIDED); reports **per currency with no cross-currency totals** (FR-OV-M18, DECIDED, D28); applies cohort and concentration tests (**at both tenant and company level, the stricter governing**, FR-OV-M13), complementary suppression and the cohort-churn rule (FR-OV-M11, with GL's own record of published cohorts, which is reporting state in the ledger engine and a coupling cost to weigh in the design) **inside GL**; returns the whole table (market and segments) as totals and counts only; audited; never logs per-tenant values (NFR-OV-9). **It must be its own route with its own authorization for Omniview's identity: GL's existing service-account bypass skips the tenant check and must not be reused** | **GL** | 8B.3, 8B.4, 8A.2 (D8), 8B.1, D10, D22, D28 | Not started, suspended |
| 8B.7 | Market report API and view (UC-OV-7, 12): the labels, the suppressed-cell display, a response-shape guard that rejects anything per-tenant from GL | Omniview | 8B.5, 8B.1 | Not started, suspended |
| 8B.8 | **Adversarial non-identification suite:** differencing across time and consent churn (**including a tenant consenting or revoking between two published dates**), complementary suppression, the consenting-set count, **attempts to vary the date, segment or rate to isolate a tenant (a crafted rate against a single-currency tenant)**, dominance, small cells, logs and error text. Statistician reviews the cases | GL, Omniview, statistician | 8B.5, 8B.7 | Not started, suspended |
| 8B.9 | Authorize **the two new paths**: Omniview as a caller of the GL route, and GL as a reader of EA's consent route (service identities, secrets, env), with GL's own route and authorization, **never the existing service-account bypass**. Both are over the private network, neither reachable beyond that gating (see 7B.3). A third path, GL reading rates from Omniview, is deferred with the treasury phase (Wave 10) | CM, GL, EA | 8B.5 | Not started, suspended |
| 8B.10 | Deploy and verify live with real consenting tenants | CM, Omniview, GL | 8B.1–8B.9, Wave 7C deployed | Not started, suspended |

## Wave 9: parked, with reasons

| # | Item | Why parked |
|---|---|---|
| 9.1 | Education Runtime status (`docs/omniview-er-status-sputo`, unmerged) | Femi: ER is an industry sub-segment; its own SPUTO later |
| 9.2 | Stored snapshots and trends | Revocation and differencing make this risky (FR-OV-M9) |
| 9.3 | Consolidation of intercompany balances inside one tenant | GL has none; reports state the limit until it exists |
| 9.4 | Attachments on tickets | An upload surface carrying tenant files through a public relay into the ticket store; large risk, little value for v2 (D5) |
| 9.5 | Real operator identity system | Only if D13 chooses to keep the token bridge |

---

## Wave 10: Treasury & Investment Analysis (DEFERRED, off the critical path)

Femi: "It is not required now" and "This leaving the area of accounting and into the treasury management and investment analysis space... and that will be done later." A separate later SPUTO, like Education Runtime status. **Nothing here is built, scheduled or required for Product Support or Market Support.** Rows are kept verbatim so the later pass starts informed; see SRS §11.

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 10.1 (was 8B.4a) | **`common`:** define gold as an **analytics-only** currency with an explicit unit and precision rule (D25). `XAU` has -1 default fraction digits in the JDK, so today `Money(123.456, XAU)` rounds to 120. **Guardrail (FR-OV-M17): it must not be selectable as a Company base currency or appear in WEB's currency lists**; keep the change minimal and additive, since gold is not a client-reporting currency. Home in `common` DECIDED (D23a). `common` holds types and rules, **not rate data**; it is consumed as source by GL/SOP/POP/IM/HR, so this is a wide change to review as one | Owner TBD (GL session by default), CM, each consumer, WEB (currency lists) | D25 | Deferred |
| 10.2 (was 8B.6) | **Currency rate store (Omniview owns it, D23b DECIDED).** One effective rate per currency per report date, append-only, with source, retrieval time and raw value; bounds check against the prior day; audited corrections that never silently recompute a published report; report refuses a date with no rate (FR-OV-M12, M15, M16). A read-only route GL calls to fetch the published rate (private network, GL's service identity; separate, lightweight, own timeout; published rates are immutable so GL may cache). Maintainers and report readers are separate roles (D20) | Omniview | 8A.1 (D7, D20), 7B.4, 8B.6a | Deferred |
| 10.3 (was 8B.6a) | **Daily rate download job:** scheduled, HTTPS, failure alerting, the month-end missed-day rule (FR-OV-M14, M16). The first scheduled job in Omniview, so it needs monitoring of its own | Omniview | D26 (provider and licence), D27 (which currencies), 8B.6b | Deferred |
| 10.4 (was 8B.6b) | **Controlled egress for Omniview to the rate provider** (private subnets with NAT or an allow-listed egress), costed; Omniview stays private inbound (NFR-OV-8, NFR-OV-16) | CM | D26, 7B.3 | Deferred |
| 10.5 (was 8B.6c) | **Decide the rate provider, licence and cost (D26) and the currency scope (D27)** | Femi (+ solicitor for the licence) | 8A.1 | Deferred |
| 10.6 | The GL-to-Omniview private rate read, its service identity and the circular-call design (a separate lightweight route, its own timeout, GL may cache an immutable published rate). Was part of 7B.3 and 8B.9 | CM, GL, Omniview | 10.2 | Deferred |
| 10.7 | The treasury & investment-analysis SPUTO itself: translating any jurisdiction's statements to a common factor, the rate source and licence, outbound egress, and how client reporting (fiat) stays separate | Omniview + Femi | after Product Support and accounting-terms Market Support | Not started, deferred |

---

## Dependency chain

```
7A.1 (Femi) ──┐
7A.2 (CM/EA, then Femi) ─┬─> 7B.5 ─> 7B.6 ─┐
7A.3 (CM + Femi: D4) ────┤                  ├─> 7C.2 ─┐
                         └─> 7B.3 (CM+Femi) ─> 7B.4 ─> 7C.1 ─┴─> 7C.3 ─┐
7B.5 ─> 7B.7 (EA relay) ─> 7C.6 (WEB) ─> 7C.7 (EA)                      │
7B.3, 7B.7, 7C.2, 7C.3, 7A.3 ──────────────────────────> 7C.9 <────────┘
7C.9, 7C.6, 7A.3 ─> 7C.10 (WEB retires /operator)
7B.1 ─> 7B.2   (independent of the rest of 7B)

8A.1/8A.2/8A.3 (Femi, statistician, solicitor)
  8A.3 ─> 8B.1 (EA) ─> 8B.2 (WEB)
  8A.1 ─> 8B.3, 8B.4 (GL) ─┐
  8A.2 (parked) ─────────────┴─> 8B.5 (GL, needs 8B.1) ─> 8B.9 ─> 8B.7 ─> 8B.8 ─> 8B.10
```

## What can move while the build is suspended

Planning only, none of it code: Femi's decisions in 7A.1 and 8A.1;
CM + EA confirming D3 (7A.2) and CM + Femi settling D4 (7A.3), which is
the one most likely to be underestimated because every operator needs it
before the console is usable at all; WEB confirming 7A.4; starting the
solicitor and statistician conversations (8A.2, 8A.3); and the GL session
writing its design for 8B.5, the longest pole and the riskiest piece.

## Recommended order, with reasons

1. **Wave 7 (Support) before Wave 8 (Market).** Agreed with the seed. Support needs one new piece in one other service (the EA relay, 7B.7, built on identity logic EA already has), unblocks retiring `/operator`, and delivers value alone. Market needs new code in GL, EA and WEB, a consent mechanism that does not exist, a statistician and a solicitor.
2. **Start 8A (decisions and legal) alongside Wave 7**, because it is the slowest and depends on people, not engineering.
3. **One leverage ratio** (D6, DECIDED): total liabilities to shareholders' funds, which GL already computes from `totalLiabilities` and `totalEquity`; no new account concept is needed in GL.
4. **Never ship Market without 8B.8.** A report that works but cannot be shown to resist differencing is the outcome the SRS ranks worst.
