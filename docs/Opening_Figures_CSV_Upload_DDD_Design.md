# FiSH — Opening Figures CSV Upload: DDD Design

**Version:** 0.1
**Date:** 2026-09-18
**Status:** design — not yet built.
**Supersedes nothing; extends:** `docs/Opening_Figures_CSV_Upload_Requirements_Specification.md` (v0.1, 2026-09-15) — that document's FRs/NFRs/UC catalogue/acceptance criteria stand unchanged. This document answers §12's open questions and turns them into a concrete build plan, the same "requirements doc → DDD design doc" progression `Purchase_Order_Processing_DDD_Design.md` followed from its own requirements doc.
**Related:** `docs/DDD_Design.md` §9.8 (anchor date; AR/AP itemized via SOP/POP); `RecordOpeningBalanceUseCase`, `CreateFixedAssetUseCase`/`FixedAssetFundingMethod.AlreadyOwned`, `ChartOfAccountsTemplate.SUSPENSE_ACCOUNT_CODE` (all confirmed by reading current code, 2026-09-18).

---

## 1. §12 open questions — resolved

| # | Question | Decision |
|---|----------|----------|
| 1 | Re-upload/idempotency policy | **Accepted as recommended** — reject duplicates per domain (same account+period for GL, same asset code for FA, same item+location for stock, same counterparty+reference for AR/AP); a correction requires an explicit reversal first, never a silent overwrite. |
| 2 | Strict-block vs warn when GL CSV targets an AR/AP/Inventory/FA control account | **Neither — redirect to Suspense** (§2 below). Blocking loses the figure entirely; warn-and-allow lets a control-account balance exist with no itemized detail behind it, which is the exact integrity problem FR‑GL3 exists to prevent. Redirecting to the existing `SUSPENSE_ACCOUNT_CODE` keeps the balance sheet correct today and creates an explicit, auditable "still needs itemizing" trail — reusing the same mechanism `FixedAssetFundingMethod.AlreadyOwned` already established for "we know this exists, we haven't classified it yet." |
| 3 | CSV-only vs `.xlsx` for v1 | **CSV only.** Matches the requirements doc's own non-goal; an Excel user does Save As → CSV UTF-8 first. |
| 4 | Auto-create missing customers/suppliers/items, or reject? | **Reject the row, require pre-creation.** Matches the requirements doc's own stated v1 default and the house rule that POP owns Supplier, SOP owns Customer, IM owns Item — an opening-figures importer is not a fourth place allowed to create that master data. |
| 5 | Max rows per batch; sync vs async | **Not a Finance decision — set here as an engineering default.** Dry-run and commit run synchronously up to 2,000 rows (comfortably inside the requirements doc's own <30s/5,000-row NFR target); above 2,000 rows, the same validate/commit logic runs as a background job and the caller polls `OpeningImportBatch.status` (§3) rather than holding an HTTP request open. No separate code path — the row-processing logic is identical either way; only who's waiting for it differs. |
| 6 | Whether opening stock needs a new IM use case vs a labelled goods receipt | **New use case: `RecordOpeningStockUseCase`** (§4.1). Reusing goods receipt with an "opening" `AdjustmentReason` is exactly what FR‑ST4 already warns against — a goods receipt's own semantics (received against what, from whom, condition/tolerance) don't map cleanly onto "this quantity already existed before FiSH did." A dedicated use case documents the real meaning and gives `JournalSource.IMPORT` (§5) a genuine home instead of being force-fit onto a receipt-shaped event that didn't happen. |

---

## 2. The Suspense-redirect mechanism (resolves open question 2)

Applies only to the **generic GL account-balance import** (FR‑GL1–GL3), never to the domain-specific imports (FA/IM/AR/AP), which always post against their own real accounts by design.

**Rule:** if a GL-balance CSV row's target account is flagged (§2.1) as belonging to a domain that owns itemized detail, the importer does not post to that account at all. It instead posts the row's amount as `Dr Suspense Account (3910) / Cr Opening Balance Equity (3900)` (or the reverse side, per `AccountType.normalBalance()` — same balancing logic `RecordOpeningBalanceUseCase` already applies), and the row's *result* records both the amount actually posted and the originally-requested (blocked) account, with a `NEEDS_ITEMIZATION` status distinct from plain `ACCEPTED`.

This is not a new posting mechanism — it's `RecordOpeningBalanceUseCase` called with `accountId = suspenseAccountId` instead of the row's own requested account. No new use case is needed for this path; the importer (§3) just substitutes the account before calling it.

**Reclassifying out of Suspense later** is not this design's job — it's an ordinary journal entry (or, once the real itemized import runs, that import's own postings reduce Suspense and populate the correct control account, which nets Suspense back toward zero). `UC‑OF09` (reverse or correct a bad import) already covers the reversal half of this.

### 2.1 Which accounts get redirected

A company's four "itemized-elsewhere" accounts are resolvable today without new configuration — they're already named, per-company account IDs the platform already knows about:

- **Inventory** — `Company`'s inventory asset account (already referenced by `CreateItemUseCase.Request.inventoryAssetAccountId` and IM's own posting gateway).
- **Fixed Assets** — the fixed-asset account(s) `CreateFixedAssetUseCase.Request.fixedAssetAccountId` posts against.
- **AR control** — the account `RecordSaleUseCase`/`RecordCollectionUseCase` post against with `DimensionType.CUSTOMER`.
- **AP control** — the account `RecordVendorObligationUseCase`/`RecordVendorPaymentUseCase` post against with `DimensionType.VENDOR`.

The GL-balance importer resolves these four account IDs per company (the same way `ComputePurchasePostingContextUseCase`/its Sales-side equivalent already do) and checks the CSV's target account against that set before deciding whether to redirect.

---

## 3. `OpeningImportBatch` / `OpeningImportRowResult` — concrete shape

Per the requirements doc's §9 high-level model, now with real fields:

```
OpeningImportBatch
  id: OpeningImportBatchId
  domain: OpeningImportDomain        // GL_BALANCES | FIXED_ASSETS | STOCK | AR | AP
  companyId: CompanyId
  anchorDate: LocalDate
  filenameHash: String
  status: DRAFT | VALIDATING | VALIDATED | COMMITTING | COMMITTED | FAILED
  rowCount: Int
  acceptedCount: Int
  rejectedCount: Int
  needsItemizationCount: Int          // GL_BALANCES domain only - see §2
  createdBy: UserId
  createdAt: Instant
  committedAt: Instant?

OpeningImportRowResult
  batchId: OpeningImportBatchId
  rowNumber: Int
  status: ACCEPTED | REJECTED | NEEDS_ITEMIZATION
  errors: List<String>                // empty unless REJECTED
  resultingEntityIds: List<String>     // JournalEntry id, FixedAsset id, etc. - empty unless ACCEPTED/NEEDS_ITEMIZATION
```

Two statuses on the batch (`VALIDATING`/`COMMITTING`) exist specifically for the >2,000-row async path (decision 5) — a synchronous small batch moves through `DRAFT → VALIDATED → COMMITTED` in one request/response pair and a caller never observes the intermediate states.

---

## 4. New use cases (one per domain, each wrapping the existing single-row use case — per requirements doc G6)

Every import use case follows the same two-phase shape: `validate(rows)` (dry-run, FR‑UP4, no persistence) and `commit(batchId)` (FR‑UP5). Both phases reuse the same per-row validation logic; `commit` is `validate` plus actually calling the wrapped use case per accepted row.

### 4.1 `RecordOpeningStockUseCase` (IM) — new

```kotlin
class RecordOpeningStockUseCase(
    private val itemRepository: ItemRepository,
    private val glEngineGateway: ImGlEngineGateway   // same gateway RecordInventoryReceiptUseCase already posts through
) {
    data class Request(
        val itemId: ItemId,
        val quantity: BigDecimal,
        val unitCost: Money,
        val facilityId: FacilityId?,
        val date: LocalDate
    )
    sealed class Result {
        data class Success(val item: Item, val journalEntryId: String) : Result()
        data object ItemNotFound : Result()
        data object AlreadyHasOpeningStock : Result()   // idempotency guard, decision 1
        data class InvalidQuantity(val message: String) : Result()
    }
    // sets Item's opening on-hand qty/cost directly (not via a simulated receipt),
    // then posts Dr Inventory / Cr Suspense through the same GL-crossing interface
    // RecordInventoryReceiptUseCase already uses - JournalSource.IMPORT (§5), not
    // the receipt's own source, so it's never confused with an operational receipt.
}
```

The CSV importer calls this once per row; `AlreadyHasOpeningStock` is exactly decision 1's per-item duplicate guard.

### 4.2 Fixed assets — reuse `CreateFixedAssetUseCase`, no new use case

Per FR‑FA2, the importer calls `CreateFixedAssetUseCase.execute()` once per row with `funding = FixedAssetFundingMethod.AlreadyOwned(suspenseAccountId)` — already exactly the "opening" shape. `AlreadyHasOpeningStock`-equivalent duplicate guard (decision 1: reject duplicate asset code) is a pre-check the importer does against `FixedAssetRepository` before calling `CreateFixedAssetUseCase`, not a change to that use case itself.

### 4.3 AR / AP — new thin wrapping use cases in SOP / POP

Per FR‑AR2/FR‑AP2, these must NOT call `RecordOpeningBalanceUseCase` on the AR/AP control account (that's exactly what decision 2's Suspense-redirect exists to catch if someone tries it via the wrong path). Instead:

- **SOP**: `ImportOpeningArLineUseCase` creates an open (unpaid) `SalesOrder`/invoice-equivalent dated at or before the anchor date, through the same path `CreateSalesInvoiceUseCase` already uses for a credit sale — which already posts `Dr AR (customer-dimensioned) / Cr Revenue-or-equivalent` correctly itemized. The "revenue" side of an opening balance is genuinely odd (no sale happened), so the contra for an opening-import row specifically is Suspense, not a live revenue account — a one-parameter variant of the existing use case, not new posting logic.
- **POP**: `ImportOpeningApLineUseCase` mirrors this via `RecordVendorObligationUseCase`, contra = Suspense instead of the operational Inventory/Expense account a real PO's obligation would use.

Both wrap an *existing* single-row use case per requirements doc G6; neither invents a new posting shape.

### 4.4 GL balances — reuse `RecordOpeningBalanceUseCase`, no new use case

Per FR‑GL2, the importer calls the existing use case once per row, with the account substitution from §2 applied first when the target is a flagged control account.

---

## 5. `JournalSource.IMPORT` — now wired (resolves the requirements doc's G8)

Every journal entry any of the above use cases post — stock, FA, AR, AP, or GL-balance rows, redirected-to-Suspense or not — is tagged `JournalSource.IMPORT`, not `MANUAL`. This is a one-line change at each call site (the enum already exists; nothing currently sets it). It's what makes `UC‑OF08` (review import batch, tie postings back to the batch) and any future "what came from an opening import vs. real activity" report possible without inspecting descriptions as free text.

---

## 6. CSV column schemas (concrete)

| Domain | Required columns | Notes |
|---|---|---|
| **GL balances** | `account_code`, `amount`, `contra_account_code` (optional, default `3900`) | `amount` always positive magnitude, per `RecordOpeningBalanceUseCase`'s own convention — the account's own `normalBalance()` decides the side. |
| **Fixed assets** | `asset_name`, `category`, `acquisition_date`, `cost`, `currency`, `useful_life_years` (optional), `identifier` (optional), `fixed_asset_account_code` | `acquisition_date` must be ≤ the batch's anchor date. |
| **Stock (IM)** | `item_sku`, `quantity`, `unit_cost`, `currency`, `facility_code` (optional) | Rejects unknown `item_sku` per decision 4 (§1). |
| **AR (SOP)** | `customer_code`, `reference`, `amount`, `currency`, `due_date` (optional), `description` (optional) | Rejects unknown `customer_code` per decision 4. |
| **AP (POP)** | `supplier_code`, `reference`, `amount`, `currency`, `due_date` (optional), `description` (optional) | Rejects unknown `supplier_code` per decision 4. |

Every file additionally requires the common columns FR‑UP3 already specifies at the batch level (not per row): `company_id`, `anchor_date`.

---

## 7. Build order (unchanged from the requirements doc's own recommendation)

1. **GL balances** — pure-GL, exercises the Suspense-redirect mechanism (§2) that every other domain's "reject vs redirect" reasoning leans on.
2. **Fixed assets** — no new use case needed at all (§4.2), lowest-risk second step.
3. **Stock (IM)** — one new use case (§4.1).
4. **AR / AP** — two new use cases, each in a different service (§4.3); last because they're the only domains needing cross-service coordination (SOP/POP calling into GL).

---

## 8. Still open

- **Exact batch-size async threshold** (decision 5 set 2,000 rows as a working default) — worth revisiting once a real anchor-date file's typical row count is known.
- **Whether `ImportOpeningArLineUseCase`/`ImportOpeningApLineUseCase`'s Suspense-contra variant belongs as a new parameter on the existing `CreateSalesInvoiceUseCase`/`RecordVendorObligationUseCase`, or as a genuinely separate use case that happens to call the same lower-level posting helper** — a real design choice for whoever builds §4.3, not resolved here; flagged rather than picked, per house convention.
- Everything the requirements doc itself still calls out in its own §12 that this document didn't touch (there isn't any — all six are addressed above).
