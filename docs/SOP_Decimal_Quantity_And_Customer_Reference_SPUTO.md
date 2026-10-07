# SOP: decimal line quantities and a customer reference / service period on the invoice: SPUTO

**Status: 2026-10-07, SOP session. Femi: "Yes, SPUTO decimal quantity and the PO reference field", then (via WEB) "Yes" to both builds. Decided policy below. The SPUTO is final; building on branch `feature/decimal-quantity-reference` in the SOP checkout.** Triggered by WEB's urgent question about raising service invoices (S1 time-based, S2 fixed-fee): hours are fractional and a customer PO number has nowhere to go.

## S: Scope and problem

A service invoice needs two things SOP cannot do today:

1. **Fractional quantities.** A line's quantity is a whole number end to end (JSON, domain, database column, PDF). 7.5 hours is refused. The only workaround (quantity 1, hours in the description) loses the quantity and rate on the invoice.
2. **A customer reference and service period.** There is no field for the customer's PO number or the period a service covers. Only a line's description reaches the invoice PDF.

**In scope:** decimal quantity on sale lines (credit and cash), a customer reference and an informational service period on the sale, shown on the invoice PDF and in the Sales list; one latent amount bug found on the way (F1).

**Out of scope (stays a separate future build):** anything that changes revenue recognition (deferred income, service-period accrual, contract assets, milestones, outcome-based or project revenue). The service period is **printed only**; the ledger posting, its date and its period do not use it. Return-request quantities stay whole numbers (returns are of goods in whole units; see Q3).

### Findings made while reading the code

- **F1 (latent amount bug).** For a stock-tracked line, `RecordOrdinarySaleUseCase` builds the order line from IM's selling price × the stock quantity (a total) but puts that total in the *unit price* slot and keeps the request's `quantity`, so the line amount is `total × quantity`. With quantity 1 (what WEB sends) it is right; with quantity 2 and stockQuantity 2 the invoice and the ledger would be double the price. Confirmed by reading the code and the existing tests: the one test that sells a stock line with quantity 10 never asserts the amount, and the test that asserts it uses quantity 1. Not reproduced against a running system. Fix with decimal quantity: for a stock line the invoiced quantity is the stock quantity and the unit price is IM's selling price, so `amount = quantity × unit price` is true by construction.
- **F2.** The sales-performance and returns-analytics reports sum line quantities as integers (`totalLineQuantity`); they must become decimals or they truncate.

## P: Plan (requirements)

| # | Requirement |
|---|---|
| R1 | A line quantity is a positive decimal with at most 4 decimal places (and a sane upper bound), stored exactly, never as a float. |
| R2 | **Backward compatible on the wire.** `quantity` stays a JSON number: integers keep working; a decimal number such as 7.5 is accepted; responses write a plain number without trailing zeros (`1`, `7.5`). Existing readers (WEB) need no change. |
| R3 | A line's amount is unit price × quantity, rounded once per line to the currency's minor units (`Money` already does this); the invoice total is the sum of the rounded line amounts; GL still receives per-line net amounts only (no GL change). |
| R4 | The invoice PDF prints the quantity without trailing zeros and the rounded line amount. |
| R5 | F1 is fixed: for a stock-tracked line, invoiced quantity = stock quantity, unit price = IM's selling price. Covered by a test with quantity greater than 1. |
| R6 | The two reports sum quantities as decimals (F2). |
| R7 | **Customer reference:** optional text on the sale (a PO or other customer-side reference), trimmed, at most 100 characters, no control characters. Printed on the invoice PDF ("Your reference: …"), returned in the Sales list item and `GET /sales-orders/{id}`. |
| R8 | **Service period:** optional from and to dates (inclusive), `from` not after `to`, both or neither. Informational only (see Scope); printed on the PDF ("Service period: … to …") and returned with the order. |
| R9 | Both new fields are optional on `POST /api/sales` for credit and cash sales; omitting them changes nothing for any existing caller. |
| R10 | The idempotency fingerprint already covers the whole request, so a retry with the same reference and period replays, and a changed one is refused 422 (no new work). |
| R11 | Additive migration: the quantity column changes from integer to numeric with every existing value preserved; the new columns are nullable. Orders before the change read back unchanged. |
| R12 | No change to the access rules, the GL contract, the IM contract or the email routes. |

## U: Use cases

- **UC-1** A consultant bills 7.5 hours at 80.00: quantity 7.5, unit price 80.00, line amount 600.00, PDF shows "7.5 × 80.00 = 600.00".
- **UC-2** 7.333 hours at 10.00: amount rounds once to 73.33; the total equals the sum of the rounded lines.
- **UC-3** A customer's PO "PO-4471" and a service period 1 to 30 October appear on the emailed PDF and in the Sales list.
- **UC-4** An existing caller sending `"quantity": 1` and no new fields behaves exactly as before.
- **UC-5** Quantity 0, negative, or with more than 4 decimals is refused 400 with the field named.
- **UC-6** A reference over 100 characters, or a period with `from` after `to`, or only one of the two dates, is refused 400.
- **UC-7** A stock-tracked line with quantity 2 invoices exactly 2 × the selling price, not 4×.
- **UC-8** A cash sale with a reference records and collects the gross as today; the reference prints on the receipt.
- **UC-9** A retried keyed sale with the same body replays; one with a different reference is refused 422.

## T: Tasks

| Task | Work |
|---|---|
| T1 | Domain: `SalesOrderLine.quantity` and `InvoiceLine.quantity` become `BigDecimal` (positive, scale at most 4); `amount` unchanged in form. |
| T2 | A serializer that reads a JSON number (integer or decimal) into `BigDecimal` and writes it back as a plain number without trailing zeros. |
| T3 | DTOs and use-case requests: `SalesOrderLineDto.quantity`, `LineRequest.quantity`, `CreateSalesOrderUseCase` lines. |
| T4 | Persistence and migration: `sales_order_lines.quantity` to `NUMERIC(19,4)`; table and repository mapping. |
| T5 | F1 fix in `RecordOrdinarySaleUseCase` (stock lines). |
| T6 | Order header fields: `customerReference`, `servicePeriodFrom`, `servicePeriodTo` (domain with validation, migration, repository, request and response DTOs, Sales list item, `GET /sales-orders/{id}`). |
| T7 | Invoice document and PDF: print quantity, reference, period; InvoiceLookup carries the fields. |
| T8 | Reports (F2): `totalLineQuantity` decimals. |
| T9 | Tests: domain validation; JSON integer and decimal round trips; amount rounding; F1 with quantity 2; reference and period validation and printing; migration against real Postgres with existing rows; idempotent retry. |
| T10 | Docs and handover: SOP playbook (remove the whole-number limit), tell WEB the exact contract and release order. |

## O: Order

1. **T1, T2, T3** (the type change everything else depends on), with **T5** because F1 is fixed by the same change.
2. **T4** (the migration) together with T1 so the application never reads a decimal into an integer column.
3. **T6, T7** (header fields and the PDF), then **T8**.
4. **T9** alongside each step; **T10** last.
5. **Release:** one SOP deploy (the migration runs at startup and is additive). WEB sends decimals or the new fields only after SOP confirms the deploy; until then WEB keeps the whole-number workaround.

Safety foundations first: none are missing for this change. Idempotency, Company scoping and the claim-first guards are already live; this change adds no posting path and no new money route.

## Decided

- **Accounting policy (Femi, 2026-10-07): "Services Invoice recognise revenue immediately."** A service invoice recognises revenue when the invoice is recorded, which is what `POST /api/sales` already posts. The customer reference and the service period are **information on the invoice only**, never an input to recognition; no deferred income, accrual, contract asset or milestone. Limits that follow: no advance billing, deposits or work in progress until a deferred-income build is separately decided.
- **Femi said yes** to decimal quantity and to the reference and period fields.
- **Defaults applied for Q1 to Q4** (open questions below, answered by the proposals unless Femi objects): at most 4 decimal places and a maximum of 1,000,000 (Q1); the reference does not go into the ledger description (Q2); return quantities stay whole numbers (Q3); the email subject and body do not mention the reference, the PDF does (Q4).

## Final contract (what WEB builds against)

- **Line `quantity`**: stays a JSON **number**. Integers (`1`, `100`) keep working unchanged. A decimal number (`7.5`, `7.333`) is accepted. At most **4 decimal places**, greater than 0, at most 1,000,000; otherwise 400 naming the field. A quoted string (`"7.5"`) is refused: it must be a JSON number. Responses write the same number without trailing zeros (`7.5`, never `7.50` or `7.5000`; `1`, never `1.0`).
- **PDF**: quantity printed without trailing zeros (`7.5`); line amount and totals at the currency's minor units (two decimals for USD/GBP/EUR/NGN/SLE).
- **Rounding**: each line amount = unit price × quantity rounded once to the currency's minor units (half up); invoice net = sum of the rounded lines.
- **New optional fields on `POST /api/sales`** (credit and cash): `customerReference` (string, trimmed, 1 to 100 characters, no control characters), `servicePeriodFrom` and `servicePeriodTo` (ISO dates `YYYY-MM-DD`, inclusive, both or neither, `from` not after `to`). Violations are 400 `bad_request` naming the field.
- **Returned**: `customerReference`, `servicePeriodFrom`, `servicePeriodTo` (null when absent) on each `GET /api/sales` item and on `GET /api/sales-orders/{id}`; line `quantity` in the same number form.
- **Idempotency**: the new fields are part of the request, so a keyed retry must repeat them identically.
- **Stock-tracked (itemId) lines**: the invoiced quantity is the stock quantity (default: the line quantity) and the unit price is IM's selling price (F1 fixed); a caller-supplied unit price is still ignored for these lines.
- **Release order**: SOP deploys first; WEB sends decimals or the new fields only after SOP says it is deployed. Until then an old SOP would refuse a decimal quantity with 400.

## Open questions (answered by the proposals above unless Femi objects)

- **Q1** Four decimal places and a maximum quantity (proposed 4 and 1,000,000)? Hours need two; weights and lengths may need three or four.
- **Q2** Should the customer reference also go into the ledger journal description so it is searchable in the books? Proposed: no (GL description stays the sale description).
- **Q3** Return requests keep whole-number quantities for now (proposed). If goods are ever sold in fractions (kilograms, metres) returns will need decimals too; confirm that is a later item.
- **Q4** Should the invoice email's subject or body mention the customer reference? Proposed: no, PDF only.
