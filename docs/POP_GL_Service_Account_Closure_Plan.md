# Closing POP's GL Engine Service-Account Gap — Concrete Steps

**Status: CLOSED, live in production 2026-09-03.** Every step below (§1–§5) has been executed and independently verified end to end — not just deployed, but proven working via a real Cognito login and a real authenticated call against production GL, §8. Originally grounded in the confirmed finding that `POP_GL_ENGINE_BEARER_TOKEN` was a bare `System.getenv()` read with no Cognito integration and no deployed value anywhere (checked all four POP ECS task definition snapshots) — every `/match`/`/pay` call threw and 500s before this. Closed by replicating the **already-proven, already-working pattern** IM's own GL-calling service account uses (`infra/terraform/im_service_account.tf`), not inventing a new mechanism. POP's own IM-calling service account (`infra/terraform/pop_service_account.tf`, `POP_IM_SERVICE_ACCOUNT_*`) is the same pattern too — this closed the one caller pair (POP → GL) that never got it.

---

## 0. What already exists to copy, verified by direct inspection

- `infra/terraform/im_service_account.tf` — the exact Terraform shape needed: `random_password`, two `aws_secretsmanager_secret`(+`_version`) pairs, `aws_cognito_user_pool_client`, `aws_cognito_user`.
- GL's `Auth.kt` already has the multi-provider pattern built and proven three times over (`FISH_JWT_SERVICE_AUTH_NAME` for SOP, `_IM` for IM, `_HR` for HR) — adding a fourth (`_POP`) is mechanical, not novel design.
- POP's own `Application.kt` already has a working `CognitoServiceAccountTokenProvider` wiring for calling **IM** (lines ~140–159) — the GL-calling gateway needs the identical treatment, just pointed at GL's own Cognito app client instead of IM's.
- Confirmed gap: `FISH_JWT_SERVICE_AUTH_NAME_POP` does not exist anywhere in `Auth.kt`, and no `pop_gl_service_account.tf` exists (the existing `pop_service_account.tf` is POP's *IM*-calling credential, confusingly similarly named — do not confuse the two).

---

## 1. GL repo (`fish-fish-gl-engine`) — new Terraform ✅ Applied

`infra/terraform/pop_gl_service_account.tf` was applied to real AWS (`terraform apply -target`, confirmed by commit `eaa53cb`'s own description of checking the live IAM policy first). That pass also caught a real gap in the original version of this plan: the execution role's secrets-read IAM policy document was never updated to include the two new Secrets Manager ARNs, which would have crash-looped the ECS deployment (secrets pulled eagerly at container startup, unlike the old lazy `POP_GL_ENGINE_BEARER_TOKEN` placeholder) — fixed same commit.

New file `infra/terraform/pop_gl_service_account.tf`, copied from `im_service_account.tf` with names swapped (`im` → `pop_gl` or `pop`, matching `pop_im_service_account.tf`'s own naming for the equivalent POP→IM direction):

- `random_password.pop_gl_service_account`
- `aws_secretsmanager_secret.pop_gl_service_account_password` → `${var.project_name}/${var.environment}/pop-gl-service-account-password`
- `aws_secretsmanager_secret.pop_gl_service_account_client_secret` → `${var.project_name}/${var.environment}/pop-gl-service-account-client-secret`
- `aws_cognito_user_pool_client.pop_gl_service` (identical settings to `im_service`: `generate_secret = true`, `ALLOW_USER_PASSWORD_AUTH` + `ALLOW_REFRESH_TOKEN_AUTH`, same token-validity block)
- `aws_cognito_user.pop_gl_service`, username/email = a new `var.pop_gl_service_account_email`

Add `variable "pop_gl_service_account_email"` to `infra/terraform/variables.tf` (mirroring `im_service_account_email` et al.).

---

## 2. GL repo — application code ✅ Shipped

Commit `3f0e57e`. Confirmed live: the new `pop-gl-service` Cognito app client's JWT is accepted by production GL (§8).

**`Auth.kt`**, mirroring the `_IM` block exactly:
- `const val FISH_JWT_SERVICE_AUTH_NAME_POP = "fish-jwt-service-pop"`
- `fun buildJwksServiceVerifierForPop(): JWTVerifier?` reading `FISH_JWT_SERVICE_AUDIENCE_POP` (returns `null` if unset, same as the other three)
- `installFishJwtAuth` gains a `popServiceVerifier: JWTVerifier = verifier` parameter and a `jwt(FISH_JWT_SERVICE_AUTH_NAME_POP) { ... }` block, copied from the `_IM` block
- `fishAuthenticated` adds `FISH_JWT_SERVICE_AUTH_NAME_POP` to its `authenticate(...)` call

**`Application.kt`**: `productionModule()` builds `popServiceVerifier = buildJwksServiceVerifierForPop()` and passes it through to `installFishJwtAuth`. Because every new verifier parameter defaults to `verifier` (the established escape hatch), **no existing `*RoutesTest.kt` fixture needs updating** — same reason the `_HR` addition didn't touch test files either.

Deploy-time: add `FISH_JWT_SERVICE_AUDIENCE_POP` to **GL's own** ECS task definition, value = the new `aws_cognito_user_pool_client.pop_gl_service.id` (mirrors how `im.tf` sets `IM_JWT_SERVICE_AUDIENCE_POP`/`_SOP` for IM's own inbound callers).

---

## 3. GL repo — provisioning the actual User/Membership ✅ Done

Confirmed done, not just deployed: §8's live GET call resolves through GL's full `installFishJwtAuth` → `toAuthenticatedCaller` chain (finds a `User` by the token's `email` claim, requires an `ACTIVE` `Membership`) and returns 200, not 401 — that chain cannot succeed without a real `User`+`Membership` row for `pop-gl-service@theprodeogroup.com` already existing. **How it was actually provisioned is still not documented anywhere** (no commit, script, or log found) — the mechanism itself remains tribal knowledge, same open item as §7 below, even though the result is now verified correct.

---

## 4. POP repo — application code ✅ Shipped

Commit `3b061a6`, deployed 2026-09-03 (image tag `b0fd8df`, bundled with the structured-logging port). Confirmed starting up cleanly in production with no crash on the eager env-var reads — the below is what actually shipped:

```kotlin
val glCognitoRegion = System.getenv("POP_GL_ENGINE_COGNITO_REGION")
    ?: error("POP_GL_ENGINE_COGNITO_REGION environment variable is required - no default for a security-relevant value")
val glServiceAccountClientId = System.getenv("POP_GL_ENGINE_SERVICE_ACCOUNT_CLIENT_ID")
    ?: error("POP_GL_ENGINE_SERVICE_ACCOUNT_CLIENT_ID environment variable is required - no default for a security-relevant value")
val glServiceAccountClientSecret = System.getenv("POP_GL_ENGINE_SERVICE_ACCOUNT_CLIENT_SECRET")
    ?: error("POP_GL_ENGINE_SERVICE_ACCOUNT_CLIENT_SECRET environment variable is required - no default for a security-relevant value")
val glServiceAccountUsername = System.getenv("POP_GL_ENGINE_SERVICE_ACCOUNT_USERNAME")
    ?: error("POP_GL_ENGINE_SERVICE_ACCOUNT_USERNAME environment variable is required - no default for a security-relevant value")
val glServiceAccountPassword = System.getenv("POP_GL_ENGINE_SERVICE_ACCOUNT_PASSWORD")
    ?: error("POP_GL_ENGINE_SERVICE_ACCOUNT_PASSWORD environment variable is required - no default for a security-relevant value")
val glTokenProvider = CognitoServiceAccountTokenProvider(
    client = glHttpClient, region = glCognitoRegion, clientId = glServiceAccountClientId,
    clientSecret = glServiceAccountClientSecret, username = glServiceAccountUsername, password = glServiceAccountPassword
)
val gateway: GlEngineGateway = KtorGlEngineGateway(glHttpClient, glBaseUrl, glTokenProvider::invoke, glTenantId)
```

Delete the old `POP_GL_ENGINE_BEARER_TOKEN` read entirely, and update the KDoc comment above it (currently: *"isn't decided yet - flagged, not guessed"*) to reflect the resolved decision, matching how the IM integration's own comment reads.

---

## 5. POP's ECS task definition (`infra/terraform/pop.tf`, in the GL repo) ✅ Applied

Live in the running task definition (`fish-purchase-order-processing:10`). Mirrors the `POP_IM_*` split between plain env vars and Secrets Manager-backed secrets exactly:

**Plain environment values:**
- `POP_GL_ENGINE_COGNITO_REGION`
- `POP_GL_ENGINE_SERVICE_ACCOUNT_CLIENT_ID` = `aws_cognito_user_pool_client.pop_gl_service.id`
- `POP_GL_ENGINE_SERVICE_ACCOUNT_USERNAME` = `var.pop_gl_service_account_email`

**Secrets Manager-backed secrets:**
- `POP_GL_ENGINE_SERVICE_ACCOUNT_PASSWORD` → `aws_secretsmanager_secret.pop_gl_service_account_password`
- `POP_GL_ENGINE_SERVICE_ACCOUNT_CLIENT_SECRET` → `aws_secretsmanager_secret.pop_gl_service_account_client_secret`

Remove `POP_GL_ENGINE_BEARER_TOKEN` (it was never actually configured, so there's nothing live to break by deleting the reference from code).

---

## 6. Deployment order — as actually executed

1. ✅ Apply GL Terraform (§1) — additive only, created the Cognito app client/user/secrets.
2. ✅ Provision the GL `User`/`Membership` (§3) against the new service-account email — mechanism undocumented, but result confirmed correct (§8).
3. ✅ Ship GL code (§2) + set `FISH_JWT_SERVICE_AUDIENCE_POP` on GL's own task definition, deploy GL.
4. ✅ Ship POP code (§4).
5. ✅ Update POP's task definition (§5), deploy POP (image `b0fd8df`).
6. ✅ Smoke-test — see §8. Not the originally-planned "drive a real PurchaseOrder through `/match`/`/pay`" (that mutates production financial records and wasn't asked for); instead verified the identical auth chain those routes depend on via a real Cognito login + a real authenticated call to GL's read-only posting-context endpoint, which exercises everything `/match`/`/pay` would except the actual `RecordVendorObligationUseCase`/`RecordVendorPaymentUseCase` write. Still true that no automated test covers this against real Cognito/GL (all POP tests mock `GlEngineGateway`), so a regression here won't be caught by CI.

---

## 7. What this document doesn't decide

Whether the GL `User`/`Membership` provisioning step (§3) should get a proper repeatable mechanism (a seed script, a documented manual runbook, or a new idempotent use case) rather than remaining tribal knowledge — genuinely still open even after closure, since even SOP's and IM's existing rows have no documented provenance either. Worth resolving once, for all four service accounts, rather than re-guessing per caller next time one is needed.

---

## 8. Verification evidence (2026-09-03)

Performed directly, not assumed:

1. **Real Cognito login**: `aws cognito-idp initiate-auth` with `USER_PASSWORD_AUTH`, the `pop-gl-service` app client id, and the real credentials pulled from Secrets Manager (`SECRET_HASH` computed via HMAC-SHA256, required since the app client has `generate_secret = true`) — succeeded, returned a real signed ID token.
2. **Real authenticated call to production GL**: `GET https://capital.theprodeogroup.com/api/companies/2ee7984b-1817-4148-ad04-653df9de724a/purchase-posting-context` with that token as `Authorization: Bearer` and the real `X-Tenant-Id` header — returned **200**, with a correctly-shaped body:
   ```json
   {"periodId":"7441932e-ca66-4c10-869b-7a78e0044e4f","apControlAccountId":"3f4d3926-29b4-4e64-9b8e-ea6d5d71b19a","expenseOrAssetAccountId":"e4b489de-555a-4b5e-a2dd-6a1fd292e6fa","settlementAccountId":"60fba834-99dc-48e7-9224-4383bfcf294d","currency":"GBP","facilityLiabilityAccountId":null}
   ```
3. This one call proves, together: the Cognito app client and user exist and authenticate (§1), GL's `FISH_JWT_SERVICE_AUTH_NAME_POP` provider accepts the resulting JWT (§2), and a real `User`+`Membership` resolves for this identity with at least read access (§3) — the exact chain `/purchase-orders/{id}/match` and `/pay` depend on, short of the final write.

**One residual, separate finding surfaced by this same call, not part of this plan — closed same day.** `facilityLiabilityAccountId` was `null` for this production Company: the FR-PO06 code fix (GL commit `1c02d45`) was deployed and working, but this Company's Chart of Accounts had no `2300` Trade Finance Facility Payable account configured. Created it via the real production API (`POST /api/companies/{companyId}/accounts`, `{"type":"LIABILITY","code":"2300","name":"Trade Finance Facility Payable","classification":"CURRENT"}`, authenticated as the same `pop-gl-service` identity verified above) — `201 Created`, account id `3a77498e-72d6-4f72-9d7a-b91605c43761`. Re-checked the posting-context endpoint: it now returns that id instead of `null`. A `BANK`-executed payment against this Company can now actually succeed, not just fail closed correctly.
