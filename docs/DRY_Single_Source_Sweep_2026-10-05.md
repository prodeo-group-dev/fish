# DRY / single-sources-of-truth sweep (2026-10-05)

**Requested by Femi:** "when you are idle, do a code sweep for code reuse possibilities... this should create single sources of truth." Done by CM as three read-only sweeps (backend services, infrastructure and CI, WEB frontend). Every count below was measured, not estimated. Nothing was changed by the sweep.

**How to read this.** Each finding names the ONE owner the duplicated thing should become, how everyone else reads it, and what stops a second copy reappearing. Findings are ranked by value (duplicated lines x copies x bug risk). Models already in the platform: one Tenant table in EA, one `Jurisdiction` registry in GL (served at `GET /api/jurisdictions`, WEB deleted its copy the same day), one shared figure formatter in WEB.

**Ground rules.** (1) Support go-live stays the top priority; none of this starts ahead of it unless marked "no-regret". (2) Peers own their application code: findings go to the owning session, they commit, CM reviews and deploys. CM owns the infrastructure and CI items directly. (3) Anything on the authentication path gets a high-effort review. (4) Production Terraform is never "re-organised in place": adoption is by `moved {}` blocks and a plan that shows zero adds, changes or destroys.

---

## A. The foundation: fix how `common/` is consumed (do this first)

`common/` (fish-common) is the natural single home for shared backend code, but today it is consumed as a source submodule pinned at **six different commits** across GL, EA, POP, SOP, IM and HR; HR's pin predates `CognitoServiceAccountTokenProvider` (so HR carries its own identical copy); ER (Education Runtime) and Omniview do not use `common` at all. Until there is one pin (or a published artifact / composite build), extracting anything into `common` fans out inconsistently.

- **Owner:** CM (build) with a one-line rule: every service pins the same `common` SHA, bumped together.
- **Guard:** a CI check that fails if a service's `common` pin differs from the platform pin.
- **Risk LOW, effort S.** No-regret; it unblocks everything in section B.

## B. Backend services (Kotlin/Ktor), ranked

| # | Duplicated thing | Where / how many | Single home | Stays per service | Guard | Risk / effort |
|---|---|---|---|---|---|---|
| B1 | **JWT/JWKS verifier + auth install** (`JwkProviderBuilder`, cache/rate-limit, `JWT.require`, identical `challenge { unauthorized }`) | verifier built 12 times and 20 identical `jwt(...)` blocks across GL, EA, POP, SOP, IM, HR, ER, Omniview; Auth.kt files 139-560 lines | `common` `FishJwt` module: `buildJwksVerifier(...)`, `installServiceJwt(...)`; challenge defined once | the `validate{}` body, env prefixes, which audiences exist | build check failing on `JwkProviderBuilder(` outside `common` | **MED (security path), M** |
| B2 | **EA membership client + authorizer** | `ktor_ea_membership_gateway.kt` byte-identical in POP/SOP/IM/HR; `ea_dtos.kt` identical in GL/POP/SOP/IM; `access_level.kt` x4; `XxMembershipAuthorizer` ~70 lines x4; HR's own copy of the Cognito token provider (identical to `common`) | `common-ea-client`: `EaMembershipGateway`, `EaMyProfileResponseDto`, `AccessLevel`, `ModuleMembershipAuthorizer(gateway, tenantId, moduleCode, serviceAccountBypass)`; delete HR's token provider | module code and messages; SOP/IM service-account bypass and SOP's tenant-wide scope become parameters | an EA contract test that deserialises the shared DTO (an `/api/me` change breaks EA's build) | **MED, M** |
| B3 | **Ktor bootstrap** (ContentNegotiation, CallId, JSON logging, StatusPages, CORS, Netty start, health) | ~45 lines x 7 services | `common`: `installFishPlatform(corsEnvVar, extraMethods, extraHeaders)`, `healthRoutes()`, `startNetty(...)` | productionModule wiring, extra CORS methods/headers | the shared function is the only caller of `install(CallId)` | LOW, S-M |
| B4 | **Database plumbing** (`DatabaseConfig`, Flyway `DatabaseMigrator` with the zero-migrations guard) | six near-identical `DatabaseConfig` (39-55 lines), five identical migrators | `common`: `FishDatabase.dataSource(prefix, defaultDb)`, `Migrator.migrate(ds, callbacks)` | GL's tenant callback; table definitions | none needed beyond review | LOW, S |
| B5 | **GL client mirrored in POP/SOP/IM/HR** (`GlEngineResult`, `toFailure`, request DTO subsets of GL's 903-line `Dtos.kt`) and **EA's GL mirrors** | four hand-mirrored subsets plus EA's `infrastructure/gl/gl_dtos.kt` | GL publishes a `gl-client` artifact built from its own DTOs; shared `ErrorResponseDto` in `common` | each service's gateway interface and domain mapping | contract tests in GL | MED, L (later) |
| B6 | Small exact copies | `logback.xml` byte-identical x4; `HealthRoutes.kt` x6; `parseUuid/parseMoney/parseLocalDate` x4; `rawBearerToken` x4; `ErrorResponseDto` declared in every service | `common` | - | review | LOW, S |
| B7 | Test fixtures | `TestJwtSupport.kt` x6; `FakeEaMembershipGateway` x4 | `common-testfixtures` | - | review | LOW, S |
| B8 | EA operator surface mirrored in Omniview (`PlatformHealthGateway`, operator routes) | EA 79+71+67 lines vs Omniview 86+28+24 | finish the extraction: Omniview is the single owner, delete EA's copy | - | - | MED, M |

**Divergences that are already live bugs (found because the copies drifted):**
1. Only GL and EA send `Cache-Control: no-store, private`; POP, SOP, IM, HR and Omniview do not. A security fix that never propagated. **B3 closes it by construction.**
2. EA's optional service verifier treats a blank audience variable as "unset"; IM's and SOP's do not, so a blank value builds a verifier whose audience is the empty string. **B1 closes it.**
3. CORS allowed methods differ per service (HR adds PUT/PATCH/DELETE; IM/POP/SOP allow only GET/POST), a latent preflight bug for any service that adds PUT or DELETE. **B3 closes it.**

## C. Infrastructure and CI (CM owns these)

| # | Duplicated thing | Evidence | Single home | Guard | Risk / effort |
|---|---|---|---|---|---|
| C1 | **Hand-kept per-service lists** edited in several places when a service is added (ECR ARNs and role ARNs in `jenkins.tf`, ALB listener priorities 100-107, per-service `acm_validation_record` outputs) | dated "added 2026-09-xx" comments in the lists are the drift evidence | derive them from one `local.services` map / module outputs | review; a plan must show an in-place IAM change with the same ARN set | **LOW, S. Do this first among infra items.** |
| C2 | **Per-service Terraform is one template copied 8 times** (ECR+lifecycle, log group, exec/task roles, security group, DB password secret, ACM, target group, listener rule, task def, ECS service) | ea/hr/im/pop/sop/omniview/education_runtime/buzzme = 3,704 lines; hr vs im 92% identical; the six ECR lifecycle policies are byte-identical | `modules/service` (+ `modules/service-account`, 10 files / 901 lines, hr vs im differ by 6 of 50 lines), driven by `for_each` over one map | CI grep rejecting `aws_ecs_service` outside the module | MED, L |
| C3 | **Jenkinsfiles are one pipeline pasted 9 times** | HR/EA/IM/POP/SOP each have exactly 134 code lines and differ in ~16 | a Jenkins Shared Library (`fish-jenkins-lib`, `fishServicePipeline(name:..., dbPrefix:..., integration:true)`), each Jenkinsfile becomes ~6 lines | a new repo's Jenkinsfile can only be a call | LOW-MED, M |
| C4 | `variables.tf`: ~55 per-service variables that are really constants | 87 variables; same shapes repeated | fold into the `local.services` map | review | LOW, S-M |
| C5 | Dockerfiles (6 near-identical Kotlin ones) | differ only in user, jar name, port | one `Dockerfile.kotlin-service` in `common` (keep Omniview's and ER's variants separate; ER does not copy `common/`) | review | LOW, S |
| C6 | `.gitattributes` (`/gradlew text eol=lf`) | 7 copies; **ER and WEB have none** (ER is a latent Windows `./gradlew: not found` break, which has already bitten the others) | one standard snippet; add it to ER now | review | LOW, S. **No-regret, do now.** |
| C7 | Single facts written in many files (account id, region, cluster name, domains `*.theprodeogroup.com` ~54 places, `jenkins-casc.yaml` hand-synced) | account id in 9 Jenkinsfiles + 10 places in one policy file | derive from `data.aws_caller_identity`, `var.aws_region`, `root_domain`; manage CASC via `templatefile` | review | LOW, S |

**Real drift already present in CI:** GL's deploy resolves the service's current task-definition ARN, the other eight use the latest in the family; ER skips integration tests via `expression { false }`; Omniview has no integration stage; the throttle comment says "8 repos" but there are 9 pipelines; `maxConcurrentTotal` lives only in a hand-synced file.

**Safe adoption of C2/C4 on live production:** `terraform state pull` backup first (the 2026-09-24 state incident); the module must reproduce every ForceNew name verbatim (IAM roles, target-group short names, SG names, secret names, ECR and log-group names, Cognito usernames); pilot one service per PR; a `moved {}` block per resource (~20 per service, generated by script); gate each PR on a plan showing only moves; keep `ignore_changes = [container_definitions, task_definition]` (Jenkins registers revisions out of band). Seven near-copies of a GitHub OIDC deploy role look dead (GitHub Actions is disabled); retire them in a separate, deliberate destroy plan.

## D. WEB (single shared frontend), ranked

| # | Duplicated thing | Measured | Single home | Guard | Risk / effort |
|---|---|---|---|---|---|
| D1 | **`getErrorMessage` / `describeError`**: ApiError to display text | `instanceof ApiError` 37x in 32 files; `err.body.detail ?? err.body.error` 50x; `err.body as ApiErrorBody` 17x | one `describeError(err, fallback)` in `httpClient.ts` (built on `supportErrors.ts`'s richer mapping) | lint ban on `err.body as ApiErrorBody` | LOW, S |
| D2 | **Bearer-only fetch wrapper** | 11 API files re-declare `{service}Fetch`; `Authorization: Bearer ${idToken}` hand-written 20x in 18 files; 6 wrappers with identical bodies | `bearerFetch(baseUrl, path, idToken, init)` in `httpClient.ts`; each service file becomes one line | lint ban on the string `Bearer ` outside `httpClient.ts`/AuthContext | LOW, S |
| D3 | **`useApiResource` hook** (load + loading + error + cancelled flag) | `let cancelled = false` 57x in 40 files; `if (!idToken) return` 99x; `error-banner` 58x; "Loading…" 39x; empty states 42x | `hooks/useApiResource.ts` + a `<ResourceState>` component | lint rule banning `let cancelled` outside `hooks/` | MED, M |
| D4 | **Enums/lists hand-copied from the backend** (modules in 5 places, roles, industry types, client types, currencies) | ManagedModule declared in `api/tenants.ts`, again as StaffModule, again in `SupportChatWidget`, `FinanceScreen`, `BusinessOperationsScreen` | a backend **reference-data read route** (same pattern as jurisdictions: `GET /api/reference-data`), read once through a `useReferenceData()` cache | a CI test diffing WEB's lists against the route | MED, M (needs GL/EA owner) |
| D5 | Business-logic helpers re-derived (`isSchoolTenant` in 4 files; `isOwnerAdmin` threaded through 5 as differently named props) | | `isSchoolAt(...)`/`canManageAt(...)` in `api/me.ts`, or one `useCompanyContext()` | lint ban on the literal `'EDUCATION_RUNTIME'` outside `me.ts` | LOW, S |
| D6 | Date helpers not on the shared formatter | `new Date().toISOString().slice(0,10)` 14x in 12 files (9 local `today()`); `formatDay`/`isSameDay` duplicated; `toLocale*String` in 6 files. **Latent bug:** "today" via `toISOString` is the UTC date, wrong near midnight outside GMT | `todayIso()`, `formatDay/Date/DateTime/Time` in `lib/format.ts` | ban `.toISOString().slice` and `toLocale*String` outside `lib/format.ts` | LOW, S |
| D7 | Sub-tab bars and status badges | `module-tab sub-tab` hand-written in 12 files; `status-badge` 20+x defined 3 ways | `<TabBar>`, `<StatusBadge status>` with one status-to-tone map; retire `operator-badge`; adopt or delete the unused shadcn `ui/*` | lint on raw `className="status-badge` | LOW, S |
| D8 | Forms (`<label>` 185x, 53 `<form>`, 43 busy-labelled submit buttons; 6 free-text currency inputs next to the CURRENCIES select) | | `Field`, `useSubmit`, `CurrencySelect` | review checklist | MED, M |
| D9 | Label maps, 497 inline `style={{}}` (top: `marginBottom: 0` x83) | | labels next to their types; utility classes / `<Card>` / `<SectionHeader>` | stylelint budget | LOW-MED, M |

Already done by the CX work and not re-reported: shared money formatter (12 copies removed), shared figure cells, exact-decimal sums, jurisdiction list read from GL.

## E. Recommended order

**Do now (no-regret, small, safe, no Support impact):** A (one `common` pin), C6 (`.gitattributes` for ER and WEB), C1 (derive the Jenkins permission lists and listener priorities from one map), D1 + D2 (WEB error and fetch helpers).

**After the Support go-live, in this order:** B3 (closes the missing `no-store` and CORS bugs), B1 (JWT; high-effort review), B2, B4, B6/B7; C3 (Jenkins library); D3, D6, D5, D7; then C2/C4 (Terraform modules, one service per PR); D4 (reference-data route), D8, D9; B5 and B8 later.

**Owners.** CM: A, C1-C7. Backend sessions (GL/EA/POP/SOP/IM/HR/ER): B1-B8 in their repos, with `common` changes reviewed by CM. WEB: D1-D9. GL or EA (whoever owns it): the reference-data route for D4. Omniview: B8.

**What this report deliberately does not recommend:** moving the 239 `transaction { }` call sites (an idiom, not a duplicate); merging per-service gateway interfaces (genuinely different operations); touching `ER`'s Dockerfile blindly (it does not copy `common/`).
