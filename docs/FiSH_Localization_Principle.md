# FiSH Localization Principle

**Status**: principle/design-only, 2026-09-13. Nothing built or restructured as a result of this document yet. Direct instruction: FiSH shall be made local to every jurisdiction it operates in, **as far as it is possible** — a best-effort, per-jurisdiction principle, not a blanket hard requirement applied uniformly everywhere regardless of actual need or feasibility.

## The principle, stated precisely

"Local to every jurisdiction" is a combined principle covering three genuinely different pillars, each triggered by what a given jurisdiction *actually* requires — not applied wholesale to every market on day one:

1. **Legal presence** — an incorporated local entity where operating there requires or benefits from one (licensing, tax registration, local banking relationships).
2. **Data residency** — data and compute kept within a jurisdiction's own borders (or region) where that jurisdiction's law requires it.
3. **Product/regulatory localization** — the software itself reflects that jurisdiction's currency, tax rules, chart of accounts, and compliance behavior correctly.

These pull on different levers (legal/corporate structuring, infrastructure architecture, and software design respectively) and are at very different levels of readiness today — treating them as one undifferentiated goal risks either under-scoping the infrastructure work or over-scoping the legal work relative to what's actually needed.

## Current state, checked directly — not assumed

**All six live services run from a single shared AWS region, `eu-west-2` (London, UK)** — confirmed directly against the running cluster (`fish-gl-engine-production`), not recalled from memory. Every tenant, regardless of jurisdiction, has its data and compute in the same place today. There is currently **zero data-residency segregation by jurisdiction** — a Sierra Leone tenant's data and a (future) Nigerian tenant's data would sit in exactly the same UK-hosted infrastructure as everyone else's.

This matters immediately, not just as a future concern:

- **Republic of Ireland is the active MVP jurisdiction**, and the infrastructure serving it is hosted in the UK (`eu-west-2`), not Ireland (`eu-west-1`) or the EU generally. Post-Brexit, the UK is a "third country" for GDPR purposes — data flows between the EU/Ireland and the UK currently rely on an adequacy decision, not in-region hosting. Whether that's sufficient for an Irish business's own compliance comfort (as distinct from bare legal minimum) is worth a real answer before RoI customers are onboarded, not an assumption.
- **Nigeria has a dated, confirmed data-localization deadline** — the fresh research pulled for the Nigeria banking-rollout question surfaced a 2027 CBN mandate forcing financial institutions toward in-country data. If FiSH ever serves a Nigerian financial-institution customer under that mandate's scope, in-region (or in-country) hosting isn't optional — it's a named legal deadline.

## Nigeria hosting — corrected same day: real options exist, this is a decision, not an unsolved problem

**AWS has no region inside Nigeria, Sierra Leone, or Liberia** — AWS's only African region is `af-south-1` (Cape Town, South Africa). This fact is accurate. What's not accurate — an overclaim made earlier the same day this was first written, corrected after direct research — is treating that as evidence that no compliant in-country hosting exists in Nigeria. It does:

- **Huawei Cloud operates a live, customer-provisionable hyperscaler region physically inside Nigeria** (launched December 2024), explicitly marketed for CBN/NDPC data-sovereignty compliance, with named commercial customers already using it.
- **Multiple Tier III-certified, carrier-neutral colocation facilities already operate in Lagos**, independent of any hyperscaler — Rack Centre, MDXi (MainOne/Equinix), and Africa Data Centres — already serving banks and fintechs.
- Azure, Google Cloud, and Oracle genuinely have no live Nigerian region either — so AWS isn't uniquely behind competitors on those clouds, but it is behind Huawei Cloud and behind any option built on local colocation.

For Sierra Leone and Liberia specifically, no equivalent check has been done yet — genuinely unresearched, not assumed either way.

**Revised framing**: for Nigeria, "as far as it is possible" isn't blocked on an infrastructure gap the market hasn't solved — it's an open *architecture decision* (which of several real providers to build on), and per `docs/Nigeria_Compliant_Hosting_Opportunity.md`, a genuine early-mover business opportunity given most competitors are almost certainly on clouds that don't solve this either — not just a compliance cost to absorb.

## The three pillars, honestly assessed

### 1. Legal presence — confirmed starting point: a single UK Limited company

Prodeo Group's current corporate structure is **one entity, a UK Limited company** — no local incorporation yet in any other jurisdiction, including Ireland. This is a real, concrete gap given RoI's active MVP status, not a hypothetical future question: **FiSH would be selling into and serving Irish customers from a UK-incorporated entity, with no Irish legal presence today.**

**Decided, 2026-09-13: an Irish subsidiary will be created specifically to serve Irish customers** (not a branch of the UK entity) — name still being chosen between two candidates, **"Prodeo Capital IE" or "Prodeo EIRE"**, not yet settled to one. This resolves the decision-to-have-presence and its legal form; the name is the one remaining open detail on this particular point. What's still open beyond naming: timing relative to onboarding the first paying Irish customer, and the operational mechanics (which entity holds the customer contract, how VAT filing on the customer's behalf is handled given the subsidiary is its own legal person distinct from the UK parent) — real Irish counsel input still needed for those, but the structural decision itself is made.

The same question repeats per jurisdiction as each is actually onboarded, and each jurisdiction's answer is its own, not inherited from Ireland's — **except that Nigeria has already had the same pattern applied**, decided the same day: **a local Nigerian entity will be institutionalised when FiSH actually enters that market**, regardless of the outcome. This wasn't researched into being unnecessary — it directly sidesteps a genuinely unresolved external question (whether a foreign-incorporated company could even register as an "API Consumer" under Nigeria's Open Banking framework once live; see `docs/External_Regulatory_And_Banking_API_Integrations_Requirements_Specification.md` §6.3) rather than waiting on an answer to it. Sierra Leone and Liberia haven't had this question raised yet at all — genuinely open, not decided by extension.

### 2. Data residency — real, checked, and unevenly urgent

Per the current-state findings above: this isn't ready anywhere today (single shared UK region for everyone), it's a **named, dated legal requirement in Nigeria** (2027), and it's **immediately worth a real answer for Ireland** given RoI's MVP status, even if the honest answer turns out to be "UK hosting is fine under the current adequacy decision, revisit if that changes."

**Sierra Leone and Liberia — checked directly, 2026-09-13, not left unresearched any longer:**

- **Sierra Leone has no data protection law in force at all** — a bill completed final national validation in November 2025, and Cabinet approved a national Data Protection Policy in April 2026 authorizing the Act's drafting, but Parliament has not yet enacted it. No general or Bank-of-Sierra-Leone-specific data-residency requirement exists today. One claimed "BSL directive requiring in-country hosting," found during this research, traced back to a vendor's own marketing copy rather than any real BSL source — flagged as likely not real, not repeated as fact.
- **Liberia's Data Protection Act was actually signed into law in June 2026** — genuinely in force, unlike Sierra Leone's. No general residency clause was confirmed in the Act itself (full text wasn't accessible). Separately, the Central Bank of Liberia's own E-Payment Services regulation (read directly, §9.0(c)) states hosting "should be" local but explicitly **permits offshore hosting if the CBL is guaranteed unfettered access to the system's reports** — a soft preference plus an access condition, not a hard mandate. A separate clause requires interoperable payment *routing* (not data storage) to stay within Liberia's own national payment switch.
- **Neither country has real hosting infrastructure maturity regardless of the legal answer**: no hyperscaler presence in either; Sierra Leone has at least one real colocation provider (Afcom, Freetown) with a second (Africell) under construction; Liberia's data-center market is genuinely sparse — a submarine-cable landing station exists, but no established commercial colocation provider was confirmed.

**Net effect**: neither country currently forces a strict in-country hosting answer the way Nigeria's 2027 mandate does. Worth continuing to track (Sierra Leone's bill could change this once enacted), but not a current build blocker for either market.

### 3. Product/regulatory localization — already the platform's actual strength

This is the pillar most already underway, and honestly the one this project has invested the most real work in: the UK/IE/NG/SL/LR/GN/CI tax-and-currency docs, `TaxRule`'s `RateStructure` shapes built specifically to represent each jurisdiction's real tax mechanics (not forced into one shape), and the VAT MVP design now in progress for Ireland specifically. This pillar doesn't need a new initiative — it needs to keep being the standard every future jurisdiction gets held to.

## Recommended application — sequenced, not simultaneous

Given the team-capacity reality already on record (solo-founder-built platform), applying all three pillars fully across every named jurisdiction at once isn't realistic and isn't what "as far as possible" asks for. Recommended reading: **each jurisdiction earns its localization work as it's actually onboarded**, in the same order already set for the rest of the platform (Ireland first, per the MVP sequencing) —

1. **Ireland (active now)**: two concrete, near-term items, not deferred, since this is the live MVP jurisdiction — the UK-vs-EU hosting question above (still open), *and* standing up the Irish subsidiary now decided on (structure settled, name still between "Prodeo Capital IE"/"Prodeo EIRE," timing/operational mechanics still need Irish counsel input). Both belong on the timeline before or alongside onboarding a first paying Irish customer.
2. **UK (next)**: already correctly hosted (UK infrastructure) *and* already the jurisdiction the existing entity is incorporated in — no legal-presence or data-residency gap here at all.
3. **Nigeria (a named future destination)**: legal presence is already decided in principle (a local entity, per above) even though timing isn't — data residency's 2027 deadline is real but not this year's problem, worth tracking rather than building against yet. Re-checked 2026-09-13: the country's own Open Banking rollout is materially further behind than earlier understood (CBN's own report shows it hadn't even issued its implementation roadmap yet), reinforcing that this stays a watch item, not a near-term build target — consistent with `docs/External_Regulatory_And_Banking_API_Integrations_Requirements_Specification.md`'s own Nigeria gating.
4. **Sierra Leone / Liberia**: checked 2026-09-13 — neither currently has a confirmed hard data-residency mandate (Sierra Leone has no data protection law in force yet at all; Liberia's own central-bank rule is a soft preference with an access-guarantee escape valve, not an absolute requirement). Not a current build blocker for either market; worth re-checking once Sierra Leone's pending Act is actually enacted.

## Relationship to other documents

This principle sits above and motivates several existing decisions rather than replacing them: `docs/IE/IE_MVP_Definition.md`'s RoI-first sequencing, `docs/External_Regulatory_And_Banking_API_Integrations_Requirements_Specification.md`'s per-jurisdiction gating, and the jurisdiction-specific tax/currency docs under `docs/UK/`, `docs/IE/`, `docs/NG/`, `docs/SL/`, `docs/LR/`, `docs/GN/`, `docs/CI/`. Nothing in those documents needs to change as a result of this one — this document names the principle they were already, informally, moving toward.
