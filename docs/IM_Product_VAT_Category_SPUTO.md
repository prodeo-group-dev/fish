# Product VAT category, owned by IM: SPUTO / Playbook (v4)

**Status: v4 APPROVED by Femi 2026-10-14 ("Yes to all four", Decisions Log). Updated by the IM session 2026-10-17: slice A is BUILT (IM branch `feat/im-vat-category-a`, tip `a9aef11`, reviewed by CM, queued to release, not yet deployed); slice B (service items), A0 and wave 5 are not built. The category will also depend on the Tax Jurisdiction and the date (Femi 2026-10-15): see `IM_Product_VAT_Category_v5_Extension_Note.md`, which explains how slice A extends to that without a rewrite. Nothing below changes for slice A.** v1, v2 and v3 are superseded by this file and stay in git history. **v4 states the model exactly as Femi put it on 2026-10-14** (R27 below): *"IM should know whether a product is VATable and if so which category of VAT"*, with exempt, zero-rated and out-of-scope as explicit answers, never a missing value, and "no answer yet" refused at sale and purchase time. **v3 folds in POP's review of v2** (POP, 2026-10-12, relayed by CM): purchases differ from sales in three ways, see R23 to R26 and D8, D9 below.

**Why v2.** On 2026-10-11 Femi decided the design with SOP (Decisions Log, entry "VAT category: IM owns it per product or service item", merged in `dd6a0b2`): *IM owns the category for every product **and service** (services are IM items); a sales line takes a **copy** of the item's category when it is ordered and the copy never changes afterwards, so a posted invoice reprints exactly as issued; **nobody types the category on a line**; SOP **reads** it from IM at order time; the VAT figure itself is calculated by GL.* That reverses three parts of v1: v1 said WEB pre-fills a line the user may override, that POP/SOP make no call to IM, and that every IM Item is stock. All three are rewritten below.

**Source of the original requirement.** Femi, via CM, 2026-10-10: *"it is the product that determines whether it's vatable or not"*. Process rule: *"SPUTO gives them the Playbook to build against"*. This document is that Playbook for IM, SOP, POP, WEB and EA.

**Written from.** IM master `cf97150` (task definition `:32`) and the code read for v1, plus, for v2: IM's route list, `Item`/`ItemResponseDto`/`items` table, `CreateItemUseCase`, SOP's own replies today, and the Decisions Log. Every claim marked "checked" was read in code. Anything unverified is in section 10 and says so.

---

## 0. In one paragraph

Today an IM `Item` has no VAT information and every Item is physical stock. This playbook (1) adds **`Item.vatCategory`**, one of the six GL values, set by the owner and never defaulted, editable with a reason and an audit trail; (2) adds **service items**, so a service is an Item with no stock tracking (`kind = SERVICE`) and therefore also has a category; (3) has **SOP read the category from IM when a line is ordered and store a frozen copy on the line**, with no one typing it. GL still decides which categories a country allows and computes the VAT figure. The dangerous part is shipping order: **EA's decoder fails closed on an unknown field**, so consumers declare the new fields before IM ships them.

---

## 1. Scope (S)

**In scope**
1. `vatCategory` on the IM `Item`: stored, returned in every item response, set at creation, set or changed afterwards by a human with write access, with an audit trail.
2. **Service items**: `kind` = `STOCK` or `SERVICE`; a service item carries a category, a unit, an optional selling price, and no stock tracking.
3. A rule for every existing Item: nothing is defaulted. They start as "not set" and the owner sets them. (Every existing Item is `STOCK`; that is a fact, not a default of the tax kind.)
4. How SOP (and, if confirmed, POP) read and copy it, and what happens when it is missing.
5. The wire contract and the order in which services ship it; migration safety on the live IM database.

**Out of scope (noted, not decided here)**
- Which products are vatable, or at which rate: the owner's legal decision, and GL's rate schedule decides the percentage. IM never computes VAT.
- Whether a Company is VAT-registered at all (a Company-level fact, section 10, item 6).
- Partial-exemption apportionment and price-inclusive pricing (GL has deferred both).
- Transaction-dependent VAT such as exports and reverse charge (a product-only category cannot express it, section 10, item 1).
- SOP's and POP's own line changes, listed here only where this playbook depends on them.

**This amends `docs/IE/IE_VAT_MVP_Design.md` (2026-09-13)** twice: first by moving the *source* of the category from the line to the product (that document already allowed an Item-level default as "a legitimate later UX convenience"), and second, now, by taking away the line-level choice altogether. What it kept is still true: the line stores what actually applied.

---

## 2. Plan / requirements (P)

| # | Requirement |
|---|---|
| R1 | `Item.vatCategory` is exactly one of `STANDARD`, `REDUCED`, `SECOND_REDUCED`, `SUPER_REDUCED`, `ZERO_RATED`, `EXEMPT`: the identical names GL, POP and SOP use. No mapping layer. |
| R2 | `null` means "not set yet". It never means exempt or zero-rated, and nothing treats it as a default. |
| R3 | An Item (of either kind) is created **with** a category once enforcement is on (Wave 5). Before that the field is accepted but optional. |
| R4 | Existing Items are not backfilled. They stay `null` until a human sets them. |
| R5 | Setting or changing the category (and sending one on create) needs the ordinary IM write gate AND the caller to be the Tenant's **Owner Admin or an accountant** at the Company (Femi's D2 ruling, 2026-10-14). Service accounts (POP, SOP tokens) are refused. **Built in slice A** as an added refusal on top of the existing gate, so an accountant also needs the IM module granted at the Company. |
| R6 | Changing a category that is already set requires a non-blank `reason`. The first set does not. |
| R7 | Every set or change writes an audit row in the same transaction as the item update: previous value, new value, reason, who (email), when. |
| R8 | The set route runs under the same per-Item lock as the other Item writes, so a concurrent stock movement cannot write a stale category back (`ItemRepository.save()` rewrites the whole row). |
| R9 | Item responses (list, single, and the `item` embedded in goods receipt/issue/adjustment responses) gain `vatCategory: String?` and `kind: String`. |
| R10 | IM validates only the six names. GL stays the authority on what a Company's country supports and answers `vat_category_not_supported` at posting. |
| R11 | **SOP reads the category from IM when a sales line is ordered**, using the existing `GET /companies/{companyId}/items/{id}` with SOP's service login, and stores a **copy** on the line. No one types the category on a line. WEB shows it read-only. |
| R12 | The copy never changes afterwards. A later change to the Item never alters a line already ordered, and a posted invoice reprints exactly as issued. |
| R13 | If the Item has no category, SOP **refuses the line** with `409 item_has_no_vat_category`, mirroring `item_has_no_selling_price`. Never a default. (Whether POP follows the same rule for purchase lines is open: section 10, item 2.) |
| R14 | No path anywhere may silently default a category. Missing means refused. |
| R27 | **The model, exactly as Femi stated it (2026-10-14).** For every product **and** service IM holds two answers: (1) **is it VATable at all**, where *exempt*, *zero-rated* and *out of scope* are explicit answers and not a missing value; and (2) **if it is VATable, which rate category**. Stored as the one `vatCategory` value (the six GL names, R1), read like this: **no answer yet** = `null`; **exempt or out of scope** = `EXEMPT` (GL's own definition is "outside VAT scope entirely, no output VAT"; a separate out-of-scope value is decision D11); **VATable at 0%** = `ZERO_RATED`; **VATable at a rate** = `STANDARD`, `REDUCED`, `SECOND_REDUCED` or `SUPER_REDUCED`. The *percentage* behind a rate category is GL's, per country and date, never IM's. |
| R28 | **"No answer yet" is refused at sale and at purchase time, in plain words, never defaulted.** SOP and POP answer `409 item_has_no_vat_category` with the message *"This product or service has no VAT answer yet. Set whether it is VATable, and its VAT category, on the item first."*, and WEB shows it with a link to the item. Posting to GL is never reached with a missing category. |
| R15 | The migrations are additive and safe on the live shared database (section 7). |
| R16 | Contract changes ship consumer-first (section 6). IM does not ship a new response field until EA and WEB have deployed decoders that declare it. |
| R17 | `kind` is `STOCK` or `SERVICE`, set at creation, immutable. Every existing Item is `STOCK`. |
| R18 | A `SERVICE` item requires: description, unit of measure, entity, currency and (once enforcement is on) `vatCategory`; it may have a selling price. It has **no** inventory asset account, COGS account, GL stock item, valuation method, stage, batch tracking, bins, quantity or cost. Its quantity and value fields read `"0"`. |
| R19 | Every stock route refuses a `SERVICE` item with `409 item_is_service` and changes nothing: receive, issue, transfer, location assignments, stock counts, adjustments (create and approve), replenishment policy, stock velocity, inventory levels. A table-driven test covers every route. |
| R20 | Stock reporting excludes services: IM's low-stock monitor, EA's inventory tile counts and WEB's stock valuation report. `GET /items` returns both kinds, with `kind`, and accepts an optional `?kind=` filter. |
| R21 | No consumer may infer "stock" from "has an itemId". A line is stock only when its Item's `kind` is `STOCK`. **POP derives its `itemType` from `kind` at entry** (a `SERVICE` item forces `itemType` `SERVICE`), so POP needs no new column; IM's `409 item_is_service` on a receipt stays as the second guard. |
| R22 | The old per-line category entry that SOP built stays only as a transition path and is removed once Wave 4 is live (section 5, T-SOP-3). **This is SOP's transition only; it does not apply to POP's set-category route (R25).** |
| R23 | **Purchases follow the same read-and-copy rule where a line has an Item** (Femi's snapshot rule, confirmed by CM): POP reads the Item's category at order time and stores a frozen copy per line; a category typed on a line that has an `itemId` is refused with `400`. |
| R24 | **Purchase lines with no Item** (rent, utilities, one-off supplier services) are **not** refused: they keep an explicit category on the line (required on create and amend), until Femi decides D8. |
| R25 | **POP's set-category route (unposted orders only) stays** as the visible correction path before the match. Reason: input VAT is what the **supplier charged**, which can differ from the buyer's own Item category (supplier zero-rating, exports, intra-EU supplies). It is the purchase analogue of D7, and it is not listed for removal. |
| R26 | POP's read of an Item is a new POP-to-IM call, `GET /companies/{companyId}/items/{id}` with POP's service login, decoding only `{id, kind, vatCategory}` tolerantly. If IM is unreachable at order time the line is refused with `503` (try again), never given a default category. An Item with no category answers `409 item_has_no_vat_category`. |

### Decisions for Femi (each has a recommendation; none is made without you)

Decided already (Decisions Log, 2026-10-11): IM owns the category; services are IM items; the line holds a frozen copy; nobody types it; SOP reads it; GL computes the figure. Not asked again.

| # | Question | Recommendation |
|---|---|---|
| D1 | Required at creation, or optional forever? | Required, in two steps: accepted-but-optional first (Wave 2), enforced as `vat_category_required` once WEB's create forms send it (Wave 5). "Not set" then exists only for Items created before. |
| D2 | Who may change a category? | **RULED 2026-10-14 (Femi): only the Owner Admin or an accountant, audited.** Built in slice A. Service accounts refused, a reason required to change. (The earlier recommendation, any writer, is superseded.) |
| D3 | Check the category against the Company's country at set time? | No, not in v1. WEB offers only the categories GL lists for the Company (`GET /companies/{companyId}/vat-categories`). GL refuses an unsupported one at posting. |
| D4 | How do owners fix the old Items? | One at a time with a "VAT category not set" badge and filter (Wave 4). Optional later (Wave 6): a bulk "set all unset Items to X" the owner must confirm: an explicit act, not a silent default. |
| D5 | The shape of a service item (R18). | As R18: the fewest fields, no stock machinery, immutable `kind`. The alternative (a separate Service resource) is rejected: services must be readable at `GET items/{id}` like products or SOP needs two code paths. |
| D6 | **Sales** lines with **no item** (free text, one-off). With nobody typing the category there is no source for it. | **Refuse them** (SOP), and give WEB a one-step "add a service" that creates a `SERVICE` item with its category inline, so a one-off charge costs one extra click, not a blocked order. Needs confirmation (it ends free-text sales lines), routed through CM. |
| D7 | An unposted **sales** line holds a wrong copy (the item was fixed afterwards). | Not a typed correction. Offer **"re-read from the item"** before posting, which replaces the copy from the Item's current value. Needs SOP's and CM's agreement, since SOP built an explicit correction route that this supersedes. Purchases are different (R25). |
| D8 | **Purchase** lines with **no item** (rent, utilities, a supplier's one-off service). Refusing them, as D6 does for sales, would block any purchase not in the item list. | **Do not refuse.** Lines with an `itemId` read-and-copy (R23); lines without keep an explicit category on the line (R24). Revisit if Femi wants every purchase to be an Item too (a "service" item per recurring cost). Purchase-specific question for Femi, through CM. |
| D11 | **ANSWERED 2026-10-14 (Femi): keep the six values; EXEMPT also covers out of scope.** (Original question:) **Is "out of scope" different from "exempt"?** Femi named both. GL today has one value, `EXEMPT`, defined as outside VAT scope (no output VAT; input VAT on directly attributable costs not reclaimable). In many countries the two differ (exempt supplies sit inside the VAT system; out-of-scope ones sit outside it) mainly for input-VAT recovery, which GL has deferred (partial exemption). | **Keep the six values for now:** exempt and out of scope both answer `EXEMPT`, and WEB labels it "Exempt or outside VAT". Add a separate `OUT_OF_SCOPE` only when GL builds partial-exemption apportionment: it is a change in GL, POP, SOP and IM at once. A question for Femi and GL, through CM. |
| D9 | A product-only category **cannot express VAT that depends on the transaction**: an export (zero-rated though the product is normally standard), reverse charge, a supplier who charges differently. | For MVP: **not supported on the sales side**; use a separate Item ("Sugar, export") where it matters. For purchases R25 already covers it. A tightly controlled transaction-level override can come later if Femi wants it. A question for Femi, through CM. |

---

## 3. Wire contract

All routes are Company-scoped under `/api/companies/{companyId}`, as today.

**`ItemResponseDto` changes** (consumers declare these first, section 6)

```json
{ "id": "…", "kind": "STOCK", "description": "Sugar 50kg", "…": "…existing fields…",
  "sellingPriceAmount": "55.00", "vatCategory": "ZERO_RATED" }
{ "id": "…", "kind": "SERVICE", "description": "Delivery", "unitOfMeasure": "trip", "…": "…",
  "inventoryAssetAccountId": null, "cogsExpenseAccountId": null, "glStockItemId": null,
  "quantityOnHand": "0", "unitCost": "0", "…": "all stock values \"0\"", "vatCategory": "STANDARD" }
```
- `vatCategory` is `null` when not set. `kind` is always present.
- The three account fields become **nullable** (null for `SERVICE` only). Today EA's decoder declares them non-null, so EA and WEB must declare them nullable before any service item exists.
- The same DTO is embedded as `item` in the goods receipt, issue and adjustment responses, so those gain the fields too.

**Create** (`POST /items`): optional `kind` (default `STOCK`); `vatCategory` optional in Wave 2, required in Wave 5 (`400 vat_category_required`). For `SERVICE` the stock fields (accounts, valuation, stage, batch tracking) must be absent (`400 service_item_has_stock_fields`). Invalid value: `400 invalid_vat_category`.

**Set or change** (new): `POST /items/{id}/vat-category`

```json
{ "vatCategory": "STANDARD", "reason": "Reclassified after accountant review" }
```
- `200` with the updated `ItemResponseDto` (same value as stored: `200`, no audit row).
- `400 invalid_vat_category`; `400 reason_required` (already set, `reason` blank).
- `403 forbidden` (no WRITE, or a service account); `404` (missing or another Company's item); `409 item_busy`.

**History** (new, read access): `GET /items/{id}/vat-category-history` returning `{ "changes": [ { "changedAt", "changedBy", "previous", "new", "reason" } ] }`, newest first; `previous` is `null` for the first set.

**Stock routes on a service item:** `409 item_is_service` (R19).

**What POP uses (R23, R26):** the same `GET /items/{id}` with POP's service login, a narrow tolerant decode of `{id, kind, vatCategory}`. POP has no read of an IM item today (only receive and issue), so this is a **new** POP-to-IM call. IM's inbound service allow-list (M1b) is not built yet; **when it is, POP's list must include this GET**, as SOP's does. After the decode fix (live `:33`) POP's existing receive and issue calls already ignore new item fields, so W2 does not break them.

**What SOP uses (R11):** the existing `GET /items/{id}`, with SOP's service login. The same call that already reads the selling price at order time now also carries `vatCategory` and `kind`. No new route and no new allow-list entry: IM's inbound service allow-list (M1b) is not built yet, and when it is, this GET is already on SOP's list because SOP uses it for availability and price.

---

## 4. Use cases (U)

| # | Use case |
|---|---|
| UC-1 | **Create a product with its category.** An owner creates a stock Item and picks a category from the list GL allows for the Company. |
| UC-2 | **Create a service with its category.** An owner adds "Delivery" or "Consultation" as a service item: no stock fields, a category, optionally a price. |
| UC-3 | **Set the category on an old Item.** The items list shows "VAT category not set". The owner opens the Item, chooses a category, saves. No reason needed for the first set. |
| UC-4 | **Change a category.** REDUCED to STANDARD, with a reason; the history shows who, when, from, to, why. |
| UC-5 | **Order a line.** The user picks an Item (product or service). SOP reads it from IM, copies the category onto the line, WEB shows it read-only. |
| UC-6 | **The Item has no category.** SOP refuses the line, `409 item_has_no_vat_category`; WEB tells the user to set the category on the Item (and links to it). |
| UC-7 | **A one-off sales charge with no Item.** Refused (D6); WEB offers "add a service", which creates the service item and its category in one step. |
| UC-7b | **A purchase line for an Item.** POP reads the Item, copies its category onto the line; a typed category on such a line is refused `400`. |
| UC-7c | **A purchase line with no Item** (rent, utilities). The user states the category explicitly (D8); no IM call. |
| UC-7d | **The supplier charged something different.** Before the match the user corrects the unposted order's line through POP's set-category route (R25); after the match it is posted and GL holds the truth. |
| UC-8 | **The Item changes after ordering.** Placed lines keep their copy; a posted invoice reprints exactly as issued. |
| UC-9 | **GL refuses a category** (`vat_category_not_supported`) at posting: the order cannot post until the Item's category is corrected and the unposted line is re-read (D7). |
| UC-10 | **A machine tries to change a category.** POP's or SOP's service token gets `403`. |
| UC-11 | **Review history.** An owner or accountant reads why a category changed. |
| UC-12 | **A stock action on a service.** Receiving, issuing, counting or transferring a service item answers `409 item_is_service`. |
| UC-13 | **Old order from before SOP's fix.** SOP shows the category as "not recorded"; once invoiced it cannot be corrected, because GL holds the truth (SOP's own use case). |
| UC-14 | **Bulk (optional, Wave 6).** "Set all unset Items to X" with an explicit confirm, and a CSV column for opening stock (`docs/Opening_Figures_CSV_Upload_DDD_Design.md`). |

---

## 5. Tasks (T)

**IM (owner of the field and of service items)**
- T-IM-1 Migration `Vn__item_vat_category.sql` (next free number at build time, section 10, item 4): nullable `items.vat_category VARCHAR(20)` with a `CHECK` on the six values (nullable), plus table `item_vat_category_changes`.
- T-IM-2 Domain: `VatCategory` enum; `Item.vatCategory`; `setVatCategory(category, reason)` returning `ValidationResult`; the repository's `save()` must not clobber the column (R8).
- T-IM-3 Application and web: `SetItemVatCategoryUseCase` (Item and audit row atomically via `UnitOfWork`), history use case, `POST .../vat-category` under the per-Item lock and WRITE gate (service accounts refused), `GET .../vat-category-history`; `vatCategory` on `ItemResponseDto` and `CreateItemRequestDto`.
- T-IM-4 Tests first, red then green: domain; use case; end-to-end for every error code; contract test that the field is present, `null` on old Items, present in the embedded `item`; mutation checks on the reason rule and the service-account refusal; Postgres integration test on a database that already holds Items; a concurrency test (a receipt and a set at once never lose the category).
- T-IM-5 **Service items** (Wave 3): migration `Vm__item_kind.sql`: `kind VARCHAR(10) NOT NULL DEFAULT 'STOCK'`, `DROP NOT NULL` on `inventory_asset_account_id`, `cogs_expense_account_id`, `gl_stock_item_id`, and a `CHECK` that a `STOCK` row has all three; domain: `Item.createService(...)`; `requireStockItem()` guard on every stock route (R19) with the table-driven test; `kind` on the DTO with the three account fields nullable; exclusion of services from the low-stock monitor, velocity and inventory levels; optional `?kind=` filter.
- T-IM-6 Wave 5: `vat_category_required` on create, behind the same tests.
- T-IM-7 Operator sheet and error glossary updated in the same change as the code (`docs/IM_Playbook_Draft.md`, to be written).

**EA (decoder, ships first)**
- T-EA-1 `ImItemResponseDto`: add `vatCategory: String? = null`, `kind: String = "STOCK"`, and make the three account fields nullable; update `KtorImGatewayTest`'s copy field for field. EA's decoder rejects unknown keys by design, so this must be live **before** IM ships.
- T-EA-2 Inventory tile and counts: exclude `SERVICE` items (R20). Separately, EA's tile is already failing on a removed flat route (UAT finding 2); fix it in the same change so it is verified once against the new shape.

**WEB**
- T-WEB-1 Types first: `Item` gains `vatCategory: VatCategory | null`, `kind`, nullable account fields. No UI. Ships before IM.
- T-WEB-2 Wave 4: create-item form with a `kind` choice and the category select (options from GL's `vat-categories` route, so unsupported categories are never offered); items list badge and filter for "not set"; set/change dialog (reason when changing); read-only category on order lines; "add a service" inline (D6); stock valuation report excludes services; plain-words display of `item_has_no_vat_category` and `item_is_service`.
- T-WEB-3 Send `vatCategory` on create before Wave 5.

**SOP (their own work, listed for dependency)**
- T-SOP-1 Nullable `itemId` on `SalesOrderLine`, persisted category on the line (their V18), refuse a missing category on every path (agreed, in progress).
- T-SOP-2 At order time, read the Item (existing `GET items/{id}`, service login), copy `vatCategory` onto the line, refuse with `409 item_has_no_vat_category`; add `vatCategory` and `kind` to SOP's partial, tolerant DTO; decide stock behaviour from `kind == STOCK`, **not** from the presence of `itemId` (R21).
- T-SOP-3 Remove the typed per-line category once Wave 4 is live (R22); settle D7.

**POP**
- T-POP-1 At order time, for a line with an `itemId`, read the Item (`GET items/{id}`, service login, narrow tolerant DTO `{id, kind, vatCategory}`), copy the category onto the line, refuse a typed one with `400`; `503` when IM is unreachable; `409 item_has_no_vat_category` when the Item has none (R23, R26).
- T-POP-2 Derive `itemType` from `kind` at entry: a `SERVICE` item forces `itemType` `SERVICE`, no new column (R21). A line is stock only when `itemType` is GOODS **and** `kind` is `STOCK`. IM refuses receipts for a service item, so no service line can reach GRNI by mistake.
- T-POP-3 Keep the set-category route for unposted orders (R25) and the explicit category on lines without an Item (R24). Not removed with SOP's transition.
- T-POP-4 Verify POP's IM decoder against a real response (CM already assigned this; POP reports the decode fix is live). POP estimates about 3 days after approval.

**GL**
- T-GL-1 None. GL stays the authority and computes the figure. Confirm WEB's Company Membership may read `vat-categories`.

**CM**
- T-CM-1 Deploy order (section 6), checking EA's decoder is live before IM's image. No terraform, no secrets, no new allow-list entry.
- T-CM-2 Migration number gate: IM has several migrations queued (VAT, kind, receipt idempotency from the GRNI half, M2); only one takes each number.

---

## 6. Dependency order (O)

Foundations first, then consumers, then the producer, then the UI, then enforcement.

| Wave | What | Who | Gate to start |
|---|---|---|---|
| W0 | Playbook and D1 to D7 approved | Femi (via CM) | none |
| W1 | **Consumers declare the new fields** (optional, nullable, tolerant) | EA T-EA-1, WEB T-WEB-1, SOP T-SOP-2 (DTO fields only), **POP** (declares its narrow `{id, kind, vatCategory}` DTO and contract test) | W0. **Must be deployed and verified before W2 ships** |
| W2 | **IM ships** `vatCategory`, the optional create field, the set and history routes. **Recommended: ship the `kind` and nullable-account shape in the same wave as the field** (see "Smallest first slice" below) so EA and WEB declare everything once | IM T-IM-1 to T-IM-4 | W1 live in production |
| W3 | **IM ships service items** and the stock-route guards | IM T-IM-5 | W2 live |
| W4 | WEB UI; SOP reads and copies at order time, refuses a missing category; POP's stock rule uses `kind` | WEB T-WEB-2/3, SOP T-SOP-2/3, **POP T-POP-1 to T-POP-3 (read at order time after W2, `kind` rule after W3)** | W2 live for stock items, W3 live for services |
| W5 | IM makes the category **required** at creation | IM T-IM-6 | W4's create forms send it |
| W6 | Optional: bulk set, CSV column | IM/WEB | Femi's call |

**Smallest first slice (v4, 2026-10-14), for the WEB tidy-up that stops asking the user for a category:**
- **Slice A, the answer for products:** `Item.vatCategory` stored, returned on every item response and set by a person with an audit trail (T-IM-1 to T-IM-4). About **1.5 days** of IM work. WEB can then stop asking for any line whose item has an answer, and must refuse lines whose item has none (R28).
- **Slice B, the answer for services:** service items (`kind`, nullable stock fields, stock-route guards, reports exclude services; T-IM-5). About **2 to 3 days** more. Until B ships a service is not an item and a service line still has nowhere to take a category from, so WEB cannot fully stop asking until B.
- **Consumers first (W1), once, covering both slices:** EA declares `vatCategory`, `kind` and the three nullable account fields in one change (about 0.5 day); WEB types (about 0.25 day); SOP and POP declare `vatCategory` and `kind` in their narrow tolerant DTOs. Doing W1 once for A and B saves a second strict-decoder rollout.
- **Reading it at order time** (SOP about 0.5 day, POP about 3 days) follows W2 and W3 as in W4.
- **Ordering against the receipt retry-safety work (A0):** A0 was first because idempotency comes before money features. The VAT category is data, not a posting, and Femi has made it the critical path of the WEB tidy-up, so I recommend **slice A, then A0, then slice B** (CM's call).

**Why two directions.** IM *responds* with new fields (decoders must accept them first: EA strictly, SOP and POP tolerate) and IM *accepts* a new field on create (IM must accept it before WEB sends it, since IM's server decoder also rejects unknown keys). So: decoders first, then IM, then senders, then enforcement.

**Why W1 cannot be skipped.** This is the failure class of 2026-09-29: a peer's response gains a field and a strict decoder throws on a live request. Here the peer is IM and the strict consumer is EA. Making three EA fields nullable is the same class and needs the same care.

**Why services are a separate wave from the field.** The category alone is small and unblocks SOP's read for stock items. Service items touch many routes and the response shape; shipping them separately keeps each rollback simple.

---

## 7. Migration and safety on the live IM database

- IM's database already holds Items (legacy test data, treated carefully). All changes are **additive or relaxing**: `ADD COLUMN vat_category VARCHAR(20)` with no default and no `NOT NULL`; `ADD COLUMN kind VARCHAR(10) NOT NULL DEFAULT 'STOCK'`; `DROP NOT NULL` on three columns. On Postgres 16 each is a metadata change with no table rewrite and no long lock. The `kind` default is a fact (every existing row is stock), not a guess.
- A `CHECK` on `vat_category` (six names, nullable) and a `CHECK` that a `STOCK` row has its three stock fields: a bad value or an incomplete stock item cannot be stored even by a bug.
- A new table `item_vat_category_changes` (id, item_id foreign key, previous, new, reason, changed_by, changed_at, index on item_id).
- **No backfill of the category** (R4).
- **Rolling deploy.** Flyway migrates at start-up before the new task serves. An old task keeps running against the new schema and ignores `vat_category` and `kind`. **One real window for services:** an old task that reads a `SERVICE` row would meet nulls in columns it treats as non-null. So no service item may be created until every IM task runs the new code (a few minutes at deploy; CM confirms before W3 is used). Rolling the image back after service items exist is **not** safe for those rows; roll forward.
- **Verify** with a Postgres integration test that starts from a database already containing Items, and check each migration's number against IM's other queued branches before merge.

---

## 8. Audit and who can change

- **Who:** a human with WRITE at the Company. Service accounts refused. The first set needs no reason; any later change does.
- **What is kept:** previous value, new value, reason, `changedBy` (the caller's email, the only identity IM holds), `changedAt`, in the same transaction as the item update. Retained as long as the Item.
- **Limits, stated plainly:** IM has no EA user id, only email; there is no approval step (a second person confirming a tax-affecting change); the audit is not yet shown in Omniview or EA. Deliberate omissions for v1, to be revisited with the RBAC SPUTO.

---

## 9. Acceptance checks per wave

- **W1:** EA decodes a real IM item response containing `vatCategory`, `kind` and nullable account fields; WEB type-checks; SOP's DTO carries the fields; all deployed; EA's inventory tile loads against production IM.
- **W2:** every error in section 3 returned correctly; an old Item returns `vatCategory: null`; a set under concurrent stock movement never loses the value; migration passes on a database that already has Items; POP and SOP calls to IM unchanged.
- **W3:** a service item can be created and read at `GET items/{id}`; **every** stock route refuses it with `409 item_is_service` (table-driven); stock reports exclude it; an old stock Item is unchanged.
- **W4:** an order line for an Item copies the category and WEB shows it read-only; an Item with no category blocks the line with the plain-words message; changing the Item afterwards leaves a placed line untouched; a one-off charge goes through "add a service"; GL refusing a category blocks posting with a clear message.
- **W5:** creating an Item without a category answers `400 vat_category_required`; WEB's forms never trigger it.

---

## 10. Risks and things nobody asked (candid)

1. **A product-only category cannot express some real VAT.** Exports (zero-rated even though the product is normally standard), reverse charge, and mixed supplies depend on the *transaction*, not the product. Femi's rule (nobody types it on a line) means v2 cannot represent them; the workarounds are a separate Item ("Sugar, export") or a later, tightly controlled transaction-level override. Not decided here; flagged to CM.
2. **Purchases (answered by POP and CM).** Purchase lines with an Item read-and-copy (R23); lines without keep an explicit category (R24, D8); POP's correction route stays (R25). The remaining risk is that purchases keep a typed category where sales has none; it is deliberate, because input VAT is what the supplier charged, and it needs Femi's confirmation through D8.
3. **EA's strict decoder (high).** If IM ships a new field or a null account before EA declares it, every EA call that decodes an IM item throws. W1 exists for this. EA's tile is *already* failing on a removed route, so verify EA end to end, not only its unit test.
4. **Migration numbers.** IM has VAT, kind, receipt-idempotency (seam A) and the M2 child-table work queued. Only one can take each number; IM has hit this before (V3/V4). CM gates it; build order fixes the sequence.
5. **Lost update.** `ItemRepository.save()` writes the whole row. Without the per-Item lock a receipt could write a stale category back and the audit would say it changed. This is why the set route takes the lock.
6. **VAT registration is a Company fact, not a product fact.** A Company that is not VAT-registered should not charge VAT whatever the category. Nobody owns "is this Company VAT-registered" yet. For GL and EA.
7. **Services leak into stock figures if one place is missed.** The stock valuation report, the low-stock monitor, EA's counts, stock velocity and inventory levels all read Items and assume stock. R19 and R20 list them; the table-driven route test and a report test are the guard. This is the most likely source of bugs in W3.
8. **"Has an itemId means stock" is now false** (R21). POP's GRNI plan and SOP's goods-issue decision both used it. Both must switch to `kind`. A service line that reached goods issue would be a real error, so IM also refuses it (R19).
9. **POP's IM decoder.** CM confirmed my earlier finding was real; POP now decodes only what it needs. Independent of this work.
10. **Wrong category means wrong tax.** Mitigations: the reason, the audit and the write gate. No second-person approval in v1.
11. **Wire change reaches embedded responses.** Receipts, issues and adjustments embed the item, so their responses gain the fields too (R9).
12. **POP now depends on IM being up at order time** for any line with an `itemId` (R26): an IM outage turns a purchase order into a `503` until it returns. Deliberate (never a default category); worth knowing for the Tenant's administrator (Prodeo is a landlord with no role in a Tenant's data, so there is no "Prodeo support" step in this flow).
13. **SOP built the typed per-line category and has not released it.** It is the transition path until W4 (R22); removing it is a tracked task so two sources of truth do not live on.

---

## 11. What I am not claiming

I do not know which of anyone's products or services are vatable, and IM holds no VAT data today. This playbook decides where the answer is stored, who may record it, and how a line copies it, not what the answer is.
