# Omniview v2 — Use Cases

**Companion to** `docs/Omniview_v2_Software_Requirements_Specification.md`
(`FR-OV-*`, `NFR-OV-*`, decisions `D1`–`D20`). **Numbering:** the
existing UC-OV-1 to 4 (sign in, tenant overview, interim thread view,
health) are unchanged and not repeated; UC-OV-5 to 7 keep CM's draft
numbers and are completed here; UC-OV-8 to 12 are new. The seed's
UC-1..8 map as: 1→UC-OV-1, 2→UC-OV-2, 3→UC-OV-4, 4→UC-OV-5,
5→UC-OV-8, 6→UC-OV-6, 7→UC-OV-7, 8→UC-OV-3.

Actors: **Owner Admin** (a tenant's one Owner Admin), **Employee** (any
other active member of a tenant), **Operator** (Prodeo staff).
Status labels as in the SRS. Every flow that touches another service is
**read-only toward it**; Omniview's only writes are to its own database.

---

## UC-OV-5: An Owner Admin raises a support ticket from inside FiSH

**Actor:** Owner Admin. **Preconditions:** signed in to FiSH (Cognito); is Owner Admin of at least one tenant.
**Trigger:** opens the support chat in FiSH and sends a first message.

**Main flow:**
1. The widget calls Omniview directly with the user's Cognito token (D3, D4).
2. Omniview verifies the token (issuer, audience, keys), then asks EA `GET /me` with that same token.
3. Omniview confirms the caller is Owner Admin of the tenant being raised for; the tenant comes from the verified `/me` result, not from the request body (FR-OV-S9).
4. Omniview creates a ticket (state Open) in its own database, with the tenant as a reference, the Owner Admin's identity, and the message (FR-OV-S1, S3, S12, NFR-OV-13).
5. The widget shows the ticket as sent.

**Alternate flows:**
- 2a. Token invalid or expired: 401; the widget asks the user to sign in again. No ticket.
- 3a. Caller is not an Owner Admin of any tenant: 403 with a plain message (see UC-OV-10).
- 3b. Caller is Owner Admin of several tenants: the widget asks which; the server checks the chosen tenant against `/me`.
- 3c. EA is unreachable: 503, no ticket, the draft is kept in the widget so nothing typed is lost. Omniview never falls back to trusting the request's own tenant claim.
- 4a. Over the per-tenant ticket quota, or body over the size limit: rejected with a clear message (NFR-OV-8, D18).

**Postconditions:** one ticket exists in Omniview only. Nothing was written to EA or any service.
**Traces to:** FR-OV-S1, S3, S9, S12; NFR-OV-6, 8, 13.

---

## UC-OV-6: An operator triages and answers a ticket

**Actor:** Operator. **Preconditions:** signed in (UC-OV-1, or a Cognito operator group if D13 moves there).
**Trigger:** opens the Tickets view.

**Main flow:**
1. Omniview lists tickets, Open first then oldest first, with the tenant's *name* (looked up from EA's operator overview, read-only), state, age, and last message preview.
2. Operator opens a ticket and reads the thread. All text is rendered as text (NFR-OV-10).
3. Operator writes a reply; Omniview stores it in its own database, records the operator's name, and sets the ticket to Answered (FR-OV-S2, S8).
4. Operator can close the ticket. Closing changes only Omniview's record (FR-OV-S7).

**Alternate flows:**
- 1a. The tenant-name lookup fails: tickets still list, with the tenant id shown instead of the name; the failure never blocks answering.
- 3a. Database write fails: the reply stays in the box with an inline error; nothing is lost.
- 4a. A ticket calls for a change in the tenant's data (for example fixing an account): the operator tells the Owner Admin in the reply; whoever owns that data makes the change. Omniview offers no action that writes into a tenancy (FR-OV-S7).

**Postconditions:** the reply is attributable to a named operator and is visible to the Owner Admin by pull (UC-OV-8).
**Traces to:** FR-OV-S2, S7, S8, S12; NFR-OV-10, 13.

---

## UC-OV-7: An operator views the market report

**Actor:** Operator (audience and role separation: D20). **Preconditions:** signed in; the legal gates (D9) are passed; at least the minimum cohort of consenting tenants exists.
**Trigger:** opens the Market view and picks whole market or a segment.

**Main flow:**
1. Omniview obtains the consenting-tenant list from EA (D16) and the current gold rate table from its own database.
2. Omniview sends GL (operator-only, totals-only route) the allow-list, the report date and the rate table.
3. GL computes each consenting tenant's balance sheet as at that date (summing its Companies), converts to gold, and applies the cohort, concentration and suppression rules **inside GL**. It returns totals and counts only, never a per-tenant figure.
4. Omniview shows: tenants, staff with FiSH access, aggregate shareholders' funds, liabilities-to-equity (and debt-to-equity once the debt flag exists), each in gold, with the "unaudited, compiled from tenants' own books" label and the rate, source and date used (FR-OV-M1..M7).

**Alternate flows:**
- 3a. A figure fails the cohort or concentration test: it is shown as "insufficient cohort" (FR-OV-M10). Related cells are suppressed with it so it cannot be recovered by subtraction (§7.1 of the SRS).
- 3b. Debt-to-equity requested before the debt flag exists or with thin coverage: shown as "not yet available", with coverage if known.
- 3c. GL is unreachable: the view is unavailable, never an empty report.
- 1a. A tenant revokes consent: it is excluded from the next computation, nothing stored needs correcting (FR-OV-M9).

**Postconditions:** nothing is stored by default; no per-tenant value left GL or reached a log.
**Traces to:** FR-OV-M1..M10; NFR-OV-6, 7, 9.

---

## UC-OV-8: An Owner Admin reads replies in the FiSH chat

**Actor:** Owner Admin. **Preconditions:** has at least one ticket.
**Trigger:** opens the chat, or the widget's poll interval fires.

**Main flow:**
1. The widget asks Omniview for its tickets and new replies (authenticated as in UC-OV-5).
2. Omniview returns only tickets of tenants the caller is verified Owner Admin of (FR-OV-S10).
3. The widget shows the replies. **FiSH pulls; Omniview pushes nothing** (FR-OV-S4).

**Alternate flows:**
- 2a. Another tenant's ticket id is requested: the response is indistinguishable from "no such ticket".
- 3a. If D12 allows email: a reply also triggers an email to the Owner Admin's address. That is a message to a mailbox, written nowhere in a tenancy.

**Traces to:** FR-OV-S4, S10; NFR-OV-8.

---

## UC-OV-9: An Owner Admin grants or withdraws consent to aggregate use

**Actor:** Owner Admin. **Preconditions:** the consent wording exists and is approved (D9).
**Trigger:** opens the consent screen in FiSH.

**Main flow:**
1. FiSH shows the versioned wording and the current state.
2. The Owner Admin accepts or withdraws; **EA** records it (EA owns tenant data, D16) with who, when and which wording version.
3. Omniview learns the current consenting set only by reading EA, at report time.

**Alternate flows:**
- 2a. Wording changes: prior consent applies to the prior version; the tenant is excluded until it accepts the new one (PROPOSED).
- 2b. Withdrawal: effective for the next report; no stored report keeps the tenant's contribution (FR-OV-M9).

**Note:** this use case is mostly EA and WEB work; it appears here because Market Support cannot exist without it.
**Traces to:** FR-OV-M8; D9, D16.

---

## UC-OV-10: An employee who is not the Owner Admin opens the support chat

**Actor:** Employee. **Trigger:** opens the chat in FiSH.

**Main flow:** the widget recognises the user is not an Owner Admin (from the same `/me` data FiSH already holds), explains that product support is raised by the tenant's Owner Admin, and offers EA's internal chat so the employee can ask them (FR-OV-S5, S11). No call reaches Omniview.

**Alternate flow:** if the widget did call Omniview anyway, Omniview rejects with 403 (UC-OV-5, 3a). Hiding the control is a courtesy; the server check is the rule.

**Traces to:** FR-OV-S5, S11.

---

## UC-OV-11: An operator maintains the gold rate table

**Actor:** Operator (or a named finance role, D7). **Trigger:** a new rate is due.

**Main flow:** the operator enters a rate with its date, source and basis (for example "closing price on the date"); Omniview stores it in its own rate table, never overwriting history. Reports always show the rate row used.

**Alternate flows:**
- A report date with no rate: the report is unavailable for that date, not estimated.
- A correction: added as a new row with a reason; the old row stays for traceability.

**Note:** whether rates are entered by hand or fetched from a named source is D7. Entering by hand is the smaller first step and removes a third-party dependency.
**Traces to:** FR-OV-M5, M7; D7.

---

## UC-OV-12: An operator views a segment whose cohort is too small

**Actor:** Operator. **Trigger:** picks a segment (for example one industry in one jurisdiction) with few consenting tenants.

**Main flow:** the segment's figures display "insufficient cohort". The whole-market figures remain visible only if showing them does not let the suppressed segment be recovered by subtraction; otherwise the complementary segment is suppressed too (SRS §7.1, item 3). The screen explains the rule in a sentence, without revealing how many tenants fall short.

**Why it is a use case:** before launch, and for some time after, this will be the common case, and it must look like the product working, not failing (FR-OV-M10).
**Traces to:** FR-OV-M6, M10; NFR-OV-7.

---

## Summary

| ID | Name | Actor | Reads from | Writes to |
|---|---|---|---|---|
| UC-OV-5 | Raise a ticket | Owner Admin | EA `/me` | Omniview DB |
| UC-OV-6 | Answer a ticket | Operator | EA overview (name only) | Omniview DB |
| UC-OV-7 | View market report | Operator | EA (consent list, counts), GL (new), Omniview rates | nothing |
| UC-OV-8 | Read replies (pull) | Owner Admin | EA `/me`, Omniview DB | nothing |
| UC-OV-9 | Grant/withdraw consent | Owner Admin | n/a | **EA** (EA's own data) |
| UC-OV-10 | Employee opens chat | Employee | EA `/me` (in FiSH) | nothing |
| UC-OV-11 | Maintain gold rates | Operator | n/a | Omniview DB |
| UC-OV-12 | Suppressed segment | Operator | as UC-OV-7 | nothing |
