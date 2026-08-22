# Guinea Tax and Currency Settings — reference

**Status: reference data, 2026-08-22.** Sixth national-folder document — Guinea is the third of the four Mano River jurisdictions named in the spec's own tax-computation scope list (`FiSH_GL_Engine_Spec.md`: "starting with Sierra Leone, Liberia, Guinea, Côte d'Ivoire"), closing a previously-open gap, same as SL and Liberia. Real, current Direction Générale des Impôts (DGI)-derived figures for the 2026 fiscal year (see Sources) — not fabricated, same discipline as the rest of this document set.

**Currency: deliberately not onboarded here — SLE is the only recognized currency.** Same 2026-08-22 confirmation as Liberia's document: this system only recognises `SLE` across the Mano River operation. Guinea's own currency (GNF, the Guinean franc) is documented below **for reference only**, so the decision not to onboard it stays visible and intentional. Nothing in `Money`/`Company.baseCurrency`/anywhere else should be seeded with `GNF` on the strength of this document.

**Best-sourced income-tax band table in this entire document set, worth noting.** Unlike SL's unresolved PAYE-threshold-unit gap or Liberia's conflicting NASSCORP figures, Guinea's ITS bands trace to a specific, citable legal instrument — Article 63 of Law L/2021/032/AN (the 2022 General Tax Code), in force since 1 January 2022 and still current for 2026. Where this document set has otherwise had to flag gaps, this section doesn't need to.

---

## 1. Currency (reference only, not onboarded — see status note above)

| Setting | Value | Note |
|---|---|---|
| ISO 4217 code | `GNF` | Guinean franc — **not recognized in this system**; SLE is the sole recognized currency per the 2026-08-22 product decision |
| Decimal places (for reference) | 0 | GNF has no minor unit in practice — worth noting for whenever this decision is revisited, since it'd be `Money`'s first zero-decimal-place currency if ever onboarded (same category as JPY) |

---

## 2. Corporate Income Tax (Impôt sur les Sociétés) — maps to the already-built `TaxType.CORPORATE_INCOME_TAX`

| Category | Rate |
|---|---|
| Standard rate | 35% |
| Mining companies (exploitation phase) | 30% (reduced) |

The highest standard headline rate across the whole document set (UK 25%, Ireland 12.5%/25%, Nigeria 30%, SL 30%, Liberia 25%/30%) — a genuinely different competitive/fiscal position worth being aware of if this is ever used for anything comparative across the Mano River markets, not just a number to plug in. Same sector-dependent shape as Liberia's mining/oil carve-out (a reduced, not increased, rate for a specific sector) — a fifth distinct `TaxRule`-shape complication in this set, though it happens to structurally resemble Liberia's rather than introducing a wholly new pattern.

---

## 3. TVA (Taxe sur la Valeur Ajoutée) — Guinea's actual VAT, **not yet computable anywhere in this codebase**

Unlike SL/Liberia's GST terminology, Guinea genuinely uses VAT (TVA) — worth being precise about the terminology difference across the Mano River set, not just treating "GST" and "TVA/VAT" as interchangeable labels for the same concept.

| Rate | Value |
|---|---|
| Standard rate | 18% |

No reduced/zero-rate tiers identified in this sourcing pass — a single flat rate, same simplicity as SL's GST.

---

## 4. ITS (Impôt sur les Traitements et Salaires) — for `HR/`'s `PayrollTaxRule`, best-sourced band table in this document set

Six-bracket progressive scale, Article 63 of Law L/2021/032/AN (2022 General Tax Code, in force since 1 January 2022). Assessment base is gross salary minus capped employee CNSS contributions (capped at 125,000 GNF/month) and mandatory pension withholdings — Article 59's flat-rate allowances were repealed, worth noting if this is ever compared against an older source that still assumes they apply.

| Band | Monthly taxable income (GNF) | Rate |
|---|---|---|
| 1 | 0–1,000,000 | 0% |
| 2 | 1,000,001–3,000,000 | 5% |
| 3 | 3,000,001–5,000,000 | 8% |
| 4 | 5,000,001–10,000,000 | 10% |
| 5 | 10,000,001–20,000,000 | 15% |
| 6 | Above 20,000,000 | 20% |

Each rate applies only to its own bracket, not the whole salary (standard marginal-bracket mechanics) — the lowest top marginal rate (20%) of any jurisdiction in this document set, notably lower than SL/Nigeria/Liberia's 25–30% top bands, despite Guinea's Corporate Income Tax being the highest in the set. Worth being aware of as a real asymmetry between the two tax bases, not an inconsistency to reconcile.

---

## 5. CNSS (Caisse Nationale de Sécurité Sociale) — Guinea's NI/PRSI/NASSIT equivalent

| Party | Rate | Note |
|---|---|---|
| Employer | 18% | Composed of: family allowances (6%), workplace accidents (4%), health expenses (4%), various allowances (4%) — a genuinely itemized breakdown, not a flat headline figure like SL/Liberia's employer rates |
| Employee | 5% | Capped at 125,000 GNF/month (same cap referenced in §4's ITS assessment base) |
| Additional employer levies (separate from CNSS itself) | Lump-Sum Payment 6% (General Tax Code Article 201), Apprenticeship Tax 2% or Training Contribution 1.5% per headcount | Not part of the 18% CNSS figure — a real additional payroll-cost layer if this is ever used for actual cost-of-employment modeling, not just tax computation |

---

## Sources

- [Présentation de la Guinée : Fiscalité (Société Générale)](https://import-export.societegenerale.fr/fr/fiche-pays/guinee/presentation-fiscalite)
- [Cadre juridique et fiscal (Invest in Guinea)](https://www.invest.gov.gn/page/cadre-juridique-et-fiscal?onglet=fiscalite-des-entreprises)
- [Employer Taxes & Social Contributions in Guinea - Guide 2026 (Africarrieres)](https://africarrieres.com/guinea/en/guide/employeur-entreprise/employer-taxes)
- [Calculating Progressive ITS in Guinea 2026: The Complete Guide for HR and CFOs (Wali HRIS)](https://walirh.com/en/blog/calcul-its-progressif-guinee-2026)
- [Employment Taxes in Guinea (Rivermate)](https://rivermate.com/guides/guinea/taxes)
