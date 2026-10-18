# Overpayments on Invoice: GL account and posting note (short, no build until Femi has seen it)

GL session, 2026-10-18. Docs only. Trigger (Femi, via CM): when a customer pays more than an invoice has left to pay, the excess is posted as **"Overpayments on Invoice"**, which Femi calls "a specialised Suspense account": it holds an unresolved amount, but dedicated and named, a liability owed back to the customer. It "may need reversal later or may be distribution to staff", so it must not be a dead end. Do not net it against Accounts Receivable silently.

Companion: `docs/GL_Per_Line_Account_Routing_Audit_And_Design.md` (the per-line account mechanism and Suspense 3910).

## 1. The account: code, type, how Companies get it

- **Proposed:** code **2400**, name "Overpayments on Invoice", type **LIABILITY**, classification **CURRENT**. 2400 is free in every business chart (taken: 2000 Accounts Payable, 2100 Loans Payable, 2150 VAT Control, 2200 Accrued Leave, 2300 Trade Finance Facility). Femi may prefer another code; the mechanism does not depend on it.
- **New Companies:** added to the business chart templates (sole trader, partnership, company limited, non-profit); not to the Individual chart (no invoices).
- **Existing Companies:** exactly the 2300 and 4920 route: `POST /companies/{id}/standard-accounts` adds the missing standard accounts, leaves any account that already uses the code for something else alone and reports the conflict. Nothing is created silently for a Company that never calls it.
- **A Company without 2400:** SOP's collection that has an excess is refused `overpayments_account_not_configured` (409) with the instruction to add the standard accounts. It does **not** fall back to Suspense: money owed back to a customer should not sit in equity suspense. Femi can overrule this (the alternative is Suspense 3910).

## 2. Control account for SOP's per-invoice balances?

Yes. 2400 is a **control account with SOP as its sub-ledger**, exactly as 1100 is for receivables and 2000 for payables. SOP keeps the per-customer, per-invoice overpayment balance; GL keeps the total and the customer tag on each line. Consequences in GL:
- 2400 joins the module-owned list (`ModuleOwnedAccounts`, "use Sales instead"): a cash-book receipt or payment cannot post straight to it, and it is excluded from the sale-line and purchase-line pickers.
- Its balance must equal SOP's sum of open overpayment balances; the reconciliation is SOP's (GL aggregates; SOP reconciles to the control account).

## 3. Which GL posting interface for the excess

SOP's collection today calls `POST /sales/record-collection` (Dr settlement, Cr AR control, and the collection must clear the invoice exactly). Recommended, consumer-first and additive: the same route gets an optional `excess` {amount, accountId?}:
- Dr settlement account (cash or bank) for the **whole** amount received; Cr AR control 1100 for what the invoice had left (tagged to the customer, as today); Cr the overpayment account for the excess (tagged to the customer, dimension `OVERPAYMENT_INVOICE` carrying the invoice reference). One entry, atomic: the receipt is never half-recorded.
- `excess.accountId` absent: GL uses the Company's 2400 by code. Present: validated by the per-line rule (Company's own, active, LIABILITY, and it must be a Company's overpayment-role account), so another liability cannot be named by mistake.
- A collection with no `excess` behaves exactly as today.

## 4. How it appears on the trial balance and balance sheet

A **current liability** on its own line, "Overpayments on Invoice (owed to customers)", shown in full. It is **not netted against 1100** in any report: the balance sheet shows receivables gross and this liability gross; "Customers owe you" (dashboard) stays the gross receivables figure, and the overpayment is shown beside it as what the Company holds for customers. The working-capital and current-ratio figures count it as a current liability (it is owed back or released). Femi may later ask for a presentation netting by customer; that is a report option, never the default.

## 5. Not a dead end: reversal and release

All three moves below are **thin routes SOP calls** after SOP's own approval; GL posts the approved journal, validates accounts, and records the reference. SOP owns the per-invoice balance and the approval screen.

| Move | When | Posting (GL) | Who may do it |
|---|---|---|---|
| **Apply to an invoice** | The customer owes another invoice | Dr 2400 (customer, old invoice), Cr 1100 AR (customer, new invoice) | The sales role that can record collections |
| **Refund the customer** | Money goes back | Dr 2400 (customer), Cr cash or bank | Accountant or Owner Admin approves; Owner Admin may self-approve, flagged |
| **Reverse a mistaken overpayment** | The excess was never real (wrong invoice, wrong amount, duplicate) | An ordinary reversal of the original collection entry, or Dr 2400, Cr 1100 for the part mis-posted; the reversal is linked to the original | Accountant or Owner Admin approves; self-approval flagged |
| **Release (reclassify or distribute)**, for example to staff | The Company decides to move the held balance out, a deliberate act | Dr 2400 (customer, invoice), Cr the chosen target account from the Company's chart: another liability (staff payable), or income, or equity, as the accountant decides, with a mandatory reason | **Owner Admin approves**; self-approval allowed but flagged, as for other approvals. Never silent; never a bulk write-off |

**Audit trail: where each amount went.** Every move is its own journal entry, linked to the original collection by the invoice reference tag and `OVERPAYMENT_INVOICE`, with an action tag (`APPLY`, `REFUND`, `REVERSE`, `RELEASE`) and a description that names the target and the reason. SOP's record of the move keeps who asked, who approved, whether it was a self-approval, and the evidence. **Honest limit:** GL does not yet store an actor on a journal entry (known gap OS-GL-N3, audit-trail writes); until that lands, who requested and approved sits in SOP's record, referenced from the GL entry's description and tags, and the GL side shows what moved and where. Reading it back: GL's entries on 2400 filtered by customer and invoice give the held balance and every movement out, each with its target account.

## 6. Open points for Femi

- Code 2400 and the name, or another.
- A Company without 2400: refuse (recommended) or fall back to Suspense.
- Release targets: any account of the Company's chart (recommended, validated), or a fixed list (income, staff payable).
- Whether apply, refund and reverse need the same approval as release, or only release (recommended: release and refund approved; apply is routine).
