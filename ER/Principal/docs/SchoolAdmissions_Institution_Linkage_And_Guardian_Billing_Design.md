# SchoolAdmissions ↔ FiSH institution linkage, and Guardian-as-Customer

**Status:** design confirmed, 2026-09-22. **Item 1's SchoolAdmissions side
is built, tested (3x real-Postgres rerun), and live on `master`**
(`fish-school-admissions` `57ad955`) — `School` aggregate, idempotent
`POST /schools`, new EA service-account trust
(`buildJwksServiceVerifierForEa`, `requireServiceAccount`). **EA's own
side is not built yet** — proposed to the live "Enterprise Administration
- EA" peer session; that session is independently verifying the
Organisation/Company taxonomy decision with Femi directly before
committing to field naming or new Terraform/Cognito work, rather than
building on a relayed confirmation (the right call — flag, don't just
trust a second-hand relay for something with platform-wide reach). Not
deployed to production yet either: `SCHOOLADMISSIONS_JWT_SERVICE_AUDIENCE_EA`
has no value in the real task definition until EA's Cognito app client
exists. Item 2 (Guardian → SOP Customer) is designed and sequenced next —
correctly *after* item 1 fully lands (both sides), not parallel to it
(see "Why sequencing matters" below).

**Origin:** relayed via FiSH+ER WEB, from a direct instruction while building
the Student Management Console's first slice (student roster, calling
`GET /schools/{schoolId}/students`). Two real backend gaps surfaced: no
stored link between a FiSH institution and a SchoolAdmissions School, and
`Guardian` has no standalone identity to bill against.

## A terminology note first

Femi's own correction, same day: **"Company" is too narrow — every
organisation regardless of size or turnover needs Financial Information
Systems Handling, so "FiSH institution" or "organisation" is the better
frame.** Checked before writing anything else: `Company`/`CompanyId` is a
genuinely deep, live domain term — 250+ files across at least
GL/EA/SOP/POP/IM/HR/WEB reference it directly. This doc uses "institution"
in prose throughout, matching the intended framing, but does **not**
rename the actual `Company` domain class/table/API shape anywhere — that
would be a separate, deliberate, platform-wide rename decision, not
something to fold silently into this feature. Flagged back to Femi rather
than either ignored or done unilaterally.

**Sharpened further, same session: "A school is a type of organisation"
too** — parallel to the Company statement. Read together: `Organisation`
is the umbrella; `Company` and `School` are **siblings under it**, not
School-subordinate-to-Company. This changes one concrete naming choice
below: the School aggregate's linking field is `organisationId`, not
`companyId` — the field shouldn't silently bake in a hierarchy the
taxonomy correction just ruled out. The underlying mechanic is unchanged:
SchoolAdmissions is still a genuinely separate bounded context/service
(deliberate architecture, matching Scrip/Osusu/Lending's own separation),
so it still needs to store *some* cross-service reference to its
counterpart record in EA — only the field's name and conceptual framing
change, not whether the reference exists. What that reference actually
points to today is still EA's existing `Company` row (the broader
`Organisation` aggregate doesn't exist as its own EA entity yet — that's
the platform-wide rename decision above, still unmade) — `organisationId`
names the *relationship*, `Company` is still the concrete thing it
resolves to for now.

## Decision 1: institution ↔ School linkage

**Confirmed: EA provisions SchoolAdmissions automatically.** When an
institution's `industryType == SCHOOL` (already a real, closed EA field per
`docs/Industry_Type_Module_Enablement_Design.md`'s Phase 1), EA's
`RegisterCompanyUseCase` calls a new SchoolAdmissions provisioning
endpoint to create the real `School`, using a new Cognito service-account
trust — mirroring the proven POP→IM/SOP→IM/HR→GL pattern (see
`docs/POP_GL_Service_Account_Closure_Plan.md` as the worked example).

**One correction to the source design doc before building on it**: it
says SchoolAdmissions has "no real authentication (only
`StubErIdentityGateway`)" — stale. Real Cognito JWT auth
(`CognitoErIdentityGateway`, `StaffAssignment`, `SCHOOLADMISSIONS_AUTH_MODE`
defaulting to `cognito` in production) has been live since before this
session started. The EA→SchoolAdmissions service-account leg is buildable
now, not blocked on auth infrastructure.

### What SchoolAdmissions needs (this session's own side, building now)

- New `domain/platform/School` aggregate — today `SchoolId` is used as an
  implicit tenant key across every record, but nothing stores a School as
  an entity in its own right (name, `organisationId`/`tenantId` it's
  linked to — see the naming note above, provisioned-at timestamp).
  `schools` table, `SchoolStore` additions.
- New `POST /schools` provisioning endpoint, gated by a new
  `DEVICE_ATTENDANCE_CAPTURE_ROLE`-style narrow service-account role
  (e.g. `EA_PROVISIONING_ROLE`), accepting `{organisationId, tenantId, name}`,
  idempotent on `organisationId` (EA retrying a failed registration call
  must not create two Schools for one institution).
- A new named JWT verifier in `CognitoErIdentityGateway`/`Auth.kt` for the
  EA service-account audience, alongside the existing DPID one — same
  shape, different audience.

### What EA needs (that session's own repo/thread — coordinating, not building here)

- `RegisterCompanyUseCase` (or wherever `industryType` is actually
  finalized in EA's flow — worth confirming with that session, not
  assumed here) calls the new endpoint when `industryType == SCHOOL`.
- A new Cognito app client + Terraform (`ea_schooladmissions_service_account.tf`
  in `fish-infrastructure`), a new `FISH_JWT_SERVICE_AUTH_NAME_EA`-style
  provider entry.
- Decide what happens on failure — EA's own `RegisterCompanyUseCase` KDoc
  already flags "cross-system onboarding orchestration is explicitly out
  of scope this pass" for the GL↔EA leg; this is a third leg on top of
  that already-deferred one, so the failure-handling answer isn't free to
  assume symmetric with the other two.

Proposed to the live "Enterprise Administration - EA" session directly;
building the SchoolAdmissions side now regardless, since it's useful
(and testable) standalone.

## Decision 2: Guardian as Customer

Femi's own framing, direct quote: **"a Guardian is equivalent to a
Customer. The service provided by a school is to TEACH his wards. It is a
contract the school has to fulfil."** — the school's actual deliverable
under contract is teaching the enrolled student (the ward); the Guardian
is who that contract runs to, and who pays. Confirmed against real SOP
code before committing to this shape, not assumed:

- SOP's `Customer` (`domain/salesorder/customer.kt`) is a lean "buyer
  master record" — `name`, `entityId` (scoping UUID — the paying
  institution), `creditTerms` (required), plus `facilityId`/
  `avalArrangement` (both optional, trade-finance-specific, naturally
  `null` for a school-fees context). `POST /customers` already exists on
  SOP, gated by a service-account write check. Nothing about this shape
  needs to change for a Guardian to be represented as one — the optional
  fields simply stay unset.
- **`Guardian` today is a bare embedded value object, not an identity.**
  `StudentProfile.guardians: List<Guardian>` has no id and no dedup — a
  guardian with two children at the same school appears as two separate,
  unlinked `Guardian` rows today. Billing rollup (Femi's actual ask, "a
  school's customers are the Guardians") needs a real, shared identity a
  `CustomerId` can attach to, which the current shape can't carry.
- Revenue recognition is already settled (relayed via FiSH+ER WEB):
  immediate-at-enrolment, no deferral — fees are non-refundable past
  cool-off, which is usually 0 days. This matches `RecordSaleUseCase`'s
  existing posting pattern directly; no new GL work implied by this
  decision.

### Why sequencing matters — this is next, not parallel

Creating a real SOP `Customer` needs a real `entityId` to scope it to —
the paying institution. Today SchoolAdmissions has no reliable way to know
which institution a School is linked to (that's precisely decision 1's
gap, `organisationId`). Building Guardian→Customer before decision 1
lands would mean guessing or hardcoding an `entityId`, which this
project's own standing practice (park, don't guess) rules out. **Decision
1 is a genuine prerequisite for decision 2, not just a nice-to-have
ordering.**

### Concrete shape, once decision 1 lands

- `Guardian` gains its own identity — likely promoted out of
  `StudentProfile`'s embedded list into a standalone
  `domain/billing/Guardian` (or similar) aggregate: `id`, `schoolId`,
  `name`, `phone`, `email`, `subjectId?`, `customerId: CustomerId?`
  (null until first billed). `StudentProfile` keeps a `guardianIds: List<String>`
  reference instead of embedding full `Guardian` rows — the real dedup
  fix.
- A new `SchoolStore`/`GuardianStore` method resolves-or-creates a
  `Guardian`, matching an existing one by (schoolId, email-or-phone) when
  re-entering a sibling's guardian on a second child, rather than always
  minting a new one.
- First-billing-event (not enrolment itself, per the immediate-at-
  enrolment revenue rule — likely `FeeService.issueInvoice()`'s own
  moment) calls SOP's `POST /customers` if `customerId` is still null,
  using the School's `organisationId` (decision 1) as SOP's `entityId`,
  then stores the returned `CustomerId` back on the `Guardian`.
- `creditTerms` for a school-fees Guardian: something simple reflecting
  the 0-day cool-off framing (e.g. `"Due on invoice"` or `"N0"`) — not
  yet picked as a literal string, flagged for whoever builds this to
  confirm against SOP's own expected `creditTerms` vocabulary rather than
  inventing one.

**Not built yet** — designed and sequenced behind decision 1. Whoever
picks this up next (likely this same thread, once decision 1 ships)
should re-read `SOP/src/main/kotlin/.../customer.kt` and
`CreateCustomerUseCase.kt` directly rather than trust this doc's summary,
same standing practice as every other cross-system design note in this
project.
