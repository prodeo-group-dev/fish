# FiSH — Service-to-service identity & EA membership (design note)

**Version:** 1.7  
**Date:** 2026-09-16  
**Status:** Product decision recorded; Option B is **permanent** (runtime since a022435; KDoc rewritten IM@`2daea8a` / `3b4952b`; doc pointer from IM `VerifiedIdentity` to this file committed IM@`0fa0be9`). Cognito `@theprodeogroup.com` SA emails remain technical debt — plan separately before any live identity change.  
**Audience:** Engineering / security / ops  
**Related:** IM `VerifiedIdentity.isServiceAccount`, `ImMembershipAuthorizer`, `Auth.kt` (PERMANENT bypass KDoc); terraform `pop_service_account.tf` / `sop_im_service_account.tf` (and sibling `*-service@theprodeogroup.com` defaults); EA tenancy (per-tenant Membership); `docs/POP_GL_Service_Account_Closure_Plan.md` (POP→GL SA pattern — identity shape only).

---

## 0. Ownership vs runtime (read this first)

| Fact | Meaning |
|------|---------|
| **Prodeo Group / Prodeo Capital owns FiSH** | Product, platform, and operator of the software. |
| **FiSH is multi-tenant GLaaS** | General Ledger as a Service — each tenant is a separate business using the platform. **FiSH will be trademarked.** It is presented as **GLaaS** (General Ledger as a Service), not merely SaaS. **GLaaS** is a term Prodeo developed. |
| **GLaaS includes SOP–IM–POP (and peers)** | Operational modules that must interact for real work (receipts, issues, sales/purchase flows, etc.). |

**Critical distinction:** ownership of the *product* is not the same as being a *party on every service call*.

SOP ↔ IM ↔ POP must make **service-to-service calls without calling on the Prodeo Group** — i.e. without Prodeo mailbox identities, without Prodeo staff Membership in tenant EA, and without treating Prodeo as the actor inside a tenant’s inventory/sales/purchasing path. The platform is owned by Prodeo; the **in-tenant module mesh runs as FiSH GLaaS plumbing**, not as “ask / act as Prodeo.”

EA still authorises **human** users of each tenant. That is the business owner’s control plane, not a Prodeo interjection into SOP–IM–POP.

---

## 1. Decision (summary)

| Topic | Decision |
|--------|----------|
| **SOP ↔ IM ↔ POP (module-to-module) traffic** | Must be **seamless** — direct S2S. **No calling on Prodeo Group** as actor; **no EA membership** hop on the M2M path. |
| Human callers into IM (and similarly gated services) | **Must** pass EA membership (fail-closed). Each tenant’s business owner owns their own EA. |
| POP/SOP → IM machine callers (`isServiceAccount`) | **Permanent bypass** of EA membership checks (**Option B**). Not interim. |
| Provision `pop-im-service@…` / `sop-im-service@…` as EA Users | **Must not.** Absence from `ea_production` is correct, not a gap. |
| `@theprodeogroup.com` Cognito service-account emails | **Wrong for multi-tenant GLaaS.** Implies calling on / acting as Prodeo inside a tenant. Longer-term: non-mailbox / opaque technical principals. |

---

## 2. Guiding principles

1. **Prodeo owns FiSH** (Prodeo Group / Prodeo Capital).  
2. **FiSH will be trademarked** and presented as multi-tenant **GLaaS** (not merely SaaS); GLaaS is a Prodeo-developed term.  
3. **Within GLaaS, SOP–IM–POP interactions must be able to make service-to-service calls without calling on the Prodeo Group.**  
4. **No third-party interjection on that path** — not EA as membership broker for machines, not Prodeo-as-principal.  
5. **EA authorises people** for this tenant’s modules; it is not a hop on SOP↔IM↔POP.

Trust for M2M is deployment-configured between the services (authenticated service credentials / audiences), not “Prodeo is on the team” and not “ask EA whether this machine is staff.”

---

## 3. Context (how we got here)

FiSH is multi-tenant GLaaS; EA is per tenant.

In September 2026, IM gained EA-backed membership authorization for **human** routes (`ImMembershipAuthorizer` → EA `GET /api/me`, fail-closed 503 if EA unreachable). POP/SOP call IM with Cognito service-account JWTs. Forcing those machines through EA (or branding them as `@theprodeogroup.com` actors) would mean **calling on Prodeo / EA on every goods-receipt / goods-issue** — the opposite of seamless GLaaS module communication. `isServiceAccount` bypass keeps that path direct.

Early ops framing: **(A)** create EA Users + Memberships for those emails and remove the bypass, or **(B)** permanent bypass. **A rejected; B is the rule**, grounded in §0–§2.

IM KDoc was first labelled interim (`ff32ebb`), then rewritten to **PERMANENT** with the multi-tenant GLaaS rationale (IM@`2daea8a`, generalized beyond “Prodeo’s own tenant” in IM@`3b4952b`). No behaviour change in those commits — documentation catch-up only.

---

## 4. Why Option A is rejected

1. **Would make EA a third party on SOP–IM–POP** — not seamless S2S.  
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

**Code alignment:** IM `VerifiedIdentity` / `Auth` / EA gateway KDoc already document this as **PERMANENT** (IM@`2daea8a`, `3b4952b`), and `VerifiedIdentity` now cites this design note directly (IM@`0fa0be9`).

---

## 6. Longer-term identity shape

**Debt:** Cognito SA defaults use `@theprodeogroup.com` emails (`message_action = SUPPRESS`). That still reads as calling on Prodeo.

**Target:** opaque technical principals for GLaaS M2M — platform plumbing owned *as infrastructure of FiSH*, without Prodeo mailbox identity and without EA User rows. Humans stay Cognito + EA Membership.

---

## 7. What stays in place today

- Human IM routes: EA membership authorize (shipped).  
- POP/SOP → IM: service JWT + **permanent** membership bypass (runtime **and** KDoc — IM@`2daea8a` / `3b4952b`).  
- FiSH chat (EA + WEB): human communication.  
- Temporary `claude-readonly` IAM: walk back after production go-live (separate).

---

## 8. Explicit non-goals

- Seeding EA Users for POP/SOP IM service emails.  
- Removing SA bypass so M2M must call EA.  
- Long-term M2M identity = Prodeo Group email.  
- Any approval hop that makes SOP↔IM↔POP “call on” Prodeo or EA for routine postings.

---

## 9. Follow-ups

1. **Done:** IM KDoc Option B rewrite (IM@`2daea8a` / `3b4952b`) + explicit pointer from `VerifiedIdentity` to this design note (IM@`0fa0be9`). Optional, still open: same one-liner pointer on `Auth`'s own `authorizeIm` KDoc, which currently only cross-references `VerifiedIdentity.isServiceAccount`, not this file directly.  
2. Replace `@theprodeogroup.com` SA principals in terraform with opaque M2M identities — **live production identity change; scope and plan separately before touching.** Scoped in `docs/Service_Account_Principal_Cutover_Scope.md` — surfaces that this only holds "no EA row needed" for the two IM-bound pairs; the four GL-bound pairs need a further decision (does GL's own gate adopt Option B too?) before they can move.  
3. **Done:** GLaaS wording throughout IM `VerifiedIdentity.kt` (confirmed IM@`3b4952b` - no remaining "SaaS" reference in the file).  
4. When redesigning M2M, update this note with mechanism + migrate runbook.

