# Generic core and runtimes: the synthesis (SPUTO)

**Status:** 2026-10-18, planning only. Nothing here is built. Written by CM from the seven part documents requested by Femi ("full SPUTO exercises on FiSH SOP-IM-POP and Runtime wrappers; today it is Education Runtime, tomorrow it can be Hospital Runtime, or AutoMechanic Runtime"). Baseline it builds on: `Platform_Contract_Generic_Services_And_Runtimes_SPUTO.md` (the contract layer, 2026-10-12).

| Part | Document | Author session |
|---|---|---|
| Runtime wrapper pattern | `Runtime_Wrapper_Pattern_SPUTO.md` | ER |
| Runtime registration and onboarding | `EA_Runtime_Registration_And_Onboarding_SPUTO.md` | EA |
| Receivables and income core | `SOP_Generic_Core_And_Runtimes_SPUTO.md` | SOP |
| Items and services core | `IM_Generic_Core_And_Runtimes_SPUTO.md` (IM repo) | IM |
| Payables and purchasing core | `POP_Generic_Core_And_Runtimes_SPUTO.md` | POP |
| Industry charts and posting | `GL_Industry_Charts_And_Posting_SPUTO.md` | GL |
| Vocabulary and navigation | `WEB_Runtime_Vocabulary_And_Navigation_SPUTO.md` (WEB repo) | WEB |

## 1. Scope (S)

The platform is a heartbeat of three generic services (SOP income, IM catalogue and stock, POP spend) over a ledger (GL), identity (EA), people (HR) and a front end (WEB). A **runtime** is an industry wrapper (Education today; Hospital and AutoMechanic are paper test cases) that owns its own domain, roles and vocabulary and **consumes** the generic services; it never duplicates them (a school raises its tuition invoice in SOP, sells Tuition as an IM service item, buys through POP). This document: what the seven parts agree on, where they conflict, the single order of work, and the decisions that gate it. Out: any build, any industry beyond the three, the contract layer already covered by the baseline.

## 2. What is true today (all seven parts agree)

1. **The generic cores are nearly Education-free in code.** SOP, IM, POP: no Education logic in the domain or application layers; the only mentions are EA's `schoolId` mirror field and SOP's Education-credential rule. GL has no industry on a Company and no industry posting logic.
2. **The Education coupling sits at the edges:** EA (a closed two-value `IndustryType`, the `EDUCATION_RUNTIME` literal in four rules, a hard-wired gateway, `schoolId` on `/me`), SOP (the ER credential and its services-only rule, an allow-list environment variable), WEB (a closed GENERIC or SCHOOL type inferred from grants, fifteen files, SOP hidden for a school) and the Education Runtime itself (the School noun, closed roles, `SCHOOLADMISSIONS_*` names, an NGN default).
3. **The core is untested by a second runtime.** Education makes one call to SOP and none to POP or IM's stock; Hospital and AutoMechanic content in every part is paper, assumed from general knowledge, and each part says so.
4. **The real non-neutral parts of the cores:** SOP: trade-finance ceremony in the ordinary sale path, goods-only returns and credit notes, one reference, one period, one customer and one revenue account per sale, a non-sequential `INV-xxxxxxxx` number, a fixed document title. IM: trade-finance names and a Cognito `StoreManager` group, no item code/edit/retire or categories yet. POP: whole-number quantities, mandatory delivery terms, no bill without an order, no runtime reference or dimension on a line, no key on order creation. GL: single-account posting contexts (being replaced by per-line accounts), chart chosen by legal form, not industry.

## 3. The common design (what the parts converge on)

- **A runtime is data plus a thin wrapper.** EA holds a **runtime manifest** (a reviewed file in `fish-contracts/runtimes/`): industry type, module id, role names mapped to the platform's view/enter/approve/administer capabilities, provisioning adapter, chart key, owner summary. Wire spellings stay (`SCHOOL`, `GENERIC`, `EDUCATION_RUNTIME`).
- **A runtime's permission at a generic service is data held by EA** (which routes, which Companies, which kinds of line it may sell), not code in SOP. This resolves the one visible conflict: SOP recommends a runtime credential may only sell IM service items (right for Education), while AutoMechanic and a hospital pharmacy must sell stock; the allowed line kinds are the runtime's permission, and every line still names an IM item.
- **A runtime kit boundary inside the Education code** (about 1.5 days, no behaviour change, an architecture test); a separate repository only when a second runtime is approved.
- **Chart packs are owned by GL** (versioned, applied by id, idempotent like today's standard accounts); EA only names the pack; GL records packs applied, not an industry.
- **Vocabulary packs and navigation manifests are owned by WEB** (typed, fall back to the generic word, one design system for every runtime; a runtime may change words, area names and added screens, never colours, nav depth, or hide money screens).
- **One mechanism for line-level business references.** Four parts independently asked for the same thing under different names: SOP's beneficiary reference per line (D1), POP's departments, cost centres and projects kept as a list by the owner (D3), GL's optional opaque dimensions on the thin interfaces (D4), and IM's categories. The synthesis: one optional, opaque, runtime-defined reference or dimension on every line in SOP and POP, carried to GL as a dimension, with the list kept in one place; no service interprets it.
- **Work the live Education Runtime needs first, not only a second runtime:** decimal quantities and hourly services (POP, SOP), bill without an order (POP), receipts and adjustments (SOP), item identity and categories (IM), per-line accounts (GL), school-term revenue recognition (GL).

## 4. Where the parts need each other (cross-checks)

- ER's permission-as-data needs EA's manifest; EA's `runtimeLinks` on `/me` is lockstep across five strict mirrors and WEB; GL must take a chart key at Company creation (EA asked; GL's part is the authority); SOP's allowed-route check must read EA, not an environment variable.
- Health data (Hospital) changes the kit's identity and logging (ER), and EA must never hold it; a separate security review precedes any Hospital design.
- ER did not cross-check the other parts; this section is the first cross-check.
- Unverified in every part: Hospital and AutoMechanic needs (paper); per-country sequential-invoice rules; the tax treatment of medical services; production `schoolId` data.

## 5. Tasks and order (O)

**Wave 0, behaviour-preserving, useful to Education today, no second runtime needed:** ER kit boundary (1.5 d); EA Wave 1 removing the Education literals (about 5.5 d); WEB vocabulary refactor (about 2.75 d, 1.25 d riding the label work already queued); IM item identity, paging, categories, starter catalogue and owner summaries (about 7.5 d); POP decimals, bill without an order, line reference (about 10.5 new days, most useful to Education); SOP receipts, adjustment kinds, sequential numbering and document words (its N1 to N11); GL per-line accounts (in progress) and the industry pack mechanism.

**Wave 1, lockstep once, before a second runtime:** EA `runtimeLinks` and manifest consumption across SOP, GL and WEB; runtime permission as EA data; chart key at Company creation; the shared reference and dimension mechanism.

**Wave 2, only when a second runtime is decided:** a separate runtime-kit repository; expiry, packs, serials, reservation and price lists in IM (named-customer trigger); supplier licence enforcement; quotes; payer-split option (b); the first Hospital or AutoMechanic wrapper, after one clinician and one mechanic have read the paper sections.

## 6. Decisions for Femi

The part documents hold about forty. These nine gate the order; the rest take each author's recommendation unless Femi objects.

1. Draw the runtime-kit boundary inside the Education code now (1.5 d), a separate repository only when a second runtime is approved? (ER D1; recommend yes)
2. A runtime's permission at a generic service is data held by EA, including which kinds of line it may sell? (ER D2; recommend yes)
3. One optional reference or dimension per line, one list kept in one place, opaque to the services? (SOP D1, POP D3, GL D4; recommend yes)
4. Billing a visit to two payers (patient and insurer): two invoices created together by the runtime for the first release, one sale with shares later? (SOP D2; recommend two invoices first)
5. A gapless per-Company invoice number series like the receipts, with visible VOID? (SOP D3; recommend yes; needs a per-country check)
6. Chart packs owned by GL, EA names the pack, no industry stored on the Company? (GL D1 and D2, EA O2; recommend yes)
7. Health data: its own boundary and a separate security review (consent, read logging, residency) before any Hospital design? (EA O4, ER D6; recommend yes)
8. One conversation with a clinician and one with a mechanic before anyone relies on the paper sections? (ER D4; recommend yes)
9. Build EA Wave 1 now, ahead of a second runtime? (EA O5; recommend yes, it removes literals and changes no behaviour)

**Taken as recommended unless Femi objects:** one industry per Company (EA O1); the manifest as a reviewed file (EA O3); module id spelling (EA O6); document words as data (SOP D4); quotes only when a runtime needs them (SOP D5); one adjustment mechanism with kinds (SOP D6); a runtime credential's lines always name an IM item (SOP D7); decimal quantities (POP D1); a runtime may raise orders and bills in POP through its public API (POP D2); a purchase for a customer's job carries only a reference (POP D4); supplier licence shown now, enforced later (POP D5); one kit owner (ER D3); naming (ER D5); account ranges, optional opaque dimensions and one receivables control account with the payer as a customer (GL D3 to D5); accounting policies and tax lists are Femi's and nobody drafts them as settled (GL D6 and D7); IM's seven (price lists only when the first Company needs a second price, and the rest per its document); WEB's six (same look for every runtime; a school's money screens through the generic Sales screens in school words; the runtime owner writes its own words; packs in WEB's code first, a registry later; accountants' words constant; translation planned, not built).

## 7. What this synthesis did not verify

Every code claim is the author session's, cited by file in its own document. CM read the decisions and order sections of the EA, SOP, POP, ER and GL parts and the IM and WEB summaries, not all code evidence. The IM and WEB documents sit in their own repositories and were read from their branches. No effort figure is more than an estimate.
