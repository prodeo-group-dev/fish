# SOP's section of the shared payment-terms design: customer terms and invoice due dates (SOP session, 2026-10-18)

**Status: docs only, nothing built.** Companion to `docs/Payment_Terms_Shared_Definition_Design.md` (POP; branch `docs/pop-payment-terms-design`), which owns the list, the codes, the object `terms`, the due-date rule, the mapping rule, the shared fixture (`contracts/shared/payment-terms-cases.json`) and the EA Company default. This file says only what SOP stores and changes (that note's T-PT5). It is also the first item of the receivables plan (`SOP_Accounts_Receivable_Completeness_Assessment_2026-10-18.md`, item 1).

## 1. What SOP has today (checked in code)

`Customer.creditTerms` is a required free-text string (column `credit_terms`, 255 characters), validated only as not blank, returned on customer responses and lists. A sale (`SalesOrder`) has a date and amounts but **no due date**; the invoice (read route, PDF, email) shows none. Bills for Collection have their own `due_date`, a different thing. Cash sales ignore terms.

## 2. Storage (additive migration, next free version after `V19`)

- `customers`: add `terms_code` (nullable text), `terms_days` (nullable int), `terms_label` (nullable text). `credit_terms` stays and is filled with the display text ("Net 30"; the CUSTOM label).
- `sales_orders`: add `due_date` (nullable date), `terms_code`, `terms_days`, `terms_label` (the terms the invoice was issued under, frozen). A later change of the customer's terms never moves an issued invoice.
- Mapping migration for existing customers: only the forms the shared rule is sure of; everything else becomes CUSTOM with the original text as label and unknown days. Existing sales get **no due date invented**: they stay undated (ageing shows them as their own total).

## 3. API (consumer-first: old shape keeps working)

- Customer create/update accept `terms: { code, days, label }` **or** the old `creditTerms` string (mapped by the shared rule); both present and disagreeing is `400`. Responses add `terms` next to `creditTerms`. Strict: `days` null only for END_OF_MONTH, required 0..365 for CUSTOM, fixed for every other code; `label` only for CUSTOM.
- Until EA holds the Company default, terms stay required on customer create, as today (creditTerms or terms). When EA ships its two default fields SOP reads the customer default only on a create without terms (retryable `503` if EA is unreachable, never guessed), with a strict DTO and a fixture first.
- A sale (`POST /api/sales`, credit method) computes `dueDate` from the customer's terms and the sale `date` using the shared function and stores it with the terms. A request may carry an explicit `dueDate` that wins (an invoice with its own agreed date), validated not before the sale date. Responses and the invoice read route add `dueDate` and `terms`; the invoice PDF and email show "Due 9 Nov 2026 (Net 30)". Cash sales: no due date.
- The Idempotency-Key rules are unchanged: a replay returns the stored sale, due date included; the request fingerprint includes an explicit `dueDate`.
- The Education Runtime fee invoice (S1) gets its due date the same way, from the guardian Customer's terms; ER may send an explicit `dueDate` per term.

## 4. Code and tests

Copy of the pure function `dueDate(documentDate, code, days)` and of the free-text mapping in SOP's own domain package, each tested against the **shared fixture file** (read through the pinned `fish-contracts` submodule), plus SOP's own tests: strict `terms` validation, both-forms-disagree 400, due date stored at sale time and unchanged after the customer's terms change, explicit `dueDate` wins, replay returns the same due date, mapping migration on a real Postgres with a legacy row ("Net 30" mapped, "Net 30 EOM" CUSTOM and undated).

## 5. Estimate and order

About 1.5 d of SOP (T-PT5), after POP publishes the shared fixture (T-PT1, 0.5 d, POP) and in parallel with POP's own build; EA's default fields (T-PT2) are not on SOP's critical path because terms stay required until they exist. This unlocks receivables ageing by due date (the AR assessment's items 4, 5 and 8).

## 6. Open points

- Femi's D1 and D2 in POP's note (meaning of End of month; Cash on delivery vs Due on receipt) decide the shared function; SOP follows whatever the fixture says.
- Whether a customer-less sale ("Unregistered Cash Customer") needs terms: no, it is a cash sale.
