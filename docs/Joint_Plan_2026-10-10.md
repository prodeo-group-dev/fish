# Joint plan, 2026-10-10 (CM)

Built from the "where we are at" reports of 2026-10-10 (round 1 and, where marked, round 2). Sessions GL, SOP, IM, EA and ER were unreachable in round 2, so their rows use their round 1 report plus what CM verified since. Status words below are verified against ECS and git by CM, not taken on trust.

**Paradigm (Femi, 2026-10-10):** SOP-IM-POP are the heartbeat of any organisation and must work seamlessly together, whatever names a specialty runtime (EduSys, etc.) gives them. Everything below is ordered with that in mind.

## 1. Live state (verified 2026-10-10)

| Service | Task definition | Image = master head |
|---|---|---|
| GL | :117 (service allow-list ENFORCING) | 6ea02f8 |
| EA | :89 | 3bf2f12 |
| SOP | :51 | f65c7b7 |
| IM | :32 | cf97150 |
| POP | :36 | 52d01cd |
| HR | :40 | 43aa03a |
| ER (Education Runtime) | :84 | fc52911 |
| WEB | master fe4b441 (nav stage 3 merged, #131) | |

Multi-Tenant (T15) is live end to end in code: services derive the Tenant from the Company, GL checks Company-in-Tenant, service logins are limited by an endpoint allow-list. **Verified by real traffic only for SOP and IM** (sales and stock on a second Tenant). POP, HR, and SOP's sales return have never run under enforcement.

## 2. Corrections made today (so nobody repeats them)

- The "Period wall" was false. No posting compares an entry date with a Period's dates, and nothing closes a Period, so the opening Period stays open and takes postings of any date. Periods are a design improvement, not a blocker. Femi's requirement stands for later: **automatic opening, explicit month closure, especially because of bank reconciliations.** Deferred past UAT. See `docs/GL_Period_Management_Scoping.md`.
- ER's Postgres tests (175) never ran in CI because the integration stage had been switched off. Re-enabled today, with a guard that fails the build if zero tests ran. Every repo now runs its Postgres tests in CI.

## 3. Sequence

**A. Before the combined UAT sitting (in this order)**
1. **POP T7** (match and pay: post to GL first with a deterministic idempotency key, then save; 1.5 to 2 days). Found today by POP in its own code: the three-way match saves MATCHED before GL answers, so a GL refusal leaves the order stuck MATCHED with no journal entry, and a later payment would debit AP with nothing recorded. The sitting's step 6 would trip this under any GL failure. HIGH review (money).
2. **WEB, in this order (CM decision):** (a) SOP Net/VAT/Gross columns + open invoice + glError message first (half a day; it is what the tester sees in sales), (b) stage 4 (half a day, not yet started), (c) dashboard-with-data check. Merge WEB docs branch `docs/web-school-screen-mapping` @ 9bb2da7 together with (a) so WEB is not redeployed for docs alone. Stage 3 is already merged and live (#131).
3. HR: check expense-claim and salary-advance approvals for a deterministic idempotency key (risk c), fix if real; smoke script for the six GL routes.
4. Reviewed and live already: ER T-ER1/T-ER2 (access-tightening, add-a-deny only).

**B. The combined UAT sitting**: Femi's tester onboards a brand-new Tenant with two businesses and a school, on current production code. Checklist (CM reads logs right after each part):
- EA: `POST /api/tenants` 201 once; company-registration 200 x3; no 502 `school_provisioning_failed`, no 409 `company_registration_rejected`, no `first_admin_already_set` warning; no 5xx.
- ER: `schools.organisation_id` is a 36-character UUID matching EA's Company id; first-admin row (`staff_assignments` SCHOOL_ADMIN ACTIVE, `granted_by ea-provisioning:`). Add the new school Company id to `SOP_ER_COMPANY_IDS` (new SOP task definition) before testing guardian billing.
- POP (POP's checklist): supplier, PO, send, receive, **IM stock receipt**, three-way match, aging, pay. GL log expected: purchase-posting-context then record-obligation then record-payment, each with `service=pop`. **After steps 5 and 6, read GL AP and inventory balances once each: seam A (below).** Cross-tenant check: each Tenant's person opens the other's Company by URL, expect 403.
- SOP: credit-note sales return end to end (never run under enforcement); read GL for `BLOCKED service=` / `forbidden_endpoint`.
- HR: payroll approve and pay, leave, expense claim, salary advance.
- GL: nothing blocked, no 5xx; read the 409s on Company `13de72e4` (likely missing VAT control account 2150).
- Skip step 9 (returns outwards) until IM clears POP's T6.

**C. After the sitting**
1. **SOP-IM-POP seam work (Femi's priority).** One joint design note (POP drafts, IM and GL contribute): see section 4.
2. EA hardening bundle (Tenant row lock, `POST /tenants` idempotency, WEB double-submit disable, 15 s outbound timeouts, central Company-in-Tenant guard), ~2.5 days, HIGH review.
3. Remove the old Tenant env vars (M3): `*_EA_TENANT_ID`, `*_GL_ENGINE_TENANT_ID`, via manually registered task definitions.
4. HR H6/H7, IM M1b, T11 EA+IM approval, POP T6 release (after IM real-token check) and T8 partial payments, GL alarm on "BLOCKED" (Terraform, Femi applies).
5. Periods (scoping doc), GL "add missing template accounts" use case (~1 day), opening-import anchor-date gap.
6. ER: S1 A4 to A7 after Femi's remaining decisions; T-ER3 (parent payment becomes a claim) before any outbox relay; Epic 13 after SOP's inbox shapes.

## 4. SOP-IM-POP weak seams (the heartbeat)

| # | Seam | Status |
|---|---|---|
| A | **Double recognition of a stock purchase.** IM receipt posts Dr Inventory / Cr AP control (default contra, `ItemRoutes.kt:228`); POP match posts Dr (caller-supplied expense/asset) / Cr AP control + VAT. A stock PO through both credits AP twice. Pattern per `IFRS_GL_Posting_Matrix.md`: IM receipt credits GRNI; the match debits GRNI for stock lines. | Real by the code; the sitting measures it. Fix is a joint IM+POP+GL change. |
| B | POP "received" and IM stock receipt are two unlinked calls: POP can say FULLY_RECEIVED while IM has no stock, and SOP cannot sell what IM never received. | Open. POP T10 (design with IM). |
| C | A PO line without an item id never reaches IM. | Open. |
| D | POP to GL had no idempotency key on obligation/payment. | In progress (POP T7, section 3A). |
| E | A failed IM call during return dispatch leaves the return DISPATCHED and not retryable until POP T6 ships. | T6 built (tip 1d1001c), held for IM real-token verification. |
| F | Any payment closes the order (CLOSED) while GL holds the true balance. | Open. POP T8. |
| G | A PO raised by one Tenant never becomes a sales order for another (vision only, gated until two paying Tenants want it). | Parked. |
| H | Match saves before GL answers. | Same as D, fixed by T7. |
| I | Receipt and issue forms in IM require PO / sales-order references; the sales list shows net while customer balance shows gross. | Open (tester finding); WEB shows Net/VAT/Gross after stage 4. |
| J | Returns Inwards: AR side posts, IM inventory-value side has no home (IM receipt hard-wired to PO). | Open; IM contra already generalized, wiring pending. |

## 5. Decisions needed from Femi

1. **SOP:** who is the "acting person" on money acts (S-T1), and is the payments ledger or Epic 13's fee-payment ledger the single one.
2. **ER:** D-ER5 and D11 remain open (D-ER1 to D-ER4/D-ER6/D-ER7 decided today); the offline-deadline rule.
3. **EA:** should a SUSPENDED or CLOSED Tenant actually be blocked? Today nothing enforces either; the 180-day KYB suspension is a control in name only.
4. **GL:** bank-reconciliation balance tie-out switch (`enforceBalanceTieOut`); run `run_gl_fixed_asset_h1.ps1` and paste the output (blocks fixed-asset register vs GL checks).
5. **HR:** H7 bank-details key (A then B); fortnightly / four-weekly payroll cadence (D9/T10b).
6. **POP:** T9c (does payment/match/return approval need a second person) and the capability model before T9b.
7. **Periods (after UAT):** GL's five questions and the legacy-history choice (L1/L2/L3, GL recommends L2).
8. **Sign-up policy** (open vs invite-only), the stuck `support@theprodeogroup.com` account (sign in, confirm the code, or I admin-confirm on your word), the "Set up school profile" press for Valiant's Hall, the three Tenants named "Developers", Business ID order for your four businesses.
9. Approvals held for the Live switch (not now): owner MFA policy, full security scope.

## 6. Cross-cutting risks

- The G3 allow-lists come from reading each service's GL client; only real traffic proves them. POP, HR and SOP return are the unproven ones.
- A service login is valid for every Tenant by design; the allow-list limits what it can do, not which Tenant. A stolen service credential is a cross-Tenant risk. Postings by a service carry the service identity as actor.
- No database-level isolation (RLS); GL, EA and HR rely on application checks and tests. Held as future work.
- EA is on every request's path (each service calls `/me`), fail-closed, no cache; outbound clients have no explicit timeouts.
- Every EA save is load-modify-save with delete-and-reinsert: concurrent writes to one Tenant or Membership can lose data. Registration is the worst case.
- HR computes no PAYE/NI (PayrollTaxRule unpopulated); payroll amounts are trusted as submitted.
- ER payment confirmation is a stub: a guardian can mark their own child's invoice PAID (T-ER3). Must be fixed before any outbox relay exists.
- Several services hand-mirror EA's `/me` with strict decoding: any new field EA adds will 500 them. There is no contract test against EA's real shape.
- Every claim that a peer made today about code was re-checked by CM only when it blocked something; peers' "nothing can do X" claims should be verified against code or logs before anyone builds on them.

## 7. Owners at a glance

CM: review, push, deploy, CI, sitting log reads, this plan. GL: posting layer, Periods scoping, missing-accounts use case. POP: T7 now, then T6/T8/T10 design. IM: seam A/B/J, M1b, T11, real-token check. SOP: acting-person decision work, sales return. HR: idempotency check, smoke script, H6/H7. EA: hardening bundle after the sitting. ER: S1 follow-ons after decisions, T-ER3. WEB: SOP Net/VAT/Gross first, then stage 4, then dashboard-with-data check.
