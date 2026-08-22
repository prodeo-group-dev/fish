# Nigeria Tax and Currency Settings — reference

**Status: reference data, 2026-08-22. Scope flag, not a scope decision.** Unlike `docs/UK/` and `docs/IE/`, Nigeria is not otherwise mentioned anywhere in this project — the Mano River market focus is consistently defined as Sierra Leone, Liberia, Guinea, and Côte d'Ivoire only (`docs/FiSH_GL_Engine_Spec.md`), and no business plan, requirements doc, or `CLAUDE.md` reference names Nigeria as a target market. This document was built on explicit instruction despite that gap, not because Nigeria's in-scope status was independently confirmed elsewhere. If Nigeria is a genuine future target, this is a useful head start; if it isn't, this is the one national-folder document in the set that doesn't correspond to anything else in the project and should be treated as provisional until that's settled.

**Timing note, unusually significant here:** Nigeria's entire tax system changed under the Nigeria Tax Act (NTA) 2025, effective **1 January 2026** — this document reflects the *new* regime, not the prior Companies Income Tax Act/Personal Income Tax Act framework it replaced. Real, current figures as of 2026-08-22 (see Sources), not invented, same discipline as the UK/IE documents.

**One area flagged as actively unsettled, not just unsourced:** employer pension contribution rates are under active review by PenCom (the National Pension Commission) as of August 2026 — a proposed employer-rate increase hasn't been finalized, and organised private-sector employers are opposing it. The rate recorded below (10% minimum) is the *current*, not-yet-superseded figure — treat it as more likely to change soon than anything else in this document.

---

## 1. Currency

| Setting | Value | Grounded in |
|---|---|---|
| ISO 4217 code | `NGN` | Not among the four v1 currencies named in `FiSH_GL_Engine_Spec.md` (GBP, EUR, SLE, USD) — genuinely new to this project, consistent with Nigeria's own unconfirmed scope status above |
| Decimal places | 2 | Same JDK-derived `Money` behavior — `Currency.getInstance("NGN").defaultFractionDigits` |
| Symbol | `₦` | Not currently stored or rendered anywhere in code — same gap already flagged for `£`/`€` |

---

## 2. Companies Income Tax (CIT) — maps to the already-built `TaxType.CORPORATE_INCOME_TAX`

A third distinct shape, after the UK's tiered small-profits/main-rate and Ireland's trading/passive split: Nigeria is a **flat rate with a full small-company exemption below a turnover-and-assets threshold**, not a reduced rate.

| Item | Value |
|---|---|
| Standard rate | 30% flat, on all profits **including capital gains** (NTA 2025 folded Capital Gains Tax into CIT for companies — previously a separate 10% CGT) |
| Small company exemption | Full exemption from CIT (and CGT and the Development Levy below) if annual turnover ≤ ₦100,000,000 **and** total fixed assets ≤ ₦250,000,000 (raised from a ₦25,000,000 turnover threshold under the prior regime — both figures matter, not just turnover) |
| Development Levy | 4% of assessable profits (pre-tax-depreciation, pre-losses) — applies to all non-small companies, consolidates four prior separate levies (Tertiary Education Tax, IT Levy, NASENI, Police Trust Fund) into one |

`TaxRule`'s flat `rate` field can represent the 30% headline rate, but not the turnover-*and*-assets small-company exemption test, nor the separate Development Levy line — a third distinct gap, alongside the UK's marginal-relief tiering and Ireland's trading/passive split, none of which share a common shape.

---

## 3. VAT — **not yet computable anywhere in this codebase**, same gap as UK/IE

| Rate | Value | Applies to |
|---|---|---|
| Standard rate | 7.5% | Default rate — confirmed *not* increased to the originally proposed 12.5% under NTA 2025 |
| Zero rate | 0% | Food and basic consumables, effective 1 January 2026 (a scope expansion — these weren't zero-rated before) |
| Exempt | N/A (no VAT charged, no input-VAT reclaim) | Healthcare services, medicines, education services, passenger road transport |

---

## 4. Personal Income Tax (PAYE) bands — for `HR/`'s `PayrollTaxRule`

A sixth jurisdiction beyond `PayrollTaxRule`'s current "UK and Ireland first" scope (`docs/HR_Payroll_DDD_Design.md` §8.1) — recorded here as reference data only, same as VAT above, ready for if/when Nigeria is actually confirmed in scope.

| Band | Rate | Threshold |
|---|---|---|
| Exempt | 0% | First ₦800,000/year |
| Band 2 | 15% | ₦800,001–₦3,000,000 |
| Band 3 | 18% | ₦3,000,001–₦12,000,000 |
| Band 4 | 21% | ₦12,000,001–₦25,000,000 |
| Band 5 | 23% | ₦25,000,001–₦50,000,000 |
| Band 6 | 25% | Above ₦50,000,000 |

**Minimum-wage carve-out:** employees earning at or below the national minimum wage (₦70,000/month, i.e. ₦840,000/year) are exempt from PAYE deduction entirely — a separate rule from the 0% band above, not just a restatement of it (it's a *deduction* exemption, not merely a 0%-rate band result), worth keeping distinct if `PayrollTaxRule` ever models this.

---

## 5. Pension contributions — for `HR/`'s `PayrollTaxRule`, Nigeria's rough NI equivalent

Under the Pension Reform Act (2014, as currently in force — **not** part of the NTA 2025 reform, a separate statute), not a tax in the strict sense but a mandatory statutory payroll deduction, same category as UK NI / Irish PRSI.

| Party | Rate | Note |
|---|---|---|
| Employee | 8% of monthly emoluments | Stable, not under review |
| Employer | 10% minimum of monthly emoluments | **Under active PenCom review as of August 2026** — a proposed increase (employer-side only, per PenCom's own public statement) hasn't been finalized; treat 10% as current-but-unstable, not settled |
| Combined | 18% minimum | Will rise if the employer-side proposal is adopted |

---

## Sources

- [Nigeria Tax Act, 2025 has been signed – highlights (EY)](https://www.ey.com/en_gl/technical/tax-alerts/nigeria-tax-act-2025-has-been-signed-highlights)
- [Nigeria Tax Act 2025 Goes into Effect on Jan 1, 2026 (Safeguard Global)](https://www.safeguardglobal.com/resources/blog/nigeria-tax-act-2025/)
- [Nigeria's tax reforms set lowest VAT rate among African peers (Businessday NG)](https://businessday.ng/business-economy/article/nigerias-tax-reforms-set-lowest-vat-rate-among-african-peers/)
- [Understanding Personal Income Tax Under The Nigerian Tax Act 2025 (Mondaq)](https://www.mondaq.com/nigeria/capital-gains-tax/1726922/understanding-personal-income-tax-under-the-nigerian-tax-act-2025)
- [Companies Income Tax, 4% Development Levy & ETR in Nigeria (SmartSMSSolutions)](https://smartsmssolutions.com/resources/blog/ng/companies-income-tax-development-levy-effective-tax-rate)
- [PenCom to increase statutory pension contribution rates in Reform Act review (Nairametrics)](https://nairametrics.com/2026/07/22/pencom-to-increase-statutory-pension-contribution-rates-in-reform-act-review/)
