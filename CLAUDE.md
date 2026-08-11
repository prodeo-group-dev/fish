# FiSH

FiSH (Financial [Information] Systems Handler) is the shared General Ledger (GL) Engine platform underlying four related ventures: **Purse** (a Christian credit union — UK, Northern Ireland, Republic of Ireland, and a Sierra Leone agrifinance play), **Scrip** (Purse's treasury/investment arm, in Rust), **Osusu** (rotating-savings/micro-lending run through Purse, in Kotlin), and **BuzzMe** (a not-yet-scoped Mano River e-money concept). The GL Engine is also offered as a standalone B2B ledger/SaaS product to any company, with a go-to-market emphasis on the Mano River region (Sierra Leone, Liberia, Guinea, Côte d'Ivoire).

## Read these first

- `FiSH_GL_Engine_Spec.docx` — requirements/spec (v0.7 as of 2026-08-11). Business context, scope, functional/non-functional requirements, data model, open questions.
- `docs/DDD_Design.md` — the DDD model: ubiquitous language, bounded contexts, aggregates, package structure, first TDD test specifications.
- `docs/SL/FiSH_GL_Business_Plan.md` — Sierra Leone business plan (the market-facing wedge).
- `docs/UK/` — UK credit union business plans and the ethical/theological lending framework (source of the APR ceilings, arrears process, and prohibited-purpose rules referenced in the spec).
- `FiSH_GL_Comparative_Analysis.docx` — how the SL business plan and the Engine Spec relate (market-first vs. architecture-first).

## Current code state (2026-08-11, updated same day)

`GL/` is now a working Gradle Kotlin project (`build.gradle.kts`, `settings.gradle.kts`, wrapper — Kotlin 2.2.0, Gradle 8.10, JDK 21). `com.theprodeogroup.fish.domain.common` has 14 files under `src/main/kotlin/...` — value objects and enums only (`AuditAction`, `ClientType`, `PostingStatus`, `PeriodStatus`, `PeriodType`, `JournalSource`, `TransactionSide`, `DimensionType`, `FieldChange`, `ExportFormat`, `OrderBy`, `PaginatedResult`, `RequestContext`, `ValidationResult`, `DomainEvent`). `field_change.kt` is fixed (was truncated mid-declaration).

The first aggregate now exists: `com.theprodeogroup.fish.domain.tenancy.Tenant`, built ahead of the Ledger aggregates (Money/Account/Period/JournalEntry are still unbuilt) per explicit user direction, with `TenantStatus`/`TenantSegment`/`KybStatus`/`TenantId`/`CompanyId`/`MembershipId`/domain events alongside it. 27 tests pass (`gradle test`). See `docs/DDD_Design.md` Section 9 for the design and Section 9.6 for exactly what's built vs. not (no `OnboardTenantUseCase`/application layer yet, no `Company`/`User`/`Membership` aggregates, no persistence).

A prior attempt (in a separate, now-treated-as-lost chat) proposed splitting into ~47 files across 9 packages and only got partway through before creating duplicates. **Don't repeat that** — group related small value objects/enums in one package (as `common` already does) and only split further when a cluster of related types genuinely grows large.

## Conventions to follow

- **DDD**: see `docs/DDD_Design.md` for bounded contexts (Ledger = core domain; Tenancy, Lending, Tax = supporting) and aggregate boundaries. Ledger stays generic — Purse-specific rules (APR ceilings, arrears workflow, common-bond onboarding) live in the Lending context and depend on Ledger, never the reverse.
- **TDD**: write the test first. Recommended build order for the core Ledger aggregates: `Money` → `Account` → `Period` → `JournalEntry` (each depends on the previous). Test specs for these are already written given/when/then in `docs/DDD_Design.md` Section 6.
- **Testing stack**: not yet finalized — the default recommendation on the table is JUnit5 + Kotest assertions + MockK.
- **State machines**: encode transition rules inside the value type itself (see `PostingStatus.canTransitionTo()`, `PeriodStatus.isValidTransition()`), not scattered across services.
- **Validation**: return `ValidationResult` (existing `success()/failure()/withWarnings()/combine()` pattern) rather than throwing for expected domain-rule violations.
- **Money**: always amount + currency together, never a bare number — this doesn't exist in the codebase yet and should be built before `JournalLine`.
- **IDs**: prefer typed ID wrappers (`@JvmInline value class`) over raw `UUID` once aggregates are built, so the compiler catches an `AccountId` passed where a `TenantId` is expected.

## Known environment constraint

The Cowork sandbox this project has mostly been worked in has no Kotlin compiler, no Gradle, and blocks network access to Maven Central / Gradle services / JetBrains downloads. Actual compilation and test execution needs to happen in an environment with real tooling (local machine, or a Claude Code session) — designs and code written in Cowork sessions should be treated as unverified until run there.

**This machine (the `GL/` local checkout) is not that sandbox** — it has Kotlin, Gradle, and JDK 21 installed with working internet access, confirmed 2026-08-11 by actually running `gradle test`. Code built here (starting with `Tenant`) is real and verified, not a design-only artifact — don't apply the "treat as unverified" caveat to it.
