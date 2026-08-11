# FiSH GL Engine — Domain-Driven Design

**Status:** Draft v0.1
**Date:** 2026-08-11
**Companion documents:** `FiSH_GL_Engine_Spec.docx` (requirements), `docs/SL/FiSH_GL_Business_Plan.md`, `docs/UK/*` (business plans)

This document translates the requirements spec into a DDD model: ubiquitous language, bounded contexts, aggregates, and the package structure the codebase should converge on. It also reviews the code that already exists and defines the first TDD test specifications — written as given/when/then cases, ready to become real Kotest/JUnit tests once a working build (Gradle + Kotlin compiler) is available.

**Update (2026-08-11): a Gradle project now exists** (`build.gradle.kts`, `settings.gradle.kts`, wrapper, all in `GL/`), built on a local machine with real Kotlin/Gradle tooling — the Cowork-sandbox constraint in CLAUDE.md no longer applies to this session. The 14 existing `domain.common` files have been moved into `src/main/kotlin/...` and compile. The `Tenant` aggregate (Section 9) is implemented and covered by 29 passing tests, `Money` (Section 3.1) by 11 more, `Account` (Section 3.1) by 14 more, and `Company` (Section 3.2) by 7 more (4 for `Company` itself, 3 for `GoingConcernStatus`) — 61 passing tests total (`gradle test`, all green). `User`/`Membership`, `Period`, `JournalEntry`, and `CashBookEntry` are still design-only.

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

**Confirmed 2026-08-11: FiSH is accrual-based accounting**, not cash-basis — **grounded specifically in IAS 1** (Presentation of Financial Statements — IAS 1.27 requires the accrual basis), not just a general engineering preference. Financial facts are recognized when incurred/earned, not when cash actually moves. Concretely, and **asymmetric between the two sides by deliberate design, each grounded in a different standard** (see Section 2.5's final, confirmed timing model): `Accounts Payable` is recognized in full when a Purchase Order is *sent* ("when we order we owe"), per **IFRS 9**'s financial-liability recognition (a present obligation to repay cash or another financial asset), while Income/`Accounts Receivable` is recognized progressively *as a Sales Order is delivered*, per **IFRS 15**'s performance-obligation model (income recognized when earned, i.e. when the obligation is satisfied) — not when the sale is placed. Both are accrual (neither waits for cash to move), but they're governed by two different standards, which is exactly why they don't share a recognition trigger. Worth checking against this principle, asymmetry included, whenever a new module's posting timing gets designed (Payroll accruing unpaid wages, Inventory/COGS timing, etc.) rather than assuming symmetric timing by default. **Framing confirmed and sharpened by the user (2026-08-11):** the GL's job is for a Company to "recognise its own income, expenditure, capital, assets and liabilities" — a plain-language restatement of `Account`'s five types (Revenue/Expense/Equity/Asset/Liability, Section 3.1). Sharpened further, same session: **"The GL sole purpose is the financial effect."** Not a soft emphasis — a hard scope boundary. The GL records the financial *effect* of activity (postings, balances) and nothing about the operational/member detail that produced it (loan terms, order details, member records) — that detail belongs to whichever context generated it (Lending, and eventually Purchase/Sales Order Processing, Section 2.5) and posts its financial effect into Ledger. This is a general principle, not Purse-specific — applies the same way to any Company FiSH serves, credit union or ordinary SMB client.

### 2.2 Tenancy & Access (supporting)
Tenant, Company, User, Membership, roles, `RequestContext`. Every other context depends on this for "who is doing this, on behalf of which Company." Necessary, not a differentiator — resist the urge to over-engineer it.

### 2.3 Lending (supporting, Purse-specific — "the banking module")
`LoanProduct`, `ArrearsCase`, `EquityStake`, purpose affirmation, interest-rate ceilings. Consumes Ledger (loans post through it) but owns rules that are specific to Purse's ethical framework, not general-purpose ledger behaviour. Keeping this separate from Ledger is what stops the core engine from silently becoming "a UK credit union's booking system" instead of a generic multi-tenant ledger. The user's own analogy for this context is a "banking module," similar to how a real core banking system holds member/product/transaction detail and posts summarized entries to a GL.

**Correction, 2026-08-11, same day:** an earlier pass of this section additionally claimed Lending shares the same deployment/codebase as core Ledger (not a separate service, unlike Scrip/Osusu). The user flagged this as a misunderstanding on a follow-up message ("Lending is separate from the GL") but didn't resolve, when asked directly, whether "separate" means a genuinely separate deployed service (Scrip/Osusu-style, API-only) or just a distinct bounded context/package within one codebase (what this section said before that edit). **Do not assume either answer.** What's actually settled either way: Lending owns Purse-specific rules and member-level detail, consumes Ledger by reference, and Ledger never depends back on it (Section 2's "Context relationships"). The deployment topology is open.

### 2.4 Tax (supporting)
`TaxRule`, `TaxComputation`. Reads Ledger data (posted transactions), applies jurisdiction configuration, produces a report. Does not post back into the Ledger in v1 (see spec Section 5.2 — no automated remittance).

### 2.5 Purchase Order Processing / Sales Order Processing (current build scope, not yet designed)

**Status upgraded 2026-08-11 — no longer speculative future work.** The user's own framing: "A GL comes with the 2 Order Processing modules and Payroll Modules and Inventory Management Modules. That is what we are building NOW." Restated and sharpened the same day: **"This is the generic ecosystem for a GL engine."** Not four independent bolt-ons — an *ecosystem*, i.e., these four (PO/SO Processing, Payroll, Inventory Management — see 2.6/2.7) are expected to be interconnected (goods/AR/AP/payroll all post into the same Ledger, and 2.6 already flags PO/SO/Inventory as one connected cluster) and together constitute what makes a GL engine generic across different types of companies — not Purse-specific add-ons, but the standard cross-industry toolkit that fulfills the spec's own stated ambition of a general-purpose B2B ledger (spec §2, "supports the general-purpose client types... this generality is already a design decision, not an open question"). Purse needs Lending on top of this ecosystem; an ordinary SMB client mostly just needs the ecosystem itself.

Still not designed in detail — no aggregates, fields, or workflows invented here, to avoid guessing ahead of the user. What's confirmed: these are what will keep AR/AP accurate against the GL, for both ongoing operations and a Company's opening/historical figures at onboarding (Section 9.8) — the same mechanism handles both, rather than onboarding needing its own bespoke AR/AP import path.

**Mapping confirmed 2026-08-11** (the earlier working assumption was right):
- **Sales Order Processing** → creates **Customers** and, where the sale is on credit, **Accounts Receivable** — the counterparty is a **Debtor** once there's a balance owed. "Debtor" is the standard UK/Commonwealth accounting term (matches British English throughout the spec and Purse's UK context), same relationship as "Trade Debtors" on a UK balance sheet.
- **Purchase Order Processing** → creates **Accounts Payable** and, correspondingly, a **Creditor** once there's a balance owed — same UK-accounting pairing ("Trade Creditors").

**Confirmed 2026-08-11 — the two-layer reading above is correct.** The user's own framing: "only customers with outstanding payments need to be registered in the books" — i.e., *registration in the books* (a Debtor record) is driven by having a balance, not by the sale happening at all. Not every Customer is a Debtor at a given moment; every Debtor is a Customer.

**New, optional, explicitly deferred:** cash customers (who never carry a balance, so never need Debtor registration for GL accuracy) may *optionally* — and the user recommends this — still be registered as Customers anyway, for marketing purposes, "possibly through a loyalty scheme." This is a CRM/marketing-adjacent feature, not an accounting requirement, and has no obvious equivalent on the Purchase/Creditor side (no stated "loyalty scheme for suppliers" concept). **Do not build this now** — it's a recommendation for a future capability, not a current design gap; noted here so it isn't lost, not because it's in scope for the current PO/SO design work.

**Control account architecture, resolved 2026-08-11 — this settles the "onboarding snapshot vs. ongoing subledger" question left open above and in Section 9.8.** This point went through several rounds of correction in conversation before landing — see `project_future_modules` in memory for the revision history if it matters later. **What follows is the final, explicitly confirmed model — treat it as current, not any earlier draft of it.**

- `Accounts Payable` and `Accounts Receivable` are each a **control account** in core Ledger — a single `Account` (Liability / Asset type respectively) in the Company's Chart of Accounts representing the *total* owed to suppliers / owed by customers.
- Each individual counterparty's balance lives in a **subsidiary ledger** — Creditor balances owned by Purchase Order Processing, Debtor balances owned by Sales Order Processing (per Section 2.1's scope boundary — the module owns the counterparty-level detail, Ledger only holds the control account's aggregate effect).
- **The control account must always tally with the sum of subsidiary balances** — the actual mechanism, not a soft goal. It's *why* AR/AP can't be a one-time onboarding snapshot: a control account only means anything if the subsidiary ledger is tracked continuously and reconciles against it. This is what resolves the "snapshot vs. subledger" question (Section 9.8/`project_anchor_date_onboarding`) as genuinely settled: itemized AR/AP is an ongoing subledger.
- **Recognition timing is asymmetric between the two sides, confirmed 2026-08-11 — this is the final answer after two earlier drafts got corrected:**
  - **Purchase Order Processing (AP):** "When we order we owe" — the user's own words. AP is recognized **when the Purchase Order is sent**, in full, not progressively as goods arrive (an intermediate draft tried progressive recognition here and was explicitly reverted). Credit `Accounts Payable` (control) and the supplier's subsidiary account at PO-send; debit both, credit Cash/Bank, when paid.
  - **Sales Order Processing (Income/AR):** "When they order, Income is recognised as we deliver" — the user's own words. Placing a Sales Order does **not** recognize income. Income/`Accounts Receivable` accrues **progressively as the order is fulfilled/delivered** — the reverse timing from AP, not the same timing mirrored.
  - **Grounded in specific IFRS/IAS standards, per the user (2026-08-11), not just convention:**
    - **IFRS 15** (Revenue from Contracts with Customers) uses a five-step model; the relevant one here is **Step 5**: revenue is recognized when (or as) control of goods/services transfers to the customer, regardless of cash timing. Two sub-cases matter for Sales Order Processing specifically: a **point-in-time** transfer (a physical product delivered — recognize revenue at that point) vs. an **over-time** transfer (a service delivered across a period — recognize revenue progressively as it's delivered, not just at the very end). Both are "income recognized as delivered," but which sub-case applies depends on whether a given Sales Order is a goods sale or a service.
    - **IFRS 9** (Financial Instruments): a financial liability is recognized "when the entity becomes party to a contractual obligation to deliver cash or another financial asset" — initially at fair value, at the point the contract is signed/the obligation arises. FiSH treats sending a Purchase Order as that point, ahead of goods receipt.
    - **IAS 1** (Presentation of Financial Statements): IAS 1.27 is the general basis requiring accrual accounting at all — the standard underlying the broader "FiSH is accrual-based" principle in Section 2.1. IAS 1 also governs **current vs. non-current classification** of a recognized liability (see the new `Account` requirement in Section 3.1) — a liability is current unless the Company has the unconditional right to defer settlement ≥12 months, and covenant breaches can force otherwise-non-current debt into current classification (repayable on demand).
    - **Practical summary, the user's own framing:** revenue is *earned-based*, debt is *obligation-based*. Neither depends on cash movement — both depend on the underlying economic event, just different events (satisfying a performance obligation vs. incurring a contractual obligation). That's precisely why they aren't symmetric even though the control-account mechanism is.
    - This isn't a from-scratch design choice or an informal "prudence" convention — it's the two sides of AR/AP being governed by two different standards (a revenue-recognition standard vs. a financial-instruments standard), which is exactly why they don't share a recognition trigger even though the control-account mechanism is otherwise symmetric.
  - **The control-account *structure* still mirrors exactly between AP and AR** (control account + subsidiary ledger + tally) — only the *recognition trigger* differs. "Mirror image," the user's earlier description of Sales vs. Purchase Order Processing, refers to the structure, not the timing.
- **Correction confirmed 2026-08-11:** the original Purchase Order example named "Accounts Receivable" — confirmed a label slip for Accounts Payable, the buying/owing side.
- **Event ordering:** "we buy, we owe" is confirmed atomic again (AP recognized fully at order time) — receiving goods and paying can still happen in either order relative to each other, without affecting the AP amount already recognized at PO-send; since the full liability exists from PO-send onward, a prepayment before goods arrive simply debits the same AP balance, no separate handling needed. On the Sales side, income timing tracks delivery instead, independent of when the customer's payment arrives.

This surfaces two candidate entities not yet in the domain model: **Customer** (AR counterparty) and **Creditor** (AP counterparty). `DimensionType.CUSTOMER`/`VENDOR` already exist in `domain.common` as journal-line tags, which presumes *something* with an ID sits behind them — but a tag value isn't the same as a first-class entity with its own record (contact info, running balance, aging). Whether Customer/Creditor become real aggregates (owned by Sales/Purchase Order Processing respectively) or stay reference-only concepts is part of designing those two modules, not decided here. Still depend on Ledger the same way Lending and Tax do (post through it, don't get absorbed into it) — inference, not yet confirmed.

### 2.6 Inventory Management (current build scope, not yet designed)

Named by the user 2026-08-11, alongside Purchase/Sales Order Processing — part of the same "current build scope" upgrade as 2.5. Not designed yet — no aggregates, fields, or valuation method (FIFO/weighted-average/etc.) invented here. Obvious relationship, not yet confirmed: goods received against a Purchase Order likely increase stock, goods shipped against a Sales Order likely decrease it and generate a Cost of Goods Sold posting — meaning Inventory Management, Purchase Order Processing, and Sales Order Processing probably form one connected cluster (goods flow in → held → out) rather than three independent modules, and stock valuation touches the GL (an inventory asset account, a COGS expense account) the same way Sales Order Processing touches AR. Whether Inventory Management is its own bounded context or part of the same context as Purchase/Sales Order Processing is an open question, not decided.

### 2.7 Payroll (current build scope, not yet designed)

Named by the user 2026-08-11, alongside PO/SO Processing and Inventory Management, as the fourth module in the "what makes a GL engine generic" ecosystem (2.5). Nothing designed yet — no aggregates, no pay-run/payslip model, no statutory-deduction handling invented here. Obvious relationship, not yet confirmed: payroll runs almost certainly generate `JournalEntry` postings against Ledger (gross pay, statutory deductions/PAYE-NI-equivalent, net pay, employer costs) the same way Sales/Purchase Order Processing post AR/AP — Payroll owns the calculation and compliance detail, Ledger only receives the financial effect (Section 2.1's scope boundary). Jurisdiction-specific rules (UK PAYE/NI vs. Sierra Leone/Mano River equivalents) will need the same "data, not code" treatment the spec already uses for `TaxRule` (Section 3.4) — an inference from precedent, not yet confirmed for Payroll specifically.

**Confirmed 2026-08-11 — Payroll's scope boundary against Lending:** an ordinary trading company does not need the full Lending context (Section 2.3) at all — that stays Purse/Osusu-specific (credit-union-style loan products, APR ceilings, arrears workflow, common bond). What an ordinary company *may* need is **salary advances management**, scoped inside Payroll — the user's own distinction. A salary advance (employer advances an employee money, recovers it via payroll deduction over subsequent pay periods) is a much simpler mechanism than member/consumer lending: no APR ceiling, no arrears staging, no common-bond eligibility check, recovery is just a payroll deduction line. Not designed in detail yet, but the boundary is clear: salary advances live in Payroll, not Lending, and Lending's machinery (Section 2.3) is the wrong tool for it even though both involve one party advancing money to another.

### 2.8 Fixed Asset Register (current build scope, not yet designed)

Named by the user 2026-08-11: "we will need a fixed asset register," resolving the open question in Section 3.1's `Account`/depreciation note (fields on `Account` vs. a dedicated register — settled in favor of the register). Follows the same control-account + subsidiary-ledger pattern already established for AP/AR (Section 2.5): a Fixed Assets control account (or one per category — Land, Buildings, Equipment, Vehicles) lives in core Ledger; per-asset detail (cost, acquisition date, useful life, depreciation method, accumulated depreciation, disposal status) lives in this module, with the same tally requirement between them. Nothing designed at field/aggregate level yet — including whether accumulated depreciation needs its own contra-asset control account per category, and whether this is its own bounded context or shares one with Inventory Management (both manage physical/capital items, unlike PO/SO/Payroll which are transactional). Depreciation postings will use `JournalSource.SYSTEM` (see Section 3.1). Land's confirmed policy (not depreciated; revaluation gains, if ever built, route through OCI per IAS 16 — Section 3.1) belongs to whatever this register ends up looking like.

### Context relationships
- Scrip (Rust) and Osusu (Kotlin) are **external** to all four contexts — they're API clients of Ledger (and, per the spec's 7.13/7.14, Scrip is where `EquityStake` and business-health classification logic actually live, even though the *data* originates in FiSH).
- Lending and Tax both depend on Ledger; Ledger depends on neither. This dependency direction is the one invariant to protect as the codebase grows — if Ledger ever needs to import from Lending, that's a signal the boundary has been drawn wrong.

---

## 3. Aggregates

### 3.1 Ledger context

**Account** (aggregate root — **built and tested 2026-08-11**, `com.theprodeogroup.fish.domain.ledger.Account`, 14 passing tests)
- Identity: `AccountId`.
- Invariants: belongs to exactly one Company; type is one of Asset/Liability/Equity/Revenue/Expense (`AccountType`, with `normalBalance(): TransactionSide` and `requiresClassification(): Boolean` helpers); cannot be hard-deleted once it has posted activity — `validateDeletion()` rejects with `ValidationResult.failure` if `recordActivity()` has been called, deactivation (`deactivate()`/`reactivate()`) is offered instead.
- **IAS 1 current/non-current classification, built as specified:** Asset/Liability accounts require an `AccountClassification` (`CURRENT`/`NON_CURRENT`); Equity/Revenue/Expense accounts must *not* have one — both directions enforced at construction (`Account.create()` throws `IllegalArgumentException` via `require()`, matching `Money`'s precedent for constructor-time invariants, rather than `ValidationResult` which is used for post-construction transitions here, matching `Tenant`'s precedent). Covenant-triggered reclassification still deliberately not built (Section 3.1's original note stands).
- **Parent hierarchy, partially built:** only a self-parent cycle is checked at construction (`parentId != id`) — deeper multi-level cycle detection and cross-Company parent validation need the full Account tree, which a single aggregate can't see in isolation. Flagged in code as an application-service-level concern, the same way `PostingService` checks `Period.status` outside `JournalEntry` itself (design note below) — **not built yet**, since there's no repository/application layer at all in this codebase so far.
- Depends on: `Company` (by reference/ID only, not embedded) — `com.theprodeogroup.fish.domain.tenancy.CompanyId`, a real cross-context reference now that both packages exist.
- **Fixed vs. Current Assets, confirmed 2026-08-11 — already covered by `AccountClassification`, no new field needed.** The user's own framing: "Assets also are Fixed or Current." This is the same `CURRENT`/`NON_CURRENT` split already built for IAS 1 (above) — "Fixed Asset" is just the common name for a `NON_CURRENT` Asset account, not a separate classification to add.
- **Depreciation, resolved 2026-08-11 — a Fixed Asset Register, not new fields on `Account`.** Fixed Assets are "likely to incur depreciation charges over time depending on how long is required by the system user" — i.e., useful life is a user-configurable input, not a hardcoded rule. The user confirmed: "we will need a fixed asset register," settling the shape question left open earlier. Follows the same control-account + subsidiary-ledger pattern as AP/AR (Section 2.5/2.8): a Fixed Assets control account (or one per category — Land, Buildings, Equipment, etc.) lives in core Ledger, per-asset detail (cost, useful life, depreciation method, accumulated depreciation, disposal status) lives in the **Fixed Asset Register** module (Section 2.8), with the same tally requirement between them. Periodic depreciation postings use `JournalSource.SYSTEM` — already anticipated in that enum's own original KDoc example ("Monthly depreciation entry"), written before this session even started. Not designed in field-level detail yet, including whether accumulated depreciation needs its own contra-asset control account per category (standard practice — net book value = cost − accumulated depreciation) — that's Section 2.8's job once it gets designed.
- **Land: confirmed policy 2026-08-11, not just a default assumption anymore.** Land is not depreciated (indefinite useful life, unlike buildings/equipment). If/when land revaluation is built, the user confirmed the IAS 16 treatment should be followed: revaluation gains route through **Other Comprehensive Income into a separate revaluation reserve within Equity**, not straight through P&L. Both points are now confirmed policy to build toward when this gets designed in detail — not tentative, though still not built.

**JournalEntry** (aggregate root, `JournalLine` is part of the same aggregate — not its own root)
- Identity: `JournalEntryId`.
- Invariants: sum of debit `Money` amounts equals sum of credit `Money` amounts, *per currency* (a multi-currency entry needs care here — see open question below); `PostingStatus` transitions only via `canTransitionTo()`; once `Posted`/`System`, immutable except for a `Reversed` transition; every entry carries a `JournalSource`.
- Contains: one or more `JournalLine` value objects/entities, each referencing an `AccountId` and carrying a `Money` amount + `TransactionSide` + optional `DimensionType` tags.
- Depends on: `Account` (by ID), `Period` (by ID, to check postability — see below).
- **The accounting equation, confirmed 2026-08-11 — a system-level invariant, not a new rule to enforce separately.** The user's own framing: "the total sum of all Asset balances must equal the total sum of all Liability and Capital balances." This is `Assets = Liabilities + Equity` — and it's a **derived, emergent property** of every `JournalEntry` being balanced (debits = credits), not an independent check that needs its own enforcement mechanism. If every posted entry balances, the whole ledger balances automatically: summing every account by its `normalBalance()` (`AccountType.normalBalance()`, already built), `Σ(Asset + Expense balances) = Σ(Liability + Equity + Revenue balances)` holds identically — this is the more general, always-true form (including Revenue/Expense, which is what actually holds continuously, before any period-end closing entries move net income into Equity). Practical implication, not yet built: a **Trial Balance** check/report (sum Asset+Expense vs. Liability+Equity+Revenue, per Company, expect equality) is the natural verification mechanism — a way to catch corruption, bugs, or bypassed validation, not a rule the domain model enforces directly beyond what `JournalEntry`'s own per-entry balance invariant already guarantees. Worth building as a query/report once `JournalEntry` exists, not as new domain logic. Multi-currency raises the same nuance flagged in Section 8's open question — does the equation need to hold per-currency, or does it need a reporting-currency consolidation step first.

**Second report confirmed 2026-08-11, alongside Trial Balance:** the user wants Revenue and Expense shown **separately** too — a **Profit & Loss / Income and Expenditure Account** (the latter is the correct term for Purse specifically, given its `ClientType.NON_PROFIT` classification, Section 8 — matches the GL's own stated purpose of letting a Company "recognise its own income, expenditure, capital, assets and liabilities," Section 2.1). Same non-building-new-domain-logic principle as Trial Balance: `Revenue − Expense` = net income/loss for a period, using accounts already typed via `AccountType`, no new invariant. The distinction from Trial Balance/Balance Sheet worth remembering when `Period` gets designed next: **Balance Sheet accounts (Asset/Liability/Equity) are point-in-time** (as-at a date), while **Income Statement accounts (Revenue/Expense) are period-bound** (for the month/year ended) — a P&L report is inherently scoped to a `Period` in a way a Trial Balance/Balance Sheet isn't. Neither report is built yet; both are query/reporting concerns for once `JournalEntry` (and ideally `Period`) exist.

**Period** (aggregate root)
- Identity: `PeriodId`.
- Invariants: `PeriodStatus` transitions only via valid paths (Draft→Open→Closed→Locked, Closed→Open reopen); posting is only allowed when `allowsPosting()` is true.
- **Design note:** `JournalEntry` posting must check `Period.status`, but `Period` should *not* be inside `JournalEntry`'s consistency boundary (they change at different rates and for different reasons). Enforce "no posting into a closed period" as an **application-layer/domain-service check** (`PostingService`) that loads both and validates, rather than merging them into one aggregate. This is a standard DDD trade-off worth being deliberate about rather than accidental.

**Money** (value object — **built and tested 2026-08-11**, `com.theprodeogroup.fish.domain.ledger.Money`)
- `amount: BigDecimal`, `currency: Currency` (ISO 4217 code). `plus()` and `compareTo()` (via `Comparable<Money>`) throw `IllegalArgumentException` on mixed currencies rather than silently producing a wrong number — resolved as "throw," not `ValidationResult`, since Kotlin operator overloads and `Comparable.compareTo` need to return their natural type (`Money`/`Int`), not a wrapped result.
- **Design addition beyond the original spec, needed for correctness:** the constructor normalizes `amount` to the currency's minor unit (`currency.defaultFractionDigits` — 2 for GBP/USD, 0 for JPY) using `RoundingMode.HALF_EVEN`, and `equals()`/`hashCode()` are overridden to compare by numeric value rather than raw `BigDecimal.equals()` (which is scale-sensitive — `10.0` and `10.00` are unequal under the JDK default). Without this, two `Money` values representing the same amount could compare unequal depending on how they were constructed — a real bug class for a financial type, not a hypothetical one.
- 11 passing tests, `MoneyTest.kt` — same-currency addition, cross-currency addition/comparison rejected, scale-insensitive equality, minor-unit rounding. **Verified directly against the actual Mano River launch markets (spec §2.6/7.12), not just JPY as a generic example:** checked `java.util.Currency` at the JDK level and confirmed Guinea (GNF) and Côte d'Ivoire (XOF) are genuinely zero-decimal currencies, same shape as JPY — while Sierra Leone (SLL/SLE) and Liberia (LRD) are 2-decimal. Two of the four launch markets would have been silently mishandled by a naive "always round to 2 decimal places" implementation; the `currency.defaultFractionDigits`-driven design handles all four correctly without special-casing. Explicit test cases added for GNF/XOF/SLE/LRD, not just the generic JPY case.
- This blocked `JournalLine` from being written correctly per the original design note — now unblocked. `Account` is next per the Section 6 build order.

**CashBookEntry** (new, 2026-08-11 — a book of original entry, not a separate ledger; design only, not yet built)
- Resolved: FiSH's Cash/Bank Book is a **simplified single-sided capture** that generates a proper `JournalEntry` behind the scenes, not a new parallel ledger and not just a read-only view over existing `JournalEntry` lines. Consistent with the non-accountant UX principle already established (memory: `feedback_non_accountant_ux`) — the person recording "money came in" or "money went out" shouldn't need to know which side is debit and which is credit.
- Fields (draft, not yet finalized): `accountId` (which Cash or Bank `Account` — a Company may have more than one), `direction` (received / paid — plain language, not `TransactionSide` directly), `amount: Money`, `counterAccountId` or counterparty reference (what the other side of the entry is — an expense/revenue `Account`, or a Debtor/Creditor once Sales/Purchase Order Processing exist), `date`, `description`.
- Behaviour: on submission, derives a balanced `JournalEntry` — the Cash/Bank `Account` takes the `TransactionSide` implied by `direction` (received → debit for an asset account, paid → credit), the counter-account takes the opposite side. This is the concrete mechanism, not yet built, that would eventually implement the "correct side" logic non-accountant users shouldn't have to think about.
- **Depends on `Account` and `JournalEntry` still** (Money is now done) — this is a consumer of the Ledger core, not a replacement for it.
- **Not yet decided:** exact `JournalSource` value for entries originating this way (existing values — `MANUAL`, `IMPORT`, etc. — don't quite name it; Section 9.8 flagged a similar gap for opening-balance entries specifically, this may be the same value or a different one). Whether `CashBookEntry` is a first-class persisted aggregate in its own right, or just an application-service-level DTO/command that produces a `JournalEntry` and is never stored itself, is also open — leaning toward the latter (simpler, no extra aggregate to keep consistent) but not decided.

### 3.2 Tenancy & Access context

**Tenant** (aggregate root) — owns Companies, Memberships, tenant-level settings (COA template, base currency, fiscal calendar).
**Company** (aggregate root — **built and tested 2026-08-11**, `com.theprodeogroup.fish.domain.tenancy.Company`, 4 passing tests, referenced by ID from Ledger, not embedded in Tenant) — one legal entity, its own COA and books. Core fields only, per the agreed minimal-build scope: `tenantId` (reference), `name`, `clientType` (`ClientType`), `jurisdiction` (plain `String`, matching `Tenant`'s precedent of not over-typing simple fields), `baseCurrency` (`Currency` — a Company's own, not inherited from Tenant, since jurisdictions can differ within one Tenant, e.g. Purse's UK/NI/ROI/SL). Carries a `goingConcernStatus` (`GoingConcernStatus` — resolved 2026-08-11, see Section 9.7, **built as a 2-state enum with `canTransitionTo()`**): every Company defaults to `ASSUMED` going concern at creation — this is the standard accounting default, not a special case — and can move to `SUBSTANTIAL_DOUBT` via `flagSubstantialDoubt()`, which the (not yet built) Lending context will call when a business borrower's `ArrearsCase` reaches `Final Resolution`. **No reversal built** — `SUBSTANTIAL_DOUBT → ASSUMED` deliberately doesn't exist yet, since how that should work is still an open question (Section 9.7).
- **Company relationships, confirmed 2026-08-11 — not yet built.** A Tenant's Companies can relate to each other, not just sit side by side — the user's own framing: "he sets up his company or companies and the relationships between them (e.g. consolidation of accounts or separate accounts)." Concretely: a `parentCompanyId: CompanyId?` (mirroring the parent/child pattern already built on `Account`), plus a consolidation mode — whether a Company's figures combine into group reporting with its parent, or stay standalone. Real implication for the Trial Balance/P&L reports flagged in Section 3.1 (JournalEntry note): they'll eventually need both a per-Company view and a consolidated-group view, not just per-Company. Not designed in detail yet — this is the concept, not the field-level design.
- **Real-time going-concern monitoring (RAG indicators), raised 2026-08-11 — explicitly parked, not decided.** The user's framing: going-concern health measured continuously with Red/Amber/Green indicators, "a bit like real time analysis of blood pressure oxygen etc of a human." This is a meaningfully richer concept than the current `GoingConcernStatus` (a two-value `ASSUMED`/`SUBSTANTIAL_DOUBT` enum, Section 9.7) and it collides with something already decided elsewhere in this doc: Section 2.4's "Context relationships" already states Scrip owns business-health classification logic (spec §7.13/7.14's "business-health signal feed"), consuming data that originates in FiSH rather than FiSH computing it. **Asked directly whether RAG scoring should live in FiSH (expanding `GoingConcernStatus`) or stay in Scrip (FiSH just emits good data/events) — not answered, don't assume either way.** A related, explicitly speculative idea from the same message — "this probably would lead to gamifying the activities of the company" — is flagged as a future product direction only, not scoped or designed.
- **Boundary clarified 2026-08-11, doesn't fully resolve the above but narrows it:** the user distinguished going-concern management (a *diagnostic* question — is the company healthy) from **treasury/investment optimization of company assets, especially current assets** (an *operational* one — actively deploying assets for best use) as "two different things." Treasury/investment is Scrip's stated core identity (CLAUDE.md: "Scrip — Purse's treasury/investment arm"), and its natural data hook is exactly `AccountClassification.CURRENT` — already built on `Account`. This doesn't answer whether RAG scoring lives in FiSH or Scrip, but it does mean: don't design one mechanism trying to serve both going-concern health *and* treasury/investment optimization as if they're the same feature. They may share a data source (FiSH's ledger) without sharing logic or ownership.
**User** / **Membership** — a User can hold Memberships (User × Tenant × Role) across multiple Tenants.

### 3.3 Lending context (Purse-specific)

**LoanProduct** — product type, APR ceiling, rate-breakdown components.
**ArrearsCase** — staged record linked to a loan (via `JournalEntry`/`Account` reference), tracking `Early Contact → Pastoral Engagement → Formal Review → Final Resolution`, each transition audited. Outcomes: payment-plan restructure, payment holiday, partial write-off, formal collection, or (business borrowers only) capitalization into an `EquityStake`. An `ArrearsCase` reaching `Final Resolution` for a business borrower is what moves the borrowing `Company`'s `goingConcernStatus` to `SUBSTANTIAL_DOUBT` (Section 9.7) — the earlier stages (Early Contact, Pastoral Engagement, Formal Review) don't, since they aren't yet indicative of real going-concern risk.
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
5. ~~Work through Section 6 in order — `Money` first (red → green), then `Account`, then `Period`, then `JournalEntry`.~~ `Money` and `Account` done (2026-08-11). Still to do: `Period`, then `JournalEntry`.

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

### 9.7 Going-concern status on Company (new, 2026-08-11)

Clarification from the user during this session: "going concern" is the accounting term itself — the assumption that a business will continue operating, not a synonym for "has pre-existing history." It applies equally to a brand-new Company being onboarded (intended to operate ongoing) and an established one bringing in prior books. So this isn't a special onboarding path or a fork in `OnboardTenantUseCase` — it's a status every `Company` carries from the moment it's created, defaulting to the standard assumption.

- **`GoingConcernStatus`** (new enum, `domain.tenancy`, not yet built in code): `ASSUMED` (default — no known events raising doubt) and `SUBSTANTIAL_DOUBT` (mirrors real audit language: "substantial doubt about the entity's ability to continue as a going concern").
- **Lives on `Company`, not `Tenant`** — resolved 2026-08-11. Going concern is a legal-entity/books-level accounting assessment (financial statements are prepared per Company), and a single Tenant can hold Companies with different statuses (e.g., one of Purse's four Companies could be in distress while the others aren't) — a Tenant-level field couldn't represent that. **Concrete case from the user, same day:** a Tenant running a conglomerate/group structure may deliberately designate one Company as a loss-leader — its losses are a strategic choice, not doubt about the group's ability to continue. A Tenant-level status would either wrongly flag the whole group over one intentionally-unprofitable subsidiary, or hide a real per-Company signal entirely. Per-Company tracking is what makes "this one subsidiary is fine being unprofitable" representable at all.
- **Default assignment**: Section 9.2 step 3 (create the first `Company`) sets `goingConcernStatus = ASSUMED`. No activation gate depends on it — a Company starts `ASSUMED` and stays that way unless something specific changes it.
- **What changes it**: resolved 2026-08-11 — **tied to the Lending context's `ArrearsCase`, not a standalone mechanism.** When a business borrower's `ArrearsCase` (Section 3.3) reaches `Final Resolution` — the most severe stage, where outcomes like partial write-off, formal collection, or capitalization into an `EquityStake` happen — the borrowing `Company`'s `goingConcernStatus` moves to `SUBSTANTIAL_DOUBT`. The earlier stages (Early Contact, Pastoral Engagement, Formal Review) don't trigger this; they're not yet indicative of real going-concern risk, and firing this on every arrears case would make the flag meaningless noise.
- **Open, not decided**: whether/how a Company moves back from `SUBSTANTIAL_DOUBT` to `ASSUMED` (e.g., if the `ArrearsCase` resolves via restructure, or the resulting `EquityStake` reaches `Exited` per a successful turnaround). Auto-reverting the same way it auto-triggers is one option; requiring an explicit accountant/compliance re-assessment before clearing it is another, and probably the safer default given this is meant to reflect real financial-statement risk, not just cause-and-effect bookkeeping — worth a decision before this gets built, not assumed.
- **Not built yet** — this is design only. `Company`, `ArrearsCase`, and `EquityStake` don't exist in code (Section 9.6 confirms only `Tenant` is built so far).

### 9.8 Onboarding an established Company: the anchor date (new, 2026-08-11, partially resolved)

Separate from going-concern status (9.7) — this is about a Company that has pre-existing books, which needs its history brought into FiSH somehow before normal posting makes sense. A brand-new Company just activates at zero balances (already covered by 9.2); this section is the established-Company case flagged as a gap when onboarding was first discussed.

**Resolved:**
- **Anchor date** (the user's term — use this, not "cutover date") — an administrator-chosen date. Cash and Bank account balances *as at* the anchor date become the opening balance for those accounts in FiSH — i.e., an opening-balance `JournalEntry` (needs its own `JournalSource` value, not yet added — `IMPORT` is close but generic; consider a dedicated value) dated at the anchor date, posted before any normal activity.
- **Accounts Receivable / Accounts Payable are itemized, not a lump sum** — resolved 2026-08-11. Each open invoice (AR) or bill (AP) as at the anchor date is captured individually: counterparty, amount, due date, reference — not just a single AR/AP total. This is unlike Cash/Bank, which is one balance figure.

**Resolved 2026-08-11 — routed to a new module, not decided as core-Ledger scope:** AR/AP accuracy (both ongoing and opening/historical figures) is owned by the planned **Purchase Order Processing / Sales Order Processing** modules (Section 2.5), not by a bespoke onboarding import mechanism and not by a subledger built directly into core Ledger. The same modules used for ongoing operations are also how opening AR/AP figures get entered — one mechanism for both, not two. This is *why* progressive/incremental entry (below) makes sense: it's normal usage of an operational module, not a special onboarding-only allowance.

AR/AP items "can be entered on an ongoing basis till the final accounts are prepared and the year is closed" — explicitly framed by the user as a UX/accessibility choice ("allowing for this makes the software easy to use for non-accountants"), and a general product principle worth applying beyond this one feature (see the "why" note in memory).

**Plain-language framing (2026-08-11):** for a non-accountant entrepreneur specifically, the opening-balance entry for AR/AP shouldn't be presented using accounting jargon at all — the user's own framing: ask for "the list of people who owe him" (AR) and "the people he owes money [to]" (AP), entered day-to-day through the first year, before EOY balances are closed. `AccountsReceivable`/`AccountsPayable` (or whatever the domain model ends up calling these once Purchase/Sales Order Processing is designed) should stay proper accounting terms internally — needed for correctness, reporting, tax, audit — but the entrepreneur-facing UI copy/labels are a separate presentation-layer concern and should use this kind of plain language, not the jargon. Worth carrying forward whenever the PO/SO modules' UI gets designed, not just as a one-off phrasing note.

**Still open:** Section 2.5's own scope — Purchase/Sales Order Processing aren't designed yet beyond the confirmed Customer/AR and Creditor/AP mapping (Section 2.5), including how these modules post into Ledger (Account/JournalEntry). Onboarding's role narrows to: point the admin at these modules for opening AR/AP figures once they exist, and (per 9.8's earlier resolution) handle Cash/Bank directly via a single opening-balance `JournalEntry` at the anchor date, since Cash/Bank doesn't need order/item-level tracking the way AR/AP does.

---

## 10. Persistence & Multi-Tenancy Strategy (new, 2026-08-11)

Nothing in `infrastructure` exists in code yet (Section 5 — repository interfaces belong in `domain`, implementations were deliberately deferred). This section records the decision so it's not re-litigated when that work starts.

**Resolved: PostgreSQL**, chosen for the reason double-entry bookkeeping actually needs it — a `JournalEntry`'s lines must commit together or not at all, which wants a database with strong ACID transactions, plus the domain is already relational by nature (typed IDs, `Tenant` → `Company` → `Account` → `JournalEntry` references).

**Correction to the reasoning below (2026-08-11, same day):** an earlier pass of this section treated RLS as addressing the noisy-neighbor concern. That was wrong and got corrected in conversation — **RLS is a row-filtering access-control mechanism only.** It stops Tenant A's queries from seeing Tenant B's rows; it does nothing about physical resource contention. Tenants on RLS-protected shared tables still share the same table files, indexes, `shared_buffers` cache, disk I/O, WAL, connection pool, and autovacuum/background-writer processes — a write-heavy tenant bloating a shared table still degrades everyone else sharing it, RLS or not. Also worth recording: schema-per-tenant or database-per-tenant *on the same Postgres instance* only partially solves this either — separate tables/indexes reduce bloat cross-contamination, but `shared_buffers`, WAL, and `max_connections` are cluster-wide in Postgres, not per-database. Full elimination of noisy-neighbor effects needs separate compute (a genuinely separate server instance per tenant), a much bigger step than "recreate a schema."

**Resolved: PostgreSQL native table partitioning by `tenant_id`**, not schema-per-tenant, not database-per-tenant, and not relying on RLS for the resource-isolation problem (RLS still applies on top, for the access-control property it's actually good at). Reasoning:
- Partitioning gives each tenant (or tenant group) separate physical storage and indexes *within one logical table, one database, one migration surface* — no per-tenant schema-recreation ceremony, which the user explicitly wanted to avoid unless performance or regulatory reasons forced it.
- This meaningfully reduces the bloat/cache-eviction side of the noisy-neighbor problem (the part schema/DB-per-tenant would have partially addressed anyway) without paying the migration-multiplication or connection-pool-multiplication costs those patterns carry.
- **Does not** solve CPU scheduling, `shared_buffers` cache, or `max_connections` contention at the instance level — that residual risk is accepted for now, consistent with FiSH's expected shape (a long tail of small SMB tenants, not many large write-heavy ones). Revisit if it becomes a real problem rather than over-building for a risk that may not materialize.
- **Elegant side effect, worth acting on:** partitioning strategy can double as the answer to the Purse regulatory question below — a hybrid scheme (a dedicated `LIST` partition for named large/regulated tenants like Purse, `HASH`-bucketed partitions for the general SMB tail) gets physical separation for the tenant that might need it *and* keeps everyone else on the low-ceremony path, in one mechanism rather than two separate ones. Exact bucket count/partition key details are an implementation decision for when `infrastructure` actually gets built, not decided here.

**Still flagged, not decided, but narrower than first framed — a regulatory question, not an engineering one:** the spec commits to "full data isolation between tenants" (§7.7), and Purse is FCA/PRA-regulated. Confirmed 2026-08-11 (Section 2.3): the member-level detail a regulator would actually scrutinize — loan terms, common-bond declarations, KYC — lives in the Lending context ("the banking module"), not in core Ledger's `Account`/`JournalEntry`/`Period` tables, which only hold the financial *effect* (income/expenditure/capital/assets/liabilities). That means this section's partitioning decision may not need to carry the regulatory weight originally assumed — the sharper open question is **the Lending context's own persistence/isolation strategy**, not core Ledger's. Still needs an actual answer from whoever owns Purse's regulatory compliance, but the question has moved: ask about Lending's data, not just Ledger's, before assuming either way.
