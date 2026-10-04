# Omniview v2: EA route contracts (DRAFT 4)

**Draft 4.1 (2026-10-04, after OmniView confirmed the built Omniview API against this contract):** the exact Omniview rules EA now applies for it are written down in section 2 ("Omniview input rules"); `unreadCount` counts **tickets** with an unread support reply, not messages; new fixed detail token `body_control_characters`; Omniview's own idempotency window (48 hours) and provisional quota caps are recorded as Omniview's numbers, not EA's. No route changed.

**Changes since Draft 3 (2026-10-04, after Femi's go-live decisions via CM, CM's HIGH review of the build, and WEB's questions):**
- **D5 DECIDED: real tickets** (several per tenant, each its own thread and status, no attachments). Section 2 is no longer conditional.
- **D38 DECIDED: operators close tickets; a reply on a closed ticket becomes a new ticket.** EA's mechanism: the relay answers `409 ticket_closed` and **never creates a ticket server-side**; WEB shows "closed, start a new ticket" and carries the unsent text into the new-ticket form. A hidden server-side create would need a second idempotency key and a second Omniview call in one request, and could create a ticket the user never saw.
- **D9 for v1: the support-terms gate IS in v1.** EA serves the wording, records the acceptance and enforces it on **every** support route (including `unread`) with `403 support_terms_required`. Market-aggregate consent stays out of v1: its routes exist but its wording is a non-final placeholder, so it is dormant.
- **Placeholder wording is never served to a tenant** (new code `consent_wording_unavailable`, section 3A).
- **Support and consent routes are human-only** (a service-account token is `401`), and the edge limiter runs **before** the terms gate (sections 1, 5).
- Consent entry wire shape stated exactly for WEB (section 3A): `purpose` values `SUPPORT_TERMS` / `MARKET_AGGREGATE`, versions are JSON numbers.
- Error catalogue: new `consent_wording_unavailable`; new fixed `detail` tokens `invalid_body`, `invalid_paging`, `invalid_version`, `body_rejected`.
- EA's side is **built on local branches, not deployed** (section 11); the Omniview env names EA actually reads are in section 9.
Details are marked "(Draft 4)" below.

**Changes since Draft 2 (2026-10-04, after D41 and the industry-immutability ruling):** the consenting-tenants response loses `activeStaff` (D41 DECIDED: the market view is capitalisation plus the leverage ratio only; no tenant or staff counts), so the staff bullet, D15/D24/D40 and the FR-OV-M1 revisit fall away; industry immutability is now **DECIDED** (Femi: a Company that is a school cannot become something else), its enforcing fix is approved and queued for deploy, and one data caveat for legacy rows is recorded; a new section 7A states the EA-side **workflows** (ticket relay lifecycle, relay unavailable, quota, legacy threads, retention and erasure) with their open decisions named. Details are marked "(Draft 3)" below.

**Changes since Draft 1 (2026-10-04, after WEB's and GL's reviews of `16f5d31`):** ticket summary gains `subject`; create returns `{ticket, message}`; message paging defined (latest page by default, `before`/`after`); body limit unit stated (UTF-16 code units); idempotency edge cases (`idempotency_key_reused`, a stated dedupe window); closed-ticket reply refused (`ticket_closed`, PROPOSED); `retryAfterSeconds` in the 429 body plus `Access-Control-Expose-Headers`; closed enums are lockstep changes; section 4 reshaped for GL (GL supplies the tenant-to-Company mapping, tenant status unused per D37, staff aggregates removed from this route for v1, industry-immutability fix noted, GL's client rules); two new error codes. Details are marked "(Draft 2)" below.

**Status (Draft 4, 2026-10-04): EA's side is BUILT on local branches and NOT deployed or applied** (see section 11); Omniview's side, the Cognito client and the private network path are other sessions' work and are not live. Owner: the EA session, per Femi's D3 ("Definitely.. It is where the owner Admin lives. The dashboard there is his"). Inputs: `Omniview_v2_Software_Requirements_Specification.md` (FR-OV-S*, FR-OV-M8, NFR-OV-8/14, D3, D5, D9, D15, D24, D33-D36), `Omniview_v2_EA_Request.md` and WEB's and GL's feasibility notes, all on the FiSH repo (read at branch `docs/omniview-v2-sputo-r20`). Everything below was checked against EA's code on master (`d091252`) unless marked ASSUMPTION.

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

**Human callers only (Draft 4).** The support and consent routes are mounted under the human token provider alone. A token from any of the service providers (GL, POP, SOP, IM, HR) is `401` there even when its identity happens to hold an Owner-Admin Membership, so a service identity can never raise or read a tenant's tickets or accept a consent in the owner's name. (Section 4's GL-only route is the opposite case and stays service-only.)

## 2. Support ticket relay (tenant-facing)

All routes: Owner Admin of `{tenantId}`; **every** route here, including `unread`, also requires the current **support terms** accepted (section 3), else `403 support_terms_required`. **D5 DECIDED (Draft 4): real tickets** (several per tenant, each its own thread and status; no attachments).

| Route | Body / query | Success | Notes |
|---|---|---|---|
| `POST /tenants/{tenantId}/support/tickets` | `{body, companyId?}`; header `Idempotency-Key` (required) | `201 {ticket, message}` (Draft 2: the ticket summary and its first message, so WEB renders without a second fetch) | `companyId` is optional context only, must be a Company of the tenant (else `400 validation_failed`). EA adds tenant display name when calling Omniview |
| `GET /tenants/{tenantId}/support/tickets` | none | `200` array of ticket summaries, most recent activity first, **max 50, no paging in v1** | **a response of exactly 50 may be clipped** (Draft 2): clients show "the 50 most recent"; paging is deferred, not forgotten |
| `GET /tenants/{tenantId}/support/tickets/{ticketId}/messages` | optional `before=<messageId>` or `after=<messageId>` (not both) | `200` array of messages, **always oldest first within the page**, max 100 | **(Draft 2)** no parameter = the **latest** page (up to 100). `before` = up to 100 messages immediately earlier than that id. `after` = up to 100 messages later than that id (incremental polling). **A page shorter than 100 means there is nothing further in that direction** |
| `POST /tenants/{tenantId}/support/tickets/{ticketId}/messages` | `{body}`; header `Idempotency-Key` (required) | `201` message | a reply on an Answered ticket reopens it (SRS S8, Omniview's rule). **A reply on a CLOSED ticket is refused `409 ticket_closed`** (Draft 4, **D38 DECIDED**: operators close; a reply on a closed ticket becomes a NEW ticket. EA never creates the new ticket itself and Omniview never reopens: WEB turns this answer into "start a new ticket" and carries the unsent text into the new-ticket form) |
| `POST /tenants/{tenantId}/support/tickets/{ticketId}/read` | none | `204` | server-side read marker, held in Omniview per tenant + reader (S17) |
| `GET /tenants/{tenantId}/support/unread` | none | `200 {unreadCount, hasUnread, latestReplyAt?}` | cheap poll; see caching below. **`unreadCount` counts TICKETS that have an unread support reply, not messages** (Draft 4.1, Omniview) |

**Shapes** (all fields always present unless marked `?`):

- Ticket summary: `{id, tenantId, subject, status, companyId?, createdAt, lastActivityAt, hasUnread}`; `status` is `OPEN | ANSWERED | CLOSED`. **`subject` (Draft 2)** is plain text derived by Omniview from the first message (whitespace collapsed, truncated to at most 80 UTF-16 code units, never HTML), so the list renders without fetching each thread. It is ticket content: it lives in Omniview and EA only relays it.
- Message: `{id, ticketId, tenantId, senderId?, fromSupport, body, sentAt}`. `senderId` is the opaque userId of the Owner Admin, absent when `fromSupport` is true. **The direction field is `fromSupport`; it is named once and never renamed silently** (WEB's legacy `fromOperator` stays only on the legacy routes).
- Body: plain text, trimmed, non-blank, **max 4,000 UTF-16 code units** (PROPOSED; Draft 2: the unit is JavaScript's `string.length` and Kotlin's `String.length`, measured after trimming, so an emoji counts as 2 and a message WEB's counter accepts is never rejected by EA or Omniview; a database column sized in code points is always large enough), no attachments (S22). Request payload cap 16 KiB (PROPOSED), larger answers `413 payload_too_large`.
- `Idempotency-Key`: a client-generated UUID. EA does not store it; it forwards the key to Omniview, which dedupes (S20). Semantics are **at-least-once with the key**: after a timeout or `503` the request may or may not have landed, and retrying with the same key is safe. A missing or malformed key is `400 validation_failed` (`detail: idempotency_key_missing`). **Draft 2:** reusing a key with a **different body** is `409 idempotency_key_reused` (Omniview compares a fingerprint of the request; WEB mints a new key whenever the draft changes, so this is a safety net). Omniview dedupes a key for a stated window: PROPOSED **at least 24 hours** (Omniview owns the number, OPEN); after the window a reused key may be treated as new, so clients mint a fresh key for a deliberate new send.

**Omniview input rules EA applies for it (Draft 4.1, confirmed by Omniview):**
- **Body control characters:** a body containing control characters other than newline, carriage return and tab is refused. EA refuses it first with `400 validation_failed` (`body_control_characters`), before the call; WEB should strip them while typing or pasting.
- **Tenant display name:** Omniview requires it trimmed and 1 to 200 characters (else `400 tenant_name_invalid`). EA sends a cleaned name so a tenant's support is never blocked by its own name: trimmed, cut at 200 UTF-16 units without splitting a surrogate pair, or the tenant id if the name is blank.
- **Request ids and keys:** the `Idempotency-Key` Omniview accepts is 8 to 128 characters of `A-Za-z0-9_-`; EA requires a canonical UUID, which always fits. Omniview's own unknown-field handling is strict (a request with a field it does not declare is a 400), which EA's request shapes respect.
- **Lists:** a message list is the latest 100 and the ticket list the latest 50 by activity, as in the shapes above.
- **Omniview's numbers, not EA's:** the idempotency window is 48 hours, and the quota caps are provisional and configurable in Omniview (20 not-closed tickets and 100 tenant messages per day per tenant; the open-ticket cap answers `429` with 3600 s, the daily cap with the real wait). EA hard-codes none of them and passes the wait through.
- **Token:** Omniview pins issuer, key set and audience to the app client id of EA's own Cognito client and checks the token's `aud` claim, so EA must send an **ID-style** token (the shared `CognitoServiceAccountTokenProvider` does: it returns the ID token, whose `aud` is the client id; an access token carries `client_id` instead and would be refused).

**Unread caching.** EA may cache the unread COUNT per tenant for a short TTL (PROPOSED 15 s, in memory, count only, dropped on this tenant's own read/reply). Content is never cached (rule 1).

**Omniview calls (ASSUMPTION, Omniview and CM to confirm):** EA calls Omniview's private API as a service with a Cognito service-account token, passing tenantId, opaque userId, tenant display name (create only), the idempotency key and the body. Omniview scopes every read by the tenantId EA supplies and returns the same shapes with its own ids. Timeouts (PROPOSED): connect 1 s, total 3 s for reads, 5 s for writes, no retry inside EA (the client retries with the key). Any non-2xx other than the mapped ones below, any timeout, and any undecodable body becomes `503 support_unavailable`.

Omniview-to-EA error mapping: 404 on a ticket -> `404 ticket_not_found`; 400 -> `400 validation_failed`; 429 -> `429` (`quota_exceeded` or `rate_limited`); 409 on a closed ticket -> `409 ticket_closed`; 409 on a reused key -> `409 idempotency_key_reused`; everything else -> `503 support_unavailable`. **Every `429` carries the wait twice (Draft 2):** the `Retry-After` header and `retryAfterSeconds` in the JSON body. Browsers hide `Retry-After` from cross-origin scripts unless the server sends `Access-Control-Expose-Headers: Retry-After`, so WEB reads the body field; EA also adds the expose header at build time.

## 3. Consent records (tenant-facing): two separate purposes (D35)

Two **separate, versioned** records, both owned by EA and both Owner-Admin only. **Support terms** gate every support route in v1 (D9, decided); **market-aggregate inclusion** is optional, revocable, and **never a condition of any service**. Wording and legal mechanism are D9 (Femi + solicitor); the text is data served by EA, so a rewording needs no WEB deploy (FR-OV-M8).

| Route | Body | Success | Notes |
|---|---|---|---|
| `GET /tenants/{tenantId}/consents` | none | `200` array, one entry per purpose | entry: `{purpose, currentVersion, text, accepted, acceptedVersion?, acceptedAt?}`; `accepted` means acceptedVersion equals currentVersion |
| `POST /tenants/{tenantId}/consents/support-terms/acceptance` | `{version}` | `200` the entry | idempotent; a stale `version` is `409 consent_version_stale` (client refetches) |
| `POST /tenants/{tenantId}/consents/market-aggregate/acceptance` | `{version}` | `200` the entry | same |
| `POST /tenants/{tenantId}/consents/market-aggregate/revocation` | none | `200` the entry | **no revocation route for support terms** (WEB feedback); revocation is idempotent |

**Storage (new, build-time migration; next free `V` number):** `consent_texts(purpose, version, text, effective_from)` and `consent_records(id, tenant_id, purpose, version, action ACCEPTED|REVOKED, user_id, recorded_at)`. **Append-only, never updated or deleted**; "current state" is the latest record. Texts are authored in reviewed migrations until an admin surface exists (OPEN: acceptable, or does Femi want an operator-managed text?). Existing Owner Admins have no record and are gated on first use (SRS M8).

**Rules:** support terms are "accepted" when the latest record for that purpose is ACCEPTED at the current version (a new version re-asks). Market consent for a **report date D** follows D33: the tenant counts only if its latest market record **recorded before 00:00 UTC on the 1st of D's month** is ACCEPTED at the version that was current at that boundary. OPEN (legal, D9/D33): whether acceptance of an old version survives a version bump at the boundary (default here: it lapses until re-accepted); and when an Owner-Admin ownership change (future feature) carries consent over (default: consent belongs to the tenant, the record keeps who accepted).

## 3A. Consent wire shape, the gate flow and placeholder wording (Draft 4)

**Entry shape**, from `GET /tenants/{tenantId}/consents` (an array, one entry per purpose that has final wording): `{purpose, currentVersion, text, accepted, acceptedVersion?, acceptedAt?}`.
- `purpose` is exactly `SUPPORT_TERMS` or `MARKET_AGGREGATE` (upper-snake enum names, not the path slugs; a closed enum, lockstep change).
- `currentVersion` and `acceptedVersion` are **JSON numbers** (integers). `acceptedAt` is an ISO-8601 UTC string.
- `accepted` is true only when the latest record is an acceptance of exactly `currentVersion`. `acceptedVersion`/`acceptedAt` are absent unless an acceptance is on file (a stale one still shows its old `acceptedVersion` with `accepted: false`).
- Acceptance body is `{"version": <number>}` and is strict: an extra field or a non-number is `400 validation_failed` (`invalid_body`); a version below 1 is `invalid_version`; a version that is not the current one is `409 consent_version_stale`.

**How the widget learns the gate is up (WEB's question):** one `GET /consents` when the widget first opens in a session; gate if the `SUPPORT_TERMS` entry has `accepted: false`. No flag is added to list or unread. Because every support route enforces the gate, the widget must also handle `403 support_terms_required` at any call (for example after a wording version bump, when the old acceptance lapses) by refetching `/consents`. **The widget must not poll `unread` before acceptance** (it would 403 each time); treat `support_terms_required` on `unread` as "no indicator".

**Placeholder wording is never served (Draft 4, CM's and WEB's requirement).** `consent_texts` carries a `placeholder` flag; the seeded version 1 of both purposes is placeholder text, not legal wording. While the current `SUPPORT_TERMS` wording is a placeholder: `GET /consents` answers `503 consent_wording_unavailable`, acceptance answers the same, and the gate refuses, so the support routes answer `403 support_terms_required` (the widget shows "support is not available yet", not a gate it cannot satisfy). A non-final `MARKET_AGGREGATE` entry is simply absent from the list. The real wording ships as a new row (higher version, `placeholder = FALSE`). Only the environment variable `EA_ALLOW_PLACEHOLDER_CONSENT_TEXT=true`, for a development environment, serves placeholders (and logs a warning at boot); **it must never be set in a production task definition**. Consequence: support stays deliberately unavailable in production until Femi's final wording exists.

## 4. Consenting-tenants route (GL only)

`GET /api/internal/consenting-tenants?reportDate=YYYY-MM-DD`

- **Caller:** GL's service identity only. A human token, another service's token, the operator token, or no token is rejected (`401` / `403 service_forbidden`). GL never holds an operator token.
- **Not a network boundary:** "internal" is a name. EA's load balancer is public, so the only protection is the authentication below; CM may add a listener rule denying `/api/internal/*` from the internet as defence in depth (CM's call).
- **Authentication requirement (NFR-OV-14):** a service-principal validator (no email claim, no Membership lookup), a route group authenticated by the GL provider **only**, and **fail closed when `EA_JWT_SERVICE_AUDIENCE_GL` is unset** (the group is not registered and the path answers `503 service_unavailable`; it must never fall back to the human verifier, which is what today's `glServiceVerifier ?: verifier` would do). Verified 2026-10-04: no existing route depends on that slot, so nothing live is exposed today.
- **Request:** `reportDate` only. The caller cannot select, narrow or vary the cohort (D22). EA applies D33. GL validates month-end and not-in-the-future itself before calling; EA still validates an ISO date that is not in the future and answers `400 validation_failed` (`invalid_report_date`).
- **Response (Draft 2; fully declared, no names or emails):**
  `{reportDate, consentBoundary, tenants: [{tenantId, companies: [{companyId, industryType?}]}]}` **(Draft 3: `activeStaff` removed, D41)**.
  `industryType` is `GENERIC | SCHOOL`, absent only if unknown (closed enum, lockstep change, section 0 rule 6). `consentBoundary` is the instant GL records in its operator audit entry. One unpaginated list (fine at launch scale; revisit if tenants reach the thousands).
- **GL owns the tenant-to-Company mapping (Draft 2, GL's change 1).** GL holds `companies.tenant_id` (stable, GL-owned). GL uses this route only for (a) the **consenting tenant set at the boundary** and (b) **industryType by companyId**. EA's Company list is a lookup for (b), not the source of membership; a GL Company EA does not list is "unknown industry" (whole-market only). This removes the "Company added after the boundary appears in a recomputed past report" limit for the financial cohort.
- **Tenant status is not used (Draft 2, D37 PROPOSED; Femi decides the consequence):** a tenant that consented and is later suspended or closed keeps contributing to recomputed reports for as long as its books exist (historically right for reproducibility). EA applies no status filter.
- **No staff or tenant counts in this route (Draft 3, D41 DECIDED).** Femi: the market view is aggregate capitalisation plus the leverage ratio only (counts were not asked for). So there is no `activeStaff`, no `distinctPeople`, no `staffByIndustry` and no tenant total, and none may be added without a new decision. This also removes the cohort-differencing concern GL raised (EA computing staff over a wider set than GL's final cohort), and D15/D24/D40 and the FR-OV-M1 revisit are no longer needed. The route returns membership only: which tenants consented at the boundary and, per Company, its industry.
- **Industry history (GL's gap 1).** `industryType` is current-only, so a Company changing industry would move its contribution between cells for all dates and could be differenced. Until now it could change only by a **bug**: a repeat company-registration call overwrote it. **Draft 3: immutability is DECIDED** (Femi, 2026-10-04: a school cannot become a cement factory; a business that ends closes its books), and the enforcing fix is reviewed and approved by CM (EA `fix/company-registration-integrity`, with cross-tenant uniqueness for companyId), queued to deploy in one EA release; nothing is live until it deploys. **Once it is live, industryType is immutable and no industry history is needed**; if Femi ever reverses this, an append-only effective-dated industry history in EA becomes necessary first. **Caveat on legacy data:** Companies that predate industry type were stored `GENERIC` by default. If any of them is really a school, that is a data defect to correct deliberately and with audit (Femi approves, run via CM's credential-split path) **before** relying on `industryType` for a cell; it is not something the route or the immutability rule can repair, and the rule intentionally rejects a later `GENERIC` to `SCHOOL` change. CM's read-only SQL (population by industry and school link, and school-module grants on `GENERIC` Companies) tells us whether any exist.
- **Logging (GL's point):** neither EA nor GL may log this response; it lists exactly which tenants and Companies consented. EA logs route, status, duration and request id only.
- **Errors:** `400 validation_failed` (bad date), `401 unauthorized`, `403 service_forbidden`, `503 service_unavailable`. No caching in GL (GL: `503` means publish nothing; every non-2xx, timeout or decode failure is a `503` on GL's side). EA computes live from the consent history, so a revocation is visible at the next boundary by rule, never by a cached set.
- **GL's client (Draft 2, GL's gap 4):** GL needs its own service identity at EA (a Cognito service client and a token provider; today GL forwards a human token to EA), on a **separate HttpClient with no body logging**, with a timeout of a few seconds, below Omniview's, so Omniview never waits on a hung EA. The client secret reaches GL through a task-definition change, not Jenkins (CM's lane, section 9).
- **Remaining limit, stated plainly:** EA stores no effective-dated tenant status and no Company creation date; with the two changes above neither is needed for the financial cohort, and consent history itself is exact.

## 5. Edge protections (the support routes only)

EA is the **public edge for support** and also the authorization service every other service calls (`GET /me`), runs one task and has no rate limiting today. A flood or a slow Omniview must not degrade `/me`. Requirements:

1. Limits apply **only to `/support/*`** (the consent routes carry no limit in v1: a few rare, idempotent calls per tenant), never to `/me` or other routes. **Order of checks (Draft 4, as built): authentication, Owner Admin, the edge limit, the terms gate, then the request.** The limiter (in memory) runs before the terms gate so a flood cannot become database reads. PROPOSED per tenant+user: writes 20/min, reads 120/min, answers `429 rate_limited` with `Retry-After`. In-memory per instance (fine at one task; revisit if EA scales).
2. Size limits (section 2) enforced at EA; Omniview repeats them.
3. The **authoritative per-tenant quota is Omniview's**; EA passes its `429 quota_exceeded` and `Retry-After` through.
4. Short timeouts to Omniview (section 2) and an immediate `503`, never queueing, so slow calls cannot pin EA's request threads.

## 6. Error catalogue (enumerated, stable)

| Status | `error` | When |
|---|---|---|
| 401 | `unauthorized` | missing or invalid token (existing behaviour) |
| 403 | `not_owner_admin` | caller is not the Owner Admin of the path tenant (employee, other tenant's owner, non-member) |
| 403 | `support_terms_required` | any support route (including `unread`) before the current support terms are accepted, after a wording version bump, or while the wording is still a placeholder (Draft 4) |
| 403 | `service_forbidden` | section 4 only: caller is not GL's service identity |
| 400 | `validation_failed` | empty or over-length body, bad `companyId`, bad or missing `Idempotency-Key`, bad date; `detail` carries a fixed token (`body_empty`, `body_too_long`, `invalid_company`, `idempotency_key_missing`, `invalid_report_date`, and from Draft 4: `invalid_body` malformed or unknown-field JSON, `invalid_paging` both or malformed `before`/`after`, `invalid_version` a consent version below 1, `body_rejected` Omniview refused the text, `body_control_characters` a body with control characters other than newline, carriage return and tab, from Draft 4.1) |
| 404 | `ticket_not_found` | ticket id unknown or belongs to another tenant |
| 409 | `consent_version_stale` | accepted version is not the current one |
| 409 | `ticket_closed` | reply on a CLOSED ticket (D38 DECIDED; Draft 4) |
| 409 | `idempotency_key_reused` | (Draft 2) same `Idempotency-Key` with a different body |
| 413 | `payload_too_large` | request over the byte cap |
| 429 | `rate_limited` / `quota_exceeded` | edge limit / Omniview quota; `Retry-After` header **and** `retryAfterSeconds` in the body (Draft 2) |
| 503 | `support_unavailable` | Omniview unreachable, slow, or unusable (tenant support routes) |
| 503 | `consent_wording_unavailable` | (Draft 4) the consent wording is not final (placeholder or missing), on `GET /consents`, acceptance or revocation |
| 503 | `service_unavailable` | section 4 when the GL audience is not configured or EA cannot compute |
| 409 | `legacy_thread_read_only` | legacy `POST /support-thread/messages` after retirement (section 7 only) |

## 7. Legacy operator thread and cutover (D1/D2 OPEN)

- **Recommended:** legacy read-only, nothing migrated. Existing `/tenants/{tenantId}/support-thread/messages` GET/POST and the operator routes (`X-Operator-Token`, WEB `/operator`) **stay unchanged** until WEB's widget has moved (additive, FR-OV-S23).
- After the widget moves, retiring the legacy tenant **POST** is a separate lockstep change (answers `409 legacy_thread_read_only`); the legacy GET stays so history remains readable. WEB `/operator` stays the reply surface for any legacy thread still awaiting an answer, because Omniview cannot write into EA (FR-OV-S18).
- Retiring the legacy POST also ends today's operator email on each tenant message. **D34 (new-ticket alerting) is open and must be settled first**, or support would not learn of new tickets.
- CORS already allows GET/POST/DELETE with `Authorization` and `Content-Type` and the WEB origin; the new `Idempotency-Key` request header must be added to the allowed headers, and `Retry-After` exposed with `Access-Control-Expose-Headers` (a missing CORS entry has broken a route here before).

## 7A. Workflows (Draft 3, EA side)

Each step names who does what and what happens when it fails. EA is a relay and a consent ledger here; it is **not** a ticket store.

**Raising a ticket.** Owner Admin posts with an `Idempotency-Key`. EA checks, in order: the gate (Owner Admin of that tenant), `support_terms_required` (latest support-terms record not accepted at the current version), the edge limit, body rules. It then forwards to Omniview with the key and the tenant's display name, and returns `201 {ticket, message}` from Omniview's answer. EA writes nothing for the ticket.

**Relay unavailable (PROPOSED).** If Omniview times out, refuses, or answers something EA cannot decode, EA answers `503 support_unavailable` and **queues nothing**: there is no EA-side outbox. The cost is that a message the user typed is not delivered until they retry; the benefit is that EA never holds ticket content and cannot send a stale message later. WEB keeps the draft and the same `Idempotency-Key` so a retry after a timeout cannot duplicate (at-least-once with the key, section 2). If Femi wants guaranteed delivery instead, that needs an EA outbox storing message bodies (a different privacy and retention position), so it would be an explicit decision, not an implementation detail.

**Quota (PROPOSED).** Omniview owns the quota and the unread marker. EA does not count tickets. Omniview's refusal arrives as `429`; EA returns `429 quota_exceeded` with `retryAfterSeconds` (section 2). The edge limit (`rate_limited`) is EA's own and separate.

**Replying, closing, reopening (Draft 4, D38 DECIDED).** Operators close tickets; EA exposes no close route to tenants. A reply on an Answered ticket reopens it. A reply on a Closed ticket is `409 ticket_closed`: EA does not create a new ticket and Omniview does not reopen; WEB shows "closed, start a new ticket" and carries the typed text into the new-ticket form, so nothing is lost. Auto-closing stale Answered tickets follows v1.

**Legacy threads.** The old support thread and the operator routes stay as they are (section 7). Nothing is migrated; a tenant sees old history through the legacy GET and new conversations as tickets. The two do not merge in v1.

**Consent.** Accepting support terms is required, once per wording version, before **any** support route works (Draft 4, D9 decided for v1); EA serves the wording, records the acceptance and enforces it, and Omniview enforces nothing about it. Market-aggregate consent is a separate choice that is never a condition of service; accepting and revoking are Owner-Admin only and append a record. A revocation takes effect at the **next** report boundary by rule (D33) and never rewrites a past report's cohort.

**Retention and erasure (PROPOSED; two parts OPEN).**
- Consent records are an audit trail and are append-only: EA never deletes or edits them. They hold the tenant, purpose, version, action, the accepting user's id and the time, no free text.
- Ticket content lives only in Omniview, so retention and deletion of ticket text and subjects is Omniview's policy. EA stores none and returns nothing from a cache.
- OPEN (Femi, Omniview): what happens to a tenant's tickets when the tenant is closed, and how a person's erasure request reaches Omniview. EA proposes an operator-initiated action, not an automatic cascade, and builds nothing for it until this is decided.
- OPEN (Omniview): whether a ticket message carries the author's name or email, which decides whether personal-data erasure applies to tickets at all.

## 8. Multi-tenant owner

Routes are path-scoped and the gate is evaluated per tenant, so a user who is Owner Admin of tenants A and B works on each independently, and a user who is Owner Admin of A and an employee of B is correctly rejected on B. Tickets, unread state and **both consents are per tenant** (two tenants means two acceptances). WEB must send the tenantId of the Company in view and clear its state when the tenant changes (S19).

## 9. Infrastructure and configuration (CM's lane; EA proposes names)

- EA to Omniview: a Cognito service-account app client and resource scope for EA, Omniview verifying that audience (NFR-OV-14), a private network path and security-group restriction. **Draft 4: the names EA actually reads (six, mirroring the `EA_SCHOOLADMISSIONS_*` pattern):** `EA_OMNIVIEW_BASE_URL` (origin plus any path prefix, for example `http://omniview.fish.internal:8090`), `EA_OMNIVIEW_COGNITO_REGION`, `EA_OMNIVIEW_COGNITO_CLIENT_ID`, `EA_OMNIVIEW_COGNITO_CLIENT_SECRET`, `EA_OMNIVIEW_COGNITO_USERNAME`, `EA_OMNIVIEW_COGNITO_PASSWORD` (secrets through the reviewed task-definition path). **If any is unset or blank, EA still boots, one warning logs the missing NAMES only, and the ticket routes answer `503 support_unavailable`** (new, additive feature must not crash-loop the auth service); the consent routes need no Omniview. **Never set `EA_ALLOW_PLACEHOLDER_CONSENT_TEXT` in a production task definition** (section 3A).
- GL to EA: set `EA_JWT_SERVICE_AUDIENCE_GL` (unset in production today; HR, IM, POP and SOP are set) and give GL a Cognito service client for that audience. GL also needs new client code (a service-account token provider on a separate, body-log-free HttpClient; GL forwards a human token to EA today), and its client secret reaches GL through a task-definition change (Draft 2, GL's gap 4).
- Env or task-definition changes are not carried by Jenkins (it patches only the image): same targeted, reviewed, task-definition path as past EA secret changes.

## 10. Tests the build must include

Fake `OmniviewGateway` with success, 4xx, timeout and undecodable-body cases mapped to the exact codes above; a `MockEngine` test that a malformed 200 never leaks body text; the gate matrix (Owner Admin, employee, other tenant's owner, non-member) on every tenant route; `support_terms_required` before and after acceptance and after a version bump; consent-history boundary tests (recorded just before and after 00:00 UTC on the 1st, revoke, re-accept, version bump); the GL route rejecting a human token, a POP/SOP/IM/HR token and the operator token, and failing closed with the audience unset; limits scoped to support routes only (`/me` unaffected); Idempotency-Key forwarded unchanged. Draft 2 additions: latest-page / `before` / `after` paging including a short final page; `subject` truncation at 80 UTF-16 code units; a body of exactly 4,000 and of 4,001 code units (emoji counted as 2); `ticket_closed`, `idempotency_key_reused`; a `429` carrying both the header and `retryAfterSeconds`; the GL response containing no staff or count fields at all (Draft 3: assert the exact field set per Company is `companyId` and `industryType`) and no tenant-status filtering; the GL route not logging its response.

## 11. Build order and sizing (when build resumes; no dates)

1. **Consent texts, records and routes** (small-medium): no external dependency. **Draft 4 status: built** (migration V18, which must be released after V17, the company-registration fix). The legal wording is a V19 row Femi must supply; until then the placeholder guard keeps support deliberately unavailable in production.
2. **Edge protections** (small): support-route-only limits and CORS header.
3. **Omniview gateway and ticket routes** (medium): **Draft 4 status: built** against a fake gateway and a mock Omniview, with the consent-backed gate, human-only mounting and the placeholder guard (branch `feat/omniview-support-terms`, local, not deployed). Still needed: Omniview's private API live, the Cognito client and the private path (CM), Femi's final wording.
4. **Service-principal validator and GL route** (medium): needs `EA_JWT_SERVICE_AUDIENCE_GL` and GL's call shape; this is the security-sensitive piece and gets the full test list above.
5. **Legacy POST retirement** (small, lockstep with WEB): only after D34 and the widget move.

## 12. Open items

| # | Item | Owner |
|---|---|---|
| D5 | **DECIDED (Draft 4): real tickets**, no attachments | closed |
| D38 | **DECIDED (Draft 4): operators close; a reply on a closed ticket becomes a new ticket** (relay: `409 ticket_closed`, WEB creates the new ticket with the carried text); auto-close of stale Answered tickets follows v1 | closed |
| D1/D2 | legacy operator-thread history (recommended: read-only, not migrated) | Femi |
| D9/D33 | **v1: the support-terms gate is IN** (EA serves, records and enforces it); the support-terms WORDING is still Femi's and a solicitor's (a V19 row, until then support is deliberately unavailable in production). Still open: market-consent wording, version-bump survival, revocation timing, ownership-change carry-over | Femi + solicitor |
| D15/D24/D40 | **fell away (Draft 3, D41 DECIDED): no staff or tenant counts in the market view** | closed |
| D34 | new-ticket alerting: **DECIDED in substance** (an SNS topic with an email subscription, at ticket creation and at an Owner Admin reply; Omniview's and CM's side, nothing in EA). Mailbox address and on-call remain Femi's | Femi, CM |
| D36 | where the Owner Admin revokes market consent: **not needed in v1** (market consent stays out of v1); revisit with the market view | Femi |
| - | Omniview's private API, quota and unread-marker shapes | OmniView |
| - | Cognito clients, `EA_JWT_SERVICE_AUDIENCE_GL`, private path, optional `/api/internal/*` deny | CM |
| - | consent text authoring (migration vs operator-managed) | Femi |
| D37 | cohort rule: consent at boundary intersected with Companies with posted activity; **tenant status unused**, so a consenting tenant later closed still contributes (consequence is Femi's) | Femi, GL, OmniView |
| D41 | **DECIDED (Draft 3):** market view = aggregate capitalisation plus the leverage ratio only; EA adds no staff or count fields | closed |
| - | relay unavailable: no EA outbox (PROPOSED, section 7A); guaranteed delivery would be a separate decision | Femi |
| - | ticket retention and erasure on tenant closure and on a person's request; whether messages carry author identity (section 7A) | Femi, OmniView |
| - | idempotency dedupe window (PROPOSED at least 24 h) and the closed-ticket reply rule (`ticket_closed`, PROPOSED) | OmniView, Femi |
| - | industryType immutability is DECIDED; the guard and companyId cross-tenant uniqueness are approved by CM and queued for one EA release (not live yet); until it deploys industryType is current-only. Legacy `GENERIC` rows that are really schools need an audited correction first | EA, CM, Femi |
| - | exact limit and timeout numbers (all PROPOSED) | EA with CM |
