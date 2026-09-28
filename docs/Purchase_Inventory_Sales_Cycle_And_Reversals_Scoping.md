# Purchases → Inventory → Sales Cycle and Reversals: Scoping & Task Plan

**Version:** 0.2 (updated with IM's own audit reply)
**Date:** 2026-09-28
**Author:** Purchase Order Processing (POP) session, coordinating with the Inventory Management (IM) and Sales Order Processing (SOP) sessions live in this project; GL has no live peer session today, grounded via direct code review instead.
**Status:** audit + task plan. IM has independently confirmed §3.2/§4's gap from their own side (their reply folded in below) and already shipped their own half of the auth-bug fix (§5). SOP messaged, not yet replied as of this version.
**Scope:** the full Purchase-to-Pay cycle (POP), Inventory (IM), Sales/Order-to-Cash cycle (SOP), and both reversal flows — Returns Outwards (POP→IM→GL) and Returns Inwards (SOP→IM→GL) — with GL as the posting layer underneath all four.
**Trigger:** direct instruction, 2026-09-28, following the discovery of a shared authorization bug in POP/IM (`docs/POP_IM_Shared_Company_Scoping_Auth_Bug.md`) surfaced while investigating a broken Purchases page for a multi-company Tenant.

---

## 1. Ownership, confirmed against actual code

| Flow | Owning service | Confirmed by |
|---|---|---|
| Purchases (Purchase-to-Pay) | POP | `POP/src/main/kotlin/.../application/` — full use-case set below |
| Returns Outwards | POP | `ReturnOutwards` aggregate, `POP/domain/purchaseorder/return_outwards.kt` |
| Inventory | IM | `IM/src/main/kotlin/.../domain/inventory/` — 27 domain files |
| Sales (Order-to-Cash) | SOP | `SOP/src/main/kotlin/.../domain/salesorder/` |
| Returns Inwards | SOP | `SOP/domain/returns/` (per `docs/Returns_Inwards_Requirements_Specification.md`) |
| Financial posting for all four | GL | thin "Record X" posting interfaces, one family per crossing (§2) |

This matches the ownership split named in the instruction exactly — confirmed, not assumed.

---

## 2. The forward flows — audit

### 2.1 Purchase-to-Pay (POP) — built end to end

`Supplier → CreatePurchaseOrder → SendPurchaseOrder → (Approve if over threshold) → ReceivePurchaseOrderLine (→ IM goods receipt) → RecordThreeWayMatch → RecordSupplierPayment`, all with real use cases: `CreateSupplierUseCase`, `CreatePurchaseOrderUseCase`, `SendPurchaseOrderUseCase`, `SubmitPurchaseOrderForApprovalUseCase`/`ApprovePurchaseOrderUseCase`, `ReceivePurchaseOrderLineUseCase`, `RecordThreeWayMatchUseCase`, `RecordSupplierPaymentUseCase`. Negotiation (`NegotiationProposal`) and discrepancy handling (`DiscrepancyReport`) both exist as side-flows. GL crossings: `RecordVendorObligationUseCase`/`RecordVendorPaymentUseCase` (AP), plus IM's `RecordGoodsReceiptUseCase` for the inventory side of a GOODS line.

### 2.2 Sales/Order-to-Cash (SOP) — built end to end

`Customer → CreateSalesOrder → AvalConfirmation (trade-finance gate) → RecordSale (delivery) → RecordCollection`, plus `RecordOrdinarySale` for a non-trade-finance path. GL crossings: `RecordSaleUseCase`/`RecordCollectionUseCase` (AR), `CreateSalesInvoiceUseCase` for the cash/credit invoice path. `BillForCollection`/`FacilityHeadroom` cover the self-liquidating trade-finance mechanics specific to the Group's own business.

### 2.3 Inventory (IM) — built, and the deepest of the three domains

Item master data (`CreateItemUseCase`, weighted-average/FIFO costing on `Item` itself), `RecordGoodsReceiptUseCase`/`RecordGoodsIssueUseCase` (the two GL-crossing posting points), `InventoryAdjustment` (UC-IM6: spoilage/shrinkage/damage/count-variance, with its own approve/reject workflow — **confirmed by the IM session: committed and deployed to production since 2026-09-06, image `:12`, nothing in flight**), `StockCountReconciliation`, per-location `InventoryBalance`/bins/zones/warehouses, `InTransitShipment`, `EconomicOrderQuantity`/`ReorderPoint`/`ReplenishmentPolicy`, landed cost allocation, NRV assessment. This is the most mature of the three domains — nothing in the forward flow is missing.

**All three forward flows are complete.** The open work is entirely in the reversals and the cross-cutting auth bug.

---

## 3. The reversal flows — audit

### 3.1 Returns Outwards (POP) — built end to end, including the inventory posting

`InitiateReturnOutwardsUseCase → ResolveReturnOutwardsUseCase (approve/reject) → DispatchReturnOutwardsUseCase → RecordSupplierCreditNoteUseCase`. Confirmed by reading `DispatchReturnOutwardsUseCase.kt` directly: dispatch posts **both** the inventory and AP effect in one call, by reusing IM's existing `recordGoodsIssue` endpoint with `apControlAccountId` supplied as the contra account instead of COGS — `Dr AP control / Cr Inventory`. This reuse was deliberately engineered into `RecordGoodsIssueUseCase` on 2026-09-03 (its own KDoc: *"`Request.contraAccountId` made caller-overridable... a return to a supplier isn't a sale, so its contra shouldn't hit COGS"*) specifically so POP wouldn't need a new IM endpoint. It worked — Returns Outwards has no open inventory-posting gap.

### 3.2 Returns Inwards (SOP) — AR side built, inventory side not built

Per `docs/Returns_Inwards_Requirements_Specification.md` §7 (its own build-status table, already precise and current):

- `ReturnRequest`/lifecycle (`Draft→Submitted→Approved/Rejected→Received→Inspected→Credited`), `Disposition` (Resaleable/Repairable/Scrap/Dispute), `CreditNote` — **all built**, full HTTP-tested lifecycle.
- GL posting for the credit-note/AR side (`Dr Sales Returns / Cr AR`, via GL's `RecordSalesReturnUseCase`) — **built**.
- **GL posting for the inventory-value side (`Dr Inventory / Cr Sales Returns` for a Resaleable disposition) — not built.** `RecordSalesReturnUseCase`'s own KDoc says so directly: *"Deliberately posts only the credit-note/AR side of a return, not the inventory-value side... that posting depends on IM's own goods-receipt-against-return crossing, which is a separate, not-yet-built increment."*

**This is the one real gap in the reversal flows**, and it's asymmetric with Returns Outwards for a specific, confirmed reason (§4). **Independently confirmed by the IM session** (not prompted with this finding first): *"IM's receipt/issue/costing side has no reversal/return path today... SOP's Returns Inwards shipped end-to-end but explicitly left its IM-side posting undone... that's a real, currently-open gap on IM's end, not just undocumented."*

---

## 4. The core gap, precisely

IM's two GL-crossing posting use cases are not symmetric:

| | `RecordGoodsIssueUseCase` | `RecordGoodsReceiptUseCase` |
|---|---|---|
| Reference field | `salesOrderReference: String` | `purchaseOrderReference: String` (**required**) |
| Contra account | `contraAccountId: String? = null` (defaults to `Item.cogsExpenseAccountId`; **caller-overridable**) | `apControlAccountId: String` (**hardcoded to AP by field name and by every call site**) |
| Confirmation aggregate | `GoodsIssueConfirmation` — generic fields | `GoodsReceiptConfirmation` — carries `purchaseOrderReference`, `toleranceResult`, `varianceDetail` (all PO-specific concepts) |

`recordGoodsIssue` was generalized on 2026-09-03 for exactly this kind of reuse (§3.1). `recordGoodsReceipt` never was — it's still shaped for one caller only (`ReceivePurchaseOrderLineUseCase`). The underlying GL Engine call it posts through, `RecordInventoryReceiptUseCase`, is **already fully generic** (`contraAccountId: AccountId`, no AP-specific logic at all — confirmed by reading it directly) — the hardcoding is entirely in IM's own application-layer use case, not GL.

**The fix is the same shape as the 2026-09-03 issue-side change**: make `RecordGoodsReceiptUseCase.Request.contraAccountId` caller-overridable (default to the AP control account, as today, for every existing PO-receipt caller), and either make `purchaseOrderReference` generic (`sourceReference: String`) or add a parallel optional field for a non-PO source. This is IM's own file to change — POP's Returns Outwards reuse of `recordGoodsIssue` is the direct precedent to follow, not a new mechanism to invent.

---

## 5. The shared authorization bug — resolved on both sides

`PopMembershipAuthorizer`/`ImMembershipAuthorizer` both gated every request on a single hardcoded `companyId` (baked in at deploy time) rather than the real per-request company, unlike GL's `authorizeTenant`, which was correctly updated in EA's 2026-09-23 per-Company RBAC rewrite. This blocked *any* company whose module grant wasn't set at that one hardcoded company — not Education-specific, universal.

**Both sides fixed 2026-09-28, independently, to the same shape** (the tactical option — check "granted on any Company" rather than one hardcoded Company, since neither service's own data is Company-scoped internally anyway):
- **POP**: fixed and committed (`22b8743`) in this session. Not yet pushed/deployed — pending go-ahead.
- **IM**: fixed by the IM session, PR open (https://github.com/prodeo-group-dev/fish-inventory-management/pull/6), not yet merged/deployed — held for the user's go-ahead given it's a live prod auth path. IM's own version is `CallerMembership.hasModuleGrantedAnywhere("IM", minAccessLevel)`, a named helper rather than an inline `.any {}` — worth considering whether POP's inline version should be lifted to match, or whether that helper should move to the shared `EaMembershipGateway`-adjacent code each service already duplicates (open question, §7).

Full diagnosis: `docs/POP_IM_Shared_Company_Scoping_Auth_Bug.md`.

---

## 6. Task list, in dependency order

1. **Fix the POP/IM authorization bug** (§5) — **done on both sides, neither yet pushed/deployed.** Should ship first since it's a live production defect, not a design gap.
2. **Generalize `IM/RecordGoodsReceiptUseCase`** (§4) — make the contra account and source-reference generic, mirroring `RecordGoodsIssueUseCase`'s own 2026-09-03 precedent exactly. No GL change needed (already generic). This is IM's file — belongs with the IM session.
3. **Add the SOP-side crossing**: a new IM gateway call from SOP (`ImGateway.recordGoodsReceipt`-equivalent, mirroring SOP's existing `ImGateway.recordGoodsIssue` used elsewhere), called from a new step in the Returns Inwards lifecycle — the natural point is right after `InspectReturnedGoodsUseCase` determines a `Resaleable` disposition, before or alongside `IssueCreditNoteUseCase`. Depends on (2).
4. **Decide the Repairable/Scrap dispositions' own postings** — `Repairable` (quarantine, not yet saleable — may need a distinct non-`Item.recordReceipt` inventory state, or may simply not post to GL until repair completes) and `Scrap` (`Dr Inventory Write-off Expense / Cr Inventory`, per FR-IF2 — this one maps cleanly onto `InventoryAdjustment`'s existing `DAMAGE` reason rather than needing new IM mechanism, per §... this needs an explicit decision, not a guess: flagged, not picked, in §7). Depends on (2) for Resaleable to be the proven pattern first.
5. **RMA document generation** (FR-RA2, Returns Inwards) and **returns reporting/analytics** (FR-RE1/2) — both already flagged "not built" in the Returns Inwards spec's own build-status table, both genuinely separable from the accounting-correctness gap above. Lowest priority — no dependency relationship to (2)-(4), can run in parallel or after, whenever prioritized.

Nothing above touches GL directly — every gap found is in IM's or SOP's own application layer, not the ledger itself. GL's posting primitives for all four flows and both reversals are already fully generic and already correct.

---

## 7. Open questions — flagged, not picked

1. **Scrap disposition (§6.4)**: reuse `InventoryAdjustment`'s existing `DAMAGE` reason (no new IM mechanism), or does Returns Inwards need its own distinct write-off path (traceable back to the originating `ReturnRequest`, which a generic `InventoryAdjustment` row can't reference today)? Needs a decision before task 4 can be scoped precisely.
2. **Repairable disposition (§6.4)**: does "quarantine" need a real IM location-state concept (there's already `LocationState`/bins - possibly reusable as-is), or is this genuinely unbuilt inventory-state modeling? Not yet investigated in enough depth to have a recommendation.
3. **SOP's own audit input** — messaged, not yet replied as of this version. (IM has replied — folded into §2.3/§3.2 above; nothing else in flight in IM's tree beyond the auth fix, confirmed via `git status`.)
4. **No live GL peer session exists today** (checked via `ListAgents`) — GL's own part of this document is grounded in direct code review only; flagging in case GL work should get its own session the way IM/SOP/EA/CM do.
5. **Auth-fix code shape (§5)**: IM factored its fix into a named `CallerMembership.hasModuleGrantedAnywhere(module, minAccessLevel)` helper; POP's fix is an inline `.any {}` in `PopMembershipAuthorizer.resolve()`. Worth deciding whether to converge on one shape (and whether it belongs on the shared `EaMembershipGateway`-adjacent code each service currently duplicates rather than on each service's own copy) — not done here since it's a style/reuse question, not a correctness one.
