SALES ORDER PROCESSING (SOP) PLAYBOOK (draft for Omniview's Playbooks tab, service SOP)

Written by the SOP session, 2026-10-07, from the code on fish-sales-order-processing master (commit a83581d, deployed as task definition fish-sales-order-processing:40, and :41 since the invoice-email switch-on that day). Plain text so it can be pasted straight into the console. Everything below is what the code does TODAY. The last section lists what is NOT built, not deployed yet, or not yet exercised, so nobody promises it to a customer. Re-check the date before trusting an answer, and update this when the code changes. Where this says "not verified in production", the code does it but nobody has watched it happen live.

PLAYBOOK CONTENTS (see docs/Playbook_Definition.md; a playbook is this sheet PLUS the SPUTO set)
1. Operator sheet: this document.
2. Scope: SOP/docs/SOP_MVP_Definition.md (in the SOP repo).
3. Plan / SRS: SOP/docs/Sales_Order_Processing_Requirements_Use_Cases.md, docs/Sales_Order_Processing_DDD_Design.md, SOP/docs/Trade_Finance_Collection_Software_Requirements_Specification.md, docs/Sales_Processing_Requirements_Specification.md.
4. Use cases: SOP/docs/Sales_Order_Processing_Requirements_Use_Cases.md (UC-SO1 to 7), SOP/docs/Trade_Finance_Collection_Use_Cases.md.
5. Tasks: SOP/docs/Trade_Finance_Collection_Backlog.md, docs/GL_POP_IM_SOP_Backlog.md, docs/IM_Goods_Issue_Idempotency_SPUTO.md.
6. Order: docs/GL_POP_IM_SOP_Backlog.md (dependency-ordered waves), docs/Fee_Billing_Epic13_SPUTO_Scope.md (school billing, SOP half in progress).
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
Fact for the operator: SOP serves ONE business (Tenant) per deployment today. A person who belongs to a different business than the one this SOP is wired to always gets "No active Membership in this deployment's Tenant", however senior they are.

COMMON QUESTIONS AND HOW TO ANSWER

RECORDING A SALE (POST /api/sales)

Q: "lines[0]: vatCategory is required" (400).
A: Every sale line must carry a VAT category: STANDARD, REDUCED, SECOND_REDUCED, SUPER_REDUCED, ZERO_RATED or EXEMPT. This has been required since 2026-09-20 and there is no default; the seller must choose. A screen that does not send it will fail on every sale.

Q: "vat_category_not_supported" or "no_vat_rate_schedule".
A: The ledger decides which VAT categories exist for the Company's country. Ireland has five bands and the UK has three, plus EXEMPT; asking for a band the country does not have is refused. A country with no VAT rates loaded (Sierra Leone is seeded but not verified; Liberia, Guinea, Cote d'Ivoire and Nigeria have none) cannot record ANY sale until its rates are verified: the ledger answers 409 no_vat_rate_schedule whatever category is sent. This is not a SOP fault and the customer cannot fix it. Escalate to GL with the Company's country.

Q: "posting_context_unavailable" (often 409 no_open_period).
A: The ledger could not give SOP the accounts and open period it needs. Most often the Company has no open accounting period, or a required account (receivables, revenue, VAT) is missing. Nothing was recorded. Ask the Company's accountant to open a period; if accounts are missing, escalate to GL.

Q: "gl_engine_call_failed".
A: The ledger refused or did not answer. The status is the ledger's own (409 closed period, 400 bad request, 503 down). IMPORTANT, say this plainly: a sale that fails at this step can still leave an order in the Sales list, marked invoiced, with NO ledger posting. Do not tell the customer it is posted. Escalate with the order id; do not ask the customer to simply retry, because today a retry makes a second order (see "double click" below).

Q: "stock_check_failed" or "item_has_no_selling_price".
A: A line tied to a stock item could not be checked or issued at Inventory Management (item unknown, not enough stock, IM down), or the item has no selling price set. Fix the item in Inventory first. Stock lines are issued BEFORE the ledger posting; if the sale then fails, the stock has already been issued. Escalate such cases so someone checks stock.

Q: The customer clicked twice, or the request timed out, and now there are two sales.
A: Today there is NO protection against that: two identical requests are two sales. A fix (a client "Idempotency-Key" on sales and collections) is built and waiting for review and deployment, and the screen sending it is held back until then. Even once deployed it only protects a screen that sends the key, and a retried sale with stock-tracked lines can still issue the stock twice until Inventory makes its issue idempotent (being built). Until it is deployed there is no quick undo: an ordinary sale is invoiced and posted the moment it is recorded, so the duplicate cannot be cancelled; the correction is a credit note through the returns flow. Escalate rather than improvising.

Q: What does the status mean?
A: Sales (ordinary) go straight to INVOICED when recorded. INVOICED means billed and not paid. PARTIALLY_COLLECTED means some money has been recorded, COLLECTED means paid in full. Other statuses (DRAFT, AVAL_CONFIRMED, FULFILLED...) belong to the trade-finance order flow. CANCELLED is final.

Q: "Collection currency GBP does not match the order's own currency USD", or "Cannot record a collection from status X".
A: A collection must be in the order's own currency, and only an invoiced or part-collected order accepts one. An already fully collected order refuses more ("order_not_ready_to_collect"). Check the order's status and currency.

Q: How is "paid in full" decided?
A: Against the amount the ledger actually debited to receivables, which is the net total PLUS VAT (the "gross"), when the ledger has reported it. Older sales have no gross recorded and are judged against the net total as before. A customer who pays only the net on a taxed sale therefore stays part-collected, correctly. If someone insists a fully paid sale shows part-paid, check whether VAT was added.

CASH SALES (saleMethod CASH)
Q: Can customers take cash sales through SOP?
A: The route is deployed but NOT switched on in any screen yet (as of 2026-10-07). It records the sale and the full cash payment together. Do not promise it. When it is live: a customer is always required (there is no pooled walk-in customer in SOP), the Company must have a cash account (code 1000), and a "409 cash_account_not_configured" means nothing was posted because the Company has none. A "502 sale_recorded_not_collected" means the sale exists and is invoiced but the cash step did not complete; the screen finishes it through the collections route using the amounts in the message. "gross_amount_unknown" means the ledger did not report the amount to collect: contact support, no retry.

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
Q: A customer with no email can't be emailed an invoice.
A: The email goes to whatever address the person types; the customer's stored email is not required.

TRADE FINANCE (BILL FOR COLLECTION, FACILITY HEADROOM)
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
- Protection against a double click or retry creating two sales (built, in review, not deployed; stock-line retries also need Inventory's own fix, in progress).
- Fixes built and in review, NOT deployed: a refused ledger post will no longer leave an invoiced order behind, and the Sales list, order lookup, collections and cancel will be limited to the Companies the caller may use. Until they deploy, the two behaviours described in this sheet (phantom order after a failed sale; the Sales list showing every Company) still happen. Orders recorded before the fix carry no reliable Company and will disappear from lists when it deploys (they are legacy test data).
- Cash sales on any screen (route deployed, no screen uses it yet).
- Delivery, bounce and complaint tracking for emailed invoices; the first real invoice email had not been sent when this was written.
- RMA notice emails to customers.
- School fee billing in SOP (billing accounts, fee schedules, bulk billing runs, per-school receipt numbers, payments allocated to invoices). Being designed (Epic 13); today fees and payments marked in the Education Runtime do NOT reach SOP or the ledger.
- Multiple businesses (Tenants) on one SOP deployment.
- Foreign-currency sales, price lists, quotes, discounts and promotions, and recurring invoices.
- A list that is limited to one Company: the Sales list returns every Company in the business to anyone who can read Sales. Do not treat it as Company-private.
- Sales in countries without loaded VAT rates (see above).

BEFORE ESCALATING, COLLECT
The business and Company name, the person's sign-in email and their access at that Company, the exact error code and message, the invoice number or order id, the time it happened (with timezone), and for any email question the invoice number only (never paste the customer's address into a ticket unless asked).
