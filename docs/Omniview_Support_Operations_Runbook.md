# Omniview Product Support: operations runbook

**Status:** 2026-10-05, written against the built service (`fish-er-omniview`, branch
`feat/omniview-v2-support-foundation`, merged as PR #4). Covers backlog **7C.15** (the workflow
completeness check on what was actually built) and **D17** (the v1 erasure and export procedure),
plus what to read in the logs on first boot. Companions:
`docs/Omniview_v2_Software_Requirements_Specification.md` (FR-OV-S32 and section 14),
`docs/Omniview_v2_Backlog.md`.

Omniview is private-only. Everything below is done over private access (D4), and anything that touches
the database goes through CM's lane (credential-split: Femi or CM runs the SQL; no session holds the
database password in a chat).

## 1. Workflow completeness, as built (7C.15)

Femi's rule (FR-OV-S32): every workflow states **who is told**, **what happens if nobody acts**, and
**how it closes**. One row per workflow the code now implements.

| # | Workflow | Who is told | If nobody acts | How it closes |
|---|---|---|---|---|
| 1 | An Owner Admin raises a ticket | The tenant sees "sent" (EA/WEB). Prodeo staff get a `NEW_TICKET` alert, written in the same transaction as the ticket and delivered by email through the SNS topic | The ticket is OPEN and its wait is counted. After 4 hours (configurable) an `AWAITING_REPLY` alert fires once for that waiting episode, and the console flags it OVERDUE | An operator replies (ANSWERED) and later closes it |
| 2 | An Owner Admin replies on a ticket | Staff get an `OWNER_REPLY` alert; the ticket returns to OPEN if it was ANSWERED, and the wait restarts | Same 4-hour awaiting alert for the new waiting episode | As row 1 |
| 3 | An operator replies | The Owner Admin: unread marker on the ticket, polled through EA (about every 15 s while FiSH is open) | The reply stays unread until the Owner Admin opens FiSH. The limitation is recorded (FR-OV-S30): no email to tenants (D12) | The Owner Admin reads it (marker moves); a follow-up reopens the ticket, otherwise an operator closes it |
| 4 | An operator closes a ticket | The Owner Admin sees CLOSED the next time they open it | Nothing: tickets stay ANSWERED until an operator closes them. Auto-close is **not built** (follows v1, D38); the ANSWERED tickets are in the console, not nagging anyone | Closed is final. A reply on a closed ticket is refused `409 ticket_closed` and the widget starts a **new** ticket |
| 5 | The alert topic or its subscription is down or unset | Nobody by email, but the service logs `SUPPORT ALERT NOT DELIVERED ...` (or the `OMNIVIEW_ALERT_TOPIC_ARN is not set` ERROR) every 30 s cycle, which CloudWatch can alarm on | The alert stays in the outbox and retries with backoff (30 s doubling to 15 min). The ticket itself is never lost or blocked, and the console queue still shows it | Delivery succeeds once the topic works; the row is marked delivered |
| 6 | The relay (EA) cannot reach Omniview | The Owner Admin sees "Support is temporarily unavailable; your message was not sent" and keeps the draft (FR-OV-S15) | Nothing is stored in EA as a fallback; the draft stays in the browser | The Owner Admin retries; the same idempotency key makes the retry safe |
| 7 | A retry after an ambiguous failure | Nobody needs to be: the same `Idempotency-Key` returns the original result | n/a | The key window (48 h) lapses; a later deliberate send with the same key counts as new |
| 8 | A tenant hits its quota | The Owner Admin gets `429` with the wait (header and body) | They wait or an operator closes tickets (the open-ticket cap frees only when one is closed) | The window passes or tickets close. Caps are provisional (D18) |
| 9 | An operator's reply fails to save | The operator sees the inline error with the text kept in the box | The same reply key is reused on retry, so it cannot post twice | The operator retries |
| 10 | A wrong operator token is presented repeatedly | The operator gets `401`, then `429 rate_limited`; the server logs each failure | After 5 minutes the oldest failure ages out | The source is unblocked automatically |
| 11 | An operator leaves | Femi removes that operator's entry from `OMNIVIEW_OPERATOR_TOKENS` (and from EA's `EA_OPERATOR_TOKENS` while the legacy views exist) | Until removed the token still works | Redeploy the task with the secret updated; the token stops working |

**Known gaps, stated rather than hidden:** no automatic close or retention job (D38, D17); no
tenant-side email or push for a reply (D12); one alert channel (email) with the on-call decision still
Femi's (D34); the per-source limiter treats everyone behind one bastion as one source.

## 2. Erasure and export on a verified request (D17)

**This is now done in the console, under Data requests, not by hand-run SQL.** (The SQL this section used to carry had gone stale: every table
added since the first release hangs off a ticket, so it would have failed on a foreign key or left content behind. It has been removed on purpose.
A stale erasure script is worse than none.) See `docs/Omniview_Support_S8_Data_Requests_Contract.md`.

The procedure, for a request from a business's Owner Admin, which must arrive **on a real ticket** (never act on a chat message):

1. **Open the request** (any operator): the business, the ticket it arrived on, export or erasure, and optionally one ticket only. A 30-day statutory clock starts and shows as overdue.
2. **Confirm who is asking, out of band** (any operator): ring back on a number Prodeo already holds, a video call, a signed letter, or in person. Record **how**, never the evidence.
3. **Approve** (an administrator; while there is more than one operator, not the person who verified). An approval lasts seven days.
4. **Export**: an administrator presses Download. The copy is built then, handed over as a file and stored nowhere. Send it to the Owner Admin by the route you verified, then mark the request done.
   **Erasure**: an administrator reads the preview (how many of each thing), types the phrase naming the business, and presses Erase. It runs in one transaction. The request's own ticket is kept unless
   you tick the box, so you can still tell them it is done; **tell them first if you do tick it**.
5. **Tell the requester what was done and what remains.** Backups age out on the database's normal schedule; say so. The operator access log is kept (who looked at what, never content).

Every step is in the request's timeline and the operator access log with counts and names, never content. **Correction** of ticket text is not built: a ticket is a record of what was said,
so a correction is handled by hand and recorded in a note on the request. If the console is unavailable, the request waits (the clock is a month); fix Omniview rather than reaching for SQL.
**A test reads the real database schema and fails the build if any table holds tenant or ticket data that erasure neither handles nor keeps on purpose**, so this cannot go stale again.

## 3. First boot: what the log lines mean

The service logs structured JSON to `/ecs/fish-er-omniview`.

| Log line (message) | Meaning | Fix |
|---|---|---|
| `FATAL ... OMNIVIEW_DB_USER environment variable is required` or a Postgres `password authentication failed` / `database "omniview_production" does not exist` on start | The task cannot reach its database. The role or database is not created, or the password secret is wrong | CM/Femi: create `omniview_production` and `omniview_app`, check the `OMNIVIEW_DB_PASSWORD` secret |
| `Flyway resolved zero migrations` | The fat jar lost its migrations (service-file merge) | A build problem; rebuild |
| `Service authentication is not configured (OMNIVIEW_SERVICE_JWT_ISSUER, ...)` | The audience, issuer or JWKS value is unset: every `/internal` route answers 503 `not_configured` | Set the three values in the task definition |
| `OMNIVIEW_ALERT_TOPIC_ARN is not set` | Alerts will queue but not be delivered | Set the topic ARN |
| `SUPPORT ALERT NOT DELIVERED kind=... reason=...` | The topic rejected the publish (permissions, unconfirmed subscription, region) | Check the task role's `sns:Publish`, the topic ARN, `OMNIVIEW_AWS_REGION`, and that the email subscription is confirmed |
| `No operator token is configured` or `operator '<name>' refused: the token is shorter than 32 characters` | The operator secret is empty or too weak: operator ticket routes answer 503 | Put 32+ character tokens in the secret (never log them) |
| `Operator authorization failed for ...` | A wrong or missing operator token | Expected occasionally; a burst means guessing (the limiter will answer 429) |

A healthy first boot shows Flyway applying `V1__support_tickets` and `V2__support_alert_outbox`, then
`Responding at http://127.0.0.1:8090` (the log prints the loopback address, but the server listens on all interfaces, checked with netstat), and `GET /health` answers 200.
