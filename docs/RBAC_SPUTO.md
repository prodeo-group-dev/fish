# RBAC across FiSH: Scope, Plan, Use cases, Tasks, Order (SPUTO)

**Owner:** Configuration Manager (CM). **Status:** DRAFT v0.1, 2026-10-08, for Femi's decisions. **Trigger (Femi, 2026-10-08):** he withdrew the idea that the Owner Admin gets full ADMIN on every module ("full administrative access comes not only with read access but write access; the writing into financial data is wrong") and asked CM to write a full SPUTO on RBAC across the FiSH system. Each runtime (Education Runtime/EduSys and the ones that follow) writes its own RBAC SPUTO as it comes onboard. When this one is settled, CM works through how it applies to each peer, one by one.

**Freeze while this is open:** no service changes its authorization model (role floors, owner uplifts, access levels, grants, new capabilities) without CM. The unmerged EA branch `feat/ea-owner-admin-all-modules` is withdrawn.

**How this was produced.** A read-only survey of all nine checkouts (code as it sits in each working tree, plus the docs), then CM spot-checked the most serious findings against `origin/master`. Items marked **[verified]** were confirmed against master or the live task definitions by CM; the rest are the survey's reading and must be re-checked by the owning peer in the application round (section 5). File references are relative to the FiSH root.

---

## 1. Scope (the problem)

FiSH has seven services and a shared web app that each decide "may this person do this?" separately. They agree on the shape (EA `GET /me` tells a service the caller's Role, AccessLevel and module grants per Company) but not on what the words mean, who is trusted, or who may approve money. Femi's correction makes the gap explicit: **being an owner or administrator must not, by itself, let anyone write into financial data.**

In scope: human authorization (roles, access levels, module grants, per-Company scoping), approvals and separation of duties, service-to-service identities, operator access (Omniview), the WEB app's use of the rules, and the extension contract for industry runtimes.

Out of scope here (own SPUTOs): the live-switch security scope (rate limiting, WAF, row-level security, backup/DR), the Tenant-level identity of end customers (guardians, suppliers, customers), and each runtime's own role vocabulary (they write theirs).

### What the code does today (summary)

| Topic | Today |
|---|---|
| Identity | Every service uses the JWT `email` claim only (no `sub`), RS256 against one issuer/audience. EA matches email exactly; ER lowercases. |
| Levels | EA `AccessLevel`: NONE < READ < WRITE < APPROVE < ADMIN, compared by ordinal. GL's `ADMIN` gate exists but nothing calls it. **APPROVE is used in exactly one place** (HR leave approve/reject). |
| Decision | Services call EA `/me` per request; allow when the Company's level is high enough and (GL only on TAX routes, others always) the module is granted. EA unreachable = 503 (fail closed). |
| Owner Admin | EA reports READ with no modules at every Tenant Company on master. SOP raises it to WRITE+Sales (2026-10-06). HR approves payroll, expenses and advances by an "owner only" email match. Elsewhere the Owner Admin needs explicit assignments. |
| Service accounts | GL, IM, SOP skip EA membership entirely for service tokens. Nothing ties a service token to a Tenant or Company. |
| ER | Own model: `staff_assignments` rows with free-form role strings; EA only seeds the first admin. |
| WEB | Hides/shows by `isOwnerAdmin` and the granted-module list; never by access level. |

### Findings that drive the plan

Severity is CM's reading for a system that will hold real money.

**F1 (HIGH, [verified]): fail-open service verifiers.** `serviceVerifier ?: verifier` in GL (`GL/.../web/Application.kt:498`), IM (`IM/.../web/Application.kt:268`) and SOP (`SOP/.../web/Application.kt:387`): if a service-audience variable is unset, a *human* token is registered as a service account and skips EA membership. CM checked the live task definitions: all five audience variables (GL 4, IM 2, SOP 1) are set in production today, so it is **latent, not exploitable now**, but a missing variable after any future redeploy would silently open it.

**F2 (HIGH, [verified]): SOP trusts a body field for the approving authority.** `approvedBy` on a customer-cancellation return is client-supplied (`SOP/.../ReturnRequestRoutes.kt:145`); any WRITE caller can claim `CFO_ACCOUNTANT`.

**F3 (HIGH, survey): money can be created and approved by the same person.** POP approval needs only WRITE and records no actor, and the approval threshold itself is editable with WRITE (a WRITE user can raise or remove it); SOP credit notes, IM adjustments (group `StoreManager` is separate from EA's roles), GL postings, HR payroll (owner-only, but `submittedBy`/`decidedBy` may be the same person).

**F4 (HIGH, survey): ER staff management lets a REGISTRAR grant SCHOOL_ADMIN** (role strings are free-form and matched by exact case; `canManageRegister` covers staff routes).

**F5 (MEDIUM, survey): EA delegation is uncapped.** An HR_OFFICER at ADMIN can invite staff up to ADMIN with any modules and can edit their own modules at their Company.

**F6 (MEDIUM, survey): service tokens are blanket.** They bypass membership and are not bound to a Tenant or Company; POP, SOP, IM and HR still fix one Tenant in their environment, GL derives it from the Company.

**F7 (MEDIUM, survey): inconsistent "Owner Admin" and "Company missing from /me" fall-backs** (GL/SOP return READ, POP/IM/HR return NONE); HR approve routes skip the module check; WEB comments still describe a READ floor and WEB never gates on level.

**F8 (MEDIUM, survey): ER student read has no per-child guardian check; EA operator tokens have no length rule or throttle** (Omniview's do).

---

## 2. Plan (principles and requirements, SRS)

### Principles (decided unless marked)

- **P1 Read and write are different powers.** Seeing everything never implies posting anything. *(Femi, 2026-10-08.)*
- **P2 Owner Admin is an oversight and administration role, not a financial-write role.** It can see all, manage people and configuration, and approve (if so decided in D2), but it does not post, edit or delete financial records by virtue of being the owner. *(Femi's correction; the exact line is D1/D2.)*
- **P3 Separation of duties on money.** For any record that moves money or stock value, the person who creates it is not the person who approves it, and both are recorded.
- **P4 Fail closed.** No fall-back verifier, no default grant. Unknown caller, unknown Company, missing configuration = deny and start-up failure, never "treat as trusted".
- **P5 One vocabulary.** NONE, READ, WRITE, APPROVE, ADMIN, and the module grants mean the same thing in every service (definitions in R1).
- **P6 Per-Company everywhere.** A decision is made at the record's own Company; the Tenant comes from the Company, never from the caller or a deploy-time value.
- **P7 Service identities are scoped.** A service credential acts for a stated set of Tenants/Companies and only the endpoints its role needs.
- **P8 The server decides.** The UI may hide controls but never relies on hiding; every route checks.
- **P9 Everything is attributable.** Create, approve, reject, override and role change record the acting identity.
- **P10 Industry runtimes extend, they do not fork.** A runtime maps its own roles onto the platform capabilities through a defined contract and writes its own RBAC SPUTO.

### Requirements (R-numbers are for the tasks)

- **R1 Definitions.** READ = see within granted modules at that Company. WRITE = create/edit drafts and non-approval operational records. APPROVE = approve or reject another person's money-affecting record within granted modules. ADMIN = administer access and configuration for that Company/module (grant roles, set thresholds, set policy); **ADMIN does not include posting or approving**. *(Proposed; D1.)*
- **R2 Approvals.** Every approval route requires APPROVE (not WRITE), refuses when approver = creator, and stores the approver's identity from the token, never from a body field.
- **R3 Thresholds and policy** (POP approval threshold, HR expense policy, tax settings) are ADMIN-only and audited.
- **R4 Owner Admin.** Exactly what EA reports for an Owner Admin is decided once in EA (R1 semantics), and every service consumes it as is: no local uplifts. SOP's 2026-10-06 Sales WRITE uplift is removed or re-expressed through EA once D2/D3 are decided.
- **R5 Delegation is capped.** A delegate can grant at most their own level, only for Companies they administer, never to themselves, and never an APPROVE/ADMIN they do not hold.
- **R6 Fail closed.** Services refuse to start if a required verifier audience is unset; no `?: verifier` fall-backs.
- **R7 Service accounts.** Each service credential is bound to a declared Tenant/Company scope and endpoint set; the Tenant header (or equivalent) is validated, not trusted. GL's Tenant-header options note (`docs/GL_Tenant_Header_Service_Account_Options.md`) is input.
- **R8 Consistent fall-backs.** A Company absent from `/me` is NONE for everyone including the Owner Admin.
- **R9 Identity.** One canonical email form (trim + lower-case) everywhere, applied at the token boundary; matching is case-insensitive; `sub` is recorded alongside for audit.
- **R10 Audit.** A shared minimum audit record (who, what, which Company, when, before/after for role and threshold changes).
- **R11 WEB.** Controls are shown by capability (level + module + Company) from `/me`, not by `isOwnerAdmin`; stale READ-floor comments removed.
- **R12 Runtime contract.** A runtime declares: its role names, how each maps to platform capabilities (view, enter, approve, administer), its service identities, and where it keeps role data; it must meet R2-R9 for its own approvals.
- **R13 Operators.** Operator tokens: minimum length, throttle, named per operator (EA to match Omniview); two-person rule for destructive/exposing actions.

### Decisions needed from Femi

| # | Decision | CM recommendation |
|---|---|---|
| D1 | Is **ADMIN** "administer access and configuration only" (no posting, no approving)? | Yes. It matches "administrative access comes with write" being the problem. |
| D2 | Who may **approve** money records: holders of APPROVE only, and may the Owner Admin hold it? | APPROVE is a separate grant; the Owner Admin may be given it explicitly per Company (so the owner can approve staff-created records) but never approves their own creations. |
| D3 | The Owner Admin's **default** at a Company: READ everywhere (today), plus what? | READ on everything plus oversight/people-management routes; any WRITE or APPROVE is an explicit assignment. SOP's WRITE uplift then goes. |
| D4 | May the Owner Admin do **day-to-day posting** at all (small businesses with no staff)? | Only via an explicit role assignment to themselves (e.g. ACCOUNTANT/SALES_OFFICER at WRITE), visible and audited, never implicit. |
| D5 | **Service credentials:** one Tenant per credential, a list, or all? | One Tenant per credential, Company-set optional. |
| D6 | Separation of duties **for a one-person business**: block or allow-with-warning when creator = approver? | Allow with an explicit "self-approval" flag recorded, only if the Tenant has a single staff member; otherwise block. |

---

## 3. Use cases

| UC | Actor | Main flow | Rule |
|---|---|---|---|
| UC-R1 | Owner Admin | Sees dashboards, ledgers, reports, staff, configuration at every Company of the Tenant | READ; people/config via ADMIN routes; no financial write (P1, P2) |
| UC-R2 | Accountant / officer | Creates and edits operational records (sales, POs, journals, adjustments) | WRITE at the Company with the module granted |
| UC-R3 | Approver | Approves or rejects a record created by someone else (PO, return/credit note, adjustment, payroll, expense) | APPROVE; refused if approver = creator (R2/D6); approver stored from the token |
| UC-R4 | HR officer / Owner | Invites staff and assigns Company roles | R5 cap; cannot self-escalate; audited |
| UC-R5 | Service (POP/SOP/IM/HR/ER → GL, IM; EA → ER) | Posts or reads on behalf of a Tenant | R7 scoped credential, endpoint set, Tenant validated |
| UC-R6 | Runtime user (e.g. School Admin, Registrar, Teacher) | Acts inside the runtime | Runtime roles mapped per R12; approvals follow P3 in the runtime |
| UC-R7 | Support operator (Omniview) | Handles tickets, diagnostics with consent | R13; two-person rule; access log |
| UC-R8 | Read-only viewer / auditor | Reads within a granted module | READ only; no write controls shown (R11) |
| UC-R9 | A one-person business | Owner does everything | D4/D6: explicit self-assignment, self-approval flag, audit |

---

## 4. Tasks (dependency-ordered; owner in brackets)

Task severity maps to the findings in section 1. Nothing is built until Femi decides D1-D6; tasks marked **(safe now)** change no policy and can start with CM's go.

**Foundation (no policy decision needed)**
- **T1 (safe now) Remove the fail-open verifier fall-backs** in GL, IM, SOP: refuse to start (or register a deny-all provider) when a service audience is unset; test it. [GL, IM, SOP sessions; CM reviews, HIGH]
- **T2 (safe now) Case-insensitive, canonical email matching** at the token boundary in EA/HR/SOP (ER already). [EA, HR, SOP; HIGH review, auth]
- **T3 (safe now) EA operator tokens:** minimum length, throttle, named per operator (copy Omniview's). [EA]
- **T4 (safe now) Consistent "Company missing from /me" = NONE** in GL and SOP. [GL, SOP]

**Definitions and the owner model (after D1-D4)**
- **T5 Write the platform capability definitions** (R1) and the Owner Admin rule (R4) into this document as the settled text; Femi signs off. [CM]
- **T6 EA: implement the settled Owner Admin default and remove nothing else;** keep the explicit-assignment path for owners who also work. [EA; HIGH]
- **T7 SOP: remove or re-express the Sales WRITE uplift;** WEB shows what EA reports. [SOP, WEB]

**Separation of duties (after D2, D6)**
- **T8 SOP: derive `approvedBy` from the caller (APPROVE + role), drop the body field;** creator ≠ approver on returns/credit notes. [SOP; HIGH]
- **T9 POP: approval needs APPROVE and records the actor; threshold and settings need ADMIN;** creator ≠ approver. [POP; HIGH]
- **T10 HR: `submittedBy` ≠ `decidedBy` (with the one-person exception per D6); initial pay and bank details on create become owner/ADMIN-only.** [HR; HIGH]
- **T11 IM: adjustment and stock-count approval uses EA APPROVE, not the Cognito group `StoreManager`;** creator ≠ approver. [IM; HIGH]
- **T12 GL: add approval where the business needs it** (fixed-asset disposals, manual journals above a limit; to be scoped) and give the unused ADMIN gate a use for period/account configuration. [GL]
- **T13 ER: staff management cannot grant a role the grantor does not hold; role strings validated against a closed list; fee issue ≠ payment confirm** (ER's own SPUTO covers detail). [ER; HIGH]

**Delegation, services, operators (after D5)**
- **T14 EA: cap delegation (R5);** no self-PATCH of modules; an active member's re-invite applies the new assignment. [EA; HIGH]
- **T15 Scoped service credentials (R7):** per-service principals bound to Tenant/Company sets; GL validates the Tenant header against the credential; decide GL options A/B in `docs/GL_Tenant_Header_Service_Account_Options.md`; then POP/IM/SOP/HR derive the Tenant from the Company instead of a deploy-time value (this also closes the "one Company/Tenant per deployment" class). [GL, EA, CM for secrets/Terraform; HIGH]
- **T16 WEB: gate by capability from `/me` (R11);** remove READ-floor assumptions. [WEB]

**Audit and runtimes**
- **T17 Shared minimum audit record (R10)** and the per-service writers for create/approve/role-change. [each service; EA defines the shape]
- **T18 Runtime extension contract (R12)** published; the Education Runtime's RBAC SPUTO follows it; ER student read gets a per-child guardian check. [ER, CM]

---

## 5. Order (foundations first)

1. **Now, no decisions needed:** T1-T4 (fail-closed, canonical email, operator tokens, consistent fall-backs). These remove risk without changing who can do what. The freeze stays for everything else.
2. **Femi decides D1-D6** (this document is the agenda). CM then writes T5 as the settled definitions.
3. **Owner model and separation of duties:** T6/T7, then T8-T13 in this order of risk: SOP (F2), POP (F3), HR, IM, ER (F4), GL.
4. **Delegation and service scope:** T14, T15, T16.
5. **Audit and runtimes:** T17, T18, then each runtime's own RBAC SPUTO.
6. **Application round with every peer (Femi, 2026-10-08):** CM sits down with each session in turn (EA, GL, POP, SOP, IM, HR, ER, WEB, Omniview): each peer maps the settled rules to its own routes and screens, lists exceptions, re-verifies the survey items marked above, and returns a short docs-only statement of its current rules and its plan. Output: one row per service in the status table below. No service changes its model before its row exists.

### Status table (to be filled in the application round)

| Service | Current-rules statement | Gaps vs this SPUTO | Plan / branch | Reviewed by CM |
|---|---|---|---|---|
| EA | not yet | | | |
| GL | not yet | | | |
| POP | not yet | | | |
| SOP | statement sent in chat 2026-10-08 (to be written up) | F2, uplift, fail-open | | |
| IM | not yet | | | |
| HR | not yet | | | |
| ER (Education Runtime) | will write its own RBAC SPUTO | F4, guardian read | | |
| WEB | not yet | | | |
| Omniview | not yet | | | |

---

*Sources: the 2026-10-08 code survey (nine checkouts), `docs/Per_Company_RBAC_Design.md` (2026-09-23; its section 3(f) said Owner-Admin-implies-ADMIN "is confirmed wrong and should not be built", which matches Femi's correction), `docs/Service_Account_Identity_And_EA_Membership_Design_Note.md` (v1.8), `docs/Service_Account_Principal_Cutover_Scope.md`, `docs/GL_Tenant_Header_Service_Account_Options.md`, and CM's checks of `origin/master` and the live task definitions.*
