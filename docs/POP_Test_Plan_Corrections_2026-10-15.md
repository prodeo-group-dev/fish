# POP test plan and Retest plan: corrections after the 2026-10-15 decisions

Written by the POP session, 2026-10-15, for CM to fold into the tester's `POP_Test_Plan.md` and `Retest_Plan_2026-10-15.md` (those live in CM's reports folder, not in git, so this file lists the changes row by row). Checked against POP master `a05acfa` (live as `:47`). **Docs only; no live test was run to write this.** Three POP changes are READY BUT NOT LIVE as of this note (the line item link V19, the trade discount V20, the consumer-side posting-context field); rows that depend on them say so.

## 1. The Retest plan: the "Full financier" test is gone, check this instead

**Why it is stale.** Decisions Log 2026-10-15 ("PRODEO IS A LANDLORD" and the trade-finance entry): Prodeo has no role in a Tenant's purchase order, payments or accounts and is not in the business of providing trade finance. POP stage 1 is live (`:47`): a purchase order needs no role, the field is accepted and ignored, and the answer never shows one. The Retest plan rows `PO "Prodeo's role" = Full financier` (line 60) and `RT-C5` (type-of-sale and PO financier blank defaults, line 122) test a control that no longer exists.

**Replace with these checks.**

*Purchase order form (WEB build with the control removed, PR 164 or later):*
1. The form shows **no** "Prodeo's role", "financier" or "deal role" field anywhere (create, amend, order detail, the purchases list). Record the WEB build seen.
2. A purchase order can be created with every required field filled and nothing else: created, numbered `PO-00000n`, status Draft.
3. (API, tester with a token) `POST .../purchase-orders` with **no** `prodeoRole` answers 201 and the answer shows `prodeoRole: null`.
4. (API) The same with an old `prodeoRole` such as `FULL_FINANCIER`, or a meaningless value, answers 201 (accepted and ignored) and the answer still shows `prodeoRole: null`.

*Payment (pay a matched purchase order):*
5. The pay screen shows **no** "executing party", "bank pays" or financing choice.
6. Paying a matched order succeeds; the order becomes CLOSED (known limit: a part payment also closes it until T8 is built; do not treat that as a new fault).
7. The ledger entry for the payment is **Dr Accounts Payable / Cr the Company's cash or bank account**. It must NOT touch any facility liability account (code 2300).
8. (API) A payment with **no** `executingParty` behaves exactly as 6 and 7. A payment with the old `executingParty: "PRODEO"` also behaves as 6 and 7.
9. (API, only if the tester is checking the kept lender path; not offered in the screens) `executingParty: "TENANT_LENDER"` **with** `lenderConfirmationReference` settles against the Company's facility liability account (409 `facility_liability_account_not_configured` if the Company has none, nothing posted); `TENANT_LENDER` **without** a reference answers 400 and posts nothing; an unknown value answers 400. The old `executingParty: "BANK"` with `bankConfirmationReference` behaves as `TENANT_LENDER`.

## 2. `POP_Test_Plan.md`: rows to change

| Row | Now says | Change to |
|---|---|---|
| Header, "POP floor (refreshed 2026-10-13)", line 15 | "UC-PO2/FR-PO02 deal role with PO-000123 numbers" | "UC-PO2/FR-PO02 purchase order creation with PO-000123 numbers; no deal role (Prodeo has none; the old field is accepted and ignored)" |
| `UC-PO2` (line 246), `FR-PO02` (253), `NFR-PO02` role-aware actions (261) | "Create a PO with a deal role / Role stored and shown" | **Superseded by the landlord decision.** Test: create a PO with no role; the answer shows `prodeoRole: null` (see 1.3 and 1.4). `NFR-PO02` (role-aware actions) has no meaning without a role: mark **Not applicable (decision 2026-10-15)** |
| `UC-PO6` (250) | "Dr AP / Cr Cash Book or bank book; order CLOSED even if partial (T8 limit)" | Keep, and add: default settles from the Tenant's own cash or bank; the lender path is optional, API only (see 1.7 to 1.9) |
| `OS-POP-13` (117) | "Returns outwards REQUESTED, APPROVED/REJECTED, DISPATCHED, CREDITED; stock leaves via IM" | Add: **stock leaves via IM only for a line that has an inventory item.** Until V19 is live, a dispatch posts nothing to IM for ANY order read from the database; expected today: dispatch succeeds in POP, no stock movement in IM. After V19: a return of a line with an item posts once (Dr AP / Cr Inventory); an order created before V19, or a line with no item, posts nothing and the answer carries `inventoryNotPostedReason: line_has_no_inventory_item` |
| `OS-POP-T6` (134) | "Dispatch a return twice / One issue / BUILT and HELD; Unclear" | **T6 is LIVE** (merged and deployed). Expected: dispatching again retries with the same key and completes or replays once; a posted return answers its stored journal entry and calls nothing. It can only be seen against IM for a line with an item, so the real check waits for V19 |
| `SC-3.1` (232) | "Returns outwards posts inventory and AP in one IM call / Built (audit)" | Same caveat as `OS-POP-13`: built, but a real order reaches IM only once V19 is live |
| `OS-POP-REP` (136) | "Record-existing-posting operator route / Enhancement / Parked" | Reword: **a route for the Tenant's own Owner Admin or accountant, not a Prodeo operator**; still NOT BUILT, parked. Prodeo support never edits a Tenant's data |
| Any row or note saying "Prodeo support in the database" or "contact support" for a tenant-data problem | | "contact your administrator" (the Tenant's Owner Admin or accountant). The 422 `idempotency_key_reused` message the screens show should say so |
| `POP-GR-4.3` (148) and the line-32 entry | "Stock line rule (itemId; with VAT SPUTO: kind STOCK)" | Unchanged in substance (GRNI still In floor, NOT built), but note it **depends on V19**: without a saved item link there is no stock line to detect |

## 3. New rows to add (decided or ready since the plan was built)

| New row | Expected | State today |
|---|---|---|
| Discounts Received, kind A: a purchase line with a list price above the net price | The order shows list price, discount percentage and the **net** price; the order total and every posting use the net; list below net is refused 400 | **READY, NOT LIVE** (V20). Test after CM says it is deployed |
| Discounts Received, kinds B to F (discount on the invoice total, early-payment discount, price-allowance credit note, rebate, bonus goods) | See `docs/POP_Discounts_Received_SPUTO.md` | **NOT BUILT.** Femi decided the order on 2026-10-15; the early-payment discount additionally waits for its own VAT playbook and a tax professional's confirmation of Ireland. Mark "Not built, decided". Do not test |
| Purchase line carries its IM item link after saving (GET the order after create) | `itemId` still present | **READY, NOT LIVE** (V19). Today it comes back null |
| Product VAT category read from the Inventory item | Not applicable yet | POP stage 1 (the read) is live and unused; stage 2 waits for Inventory. Mark "Not built, gated" |

## 4. What did NOT change

The VAT category is still typed on every purchase line and required (400 `missing_vat_category` naming the line); the set-category route for unposted orders stays (it is the correction path because input VAT is what the supplier charged). Match and payment keys are the order id only; a refusal never blocks a corrected retry. T8 (partial payments) and GRNI (seam A) remain NOT BUILT, and seam A's double count is still open.
