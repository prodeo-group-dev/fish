# POP/IM Shared Authorization Bug: Hardcoded Company Scoping

**Date:** 2026-09-28
**Status:** fixed on both sides, neither yet pushed/deployed. POP: committed (`22b8743`). IM: PR open (https://github.com/prodeo-group-dev/fish-inventory-management/pull/6), 244 tests green, held for go-ahead given it's a live prod auth path.
**Severity:** high — blocks legitimate access, universally, not just for the company that surfaced it.

---

## Symptom

POP's Purchases fulfilment page failed to load under an "Education Runtime" company context for the Prodeo Group tenant, showing a generic frontend error ("Couldn't load the fulfilment page - try again shortly.") — `PurchasesTab.tsx`'s catch-all, which fires on any non-success response including a 403.

## Root cause

EA's 2026-09-23 per-Company RBAC rewrite moved `accessLevel`/`grantedModules` from flat Tenant-wide fields to per-Company (`CallerMembership.companies: List<CompanyAccess>`). GL's own authorization (`GL/.../Auth.kt`'s `authorizeTenant`) was updated correctly: `companyId` is a real parameter, resolved per-request from the URL path (`/companies/{companyId}/...`).

POP's `PopMembershipAuthorizer` and IM's `ImMembershipAuthorizer` were **not** updated correctly — both still take a single `companyId: String` baked in at deploy time (from `POP_GL_ENGINE_COMPANY_ID`/its IM equivalent — Prodeo's own original single company, from back when both services genuinely had only one), and check every request's `membership.accessLevelAt(companyId)`/`membership.grantedModulesAt(companyId)` against that one fixed company, regardless of which company the caller is actually working in. Neither service's route surface even carries a companyId at all (e.g. `GET /purchase-orders/fulfillment` takes none) — this was a deliberate, documented design choice from when both services were genuinely single-company internal tools (`ListPurchaseOrdersForFulfillmentUseCase`'s own KDoc: *"POP is Prodeo Group's own internal trade-finance ops tool... there is effectively one operator"*).

`CallerMembership.grantedModulesAt(companyId)` returns an **empty set** for any company not explicitly in `companies` — including, by its own KDoc, for an Owner-Admin's intrinsic Tenant-wide floor (*"read-only oversight, not module access"*). So any Membership whose POP/IM module grant isn't specifically set at the one hardcoded company gets a silent `403 Forbidden` on every request, regardless of role.

**This is not Education-specific and not POP-specific.** It reproduces identically for any company other than the one each service was deployed with, and for IM the same way — confirmed by direct comparison of `ImMembershipAuthorizer` against `PopMembershipAuthorizer`: identical constructor shape, identical bug.

## Fix applied (both services, 2026-09-28)

The **tactical** option, chosen independently by both sessions without coordinating on the choice itself (only on the diagnosis): stop gating on one hardcoded company — check "does this Membership have POP/IM granted on *any* company" instead. Neither service's own data is company-scoped internally anyway (confirmed: `ListPurchaseOrdersForFulfillmentUseCase.execute()` takes no company filter at all), so a company-specific *authorization* gate was already conceptually questionable independent of this bug.

- **POP**: `PopMembershipAuthorizer` no longer takes a `companyId` constructor parameter at all — `resolve()` now checks `membership.companies.any { accessLevelAt(it.companyId).atLeast(minAccessLevel) && "POP" in grantedModulesAt(it.companyId) }`. New regression test added (grant on a company other than the deployment's own GL company → 200, was 403). Committed `22b8743`, full suite green.
- **IM**: factored the equivalent check into a named `CallerMembership.hasModuleGrantedAnywhere(module, minAccessLevel)` helper rather than an inline check. Own regression test added. PR #6, 244 tests green.

**Not applied**: the "real fix" (thread an actual `companyId` through POP's/IM's routes, WEB's calling code, and each service's own domain queries, matching GL's own corrected pattern) — multi-day scope per service, only worth doing if POP/IM data itself needs to differ per company, which is an open question tracked in `docs/Purchase_Inventory_Sales_Cycle_And_Reversals_Scoping.md` rather than assumed here.

## Coordination

- Full diagnosis sent to the IM session (message, 2026-09-28); IM confirmed the same root cause independently before applying its own fix.
- SOP session messaged to check whether an equivalent `SopMembershipAuthorizer` (if SOP has one) carries the same shape — not yet replied.
- Both fixes are committed but **not pushed or deployed** — holding for the user's go-ahead on each repo, since this is a live production authorization path.
