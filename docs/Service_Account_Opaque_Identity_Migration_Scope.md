# Replacing `@theprodeogroup.com` service-account identities — migration scope

**Status:** scoping only — nothing in this document has been implemented. No terraform or Cognito resource has been touched.
**Related:** `docs/Service_Account_Identity_And_EA_Membership_Design_Note.md` (the policy decision this scopes the follow-through for — §6 "Longer-term identity shape," §9 Follow-up #2).

---

## 1. Full inventory (not just the two the design note names)

The design note's Option B discussion centers on POP/SOP→IM specifically, but "replace `@theprodeogroup.com` SA principals in terraform" (Follow-up #2) is broader. There are **six** service-account Cognito identities in `GL/infra/terraform/`, all shaped the same way (`aws_cognito_user`, `message_action = "SUPPRESS"`, a `*.theprodeogroup.com` email as the username):

| # | Terraform file / resource | Identity | Caller → Callee | Does the callee check EA Membership for this caller today? |
|---|---|---|---|---|
| 1 | `pop_service_account.tf` / `pop_im_service` | `pop-im-service@theprodeogroup.com` | POP → IM | **No** — explicit permanent bypass (`VerifiedIdentity.isServiceAccount`, design note Option B) |
| 2 | `sop_im_service_account.tf` / `sop_im_service` | `sop-im-service@theprodeogroup.com` | SOP → IM | **No** — same bypass |
| 3 | `pop_gl_service_account.tf` / `pop_gl_service` | `pop-gl-service@theprodeogroup.com` | POP → GL | **Yes** — a real EA User + Membership was provisioned and verified end-to-end (`docs/POP_GL_Service_Account_Closure_Plan.md`, 2026-09-03) |
| 4 | `sop_service_account.tf` / `sop_service` | `sop-service@theprodeogroup.com` | SOP → GL | Yes, architecturally — GL's `installFishJwtAuth` passes the *same* `eaMembershipGateway` for every named JWT provider, human and service alike (`GL/Auth.kt`), so this caller is resolved through EA's `/me` just like a human. Whether the actual EA row exists was never verified this session. |
| 5 | `im_service_account.tf` / `im_service` | `im-service@theprodeogroup.com` | IM → GL | Same as #4 — architecturally EA-checked by GL, row existence unverified |
| 6 | `hr_service_account.tf` / `hr_service` | `hr-service@theprodeogroup.com` | HR → GL | Same as #4 — architecturally EA-checked by GL, row existence unverified |

## 2. The fork this scoping surfaces — needs a decision before any code changes

Rows 1–2 and rows 3–6 are on **opposite sides of the exact policy question the design note just settled for IM**:

- **IM's own gate (rows 1–2):** module-to-module calls permanently bypass EA. Settled, shipped, documented.
- **GL's own gate (rows 3–6):** every caller — including these four service accounts — is resolved through EA's `Tenant`/`Membership` model, the same code path a human uses. Row 3 already has a real EA User provisioned specifically so that check passes. This is architecturally the same shape as "Option A," which the design note rejected for IM.

That means "replace the `@theprodeogroup.com` principals with opaque technical ones" is not one migration, it's two different ones depending on the answer to:

> **Should GL's own service-to-service gate also move to Option B (bypass EA, trust the Cognito service audience directly), or does GL deliberately stay on the EA-Membership model for its callers (e.g., because GL is the ledger of record and wants every posting traceable to a real, audited identity)?**

- **If GL adopts Option B too:** rows 3–6 become a pure identity-shape change (same as rows 1–2) — new opaque Cognito identity, no EA row needed, `GL/Auth.kt` gets its own `isServiceAccount`-equivalent bypass. A real code change to GL, not just a terraform rename.
- **If GL stays on the EA-Membership model:** rows 3–6 can only change *shape* (drop the mailbox-like username), not *mechanism* — the new opaque identity still needs an EA User + Membership row, so the practical work is "rename POP's/SOP's/IM's/HR's existing EA rows to something non-mailbox-shaped," not "remove EA from the path."

This is a real fork, not a detail — I'm not picking one. Flagging it here rather than guessing, per this project's own "park, don't guess" convention.

## 3. What "opaque technical principal" concretely means, independent of §2

Today: a Cognito user whose `username` is a plausible email address at Prodeo's own domain — the exact thing the design note objects to ("implies calling on / acting as Prodeo"). Target, per the design note's §6: an identity that doesn't read as a Prodeo mailbox at all — e.g., a UUID-shaped username, or (once genuine multi-tenancy exists) a per-tenant-scoped technical identifier.

**A second question this raises, also unresolved:** today every one of these six identities is a single, global, Prodeo-wide service account — there's exactly one `pop-im-service@...` regardless of which Tenant's data POP is acting on, because POP/SOP/IM are single-tenant-per-deployment today (confirmed while building the §2.4 membership-check rollout — `POP_GL_ENGINE_TENANT_ID`/`IM_EA_TENANT_ID` etc. are fixed per deployment, not per-request). Once FiSH is genuinely multi-tenant, a shared global service identity across every tenant's own module mesh is itself a design smell — Tenant X's POP calling Tenant X's IM should arguably use an identity scoped to that Tenant, not one shared platform-wide account standing in for every tenant at once. That's a bigger structural change than a naming migration and is explicitly **out of scope** for this pass — noted so it isn't lost, not scoped further here.

## 4. Blast radius / why this can't be a single terraform apply

- Cognito usernames are immutable once created — this is create-new-identity-and-cut-over, not an in-place rename.
- Each of the six pairs has its own app client, secret rotation (Secrets Manager), and ECS task-definition env vars (`*_SERVICE_ACCOUNT_CLIENT_ID/SECRET/USERNAME/PASSWORD`) that all need to move together for that one caller, or its calls start failing.
- Six identities × (new Cognito user, new app client, new secrets, new env vars in the relevant ECS task def, verify the real caller re-authenticates) is real, multi-step, per-pair work — not a bulk change.
- Getting any single pair wrong breaks live traffic on that path immediately (goods-receipt/issue postings for IM's two, ledger postings for GL's four).

## 5. Proposed sequencing (once §2 is answered)

1. Resolve §2 (GL's own posture) — this gates whether rows 3–6 need a `GL/Auth.kt` code change or just an identity rename.
2. Pilot the new identity *shape* on one pair first — recommend **POP→IM** (`pop-im-service`), since it's already fully EA-bypassed with zero EA-side coordination needed, making it the cleanest test of the new identity format alone, decoupled from §2's answer.
3. Provision the new opaque identity + Cognito app client **alongside** the old one (don't delete `pop-im-service@theprodeogroup.com` yet).
4. Cut IM's `IM_JWT_SERVICE_AUDIENCE_POP` verifier to trust the new app client (can accept both old and new during the transition, same pattern `buildJwksServiceVerifierForPop()` already uses for "unconfigured caller" tolerance).
5. Update POP's own outbound `POP_IM_SERVICE_ACCOUNT_*` credentials to the new identity, redeploy, verify a real goods-receipt call still authenticates end-to-end.
6. Decommission the old Cognito user only after the new one is proven live in production.
7. Repeat for `sop-im-service`, then — pending §2's answer — the four GL-calling identities, each as its own pass, not bundled.

## 6. Explicit non-goals for this scoping pass

- No terraform, Cognito, or application code changed by this document.
- Not deciding §2 (GL's posture) — flagged for the user to decide.
- Not deciding the exact opaque-identity format (UUID username vs. per-tenant-scoped vs. other) — follows from §2.
- Not addressing §3's per-tenant service-identity question — noted, not scoped.
