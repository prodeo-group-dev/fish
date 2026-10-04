# Omniview v2: request to the EA session (UNOWNED: no EA session exists)

**Status, 2026-10-04: PLANNING / DESIGN ONLY. Nothing here is to be built, branched, deployed or applied.** Femi approved sending planning requests to GL, WEB and EA (relayed via CM). GL and WEB have theirs. **There is no EA session, so this request has not been delivered and the EA-side work has no owner.** CM is raising that with Femi. Whoever picks up EA (a new session, or the session Femi nominates): read this, then the three v2 documents on FiSH master, then reply to the Omniview session ("FiSH+ER OmniView") with feasibility and gaps; the answers go back into the v2 documents.

**Why it matters.** EA's route contract gates two other pieces: **WEB's** support-chat widget calls EA's ticket routes (it must never call Omniview, which is never internet-facing), and **GL's** Market Support aggregate route reads the consenting set from EA. Product Support (Wave 7) and Market Support (Wave 8) cannot start without it.

**References (FiSH master):** `docs/Omniview_v2_Software_Requirements_Specification.md` (FR-OV-S1..S16, FR-OV-M8, NFR-OV-8/14, decisions D1-D4, D9, D12, D15-D18, D24), `docs/Omniview_v2_Backlog.md` (7B.5, 7B.7, 7C.7, 8B.1), `docs/Omniview_v2_Use_Cases.md` (UC-OV-5, 8, 9, 10). Treasury, gold and rates are **deferred** (SRS section 11); ignore them.

## Settled (DECIDED by Femi)

Omniview is **never internet-facing** (private network only; a tenant's browser never reaches it). Only a tenant's **Owner Admin** raises a ticket. Tickets arrive only through a FiSH service over the private network; replies are **pulled** back the same way; Omniview never pushes. **EA is not Omniview**: the tenancy's own owner-and-staff communication in EA continues unchanged. Omniview is read-only toward every other service and writes only to its own database.

## 1. Ticket relay (backlog 7B.7)

**PROPOSED, not yet confirmed by Femi (D3): EA is the relay.** Reasons: EA already authenticates the Owner Admin (`GET /me` `isOwnerAdmin`; `authorizeTenantOwnerAdmin`) and hosts today's support chat and email gateway.

Asked: Owner-Admin ticket create / list / read routes that verify the Owner Admin with the existing gate and call Omniview over the private network **as a service** (a Cognito service-account audience; NFR-OV-14), and:

- store **no ticket content** (FR-OV-S14); tickets live only in Omniview;
- **fail closed** if Omniview is unreachable, never falling back to the legacy operator-thread store (FR-OV-S15);
- enforce a per-tenant ticket quota and size limits **at the public edge** (FR-OV-S16, D18; the platform has no rate limiting today, so this is new);
- reject an employee's ticket (FR-OV-S11); employees keep the tenancy chat.

**OPEN, Femi's:** D1/D2 (what happens to EA's existing operator-thread routes and messages; recommended: legacy read-only, nothing migrated), D12 (may a reply be emailed, and who sends it: Omniview or EA's `SupportNotificationGateway`), D17 (data protection of ticket text).

## 2. Consent record (backlog 8B.1)

Market reports may include only tenants whose Owner Admin has consented. **No consent mechanism exists anywhere** (grepped EA, GL, WEB, HR, POP, SOP, IM). **PROPOSED:** EA owns a versioned, revocable record, Owner Admin only, recording who, when and which wording version; revocation excludes the tenant from the next report. Wording and legal mechanism are **OPEN** (D9, solicitor).

## 3. Consenting-tenants route (backlog 8B.1)

**PROPOSED:** an operator-only, read-only route returning, per consenting tenant, its Companies with each Company's `industryType` (stored per Company, migration V13) and per-Company staff assignment counts, readable by **GL's service identity** and Omniview's. GL calls it itself (D22, DECIDED) so no caller can choose the cohort.

Questions: can EA authorise a service credential on a route today (its operator routes use `X-Operator-Token`)? What does "staff" mean for counts (D15 **OPEN**; proposed: distinct active Memberships, and distinct people per industry, D24 **OPEN**)?

## What is wanted back

Feasibility, gaps and effort; anything wrong in the SRS; what you need from Omniview or Femi; and the case of one user who is Owner Admin of more than one tenant. Also write down the **route contracts** (shapes, error codes for 401/403/quota/Omniview-unreachable, fields for polling or unread) so GL's and WEB's designs can be checked against them.


## Added 2026-10-04: WEB's contract requirements (assumptions to re-confirm; EA has no owner)

From WEB's feasibility view (SRS section 12.1). WEB builds only against real, deployed routes, so these are **written-down needs, not a design of EA's routes**, to be confirmed by whoever owns EA.

**Baseline** (today's EA support thread, for new routes to match where sensible): path-scoped `/tenants/{tenantId}/...`; `Authorization: Bearer <Cognito ID token>` only; errors `{error, detail?}`; messages `{id, tenantId, senderId, fromOperator, body, sentAt}` oldest first.

- **A. Identity and access.** The server enforces that the caller is the Owner Admin of the path tenant; the widget hides the control only as a courtesy. Another tenant's ticket returns **404**, not 403 (FR-OV-S10, S21).
- **B. Ticket shape** (D5 is Femi's). If tickets: create `POST .../support/tickets {body, optional companyId}`; a lightweight list (id, status, createdAt, lastActivityAt, unread indicator); read `.../tickets/{id}/messages` oldest first with an optional `after` cursor; reply `POST .../tickets/{id}/messages`. If one thread per tenant, the same routes without the ticket id. Name the direction field once (WEB uses `fromOperator` today; `fromSupport` is fine) and never rename it silently.
- **C. Idempotent create and reply** via a client-supplied key, so a retry cannot raise two tickets; on the unreachable failure nothing was persisted (FR-OV-S20).
- **D. Polling and unread.** A very small summary route (for example `GET .../support/unread` returning `{hasUnread, latestReplyAt}`) so background polling does not pull full threads, and a server-side read marker (`POST .../tickets/{id}/read`) so unread syncs across devices; if EA will not do the marker, WEB falls back to per-device storage and says so (FR-OV-S17). If email on reply is decided (D12), the user-facing text can say so; otherwise the widget must not imply they will be told.
- **E. Error codes** the widget must tell apart: 401, 403 `not_owner_admin`, 403/409 `support_terms_required`, 404 `ticket_not_found`, 400 validation, 429 `rate_limited`/`quota_exceeded` with `Retry-After`, **503 `support_unavailable`** distinct from 500/502 (FR-OV-S21, S15).
- **F. Body constraints.** State the maximum length (WEB enforces it with a counter); plain text only; attachments out (FR-OV-S22).
- **G. Consent.** `GET` the current consent text and version; `POST` acceptance with that version; ticket routes refuse with `support_terms_required` until the current version is accepted, and again when it changes; the text is served from EA, never hardcoded in WEB (FR-OV-M8).
- **H. Compatibility and cutover.** New routes are additive; the existing support-thread routes stay until the widget has moved; contract-breaking changes use the lockstep pattern (field diff, coordinated window); state what happens to existing operator-thread history for the Owner Admin (D1/D2, FR-OV-S18); CORS allows WEB's origin with `Authorization` and GET/POST (FR-OV-S23).

Also open, asked of EA earlier in this document: whether a ticket may carry the `companyId` the user was working in as context (D5, optional).

## Answered by EA, 2026-10-04 (corrections and open items)

EA's feasibility view is recorded in SRS section 12.3. Corrections to this document: use **403** for `support_terms_required` (not 409); idempotency is **at-least-once with the key**, since a timeout may have landed; the authoritative quota and the unread marker live in **Omniview**, EA enforcing size and burst and passing Omniview's 429 through; the consenting-tenants route needs a **service-principal validator** because EA's GL provider slot has the human validator today. Open: the consent boundary rule (D33), new-ticket alerting (D34), staff counting detail (D15/D24). **EA offers to own the route-contract doc once Femi confirms D3.**

**Security requirement (EA, 2026-10-04):** the consenting-tenants route group is authenticated by the GL provider **only**, with a service-principal validator, and **fails closed** when the GL audience is unset (not registered, or 503). EA's current `glServiceVerifier ?: verifier` would otherwise make it callable by any tenant user. Written into SRS NFR-OV-14.

## Second round, 2026-10-04 (EA's wording checks, SRS 12.4)

- **Two consent purposes, not one (D35):** support terms (may gate tickets) and market-aggregate inclusion (optional, revocable, never a condition of any service). The ticket-route code is `support_terms_required`.
- Only the **opaque user id** crosses to Omniview; the relay supplies the tenant display name on create; fixed error codes only, never raw exception or response text; a non-member or non-Owner-Admin is 403 `not_owner_admin`, 404 only for a ticket id; cache only the unread count briefly; the support routes need their own limits and a short timeout to Omniview with a fast 503.

## Third round, 2026-10-04 (WEB's reading of the second round, SRS 12.5)

- **Both consents need routes:** the current text and version, the Owner Admin's accepted version, accept, and, for the **market** consent only, revoke. The consent copy is content served by EA with a version; "fixed error codes only" is about error messages, not this copy.
- **The error-code list is an enumerated, stable contract**; WEB treats an unknown code with a generic fallback, so changes follow the lockstep pattern.
- **D36 (Femi):** where the Owner Admin revokes the market consent.