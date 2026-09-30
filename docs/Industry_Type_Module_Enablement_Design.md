# Industry Type → Module Enablement (design-only, EA-owned)

**Date:** 2026-09-20. Requested directly: business setup should ask for an
industry type; selecting "School" brings the Education Runtime (product
name "The Principal's EduSys", formerly SchoolAdmissions — see
`project_fish_er_edusys_roles` memory for the term) into that tenant's
operations; industry type
generally drives which operations-tab elements are required. **Enterprise
Administration (EA) is named as the owner.**

**Not implemented here.** This session is scoped to ER/Education
(`+ER Education`) — EA is explicitly a different thread's repo, per this
session's own recorded [[feedback_commit_boundary_handoff]] and an earlier
incident this same day where an EA-targeted `create-pr-command` was
correctly declined for the same reason. This doc exists so the EA thread
can pick the feature up without re-deriving the grounding below.

## Where this fits in EA's actual current model

Checked directly against `EA/src/main/kotlin` before writing anything down:

- **`ManagedModule`** (`domain/tenancy/managed_module.kt`) is already the
  exact vocabulary for "operations tab elements" — a closed enum
  (`GL, HR, SOP, POP, IM, TAX`) captured during Company setup as
  `ModuleManagementPreference` (self-managed vs. delegated), and reused
  as `Membership.grantedModules`' own vocabulary for per-staff access.
  Adding the Education Runtime as a new module means extending this enum
  — call it `EDUCATION_RUNTIME` pending a better name — not inventing a
  parallel concept.
- **The self-managed/delegated choice doesn't fit an industry-driven
  module.** `ModuleManagementPreference` today always requires an
  explicit owner choice per module. "School selected → Education Runtime
  included" is a different shape: automatic inclusion driven by a
  classification field, not an owner decision to capture. Whatever
  carries `industryType` needs its own rule (e.g. `industryType == SCHOOL`
  implies `ManagedModule.EDUCATION_RUNTIME` is present, possibly without
  ever prompting the owner for a self-managed/delegated choice on it the
  way the other five modules get).
- **`industryType` likely doesn't belong on GL's `Company`, despite the
  surface similarity to `ClientType`.** `Company.clientType` (`ClientType`
  — e.g. `NON_PROFIT` for Purse) is a real accounting classification
  (drives Chart of Accounts template selection). Industry type as
  described here is administrative/orchestration metadata, not an
  accounting fact — closer to `companyName`, which `RegisterCompanyUseCase`
  already stores in EA's own `CompanyNameRepository` specifically because,
  per its own comment, "it is not for GL to handle the administrative
  stuff." The same reasoning point supports treating `industryType` as
  EA's own field, not a new column on GL's `Company` — flagged as the
  likely answer, not settled, since nobody has confirmed it directly.

## The real open gap: Education Runtime has no linkage to EA/GL at all

This is the part worth being explicit about rather than glossing over.
"Operations will also include the Education Runtime" reads as more than a
WEB dashboard tab becoming visible — Education Runtime's own tenancy model
(`SchoolId`, per `ER/Principal/EducationRuntime/src/main/kotlin/.../SchoolId.kt`)
is completely disconnected from EA's `TenantId`/`CompanyId` today: no
foreign key, no provisioning call, nothing. Confirmed directly (this
session built Education Runtime's AWS infrastructure 2026-09-19 and its own
outbound event publisher only writes to its own local outbox table —
no call to any sibling, EA included, exists anywhere in its code).

So "industry type = School → include Education Runtime" has at least two
real components, not one:
1. **The EA-side module-enablement mechanic** described above (adding
   `EDUCATION_RUNTIME` to `ManagedModule`, deciding how it's captured).
2. **Actually provisioning a `SchoolId`/tenant in Education Runtime** for
   that Company when School is selected — a genuine cross-system
   orchestration call that doesn't exist in either direction today.
   `RegisterCompanyUseCase`'s own KDoc already flags "cross-system
   onboarding orchestration is explicitly out of scope this pass" for
   the GL↔EA leg; this would be a third leg (EA→Education Runtime) on top
   of that already-deferred one.

Building (1) without (2) gives a real UI toggle with nothing behind it —
worth deciding explicitly whether this feature ships in two steps (tab
visibility first, real provisioning later) or waits for both, rather than
assuming.

## Open questions, parked rather than guessed

- Is `industryType` a closed enum (School, Retail, Manufacturing, …) or
  free text with School as the one currently-special-cased value?
- Set once at Company creation, or changeable later? If changeable,
  what happens to an already-provisioned Education Runtime tenant if
  School is deselected?
- Does WEB need new per-industry tab-visibility logic, or does this ride
  entirely on the existing `Membership.grantedModules` mechanism once
  `EDUCATION_RUNTIME` is a real `ManagedModule` value?
- Who calls the (currently nonexistent) EA→Education Runtime provisioning
  step, and with what — does Education Runtime need its own inbound
  onboarding endpoint, or does EA's Cognito service-account pattern
  (already proven for POP→IM, SOP→IM, HR→GL, etc.) extend here too?

## Status

**Phase 1 done, 2026-09-20** — built by the EA thread per this doc's own
grounding, see `EA/docs/EA_Development_Backlog.md` item 10 for the full
detail. Answers to this doc's own open questions, as actually decided:

- **Scope**: "both together" was the initial direction, then re-confirmed
  once this doc's own Education Runtime-has-no-auth finding was surfaced
  again at build time — split into two shippable phases instead of one
  combined build. Phase 1 (EA-side module enablement + WEB) is done.
  Phase 2 (Education Runtime `School` aggregate + real Cognito auth + the
  actual EA→Education Runtime provisioning call) is deliberately deferred,
  not scoped further than this doc's own §"the real open gap".
- **`industryType` ownership**: confirmed EA's own field, not GL's, per
  this doc's own reasoning - now `IndustryType` (`domain/tenancy/industry_type.kt`),
  persisted as a third column on EA's existing `company_names` cache.
- **Closed enum vs. free text**: closed enum (`GENERIC`/`SCHOOL` only).
- **Mutable after setup**: no - immutable once set, by decision.
- **WEB tab-visibility**: rides `Membership.grantedModules` entirely, as
  this doc predicted - `EDUCATION_RUNTIME` is a real `ManagedModule` value
  now, and `BusinessOperationsScreen.tsx`'s existing per-module gating
  needed no new mechanism.
- **Who calls Education Runtime provisioning**: still unanswered - that's
  Phase 2, not attempted here.

Phase 2 remains open, with this doc's own "real open gap" section still
the accurate starting point for it: Education Runtime has no `School`
aggregate/table and no real authentication (only `StubErIdentityGateway`),
confirmed unchanged as of Phase 1's build.
