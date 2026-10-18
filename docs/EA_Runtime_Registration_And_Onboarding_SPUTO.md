# EA: runtime registration and Tenant onboarding for any runtime (SPUTO)

**Status:** 2026-10-18, planning only, nothing built. Written by the EA session for CM's programme "Generic core and runtimes" (Femi: "Today it is Education Runtime, tomorrow it can be Hospital Runtime, or AutoMechanic Runtime etc."). It builds on `docs/Platform_Contract_Generic_Services_And_Runtimes_SPUTO.md` (the contract layer, 2026-10-12, which this note does not repeat) and `docs/Owner_Information_SPUTO.md`, and replaces the design-only `docs/Industry_Type_Module_Enablement_Design.md` (2026-09-20) where they differ. Evidence tags: **[code]** read on `origin/master` of EA, GL, SOP or WEB on 2026-10-18; **[doc]** read in a repo document; **[decided]** in the Decisions_Log; **[proposed]** this note's proposal; **[unverified]** not checked.

Principles this note obeys and does not reopen: SOP, IM and POP are the heartbeat of any organisation and work under any runtime's own names; generic core first, a runtime specialises by **data and wrappers**, never by duplicating a generic service; a runtime keeps its own domain and vocabulary; Prodeo is a landlord with no role in a Tenant's data; strict decoding with consumers declaring a field first; an account per transaction type from the Company's chart (Suspense 3910 when none).

---

## 1. Scope (S)

**EA's part of the programme:** what it takes for a **new runtime** (Hospital, AutoMechanic, anything else) to be registered with the platform and for a **Tenant to onboard onto it**, with no change to the generic services and as little code in EA as possible. Concretely, EA's six jobs:

1. **Know what runtimes exist and what each declares** (a *runtime manifest*).
2. **Industry type as data**: the value chosen when a Company is registered, mapped to a runtime, a module set and a chart template.
3. **Module and role declaration**: which module a runtime adds and which roles it brings.
4. **Provisioning**: creating the runtime's own organisation and first administrator when a Company of that industry is registered, idempotently.
5. **Default module enablement and default chart per industry** (EA decides *which*; GL owns the templates).
6. **How the Business Owner sees a runtime's information** (the Owner view, extended).

**Out of scope here:** a runtime's own domain (admissions, patients, vehicles, job cards) and workflows (the Runtime Wrapper Pattern SPUTO, ER); vocabulary and navigation (WEB's SPUTO); the chart templates and posting rules themselves (GL's SPUTO); what SOP, IM and POP offer a runtime (their SPUTOs); the event contract and broker (platform contract Layers C and D); a credit-union or banking runtime (Femi, 2026-10-07: build only what a dry run proves necessary).

---

## 2. What is true today (evidence)

| # | Finding | Tag |
|---|---|---|
| E1 | `IndustryType` is a closed enum with two values, `GENERIC` and `SCHOOL`; its own KDoc says the second value exists only because one industry has real behaviour. It is immutable once set (a repeat registration with a different industry is refused 409 `industry_type_immutable`). | [code] EA `industry_type.kt`, `RegisterCompanyUseCase` |
| E2 | `ManagedModule` is a closed enum (GL, HR, SOP, POP, IM, TAX, EDUCATION_RUNTIME, PAYROLL withheld). The Education module is a literal enum value, and four rules mention it by name: registration auto-grants it for a SCHOOL Company; invite and modules change refuse it at a non-school (`module_not_allowed_for_industry`); the Owner Admin's default set excludes it. | [code] EA `managed_module.kt`, `RegisterCompanyUseCase`, `InviteStaffMemberUseCase`, `UpdateMembershipModulesUseCase`, `Membership.defaultModulesFor` |
| E3 | Provisioning is one hard-wired port, `EducationRuntimeGateway` (`provisionSchool`, then `grantFirstAdmin`), called inside `RegisterCompanyUseCase` before the Company is activated; a failure refuses the whole registration (`school_provisioning_failed`). It authenticates as EA's own service identity. | [code] EA `education_runtime_gateway.kt`, `RegisterCompanyUseCase` |
| E4 | EA stores the runtime's organisation id on the Company (`schoolId`) and `GET /me` carries `schoolId` per Company. The five services mirror `/me` strictly. | [code] EA `Dtos.kt` (`schoolId`), `MeRoutes.kt` |
| E5 | The "is this a school" test is a lookup, `SchoolCompanyLookup`, used by the invite and modules rules and exposed to SOP through a service-only route answering `{"industryType":"SCHOOL"\|"GENERIC"}`. | [code] EA `SchoolCompanyLookup.kt`, `CompanyIndustryRoutes.kt` |
| E6 | SOP decides which Companies the Education Runtime's credential may act in from an **environment variable** (`SOP_ER_COMPANY_IDS`), not from EA. | [code] SOP `Application.kt` line 214 |
| E7 | GL's chart template is chosen by `ClientType` (individual, sole trader, partnership, limited company, non-profit), **not by industry**: `ChartOfAccountsTemplate.accountsFor(clientType, companyId)`. A school and a trading business get the same template for the same legal form. | [code] GL `chart_of_accounts_template.kt` line 143 |
| E8 | WEB has a closed `Industry = 'GENERIC' \| 'SCHOOL'` and **infers** it from whether the Company holds the Education module (`industryOfGrants`). The Education screens are many (`educationRuntime.ts` alone has 36 references). | [code] WEB `moduleLabels.ts`; reference counts from a search |
| E9 | The runtime's own roles are the runtime's: the Education Runtime has `SCHOOL_ADMIN` and its own assignments; the first admin is granted by EA once. EA's roles are functional platform roles (OWNER_ADMIN, ACCOUNTANT, SALES_OFFICER, and so on). The mapping from a runtime's roles to platform view/enter/approve/administer capabilities is the RBAC SPUTO's R12, **not built**. | [code] ER `FirstAdminService.kt`; [doc] RBAC_SPUTO |
| E10 | SOP, POP, IM and HR hold module ids as **strings** (a new id decodes without a code change); GL decoded them as an enum and, since 2026-10-15, fails closed on an unknown value (no access, not an error). | [code] the five mirrors; [decided] CM, 2026-10-15 |
| E11 | Order of onboarding today: WEB creates the Company in GL (GL builds the chart and opens a period), then registers it with EA, which stores name and industry and provisions the runtime. EA never calls GL. | [code] GL `AddCompanyToTenantUseCase`, EA `RegisterCompanyUseCase` |
| E12 | The Education provisioning is the **only** industry-specific code in EA; everything else in the Tenant, membership and communication model is already runtime-neutral. | [code] my reading of the greps above; counts per file in section 7 |

**Where each service assumes Education** (so the generalisation is honest): EA four rules (E2) plus the port (E3); SOP one env var (E6); WEB the closed type and inference (E8); GL nothing (E7 is industry-blind); HR, IM, POP only mirror the module string.

---

## 3. What the generic design must achieve (P, requirements)

**Functional (FR-RUN-n)**

| ID | Requirement | MoSCoW |
|---|---|---|
| FR-RUN-01 | A **runtime manifest** (data, versioned) declares: runtime id and name; the industry types it serves; its module id (a string); the roles it declares (id, label, which platform capabilities it implies); its provisioning contract (route, schema version, idempotency key); the service identities it uses and the generic routes each may call; its default module set; the chart template key GL should use; a vocabulary key for WEB; and optionally an owner-summary route. | Must |
| FR-RUN-02 | An **industry type is a registered value** in a registry, not an enum compiled into five services. Adding Hospital means adding a manifest and a registry entry, not changing SOP, IM, POP, HR or GL code. `GENERIC` has no runtime. The two values in use today keep their wire spellings. | Must |
| FR-RUN-03 | A Company has **exactly one** industry type, set at registration and immutable (existing rule, kept). | Must |
| FR-RUN-04 | The rule "a runtime's module can be granted only at a Company whose industry that runtime serves" is **one generic rule driven by the registry**, replacing the four named-Education checks, with behaviour for Education unchanged (the same refusal `module_not_allowed_for_industry`). | Must |
| FR-RUN-05 | **Provisioning is one generic port** driven by the manifest: create the runtime's organisation for the Company (idempotent on the Company id), then grant the Owner Admin as its first administrator, then activate; any failure refuses the registration and leaves nothing half-made (existing semantics, generalised). The Education adapter wraps today's gateway. | Must |
| FR-RUN-06 | `GET /me` carries a generic **`runtimeLinks`** per Company (runtime id, the runtime's organisation id) instead of a runtime-specific field; `schoolId` stays during a stated overlap. Declared by all five strict mirrors first. | Must |
| FR-RUN-07 | The services that gate a runtime's credential (SOP, GL) ask EA "which runtime serves this Company" (a service-only read) instead of reading an environment variable. | Should |
| FR-RUN-08 | **Default module set per industry**: every Company gets the generic modules; a runtime adds its own; the Owner Admin's default includes the runtime module for his Company (existing behaviour for Education). A runtime may also name modules that should be *off* by default (for example Inventory off for a consultancy), never removed. | Must |
| FR-RUN-09 | **Default chart per industry**: the manifest's template key tells WEB/GL which chart template a new Company of that industry gets; GL owns the templates and falls back to the legal-form template (today's behaviour) when the key is unknown or absent. | Should |
| FR-RUN-10 | **Role declaration**: a runtime's roles are listed in its manifest with the platform capabilities they imply (view, enter, approve, administer), so the platform can answer "what may this person do here" for the Owner view and for approval routing; the capability mapping itself is the RBAC SPUTO's work. | Should |
| FR-RUN-11 | The **Owner view** (Owner Information SPUTO) includes a runtime's owner summary through the manifest's route, using the same honest-figure contract (basis, as-of, source, quality); a runtime without one simply has no tile. | Should |
| FR-RUN-12 | An **unknown runtime, module or industry fails closed** everywhere: no access, a plain refusal, never an exception or a silent default to a different runtime. | Must |
| FR-RUN-13 | Registry changes are **made by the platform's people through a reviewed change**, never through a Tenant-facing route; no Tenant can register a runtime. | Must |

**Non-functional (NFR-RUN-n)**

| ID | Requirement |
|---|---|
| NFR-RUN-01 | **Landlord:** EA holds only the link (runtime id and the runtime's organisation id) for a Company, never the runtime's domain data. For Hospital this means **no patient identifier or health fact ever reaches EA, `/me`, a log or a notification**. |
| NFR-RUN-02 | Provisioning calls are idempotent and replay-safe; the Company id is the idempotency key; a retry after a partial failure completes without duplicating the runtime's organisation. |
| NFR-RUN-03 | Every cross-service payload here is strict, with golden contract files and consumers declaring a new field first; no `ignoreUnknownKeys`. |
| NFR-RUN-04 | The manifest is validated at start-up: a malformed or duplicate manifest stops EA from starting rather than half-working. |
| NFR-RUN-05 | Registering a runtime and each Company's provisioning are audited in the platform audit-record shape (the T17 shape, once EA's audit table exists). |
| NFR-RUN-06 | Tests-first and mutation-checked, as for every authorization rule in EA. |

---

## 4. The three paper runtimes (U, use cases)

The test of genericity: what each runtime would register, and where it would break today.

| | Education (live) | Hospital (paper) | AutoMechanic (paper) |
|---|---|---|---|
| **Industry value** | SCHOOL (exists) | HOSPITAL | AUTO_WORKSHOP |
| **Module id** | EDUCATION_RUNTIME (kept for compatibility) | HOSPITAL_RUNTIME | WORKSHOP_RUNTIME |
| **Provisioned organisation** | School | Hospital or clinic | Workshop |
| **First administrator** | SCHOOL_ADMIN | the facility's administrator | the workshop manager |
| **Roles it declares** | SCHOOL_ADMIN, teacher, registrar, bursar | doctor, nurse, receptionist, pharmacist, billing clerk | service advisor, technician, parts clerk |
| **Chart template key** | school (tuition income, fee debtors) | hospital (patient-fee income, insurer receivables, drugs and consumables in stock) | workshop (labour and parts income, parts cost of sales, warranty) |
| **Owner summary** | fees owed by pupil and term, enrolment | patients seen today, unpaid insurer claims, drugs running low | jobs open, parts on order, vehicles waiting for payment |
| **What would break today** | nothing (it is the template) | the enum would need a third value in EA and WEB; the module enum a third literal; a third hard-wired port; the Owner Admin's default module rule; WEB's closed `Industry` type; SOP's env var for its credential | the same set again |
| **Data EA must NOT hold** | pupil records | **patient identifiers or health facts (special-category data)** | vehicle owners' details beyond the runtime's own database |

**Use cases** (EA's side):

| UC | Situation | Expected |
|---|---|---|
| UC-RUN-01 | The platform adds Hospital: a manifest and a registry entry are reviewed and released | EA lists the industry for new Companies; SOP, IM, POP, HR and GL are not changed or redeployed |
| UC-RUN-02 | An Owner registers a Company as HOSPITAL | EA validates the industry, GL builds the hospital chart, EA provisions the hospital's organisation, grants the Owner as its first administrator, activates, and `/me` shows the runtime link |
| UC-RUN-03 | The runtime's provisioning is down | the registration is refused with a plain retry-later answer, nothing half-registered, a retry completes it |
| UC-RUN-04 | A manager is invited to a hospital Company with the hospital module | allowed; the same invite for a trading Company is refused `module_not_allowed_for_industry` |
| UC-RUN-05 | A Company of an unknown industry value | refused plainly; nothing created |
| UC-RUN-06 | The Owner opens the home screen of a workshop Company | the generic tiles (cash, owed, owing, stock, people) show as for any business, plus the workshop's owner summary if its manifest names one |
| UC-RUN-07 | SOP gets a call from the hospital runtime's credential | SOP asks EA whether that runtime serves this Company; allowed only if it does |
| UC-RUN-08 | A Tenant owns a school and a workshop | each Company has its own industry, module set, chart and runtime link; the Owner sees both on one picker |

---

## 5. Recommended shape [proposed]

**The registry is a reviewed file, not a table (v1).** Each runtime is one JSON manifest in `fish-contracts/runtimes/` (so the contract repo is already the shared source), with a schema, an index and a golden example. EA loads and validates them at start-up (NFR-RUN-04). A new runtime is a reviewed change plus an EA release; no Tenant-facing admin surface exists (FR-RUN-13). A table with an operator screen can come later if the number of runtimes makes releases the bottleneck; that is a bigger attack surface and not needed for two or three runtimes.

**Module ids become data, keeping the compatibility spellings.** `ManagedModule` stays the generic six (plus PAYROLL when enabled); runtime modules are registered ids. EA's permission checks treat a module id as a string (as SOP, POP, IM and HR already do), so a new id needs no lockstep release.

**Onboarding keeps today's order.** WEB creates the Company in GL then registers it with EA (E11); EA stays the only place that knows industry types and returns, in one authenticated read (`GET /industries`), each industry's label, module set and chart template key. WEB passes the template key when it creates the Company in GL. This avoids making EA a saga that calls GL; it is the smallest change that makes the chart follow the industry. (Decision O2 below.)

**Provisioning is a port with one adapter per runtime.** The Education adapter is today's gateway, unchanged in behaviour. A new runtime supplies an adapter against the manifest's provisioning contract; the contract is the same two calls (create the organisation idempotently on the Company id; grant the first admin once).

**`/me` gains `runtimeLinks`, and `schoolId` is retired after an overlap.** This is the one lockstep change across the five strict mirrors; it is the largest coordination cost of the whole design and should be done once, ahead of the second runtime.

---

## 6. Tasks (T) and order (O)

Sizes are mine and unproven. "Behaviour-preserving" means Education works exactly as today, proved by the existing tests.

| # | Item | Owner | Size | Depends on |
|---|---|---|---|---|
| **Wave 0: decisions and paper work** | | | | |
| 0.1 | Femi's answers to section 8 | Femi, via CM | none | none |
| 0.2 | Paper dry runs written for Hospital and AutoMechanic against the manifest (no code), checking section 4's "what would break" list | EA, with ER, SOP, GL | 0.5 d | none |
| 0.3 | Manifest schema, example for Education, and the registry location in `fish-contracts` | EA, CM | 0.5 d | 0.1 |
| **Wave 1: behaviour-preserving generalisation (can ship before a second runtime exists)** | | | | |
| 1.1 | Load and validate manifests at start-up; Education is the first manifest | EA | 1 d | 0.3 |
| 1.2 | One generic rule replaces the four named-Education checks (`RuntimeCompanyLookup` replaces `SchoolCompanyLookup`); same refusal code; mutation-checked | EA | 1 d | 1.1 |
| 1.3 | Generic provisioning port with the Education adapter wrapping today's gateway | EA | 1.5 d | 1.1 |
| 1.4 | Industry type and module ids read from the registry; wire spellings SCHOOL and GENERIC unchanged | EA | 1.5 d | 1.1 |
| 1.5 | `GET /industries` (label, module set, chart template key) for WEB | EA | 0.5 d | 1.4 |
| **Wave 2: cross-service, needs the other sessions** | | | | |
| 2.1 | `runtimeLinks` on `/me`: GL, SOP, POP, IM, HR declare it first, then EA ships it, `schoolId` kept during overlap | all five, then EA | 0.5 d each + EA 1 d | 1.4 |
| 2.2 | EA answers "which runtime serves this Company" (service-only); SOP and GL read it instead of the env var | EA, SOP, GL | EA 1 d, SOP 0.5 d | 1.4 |
| 2.3 | Chart template key accepted at Company creation; unknown key falls back to the legal-form template | GL (their SPUTO), WEB | per GL | 1.5 |
| 2.4 | WEB reads industry list and vocabulary key from EA instead of the closed type and module inference | WEB | per WEB | 1.5, 2.1 |
| **Wave 3: when the second runtime is decided** | | | | |
| 3.1 | Role declaration mapped to platform capabilities (RBAC R12) | CM, EA | per RBAC | 1.1 |
| 3.2 | Owner-summary route in the manifest and the extended Owner view | EA, WEB, the runtime | 1 d EA | Owner Information tasks |
| 3.3 | The second runtime's adapter and manifest | the runtime's session, EA | per runtime | Wave 1 |

**What can ship before a second runtime exists:** all of Wave 1 (it changes no behaviour and removes the Education literals), and 2.2 (it removes an environment variable). Wave 2.1 and 2.3 to 2.4 are best done **once, ahead of the second runtime**, because they are lockstep changes across services. Wave 3 waits for a decision to build a second runtime. **Critical path:** 0.1, 0.3, 1.1 to 1.4, then 2.1.

---

## 7. Evidence detail

Files with Education-specific references in EA main code (counts from one search on 2026-10-18; a count is a pointer, not a measure of effort): `RegisterCompanyUseCase` (15), `Application.kt` (8), `repositories.kt` (7), `SchoolCompanyLookup` (6), `education_runtime_gateway.kt` (5), `ktor_education_runtime_gateway.kt` (4), `managed_module.kt` (4), `exposed_company_name_repository.kt` (4), `UpdateMembershipModulesUseCase` (2), `InviteStaffMemberUseCase` (2), and one in each of `MeRoutes`, `Dtos`, and the migrations V13, V15, V16. Other services: SOP (env var, 4 references in `Application.kt`), GL (3 in `managed_module.kt` and the `/me` mirror), IM, POP, HR (module string only in their `/me` mirrors), WEB (36 in `educationRuntime.ts` and many components).

---

## 8. Decisions asked of Femi

1. **O1, one industry per Company (recommended, immutable)** or allow a Company to be two things (a school with a clinic)? A Tenant already can own Companies of different industries; I recommend keeping one per Company and giving the second activity its own Company.
2. **O2, who tells GL the chart:** keep today's order (WEB creates the Company in GL, then registers it with EA) and have EA only publish each industry's chart template key (recommended, smallest change), or make EA the single orchestrator that creates the Company in GL itself (a bigger change and a new dependency from EA to GL)?
3. **O3, how a new runtime is registered:** a reviewed manifest file released with EA (recommended for two or three runtimes) or a table with an operator screen (more flexible, more surface)?
4. **O4, special-category data:** for a Hospital runtime (patient and health data) should it live in its own database and hosting boundary, with a separate consent and retention basis decided before any build? I recommend yes; it is your call and not a gate I set. EA's side is simple: it never holds such data.
5. **O5, build now or later:** Wave 1 changes no behaviour and removes the Education literals; do it ahead of a second runtime (my recommendation, since you have named two), or wait until a second runtime is formally decided?
6. **O6, module id spelling:** keep `EDUCATION_RUNTIME` as is for compatibility and name new ones `<NAME>_RUNTIME` (recommended)?

## 9. What I could not verify

- How many places in WEB hard-code the school type beyond the module inference; WEB's SPUTO is the authority.
- Whether any production Company already carries a `schoolId` that would need a one-off migration to `runtimeLinks` (the overlap rule covers it, but I did not look at data).
- The Education Runtime's own provisioning contract beyond what EA's gateway mirrors (ER's SPUTO is the authority).
- Whether GL's company creation can accept a template key without a schema change; GL's SPUTO decides.
- The effort figures; they are estimates from reading the code, not from a spike.
- Any legal or hosting requirement for health data (O4 is a question, not a finding).
