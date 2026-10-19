# New service and Enterprise Administration (EA): integration runbook

**Date:** 2026-10-19. **Owner:** EA session. **For:** the sessions building `fish-payroll` (module `PAYROLL`), the new `fish-hr` (Personnel) and `fish-cash-bank-books` (module `CASH_BANK_BOOKS`); and CM, who deploys them.
**Grounded in code, not memory:** HR `shared/infrastructure/web/Auth.kt`, IM `infrastructure/ea/ea_membership_gateway.kt`, EA `MeRoutes.kt` / `Dtos.kt` / `managed_module.kt` / migrations V13-V15, `Infrastructure/*_service_account.tf`, and `docs/Service_Account_Identity_And_EA_Membership_Design_Note.md` (v1.8).

## 0. The one correction to the brief

CM's brief asked for "how service-account Users and Memberships are provisioned for a new service's Cognito credential". **They are not, and a new service must not get any.** The design note (Option B, permanent, adopted by IM and by GL) is: a machine caller proves a configured service audience, and the receiving service skips the EA membership check for it. EA never sees it. A service account has a Cognito user and an app client and nothing in `ea_production`. The only EA row of that kind that exists (`pop-gl-service@`) predates the decision and is dead weight awaiting retirement.

So the "undocumented step" is not a missing EA step. It is two things: the Cognito/Terraform steps in section 3, and the human membership check in section 2. Write nothing into EA for a service.

## 1. What EA must know about a new service: only its module name

EA authorises people, per Company, by module name. A new service needs EA for exactly three things: its **module name** declared, its **human routes** gated through `GET /me`, and (optionally, later) an **Owner view read** that EA calls. Nothing else.

## 2. The human membership authorizer a new service must implement

Mirror HR's `HrMembershipAuthorizer` (or IM's / POP's, the same shape). Copy the files, rename the package and the module constant.

**Authentication (JWT)**
- Verify the caller's Cognito JWT in-process against the shared pool: env `{SVC}_JWT_ISSUER`, `{SVC}_JWT_AUDIENCE` (the shared human-facing app client id), `{SVC}_JWT_JWKS_URL`. No defaults, fail at startup if unset. Require the `email` claim.
- Machine callers each get their own auth provider and audience (`{SVC}_JWT_SERVICE_AUDIENCE_{CALLER}`, one `JWTVerifier` per audience, because the library takes one audience). Section 3.

**Membership (EA)**
- Call `GET {EA_BASE_URL}/api/me` with **the caller's own bearer token forwarded**, never a service token. Env `{SVC}_EA_BASE_URL` (required, no default). Three-way result: `Success`, `Unauthorized` (401), `Failure` (EA down).
- Decode with **strict** mirror DTOs, no `ignoreUnknownKeys`. Take the shape from the `fish-contracts` fixture `contracts/ea/me.json`, not from this page. Today: `{email, name, kycStatus, userId, tenants:[{tenantId, tenantName, isOwnerAdmin, tenantStatus, kybStatus, adminPhoneNumber, adminPhoneVerificationStatus, phoneVerificationDeadline, companies:[{id, name, schoolId?, role?, accessLevel?, grantedModules[]}]}]}`. If EA adds a field, the fix is declaring it, in every service (a missing field has broken production before).
- **The Tenant comes from the Company in the request, never from configuration.** Find the `/me` tenant block whose `companies[]` contains the request's `companyId` (`owningMembershipOf`): exactly one, else deny. No Membership at all is `no_membership`; Memberships but none listing this Company is `insufficient_access`.
- **Access level** at that Company: the assignment's `accessLevel`; an Owner Admin with no explicit assignment there has an intrinsic floor of `READ`; anyone else with no assignment is `NONE`. Order: `NONE < READ < WRITE < APPROVE < ADMIN`. Require at least the route's level (reads `READ`, writes `WRITE`, approvals `APPROVE`, never `ADMIN` for ordinary work).
- **Module**: the route's module must be in that Company's `grantedModules`. Being the Owner Admin does not by itself pass a module check: the Owner Admin passes only through the modules on an actual assignment at that Company. Where there is no assignment, the intrinsic floor gives `READ` and no modules. A service that wants the Owner Admin to pass a route regardless must say so explicitly (HR's `ownerAdminPassesModule`), and the level check still applies.
- **Responses (the wire contract WEB depends on):** `401 unauthorized`; **`503 service_unavailable` when EA cannot be reached (fail closed, never fall back)**; `403 forbidden` with a machine-readable `reason` of `no_membership`, `insufficient_access` or `module_not_granted`; on routes that find a record by its own id and only then learn the Company, answer **404** instead of 403 so an id is never confirmed to someone with no access.
- **Owner Admin only** things (bank details, pay data and the like) read `isOwnerAdmin` from the same `/me` call. Keep it in a request attribute, default `false`, so a route that forgot to authorize hides rather than reveals.
- **Maker-checker** (the person who prepared a thing cannot approve it): the email EA reports for the verified token is the identity to compare.

**Do not** configure a Tenant id for the service (`HR_EA_TENANT_ID` is retired), and do not add an EA User or Membership for any service account.

**Tests every new service needs (I will check these at review)**: a caller with no Membership; with a Membership that does not list the Company; with the Company but too low a level; with the level but without the module; the Owner Admin floor; EA unreachable gives 503 and not 200; a machine audience bypasses EA and a human never does; a by-id route answers 404 not 403; the contract fixture `me.json` decodes strictly and an extra field fails loudly.

## 3. Giving a new service a machine credential (Cognito and Terraform only)

Only needed if another FiSH service must call it, or it must call another (for example Payroll or CBB posting to GL, or being called by HR). All of it lives in `fish-infrastructure`; copy `pop_service_account.tf`.

1. Per caller-and-callee pair, one **Cognito app client** with `generate_secret = true`, `ALLOW_USER_PASSWORD_AUTH`, and one Cognito **user** (name it `{caller}-{callee}-service`), plus a `random_password`. The callee gets a **new auth provider** trusting that app client's id as an audience.
2. Store the app client secret and the user's password in Secrets Manager (`{project}/{env}/{caller}-{callee}-service-account-password` and `...-client-secret`). Never read them back into a session.
3. **Gotcha, cost real time already:** the pool uses `username_attributes = ["email"]`, so Cognito assigns its own UUID as the true username whatever Terraform asks for. The `aws_cognito_user.username` in the file must be that real UUID (see the comment in `hr_service_account.tf`), not the email. Create the user, read the UUID with `list-users` (never `describe-user-pool-client`, it prints the client secret), then put the UUID in the file.
4. Caller side env, per pair: `{CALLER}_{CALLEE}_COGNITO_REGION`, `..._SERVICE_ACCOUNT_CLIENT_ID`, `..._CLIENT_SECRET`, `..._USERNAME`, `..._PASSWORD`; code uses the existing `CognitoServiceAccountTokenProvider`.
5. Callee side env: `{CALLEE}_JWT_SERVICE_AUDIENCE_{CALLER}` = the app client id; register a provider named `{CALLEE}_JWT_SERVICE_AUTH_NAME_{CALLER}`; mark requests authenticated by it `isServiceAccount = true` and skip the EA step for those only.
6. **Deployment gotcha (outage risk):** Jenkins' deploy stage only patches `.image` on the live task definition; it never re-reads `container_definitions` from Terraform. A new env var or secret reaches a running service only by a manual task-definition registration. A bare `terraform apply` that renames or replaces a secret destroys the one the running task still uses. CM sequences this; I flag it so nobody assumes a Terraform apply is enough.
7. Tagged debt, not for this build: the `@theprodeogroup.com` service emails are to be replaced by opaque principals (design note section 6).

**Optional (the one case EA is involved):** if a new service must be called **by EA** (an Owner view read, for example `GET /api/companies/{id}/...`), EA forwards the Owner's own bearer token, as it does today for SOP/POP/IM/HR/GL. No EA service account, no Cognito work for that direction.

## 4. Module declarations

- Module names are strings on the wire and in the database (`membership_module_grants.module`, `messages.audience_module`, both `VARCHAR(20)`). `PAYROLL` and `CASH_BANK_BOOKS` (15 characters) fit; **a name longer than 20 characters fails at insert and needs a migration**.
- EA's `ManagedModule` enum is the vocabulary. EA cannot read a module name it does not declare, so **EA declares a module first, inert, before any service or screen mentions it**. Consumers (services) compare plain strings, so they do not break; WEB gets the new name from `/me`.
- **`PAYROLL`**: already declared and withheld. It becomes real when it is removed from `ManagedModule.withheld`, which is the enabling act (defaults, `EA_PAYROLL_BACKFILL` dry-run then execute, `EA_PAYROLL_SWITCH_DATE` warning, then HR's pay-split). Femi decided: only Owner Admins and Accountants get it; HR WRITE holders do not. Unchanged by the split into a new service: the module name stays `PAYROLL`.
- **`CASH_BANK_BOOKS`**: to be declared the same way. Owner Admin defaults pick up every non-withheld module automatically, so once enabled an Owner Admin gets it. **Who else gets it by default (an Accountant?) is not decided and I have not guessed**: see the questions in the reply.
- **Open for the HR session:** does the new HR keep module name `HR` (Personnel being a display name)? I have assumed yes and changed nothing. Renaming a module is a data migration across every Membership, so it must be decided before, not after.

## 5. Order of work (consumer first, nothing live changes until the last step)

1. EA declares the new module values withheld (inert). Deploys with no behaviour change.
2. The new service ships its authorizer with `{SVC}_EA_BASE_URL` and the JWT env set, and its human routes denied by default until the module is granted.
3. WEB shows the new area only for a Company whose `grantedModules` contains the name.
4. EA enables the module (removes it from `withheld`), backfills in dry-run then execute, in a window CM chooses.
5. The old service is discarded only after the new one has served real calls on staging and EA's HIGH review is clean.

## 6. What I will check when a tip arrives (HIGH review)

Every route is behind the authorizer with the right module and level; Tenant comes from the Company; 503 on EA down; 404-as-not-found on by-id routes; machine audience bypass is explicit and per-audience; no `ignoreUnknownKeys` on the `/me` decode; no `HR_EA_TENANT_ID`-style configured Tenant; mutation-checked tests for each deny; fixtures consumed from `fish-contracts` at a pinned SHA; Owner-Admin-only fields hidden by default; no EA row for a service account.
