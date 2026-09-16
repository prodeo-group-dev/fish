# FiSH — Scope of work: replace Prodeo-branded service-account principals

**Version:** 0.4 (design fully decided; implementation — WP1 onward — not started). Merges this doc with the independently-written `Service_Account_Opaque_Identity_Migration_Scope.md`, which is now retired in favor of this one — same six-identity inventory, reconciled into a single plan rather than two competing docs.
**Date:** 2026-09-16  
**Status:** Both open questions resolved — **§4.1** (GL adopted Option B, `GL@d376f66`) and **§4** (identity shape is **Option B** — opaque email on a non-Prodeo domain — confirmed against `cognito.tf`'s `username_attributes = ["email"]` constraint, which rules out Option A outright). Remaining work is picking the actual domain string and executing WP1–WP5. Do **not** apply terraform or rotate Cognito users until phasing (§9.3) and a maintenance window (§9.4) are set.  
**Parent decision:** `docs/Service_Account_Identity_And_EA_Membership_Design_Note.md` §6 / Follow-up #2  
**Goal:** GLaaS module S2S must not use `@theprodeogroup.com` emails as the machine identity (“not calling on Prodeo”). Keep Option B (no EA membership for M2M) — now settled for **all six pairs**, per §4.1. Humans unchanged.

---

## 1. Problem in one line

Today every module↔module Cognito “user” is named like a Prodeo mailbox (`*-service@theprodeogroup.com`). That is the **principal** (who’s on the JWT `email` / username). Product direction: those principals must become **opaque technical IDs**, not Prodeo addresses.

Welcome mail is already suppressed (`message_action = SUPPRESS`). The issue is **identity shape / brand / architecture**, not inbox spam.

---

## 2. Inventory (current defaults)

| Terraform var | Default principal | Used by (caller → callee) | ECS username env (typical) | EA Membership check today? |
|---------------|-------------------|---------------------------|----------------------------|------------------------------|
| `pop_im_service_account_email` | `pop-im-service@theprodeogroup.com` | POP → IM | `POP_IM_SERVICE_ACCOUNT_USERNAME` | **No** — permanent bypass (`VerifiedIdentity.isServiceAccount`, design note Option B) |
| `sop_im_service_account_email` | `sop-im-service@theprodeogroup.com` | SOP → IM | `SOP_IM_SERVICE_ACCOUNT_USERNAME` | **No** — same bypass |
| `pop_gl_service_account_email` | `pop-gl-service@theprodeogroup.com` | POP → GL | `POP_GL_ENGINE_SERVICE_ACCOUNT_USERNAME` | **No, as of `GL@d376f66`.** Had a real, production-verified EA User + Membership (`docs/POP_GL_Service_Account_Closure_Plan.md`) — that row still exists but is now unnecessary; GL bypasses EA for this caller before ever reading it. Row retirement is WP4, not yet done. |
| `sop_service_account_email` | `sop-service@theprodeogroup.com` | SOP → GL | `SOP_GL_ENGINE_SERVICE_ACCOUNT_USERNAME` | **No, as of `GL@d376f66`.** GL's `authorizeTenant` now bypasses EA for every `isServiceAccount` caller before any lookup. |
| `im_service_account_email` | `im-service@theprodeogroup.com` | IM → GL | `IM_GL_ENGINE_SERVICE_ACCOUNT_USERNAME` | Same as above — **No, as of `GL@d376f66`.** |
| `hr_service_account_email` | `hr-service@theprodeogroup.com` | HR → GL | `HR_GL_ENGINE_SERVICE_ACCOUNT_USERNAME` | Same as above — **No, as of `GL@d376f66`.** |

**Files:** `GL/infra/terraform/{pop,sop,im,hr}_*_service_account.tf` + wiring in `pop.tf` / `sop.tf` / `im.tf` / `hr.tf`.  
**Mechanism today:** Cognito **user** + app client + secret; `CognitoServiceAccountTokenProvider` does USERNAME/PASSWORD (or equivalent) auth; callees trust a dedicated **audience** (`IM_JWT_SERVICE_AUDIENCE_POP` / `_SOP`, etc.).

**Out of inventory (related but different):** human Cognito users, operator token, supplier portal tokens, staff invites.

---

## 3. In-scope / out-of-scope

### In scope
1. Choose target principal shape (see §4).  
2. Terraform + Cognito create/migrate path for all six (or agreed subset) SAs.  
3. Secrets Manager password/client-secret continuity.  
4. ECS task def env `*_USERNAME` updates.  
5. Verify JWT still validates (aud + email/username claim as required by each Auth.kt).  
6. Smoke: POP→IM, SOP→IM, POP→GL, SOP→GL, IM→GL, HR→GL.  
7. Retire old Cognito users (after dual-run or hard cut).  
8. Update design note §6 when done.

### Out of scope (this epic)
- Changing Option B / EA membership for humans.  
- HR EA membership authorize (separate tenancy item).  
- Client-credentials OAuth redesign **unless** chosen in §4 as the target (then it becomes the epic).  
- Renaming HTTPS hostnames (`*-api.theprodeogroup.com`) — DNS/branding of endpoints, not JWT principals.

---

## 4. Design choice — RESOLVED: Option B

| Option | Idea | Pros | Cons |
|--------|------|------|------|
| ~~**A. Non-email Cognito usernames**~~ | ~~e.g. `fish-sa-pop-im`, still user+password app client~~ | ~~Smallest change; same code path~~ | **Not actually available.** All six identities live in the project's one and only Cognito User Pool (`aws_cognito_user_pool.this`, `GL/infra/terraform/cognito.tf`), which is configured `username_attributes = ["email"]`. Cognito enforces this at the API level — a non-email-shaped username is rejected outright (`InvalidParameterException`), for every user in the pool, human or service. Doing Option A for real would mean a *second*, separately-configured user pool (its own issuer/JWKS/audience wiring across all six consuming `Auth.kt`s) — bigger and riskier than Option C, not "smallest change." |
| **B. Opaque email on non-Prodeo domain** | e.g. `pop-im@sa.fish.internal` (not a real mailbox) | Satisfies the pool's own email-username constraint with **zero** user-pool changes. Populates the `email` claim exactly the way every consuming `Auth.kt` already hard-requires (`getClaim("email").asString() ?: return@validate null` — confirmed in GL, IM, POP, SOP, HR) — no code change anywhere, just new Cognito users. | Still email-shaped; needs a one-time domain-naming decision (e.g. `sa.fish.internal`), otherwise no real con |
| **C. Client-credentials (no user)** | app client only; no username | Clearest "not a person / not Prodeo" | Client-credentials tokens carry no `email` claim at all - would break every one of these `Auth.kt`'s validation logic (GL's, IM's) immediately, requiring a real code change to accept a different identifying claim (`client_id`/`sub`) everywhere a service caller is validated, not just a Cognito change. A bigger, separate epic if ever pursued - not this cutover. |

**Decided:** **Option B.** Confirmed directly against `GL/infra/terraform/cognito.tf` and every consuming `Auth.kt`'s validation logic - not the "A, or B if forced" hedge this section used to carry. A is technically blocked by the shared pool's own configuration, and C's blast radius (real code changes across every callee) is disproportionate to a naming/branding problem. B is the one option that's a pure identity-shape change with no code touched anywhere.

### 4.1 Corrected invariant — RESOLVED, now holds uniformly across all six

The original single invariant ("no `@theprodeogroup.com` on M2M principals; no EA User rows for these identities") did not hold for the four GL-bound rows as of v0.2 - GL's own `authorizeTenant()` resolved every caller, human or service, through EA's `/me`, and `pop-gl-service@theprodeogroup.com` had a real, production-verified EA User + Membership row.

**Resolved 2026-09-16:** GL adopted Option B for its own four service callers, same shape as IM's (`GL@d376f66` - `AuthenticatedCaller.isServiceAccount`, `authorizeTenant` bypasses EA entirely for service callers before ever consulting it). The invariant now holds for all six rows uniformly: no EA Membership involvement, for any of them, going forward.

**What this unblocks:** WP0's design-choice question (§4 A/B/C) is the only remaining decision for all six pairs - there is no longer a per-row split in mechanism.

**What this does NOT yet do:** `pop-gl-service@theprodeogroup.com`'s existing EA User + Membership row still exists in `ea_production`. It's now dead weight, not a model to replicate, but retiring it is still a live-production-data change belonging to WP4 ("remove old Cognito users + tidy vars/defaults"), not bundled into the `GL@d376f66` code change. Do not delete it casually - confirm no other caller depends on that specific row first.

---

## 5. Work packages

| # | Package | Owner surface | Risk |
|---|---------|---------------|------|
| WP0 | ~~Decision §4~~ **Done** — Option B decided (§4), confirmed against `cognito.tf`'s `username_attributes = ["email"]` constraint and every consuming `Auth.kt`'s claim requirements. §4.1 also resolved (GL adopted Option B, `GL@d376f66`). **No remaining design blocker — WP1 can start.** | Design | Closed |
| WP1 | Terraform: new opaque-domain email usernames (e.g. `*@sa.fish.internal`), `message_action=SUPPRESS`, secrets unchanged or rotated | `GL/infra/terraform` | Cognito user replace can break live S2S if ECS still has old username |
| WP2 | Dual-run or blue/green: create new SA users → point one caller → verify → roll forward | Ops | Highest prod risk |
| WP3 | Update ECS env USERNAME values via terraform apply / deploy | Jenkins/ECS | Must sync with Cognito |
| WP4 | Remove old Cognito users + tidy vars/defaults | Terraform | After all callers moved |
| WP5 | Docs: design note §6 “done”; optional POP_GL closure plan cross-link | docs/ | Low |

**Suggested first slice (lowest blast radius):** POP→IM + SOP→IM only (the original product pain), then GL-bound SAs (POP/SOP/IM/HR → GL) in a second window.

---

## 6. Risks & constraints

- **Live break:** wrong username/password → 401 on goods receipt/issue, sales postings, payroll GL posts.  
- **Cognito username is immutable** on an existing user — usually **create new user**, cut over, delete old (not rename-in-place).  
- **Single shared user pool** — collisions and cleanup matter.  
- **Aud vs email:** authorization for M2M is primarily **app client audience**; email is still logged/validated in several places — audit those before non-email usernames.  
- **No EA provisioning for any of the six principals** (Option B, now settled platform-wide per §4.1). The one existing exception - `pop-gl-service@theprodeogroup.com`'s EA Membership row - predates this decision and is scheduled for retirement (WP4), not a pattern to extend.

---

## 7. Acceptance criteria

1. No terraform **default** `*_service_account_email` uses `@theprodeogroup.com`.  
2. Production Cognito SA users used by ECS match non-Prodeo principals.  
3. All six call paths in §2 smoke green after cutover.  
4. Human login + EA membership unchanged.  
5. Design note updated; this scope doc marked complete or superseded.

---

## 8. Explicit non-goals / do-not-do-yet

- Do not `terraform apply` identity changes in this scoping pass.  
- Do not provision any `@theprodeogroup.com`-shaped SA email into EA as a User — that's the pattern being retired, regardless of how §4.1 resolves.  
- Do not mix this with HR membership authorize rollout.

---

## 9. Next ask of product/eng

1. ~~Approve §4 option A vs B vs C~~ **Resolved 2026-09-16:** Option B, confirmed against `cognito.tf`'s pool config and every `Auth.kt`'s claim requirements — see §4. Pick the actual domain string (e.g. `sa.fish.internal`) before WP1 starts; that's the one open naming detail, not an open design question.  
2. ~~Answer §4.1~~ **Resolved 2026-09-16:** GL adopts Option B (`GL@d376f66`). All six pairs are on the same footing now.  
3. Approve **phasing**: any pair can go first now that §4/§4.1 are both resolved — still recommend IM-bound first as the lowest-risk pilot of the identity shape itself.  
4. Pick a maintenance window / rollback owner.  
5. Decide who/when retires `pop-gl-service@theprodeogroup.com`'s now-unnecessary EA Membership row (WP4) - separate from the code change, still a live-data action.

---

## 10. Parked, not scoped: shared-global vs per-tenant identity

Today all six identities are single, global, Prodeo-wide service accounts — there's exactly one `pop-im-service@...` account regardless of which Tenant's data POP is acting on, because POP/SOP/IM are single-tenant-per-deployment today (`POP_GL_ENGINE_TENANT_ID`/`IM_EA_TENANT_ID` etc. are fixed per deployment, confirmed while building the §2.4 membership-check rollout). Once FiSH is genuinely multi-tenant, a shared global service identity across every tenant's own module mesh becomes a design smell in its own right — Tenant X's POP calling Tenant X's IM arguably wants an identity scoped to that Tenant, not one platform-wide account standing in for every tenant at once. That's a bigger structural change than this cutover and is explicitly out of scope here — noted so it isn't lost, not scoped further.
