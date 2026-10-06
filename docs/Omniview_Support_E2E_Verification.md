# Product Support: first end-to-end verification (round trip)

**Purpose:** prove, in production, the whole loop Femi asked for: *an Owner Admin raises a ticket from FiSH; an
operator sees it, is alerted, answers; the Owner Admin sees the reply; closure works; nothing is lost; Omniview
is not reachable from outside.* Written 2026-10-05 by the Omniview session for CM to run the moment EA's relay and
WEB's widget are live. Companions: `docs/Omniview_Support_Operations_Runbook.md` (log guide, erasure),
`docs/Omniview_v2_EA_Route_Contracts.md` (EA's routes), `docs/Omniview_v2_Backlog.md` (support go-live plan).

**Who does what:** the **tester** acts as a real Owner Admin through WEB (and, for the negative cases, with curl);
the **operator** works in Omniview's console over private access; **CM** reads logs and runs the outside-in checks.
Never paste a token, a password or the operator token into chat, a ticket or a log. Use a **dedicated test tenant**
(the data reset leaves Omniview's tables empty, so no existing row is needed).

## 0. Preconditions (CM, read-only)

| # | Check | Pass looks like |
|---|---|---|
| P1 | Omniview task healthy | ECS service `fish-er-omniview-production` shows 1 running; `GET /health` is `200` through the operator tunnel |
| P2 | Omniview log, last boot | Flyway applied up to the deployed image's latest migration; `Responding at http://127.0.0.1:8090` (it listens on all interfaces); **no** `Service authentication is not configured`, **no** `No operator token is configured`, **no** `OMNIVIEW_ALERT_TOPIC_ARN is not set` |
| P3 | Alert path | the SNS email subscription to `support@theprodeogroup.com` is **Confirmed** (one click), not "Pending confirmation" |
| P4 | EA relay deployed | an unauthenticated `GET https://ea-api.theprodeogroup.com/api/tenants/<any-uuid>/support/tickets` answers `401` (not `404`): the route exists and is gated |
| P5 | EA to Omniview credential | EA's task has the Omniview base URL and the ID-token provider configured (its log shows no `support_unavailable` on startup); Omniview's `OMNIVIEW_SERVICE_AUDIENCE_EA` equals the `ea-omniview-service` app client id |
| P6 | WEB widget live | the support chat is visible to an Owner Admin of the test tenant, and an employee sees "ask your Owner Admin" |
| P7 | Operator token | the same operator name and value exist in `OMNIVIEW_OPERATOR_TOKENS` and `EA_OPERATOR_TOKENS`; `OMNIVIEW_ADMIN_OPERATORS` names a real operator |

Stop and fix the first failing row; the log guide in the runbook maps each message to its fix.

## 1. Test cast

* **Owner Admin (OA):** a real FiSH user, Owner Admin of the test tenant `T1`. Note `T1`'s tenant id.
* **Employee (EMP):** a second user in `T1` with any non-owner role.
* **Other tenant owner (OA2):** an Owner Admin of a different tenant `T2` (for the isolation check).
* **Operator (OP):** a named operator with access to the console through the private path.

## 2. The round trip (do in order; record the time of each step)

| Step | Who | Action | Expected |
|---|---|---|---|
| 1 | OA (WEB) | Open the support chat, type "Round trip test 1", send | The message shows as sent; no error. (Draft is kept if it fails.) |
| 2 | CM | Omniview log | one `201 POST /internal/tickets` line; **no** stack trace |
| 3 | OP (console) | Open **Tickets** | The ticket is **OPEN**, tenant name correct, subject "Round trip test 1", "waiting" a few minutes at most, severity "untriaged" (if Wave S1 is deployed) |
| 4 | OP mailbox | Check `support@theprodeogroup.com` | Within about 2 minutes: **"[Omniview] New support ticket from <tenant>"** with the ticket id and **no ticket text** |
| 5 | OA | Send the **same** message again from the same screen by retrying after a forced network drop, or replay the create with the same `Idempotency-Key` (section 3) | Still **one** ticket in the console (the key makes the retry safe) |
| 6 | OP | Reply "Round trip answer 1" | The ticket becomes **ANSWERED** |
| 7 | OA | Before opening the chat, read the unread indicator (or `GET .../support/unread`) | `unreadCount: 1`, `hasUnread: true` (EA may cache the count up to 15 s) |
| 8 | OA | Open the chat | The reply "Round trip answer 1" appears as **from Prodeo Support**, with **no operator name** |
| 9 | OA | Leave the chat; wait 15 s; read the unread indicator | `unreadCount: 0` (the read marker moved) |
| 10 | OA | Reply "Follow-up 1" | The ticket returns to **OPEN** in the console; OP mailbox gets **"... replied on a support ticket"** |
| 11 | OP | Reply, then **Close ticket** | Console shows it closed (visible with "Show closed") |
| 12 | OA | Try to reply on the closed ticket | The widget says it is closed and offers a **new** ticket (EA `409 ticket_closed`); starting one creates a **separate** ticket in the console |

Pass when all twelve behave as written.

## 3. Direct checks with curl (isolation; OA's own session token, never pasted anywhere shared)

Set `EA=https://ea-api.theprodeogroup.com/api`, `T1=<tenant id>`, and `ID=<OA's Cognito ID token>` from the tester's
own session. Each key is a fresh UUID.

```bash
K=$(uuidgen)
curl -s -X POST "$EA/tenants/$T1/support/tickets" -H "Authorization: Bearer $ID" -H "Content-Type: application/json" \
     -H "Idempotency-Key: $K" -d '{"body":"Round trip test 2"}'          # 201 {ticket, message}
curl -s -X POST "$EA/tenants/$T1/support/tickets" -H "Authorization: Bearer $ID" -H "Content-Type: application/json" \
     -H "Idempotency-Key: $K" -d '{"body":"Round trip test 2"}'          # 201 again, SAME ids, still one ticket
curl -s "$EA/tenants/$T1/support/tickets"      -H "Authorization: Bearer $ID"     # array, newest activity first
curl -s "$EA/tenants/$T1/support/unread"       -H "Authorization: Bearer $ID"     # {"unreadCount":...,"hasUnread":...}
```

## 4. Negative and safety checks

| # | Check | Expected |
|---|---|---|
| N1 | Create with **no** `Authorization` header | `401` at EA; nothing in Omniview's log |
| N2 | EMP (non-owner) creates a ticket | `403` `not_owner_admin`; Omniview never contacted |
| N3 | OA2 reads or replies on a `T1` ticket id through `T2`'s path | `404` `ticket_not_found` (never a hint it exists) |
| N4 | OA calls EA with `T2`'s id in the path | `403` (not an Owner Admin of `T2`) |
| N5 | Body of 4,001 characters | `400` `validation_failed` (`body_too_long`) |
| N6 | Body containing a bell character (`\u0007`) | `400` `validation_failed` (`body_control_characters`) |
| N7 | Same `Idempotency-Key`, **different** body | `409` `idempotency_key_reused` |
| N8 | A script in a ticket: `<img src=x onerror=alert(1)>` | Console shows it as **plain text**; no alert fires |
| N9 | Missing `Idempotency-Key` on create | `400` `validation_failed` (`idempotency_key_missing`) |
| N10 | 21 not-closed tickets from one tenant (optional, off-peak) | `429` `quota_exceeded` with `Retry-After`; closing one frees it |

## 5. Fail-closed and exposure checks (CM; do N11 off-peak)

| # | Check | Expected |
|---|---|---|
| N11 | Set Omniview desired count to 0, then OA sends a message | `503` `support_unavailable`; **the draft stays in the widget**; EA stores nothing as a fallback. Restore to 1; resend with the **same key**; it lands once |
| N12 | From a machine **outside** the VPC | `omniview.fish.internal` does not resolve; the task's public IP on `8090` **times out** (security group admits only EA's group); no ALB listener or public DNS name points at Omniview |
| N13 | A forged service token (wrong audience) on `/internal/tickets` from inside the VPC (CM's own test token) | `401`; no ticket created |
| N14 | Operator console with a wrong token five times | `401` each, then `429` `rate_limited` with `Retry-After` |

## 6. What to read in the logs (`/ecs/fish-er-omniview`, plus EA's group)

* **Healthy:** `201 POST /internal/tickets`, `200 GET /internal/tenants/.../tickets`, `204 POST .../read`, `200 GET .../unread`, no `ERROR`.
* **Alert trouble:** `SUPPORT ALERT NOT DELIVERED kind=... reason=...` (topic permission, subscription not confirmed, region).
* **Credential trouble:** `401` on `/internal/...` from EA means the audience or token type is wrong (EA must send the **ID** token).
* **Operator trouble:** `Operator authorization failed ...` (token mismatch between the two secrets).
* **Never present:** a token, an operator token fragment, or ticket text in any log line.

## 7. Wave-specific extras (run what is deployed)

| Wave deployed | Extra check |
|---|---|
| **S1** | In the console: set family and severity (P1 asks for a reason), take the ticket, add a tag and an internal note; use a canned reply; "Metrics" and "Access log" open (the access log only for the admin operator, `403` for others); the queue shows the SLA state (the clock runs only 08:00 to 18:00 UK time, Monday to Friday) |
| **S2** | The ticket shows a **Tenant** tab: Omniview's own facts appear; the business-setup part says **"unavailable"** until EA builds its card route (and, later, "the owner has not allowed support" while the owner's switch is off). Opening the tab adds a `TENANT_CARD_VIEW` line to the access log |
| **S3** | The **Articles** tab works (create, publish, withdraw); nothing reaches tenants until EA relays the routes |

## 8. Sign-off

Record in `Infrastructure/COORDINATION.md`: date, who ran it, the image tags (Omniview, EA, WEB), steps 1 to 12 pass /
fail, N1 to N14 pass / fail / not run, and any ticket ids left behind. **Clean up:** close the test tickets; if real
content was typed, erase the test tenant's tickets with the runbook's procedure. A passing run (steps 1 to 12, N1 to N9,
N12) is what "Product Support is live" means.
