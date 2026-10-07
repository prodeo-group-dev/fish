# SOP Company scoping inside a business (Tenant): SPUTO

**Status: 2026-10-07, SOP session. Part 1 (Sales surface) is DONE and live (PR #22, merge 262a28d, task definition :42). Parts 2 and 3 below are planned here and then built on branch `fix/company-scope-returns-complaints-bfc`.** Prioritised by Femi: duplicate sales, phantom orders and the unscoped Sales list are "company existentially critical".

## S: Scope and problem

SOP serves one business (Tenant) per deployment and many Companies inside it. EA says, per Company, what a person may do (access level, and whether the Sales module is granted). A person's access at Company A must never let them see or change Company B's records.

Found 2026-10-07 by reading the routes: only the routes that carry a `companyId` (record a sale, a collection, a credit note, a Bill collection, customers, reports) checked access at that Company. Every other route used a Tenant-wide check ("access somewhere in the business"), so a person with Sales access at one Company could read or change another Company's orders, return requests, complaints and Bills for Collection by id or by listing. Underneath it, a sale's `entityId` came from WEB as a fresh random UUID, so an order had no reliable Company at all.

Done (Part 1, live): the order's entity is the authorized `companyId`; Sales list, order lookup, collections, cancel and create-order are Company-scoped.

**In scope now:** Part 2, return requests, credit notes and complaints; Part 3, Bills for Collection. **Out of scope / tracked:** `FacilityHeadroom` is keyed by facility and has no Company (a facility is a financing arrangement; see open question Q1); the sale route does not yet verify that the customer in the request belongs to the Company (a mislabel of the AR customer tag inside the same Company's own ledger, not a leak between Companies; tracked).

## P: Plan (requirements)

| # | Requirement |
|---|---|
| R1 | A record belongs to exactly one Company, derived from data we trust: a return request's Company is its customer's Company (`Customer.entityId`, set from the authorized path since Wave 0R.3); a complaint's Company is its return request's; a Bill for Collection's Company is its order's customer's Company, falling back to the order's entity. |
| R2 | Every read of one record requires READ at that record's Company; every write requires WRITE at it. Failing that, a read answers 404 (the record's existence is not theirs to learn) and a write answers 403 like every other Company-scoped write. |
| R3 | Lists return only the Companies the caller may read; a caller can never widen that with a parameter. |
| R4 | Creating a record (a return request, a complaint, a Bill) requires WRITE at the Company of the thing it hangs off (the customer, the return request, the order). |
| R5 | A record whose Company cannot be resolved (missing customer or order) is invisible and read-only to people: fail closed, treated as not found. |
| R6 | Service accounts keep their trusted access (unchanged). |
| R7 | One EA lookup per request (resolve the record, authorize once), as for cancel. |
| R8 | Every previously working call by an authorized person keeps working with the same request and response shapes. |

## U: Use cases

- **UC-1** Staff at Company A list return requests: only A's appear. Staff with access at A and B see both.
- **UC-2** Staff at A fetch, submit, approve, reject, receive, inspect or credit a return request that belongs to B: refused (404 on read, 403 on write).
- **UC-3** Staff at A raise a complaint against B's return request: refused.
- **UC-4** Staff at A present, accept, mark due or collect a Bill for Collection on B's order: refused.
- **UC-5** Staff at A create a return request for an order and customer of A: allowed.
- **UC-6** The credit-note route names a `companyId`; it must equal the return request's Company, otherwise refused (a person with write at A cannot post a credit to A's ledger against B's return).
- **UC-7** A record whose customer was deleted or never existed: invisible to people, still reachable by a service account.

## T: Tasks

| Task | Work |
|---|---|
| T1 | `CompanyResolver` (customer, return request, complaint, Bill, order to Company). |
| T2 | Auth helpers: authorize a read or write at a record's Company with one EA lookup, 404/403 as R2 and R5. |
| T3 | Return-request routes (list, get, create, submit, approve, reject, receive, inspect, issue-credit-note): scope per R1-R5; the credit-note and inspect `companyId` must match the record's Company. |
| T4 | Complaint routes (list by return request, get, raise, escalate, record supplier response, resolve, reject). |
| T5 | Bill-for-collection routes (present, accept, mark due, collect); collect's `companyId` must match the Bill's Company. |
| T6 | Tests: one cross-Company refusal per route family, list filtering, unchanged happy paths, service-account bypass, unresolvable Company. |
| T7 | Update the SOP playbook status; tell WEB (list calls unchanged; per-id calls may now 404/403). |

## O: Order

T1 first (everything depends on the resolver), then T2, then T3 (the largest and the one with a money posting), T4 (hangs off T3's resolution), T5, then T6 alongside each, T7 last. No migration, no new configuration, no change to any request or response shape. One deploy.

## Open questions

- **Q1** `FacilityHeadroom` is per facility with no Company. Options: leave Tenant-wide (a facility is a financing arrangement of the business), or add the owning Company to the headroom when it is opened (a migration and a WEB change). Not decided; left Tenant-wide in this pass.
- **Q2** Legacy data: records created before the fix whose customer's Company is unreliable become invisible (R5). All production data is legacy test data (Femi, 2026-10-06).
