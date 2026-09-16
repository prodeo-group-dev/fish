# FiSH — Scope of work: replace Prodeo-branded service-account principals

**Version:** 0.2 (scope only — no production change yet). Merges this doc with the independently-written `Service_Account_Opaque_Identity_Migration_Scope.md`, which is now retired in favor of this one — same six-identity inventory, reconciled into a single plan rather than two competing docs.
**Date:** 2026-09-16  
**Status:** Planning. Do **not** apply terraform or rotate Cognito users until cutover plan is approved. **§4's invariant is corrected in this version** — see §4.1.  
**Parent decision:** `docs/Service_Account_Identity_And_EA_Membership_Design_Note.md` §6 / Follow-up #2  
**Goal:** GLaaS module S2S must not use `@theprodeogroup.com` emails as the machine identity (“not calling on Prodeo”). Keep Option B (no EA membership for M2M) **where it already applies today** — see §4.1 for which pairs that actually is. Humans unchanged.

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
| `pop_gl_service_account_email` | `pop-gl-service@theprodeogroup.com` | POP → GL | `POP_GL_ENGINE_SERVICE_ACCOUNT_USERNAME` | **Yes** — real EA User + Membership provisioned and verified in production (`docs/POP_GL_Service_Account_Closure_Plan.md`) |
| `sop_service_account_email` | `sop-service@theprodeogroup.com` | SOP → GL | `SOP_GL_ENGINE_SERVICE_ACCOUNT_USERNAME` | Architecturally yes — GL's `installFishJwtAuth` passes the *same* `eaMembershipGateway` to every named provider, human and service alike (`GL/Auth.kt`). Row existence unverified. |
| `im_service_account_email` | `im-service@theprodeogroup.com` | IM → GL | `IM_GL_ENGINE_SERVICE_ACCOUNT_USERNAME` | Same as above — architecturally yes, row unverified |
| `hr_service_account_email` | `hr-service@theprodeogroup.com` | HR → GL | `HR_GL_ENGINE_SERVICE_ACCOUNT_USERNAME` | Same as above — architecturally yes, row unverified |

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

## 4. Design choice (decide before build)

| Option | Idea | Pros | Cons |
|--------|------|------|------|
| **A. Non-email Cognito usernames** | e.g. `fish-sa-pop-im`, still user+password app client; keep `email` claim synthetic or drop if Auth allows | Smallest change; same code path | Still Cognito “users”; must confirm every verifier tolerates non-email `email` claim or stop requiring email for SA |
| **B. Opaque email on non-Prodeo domain** | e.g. `pop-im@sa.fish.internal` (not a real mailbox) | Keeps email-shaped claims | Still looks like email; need a domain policy |
| **C. Client-credentials (no user)** | app client only; no username | Clearest “not a person / not Prodeo” | Larger: Auth.kt + token provider + GL/IM audience checks that assume `email` claim |

**Recommendation for first cut:** **A** (or B if email claim is hard-required everywhere), with a later epic for **C** if desired. Confirm SA JWT validation paths that `require` `email` before picking A.

### 4.1 Corrected invariant — splits by row, does not hold uniformly

The original single invariant ("no `@theprodeogroup.com` on M2M principals; no EA User rows for these identities") is right for two of the six rows and wrong for the other four as things stand today:

- **POP→IM, SOP→IM:** invariant holds as written. These already bypass EA permanently (Option B, shipped). A rename is a pure identity-shape change — no EA coordination needed.
- **POP→GL, SOP→GL, IM→GL, HR→GL:** invariant does **not** hold today. GL's own `authorizeTenant()` resolves *every* caller — human or service — through EA's `/me`, and `pop-gl-service@theprodeogroup.com` already has a real, production-verified EA User + Membership row created specifically to pass that check. Renaming the Cognito username for any of these four without also resolving the question below would break that call path on the next request — EA has no User record matching the new opaque identity.

**Decision required before WP0 can close for the GL-bound four:** does GL's own gate also move to Option B (a real code change to `GL/Auth.kt` — add its own `isServiceAccount`-equivalent bypass, matching IM's), or does GL deliberately keep its service accounts EA-Membership-backed (e.g., because GL is the ledger of record and wants every posting traceable to a real, audited identity)? Either answer is workable; guessing at it isn't. If GL keeps the EA-Membership model, the migration for these four is "create a new EA User + Membership for the new opaque identity, cut over, retire the old EA row" — not a pure rename.

This is why §5's suggested sequencing (IM-bound pairs first) is more than a blast-radius call: those two are the *only* pairs where a rename alone is sufficient today. The GL-bound four are blocked on this decision regardless of phasing.

---

## 5. Work packages

| # | Package | Owner surface | Risk |
|---|---------|---------------|------|
| WP0 | Decision §4 (identity shape) **and** §4.1 (does GL's own gate adopt Option B, or stay EA-Membership-backed) + list of Auth.kt claim requirements per callee | Design | Blocks build — §4.1 specifically blocks the four GL-bound pairs |
| WP1 | Terraform: new usernames, `message_action=SUPPRESS`, secrets unchanged or rotated | `GL/infra/terraform` | Cognito user replace can break live S2S if ECS still has old username |
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
- **No EA provisioning for the two IM-bound principals** (Option B, settled). **Unresolved for the four GL-bound principals** pending §4.1 — if GL keeps its EA-Membership model, the new opaque identities for those four need their own EA User + Membership rows (just not `@theprodeogroup.com`-shaped ones), not zero EA rows.

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

1. Approve **§4 option A vs B vs C**.  
2. Answer **§4.1**: does GL's own service-to-service gate adopt Option B, or stay EA-Membership-backed? Gates all work on the four GL-bound pairs.  
3. Approve **phasing**: IM-bound first (unblocked regardless of §4.1) vs all six in one window.  
4. Pick a maintenance window / rollback owner.

---

## 10. Parked, not scoped: shared-global vs per-tenant identity

Today all six identities are single, global, Prodeo-wide service accounts — there's exactly one `pop-im-service@...` account regardless of which Tenant's data POP is acting on, because POP/SOP/IM are single-tenant-per-deployment today (`POP_GL_ENGINE_TENANT_ID`/`IM_EA_TENANT_ID` etc. are fixed per deployment, confirmed while building the §2.4 membership-check rollout). Once FiSH is genuinely multi-tenant, a shared global service identity across every tenant's own module mesh becomes a design smell in its own right — Tenant X's POP calling Tenant X's IM arguably wants an identity scoped to that Tenant, not one platform-wide account standing in for every tenant at once. That's a bigger structural change than this cutover and is explicitly out of scope here — noted so it isn't lost, not scoped further.
