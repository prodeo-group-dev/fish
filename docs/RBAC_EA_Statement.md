# RBAC: Enterprise Administration (EA) statement

**Status:** DRAFT v1, 2026-10-08, written by the EA session in reply to `docs/RBAC_SPUTO.md` v0.2. Docs only; no code or authorization-model change (the freeze stands). Everything below was read from EA's `origin/master` (commit `bc9f36e`, running as task definition `fish-enterprise-administration:78`) on 2026-10-08, with file references. Where this statement contradicts the SPUTO's survey, the contradiction is marked and is mine to defend.

## 0. A correction first (it changes the picture)

For several days EA told other sessions, and through them Femi, that the Owner Admin "has only an intrinsic READ floor and no module grants in `/me`". **That is wrong for every Company registered through EA since 2026-09-23, and for every Company that existed at migration V15.** Details in section 1.3. The consequences the SPUTO and I both drew from it need re-checking:

- The SPUTO's table row "Owner Admin: EA reports READ with no modules at every Tenant Company on master" is **WRONG** (marked in section 2, F7).
- **T6 (EA registration creates the Owner's explicit assignments) is already implemented**, with level ADMIN and every business module. What is missing is the capability model underneath it (T5a) and the rule that the Owner's approver role cannot be removed.
- The parked branch `feat/ea-owner-admin-all-modules` would have changed almost nothing for registered Companies, and the sitting's expectation that the Owner "will 403 on Purchases" is probably wrong too (to be confirmed with the one query in section 5).
- SOP's Owner Admin uplift may have been added for a Company where the Owner had no assignment. That should be checked before T7.

I have not verified production data (no database access from this session). **Request to CM: one read-only query** on `membership_company_assignments` joined to `memberships.is_owner_admin` for Femi's Tenant's Companies (role, access_level, modules), to confirm.

## 1. EA's current authorization rules, as the code does them

### 1.1 The vocabulary

- **Role** (closed enum, `domain/tenancy/role.kt`): `OWNER_ADMIN`, `ACCOUNTANT`, `SALES_OFFICER`, `PURCHASING_OFFICER`, `INVENTORY_MANAGER`, `HR_OFFICER`. Business functions, not seniority. `OWNER_ADMIN` is never assigned by invite.
- **AccessLevel** (`access_level.kt`): `NONE < READ < WRITE < APPROVE < ADMIN`, compared with `atLeast` (a linear ladder, so ADMIN implies everything below it).
- **ManagedModule**: `GL, HR, SOP, POP, IM, TAX, EDUCATION_RUNTIME`. `EDUCATION_RUNTIME` marks a SCHOOL Company and is granted by registration, never by hand.
- **Membership** (one per User per Tenant, `membership.kt`): `isOwnerAdmin` (one per Tenant), `status` (`PENDING | ACTIVE | REVOKED`), and a set of **CompanyRoleAssignment** (role, accessLevel, non-empty `grantedModules`) per Company. Defaults for an invited role: level `WRITE`, modules by role (`ACCOUNTANT` GL+TAX, `SALES_OFFICER` SOP, `PURCHASING_OFFICER` POP, `INVENTORY_MANAGER` IM, `HR_OFFICER` HR) (`Membership.defaultAccessLevelFor` / `defaultModulesFor`).
- Only an `ACTIVE` membership authenticates. A person with no active membership anywhere gets 401, not 403 (`Auth.kt toAuthenticatedCaller`). An expired employment window does not exist yet (designed in `docs/Staff_Onboarding_Offboarding_SRS.md`, not built).

### 1.2 What `GET /me` reports (`MeRoutes.kt`)

Per Tenant: `isOwnerAdmin`, `tenantStatus`, `kybStatus`, phone status and deadline, and `companies`. For the Owner, `companies` lists **every Company of the Tenant**; for staff, only the Companies they have an assignment at. Per Company: `role`, `accessLevel` and `grantedModules` **are the assignment's values, or null / empty when there is no assignment**. The "intrinsic READ floor" exists only inside `Membership.accessLevelAt()` (internal to EA); it is **never serialised**: a Company without an assignment reaches consumers as `accessLevel: null`, which GL and SOP read as READ and POP, IM, HR as NONE (that divergence is F7, and it starts here).

### 1.3 The Owner Admin today

1. **Registration creates an explicit assignment.** `RegisterCompanyUseCase.assignOwnerAdminsAt` (lines 219-225) gives every owner Membership of the Tenant, at each newly registered Company, role `OWNER_ADMIN`, level `ADMIN`, modules = **every module except `EDUCATION_RUNTIME`** (`GL, HR, SOP, POP, IM, TAX`). For a SCHOOL Company `EDUCATION_RUNTIME` is added to that assignment. Added 2026-09-23 (`a8d0e31`), tested by `RegisterCompanyUseCaseTest` ("the founding admin is auto-assigned OWNER_ADMIN at ADMIN and every non-EDUCATION module").
2. **Migration V15 carried the old Tenant-wide values into per-Company assignments** for every existing Membership, including the Owner's former `OWNER_ADMIN` / `ADMIN` (with the old default of all non-education modules when none were recorded).
3. **The READ floor is only the fallback** for a Company where the Owner has no assignment (not produced by the live routes).
4. **Owner-only routes** key on `isOwnerAdmin`, not on level (`authorizeTenantOwnerAdmin`, `Auth.kt`): company registration, admin phone, dashboard (since 2026-10-07), verification status, support tickets, company links (approve/revoke/list), broadcast to everyone / a role / a Company, and the owner-contact lookup's data source.
5. **The Owner can narrow himself.** The domain allows `removeAssignment`, and `PATCH .../modules` (`canManageStaffAt` is true for the Owner) can shrink his own module set to any non-empty set. There is no route that removes an assignment, and nothing stops the Owner dropping a module. **There is no "approver role cannot be removed" rule** (SPUTO R4); today there is also no approve capability separate from level.

### 1.4 Routes and who may call them

| Area | Rule today |
|---|---|
| Onboarding (`POST /tenants`, `POST /users`) | any verified sign-in (email claim), no existing user needed |
| `POST /tenants/{t}/company-registration` | Owner Admin only |
| Staff: invite `POST .../memberships`, roster `GET`, remove `DELETE` | Owner Admin **or** a Membership holding `HR_OFFICER` at `ADMIN` at any Company (`authorizeStaffManagement`); each invited assignment must then be at a Company where the caller `canManageStaffAt`; remove needs all of the target's assignments inside the caller's reach |
| `PATCH .../memberships/{m}/companies/{c}/modules` | member passing `canManageStaffAt(company)`; **no self-restriction**; changes modules only, never level |
| Dashboard, verification status, admin phone, support tickets, company links | Owner Admin only (human token) |
| Approvals queue `GET .../companies/{c}/approvals-queue` | **any member with READ at that Company** (`authorizeCompanyForRead`); lists pending customer returns, stock adjustments, supplier returns and payroll runs. Wider than its content warrants (my backlog item 1.2, not yet built) |
| Messaging | direct: any member to an active member, subject to the company-link rule; company channel: READ at the Company; module channel: module granted at that Company (or Owner); role channel: holds the role (or Owner); everyone / role / Company broadcast: Owner only |
| `GET /me` | any active member |
| Owner-contact `GET /api/internal/companies/{id}/owner-contact` | SOP's own service principal only (no user, no membership, never falls back to the human verifier) |
| `/operator/*` | `X-Operator-Token` matched against `EA_OPERATOR_TOKENS` (JSON map of operator name to token, constant-time compare, named in the log); **no minimum length, no throttle** |

### 1.5 How service callers are trusted

- EA registers five **service providers** (GL, POP, SOP, IM, HR) beside the human provider. Each resolves the token's `email` claim to a **User with an active Membership** exactly like a person, so **EA does not give service tokens a membership bypass**; those service accounts are Users with Memberships. The bypass the SPUTO describes is in GL, IM and SOP, not here.
- **The `?: verifier` fall-back exists in EA too** (`infrastructure/web/Application.kt:467-468`, the `installEaJwtAuth(...)` call: `glServiceVerifier ?: verifier` and the same for POP, SOP, IM, HR): if a service audience variable is unset, the human verifier is registered under the service name. In EA that grants nothing extra (a human token already passes the human provider and still needs a membership), but it is the same fail-open pattern as F1. All five audiences are set in production (CM's check of `:77`).
- The one **pure service principal** is SOP's (`ea-jwt-service-principal-sop`): a token for SOP's own audience, no User lookup, and it **refuses everything when the audience is unset**. It is the pattern T1 and T15 want; EA's other five providers are not.

## 2. Re-verification of the survey findings that touch EA

| Finding | Verdict | Evidence |
|---|---|---|
| F1 fail-open verifiers | **PARTLY** (pattern present, no privilege gain) | `Application.kt` `installEaJwtAuth(... ?: verifier ...)`; service providers still resolve a Membership (`Auth.kt toAuthenticatedCaller`) |
| F5 EA delegation uncapped | **CONFIRMED** | `InviteStaffMemberUseCase` accepts any `accessLevel` and any modules per assignment (`CompanyAssignment`), checked only against the grantor's Company reach (`TenantRoutes.kt` invite handler); `PATCH modules` has no self-restriction; an active member's re-invite is a no-op (`alreadyMember=true`) |
| F6 service tokens blanket | **PARTLY for EA** | EA's own providers bind to a Membership; the blanket bypass is in GL, IM, SOP. EA's pure principal (SOP) is not scoped to a Company either |
| F7 "EA reports READ with no modules for the Owner" | **WRONG for registered or migrated Companies; PARTLY otherwise** | section 1.3; for an unassigned Company `/me` reports `null`, not READ (section 1.2). "Company missing from /me" is never produced by EA for the Owner (he lists every Tenant Company); a staff member simply lacks it |
| F7 "WEB comments describe a READ floor" | not EA's; consistent with section 1.3 being unknown to consumers | |
| F8 EA operator tokens: no length rule or throttle | **CONFIRMED** | `Auth.kt authorizeOperator`; tokens loaded from `EA_OPERATOR_TOKENS` JSON without validation (`Application.kt`) |
| T2 EA email matching | **CONFIRMED** (exact, case-sensitive) | `ExposedUserRepository.findByEmail` uses `UsersTable.email eq email`; `User.create` does not normalise (`user.kt`) |

## 3. Gaps against R1-R13 and the tasks that touch EA

| Requirement / task | EA gap | EA estimate | Proposed order |
|---|---|---|---|
| **T3 / R13** operator tokens | no length rule, no throttle (Omniview has both) | 0.5 day | with T1/T2, first |
| **T2 / R9** canonical email | exact match, no normalisation; plus a one-off lower-casing migration (check duplicates first) | 1 day + review | first |
| **T1 / R6** fail-open | replace the five `?: verifier` fall-backs with deny-all (the SOP principal is the model) | 0.5 day | first |
| **R8** consistent missing-Company | EA must report an explicit value for an unassigned Company (see T5a) | folded into T5a | with T5a |
| **T5a / R1** capability set | see 3.1 | EA side 2-3 days across 4 deploys; consumers' declarations are theirs | after T5 text is settled |
| **T6 / R4** Owner's explicit assignments | **already implemented** at ADMIN with all business modules; remaining: express as explicit capabilities, forbid removing the Owner's approve capability, one-off check of legacy Companies | 1 day after T5a | with T5a |
| **T7** | SOP removes its uplift; but first confirm why it was needed (section 0) | none (SOP/WEB) | after T6 verified |
| **T14 / R5** delegation caps | see 3.2 | 1-2 days | after T5a |
| **R2 / R3** approvals, thresholds | EA owns none of these; the staff onboarding design (delegate triggers, Owner approves) is the EA-side example: `docs/Staff_Onboarding_Offboarding_SRS.md` | n/a | n/a |
| **T17 / R10** audit record | EA keeps no audit record of role or module changes today; shape to be defined by EA as the SPUTO asks | 2 days for the shape and EA's writers | after T5a |
| **Approvals queue read gate** (not in the SPUTO) | wider than its content: any READ member sees pending payroll and returns | 0.5 day | with T3 |

### 3.1 T5a: rolling out the capability set consumers-first

Today every consumer reads `accessLevel` from `/me` (a string) and compares by ladder. A change from a linear level to a capability set is a contract change across GL, POP, SOP, IM, HR and WEB, which all decode `/me` strictly. Proposed sequence, **each step its own deploy, HIGH review, nothing skipped**:

1. **Declare.** Every consumer adds an optional `capabilities: List<String>` (default empty) to its strict `/me` mirror and ignores it. WEB declares it too. EA ships nothing yet.
2. **Publish (no behaviour change).** EA adds `capabilities` per Company, derived from the stored level by the *current* ladder (`READ` gives `[read]`, `WRITE` gives `[read, write]`, `APPROVE` adds `approve`, `ADMIN` gives `[read, write, approve, administer]`), so every decision a consumer makes is unchanged. `accessLevel` stays.
3. **Switch.** Each consumer moves its decisions to `capabilities` one service at a time (SOP first, per the SPUTO's risk order), still accepting `accessLevel` as a fallback while a Company has no `capabilities`.
4. **Store the real set.** EA adds capability storage (a table next to `membership_assignment_modules`) with a migration that maps **every existing ADMIN to the full set** (so no one loses write or approve overnight: the Owner's registration assignment, and any `HR_OFFICER` delegate at ADMIN, keep exactly what they have), and from then on `administer` can be granted **without** write or approve. New invites use the real set; the Owner's registration assignment becomes the explicit full set (D4).
5. **Retire.** Remove `accessLevel` from `/me` last, after every consumer has stopped reading it (a final consumers-first removal, since strict mirrors that still declare it would fail).

Compatibility rule for the whole sequence: a Company with no assignment reports `capabilities: []` and `accessLevel: null`, which means **NONE for everyone including the Owner** (R8).

### 3.2 T14 / R5: delegation caps (EA's proposal)

- Invite and re-assign: a grantor may grant at most the capabilities **they hold at that Company**, only for Companies where they `canManageStaffAt`, never to themselves, and never `approve` or `administer` they do not hold.
- `PATCH modules`: refuse when the target is the caller; refuse modules the caller does not hold at that Company.
- An invite for an already-active member applies the new assignment (today it is a no-op) with the same caps.
- The `HR_OFFICER at ADMIN` delegation rule (Femi's 2026-09-23 direction) stays, but under the capability model it becomes "holds `administer` plus the HR module at that Company".

## 4. Objections, corrections and things the SPUTO misses for EA

1. **Section 0 / F7 is wrong about the Owner**, and T6 is mostly done. Please do not schedule T6 as new work; schedule the capability expression and the "approver role not removable" rule.
2. **D1 versus the existing Owner assignment.** Under today's ladder the Owner's registration assignment (`ADMIN`) already implies write and approve. Femi's rule (D4: the Owner holds every capability as explicit assignments) matches that, but the *reasoning* for rejecting "ADMIN everywhere" (writing into financial data) is satisfied only if ADMIN is split into capabilities. Until T5a ships, the Owner **does** have write on every module of a registered Company through his explicit assignment.
3. **Staff onboarding and offboarding SPUTO** (`docs/Staff_Onboarding_Offboarding_*`) already encodes P3 and R2 for people changes (a delegate raises, the Owner alone approves) and introduces employment links with a union of active windows on membership resolution. Those are RBAC changes too and should be in the order, ahead of any change to `/me`.
4. **A generic `STAFF` role** (non-function staff, e.g. teachers) is proposed there; the closed `Role` list is read strictly by GL, so it needs the same consumers-first order as T5a.
5. **R9** also needs `sub` recorded: EA stores no `sub` today; adding it to `User` is part of T2.
6. **Service identities in EA**: the pure-principal pattern (SOP) should become the template for T15; EA would also need a per-service principal for any new caller (the Company-to-Tenant lookup proposed for Phase 2 is the first example, on hold).

## 5. What EA needs from others

- **CM:** the read-only check in section 0; the order for T1-T3 (EA can start them the moment the freeze lifts for the "safe now" items); a decision on whether the approvals queue gate (section 3) counts as "safe now".
- **GL, POP, SOP, IM, HR, WEB:** declare an optional `capabilities` field in their `/me` mirrors (T5a step 1) when CM clears it; tell EA how each treats `accessLevel: null` today so step 2 can remove the divergence.
- **HR:** confirm the delegate-cap semantics for `HR_OFFICER`, since T14 changes who can invite whom.
- **Femi:** D5 (service credential scope); and whether the Owner may remove modules from himself at all (today he can shrink them).
