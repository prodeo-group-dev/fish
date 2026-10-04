# Omniview v2: EA route contracts (DRAFT 2)

**Changes since Draft 1 (2026-10-04, after WEB's and GL's reviews of `16f5d31`):** ticket summary gains `subject`; create returns `{ticket, message}`; message paging defined (latest page by default, `before`/`after`); body limit unit stated (UTF-16 code units); idempotency edge cases (`idempotency_key_reused`, a stated dedupe window); closed-ticket reply refused (`ticket_closed`, PROPOSED); `retryAfterSeconds` in the 429 body plus `Access-Control-Expose-Headers`; closed enums are lockstep changes; section 4 reshaped for GL (GL supplies the tenant-to-Company mapping, tenant status unused per D37, staff aggregates removed from this route for v1, industry-immutability fix noted, GL's client rules); two new error codes. Details are marked "(Draft 2)" below.

**Status, 2026-10-04: DESIGN ONLY. Nothing here is built, branched for build, deployed or applied; "build" is suspended.** Owner: the EA session, per Femi's D3 ("Definitely.. It is where the owner Admin lives. The dashboard there is his"). Inputs: `Omniview_v2_Software_Requirements_Specification.md` (FR-OV-S*, FR-OV-M8, NFR-OV-8/14, D3, D5, D9, D15, D24, D33-D36), `Omniview_v2_EA_Request.md` and WEB's and GL's feasibility notes, all on the FiSH repo (read at branch `docs/omniview-v2-sputo-r20`). Everything below was checked against EA's code on master (`d091252`) unless marked ASSUMPTION.

Marks: **DECIDED** (Femi), **PROPOSED** (EA's recommendation, needs the named owner), **OPEN** (someone else's call). Numbers marked PROPOSED are starting values, not measurements.

## 0. Contract rules (apply to every route below)

1. **EA stores no ticket content** (FR-OV-S14). Tickets, replies, the read marker and the authoritative quota live in Omniview. EA keeps only consent records (section 3) and, optionally, a few-second in-memory cache of an unread COUNT.
2. **Fail closed.** If Omniview is unreachable, slow, answers non-2xx unexpectedly, or answers a body EA cannot decode, EA answers `503 support_unavailable`. It never falls back to the legacy operator-thread store (FR-OV-S15).
3. **No raw text in errors or logs.** Error bodies use the fixed codes in section 6 and fixed wording. EA never returns or logs an exception message or a response-body fragment on these routes (a decoding error can quote ticket text). Allowed log fields: tenantId, ticketId, opaque userId, route, status, duration, request id.
4. **Baseline conventions** (same as today's support thread): path-scoped `/tenants/{tenantId}/...` under `/api`; `Authorization: Bearer <Cognito ID token>` only; errors `{error, detail?}` (`error` is the stable code; a `429` body also carries `retryAfterSeconds`, Draft 2); ISO-8601 UTC instants; JSON; additive routes.
5. **Strict decoding.** Every DTO EA receives from Omniview is fully declared (no `ignoreUnknownKeys`). **Nothing is added to `GET /me`**: consent and ticket state have their own routes, so GL/POP/SOP/IM do not need a lockstep change.
6. **The error-code list in section 6 is an enumerated, stable contract** (WEB maps each code to wording and treats an unknown code generically). Adding or renaming a code follows the lockstep pattern (field diff first, coordinated window). **Closed enums are the same (Draft 2, GL's point):** `status` (`OPEN | ANSWERED | CLOSED`), `industryType` (`GENERIC | SCHOOL`) and consent `purpose` are closed. GL and WEB decode strictly, so an unknown value fails the decode (GL then answers 503 and publishes nothing). Adding a value is therefore a lockstep change (consumer field-diff first, then EA ships), not "additive".
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
| `POST /tenants/{tenantId}/support/tickets` | `{body, companyId?}`; header `Idempotency-Key` (required) | `201 {ticket, message}` (Draft 2: the ticket summary and its first message, so WEB renders without a second fetch) | `companyId` is optional context only, must be a Company of the tenant (else `400 validation_failed`). EA adds tenant display name when calling Omniview |
| `GET /tenants/{tenantId}/support/tickets` | none | `200` array of ticket summaries, most recent activity first, **max 50, no paging in v1** | **a response of exactly 50 may be clipped** (Draft 2): clients show "the 50 most recent"; paging is deferred, not forgotten |
| `GET /tenants/{tenantId}/support/tickets/{ticketId}/messages` | optional `before=<messageId>` or `after=<messageId>` (not both) | `200` array of messages, **always oldest first within the page**, max 100 | **(Draft 2)** no parameter = the **latest** page (up to 100). `before` = up to 100 messages immediately earlier than that id. `after` = up to 100 messages later than that id (incremental polling). **A page shorter than 100 means there is nothing further in that direction** |
| `POST /tenants/{tenantId}/support/tickets/{ticketId}/messages` | `{body}`; header `Idempotency-Key` (required) | `201` message | a reply on an Answered ticket reopens it (SRS S8, Omniview's rule). **A reply on a CLOSED ticket is refused `409 ticket_closed`** (Draft 2, PROPOSED: closed stays closed; the client starts a new ticket; Omniview/Femi to confirm, it is a ticket-state rule) |
| `POST /tenants/{tenantId}/support/tickets/{ticketId}/read` | none | `204` | server-side read marker, held in Omniview per tenant + reader (S17) |
| `GET /tenants/{tenantId}/support/unread` | none | `200 {unreadCount, hasUnread, latestReplyAt?}` | cheap poll; see caching below |

**Shapes** (all fields always present unless marked `?`):

- Ticket summary: `{id, tenantId, subject, status, companyId?, createdAt, lastActivityAt, hasUnread}`; `status` is `OPEN | ANSWERED | CLOSED`. **`subject` (Draft 2)** is plain text derived by Omniview from the first message (whitespace collapsed, truncated to at most 80 UTF-16 code units, never HTML), so the list renders without fetching each thread. It is ticket content: it lives in Omniview and EA only relays it.
- Message: `{id, ticketId, tenantId, senderId?, fromSupport, body, sentAt}`. `senderId` is the opaque userId of the Owner Admin, absent when `fromSupport` is true. **The direction field is `fromSupport`; it is named once and never renamed silently** (WEB's legacy `fromOperator` stays only on the legacy routes).
- Body: plain text, trimmed, non-blank, **max 4,000 UTF-16 code units** (PROPOSED; Draft 2: the unit is JavaScript's `string.length` and Kotlin's `String.length`, measured after trimming, so an emoji counts as 2 and a message WEB's counter accepts is never rejected by EA or Omniview; a database column sized in code points is always large enough), no attachments (S22). Request payload cap 16 KiB (PROPOSED), larger answers `413 payload_too_large`.
- `Idempotency-Key`: a client-generated UUID. EA does not store it; it forwards the key to Omniview, which dedupes (S20). Semantics are **at-least-once with the key**: after a timeout or `503` the request may or may not have landed, and retrying with the same key is safe. A missing or malformed key is `400 validation_failed` (`detail: idempotency_key_missing`). **Draft 2:** reusing a key with a **different body** is `409 idempotency_key_reused` (Omniview compares a fingerprint of the request; WEB mints a new key whenever the draft changes, so this is a safety net). Omniview dedupes a key for a stated window: PROPOSED **at least 24 hours** (Omniview owns the number, OPEN); after the window a reused key may be treated as new, so clients mint a fresh key for a deliberate new send.

**Unread caching.** EA may cache the unread COUNT per tenant for a short TTL (PROPOSED 15 s, in memory, count only, dropped on this tenant's own read/reply). Content is never cached (rule 1).

**Omniview calls (ASSUMPTION, Omniview and CM to confirm):** EA calls Omniview's private API as a service with a Cognito service-account token, passing tenantId, opaque userId, tenant display name (create only), the idempotency key and the body. Omniview scopes every read by the tenantId EA supplies and returns the same shapes with its own ids. Timeouts (PROPOSED): connect 1 s, total 3 s for reads, 5 s for writes, no retry inside EA (the client retries with the key). Any non-2xx other than the mapped ones below, any timeout, and any undecodable body becomes `503 support_unavailable`.

Omniview-to-EA error mapping: 404 on a ticket -> `404 ticket_not_found`; 400 -> `400 validation_failed`; 429 -> `429` (`quota_exceeded` or `rate_limited`); 409 on a closed ticket -> `409 ticket_closed`; 409 on a reused key -> `409 idempotency_key_reused`; everything else -> `503 support_unavailable`. **Every `429` carries the wait twice (Draft 2):** the `Retry-After` header and `retryAfterSeconds` in the JSON body. Browsers hide `Retry-After` from cross-origin scripts unless the server sends `Access-Control-Expose-Headers: Retry-After`, so WEB reads the body field; EA also adds the expose header at build time.

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
- **Request:** `reportDate` only. The caller cannot select, narrow or vary the cohort (D22). EA applies D33. GL validates month-end and not-in-the-future itself before calling; EA still validates an ISO date that is not in the future and answers `400 validation_failed` (`invalid_report_date`).
- **Response (Draft 2; fully declared, no names or emails):**
  `{reportDate, consentBoundary, tenants: [{tenantId, companies: [{companyId, industryType?, activeStaff}]}]}`.
  `industryType` is `GENERIC | SCHOOL`, absent only if unknown (closed enum, lockstep change, section 0 rule 6). `consentBoundary` is the instant GL records in its operator audit entry. One unpaginated list (fine at launch scale; revisit if tenants reach the thousands).
- **GL owns the tenant-to-Company mapping (Draft 2, GL's change 1).** GL holds `companies.tenant_id` (stable, GL-owned). GL uses this route only for (a) the **consenting tenant set at the boundary** and (b) **industryType by companyId**. EA's Company list is a lookup for (b), not the source of membership; a GL Company EA does not list is "unknown industry" (whole-market only). This removes the "Company added after the boundary appears in a recomputed past report" limit for the financial cohort.
- **Tenant status is not used (Draft 2, D37 PROPOSED; Femi decides the consequence):** a tenant that consented and is later suspended or closed keeps contributing to recomputed reports for as long as its books exist (historically right for reproducibility). EA applies no status filter.
- **Staff aggregates are NOT in this route for v1 (Draft 2, GL's gap 2, EA agrees).** GL's final cohort is EA's set filtered by GL eligibility; a staff total EA computed over EA's full set (and deduplicated across tenants) could not be recomputed for GL's smaller cohort, giving two cohorts that can be differenced against each other. So `distinctPeople`, `staffByIndustry` and a tenant-level staff total are removed. Per-Company `activeStaff` stays: **the count of ACTIVE Memberships holding an assignment at that Company** (PENDING and REVOKED excluded; the Owner-Admin is counted because they hold an OWNER_ADMIN assignment at every Company). It is **not** a count of distinct people. A distinct-people / by-industry staff figure (D15/D24, OPEN) is served later from EA over a cohort EA fully controls, designed separately; SRS FR-OV-M1 needs revisiting for this.
- **Industry history (GL's gap 1).** `industryType` is current-only, so a Company changing industry would move its contribution between cells for all dates and could be differenced. Today it can change only by a **bug**: a repeat company-registration call overwrites it (found 2026-10-04; a guard making it truly immutable, plus cross-tenant uniqueness for companyId, is being fixed in EA as a separate PR under CM review). **Once that guard lands, industryType is immutable and no industry history is needed**; if Femi ever wants industry to be changeable, an append-only effective-dated industry history in EA becomes necessary first.
- **Logging (GL's point):** neither EA nor GL may log this response; it lists exactly which tenants and Companies consented. EA logs route, status, duration and request id only.
- **Errors:** `400 validation_failed` (bad date), `401 unauthorized`, `403 service_forbidden`, `503 service_unavailable`. No caching in GL (GL: `503` means publish nothing; every non-2xx, timeout or decode failure is a `503` on GL's side). EA computes live from the consent history, so a revocation is visible at the next boundary by rule, never by a cached set.
- **GL's client (Draft 2, GL's gap 4):** GL needs its own service identity at EA (a Cognito service client and a token provider; today GL forwards a human token to EA), on a **separate HttpClient with no body logging**, with a timeout of a few seconds, below Omniview's, so Omniview never waits on a hung EA. The client secret reaches GL through a task-definition change, not Jenkins (CM's lane, section 9).
- **Remaining limit, stated plainly:** EA stores no effective-dated tenant status and no Company creation date; with the two changes above neither is needed for the financial cohort, and consent history itself is exact.

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
| 409 | `ticket_closed` | (Draft 2) reply on a CLOSED ticket (PROPOSED rule) |
| 409 | `idempotency_key_reused` | (Draft 2) same `Idempotency-Key` with a different body |
| 413 | `payload_too_large` | request over the byte cap |
| 429 | `rate_limited` / `quota_exceeded` | edge limit / Omniview quota; `Retry-After` header **and** `retryAfterSeconds` in the body (Draft 2) |
| 503 | `support_unavailable` | Omniview unreachable, slow, or unusable (tenant support routes) |
| 503 | `service_unavailable` | section 4 when the GL audience is not configured or EA cannot compute |
| 409 | `legacy_thread_read_only` | legacy `POST /support-thread/messages` after retirement (section 7 only) |

## 7. Legacy operator thread and cutover (D1/D2 OPEN)

- **Recommended:** legacy read-only, nothing migrated. Existing `/tenants/{tenantId}/support-thread/messages` GET/POST and the operator routes (`X-Operator-Token`, WEB `/operator`) **stay unchanged** until WEB's widget has moved (additive, FR-OV-S23).
- After the widget moves, retiring the legacy tenant **POST** is a separate lockstep change (answers `409 legacy_thread_read_only`); the legacy GET stays so history remains readable. WEB `/operator` stays the reply surface for any legacy thread still awaiting an answer, because Omniview cannot write into EA (FR-OV-S18).
- Retiring the legacy POST also ends today's operator email on each tenant message. **D34 (new-ticket alerting) is open and must be settled first**, or support would not learn of new tickets.
- CORS already allows GET/POST/DELETE with `Authorization` and `Content-Type` and the WEB origin; the new `Idempotency-Key` request header must be added to the allowed headers, and `Retry-After` exposed with `Access-Control-Expose-Headers` (a missing CORS entry has broken a route here before).

## 8. Multi-tenant owner

Routes are path-scoped and the gate is evaluated per tenant, so a user who is Owner Admin of tenants A and B works on each independently, and a user who is Owner Admin of A and an employee of B is correctly rejected on B. Tickets, unread state and **both consents are per tenant** (two tenants means two acceptances). WEB must send the tenantId of the Company in view and clear its state when the tenant changes (S19).

## 9. Infrastructure and configuration (CM's lane; EA proposes names)

- EA to Omniview: a Cognito service-account app client and resource scope for EA, Omniview verifying that audience (NFR-OV-14), a private network path and security-group restriction. PROPOSED EA env names: `EA_OMNIVIEW_BASE_URL`, `EA_OMNIVIEW_COGNITO_*` (mirroring the existing `EA_SCHOOLADMISSIONS_*` pattern). **If unset, EA still boots and the ticket routes answer `503 support_unavailable`** (new, additive feature must not crash-loop the auth service); the consent routes need no Omniview.
- GL to EA: set `EA_JWT_SERVICE_AUDIENCE_GL` (unset in production today; HR, IM, POP and SOP are set) and give GL a Cognito service client for that audience. GL also needs new client code (a service-account token provider on a separate, body-log-free HttpClient; GL forwards a human token to EA today), and its client secret reaches GL through a task-definition change (Draft 2, GL's gap 4).
- Env or task-definition changes are not carried by Jenkins (it patches only the image): same targeted, reviewed, task-definition path as past EA secret changes.

## 10. Tests the build must include

Fake `OmniviewGateway` with success, 4xx, timeout and undecodable-body cases mapped to the exact codes above; a `MockEngine` test that a malformed 200 never leaks body text; the gate matrix (Owner Admin, employee, other tenant's owner, non-member) on every tenant route; `support_terms_required` before and after acceptance and after a version bump; consent-history boundary tests (recorded just before and after 00:00 UTC on the 1st, revoke, re-accept, version bump); the GL route rejecting a human token, a POP/SOP/IM/HR token and the operator token, and failing closed with the audience unset; limits scoped to support routes only (`/me` unaffected); Idempotency-Key forwarded unchanged. Draft 2 additions: latest-page / `before` / `after` paging including a short final page; `subject` truncation at 80 UTF-16 code units; a body of exactly 4,000 and of 4,001 code units (emoji counted as 2); `ticket_closed`, `idempotency_key_reused`; a `429` carrying both the header and `retryAfterSeconds`; the GL response containing no staff aggregates and no tenant-status filtering; the GL route not logging its response.

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
| D37 | cohort rule: consent at boundary intersected with Companies with posted activity; **tenant status unused**, so a consenting tenant later closed still contributes (consequence is Femi's) | Femi, GL, OmniView |
| - | staff counts: distinct-people / by-industry figures to be served from EA over a cohort EA controls, separate from this route (D15/D24); FR-OV-M1 to be revisited | Femi, OmniView, GL |
| - | idempotency dedupe window (PROPOSED at least 24 h) and the closed-ticket reply rule (`ticket_closed`, PROPOSED) | OmniView, Femi |
| - | industryType immutability guard and companyId cross-tenant uniqueness (EA bug fix, CM go-ahead given, under CM review); until it lands industryType is current-only | EA, CM |
| - | exact limit and timeout numbers (all PROPOSED) | EA with CM |
