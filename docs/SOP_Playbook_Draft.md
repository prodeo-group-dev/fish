SALES ORDER PROCESSING (SOP) PLAYBOOK (draft for Omniview's Playbooks tab, service SOP)

Written by the SOP session, 2026-10-07 and updated the same day after the sales-integrity release (SOP master 262a28d, task definition fish-sales-order-processing:42). Plain text so it can be pasted straight into the console. Everything below is what the code does TODAY. The last section lists what is NOT built, not deployed yet, or not yet exercised, so nobody promises it to a customer. Re-check the date before trusting an answer, and update this when the code changes. Where this says "not verified in production", the code does it but nobody has watched it happen live.

REVIEWED 2026-10-17 by the SOP session against the Decisions Log (2026-10-15 and 2026-10-16), docs only. SOP is now at task definition :57 (adds customer-create idempotency and the contract-fixture tests). What changed in this sheet: Prodeo is a landlord (see the next paragraph); trade finance is the Tenant's own record-keeping with its own lender; "contact support" for a Tenant's data problem now says "ask your administrator"; items that were "not built" or "not deployed" but have since landed (decimal quantities, Company-by-Company access) are corrected; the VAT-category rule and the first-cohort scope are added. Facts that were not re-verified in production are still marked as such.

PRODEO'S ROLE (Femi, 2026-10-15: "Prodeo is a landlord. It has no role whatsoever in its tenants' data."). Prodeo provides the platform; it does not read, edit, correct or approve a Tenant's sales, customers, collections, returns or trade-finance records. Answers on this sheet explain what the system does and who can fix it. The fix is always on the Tenant's side: repeat the identical request, or a person with the right access in the Tenant's business (its Owner Admin or accountant) acts through the normal screens. Prodeo staff never "fix it in the database". Support IS for the FiSH system itself (a trial balance that does not balance, a ledger answer SOP cannot read, audit logs: Femi 2026-10-17); "ask your administrator" is for the Tenant's own business matters. SOP prepares records and calculates accurately; it does not audit and does not vouch for what a Tenant records (Femi, 2026-10-16: "Audit and Preparation are two different things").

PLAYBOOK CONTENTS (see docs/Playbook_Definition.md; a playbook is this sheet PLUS the SPUTO set)
1. Operator sheet: this document.
2. Scope: SOP/docs/SOP_MVP_Definition.md (in the SOP repo).
3. Plan / SRS: SOP/docs/Sales_Order_Processing_Requirements_Use_Cases.md, docs/Sales_Order_Processing_DDD_Design.md, SOP/docs/Trade_Finance_Collection_Software_Requirements_Specification.md, docs/Sales_Processing_Requirements_Specification.md.
4. Use cases: SOP/docs/Sales_Order_Processing_Requirements_Use_Cases.md (UC-SO1 to 7), SOP/docs/Trade_Finance_Collection_Use_Cases.md.
5. Tasks: SOP/docs/Trade_Finance_Collection_Backlog.md, docs/GL_POP_IM_SOP_Backlog.md, docs/IM_Goods_Issue_Idempotency_SPUTO.md.
6. Order: docs/GL_POP_IM_SOP_Backlog.md (dependency-ordered waves), docs/Fee_Billing_Epic13_SPUTO_Scope.md (school billing, SOP half in progress).
TRACEABLE IDS (2026-10-22, DRAFT awaiting Femi; GL reviewed the GL-impacting rows and approved from its side): docs/SOP_Requirements_And_Use_Cases_For_Approval_2026-10-22.md holds the stable requirement and use-case IDs for the work done since 2026-10-11, and is parts 3 and 4 of this Playbook for that work: FR-SOP-CUR-nn / UC-SOP-CUR-n (Company currency, serves UC-TJ-15, TJ-CUR-10, T-TJ-27), FR-SOP-FEE-nn / UC-SOP-FEE-n (interim school fee invoice path), FR-SOP-AR-nn / UC-SOP-AR-n (receivables: receipts, credits, overpayment, invoice date, ageing, locks, idempotency). It adds to, and does not replace, FR-SO / UC-SO, FR-TF / UC-TF, UC-SRS and FR-SOPFEE / UC-F. Every SOP branch, commit, fix, migration and test case cites these IDs (Femi's traceability gate, 2026-10-22).
Not written yet: a single SOP SRS that merges the order-to-cash and invoice-email/cash-sale/idempotency requirements; invoice emailing and cash sales were built from a contract agreed with the screen owner, not from an SRS (a gap Femi has called out: foundations must be ordered first).

OWNING SERVICE
Sales Order Processing (repo fish-sales-order-processing). The SOP session is the L2 for anything below. SOP posts every financial effect to the General Ledger (GL); stock effects go through Inventory Management (IM); who may do what comes from Enterprise Administration (EA). Deploys, task definitions and secrets belong to Configuration Management (CM), never to SOP.

ESCALATE TO
Owner: the SOP session (lane name not assigned yet, Femi names it). Deploy, environment-variable and secret problems: CM. Ledger or VAT-rate problems: GL. "Cannot access" for a person: EA.

HELP ARTICLES
None written yet. Do not invent links; say so if asked.

HOW ACCESS WORKS (needed for most "I can't do X" tickets)
SOP does not keep its own user list. For every call it asks EA who the person is and what they may do at the Company in the request.
- 401 unauthorized: no valid sign-in token. Ask them to sign out and in.
- 403 forbidden, with a reason. The three you will see: "No active Membership in this deployment's Tenant" (they have no membership in the business that runs this SOP at all); "This Membership's access level at the requested Company cannot perform this action" (they have access, but only to read; recording a sale, a collection or emailing an invoice needs WRITE); "This Membership is not granted access to the SOP module at the requested Company" (the Sales module was not switched on for them at that Company; an administrator does that in EA).
- 503 service_unavailable: SOP could not reach EA, so it refuses rather than guessing. Retry in a minute; if it persists, escalate to CM.
- The Owner Admin of the business gets WRITE on Sales at the business's own Companies automatically (since 2026-10-06), without being assigned. They do not get APPROVE or ADMIN, and not at any Company that is not listed under their business. Everyone else needs an explicit assignment.
- Service accounts (for example the Education Runtime's) are trusted by their own credential and skip the person check; they cannot send invoice emails.
Fact for the operator: for orders, collections, cancel and the Sales list, access is judged at the order's own Company (a record of a Company you cannot read is "not found"). SOP serves ONE business (Tenant) per deployment today. A person who belongs to a different business than the one this SOP is wired to always gets "No active Membership in this deployment's Tenant", however senior they are.

COMMON QUESTIONS AND HOW TO ANSWER

RECORDING A SALE (POST /api/sales)

Q: "lines[0]: vatCategory is required" (400).
A: Every sale line must carry a VAT category: STANDARD, REDUCED, SECOND_REDUCED, SUPER_REDUCED, ZERO_RATED or EXEMPT. This has been required since 2026-09-20 and there is no default; the seller must choose. A screen that does not send it will fail on every sale.
Decided 2026-10-15 and 2026-10-17 (Femi). A goods line (one with an item) now takes its category FROM THE ITEM in Inventory: whatever category the caller sent is ignored, and an item with no category refuses the sale with 409 item_has_no_vat_category before any stock is issued (built 2026-10-18, branch feature/item-vat-category-read, not yet deployed). A service line (no item) still needs the seller to choose one until Inventory has service items. NOT BUILT in SOP yet, from the 2026-10-15 decision: a product's or service's VAT category depends on the Tax Jurisdiction (the Company's) and the date (fiscal year and accounting period) of the sale. Inventory Management (IM) resolves it for a jurisdiction and date, the chosen category is frozen on the sale line, and if no entry covers the date the sale is refused, never defaulted. The rate for a category stays the ledger's, per jurisdiction and period. Until IM's slice A is live and SOP reads it, the seller still picks the category by hand, as above.

Q: "vat_category_not_supported" or "no_vat_rate_schedule".
A: The ledger decides which VAT categories exist for the Company's country. Ireland has five bands and the UK has three, plus EXEMPT; asking for a band the country does not have is refused. A country with no VAT rates loaded (Sierra Leone is seeded but not verified; Liberia, Guinea, Cote d'Ivoire and Nigeria have none) cannot record ANY sale until its rates are verified: the ledger answers 409 no_vat_rate_schedule whatever category is sent. This is not a SOP fault and the customer cannot fix it. Escalate to GL with the Company's country.

Q: "posting_context_unavailable" (often 409 no_open_period).
A: The ledger could not give SOP the accounts and open period it needs. Most often the Company has no open accounting period, or a required account (receivables, revenue, VAT) is missing. Nothing was recorded. Ask the Company's accountant to open a period; if accounts are missing, escalate to GL.

Q: "gl_engine_call_failed".
A: The ledger refused or did not answer. The status is the ledger's own (409 closed period, 400 bad request, 503 down). Since 2026-10-07 a failed sale is genuinely "nothing recorded": no order is saved, so it does not appear in the Sales list, cannot be emailed and cannot be collected. If the sale had stock lines, the detail ends "check the stock in Inventory before trying again" (stock was already issued at Inventory and is not returned automatically; an undo route is being designed with Inventory); the person or their administrator checks the stock in Inventory first. The error code and the ledger's own code are unchanged by that wording. A refusal with the code gl_idempotency_conflict (409) means the ledger already holds an earlier attempt under the same key and it may have posted: do NOT resubmit with a new key; escalate with the time.

Q: "stock_check_failed" or "item_has_no_selling_price".
A: A line tied to a stock item could not be checked or issued at Inventory Management (item unknown, not enough stock, IM down), or the item has no selling price set. Fix the item in Inventory first. Stock lines are issued BEFORE the ledger posting; if the sale then fails, the stock has already been issued. Escalate such cases so someone checks stock.

Q: The customer clicked twice, or the request timed out, and now there are two sales.
A: Deployed 2026-10-07: a sale or collection sent with an "Idempotency-Key" header is protected: the same key and the same request replays the original result instead of making a second sale or cash receipt; the same key with a different request is refused (422 idempotency_key_reused); the same key while the first is still running is 409 idempotency_key_in_progress (retry in a second). It protects ONLY a screen that sends the key: the cash-sale screen does (reported live, not verified), whether the older credit-sale form does is not verified. Without the key two identical requests are still two sales. After an unknown outcome (a timeout or 5xx) a retry must carry the IDENTICAL request. A retried sale with stock-tracked lines can still issue the stock twice until Inventory makes its issue idempotent (in progress), so check stock before resubmitting such a sale.

Q: What does the status mean?
A: Sales (ordinary) go straight to INVOICED when recorded. INVOICED means billed and not paid. PARTIALLY_COLLECTED means some money has been recorded, COLLECTED means paid in full. Other statuses (DRAFT, AVAL_CONFIRMED, FULFILLED...) belong to the trade-finance order flow. CANCELLED is final.

Q: "Collection currency GBP does not match the order's own currency USD", or "Cannot record a collection from status X".
A: A collection must be in the order's own currency, and only an invoiced or part-collected order accepts one. An already fully collected order refuses more ("order_not_ready_to_collect"). Check the order's status and currency.

Q: How is "paid in full" decided?
A: Against the amount the ledger actually debited to receivables, which is the net total PLUS VAT (the "gross"), when the ledger has reported it. Older sales have no gross recorded and are judged against the net total as before. A customer who pays only the net on a taxed sale therefore stays part-collected, correctly. If someone insists a fully paid sale shows part-paid, check whether VAT was added.

CASH SALES (saleMethod CASH)
Q: Can customers take cash sales through SOP?
A: Yes since 2026-10-07 the web cash-sale screen records the sale and the full cash payment together (reported live by Configuration Management; nobody has yet reported a real cash sale, so not verified in production). A customer is always required (there is no pooled walk-in customer in SOP; the screen creates one customer per Company called "Unregistered Cash Customer"), the Company must have a cash account (code 1000), and a "409 cash_account_not_configured" means nothing was posted because the Company has none. A "502 sale_recorded_not_collected" means the sale exists and is invoiced but the cash step did not complete; the screen finishes it through the collections route using the amounts and the "retryIdempotencyKey" in the message. "gross_amount_unknown" means the ledger did not report the amount to collect: do not retry; this is a fault in how the ledger answered, so it goes to support (the FiSH system), not to the Tenant's administrator.

INVOICE NUMBERS AND EMAILING AN INVOICE

Q: Where does an invoice number come from?
A: For credit sales it is INV- plus the first eight characters of the order id in capitals. It is not a running sequence. Rarely two orders in one Company share the same eight characters; the system then treats the number as ambiguous and answers "invoice_not_found" rather than guess. Cash invoices recorded in the ledger have the ledger's own numbers.

Q: Email an invoice to a customer.
A: Switched on 2026-10-07 (task definition :41). Not verified in production: the first real send had not been done when this was written. How it works: the person needs WRITE on Sales at that Company; they give ONE recipient address; SOP builds the PDF itself from the stored invoice and sends it from invoices@mail.theprodeogroup.com with the business name as the display name. Replies go to the business's Owner Admin email, not the person who clicked Send.
- 503 email_not_configured: either the sender is not switched on, or SOP could not find a usable Owner Admin email through EA (the Owner Admin needs a verified sign-in email). Nothing was sent. If it persists after Femi's first test, escalate to EA and CM with the Company.
- 400 invalid_email: not one plain address (no lists, no names in angle brackets).
- 404 invoice_not_found: no invoice with that number for that Company, or it is not invoiced yet.
- 409 duplicate_send: the same invoice went to the same address in the last 10 minutes; the answer says when. Not an error to fix.
- 429 rate_limited: 50 invoice emails per Company per UTC day; the answer says when it resets.
- 502 email_failed or invoice_source_unavailable: the mail service refused (for example an address it rejects) or the ledger could not be read. A failed send does not count against the limit and may be retried immediately.
- 403 "Emailing an invoice requires a signed-in person": automated callers cannot send.
Q: Did the customer get it? Did it bounce?
A: SOP only knows the mail service accepted it. Delivered, bounced and complained are NOT tracked yet; the list of sends shows "SENT" at best. Never promise a delivery receipt.
Q: Can we see who sent what?
A: Yes: the send list for an invoice shows recipient, time, who sent it and the status, newest first. The recipient address is kept there as the audit record and is not written to logs.

CUSTOMERS
Q: Create or find a customer.
A: Customers belong to a Company. Name, credit terms (free text such as "Net 30" or "Cash") and optional contact email. The customers list shows balances from the ledger (an unreachable ledger gives "balance_fetch_failed" and the list should be retried). The Education Runtime creates a customer for each guardian the first time one is set up; those appear here like any other.
Q: The customer was created twice after a click or a timeout.
A: Since task definition :57 (2026-10-14) creating a customer is safe to retry: a request sent with an "Idempotency-Key" header makes one Customer per key; repeating the identical request returns the same customer (200 instead of 201), and the same key with a different body is refused (422 idempotency_key_reused). The key is kept per Company with no expiry. Without the header two identical requests are still two customers. The Education Runtime sends one per guardian; whether the web customer form sends one is not verified.
Q: A customer with no email can't be emailed an invoice.
A: The email goes to whatever address the person types; the customer's stored email is not required.

TRADE FINANCE (BILL FOR COLLECTION, FACILITY HEADROOM)
Whose it is (Femi, 2026-10-15): this is the Tenant's own record-keeping of its own arrangement with a bank or lender the Tenant chooses. Prodeo and FiSH do not provide, arrange, confirm or take part in any trade finance ("FiSH delivers GLaaS for SMEs and that is all"); the feature is kept, generic for the Tenant's own lender. In SOP "the bank", "the facility" and "the avalising bank" always mean the Tenant's. Trade finance is in the first-cohort scope, but it has not yet been exercised end to end with a real counterparty flow; do not promise it as proven.
Q: What is the lifecycle?
A: A Bill for Collection is presented against an already-invoiced order, then ACCEPTED by the buyer's side, then marked DUE, then COLLECTED. Each step only moves forward one at a time ("invalid_transition" otherwise). Collecting posts to the ledger (needs a settlement account) and gives back facility headroom only when that posting succeeds. A facility headroom is opened once per facility ("facility_headroom_already_exists" if repeated).
Q: Buyer-side aval.
A: A trade-finance order cannot be fulfilled until the buyer's bank aval is confirmed; that is a hard rule, not a setting. An override needs a recorded reason.
Known gap: a Bill's own "Collected" step is saved even if the ledger posting failed. If a collection shows collected but the ledger does not show the cash, escalate.

RETURNS (RMA) AND CREDIT NOTES
Q: What are the steps?
A: DRAFT, SUBMITTED, then APPROVED or REJECTED; then RECEIVED, INSPECTED, CREDITED. One step at a time, no skipping, no going back; REJECTED and CREDITED are final.
Q: What does inspection do?
A: Each line gets a disposition: RESALEABLE, REPAIRABLE, SCRAP or DISPUTE. Resaleable and repairable lines put stock back into Inventory (and post to the ledger); scrap lines create a write-off in Inventory that still needs a Store Manager's approval before it posts. If a request has several lines and a later line fails at Inventory, the earlier lines are NOT undone: escalate with the request id, do not re-run it blindly.
Q: Issuing the credit note.
A: Only from an inspected request. The amount is supplied by the person, not worked out by SOP. It posts to the ledger as a sales return; if the ledger refuses, nothing is saved and it can be retried. When a single return covers every line of the original order and all are customer cancellations, the order itself becomes CANCELLED automatically.
Q: Does the customer get an RMA notice email?
A: Not yet. That sender is not switched on, so no RMA emails go out.

COMPLAINTS
Q: States?
A: OPEN, which can be ESCALATED (to the supplier), RESOLVED or REJECTED; escalated ones can be RESOLVED or REJECTED; resolved and rejected are final. A supplier's response can be recorded against an escalated complaint.

REPORTS
Q: What reports exist?
A: Sales performance and returns analytics (read-only, per the person's Sales read access). They report what SOP stores; they are not the ledger.

ERROR GLOSSARY (what the "error" field means)
unauthorized - bad or missing sign-in. forbidden - signed in but not allowed (read the reason). service_unavailable - cannot reach EA. bad_request - something in the request is wrong; the detail names the field. invalid_transition - that step is not allowed from the current status. *_not_found - no such record for this Company. posting_context_unavailable - ledger accounts or period missing. gl_engine_call_failed - the ledger refused or is down; read the detail. stock_check_failed / item_has_no_selling_price - Inventory problem. order_not_ready_to_invoice / order_not_ready_to_collect / sales_order_not_yet_invoiced - the order is in the wrong state. cash_account_not_configured - no cash account 1000. email_not_configured / invalid_email / duplicate_send / rate_limited / email_failed - invoice email (see above). inventory_posting_failed / inventory_adjustment_failed - a returns step failed at Inventory. internal_error - a bug; always escalate with the time.

NOT BUILT, NOT DEPLOYED YET, OR NOT YET EXERCISED (do not promise these)
- Company-by-Company access: CORRECTED 2026-10-17. Return requests, complaints and Bills for Collection were scoped to their Company on 2026-10-07 (the sale and sales-order routes now also require the customer to belong to the Company), lists and reports filter by Company in the query (T15 M1a, 2026-10-09), and the Education Runtime credential is scoped, not All. All of that is in master and therefore in task definition :57; it has not been exercised in production with two businesses.
- Decimal quantities (7.5 hours): CORRECTED 2026-10-17. Built 2026-10-08 together with a customer reference and service period on the sale (see `SOP_Decimal_Quantity_And_Customer_Reference_SPUTO.md`). Not re-verified in production.
- Opening receivables (first-cohort scope, Femi 2026-10-15): bulk upload of what customers already owe at the anchor date is NOT built. Per `Opening_Figures_CSV_Upload_DDD_Design.md` it is a thin SOP use case, one itemised receivable per row, contra the Suspense account, built after GL balances, Fixed Assets and Stock.
- Waiting on Femi's answer: third-party payments (a payment made by someone other than the customer) and Discounts Given (SOP note 005dd1d), and the returns playbook. Nothing is built for them.
- VAT category by jurisdiction and period (see the VAT answer above): decided, not built. Per-line stock keys for a multi-line sale (T5) and the school-Company rule client are queued; the school-Company rule will ship switched OFF.
- Services beyond "invoice for work already delivered": no service period, deferred income (billing in advance), contract asset, milestones, outcome-based or project revenue, production orders. A service can be invoiced as an ordinary sale at billing time (acceptable for hourly work already done and for fixed-fee work on completion); do not use it to bill in advance. A customer PO reference or service period has no field; only the line description reaches the invoice.
- Delivery, bounce and complaint tracking for emailed invoices; the first real invoice email had not been sent when this was written.
- RMA notice emails to customers.
- School fee billing in SOP (billing accounts, fee schedules, bulk billing runs, per-school receipt numbers, payments allocated to invoices). Being designed (Epic 13); today fees and payments marked in the Education Runtime do NOT reach SOP or the ledger.
- Multiple businesses (Tenants) on one SOP deployment: the isolation code (T15 M1a, 2026-10-09: the Tenant is the one that owns the Company, answers byte-identical once a second Tenant has data) is built, but it has never run with a second real Tenant, so do not promise it as proven.
- Foreign-currency sales, price lists, quotes, discounts and promotions, and recurring invoices.
- Orders recorded before 2026-10-07 carry no reliable Company (the screen sent a random entity id), so they no longer appear in any list. They are legacy test data.
- Sales in countries without loaded VAT rates (see above).
- A way to give stock back automatically when a sale fails after stock was issued (being designed with Inventory).

BEFORE ESCALATING, COLLECT
The business and Company name, the person's sign-in email and their access at that Company, the exact error code and message, the invoice number or order id, the time it happened (with timezone), and for any email question the invoice number only (never paste the customer's address into a ticket unless asked).
