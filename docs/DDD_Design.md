# FiSH GL Engine — Domain-Driven Design

**Status:** Draft v0.1
**Date:** 2026-08-11
**Companion documents:** `FiSH_GL_Engine_Spec.docx` (requirements), `docs/SL/FiSH_GL_Business_Plan.md`, `docs/UK/*` (business plans)

This document translates the requirements spec into a DDD model: ubiquitous language, bounded contexts, aggregates, and the package structure the codebase should converge on. It also reviews the code that already exists and defines the first TDD test specifications — written as given/when/then cases, ready to become real Kotest/JUnit tests once a working build (Gradle + Kotlin compiler) is available.

**Update (2026-08-11): a Gradle project now exists** (`build.gradle.kts`, `settings.gradle.kts`, wrapper, all in `GL/`), built on a local machine with real Kotlin/Gradle tooling — the Cowork-sandbox constraint in CLAUDE.md no longer applies to this session. The 14 existing `domain.common` files have been moved into `src/main/kotlin/...` and compile. The `Tenant` aggregate (Section 9) is implemented and covered by 27 passing tests (`gradle test`, all green) — it's the first code in this repo that's actually been run, not just designed. Everything else described below (Account, Period, JournalEntry, Money) is still design-only.

---

## 0. Review of Existing Code

As of 2026-08-11, `com.theprodeogroup.fish.domain.common` has 14 files sitting at the FiSH repo root (not yet in a `src/main/kotlin/...` folder structure, no Gradle project wraps them). What's there:

`audit_action.kt`, `client_type.kt`, `dimension_type.kt`, `export_format.kt`, `field_change.kt`, `journal_source.kt`, `order_by.kt`, `paginated_result.kt`, `period_status.kt`, `period_type.kt`, `posting_status.kt`, `request_context.kt`, `transaction_side.kt`, `validation_result.kt`.

**What's good, worth keeping the pattern of:**
- Every type has thorough KDoc — purpose, usage example, sometimes SQL hints. Keep this discipline; it's genuinely useful for a domain this compliance-heavy.
- `PostingStatus.canTransitionTo()` and `PeriodStatus.isValidTransition()` encode state-machine rules *inside* the value type rather than scattering `if` checks across services — good DDD tactical pattern, keep doing this for new state machines (e.g., `ArrearsCase` stage transitions, `EquityStake` status).
- `ValidationResult` with `success()/failure()/withWarnings()/combine()` is a clean Notification pattern — reuse it as the standard return type for domain validation, don't invent a second one.
- `PaginatedResult<T>` and `ExportFormat` are sensible generic/application-layer helpers, correctly kept out of any single aggregate.
- The `common` package itself — grouping small, related value objects/enums into one package rather than one file each — is the right call. **Do not** repeat the mistake from the abandoned prior attempt (47 files across nine packages for a domain this size). Split into a new package only when a cluster of types plus their behaviour becomes genuinely large (roughly 6–10+ files that belong together), not pre-emptively.

**Gaps to fix before/while building the core aggregates:**
1. ~~`field_change.kt` is **incomplete**~~ **Fixed (2026-08-11):** `FieldChange` now has `fieldName: String`, `oldValue: String?`, `newValue: String?`, `fieldType: String`.
2. **No `Ledger`-context aggregates exist yet** (Account, JournalEntry, Period) — `Tenant` (Tenancy context) is now built, see Section 9. Section 3.1 still defines what to build next for Ledger.
3. ~~**No package folder structure.**~~ **Fixed (2026-08-11):** files now live under `src/main/kotlin/com/theprodeogroup/fish/domain/common/`, matching their declared package. A Gradle project wraps them (`GL/build.gradle.kts`).
4. **No `Money` value object.** Nothing here represents an amount-plus-currency pairing. This is the single most important missing piece before `JournalLine` can be written correctly — see Section 3.1.
5. **Typed IDs started, not finished.** `TenantId`/`CompanyId`/`MembershipId` now exist as `@JvmInline value class` (`domain.tenancy.ids.kt`) — `AccountId`, `UserId`, etc. still need the same treatment when their aggregates are built. `RequestContext.clientId`/`userId` are still raw `java.util.UUID`.
6. **`PeriodStatus.isValidTransition(from)`** reads backwards relative to `PostingStatus.canTransitionTo(newStatus)` — one asks "can I go FROM here," the other "can I go TO there." Minor inconsistency; worth aligning both to the same calling convention when this file is next touched, so the ubiquitous language ("can transition to") is uniform.
7. **`RequestContext.sanitize()` is currently a no-op** — the comment says "nothing sensitive here," but `ipAddress` and `userAgent` are commonly PII under GDPR (Section 8.2 of the spec commits to GDPR/ICO compliance). Worth revisiting once logging/audit export is built — `sanitize()` should probably actually redact these for exports that leave the tenant's own audit view.

---

## 1. Ubiquitous Language

| Term | Meaning |
|---|---|
| Tenant | A customer organization using FiSH; the top-level data-isolation boundary. |
| Company | A legal entity within a Tenant. A Tenant may hold several Companies (group structure). |
| Client | A ledger party of a given `ClientType` (Individual, Sole Trader, Partnership, Company Limited, Non-Profit). Purse (credit union) uses `NON_PROFIT` — resolved 2026-08-11, see Section 8. |
| Account | A Chart-of-Accounts entry belonging to a Company: type (Asset/Liability/Equity/Revenue/Expense), code, parent/child hierarchy. |
| Journal Entry | A balanced, atomic set of debit/credit lines posted on a date. The core transactional unit of the ledger. |
| Journal Line | One debit or credit within a Journal Entry, referencing an Account, optionally tagged with `DimensionType` values. |
| Posting | The act of moving a Journal Entry from Draft/Pending to Posted, making it affect account balances and become immutable. |
| Period | A fiscal period (Month/Quarter/Year/Custom) belonging to a Company, with its own open/closed/locked lifecycle. |
| Money | An amount paired with a currency; never a bare number. |
| Audit Log Entry | An immutable record of an `AuditAction` against some entity, with `FieldChange` detail where applicable. |
| Loan Product | Purse-specific: a lending product with an APR ceiling and rate-breakdown components. |
| Arrears Case | Purse-specific: the staged (Early Contact → Pastoral Engagement → Formal Review → Final Resolution) record tracking a struggling loan. |
| Equity Stake | Purse/Scrip-specific: an ownership position arising from capitalizing a company's debt, held toward a turnaround. |
| Tax Rule / Tax Computation | Jurisdiction-specific configuration, and the derived tax-due record computed from a Company's posted ledger data. |

---

## 2. Bounded Contexts

FiSH is one platform but not one undifferentiated blob. Four bounded contexts, one core:

### 2.1 Ledger (core domain)
Double-entry bookkeeping: Chart of Accounts, Journal Entries, Periods, multi-currency, audit trail. This is FiSH's actual differentiator — everything else is built to make this trustworthy and reusable across ventures. Keep this context free of Purse-specific policy (no APR ceilings, no "common bond" fields *inside* Ledger aggregates) — those belong to the Lending context and reference Ledger concepts, not the other way around.

### 2.2 Tenancy & Access (supporting)
Tenant, Company, User, Membership, roles, `RequestContext`. Every other context depends on this for "who is doing this, on behalf of which Company." Necessary, not a differentiator — resist the urge to over-engineer it.

### 2.3 Lending (supporting, Purse-specific)
`LoanProduct`, `ArrearsCase`, `EquityStake`, purpose affirmation, interest-rate ceilings. Consumes Ledger (loans post through it) but owns rules that are specific to Purse's ethical framework, not general-purpose ledger behaviour. Keeping this separate from Ledger is what stops the core engine from silently becoming "a UK credit union's booking system" instead of a generic multi-tenant ledger.

### 2.4 Tax (supporting)
`TaxRule`, `TaxComputation`. Reads Ledger data (posted transactions), applies jurisdiction configuration, produces a report. Does not post back into the Ledger in v1 (see spec Section 5.2 — no automated remittance).

### Context relationships
- Scrip (Rust) and Osusu (Kotlin) are **external** to all four contexts — they're API clients of Ledger (and, per the spec's 7.13/7.14, Scrip is where `EquityStake` and business-health classification logic actually live, even though the *data* originates in FiSH).
- Lending and Tax both depend on Ledger; Ledger depends on neither. This dependency direction is the one invariant to protect as the codebase grows — if Ledger ever needs to import from Lending, that's a signal the boundary has been drawn wrong.

---

## 3. Aggregates

### 3.1 Ledger context

**Account** (aggregate root)
- Identity: `AccountId`.
- Invariants: belongs to exactly one Company; type is one of Asset/Liability/Equity/Revenue/Expense; cannot be hard-deleted once it has posted activity (can be deactivated instead).
- Depends on: `Company` (by reference/ID only, not embedded).

**JournalEntry** (aggregate root, `JournalLine` is part of the same aggregate — not its own root)
- Identity: `JournalEntryId`.
- Invariants: sum of debit `Money` amounts equals sum of credit `Money` amounts, *per currency* (a multi-currency entry needs care here — see open question below); `PostingStatus` transitions only via `canTransitionTo()`; once `Posted`/`System`, immutable except for a `Reversed` transition; every entry carries a `JournalSource`.
- Contains: one or more `JournalLine` value objects/entities, each referencing an `AccountId` and carrying a `Money` amount + `TransactionSide` + optional `DimensionType` tags.
- Depends on: `Account` (by ID), `Period` (by ID, to check postability — see below).

**Period** (aggregate root)
- Identity: `PeriodId`.
- Invariants: `PeriodStatus` transitions only via valid paths (Draft→Open→Closed→Locked, Closed→Open reopen); posting is only allowed when `allowsPosting()` is true.
- **Design note:** `JournalEntry` posting must check `Period.status`, but `Period` should *not* be inside `JournalEntry`'s consistency boundary (they change at different rates and for different reasons). Enforce "no posting into a closed period" as an **application-layer/domain-service check** (`PostingService`) that loads both and validates, rather than merging them into one aggregate. This is a standard DDD trade-off worth being deliberate about rather than accidental.

**Money** (value object — *does not exist yet, build first*)
- `amount: BigDecimal`, `currency: Currency` (ISO 4217 code). Arithmetic operators should reject mixing currencies (throw, or return a `ValidationResult` failure, matching the existing pattern). This blocks `JournalLine` from being written correctly — build it before `JournalEntry`.

### 3.2 Tenancy & Access context

**Tenant** (aggregate root) — owns Companies, Memberships, tenant-level settings (COA template, base currency, fiscal calendar).
**Company** (aggregate root, referenced by ID from Ledger, not embedded in Tenant) — one legal entity, its own COA and books.
**User** / **Membership** — a User can hold Memberships (User × Tenant × Role) across multiple Tenants.

### 3.3 Lending context (Purse-specific)

**LoanProduct** — product type, APR ceiling, rate-breakdown components.
**ArrearsCase** — staged record linked to a loan (via `JournalEntry`/`Account` reference), tracking `Early Contact → Pastoral Engagement → Formal Review → Final Resolution`, each transition audited. Outcomes: payment-plan restructure, payment holiday, partial write-off, formal collection, or (business borrowers only) capitalization into an `EquityStake`.
**EquityStake** — conversion date, converted amount, resulting ownership percentage, valuation basis, status (`Under Administration` / `Turnaround In Progress` / `Exited`). Expected to transfer to/be co-managed with Scrip once created (spec Section 7.13/11.1) — FiSH's job is to record the conversion accurately, not to manage the turnaround.

### 3.4 Tax context

**TaxRule** — jurisdiction, tax type, rate, applicable accounts/periods; data, not code, since rates change per country over time.
**TaxComputation** — derived record per Company/Period, computed from `JournalEntry` data already posted; feeds the government-ready report.

---

## 4. Domain Events (for cross-context/API communication)

Consistent with the spec's Section 7.10 (event notifications) and 7.14 (business-health signal feed):

- `JournalEntryPosted` — fired on the `Draft/Pending → Posted` transition. Consumed by: reporting, Scrip's business-health monitoring, Tax context (recompute `TaxComputation` incrementally).
- `PeriodClosed` / `PeriodLocked` — fired on Period lifecycle transitions.
- `ArrearsStageChanged` — fired on every `ArrearsCase` stage transition.
- `DebtCapitalized` — fired when an `EquityStake` is created from an `ArrearsCase`; this is the hand-off point to Scrip.
- `TaxComputed` — fired when a `TaxComputation` is generated for a Company/Period.

These map directly to the "event notifications (webhook or message-queue publish)" requirement already in the spec — they don't need to be implemented as a full event bus on day one; even a simple domain-event list drained after each use case (the "Aggregate collects events, application service publishes them" pattern) is enough to start.

---

## 5. Package Structure

Single Gradle module to start (per your steer: design first, avoid the prior over-fragmentation). DDD-layered packages, not one-class-per-folder:

```
com.theprodeogroup.fish
├── domain
│   ├── common        (existing 14 files — shared value objects/enums)
│   ├── ledger         (Account, JournalEntry, JournalLine, Period, Money)
│   ├── tenancy        (Tenant, Company, User, Membership)
│   ├── lending        (LoanProduct, ArrearsCase, EquityStake)
│   └── tax            (TaxRule, TaxComputation)
├── application         (use cases: PostJournalEntry, ClosePeriod, ComputeTax, ... — orchestrate domain + repositories)
└── infrastructure       (persistence, API adapters — build once a real target exists; not needed for the design/TDD phase)
```

Repository **interfaces** belong in `domain` (e.g., `domain.ledger.JournalEntryRepository`), next to the aggregate they serve — implementations go in `infrastructure` later. This keeps `domain` free of any database/framework dependency, which is what makes it unit-testable without a running database.

---

## 6. First TDD Test Specifications (not yet executable — see tooling note)

Written given/when/then, ready to become Kotest `DescribeSpec`/`BehaviorSpec` or plain JUnit5 tests once a build exists. Recommended build order: **Money → Account → Period → JournalEntry** (each depends on the previous).

### Money
- Given two `Money` values in the same currency, when added, then the result has the summed amount and the same currency.
- Given two `Money` values in different currencies, when added, then it fails (exception or `ValidationResult.failure`, matching existing convention) rather than silently producing a wrong number.
- Given a `Money` value, when compared to another in a different currency, then comparison fails rather than silently comparing raw amounts.

### Account
- Given a valid Company ID, account type, code, and name, when an `Account` is created, then it's active and has no parent.
- Given an existing `Account` with posted `JournalEntry` history, when deletion is attempted, then it's rejected — deactivation is offered instead.
- Given a child `Account`, when its parent is looked up, then the hierarchy resolves correctly (no cycles allowed — a creation-time check).

### Period
- Given a new `Period` in `Draft`, when opened, then status becomes `Open` and `allowsPosting()` is true.
- Given an `Open` `Period`, when closed, then status becomes `Closed` and `allowsPosting()` is false.
- Given a `Closed` `Period`, when reopened, then status returns to `Open` (per `canReopen()`).
- Given a `Locked` `Period`, when any transition is attempted, then it fails — `Locked` is terminal, per the existing `PeriodStatus` rules.

### JournalEntry
- Given a set of lines where total debits equal total credits (same currency), when the entry is validated, then validation succeeds.
- Given a set of lines where debits ≠ credits, when validated, then validation fails with a clear error (via `ValidationResult`, not a silent post).
- Given a `Draft` entry, when posted, then status becomes `Posted`, a `JournalEntryPosted` event is recorded, and further edits are rejected (`isEditable()` becomes false).
- Given a `Posted` entry, when posted again, then it's rejected (`canTransitionTo` only allows `Posted → Reversed`).
- Given a `Draft` entry whose target `Period` is `Closed`, when posting is attempted, then it's rejected by the `PostingService` (not by `JournalEntry` itself, per the Section 3.1 design note).
- Given a `Posted` entry, when reversed, then a new `Reversed`-sourced entry is created referencing the original, and the original's own status becomes `Reversed` — the original is never deleted or edited in place.

---

## 7. Tooling Note

This design was originally produced without a working Kotlin/Gradle toolchain (no compiler, no Gradle, Maven Central/Gradle/JetBrains download servers network-blocked in that sandbox) — nothing was compiled or executed at the time.

**Update (2026-08-11):** steps 1–4 below are done, on a local machine with real tooling (Kotlin 2.2.0, Gradle 9.1 wrapped down to 8.10, JDK 21). `gradle test` runs and passes. Kept here for the historical record and because step 5's ordering (Money → Account → Period → JournalEntry) is still the right order for the Ledger context — it just hasn't been started yet. `Tenant` (Tenancy context, Section 9) got built out of that order, ahead of Ledger, per an explicit user request; JUnit5 + Kotest assertions were used (not MockK yet — no aggregate here needed a collaborator to mock).

1. ~~Set up a Gradle Kotlin project...~~ Done — `GL/build.gradle.kts`, `settings.gradle.kts`, wrapper.
2. ~~Move the existing 14 files into `src/main/kotlin/com/theprodeogroup/fish/domain/common/`.~~ Done.
3. ~~Add JUnit5 + Kotest assertions + MockK as test dependencies~~ Done (JUnit5 + Kotest assertions; MockK not yet needed).
4. ~~Finish `field_change.kt`~~ Done.
5. Still to do: work through Section 6 in order — `Money` first (red → green), then `Account`, then `Period`, then `JournalEntry`.

---

## 8. Open Design Questions

- Multi-currency `JournalEntry`: is "balanced per currency" the right invariant, or should mixed-currency entries be disallowed entirely at the aggregate level (simpler, but Scrip/FX-heavy activity may need mixed entries with an FX gain/loss line)?
- Should `ArrearsCase` and `EquityStake` live in a `lending` package under the main `domain`, or in a genuinely separate Gradle module/bounded context boundary given they're Purse-specific and the Ledger context is meant to stay generic? (Leaning toward: same module, separate package, for now — split into a module only if/when Purse-specific code volume justifies it.)
- Where do domain events get published from — do aggregates return a list of events for the application service to drain (common, testable pattern), or is there an injected event publisher port on the aggregate itself (less common, harder to unit test in isolation)? Recommend the former.
- ~~Should Purse UK, Purse NI/ROI, and Purse Sierra Leone be one Tenant with multiple Companies, or separate Tenants?~~ **Resolved (2026-08-11, user accepted the recommendation): one Tenant, four Companies (UK, NI, ROI, SL).** The spec's own ubiquitous-language example already assumed this ("Company... a Tenant may contain multiple Companies — e.g., Purse's UK/NI/ROI/SL entities," spec §Glossary; §7.7 lists it as the primary option with "or as separate tenants" as the fallback). Each jurisdiction gets its own COA, books, currency, and regulator-facing reporting via its own `Company`; the Tenant boundary adds group-level roll-up and a shared admin Membership base. This is no longer a blocker for Section 9's onboarding flow.
- ~~Is Osusu a Company under Purse's Tenant, or its own Tenant?~~ **Resolved (2026-08-11): Osusu is onboarded as its own Tenant**, via the same `OnboardTenantUseCase` as any other tenant (spec §7.10's "external API clients" framing, not a Company-under-Purse rollup) — despite running "through Purse" operationally, it does not share Purse's Tenant boundary or consolidated reporting. Update Section 9.4 accordingly; this is no longer a blocker for the onboarding flow.
- **Resolved (2026-08-11): Purse and Scrip are each their own Tenants too** — same pattern as Osusu. Every FiSH venture (Purse, Scrip, Osusu, BuzzMe once scoped) onboards as an independent Tenant of the platform, none nested inside another as a Company. This has one knock-on effect worth flagging: Section 2.4's "Scrip is external to all four contexts — it's an API client of Ledger" framing was written assuming Scrip only *posts into* another tenant's books. If Scrip is its own Tenant, it also *has its own* Companies/ledger in FiSH (its treasury/investment books), not merely a client posting on someone else's behalf — worth revisiting Section 2.4's wording next time that section is touched, so "external API client" doesn't imply "no ledger data of its own."
- ~~What ledger `ClientType` represents Purse itself, given it's a cooperative/credit union?~~ **Resolved (2026-08-11): Purse's Companies use `NON_PROFIT`** — the existing enum value in `client_type.kt`, no new `ClientType` added. **Flag for whoever builds Purse's actual COA template:** the `NON_PROFIT` KDoc describes a template built for donations/grants/restricted funds (a charity's shape), whereas a credit union's real structure is member shares/deposits, loan loss reserves, and dividends payable (spec §7's own words, line 213) — closer to a deposit-taking institution than a charity. `ClientType.NON_PROFIT` is now the settled *classification*, but the *default COA template* keyed to it will likely need a credit-union-specific variant rather than the literal donations/grants template as written today. That's a template-content task, not a domain-model gap, so it doesn't block Section 9's onboarding flow.

---

## 9. Tenant Onboarding Flow

Two genuinely different onboarding paths share the same underlying aggregates but differ in who triggers them and how much friction is appropriate:

- **Internal venture provisioning** — Purse (one Tenant, four Companies: UK, NI, ROI, SL — Section 8), Scrip, Osusu, and BuzzMe once scoped. White-glove, done by FiSH/Purse ops, not self-serve.
- **External B2B SaaS signup** — the Mano River SMB wedge (spec §2.6). Closer to self-serve, KYB-gated, typically a single Company at first.

Both paths run the same core use case with different defaults/friction, not two different domain models.

### 9.1 Two distinct use cases, not one

"Onboarding a tenant" and "onboarding a company" are different weights of operation and should stay separate application services:

- **`OnboardTenantUseCase`** (rare — once per venture or per external customer): creates the `Tenant`, its first `Company`, the first admin `User` + `Membership`, and records the initial KYB outcome. Heavyweight, happens a handful of times.
- **`AddCompanyToTenantUseCase`** (more frequent): adds another legal entity to an *existing* Tenant — e.g., Purse adding its Sierra Leone entity after UK is already onboarded. Lighter: no new admin Membership required, inherits the Tenant's settings, only jurisdiction-specific fields (currency, fiscal calendar, COA template variant) are new inputs.

Collapsing these into one flow would force every "add a jurisdiction" operation to re-walk full Tenant-level KYB and admin-invitation steps it doesn't need.

### 9.2 `OnboardTenantUseCase` — step by step

1. **Capture Tenant identity**: legal/group name, tenant segment (internal venture vs. external B2B customer — drives which defaults and friction level apply), primary jurisdiction, base currency, fiscal calendar.
2. **Create `Tenant`** in an initial not-yet-active status (see 9.3) — mirrors the existing convention of encoding lifecycle state in the type itself (`PostingStatus`, `PeriodStatus`).
3. **Create the first `Company`** under that Tenant: legal entity name, `ClientType` (Purse's UK/NI/ROI/SL Companies use `NON_PROFIT` — resolved 2026-08-11, see Section 8), jurisdiction. `ClientType` selects the default COA template (spec §7 mentions per-`ClientType` COA templates already) — note the flag in Section 8 about the `NON_PROFIT` template's fit for a credit union's actual account structure.
4. **Create the first admin `User` + `Membership`** (User × Tenant × Role=Owner/Admin) — the person who can subsequently use the spec §7.8 invitation flow to add more users, so onboarding only ever needs to create one user, not enumerate the whole team.
5. **Record KYB/AML outcome as metadata, and KYC on the admin from step 4** — per spec §5.2 (out of scope) and §7.11, FiSH does not perform screening, only records the outcome and gates on it. **Resolved (2026-08-11): this step is two checks, not one** — `kybStatus` (the business-level KYB check) and `adminKycStatus` (personal KYC on the admin `User` created in step 4), each independently `Verified`/`Pending`/`Flagged`. **Why (user, 2026-08-11): AML.** Anti-money-laundering regulation is what actually requires identifying and verifying the individual(s) who control a business, not just the business entity itself — "verify the business" without "verify who runs it" leaves the exact gap AML rules exist to close (a shell business with an unverified controller). So the founding admin's KYC isn't optional polish on top of KYB, it's a component AML compliance requires — captured here, as part of onboarding, not deferred. This is *not* the same as the *Client*-level common-bond/KYC declaration in §7.11, which only applies to members onboarded later (a different population, once the Tenant is already Active) — the admin created at onboarding is a special case precisely because AML cares who controls the Tenant from day one.
6. **Issue a Tenant-scoped API key** if the Tenant will integrate programmatically (Scrip, Osusu, a future USSD gateway) — optional at onboarding time, can be deferred.
7. **Activate**: once minimum requirements are met (≥1 Company, ≥1 admin Membership, recorded `kybStatus`/`adminKycStatus`), transition `Tenant` to `Active`. **Resolved (2026-08-11): neither KYB nor admin KYC verification blocks activation** — a Tenant with `Pending` `kybStatus` and/or `adminKycStatus` (or even not-yet-`Verified`) can go `Active` immediately. Both instead run on a shared **180-day grace-period clock** — see 9.4. (`Flagged` on either one still gates activation.)
8. **Emit `TenantOnboarded`** (new domain event, add to the Section 4 list) for downstream consumers — billing, reporting, audit trail.

Steps 2–5 happen inside one application-service transaction boundary even though `Tenant`, `Company`, `User`, and `Membership` remain separate aggregates persisted separately (per Section 3.2 — `Company` is referenced by ID from `Tenant`, never embedded).

### 9.3 `TenantStatus` — new state machine

Doesn't exist in code yet; needs the same "encode transitions inside the type" treatment as `PostingStatus`/`PeriodStatus`. **Revised 2026-08-11**: no `PendingVerification` state — since neither KYB nor admin KYC gates activation (9.2 step 7), a lifecycle stage named after verification would be misleading dead weight. Verification progress is tracked as its own fields/clock on the Tenant (9.4), orthogonal to `TenantStatus`:

- `Draft` → `Active`
- `Active` ⇄ `Suspended` (reversible — e.g., non-payment, a KYB or admin-KYC flag raised post-activation, **or the 180-day grace period lapsing unverified — see 9.4**)
- `Active` / `Suspended` → `Closed` (terminal — customer offboarding; data retained per spec §7.15 retention policy, never deleted on close)

Every transition should produce an `AuditAction` entry, consistent with how the rest of the domain treats state changes.

### 9.4 Verification grace period (new, 2026-08-11; revised same day to cover admin KYC)

Resolved: a Tenant activates immediately regardless of `kybStatus`/`adminKycStatus`, but both are expected to reach `Verified` within a **180-day grace period** from activation, tracked separately from `TenantStatus`:

- **Fields on `Tenant`**: `kybStatus` (business-level check) and `adminKycStatus` (the founding admin's personal check, step 5) — each `Pending`/`Verified`/`Flagged` — sharing one `kybVerificationDeadline` (activation date + 180 days). **Resolved (2026-08-11): tracked as two independent fields, not one combined status** — they can clear at different times or via different verification providers. Both use the same activation rule (`Pending` doesn't block, `Flagged` does) and the same deadline; the grace period is only cleared once *both* reach `Verified`.
- **Reminders**: scheduled prompts to the Tenant's admin `User`(s), escalating as the deadline approaches. **Resolved (2026-08-11): day 90 (halfway), day 150 (30 left), day 166 (14 left), day 173 (7 left), day 179 (1 left)** — five touchpoints total, counted from activation. Uniform across all tenant segments (internal venture and external B2B alike) — not configurable per segment; this was a deliberate simplicity choice, not an oversight.
- **Deadline enforcement**: a scheduled application-service sweep (not aggregate-internal logic — same "domain service checks and validates" pattern already used for `Period`/`PostingService` in Section 3.1) checks for Tenants past `kybVerificationDeadline` where `kybStatus` and/or `adminKycStatus` is still not `Verified`, and transitions them `Active → Suspended`, with an `AuditAction` recording the automated reason (distinct from a manually-triggered suspension).
- **New domain event** (add to Section 4's list): `KYBGracePeriodExpired`, fired on that automated suspension, so billing/notifications can react. One event covers either field lapsing — not split into separate KYB/KYC expiry events, since the outcome (suspension) is identical either way.

### 9.5 Still open before this can become code

Every decision point raised across Sections 9.1–9.4 is now resolved (Tenant/Company boundaries and `ClientType` — Section 8; KYB-vs-activation and the grace-period cadence — 9.4). Nothing left blocking this flow from becoming real code. One residual, non-blocking item:

- Purse's `ClientType` is resolved (`NON_PROFIT`, Section 8), but its default COA *template* content still needs credit-union-specific work before step 3 produces a chart of accounts that actually fits a credit union's books, not a charity's. Template-content work, not a design gap.

### 9.6 Implementation status (2026-08-11)

The `Tenant` aggregate itself is **built and tested** — `src/main/kotlin/com/theprodeogroup/fish/domain/tenancy/` (`tenant.kt`, `tenant_status.kt`, `tenant_segment.kt`, `verification_status.kt`, `tenant_events.kt`, `ids.kt`), 29 passing tests across `TenantTest.kt` and `TenantStatusTest.kt`. Covers: `onboard()` (bare Draft, no Company/Membership yet — Section 9.2 steps 1–2), `addCompany()`/`addAdminMembership()`/`recordKybOutcome()`/`recordAdminKycOutcome()` (steps 3–5), `activate()` (step 7 — rejects on missing Company, missing admin Membership, or Flagged `kybStatus`/`adminKycStatus`, combining all four via `ValidationResult.combine()`; succeeds when both are still Pending; starts the shared 180-day deadline; raises both `TenantActivated` and `TenantOnboarded`, since this one call is steps 7+8), `suspend()`/`reactivate()`/`close()`, and `isKybGracePeriodExpired()`/`suspendForExpiredKyb()` for the 9.4 scheduled sweep (expired if *either* field is still unverified past the deadline). `KybStatus` was renamed to `VerificationStatus` when the admin-KYC field was added, since the type is now shared by both checks.

**Not built yet, deliberately out of scope for this pass:** `OnboardTenantUseCase`/`AddCompanyToTenantUseCase` (application-service layer — Tenant only exposes the primitives they'd call), the actual scheduled sweep job that calls `suspendForExpiredKyb()`, the reminder-sending mechanism for the five touchpoints, `Company`/`User`/`Membership` aggregates themselves (`Tenant` only holds their IDs by reference, per Section 3.2), and persistence/repository interfaces. `AuditAction` gained `ACTIVATED`/`SUSPENDED`/`REACTIVATED` to support this (`domain.common.audit_action.kt`), though `Tenant` doesn't emit `AuditAction` entries itself yet — that's an application-service/audit-logging concern layered on top of the domain events, not implemented here.
