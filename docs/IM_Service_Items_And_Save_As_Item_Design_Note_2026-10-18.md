# IM slice B: service items, and "save a purchase line as an item" (design note, for POP, WEB, EA, SOP and CM)

**Status 2026-10-18 (later): APPROVED by Femi on all three questions and BUILT** on IM branch `feat/im-service-items`, tip `396569a`, handed to CM (not yet deployed). 380 unit and 51 Postgres tests. Two changes since this note was first sent, both from Femi: (1) a service item carries an **optional default expense account** from the first slice (section 8); (2) **no account = Suspense**. A revenue account for sales (section 9) follows as its own small branch.

From the IM session, 2026-10-18. DESIGN ONLY, nothing built. Extends `IM_Product_VAT_Category_SPUTO.md` v4 (slice B, R17 to R21, D8). **Source (Femi, relayed by CM, 2026-10-18):** a purchase line for something not in the item list (rent, utilities, a supplier's one-off service) keeps an explicit VAT category chosen at purchase, and must carry an official description and that category, **saved at purchase as a reusable line item** so a repeat can pick it. VAT recoverable where charged (UK and IE). And the relayed rule: **line VAT always comes from the item's category.**

## 1. The shape in one paragraph

A **service item** is an IM Item with `kind = SERVICE`: no stock, no bins, no cost method, but an official description, a unit, a currency, and a **mandatory VAT category**. A purchasing caller can create one from a purchase line through one dedicated route, and later purchases pick it from the item list like any other item. The first time, the line carries the category the user chose; once the item exists, the line takes the item's category (a frozen copy) and the typed one is no longer used.

## 2. Routes (all under `/api/companies/{companyId}`, additive)

| Route | Body and answer |
|---|---|
| **`POST /items/from-purchase-line`** (new) | Body: `{ "description": "Office rent, Unit 4", "vatCategory": "STANDARD", "unitOfMeasure": "each", "currency": "GBP", "requestedBy": "buyer@example.com" }`. `description` and `vatCategory` required (the six GL names); `unitOfMeasure` defaults to `each`; `requestedBy` is the human at the PO form and is honoured **only** from POP's service token (it goes into the audit row). **201** a new SERVICE item. **200** the existing item, when the same description (compared ignoring case and extra spaces) already exists in this Company with the **same** category: this makes retries and repeats safe, nothing is duplicated. **409 `item_exists_with_different_category`** (body names the existing item id and category) when the description exists with another category: it is never overwritten. **400** `invalid_vat_category`, `description_required`. |
| `GET /items?kind=SERVICE&q=rent` (existing route, two optional filters) | `kind` is `STOCK` or `SERVICE`; `q` is a case-insensitive text match on the description. This is how "pick it on a repeat" finds the item. Without them the answer is unchanged. |
| `POST /items` (existing) | Also accepts `kind: "SERVICE"` for the master-data path (Owner Admin or accountant only, with the category, as slice A). For `SERVICE` the stock fields (accounts, valuation method, stage, batch tracking) must be absent: `400 service_item_has_stock_fields`. |
| `POST /items/{id}/vat-category` (existing) | **Unchanged and unchanged gate: Owner Admin or accountant only (D2).** Changing a service item's category later is theirs alone, with a reason. |
| Every stock route | A SERVICE item is refused `409 item_is_service` (receive, issue, transfer, opening stock, counts, adjustments, replenishment, velocity, levels). Stock reports and EA's inventory tile exclude services. |

## 3. Response shape (consumer-first, section 5)

`ItemResponseDto` gains `kind` (`STOCK` or `SERVICE`, always present) and `origin` (`MASTER` or `PURCHASE_LINE`, always present); `inventoryAssetAccountId`, `cogsExpenseAccountId` and `glStockItemId` become **nullable** (null for SERVICE only). For a SERVICE every stock number reads `"0"`. **EA's strict mirror already declares `kind` and the three nullable fields (checked in `im_dtos.kt`)**; it does not yet declare `origin`, so EA adds one nullable-with-default field before IM ships.

## 4. Who may do what (the gate)

| Action | Who | Why |
|---|---|---|
| **Create a service item from a purchase line** | POP's service account (on behalf of the PO writer POP has already authorised through EA), **or** a human Owner Admin or accountant | The category entered here is what the **supplier charged** (input VAT), the same reasoning as Playbook R25; the people writing purchase orders are usually Purchasing Officers who hold POP but not IM, so they reach IM through POP. SOP's service account and every other human are refused 403. |
| **Change that item's category later** | Owner Admin or accountant only (D2), with a reason | Unchanged. |
| Read and search | Anyone who may read items, including POP's and SOP's service tokens | As today. |

This is a **narrow, deliberate exception to "a service account never decides a category"**: POP may set the category exactly once, when the item is first created from a purchase, and can never change it. Safeguards: every item created this way is stamped `origin = PURCHASE_LINE` with `requestedBy` in the audit row (the existing `item_vat_category_changes` first-answer row), so an accountant can review them; duplicates are impossible by the description rule; a wrong category can be corrected only by Owner Admin or accountant. **Needs Femi's yes** (section 6, question 1).

Implementation note: `VerifiedIdentity` today knows only `isServiceAccount`; it gains a `serviceName` (`POP` or `SOP`) set at validation time from the provider that matched, so the gate can name POP specifically. No change to how any existing route authorises.

## 5. Order (consumer-first, as always)

1. **EA:** declare `origin` (default `MASTER`). Everything else is already declared.
2. **WEB:** types first: `Item.kind`, `Item.origin`, nullable account ids. No UI yet.
3. **POP:** declare `kind`, `origin`, `vatCategory` in its narrow tolerant item DTO; no behaviour yet.
4. **IM ships** slice B (this note), behind nothing: every new field and route is additive and every existing answer unchanged.
5. **POP and WEB build:** a purchase line with no item gets a "Save as an item" step (official description, category, then `POST /items/from-purchase-line`); POP then stores the returned `itemId` on the line and takes the category from the item. Later purchases search the item list (`kind=SERVICE&q=`) and pick it.

POP also needs to settle one thing IM cannot: **which ledger account a purchase of a service item debits.** IM holds none for a SERVICE (the account fields are null). POP's existing handling of a line with no stock item stays as it is; if Femi wants a default expense account per service item, that is a further optional field on the item, not part of this slice.

## 6. Questions for Femi (ALL ANSWERED YES, 2026-10-18)

1. **May the purchasing side set the category the first time**, with only the Owner Admin or an accountant able to change it afterwards (section 4)? Recommendation: yes. Otherwise a Purchasing Officer cannot save a rent or utility line at all, and the user is back to typing a category on every line.
2. **One item per description?** A repeat of "Office rent, Unit 4" at a different category (rate change, a different landlord's VAT status) would be refused with the existing item named, and the accountant changes the category deliberately. Recommendation: yes. The alternative is one item per supplier and description, which makes the list grow with every supplier.
3. **Name of the kind.** Femi said service or expense; IM keeps one kind, `SERVICE` ("no stock"), because a bought expense and a sold service are the same thing to IM (a description, a unit and a VAT category). WEB can label it "Service or expense".

## 7. Size

About 2.5 IM days (migration for `kind`, `origin` and nullable accounts; the domain factory; the new route and filters; the stock-route guard with a table-driven test over every route; reports and EA tile exclusion; tests including a Postgres migration test on a database that already holds Items). The migration is additive: `kind` defaults to `STOCK` for every existing row, which is a fact, not a guess.

## 8. The default expense account (added 2026-10-18, Femi: "the primary function of a General Ledger. Sacrosanct.")

- **Field:** `expenseAccountId` (nullable string, an account id of the Company's own chart) on **every item response**; always `null` for a STOCK item (its accounts are the three stock fields). `null` on a service means **unclassified: a purchase posts to GL's Suspense account (3910), never to a default expense account**. POP and WEB show "Unclassified (Suspense)" when it is null.
- **Set at creation:** optional `expenseAccountId` on `POST /items/from-purchase-line` and on the master `POST /items` with `kind: SERVICE`.
- **Changed or cleared afterwards:** `POST /items/{id}/expense-account` with `{ "expenseAccountId": "..." }` (or `null` to clear). **Owner Admin or accountant only**, the same gate as the VAT category. `409 item_is_stock` for a stock item. History: `GET /items/{id}/expense-account-history` (who, when, from, to).
- **Validated against GL's chart before it is stored:** IM reads GL's `GET /companies/{companyId}/accounts` with its own service login; the account must be an **active** account of **this Company** of type **EXPENSE** (receivables, payables, VAT and inventory are assets and liabilities, so an expense type is never a control account). Otherwise `400 invalid_expense_account`; if GL cannot be asked the answer is GL's status as `gl_engine_call_failed` and nothing is stored.
- **A repeat of the same description and category with a different account returns the existing item (200) and never changes its account silently.** The 409 `item_exists_with_different_category` stays for the category only.
- The account is audited in its own table (`item_expense_account_changes`), written in the same transaction as the item.

## 9. The response shape as built (a SERVICE read, `GET /items/{id}`)

`kind: "SERVICE"` (values `STOCK` | `SERVICE`, always present), `origin: "PURCHASE_LINE"` (`MASTER` | `PURCHASE_LINE`, always present), `vatCategory`, `expenseAccountId`, `currency`, `unitOfMeasure`, `description`, `sellingPriceAmount` (a service MAY carry a price; null until set). The three stock accounts and `facilityId` are `null`. Every stock figure reads zero: `quantityOnHand "0"`, `unitCost`/`totalValue`/`nrvWriteDownPerUnit`/`carryingValuePerUnit`/`totalCarryingValue` `"0.00"`, `batchesOnHand []`, `isBatchTracked false`; `valuationMethod` reads `WEIGHTED_AVERAGE` and `stage` `FINISHED_GOODS` as meaningless placeholders (a service has neither). Every stock action on it answers `409 item_is_service`.

**Next, its own small branch (Femi approved D2, relayed by CM):** an optional nullable `revenueAccountId` on **every item (stock and service)**, the sales revenue account chosen from the Company's chart, set by the Owner Admin or an accountant (the VAT-category gate), validated against GL (type REVENUE, active, this Company) with the same lookup. Additive, in every item response. Labels (Femi): Sales, Purchases, Inventory.
