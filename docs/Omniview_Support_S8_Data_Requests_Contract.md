# Omniview Support, Wave S8: data requests and exit

**Status:** DRAFT 1, 2026-10-06, written by the Omniview session for CM, Femi and the solicitor. Backlog rows S8.1 to S8.4 in
`docs/Omniview_Support_Model_Backlog.md`; requirements FR-SUP-G1 to G4 and UC-SUP-14, UC-SUP-17, SD13.
**S8.1 is built and tested on Omniview's side** (fish-er-omniview branch `feat/omniview-support-s5`, migration V15, awaiting CM). S8.2, S8.3 and S8.4 are **not built, and
each is blocked on something that is not Omniview's** (section 4). Operator-side only: no change to any `/internal` route, EA, WEB or any other service.

## 0. The finding that made S8.1 worth building properly

The v1 runbook carried hand-written SQL for erasure. Every table added since (case steps, escalations, incident and problem links, notes, history, tags, article links, health
episodes, outreach, tenant-addressed notices) hangs off a ticket or is keyed by tenant, so **that SQL would now have failed on a foreign key, or left content behind**. It had gone stale
silently, because nothing tied it to the schema. S8.1 replaces it with a built workflow **and a test that reads the real schema** and fails the build if any table holds tenant or ticket
data that erasure neither handles nor keeps on purpose (checked by removing a table from its list: it fails).

## 1. What is built (S8.1)

A **data request** is raised on a real ticket from the business, as an **export** (a copy of what support holds) or an **erasure**, for the whole business or one ticket. It walks:

1. **Opened** by any operator. A **30-day statutory clock** starts (UK GDPR: one month) and shows as overdue. One staff alert (the support mailbox) says it needs verifying and approving.
2. **Identity verified out of band** by any operator: the method (call-back to a number already held, video call, signed letter, in person, other) and a short note on how. **The method only; never the evidence.**
3. **Approved** by an **administrator**. While more than one operator exists, **the approver must not be the person who verified**. An approval lasts **seven days**; an old one is not a standing licence.
4. **Executed** by an administrator:
   - **Export**: built when the administrator presses Download, sent with `Cache-Control: no-store` as a file, **stored nowhere**. It holds the business's tickets, messages, internal notes about it, history, escalations,
     case steps, notices addressed to it, and **who at Prodeo looked at what, by name and time**. The administrator records how it was delivered, which closes the request.
   - **Erasure**: a **preview** shows how many of each thing would go; the administrator types a phrase naming the business (`ERASE` and the first eight characters of its id); it then runs **in one transaction**.
     It removes the tickets and everything hanging off them, notices addressed **only** to that business (a notice shared with others only loses this business's address), and the business's health episodes and outreach.
     **The request's own ticket is kept** unless the administrator ticks a box, so the requester can still be told it is done.

The **record keeps counts and names, never content**, in a timeline (opened, identity verified, approved, export generated or erased, completed) and in the operator access log. The request table has **no foreign keys**, so it survives the erasure it describes.
**Kept on purpose after any erasure**: the operator access log (append-only; who looked at what, never content) and the data-request record. Both hold operator names and tenant ids.
**Server-enforced**: approve, export, erase, preview and reject are administrators only (`403 forbidden` otherwise); a withdrawal is by the opener or an administrator.

## 2. What is not built in S8.1

- **Correction** of ticket text. A ticket is a record of what was said, so a correction is handled by hand and noted on the request. It can be built if it is ever asked for.
- **A scheduled reminder** before the statutory deadline. The list shows overdue; a background reminder needs the same scheduler the S5 worklist is waiting for.
- **Erasing other services' data.** Omniview erases only what **Omniview** holds. GL, POP, SOP, IM, HR and EA hold their own business data and have their own paths; coordinating them is S8.3.

## 3. Production changes

One additive migration, V15 (data requests, their events, a new staff-alert kind). No new environment variable, no new infrastructure. From the first deploy the console has a **Data requests** tab.
The new capability is **destructive**, which is why it is gated three ways (verified, approved, typed confirmation) and administrator-only; **CM's review should weight the erase path**, and the
test of every table in the schema.

## 4. The rest of the wave, and what blocks each part

| Row | What it is | Blocked on |
| --- | --- | --- |
| **S8.2 Retention** | A schedule per data class and jurisdiction, enforced automatically | **SD13** (Femi and the solicitor): today tickets are kept until erased on a verified request. Nothing to build until the schedule exists. When it does, enforcement is this same erasure run by a rule, so S8.1's code is the foundation |
| **S8.3 Exit** | A documented exit across the services: final export, retention period, deletion date, confirmation | **S9.1**, a subscription system that does not exist (SD3). Omniview must not simulate one |
| **S8.4 Residency statement** | Say, per tenant, where its ticket data lives | **SD13 and CM**: the ticket database is in one UK-region RDS instance today (see `docs/FiSH_Localization_Principle.md`); the honest statement for an Irish or Nigerian tenant needs the solicitor and CM's region decision |

## 5. Decisions and asks

1. **Femi: confirm the approval rules** (an administrator approves; a different person from the verifier once there is more than one operator; an approval lasts seven days; thirty days to complete) or change them.
2. **Femi and the solicitor: the access log.** It is kept after an erasure and names operators and tenants. That is defensible as an accountability record, but it is personal data of Prodeo's staff and a trace of who a business was, so
   **retention of the access log and the request record is part of SD13**. (EA's planned diagnostic read log, in the S7 design, raises the same question.)
3. **Femi and the solicitor: SD13 itself.** A retention schedule per data class and country, before the first Irish or Nigerian customer.
4. **CM: review the erase path at high effort**, and say whether you want the typed phrase and the seven-day approval window as they are.
5. **Whether a business can see its own request's progress.** Today the requester is told by the operator in the ticket; a tenant-facing status would need relay and WEB work. Not built, not asked for.
