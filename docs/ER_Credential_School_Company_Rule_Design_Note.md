# How a specialist runtime plugs into the generic services: the school-Company rule first, then the general pattern

Status: design only, 2026-10-12. Led by the Education Runtime (+ER) session at Femi's direction ("The Education Runtime should actually design it. It is its primary responsibility i.e. to add an Education Runtime to the Generic."); SOP and EA contribute facts. **No code until CM has reviewed any auth path.** Part 1 (sections 1 to 8) is the immediate rule and the customer-creation idempotency, small and first. Part 2 (section 9) is the general pattern, shorter, so the next runtime follows it; it builds on EA's `docs/Platform_Contract_Generic_Services_And_Runtimes_SPUTO.md` and does not repeat it. Replaces the hand-kept `SOP_ER_COMPANY_IDS` list (Decisions_Log, 2026-10-12: every school recognises its income through SOP, so the credential must work in every school Company by a rule, and never in a non-school Company).

## 1. The problem, and the two things that must both hold

The Education Runtime (ER) calls SOP with its own Cognito service-account token to create a Customer for a guardian: `POST /api/companies/{companyId}/customers` (only customers create and read are open to it; every other SOP route refuses it). Today SOP lets that credential act only in Companies named in `SOP_ER_COMPANY_IDS`; the variable is empty in production, so every call is refused.

The rule we want: **allowed in any Company that is a school, refused in every other Company, with no list kept by hand.** Two requirements follow, and the design must serve both:

1. **Security boundary.** A stolen or misbehaving ER credential must not be able to create or read Customers in a non-school Company (another Tenant's business). This is a cross-Tenant boundary.
2. **Safe retry.** ER can fail mid-flight (timeout after SOP received the request). SOP's `CreateCustomerUseCase` has no key and no dedupe, so a retry can create a second Customer for the same guardian. ER now answers such failures with a retryable `billing_unavailable` (503, branch `feature/billing-unavailable`), which is only safe if the retry cannot duplicate.

## 2. Facts (each checked in code)

| Fact | Where |
|---|---|
| SOP verifies the ER token against its own audience (`SOP_JWT_SERVICE_AUDIENCE_SCHOOLADMISSIONS`); unset means deny-all. The token proves "this is the ER app client" and nothing about a Company. | SOP `Auth.kt` |
| The service credential is authorised by `authorizeServiceAccount`: route must opt in (`serviceMayCall`), request must name a Company, and the Company must be in the configured set. Otherwise 403. | SOP `Auth.kt` |
| SOP's own comment already names the intended successor: "M1b replaces this list with EA's 'Education Runtime enabled for this Company'". | SOP `Application.kt` |
| EA stores `company_names.industry_type` (GENERIC or SCHOOL), set at Company registration **before** ER is provisioned, and immutable (`IndustryTypeImmutable`). EA also stores `school_id` after provisioning. | EA, per EA's message |
| EA has no service-readable "is this a school" answer today (`/me` is person-only). | EA, per EA's message |
| ER's `schools` table holds only `id, organisation_id (= EA Company id), tenant_id, name, provisioned_at`. No industry column. A row exists only if EA called `POST /schools`. | ER `V19__schools.sql` |
| ER sends SOP the school's `organisation_id` as the Company in the path (UUID-checked first), a bearer token, and `name + creditTerms`. It asserts nothing else. | ER `GuardianBillingService`, `KtorSopCustomerGateway` |
| SOP `CreateCustomerUseCase` validates name and credit terms, then saves. No key, no dedupe. | SOP `CreateCustomerUseCase.kt` |
| A Cognito client-credentials token is per app client, not per request: it cannot carry "which Company". | Cognito M2M model |

## 3. Options weighed

**A. SOP asks EA whether the Company is a school (recommended).** EA is the one party that is authoritative on a Company's industry and that the ER credential holder does not control. SOP checks `industryType == SCHOOL`, fail closed.

**B. ER attests the school link itself.** Rejected. ER is the party being constrained; a self-assertion adds no protection: whoever holds the ER credential (or exploits an ER bug) can assert anything. Only worth considering as a second factor, and EA already says the same thing more authoritatively.

**C. A claim carried on the ER token.** Rejected. Machine tokens are per app client; a claim cannot vary per Company, so it could only say "this is ER", which SOP already knows. A per-school client would mean one Cognito client per school: unmanageable.

**D. SOP keeps a table fed by ER's provisioning.** Rejected. It recreates a hand-kept list with a feed in front of it, creates a second source of truth for industry, and the feed is again written by the constrained party.

**E. Keep the list but have EA generate it.** Rejected. A push-synchronised list can drift (a missed event leaves a school unable to bill, or a removed school still allowed) and needs its own failure handling. Option A reads the truth when needed.

**Recommendation: Option A**, with the refinements in section 4. It is also what EA proposed; ER's facts in section 2 are why it is right rather than a preference: ER cannot be the authority, and a token cannot carry the answer.

## 4. The design

### 4.1 The rule at SOP

In `authorizeServiceAccount` (the only place the ER credential is judged), replace the list lookup with a port `CompanyIndustryGateway.industryOf(companyId)`:

1. Route must opt in (`serviceMayCall`) and name a Company. Unchanged.
2. The Company id must be a UUID. A malformed id is a 400 before anything is called, so garbage never reaches EA.
3. Ask EA (4.2). Only an explicit `SCHOOL` allows the call.
4. Everything else is refused, and **the refusal reveals nothing about the Company**: unknown Company, non-school Company and an unrecognised industry value all give the same 403 `not_a_school_company`; the log line (not the response) carries the reason.

`SOP_ER_COMPANY_IDS` is removed once this is live. The existing kill switch stays: unset `SOP_JWT_SERVICE_AUDIENCE_SCHOOLADMISSIONS` and every ER token is refused.

### 4.2 The EA read

`GET /api/internal/companies/{companyId}/industry`, answering exactly `{"industryType":"SCHOOL"}` or `{"industryType":"GENERIC"}`; 404 with body exactly `{"error":"company_not_found"}` (no detail text) for a Company with no EA record. Callable only by SOP's own service principal (see 6, an infrastructure item for CM). SOP decodes it **strictly** (no `ignoreUnknownKeys`), per the standing rule for auth payloads. Minimal on purpose: one field, no school id, no names.

### 4.3 Failure modes (fail closed, always)

| What happens | SOP answers | ER then answers its caller |
|---|---|---|
| EA says SCHOOL | proceeds | normal |
| EA says GENERIC | 403 `not_a_school_company` | `billing_not_enabled` (503) |
| EA 404 (unknown Company) | 403 `not_a_school_company` (same body: no existence leak) | `billing_not_enabled` |
| EA unreachable, timeout, 5xx, or any non-200 | 503 `service_unavailable` | `billing_unavailable` (503, retry later) |
| EA body not decodable, or an industry value SOP does not know | 403 `not_a_school_company`, logged loudly | `billing_not_enabled` |
| Malformed Company id | 400 | ER never sends one (it validates first) |
| Route has not opted in | 403 (unchanged) | n/a |

**Caching** (to keep EA off the hot path without weakening the boundary): cache **only positive** (`SCHOOL`) answers, with a bounded lifetime (suggest 10 minutes), per Company. Industry is immutable today, so a positive answer cannot go stale, and the bound is cheap insurance in case that ever changes. **Never cache** a refusal or an error: a school registered a moment ago must not stay refused, and an EA blip must not become a sticky outage.

### 4.4 Safe retry: an idempotency key on customer creation

Add an `Idempotency-Key` header to SOP's `POST /api/companies/{company}/customers`:

- ER sends `ER-guardian-{guardianAccountId}`: one stable key per guardian account, so "one guardian account = one Customer in that Company" is enforced by SOP, not hoped for.
- SOP stores `(companyId, key) -> customerId` with a hash of the request, **in the same database transaction as the Customer insert**, under a unique constraint. A replay returns the stored Customer (same id; 200 instead of 201). The same key with a different body is a 422 `idempotency_key_reused`. Two concurrent first calls: the unique constraint lets one win and the other read the winner's row.
- **A refused request spends no key** (same rule the Decisions_Log set for GL: only a success is stored). A 403, 400 or 503 leaves nothing behind, so fixing the cause and retrying works.
- These keys are identity keys, not short-lived replay guards: no expiry.

With this in place the retry after a mid-flight timeout is safe, which is what justifies `billing_unavailable`. It also makes a `502 sop_bad_response` (SOP created the Customer but ER could not read the reply) safe to retry; ER keeps that one loud for now and may relax it later as a separate decision.

Without the key, the alternative is to refuse to retry on `sop_unreachable`, which pushes duplicates onto a human; not recommended.

## 5. What each service builds

| Service | Change | Size |
|---|---|---|
| **SOP** | (a) idempotency key on customer creation with the stored key and tests; (b) `CompanyIndustryGateway` + strict EA client + positive-only cache; (c) `authorizeServiceAccount` uses it; remove `SOP_ER_COMPANY_IDS` after rollout | M |
| **EA** | the `GET /api/internal/companies/{id}/industry` route, authorised for SOP's principal only; fixture for it in `fish-contracts` | S |
| **ER** | send `Idempotency-Key: ER-guardian-{id}`; keep `billing_not_enabled` / `billing_unavailable` mapping (already built); a test that the header is sent and reused on retry | S |
| **CM** | env vars for SOP's new client and the EA base URL; apply order; remove `SOP_ER_COMPANY_IDS` from Infrastructure. SOP's principal for calling EA **already exists** (EA validates SOP's service token through its `ea-jwt-service-principal-sop` provider, audience `EA_JWT_SERVICE_AUDIENCE_SOP`, used today for owner-contact); EA's new route reuses it, so no new Cognito client is needed (EA's correction, to be confirmed once on SOP's side) | S |

## 6. Build order

1. **SOP idempotency** first. It is independent, valuable on its own, and unblocks safe retry. ER sending the header earlier is harmless (SOP ignores an unknown header), so ER can follow immediately.
2. **EA route and SOP's principal** (EA + CM, in parallel with 1).
3. **SOP rule switch**: ship the gateway and the new check; flip the check on only when EA's route is live. Until then the existing refuse-everywhere default stays in force.
4. **ER header**, then a real end-to-end check on a test school (below).
5. Remove `SOP_ER_COMPANY_IDS`.
6. **Data prerequisite, before step 3 is switched on:** Companies registered before industry type existed hold the migration default GENERIC (EA V13), so any real school Company registered then, or without SCHOOL, would be refused. List the real school Companies and correct them by a reviewed data fix (the type is immutable through the API). Femi or CM names them; ER's `schools` table (organisation_id) is the list of Companies that actually have a school.

## 7. Test plan

**SOP (unit, route and real-Postgres):** ER credential with a SCHOOL Company: customers create and read succeed. GENERIC: 403 `not_a_school_company`. EA 404, EA 5xx, EA timeout, undecodable EA body, unknown industry value: fail closed with the table's status. Malformed Company id: 400 and EA not called. Positive answer cached; refusal and error not cached (EA called again). A human token's path is untouched. A route that has not opted in still 403. Idempotency: same key twice gives one Customer and the same id; same key with a different body gives 422; a refused request leaves no key; two concurrent first calls give exactly one row (Postgres, real concurrency); replay returns 200 not 201.

**EA:** route answers exactly one field; refuses any caller but SOP's principal; unknown Company 404; contract fixture in `fish-contracts` decodes through SOP's strict client (no `ignoreUnknownKeys`).

**ER:** header present and equal to the guardian account id; after a 503 the retry sends the same key and reuses the account; 403 maps to `billing_not_enabled`, 503 to `billing_unavailable`, `sop_bad_response` stays loud (already tested in `e532ac4`).

**End to end (test school):** a school Company bills a guardian once and a retry does not duplicate; a non-school Company is refused with the same body as an unknown one; EA stopped, the call returns `billing_unavailable`; EA back, the same request succeeds.

## 8. Open questions (for CM and Femi, not blocking review)

1. ~~SOP's principal for calling EA~~ **resolved by EA**: it already exists (see section 5); SOP to confirm with a one-line check.
2. **Cache lifetime** for positive answers (10 minutes proposed).
3. **Should ER also treat `502 sop_bad_response` as retryable** once idempotency is live? Proposed as a later, separate decision.
4. **Reading customers**: the credential may also read customers in a school Company; consider later whether it should see only Customers it created. Out of scope here.

---

# Part 2. The general pattern: how any specialist runtime plugs into the generic services

Shorter on purpose. The generic services are GL, SOP, POP, IM, HR and EA; a specialist runtime (Education now; credit union, banking, investment management, a doctor's surgery later) adds a domain on top of them. The platform-wide contract (versioning, fixtures, registry, broker) is EA's `docs/Platform_Contract_Generic_Services_And_Runtimes_SPUTO.md`; this part is the **runtime's side of it**, written from what the Education Runtime actually does today, so the next runtime copies a pattern that has been tried once. Nothing here is built beyond what is stated as built.

## 9. The five rules a runtime follows

**R-1. Identity of a runtime's Company is EA's to say, never the runtime's.** A Company belongs to a runtime because EA registered it so (today `industryType`; later EA's runtime manifest and `runtimeLinks`, EA doc Layer B). A generic service lets a runtime's credential act in a Company only if EA confirms that Company is registered for **that** runtime. Part 1 is the first instance: credential ER may act in Company C if and only if EA says C is SCHOOL. In SOP the mapping is data, not branches: *credential (audience) to required industry*; the second runtime adds one credential and one row. A runtime never asserts its own scope (Part 1, option B).

**R-2. A runtime owns its domain and its own people; the generic services own money, stock and the ledger.** The Education Runtime owns students, admissions, attendance, marks, curriculum, fee schedules and invoices, and its own staff and roles (`staff_assignments`); it does not read EA's `/me` or module grants for what a person may do inside it. It **never posts to GL** (enforced in code: `NoDirectGlWrites`). Financial meaning reaches the ledger only through a generic service's existing posting route. A runtime that wants a posting the generic service cannot yet express asks the generic owner to extend it; it does not reach around it.

**R-3. Least privilege, per route and per Company.** A runtime has its own Cognito service client and audience in each generic service (one audience per caller). The generic service opts routes in one by one (`serviceMayCall`) and always requires a Company the identity rule accepts. Today the Education Runtime may call exactly one thing: SOP customer create and read, for a school Company. It calls nothing at GL, POP, IM or HR, and EA only calls it (provisioning). The kill switch is per runtime: unset the audience and that runtime's tokens are all refused.

**R-4. Financial events leave a runtime as business facts, through an outbox, never as ledger postings.** The runtime writes an event row in the **same transaction** as the business change (fee payment confirmed, enrolment, marks published). A relay delivers it to the generic service's ingestion route; the generic service turns it into its own posting (for SOP: a collection through the existing record-collection route, which reaches GL). Delivery is **at least once**; the event id is deterministic from the business fact (the Education Runtime already uses `StudentPaymentReceived:{invoiceId}`) so the consumer deduplicates by id. Order is guaranteed **per business key** (for fees: the invoice), by a sequence column, not by timestamp. EA's CloudEvents envelope and `fish-contracts/events/` fixtures are the format (EA doc C1).

**R-5. Every call from a runtime to a generic service is retry-safe.** (a) A call with a side effect carries an `Idempotency-Key` derived from a stable business id, and the generic service stores only successes ("a refused request must not spend a key", Decisions_Log). (b) The reply read after the effect is decoded tolerantly: if it cannot be read, the runtime retries with the same key rather than failing a call that already succeeded; access and money payloads stay strict (no `ignoreUnknownKeys` there). (c) Every client has a connect and request timeout. (d) Failures map to three runtime answers, and only three: refused by the platform (401/403) gives `..._not_enabled`; platform down or slow (503, timeout) gives `..._unavailable`, retry later; anything else is a loud internal error. Part 1 section 4.4 and the built `billing_unavailable` are the first instance.

## 10. What the Education Runtime has, and lacks, against those rules

| Rule | Today | Gap |
|---|---|---|
| R-1 identity | EA registers the school Company and provisions ER; SOP uses a hand-kept list | Part 1 (the EA read), plus the data fix for pre-existing school Companies |
| R-2 ownership | holds; `NoDirectGlWrites`; own staff table | none |
| R-3 least privilege | one SOP route family, own audience, deny-all kill switch | none beyond Part 1's rule |
| R-4 events | outbox is written in the business transaction with deterministic ids; **nothing relays it**, so a fee payment has no financial effect in SOP or GL | the relay (below); the outbox table also lacks a sequence column, a published marker and a dead state, and carries `school_id` not the Company id |
| R-5 retry | `billing_unavailable` built (`e532ac4`); no key; customer-create reply decoded strictly after the effect; no client timeout; error body is `{error, message}` against the platform convention `{error, detail}` | the Part 1 key; tolerant decode; timeout; error body |

## 11. The Education Runtime's own build list for the pattern (each its own branch, none before CM review)

1. `Idempotency-Key: ER-guardian-{guardianAccountId}` on SOP customer create; on a 2xx whose body cannot be read, retry once with the same key instead of failing. (Part 1; size S.)
2. A request and connect timeout on the SOP client. (S.)
3. Error body `{error, detail}`: a breaking change for WEB and for tests, so brief WEB first; cheapest before the Live switch (EA doc decision 3). (S, with WEB.)
4. **Outbox relay** (EA's C2, the first build that makes a fee payment reach SOP): a migration adding a sequence column, `published_at`, attempt count, a dead state and the Company id; a poller that claims the oldest unpublished row **per invoice**, delivers to SOP's ingestion route, marks it published, dead-letters after N tries with an alert on oldest-unpublished age; real-Postgres tests for ordering, a crash mid-delivery, concurrent relays and replay. **Held until after the UAT sitting and after T-ER3** (a parent's "paid" becomes a claim to verify, not a payment), because the relay must carry the verified fact, not the claim. (M.)

## 12. The checklist for the next runtime

1. EA: a registered runtime (manifest and its industry value) and a JSON, idempotent provisioning contract keyed on the organisation id.
2. A Cognito service client per generic service it needs, one audience per caller; route opt-in in each generic service; a deny-all default and a kill switch.
3. The identity rule (R-1) as data: credential to required Company registration, checked against EA, fail closed, positive answers cached briefly, refusals and errors never cached.
4. Its own people and roles inside the runtime, mapped to the platform's view / enter / approve / administer capabilities; no reading of EA's `/me` for runtime permissions.
5. An outbox in the same transaction as each business fact; deterministic event ids; per-key ordering by sequence column; a relay and a dead state; the consumer's ingestion route deduplicates.
6. Every outbound call: Idempotency-Key, tolerant reply after the effect, timeouts, the three-way failure mapping.
7. Fixtures in `fish-contracts` for every response it provides to another service and a strict decode of every one it consumes; a paper dry run against SOP, GL and EA before any code (EA doc B1).

## 13. What the generic owners contribute (asked, not assumed)

- **SOP:** the idempotent customer create, the rule switch, and the event ingestion route with inbox dedupe; confirm how a collection is recorded from an event.
- **EA:** the industry route, the data-fix list, and later the manifest and `runtimeLinks`.
- **GL, IM, POP, HR:** state which of their routes a runtime must *never* call and which, if any, a future runtime might need; for the next runtime's dry run (EA B1), not for Education.
- **CM:** reviews every auth path before code; owns env vars, Cognito clients and the deploy order.

---

# Part 3. Raising tuition in SOP: which routes the Education Runtime credential needs, and what happens to ER's own fee code

Added 2026-10-12 after Femi's direction relayed by EA and CM: "Education Runtime does not need to duplicate these services. SOP creates income; ER should raise tuition fee invoices in SOP." This extends Part 1 (who may act in a school Company) and Part 2 (how a runtime behaves). Facts below are from SOP's and ER's code read the same day. Design only; nothing built.

## 14. What changes in principle

ER keeps its **price list** (fee schedule items) and its **people** (students, guardians, who may do what). It stops being the place where the money fact lives: a tuition invoice becomes a **credit sale in SOP** for the guardian's Customer, and a payment becomes a **collection** against that sale. SOP and GL then do what they already do (revenue, receivable, cash). ER's `confirmPaymentStub` and its `StudentPaymentReceived` outbox event, which today has no financial effect at all, are replaced by a direct, idempotent call. The outbox relay is no longer the first build; it stays for non-financial events only (EA's rev 2).

## 15. SOP routes the ER credential would need (per route, never broad)

Today the credential is opted in on exactly two routes (customer create, customer read; `serviceMayCall`). Every route below needs its own opt-in, **behind Part 1's SCHOOL check**, and each is an auth-path change for CM to review at higher effort. In the order they are needed:

| # | SOP route | Why ER needs it | Key | Notes for SOP |
|---|---|---|---|---|
| 1 | `POST /api/companies/{c}/customers` | create the guardian's Customer (exists, cleared) | `ER-guardian-{guardianAccountId}` (Part 1) | first build |
| 2 | `POST /api/sales` (credit sale) | raise a tuition invoice | `ER-invoice-{erInvoiceId}` | the Company is a **body field** on this flat route: the rule must take it from the body, never from a header, and check the Customer belongs to that Company (it already does); lines carry an **explicit** VAT category (section 16); `servicePeriodFrom/To` and `customerReference` carry the term dates and the student reference (print-only) |
| 3 | `POST /api/sales-orders/{id}/collections` | record a verified payment | `ER-payment-{paymentId}` | the route has no Company in path or body: SOP must derive the Company from the order itself and apply the SCHOOL rule to **that**, not trust the caller; needs the gross, currency and cash account (section 17) |
| 4 | `GET /api/companies/{c}/customers-with-balances`, `GET /api/sales`, `GET /api/sales-invoices/{n}` | statements, outstanding, invoice print | none (reads) | read-only, same SCHOOL rule; later than 2 and 3 |

**Never** for ER: cancel, return requests and credit notes, `record-sale` (the lower-level synthesis route), bills for collection and facilities (trade finance), the VAT-category edit route, invoice email, complaints, analytics. A refund or a mistaken invoice is a separate, later design (credit note through the returns flow), not part of this opt-in.

Two things SOP must also settle: the sale records the **actor from the token's email claim**, which for ER is the service account, not the bursar who raised the invoice, **proposal (CM agrees): an explicit `raisedBy` field on the sale request, the bursar's name as data and never as the token identity**; and `Idempotency-Key` already works on `POST /sales` and the collections route, so ER's keys need no new SOP mechanism.

## 16. VAT and revenue timing: not mine to decide, so asked, not defaulted

- **VAT category is mandatory per sale line** (`STANDARD`, `REDUCED`, `SECOND_REDUCED`, `SUPER_REDUCED`, `ZERO_RATED`, `EXEMPT`). The Decisions_Log (2026-10-11) says IM owns the category per item and SOP copies it at order time, but that SOP-to-IM read is not built. **Interim:** each ER fee-schedule item carries an explicit `vatCategory`, set by Finance when the item is defined, with no default (a missing one refuses the invoice). The right value per jurisdiction is Finance's and Femi's call.
- **Tuition is earned over a term; SOP recognises a credit sale at the sale date.** `servicePeriodFrom/To` and `customerReference` are, by SOP's own KDoc, print-only and never an input to recognition, so they do not give over-the-term recognition. Whether that is acceptable, or tuition needs deferred income released over the term, is an accounting question for Finance and SOP. It does not block the first build (a termly invoice raised at the start of term), but it must be answered before the Live switch.

## 17. Open design points with SOP and GL

- **Cash account for a payment.** The collection needs the gross GL debits, the currency and the cash account; ER holds no GL account ids. Proposal: SOP resolves the Company's default cash book (account 1000 is always the Cash Book, Decisions_Log 2026-10-11) when ER sends none; a school paying into a bank account is a later extension.
- **A payment is a claim until verified** (T-ER3, held until after the sitting): ER calls the collection route only when the fee desk has verified the payment, never on a parent's tick. This is the same rule as Part 2's R-4: the financial call carries the verified fact.
- **Student view over a guardian's Customer.** SOP's Customer is the guardian; a guardian with three children has one Customer and three students' invoices. A per-student statement therefore cannot be read from SOP alone (the student reference on the invoice is print-only text). ER keeps a thin mapping (section 18).

## 18. What happens to ER's existing code

| ER code | Fate | Reason |
|---|---|---|
| `GuardianBillingService`, `GuardianAccount`, `KtorSopCustomerGateway`, Part 1 key, `billing_unavailable` (`e532ac4`) | **stay, unchanged** | the first leg of the new flow; the Customer is what every sale hangs on |
| Fee schedule items (`defineScheduleItem`) | **stay**; gain an explicit `vatCategory` | the price list is the runtime's own; the money fact moves |
| `FeeService.issueInvoice` | **changes**: raises the credit sale in SOP, then stores the mapping | one key per invoice |
| `FeeInvoice` table (amount and status as truth) | **reduced to a mapping**: ER invoice id, student id and SOP sale id only: no amounts and no status, so no second copy can drift (CM steer, 2026-10-12); **not** retired outright | the student-to-sale link exists nowhere else; status and amounts read from SOP |
| `confirmPaymentStub`, the `StudentPaymentReceived` outbox event | **replaced** by the verified-payment call to the collection route (key per payment) | today's event has no financial effect |
| `reconcileStuckInvoices` | **replaced**: replay any invoice or payment with no confirmed SOP result under the **same** key; it converges because SOP dedupes | SOP now knows the truth |
| Parent gateway `outstandingCount`, per-student statement, guardian `outstanding` (`4e03ab9`) | **stay as ER's API for WEB; source swaps to SOP** | the response shape WEB codes against does not change |

**The queued read branch `4e03ab9` (statement route and guardian `outstanding`):** safe to release as it is, read-only and over test data, and its **shapes stay**; its **implementation is later re-pointed** at SOP (balances from `customers-with-balances`, per-student via the mapping). One difference WEB and Finance must know: SOP's balance is **gross, including VAT**, while ER's today sums net invoice amounts; once re-pointed the figure changes meaning, so the label ("including VAT") must change with it.

## 19. Build order (extends sections 6 and 11)

1. SOP idempotent customer create (Part 1, first). 2. EA industry route and the SOP rule, switched on only when CM says (the data gate in section 6). 3. ER customer-create key, tolerant retry, timeout (Part 2 list). 4. **Decide with Finance:** per-item VAT category, and the revenue-timing question (section 16); SOP's actor and cash-account answers (section 17). 5. SOP opts in `POST /sales` then the collection route (rows 2 and 3), each reviewed by CM. 6. ER: `vatCategory` on schedule items; `issueInvoice` raises the sale and stores the mapping. 7. ER: T-ER3 (payment as a claim), then the verified-payment call replaces `confirmPaymentStub`. 8. Re-point the reads (row 4) and retire `reconcileStuckInvoices`. Steps 1 to 3 need nothing from Finance; steps 5 to 8 wait on step 4.

## 20. Test plan additions

SOP: the credential is refused on each new route for a non-school Company and for an unknown order; a replayed `POST /sales` or collection with the same key returns the same result and posts once; a refused request spends no key; the actor field. ER: one sale per invoice across a retry after a timeout; a payment verified twice posts one collection; a missing `vatCategory` refuses the invoice; a parent's tick never calls SOP; the mapping survives a crash between SOP success and the local save (replay converges). End to end on a test school: invoice raised, payment verified, SOP and GL balances agree, and the ER statement matches SOP's gross figure.
