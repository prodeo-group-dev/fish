# Product VAT category, owned by IM: SPUTO / Playbook

**Status: DRAFT for Femi's approval, 2026-10-11, IM session. Planning only. Nothing is built, nothing is deployed, and no code starts until Femi approves this playbook.**

**Source of the requirement.** Femi, relayed by CM on 2026-10-10: *"it is the product that determines whether it's vatable or not"*, and IM, as owner of the product, must determine it. Process rule (also Femi, via CM): *"SPUTO gives them the Playbook to build against"*. This document is that Playbook for IM, SOP, POP, WEB, EA and CM.

**Written from.** IM master `cf97150` (task definition `:32`), GL `vat_category.kt` and `VatCategoriesRoutes.kt`, POP `purchase_order_line.kt`/`ktor_im_gateway.kt`, SOP `sales_order_line.kt` plus SOP's own replies today, EA `im_dtos.kt`, WEB `src/api/im.ts` and `ImItemsList.tsx`, and `docs/IE/IE_VAT_MVP_Design.md`. Every claim marked "checked" was read in code today. Anything I could not verify is listed in section 10 and says so.

---

## 0. In one paragraph

Today an IM `Item` has no VAT information. The category is typed on each order line in POP and SOP. This playbook makes the **product** carry it: `Item.vatCategory`, one of the six GL values, set by the owner (never defaulted), editable with a reason and an audit trail. WEB reads it from IM's item response and **pre-fills** the order line (visible, overridable). The line stores the category it was ordered with, so a later change to the product never alters an order already placed, and GL keeps deciding which categories a country allows. POP and SOP make no new call to IM. The one dangerous part is shipping order: **EA's decoder fails closed on an unknown field**, so consumers declare the field before IM ships it.

---

## 1. Scope (S)

**In scope**
1. `vatCategory` on the IM `Item`: stored, returned in every item response, set at creation, set or changed afterwards by a human with write access, with an audit trail.
2. A rule for every existing Item: nothing is defaulted. They start as "not set" and the owner sets them.
3. How WEB, SOP and POP use it (pre-fill at entry, line-stored value, item-less lines choose explicitly).
4. The wire contract and the order in which services ship it.
5. Migration safety on the live IM database.

**Out of scope (noted, not decided here)**
- Which products are vatable or at which rate: that is the owner's legal decision, and GL's rate schedule decides the percentage. IM never computes VAT.
- Whether a Company is VAT-registered at all (a Company-level fact, see section 10, item 5).
- Partial-exemption input-VAT apportionment and price-inclusive pricing (GL has already deferred both).
- A "stocked vs service" flag on Item (decision D5: not now).
- SOP's own fixes (explicit category on every path, persisting it, nullable `itemId`): SOP's work, listed here only where this playbook depends on it.

**This amends one earlier decision, and says so.** `docs/IE/IE_VAT_MVP_Design.md` (2026-09-13) put the category on the transaction line, not on the Item master, because `SalesOrderLine` had no item link and `PurchaseOrderLine.itemId` is often absent. That document already said an Item-level category is "a legitimate later UX convenience" provided the line "always stores what actually applied". This playbook keeps that rule exactly. Only the **source of the default** moves to the product.

---

## 2. Plan / requirements (P)

| # | Requirement |
|---|---|
| R1 | `Item.vatCategory` is one of exactly `STANDARD`, `REDUCED`, `SECOND_REDUCED`, `SUPER_REDUCED`, `ZERO_RATED`, `EXEMPT`: the identical names GL, POP and SOP use. No mapping layer. |
| R2 | `null` means "not set yet". It never means exempt or zero-rated, and nothing treats it as a default. |
| R3 | An Item is created **with** a category once enforcement is on (Wave 4). Before that the field is accepted but optional. |
| R4 | Existing Items are not backfilled. They stay `null` until a human sets them. |
| R5 | Setting or changing the category needs a human with WRITE at the Company. Service accounts (POP, SOP tokens) are refused. |
| R6 | Changing a category that is already set requires a non-blank `reason`. The first set does not. |
| R7 | Every set or change writes an audit row in the same transaction as the item update: previous value, new value, reason, who (email), when. |
| R8 | The set route runs under the same per-Item lock as the other Item writes, so a concurrent stock movement cannot write a stale category back over it. |
| R9 | Item responses (list, single, and the `item` embedded in goods receipt/issue/adjustment responses) gain `vatCategory: String?`. |
| R10 | IM validates only the six names. GL stays the authority on what a Company's country supports and answers `vat_category_not_supported` at posting. |
| R11 | POP and SOP make **no** new service-to-service call and need **no** new allow-list entry. WEB pre-fills; the line carries the value. |
| R12 | A line stores the category at the time of ordering. A later Item change never alters placed lines. Only the existing set-line-category routes correct a line, and only before posting or match. |
| R13 | A line with no item (service, free text) chooses its category explicitly. A line whose Item has no category forces an explicit choice and offers to save it to the product. |
| R14 | No path anywhere may silently default a category. Missing means refused. |
| R15 | The migration is additive and safe on the live shared database (section 7). |
| R16 | Contract changes ship consumer-first (section 6). IM does not ship the response field until EA and WEB have deployed decoders that declare it. |

### Decisions for Femi (each has a recommendation; none is made without you)

| # | Question | Recommendation |
|---|---|---|
| D1 | Required at creation, or optional forever? | Required, in two steps: accepted-but-optional first (Wave 2), enforced as `vat_category_required` once WEB's create form sends it (Wave 4). "Not set" then exists only for Items created before. |
| D2 | Who may change a category? | Any human with WRITE at the Company today (same gate as creating an Item and the selling price), service accounts refused, a reason required to change. RBAC changes are frozen until the RBAC SPUTO lands; when it does, "change VAT category" should become its own capability for accountants/owners, not every writer. |
| D3 | Check the category against the Company's country at set time? | No, not in v1. WEB offers only the categories GL lists for the Company (`GET /companies/{companyId}/vat-categories`). GL refuses an unsupported one at posting. Having IM call GL for a convenience check adds a service-to-service dependency and an allow-list entry for little gain. |
| D4 | How do owners fix the old Items? | One at a time with a "VAT category not set" badge and filter (Wave 3). Optional later (Wave 5): a bulk "set all unset Items to X" that the owner must confirm, which is an explicit act, not a silent default. |
| D5 | A stocked-vs-service flag on Item? | None now. Checked: every IM Item is stock by construction (it requires an inventory asset account, a valuation method and a GL stock item), so POP's planned rule "a line with an `itemId` is a STOCK line" is true today. If services are ever to be Items, add an explicit `kind` first, and before that rule ships. |
| D6 | Confirm the amendment to the 2026-09-13 decision above. | Recorded as instructed; Femi to confirm. |

---

## 3. Wire contract

All routes are Company-scoped under `/api/companies/{companyId}`, as today.

**`ItemResponseDto` gains one field**

```json
{ "id": "…", "description": "Sugar 50kg", "…": "…existing fields…", "sellingPriceAmount": "55.00", "vatCategory": "ZERO_RATED" }
```
`vatCategory` is `null` when not set. Because the same DTO is embedded as `item` in the goods receipt, goods issue and adjustment responses, those gain it too.

**Create** (`POST /items`): `vatCategory` optional in Wave 2, required in Wave 4 (`400 vat_category_required`). Invalid value: `400 invalid_vat_category`.

**Set or change** (new): `POST /items/{id}/vat-category`

```json
{ "vatCategory": "STANDARD", "reason": "Reclassified after accountant review" }
```
- `200` with the updated `ItemResponseDto`. Same value as already stored: `200`, no audit row.
- `400 invalid_vat_category`: not one of the six (detail lists them).
- `400 reason_required`: the Item already has a category and `reason` is blank.
- `403 forbidden`: no WRITE at the Company, or a service-account caller.
- `404`: item missing or belongs to another Company (identical, as everywhere in IM).
- `409 item_busy`: another stock movement for this Item is in progress; nothing changed, retry is safe.

**History** (new, read access): `GET /items/{id}/vat-category-history`

```json
{ "changes": [ { "changedAt": "2026-10-11T09:12:00Z", "changedBy": "owner@example.com", "previous": "STANDARD", "new": "REDUCED", "reason": "Reclassified…" } ] }
```
Newest first. `previous` is `null` for the first set.

**Nothing else changes.** No new route is needed to read the category: WEB already lists Items.

---

## 4. Use cases (U)

| # | Use case |
|---|---|
| UC-1 | **Create a product with its category.** An owner creates an Item and picks a category from the list GL allows for the Company. |
| UC-2 | **Set the category on an old Item.** The items list shows "VAT category not set". The owner opens the Item, chooses a category, saves. No reason is needed for the first set. |
| UC-3 | **Change a category.** The owner changes REDUCED to STANDARD, must give a reason, and the history shows who, when, from, to, why. |
| UC-4 | **Order line for a known product (POP and SOP).** WEB pre-fills the line's category from the Item. The user sees it and may override it. The line stores what the user submitted. |
| UC-5 | **Product has no category yet.** WEB makes the user choose and offers "also save to product" (calls UC-2). Nothing is guessed. |
| UC-6 | **Free-text or service line, no item.** The user chooses explicitly. |
| UC-7 | **Product changes after ordering.** Lines already placed keep their stored category. Only a line's own correction route (POP set-line-category, SOP's equivalent) changes it, and only before posting or match. |
| UC-8 | **GL refuses a category.** `vat_category_not_supported` on posting: the user corrects the line through the line route. The product itself is not touched. |
| UC-9 | **A machine tries to change a category.** POP's or SOP's service token gets `403`. |
| UC-10 | **Review history.** An owner or accountant reads why a category changed. |
| UC-11 | **Old order from before SOP's fix.** SOP shows the category as "not recorded"; once invoiced it cannot be corrected, because GL holds the truth (SOP's own use case g). |
| UC-12 | **Bulk (optional, Wave 5).** "Set all unset Items to X" with an explicit confirm, and a CSV column for opening stock (`docs/Opening_Figures_CSV_Upload_DDD_Design.md`). |

---

## 5. Tasks (T)

**IM (owner of the field)**
- T-IM-1 Migration `V10__item_vat_category.sql` (check the next free number at build time, see section 10, item 3): nullable `items.vat_category VARCHAR(20)` with a `CHECK` on the six values (nullable), plus table `item_vat_category_changes`.
- T-IM-2 Domain: `Item.vatCategory` (nullable), `setVatCategory(category, reason)` returning `ValidationResult` (reason rule), enum `VatCategory` with the six names. The repository's `save()` must not clobber the column (R8).
- T-IM-3 Application: `SetItemVatCategoryUseCase` (writes Item and audit row atomically via `UnitOfWork`), `GetItemVatCategoryHistoryUseCase`; `CreateItemUseCase` accepts the optional field.
- T-IM-4 Web: `POST /items/{id}/vat-category` under the per-Item lock and WRITE gate, refusing service accounts; `GET .../vat-category-history`; `vatCategory` on `ItemResponseDto` and `CreateItemRequestDto`.
- T-IM-5 Tests first, red then green: domain; use case; end-to-end for every error code above; contract test that the field is present, `null` on old Items, and present in the embedded `item`; mutation check on the reason rule and the service-account refusal; Postgres integration test for the migration on a database that already holds Items (see section 7); concurrency test (a receipt and a set at once never loses the category).
- T-IM-6 Wave 4: `vat_category_required` on create, behind the same tests.
- T-IM-7 Operator sheet and error glossary updated in the same change as the code (`docs/IM_Playbook_Draft.md`, to be written).

**EA (decoder, ships first)**
- T-EA-1 `ImItemResponseDto`: add `vatCategory: String? = null` and update `KtorImGatewayTest`'s copy field for field. EA's decoder rejects unknown keys by design, so this must be live **before** IM ships.
- T-EA-2 Separate, already known: EA's inventory dashboard tile calls IM's removed flat `GET /api/items` (UAT finding 2). Fix it with the Company id, ideally in the same EA change so the tile is verified once against a response that carries the new field.

**WEB (types first, then UI)**
- T-WEB-1 `Item` type gains `vatCategory: VatCategory | null`, and a `VatCategory` union of the six names. No UI yet. Ships before IM.
- T-WEB-2 Wave 3: create-item form select; items list badge and filter for "not set"; set/change dialog (reason field shown when changing); order-line pre-fill in POP and SOP forms with "also save to product"; options come from GL's `vat-categories` route so unsupported categories are never offered; reload the Item list when an order form opens.
- T-WEB-3 Send `vatCategory` on create (before Wave 4).
- T-WEB-4 Account for the idempotency-key-in-page-memory weakness noted separately (unrelated, but the same screens).

**POP**
- T-POP-1 No wire change needed. Keep `missing_vat_category` and the set-line-category route. Confirm the item-less line rule (R13).
- T-POP-2 Verify (not assume) the risk in section 10, item 2.

**SOP** (their own work, listed for dependency)
- T-SOP-1 Nullable `itemId` (string, IM item UUID, informational) on `SalesOrderLine`; persist the category on the line (their V18); refuse a missing category on every path (including `POST /api/record-sale`, which SOP reports silently posts ZERO_RATED today, and `POST /api/sales-orders`). SOP confirmed all of this today.

**GL**
- T-GL-1 None. GL stays the authority. Confirm WEB's Company Membership may read `vat-categories` (it is read-only reference data behind `authorizeTenantForRead`).

**CM**
- T-CM-1 Deploy order (section 6), checking EA's decoder is live before IM's image. No terraform, no secrets, no new allow-list entry.
- T-CM-2 Migration number gate: only one of IM's branches may take `V10` (section 10, item 3).

---

## 6. Dependency order (O)

Foundations first, then consumers, then the producer, then the UI, then enforcement.

| Wave | What | Who | Gate to start |
|---|---|---|---|
| W0 | Playbook and D1 to D6 approved | Femi | none |
| W1 | **Consumers declare the field (optional, default null)** | EA T-EA-1, WEB T-WEB-1 | W0. **Must be deployed and verified before W2 ships** |
| W2 | **IM ships** the field, the optional create field, the set route and the history route | IM T-IM-1 to T-IM-5 | W1 live in production |
| W3 | WEB UI, line pre-fill, "also save to product" | WEB T-WEB-2/3 | W2 live |
| W4 | IM makes the category **required** at creation | IM T-IM-6 | W3's create form sends it |
| W5 | Optional: bulk set, CSV column, a `kind` flag if D5 changes | IM/WEB | Femi's call |

**Why two directions.** IM *responds* with the new field (so decoders must accept it first: EA strictly, SOP and POP tolerate it) and IM *accepts* the new field on create (so IM must accept it before WEB sends it, since IM's server decoder also rejects unknown keys). So: decoders first, then IM, then senders, then enforcement.

**Why W1 cannot be skipped.** This is the exact failure class of 2026-09-29: EA, SOP, POP and GL each mirror a peer's response, a new field arrives unannounced, and a strict decoder throws on a live request. Here the peer is IM and the strict consumer is EA.

---

## 7. Migration and safety on the live IM database

- IM's database already holds Items (legacy test data, but treated carefully). The change is **additive**: `ALTER TABLE items ADD COLUMN vat_category VARCHAR(20)` with no default and no `NOT NULL`. On Postgres 16 this is a metadata change, with no table rewrite and no long lock.
- A new table `item_vat_category_changes` (id, item_id foreign key, previous, new, reason, changed_by, changed_at, index on item_id).
- **No backfill, no default.** Existing rows are `null` (R4).
- **Rolling deploy is safe both ways.** Flyway runs at start-up before the new task serves. The old task keeps running against the new schema (Exposed selects named columns, so the extra column is invisible to it). Rolling the image back leaves the column in place, harmless.
- **The `CHECK` constraint** lists the six names and allows `null`; a bad value cannot be stored even by a bug.
- **Verify** with a Postgres integration test that starts from a database already containing Items (not only an empty one), and check the new migration's number against any other IM branch before merge.

---

## 8. Audit and who can change

- **Who:** a human with WRITE at the Company. Service accounts refused. The first set needs no reason; any later change does.
- **What is kept:** previous value, new value, reason, `changedBy` (the caller's email, the only identity IM holds), `changedAt`, in the same transaction as the item update. Retained as long as the Item.
- **Limits, stated plainly:** IM has no EA user id, only email; there is no approval step (a second person confirming a tax-affecting change); and the audit is not yet shown in Omniview or EA. All three are deliberate omissions for v1, to be revisited with the RBAC SPUTO.

---

## 9. Acceptance checks per wave

- **W1:** EA's unit test decodes a real IM item response that includes `vatCategory`; WEB type-checks; both deployed; EA's inventory tile loads against production IM.
- **W2:** every error in section 3 returned correctly; an old Item returns `vatCategory: null`; setting under concurrent stock movement never loses the value; migration passes on a database that already has Items; POP and SOP calls to IM unchanged.
- **W3:** an owner creates a product with a category, sets an old one, changes one with a reason, sees the history; a POP and a SOP line pre-fill; an Item with no category forces a choice; a category GL refuses is corrected on the line.
- **W4:** creating an Item without a category answers `400 vat_category_required`; WEB's form never triggers it.

---

## 10. Risks and things nobody asked (candid)

1. **EA's strict decoder (high).** If IM ships before EA, every EA call that decodes an IM item throws. The wave order exists for this. EA's tile is *already* failing on a removed route, so verify EA end to end, not only its unit test.
2. **POP's IM decoder may already be wrong (unverified).** POP's IM gateway decodes IM's goods receipt/issue response with Ktor's default JSON into a one-field `ItemResponseDto(id)`, while IM returns the whole item (twenty-odd fields). POP's own tests feed it a one-field stub, so tests cannot catch this. I believe default Ktor JSON rejects unknown keys, in which case POP's call fails *after* IM has already posted; I have not run it. The last seven days of POP logs show no such calls, so it has never been exercised in production. It is independent of this work (adding `vatCategory` makes it neither better nor worse), but POP should test it against a real IM response before relying on it. SOP's client is explicitly tolerant, so SOP is not affected.
3. **Migration number clash.** I planned `V10` for the Company-scoped child-table work (M2). This playbook also needs a migration. Only one may be `V10`; the other becomes `V11`. IM has hit this before (V3/V4). CM gates it.
4. **Lost update.** `ItemRepository.save()` writes the whole row. Without the per-Item lock (R8) a receipt could write a stale category back and the audit would say it changed. This is why the set route takes the lock.
5. **VAT registration is a Company fact, not a product fact.** A Company that is not VAT-registered should not charge VAT whatever the product category. GL's `vatScheduleConfigured` covers countries with no verified rates, not registration status. Nobody owns "is this Company VAT-registered" yet. Not solved here; for GL and EA.
6. **Wrong category means wrong tax.** The mitigations are the reason, the audit and the write gate. There is no second-person approval in v1.
7. **Stale pre-fill.** If WEB holds an old Item list, a line pre-fills the older category. The line stores what the user saw, which is correct and auditable; WEB should reload the list when an order form opens.
8. **One category per product.** A bundle with mixed rates is separate lines, not one Item.
9. **Wire change reaches embedded responses.** Receipts, issues and adjustments embed the item, so their responses gain the field too (R9).

---

## 11. What I am not claiming

I do not know which of anyone's products are vatable, and IM holds no VAT data today. This playbook decides where the answer is stored and who may record it, not what the answer is.
