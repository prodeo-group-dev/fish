# Epic 13: EA's identity leg (BK-FIN-1)

**Status:** DRAFT, 2026-10-07, written by the EA session at CM's request for `docs/Fee_Billing_Epic13_SPUTO_Scope.md` (section 6). **Docs only; no code, and none is started.** It answers three questions: how a school maps to an EA Company and an SOP entity, how a school's Bursar maps to access, and what EA must issue or change for service identities. Everything below was read from the code on 2026-10-07, not assumed.

## 1. School, Company and SOP entity

**The link already exists and is one-to-one: one school = one EA Company = one SOP entity, and the key is the EA Company id.**

- **Who creates it, and when:** EA, at Company registration. When the Owner Admin registers a Company whose industry is `SCHOOL`, `RegisterCompanyUseCase` first calls Education Runtime `POST /schools {organisationId = the Company id, tenantId, name}` as EA's own dedicated service account, and refuses to register the Company if ER fails ("there must exist a school and its records before any school admission is done"). ER answers `{schoolId, organisationId, name}`; EA stores `schoolId` on the Company's own record (`company_names.school_id`) and ER stores `organisationId` (the Company id) on the school. A repeat of the same registration is idempotent and backfills `schoolId`.
- **The SOP side:** SOP's `entityId` is the EA Company id (SOP sales orders and customers carry `entityId`; EA's dashboard already reads SOP by it). So SOP needs **no school id at all**: it keys everything by Company id, which ER already holds as `organisationId`. SOP to ER events should therefore carry the Company id, and ER resolves its own school from `organisationId`. EA need not be in the runtime path, and EA's stored `schoolId` stays what it is today: a convenience for WEB.
- **The gap, honestly:** Companies registered **before 2026-09-27** have no `schoolId` on file, and a Company's industry type is immutable, so they cannot be converted into school Companies. This is the "no self-service school provisioning" item already in the backlog. For Epic 13 it does not matter: all production data is legacy test data until the live switch, and the reset covers both services. The pilot school should be registered through the live path.
- **A bigger constraint this exposed (needs SOP, GL and CM, not EA):** SOP is bound to **one Tenant per deployment** (`SOP_EA_TENANT_ID`; GL likewise with `SOP_GL_ENGINE_TENANT_ID` on SOP's side). SOP's membership check accepts callers of that configured Tenant only. A school owned by a different Tenant from the one SOP is configured for cannot use SOP billing at all. The first pilot school must therefore sit under the Tenant SOP is bound to, or SOP and GL must become multi-tenant (resolving the Tenant from the Company per request), or a separate SOP deployment per school Tenant. This belongs in the epic's order of work and in Femi's "first pilot school" decision (scope doc section 7). EA's contribution if SOP becomes multi-tenant: the existing `findTenantIdsLinkedToCompany` lookup and the new owner-contact style service-principal route are the building blocks.

## 2. The Bursar's access

Two separate grants are involved, in two systems, and EA owns only one of them.

| Grant | System | Today |
|---|---|---|
| The ER duty `BURSAR` (and `FEE_OFFICER`), which gates ER's fee rules and clearance | ER, hand-assigned as a `StaffAssignment`; by the teaching-staff design it **never** comes from HR or EA | unchanged by this epic |
| Billing in SOP (invoices, payments, balances, runs) | EA Membership at the school's Company, checked by SOP's own authorizer: module `SOP` at `WRITE` or above at that Company | to define |

**Recommendation for the SOP side: do not add a new EA role.** EA's `Role` is a closed list of business functions (accountant, sales officer, purchasing officer, inventory manager, HR officer) and is read strictly by GL, so a school-specific `BURSAR` role would be a lockstep release for an industry title. Billing is the sales function, and EA already maps `SALES_OFFICER` to module `SOP` at `WRITE` by default. So **a Bursar holds the EA role `SALES_OFFICER` at the school's Company, module `SOP`, access level `WRITE`.** This is the generic-core, industry-specialisation rule the platform already follows (industry specialisation is carried by `IndustryType`, not by new core roles).

- **Approval-level actions** (waivers, refunds): Femi's rule is that the Owner Admin is the sole approver of anything sensitive. If waivers and refunds need approval, they belong to the Owner Admin (or an explicit `APPROVE` level the Owner Admin grants), not to the Bursar's default `WRITE`. Needs Femi's answer in the SOP half.
- **Does the proposed `STAFF` role help?** No. `STAFF` is for people with no business function (teachers, drivers); the Bursar has one. A generic `STAFF` with an explicit `SOP` grant would work technically, but it would hide what the person does.
- **One limitation to know:** an assignment carries one access level for all its granted modules, so "SOP at `WRITE` and GL at `READ`" for the same person at the same Company is not expressible in one assignment. If a Bursar needs ledger reports as well, that is a follow-up (a per-module level, or two grants), not a blocker.
- **How a Bursar gets the Membership:** today only the Owner Admin invites staff (and an HR Officer delegate, pending Femi's decision on the invite and remove lock-down). The HR onboarding design has a closed list of position codes (`STAFF`, `TEACHER`, `NON_TEACHING_STAFF`); a Bursar onboarded through HR would arrive as `NON_TEACHING_STAFF`, which maps to `STAFF` with **no modules**, so SOP access would still need a manual grant. **Proposal for Femi, HR and ER:** add one HR position code `BURSAR` mapping to `SALES_OFFICER` + `SOP` at `WRITE` (and no ER duty; the ER `BURSAR` duty stays admin-assigned). Until then the Owner Admin grants it by invite.
- **The Owner Admin himself:** SOP is giving the Owner Admin of its configured Tenant write on Sales through its own authorizer (SOP-side rule, with CM for review at the time of writing; no EA change), so the school's owner can bill without a Bursar.

## 3. Service identities: what EA must issue or change

**Short answer: nothing, for ER and SOP calling each other.**

- Module-to-module calls bypass EA's membership check **by design** (`docs/Service_Account_Identity_And_EA_Membership_Design_Note.md`: the Tenant's own module mesh is not Prodeo's to gate). The service identities themselves are Cognito service-account users or clients in the shared infrastructure (CM's `Infrastructure/` project), not something EA issues.
- **ER to SOP** exists in one direction today (creating a guardian as an SOP customer). **SOP to ER** needs ER to accept a **pure service principal**: verify a token for SOP's audience against ER's own configuration, no user lookup, and **never fall back to the human verifier when the audience is unset**. That is an ER change and a CM wiring task. EA has just built exactly this pattern for SOP's owner-contact route (`ea-jwt-service-principal-sop`, merged and live, the `ServicePrincipal` principal in `AuthenticatedCaller.kt`), which ER can copy, including the mutation test that proves a human token cannot pass when the audience is unset.
- **EA has no Education Runtime audience** (`EA_JWT_SERVICE_AUDIENCE_*` covers GL, POP, SOP, IM and HR only). It would be needed only if ER ever calls EA with its own identity (for example to read the Owner Admin's contact for notifications). Nothing in Epic 13 requires it; if it ever does, it is one new audience variable plus a dedicated Cognito client, wired by CM.
- **Per the strict-decoding rule**, any new EA route that SOP or ER consume must be declared by the consumer before use; EA has none to add for this epic.

## 4. Order, and what EA depends on

- EA's own held work in front of this (the `STAFF` role, the membership validity window) does **not** block the Bursar path: `SALES_OFFICER` + `SOP` exists today. The validity window only matters if the Bursar is employed through HR, which also needs the `BURSAR` position code above.
- Dependencies to register: **SOP and GL** (the one-Tenant binding, section 1), **ER** (accepting SOP's service principal; resolving a school by `organisationId`), **HR** (a `BURSAR` position code, optional), **CM** (service-principal wiring; any new audience), **Femi** (first pilot school and its Tenant; the waiver and refund approval rule; the `BURSAR` code).
