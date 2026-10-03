# Omniview — Use Cases

**Companion to** `docs/Omniview_Software_Requirements_Specification.md`
(FR-OV-* referenced below) and `docs/Omniview_Extraction_DDD_Design.md`
(the architecture these flows are built on). One user class (§2.3 of
the SRS): the **Operator**.

---

## UC-OV-1: Operator signs in

**Actor:** Operator
**Preconditions:** Operator holds a valid EA operator token (issued
out-of-band, same as today's EA `/operator` sign-in).
**Trigger:** Operator navigates to `omniview.theprodeogroup.com`.

**Main flow:**
1. Omniview presents a token-entry form (mirroring WEB's existing
   `/operator` sign-in gate).
2. Operator enters their EA operator token.
3. Omniview stores it client-side (session/local storage) and uses it
   on every subsequent call to EA.
4. Omniview does **not** validate the token itself at sign-in time — the
   first real call to EA (UC-OV-2) is the actual validation, consistent
   with EA's own token check living entirely server-side.

**Alternate flow — invalid token:**
- 3a. The first EA call (UC-OV-2/UC-OV-3) returns 401/403.
- 3b. Omniview surfaces "token rejected," clears the stored token, returns to the sign-in form — mirroring WEB's existing `authError` handling exactly.

**Postconditions:** Operator has a working session; every subsequent
outbound call to EA carries their token.

**Traces to:** FR-OV-7, FR-OV-11 (the token Omniview forwards), §7.1's
open item (exact entry mechanism).

---

## UC-OV-2: Operator views the platform-wide tenant overview

**Actor:** Operator
**Preconditions:** Signed in (UC-OV-1).
**Trigger:** Operator opens Omniview's "Tenants" view.

**Main flow:**
1. Omniview's backend calls EA's `GET /operator/tenants`, forwarding the operator's token.
2. EA returns every Tenant's onboarding/KYB/phone/support-activity status (unchanged response shape).
3. Omniview renders one row per Tenant — name, status, segment, KYB, phone, company count, staff count, support activity, awaiting-reply indicator.
4. View polls on an interval (matching the existing 15s pattern already used inside EA's own operator page) so status stays current without a manual refresh.

**Alternate flow — EA unreachable:**
- 1a. The call to EA fails or times out.
- 1b. Omniview shows the view as unavailable, distinct from "zero tenants" — never silently renders an empty list that could be mistaken for a real, empty platform.

**Postconditions:** Operator sees current cross-tenant status.

**Traces to:** FR-OV-6, FR-OV-7, FR-OV-8 (no financial data surfaced).

---

## UC-OV-3: Operator reads and replies to a Tenant's support thread

**Actor:** Operator
**Preconditions:** Signed in (UC-OV-1).
**Trigger:** Operator opens Omniview's "Messages" view, optionally
arriving from UC-OV-2 by clicking a Tenant's support-activity count.

**Main flow:**
1. Omniview's backend calls EA's `GET /operator/support-threads`, forwarding the operator's token.
2. EA returns every Tenant's operator-thread messages.
3. Omniview groups by Tenant, sorted by most recent activity, and highlights threads awaiting an operator reply.
4. Operator selects a Tenant's thread and reads the full message history.
5. Operator types a reply and submits.
6. Omniview's backend calls EA's `POST /operator/tenants/{tenantId}/support-thread/messages`, forwarding the token and the reply body.
7. EA persists the message (its own `MessageRepository`/`SendMessageUseCase`, `MessageAudience.OperatorThread`) and returns it.
8. Omniview appends the new message to the thread view immediately, without waiting for the next poll cycle.

**Alternate flow — send fails:**
- 6a. The call to EA fails (network, 401/403, 5xx).
- 6b. Omniview shows an inline error on the reply box, preserves the operator's drafted text (doesn't clear the input), so nothing typed is lost.

**Postconditions:** Reply is persisted in EA exactly as if sent through EA's own operator page; attributable to the specific operator via their forwarded token (NFR-OV-2).

**Traces to:** FR-OV-9, FR-OV-10, FR-OV-11.

---

## UC-OV-4: Operator checks platform health

**Actor:** Operator
**Preconditions:** Signed in (UC-OV-1) — though note this is the one
view with no EA dependency at all; could in principle work signed-out,
but stays behind the same sign-in gate for a consistent single
console experience rather than a special case.
**Trigger:** Operator opens Omniview's "Health" strip/view (always
visible, per the existing `PlatformHealthStrip` precedent — shown
above the tab content, not its own separate tab).

**Main flow:**
1. Omniview's backend checks GL, POP, SOP, IM, HR in parallel.
2. For GL: checks for `X-Request-Id` on the `/api` root response.
3. For POP/SOP/IM/HR: checks for a 2xx response from `/health`.
4. Omniview renders each service as up (with latency) or down (with a reason), polling on the same interval as UC-OV-2.

**Alternate flow — a service is down:**
- 4a. That service renders visually distinct (the existing `verify-flagged`/red badge treatment) with its failure detail available on hover — an operator can tell *which* service and roughly *why* (timeout vs. non-2xx vs. unconfigured) without leaving Omniview.

**Postconditions:** Operator has current reachability for every
sibling service, independent of whether EA itself is reachable (the
one view that keeps working even if EA is the service that's down).

**Traces to:** FR-OV-1 through FR-OV-5.

---

## Use Case Summary Table

| ID | Name | Primary actor | Depends on EA? |
|---|---|---|---|
| UC-OV-1 | Sign in | Operator | Indirectly (token validated on first real call) |
| UC-OV-2 | Platform-wide tenant overview | Operator | Yes |
| UC-OV-3 | Read/reply to support threads | Operator | Yes |
| UC-OV-4 | Platform health | Operator | No |
