# IM: opening stock for the first cohort

From the IM session, 2026-10-17. **Source:** Femi, 2026-10-15 (Decisions Log): the first customers must be able to do opening stock upload, opening receivables and payables, and trade finance at go-live; the build order in `docs/Opening_Figures_CSV_Upload_DDD_Design.md` stands (GL balances, Fixed Assets, **Stock**, then AR/AP). This note is the IM slice of that.

## 1. What existed, and what is built now

| Piece | State on 2026-10-17 |
|---|---|
| `RecordOpeningStockUseCase` (Dr Inventory / Cr Suspense, tagged IMPORT, no goods receipt, refused when the Item already holds stock) | Existed since 2026-10-01, tested at unit level, **never reachable**: no route (MVP definition, go-live flag 1). |
| `POST /api/companies/{companyId}/items/{id}/opening-stock` | **Built now**, IM branch `feat/im-opening-stock-route` (stacked on `feat/im-vat-category-a`, so CM merges slice A first). 317 unit and 37 Postgres tests green. |
| CSV upload | **Later**, per the design doc: the importer calls this route once per row. Not started. |

## 2. The route

Request: `{ "quantity": "108", "unitCostAmount": "410.00", "date": "2026-10-01", "description": "Opening stock" }`. Answers: `201` with the item and the journal entry id; `404 item_not_found`; `409 already_has_stock` (the Item holds any quantity, so it can be done once per Item; a correction is a reversal first, never an overwrite, per the design doc's decision 1); `409 invalid_opening_stock` (zero or negative quantity); `409 suspense_account_unavailable` (the Company has no Suspense account: **refused, never posted to Accounts Payable**); `403` for anyone but the Owner Admin or an accountant, and for a service account; `409 item_busy` if another stock movement holds the Item.

Behaviour, checked in tests: posts to the Company's Suspense account (3910) and not to AP; tags the journal IMPORT; creates **no** goods receipt confirmation (nothing was received); runs under the per-Item lock; the stored Item is untouched when GL refuses.

## 3. Decisions for Femi: ANSWERED 2026-10-17 (via CM)

1. Gate: stays Owner Admin or accountant only. 2. Quantity and TOTAL value: yes, built on `feat/im-total-value-costing` (`9458a21`): the route takes `totalValueAmount`; `unitCostAmount` is still accepted until WEB moves. 3. (Suspense reclassification) still a go-live checklist item. The original text follows for the record.

## 3a. Decisions for Femi (original, each had a recommendation)

1. **Who may record opening stock.** Built as the Owner Admin or an accountant (the same rule Femi set for the VAT category), because it puts a figure into the ledger. An inventory manager with WRITE is refused. Recommendation: keep. Relaxing it to every writer is a one-line change. (Fixed assets were treated the same way: inflated assets mean false profit.)
2. **Unit cost or total value.** The route takes a unit cost, and IM holds unit costs to the penny. Real opening figures arrive as quantity and a **total value** (for example 108 units worth 44,285.00, a unit cost of 410.0463...), which a penny-rounded unit cost cannot hold, so the Item would start with the same rounding drift described in `TestResultsResponses/IM_Response_to_RT-5_Supplier_Tile_2026-10-15.md`. Recommendation: decide that note's option A (IM holds the total value) **before the CSV importer is built**, then the route and the CSV take quantity plus total value. Until then, a cost that is a whole number of pence per unit is exact.
3. **Reclassifying Suspense.** Opening stock lands in Suspense until classified (design doc section 2). Who clears it, and when, is the accountant's ordinary journal. Not decided here, flagged so a go-live checklist can include "Suspense is zero after the opening figures are all in".

## 4. Known limits (stated plainly)

- **Not retry-safe at the GL boundary.** Like the goods receipt, it posts to GL and then saves the Item. A failure between the two leaves GL ahead of IM, and a retry would post again because the Item still shows no stock. The per-Item lock and the once-only guard cover a lost reply (the retry sees stock and answers `already_has_stock`). The window is the same A0 gap the receipt has (receipt idempotency and atomic save, the first task of the seam A plan); fixing A0 fixes this too. Until then an operator doing a bulk upload should check any row that failed with a gateway error before retrying it.
- **No bin balances.** The stock goes onto the Item, not into a bin. A business using warehouses, zones and bins would add the balances separately (a transfer-in does not exist for opening stock yet). Not needed for the first cohort unless Femi says they use bins.
- **Batch-tracked or FIFO items:** the use case uses the ordinary receipt costing, so FIFO gets one opening layer; batch tracking has no opening-stock path (the domain batch API is not routed anyway).
- **Needs GL's posting context to send `suspenseAccountId`.** GL's `ComputeInventoryPostingContextUseCase` carries it (added 2026-10-01); IM refuses cleanly when it is absent.

## 5. Order and hand-off

Slice A (VAT category) first, because this branch is stacked on it. Then, if Femi wants opening stock sooner than service items (slice B), this route can ship alone as soon as CM merges slice A. The CSV importer (design doc section 3) is a separate piece and waits on GL balances and Fixed Assets, and on the unit-cost-versus-total-value decision above.
