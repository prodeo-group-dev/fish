# Unified Communication System — Use Cases

**Status**: requirements/use-case documentation only, 2026-09-23. Companion to `Unified_Communication_SRS.md` — read that document first for the actor definitions, the three organizational contexts (normal company / conglomerate / school or group of schools), and the "already built vs. not built" grounding this document assumes. Style follows this project's existing requirements/use-case documents (`SOP/docs/Sales_Order_Processing_Requirements_Use_Cases.md`, `POP/docs/Purchase_Order_Processing_Requirements_Use_Cases.md`). No technical design, API shape, or code is proposed here.

**ID convention**: `UC-COMM-##`, one per distinct interaction. Where a requirement behaves identically across organizational contexts, one use case covers all of them (noted in its Context line); where it genuinely differs, separate use cases are given.

---

## UC-COMM-01: Send a Direct 1:1 Message

**Status:** Built (`MessageAudience.Direct`, `MessageRoutes.kt`)
**Context:** Normal company and Conglomerate (identical behavior — see Note below for why). Not usable by School Staff (see UC-COMM-14).
**Actor(s):** Tenant Staff (sender), Tenant Staff (recipient)
**Preconditions:** Sender holds an active Membership in the Tenant. Recipient holds *any* active Membership in the same Tenant (no Company-match requirement is enforced).

**Main Flow:**
1. Sender opens a direct conversation with a specific recipient by their User id.
2. System confirms the recipient holds a Membership somewhere in the same Tenant.
3. Sender composes and sends a message body.
4. System records the message under `MessageAudience.Direct(recipientId)` and returns it to the sender.
5. Recipient retrieves the thread (`GET .../messages/direct/{userId}`) and may reply the same way, and may mark a message seen.

**Alternate/Failure Flows:**
- 3a. Recipient does not hold any Membership in the Tenant → request rejected (404, `user_not_found`).
- 3b. Message body is blank → rejected (400, `bad_request`).

**Note:** This use case's authorization check is Tenant-wide, not Company-scoped — a sender in one Company of a multi-Company Tenant can already Direct-message a recipient in a different Company of the same Tenant today, with no approval step. This is the exact channel UC-COMM-06/07/08/09 (the new cross-Company approval workflow) is meant to gate for FR-COMM-04's intent, and the two are not currently reconciled — see `Unified_Communication_SRS.md` §7 Q3.

---

## UC-COMM-02: Post to a Fixed Team/Module Channel

**Status:** Built (`MessageAudience.ForModule`, `MessageRoutes.kt` `/messages/module/{module}`)
**Context:** Normal company and Conglomerate (Tenant-wide, not Company-scoped — see Note)
**Actor(s):** Tenant Staff
**Preconditions:** Sender's Membership has `AccessLevel.READ` or higher on the named module (`authorizeTenantForModule(tenantId, module, READ)`) and the module is in the sender's `grantedModules`.

**Main Flow:**
1. Staff member selects a module channel (GL, HR, SOP, POP, IM, TAX — per WEB's `CHAT_MODULES`).
2. Staff member composes and sends a message.
3. System records it under `MessageAudience.ForModule(module)`, visible to every Membership with read access to that module in the Tenant.
4. Other staff with access to that module poll/read the channel.

**Alternate/Failure Flows:**
- 1a. Staff member's Membership does not have the module in `grantedModules`, or lacks `READ` access → 403.

**Note (Conglomerate context):** the channel pools every Company's module-access staff into one Tenant-wide conversation. There is no way to stand up a Company-specific version of this channel (e.g., "Company B's GL team only") using this mechanism — see `Unified_Communication_SRS.md` FR-COMM-02.

---

## UC-COMM-03: Send a Role-Wide Broadcast

**Status:** Built (`MessageAudience.ForRole`, `MessageRoutes.kt` `/messages/role/{role}`)
**Context:** Normal company and Conglomerate (Tenant-wide)
**Actor(s):** Tenant Staff (must hold the target Role, or be `AccessLevel.ADMIN`)
**Preconditions:** Sender authorized as `authorizeTenantForAdmin` for send; for read, sender must hold the Role being viewed or be ADMIN.

**Main Flow:**
1. An admin-level staff member (or a member of the target Role, for reading) selects a Role (e.g., `ACCOUNTANT`).
2. Sender sends a message.
3. System records it under `MessageAudience.ForRole(role)`, visible to every active Membership holding that Role, Tenant-wide.

**Alternate/Failure Flows:**
- 1a. Reader does not hold the requested Role and is not ADMIN → 403 (`role_access_denied`).

---

## UC-COMM-04: Send a Tenant-Wide Announcement ("Everyone")

**Status:** Built (`MessageAudience.Everyone`, `MessageRoutes.kt` `/messages/everyone`; surfaced in WEB as "Announcements")
**Context:** Normal company (reaches the whole, single-Company Tenant); Conglomerate (reaches every Company under the Tenant at once — see UC-COMM-05 for the Company-scoped alternative)
**Actor(s):** Owner-Admin or any admin-level Membership
**Preconditions:** Sender authorized via `authorizeTenantForAdmin`.

**Main Flow:**
1. Admin composes an announcement.
2. System records it under `MessageAudience.Everyone`.
3. Every active Membership in the Tenant can read it (`authorizeTenantForRead`).

**Alternate/Failure Flows:**
- 1a. Sender lacks admin access → 403.

---

## UC-COMM-05: Send a Company-Scoped Broadcast (Conglomerate)

**Status:** Built (`MessageAudience.ForCompany`, `MessageRoutes.kt` `/messages/company/{companyId}`)
**Context:** Conglomerate only (moot for a single-Company Tenant, where it is equivalent to UC-COMM-04)
**Actor(s):** Owner-Admin or admin-level Membership with access to the target Company
**Preconditions:** Sender authorized via `authorizeTenantForAdmin`, and `membership.hasAccessToCompany(companyId)` is true.

**Main Flow:**
1. Admin selects a specific Company under the Tenant (e.g., "Company B" of a 4-Company Tenant).
2. Admin composes and sends a broadcast.
3. System records it under `MessageAudience.ForCompany(companyId)`.
4. Only Memberships with access to that Company (`hasAccessToCompany`) can read it.

**Alternate/Failure Flows:**
- 1a. Sender's Membership is restricted away from the target Company (`companyIds` doesn't include it) → 403 (`company_access_denied`), on both send and read.

---

## UC-COMM-06: Request a Cross-Company Conversation (Same Tenant)

**Status:** NOT BUILT — new use case
**Context:** Conglomerate only (moot for a normal company — no second Company to reach)
**Actor(s):** Tenant Staff (requester, Company A), Tenant Staff (target, Company B)
**Preconditions:** Requester and target both hold active Memberships in the same Tenant, in different Companies. No existing approved (or pending) conversation already covers this specific pair.

**Main Flow:**
1. Staff member in Company A identifies a specific staff member in Company B they want to reach.
2. Staff member raises a request to open a conversation with that specific person, naming the reason/context.
3. System records the request in a **Requested** state and notifies the Owner-Admin (see UC-COMM-07).
4. Requester is shown the conversation as **Pending Approval** — no messaging is possible yet.

**Alternate/Failure Flows:**
- 1a. A request between this exact pair is already Pending or already Approved → system should not create a duplicate (exact duplicate-detection rule not decided — open question).
- 1b. Target is not a valid Membership of a *different* Company under the same Tenant → rejected.

---

## UC-COMM-07: Owner-Admin Approves a Cross-Company Conversation Request

**Status:** NOT BUILT — new use case
**Context:** Conglomerate only
**Actor(s):** Owner-Admin
**Preconditions:** A conversation request exists in the **Pending Approval** state (UC-COMM-06). Which Owner-Admin(s) may act on it is an open question (`Unified_Communication_SRS.md` §7 Q1 — the single `businessOwnerId`, or any `Role.OWNER_ADMIN` Membership).

**Main Flow:**
1. Owner-Admin reviews the pending request (requester, target, stated reason).
2. Owner-Admin approves this **specific** conversation.
3. System transitions the request to **Approved** and opens messaging between exactly the requester and the target — this approval does not extend to any other pair from Company A/B, and does not create a standing Company-pair rule (per the user's explicit "not a one-time toggle or a per-Company-pair approval" direction).
4. Both parties are notified the conversation is now open.

**Alternate/Failure Flows:**
- 2a. See UC-COMM-08 for denial.
- 2b. Owner-Admin attempting to act is not authorized to approve (fails whatever resolution Q1 settles on) → rejected.

---

## UC-COMM-08: Owner-Admin Denies a Cross-Company Conversation Request

**Status:** NOT BUILT — new use case (alternate flow of UC-COMM-06/07)
**Context:** Conglomerate only
**Actor(s):** Owner-Admin
**Preconditions:** A conversation request exists in the **Pending Approval** state.

**Main Flow:**
1. Owner-Admin reviews the pending request.
2. Owner-Admin denies it, optionally recording a reason.
3. System transitions the request to **Denied**. Messaging never opens for this pair under this request.
4. Requester is notified of the denial.

**Alternate/Failure Flows:**
- 3a. Whether a denied requester may raise a new request for the same target later (immediately, or after a cooldown) is not decided — open question, not addressed by this use case.

---

## UC-COMM-09: Exchange Messages Within an Approved Cross-Company Conversation

**Status:** NOT BUILT — new use case
**Context:** Conglomerate only
**Actor(s):** The two Tenant Staff members named in an Approved request (UC-COMM-07)
**Preconditions:** The specific conversation is in the **Approved** state.

**Main Flow:**
1. Either party sends a message within the approved conversation.
2. System records and delivers it to the other party only — this is a scoped, two-party channel tied to the specific approval, not a general re-opening of unrestricted Direct messaging between all of Company A and Company B's staff.
3. Either party (or the Owner-Admin) may end the conversation, per whatever lifecycle rules a future design settles — not specified here.

**Alternate/Failure Flows:**
- 1a. A party attempts to message outside the scope of what was approved (e.g., requester tries to loop in a third person from Company A) → not covered by this approval; would require a new request (UC-COMM-06) naming that person.

---

## UC-COMM-10: Owner-Admin Requests Contact With Another Tenant's Owner-Admin

**Status:** NOT BUILT — BLOCKED on a real prerequisite (no cross-tenant identity/discovery mechanism exists anywhere in the platform; see `Unified_Communication_SRS.md` FR-COMM-05)
**Context:** Normal company, Conglomerate, and School (identical — the blocker sits below all three)
**Actor(s):** Owner-Admin (Tenant X), Owner-Admin (Tenant Y)
**Preconditions (currently unmet):** A mechanism must exist for Owner-Admin (Tenant X) to identify/locate Tenant Y at all. None exists today — `EA`'s repositories expose no cross-tenant query of any kind (`repositories.kt`, confirmed directly).

**Main Flow (aspirational — cannot be executed against current code):**
1. Owner-Admin of Tenant X somehow identifies Tenant Y (mechanism undecided — directory vs. invitation-by-reference, per `Inter_Tenant_Trade_Automation_Vision.md`'s own open question 2).
2. Owner-Admin of Tenant X requests contact with Tenant Y's Owner-Admin.
3. (Undesigned) some consent step on Tenant Y's side.
4. (Undesigned) messaging opens between the two Owner-Admins only — no other staff of either Tenant is party to it.

**Alternate/Failure Flows:**
- Entire use case is blocked pending the discovery/identity prerequisite. Recorded here to make the dependency explicit, not to imply near-term buildability.

---

## UC-COMM-11: Owner-Admin Exchanges Messages With Another Tenant's Owner-Admin

**Status:** NOT BUILT — BLOCKED (depends on UC-COMM-10)
**Context:** Normal company, Conglomerate, School — identical, same blocker
**Actor(s):** Owner-Admin (Tenant X), Owner-Admin (Tenant Y)
**Preconditions (currently unmet):** UC-COMM-10 completed with consent from both sides.

**Main Flow (aspirational):**
1. Either Owner-Admin sends a message.
2. Delivered only to the other named Owner-Admin — never any staff Membership of either Tenant.

**Alternate/Failure Flows:** Not designed; blocked with UC-COMM-10.

---

## UC-COMM-12: Tenant Submits a Support Request to the Platform Operator

**Status:** Built (`MessageAudience.OperatorThread`, `Message.sendToOperatorThread()`, `MessageRoutes.kt` `/support-thread/messages`)
**Context:** Normal company, Conglomerate, School — identical (Tenant-scoped, not Company- or School-specific)
**Actor(s):** Tenant Staff (any Membership with read access), Platform Operator (recipient side)
**Preconditions:** Sender holds an active Membership in the Tenant.

**Main Flow:**
1. Staff member opens the Support Chat widget (`WEB/src/components/SupportChatWidget.tsx`), which is rendered globally regardless of screen.
2. Staff member selects the default "Support" channel and composes a message.
3. System records the message under `MessageAudience.OperatorThread` for this Tenant, with `senderId` set to the sender.
4. Message becomes visible in Omniview's cross-Tenant operator inbox (UC-COMM-13).

**Alternate/Failure Flows:**
- 2a. Message body blank → rejected (`IllegalArgumentException` → 400).

---

## UC-COMM-13: Platform Operator Replies via Omniview

**Status:** Built (`OperatorMessagesRoutes.kt`, `Message.sendFromOperator()`)
**Context:** Normal company, Conglomerate, School — identical
**Actor(s):** Platform Operator
**Preconditions:** Operator authenticated via a configured operator token (`authorizeOperator`).

**Main Flow:**
1. Operator views the flat, cross-Tenant, oldest-first inbox (`GET /operator/support-threads`), alongside the Tenant-overview and platform-health views that make up Omniview.
2. Operator selects a specific Tenant's thread and replies (`POST /operator/tenants/{tenantId}/support-thread/messages`).
3. System records the reply under `MessageAudience.OperatorThread` for that Tenant, with `senderId = null` and `fromOperator = true`.
4. The Tenant's staff see the reply in their own Support Chat widget on their next poll (15-second interval).

**Alternate/Failure Flows:**
- 2a. Reply body blank → rejected (400).
- 1a. Operator token not configured for this deployment → 503 (`not_configured`).

---

## UC-COMM-14: School Staff Member Attempts Intra-School Messaging

**Status:** NOT BUILT / OPEN QUESTION — no answer assumed
**Context:** School / group of schools
**Actor(s):** School Staff (`ErPrincipal` via `StaffAssignment` — e.g., two teachers at the same school)
**Preconditions:** Both parties are verified via SchoolAdmissions' `ErIdentityGateway` and hold `StaffAssignment` rows for the same `SchoolId`. Neither necessarily holds an EA `User`/`Membership`.

**Main Flow:** Not specified — this is precisely the open question named in `Unified_Communication_SRS.md` §7 Q2. Three unresolved candidate shapes, named but not chosen:
1. Both teachers are somehow also EA `User`/`Membership` holders (nothing today creates this), and existing EA `Message`/`MessageAudience.Direct` is reused as-is.
2. SchoolAdmissions grows its own, entirely separate messaging primitive, independent of EA's.
3. A future bridged/federated identity lets one real person be recognized as both an EA Membership holder and a SchoolAdmissions `ErPrincipal`, and messaging routes through whichever system is appropriate.

**Alternate/Failure Flows:** N/A — recorded to make the gap concrete, not to prescribe a resolution.

---

## UC-COMM-15: Business Owner (EA) Communicates With School Staff (SchoolAdmissions)

**Status:** NOT BUILT / OPEN QUESTION — no answer assumed
**Context:** School / group of schools (and, for a multi-school Tenant, potentially spanning more than one School)
**Actor(s):** Owner-Admin / Tenant Staff (EA side), School Staff (`ErPrincipal`, SchoolAdmissions side — e.g., a head teacher)
**Preconditions:** The Business Owner's Tenant has at least one Company with `IndustryType.SCHOOL`, provisioned as a `School` in SchoolAdmissions (`RegisterCompanyUseCase` → `SchoolAdmissionsGateway.provisionSchool`).

**Main Flow:** Not specified — same underlying identity gap as UC-COMM-14, viewed from the other direction. The Business Owner today has no route to message a specific `ErPrincipal` (e.g., a named head teacher) at all: EA's `Message`/`MessageAudience` only ever addresses EA `UserId`s, and nothing links a `School`'s staff back to any addressable identity EA recognizes. The one existing cross-system link — the `School.organisationId`/`tenantId` fields recorded at provisioning time — is informational only (set once, at creation) and is not a live, queryable identity bridge.

**Alternate/Failure Flows:** N/A — recorded as an open question, consistent with `Unified_Communication_SRS.md` §7 Q2. A future design pass should treat UC-COMM-14 and UC-COMM-15 as two faces of the same unresolved dependency, not two separate problems.

---

## Traceability Summary

| Use Case | Requirement | Status | Context(s) |
|---|---|---|---|
| UC-COMM-01 | FR-COMM-01 | Built | Normal, Conglomerate |
| UC-COMM-02 | FR-COMM-02 | Built (fixed shape only) | Normal, Conglomerate |
| UC-COMM-03 | FR-COMM-02 | Built (fixed shape only) | Normal, Conglomerate |
| UC-COMM-04 | FR-COMM-03 | Built | Normal, Conglomerate |
| UC-COMM-05 | FR-COMM-03 | Built | Conglomerate |
| UC-COMM-06 | FR-COMM-04 | Not built | Conglomerate |
| UC-COMM-07 | FR-COMM-04 | Not built | Conglomerate |
| UC-COMM-08 | FR-COMM-04 | Not built | Conglomerate |
| UC-COMM-09 | FR-COMM-04 | Not built | Conglomerate |
| UC-COMM-10 | FR-COMM-05 | Not built, blocked | All (identical) |
| UC-COMM-11 | FR-COMM-05 | Not built, blocked | All (identical) |
| UC-COMM-12 | FR-COMM-06 | Built | All (identical) |
| UC-COMM-13 | FR-COMM-06 | Built | All (identical) |
| UC-COMM-14 | FR-COMM-01/02 (school) | Open question | School |
| UC-COMM-15 | FR-COMM-01/02/03 (school) | Open question | School |

## Open Decisions Carried Forward (unresolved, per `Unified_Communication_SRS.md` §7)

1. Which "Owner-Admin" FR-COMM-04/05's approval authority actually refers to (`businessOwnerId` vs. any `Role.OWNER_ADMIN` Membership) — affects UC-COMM-07/10/11 directly.
2. The EA/SchoolAdmissions identity-bridging question — affects UC-COMM-02, UC-COMM-04 (school context), UC-COMM-14, UC-COMM-15 directly.
3. Whether `MessageAudience.Direct`'s existing unrestricted cross-Company behavior should be tightened alongside building UC-COMM-06 through UC-COMM-09, or left as a separate, pre-existing channel.
4. Scope of any future ad-hoc group-chat primitive (UC-COMM-02's named gap) — Company-scoped, Tenant-wide, or itself subject to a UC-COMM-06-style approval gate.
5. Whether FR-COMM-05's Owner-Admin-only cross-tenant contact needs its own discovery/consent mechanism or should wait for `Inter_Tenant_Trade_Automation_Vision.md`'s broader trading-partner mechanism.
