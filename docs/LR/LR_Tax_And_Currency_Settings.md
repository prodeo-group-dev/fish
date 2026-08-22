# Liberia Tax and Currency Settings — reference

**Status: reference data, 2026-08-22.** Fifth national-folder document, following SL directly — Liberia is named alongside Sierra Leone, Guinea, and Côte d'Ivoire in the spec's own tax-computation scope list (`FiSH_GL_Engine_Spec.md`: "starting with Sierra Leone, Liberia, Guinea, Côte d'Ivoire"), so like SL this closes a previously-open gap rather than adding new scope. Real, current Liberia Revenue Authority (LRA)-derived figures for the 2026 fiscal year (see Sources) — not fabricated, same discipline as UK/IE/NG/SL.

**Currency: deliberately not onboarded here — SLE is the only recognized currency.** Confirmed 2026-08-22: this system will only recognise `SLE` across the Mano River operation, not each country's own local currency. Liberia's own currency (LRD, the Liberian dollar — and in practice, USD circulates alongside it in a de facto dual-currency system) is documented below **for reference only**, so the decision not to onboard it is visible and intentional rather than a silent omission. Nothing in `Money`/`Company.baseCurrency`/anywhere else should be seeded with `LRD` on the strength of this document — if Liberia entities transact in this system, they do so in SLE, per this explicit product decision, not LRD.

**Timing is unusually live here, more than any prior document in this set.** Liberia is mid-transition: GST rose from 12% to 13% under the *Liberia Tax Amendment Act of December 2025* (approved 24 March 2026, published 1 April 2026, effective retroactively to 1 January 2026), and a full GST→VAT replacement is separately planned for 2027 (VAT registration opening from 1 July 2026, launch likely at 18%). Treat the GST figures below as accurate for 2026 specifically, not as a stable multi-year baseline — this document would need a real rewrite, not just a rate tweak, once VAT actually launches.

---

## 1. Currency (reference only, not onboarded — see status note above)

| Setting | Value | Note |
|---|---|---|
| ISO 4217 code | `LRD` | Liberian dollar — **not recognized in this system**; SLE is the sole recognized currency per the 2026-08-22 product decision |
| Practical note | USD circulates widely alongside LRD in Liberia's real economy (a de facto, not de jure, dual-currency system) | Recorded for context only — doesn't change the SLE-only decision above |

---

## 2. Corporate Income Tax — maps to the already-built `TaxType.CORPORATE_INCOME_TAX`

| Category | Rate |
|---|---|
| General companies | 25% |
| Mining and oil-sector companies | 30% |

A sector-dependent rate, not a profit-threshold tier (UK), an income-type split (Ireland), or a turnover-and-assets exemption (Nigeria) — a fourth distinct shape `TaxRule`'s flat `rate` field can't represent on its own, joining the growing list of jurisdiction-specific complications across this document set.

---

## 3. GST (Goods and Services Tax) — Liberia's VAT-equivalent, **not yet computable anywhere in this codebase**, and mid-transition (see status note)

| Rate | Value | Applies to | Effective |
|---|---|---|---|
| Standard rate | 13% | Services generally | 1 January 2026 (Liberia Tax Amendment Act, enacted 24 March 2026) — raised from 12% |
| Telecommunications | 15% | Telecom services specifically — kept separate from the general rate change | Same act |

**Known future change, not yet in effect:** GST is planned to be fully replaced by VAT in 2027 (likely 18% launch rate), with registration opening from 1 July 2026. Not reflected in the figures above since it hadn't launched as of this document's 2026-08-22 write date.

---

## 4. PAYE — for `HR/`'s `PayrollTaxRule`, a jurisdiction beyond its current "UK and Ireland first" scope

| Band | Rate | Threshold (LRD) |
|---|---|---|
| Exempt | 0% | Up to 100,000 |
| Band 2 | 10% | 100,001–200,000 |
| Band 3 | 15% | 200,001–500,000 |
| Band 4 | 25% | Above 500,000 |

Denominated in LRD in the source data even though LRD itself isn't onboarded as a recognized currency here (§1) — worth keeping distinct: PAYE *band thresholds* are jurisdiction reference data regardless of which currencies this system actually posts transactions in. If Liberia payroll is ever computed through `PayrollTaxRule` while the system only recognizes SLE, these LRD thresholds would need an explicit conversion step — not addressed here, flagged as a real future gap.

---

## 5. NASSCORP (National Social Security and Welfare Corporation) — Liberia's NI/PRSI/NASSIT equivalent, **genuinely conflicting sources, not resolved**

Unlike SL's NASSIT figure (the cleanest in the whole document set), Liberia's sourcing pass returned two incompatible versions:

| Source version | Employer | Employee | Structure |
|---|---|---|---|
| Version A | 5% of gross monthly earnings | 5% of gross monthly earnings | Flat, symmetric |
| Version B | 3% of gross salary | 4.75% of gross salary | Split: National Pensions Fund (6% combined) + Employment Injury Scheme (1.75%, employer-side implied) |

**Not resolved in this pass** — recorded as an open conflict rather than picking one arbitrarily, same discipline as SL's PAYE-threshold-unit gap and Ireland's employer PRSI gap. Needs a primary LRA/NASSCORP source before either version is used for anything beyond illustration. One fact both versions agree on: the employee's mandatory NASSCORP contribution is deductible from gross income for income tax purposes.

---

## Sources

- [Liberia's 2026 Budget Proposes Digital Tax, GST Hike, and Tax Incentive Reforms (VATupdate)](https://www.vatupdate.com/2026/01/17/liberias-2026-budget-proposes-digital-tax-gst-hike-and-tax-incentive-reforms/)
- [Liberia: Draft 2026 budget includes measures to tax digital economy, increase in GST (KPMG)](https://kpmg.com/us/en/taxnewsflash/news/2026/01/liberia-draft-budget-tax-measures.html)
- [Liberia to Raise GST to 13% in 2026, Plans 18% VAT Launch in 2027 (VATupdate)](https://www.vatupdate.com/2025/11/13/liberia-to-raise-gst-to-13-in-2026-plans-18-vat-launch-in-2027/)
- [IMPORTANT REVENUE NOTICE: Adjustment to GST Rates (Liberia Revenue Authority)](https://revenue.lra.gov.lr/important-revenue-noticeadjustment-to-goods-and-services-tax-gst-rates/)
- [How to Calculate PAYE Tax in Liberia: A Step-by-Step Guide for 2026 (Cardinal Point Advisors)](https://cardinalpointadvisors.net/how-to-calculate-paye-tax-in-liberia-a-step-by-step-guide-for-2026/)
- [Employment Taxes in Liberia (Rivermate)](https://rivermate.com/guides/liberia/taxes)
