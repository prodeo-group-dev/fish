PURCHASE ORDER PROCESSING (POP) PLAYBOOK (draft for Omniview's Playbooks tab, service POP)

Written by the POP session, first 2026-10-07, REVIEWED 2026-10-15 against that day's decisions (Prodeo is a landlord, Discounts Received, the product VAT category) and against the code on fish-purchase-order-processing master a05acfa, live as task definition :47 (the T15 multi-Tenant slice, T7 GL-first posting with order-id keys, T6 return-dispatch retry, the VAT category on every line, the contract fixtures, and Prodeo-is-a-landlord stage 1). THREE POP changes are ready but NOT live yet and are marked where they apply: the line item link (V19), the trade discount on a line (V20) and the consumer-side posting-context field; treat them as not live until CM says so. UPDATED 2026-10-16: live since this review are the line item link (V19), the trade discount on a line (V20), the discount on the invoice total (V21) (all POP :50) and T8 partial supplier payments (V22, POP :51). BUILT BUT NOT LIVE as this is written: the supplier credit note of kind DISCOUNT or REBATE (T-D5, V23; it is released only after the ledger's own route is live) and the pass-through of Inventory's error code on a refused return dispatch (releasing). Where this text says NOT LIVE below, read it against this paragraph first. Plain text so it can be pasted straight into the console. Everything below is what the code does TODAY unless it says NOT LIVE. The last section lists what is NOT built or not deployed, so nobody promises it to a customer. Update this in the same change as the code it describes.

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
- 403 forbidden. Three reasons you will see: "This Company is not listed in any of your Memberships" (none of the person's businesses lists the Company in the URL: they are in the wrong business or the wrong Company; EA fixes it); "This Company is listed under more than one of your Memberships; refusing to guess which applies" (an ambiguous mapping; escalate to EA, it should not happen); and "This Membership is not granted POP access, at the required level, on this Company" (the Purchases module is not switched on for them at that Company, or they have READ only; every change needs WRITE). An administrator fixes the last in EA.
- 503 service_unavailable: POP could not reach EA and refuses rather than guess. Retry in a minute, then escalate to CM.
- Every record is checked against the Company in the URL. A purchase order from another Company answers 404 purchase_order_not_found, never its contents.
- Warning, say it plainly: approving a purchase order needs only WRITE, and the same person can submit and approve their own order. Do not tell a customer that approval is a control between two people. What changed on 2026-10-08: POP now records WHO did every create, submit, approve, send, match, payment and return step in an audit log (see "Who did this?" below), so it can be answered after the fact, even though it is not yet prevented. Separation of duties (T9b) waits for the platform capability model and Femi's decisions.
- POP serves any number of businesses (Tenants) at once since 2026-10-10. It no longer has one configured Tenant: for each request it uses the person's Membership that lists the Company in the URL, exactly one match, no fallback to a default. Every record is also tied to its Company, and a record of another Company, in the same business or another, answers 404 exactly like a missing one. Two Companies owned by the same person are separate: a list, a number or a record from one never appears under the other.
- Supplier portal routes (/supplier-portal/...) do not use sign-in. They are gated by a link token sent to the supplier for one order.

THE LIFECYCLE (what each status means)
DRAFT created, not sent. PENDING_APPROVAL waiting for approval. APPROVED cleared to send. SENT transmitted to the supplier. PARTIALLY_RECEIVED / FULLY_RECEIVED goods recorded against the order. MATCHED the three-way match passed and the supplier obligation is recorded in the ledger. CLOSED paid. CANCELLED and AMENDED are final; an amended order is replaced by a new one. After goods have been received an order can no longer be amended, only cancelled and re-ordered.
Any step the status table does not allow answers 409 invalid_transition, with the reason.

COMMON QUESTIONS AND HOW TO ANSWER

Q: What is the PO number?
A: Each purchase order has a number like PO-000123, counted per Company (each Company starts at PO-000001), taken when the order is first saved and never changed. An amended order's replacement gets its own new number. Orders that existed before 2026-10-08 were numbered per Company in id order, not creation order, so their numbers may not follow the dates. The long id is still the key in every URL.

Q: Who did this? Who created, approved or paid this order?
A: POP keeps an append-only audit log in its database (pop_audit_log): one row for every save of a purchase order, return, supplier, vendor invoice, negotiation proposal, discrepancy report or purchase-order settings, with the person (EA's user id and email, or a supplier-portal link for a supplier action), the Company, what happened (CREATED, then the new status) and the time; a settings change also records the threshold and tolerance before and after. There is NO screen or API to read it yet: only the POP session can answer, from the database, so escalate with the order number and the question. The database refuses to change or delete these rows. Records made before 2026-10-08 have no rows. If a request ever answers 500 and the log shows AUDIT_ACTOR_MISSING, a route saved something without knowing who asked: a POP bug, escalate.

Q: 409 approval_required when sending.
A: The Company has set an approval threshold in its purchase-order settings and this order's total is above it. Submit it for approval and approve it first, then send. If no threshold is configured, orders send straight from DRAFT, which is the default for every Company today. A threshold that cannot be compared with the order total (different currency) counts as exceeded.

Q: 409 supplier_inactive.
A: The supplier was deactivated. Reactivate it (suppliers/{id}/activate) or pick another supplier. Creating, amending and accepting a supplier proposal all check this.

Q: 400 missing_vat_category (on create, amend, accepting a proposal, or at the three-way match).
A: Every order line must carry a VAT category, and since 2026-10-11 (POP :39) POP asks for it when the order is CREATED or AMENDED, not only at the match: the answer names the line (zero-based, so line 0 is the first). The accepted values are STANDARD, REDUCED, SECOND_REDUCED, SUPER_REDUCED, ZERO_RATED and EXEMPT; which of them a Company may use depends on its country and GL decides (an unsupported one is refused at posting as vat_category_not_supported). POP never picks one for the person, because a wrong default puts wrong input VAT in the ledger. Orders made before this rule may still have lines with no category: give each one its category with POST .../purchase-orders/{id}/lines/{lineIndex}/vat-category (WRITE; only the category changes, never the price, quantity or total). That route works on any order that is not yet matched, closed, cancelled or amended; after the match it answers 409 invalid_state, because the category is by then part of what was posted. Each change is recorded in the audit log with the before and after ("line 0 vatCategory: none -> STANDARD"). Accepting a proposal on an older order that still has an uncategorised line answers 400 missing_vat_category and changes nothing: set the category on the order first.

Q: Who decides whether a purchase is VATable?
A: Today the person ordering, per line. Femi's decision (2026-10-11) is that the product decides, with IM owning the product: IM is designing an Item VAT category, and a line with an item will then be pre-filled from it (visible and overridable) while a line with no item, such as a service, still chooses explicitly. Not built yet; POP changes nothing until Femi approves IM's plan.

Q: Three-way match: 409 invalid_match.
A: The match is not allowed from the order's current status (it must be fully received) or the match came back MISMATCHED. Nothing was posted. If the Company has a match tolerance set and the request carried the supplier invoice's quantities and prices, POP works out the verdict itself: invoiced quantity is compared with what was RECEIVED, price with the ordered price, and a different currency is always a mismatch. If either is missing, the person's own MATCHED/MISMATCHED verdict is used.

Q: The match or the payment timed out or failed. Can pressing it again post twice?
A: Not by accident. A match sends the ledger ONE key per order (po-match:{order}); a payment sends po-pay:{order} for the first payment of the order and po-pay:{order}:{n} for the nth (T8), n being the payments already recorded plus one; so an identical retry after a lost reply or a failed save returns the SAME journal entry instead of posting again, and two simultaneous presses post once (POP runs one instance and its lock lives in that process; if a second instance ever runs, the database's unique index on (order, payment number) is what stops a duplicate payment, and the ledger's own claim-first lock, which does not exist yet, would be needed for the rest). A payment can also carry a paymentReference of the caller's own (one per payment form): the same reference again returns the first payment instead of recording a second, even after the order has closed, so a double click or a retry after a lost reply is safe; without a reference two identical requests are two payments, so every payment screen should send one. A retry that CHANGED the date or an account after a post that POP could not save is refused 422 idempotency_key_reused and posts nothing, never a second entry; resubmit the same values. Order creation, sending, receiving and the return steps (apart from the dispatch, below) have no such key.

Q: 409 posting_context_unavailable.
A: The ledger could not give POP the accounts or open period it needs. Most often the Company has no open accounting period. Nothing was recorded. The Company's accountant opens a period; missing accounts go to GL.

Q: gl_engine_call_failed (status is the ledger's own: 409 closed period, 400, 503).
A: The ledger refused or did not answer. Since 2026-10-10 (T7) a match or a payment posts to the ledger FIRST and records its own state only when the ledger accepts, so on a refusal, an error or a timeout NOTHING is saved and the same request can be tried again once the cause is fixed. Two cautions. (1) An order that was matched BEFORE T7 and refused at the ledger may be stuck in MATCHED with no journal entry and no invoice; do not pay it. Prodeo has no role in a Tenant's data and does not edit it, so this is recovered on the Tenant's side by its own Owner Admin or accountant (the order is theirs); nobody at Prodeo resets it in a database. The recovery route for a Tenant's own administrator is not built yet (see the task list), so until then such an order is left as it is. (2) The posting key is the order itself (po-match:{order} / po-pay:{order}, since 2026-10-11) and the ledger remembers only SUCCESSFUL answers, so a refusal never blocks a corrected retry: fix the cause (or change the date, the period or the accounts) and submit again. The one case that differs: if the ledger DID post but POP could not save (rare, a database failure at that moment), an identical retry finishes the order with the original journal entry, but a retry that changed anything is refused 422 idempotency_key_reused, because the ledger refuses a second entry under the same order. Tell the person: this order was already posted, resubmit exactly the same values, and if that is refused too (for example the period moved on), contact your administrator: the Tenant's own Owner Admin or accountant decides what to do with the order. Prodeo does not change a Tenant's records. Reversing the ledger entry does NOT free the key.

Q: Who pays the supplier, and what is "executingParty"?
A: The Tenant pays its own supplier from its own cash or bank account. Prodeo has no role in a Tenant's purchase orders, payments or accounts, and is not in the business of providing trade finance (Decisions Log 2026-10-15). executingParty is OPTIONAL: absent means TENANT (the Tenant pays from its own cash or bank, the ledger entry is Dr Accounts Payable / Cr the cash or bank account). The old values PRODEO and BANK are still accepted and mean TENANT and TENANT_LENDER. TENANT_LENDER means the Tenant's OWN lender (whichever bank or financier the Tenant chose) pays the supplier under the Tenant's facility; it needs a lenderConfirmationReference (the old bankConfirmationReference still works), settles against the Tenant's own facility liability account, is off by default and is NOT offered in the screens. An unknown value is 400.
Q: What is prodeoRole on a purchase order?
A: A leftover. A purchase order no longer needs a role and the field is ACCEPTED AND IGNORED on create (even a meaningless value); the answer always shows prodeoRole as null. Nothing reads it. It is removed in stage 2, after the screens stop sending it. If a customer asks "what is my Prodeo role", the answer is that Prodeo has none.
Q: 409 facility_liability_account_not_configured when paying.
A: Only when the payment was marked TENANT_LENDER (the Tenant's own lender paid under its facility) and the Company's chart of accounts has no facility liability account (code 2300, the Tenant's own liability). Create it in GL. Nothing was posted. An ordinary payment never needs it.

Q: 409 invalid_payment.
A: The order is not in a status that can be paid (it must be MATCHED). Also 409 invalid_payment when the payment is in a different currency from what is owed. Since T8 (live, 2026-10-16) a payment may be LESS than what is owed. What is owed is the vendor invoice's NET amount (after any discount on the invoice total), or the order total when there is no invoice. Each payment that reaches the ledger is recorded; the order stays MATCHED and the invoice unsettled until the recorded payments cover what is owed, and then both close. The answer says paymentNumber, amountPaid, amountOutstanding and fullyPaid. GET .../purchase-orders/{id}/payments lists them in order.

Q: 409 payment_exceeds_balance.
A: The payment is more than what is still owed on the order (the message says how much). Nothing was sent to the ledger. Pay the outstanding amount or less.

Q: 409 payment_reference_reused.
A: That paymentReference was already used on this order for a payment of a different amount. Use a new reference for a new payment; send the same reference and amount only to repeat the same payment.

Q: What is the due-date aging report?
A: GET .../accounts-payable-due-date-aging lists supplier invoices not yet settled in buckets: CURRENT (not yet due, or up to 30 days overdue), 31-60, 61-90, over 90 days overdue. Invoices with no due date are shown as a separate total, never put in CURRENT. The due date is whatever the person typed when recording the match; POP does not work it out from payment terms. A part-paid invoice is aged only on what it still owes (T8). It measures due date, so it will not agree with the ledger's own payables aging, which uses posting date.

Q: PUT purchase-order-settings answers 400 invalid_settings.
A: The approval threshold is negative, or the match tolerance is not a fraction between 0 and 1 (so 0.05 means 5 percent, and 5 is refused); the message says which. Leaving a figure empty means "not enforced".

RETURNS OUTWARDS (sending goods back to a supplier)
Q: Steps?
A: REQUESTED, then APPROVED or REJECTED; APPROVED goes to DISPATCHED (stock leaves, ledger entry posted through IM, but ONLY for a line that has an inventory item, see the next answer), then CREDITED when the supplier's credit note is recorded. One step at a time. 409 quantity_unavailable: only that much is left to return on the line. 409 invalid_state: wrong step.
Q: 502/4xx im_call_failed on dispatch.
A: POP marks the return DISPATCHED before it calls Inventory. If the call fails, the return stays DISPATCHED and pressing dispatch again RETRIES it (since T6, live): the same date, the same account and the same key go to Inventory, so it completes or replays the one posting instead of moving stock twice; a return that was already posted answers with its stored journal entry and calls nothing. A return refused because its date's period is closed needs the period reopened (the stored date cannot change). A return dispatched before T6 has no stored details and still answers invalid_state: escalate it.
Q: A return was dispatched but IM shows no stock movement (inventoryNotPostedReason line_has_no_inventory_item).
A: IMPORTANT, say this plainly. POP did not save a purchase line's inventory item link until the V19 change (NOT LIVE as of this review): every order read back from the database had NO item on its lines, so a return dispatch finished in POP and posted NOTHING to Inventory, with no error. After V19 deploys, a return of a line WITH an item posts Dr Accounts Payable / Cr Inventory through Inventory exactly once; orders created BEFORE V19 keep no item link and their returns still post nothing to Inventory (nothing is backfilled, nobody edits a Tenant's data), and a service or one-off line has none by nature. Since V19 the dispatch answer says why in inventoryNotPostedReason and POP logs a warning. For such an order the stock and the ledger must be adjusted on the Tenant's side by whoever owns that stock.
Q: Two people dispatch the same return at the same moment.
A: The second press either finds it already DISPATCHED and retries with the same key, or reaches Inventory with the same key; Inventory answers the second with the first one's result, so stock should move once. Escalate any case of double stock movement.

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
unauthorized - bad or missing sign-in. forbidden - signed in but not allowed (read the reason). service_unavailable - cannot reach EA. bad_request / invalid_request - something in the request is wrong; the detail names the field. invalid_transition / invalid_state - that step is not allowed from the current status. purchase_order_not_found / supplier_not_found / return_outwards_not_found / negotiation_proposal_not_found / discrepancy_report_not_found - no such record for this Company (it may belong to another Company or to another order). supplier_inactive - supplier deactivated. approval_required - over the approval threshold. invalid_replacement - an amend or accepted proposal does not make a valid order. invalid_supplier / invalid_purchase_order - creation failed validation. invalid_match / missing_vat_category - three-way match problems. invalid_payment / payment_exceeds_balance / payment_reference_reused / facility_liability_account_not_configured - payment problems. credit_note_reference_reused / invalid_credit_note / discounts_received_account_not_configured - supplier credit note (T-D5, not live yet). On a refused return dispatch the answer is im_call_failed with imErrorCode, Inventory's own code: invalid_issue means not enough stock on hand (a decision, nothing was posted), item_busy and idempotency_key_in_progress mean try again with the same request. posting_context_unavailable - ledger accounts or period missing. gl_engine_call_failed - the ledger refused or is down. im_call_failed - Inventory refused or is down on a return dispatch (see imErrorCode). quantity_unavailable - return larger than what remains. invalid_settings - bad settings figure. internal_error - a bug; always escalate with the time. invalid_vat_category - the value is not one of the six; missing_vat_category - a line has no category (create, amend, accept a proposal, or match); line_not_found - no line at that index on the order.

NOT BUILT, NOT DEPLOYED YET, OR NOT YET EXERCISED (do not promise these)
- (Closed 2026-10-07, for the record.) Two gaps of one kind, both fixed and live. (1) Eight "nested" routes (accept/reject a negotiation proposal, acknowledge/resolve a discrepancy report, approve/reject/dispatch/credit a return) used to let a person with write access in one Company act on another Company's record by pairing it with a purchase order of their own: fixed in d178982, merged b024f22. (2) Supplier activate/deactivate, creating a purchase order and recording an opening payable looked a supplier up by id alone, so another Company's supplier could be changed or used: fixed in beedd7f, merged 55162f2. A record from another Company now answers exactly like a missing one. (3) The same ownership check for those eight routes now also sits inside the five use cases behind them (effdcd1, merged 1a5f555, deployed as task definition :30), so a future route cannot forget it.
- Protection against a double click or retry on routes other than match and payment (no Idempotency-Key on create, send, receive-line or the return steps): two identical requests are handled as the order's status allows, nothing more. Match and payment are protected since 2026-10-10 (see above). A planned fix for return dispatch is T6 below.
- Inventory postings for returns of orders created before the item link was stored (V19, live since :50) and for lines with no item: they post nothing to Inventory (see above).
- Discounts Received (decided 2026-10-15, docs/POP_Discounts_Received_SPUTO.md): LIVE are the trade discount on a line (list price kept for display, the net posted; V20) and the discount on the invoice total at the match (spread across the lines, net lines posted; V21). BUILT, NOT LIVE: the supplier credit note of kind DISCOUNT (a price allowance) or REBATE (a volume reward), recorded only after the ledger accepts (V23), released after the ledger's own route is live; the VAT is the ledger's to compute, input VAT falls by exactly the credit note's VAT, at the rate of the ORIGINAL purchase date (Femi, 2026-10-16). NOT BUILT: the early-payment (settlement) discount (waits for Femi to read its VAT SPUTO), accruing an expected rebate, bonus goods, price lists, the reports of discounts received and lost.
- The VAT category coming from the Inventory item (Femi 2026-10-14: Inventory owns it): not live. Today the category is typed on every purchase line and corrected through the set-category route; reading it from the item at order time is gated on Inventory shipping it.
- Per-receipt identity, receipt corrections, and any link between a POP receipt and the IM stock receipt.
- A screen or API to read the audit log; any rule that stops the creator approving or paying their own order (T9b); approval or separation of duties for the three-way match, payment and return approval (decisions with Femi, T9c).
- Company keys inside every query: today the isolation between Companies and between businesses is enforced in POP's routes and use cases and proven by a test suite that covers every company-scoped route for both walls, not by the database. There is no row-level security, and the child tables (waybills, proposals, reports, returns) have no Company column of their own (planned hardening, T15 M2).
- A real-world run of the second-business path: the multi-Tenant slice is live and tested, but the first real run is the combined UAT sitting. GL's per-service endpoint allow-list for POP's three calls has not yet carried real traffic.
- Separation of duties on approval; facility-utilisation calculation against the bank's facility terms; multiple invoices per order (an order has one match and so at most one invoice record).
- Multi-currency orders and any currency conversion.
- Supplier and item codes (suppliers have no code field), and a CSV bulk upload layer; only the single-row opening-figure use case for payables exists.
- Emails to suppliers of any kind from POP.
- Cross-tenant purchase orders (one tenant's order becoming another's sales order): vision only, not built.
- Metrics, tracing and rate limiting (platform-wide; see docs/GL_Production_Readiness_Assessment.md).
- A "pending approval" list: the pending-action route lists orders needing a next step, but POP cannot list orders by every status on its own; WEB must not assume it can.

BEFORE ESCALATING, COLLECT
The business and Company name, the person's sign-in email and their access at that Company, the exact error code and message, the purchase order id (or return id), the time it happened with timezone, and for any money or stock question both the POP order status and what the ledger or Inventory shows.

----------------------------------------------------------------------
PART 5 - TASKS (POP, as of 2026-10-15)

What was built since POP_MVP_Definition.md (2026-10-02), merged and deployed (POP :36, master 52d01cd):
- Approval threshold, configurable per Company (settings route; default: no threshold, current behaviour).
- VendorInvoice record created at three-way match (invoice reference, amount, caller-supplied due date, settled flag).
- AP aging by due date.
- Match tolerance with an automatic verdict when invoice figures are supplied.
- Rename of vendorId to supplierId across POP's own API.
- Audit log (T9a, 2026-10-08): who did every create, approval, payment and return step, in the same transaction as the change; hardened with timezone-aware times and database-enforced append-only (V14, V15).
- Human PO numbers PO-000123, per Company (V16, 2026-10-08).
- VAT category (2026-10-11, POP :38 and :39): the set-a-line's-VAT-category route, each order line now shows its category, and a category is required on every line of a new or amended order.
- Multi-Tenant slice (T15 P1 to P4, 2026-10-10): each request is authorized by the Membership that lists the Company in the URL (no configured Tenant), the Tenant of that Membership goes to GL on every call, the unscoped returns finder is gone, and a two-business, two-wall isolation suite covers every company-scoped route.
Their one known weakness (a part payment closed the order) was fixed by T8, live 2026-10-16.

OPEN TASKS
- P0-1 DONE 2026-10-07: nested-id ownership gate (d178982, merged b024f22) and the supplier ownership gate (beedd7f, merged 55162f2), both deployed.
- P0-1c DONE 2026-10-07: the nested-id ownership checks also sit inside the use cases (effdcd1, merged 1a5f555, live as :30 after CM re-triggered the build with an empty commit, 22da11e).
- P0-2 Check the same shape in SOP and IM: any route with a nested id under a parent path id (looked up by its own id alone). Asked of both on 2026-10-07; their own sessions own the check.
- Item VAT category (Femi, 2026-10-11): IM owns the product and will hold its VAT category; POP's use cases go into IM's plan and POP builds nothing until Femi approves it.
- T6 Goods-issue idempotency on Return Outwards dispatch: BUILT and HELD (branch feature/return-dispatch-idempotency, migration V17, rebased on the T15 work) until IM's real-token verification of its side. Sends Idempotency-Key = return-outwards:{companyId}:{returnOutwardsId}, stores the date and contra account of the first attempt so a retry sends an identical request, stores IM's journal-entry id as the posted marker, and lets a DISPATCHED-but-unposted return be retried. Known limit: the stored date cannot change, so a return refused because that date's period is closed needs the period reopened. Until it ships, a failed IM call on dispatch is not retryable (see the Returns section).
- T7 DONE 2026-10-10 (POP :37): match and payment post to the ledger first with an Idempotency-Key (since 2026-10-11 the order id only: po-match:{id}, po-pay:{id}; the earlier request hash let a changed retry after a crash post a second entry) and record their own state only on success; a per-order lock; no migration. Open on the ledger side, queued by CM: cache only successful answers, and a claim-first lock.
- Record-existing-posting (Tenant-administrator route, ~1.5 days, NOT BUILT, parked by CM 2026-10-11): completes a stuck order (the ledger posted, POP could not save, and the retry now has to differ) by recording the existing journal entry id on the order without calling the ledger. CORRECTED 2026-10-15 (Femi: Prodeo is a landlord and has NO role in its Tenants' data): this is NOT a Prodeo operator route and Prodeo support never edits Tenant data in a database. If it is ever built it is a route for the Tenant's OWN Owner Admin or accountant (audited, with the journal entry id and who recorded it), designed with EA's role model. Until then: an identical retry, or leave the order as it is.
- T8 DONE 2026-10-16 (POP :51, V22): partial supplier payments. Owed is the invoice net; each payment is recorded with its own ledger key; the order and invoice close only when covered; overpayment refused; an optional paymentReference makes a repeat of the same payment safe; aging uses the outstanding part. Reviewed by CM at high.
- DONE 2026-10-15 (POP :47): Prodeo-is-a-landlord stage 1 (no prodeoRole needed or returned, executingParty TENANT or TENANT_LENDER with the old values still accepted, V18). STAGE 2 (drop the leftover field, the enum and the column) waits until the screens stop sending prodeoRole.
- DONE (live since POP :50): the line item link V19 (return dispatch posts to Inventory for lines with an item). Inventory confirmed its goods-issue path on 2026-10-16 (IM master 31deae0). A return of goods already sold is refused by Inventory (409 invalid_issue, not enough on hand): a decision for Femi, not built.
- DONE (live since POP :50): Discounts Received T-D1, the trade discount on a purchase line (V20) and the discount on the invoice total (V21, largest-remainder rounding), no ledger change. BUILT, NOT LIVE: T-D5, the supplier credit note of kind DISCOUNT or REBATE (V23), released after the ledger's POST /purchasing/record-credit-note is live. The early-payment discount is NOT started: Femi decided (2026-10-15) it needs a full SPUTO playbook for its VAT first, which Femi reviews himself (he confirms the tax treatment); T8 is now done.
- Product VAT category read from Inventory: stage 1 (the read and a tolerant decoder) is live; stage 2 (copy the category at order time, refuse an item with no answer, 503 when Inventory is down) waits for Inventory's slice A, EA's decoder and the screens no longer sending a category on item lines. Lines with no item keep an explicit category.
- T9a DONE 2026-10-08 (audit log, above).
- T9b Separation of duties on approval: approve needs the approve capability, settings need administer, the approver differs from the creator except for the Owner (whose self-approval is allowed and flagged in the audit row), per the RBAC plan (docs/RBAC_SPUTO.md). Waits for the platform capability model (T5a) and Femi's decisions; about 4 days after that.
- T9c Whether payment, the three-way match and return approval need a second person (Femi's decision, queued by CM).
- T15 M2 (before a second real customer relies on the database, per docs/T15_MultiTenant_SPUTO.md): a Company key in every query and every repository finder (about 2 to 3 days), a Company column on the child tables (about 1 day), a static guard that no repository returns rows without a Company, and the row-level-security question. M3: CM drops the old Tenant variables from the task definition.
- T6 DONE (live): return-dispatch idempotency and retry.
- T10 Reconcile POP's received quantity with IM's stock receipt (detect drift, or have one call do both). Needs a design decision with IM.
- T11 Supplier and Item code fields, then bulk CSV opening-figure routes (docs/Opening_Figures_CSV_Upload_DDD_Design.md; platform-wide).
- Parked, not mine: NFR-PO05 facility headroom (needs the bank's terms), GL's suspenseAccountId in purchase-posting-context.

PART 6 - ORDER (foundations before features)
1. Done: P0 security gaps, audit log, PO numbers, multi-Tenant P1 to P4, GL-first posting with idempotency keys (T7).
2. Done since: T6 (retry), Prodeo-is-a-landlord stage 1, the contract fixtures. Also done since: the line item link (V19), the trade and invoice discounts (V20, V21), T8 partial payments (V22). Next: T-D5 released with the ledger's route, then the early-payment discount once Femi has read its VAT playbook.
3. T8 (partial payments) is done; payment correctness came before control changes.
4. T9b and T9c once Femi decides and the capability model exists; T10 after IM and POP agree one owner for the receipt.
5. T15 M2 before a second real customer relies on the database, not only POP's code, for isolation.
6. T11 last; it depends on the platform-wide import layer.
