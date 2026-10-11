# Business Owner dashboard: "at a glance" tiles (Playbook)

**Status:** 2026-10-11, planning only (SPUTO: Scope, Plan/SRS, Use cases, Tasks, Order). Nothing is built; no code until Femi approves. **Decisions are asked of Femi in section 7.** Written by the EA session at CM's request, after the brief `docs/EA_Dashboard_At_A_Glance_Brief.md`. Facts read from EA, WEB, GL and POP code on 2026-10-11; GL's two route shapes are GL's own proposals (GL master d862e60), not built.

## 1. Scope (S)

**In:** four additions to the Owner-Admin dashboard (Administration, Dashboard), in Femi's approved order: (1) a "Needs your attention" box, (2) money owed to you / you owe, (3) next due, (4) cash over time. **Out:** bank-feed items (unmatched statement lines, book versus bank balance) until reconciliation exists; a tax-return guidance panel; any change to `GET /me`; showing the dashboard to anyone but the Owner-Admin.

## 2. What exists today, and what the research found

| Need | What exists | Finding |
|---|---|---|
| Pending approvals | EA `GET /tenants/{t}/companies/{c}/approvals-queue` (`ComposeApprovalsQueueUseCase`): SOP customer returns, IM stock adjustments, POP supplier returns, HR payroll runs; read-only; each item has `source` + `id` to deep-link; a failing source is listed in `sourcesUnavailable`, never fails the whole call | **WEB does not call it.** This tile needs no backend change. |
| Outstanding verification | `GET /me` data WEB already holds, plus the existing banner | WEB-only. |
| Money owed to you / you owe | GL's existing aging routes (`POST .../accounts-receivable-aging`, `.../accounts-payable-aging`) need a caller-supplied list of customer or supplier ids (GL has no customer master data) and age **since the sale date**, first-in-first-out, in four buckets. GL holds no payment terms. | Not usable as is. **GL proposes** `GET /companies/{c}/receivables-payables-summary` returning total, `overdueTotal` and `overdueCount` per side, with **overdue = unpaid and more than 30 days old**. True due-date overdue can only come from SOP/POP (they hold terms). |
| True payables due dates | POP `GET /accounts-payable-due-date-aging?currency=&asOfDate=` ages by invoice due date, with `undatedAmount` and `totalOutstanding` | Its CURRENT bucket mixes "not yet due" with "up to 30 days overdue", so exact overdue is not separable there either; POP would need to add an overdue figure. SOP has no receivables due-date aging; no due dates exist for ordinary sales. |
| Next due | POP invoices have `dueDate`, read only by the aging route; no sorted list route found | Needs a small POP read route (nearest 5 unsettled). Receivables side: no due dates. |
| Cash over time | GL has `GET /companies/{c}/cash-books` (balance per book, no history) and a per-book rows route with running balance | **GL proposes** `GET /companies/{c}/cash-balance-series?days=30`: one point per day, end-of-day combined balance of all cash and bank books, dense, opening balance included, one currency per Company today (one series per currency if IAS 21 arrives; GL tells EA first). |

**How the dashboard response works today** (`ComputeDashboardUseCase`): calls out in parallel to SOP/IM/GL **with the signed-in person's own token**, and a failing source is recorded in an `unavailable` map so one slow service never blanks the page. New tiles follow the same rule. Using the person's token means GL needs no service-allow-list entry; the person's module and role rules apply, which is correct for an Owner-Admin.

## 3. Requirements (P)

- **R1** Every tile answers "so what do I do" in one line, and links to the thing.
- **R2** A tile never shows a number that is not true. "Overdue" is labelled for what it is ("older than 30 days") until due dates exist; no overdue figure is invented for receivables beyond that.
- **R3** One failing source blanks one tile, not the page (`unavailable`, as today).
- **R4** Owner-Admin only, as today. `GET /me` unchanged.
- **R5** The dashboard loads fast: slow tiles (the approvals queue fans out to four services) load after the first paint.
- **R6** New fields are declared by WEB before EA ships them. (The five strict mirrors are for `/me` and are not touched; the dashboard response is read only by WEB.)
- **R7** Money in the Company's own currency only (SLE-only Mano River decision stands); if GL reports more than one currency, the tile says unavailable rather than summing.

## 4. Options and the recommended phasing

| Phase | Content | Backend change | Risk |
|---|---|---|---|
| **P1** | "Needs your attention": pending approvals (existing route, called by WEB after first paint), outstanding verification (existing data) | **none** | lowest; ships WEB-only |
| **P2** | "You owe" and "Owed to you": GL summary route into the dashboard response (`receivablesPayables`: totals, overdue by the 30-day rule, labelled) | GL new route; EA gateway method and response field | the meaning of "overdue" (decision 2) |
| **P3** | "Next due" (payables): POP read route, nearest 5 unsettled; true due-date overdue from POP if wanted | POP new route (their call); EA field | receivables side stays total-only until credit terms exist in SOP |
| **P4** | Cash over time: GL series route into the response (`cashSeries`) | GL new route; EA gateway method and response field | depends on GL |

Rejected: building all four at once. P1 is deliverable with zero backend work and gives the owner the most useful tile first; P2 to P4 each depend on another service's route.

## 5. Use cases and expected outcomes (U)

| ID | Situation | Expected |
|---|---|---|
| UC-D1 | Owner opens the dashboard with 3 approvals waiting | the attention box lists "3 waiting for you", each line opens that service's own approve screen |
| UC-D2 | Nothing waiting, nothing overdue, verified | the box says "All clear" (never an empty gap) |
| UC-D3 | One approvals source (e.g. HR) is down | the box shows the other sources and says one source could not be checked |
| UC-D4 | Company owes 5 purchases, 2 of them more than 30 days old | "You owe" shows the total and the older-than-30-days amount and count in a warning colour, labelled as such |
| UC-D5 | Receivables exist | "Owed to you" shows the total and the older-than-30-days part, labelled; no claim that anyone is "past due" |
| UC-D6 | GL's summary route is down | both money tiles show "unavailable"; every other tile renders |
| UC-D7 | The cash series service is down | the trend line shows "unavailable"; every other tile renders |
| UC-D8 | A non-Owner staff member opens Administration | no dashboard (unchanged) |
| UC-D9 | A Company has books in two currencies | the money tiles say so and show nothing summed |

## 6. Tasks (T), each tests-first, one commit each

| Task | Owner | Content | Tests first |
|---|---|---|---|
| **T1** | WEB | Attention box: call the existing approvals-queue lazily after first paint; fold in verification; empty and partial states | component tests for UC-D1 to UC-D3 against a fake queue response |
| T2 | GL (their call) | `receivables-payables-summary` route | GL's own tests |
| **T3** | EA | Gateway method and `receivablesPayables` field in the dashboard response; failure goes to `unavailable` | use-case test with a fake gateway: UC-D4, UC-D5, UC-D6, UC-D9 |
| T4 | GL (their call) | `cash-balance-series` route | GL's own tests |
| **T5** | EA | `cashSeries` field from T4 | UC-D7 |
| T6 | POP (their call, optional) | nearest-5 unsettled invoices route; an exact overdue figure | POP's own tests |
| **T7** | WEB | "You owe", "Owed to you", "Next due" and cash trend tiles; types declared before each EA field ships | component tests per tile |

Each task reviewed by CM; only CM pushes, merges and deploys.

## 7. Order, rollout, rollback, and the decisions

**Order:** T1 (WEB-only, no dependency) first. T2 then T3 (money tiles). T4 then T5 (cash trend). T6 as POP answers. All behind the hardening bundle, the write-lock tasks and the stuck sitting fixes (CM's sequencing, 2026-10-11).
**Rollout:** additive response fields; WEB declares the type first, EA ships after; each tile independent. **Rollback:** redeploy the previous image; no data or schema changes.
**What other sessions must know:** WEB builds the screens (front-end coordination convention). GL and POP are asked only for new read routes and decide their own shapes; each sends the exact shape before anything ships. SOP is asked for nothing here.
**Decisions asked of Femi:**
1. Approve phasing P1 to P4, starting with P1 (WEB-only).
2. **What "overdue" means on the dashboard:** accept "older than 30 days", labelled as such (recommended; it needs no payment terms and is true), or prioritise adding payment terms and due dates to SOP and POP first so overdue means past a due date (a separate, larger feature)?

*Evidence read 2026-10-11: `EaTab.tsx`, `GlDashboard.tsx`, `DashboardRatios.tsx`, `DashboardRoutes.kt`, `ComputeDashboardUseCase`, `ApprovalsQueueRoutes.kt`, GL's aging routes, POP's due-date aging domain and route, SOP's aging mentions; GL's written answer of 2026-10-11. Not verified: the real cost of the approvals queue on every load; POP's reply on a next-due route; whether the dashboard should offer a one-tap link from "older than 30 days" to the aging report.*
