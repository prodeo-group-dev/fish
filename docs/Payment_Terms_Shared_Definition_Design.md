# Payment terms: one shared definition for supplier terms (POP) and customer terms (SOP), design note

Written by the POP session, 2026-10-18, DOCS ONLY. Agreed in principle with the SOP session (their reply of the same day is folded in below); not yet reviewed by CM or Femi. Nothing is built.

**Source of the requirement.** Femi, Decisions Log 2026-10-17/18 (relayed by CM): supplier PAYMENT TERMS become a fixed list (Due on receipt, Net 7, 14, 30, 45, 60, 90, End of month, Cash on delivery); the owner sets a Company default; custom terms are allowed; stored as a code plus a day count; existing free text is mapped to the list; the due date is the document date plus the term's days. This also unblocks due-date ageing and the "true overdue" the dashboard (EA At-a-glance Playbook, decision 2) has been waiting for.

## 1. Scope (S)

In: the list and its codes; the stored shape; the due-date rule; the mapping of today's free text; where the Company default lives; what POP stores and changes; what SOP stores and changes (SOP writes its own section after this note is on a branch); the order of work.

Out: late-payment interest, early-payment discount terms (a separate, paused piece: `docs/POP_Discounts_Received_SPUTO.md`), instalment schedules, a per-item or per-order override of the party's terms, terms on cash sales (they ignore terms).

## 2. Plan (P)

### 2.1 The list

| Code | Meaning | Stored `days` | Due date |
|---|---|---|---|
| `DUE_ON_RECEIPT` | Due when the document is received | 0 | document date |
| `NET_7` | | 7 | document date + 7 |
| `NET_14` | | 14 | + 14 |
| `NET_30` | | 30 | + 30 |
| `NET_45` | | 45 | + 45 |
| `NET_60` | | 60 | + 60 |
| `NET_90` | | 90 | + 90 |
| `END_OF_MONTH` | Due on the last day of the month the document is dated in | **null** | last day of the document date's month |
| `CASH_ON_DELIVERY` | Paid when the goods arrive | 0 | document date (the code stays distinct so a later delivery-based rule is possible) |
| `CUSTOM` | The owner's own terms | 0..365, required | document date + days |

Rules, strict (SOP's addition, agreed): `days` is **null** for `END_OF_MONTH`, **required 0..365** for `CUSTOM`, and equals the table's number for every other code; any other combination is refused. `label` is set only for `CUSTOM` (the owner's own words, at most 100 characters) and must be absent otherwise.

### 2.2 Wire shape, in both services

`{ "code": "NET_30", "days": 30, "label": null }` as an object named **`terms`** on a supplier or customer (and, for display, a short text such as "Net 30" kept next to it).

**Name:** POP's supplier already has a string field called `paymentTerms`, and an object cannot reuse that name. POP therefore adds `terms` (object) and keeps `paymentTerms` (string) filled with the display text. SOP said it would add an object named `paymentTerms` beside its `creditTerms`; I propose both services use `terms`, so a screen has one name to read. **SOP to confirm.** A request that carries both the old string and `terms` and they disagree is `400`; the old string alone is still accepted and mapped (2.4).

### 2.3 The due-date rule: one pure function, an executable shared fixture

`dueDate(documentDate, code, days)`: `END_OF_MONTH` returns the last day of the document date's month (28/29/30/31-day months, leap years, across a year end); every other code returns `documentDate + days`.

To stop the two services' copies from drifting, **the cases live in one file in fish-contracts**, `contracts/shared/payment-terms-cases.json`, with two arrays:

- `dueDates`: `{documentDate, code, days, expectedDueDate}` including `END_OF_MONTH` in February (common and leap year), a 30-day and a 31-day month and a December document, `CUSTOM` 0 and 365, and one case per code.
- `freeTextMapping`: `{input, expectedCode, expectedDays, expectedLabel}` (2.4).

Each service tests its own copy of the function **against the same file**. A copy per service plus the fixture, not a shared type in `common`: `common` is consumed as source, and a change there ripples through every service at once.

The due date is **stored on the document at the moment it is created** (POP: the vendor invoice at the three-way match; SOP: the sales order / invoice). A later change to the party's terms never moves an issued document.

### 2.4 Mapping today's free text (conservative; no guessing)

Today `Supplier.paymentTerms` (POP, V2) and `Customer.creditTerms` (SOP) are free text. The rule, identical in both and held in the shared fixture:

- Trim, case-fold, collapse spaces and treat `-`, `_` and a missing space the same, then match only these forms: `net 7`, `net7`, `7 days`, `net 14` ... `net 90` and the same for 14, 30, 45, 60, 90 (e.g. `Net 30`, `net30`, `NET-30`, `30 days` map to `NET_30`); `due on receipt`, `on receipt`; `cash on delivery`, `cod`; `end of month`, `eom`.
- **Anything else is `CUSTOM` with the original text as the label and the day count UNKNOWN until the owner sets it.** In particular `Net 30 EOM`, `30 days from invoice`, `2/10 net 30`, `net 30 days from end of month` are NOT mapped to `NET_30`.
- A migration maps only what this rule is sure of. The production rows are legacy test data (Decisions Log: less ceremony until the live switch), but the rule is written as if they were not.
- A `CUSTOM` row with an unknown day count has **no computed due date** until the owner fills it: the ageing treats it exactly like an undated invoice today (a separate total, never put in CURRENT).

### 2.5 The Company default (Femi: "the owner sets a Company default")

Held in **one place, EA**, set by the Owner, as **two fields**: default customer terms and default supplier terms (different decisions). SOP's constraint, adopted: EA's reads are strict decodes, so a new EA read means a new strict DTO and a contract fixture on both sides. Each service reads the default **only when a party is created WITHOUT terms**, not on every call; if EA is unreachable at that moment the create is refused with a retryable `503`, never guessed. Until EA has the setting, terms stay required on create, as now.

### 2.6 POP's changes

- **Storage (migration V24, additive):** `suppliers.payment_terms_code`, `payment_terms_days` (nullable), `payment_terms_label` (nullable); the existing `payment_terms` text stays as the display text. The Company default is not stored in POP.
- **API:** supplier create and update accept `terms` (object) and still accept the old `paymentTerms` string (mapped by 2.4); responses add `terms` next to `paymentTerms`.
- **Due date at the match:** `RecordThreeWayMatchUseCase` computes `VendorInvoice.dueDate` from the supplier's terms and the match's invoice date. **An explicit `dueDate` on the request still wins** (the supplier's invoice may state its own), so nothing today breaks. With neither a computable term nor an explicit date the invoice stays undated, as now.
- **Ageing:** unchanged in shape; it simply sees far more dated invoices.
- **Not changed:** the GL posting, the idempotency keys, the payments (T8), the credit notes (T-D5).

### 2.7 Order of work (consumer-first)

1. This note agreed by SOP, reviewed by CM, answered by Femi on D1 to D3 below.
2. The shared fixture file in fish-contracts (the cases for 2.3 and 2.4). POP writes the first version; SOP reviews it.
3. EA adds the two default fields (EA's own SPUTO row); POP and SOP then declare the strict DTO field and a contract test **before** EA ships it.
4. POP and SOP each build their half (storage, function against the shared fixture, API, due date at creation, migration), tests first.
5. WEB: the terms picker with "Net 30" style display, the Company default in EA's settings, a "custom days" input.

## 3. Use cases (U)

| # | Use case |
|---|---|
| UC-1 | The owner sets the Company's default supplier terms once; a new supplier created with no terms gets it. |
| UC-2 | A supplier is created with Net 30; its three-way match on 2026-10-10 stores a due date of 2026-11-09. |
| UC-3 | A supplier on End of month; an invoice dated 2026-02-12 is due 2026-02-28 (2027 or a leap year handled). |
| UC-4 | The supplier's invoice states its own due date; the person types it; it wins over the computed one. |
| UC-5 | A legacy supplier with the text "Net 30 EOM" becomes `CUSTOM` with that label and no due date until the owner sets one. |
| UC-6 | The owner changes a supplier's terms; invoices already issued keep their due dates. |
| UC-7 | EA is unreachable when a supplier is created without terms: the screen is told to try again, nothing is guessed. |

## 4. Tasks (T)

| # | Who | Task | Estimate |
|---|---|---|---|
| T-PT1 | POP | The shared fixture file and the pure function, tests first | 0.5 d |
| T-PT2 | EA | The two Company default fields and their read | EA's estimate |
| T-PT3 | POP | Declare EA's default field (strict DTO and contract test), consumer-first | 0.25 d |
| T-PT4 | POP | V24, supplier `terms` in the API, the mapping migration, due date at the match, tests | 1.5 d |
| T-PT5 | SOP | Their half (their own section) | SOP's estimate |
| T-PT6 | WEB | The picker, the default setting screen, display text | WEB's estimate |

## 5. Order (O)

T-PT1 first (everything tests against it), then T-PT2/T-PT3 together (consumer-first), then T-PT4 and T-PT5 in parallel, then T-PT6.

## 6. Open questions for Femi (plain words)

- **D1. What does "End of month" mean?** I have taken it as: due on the **last day of the month the invoice is dated in** (an invoice dated 12 February is due 28 February). Many suppliers mean "end of the month **following** the invoice month" (written "30 days EOM" or "Net EOM + 30"). Which do you want for this code? (The longer forms are `CUSTOM` either way.)
- **D2. "Cash on delivery" and "Due on receipt" both come out as due on the document date.** Is that right for now? (Cash on delivery stays a distinct code, so a later rule that counts from the day the goods arrive stays possible.)
- **D3. Custom terms: is 0 to 365 days the right range?** (Chosen as a generous ceiling; a longer term would need a reason.)

## 7. Out of this note, said plainly

The shape SOP stores, its invoice due date and its migration are SOP's own section. The EA setting is EA's. This note does not decide the late-payment or early-payment (settlement) discount rules; those stay with the discounts SPUTO and Femi's review of the settlement-discount VAT playbook.
