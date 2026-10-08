# RBAC: SOP's statement (current rules, re-verified findings, gaps, plan)

**Owner:** SOP session. **Date:** 2026-10-08. **Status:** DOCS ONLY, the application-round reply requested by CM for `docs/RBAC_SPUTO.md` v0.2. **No code and no authorization-model change** (freeze respected). Everything below was read from `fish-sales-order-processing` `origin/master` at `51f005d` (PR #24 merged; CM reports the :43 release with the Company scoping live and the decimal-quantity release in progress); line numbers are on that commit. Items I could not verify by reading code are marked *(not verified)*.

## 1. SOP's current authorization rules, as the code does them today

### 1.1 Who the caller is
- A human token is a Cognito JWT verified RS256 against one issuer, audience and JWKS (`SOP_JWT_ISSUER`, `SOP_JWT_AUDIENCE`, `SOP_JWT_JWKS_URL`, `Auth.kt`). The only claim SOP reads is `email` (no `sub`); it is not trimmed or lower-cased by SOP. SOP then forwards the caller's own bearer token to EA `GET /me`, so EA does the actual email matching.
- Education Runtime's service account is a second JWT provider (`SOP_JWT_SERVICE_AUDIENCE_SCHOOLADMISSIONS`); a token it validates becomes `VerifiedIdentity(email, isServiceAccount = true)`. No other service calls SOP today (POP, IM, HR, GL, WEB-as-human do not use a service identity into SOP).

### 1.2 The decision (`SopMembershipAuthorizer`, `Auth.kt`)
1. EA `/me` unreachable: **503** (fail closed). No token: **401**.
2. The caller must hold a Membership in **this deployment's single Tenant** (`SOP_EA_TENANT_ID`); otherwise 403 "No active Membership in this deployment's Tenant".
3. At the **Company in question** the caller needs (a) an access level at least the route's floor and (b) the **`SOP` module granted** at that Company. SOP uses **only READ and WRITE** as floors; **APPROVE and ADMIN are never required by any SOP route**.
4. **Owner Admin uplift (2026-10-06, Femi: "Owner Admin should get write on Sales"):** the Owner Admin of this Tenant is treated as WRITE with the `SOP` module granted at every Company EA reports under the Tenant, without an explicit assignment (`effectiveAccess`, `Auth.kt`). A higher explicit level still wins; there is no uplift to APPROVE/ADMIN; a Company not listed by EA gets no uplift. This rule is the single place that function applies, and it also drives the list of Companies a person may read (below).

### 1.3 Which Company a record belongs to (live since 2026-10-07, SOP :42/:43)
| Record | Company taken from | Read | Write |
|---|---|---|---|
| Sales order (`POST /api/sales`, `GET /api/sales`, `GET /sales-orders/{id}`, collections, cancel, create) | the authorized `companyId` (the body's `entityId` is ignored) | READ at that Company; a record of an unreadable Company is **404** | WRITE at the order's Company; the collection's `companyId` must equal the order's |
| Customer routes, reports, invoice email, availability | the **path** `companyId` | READ at it | WRITE at it |
| Return request, credit note, inspection | the customer's Company | as above | as above; the body `companyId` of an inspection or credit note must equal it |
| Complaint | its return request's Company | as above | as above |
| Bill for Collection | its order's customer's Company (fallback the order's entity) | none (no list) | as above; the collect `companyId` must equal it |
| Facility headroom | **none** (Tenant-wide) | any Sales reader | any WRITE caller opens it |
- A person's `GET /api/sales` lists only the Companies where they are READ plus module-granted. A sale or sales order is refused (404 `customer_not_found`) unless the customer belongs to the request's Company.
- A record whose Company cannot be resolved is invisible to people.

### 1.4 Service accounts (Education Runtime's token)
- `authorizeSop` returns true at once for a service account: **no Membership, no Company check, no module check** on any route; `readableSopCompanies()` returns "all Companies". The credential is not bound to any Tenant or Company. The only call it makes is creating a guardian as a customer. **ER calls `POST /api/customers`, a flat route that no longer exists on SOP (customer routes live only under `/api/companies/{companyId}/customers` since Wave 0R.3, 2026-09-30), so by code reading that call is broken today; reported to the ER session, not verified in production.**
- Exception: the **invoice email** routes refuse service accounts outright (a person must be signed in).

### 1.5 Invoice email (live 2026-10-07)
Human only; WRITE at the Company confirmed against EA; one recipient, strictly validated; 10-minute duplicate guard per invoice and recipient; 50 sends per Company per UTC day; claim-first so concurrent clicks send once; `sentBy` is the token's email; **Reply-To is the Tenant Owner Admin's email**, fetched from EA's service-principal owner-contact route (SOP's service identity is the same Cognito service-account token it uses for GL); no resolvable address means nothing is sent (503). The recipient is stored for audit and never logged.

### 1.6 Approvals and actors as built
- **There is no approval step on SOP's money acts.** Recording a sale, a collection, a credit note, a Bill collection, a cancellation and a return inspection are each executed directly by a WRITE caller.
- The only "approval" is **ordinary sales and sales-orders auto-confirming the aval gate as `ConfirmingAuthority.SALES_ADMIN`** (a constant in code, not the person), and **returns with a CUSTOMER_CANCELLATION line requiring "CFO/Accountant authority" that the client asserts in a body field** (`approvedBy`, F2 below).
- **SOP records no acting identity** on sales, collections, credit notes, return transitions, complaints or Bills. `requestedByEmail` is read from the token and passed to the sale use case but not stored. The only attributed rows are the invoice-email sends (`sentBy`). Idempotency keys store no actor.

### 1.7 SOP's own outbound identities
One Cognito service-account user for **GL** (all Companies, Tenant fixed by `SOP_GL_ENGINE_TENANT_ID` sent as `X-Tenant-Id`, `ktor_gl_engine_gateway.kt:176`), one for **IM**, and the GL token again to **EA** owner-contact. The Company is always taken per request, never from the environment (checked 2026-10-08 for IM).

## 2. Re-verification of the survey items that name SOP

| Item | Verdict on `origin/master` 51f005d | Where |
|---|---|---|
| **F1** fail-open service verifier | **Confirmed, latent.** `installSopJwtAuth(verifier, educationRuntimeServiceVerifier ?: verifier)`. `buildJwksServiceVerifierForEducationRuntime()` returns `null` when `SOP_JWT_SERVICE_AUDIENCE_SCHOOLADMISSIONS` is unset (`Auth.kt:127`), so the **human** verifier is registered as the service provider and any valid human token becomes `isServiceAccount = true` (full bypass). CM reports the variable is set in production; I did not read the live task definition. | `Application.kt:396`, `Auth.kt:127` |
| **F2** body-supplied approving authority | **Confirmed.** `approvedBy` is parsed from the request body into `ConfirmingAuthority` and passed to `ReturnRequest.approve`, which only checks `approvedBy == CFO_ACCOUNTANT` for CUSTOMER_CANCELLATION returns. Any WRITE caller can claim it. **Same class, not in the survey:** the legacy low-level `POST /record-sale` takes `confirmedBy` from the body (`SalesOrderRoutes.kt:68`) and confirms the aval gate as that authority. | `ReturnRequestRoutes.kt:145`, `return_request.kt:61`, `SalesOrderRoutes.kt:68` |
| **F3** creator and approver can be the same person | **Confirmed for SOP:** credit notes (amount supplied by the caller), cancellations and Bill collections need only WRITE and record no actor, so creator, approver and issuer are indistinguishable. | `IssueCreditNoteUseCase`, `CreditNote` (no actor field) |
| **F6** blanket service tokens | **Confirmed.** ER's token bypasses every check on every route except invoice email and is bound to no Company. | `Auth.kt` `authorizeSop`, `readableSopCompanies` |
| **F7** "Company missing from /me" fall-back | **Not exploitable in SOP but inconsistent.** `CallerMembership.accessLevelAt` returns READ for an Owner Admin when the Company is absent from `/me`; modules are then empty so every route denies, which is effectively NONE. | `ea_membership_gateway.kt` |
| New, SOP-specific | **S1** facility headroom (capacity and consumption) is opened and written with WRITE and read Tenant-wide: R3 says a limit like this is ADMIN-only. **S2** no actor is recorded on any money act (P9/R10). **S3** ER's only SOP call targets a removed route (see 1.4), which also means the one service-account path SOP has is untested end to end. | `TradeFinanceCollectionRoutes.kt`, ER `KtorSopCustomerGateway.kt:51` |

## 3. Gaps against R1-R13 and the tasks that touch SOP (estimates are build plus tests in SOP, excluding review)

| Task | What SOP does | Estimate | Depends on |
|---|---|---|---|
| **T1** remove the fail-open fall-back | When the ER service audience is unset, register a **deny-all service provider** (service tokens get 401) instead of reusing the human verifier, log a warning; keep starting normally so non-ER deployments are unaffected. Test: unset variable + a human token on a service-only path is 401. | 0.25 day | none (safe now) |
| **T4** Company absent from `/me` = NONE | `accessLevelAt` returns NONE when the Company is not in `/me`, for the Owner Admin too. No visible change today (modules are already empty). | 0.25 day | none (safe now) |
| **T2** canonical email | Trim and lower-case at the token boundary (`VerifiedIdentity`), so `sentBy`, future actor columns and logs are canonical. EA's matching is EA's T2: SOP forwards the raw token. | 0.25 day | none |
| **T5a** capability set consumer | Declare the new capability field strictly (nullable with a default) before EA ships it, then map SOP's routes: read routes = view, sales/collection/returns/Bill steps = enter, credit-note issue and cancellation after fulfilment = approve, facility limits and thresholds = administer. | 0.5 day + tests | EA T5a design |
| **S-T1** record the acting identity | Add `created_by`/`issued_by`/`approved_by` (token email, canonical) to sales orders, collections, return requests and transitions, credit notes, complaints, Bills; one additive migration; shown in the list DTOs. Prerequisite for any creator != approver rule. | 1 day | T2 |
| **T8** SOP approvals | Derive the approving authority from the caller's **approve capability**, never from a body field; **remove `approvedBy` and the legacy `confirmedBy`** (accept and ignore for one release so WEB does not break); creator != approver on returns and credit notes for employees, the Owner exempt and flagged (D6). | 1.5 days | S-T1, T5a, WEB stops sending the fields |
| **S-T2** scope the ER credential (T15) | Route allow-list for service accounts (today only customer creation; later Epic 13's inbox), plus a Company binding when EA/GL define it. | 0.5 day (allow-list) | D5, EA |
| **S-T3** facility limits ADMIN-only (R3) | Open/change headroom needs the administer capability. | 0.25 day | T5a |
| **T7** remove the Sales WRITE uplift | Delete the Owner Admin branch of `effectiveAccess` once EA creates the Owner's explicit assignments and backfills existing Companies. One function; the Company-scoped list logic keeps working unchanged. | 0.25 day | EA T6 live and backfilled |
| **T16** WEB | Out of SOP; SOP exposes nothing new. | n/a | |
| **T17** audit record | S-T1 is SOP's share. | included | EA defines the shape |

**Proposed order in SOP:** T1, T4, T2 (all safe, in one small branch) -> T5a consumer when EA is ready -> S-T1 -> S-T3 -> T8 -> S-T2 once D5 is decided -> T7 last, only after EA's backfill is verified (removing it earlier would stop an Owner Admin from selling). Each step ships as its own reviewed release; none starts before CM lifts the freeze.

## 4. Objections and things the SPUTO misses

1. **Most SOP money acts have no approval step at all (R2/P3 assume one).** Applying "creator != approver" needs a decision on WHICH SOP acts need a second person. My recommendation: credit notes, cancellation after fulfilment, Bill collections and write-offs yes; recording an ordinary or cash sale and a collection no (the Owner records his own sales). This needs Femi (**D7**).
2. **Credit-note issue should need the approve capability, not WRITE** (it reduces receivables and revenue). Today the caller also supplies the amount. Same decision D7.
3. **T7's timing.** The uplift must stay until EA's explicit Owner assignments are live **and backfilled**; the SPUTO says "removed once the assignments exist", which should read "once they exist for every existing Company".
4. **ER's service credential is about to get bigger.** Epic 13 (school fee billing) adds an ER-to-SOP inbox and SOP-to-ER events. R7 (a credential bound to a Tenant or Company, plus an endpoint set) should be settled **before** the inbox is built, so it is the first user of a scoped credential instead of a second blanket one.
5. **"Tenant comes from the Company, not a deploy-time value" (P6/T15) is the same decision as multi-tenant SOP.** SOP fixes the Tenant in two variables (`SOP_EA_TENANT_ID`, `SOP_GL_ENGINE_TENANT_ID`); deriving it per Company is the Epic 13 prerequisite EA found. Please keep T15 and that decision together.
6. **Reads can be financial.** `customers-with-balances` and the reports expose receivable balances to any READ caller with the Sales module. That is acceptable (P1 is about writing) but the capability model should say whether "view financial data" is its own capability.

## 5. What SOP needs from others

- **EA:** the capability set on `/me` (T5a, declared consumers-first); the Owner's explicit assignments and a backfill (T6); the acting person's stable id (`userId`/`sub`) on `/me` for the audit columns; canonical email matching (T2).
- **GL:** if the SOP credential becomes Tenant-bound (T15), whether GL will refuse a posting for a Company outside the credential's scope, and the answer on its Tenant-header options.
- **Education Runtime / Epic 13:** the scoped credential for its inbox (point 4) and a statement of which SOP routes it will call.
- **WEB:** stop sending `approvedBy`/`confirmedBy` (T8), and gate controls by capability (T16).
- **CM / Femi:** D5 (service credential scope), D7 (which SOP acts need a second person, and credit-note issue = approve), and whether T1 should deny-all (my proposal) or refuse to start.

## 6. CM's answers, 2026-10-08 (recorded here so the statement stays current)

- **T1:** accepted as proposed: a human verifier never doubles as a service provider; an unset audience means a deny-all service provider, a loud warning, and the app still starts (R6 will say so).
- **S-T1 (record the acting identity)** is added to the SPUTO task list as a prerequisite for "creator != approver"; SOP may claim and build it as a safe-now item. EA's `/me` already carries `userId` (SOP's `EaMyProfileResponseDto` declares it), so the audit columns can hold the stable id next to the canonical email. **Not claimed or started: Femi's go is pending.**
- **T7:** only after EA's explicit Owner assignments exist and are backfilled. CM notes EA's statement says registration has given the Owner an OWNER_ADMIN assignment at ADMIN with all modules since 2026-09-23, so the SOP uplift may already be redundant for newer Companies; CM is checking production data first.
- **D7** (which SOP acts need a second person; my recommendation: credit notes, cancellation after fulfilment, Bill collections and write-offs yes; ordinary and cash sales and collections no) goes to Femi, with "view financial data" as its own capability.
- The legacy `POST /record-sale` `confirmedBy` body field is recorded as **F2b**, the facility-limit WRITE as **F9**. Epic 13: a scoped credential (R7/T15) comes before the ER inbox.

## 7. Impact analysis: what SOP adopts as written, and what breaks (with proposals to the author)

Femi, 2026-10-08: "analyse the overall RBAC and see how it impacts your own work. Where it is adoptable, we adopt; where it breaks things we work out and propose a solution to the author." Read against SOP's live code and in-flight work (idempotency, Company scoping, invoice email, cash sales, decimal quantity, service invoices, the Epic 13 school-billing half, WEB's Sales screens, EA's dashboard reads). Proposals are addressed to CM as author of `docs/RBAC_SPUTO.md`.

### 7.1 Adopted as written (no conflict with anything SOP does)

| RBAC item | Why it fits SOP |
|---|---|
| P1, P2 read is not write; the Owner is not a financial writer by virtue of being owner | SOP already gives no role posting rights by title; the only owner rule is the Sales uplift, which T7 removes. |
| P4, R6 (as refined by CM: deny-all) | T1. SOP keeps starting; service routes reject every token. |
| P5 one vocabulary, R1 definitions | SOP uses only READ and WRITE today, so adopting four capabilities is additive (T5a consumer). |
| P8 the server decides | Every SOP route already checks; the UI never relied upon. |
| P9, R10 attribution | S-T1; SOP has the gap (no actor recorded) and wants the fix. |
| R8 absent Company = NONE | T4, effectively already true. |
| R9 canonical email | T2. |
| R3 thresholds and policy are ADMIN-only | Applies to facility limits (F9) and, if made configurable, the invoice-email daily cap and retention. |
| P3 with D6 (Owner exempt, flagged) | Fits the one-person business; SOP's Owner records his own sales and collections. |
| P7, R7 scoped service credentials | Wanted for ER's credential before the Epic 13 inbox is built. |
| P10, R12 runtime contract | Epic 13 is the first real use: ER maps its Bursar and cashier roles to SOP capabilities. |

### 7.2 What breaks, and the proposed fix

**B1. T5a's migration can lock out every existing administrator at SOP (HIGH).** Today ADMIN sits above WRITE on a ladder, so a person at ADMIN passes every SOP write. If the migration turns existing ADMIN assignments into "administer only" (D1), every current ADMIN loses write at SOP, including the Owner if his explicit roles are not yet created and backfilled. *Proposal:* the migration maps each legacy level to the full set it implied: READ gives {read}; WRITE gives {read, write}; APPROVE gives {read, write, approve}; ADMIN gives {read, write, approve, administer}. Behaviour is unchanged on day one. Only assignments created afterwards can be narrower (for example "administer only"). Consumers declare the new field first (nullable with a default), then EA ships it, then services switch from level to capability. Narrowing existing people is a separate, deliberate step per Company.

**B2. Interim hole until T5a: ADMIN still implies WRITE.** A person given ADMIN only to administer (an HR officer, say) passes every SOP write today. SOP cannot close this without the capability set. *Proposal:* record it as an accepted interim risk and make T5a's cut-over order explicit: consumers first, then EA, then narrowing.

**B3. Approvals by a service or on behalf of a human (R2 meets Epic 13).** R2 says the approver is stored from the token. For ER-originated acts (a Bursar's payment, a waiver, a void) the token is the ER service credential, not the person. Two rules are missing. *Proposal:* (a) a service principal may enter but **never approve**; approvals are only by a human token with the approve capability. (b) Every service-originated money act carries an `actedBy` block (the origin system's stable user id and role at origin) that SOP stores as attributed-by-service, next to the service identity. Add both to R2/R7. SOP's own legacy equivalent is the constant `SALES_ADMIN` it writes as the aval authority on every ordinary sale: replace it with the acting user and drop the constant (S-T1/T8).

**B4. P6/R7 "the Tenant comes from the Company" breaks SOP's fixed Tenant (and is the multi-tenant decision).** SOP fixes the Tenant in two variables and sends it to GL as a header. Deriving it per Company needs a Company-to-Tenant answer for **service** calls (a human call already carries the Tenant in the caller's membership). *Proposal:* EA exposes an internal route for service principals, `GET /api/internal/companies/{companyId}`, returning `{tenantId}` (same family as the owner-contact route); GL validates `X-Tenant-Id` against the Company's real Tenant and against the credential's declared Tenant set; SOP then sends the Tenant it was told by EA instead of a variable. This is exactly the prerequisite EA found for Epic 13; **settle it with that decision, not separately.**

**B5. SOP uses one service identity for GL and EA (P7).** The EA owner-contact route accepts the same Cognito app client SOP uses for GL, so a token minted for GL is valid at EA (and the reverse). *Proposal:* a distinct app client and audience per recipient (SOP to EA gets its own), as SOP already has for IM. Cheap, and it belongs in T15's list.

**B6. R2's creator-versus-approver rule needs a creator.** SOP stores no creator on any money act, so the rule cannot be enforced or even audited. *Proposal:* S-T1 is an explicit prerequisite of T8 (CM accepted); the audit columns are `created_by`, `approved_by`, `self_approved` (true only for the Owner, per D6), each holding the stable id and canonical email.

**B7. Segregation of duties inside payments (Epic 13, ER-FEE-009) needs action-level capabilities, not just a level.** "The person who records a payment cannot void a receipt or approve a waiver" is expressible with four capabilities **only if** record-payment is `write` and void, waiver and refund are `approve` and the creator-differs rule applies to them. *Proposal:* state in R1 that `approve` covers voids, waivers, refunds and write-offs for every module, and that `write` never does. SOP's Epic 13 half is written to that.

**B8. A class of read is financial (point 6, accepted).** `customers-with-balances` and the reports show receivable balances to any reader of the Sales module. *Proposal:* define `read` as "non-financial detail" and add `view-financial` as its own capability in R1, with the migration giving it to every legacy READ and above (so nothing disappears on day one).

**B9. T7 can be unsafe if it runs before the capability cut-over.** The uplift also decides which Companies a person may list in Sales. *Proposal:* remove it only after (a) EA's explicit Owner assignments are verified in production for every existing Company (CM is checking) and (b) B1's mapping is live. Until then keep it as is. The change is one function in SOP.

**B10. Idempotent replays are safe, no change needed.** A keyed replay passes the same authorization as the first call (access is checked before the claim), so a revoked capability blocks a replay. Noted so nobody adds a second check.

### 7.3 Effects on SOP's roadmap if the RBAC plan is adopted

| SOP item | Effect |
|---|---|
| Epic 13 school billing (SOP half) | Gains a hard prerequisite: a scoped ER credential (R7/T15) and `actedBy` (B3) before the inbox is built; payments, voids, waivers and refunds are written against the capability split (B7). |
| Services / decimal quantity / cash sales | None. They are `write` acts by the Owner or an employee. |
| Invoice email | None. It stays human-only and `write`; Reply-To still resolves to the Owner. |
| Stock-line key (T5) with IM | None (service to service). |
| Safe-now branch (T1, T4, T2) | Ready to build on CM's go: about 0.75 day in one reviewed branch. |
| S-T1, T8, S-T3 | Follow in that order after T5a is declared; S-T1 needs Femi's go. |

