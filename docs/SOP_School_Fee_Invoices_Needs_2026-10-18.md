# SOP's side of school fee invoices: routes, bodies and estimate (SOP session, 2026-10-18)

**Status: design only, docs first, no SOP code written for this.** Answers CM's request (Femi settled step 4: the VAT category comes from the fee item, revenue is recognised when the invoice is issued, per term) and sits under ER's plan `docs/ER_Fee_Invoice_Through_SOP_Plan_2026-10-18.md` (its steps B, D and E are SOP's). Read at SOP master `6de3d08` plus the unmerged item-VAT branch. Estimates are builder-days of one session including tests and hand-off, mine and unproven; they exclude CM's review time and other sessions.

## 1. What SOP already does that this relies on (checked in code)

- `POST /api/sales` takes the Company in the body (`companyId`), a `customerId`, dated lines, `customerReference`, `servicePeriodFrom/To` (print only), and an `Idempotency-Key` header (1 to 128 characters; `ER-invoice-{opId}` fits). The same key and the same body replays the stored result and posts once; the same key with a different body is `422 idempotency_key_reused`; a refused sale spends no key.
- Response (`200`): `journalEntryId`, `salesOrderId`, `status`, `invoiceNumber` (`INV-` + 8 characters), `paid`, `netAmount`, `vatAmount`, `grossAmount`, `currency`. ER can store `salesOrderId`, `invoiceNumber`, `grossAmount` and `currency` from this one answer.
- Revenue is recognised at the sale date: exactly what Femi decided for the first build ("when the invoice is issued, per term"). Service period and reference are print-only. **Nothing to build for recognition.**
- The sale does not store who raised it. `requestedByEmail` is read from the token only as a gate in the route and passed to the use case, which does not keep it. The invoice (PDF, email) is issued in the Company's name. So "the invoice issuer is the school" is already true; the service credential's token does carry an email (it is a Cognito service user, like the ones GL and IM already accept), so nothing person-shaped needs inventing: S1 only had to open the route and bound what the credential may do.
- A service credential may call only routes that opt in (`serviceMayCall`), only with a Company the school rule accepts (today the env list `SOP_ER_COMPANY_IDS`, empty in production, so ER is refused everywhere; the EA industry read replaces it).

## 2. VAT: how the fee item's category reaches the line

Two cases, one rule: a line's category is never defaulted and never copied from another line.

- **Interim (works the moment the route is open): ER sends the category it holds on the fee-schedule item** (set by a person in ER, step A of ER's plan) as the line's `vatCategory`. SOP keeps requiring it on a service line (a line with no `itemId`), as it does for every service line today, and GL refuses a category the Company's country does not have (`vat_category_not_supported`, `no_vat_rate_schedule`). ER already refuses to call SOP when an item has none.
- **Target (when IM has service items): the line carries `itemId` of an IM service item and the category is read from that item**, the same way a goods line already is as of the item-VAT branch (`409 item_has_no_vat_category` if the item has none). This needs IM to say whether an item can be a service with no stock: **today SOP issues stock for every line that has an `itemId`**, so a fee line must not carry one until IM can mark an item as a service and SOP skips the stock call for it. Asked of IM, not decided here.

## 3. What SOP builds, in order

| # | Step | What changes in SOP | Est. | Gate |
|---|---|---|---|---|
| S1 | **ER may raise a credit sale** (ER step B) | `POST /api/sales` opts in `serviceMayCall`. For the service credential only: (a) the Company is read from the body and checked by the school rule; (b) `saleMethod` must be CREDIT (a school's cash arrives through the collection route, never as a cash sale); (c) **service lines only: a line with an `itemId` is refused** (`403`, so the credential can never issue stock at IM); (e) the customer must belong to that Company (already enforced). A human's path is untouched. | 2 d | CM at HIGH (auth path) |
| S2 | **School rule client** (replaces `SOP_ER_COMPANY_IDS`) | `CompanyIndustryGateway` with a strict EA client (no `ignoreUnknownKeys`), positive-only cache, fail closed; used by `authorizeServiceAccount`. Switched ON only when CM says; **ships OFF**, the env list stays the rule until then. Until it is on, S1 can be tested end to end on the one test school through `SOP_ER_COMPANY_IDS`. | 1.5 d | CM at HIGH; needs EA's `GET /api/internal/companies/{id}/industry` |
| S3 | **Contract fixtures** | `fish-contracts` fixtures for the sale request and response and for each stable refusal, so ER decodes SOP's answer strictly (the same T2/T9 mechanism already used for customers). | 0.5 d | ordinary |
| S4 | **ER may record a verified payment** (ER step D) | The collection route opts in for the service credential. It already takes `companyId` in the body (design note section 15 said it had none: that is out of date since 2026-10-07) and looks the order up inside that Company, so a foreign Company answers not found; add the school rule on that Company, `Idempotency-Key: ER-payment-{id}`, part payments already work (`PARTIALLY_COLLECTED`). | 1 d | CM at HIGH |
| S5 | **ER may read for statements** (ER step E) | Read-only opt-in, same school rule: `GET /api/companies/{c}/customers-with-balances`, `GET /api/sales` (per Company), `GET /api/companies/{c}/sales-invoices/{invoiceNumber}`. Balances are **gross, including VAT**. | 1 d | CM at HIGH |

**Critical path for "a school can raise a fee invoice": S1 (2 d), tested through the interim env list, then S3 (0.5 d). About 2.5 days of SOP, one CM review at HIGH.** S2 is not on that path. S4 and S5 follow ER's C.

## 4. Route and body ER calls (strict JSON, unknown keys refused by ER's own decoder)

```
POST /api/sales
Authorization: Bearer <ER service token>
Idempotency-Key: ER-invoice-{opId}

{ "companyId": "<the school's organisationId>",
  "customerId": "<the guardian's SOP Customer id>",
  "entityId": "<same Company id>",
  "saleMethod": "CREDIT",
  "date": "2026-10-19",
  "description": "Tuition 2026-T1",
  "customerReference": "<student reference>",
  "servicePeriodFrom": "2026-09-07", "servicePeriodTo": "2026-12-18",
  "lines": [ { "description": "Tuition", "quantity": 1,
               "unitPriceAmount": "1200.00", "unitPriceCurrency": "SLE",
               "vatCategory": "EXEMPT" } ] }
```

One sale per request, one line per fee item (ER's recommendation 2, agreed from SOP's side: one invoice per term with its lines). Success `200` as in section 1. Refusals ER should map (SOP codes): `403 forbidden` today, and `403 not_a_school_company` once S2 is on (both to `billing_not_enabled`), `404 customer_not_found`, `400 missing_vat_category` / `bad_request` (ER should never send these), `409 no_vat_rate_schedule` / `vat_category_not_supported` (the ledger has no VAT rates for that country or category: not retryable, a person fixes the fee item or the Company), `409 posting_context_unavailable` / `no_open_period` (open a period, then retry with the same key), `409 gl_engine_call_failed` (retry with the same key only if the detail says the ledger did not post; `gl_idempotency_conflict` means do not make a new key), `422 idempotency_key_reused`, `409 idempotency_key_in_progress` (retry in a second), `503` (retry with the same key). A retry always carries the identical body.

## 5. Open points that are not SOP's to decide

1. **IM service items** (section 2): until IM can mark an item as a service, fee lines carry an explicit category from ER and no `itemId`.
2. **Settlement account for a payment** ("the school's settlement accounts"): the collection route takes an optional `settlementAccountId` and defaults to the Company's cash book `1000`. ER holds no ledger account ids. Proposal for GL and Femi: the fee desk picks the book in WEB from a read of the Company's settlement accounts, ER passes the chosen id through; default `1000` until then.
3. **Revenue over the term** stays at the invoice date for the first build (decided). Spreading it is GL's later request Q1 and needs nothing from S1 to S5.
4. **Money currency for a school**: the examples use `SLE`, the only currency the platform onboards in the Mano River countries.

## 6. Test plan (tests first)

SOP: the service credential is refused for a GENERIC Company and for an unknown Company; refused on every route not opted in; a service-credential sale with `itemId` is refused and no stock call is made; with `saleMethod` CASH it is refused; the same key twice posts once and returns the same answer; a refused request spends no key; a customer of another Company answers not found; a human token's path is byte-identical (golden); EA industry read: positive answer cached, refusal and error not cached, undecodable body fails closed (S2). End to end on the test school with the env list, then with the EA read switched on.
