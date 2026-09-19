# Republic of Ireland MVP — Platform × External Integrations

**Status**: definition only, 2026-09-13. Nothing built as a result of this document. Two-dimensional by design (per direct instruction): Dimension 1 is what "go-live ready" means for the FiSH platform itself, scoped to a Republic of Ireland Company; Dimension 2 is the minimum viable slice of `docs/External_Regulatory_And_Banking_API_Integrations_Requirements_Specification.md`, scoped the same way. RoI is the anchor jurisdiction, not the only target — the strategic bet is that solving both dimensions for RoI produces a platform *and* an integration pattern that UK, Nigeria, and Sierra Leone can then extend rather than re-derive.

## Why RoI first

RoI is one of only two jurisdictions (with the UK) where all three external API categories are real and documented today (§3 of the integrations spec). But RoI is arguably the **harder** of the two to build against, not the easier:

- CRO's Open Services API has no sandbox and pay-per-call document retrieval — Companies House has both, free.
- Revenue's ROS uses a **certificate-based** credential model — structurally different from HMRC's OAuth, and the less common pattern for this team to build first.
- Ireland's PSD2 banking has **no single mandated technical standard** — each bank picked its own, so integration is realistically aggregator-mediated (TrueLayer/Yapily/Plaid/Tink) rather than one national API, unlike the UK's single mandatory Open Banking Standard.

Solving the harder credential/integration shapes first (certificate auth, no-standard banking) means the UK follow-on is comparatively easy — OAuth is simpler than a ROS certificate, and the UK's single Open Banking Standard is simpler than aggregating across bank-chosen PSD2 implementations. Nigeria and Sierra Leone are excluded from this MVP entirely: Nigeria's Open Banking rollout is confirmed still incomplete by its own regulator's timeline, and Sierra Leone has no government API in any category — building against either now would be building against a moving target or nothing at all.

## Dimension 1 — FiSH Platform MVP, scoped to a Republic of Ireland Company

### Already load-bearing, confirmed technically ready for RoI

- **Core Ledger** (Money, Account, Period, JournalEntry) — currency-agnostic by construction (`Money.currency: java.util.Currency`), so EUR is not a gap, it's just an ISO code the platform already accepts.
- **`Company.baseCurrency`/`Company.jurisdiction`** — both already real fields on the aggregate; an RoI Company is not a new shape, just a new value.
- **Corporate Income Tax computation** — `TaxRule.rateStructure: RateStructure.CategorySplit` already exists and is explicitly documented (its own KDoc) as the shape for "Ireland's trading/passive split." The domain capability to compute IE's 12.5%/25% split correctly is built, not a gap.
- **GL reporting** (P&L, Balance Sheet, Working Capital, Bank Reconciliation) — jurisdiction-agnostic, works for any Company regardless of country.
- **Tenancy/onboarding** (Tenant → Company, User/Membership, Chart of Accounts seeding) — generic across jurisdictions today.

### Confirmed gaps — real, not guessed

- **No IE `TaxRule` reference-data row confirmed seeded.** The `CategorySplit` shape exists; whether an actual jurisdiction=`IE` row with the real 12.5%/25% rates has been created via migration/seed is unconfirmed — this is a concrete, small build item, not a design question.
- **VAT is out of scope platform-wide**, not an RoI-specific gap: `RateStructure`'s own KDoc states VAT/GST/TVA have no `TaxType` member yet anywhere in the codebase. `docs/IE/IE_Tax_And_Currency_Settings.md` records VAT figures as reference data only. If VAT computation/filing is part of this MVP's real definition of "done," that's new platform scope, not an integration-layer concern.
- **Employer-side PRSI was left blank on purpose** in the IE tax doc — not sourced with confidence at the time. Needs a follow-up lookup before any IE payroll computation can be called accurate.
- **Chart of Accounts template content for IE is unconfirmed** — whether the existing template is generic-enough-to-work or needs IE-specific line items (e.g., VAT control accounts once VAT exists) hasn't been checked in this pass.
- **HR/Payroll's `PayrollTaxRule` population for Ireland is unconfirmed** — the IE tax doc records PAYE/PRSI figures as reference data; whether `PayrollTaxRule` itself has been seeded with them is a separate question from whether the numbers are documented.

### Legal & infrastructure readiness — new since `docs/FiSH_Localization_Principle.md` (2026-09-13)

Two real go-live gates for RoI surfaced by the localization principle adopted this week, neither of which is a code gap:

- **Legal presence — decided, not yet formed.** Prodeo Group's current structure is a single UK Limited company, with no Irish entity. **Decided: an Irish subsidiary will be created specifically to serve Irish customers** (not a branch of the UK entity) — name still open between "Prodeo Capital IE" and "Prodeo EIRE." Timing relative to the first paying Irish customer, and operational mechanics (which entity holds the customer contract, how VAT filing on the customer's behalf works given the subsidiary is its own legal person), still need real Irish counsel input. This is a genuine go-live gate for RoI, not a nice-to-have — track it alongside the engineering work below, not after it.
- **Data residency — open, and more urgent than it first appears.** All six live services run from a single shared AWS region, `eu-west-2` (**London, UK**) — confirmed directly, not assumed. Post-Brexit, the UK is a GDPR "third country" relative to Ireland/the EU; data flows currently rely on an adequacy decision, not in-region hosting. Whether that's sufficient for RoI customers, or whether infrastructure should move to `eu-west-1` (Ireland) or elsewhere in the EU, is a real, near-term decision — not deferred, since RoI is the active MVP jurisdiction right now, not a future market.

### What's genuinely NOT required for this MVP

SOP, POP, IM, HR, and EA's wider ERP charter are all real, deployed, working software — but none of them are load-bearing for "can an RoI Company use FiSH as a ledger." The platform's core value (ledger + reporting + Corporate Income Tax) stands alone. Treat those five as **available extensions a Company can adopt**, not MVP gates — consistent with this project's own established minimal-builds discipline.

## Dimension 2 — External Integrations MVP, scoped to RoI

From the integrations spec's own UC list, the RoI-relevant subset, ordered by what's actually lowest-risk to build first:

1. **UC-EXT01 (Company lookup via CRO)** — read-only, free-tier company search/status lookup against `services.cro.ie`. No filing, no write access. This is the lowest-risk possible integration: no sandbox needed because there's nothing to break, and it proves the "External Integrations" architectural shape (credential storage, per-Company scoping, audit logging per FR-EXT01–03) end to end before touching a harder credential model.
2. **UC-EXT04 (Revenue VAT3 filing via ROS)** — the actual hard case this MVP exists to prove: ROS's certificate-based auth is a materially different credential shape from OAuth (NFR-EXT01's Secrets Manager discipline needs to handle a certificate, not just a token). Blocked on Dimension 1's VAT `TaxType` gap being closed first — there's no VAT liability to file until the platform can compute one.
3. **UC-EXT06 (Bank statement ingestion via an aggregator)** — pick **one** aggregator, not evaluate all four. TrueLayer is the natural choice specifically because it already covers both Ireland and the UK under one PSD2 license (per the integrations spec's own findings) — building against it for RoI sets up the UK follow-on to reuse the same integration code, not rebuild it.

### Explicitly deprioritized for this MVP

- CRO **filing** (annual returns, officer changes) — start read-only; write access is materially more scope (consent, error handling for rejected filings) than this MVP needs to prove the pattern.
- Any second banking aggregator — one is enough to prove the shape; evaluating Yapily/Plaid/Tink against TrueLayer is a later commercial decision, not an MVP blocker.
- Payment *initiation* (PIS) — account information (AIS) only for this MVP; initiating a payment carries materially higher regulatory/liability weight than reading a statement.

## Architecture placement — recommendation for MVP speed

The integrations spec (§10) left this open. For MVP purposes specifically: build the External Integrations capability **inside GL** initially, scoped per-Company, rather than standing up a seventh service before there's evidence of the load/complexity that justified extracting SOP/POP/IM/HR/EA. `Company` already lives in GL, and CRO lookup + ROS filing + one bank feed is a small enough surface that a new service would be premature — consistent with "even confirmed features stay deferred if not load-bearing now." Revisit extraction if/when this integration surface grows the way SOP/POP/IM did.

## What needs confirming before this is locked (open items)

1. Is there an IE `TaxRule` row actually seeded, or does one need creating?
2. Is IE's Chart of Accounts template sufficient as-is, or does it need real IE-specific content?
3. Employer PRSI banding — needs the follow-up lookup the IE tax doc already flagged.
4. Does "MVP" here include VAT computation, or is VAT explicitly out of scope for this pass (recommended: out of scope — it's a new `TaxType`, not a small addition)?
5. Commercial terms for TrueLayer (or whichever aggregator) and CRO's paid document-retrieval tier — a procurement question, not a technical one.
6. Final name for the Irish subsidiary — "Prodeo Capital IE" or "Prodeo EIRE" — and its formation timing relative to the first paying Irish customer.
7. Whether production infrastructure needs to move from `eu-west-2` (London) to `eu-west-1` (Ireland) or elsewhere in the EU for RoI data residency — see `docs/FiSH_Localization_Principle.md`.

## Recommended build order (superseded by direct instruction, 2026-09-13)

**VAT is now the MVP threshold, not a deferred item** — see `docs/IE/IE_VAT_MVP_Design.md` for the full design and its own open questions (VAT category placement, single-vs-split control account, filing cadence). Updated order:

1. Build VAT computation (domain modeling, SOP/POP line-level VAT, Chart of Accounts control account(s), the return-computation use case) — per `IE_VAT_MVP_Design.md`. This is now the headline deliverable, ahead of everything below.
2. Seed the real IE `TaxRule` (`CategorySplit`, 12.5%/25%) — smallest possible item, unblocks accurate Corporate Income Tax computation for a real RoI Company today.
3. Build CRO company lookup (UC-EXT01) — proves the External Integrations shape with the lowest possible risk (read-only, free, no sandbox needed because there's nothing to break).
4. Build the TrueLayer bank-feed integration (UC-EXT06) for RoI — proves AIS end-to-end and sets up the UK reuse.
5. ROS VAT3 filing (UC-EXT04) — now directly motivated by step 1 landing a real, correct VAT liability to actually file.

Once this sequence is proven for RoI, the UK follow-on should be materially faster: same aggregator, an easier (OAuth) tax-authority credential model, a free/sandboxed company registry, and a VAT computation shape that's already built and only needs UK's three-band rates substituted in — the harder problems (Ireland's five bands, ROS's certificate auth, no single Irish banking standard) were solved here first.

**Runs in parallel, not gating the engineering sequence above**: the Irish subsidiary formation and the `eu-west-2`-vs-`eu-west-1` hosting decision (see Legal & infrastructure readiness, above) are on a business/legal and infrastructure track respectively, not the engineering critical path — but both need to land before (or alongside) the first real paying Irish customer, not after.
