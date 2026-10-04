# Omniview v2: EA route contracts (DRAFT 1)

**Status, 2026-10-04: DESIGN ONLY. Nothing here is built, branched for build, deployed or applied; "build" is suspended.** Owner: the EA session, per Femi's D3 ("Definitely.. It is where the owner Admin lives. The dashboard there is his"). Inputs: `Omniview_v2_Software_Requirements_Specification.md` (FR-OV-S*, FR-OV-M8, NFR-OV-8/14, D3, D5, D9, D15, D24, D33-D36), `Omniview_v2_EA_Request.md` and WEB's and GL's feasibility notes, all on the FiSH repo (read at branch `docs/omniview-v2-sputo-r20`). Everything below was checked against EA's code on master (`d091252`) unless marked ASSUMPTION.

Marks: **DECIDED** (Femi), **PROPOSED** (EA's recommendation, needs the named owner), **OPEN** (someone else's call). Numbers marked PROPOSED are starting values, not measurements.

## 0. Contract rules (apply to every route below)

1. **EA stores no ticket content** (FR-OV-S14). Tickets, replies, the read marker and the authoritative quota live in Omniview. EA keeps only consent records (section 3) and, optionally, a few-second in-memory cache of an unread COUNT.
2. **Fail closed.** If Omniview is unreachable, slow, answers non-2xx unexpectedly, or answers a body EA cannot decode, EA answers `503 support_unavailable`. It never falls back to the legacy operator-thread store (FR-OV-S15).
3. **No raw text in errors or logs.** Error bodies use the fixed codes in section 6 and fixed wording. EA never returns or logs an exception message or a response-body fragment on these routes (a decoding error can quote ticket text). Allowed log fields: tenantId, ticketId, opaque userId, route, status, duration, request id.
4. **Baseline conventions** (same as today's support thread): path-scoped `/tenants/{tenantId}/...` under `/api`; `Authorization: Bearer <Cognito ID token>` only; errors `{error, detail?}` (`error` is the stable code); ISO-8601 UTC instants; JSON; additive routes.
5. **Strict decoding.** Every DTO EA receives from Omniview is fully declared (no `ignoreUnknownKeys`). **Nothing is added to `GET /me`**: consent and ticket state have their own routes, so GL/POP/SOP/IM do not need a lockstep change.
6. **The error-code list in section 6 is an enumerated, stable contract** (WEB maps each code to wording and treats an unknown code generically). Adding or renaming a code follows the lockstep pattern (field diff first, coordinated window).
7. Identity that crosses to Omniview: the **tenantId, an opaque userId, and the tenant display name** supplied by EA on each create call (DECIDED in SRS S9/S12). No email, no person name (D17 if operators later need more).

## 1. Who may call what

| Caller | Gate (existing code) | Routes |
|---|---|---|
| Tenant Owner Admin (human, Cognito ID token) | `eaAuthenticated` + `authorizeTenantOwnerAdmin(tenantId)` | Section 2 and section 3 tenant routes |
| Tenant employee / non-member | same gate: rejected | `403 not_owner_admin` (not `forbidden`: the new routes map their own code; the existing gate answers `forbidden`) |
| GL service identity | **NEW**: a service-principal validator, GL provider ONLY | Section 4 only |
| Omniview | EA calls Omniview (outbound); Omniview never calls EA | n/a |
| Platform operator | unchanged `X-Operator-Token` routes | legacy operator routes (section 7) |

A tenant that is not the caller's gets `403 not_owner_admin`; **404 only for a ticket id** that does not belong to the tenant (no existence leak, FR-OV-S10).

## 2. Support ticket relay (tenant-facing)

All routes: Owner Admin of `{tenantId}`; ticket routes also require the current **support terms** accepted (section 3), else `403 support_terms_required`. **D5 (ticket shape) is Femi's**; this section is written for real tickets (WEB sized: medium). If Femi chooses one thread per tenant, the same routes apply with the ticket id fixed to the tenant's single ticket (create becomes "start the thread"), and no list route is needed.

| Route | Body / query | Success | Notes |
|---|---|---|---|
| `POST /tenants/{tenantId}/support/tickets` | `{body, companyId?}`; header `Idempotency-Key` (required) | `201` ticket summary | `companyId` is optional context only, must be a Company of the tenant (else `400 validation_failed`). EA adds tenant display name when calling Omniview |
| `GET /tenants/{tenantId}/support/tickets` | none | `200` array of ticket summaries, most recent activity first, max 50 | no paging in v1 |
| `GET /tenants/{tenantId}/support/tickets/{ticketId}/messages?after=<messageId>` | optional `after` cursor | `200` array of messages oldest first, max 100 | cursor = last message id the client holds |
| `POST /tenants/{tenantId}/support/tickets/{ticketId}/messages` | `{body}`; header `Idempotency-Key` (required) | `201` message | a reply on an Answered ticket reopens it (SRS S8, Omniview's rule) |
| `POST /tenants/{tenantId}/support/tickets/{ticketId}/read` | none | `204` | server-side read marker, held in Omniview per tenant + reader (S17) |
| `GET /tenants/{tenantId}/support/unread` | none | `200 {unreadCount, hasUnread, latestReplyAt?}` | cheap poll; see caching below |

**Shapes** (all fields always present unless marked `?`):

- Ticket summary: `{id, tenantId, status, companyId?, createdAt, lastActivityAt, hasUnread}`; `status` is `OPEN | ANSWERED | CLOSED`.
- Message: `{id, ticketId, tenantId, senderId?, fromSupport, body, sentAt}`. `senderId` is the opaque userId of the Owner Admin, absent when `fromSupport` is true. **The direction field is `fromSupport`; it is named once and never renamed silently** (WEB's legacy `fromOperator` stays only on the legacy routes).
- Body: plain text, trimmed, non-blank, **max 4,000 characters** (PROPOSED), no attachments (S22). Request payload cap 16 KiB (PROPOSED), larger answers `413 payload_too_large`.
- `Idempotency-Key`: a client-generated UUID. EA does not store it; it forwards the key to Omniview, which dedupes (S20). Semantics are **at-least-once with the key**: after a timeout or `503` the request may or may not have landed, and retrying with the same key is safe. A missing or malformed key is `400 validation_failed` (`detail: idempotency_key_missing`).

**Unread caching.** EA may cache the unread COUNT per tenant for a short TTL (PROPOSED 15 s, in memory, count only, dropped on this tenant's own read/reply). Content is never cached (rule 1).

**Omniview calls (ASSUMPTION, Omniview and CM to confirm):** EA calls Omniview's private API as a service with a Cognito service-account token, passing tenantId, opaque userId, tenant display name (create only), the idempotency key and the body. Omniview scopes every read by the tenantId EA supplies and returns the same shapes with its own ids. Timeouts (PROPOSED): connect 1 s, total 3 s for reads, 5 s for writes, no retry inside EA (the client retries with the key). Any non-2xx other than the mapped ones below, any timeout, and any undecodable body becomes `503 support_unavailable`.

Omniview-to-EA error mapping: 404 on a ticket -> `404 ticket_not_found`; 400 -> `400 validation_failed`; 429 -> `429` (`quota_exceeded` or `rate_limited`, `Retry-After` passed through); everything else -> `503 support_unavailable`.

## 3. Consent records (tenant-facing): two separate purposes (D35)

Two **separate, versioned** records, both owned by EA and both Owner-Admin only. **Support terms** may gate raising a ticket; **market-aggregate inclusion** is optional, revocable, and **never a condition of any service**. Wording and legal mechanism are D9 (Femi + solicitor); the text is data served by EA, so a rewording needs no WEB deploy (FR-OV-M8).

| Route | Body | Success | Notes |
|---|---|---|---|
| `GET /tenants/{tenantId}/consents` | none | `200` array, one entry per purpose | entry: `{purpose, currentVersion, text, accepted, acceptedVersion?, acceptedAt?}`; `accepted` means acceptedVersion equals currentVersion |
| `POST /tenants/{tenantId}/consents/support-terms/acceptance` | `{version}` | `200` the entry | idempotent; a stale `version` is `409 consent_version_stale` (client refetches) |
| `POST /tenants/{tenantId}/consents/market-aggregate/acceptance` | `{version}` | `200` the entry | same |
| `POST /tenants/{tenantId}/consents/market-aggregate/revocation` | none | `200` the entry | **no revocation route for support terms** (WEB feedback); revocation is idempotent |

**Storage (new, build-time migration; next free `V` number):** `consent_texts(purpose, version, text, effective_from)` and `consent_records(id, tenant_id, purpose, version, action ACCEPTED|REVOKED, user_id, recorded_at)`. **Append-only, never updated or deleted**; "current state" is the latest record. Texts are authored in reviewed migrations until an admin surface exists (OPEN: acceptable, or does Femi want an operator-managed text?). Existing Owner Admins have no record and are gated on first use (SRS M8).

**Rules:** support terms are "accepted" when the latest record for that purpose is ACCEPTED at the current version (a new version re-asks). Market consent for a **report date D** follows D33: the tenant counts only if its latest market record **recorded before 00:00 UTC on the 1st of D's month** is ACCEPTED at the version that was current at that boundary. OPEN (legal, D9/D33): whether acceptance of an old version survives a version bump at the boundary (default here: it lapses until re-accepted); and when an Owner-Admin ownership change (future feature) carries consent over (default: consent belongs to the tenant, the record keeps who accepted).

## 4. Consenting-tenants route (GL only)

`GET /api/internal/consenting-tenants?reportDate=YYYY-MM-DD`

- **Caller:** GL's service identity only. A human token, another service's token, the operator token, or no token is rejected (`401` / `403 service_forbidden`). GL never holds an operator token.
- **Not a network boundary:** "internal" is a name. EA's load balancer is public, so the only protection is the authentication below; CM may add a listener rule denying `/api/internal/*` from the internet as defence in depth (CM's call).
- **Authentication requirement (NFR-OV-14):** a service-principal validator (no email claim, no Membership lookup), a route group authenticated by the GL provider **only**, and **fail closed when `EA_JWT_SERVICE_AUDIENCE_GL` is unset** (the group is not registered and the path answers `503 service_unavailable`; it must never fall back to the human verifier, which is what today's `glServiceVerifier ?: verifier` would do). Verified 2026-10-04: no existing route depends on that slot, so nothing live is exposed today.
- **Request:** `reportDate` only. The caller cannot select, narrow or vary the cohort (D22). EA applies D33.
- **Response (fully declared, no names or emails):**
  `{reportDate, consentBoundary, tenants: [{tenantId, companies: [{companyId, industryType?, activeStaff}], activeStaff}], staffByIndustry: [{industryType?, distinctPeople}], distinctPeople}`.
  `industryType` is `GENERIC | SCHOOL`, absent only if unknown. The staff fields are **PROPOSED and OPEN (D15, D24)**: counts are computed inside EA so no user id ever reaches GL; default rule = distinct ACTIVE Memberships (PENDING and REVOKED excluded), owner counted because the Owner-Admin holds an OWNER_ADMIN assignment at every Company, distinct people deduplicated by userId across tenants.
- **Errors:** `400 validation_failed` (bad date), `401 unauthorized`, `403 service_forbidden`, `503 service_unavailable`. No caching in GL (GL: `503` means publish nothing). EA computes live from the consent history, so a revocation is visible at the next boundary by rule, never by a cached set.
- **Known limits, stated plainly (differencing risk, SRS 7.1):** EA stores **no effective-dated tenant status and no Company creation date**, so for a past `reportDate` EA can apply consent history exactly but can only use the tenant's **current** status and **current** Companies. A Company added or a tenant suspended after the boundary would appear or vanish in a recomputed past report. Either accept this (month-end reports are produced once, close to the date) or schedule a small history addition; OPEN for Omniview/GL.

## 5. Edge protections (the support routes only)

EA is the **public edge for support** and also the authorization service every other service calls (`GET /me`), runs one task and has no rate limiting today. A flood or a slow Omniview must not degrade `/me`. Requirements:

1. Limits apply **only to `/support/*` and `/consents/*`**, never to `/me` or other routes. PROPOSED per tenant+user: writes 20/min, reads 120/min, answers `429 rate_limited` with `Retry-After`. In-memory per instance (fine at one task; revisit if EA scales).
2. Size limits (section 2) enforced at EA; Omniview repeats them.
3. The **authoritative per-tenant quota is Omniview's**; EA passes its `429 quota_exceeded` and `Retry-After` through.
4. Short timeouts to Omniview (section 2) and an immediate `503`, never queueing, so slow calls cannot pin EA's request threads.

## 6. Error catalogue (enumerated, stable)

| Status | `error` | When |
|---|---|---|
| 401 | `unauthorized` | missing or invalid token (existing behaviour) |
| 403 | `not_owner_admin` | caller is not the Owner Admin of the path tenant (employee, other tenant's owner, non-member) |
| 403 | `support_terms_required` | ticket route before the current support terms are accepted |
| 403 | `service_forbidden` | section 4 only: caller is not GL's service identity |
| 400 | `validation_failed` | empty or over-length body, bad `companyId`, bad or missing `Idempotency-Key`, bad date; `detail` carries a fixed token (`body_empty`, `body_too_long`, `invalid_company`, `idempotency_key_missing`, `invalid_report_date`) |
| 404 | `ticket_not_found` | ticket id unknown or belongs to another tenant |
| 409 | `consent_version_stale` | accepted version is not the current one |
| 413 | `payload_too_large` | request over the byte cap |
| 429 | `rate_limited` / `quota_exceeded` | edge limit / Omniview quota, with `Retry-After` |
| 503 | `support_unavailable` | Omniview unreachable, slow, or unusable (tenant support routes) |
| 503 | `service_unavailable` | section 4 when the GL audience is not configured or EA cannot compute |
| 409 | `legacy_thread_read_only` | legacy `POST /support-thread/messages` after retirement (section 7 only) |

## 7. Legacy operator thread and cutover (D1/D2 OPEN)

- **Recommended:** legacy read-only, nothing migrated. Existing `/tenants/{tenantId}/support-thread/messages` GET/POST and the operator routes (`X-Operator-Token`, WEB `/operator`) **stay unchanged** until WEB's widget has moved (additive, FR-OV-S23).
- After the widget moves, retiring the legacy tenant **POST** is a separate lockstep change (answers `409 legacy_thread_read_only`); the legacy GET stays so history remains readable. WEB `/operator` stays the reply surface for any legacy thread still awaiting an answer, because Omniview cannot write into EA (FR-OV-S18).
- Retiring the legacy POST also ends today's operator email on each tenant message. **D34 (new-ticket alerting) is open and must be settled first**, or support would not learn of new tickets.
- CORS already allows GET/POST/DELETE with `Authorization` and `Content-Type` and the WEB origin; the new `Idempotency-Key` request header must be added to the allowed headers (a missing CORS entry has broken a route here before).

## 8. Multi-tenant owner

Routes are path-scoped and the gate is evaluated per tenant, so a user who is Owner Admin of tenants A and B works on each independently, and a user who is Owner Admin of A and an employee of B is correctly rejected on B. Tickets, unread state and **both consents are per tenant** (two tenants means two acceptances). WEB must send the tenantId of the Company in view and clear its state when the tenant changes (S19).

## 9. Infrastructure and configuration (CM's lane; EA proposes names)

- EA to Omniview: a Cognito service-account app client and resource scope for EA, Omniview verifying that audience (NFR-OV-14), a private network path and security-group restriction. PROPOSED EA env names: `EA_OMNIVIEW_BASE_URL`, `EA_OMNIVIEW_COGNITO_*` (mirroring the existing `EA_SCHOOLADMISSIONS_*` pattern). **If unset, EA still boots and the ticket routes answer `503 support_unavailable`** (new, additive feature must not crash-loop the auth service); the consent routes need no Omniview.
- GL to EA: set `EA_JWT_SERVICE_AUDIENCE_GL` (unset in production today; HR, IM, POP and SOP are set) and give GL a Cognito service client for that audience.
- Env or task-definition changes are not carried by Jenkins (it patches only the image): same targeted, reviewed, task-definition path as past EA secret changes.

## 10. Tests the build must include

Fake `OmniviewGateway` with success, 4xx, timeout and undecodable-body cases mapped to the exact codes above; a `MockEngine` test that a malformed 200 never leaks body text; the gate matrix (Owner Admin, employee, other tenant's owner, non-member) on every tenant route; `support_terms_required` before and after acceptance and after a version bump; consent-history boundary tests (recorded just before and after 00:00 UTC on the 1st, revoke, re-accept, version bump); the GL route rejecting a human token, a POP/SOP/IM/HR token and the operator token, and failing closed with the audience unset; limits scoped to support routes only (`/me` unaffected); Idempotency-Key forwarded unchanged.

## 11. Build order and sizing (when build resumes; no dates)

1. **Consent texts, records and routes** (small-medium): no external dependency; legal wording (D9) can be placeholder text until Femi decides.
2. **Edge protections** (small): support-route-only limits and CORS header.
3. **Omniview gateway and ticket routes** (medium): needs Omniview's private API, the Cognito client and the private path (CM), D5.
4. **Service-principal validator and GL route** (medium): needs `EA_JWT_SERVICE_AUDIENCE_GL` and GL's call shape; this is the security-sensitive piece and gets the full test list above.
5. **Legacy POST retirement** (small, lockstep with WEB): only after D34 and the widget move.

## 12. Open items

| # | Item | Owner |
|---|---|---|
| D5 | one thread per tenant or real tickets | Femi |
| D1/D2 | legacy operator-thread history (recommended: read-only, not migrated) | Femi |
| D9/D33 | consent wording; version-bump survival; revocation timing; ownership-change carry-over | Femi + solicitor |
| D15/D24 | staff definition and by-industry counting | Femi |
| D34 | new-ticket alerting for Prodeo support | Femi, CM |
| D36 | where the Owner Admin revokes market consent | Femi |
| - | Omniview's private API, quota and unread-marker shapes | OmniView |
| - | Cognito clients, `EA_JWT_SERVICE_AUDIENCE_GL`, private path, optional `/api/internal/*` deny | CM |
| - | consent text authoring (migration vs operator-managed) | Femi |
| - | past-date recompute limits (no effective-dated tenant status or Company creation date) | OmniView, GL |
| - | exact limit and timeout numbers (all PROPOSED) | EA with CM |
