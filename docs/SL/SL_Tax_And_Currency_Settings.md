# Sierra Leone Tax and Currency Settings — reference

**Status: reference data, 2026-08-22.** Fourth national-folder document under the convention recorded in `CLAUDE.md` — but the first one for the project's actual **primary market-facing wedge** (`docs/SL/FiSH_GL_Business_Plan.md`), not a secondary jurisdiction like IE/NG. Sierra Leone was already named first in the spec's own tax-scope list ("configurable, jurisdiction-specific tax computation — starting with Sierra Leone, Liberia, Guinea, Côte d'Ivoire," `FiSH_GL_Engine_Spec.md`), so this closes a real, previously-open gap rather than adding new scope. Real, current National Revenue Authority (NRA)-derived figures for the 2026 fiscal year (see Sources) — not fabricated, same discipline as UK/IE/NG.

**A genuinely fresh number, worth flagging:** the Corporate Income Tax rate **changed this fiscal year** — raised from 25% to 30% under the Finance Act 2026 (presented to Parliament 28 November, prior to this document's 2026-08-22 write date), explicitly "to align it with the regional average and the top marginal individual income tax rate." This isn't a stable, multi-year-unchanged figure like the UK's Corporation Tax bands — treat it as more likely to move again at the next Budget than the other figures in this set.

**A real coincidence worth noting, not evidence of anything:** `GL/`'s own `TaxRuleTest.kt`/`TaxComputationTest.kt`/`ComputeTaxUseCaseTest.kt` fixtures already use `TaxRule.create("Sierra Leone", TaxType.CORPORATE_INCOME_TAX, BigDecimal("0.30"))` — 30%, which now happens to match the real current rate. That fixture was picked as a plausible round test number before this document existed, not sourced from anything — the match is coincidental, not a sign the tests were secretly grounded in real data. Worth being clear about, so nobody later assumes the tests were more authoritative than they were.

**One area flagged as genuinely unresolved, not just unsourced:** the exact PAYE monthly band thresholds are consistently reported across secondary sources as "Le 600 / 1,200 / 1,800 / 2,400," but those sources inconsistently label the unit as old Leone (SLL, pre-2022) vs. New Leone (SLE, post-2022 redenomination, 1 SLE = 1,000 SLL) — an official NRA PDF that should resolve this couldn't be extracted (binary/corrupted on fetch). The band *structure* (five bands, 0%/15%/20%/25%/30%) is consistent everywhere and trustworthy; the *unit* on the threshold values is not confirmed. See §4.

---

## 1. Currency

| Setting | Value | Grounded in |
|---|---|---|
| ISO 4217 code | `SLE` | Already one of the four v1 currencies (`FiSH_GL_Engine_Spec.md`); `SLE` specifically (not `SLL`) — Sierra Leone redenominated in 2022 (1 New Leone = 1,000 old Leone), and `SLE` is the current code |
| Decimal places | 2 | Same JDK-derived `Money` behavior — `Currency.getInstance("SLE").defaultFractionDigits` |
| Symbol | `Le` | Used in prose throughout `docs/SL/FiSH_GL_Business_Plan.md` (e.g. "SLE-denominated"). Not currently stored or rendered anywhere in code — same gap already flagged for `£`/`€`/`₦` |

---

## 2. Corporate Income Tax — maps to the already-built `TaxType.CORPORATE_INCOME_TAX`

| Item | Value |
|---|---|
| Standard rate | **30%** (Finance Act 2026 — raised from 25%) |

Flat rate, no small-company exemption or tiering identified in this sourcing pass (unlike the UK's marginal relief, Ireland's trading/passive split, or Nigeria's turnover-and-assets exemption) — the simplest of the four `TaxRule`-shape gaps encountered so far, since a single flat `rate: BigDecimal` already fits this one directly. Worth double-checking against a primary NRA source before treating "no exemption" as confirmed rather than merely "not found in this pass."

---

## 3. GST (Goods and Services Tax) — Sierra Leone's VAT-equivalent, **not yet computable anywhere in this codebase**

Sierra Leone calls this GST, not VAT — the same `TaxType` gap as the UK/IE/NG's VAT sections, just different terminology. Unlike the UK/Ireland/Nigeria's multi-band VAT, Sierra Leone's GST is a **single flat rate**, no reduced/zero-rate tiers identified in this sourcing pass.

| Rate | Value | Base |
|---|---|---|
| Standard (only) rate | 15% | Total taxable value — for imports, CIF value plus import duty (i.e. GST is charged on top of duty-inclusive value, not on the pre-duty CIF value alone) |

Administered by the Commissioner General of the NRA. In effect since 2009, per the sourcing pass — the most stable of this document's figures.

---

## 4. PAYE (Pay As You Earn) — for `HR/`'s `PayrollTaxRule`, a jurisdiction beyond its current "UK and Ireland first" scope, recorded as reference data ahead of any confirmed plan to add it

**Band structure (confirmed, consistent across sources):**

| Band | Rate |
|---|---|
| First Le 600/month | 0% (tax-free threshold) |
| Next Le 600/month | 15% |
| Next Le 600/month | 20% |
| Next Le 600/month | 25% |
| Above Le 2,400/month | 30% |

**Unresolved:** whether "Le 600" above means 600 New Leone (SLE) or 600 old Leone (SLL) — secondary sources uniformly write "SLL 600" but Sierra Leone's minimum wage (cited alongside these bands as recently rising from "SLL 600 to SLL 800") is far more consistent with New Leone figures post-2022 redenomination than with pre-2022 old-Leone figures, suggesting a labeling error in the secondary sources rather than a real SLL figure — but this is an inference, not a confirmed fact. Needs a primary NRA source (the one PDF found in this pass failed to extract as readable text) before these thresholds are used for anything beyond illustration.

---

## 5. NASSIT (National Social Security and Insurance Trust) — for `HR/`'s `PayrollTaxRule`, Sierra Leone's NI/PRSI/pension equivalent

| Party | Rate | Base |
|---|---|---|
| Employee | 5% | Covered earnings (basic salary) — excludes food concessions, housing/travel allowances, overtime, bonuses, commissions |
| Employer | 10% | Same base |
| Combined | 15% | — |

The most confidently sourced payroll-levy figure in this document — consistent across every source checked, no conflicting unit or currency-label issue like §4's PAYE thresholds.

---

## Sources

- [Sierra Leone Corporate Tax Rate 2026 (Take-profit.org)](https://take-profit.org/en/statistics/corporate-tax-rate/sierra-leone/)
- [Sierra Leone MOF Presents 2026 Budget Statement (Bloomberg Tax)](https://news.bloombergtax.com/daily-tax-report-international/sierra-leone-mof-presents-2026-budget-statement)
- [Goods and Services Tax (National Revenue Authority)](https://mail.nra.gov.sl/individuals-and-partnerships/goods-and-services-tax)
- [Sierra Leone Tax Tables | Income Tax Rates, PAYE Bands, Thresholds and Withholding](https://sl.icalculator.com/income-tax-rates.html)
- [Employment Cost Calculator for Sierra Leone (Rivermate)](https://rivermate.com/guides/sierra-leone/employment-cost-calculator)
- [Pay As You Earn (PAYE) Compliance Management in Sierra Leone (The Betts Firm)](https://thebettsfirmsl.com/blog/pay-as-you-earn-paye-compliance-management-in-sierra-leone)
