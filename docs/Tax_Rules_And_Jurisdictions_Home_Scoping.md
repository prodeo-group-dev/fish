# Where tax rules and jurisdictions should live: scoping note

**Status: scoping only, 2026-10-18. Docs only. Nothing here is built or changed.** Written by the Tax Jurisdiction session at the request of CM, who relayed Femi's suspicion that tax rules and jurisdictions belong in the shared `common` library. Femi agreed it should be scoped, not built. This note splits the question in two (data, and computation), compares the options for the data, recommends one, and lists what only Femi can answer.

## 1. Short answer

1. **Not in `common`.** The instinct (one source, not many copies) is right, but `common` is the wrong carrier. It is shared as source, so a rate change would mean a commit plus a rebuild and redeploy in every consuming service, which is the opposite of what Femi chose on 2026-10-06 (VAT rates as data, "a rate change is an INSERT with no deploy").
2. **The premise has moved.** Jurisdictions, VAT rates, Corporation Tax rules and each jurisdiction's currency are already reference data in GL's database, not code constants (section 2). "One source" for the jurisdiction list already exists and is already served over HTTP.
3. **Recommendation:** keep rules and jurisdictions as database reference data, owned by one service per kind of rule and read through a narrow, versioned API (option C below). The jurisdiction list stays with Company (GL today); statutory rates and rules belong to the Tax service when it exists. Computation stays with the owning service. `common` takes none of it.
4. **The real open decision is not the home of the data. It is where VAT rates live once Tax is extracted**, because GL must resolve a rate inside the same call that posts the entry (the atomicity decision of 2026-09-19). See section 6 and Q5 in section 8.

## 2. What is true today (read from GL `origin/master`, 2026-10-18)

| Piece | Where it lives now | How it changes |
|---|---|---|
| Approved jurisdictions (code, name, enabled) | `jurisdictions` table, GL migration V29. `Jurisdiction` is a two-letter value class, no longer a closed enum. | A data insert/update. `POST /tenants/{id}/companies` checks the registry; `GET /api/jurisdictions` serves the list to WEB, and its KDoc names EA, HR and Omniview as intended readers ("Only one source should provide this information", 2026-10-05). |
| Jurisdiction currency | `jurisdictions.currency`, V34 (UK GBP, IE EUR, NG NGN, SL/LR/GN/CI SLE per the standing SLE-only decision). | A data update. |
| VAT rates | `vat_rates` table, V30: `(jurisdiction, category, rate, effective_from, verified)`. Seeded: IE, UK verified; SL seeded unverified. | Femi's "Option B", 2026-10-06: an INSERT, no deploy. Only `verified = TRUE` rows form a schedule; an unverified jurisdiction answers 409 `no_vat_rate_schedule`. Rate must be in [0, 1) (CHECK). |
| Corporation Tax rules | `tax_rules` table, V5/V9, seeded by V31 for UK, IE, SL only. Rate structure stored as encoded text. | An INSERT/UPDATE. **No effective dating** (V31 says so). NG, LR, GN, CI not seeded: "each needs a decision first". |
| VAT category per product | IM, per item, moving to per jurisdiction and date (IM v5 draft, 2026-10-17). | IM data. The rate behind the category stays GL's. |
| Payroll tax (PAYE bands, NI/PRSI/USC, NASSIT, CNSS...) | Nowhere. HR's `PayrollTaxRule` takes bands from the caller and `jurisdiction` is a plain `String`; no seed exists. | Not yet data anywhere. |
| The `docs/<CODE>/..._Tax_And_Currency_Settings.md` and `.yaml` files | Repo docs. The yaml headers say "nothing reads it yet". | Hand-synced. They are now a third copy beside the migrations' seeds, so drift between them is possible and nothing checks it. |

So the "closed jurisdiction list (UK, IE, NG, SL, LR, GN, CI)" in the question was true on 2026-09-19 and has since been replaced by a registry. Two consequences for this note: (a) the data is already out of code, and (b) most of the "every service reads one source" need is already met for the jurisdiction list; for rates it is mostly not needed, because each rate has exactly one reader (GL for VAT, GL Tax for Corporation Tax, Payroll for statutory deductions later). The services that need the jurisdiction *code* (IM v5, EA, WEB) read it, they do not compute with it.

## 3. The question, split in two

**DATA:** the list of jurisdictions and the effective-dated rate and rule tables. Who stores them, who is allowed to change them, and how a change reaches a running service.

**COMPUTATION:** the arithmetic that applies a rule to a transaction or a period (VAT per line at posting, Corporation Tax per period, payroll deductions per pay run). Who owns the code.

These need different answers, and mixing them is what makes `common` look attractive: it suits the shape of the computation code (small, pure, shared) and does not suit the data (changes often, must not need a deploy).

## 4. Options for the DATA

- **A. `common`**, shared as source (a git submodule each consumer compiles in).
- **B. A versioned data package**, a git repository of data files consumed as a pinned submodule (the `fish-contracts` mechanism, or a sibling to it).
- **C. Service-owned data behind an API**: the rows live in the database of the service that owns them (GL today, the Tax service later), changed by a data write, read by other services through a narrow versioned contract with fixtures.

| | A. `common` | B. Versioned data package | C. Service-owned, read via API |
|---|---|---|---|
| **Who changes it, how often** | A developer, by commit. Rates move often and unpredictably: Ireland's second reduced VAT rate changes 1 Jul 2026 mid-year; Liberia's GST moved 12% to 13% in March 2026 with a replacement planned for 2027; Cote d'Ivoire's agricultural TVA changed three times in two weeks in January 2026 (docs/IE, LR, CI). | A developer or Femi, by commit and review; diffs are readable. Same frequency as A. | A data write, audited, by the person who is allowed to (today the `verified` flip is Femi's act: the SL row says "not live until Femi confirms"). Developers are not in the loop for a rate change. |
| **Effective dating** | Would have to be built into the library; the only existing model is `vat_rates.effective_from`. | Same as A. Files can carry `effective_from`. | Already modelled for VAT (`effective_from`, latest row not after the transaction date). Missing for Corporation Tax rules; payroll tables not yet modelled. |
| **How a change reaches a running service** | Commit to `common`, then in each consumer bump the pointer, rebuild, deploy. The README names GL, SOP, POP, IM, HR as consumers (EA's build also wires it). Every deploy goes through CM, so one rate change is about six deploy cycles. WEB (TypeScript) cannot consume Kotlin source at all. | Same pointer-bump-and-deploy cycle per consumer. Meant for test fixtures; its rule is "synthetic data only", so real statutory data would break its charter. | Insert the row; the owning service reads it when it next resolves a schedule (GL's `findVerifiedScheduleFor` queries the table on each call; I saw no cache). No deploy. A reading service that keeps a copy gets the change when it refreshes. |
| **Drift risk** | Zero only while every pointer is current. Pointer bumps are deliberately per-repo, so two services can compute with different rates during a rollout. | Same. | None between services that only read through the API. Risk moves to one place: the owner's table, plus the repo docs/yaml copy (see section 7). |
| **Test impact** | A rate edit recompiles and retests every consumer. | Same, plus fixtures to regenerate. | Computation tests inject a schedule (as now) and stay independent of live rates. Add a seed-parse test and a doc/yaml-versus-seed check. A new read contract needs a fixture in `fish-contracts`. |
| **Tax extraction plan** | Removes the question of how Tax and GL share `Jurisdiction`, but ties Tax's release cadence to every other service, against the point of extraction. | Neutral. | Fits the extraction: the Tax service owns rate and rule tables; the jurisdiction code is a plain key with no foreign key (V30 already did this on purpose: "No FK to jurisdictions"), so the registry and the rules can sit in different services. |

Notes on the options:

- **`common` is also a public repository** (the repo table says so). Statutory rates are public facts, but unverified seed rows and the governance flags would sit in public view. Not a secret, but not what a public library is for.
- **`common`'s own charter** is generic value types (`Money`, `ValidationResult`, the Cognito token provider). The Tax extraction design (section 6) already asked "was it designed for domain-specific enums?" and left it open.
- **Types versus data.** What could legitimately be shared is a type, not a table: the six VAT category names (today copied in GL, SOP, POP and IM) or the two-letter code format. That is a different, smaller question, and the Platform Contract Policy treats a closed enum at a boundary as a breaking-change risk. Recommendation: leave it; fixtures in `fish-contracts` already catch drift in these.
- **Option B has one good use**, as the single authored source for the *seed* data (see section 7), not as the runtime source.

## 5. COMPUTATION

Stays with the owning service. Do not move it into `common`.

- VAT per line: GL, at posting, in the same call that writes the entry (atomicity, 2026-09-19). GL says the figure; IM only says the category.
- Corporation Tax per period: GL's Tax context today; the Tax service after extraction, reading net income from GL as an ordinary API client (Tax_Extraction_DDD_Design sections 2 to 3).
- Payroll statutory deductions: Payroll (the split service, approved 2026-10-15).

Reasons: Femi's rule of 2026-10-16 ("the onus on us is to ensure we calculate it as accurately as possible") argues for exactly one implementation per calculation, with golden tests, owned by one team and one service. Shared computation code in `common` multiplies the blast radius of a bug (every service rebuilds with it) and ties each calculation's release to everything else. The principle of 2026-10-18 (each service owns its details; no service reaches into another's data) points the same way.

## 6. The real decision hiding in this: VAT rates after the Tax extraction

The Tax extraction design (2026-09-19) was written before VAT existed in GL. VAT rates (`vat_rates`), the VAT return (`VatReturn`, `ComputeVatReturnUseCase`) and the categories route all landed in GL afterwards, and the design never said where they go. Two coherent answers:

1. **VAT stays with posting in GL**, permanently. Tax owns Corporation Tax and anything period-based. Simplest, keeps the atomic posting call local, but "all the tax rules in one place" is then not quite true.
2. **Tax owns the VAT rate table; GL keeps a local, refreshed copy for posting.** Effective dating makes this safe: a rate change is legislated and dated before it applies, so a copy a few minutes behind cannot misprice a transaction, and a lagging copy of a *verified* flip fails closed (409), not wrong. Costs: a refresh contract, a fixture, and a fail-closed rule when the copy is empty or stale.

Either way, GL should not call another service per posting line; that would reopen the staleness window that the atomicity decision closed. This is for CM and Femi to decide when the extraction is scheduled, not now.

## 7. Recommendation

1. **Do not build anything in `common`.**
2. **Jurisdiction registry** (code, name, enabled, currency): stays with Company (GL today), served at `GET /api/jurisdictions`. Every service reads the list there; none keeps its own. Confirm the route is registered as a platform contract in `fish-contracts` (I did not verify that it is).
3. **Statutory rates and rules:** database reference data, one owner per kind (GL now; Tax service for Corporation Tax and, per section 6, possibly VAT; Payroll for deductions when it has tables), keyed by jurisdiction code plus an `effective_from`, with the `verified` gate used for every kind, not just VAT.
4. **One authored copy.** Today the figures live in a markdown doc, a yaml file and a SQL seed, hand-synced. Pick one to author from (the yaml is the natural one) and add a check that fails when the seed and the yaml disagree. Small, and it removes the only drift risk the recommended option leaves.
5. **Amend `Tax_Extraction_DDD_Design.md`** (not done here, docs-only scope): section 6 (how to share `Jurisdiction`) and open question 2 are superseded by the registry; section 0's inventory still describes a closed enum and an unseeded `tax_rules` table; and VAT is unplaced (section 6 above).

What to expect it to cost later: a Tax service that other services read over HTTP is one more runtime dependency than `common`. That is the price of changing a rate without a deploy, and it is lower than six deploys per change.

## 8. Questions for Femi (rule content, in plain words)

1. **Rate changes ahead of time.** When a rate change is legislated in advance (Ireland, 1 July 2026), do you want it entered as soon as it is known, dated in the future, or only close to the date? Entered early means the table already knows the answer on the day.
2. **The `verified` flip.** The Sierra Leone VAT row waits for you ("not live until Femi confirms"). Should that be your act for every jurisdiction and every kind of rule (VAT, Corporation Tax, payroll), recorded with who and when?
3. **Corporation Tax by financial year.** In the UK the rate is set by the financial year, and a company's accounting period can straddle a year boundary. Today the rule table has no dates at all. Do we need straddle handling, and for which jurisdictions first?
4. **Corporation Tax gaps.** UK has no associated-companies divisor. NG, LR, GN and CI have no rule seeded; the seed note says each "needs a decision first" (not yet onboarded, or a threshold input to settle). Which of these do you want, and in what order?
5. **VAT and the Tax service.** Should VAT stay with posting in GL, or should the Tax service own the rate table with GL holding a refreshed copy (section 6)? It is partly architecture, but it follows from your "tax lives in one place" instinct against your own atomicity decision, so it is yours to weigh.
6. **Payroll tables.** Should PAYE bands, NI/PRSI/USC, NASSIT, CNSS and the rest follow the same shape (jurisdiction, tax year, effective date, verified)? Three known holes need your answer before any seeding: Sierra Leone PAYE thresholds (old Leone or new Leone), Liberia's NASSCORP conflict (two incompatible sources), and Ireland's employer PRSI bands (left blank, not guessed).
7. **Where each country's rules are authored.** You said on 2026-10-15 that rules "will be encoded for each country". Are you content that each country's rules are one reviewed file you can read and approve, from which the data is loaded?

## 9. Questions for CM

1. Is `GET /api/jurisdictions` a registered platform contract in `fish-contracts`, and does IM v5 (which needs the Company's jurisdiction code) read it or get the code from EA?
2. Which service owns the registry when Company eventually moves from GL, if it does? The registry currently follows Company.
3. Section 7 item 4: where should the yaml-versus-seed check run (GL's test suite, or the nightly contract drift job)?

## 10. What I did not verify

- Whether migrations V29 to V35 are applied in production, and which `vat_rates` and `tax_rules` rows exist there. I read GL `origin/master` source and migrations, not the live database.
- Whether EA, IM, POP or SOP have any jurisdiction handling beyond what a source search of `src/main` found (none in IM, POP, SOP; one comment in EA).
- The exact consumers of `common` today beyond what its README and the contracts SPUTO state.
- The statutory content of any rate or rule. That is Femi's, and nothing here changes it.

*Evidence read 2026-10-18: GL `origin/master` (`vat_rate_schedule.kt`, `jurisdiction.kt`, `jurisdiction_registry.kt`, `exposed_vat_rate_repository.kt`, `JurisdictionRoutes.kt`, migrations V29, V30, V31, V34), `docs/Tax_Extraction_DDD_Design.md`, `docs/Decisions_Log.md` (2026-10-11 to 2026-10-18 entries on VAT, tax rules, microservices principle, preparation versus audit), `docs/Cross_Service_Contract_Fixtures_SPUTO.md`, `docs/Platform_Contract_Generic_Services_And_Runtimes_SPUTO.md`, `docs/IM_Product_VAT_Category_v5_Extension_Note.md`, `common/README.md`, HR `payroll_tax_rule.kt`, the seven `docs/<CODE>/*_tax_and_currency_settings.yaml` headers.*
