# SOP: payment method, settlement account and a numbered receipt for every payment (design note, SOP session, 2026-10-18)

**Status: design note only, no build until CM confirms the order.** Femi (via CM): a school fee payment is CASH, BANK TRANSFER or MOBILE MONEY, each mapped to its own cash or bank book chosen per Company (cash book 1000, a bank book, a mobile-money wallet book), and **a receipt is issued for every payment: numbered, printable, emailable to the guardian.** This note covers SOP's side. It builds on the receipts register (SOP's AR branch, held for rule 3) and on the collection route.

## 1. What exists

`POST /api/sales-orders/{id}/collections` takes `{companyId, amount, currency, date, settlementAccountId?, description?}` and an `Idempotency-Key`. No payment method; `settlementAccountId` omitted means the Company's cash book (1000). The AR branch already stores each collection as a **receipt** record (date, amount, settlement account, ledger entry id, description) with a UUID, no human-readable number. Invoices already have a printable/emailable document (PDF, SES, audit, rate limit); a fully paid invoice prints as a "Receipt" for the whole invoice, not per payment.

## 2. Payment method and the settlement account (aligned with GL's design, CM 2026-10-18)

- The collection request gains an optional **`paymentMethod`**: `CASH`, `BANK_TRANSFER`, `MOBILE_MONEY` (a closed list). SOP stores it on the receipt and prints it. ER and the fee desk send the METHOD; they need not know ledger accounts.
- **SOP owns an explicit per-Company mapping** from method to settlement account: `CASH` -> the cash book (1000, or another cash-kind book), `BANK_TRANSFER` -> a bank book, `MOBILE_MONEY` -> a wallet book (a cash-kind book). It is a **setting, never a silent fallback**:
  - Stored in SOP (`payment_method_accounts`: Company, method, settlement account id) with an audit trail of who set it and when (`payment_method_account_changes`: before, after, changed by, changed at).
  - Read and set by `GET` / `PUT /api/companies/{c}/payment-method-accounts`. Setting needs the Owner Admin or an accountant at the Company (the same gate IM uses for item settings; SOP's check for "accountant" depends on what EA's membership answer exposes, to be confirmed with EA); reading needs Sales read access.
  - **Validated against GL's `settlementAccounts` list** (the additive field GL proposes on the sales-posting-context: the Company's own, active cash and bank books with their kind). An account that is not in that list is refused (`400 settlement_account_invalid`), so a method can never be mapped to a foreign, inactive or non-cash account. SOP declares the new field strictly after GL publishes its fixture.
- A collection that names a method resolves the account from the mapping. **A method with no mapped book answers `409 settlement_account_not_configured` (naming the method)**; there is no fallback to the cash book.
- A person at the fee desk may still choose an account **explicitly** by `settlementAccountId` (validated against the same GL list); if both a method and an account are sent, the explicit account wins and the method is recorded as given. Omitting both keeps today's behaviour for older callers: the cash book, method unknown (nothing is guessed).
- The receipt number goes to GL as the optional **`reference`** on `record-collection` (GL's proposal), after the ledger accepted nothing yet: the number is assigned when the receipt is saved, so the order is ledger posting first (the posting carries no number), then number, and the number is stored in SOP; if GL wants the number on the entry, GL's `reference` field is filled by a corrective note or SOP assigns the number BEFORE the posting and burns it on a refusal. SOP prefers the first (no gaps, no burnt numbers) and asks GL whether a reference can be attached after the fact, otherwise SOP reserves the next number before posting and reuses it on retry with the same key.

## 3. The receipt number

- **A per-Company running number, assigned when the receipt is recorded**: `RCT-000001`, `RCT-000002`, ... Stored on the receipt with a unique constraint `(company, number)`. Assigned inside the same transaction that saves the receipt (a per-Company counter row, locked while incrementing), only after the ledger accepted the collection, so a refused collection uses no number and the series has no gaps from failures. A replay of the same Idempotency-Key returns the same receipt and number.
- Not a UUID prefix (the invoice number's `INV-` plus 8 hex characters is not a sequence; a receipt number should be). A school may later want its own prefix (for example per-school); the counter is per Company, which is the school.
- Existing receipts (legacy backfill) get numbers in date order by the migration, so every receipt has one.

## 4. The printable, emailable receipt

- `GET /api/companies/{c}/receipts/{receiptNumber}` returns the receipt as data: Company name, customer, receipt number and date, amount, payment method and book name, which invoice it was applied to (invoice number), the invoice total, paid so far, and what is still open (negative = credit balance).
- `GET .../receipts/{n}/pdf` (server-side PDF, same renderer as the invoice) and `POST .../receipts/{n}/email` (one recipient, same SES sender, duplicate guard, daily cap and audit as the invoice email; Reply-To is the business contact email). The guardian's email is typed or taken from the customer's contact email.
- A payment is a claim until the fee desk verifies it (T-ER3): ER calls the collection route only with a verified payment, so the receipt exists only for money that is actually recorded.

## 5. ER's opt-in

The collection route gets `serviceMayCall` for the Education Runtime credential behind the school rule, with: the order must belong to the body's Company (already enforced, a foreign order answers not found); the credential may send `paymentMethod` and `settlementAccountId`; it cannot cancel, return or credit. Key `ER-payment-{id}`. The answer adds `receiptNumber` and `receiptId` (additive) so ER can show and send the receipt.

## 6. Contract changes (all additive, consumer-first)

Request: `paymentMethod` (optional). Answer of the collection: `receiptNumber`, `receiptId`. New reads: the receipt, its PDF, its email. Fixtures in fish-contracts before the routes ship; WEB and ER declare their mirrors first.

## 7. Estimate and order

| Piece | Est. | Depends on |
|---|---|---|
| `paymentMethod` on the request and the receipt, `settlement_account_not_configured` | 0.5 d | AR branch (rule 3) |
| Receipt number (counter, migration backfill, unique) and the answer fields | 1 d | AR branch |
| Receipt read route and PDF | 1 d | the two above |
| Receipt email (SES, audit, cap) | 1 d | the PDF |
| ER credential opt-in on the collection route | 1 d | S1 released (fee-invoice route), CM review at HIGH |
| **Total** | **about 4.5 d** | |

Everything waits for the AR branch, which waits for Femi's answer on rule 3, and for GL's answer below.

## 8. Questions

**GL:** (a) how should SOP's collection and ER's verified-payment route name the settlement account (an account id of a cash or bank book from the Company's books, as in shape 1)? (b) can GL read the Company's books with their type (cash, bank, mobile money) for the picker? (c) any reason the receipt number should be GL's? (SOP recommends not: the number identifies SOP's receipt record, the ledger entry id is referenced on it.)
**Femi (via CM):** is a per-Company running `RCT-000001` series right for a school, or should the school's code be part of it?
