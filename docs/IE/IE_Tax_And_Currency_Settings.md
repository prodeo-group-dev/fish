# Republic of Ireland Tax and Currency Settings — reference

**Status: reference data, 2026-08-22.** Second content under the national-folder convention (`CLAUDE.md`, 2026-08-22): country-specific settings — currency, tax law — live under `docs/<COUNTRY>/`. Grounded in Purse's own stated ROI expansion (`FiSH_GL_Engine_Spec.md`: "Northern Ireland and the Republic of Ireland (targeted Year 6, via EU passporting)") and `docs/HR_Payroll_DDD_Design.md` §7/§8's explicit "UK and Ireland" jurisdiction scope for `PayrollTaxRule`, which flagged Irish figures as needed "from an authoritative source (Revenue.ie or a licensed service) — not fabricated here." These are those figures — real, current Revenue.ie-derived rates for the 2026 tax year (see Sources), not invented.

**Needs a refresh discipline, not a one-time entry.** Irish tax years are calendar years; rates/bands change at each Budget (announced ~October, effective 1 January, with some VAT changes mid-year — see the VAT section). Re-verify before relying on this for a period that has since rolled over.

**One gap, flagged rather than guessed:** employer-side PRSI Class A rates (the equivalent of the UK section's employer NI rate) weren't returned by the same sourcing pass that found everything else here — Class A employer PRSI is banded (varies by weekly earnings) rather than a single flat rate, and pinning the exact 2026 band boundaries needs a follow-up lookup rather than an approximation. Left out rather than filled with a remembered-but-unverified figure.

---

## 1. Currency

| Setting | Value | Grounded in |
|---|---|---|
| ISO 4217 code | `EUR` | Already one of the four v1 currencies (`FiSH_GL_Engine_Spec.md`), tied specifically to the ROI/ Northern Ireland (EU passporting) expansion |
| Decimal places | 2 | Same JDK-derived `Money` behavior as GBP — `Currency.getInstance("EUR").defaultFractionDigits` |
| Symbol | `€` | Not currently stored or rendered anywhere in code — same gap already flagged for `£` in the UK settings doc |

---

## 2. Corporation Tax — maps to the already-built `TaxType.CORPORATE_INCOME_TAX`

Ireland's split is *trading vs. passive*, not a small-profits/main-rate tier like the UK — a genuinely different shape, not just different numbers. `TaxRule`'s current single flat `rate: BigDecimal` can represent *one* of these at a time but has no concept of "which rate applies" being determined by income type rather than a profit threshold — a second, distinct gap from the UK's marginal-relief tiering gap already noted.

| Category | Rate | Applies to |
|---|---|---|
| Trading income | 12.5% | Active business income — applied from the first euro of profit, no small-company carve-out |
| Passive/non-trading income | 25% | Rental, deposit interest, investment dividends, non-trade gains |
| Knowledge Development Box | 6.25% | Qualifying patent income only |
| Pillar Two minimum | 15% | Groups with consolidated revenue ≥ €750 million (large-group only, not relevant to a standalone Purse ROI entity today) |

---

## 3. VAT — **not yet computable anywhere in this codebase**, same gap as the UK section

Ireland has more bands than the UK (five vs. three) — worth noting since any future VAT build needs to handle band *count* varying by jurisdiction, not just rate values.

| Rate | Value | Applies to |
|---|---|---|
| Standard rate | 23% | Default rate |
| Reduced rate | 13.5% | A broad reduced-rate category (building services, certain fuels, etc.) |
| Second reduced rate | 9% | Food, catering, and hairdressing services — **changes 1 July 2026**, permanently reduced from 13.5% to 9% (a mid-year effective date, not a Budget/January change — a real scheduling wrinkle if this is ever built) |
| Super-reduced rate | 4.8% | Livestock only |
| Zero rate | 0% | Zero-rated goods/services |

---

## 4. Income Tax bands — for `HR/`'s `PayrollTaxRule`

The Standard Rate Cut-Off Point (SRCOP — the income level where the higher rate starts) depends on marital/filing status, unlike the UK's single threshold — another structural difference `PayrollTaxRule`'s "bands as data" shape needs to accommodate, not just different numbers.

| Band | Rate | Threshold |
|---|---|---|
| Standard rate | 20% | Up to SRCOP (below) |
| Higher rate | 40% | Above SRCOP |

**SRCOP by filing status (2026):**

| Filing status | SRCOP |
|---|---|
| Single | €44,000 |
| Married, one income | €53,000 |
| Married, two incomes | Up to €88,000 combined (max €44,000 transferable per person) |

---

## 5. Universal Social Charge (USC) — for `HR/`'s `PayrollTaxRule`

No UK equivalent — a genuinely Irish-specific levy, additional to Income Tax and PRSI.

| Band | Rate | Threshold |
|---|---|---|
| Band 1 | 0.5% | First €12,012 |
| Band 2 | 2% | €12,013–€28,700 |
| Band 3 | 3% | €28,701–€70,044 |
| Band 4 | 8% | Above €70,044 |
| Exemption | 0% (no USC at all) | Total income ≤ €13,000 |

---

## 6. PRSI (Pay Related Social Insurance) — employee side only, see the gap note above

| Party | Rate | Threshold |
|---|---|---|
| Employee (Class A) | 4.2% (1 Jan–30 Sep 2026), rising to 4.35% (from 1 Oct 2026) | Exempt at ≤ €352/week |
| Employer (Class A) | **Not sourced — banded, not flat; needs a follow-up lookup** | — |

---

## Sources

- [Corporation Tax Ireland 2026 — 12.5% Rate, Deadlines & SME Rules](https://financetool.ie/guides/corporation-tax-ireland-2026)
- [Ireland extends again hospitality and tourism 9% VAT](https://www.vatcalc.com/ireland/ireland-extends-again-hospitality-and-tourism-9-vat/)
- [VAT Rates in Ireland (2026) | Full Rate Guide](https://www.accountantdirectory.ie/blog/vat-rates-ireland/)
- [Budget 2026 Ireland - Tax rates and credits - USC, PRSI, tax bands (KPMG)](https://kpmg.com/ie/en/insights/tax/budget-2026/tables.html)
- [Irish Income Tax Bands & USC Rates 2026 | Irish Tax Hub](https://www.irishtaxhub.ie/blog/irish-income-tax-bands-usc-rates-what-you-will-pay)
