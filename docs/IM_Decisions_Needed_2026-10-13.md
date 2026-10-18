# IM: decisions Femi needs to make (2026-10-13)

From the Inventory Management (IM) session. One place to look for the IM-owned decisions in the two Playbooks. Nothing is built until these are answered. Each has a recommendation. Checked against `docs/Decisions_Log.md` on 2026-10-13: none of these is answered there yet. When Femi answers, the session he tells appends a line to the Decisions Log.

## Update 2026-10-17 (IM): what Femi has answered since this was written

Source: `docs/Decisions_Log.md`, 2026-10-14 and 2026-10-15. Do not ask these again.

- **D2 answered (2026-10-14):** only the Owner Admin or an accountant may change a product's VAT category, audited. Built in slice A. The recommendation in row 2 below is superseded.
- **D11 answered (2026-10-14):** keep the six values; EXEMPT also covers out of scope.
- **"No answer yet" is refused at sale and purchase time (2026-10-14):** `409 item_has_no_vat_category`, never defaulted.
- **Order answered (2026-10-14):** slice A, then receipt retry-safety (A0), then slice B (service items).
- **D10 answered YES (2026-10-15), in a larger form:** the category depends on the Tax Jurisdiction and the date, so entries are effective-dated. Row 8 below ("not for now") is superseded. Design in `IM_Product_VAT_Category_v5_Extension_Note.md`, four small questions in it for Femi.
- **Still open, IM asks Femi in plain words:** D1 (required at creation), D6 to D9, and seam A D-I1 to D-I3. New: the Inventory valuation rounding (option A, B or C) in `TestResultsResponses/IM_Response_to_RT-5_Supplier_Tile_2026-10-15.md`.

## A. Product VAT category (`docs/IM_Product_VAT_Category_SPUTO.md`, v3)

Already decided and **not** asked again (Decisions Log, 2026-10-11): IM owns the category for every product and service, services are IM items, the line holds a frozen copy, nobody types it, SOP reads it, GL computes the figure.

| # | Decision | Recommendation |
|---|---|---|
| 1 (D1) | Must a new product or service have a VAT category when it is created? | Yes, in two steps (accepted first, required once WEB sends it), so nothing breaks. |
| 2 (D2) | Who may change a category? | Any person with write access today, with a reason and a history trail. Later: accountants and owners only, when the permissions work lands. |
| 3 (D4) | How are existing products fixed? | The owner sets them one by one; a "not set" badge shows which. Nothing is defaulted. Optional later: a confirmed "set all unset to X". |
| 4 (D6) | A **sales** line with no product (one-off charge). | Refuse it, and give WEB an "add a service" step that creates the service item and its category on the spot. |
| 5 (D7) | A wrong category copied onto an unposted **sales** line. | "Re-read from the item", not a typed correction. |
| 6 (D8) | A **purchase** line with no product (rent, utilities, a supplier's one-off service). | Do not refuse it: it keeps a typed category. Lines with a product copy it from IM. |
| 7 (D9) | Exports, reverse charge and other VAT that depends on the transaction, not the product. | Not supported on sales for MVP: use a separate product ("Sugar, export"). Purchases already have a correction route. A controlled override can come later. |
| 8 (new, D10) | Femi's 2026-10-13 answer that tax depends on country and period: should a product's category be able to change **from a future date**? | Not for now. A change applies immediately, every placed line keeps its frozen copy, and the owner changes it on the day the law changes. Effective-dated changes can come later. To be added to the Playbook if agreed. |

## B. Seam A, IM's half: the stock-purchase double count (`docs/POP_IM_GL_Purchase_Posting_Design_IM_Half.md`)

| # | Decision | Recommendation |
|---|---|---|
| 9 (D-I1) | A Company with no GRNI account: what happens to a goods receipt against an order? | Refuse it, never post it to Accounts Payable. Every test Company needs GL's standard accounts run first. |
| 10 (D-I2) | Order of work. | Make receipts safe to retry and atomic **first**, then change what they post. About 1.5 to 2 days, independent of GL and POP. **This is the only item that can start today.** |
| 11 (D-I3) | Receipts already posted before the change. | Record which account each receipt credited, so POP clears GRNI only against real GRNI receipts. No freeze needed. |

## C. Smaller, after seam A

| # | Decision | Size |
|---|---|---|
| 12 | A way to correct a wrongly entered receipt cost (UAT finding 7), as a revaluation with a reason and an approval. | About 1.5 days |
| 13 | A non-blocking "this cost is far from the last cost, are you sure?" warning on receive (needs WEB and EA to declare the field first). | About 0.5 day |

## Order IM proposes once approved

A0 receipt retry-safety (#10), then the VAT category field (#1 to #3), then GRNI (#9, #11), then service items (#4 onward).
