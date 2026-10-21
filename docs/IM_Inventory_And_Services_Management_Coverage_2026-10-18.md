# IM - Inventory and Services Management: what it covers end to end, and what is missing

From the IM session, 2026-10-18. Femi's direction (via CM): IM owns inventory AND services end to end ("it manages everything about inventory and services being bought and sold"). Name used in documents: **IM - Inventory and Services Management**; the repo, service and package stay `IM`. Checked against the code (routes in `infrastructure/web/*Routes.kt`, use cases in `application/`, aggregates in `domain/inventory/`), not against older docs.

**Status key.** BUILT = in IM master and live. BUILT, NOT LIVE = built and with CM, not deployed (branch tips given). PARTLY = some of it exists. MISSING = nothing exists. Sizes are IM working days, tests included.

Branches with CM now, in merge order: `feat/im-service-items` (396569a plus review fixes), `feat/im-revenue-account` (ad15ac7), `feat/im-posted-amount` (d75fb22), `feat/im-cache-control` (3e8f02a, independent).

## 1. The item master (products and services)

| Capability | Status | Where | Gap and size |
|---|---|---|---|
| Create a stock item with an official description, unit, currency, GL stock accounts, valuation method | BUILT | `POST /items`, `CreateItemUseCase` | |
| VAT category on every item, set by Owner Admin or accountant, audited, `null` = no answer, refused at sale and purchase | BUILT | `POST /items/{id}/vat-category`, `GET .../vat-category-history`, `SetItemVatCategoryUseCase` (slice A, live) | The refusal itself is in SOP and POP, which read it. |
| VAT category by Tax Jurisdiction and date (Femi, 2026-10-15) | MISSING | design only: `IM_Product_VAT_Category_v5_Extension_Note.md` | About 1.5 days, after the jurisdiction source (GL) is settled. |
| Service or expense item (no stock, mandatory category, one per description) | BUILT, NOT LIVE | `kind: SERVICE`, `POST /items` with `kind`, `SaveServiceItemUseCase` | |
| Save a purchase line as a reusable item | BUILT, NOT LIVE | `POST /items/from-purchase-line` (POP's token or Owner Admin or accountant), `GET /items?kind=&q=` | |
| Default expense account per service (unclassified = Suspense), validated against GL's chart | BUILT, NOT LIVE | `POST /items/{id}/expense-account`, history | |
| Revenue account per item (stock or service), validated against GL | BUILT, NOT LIVE | `POST /items/{id}/revenue-account`, history | |
| Selling price | BUILT | `POST /items/{id}/selling-price` | One price per item. No price lists, no currency prices, no customer prices (SOP's concern). |
| Edit an item's description or unit after creation | MISSING | no route | 0.5 day. Matters more now that the description is the identity of a service item. |
| Item code / SKU / barcode | MISSING | no field on `Item` | 0.5 day. The opening-figures CSV design keys rows on `item_sku`, so it needs this first. |
| Deactivate or archive an item | MISSING | no field | 0.5 day. |
| Item categories / groups | MISSING | | Not needed for the first cohort; size on request. |
| Item read for SOP and POP (availability, price, category, kind) | BUILT | `GET /items/{id}`, `GET /items` | Contract fixture for a service read waits on `feat/im-contract-fixtures` (about 0.5 day). |

## 2. Quantity in: opening stock and receipts

| Capability | Status | Where | Gap and size |
|---|---|---|---|
| Opening stock as quantity and total value, to Suspense, once per item | BUILT (live) | `POST /items/{id}/opening-stock`, `RecordOpeningStockUseCase` | |
| Opening stock by CSV | MISSING | design `Opening_Figures_CSV_Upload_DDD_Design.md` | Needs the item code; about 2 days after GL balances and Fixed Assets (the agreed order). |
| Goods receipt against a purchase, with a GL posting | BUILT | `POST /items/{id}/receive`, `RecordGoodsReceiptUseCase` | |
| Receipt that is retry-safe and atomic (A0) | MISSING | GL posts, then three separate saves, no key | About 1.5 days; first step of the seam A plan. Opening stock has the same window. |
| Goods Received Not Invoiced (receipt credits GRNI, POP clears it) | MISSING | receipt credits AP by default, so a matched purchase counts twice (seam A) | About 1.5 to 2 days in IM, plus GL's accounts and POP's half. Waits on Femi's D-I1 to D-I3. |
| Returns outwards (back to the supplier) | BUILT | POP calls `POST /items/{id}/issue`; the answer now carries `postedAmount` | The AP debit is at IM cost, which may differ from the supplier price (seam A question for Femi). |
| Returns inwards (customer returns stock) | MISSING | the receipt route requires a purchase-order reference | About 1 day: generalise the receipt as the issue was generalised (reference optional, contra supplied by the caller). The AR side exists in GL. |
| Landed cost | PARTLY | `LandedCostAllocation` domain only, no route | 1.5 days to route and post. |
| Goods in transit | PARTLY | `InTransitShipment`, `LocationState` domain only | About 2 days. Only needed for import trade. |
| Batch or lot receipts with expiry | PARTLY | `Item.receiveBatch` domain only; the route has no batch field | About 1 day. |

## 3. Quantity out: issues, sales and consumption

| Capability | Status | Where | Gap and size |
|---|---|---|---|
| Goods issue for a sale, retry-safe with `Idempotency-Key`, per-item lock | BUILT | `POST /items/{id}/issue`, `RecordGoodsIssueUseCase` | |
| Issue with the amount posted returned | BUILT, NOT LIVE | `postedAmount`, `currency` on the answer | |
| Issue from a named batch | PARTLY | `Item.issueFromBatch` domain only | With batch receipts, about 1 day. |
| Stock reservation against open orders | MISSING | | About 2 days plus SOP. Two concurrent orders can both look valid today; the second issue fails safely. |
| Work in Progress and production (raw material to WIP to finished goods) | PARTLY | `Item.consumeInto`, `addProductionCost`, `completeInto`, `OverheadAllocation`: domain only, exact | About 2 days to route and post. |

## 4. Adjustments, counts and locations

| Capability | Status | Where | Gap and size |
|---|---|---|---|
| Adjustments (shrinkage, found stock) with approval by a Store Manager | BUILT | `POST /items/{id}/adjustments`, `GET /adjustments/pending`, approve and reject | The approver moves to EA's approve capability when RBAC unfreezes. |
| Stock count with variance to an adjustment | BUILT | `POST /items/{id}/stock-counts`, `ConductStockCountUseCase` | |
| Correct a wrongly entered receipt cost (revaluation) | MISSING | adjustments are quantity-only; no reversal of a receipt | About 1.5 days, plus a non-blocking warning on a cost far from the last (0.5 day). UAT finding 7. |
| Warehouses, zones, bins, item-to-bin assignment, transfers | BUILT | `/warehouses`, `/zones`, `/bins`, `/items/{id}/location-assignments`, `POST /items/{id}/transfer` | |
| Stock balance per bin updated by receipts and issues | BUILT | `InventoryBalance` | |
| A stock card (movement history per item) | MISSING | confirmations are stored but no read route | About 1 day. The first thing an accountant asks for when a figure looks wrong. |

## 5. Costing and valuation

| Capability | Status | Where | Gap and size |
|---|---|---|---|
| Weighted-average and FIFO costing, exact to the penny, unit cost derived | BUILT (live) | `Item` (option A, total value) | |
| Stock value always equals the sum of what the ledger was told, zero at zero stock | BUILT (live) | `StockValueEqualsLedgerTest`, Postgres invariant tests | Legacy rows keep any drift recorded before (Business One's 0.48) until its stock next moves; an adjustment journal clears it. |
| Valuation reconciled to account 1300 | PARTLY | each item is exact; the dashboard tile sums items | No IM-versus-GL reconciliation view. About 1 day: IM total of item values, GL's 1300 balance (a read), and the difference by item where they differ. |
| Net realisable value write-down (lower of cost and NRV) | PARTLY | `Item.assessNetRealisableValue` domain only, exact | About 1 day to route and post. |
| Standard costing | MISSING | | Not needed for the first cohort. |
| Inventory aging, slow-moving | PARTLY | `GET /items/{id}/stock-velocity` per item | A company-wide report: about 1 day. |

## 6. Replenishment

| Capability | Status | Where | Gap and size |
|---|---|---|---|
| Reorder point from usage, lead time, safety stock | BUILT | `POST /items/{id}/replenishment-policy`, `GET /items/{id}/inventory-levels` | |
| A list of everything below its reorder point | MISSING | per item only | About 0.5 day. |
| Economic order quantity, replenishment recommendation | PARTLY | `EconomicOrderQuantity`, `ReplenishmentRecommendation` domain only | About 0.5 day to expose; a purchase suggestion for POP is a further step. |

## 7. Services bought and sold

| Question | Answer today |
|---|---|
| How is a service BOUGHT represented? | A POP purchase line points at a SERVICE item (`itemId`), which carries the VAT category and the default expense account. A line for something not yet in the list is saved as an item at purchase (`from-purchase-line`), so a repeat can pick it. |
| How is a service SOLD represented? | The same item kind. SOP reads it (`GET /items/{id}`), takes the VAT category (a frozen copy on the line), skips availability and goods issue. ER fee items point at a SERVICE item. The revenue account is on the item. |
| Where is the account decided? | On the item: `expenseAccountId` for what is bought, `revenueAccountId` for what is sold. Unclassified expense goes to Suspense. GL's per-line routing (design approved) and POP and SOP sending the account per line are theirs. |
| Missing in IM | The date and jurisdiction-resolved category (1.5 days); bulk setup of a school's fee types (a seeding design question); edit description and unit; a service price list by customer or period (SOP's concern); input VAT recoverability as a per-item flag (GL's rule today). |

## 8. Sizing the rest

Needed for a first cohort that holds real stock: **A0 receipt idempotency (1.5)**, **returns inwards (1)**, **valuation reconciliation to 1300 (1)**, **item code and edit (1)**, **stock card (1)**: about 5.5 days. Then **GRNI** with GL and POP (about 2 in IM), the **v5 category by jurisdiction and date** (1.5), the **opening-stock CSV** (2), and the domain-only IAS 2 features (NRV, WIP, landed cost, batches, in-transit, EOQ: about 8 together, none on the critical path). Stock reservation (2) waits on volume.

## 9. What I would do next, in order

1. Fix CM's review findings on slice B, then A0, then returns inwards. 2. Contract fixtures for the service read (SOP is waiting). 3. Item code and edit, the stock card, the valuation reconciliation. 4. GRNI once Femi answers D-I1 to D-I3.
