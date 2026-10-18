# Fee invoices through SOP: build plan and contract (+ER Education, 2026-10-18)

**Why now.** The tester (RT_School_Fee_Invoice_Create, 2026-10-18) found a school cannot raise a fee invoice. Femi has now settled step 4 of Part 3 of `ER_Credential_School_Company_Rule_Design_Note.md`: the **VAT category comes from the fee item** and **revenue is recognised when the invoice is issued, per term**. So steps 5 to 8 of that note's build order are unblocked. This is the plan CM asked for: steps, estimates, who does what, and the route and body WEB can build against. **Plan only: no fee code has been written.**

**Estimates** are builder-days of one session including tests and hand-off, my own and unproven; they exclude waiting for other sessions.

## 1. What exists today (read at ER master `9441ae8` and SOP master `6de3d08`)

- ER has `POST /schools/{id}/fees/schedule` (pipe body `code|name|amount[|currency]`, **no VAT category field, and no read route to list the fee items**), `POST /schools/{id}/fees/invoices` (pipe body `studentId|billingCycle|scheduleItemId[|guardianAccountId]`), `POST .../fees/guardians/resolve` (creates the guardian's SOP Customer, key `ER-guardian-{id}`, live), `GET .../fees/invoices`, `GET .../fees/guardians`.
- **ER's `POST .../fees/invoices` writes an ER-only row. It never reaches SOP or GL.** WEB must not build the "New invoice" form on it: the invoice would exist nowhere that counts.
- SOP's `POST /api/sales` takes the Company as a **body field** and a customer, dated lines with an explicit `vatCategory`, `servicePeriodFrom/To` and `customerReference` (print only). The ER credential is **not** opted in on it (only customer create and read are), and the route records the actor from the token's **email claim**, which a service credential does not have.

## 2. The steps (Part 3 section 19, steps 5 to 8, with what each needs)

| # | Step | Owner | Est. | Gate | Needs first |
|---|---|---|---|---|---|
| A | **VAT category on a fee item** and a read of the fee items. `vatCategory` is one of `STANDARD, REDUCED, SECOND_REDUCED, SUPER_REDUCED, ZERO_RATED, EXEMPT`, set by a person (never by machine), **no default; an item without one refuses the invoice**. New `GET /schools/{id}/fees/schedule`; define-item gains a JSON body with `vatCategory` (old pipe body still works, but an item defined that way has no category until one is set). One migration (V39, nullable column). Interim until IM serves the jurisdiction-and-date lookup (Playbook M1). | ER | 1.5 d | ordinary | none: **can ship first, independent of SOP**, and it unblocks WEB's fee-item picker and Finance setting categories |
| B | **SOP opts in `POST /api/sales` for the ER credential**, behind the school rule (or, for the test school only, the interim `SOP_ER_COMPANY_IDS` list). SOP takes the Company from the body and authorises against it; **a service credential has no email**, so SOP must record the **issuer as the school (the organisation)** with the acting service in the internal trail (Femi 2026-10-13), instead of 401ing on a missing email. | SOP (asked directly) | 2 to 3 d | **CM at HIGH** (auth path) | school rule design from Part 1; CM reviews |
| C | **ER raises the sale in SOP.** A new strict outbound gateway beside `KtorSopCustomerGateway`; builds one SOP sale from the request: Company = the school's `organisationId`, customer = the guardian account's SOP customer, one line per chosen fee item (description = item name, quantity 1, price and currency from the item, `vatCategory` from the item), `servicePeriodFrom/To` from the term when the billing cycle matches a term, `customerReference` = the student's reference. **Claim first:** the ER mapping row is saved before the call, the call carries `Idempotency-Key: ER-invoice-{opId}`, the SOP sale id and invoice number are saved after; a crash between the two replays under the same key and converges (SOP dedupes). Refusals map to stable codes below. Migration V40 adds `sop_sale_id`, `sop_invoice_number`, `op_id`, `vat_category` (the category the invoice used, frozen). | ER | 4 d | **CM at HIGH** (new outbound service call and a new SOP scope) | A, B; `fish-contracts` fixture for SOP's sale request and response (SOP provides, ER decodes strictly) |
| D | **Verified payment** replaces `confirmPaymentStub` (T-ER3, key `ER-payment-{id}`, SOP collection route, the school's settlement account). Not needed to *raise* an invoice, so not part of the first blocker. | ER, SOP, GL | 4 d | CM at HIGH | C; SOP and GL answer how a collection names the settlement account |
| E | **Re-point the reads** (outstanding, statement, balances) at SOP, gross including VAT, and retire `reconcileStuckInvoices` and the ER amounts and status as truth. | ER | 3 d | ordinary | C, D |

**Critical path for "a school can raise a fee invoice": A, B, C. About 5.5 builder-days for ER, 2 to 3 for SOP, B and C in sequence** (C needs B on a test school to run end to end). A is ER-only and can be in WEB's hands first. D and E follow and are what closes the loop with payment and statements.

## 3. The contract WEB can build against (ER, JSON, strict: unknown keys are refused)

**Fee items.** `GET /schools/{schoolId}/fees/schedule` returns `[{ id, code, name, amount, currency, vatCategory | null }]` (any role that may view fees).
`POST /schools/{schoolId}/fees/schedule` (JSON, fee desk) takes `{ code, name, amount, currency?, vatCategory }`.

**Raise an invoice.** `POST /schools/{schoolId}/fees/invoices` (JSON body; the old pipe body keeps working and keeps its ER-only behaviour until step C replaces it, which is why WEB should wait for the JSON route):

```
{ "opId": "<a UUID the form makes once per click>",
  "studentId": "...",
  "guardianAccountId": "...",
  "billingCycle": "2026-T1",
  "scheduleItemIds": ["...", "..."] }
```

One request raises **one SOP sale with one line per fee item**; a retry with the same `opId` returns the same result and posts once. Response: `{ opId, saleId, invoiceNumber, items: [{ invoiceId, scheduleItemId, amount, currency, vatCategory }], total, currency }`.
Stable refusals: `fee_item_has_no_vat_category` (422, names the item), `guardian_not_billable` (the guardian has no SOP customer yet; resolve first), `billing_not_enabled` (SOP does not allow this school), `billing_unavailable` (503, safe to retry with the same `opId`), `duplicate_invoice` (409, the student already has that item for that cycle).
WEB also needs the picker data that already exists (`GET .../students`, `GET .../fees/guardians`) and `POST .../fees/guardians/resolve` for a new guardian; the admission form now captures the guardian, so a later increment can pre-fill the resolve step from the enrolled student.

## 4. Decisions I need confirmed (each with my recommendation)

1. **Idempotency key from the form's `opId`** (`ER-invoice-{opId}`) rather than a key made from an ER row id: the form is the only place that knows "this is the same click". Part 3 wrote `ER-invoice-{erInvoiceId}`; the effect on SOP is identical. **Recommend the `opId`.**
2. **Several fee items in one invoice** (one SOP sale, many lines) rather than one invoice per item. A school expects one tuition invoice per term with its lines. ER keeps one mapping row per item sharing the sale id. **Recommend one sale per request.**
3. **Interim category on the fee item is Finance's to set, with no default** (Femi 2026-10-13 and 2026-10-14: refuse, never default). Someone must set it for every item of the test school before the first invoice; I will not seed values.
4. **A bulk "bill the whole class for the term"** is a separate, later increment (preview, then apply, reversible, Playbook PL-IMP-1). The first build is one student and one guardian per request.

## 5. What this does not fix

- A school still has **no HTTP way to create or list class sections** (only a store method used by tests exists), so the class dropdown on the admission form will be empty on a real school until one is added; classes are optional on an application. A `POST` and `GET` for class sections is small (about 1 day, no new gate beyond the timetable role) and I recommend doing it next, after CM's view.
- Revenue recognition stays at the invoice date (Femi: recognised when the invoice is issued, per term). The over-the-term release remains the Playbook's later Q1 request, not part of this build.

## 6. Test plan (tests first)

ER: a missing `vatCategory` refuses and spends no key; the same `opId` twice posts one sale (a fake SOP gateway counts calls; a real-Postgres test proves the mapping survives a crash between the SOP success and the local save); a refused SOP call releases the claim and a corrected retry succeeds; a parent can never reach the route; cross-school student, item or guardian ids answer as missing. SOP: the credential is refused for a non-school Company and on every route not opted in; a replayed `POST /api/sales` with the same key posts once. End to end on a test school: an invoice raised, SOP and GL agree with ER's list.
