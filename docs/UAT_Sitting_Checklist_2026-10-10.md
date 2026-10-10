# Combined UAT sitting: checklist (CM, 2026-10-10)

One sitting, on current production code, by Femi's tester. A brand-new Tenant with **two businesses and a school**. The tester does the clicks; CM reads the service logs right after each part and reports. Findings go to the owning session. Everything in production is legacy test data until Femi announces the Live switch.

**What is new since the last sitting (live):** GL T15 enforcement (service allow-list enforcing, GL derives Tenant from Company); POP T7 (post to GL first, idempotent match and pay, POP :37); HR idempotent expense/advance approvals + `decided_meanwhile` 409 (HR :41); ER T-ER1/T-ER2 access tightening (ER :84); WEB stage 3 (one Reports screen), SOP Net/VAT/Gross + open invoice + GL refusal message, stage 4 (People sections, Company profile under Companies). **Also live now (cash and bank, GL :119 + WEB):** cash and bank books, Company currency from the country, wording fixes. **Not live, on purpose:** Periods (auto-open / explicit close), foreign-currency accounts, GRNI fix, enforcement of the cash/bank settlement checks (log-only).

## Before the sitting (CM)
- All of the above deployed and image = master head on each service (CM verified 2026-10-10: GL :119 8687be8, EA :89, SOP :51, IM :32, POP :37 b47c0e5, HR :41 7e51428, ER :84 fc52911).
- GL still in enforce mode (no `FISH_SERVICE_ALLOWLIST_MODE`).
- After the school Company exists: add its Company id to `SOP_ER_COMPANY_IDS` (new SOP task definition, CM) before testing guardian billing.

## 1. Onboarding (EA, ER, WEB)
1. Sign up / sign in; create the Tenant with business 1 (jurisdiction, currency as the form allows today).
2. Add business 2, then the school (industry type Education).
3. "Set up school profile" for the school.

**CM reads:** EA `POST /api/tenants` 201 exactly once; company-registration 200 x3; no 502 `school_provisioning_failed`, no 409 `company_registration_rejected`, no `first_admin_already_set` warning, no 5xx. ER: `schools.organisation_id` is a 36-character UUID equal to the Company id in EA; `staff_assignments` SCHOOL_ADMIN ACTIVE `granted_by ea-provisioning:`.

## 1b. Onboarding extras (WEB, GL)
Choosing a country shows the currency read-only ("Your books will be in SLE."): UK GBP, IE EUR, NG NGN, SL/LR/GN/CI SLE. Try Add company the same way. No currency dropdown any more. **CM reads:** no 409 `currency_not_supported_for_jurisdiction`.

## 1c. Cash and bank books (GL, WEB): Finance > Cash and bank
1. Account 1000 is the Cash Book; open it. Add a bank account with "Add a bank account" (GL picks the next code, from 1010).
2. Record Money in (receipt), Money out (payment) and Move money (transfer, cash to bank); each shows the saved notice and the balance. Take the cash book below zero once: expect a warning, not a refusal.
3. Try Money in against Receivables or Payables: expect a refusal naming the right screen (Sales or Purchases).
4. Undo an entry recorded in the book: allowed. Try to undo a sale or a supplier payment from the book: not offered / refused (409 undo_elsewhere).
5. Click Save twice quickly on a receipt: one entry only.
6. Finance > Reconciliation: only the bank account is offered; reconcile it.
7. Reports > cash flow: the statement covers cash and bank together; a transfer between them is not a cash flow.
**CM reads:** `WOULD REFUSE` lines (settlement account, bank-only reconciliation), 409 `no_cash_account`, any 5xx on cash-books, accounts, standard-accounts, bank-reconciliations.

## 1d. Old Company fix (GL)
For the old Company `13de72e4-4638-4ea3-b342-552bd8116813`: a signed-in person with WRITE calls `POST /api/companies/13de72e4-4638-4ea3-b342-552bd8116813/standard-accounts` with that Company's X-Tenant-Id and no body. Expect 2150 added; then a sale there no longer answers 409 `vat_control_account_not_configured`. (CM can hand over the exact call.)

## 2. Sell (SOP, WEB, GL)
1. Credit sale, cash sale, hours sale; check "Net . VAT . Gross" on the sales list; open an invoice (lines, reference, service period), Download PDF, email box, "Back to sales".
2. Sale on a Company with no account 2150: message says to add 2150, nothing recorded.
3. Collect a payment. Then a **credit-note sales return** (never run under enforcement).

Cash and card sales settle into account 1000 (the Cash Book). **CM reads:** SOP and GL logs: `record-sale`, `record-collection`, `record-sales-return` 200, no `BLOCKED service=` / `forbidden_endpoint` / `WOULD BLOCK`, no 5xx.

## 3. Stock (IM)
Create an item, receive stock, issue stock (IM's own screens). **CM reads:** GL `service=im` calls 200; no allow-list refusal.

## 4. Buy (POP; POP's checklist, T7 now live)
1. Add supplier. 2. Create PO with a line, quantity, price, VAT category STANDARD. 3. Send it (a NO_CONTACT_METHOD notification answer is a pass). 4. Record goods received in POP. 5. Receive the same stock in **IM**. 6. Record the three-way match (invoice reference, goods receipt reference, MATCHED, a date, a due date). 7. Open payables due-date aging. 8. Pay the supplier (executing party PRODEO).
Skip POP step 9 (returns outwards) until IM clears T6.

**CM reads:** GL log order `purchase-posting-context` then `record-obligation` (step 6), then `purchase-posting-context` then `record-payment` (step 8), each `service=pop`; any other POP-origin line is a surprise. **Seam A check:** after steps 5 and 6, read GL AP and inventory balances once each. If AP is credited twice for one purchase, that is the stock-purchase double recognition (known; fix is the IM/POP/GL GRNI design).
A failed match now leaves nothing saved; if one fails, tell CM the exact status and message. Do not pay an order whose match failed.

## 5. People (HR, WEB)
1. Add an employee with email; run payroll (create, approve, pay); a leave request; an expense claim and a salary advance, approve each, and click approve twice quickly on one (expect one journal entry). 2. Invite a team member (Owner only). 3. People pills: Employees, Pay runs, Salary advances, Team; Add employee and Run payroll as buttons on Employees with "Back to employees".

**CM reads:** the six GL-facing HR routes under enforcement; no `forbidden_endpoint`; the expense/advance entries present once.

## 6. Companies (WEB, EA)
No "Company profile" pill any more. Companies shows the selected company's profile first (registered name, address, VAT number, contact email): edit, save, reload, kept. "+ Add another company" opens the add form. Verification is its own pill.

## 7. Reports (GL, WEB)
Finance > Reports: one Report picker; balance sheet as-at date; profit and loss from/to range; print on each. Dashboard with data (WEB has not yet looked).

## 8. Isolation
A person on the new Tenant opens the **first Tenant's** Company by URL: expect 403, never data; and the reverse. A guardian cannot read another child (T-ER2); a registrar cannot make a school admin (T-ER1).

## 9. School (ER, SOP)
School admin first sign-in works; fee billing to a guardian reaches SOP (needs `SOP_ER_COMPANY_IDS`; otherwise a clear 503 `billing_not_enabled`).

## After the sitting (CM)
Report what passed and failed, with the log lines, by owner. Then the order of work in `docs/Joint_Plan_2026-10-10.md` section 3C.
