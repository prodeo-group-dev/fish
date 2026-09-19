# FiSH Tax Extraction — Domain-Driven Design (design-only, no code yet)

**Status: design scoping, 2026-09-19. Decision to extract is confirmed; nothing extracted or deleted yet.** Triggered by the user's own three-division framing of the FiSH family — **"FiSH has Finance(GL,Tax), Administration(EA, HR) and Operations (SOP, IM, POP)"** — followed by direct confirmation that Tax should be a genuine peer repo alongside GL under the Finance division, not a bounded context living inside `GL/`. Confirmed via `AskUserQuestion`: **design first, defer extraction**, the same discipline already applied to Lending (`docs/DDD_Design.md` §2.3), HR/Payroll, and Purchasing/Sales/Inventory (`docs/Ecosystem_Extraction_DDD_Design.md`) before any of those actually moved. This document is that design pass, following the same template. **The go/no-go decision itself was challenged and settled during this pass — see the rationale immediately below — extraction should proceed once §8's open questions are answered, not still an open debate.**

**This reverses a real, dated decision, not a blank slate.** `ManagedModule.TAX`'s own KDoc (`domain/tenancy/managed_module.kt`, 2026-08-31) records the prior resolution explicitly: *"Tax management should be its own module... Unlike HR/SOP/POP/IM, this isn't a separate repo — `ComputeTaxUseCase`/`TaxRule`/`TaxComputation` already live in GL's own domain layer and stay there; this only gives Tax its own product-facing identity."* That's the opposite conclusion from today's instruction. Worth stating plainly rather than quietly overwriting — the earlier decision gave Tax a dashboard tab and its own access grant *within* GL; today's decision gives it a whole separate codebase. The access-grant mechanism (`ManagedModule.TAX`, `Membership.grantedModules`) isn't invalidated by this — it's a Tenancy/EA-side concept (who can see the Tax tab) orthogonal to where the Tax computation itself runs.

**The extraction decision itself was challenged and settled, not assumed — worth recording the actual reasoning, not just the outcome.** Pushback raised directly: `domain.tax` is already a cleanly separated package with zero incoming dependencies from any other GL context (§0), so the cohesion win of extraction is largely already achieved at zero deployment cost — a full new service (own RDS, ECS/ALB, Jenkins pipeline, Cognito service account, WEB cutover) is real, ongoing overhead for a solo, pre-launch team, and per §0's inventory Tax is the thinnest context in this codebase today (no write path into the Ledger at all, one `TaxType`, one already-live GL endpoint away from its whole computation). **User's counter, which settles it:** *"We will have a matrix of tax types and tax jurisdictions and fiscal years to consider. This complexity and the implications of getting wrong requires this separation."* This reframes the basis for the decision from *current* size (thin today) to *anticipated* size (`TaxType` × `Jurisdiction` × fiscal-year effective-dating — a real, foreseeable matrix, not speculative: `TaxType`'s own KDoc already names VAT/GST and PAYROLL_PAYE as future scope, and `TaxRule`'s own KDoc already flags "no effective-dating/rate-history modeling" as a known, unaddressed gap) combined with the asymmetric cost of a compliance error (a bug in an internal report is inconvenient; a bug in a tax computation risks real regulatory/legal consequences across seven jurisdictions). **Sharpened further, same exchange:** *"It is far too sensitive to get wrong, our reputation, our customer reputation, risk of loss is high. It comes high in risk management."* — the stakes aren't only regulatory/legal exposure to FiSH itself, but reputational (both FiSH's own and every tenant Company's, since a wrong Corporate Income Tax figure is *their* number, filed under *their* name) and financial (risk of loss), explicitly ranked as a high-priority risk-management concern, not just an engineering nicety. That's a legitimate basis for extracting *ahead of* current complexity rather than waiting until the domain is large and entangled with core Ledger code, at which point separating it cleanly would be harder, not easier — and it argues for treating whatever *does* get built here (once §8 resolves) with commensurately high rigor (test coverage, review discipline) rather than the default pace, though that's a build-time concern, not one this design pass needs to resolve. **Confirmed: extraction proceeds.** The matrix itself (multi-`TaxType` computation, per-jurisdiction rate history/effective-dating) is real future scope this justifies extracting *for*, but is not designed in this pass — that's the new Tax repo's own follow-on design work once it exists, not a prerequisite for standing it up.

---

## 0. What's actually in the GL Engine repo today (Tax context)

Confirmed by direct code inventory, 2026-09-19:

| Piece | File | What it is |
|---|---|---|
| `TaxRule` | `domain/tax/tax_rule.kt` | Global reference data (not Tenant/Company-scoped) — jurisdiction + tax type + rate structure. `jurisdiction` is the just-closed `Jurisdiction` enum (`domain.common`, today's earlier change). |
| `Jurisdiction` | `domain/common/jurisdiction.kt` | **Shared, not Tax-exclusive** — `Company` (Tenancy, stays in GL) uses it too. See §6, the one genuine wrinkle this extraction surfaces. |
| `TaxType` | `domain/tax/tax_type.kt` | One value today, `CORPORATE_INCOME_TAX` — VAT/GST and PAYROLL_PAYE are named but deliberately unbuilt (each needs a different computation shape its own KDoc explains). |
| `RateStructure` (+ `ExemptionTest`/`Tier`/`MarginalRelief`) | `domain/tax/rate_structure.kt` | Five computation shapes (Flat/Tiered/CategorySplit/ThresholdExemption/…) covering every Corporate Income Tax shape found across the seven jurisdictions' reference docs. |
| `TaxComputation` | `domain/tax/tax_computation.kt` | The persisted, audit-grade computed-tax-due record. **Key finding, §2 below: its actual arithmetic is almost nothing.** |
| `TaxRuleRepository` / `TaxComputationRepository` | `domain/tax/repositories.kt` | Persistence contracts. |
| `ComputeTaxUseCase` | `application/ComputeTaxUseCase.kt` | Assembles `Account`s + posted `JournalEntry`s for a Period, delegates to `TaxComputation.of()`. |
| `TaxRoutes.kt` | `infrastructure/web/TaxRoutes.kt` | `POST`/`GET /companies/{companyId}/tax`, gated by `ManagedModule.TAX`. |
| Exposed persistence | `exposed_tax_rule_repository.kt`, `exposed_tax_computation_repository.kt`, `tax_tables.kt`, `rate_structure_encoding.kt` | `tax_rules` (real `UNIQUE(jurisdiction, tax_type)` constraint), `tax_computations` (real FKs to `companies`/`periods`). |

**Confirmed by grep: nothing else in `GL/` reads or writes any of this.** The only other mentions of "Tax"/`TaxRule`/`TaxComputation` anywhere in `src/main/kotlin` are KDoc cross-references in unrelated files (`provision.kt`, `customer.kt` citing `TaxRule`'s "data, not code" pattern as precedent; `journal_entry_events.kt`, §5 below) — no actual code dependency. **This is a clean, complete lift candidate**, not a partial one like Purchasing/Sales' still-open Expected Credit Loss question.

---

## 1. Why this is a genuinely different shape of extraction than Payroll/PO/SO/Inventory

Every prior "ecosystem" extraction (`docs/Ecosystem_Extraction_DDD_Design.md` §3) follows one established pattern: **the calling system computes the number, the GL Engine only ever posts it and tags it** — `AccruedExpense`, `Borrowing`, `PayRun`, and the HR/POP/SOP/IM posting interfaces all push a caller-computed amount *into* the Ledger.

**Tax is the reverse.** `ComputeTaxUseCase`'s own KDoc is explicit: *"`ComputeTaxUseCase` still never posts back into the Ledger... tax computation is a report, not a Ledger-mutating operation."* Tax doesn't push anything in — it *pulls* already-posted Ledger data out (a Company's `Account`s and a Period's posted `JournalEntry`s) to compute a derived figure. **The interface direction is backwards relative to every extraction this codebase has done before.** This matters concretely: §3 of the Ecosystem doc could treat "what shape does the replacement interface take" as basically solved by precedent. Here it can't be — this needs its own answer.

---

## 2. The key finding: `TaxComputation.of()` already reduces to `ProfitAndLoss.netIncome`

Not a design choice — already true in the code, `tax_computation.kt`'s own KDoc states it directly: *"For the only supported [`TaxType.CORPORATE_INCOME_TAX`], that reuse is direct: `taxableProfit` IS `ProfitAndLoss.netIncome` for the same Period — one canonical net-profit calculation, not a second one recomputed here."*

**This means the extracted Tax service does not need raw `Account`/`JournalEntry` data at all.** It needs exactly one number (net income for a Period) plus its own `TaxRule.rateStructure.computeTaxDue()` arithmetic, which is already 100% self-contained Tax-side logic with zero Ledger dependency. **And GL already exposes almost exactly that number over HTTP today**: `GET /companies/{companyId}/reports/profit-and-loss` (`ReportsRoutes.kt`, `ComputeProfitAndLossUseCase`) returns `periodId`/`currency`/`totalRevenue`/`totalExpense`/`netIncome` for a Company. This is the same kind of "genuinely good finding, not something to guess around" the Ecosystem doc's `AccountsPayableAging`/`AccountsReceivableAging` discovery was (§0 of that document) — whatever else this extraction does, **Tax likely never needs a bulk data-export endpoint from GL, just this existing report, read as an ordinary API client** (the same "sibling system, own database, calls GL's API" shape Scrip/Osusu/HR/POP/SOP/IM already have — just the read/write direction flipped).

---

## 3. The real gap this surfaces: period selection

`ComputeProfitAndLossUseCase.execute(companyId)` takes **only** a `companyId` — it always resolves "the Company's currently open Period" internally (`Result.NoOpenPeriod` if none exists), with no way to ask for a specific, possibly-already-closed Period.

`ComputeTaxUseCase.Request`, by contrast, takes an **explicit `periodId`** and validates it against the Company — meaning tax can be computed today for *any* period, open or closed, current or historical (e.g. recomputing what last year's filing would have been). **If the extracted Tax service depends on the existing P&L endpoint as-is, this capability is silently lost.** Genuinely open, not guessed:

- Extend `GET /companies/{companyId}/reports/profit-and-loss` to accept an optional `?periodId=` query parameter, defaulting to the open Period when omitted — backward compatible, and the smallest change that closes the gap.
- A new, Tax-specific GL endpoint instead, leaving the existing report route untouched.
- Fall back to exposing raw `Account`/`JournalEntry` data after all — the weakest option, since it reintroduces exactly the duplication §2's finding avoids.

The first option is the front-runner given how small the change is relative to what it preserves, but this is a real decision to make before extraction starts, not during it.

---

## 4. What moves out entirely

`Jurisdiction` (§6, with a caveat), `TaxRule`, `TaxType`, `RateStructure`/`ExemptionTest`/`Tier`/`MarginalRelief`, `TaxComputation`, `TaxRuleRepository`/`TaxComputationRepository` (interfaces and Exposed implementations), `ComputeTaxUseCase`, `TaxRoutes.kt`, `tax_tables.kt`'s schema (as a fresh migration in the new repo, not a literal copy — new repo, new database). Every one of these is Tax-exclusive per §0's inventory.

## 5. What stays in GL

Nothing Tax-specific remains. GL's role narrows to exposing (an enhanced, per §3) `profit-and-loss` report that Tax calls as an ordinary read-only API client — the same shape POP/SOP/IM/HR already call GL for posting, just reversed to a read. `ManagedModule.TAX` (Tenancy/EA-side access control — who can see a "Tax" tab) is **not** Tax-computation code and doesn't move; it's the same kind of thing as `ManagedModule.HR`/`SOP`/`POP`/`IM` already are for the other extracted systems — a permission vocabulary entry, unaffected by where the actual computation runs.

**`JournalEntryPosted`'s domain event names Tax as a future consumer** ("Tax context (recompute TaxComputation incrementally)... none of those consumers exist yet"), but no event bus/message broker exists anywhere in this platform — every cross-service interaction today is a synchronous REST call (POP→IM, SOP/IM/HR→GL). Default, not yet confirmed: Tax stays pull-based (caller explicitly requests a computation, exactly as it works today) rather than this extraction becoming the occasion to introduce this codebase's first async event consumer. Flagged, not decided — an incremental-recompute trigger is a real, separate feature, not a prerequisite for extraction.

---

## 6. `Jurisdiction` — the one genuine wrinkle the enum work surfaces

`Jurisdiction` (`domain.common`, added earlier today) is used by **both** `Company` (Tenancy, stays in GL) and `TaxRule` (moving to Tax) — the whole point of closing it from free text to a closed enum was to guarantee those two always mean the same thing when `TaxRoutes.kt` looks one up by the other. Once Tax is a separate repo, that single source of truth needs to exist in **both** codebases somehow:

- **Duplicate the enum** in the new Tax repo — simplest, but reintroduces exactly the drift risk closing the free-text field was meant to prevent, just at a coarser (repo-boundary) granularity instead of a per-field one.
- **Fold it into `fish-common`** — the existing shared-source library already used for `Money`/`ValidationResult` across GL/SOP/POP/IM/HR (`common/README.md`, "consumed as source, no published artifact"). This is the more consistent answer given precedent, but wasn't designed for domain-specific enums before, only generic value types — worth confirming that's still the right role for it before assuming.

Not decided here. Whichever way this goes, `Company.jurisdiction` and the Tax service's own jurisdiction value need to keep meaning the same seven things, or the governance win from today's earlier change quietly erodes at the new repo boundary.

---

## 7. Extraction destination

Given the user's own framing — Finance as a named division containing GL *and* Tax as peers — the natural destination is a new standalone repo, `fish-tax` or similar, mirroring HR/Payroll's/POP's/SOP's/IM's shape (own Gradle project, own RDS database, own ECS/ALB deployment, own Jenkins pipeline) rather than folding into an existing sibling. Not otherwise decided — repo name, Kotlin/Ktor/Exposed vs. another stack (though every other extraction in this family has stayed on that stack, and `fish-common` reuse depends on it), and AWS resource naming are all open.

---

## 8. Open questions (summary)

1. **Period-selection gap** (§3) — extend the existing P&L endpoint, add a new one, or expose raw data.
2. **Jurisdiction sharing mechanism** (§6) — duplicate the enum, or extend `fish-common`.
3. **Extraction destination/repo name/stack** (§7).
4. **Service-account auth** — Tax calling GL's `profit-and-loss` endpoint needs its own Cognito service-account credential, mirroring the already-proven `CognitoServiceAccountTokenProvider` pattern (POP→IM, SOP/IM/HR→GL, `docs/POP_GL_Service_Account_Closure_Plan.md`) — not a new mechanism to invent, just another instance of an existing one.
5. **WEB cutover** — `WEB/` currently calls GL's own `/companies/{companyId}/tax` directly; once extracted, it needs repointing at the new Tax service, the same cutover every prior extraction has gone through.
6. **Database** — new dedicated RDS database for `tax_rules`/`tax_computations`, matching every other extracted system's "own database" precedent (`docs/Database_Tenant_Isolation_RLS_Scope.md`'s own finding that POP/SOP/IM are "already physically isolated by separate per-service databases").
7. **`ManagedModule.TAX`'s continued meaning** (§5) — confirm this stays a Tenancy/EA-side access-grant concept, unaffected by the computation itself moving.

---

## 9. What this document changes right now

**Nothing in `fish-fish-gl-engine`.** `TaxRule`/`TaxComputation`/`ComputeTaxUseCase`/`TaxRoutes.kt` stay exactly as built (now with the closed `Jurisdiction` enum from earlier today). This document exists so that when extraction actually happens, the real open questions above get resolved deliberately — the same discipline `[[feedback_park_dont_guess]]` already established as this project's working style, and the same one every prior extraction in this family has followed before touching code.
