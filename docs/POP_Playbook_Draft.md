PURCHASE ORDER PROCESSING (POP) PLAYBOOK (draft for Omniview's Playbooks tab, service POP)

Written by the POP session, 2026-10-07, from the code on fish-purchase-order-processing master (commit f2817c6, the last merge, deployed). The nested-id security fix (d178982, merged b024f22) went live on 2026-10-07 after this was written; one related gap is still open, see the NOT BUILT list. Plain text so it can be pasted straight into the console. Everything below is what the code does TODAY. The last section lists what is NOT built or not deployed, so nobody promises it to a customer. Update this in the same change as the code it describes.

PLAYBOOK CONTENTS (per docs/Playbook_Definition.md)
1. Operator sheet: this document.
2. Scope: POP/docs/POP_MVP_Definition.md (written 2026-10-02; its "Enhancement" list is partly out of date, see "What was built since" in part 5 below) and docs/Purchase_Order_Processing_DDD_Design.md.
3. Plan / SRS: POP/docs/Purchase_Order_Processing_Requirements_Use_Cases.md (FR-PO01-08, NFR-PO01-05). There is no separate SRS file for POP; this document holds them.
4. Use cases: the same file (UC-PO1-7) and POP/docs/Procurement_Officer_Use_Cases.md.
5. Tasks and 6. Order: part 5 and part 6 at the end of this document. They were not written down anywhere before this draft; the cross-service items also live in docs/GL_POP_IM_SOP_Backlog.md.

OWNING SERVICE
Purchase Order Processing (repo fish-purchase-order-processing). The POP session is the L2 for anything below. POP posts every financial effect to the General Ledger (GL); stock effects go through Inventory Management (IM); who may do what comes from Enterprise Administration (EA). Deploys, task definitions and secrets belong to Configuration Management (CM), never to POP.

ESCALATE TO
Owner: the POP session. Deploy, environment-variable and secret problems: CM. Ledger problems (no open period, missing accounts, VAT rates): GL. Stock problems on a return: IM. "Cannot access" for a person: EA.

HELP ARTICLES
None written. Do not invent links; say so if asked.

HOW ACCESS WORKS
POP does not keep its own user list. For every call it asks EA who the person is and what they may do at the Company named in the URL.
- 401 unauthorized: no valid sign-in token. Ask them to sign out and in.
- 403 forbidden. Two reasons: "No active Membership in this deployment's Tenant" (they are not in the business this POP serves) and "This Membership is not granted POP access, at the required level, on this Company" (the Purchases module is not switched on for them at that Company, or they have READ only; every change needs WRITE). An administrator fixes either in EA.
- 503 service_unavailable: POP could not reach EA and refuses rather than guess. Retry in a minute, then escalate to CM.
- Every record is checked against the Company in the URL. A purchase order from another Company answers 404 purchase_order_not_found, never its contents.
- Warning, say it plainly: approving a purchase order needs only WRITE. There is no separation of duties: the person who submitted a purchase order for approval can approve it themselves. Do not tell a customer that approval is a control between two people.
- Supplier portal routes (/supplier-portal/...) do not use sign-in. They are gated by a link token sent to the supplier for one order.

THE LIFECYCLE (what each status means)
DRAFT created, not sent. PENDING_APPROVAL waiting for approval. APPROVED cleared to send. SENT transmitted to the supplier. PARTIALLY_RECEIVED / FULLY_RECEIVED goods recorded against the order. MATCHED the three-way match passed and the supplier obligation is recorded in the ledger. CLOSED paid. CANCELLED and AMENDED are final; an amended order is replaced by a new one. After goods have been received an order can no longer be amended, only cancelled and re-ordered.
Any step the status table does not allow answers 409 invalid_transition, with the reason.

COMMON QUESTIONS AND HOW TO ANSWER

Q: 409 approval_required when sending.
A: The Company has set an approval threshold in its purchase-order settings and this order's total is above it. Submit it for approval and approve it first, then send. If no threshold is configured, orders send straight from DRAFT, which is the default for every Company today. A threshold that cannot be compared with the order total (different currency) counts as exceeded.

Q: 409 supplier_inactive.
A: The supplier was deactivated. Reactivate it (suppliers/{id}/activate) or pick another supplier. Creating, amending and accepting a supplier proposal all check this.

Q: Three-way match: 400 missing_vat_category.
A: Every order line must carry a VAT category before it can be matched; the message names the line. A line created without one cannot be matched until the order is amended or re-created.

Q: Three-way match: 409 invalid_match.
A: The match is not allowed from the order's current status (it must be fully received) or the match came back MISMATCHED. Nothing was posted. If the Company has a match tolerance set and the request carried the supplier invoice's quantities and prices, POP works out the verdict itself: invoiced quantity is compared with what was RECEIVED, price with the ordered price, and a different currency is always a mismatch. If either is missing, the person's own MATCHED/MISMATCHED verdict is used.

Q: 409 posting_context_unavailable.
A: The ledger could not give POP the accounts or open period it needs. Most often the Company has no open accounting period. Nothing was recorded. The Company's accountant opens a period; missing accounts go to GL.

Q: gl_engine_call_failed (status is the ledger's own: 409 closed period, 400, 503).
A: The ledger refused or did not answer. For a match or a payment nothing is saved when this happens, and it can be retried once the cause is fixed.

Q: 409 facility_liability_account_not_configured when paying.
A: The payment is made by the bank on the deal's behalf and the Company's chart of accounts has no trade finance facility liability account (code 2300). Create it in GL. Nothing was posted.

Q: 409 invalid_payment.
A: The order is not in a status that can be paid (it must be MATCHED). Say plainly: any successful payment CLOSES the order and marks its invoice settled, even when the amount paid is less than the invoice. Partial payments are not tracked. A part-paid supplier invoice looks fully settled in POP; the ledger holds the true balance.

Q: What is the due-date aging report?
A: GET .../accounts-payable-due-date-aging lists supplier invoices not yet settled in buckets: CURRENT (not yet due, or up to 30 days overdue), 31-60, 61-90, over 90 days overdue. Invoices with no due date are shown as a separate total, never put in CURRENT. The due date is whatever the person typed when recording the match; POP does not work it out from payment terms. It measures due date, so it will not agree with the ledger's own payables aging, which uses posting date.

Q: PUT purchase-order-settings answers 400 invalid_settings.
A: The approval threshold is negative, or the match tolerance is not a fraction between 0 and 1 (so 0.05 means 5 percent, and 5 is refused); the message says which. Leaving a figure empty means "not enforced".

RETURNS OUTWARDS (sending goods back to a supplier)
Q: Steps?
A: REQUESTED, then APPROVED or REJECTED; APPROVED goes to DISPATCHED (stock leaves, ledger entry posted through IM), then CREDITED when the supplier's credit note is recorded. One step at a time. 409 quantity_unavailable: only that much is left to return on the line. 409 invalid_state: wrong step.
Q: 502/4xx im_call_failed on dispatch.
A: IMPORTANT, say this plainly. POP marks the return DISPATCHED BEFORE it calls Inventory. If the call to Inventory then fails, the return stays DISPATCHED, stock may or may not have left, and POP has no way to retry: pressing dispatch again answers invalid_state. Escalate with the return id and the purchase order id. Do not ask the customer to retry. Someone must check IM's stock and the ledger by hand. A fix is planned (see Tasks, T6) and is not built.
Q: Two people dispatch the same return at the same moment.
A: Only the status check stops it, and it is not locked, so in theory both could post stock. Rare; escalate any case of double stock movement.

RECEIVING GOODS
Q: What does receive-line do?
A: It records a quantity received against one order line, adds it to the running total, and moves the order to PARTIALLY_RECEIVED or FULLY_RECEIVED. It does NOT touch Inventory. The physical stock receipt is a separate call made to IM by whoever is receiving. Two separate calls mean POP's received quantity and IM's stock can disagree if only one of them was made. When a customer says stock and the order disagree, check both.
Q: Can a receipt be undone or corrected?
A: No. Receipts have no identity of their own, only a running total per line. A wrong receipt is corrected by raising a return or a discrepancy report, not by editing.

SUPPLIERS AND THE SUPPLIER PORTAL
Q: A supplier says their link does not work.
A: The link token is issued per order, at the moment the order is sent; there is no separate route to issue a new one, so a supplier with a lost or expired link cannot be given a fresh one today (not built). Ask for the order number and escalate to POP. The portal lets the supplier raise a negotiation proposal (a price or quantity change), a discrepancy report, or attach a waybill; every one waits for an internal person to accept, reject or acknowledge it.
Q: Accepting a negotiation proposal.
A: It amends the order, and if the Company has an approval threshold the amended order may need approval again (approval_required). A proposal can only be resolved once (invalid_state afterwards).
Q: Discrepancy reports.
A: OPEN, then ACKNOWLEDGED, then RESOLVED. A report raised by the supplier or by the Company looks the same in the list.

ERROR GLOSSARY
unauthorized - bad or missing sign-in. forbidden - signed in but not allowed (read the reason). service_unavailable - cannot reach EA. bad_request / invalid_request - something in the request is wrong; the detail names the field. invalid_transition / invalid_state - that step is not allowed from the current status. purchase_order_not_found / supplier_not_found / return_outwards_not_found / negotiation_proposal_not_found / discrepancy_report_not_found - no such record for this Company (it may belong to another Company or to another order). supplier_inactive - supplier deactivated. approval_required - over the approval threshold. invalid_replacement - an amend or accepted proposal does not make a valid order. invalid_supplier / invalid_purchase_order - creation failed validation. invalid_match / missing_vat_category - three-way match problems. invalid_payment / facility_liability_account_not_configured - payment problems. posting_context_unavailable - ledger accounts or period missing. gl_engine_call_failed - the ledger refused or is down. im_call_failed - Inventory refused or is down on a return dispatch. quantity_unavailable - return larger than what remains. invalid_settings - bad settings figure. internal_error - a bug; always escalate with the time.

NOT BUILT, NOT DEPLOYED YET, OR NOT YET EXERCISED (do not promise these)
- (Closed 2026-10-07, for the record.) Two gaps of one kind, both fixed and live. (1) Eight "nested" routes (accept/reject a negotiation proposal, acknowledge/resolve a discrepancy report, approve/reject/dispatch/credit a return) used to let a person with write access in one Company act on another Company's record by pairing it with a purchase order of their own: fixed in d178982, merged b024f22. (2) Supplier activate/deactivate, creating a purchase order and recording an opening payable looked a supplier up by id alone, so another Company's supplier could be changed or used: fixed in beedd7f, merged 55162f2. A record from another Company now answers exactly like a missing one. Still open, same class: the ownership checks for the eight nested routes sit in the routes only, not inside the use cases (P0-1c); a future route could forget them.
- Protection against a double click or retry on any POP route (no Idempotency-Key anywhere): two identical create, match or pay requests are handled as the order's status allows, nothing more. A planned fix for return dispatch is T6 below.
- A retry path or posted marker for a return whose dispatch failed at Inventory (see above).
- Per-receipt identity, receipt corrections, and any link between a POP receipt and the IM stock receipt.
- Partial payments of a supplier invoice; separation of duties on approval; facility-utilisation calculation against the bank's facility terms; multiple invoices per order (an order has one match and so at most one invoice record).
- Multi-currency orders and any currency conversion.
- Supplier and item codes (suppliers have no code field), and a CSV bulk upload layer; only the single-row opening-figure use case for payables exists.
- Emails to suppliers of any kind from POP.
- Cross-tenant purchase orders (one tenant's order becoming another's sales order): vision only, not built.
- Metrics, tracing and rate limiting (platform-wide; see docs/GL_Production_Readiness_Assessment.md).
- A "pending approval" list: the pending-action route lists orders needing a next step, but POP cannot list orders by every status on its own; WEB must not assume it can.

BEFORE ESCALATING, COLLECT
The business and Company name, the person's sign-in email and their access at that Company, the exact error code and message, the purchase order id (or return id), the time it happened with timezone, and for any money or stock question both the POP order status and what the ledger or Inventory shows.

----------------------------------------------------------------------
PART 5 - TASKS (POP, as of 2026-10-07)

What was built since POP_MVP_Definition.md (2026-10-02), all merged and deployed on master f2817c6:
- Approval threshold, configurable per Company (settings route; default: no threshold, current behaviour).
- VendorInvoice record created at three-way match (invoice reference, amount, caller-supplied due date, settled flag).
- AP aging by due date.
- Match tolerance with an automatic verdict when invoice figures are supplied.
- Rename of vendorId to supplierId across POP's own API.
Their one known weakness (partial payment closes the order) is listed above.

OPEN TASKS
- P0-1 DONE 2026-10-07: nested-id ownership gate (d178982, merged b024f22) and the supplier ownership gate (beedd7f, merged 55162f2), both deployed.
- P0-1c Move the nested-id ownership checks inside the use cases as well (defence in depth), so a new route cannot forget the guard. POP owns it; CM approved 2026-10-07; in progress.
- P0-2 Check the same shape in SOP and IM: any route with a nested id under a parent path id (looked up by its own id alone). Asked of both on 2026-10-07; their own sessions own the check.
- T6 Goods-issue idempotency on Return Outwards dispatch (cross-service with IM, task owner POP):
    a. Send Idempotency-Key = return-outwards:{companyId}:{returnOutwardsId} on the recordGoodsIssue call (IM's contract, docs/IM_Goods_Issue_Idempotency_SPUTO.md).
    b. Persist the IM journal-entry id and a posted marker on the return (new migration, next free version, expected V14).
    c. Add a retry path: dispatch on a DISPATCHED-but-unposted return re-sends the same key instead of failing with invalid_state.
    d. Close the concurrent-dispatch race (claim the return before calling IM).
    Ships only after IM has deployed and verified its side. Needs a row in docs/GL_POP_IM_SOP_Coordination.md before the first line is written.
- T7 Match and payment idempotency (own key per match and per payment; GL's Idempotency-Key already exists on its record routes).
- T8 Partial supplier payments: track amount paid against the invoice, close the order and settle the invoice only when covered.
- T9 Separation of duties on approval: approver must differ from submitter, or a stricter access level than WRITE. Needs Femi's decision; it changes who can approve.
- T10 Reconcile POP's received quantity with IM's stock receipt (detect drift, or have one call do both). Needs a design decision with IM.
- T11 Supplier and Item code fields, then bulk CSV opening-figure routes (docs/Opening_Figures_CSV_Upload_DDD_Design.md; platform-wide).
- Parked, not mine: NFR-PO05 facility headroom (needs the bank's terms), GL's suspenseAccountId in purchase-posting-context.

PART 6 - ORDER (foundations before features)
1. P0-1 and P0-2 first: closing the cross-Company gap comes before anything new.
2. T6 (idempotency and retry on the one place POP calls IM) after IM's own idempotency deploys; then T7. These are foundations for any money or stock feature and go before T8 to T11.
3. T8 (partial payments) before T9: payment correctness before control changes, and T8 needs no decision.
4. T9 once Femi decides who may approve.
5. T10 after IM and POP agree one owner for the receipt.
6. T11 last; it depends on the platform-wide import layer.
