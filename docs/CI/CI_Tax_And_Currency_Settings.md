# Côte d'Ivoire Tax and Currency Settings — reference

**Status: reference data, 2026-08-22.** Seventh national-folder document — Côte d'Ivoire is the fourth and last of the Mano River jurisdictions named in the spec's own tax-computation scope list (`FiSH_GL_Engine_Spec.md`: "starting with Sierra Leone, Liberia, Guinea, Côte d'Ivoire"), so this completes that list rather than adding new scope, same as SL/LR/GN. Real, current Direction Générale des Impôts (DGI)-derived figures for the 2026 fiscal year (see Sources) — not fabricated, same discipline as the rest of this document set.

**Currency: deliberately not onboarded here — SLE is the only recognized currency.** Same 2026-08-22 confirmation as Liberia's and Guinea's documents: this system only recognises `SLE` across the Mano River operation. Côte d'Ivoire's own currency (XOF, the West African CFA franc — shared across all eight UEMOA states, not Côte d'Ivoire-specific) is documented below **for reference only**. Nothing in `Money`/`Company.baseCurrency`/anywhere else should be seeded with `XOF` on the strength of this document.

**A genuinely recent structural reform, worth flagging like SL's rate change and Liberia's GST transition.** Côte d'Ivoire's payroll income tax used to be three separate taxes — IS (Impôt sur Salaires), IGR (Impôt Général sur le Revenu), and CN (Contribution Nationale) — abolished and merged into a single unified ITS (Impôt sur les Traitements et Salaires) by Ordinance 2023-718/719, effective 1 January 2024. Any source describing "IGR bands" or "the CN" separately predates this reform and should be treated as superseded, not a second valid figure to reconcile against ITS.

---

## 1. Currency (reference only, not onboarded — see status note above)

| Setting | Value | Note |
|---|---|---|
| ISO 4217 code | `XOF` | West African CFA franc — **not recognized in this system**; SLE is the sole recognized currency per the 2026-08-22 product decision |
| Decimal places (for reference) | 0 | XOF has no minor unit in practice — same zero-decimal-place category as Guinea's GNF, if ever onboarded |
| Scope note | Shared across all eight UEMOA member states (Benin, Burkina Faso, Côte d'Ivoire, Guinea-Bissau, Mali, Niger, Senegal, Togo) | Worth knowing this currency isn't Côte d'Ivoire-specific, unlike every other currency in this document set — relevant only if the SLE-only decision above is ever revisited |

---

## 2. Impôt sur les Bénéfices Industriels et Commerciaux (BIC) — maps to the already-built `TaxType.CORPORATE_INCOME_TAX`

| Category | Rate |
|---|---|
| Resident companies (registered seat or effective management in Côte d'Ivoire) | 25% |
| Non-resident companies | 35% |
| Non-established online marketplaces (2026 measure) | 30% on Côte d'Ivoire-sourced turnover ≥ 50,000,000 XOF/year |

A residency-dependent split, not a profit-threshold tier (UK), an income-type split (Ireland), a turnover-and-assets exemption (Nigeria), or a sector carve-out (Liberia/Guinea) — a sixth distinct `TaxRule`-shape complication across this document set. The non-established-marketplace rate is new for 2026 and specifically aimed at digital platforms without a local establishment — a genuinely novel category (not "resident" or "non-resident" in the traditional physical-presence sense) worth flagging if this system ever needs to classify a counterparty for tax purposes.

---

## 3. TVA (Taxe sur la Valeur Ajoutée) — **not yet computable anywhere in this codebase**

Genuine VAT terminology, same as Guinea (not GST like SL/Liberia). Notable for a real mid-document-set precedent: a rate change that happened *twice* within two weeks in January 2026.

| Rate | Value | Applies to | Effective |
|---|---|---|---|
| Standard rate | 18% | Default rate | — |
| Reduced rate | 9% | Jute/sisal fibers, livestock/poultry feed and their inputs, fertilizer-manufacturing inputs and packaging | 17 January 2026 (Order No. 2026-03, 7 January 2026) |

**Worth noting as a real volatility signal, not just a footnote:** these agricultural inputs were *exempt* from VAT, then briefly moved to the full 18% standard rate, then reduced to 9% — all within roughly two weeks in January 2026, per the sourcing pass. If this is ever built, the reduced-rate category shouldn't be treated as a stable, slow-moving policy the way the UK's reduced/zero VAT categories are.

---

## 4. ITS (Impôt sur les Traitements et Salaires) — for `HR/`'s `PayrollTaxRule`, unified 2024 reform (see status note above)

Six monthly brackets, applied directly to **gross salary** — no flat professional-expense deduction, unlike the pre-2024 regime.

| Band | Monthly gross salary (XOF) | Rate |
|---|---|---|
| 1 | 0–75,000 | 0% |
| 2 | 75,001–240,000 | 16% |
| 3 | 240,001–800,000 | 21% |
| 4 | 800,001–2,400,000 | 24% |
| 5 | 2,400,001–8,000,000 | 28% |
| 6 | Above 8,000,000 | 32% |

**Two deductions, and only two** — a genuinely tight, specific rule worth preserving exactly if this is ever built, not approximated:
- **Family dependents**: a flat 5,500 XOF reduction per half-share, capped at 5 shares (i.e. a maximum reduction, not an unlimited per-dependent credit) — deducted from the *computed ITS amount*, not from taxable income.
- **CNPS employee contribution** (6.3%, §5 below) — the only other deduction permitted.

---

## 5. CNPS (Caisse Nationale de Prévoyance Sociale) — Côte d'Ivoire's NI/PRSI/NASSIT/CNSS equivalent, most granularly itemized in this document set

| Party | Rate | Composition |
|---|---|---|
| Employee | 6.3% | Retirement only |
| Employer | 14.15%–17.15% | Retirement 7.70%, family benefits 5%, maternity 0.75%, workplace accidents 2%–5% (the range within the range — accident rate varies by risk category, driving both the employer total's own range and the overall combined range) |
| Combined | 20.45%–23.45% | — |

**Separately, CMU (Couverture Maladie Universelle — universal health coverage)** is folded into CNPS contributions but tracked as its own line: employee 1.5%, employer 3%. Worth keeping distinct from the pension-branch figures above if this is ever modeled, since it's a different scheme (health, not pension/family/accident) bundled into the same collection mechanism.

**Caps, not flat across all bands:**
- Retirement ceiling: 3,375,000 XOF/month
- Family benefits / maternity / workplace accidents ceiling: 70,000 XOF/month (a much lower cap than the retirement ceiling — worth not conflating the two if this is ever computed)

---

## Sources

- [Côte d'Ivoire : Annexe fiscale 2026, éclairage sur les nouvelles règles (KOACI)](https://www.koaci.com/article/2026/01/15/cote-divoire/economie/cote-divoire-annexe-fiscale-2026-eclairage-sur-les-nouvelles-regles-qui-vont-impacter-les-entreprises-ivoiriennes_193630.html)
- [Côte d'Ivoire : les principales mesures de la Loi de Finances pour 2026 (Deloitte)](https://blog.avocats.deloitte.fr/cote-divoire-les-principales-mesures-de-la-loi-de-finances-pour-2026/)
- [La Côte d'Ivoire instaure une TVA de 9 % sur les aliments pour animaux (Team France Export)](https://www.teamfrance-export.fr/infos-sectorielles/39967/39967-la-cote-divoire-instaure-une-tva-de-9-sur-les-aliments-pour-animaux)
- [Calcul Impôt sur Salaire (ITS) Côte d'Ivoire 2026 — Barème Unifié, CNPS, Salaire Net](https://macalculatriceenligne.com/afrique/calcul-impot-revenu-cote-ivoire/)
- [Calcul CNPS Côte d'Ivoire 2026 — Cotisations Officielles](https://macalculatriceenligne.com/afrique/calcul-cnps-cote-ivoire/)
