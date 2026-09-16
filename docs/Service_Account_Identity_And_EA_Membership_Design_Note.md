# FiSH — Service-to-service identity & EA membership (design note)

**Version:** 1.8  
**Date:** 2026-09-16  
**Status:** Product decision recorded; Option B is **permanent for all six service-account call paths, not just POP/SOP→IM.** IM: runtime since `a022435`, KDoc rewritten IM@`2daea8a` / `3b4952b`, doc pointer IM@`0fa0be9`. **GL now also adopts Option B for its own four service callers (SOP/IM/HR/POP → GL)**, closing the fork the cutover scope doc's §4.1 raised — `GL@d376f66`. Cognito `@theprodeogroup.com` SA emails remain technical debt — plan separately before any live identity change; `pop-gl-service@theprodeogroup.com`'s EA Membership row is now unnecessary but not yet retired (held for the cutover epic's own WP4, not bundled into the code change).  
**Audience:** Engineering / security / ops  
**Related:** IM `VerifiedIdentity.isServiceAccount`, `ImMembershipAuthorizer`, `Auth.kt` (PERMANENT bypass KDoc); GL `AuthenticatedCaller.isServiceAccount`, `authorizeTenant` (same shape, `GL@d376f66`); terraform `pop_service_account.tf` / `sop_im_service_account.tf` / `pop_gl_service_account.tf` / `sop_service_account.tf` / `im_service_account.tf` / `hr_service_account.tf` (all six `*-service@theprodeogroup.com` defaults); EA tenancy (per-tenant Membership); `docs/POP_GL_Service_Account_Closure_Plan.md` (POP→GL SA pattern — identity shape only, its EA-Membership requirement is what GL's own Option B adoption now supersedes); `docs/Service_Account_Principal_Cutover_Scope.md` (identity-shape/terraform follow-through).

---

## 0. Ownership vs runtime (read this first)

| Fact | Meaning |
|------|---------|
| **Prodeo Group / Prodeo Capital owns FiSH** | Product, platform, and operator of the software. |
| **FiSH is multi-tenant GLaaS** | General Ledger as a Service — each tenant is a separate business using the platform. **FiSH will be trademarked.** It is presented as **GLaaS** (General Ledger as a Service), not merely SaaS. **GLaaS** is a term Prodeo developed. |
| **GLaaS includes SOP–IM–POP–GL (and peers)** | Operational modules that must interact for real work (receipts, issues, sales/purchase flows, ledger postings, etc.). |

**Critical distinction:** ownership of the *product* is not the same as being a *party on every service call*.

SOP ↔ IM ↔ POP ↔ GL must make **service-to-service calls without calling on the Prodeo Group** — i.e. without Prodeo mailbox identities, without Prodeo staff Membership in tenant EA, and without treating Prodeo as the actor inside a tenant’s inventory/sales/purchasing/ledger path. The platform is owned by Prodeo; the **in-tenant module mesh runs as FiSH GLaaS plumbing**, not as “ask / act as Prodeo.”

EA still authorises **human** users of each tenant. That is the business owner’s control plane, not a Prodeo interjection into SOP–IM–POP–GL.

---

## 1. Decision (summary)

| Topic | Decision |
|--------|----------|
| **SOP ↔ IM ↔ POP ↔ GL (module-to-module) traffic** | Must be **seamless** — direct S2S. **No calling on Prodeo Group** as actor; **no EA membership** hop on the M2M path. |
| Human callers into IM/GL (and similarly gated services) | **Must** pass EA membership (fail-closed). Each tenant’s business owner owns their own EA. |
| POP/SOP → IM machine callers (`isServiceAccount`) | **Permanent bypass** of EA membership checks (**Option B**). Not interim. |
| SOP/IM/HR/POP → GL machine callers (`AuthenticatedCaller.isServiceAccount`) | **Permanent bypass**, same Option B, adopted `GL@d376f66`. GL is no longer a third case — all six pairs are now on the same rule. |
| Provision `pop-im-service@…` / `sop-im-service@…` / `pop-gl-service@…` / etc. as EA Users | **Must not** (going forward). `pop-gl-service@…`'s existing EA Membership row predates this decision and is now dead weight, not a model to replicate — retire it as part of the identity cutover, not keep it. |
| `@theprodeogroup.com` Cognito service-account emails | **Wrong for multi-tenant GLaaS.** Implies calling on / acting as Prodeo inside a tenant. Longer-term: non-mailbox / opaque technical principals. |

---

## 2. Guiding principles

1. **Prodeo owns FiSH** (Prodeo Group / Prodeo Capital).  
2. **FiSH will be trademarked** and presented as multi-tenant **GLaaS** (not merely SaaS); GLaaS is a Prodeo-developed term.  
3. **Within GLaaS, SOP–IM–POP–GL interactions must be able to make service-to-service calls without calling on the Prodeo Group.**  
4. **No third-party interjection on that path** — not EA as membership broker for machines, not Prodeo-as-principal.  
5. **EA authorises people** for this tenant’s modules; it is not a hop on SOP↔IM↔POP↔GL.

Trust for M2M is deployment-configured between the services (authenticated service credentials / audiences), not “Prodeo is on the team” and not “ask EA whether this machine is staff.”

---

## 3. Context (how we got here)

FiSH is multi-tenant GLaaS; EA is per tenant.

In September 2026, IM gained EA-backed membership authorization for **human** routes (`ImMembershipAuthorizer` → EA `GET /api/me`, fail-closed 503 if EA unreachable). POP/SOP call IM with Cognito service-account JWTs. Forcing those machines through EA (or branding them as `@theprodeogroup.com` actors) would mean **calling on Prodeo / EA on every goods-receipt / goods-issue** — the opposite of seamless GLaaS module communication. `isServiceAccount` bypass keeps that path direct.

Early ops framing: **(A)** create EA Users + Memberships for those emails and remove the bypass, or **(B)** permanent bypass. **A rejected; B is the rule**, grounded in §0–§2.

IM KDoc was first labelled interim (`ff32ebb`), then rewritten to **PERMANENT** with the multi-tenant GLaaS rationale (IM@`2daea8a`, generalized beyond “Prodeo’s own tenant” in IM@`3b4952b`). No behaviour change in those commits — documentation catch-up only.

---

## 4. Why Option A is rejected

1. **Would make EA a third party on SOP–IM–POP–GL** — not seamless S2S.  
2. **Would “call on” Prodeo** if those principals are Prodeo mailboxes / Prodeo-shaped EA users.  
3. **Wrong ownership of EA.** Memberships belong to the **tenant’s** people, not platform machines.  
4. **Wrong human channel.** Tenant↔operator contact is **FiSH chat**, not Prodeo emails as pseudo-users of every tenant.

Do **not** provision those service emails into EA. Absence from `ea_production` is **expected**.

---

## 5. Option B — permanent rule (normative)

1. JWT validation proves a configured **service** audience (POP or SOP app client).  
2. If `isServiceAccount == true`, **skip** EA membership — no EA round-trip on M2M.  
3. If human, **always** enforce EA membership, fail-closed.  
4. Lasting rule aligned with §0–§2 (not a bridge pending EA rows).  
5. Audit: machine trust = **service-to-service**, not tenant EA, not Prodeo-as-tenant-actor.

**Code alignment:** IM `VerifiedIdentity` / `Auth` / EA gateway KDoc already document this as **PERMANENT** (IM@`2daea8a`, `3b4952b`), and `VerifiedIdentity` now cites this design note directly (IM@`0fa0be9`). GL's own `AuthenticatedCaller`/`Auth.kt` now carry the identical shape for its four service callers (`GL@d376f66`) — same `isServiceAccount` flag, same unconditional bypass ahead of any EA lookup, same fail-closed-for-humans-only framing.

---

## 6. Longer-term identity shape

**Debt:** Cognito SA defaults use `@theprodeogroup.com` emails (`message_action = SUPPRESS`). That still reads as calling on Prodeo.

**Target:** opaque technical principals for GLaaS M2M — platform plumbing owned *as infrastructure of FiSH*, without Prodeo mailbox identity and without EA User rows. Humans stay Cognito + EA Membership.

---

## 7. What stays in place today

- Human IM/GL routes: EA membership authorize (shipped).  
- POP/SOP → IM: service JWT + **permanent** membership bypass (runtime **and** KDoc — IM@`2daea8a` / `3b4952b`).  
- SOP/IM/HR/POP → GL: service JWT + **permanent** membership bypass (runtime **and** KDoc — `GL@d376f66`).  
- FiSH chat (EA + WEB): human communication.  
- Temporary `claude-readonly` IAM: walk back after production go-live (separate).  
- `pop-gl-service@theprodeogroup.com`'s EA Membership row: still exists in `ea_production`, now unnecessary, not yet retired — see cutover scope WP4.

---

## 8. Explicit non-goals

- Seeding EA Users for POP/SOP IM service emails.  
- Removing SA bypass so M2M must call EA.  
- Long-term M2M identity = Prodeo Group email.  
- Any approval hop that makes SOP↔IM↔POP↔GL “call on” Prodeo or EA for routine postings.

---

## 9. Follow-ups

1. **Done:** IM KDoc Option B rewrite (IM@`2daea8a` / `3b4952b`) + explicit pointer from `VerifiedIdentity` to this design note (IM@`0fa0be9`). Optional, still open: same one-liner pointer on `Auth`'s own `authorizeIm` KDoc, which currently only cross-references `VerifiedIdentity.isServiceAccount`, not this file directly.  
2. Replace `@theprodeogroup.com` SA principals in terraform with opaque M2M identities — **live production identity change; scope and plan separately before touching.** Scoped in `docs/Service_Account_Principal_Cutover_Scope.md`. **§4.1's blocking decision is now resolved** — GL adopted Option B (`GL@d376f66`), so all six pairs are on the same footing; remaining work is the identity-shape cutover itself (§4 A/B/C) plus retiring `pop-gl-service@theprodeogroup.com`'s now-unnecessary EA Membership row (WP4), not a further architecture decision.  
3. **Done:** GLaaS wording throughout IM `VerifiedIdentity.kt` (confirmed IM@`3b4952b` - no remaining "SaaS" reference in the file).  
4. When redesigning M2M, update this note with mechanism + migrate runbook.

