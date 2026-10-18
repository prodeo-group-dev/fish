# Product VAT category, v5: by Tax Jurisdiction and date (IM)

**Status: DRAFT for Femi, 2026-10-17, IM session. Docs only. Nothing here is built.** It amends `IM_Product_VAT_Category_SPUTO.md` (v4). It answers the instruction in `Pending_For_Sessions_2026-10-15.md`: say how slice A, which stores ONE category per product, extends to "the category depends on the Tax Jurisdiction and the Fiscal Year and Accounting Period" **without a rewrite**.

**Source (Femi, 2026-10-15, Decisions Log):** "VAT is determined by product or service VAT Category. IM is incharge of this. It depends on the Tax Jurisdiction and the Fiscal Year and Accounting Period." CM's reading, which this note follows: IM resolves a product's category for (the Company's Tax Jurisdiction, the transaction date); the RATE behind a category stays GL's, per jurisdiction and period; the line freezes the answer.

## 1. The answer: slice A extends, it does not get rewritten

Slice A (`feat/im-vat-category-a`, V10) stores:

| Piece | Shape today |
|---|---|
| `items.vat_category` | one nullable value per product (six GL names, null = no answer yet) |
| `item_vat_category_changes` | audit rows: previous, new, reason, who, when |
| `ItemResponseDto.vatCategory` | the one value |
| `POST /items/{id}/vat-category` | `{vatCategory, reason?}` |
| `GET /items/{id}/vat-category-history` | the audit trail |

v5 adds ONE table and three optional inputs. Nothing already shipped changes meaning:

1. **New table (V11, additive):** `item_vat_category_entries (item_id, jurisdiction, effective_from DATE, category, created_at, created_by)`, primary key `(item_id, jurisdiction, effective_from)`, same CHECK on the six names. This is the new source of truth for "what applies when".
2. **Backfill, one statement, no guessing:** every product that already has an answer gets one entry with `effective_from = 0001-01-01` ("since forever") for its Company's jurisdiction. That is exactly what slice A already says (one value, valid on any date), so no past answer changes. Products with no answer get no entry and stay refused.
3. **`vatCategory` on the item response keeps its name and type** and now means "the category in force TODAY for this Company's jurisdiction". Every consumer written against slice A keeps working unchanged.
4. **`GET /items/{id}?asOf=YYYY-MM-DD` (new, optional):** returns `vatCategory` for that date. SOP and POP pass the transaction date when they read at order time; callers that do not pass it get today. A new additive field `vatCategoryEntries` (the timeline) may be added later, consumer-first as always.
5. **`POST /items/{id}/vat-category` gains optional `effectiveFrom` (default today) and `jurisdiction` (default: the Company's).** Without them it behaves exactly as slice A does. The audit row stays: it records the decision (who, why, from what to what); the entries table records when it applies.
6. **`items.vat_category`** stays during the transition as "today's answer", written in the same transaction as the entry, so a rolling deploy (old and new tasks together) never disagrees. Dropped by a later migration once no consumer reads it.

The one thing that WOULD have forced a rewrite is making `vatCategory` a required or non-nullable field on the wire, or having consumers freeze "the product's category" with no date. Slice A does neither: the field is nullable, and the line's frozen copy (SOP's and POP's own) is a plain value that does not care how IM arrived at it.

## 2. Lookup, and what happens when nothing covers the date

- Lookup = `(item, the Company's Tax Jurisdiction, the transaction date)`: the entry with the greatest `effective_from <= date`. The fiscal year and accounting period follow from the date (GL owns the calendar); IM stores dates, not periods, so a period change never needs an IM change.
- **No covering entry = refused, never defaulted:** `409 item_has_no_vat_category`, with the date in the plain-words message ("This product has no VAT answer for 3 March 2026 in Ireland. Set it on the item first."). Same rule as D4.
- A sale or purchase line freezes the answer at order time; later entries never touch a line already ordered, so a posted invoice reprints exactly as issued.

## 3. What this needs from other sessions (nothing starts without Femi)

| Who | What |
|---|---|
| GL | Confirm the rate tables are per jurisdiction and period (Pending asks this). Confirm that `vat_category_not_supported` stays GL's refusal at posting. |
| EA or GL | **Who knows a Company's Tax Jurisdiction?** IM does not hold it. Recommended: GL (it holds the per-jurisdiction tax settings), exposed on the posting context IM already reads. This is the one real dependency; it does not block slice A. |
| SOP, POP | Pass the transaction date when reading an item (`?asOf=`); until then they get today's answer, which is correct for same-day sales. |
| WEB | Read-only display of the answer in force; the set dialog gains an optional "applies from" date later. |

## 4. Questions for Femi (each has a recommendation; none is decided)

1. **Back-dating.** May an owner or accountant set an `effectiveFrom` in the past? Recommendation: only to the start of the current open Period (an earlier date would reclassify a closed period), never so as to alter a posted line.
2. **Future dates.** Allowed (a law that starts on 1 July can be entered in June)? Recommendation: yes. That is the reason for building it.
3. **Date or period?** Recommendation: store dates. The period is derived by GL, so IM never has to know when a Period opens or closes.
4. **Jurisdiction source** (section 3). Recommendation: GL.

## 5. Order

Slice A ships as it is (it is the first row of the timeline). v5 is its own slice after slice B only if Femi wants it sooner; it needs the jurisdiction source (section 3) first. Estimated IM work: about 1.5 days for the table, backfill, `asOf` read and the optional inputs, plus tests (a Postgres migration test on a database that already holds slice A data).
