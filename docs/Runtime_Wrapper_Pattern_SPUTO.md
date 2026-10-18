# The runtime wrapper pattern (SPUTO): what a specialist runtime owns, what it consumes, and what it takes to build the next one

**Status:** 2026-10-18, planning only, docs only, nothing is built. SPUTO = Scope, Plan (requirements), Use cases, Tasks, Order. Written by the Education Runtime (+ER Education) session as its part of the programme Femi asked for: "Today it is Education Runtime, tomorrow it can be Hospital Runtime, or AutoMechanic Runtime etc." This is the centre of that exercise: the **wrapper** around the generic core. It builds on, and does not repeat, `Platform_Contract_Generic_Services_And_Runtimes_SPUTO.md` (EA, 2026-10-12), which covers the **contract layer** (fixtures, versioning, events, broker). The sibling parts (SOP, IM, POP, EA registration, GL charts, WEB vocabulary) are written by their own sessions; section 9 says where this document depends on them.

**How to read the evidence tags.** **[code]** I read it in the code on `fish-education-runtime` master or a named branch in this session. **[doc]** it is in a document by another session that I read but did not re-check in code. **[paper]** it is my reasoning about Hospital or AutoMechanic, which are paper runtimes: I have not spoken to a clinician or a mechanic, and every domain statement about them is an assumption to be checked with a person from that trade before anyone builds. Sizes are builder-days of one session, mine, unproven.

---

## 1. Scope (S)

**The idea.** FiSH is a **generic core** (GL, SOP, IM, POP, HR, EA) that every organisation needs, and **runtimes** that make the core fit one kind of organisation. The principle already decided: SOP, IM and POP are the heartbeat of any organisation; a runtime specialises **by data and wrappers, never by duplicating a generic service**. A school raises its tuition invoice **in SOP**, sells "Tuition" as an **IM service item**, buys through **POP**, and keeps only what is a school's own: admissions, students, classes, marks, attendance. Prodeo is a landlord with no role in a Tenant's data.

**In scope here:**
1. What a runtime **owns** and what it **consumes** (the ownership line).
2. The **rules every wrapper obeys**, taken from what the Education Runtime had to learn the hard way.
3. The **minimum a new runtime must build**, as a checklist.
4. **Education as the worked example**, concern by concern, with file evidence.
5. What **Hospital** and **AutoMechanic** would build and reuse (paper).
6. Which pieces of the Education Runtime code to **lift into reusable runtime scaffolding**, and when.

**Out of scope (other parts or later):** the contract layer and the broker (EA's platform contract); runtime registration, the manifest and Tenant onboarding (EA's part); industry charts and posting rules (GL's part); vocabulary and navigation (WEB's part); the internals of SOP, IM and POP (their parts); any build for Hospital or AutoMechanic; any change to production.

**Definitions.** A **runtime** is a service that owns one industry's domain and talks to the generic services. A **site** is the one organisation a runtime serves at a time (Education: a school; Hospital: a hospital or clinic; AutoMechanic: a workshop). Each site is one EA **Company**, inside an EA **Tenant**, and a Tenant's Business Owner owns the data. A **wrapper** is everything a runtime adds around the generic services: its domain, roles, vocabulary, workflows, mappings, integrations and screens' rules.

---

## 2. What is true today (evidence, mostly Education)

**2.1 Education already follows the pattern in spirit, and broke it in four places that have since been corrected or are being.** [code] [doc]
- It kept its **own invoice and payment model** beside SOP (a second source of money). The revision of 2026-10-12 and the 2026-10-18 work correct this: ER's old invoice route now refuses (`fee_invoices_go_through_sales`), and a fee invoice becomes one credit sale in SOP (step C, built, off by default, held until IM and SOP are ready).
- It first tried to hold the **VAT category** on its own fee item. Femi ruled it belongs in IM ("If there is a VAT Category, then it must be persisted in IM"); a fee item now carries only a link (`imItemId`) to an IM service item.
- It had **no route** to create a class section, so a real school could not set one up (found 2026-10-18; routes built, queued). A wrapper that owns a domain must give that domain a way to be created.
- Several write routes took **pipe-delimited text** with no guardian and no stable error codes; they are moving to strict JSON.

**2.2 The Education Runtime's size and shape.** [code] About 1,800 lines of cross-cutting code (counted in the files named in section 6, without `Application.kt`), inside a service whose `Application.kt` alone is about 1,480 lines and mixes kit routes with Education routes; roughly 645 unit tests and 200 real-Postgres tests as of 2026-10-18; Flyway migrations V1 to V39 (V40 reserved for step C). Three layers: `domain` (pure types and rules), `application` (services and store interfaces, with an in-memory twin for each store), `infrastructure` (Ktor routes, Exposed stores, Cognito, HTTP clients).

**2.3 Where the Education Runtime assumes Education (not runtime-neutral).** [code] unless tagged.
| What | Where | Why it matters for a second runtime |
|---|---|---|
| The tenancy noun is `School`: `SchoolId`, `School(id, organisationId, tenantId, name)`, every route is `/schools/{schoolId}/...` | `domain/platform/School.kt`, `SchoolId.kt`, `infrastructure/web/Application.kt` | the kit's identity, registry and route-guard code is generic in shape but spelled for schools |
| The role list is closed and education-named: `SCHOOL_ADMIN, HEAD_TEACHER, HOD, HOY, TEACHER, REGISTRAR, ADMISSIONS_OFFICER, TIMETABLER, FEE_OFFICER, BURSAR, SAFEGUARDING_LEAD, PASTORAL_LEAD` | `application/StaffManagementService.kt` (`ASSIGNABLE_ROLES`) | the closed-list-per-site mechanism is reusable; the list is data |
| Capabilities are `ErPrincipal` predicates with education meaning; `GET /schools/{id}/me` exposes them as codes (`ErCapability`) | `domain/platform/ErPrincipal.kt`, `ErCapability.kt`, `infrastructure/web/SchoolMeRoute.kt` | a good pattern (the server tells the screen what the caller may do); the codes are education's |
| Service-account audiences are named after the callers: `dpid`, `ea-provisioning` | `domain/platform/ErIdentityGateway.kt`, `infrastructure/web/Auth.kt` (`buildJwksServiceVerifierForDpid`, `...ForEa`) | each new integration is a new function and env var, not data |
| The per-site switch for an integration is a closed enum with one value: `SchoolIntegration { DPID }` | `domain/platform/SchoolIntegration.kt` | the idea (a deliberate per-site opt-in with who and when) is general; the list is code |
| Environment variables and database name carry the old product name: `SCHOOLADMISSIONS_*` (about 30 uses), database `schooladmissions_production` | `infrastructure/persistence/DatabaseConfig.kt`, `AppFactory.kt`, the downtime backlog | cosmetic for Education, but a runtime kit must not bake a product name into its configuration keys |
| Defaults that are a country or an industry: a fee item's currency defaults to `NGN` | `application/FeeService.kt` (`defineScheduleItem`) | a default currency belongs to the site's jurisdiction (EA/GL), not the runtime |
| SOP opens its routes to the Education credential with Education-only code: an allow-list of Companies, a rule that the credential may sell **services only** (no `itemId` of a goods item) | SOP `Auth.kt` (`serviceMayCall`, `SopServiceCompanyIdsKey`), the S1 branch [doc] | for AutoMechanic and a hospital pharmacy the credential **must** be allowed to sell stock; this rule must become a **declaration per runtime**, not a code branch (T5, section 7) |
| EA: `IndustryType` is a closed enum with a `SCHOOL` branch; `/me` carries a school-specific field | [doc] platform contract SPUTO section 2.4 and 2.5 (I did not re-read EA's code) | EA's registration part owns this; listed so the wrapper pattern can say what it needs from it |

**2.4 What the Education Runtime has that a second runtime would copy line for line.** [code] Section 6 lists them with sizes. In short: the web plumbing (request ids, JSON logs, `Cache-Control: no-store`, CORS, error bodies with stable codes, strict JSON in), the two-step identity (prove who, then resolve roles at this site), the site registry provisioned idempotently by EA, the first-admin grant, per-site staff assignments with a closed role list, the capability list behind `GET /{site}/me`, the claim-first idempotency ledger, the tenant-isolation guard on every store, the log-first enforcement flag, the service-account token provider and strict outbound clients, and the contract-fixture test harness.

---

## 3. Requirements (P)

Numbered `RW-n`. **G** = generic (the kit or the core supplies it, identical in every runtime). **R** = runtime-specific (each runtime writes its own). A requirement is only here if Education already meets it in code [code] or has met it and been corrected [code], so none is speculative.

### 3.1 The ownership line

| # | Requirement | G/R |
|---|---|---|
| RW-1 | **A runtime owns its domain and nothing else.** Its aggregates, their lifecycles and their identifiers (admissions, students, classes, marks; patients, encounters; vehicles, job cards) live in the runtime's own database. | R |
| RW-2 | **A runtime never holds money, stock, tax, payroll or the ledger.** Money is a SOP sale, collection or credit note; stock and services are IM items; purchases are POP; the ledger is GL; staff employment and pay are HR; identity, Tenant, Company and module are EA. The runtime keeps only a **thin mapping** from its own id to the generic id (a student to a SOP customer and sale), never a copy of an amount or a status that SOP can answer. | G |
| RW-3 | **A runtime never posts to the ledger.** Enforced in code in Education (`NoDirectGlWrites`) [code]; a runtime has no GL client and no GL credential. Financial effect reaches GL only through SOP, IM or POP. | G |
| RW-4 | **The category of anything the generic core decides belongs to the core.** The VAT category lives in IM; the account for a transaction type comes from the Company's chart (Suspense when none); a currency comes from the site's jurisdiction. A runtime never types, defaults or caches these. | G |
| RW-5 | **A runtime owns its vocabulary, roles and workflow rules** (what it calls a thing, who may do what inside it, the states its records move through), and exposes them as data and codes the one shared front end can draw: a role list, a capability list, and words (WEB's vocabulary part). | R |
| RW-6 | **A runtime owns its external integrations** (Education: an attendance reader; Hospital: a lab system; AutoMechanic: a diagnostics reader), each a per-site opt-in with who switched it on and when, and a service-account audience that can do only that integration's few actions. | R (mechanism G) |

### 3.2 Identity and access

| # | Requirement | G/R |
|---|---|---|
| RW-7 | **Two-step identity:** (1) prove who is calling from the bearer alone (401 if not valid); (2) resolve what that subject holds at **this** site from the runtime's own assignment table (403 `cross-tenant` if nothing). Never trust a caller-supplied site id as proof of affiliation. [code: `ErIdentityGateway`, `CognitoErIdentityGateway`, `RouteAuth.requireSchoolAccess`] | G |
| RW-8 | **Roles per site, from a closed list the runtime declares**, held in the runtime's own assignment table (one row per person and site), not in EA. Only an admin grants admin; the last admin cannot be removed; an unknown role is refused with the allowed list. [code: `StaffManagementService`] | G (list is R) |
| RW-9 | **Capabilities are computed on the server and shown to the screen**: `GET /{site}/me` returns the caller's roles and capability codes, each code being exactly one predicate the routes themselves enforce, with a reflection test that fails when a predicate is added without being exposed or left out on purpose. [code: `ErCapability`, `SchoolMeRoute`, `SchoolMeRouteTest`] | G (codes R) |
| RW-10 | **A service-account caller has its own audience and a short list of routes**; it never passes for a person. [code: `serviceAccountAudience`, `requireServiceAccount`] | G |
| RW-11 | **Module-to-module calls bypass the EA membership check by design**; a person's calls do not (the platform decision of 2026-09). The runtime resolves the person's rights itself (RW-7, RW-8). | G |
| RW-12 | **External users (a guardian, a patient, a vehicle owner) are principals with a narrow scope**, resolved against the runtime's own records (a guardian sees only a linked child), never given staff routes. [code: `GUARDIAN`/`PARENT`, `isGuardianOnly`, the parent gateway] | R |
| RW-13 | **No Prodeo operator route reaches a site's data**, and no message sends a site to "support" for its own data: recovery is the site's own administrator or an identical retry. (Landlord principle, Decisions_Log 2026-10-15.) | G |

### 3.3 Provisioning and the site

| # | Requirement | G/R |
|---|---|---|
| RW-14 | **A site is provisioned by EA, idempotently on the organisation id**, and a first admin (the Business Owner's email) is granted the same way, tolerating a repeat. EA never replaces an existing different first admin. [code: `SchoolRegistryStore.provision`, `PUT /schools/{id}/first-admin`] | G |
| RW-15 | **A runtime refuses to act for a Company EA has not provisioned as its kind of site**, and EA refuses to grant the module to any other kind of Company. (Decisions 2026-10-13: "Only schools get an Education Runtime".) | G |

### 3.4 Data, writes and retries

| # | Requirement | G/R |
|---|---|---|
| RW-16 | **Every write is safe to repeat.** Creates are idempotent on the site's own reference (the same request returns the same record; the same reference with different details is a conflict that names the existing record and changes nothing). A request that raises money carries an **operation id** made once per click; the runtime claims its rows first, calls out under `Idempotency-Key: <RUNTIME>-<thing>-<opId>`, and on a definite refusal releases the claim while on an ambiguous failure keeps it. [code: `StudentCreation`, `FeeInvoicingService`, `SyncPushLedger`] | G |
| RW-17 | **Every table is tenant-keyed and every lookup is guarded** so an id from another site answers as missing. [code: `TenantIdGuard`] | G |
| RW-18 | **Concurrent edits are detected, not overwritten** (a version compare-and-swap), and history that matters is append-only. [code: student version CAS, mark history triggers] | G |
| RW-19 | **Bodies are strict JSON with stable error codes**: an unknown key is `invalid_json`; each refusal has a machine code and a plain sentence; no response leaks an exception message. [code: `receiveJson`, `DomainRefusal`, `HttpErrorMapping`, `installErrorHandling`] | G |
| RW-20 | **A new restriction is shipped log-first**: the check runs, a would-refuse line is logged at most once per interval, behaviour is unchanged until the flag is flipped; a typo in the flag stops the service at start-up. [code: `EnforcementMode`, `RateLimitedWarner`] | G |
| RW-21 | **Responses an authenticated person receives are never cached** (`Cache-Control: no-store, private`) and every request has a request id in the logs, without bodies, headers or e-mail addresses. [code: `NoStoreCacheControl`, `RequestLogging`] | G |

### 3.5 Calling the generic core

| # | Requirement | G/R |
|---|---|---|
| RW-22 | **Outbound clients decode strictly what they read before a side effect, and report ambiguity loudly after one**: a 2xx whose body cannot be read is retried once on the same key and then surfaced as a 502 while the claim is kept. Every client has timeouts. [code: `KtorSopCustomerGateway`, `KtorSopSaleGateway`] | G |
| RW-23 | **Every response a runtime consumes, and every response it provides to another service, has a contract fixture** and is decoded through the real client in CI. (The platform contract SPUTO's R3; ER's fixtures exist for its provisioning routes and for SOP's customer answers.) | G |
| RW-24 | **A runtime declares what its service credential may do at each generic service as data**: which routes, which Companies (the sites EA says are its kind), and **which line kinds** it may sell or buy (services only; services and stock). Today this is code in SOP for Education alone (section 2.3). | G (declaration R) |
| RW-25 | **A runtime depends on a generic capability only through a narrow port** it owns (a `SopSaleGateway`, not SOP's DTOs scattered through the domain), so the generic service can change additively without the runtime's domain code changing. [code: `SopCustomerGateway`, `SopSaleGateway`] | G |

**Not required (RW-n/a):** a runtime for any industry nobody has decided to build; a message broker; a shared database; a shared UI codebase beyond the one front end.

---

## 4. Education as the worked example

For each concern: what the Education Runtime owns or consumes today, and the file it lives in. [code] unless tagged.

| Concern | Education's answer | Where |
|---|---|---|
| **Domain it owns** | admissions pipeline (Submitted, Under review, Offered, Accepted or Declined, Enrolled); students (bio-data, guardians, class, effective-dated history); class sections; timetable and rooms; curriculum; attendance; assessment set-up, subject offerings, marks (versioned, append-only history); guardian billing accounts (a thin link) | `domain/admissions`, `student`, `classroom`, `attendance`, `assessment`, `curriculum`, `billing` |
| **Roles and capabilities** | 12 staff roles plus guardian roles and a device account; capabilities = `ErPrincipal` predicates exposed as codes | `ErPrincipal.kt`, `ErCapability.kt`, `StaffManagementService.kt` |
| **Identity** | Cognito JWT verified by JWKS; roles per school from `StaffAssignment`; guardians matched by e-mail on their account; EA's provisioning and the DPID reader as service audiences | `CognitoErIdentityGateway.kt`, `Auth.kt` |
| **Site and provisioning** | `School` row created by EA (`POST /schools`, idempotent on `organisationId`); first admin `PUT /schools/{id}/first-admin`; per-school integration switch | `School.kt`, `FirstAdminService.kt`, `SchoolIntegrationStore.kt` |
| **Money, by consuming SOP** | a guardian is a SOP **customer** (`ER-guardian-{id}`); a term's tuition is **one credit sale** in SOP, one line per fee item, each line naming its IM service item and carrying **no category**; ER keeps a thin row per line (the ER invoice id, the student, the SOP sale id and number, SOP's gross). Built, **off by default**, held until IM service items and SOP's service-line change are live | `GuardianBillingService.kt`, `FeeInvoicingService.kt`, `KtorSopSaleGateway.kt` |
| **Catalogue, by consuming IM** | "Tuition", "Boarding", "Exam fee" are IM **service items** with the VAT category in IM; an ER fee item is the price-list entry plus the IM item id | `FeeModels.kt` (`imItemId`), plan `ER_Fee_Invoice_Through_SOP_Plan_2026-10-18.md` |
| **Purchases and stores, by consuming POP and IM** | none in ER; a school's supplies are the generic POP and IM, shown under school words | (no ER code, by design) |
| **People and pay, by consuming HR and EA** | teachers are employed once in HR; ER keeps only a teaching record; never calls HR | Playbook parts 1 to 4 [doc] |
| **Words** | a vocabulary map (Enrolment, Purchasing, Stores, Accounts, Surplus, Income and Expenditure, Fees owed, Guardians, Staff members) supplied by ER and drawn by WEB | `School_Vocabulary_For_WEB.md` [doc] |
| **Integrations** | an attendance reader (DPID), a per-school switch, a narrow audience | `SchoolIntegration.kt`, `buildJwksServiceVerifierForDpid` |
| **Enforcement** | schools-row and DPID-binding checks live in log mode first | `EnforcementMode.kt`, `CognitoErIdentityGateway.kt` |

**Lessons the example teaches (each is a rule above):** build the way to *create* every owned thing (class sections); never keep a second copy of what the core answers (invoices, VAT category); idempotency and strict bodies from the first route, not retrofitted; a 2xx you cannot read is not a failure; name nothing after the first industry in configuration (env prefix, database name, route noun) unless it is cheap to change later.

---

## 5. The minimum a new runtime must build, and what the paper runtimes would build and reuse

### 5.1 The minimum (the "hello runtime" checklist)

A new runtime that can onboard one site, authenticate people, hold one owned aggregate and raise one charge through SOP needs exactly these. Items marked **kit** are what section 6 proposes to lift so that a second runtime does not rewrite them.

1. **Service skeleton** (Ktor, Exposed, Flyway, `/health`, JSON logs with a request id, `no-store`, CORS, strict JSON in, coded errors out). *kit*
2. **Identity**: verify the JWT, resolve roles at the site from the runtime's own assignment table, accept the named service audiences. *kit*
3. **Site registry and first admin**, provisioned by EA, idempotent on the organisation id, with the EA industry flag as the definition of "this Company is my kind of site". *kit* plus EA's registration part
4. **A closed role list and a capability list** (data), with `GET /{site}/me` and the reflection test. *kit*
5. **The owned domain**: aggregates, their state machines and stores (an in-memory twin for each store so tests run without a database). *runtime-specific*
6. **An idempotent create** for every owned thing a person must be able to add, with the same-reference-different-details conflict. *kit* (the pattern) plus *runtime-specific* (the fields)
7. **A thin mapping to the generic core** for each charge: its own id, the SOP customer and sale ids. *runtime-specific*, on the claim-first invoicing template. *kit*
8. **Strict outbound clients** to SOP (customer, sale, collection), IM (read the catalogue through WEB, not through the runtime) and POP if it buys, with the service-account token provider. *kit*
9. **A declaration of the runtime's credential** at each generic service (routes, sites, line kinds), as data EA holds (RW-24). *EA/SOP*, the runtime supplies the content
10. **Contract fixtures** both ways. *kit* (the harness)
11. **A vocabulary pack and a role-to-capability map** for WEB. *runtime-specific*
12. **Infrastructure by CM** (a task definition, a database, a load balancer rule, a Jenkins job, Terraform): outside this document.

**Estimate (mine, unproven).** With the kit lifted and a clean EA manifest, a "hello runtime" for a new industry is about **8 to 10 builder-days** (items 5, 6, 7, 9, 11 are the real work). Without the kit, items 1 to 4, 8 and 10 are a re-write of about 2,000 lines of tested code, about **20 to 25 days** and a second place for every bug to be fixed twice. The Education Runtime itself was built incrementally over weeks, with rework; this is not a record of how long it took.

### 5.2 Hospital Runtime (paper)

**Owns [paper]:** patients (identifiers, demographics, allergies, consent), visits or encounters (open, in treatment, discharged), clinical notes (restricted), orders (lab, imaging), prescriptions, wards and beds, appointments, insurer or scheme membership. **Roles:** DOCTOR, NURSE, PHARMACIST, LAB_TECHNICIAN, FRONT_DESK, BILLING_CLERK, MEDICAL_RECORDS, plus a patient as an external principal with a narrow scope.
**Consumes:** SOP for the bill (consultations and procedures are **IM service items**, many of them VAT-exempt or zero-rated in some jurisdictions; the VAT category stays in IM per period and jurisdiction), cash patients and credit patients, **third-party payers** (an insurer or scheme pays a share of one invoice; SOP's third-party-payment design is Femi-approved but not built [doc]); IM for **drugs and consumables as stock** (IM's item model already has batch tracking, `isBatchTracked` and `batchesOnHand` [code, read in IM's item response]; expiry dates I did not verify; issue to an encounter through the goods-issue route); POP for what the hospital buys; GL for a chart with patient-fee income, insurer receivables and drugs cost of sales (GL's part); HR for staff.
**Reuses from the kit:** all of RW-7 to RW-25 unchanged.
**Builds new:** the encounter-to-invoice step (at discharge, one SOP sale with service lines plus stock-issuing drug lines); the insurer claim lifecycle on the runtime's side (submitted, adjudicated, remitted, rejected, which becomes a credit note or a payer split in SOP); a **special-category data** class (health data) with consent, access logging on reads, and no marketing or analytics use, which is stricter than a school's student data and needs its own decisions before any build; a documents port for results and a notifications port (neither exists as a generic service yet [doc]).
**What this stresses in today's core [paper]:** SOP's `Customer` assumes a sales-order customer and trade-finance fields (platform contract SPUTO 2.5 (7)); a patient who is also a guarantor, and a payer split on one invoice, need SOP's third-party payments; the Education credential rule (services only) must be lifted (RW-24) because a pharmacy line issues stock.

### 5.3 AutoMechanic Runtime (paper)

**Owns [paper]:** the customer's **vehicles** (registration, make, model, VIN, mileage), **job cards** (estimate, approved, in progress, waiting for parts, ready, invoiced, collected), inspection checklists, technician time, warranty terms, appointments. **Roles:** SERVICE_ADVISOR, MECHANIC, PARTS_CLERK, CASHIER, WORKSHOP_MANAGER; a vehicle owner as an optional external principal.
**Consumes:** SOP for the job's invoice (labour is an IM **service item**, parts are IM **stock** lines that issue stock on sale, which is SOP's native goods-line path), deposits and part payments, credit notes for warranty and goodwill; IM for the parts catalogue, reorder points and valuation; POP for parts bought from suppliers and a supplier's warranty claim (a debit note); GL for a chart with labour income, parts sales and parts cost of sales; HR for technicians' pay.
**Reuses from the kit:** all of RW-7 to RW-25.
**Builds new:** the job card and its estimate-to-invoice step (SOP has sales orders [doc]; whether an estimate is a SOP quotation or the runtime's own record is an open question for SOP's part); a vehicle reference printed on the invoice (SOP's customer reference is print-only text, adequate); technician time to labour lines (rates are IM service items).
**What this stresses [paper]:** one invoice mixing service and stock lines (so the credential declaration must allow both); a parts availability check before approving an estimate (SOP's goods line reads IM availability); warranty as a no-charge or credited line and as a supplier debit note across SOP and POP.

### 5.4 What the three share, and what is genuinely different

Shared, identical: everything in section 3 marked G. Different: the aggregates (admission and class; encounter and drug; vehicle and job card), the state machines, the roles, the vocabulary, the integrations, the **data-protection class** (children's data; health data; vehicle-owner data), the **charge shape** (a term's fees for many lines raised in bulk; an encounter at discharge; a job card at completion) and the **third party** (a sponsor; an insurer; a warranty provider). The charge shape is the most reusable runtime-specific piece: all three are "gather owned records into one SOP sale", which is why the claim-first invoicing service is the best template to lift (section 6, item 7).

---

## 6. What to lift out of the Education Runtime code into reusable scaffolding

Lines are from `wc -l` on master, 2026-10-18. **Lift = move into a runtime-neutral package with no import of an education package, tested by an architecture test; the Education Runtime then depends on it.**

| # | Piece | Files (lines) | What changes when lifted |
|---|---|---|---|
| 1 | **Web plumbing** | `RequestLogging.kt` (96), `NoStoreCacheControl.kt` (21), `HttpErrorMapping.kt` (39), `installErrorHandling` and `installCors` in `Application.kt`, `DomainRefusal.kt` (17), the strict `receiveJson` helper | none beyond package; CORS env var name becomes a parameter |
| 2 | **Identity** | `ErIdentityGateway.kt` (58), `CognitoErIdentityGateway.kt` (141), `StubErIdentityGateway.kt` (61), `Auth.kt` JWKS verifiers (139), `RouteAuth.kt` (75), `normalizeSubjectId` | rename the site noun; the service audiences become a list from configuration instead of one function each |
| 3 | **Site registry, first admin, integration switch** | `School.kt` (34), `SchoolRegistryStore.kt` (41), `FirstAdminService.kt` (50), `SchoolIntegration*.kt` (48) | `School` becomes `Site`; the integration list becomes data; Education keeps `/schools` routes as an alias |
| 4 | **Staff assignments and the closed role list** | `StaffAssignment.kt`, `StaffManagementService.kt` | the role list is injected |
| 5 | **Capabilities and `/me`** | `ErCapability.kt` (27), `SchoolMeRoute.kt`, the reflection test | the capability set is declared per runtime |
| 6 | **Persistence kit** | `TenantIdGuard.kt` (95), `UniqueViolations`, `DatabaseBootstrap.kt` (42), `DatabaseConfig.kt` (37), `SyncPushLedger.kt` and `ExposedSyncPushLedger.kt` (the Exposed one is 91) | env prefix becomes a parameter; migration numbering stays per runtime |
| 7 | **Outbound kit and the claim-first charge template** | `CognitoServiceAccountTokenProvider.kt` (112), `KtorSopCustomerGateway.kt` (109), `KtorSopSaleGateway.kt`, `FeeInvoicingService.kt` | one `SopClient` (customer, sale, collection) with typed results; `FeeInvoicingService` generalised to a **charge run** over "owned records to SOP lines" |
| 8 | **Flags** | `EnforcementMode.kt` (38) with `RateLimitedWarner` | none |
| 9 | **Test kit** | the contract-fixture reader, the stub-token helper, the `testApplication` pattern, the real-Postgres concurrency helpers | extracted as test fixtures |
| — | **Stays in Education** | admissions, students, classes, timetable, curriculum, attendance, assessment, the parent gateway, the DPID integration, fee schedule semantics, guardian accounts | by definition |

**Where it lives, and when.** Three options: (A) a packaged boundary inside the Education repo (`...runtimekit.*`) enforced by an architecture test; (B) a new source repository consumed like `fish-common` (no published artifact); (C) copy into the second runtime and converge later. **Recommendation: A now, B only when a second runtime is decided, never C.** Reason: while only Education exists, a separate repo adds release coordination (CM pushes and deploys everything) for no second user, and C produces two drifting copies, the exact failure the contract layer exists to prevent. A is cheap (about 1.5 days, no behaviour change, one architecture test) and makes B a move, not a rewrite. This also respects Femi's 2026-10-07 answer that nothing is planned for Clinical or Banking: build only what is proven necessary, and A is proven necessary by Education's own continued growth.

---

## 7. Use cases (U), in plain words

| ID | Runtime | Situation | Expected |
|---|---|---|---|
| UC-W1 | any | The platform operator registers a new kind of site | EA records the runtime (its module, roles, credential declaration) as data; no change to SOP, GL or EA code (EA's part; the wrapper's side is the declaration, RW-24) |
| UC-W2 | any | A Business Owner registers a Company of that kind | EA provisions the site in the runtime, idempotently, and grants the Owner the first admin; a repeat changes nothing |
| UC-W3 | any | The site admin appoints staff | roles come from the runtime's closed list; only an admin makes an admin; the screen then shows exactly what each person may do from `GET /{site}/me` |
| UC-W4 | Education | The bursar bills a term | one SOP sale, one line per fee item, each naming its IM item; a repeat of the same click posts once; if SOP is down the claim waits and the same click converges |
| UC-W5 | Hospital [paper] | A patient is discharged | one SOP sale: consultation and procedure lines (IM services) plus drug lines (IM stock, issued to the encounter); the insurer's share is a third-party payment on the same invoice; a repeat posts once |
| UC-W6 | AutoMechanic [paper] | A job card is completed | one SOP sale: labour lines (IM services) plus parts lines (IM stock, issued); a warranty job is a credited or no-charge line; a repeat posts once |
| UC-W7 | any | A person adds an owned record twice (a lost reply, a double click) | the same record is returned; the same reference with different details is refused and names the existing one |
| UC-W8 | any | A person from another site, or another Tenant, asks for a record by id | it answers exactly as a missing one |
| UC-W9 | any | A new restriction is introduced | it runs log-first for a normal day, then the flag is flipped by CM |
| UC-W10 | any | A developer builds a new runtime offline | the fixtures decode through the real clients; the generic services need not run |
| UC-W11 | any | A site's data has a problem | the site's own administrator fixes or retries; no operator route and no "contact support" sentence exists for it |
| UC-W12 | Hospital, AutoMechanic [paper] | A runtime needs to sell stock through SOP, which Education's credential may not | the runtime's declared credential allows goods lines; Education's does not; no code change in SOP |

---

## 8. Tasks (T) and order (O)

All docs-or-ER-only except where an owner is named. Sizes are mine and unproven. "Gate" = a decision or another session first.

| Task | Owner | What | Size | Gate |
|---|---|---|---|---|
| T1 | ER, CM | review this document against the SOP, IM, POP, EA, GL and WEB parts; reconcile the credential declaration (RW-24), the manifest content (section 9) and the vocabulary pack; list conflicts for Femi | 0.5 d | the other parts exist |
| T2 | ER | **Draw the boundary now**: move the section 6 pieces into `runtimekit` packages with no behaviour change, and add an architecture test that kit code imports nothing from the education packages | 1.5 d | none (safe, mechanical); CM reviews the PR |
| T3 | ER | **Role and capability declaration as data**: a single object per runtime listing roles, capability codes and the role-to-capability map; the closed-list check and `/me` read from it | 1 d | T2 |
| T4 | ER | **Noun-agnostic names in the kit**: `Site` in the kit, `School` kept as Education's alias and `/schools` routes unchanged; configuration keys take a prefix parameter (the env var rename itself is a CM downtime item, not done here) | 1 d | T2 |
| T5 | SOP, EA, ER | **Credential declaration as data**: which routes, sites and line kinds a runtime's credential may use, held with the runtime registration, replacing the Education-only code in SOP (services only for Education, goods allowed for others) | SOP 1.5 d, EA design in its part | EA's manifest design |
| T6 | ER, SOP | **One `SopClient`** (customer, sale, collection) with typed results and the retry rule, used by the Education gateways | 1.5 d | SOP's collection route shape |
| T7 | ER | **Generalise the claim-first invoicing service to a "charge run"** (owned records in, SOP lines out, frozen claim rows, definite versus ambiguous failure) and keep Education's fee run as its first user | 2 d | the Education fee path live (IM and SOP ready) so the template is proven, not guessed |
| T8 | ER | **Test kit**: fixtures reader, stub tokens and the real-Postgres concurrency helper as shared test fixtures | 1 d | T2 |
| T9 | ER, Femi | **Domain check with one person from each trade**: a clinician and a mechanic read sections 5.2 and 5.3 and correct them (paper becomes checked) | 1 d of their time | Femi chooses the people |
| T10 | CM, ER | **Extract the kit to a source repository** consumed like `fish-common` | 2 d plus CM infra | a second runtime is decided |
| T11 | ER | **Paper dry run of "hello Hospital" against the kit**, listing which kit pieces bite (the platform contract SPUTO's B1 for a clinical case) | 1 d | T2 to T4 |

**Order (O).**
1. **T1** and **T9** (reading and checking, no code).
2. **T2** then **T3** and **T4** in either order, all inside the Education repo with CM's review, shipping with no behaviour change. These can ship **before a second runtime exists** and are justified by Education alone: the next Education features (the single-student and guardian routes, the fee run, report cards) get cheaper and safer to write.
3. **T5** with EA's registration part and SOP, and **T6** with SOP's collection route; both are needed by Education anyway for the payment step.
4. **T7** only after the Education fee path is live, so the template is extracted from working code.
5. **T8** alongside.
6. **T11**, then **T10 only if** Femi decides a second runtime. If he does not, T10 never happens and nothing is lost.

**What can ship before a second runtime exists:** T2, T3, T4, T8 and (after the fee path is live) T7. **What must wait for a decision:** T10, any Hospital or AutoMechanic code, and any change that is only useful to a runtime nobody has approved.

**Rollout and rollback.** Each task is its own branch, tests first, handed to CM (only CM pushes, merges and deploys). T2 to T4 and T8 move code without changing behaviour, so rollback is redeploying the previous image. T5 is consumer-first at SOP: the declaration is added, Education's behaviour is kept identical (services only), and only then is the old code branch removed.

**Risks.** (1) The kit becomes speculative generality: mitigated by lifting only code that already exists and works. (2) The noun change (`School` to `Site`) touches many files: mitigated by keeping Education's names as aliases and doing it behind an architecture test. (3) A hospital's data-protection needs are materially stricter and could force design changes in the kit (access logging on reads, consent): T9 and T11 are there to find that early. (4) Sizes are estimates.

---

## 9. Dependencies on the other parts, and what I did not verify

**Needed from the sibling parts (not read; not yet written or not read by me when this was written).**
- **EA registration and onboarding:** the **runtime manifest** must carry, from the wrapper's side: a module id (a string); the role list and the role-to-capability map (RW-8, RW-9); the provisioning route and its idempotency key; the service audiences and, per audience, the routes, the sites and the **line kinds** (RW-24); the default chart template and vocabulary pack identifiers; and the rule "runtime enabled for this Company", derived from the industry type. EA's platform contract SPUTO Layer B and its RBAC capability mapping (R12) are the baseline. **Not cross-checked against EA's new document.**
- **SOP:** the third-party payment design (insurer, sponsor), the shape of the customer for non-sales-order parties, the service-line path for a service item and the credential declaration (T5).
- **IM:** the catalogue read for pickers, VAT category by period and jurisdiction, batch and expiry for drugs.
- **POP:** purchasing for supplies, drugs and parts, supplier warranty as a debit note.
- **GL:** the chart templates and the posting for each charge shape.
- **WEB:** the vocabulary pack contract and how one front end serves several runtimes.

**What I verified in code this session:** the ER file list, sizes, roles, capability and identity design, the idempotent-create and claim-first services, the SOP gateways and their tests, the environment-variable and database naming, the fee-item default currency, and the SOP credential mechanism (read in SOP `Auth.kt`).

**What I did not verify:** EA's `IndustryType` enum and `/me` shape (taken from the platform contract SPUTO); SOP's S1 and service-line branches beyond the summaries SOP sent (not released); anything in IM's service-item work beyond its read shape; whether Hospital or AutoMechanic domain statements are right (paper); the cost of extraction to a separate repository; the line counts exclude tests.

---

## 10. Decisions asked of Femi (plain words, with my recommendation)

1. **Do we draw the runtime-kit boundary inside the Education code now (about 1.5 days, no behaviour change), and wait before making it a separate repository?** Recommendation: **yes to the boundary now, no to the repository until a second runtime is approved.** It costs little, helps Education's own next features, and keeps every option open.
2. **Is a runtime's permission at a generic service a thing EA holds as data (which routes, which Companies, and which kinds of line it may sell), not code in SOP?** Today SOP has Education's rule in code (services only). Recommendation: **yes**, because AutoMechanic and a hospital pharmacy must sell stock and Education must not.
3. **Who owns the kit?** Recommendation: the Education Runtime session builds and maintains it, CM reviews every change, and the other runtimes depend on it, until a second runtime has its own owner.
4. **Do we ask one clinician and one mechanic to read the paper sections before anyone relies on them?** Recommendation: **yes, one conversation each**; the Hospital sketch especially touches health data, which carries rules a school does not.
5. **Naming:** new runtimes use their own noun for the site (hospital, workshop) in routes; the kit stays noun-neutral; Education keeps `/schools`. Recommendation: **agree**, and treat the `SCHOOLADMISSIONS_*` variables and database name as an Education-only legacy cleanup in the downtime window, not a kit concern.
6. **Health data:** if a Hospital Runtime is ever approved, should it be a separate security review first (consent, access logging on reads, residency)? Recommendation: **yes, before design, not after**, because it changes the kit's identity and logging parts.
