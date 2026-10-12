# How the Education Runtime credential is allowed in school Companies at SOP: design note

Status: design only, 2026-10-12. Led by the Education Runtime (+ER) session at Femi's direction ("The Education Runtime should actually design it"); SOP and EA contribute facts. **No code until CM has reviewed.** Replaces the hand-kept `SOP_ER_COMPANY_IDS` list (Decisions_Log, 2026-10-12: every school recognises its income through SOP, so the credential must work in every school Company by a rule, and never in a non-school Company).

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

`GET /api/internal/companies/{companyId}/industry`, answering exactly `{"industryType":"SCHOOL"}` or `{"industryType":"GENERIC"}`; 404 for an unknown Company. Callable only by SOP's own service principal (see 6, an infrastructure item for CM). SOP decodes it **strictly** (no `ignoreUnknownKeys`), per the standing rule for auth payloads. Minimal on purpose: one field, no school id, no names.

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
| **CM** | SOP's own service principal for calling EA (new Cognito app client plus EA-side authorisation), env vars (`SOP_EA_INDUSTRY_*`), apply order, remove `SOP_ER_COMPANY_IDS` from Infrastructure | S-M |

## 6. Build order

1. **SOP idempotency** first. It is independent, valuable on its own, and unblocks safe retry. ER sending the header earlier is harmless (SOP ignores an unknown header), so ER can follow immediately.
2. **EA route and SOP's principal** (EA + CM, in parallel with 1).
3. **SOP rule switch**: ship the gateway and the new check; flip the check on only when EA's route is live. Until then the existing refuse-everywhere default stays in force.
4. **ER header**, then a real end-to-end check on a test school (below).
5. Remove `SOP_ER_COMPANY_IDS`.

## 7. Test plan

**SOP (unit, route and real-Postgres):** ER credential with a SCHOOL Company: customers create and read succeed. GENERIC: 403 `not_a_school_company`. EA 404, EA 5xx, EA timeout, undecodable EA body, unknown industry value: fail closed with the table's status. Malformed Company id: 400 and EA not called. Positive answer cached; refusal and error not cached (EA called again). A human token's path is untouched. A route that has not opted in still 403. Idempotency: same key twice gives one Customer and the same id; same key with a different body gives 422; a refused request leaves no key; two concurrent first calls give exactly one row (Postgres, real concurrency); replay returns 200 not 201.

**EA:** route answers exactly one field; refuses any caller but SOP's principal; unknown Company 404; contract fixture in `fish-contracts` decodes through SOP's strict client (no `ignoreUnknownKeys`).

**ER:** header present and equal to the guardian account id; after a 503 the retry sends the same key and reuses the account; 403 maps to `billing_not_enabled`, 503 to `billing_unavailable`, `sop_bad_response` stays loud (already tested in `e532ac4`).

**End to end (test school):** a school Company bills a guardian once and a retry does not duplicate; a non-school Company is refused with the same body as an unknown one; EA stopped, the call returns `billing_unavailable`; EA back, the same request succeeds.

## 8. Open questions (for CM and Femi, not blocking review)

1. **SOP's principal for calling EA** does not exist yet: new Cognito app client, or an existing one? (CM.)
2. **Cache lifetime** for positive answers (10 minutes proposed).
3. **Should ER also treat `502 sop_bad_response` as retryable** once idempotency is live? Proposed as a later, separate decision.
4. **Reading customers**: the credential may also read customers in a school Company; consider later whether it should see only Customers it created. Out of scope here.
