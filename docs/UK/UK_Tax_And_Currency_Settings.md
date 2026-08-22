# UK Tax and Currency Settings — reference

**Status: reference data, 2026-08-22.** The first content placed under `docs/UK/` per the national-folder convention recorded in `CLAUDE.md` the same day (country-specific settings — currency, tax law — live under `docs/<COUNTRY>/`). Sourced from current HMRC/gov.uk-derived figures for the 2026/27 UK tax year (see Sources at the end) — **not** invented, per this codebase's own existing precedent against fabricating tax figures (`HR/.../payroll_tax_rule.kt`'s KDoc, `docs/HR_Payroll_DDD_Design.md` §3.3). Figures below are real, current UK statutory figures as looked up on 2026-08-22, not the FiSH universe's own fictional numbers — same relationship the existing Purse APR ceilings (`FiSH_GL_Engine_Spec.md`) have to real-world credit union regulation.

**Needs a refresh discipline, not a one-time entry.** UK tax years run 6 April–5 April and rates/thresholds routinely change at each Budget. Treat every figure here as "as of the 2026/27 tax year" and re-verify before relying on it for a period that has since rolled over — this document doesn't auto-update.

**Scope note:** England/Wales/Northern Ireland figures throughout. Scotland has its own devolved Income Tax bands (different from the below) — out of scope here since Purse's stated footprint is UK, Northern Ireland, and Republic of Ireland, not Scotland specifically. If a Scottish entity is ever onboarded, this document needs a Scotland-specific section, not a silent substitution.

**Machine-readable form:** `docs/UK/uk_tax_and_currency_settings.yaml` holds the same figures as structured key-value data (nested by section: `currency`, `corporationTax`, `vat`, `paye`, `nationalInsurance`), for whenever this needs to be loaded as actual config/seed data rather than just read as prose. Kept in sync by hand for now — nothing generates one from the other.

---

## 1. Currency

| Setting | Value | Grounded in |
|---|---|---|
| ISO 4217 code | `GBP` | Already one of the four v1 currencies (`FiSH_GL_Engine_Spec.md`: "Minimum currency set for v1: GBP, EUR, SLE, USD") |
| Decimal places | 2 | `Money`'s existing behavior — derived automatically from `java.util.Currency.getInstance("GBP").defaultFractionDigits`, not a FiSH-authored table (`common/.../Money.kt`) |
| Symbol | `£` | Used consistently in narrative UK docs (business plan, Ethical & Theological Framework) but **not currently stored or rendered anywhere in code** — `Money.toString()` prints `"10.00 GBP"`, not `"£10.00"`. Flagged here, not fixed here — a presentation-layer gap, not a data gap. |

No further settings needed on the currency side — GBP already behaves correctly through the existing generic `Money` type. This section exists to document that fact, not to introduce new code.

---

## 2. Corporation Tax — maps to the already-built `TaxType.CORPORATE_INCOME_TAX`

The only tax type `GL/`'s `ComputeTaxUseCase`/`TaxRule` actually computes today. These are the real UK figures that would seed a UK `TaxRule` (`TaxRuleTest.kt` currently uses an illustrative `0.30`/"Sierra Leone" fixture, not real data — this table is what a real UK entry should look like).

| Band | Rate | Threshold |
|---|---|---|
| Small profits rate | 19% | Augmented profits up to £50,000 |
| Marginal relief band | Tapered, 19%→25% (26.5% marginal rate within the band) | £50,000–£250,000 augmented profits |
| Main rate | 25% | Augmented profits above £250,000 |

Marginal relief formula (2026/27): `(3/200) × (£250,000 − augmented profits) × (taxable total profits ÷ augmented profits)`, subtracted from tax charged at the main rate. The £50,000/£250,000 thresholds are divided by (1 + number of associated companies) for group structures — relevant to Purse's own multi-Company-per-Tenant structure (`project_tenancy_boundaries`) if Corporation Tax computation is ever run at the Tenant level across its Companies rather than per-Company.

`TaxRule`'s existing shape (a single `rate: BigDecimal` fraction) does **not** yet support a tiered/marginal-relief structure — it's flat-rate only. Building a real UK `TaxRule` entry against these figures would need either a new `TaxRule` variant or a UK-specific wrapper that picks the right flat rate for the small-profits/main-rate bands and computes marginal relief separately. Not built here — this document is the reference data that build would consume, not the build itself.

---

## 3. VAT — **not yet computable anywhere in this codebase**

`TaxType` deliberately has no VAT/GST member yet ("to avoid implying a working computation that doesn't exist" per its own KDoc). These figures are recorded now so they're ready whenever that gap gets closed, per this codebase's established "record the decision, don't build it yet" pattern.

| Rate | Value | Applies to |
|---|---|---|
| Standard rate | 20% | Default rate for goods/services not otherwise listed |
| Reduced rate | 5% | Domestic fuel (gas/electricity), water/sewerage, children's car seats, certain medical aids |
| Zero rate | 0% | Most food, books/newspapers, children's clothing, medical equipment, exports outside the UK |

---

## 4. PAYE Income Tax bands — for `HR/`'s `PayrollTaxRule`

England/Wales/Northern Ireland, 2026/27. `HR/.../payroll_tax_rule.kt` is explicitly jurisdiction-agnostic in shape but was left unpopulated pending exactly this kind of sourced figure.

| Band | Rate | Threshold |
|---|---|---|
| Personal Allowance | 0% | First £12,570 |
| Basic rate | 20% | £12,571–£50,270 |
| Higher rate | 40% | £50,271–£125,140 |
| Additional rate | 45% | Above £125,140 |

**Personal Allowance tapering**: reduced £1 for every £2 of income above £100,000, fully withdrawn at £125,140 (creates an effective 60% marginal rate in the £100,000–£125,140 band — worth flagging explicitly if `PayrollTaxRule` ever models marginal effective rates, not just nominal bracket rates).

**PAYE threshold** (the point PAYE starts being deducted at all): £242/week, £1,048/month — matches the Primary Threshold below, not a separate figure.

---

## 5. National Insurance (Class 1) — for `HR/`'s `PayrollTaxRule`

| Party | Rate | Band |
|---|---|---|
| Employee | 8% | Primary Threshold (£242/week, £1,048/month) to Upper Earnings Limit (£967/week, £4,189/month) |
| Employee | 2% | Above Upper Earnings Limit |
| Employer | 15% | Above Secondary Threshold (£5,000/year, £417/month) |
| Employer (under-21 employee / apprentice under 25) | 0% | Up to Upper Secondary Threshold (£967/week) — reduced-rate carve-out |

---

## Sources

- [Corporation Tax Rates 2026/27 — Main Rate, Small Profits & Marginal Relief](https://pocketwise.co.uk/tax/corporation-tax-rates-2026-27/)
- [UK VAT Rates 2026/27 — 20%, 5% & 0% Rates Plus Registration Threshold](https://clearfigures.co.uk/vat-rates-uk)
- [2026-27 Personal Tax Allowance | UK Tax Bands 2026 Explained](https://www.riftrefunds.co.uk/advice/tax-updates-by-year/26-27-personal-allowance/)
- [Class 1 employer's National Insurance rates for 2026/27 - FreeAgent](https://www.freeagent.com/rates/national-insurance-class-1-employers/)
- [Class 1 employee's National Insurance rates 2026/27 - FreeAgent](https://www.freeagent.com/rates/national-insurance-class-1-employees/)
