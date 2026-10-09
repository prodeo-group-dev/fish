GENERAL LEDGER (GL) PLAYBOOK (draft for Omniview's Playbooks tab, service GL)

Written by the GL session, 2026-10-07, from the code on fish-fish-gl-engine master (commit b4723da, PR #61, deployed as task definition fish-gl-engine:98 on 2026-10-07, confirmed live by CM; refreshed from the 5fd7db6 / :97 version for the trading profit-and-loss release). Plain text so it can be pasted straight into the Playbooks tab. Everything below was read from the code, not from older documents; where a statement is a design intention rather than a fact it says so. Update this sheet in the same change as the code it describes.

PLAYBOOK CONTENTS (see docs/Playbook_Definition.md; a playbook is this sheet PLUS the SPUTO set)
1. Operator sheet: this document.
2. Scope: GL/docs/GL_MVP_Definition.md (what is the floor and what is enhancement; three pre-go-live flags), FiSH_GL_Engine_Spec.docx (v0.7, original requirements), docs/DDD_Design.md.
3. Plan / SRS: FiSH_GL_Engine_Spec.docx and docs/DDD_Design.md (core ledger); docs/IFRS_GL_Posting_Matrix.md (posting rules by transaction); docs/IE/IE_VAT_MVP_Design.md (VAT); docs/Opening_Figures_CSV_Upload_Requirements_Specification.md and _DDD_Design.md (opening imports); GL/docs/GL_Audit_Trail_Software_Requirements_Specification.md; GL/docs/GL_Working_Capital_And_Bank_Reconciliation_Software_Requirements_Specification.md; docs/Fee_Billing_Epic13_GL_Posting_Rules.md (school fees, GL half, a proposal not yet built).
4. Use cases: GL/docs/GL_Audit_Trail_Use_Cases.md; GL/docs/GL_Working_Capital_And_Bank_Reconciliation_Use_Cases.md; the use cases inside FiSH_GL_Engine_Spec.docx. Not written yet: a single GL use-case document covering posting, periods, tax and reports end to end.
5. Tasks: GL/docs/GL_Audit_Trail_Backlog.md; GL/docs/GL_Working_Capital_And_Bank_Reconciliation_Backlog.md; docs/GL_POP_IM_SOP_Backlog.md; docs/GL_Production_Readiness_Plan.md; docs/Downtime_Maintenance_Backlog.md.
6. Order: the same backlogs (each is dependency-ordered); docs/GL_Production_Readiness_Assessment.md lists the foundations still missing (row-level tenant isolation, metrics, backup and recovery story, rate limiting). Safety foundations that exist today: idempotency keys on posting routes, strict decoding of the authorisation service's answers, fail-closed VAT.

OWNING SERVICE
General Ledger (repo fish-fish-gl-engine, public). The GL session is the L2 for anything below. GL is the system of record for every financial posting: SOP, POP, IM, HR and the Education Runtime (through SOP) all post here. GL does not decide who may do what (EA does) and does not hold stock, orders or payroll records (IM, SOP, POP, HR do).

ESCALATE TO
Owner: the GL session. Deploy, environment, secret and database-access problems: CM (only CM pushes and deploys; flipping a VAT or jurisdiction row is a data update CM prepares and Femi runs). "Cannot access" for a person: EA. A sale or purchase that did not post: the owning service first (SOP or POP), then GL.

HELP ARTICLES
None written yet. Do not invent links; say so if asked.

HOW ACCESS WORKS (needed for most "I can't" tickets)
GL keeps no user list. For a signed-in person it asks EA who they are and what they may do at the Company in the request.
- 401 unauthorized ("Missing or invalid bearer token" or "No authenticated caller"): no valid sign-in token. Ask them to sign out and in.
- 403 forbidden, with a reason. "No active Membership in the requested Tenant": they have no membership in that business. "This Membership's access level at the requested Company cannot perform this action": they can read but not write (or similar) at that Company. "This Membership is not granted access to the X module at the requested Company". "Only the Tenant's Owner-Admin can perform this action": creating a Company is Owner-Admin only. "X-Tenant-Id does not own the requested resource": the business id they sent does not own that Company.
- 400 bad_request "X-Tenant-Id header is required": a person calling a Company route must say which business they are acting for. (A service login does not have to; see the service-accounts line below.) A header that is not a valid id is also 400.
- 503 service_unavailable "Could not reach the authorization service": GL could not reach EA, so it refuses rather than guessing. Retry in a minute; if it persists, escalate to CM.
- Service accounts: there are exactly four service logins, SOP, POP, IM and HR. The Education Runtime has no GL login of its own; it posts through SOP. A service login is trusted by its own credential and skips the person check by design, and it is valid for every business, with two limits (T15, 2026-10-09). (1) Endpoint allow-list: each login may call only the GL routes its own service uses, listed in `ServiceEndpointAllowList`. Anything else is 403 forbidden_endpoint. While `FISH_SERVICE_ALLOWLIST_MODE=log` is set (production, as of 2026-10-09, until CM sets enforce), an off-list call is answered normally and logged as `WOULD BLOCK service=<name> <METHOD> <path>` (no ids or tokens); with enforce, which is the default when the variable is unset, it is refused. A real service call that gets forbidden_endpoint means the list is missing a route that service really needs: tell the GL session. (2) The Company must exist and the business must match: the service may leave out X-Tenant-Id, and GL then reads the business from its own Company record; if it does send X-Tenant-Id it must own that Company (403 "X-Tenant-Id does not own the requested resource" otherwise), and an unknown Company is 404. A service can never create a Company (see below).
- Reading needs READ at the Company; posting and creating need WRITE. The Owner-Admin has READ at every Company of their business without being assigned.

WHAT GL EXPOSES (all under /api except /health; verified from the code 2026-10-07)
Posting (callers: SOP, POP, IM, HR, the generic journal for finance):
- POST /sales/record-sale, /sales/record-collection, /sales/record-sales-return (SOP).
- POST /purchasing/record-obligation, /purchasing/record-payment (POP).
- POST /inventory/record-receipt, /inventory/record-issue (IM, with a cost IM supplies).
- POST /payroll/record-pay-run and /leave-accruals (+ /remeasure, /utilize) (HR).
- POST /journal-entries (a generic balanced entry), POST /sales/create-invoice (an older direct cash or credit invoice; SOP is the system for sales now).
- POST /companies/{id}/accounts (create an account), PUT /companies/{id}/accounts/{id}/expense-classification (tag or untag an expense account as cost of sales, interest, income tax and so on), POST /companies/{id}/accounts/{id}/opening-balance.
Reading: GET /companies/{id}/accounts, /journal-entries, /customers, /sales-invoices, /fixed-assets, /vat-categories, and the posting-context routes (sales, purchase, inventory, payroll) that tell a caller which period and accounts to post to.
Reports: GET /companies/{id}/reports/balance-sheet, /profit-and-loss, /trading-profit-and-loss, /cash-flow, /working-capital, /fixed-asset-register; GET /expense-velocity, /money-velocity, /sales-to-expense-ratio; POST /accounts-receivable-aging, /accounts-payable-aging, /customer-balances, /supplier-balances.
Tax: GET and POST /companies/{id}/tax (Corporate Income Tax only); POST /companies/{id}/vat-return.
Other: bank reconciliation (/bank-reconciliations: start, match, unmatch, list, read); fixed assets (create, depreciate, impair, dispose); opening imports (/opening-imports/gl-balances and /fixed-assets, each with a /validate step); POST /tenants/{id}/companies (create a Company; people only, the business's Owner-Admin, never a service login); GET /me; GET /jurisdictions; GET /health (no sign-in, shallow: it shows the process is up, not that every dependency is).

COMMON QUESTIONS AND HOW TO ANSWER

POSTING, IN GENERAL
Q: What do the numbers in a posting response mean?
A: A posting returns the id of the journal entry and its status POSTED. record-sale also returns grossAmount (what the customer owes: net plus VAT, the amount debited to receivables) and vatAmount. Amounts are plain decimals in the Company's currency.
Q: "period_not_found" (404) or "period_not_open" (409) or "no_open_period" (409).
A: Nothing was recorded. The period the caller named does not exist, is not open, or the Company has no open period. IMPORTANT, say this plainly: there is NO route today to create, open or close a period. A Company gets one month-long OPEN period at onboarding and posting checks only that a period is open, not that the entry date falls inside it. So a period problem is not something the Company's accountant can fix in the product; escalate to GL.
Q: "company_not_found" (404), "account_not_found" and the other "..._account_not_found" or "..._account_not_configured" codes.
A: The Company or an account the caller named does not exist (or belongs to a different Company; GL answers the same way so it never confirms another business's account exists). "not_configured" means the Company's chart of accounts has no account GL expected (for example accounts receivable 1100, cash 1000, VAT control 2150). Fix by creating the account, then retry.
Q: "invalid_amount" (400), "invalid_lines", "invalid_posting".
A: An amount was zero or negative, there were no lines, or a generic journal entry did not balance (debits not equal to credits per currency).

IDEMPOTENCY (what protects against double posting)
Q: The caller retried. Did it post twice?
A: Only if it did not send an Idempotency-Key. Sending the header Idempotency-Key is optional. With it, GL records the request and its answer under (business, route, key). The same key with the same body returns the original answer (status and body) without posting again. The same key with a DIFFERENT body is refused with 422 idempotency_key_reused. Without the header there is no protection: two identical requests are two postings.
Q: A retry with the same key keeps returning the same error even after the cause was fixed.
A: By design. Keys are kept forever, and an error produced INSIDE the posting (for example period_not_open, a missing account, vat_category_not_supported) is stored and replayed with the key. After fixing the cause, send a NEW key. Errors raised BEFORE the posting (401, 403, bad request, company_not_found, no_vat_rate_schedule) are not stored.
Q: Which routes support it?
A: record-sale, record-collection, record-sales-return, record-obligation, record-payment, record-receipt, record-issue, record-pay-run, leave-accrual remeasure and utilize, create-invoice, POST /journal-entries and the fixed-asset actions. Not: account creation, creating a leave accrual, opening imports, bank reconciliation, tax, VAT return, creating a Company.
Q: Two requests with the same key at the very same moment?
A: A known narrow gap: both can run, though only one answer is stored. Sequential retries (the normal case) are safe.

VAT
Q: "no_vat_rate_schedule" (409) on a sale or purchase.
A: The Company's country has no VERIFIED VAT rates, and GL refuses rather than guess a rate. Today only Ireland (five bands) and the United Kingdom (three bands) are verified. Sierra Leone's 15% GST is loaded but NOT verified, so it still refuses. Liberia, Guinea, Cote d'Ivoire and Nigeria have no rows. Do not promise a date: turning a country on needs the rates confirmed against a primary tax source (Femi) and a data update by CM. A fee-only school with only exempt items cannot post in such a country either yet; a governed "exempt-only" path is designed (docs/Fee_Billing_Epic13_GL_Posting_Rules.md) but not built.
Q: "vat_category_not_supported" (400).
A: The line's VAT category does not exist in that country (for example SECOND_REDUCED in the UK). GET /companies/{id}/vat-categories lists exactly what the Company may use, with the rate on a date. EXEMPT has no rate (it is outside VAT, not 0%); ZERO_RATED is 0%.
Q: Which rate is used?
A: The rate in force on the date of the transaction (Ireland's second reduced rate changed from 13.5% to 9% on 1 July 2026). One taxable line problem refuses the WHOLE invoice; nothing posts partially.
Q: Does GL file VAT returns?
A: GL computes a VAT return figure (POST /companies/{id}/vat-return) in the Irish shape only. It does not file anything with a tax authority.

COUNTRIES AND CURRENCY
Q: Which countries can a Company be in?
A: Whatever is enabled in the jurisdiction list (GET /jurisdictions): UK (the whole United Kingdom, Northern Ireland included, there is no GB), IE, NG, SL, LR, GN, CI today. Adding a country is a data insert by CM, no deploy. A bad or disabled code on company creation is refused with 400. A country on the list can still have no VAT rates (see above).
Q: Which currency?
A: A Company has one base currency and GL accepts any ISO code. Which currencies a business may use is a platform policy (Femi), not enforced by GL's posting code. GL does no currency translation and no revaluation.

CHART OF ACCOUNTS
Q: What accounts does a new Company get?
A: A starter chart by business type (individual, sole trader, partnership, limited company, non-profit): cash 1000, accounts receivable 1100, fixed assets 1200, accounts payable 2000, VAT control 2150, payroll and facility accounts, equity, a suspense account (3910), one revenue account and a few expense accounts, plus an opening period and the opening cash balance. Since 2026-10-07 every business type (not individual) also gets three tagged expense accounts: 5010 Cost of Sales, 5600 Interest Expense and 5700 Income Tax Expense; Companies created BEFORE that date do not have them. There is ONE revenue account and no bank, deferred-income, pass-through or school-fee accounts in the starter charts.
Q: record-sale posts only to one revenue account.
A: Correct. A single sale credits one revenue account chosen by the caller; it cannot split an invoice across several revenue accounts yet.
Q: What is the suspense account for?
A: Opening or unclassified balances that must be sorted out later (for example an asset that already existed). A balance sitting in suspense means the books are not final.

REPORTS
Q: How are the reports calculated?
A: From posted entries only. The balance sheet uses everything posted so far (there is no "as at" date). Profit and loss, cash flow and the velocity reports use the Company's single open period. The profit-and-loss route returns three totals (revenue, expense, net income). The trading profit-and-loss route (since 2026-10-07) splits them: revenue, cost of sales, gross profit, operating expenses, operating profit, interest, profit before tax, income tax and net profit, on the same open period, and its net profit equals the plain route's net income. Reports show what is posted; they are not an audit opinion.
Q: Gross margin or interest cover shows "not available yet".
A: The trading report says whether any account is TAGGED as cost of sales (costOfSalesConfigured) or interest expense (interestConfigured). Cost of sales is only what sits in an expense account tagged as cost of goods sold; an untagged account counts as an operating expense, which makes gross profit look too high. Companies created before 2026-10-07 have no tagged accounts. Fix: tag the right expense account with PUT .../accounts/{id}/expense-classification (it only regroups the report, it never changes a balance), or create the accounts. Inventory Management posts its cost of goods sold to the account each stock item names, so those items must point at a tagged account. Tagging has no audit trail yet.
Q: Is the balance sheet balanced?
A: It reports an isBalanced flag. Retained earnings is computed from all revenue and expense ever posted, because nothing closes a period into retained earnings.

OPENING BALANCES AND IMPORTS
Q: How do we load opening figures?
A: Per account through the opening-balance route, or by uploading a CSV to the validate step first and then the import step (general-ledger balances; fixed assets). A balance for an account that receivables, payables or stock own the itemised detail for is moved to suspense rather than accepted. Receivables, payables and stock opening figures are NOT bulk-loadable through GL: their itemised imports belong to SOP, POP and IM and are only partly built there.

BANK RECONCILIATION
Q: How does it work?
A: Start a reconciliation with the bank statement lines, then match each line to a posted journal entry; a match can be undone. The reconciliation is "fully reconciled" when every line is matched. One entry can be matched to only one line. It does not import bank feeds.

FIXED ASSETS AND TAX
Q: What exists?
A: Straight-line depreciation, impairment and disposal, with a register report. No revaluation. Tax means Corporate Income Tax computed from the Company's jurisdiction rule; there is no payroll tax, withholding or sales tax engine in GL.

ERROR GLOSSARY (what the "error" field means)
unauthorized - bad or missing sign-in. forbidden - signed in but not allowed (read the detail). service_unavailable - GL could not reach EA. bad_request - something in the request is wrong; the detail names it. company_not_found / period_not_found / account_not_found / not_found - the thing named does not exist for that business. period_not_open / no_open_period - see the periods answer; nothing posted. invalid_amount / invalid_lines / invalid_posting - the amounts or lines are not acceptable. no_vat_rate_schedule / vat_category_not_supported - see VAT. ..._not_configured - the Company's chart lacks an expected account. currency_mismatch - the amount is not in the Company's or the document's currency. idempotency_key_reused (422) - same key, different body. duplicate_code - an account with that code already exists. invalid_csv - an import file could not be read. internal_error (500) - an unexpected failure; GL logs the detail with a request id and does not show it to the caller. Always collect the request id (the X-Request-Id header on the response), the Company id, the route and the time before escalating.

WHAT TO COLLECT BEFORE ESCALATING
The route and method, the Company id and business (Tenant) id, the exact "error" and "detail", the Idempotency-Key if one was sent, the journal entry id if one came back, the time (UTC) and the request id from the response header.

NOT BUILT, NOT DEPLOYED, OR NOT YET EXERCISED (do not promise these)
- Period management: no route to create, open or close a period, no period roll-over, no "as at" date on the balance sheet, no profit and loss for a chosen period.
- Reversal over HTTP: the logic exists but no route exposes it, so a posted entry cannot be reversed by a caller yet (void a receipt, cancel an invoice).
- Audit trail: the store exists and is tested, but nothing writes to it yet. GL cannot answer "who posted this" except the entry's source (manual, integration, reversal); there is no actor on an entry.
- VAT: Ireland and the UK only are live. Sierra Leone is loaded but unverified (refuses). Liberia, Guinea, Cote d'Ivoire and Nigeria have no rates. No exempt-only path. VAT returns are Irish-shaped. Nothing records who verified or changed a rate (an audit trail for that is required before any country is switched on).
- Trading profit-and-loss: live, but only as good as the tagging. Existing Companies are untagged; re-tagging has no audit trail and moves gross margin; it uses the single open period (no chosen period or date range); no work-in-progress adjustment for manufacturers.
- School fees: one revenue account per sale, no deferred income, no pass-through liability, no parent-advance or refund posting (a proposal exists: docs/Fee_Billing_Epic13_GL_Posting_Rules.md).
- Consolidation across Companies, fund accounting, contra-revenue presentation, foreign-currency translation or revaluation.
- Bulk or batch posting: one call per document.
- Receivables, payables and stock opening figures by CSV (partly built in SOP, POP and IM, not in GL).
- Market-support aggregates for Omniview (designed and held, not built).
- Row-level database isolation between businesses (tenancy is enforced in the application), metrics and tracing, rate limiting, a documented backup and recovery drill, graceful shutdown, API versioning (see docs/GL_Production_Readiness_Assessment.md).
- Not yet exercised with real money: the platform is still in its Development phase; production data is legacy test data until Femi announces the switch to Live.
