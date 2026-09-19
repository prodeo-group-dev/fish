# FiSH — Opening Figures CSV/Excel Upload: Requirements Specification

**Version:** 0.1 (draft)
**Date:** 2026-09-15
**Author:** Code Reviewer (for Femi), from product ask via Chief of Staff
**Status: draft — not scheduled for build.** Captures the requirement that opening figures must be loadable via Excel-compatible CSV, especially for stock, fixed assets, AR, and AP — not only generic GL account balances.
**Related:** `docs/DDD_Design.md` §9.8 (anchor date; AR/AP itemized via SOP/POP); existing GL `RecordOpeningBalanceUseCase`; GL fixed assets `CreateFixedAssetUseCase` / `ALREADY_OWNED`; IM goods receipt / stock count; SOP sales & customers; POP suppliers & obligations.

**Out of scope for this draft:** implementation, cloud-agent build, payment flows, and changing the DDD rule that AR/AP opening figures are itemized (not a lump control-account import).

---

## 1. Purpose

Define functional, accounting, and operational requirements for **bulk upload of opening figures** into FiSH via **CSV (Excel-compatible)**, so an established company can bring pre-FiSH balances and subledger positions into the platform at an **anchor date** without one-row-at-a-time entry for every line.

Opening figures in scope:

| Domain | Owning service | What “opening figure” means |
|--------|----------------|-----------------------------|
| Stock / inventory | IM (+ GL posting) | Quantity and cost on hand as at anchor date, per item (and location if used) |
| Fixed assets | GL (`domain.fixedassets`) | Register rows for assets already owned as at anchor date |
| Accounts receivable | SOP (+ GL) | Open customer invoices / amounts owed as at anchor date (itemized) |
| Accounts payable | POP (+ GL) | Open supplier bills / amounts owed as at anchor date (itemized) |
| GL account balances | GL | Per-account opening balances (cash/bank and other ledger accounts) where a subledger does not own the detail |

---

## 2. Problem / current state (baseline)

Assessed against PRODEO1 `C:\Users\femif\Claude\Projects\FiSH\` (2026-09-15):

| Domain | Today | Gap |
|--------|-------|-----|
| **GL balances** | Partial — `POST .../opening-balance` (`RecordOpeningBalanceUseCase`); WEB Chart of Accounts `OpeningBalanceForm` (one account). Onboarding can seed opening cash. `JournalSource.IMPORT` / audit IMPORT / export CSV·XLSX enums exist but are not wired to an upload path. | No bulk CSV/Excel upload |
| **Fixed assets** | Partial — `POST /fixed-assets` with `fundingMethod=ALREADY_OWNED` (suspense); WEB `FixedAssetRegister` one asset at a time | No bulk CSV register import |
| **Stock (IM)** | Operational receipt / issue / stock count / adjustment only (`AdjustmentReason`: spoilage, shrinkage, damage, count variance). No dedicated opening-stock import | No opening-stock CSV; no “opening” adjustment reason |
| **AR (SOP)** | Customers, sales, collections — no opening-AR import. Design (§9.8): itemized via SOP, progressive entry | No CSV of open invoices / “people who owe us” |
| **AP (POP)** | Suppliers, POs, payments — no opening-AP import. Design (§9.8): itemized via POP | No CSV of open bills / “people we owe” |
| **WEB** | No `type=file` / CSV upload UI found for any of the above | No upload UX |

**Product statement:** the feature “should be there” for opening figures — especially stock, FA, AR, AP — via CSV (Excel-compatible). Today that capability is **missing** as bulk upload; only single-entry / progressive paths exist.

---

## 3. Stakeholders

- **Company admin / bookkeeper** — prepares and uploads opening CSVs at go-live / anchor date
- **Finance / accountant** — validates control totals, period, and GL impact
- **Warehouse / inventory** — validates stock opening quantities and locations (IM)
- **Sales ops / AR** — validates customer opening invoices (SOP)
- **Procurement / AP** — validates supplier opening bills (POP)
- **Auditors** — need source file, import batch id, user, timestamp, and resulting postings

---

## 4. Goals and non-goals

### 4.1 Goals

- **G1**: Upload Excel-compatible CSV files for each opening-figure domain listed in §1.
- **G2**: Validate rows before commit; report row-level errors without silent skip of bad data mixed into a “success”.
- **G3**: Apply correct **tenant / company** scoping and authorization on every import.
- **G4**: Honour **open period** and existing ledger / module controls — imports must not bypass them.
- **G5**: Support **idempotent / safe re-upload** behaviour (explicit policy per domain — see §7).
- **G6**: Prefer **wrapping existing single-create / posting use cases** (or thin bulk variants of them) over parallel bypass postings.
- **G7**: For AR/AP, keep **itemized** opening positions (DDD §9.8) — not a single AR/AP control-account lump from CSV.
- **G8**: Tag resulting journal entries with an appropriate source (wire `JournalSource.IMPORT` or a dedicated opening/import source — decide at design time; do not leave IMPORT decorative).

### 4.2 Non-goals (v1)

- Native `.xlsx` binary parse (CSV exported from Excel is enough for v1; XLSX may be a later increment).
- Continuous mid-year “re-import everything” as a substitute for normal operations (imports are for **anchor-date opening**, not day-to-day posting).
- Replacing progressive manual entry — CSV is an accelerator; single-row paths remain.
- Cross-tenant imports or admin impersonation shortcuts.

---

## 5. Functional requirements

### 5.1 Common upload platform (all domains)

- **FR‑UP1**: Accept multipart file upload of UTF-8 CSV (Excel-compatible: commas, quoted fields, CRLF/LF). Optional BOM tolerated.
- **FR‑UP2**: Require authenticated user with **WRITE** (or module-equivalent) on the target tenant/company; reject cross-tenant `companyId`.
- **FR‑UP3**: Require an **anchor date** (and open **Period** containing that date) on the import request; refuse if period closed.
- **FR‑UP4**: Dry-run / validate mode: parse + validate all rows, return error report, **no persistence**.
- **FR‑UP5**: Commit mode: all-or-nothing **or** documented per-domain partial-commit with explicit batch status (choose one policy in design; default preference: validate-all then commit-all for GL/FA; allow row-continue with error file for large IM/AR/AP if justified).
- **FR‑UP6**: Return an **import batch id**, counts (accepted / rejected), and downloadable error CSV for failed rows.
- **FR‑UP7**: Persist audit: who, when, filename hash, domain, company, anchor date, batch id, outcome.
- **FR‑UP8**: Template download: one sample CSV per domain with required headers and one example row.

### 5.2 Stock / inventory opening (IM)

- **FR‑ST1**: CSV columns (minimum): item identity (SKU / item id), quantity on hand, unit cost (or valuation fields required by IM costing), optional facility/bin, optional lot/serial if the item requires them, currency where applicable.
- **FR‑ST2**: Create or update on-hand quantity and cost such that IM stock and GL inventory agree after import (use existing receipt / opening-shaped posting path — e.g. goods receipt or a dedicated opening-stock use case — **not** a free GL-only inventory debit).
- **FR‑ST3**: Reject unknown items, negative quantities (unless explicitly allowed), missing location when location is mandatory, and cost/currency mismatches.
- **FR‑ST4**: Do not misuse stock-count adjustment reasons (spoilage/shrinkage/etc.) as a silent substitute for opening stock without an explicit **OPENING** (or equivalent) reason/path.

### 5.3 Fixed assets opening (GL FA)

- **FR‑FA1**: CSV columns (minimum): asset name/code, category, acquisition/in-service date ≤ anchor date, cost, useful life / depreciation inputs as required by existing FA model, `fundingMethod=ALREADY_OWNED`, suspense (or equivalent) account reference.
- **FR‑FA2**: Each row creates a fixed-asset register entry via the same rules as `CreateFixedAssetUseCase` / `ALREADY_OWNED` (suspense credit / catch-up), not a bare GL balance on a FA control account without a register row.
- **FR‑FA3**: Reject rows that would skip depreciation setup required for the asset category, or that reference accounts outside the company.

### 5.4 Accounts receivable opening (SOP)

- **FR‑AR1**: CSV is **itemized**: one row per open customer obligation (customer identity, reference/invoice no., amount, currency, due date, optional description). Plain-language UX copy may say “people who owe us” (DDD §9.8); domain terms remain AR internally.
- **FR‑AR2**: Import creates the operational AR documents / balances through **SOP** mechanisms that then post to GL (sale / invoice / opening-AR equivalent) — **not** a single `RecordOpeningBalance` on the AR control account for the whole file.
- **FR‑AR3**: Support matching existing customers by stable key (customer code/email/id); policy for “create customer if missing” must be explicit (default: reject missing customers in v1).
- **FR‑AR4**: Control total in the file header or sidecar must match sum of rows before commit.

### 5.5 Accounts payable opening (POP)

- **FR‑AP1**: CSV is **itemized**: one row per open supplier obligation (supplier identity, bill/reference, amount, currency, due date, optional description). UX may say “people we owe”.
- **FR‑AP2**: Import goes through **POP** (opening bill / obligation path) then GL — not a lump AP control-account opening balance for the whole file.
- **FR‑AP3**: Same customer-style identity rules for suppliers; default reject unknown suppliers in v1.
- **FR‑AP4**: Control total check as for AR.

### 5.6 GL account opening balances

- **FR‑GL1**: CSV columns (minimum): account code (or id), amount (positive magnitude), optional explicit contra account (default Opening Balance Equity `3900` per existing use case), anchor date.
- **FR‑GL2**: Each row invokes the same controls as `RecordOpeningBalanceUseCase` (WRITE, tenant/company, open period, balanced JE vs OBE or named contra).
- **FR‑GL3**: Accounts whose detail is owned by IM/FA/SOP/POP **should not** be bulk-opened here as a substitute for domain imports (warn or block: inventory control, FA cost, AR control, AP control — configurable strictness; default **block** when the domain import exists).

### 5.7 WEB / UX

- **FR‑UX1**: Per-domain upload page (or wizard step in “Open company / anchor date” onboarding): download template → upload → dry-run results → confirm commit.
- **FR‑UX2**: Show batch history and error CSV download.
- **FR‑UX3**: Keep existing single-entry UIs (Chart of Accounts opening form, FA “Already owned”, progressive SOP/POP entry).

---

## 6. Non-functional requirements

- **Security / tenancy**: Fail closed on missing membership/WRITE; no cross-company leakage in templates, errors, or batch lists.
- **Integrity**: Double-entry and module invariants unchanged; import is not a privilege to post into closed periods.
- **Idempotency**: Re-upload of the same batch id is a no-op; re-upload of a new file against already-opened rows follows §7.
- **Performance**: Dry-run of 5,000 rows < 30s under normal load (target; tune per service).
- **Audit**: Immutable batch record + linkable journal / subledger ids.
- **Usability**: Spreadsheet users can round-trip via Excel → Save As CSV UTF-8.
- **Compliance**: Align with IAS 2 (inventory), IAS 16 (PPE), IFRS 9 / presentation of trade receivables/payables, and existing FiSH posting matrix — opening is cutover, not revenue recognition.

---

## 7. Idempotency and re-upload policy (required decisions)

Document the chosen policy in design before build. Recommended defaults:

| Domain | Recommended v1 policy |
|--------|------------------------|
| GL account opening | Reject second opening for same account+period unless prior entry is reversed first |
| FA | Reject duplicate asset code; no silent overwrite |
| IM stock | Reject if item+location already has non-zero qty from a prior opening batch; allow after compensating reversal/adjustment |
| AR / AP | Reject duplicate (counterparty + reference); no silent amount overwrite |

---

## 8. Use case catalogue

- **UC‑OF01**: Download CSV template (Admin)
- **UC‑OF02**: Dry-run validate opening CSV (Admin / Finance)
- **UC‑OF03**: Commit stock opening import (Admin + Inventory)
- **UC‑OF04**: Commit fixed-asset opening import (Admin + Finance)
- **UC‑OF05**: Commit AR opening import (Admin + AR)
- **UC‑OF06**: Commit AP opening import (Admin + AP)
- **UC‑OF07**: Commit GL account opening import (Admin + Finance)
- **UC‑OF08**: Review import batch / download errors (Admin / Auditor)
- **UC‑OF09**: Reverse or correct a bad import (Finance — via existing reversal patterns, not delete)

---

## 9. High-level data / integration model

`OpeningImportBatch` (id, domain, tenantId, companyId, anchorDate, filenameHash, status, createdBy, createdAt)  
→ `OpeningImportRowResult` (rowNo, status, errors, resultingEntityIds)  
→ domain aggregates (Item stock / FixedAsset / SOP open invoice / POP open bill / JournalEntry)  
→ GL `JournalEntry` with import/opening source.

Gateways: IM↔GL inventory posting; SOP↔GL sale/AR; POP↔GL obligation/AP; FA within GL.

---

## 10. Acceptance criteria (draft)

1. For each domain in §1, a user can dry-run and commit a template-shaped CSV against a company in an open period and see correct subledger + GL effects.
2. Cross-tenant or wrong-company upload returns 4xx and writes nothing.
3. Closed period upload returns 4xx and writes nothing.
4. AR/AP imports never produce only a control-account opening balance without itemized operational rows.
5. Stock import never leaves IM qty and GL inventory value inconsistent.
6. FA import always creates register rows for `ALREADY_OWNED` assets.
7. Re-upload behaviour matches §7 (tested).
8. Audit batch is queryable and tied to resulting postings.
9. Existing single-entry paths still work unchanged.

---

## 11. Build status against this spec

| Area | Status (2026-09-15) |
|------|---------------------|
| Common upload platform (FR‑UP*) | **Not built** |
| Stock opening CSV (FR‑ST*) | **Not built** |
| FA opening CSV (FR‑FA*) | **Not built** (single-asset `ALREADY_OWNED` exists) |
| AR opening CSV (FR‑AR*) | **Not built** (progressive SOP entry only; §9.8 design) |
| AP opening CSV (FR‑AP*) | **Not built** (progressive POP entry only; §9.8 design) |
| GL balances CSV (FR‑GL*) | **Not built** (per-account API + WEB form exist) |
| WEB upload UX (FR‑UX*) | **Not built** |
| Wire `JournalSource.IMPORT` | **Not built** (enum only) |

**Next step when scheduled:** the design pass is done (`docs/Opening_Figures_CSV_Upload_DDD_Design.md`, 2026-09-18) - implement one domain end-to-end, in the confirmed build order: **GL balances** first (exercises the Suspense-redirect mechanism every other domain leans on), then **Fixed assets** (no new use case needed), then **Stock (IM)**, then **AR/AP** (SOP/POP, needs cross-service coordination).

---

## 12. Open questions (need Femi / Finance)

**All six resolved 2026-09-18 — see `docs/Opening_Figures_CSV_Upload_DDD_Design.md`.** Kept here verbatim for the record; that document is authoritative on the actual decisions.

1. Confirm §7 re-upload defaults or override. → Accepted as recommended.
2. Strict-block vs warn when GL CSV targets AR/AP/Inventory/FA control accounts. → Neither - redirect to the existing Suspense Account instead (design doc §2).
3. v1 CSV-only vs also `.xlsx`. → CSV only.
4. Auto-create missing customers/suppliers/items on import, or reject? → Reject, require pre-creation.
5. Max rows per batch and sync vs async job for large files. → 2,000-row sync/async threshold (engineering default, not a Finance decision).
6. Whether opening stock needs a new IM use case vs labelled goods receipt. → New use case, `RecordOpeningStockUseCase` (design doc §4.1).
