# External Regulatory & Banking API Integrations — Requirements Specification

**Status**: requirements/design only, 2026-09-13. Nothing built. Grounded in real, dated research (see sourcing note below) rather than assumed API shapes — several jurisdictions genuinely have no API to integrate with yet, and this spec says so rather than picking a plausible-sounding one.

## 1. Purpose & Scope

FiSH wants to connect to three categories of external government/financial system, across five jurisdictions Purse and its sibling ventures already operate or plan to operate in:

- **Banking APIs** — account information and payment initiation for a Company's real bank accounts (feeds Bank Reconciliation, [project_bank_reconciliation_ifrs_grounding], and eventually automated cash-position visibility).
- **Tax Authority APIs** — filing, compliance-status, and TIN-verification, extending [project_compute_tax_use_case] and [project_tax_management_scope_gap] from "we compute the liability" to "we can also file it."
- **Company Registration & Returns APIs** — company lookup, annual-return filing, and officer/status changes with the national company registrar.

**Jurisdictions**: Sierra Leone (SL), United Kingdom (UK), Republic of Ireland (RoI), Liberia (LR), Nigeria (NG) — the same five already named across `docs/UK/`, `docs/IE/`, `docs/SL/`, `docs/LR/`, `docs/NG/`'s tax/currency settings docs and the Mano River business plan.

**Out of scope for this document**: how the resulting data flows into GL postings (that's a follow-on design, once a given integration is actually greenlit), and any integration this research found no live API for at all — those are recorded as parked, not designed around.

## 2. Sourcing note

Three research passes (2026-09-13) targeted each jurisdiction's *actual* regulator/registry/tax-authority sites and primary developer documentation, not secondary summaries. Every finding below is marked:

- **CONFIRMED** — a real, documented API exists, with a working link to its developer docs.
- **UNCONFIRMED / NO API** — no public API was found; what the country actually offers instead (a web portal, paper filing, a third-party reseller) is stated explicitly.

Where a finding conflicts across sources (Sierra Leone's company registrar, notably), that conflict is recorded as an open question, not silently resolved one way — per this project's established [feedback_park_dont_guess] convention. Nothing here should be treated as legal or compliance advice; before building against any API named CONFIRMED, re-verify current terms directly with the regulator, since fintech-adjacent APIs (especially Nigeria's Open Banking rollout) are moving targets.

## 3. Jurisdiction × Capability Matrix

| | Company Registration | Tax Filing/Status | Banking (AIS/PIS) |
|---|---|---|---|
| **UK** | ✅ Companies House REST API | ✅ HMRC MTD APIs | ✅ Open Banking Standard (mature) |
| **Republic of Ireland** | ✅ CRO Open Services API | ✅ Revenue web-service specs (cert-based) | ✅ PSD2 (bank-chosen standard, aggregator-mediated) |
| **Nigeria** | ❌ CAC — web portal only | ⚠️ FIRS e-invoicing API only (narrow); no TIN/filing API | ⚠️ CBN framework exists, national rollout incomplete |
| **Sierra Leone** | ❌ no API; registrar body itself unsettled across sources | ❌ NRA — web portal only | ❌ no framework; Orange Money API is the real channel |
| **Liberia** | ❌ LBR — web portal only | ❌ LRA — web portal only | ❌ no framework; MTN MoMo Open API is the real channel |

Reading this matrix: **UK and Ireland are the only two jurisdictions where all three categories have a genuine, documented integration path today.** Everywhere else, at least one (usually two) of the three categories is portal-only or mobile-money-only.

## 4. Company Registration & Returns

### 4.1 United Kingdom — Companies House — CONFIRMED

- **API**: Companies House REST API, `api.company-information.service.gov.uk`. Covers company search/lookup, filing-history retrieval, officer/PSC (persons with significant control) data. Full accounts/confirmation-statement *filing* is typically done through Companies House-approved software using the same API surface, not raw self-service.
- **Auth**: API key via HTTP Basic auth. **Sandbox**: yes, `api-sandbox.company-information.service.gov.uk`. **Cost**: free. Rate limit 600 requests/5 min (higher available on request).
- **Docs**: https://developer.company-information.service.gov.uk/
- **Third-party alternative**: DueDil, OpenCorporates, or a thin wrapper — not needed given the free direct API.

### 4.2 Republic of Ireland — Companies Registration Office (CRO) — CONFIRMED

- **API**: CRO "Open Services" REST API (`services.cro.ie`) plus a separate CRO Open Data Portal (`opendata.cro.ie`) for bulk company/financial-statement records. Covers company search and submission/filing-data lookup.
- **Auth**: API key + registered email in the Authorization header (obtained by agreeing to Open Services Ts&Cs). No dedicated sandbox found. **Cost**: basic company/submission data free; document retrieval is pay-per-call.
- **Docs**: https://services.cro.ie/ (help at `/cws/help`)
- **Third-party alternative**: Kyckr, Vision-net, CRIF Ireland.

### 4.3 Nigeria — Corporate Affairs Commission (CAC) — UNCONFIRMED / NO PUBLIC API

- CAC's own channels are a free public web search (`search.cac.gov.ng`) and the **iCRP** portal (`icrp.cac.gov.ng`) for registration, annual returns, and certificate management — both account-based web tools, no developer/API documentation found anywhere on CAC's own domains.
- **What exists instead**: manual filing via iCRP; public search page for lookups.
- **Third-party alternative**: Mono's CAC Lookup product, Prembly, Youverify — all wrap or scrape the public search rather than an official CAC API. Any integration here inherits that reseller's own reliability/ToS risk, not a government SLA.

### 4.4 Sierra Leone — registrar body unsettled — UNCONFIRMED / NO PUBLIC API

**Open question, not resolved here**: sources conflict on who is actually authoritative for company annual returns today —
- a "Corporate Affairs Commission Sierra Leone" (`cac.gov.sl`) appears to exist historically but was unreachable during research;
- the **National Investment Board (NIB)** reportedly took over limited-liability-company registration in a January 2023 transition;
- the **Office of the Administrator and Registrar General (OARG)**, `oarg.gov.sl`, still handles sole proprietorships/partnerships and was historically the registrar.

No API was found for any of the three. All three offer only web-based application forms/portals. **This ambiguity needs a direct confirmation from NRA/NIB/OARG (or a Sierra Leone-based advisor) before any integration design proceeds** — picking one silently risks building against the wrong authority.

### 4.5 Liberia — Liberia Business Registry (LBR) — UNCONFIRMED / NO PUBLIC API

- LBR (under the Ministry of Commerce & Industry, built with World Bank support as a one-stop online registry) supports online name search and registration submission as a web application (`lbr.gov.lr`), not a documented developer API. The portal has had past reliability issues (reported outages, 2018).
- **What exists instead**: web portal for name search/registration; presumed paper/in-person fallback.
- **Third-party alternative**: OpenCorporates lists Liberia as a covered register, but this is aggregated public data, not a live API to the registry itself.

## 5. Tax Authority Integration

### 5.1 United Kingdom — HMRC — CONFIRMED

- **API**: HMRC Developer Hub (`developer.service.hmrc.gov.uk`) publishes 140+ REST APIs under **Making Tax Digital (MTD)** — VAT (live since 2019) and Income Tax Self Assessment (phasing in). Covers return submission, obligations/filing-status lookups, tax-calculation triggers.
- **Auth**: OAuth 2.0, plus mandatory fraud-prevention headers (`Gov-Client-*`/`Gov-Vendor-*`) on every call. **Sandbox**: full sandbox at `test-api.service.hmrc.gov.uk` with a "Create Test User" API.
- **Adoption**: Xero, QuickBooks, Sage, FreeAgent are all HMRC-recognized MTD-compatible software (GOV.UK maintains an official list) — most UK digital returns already flow through commercial products this way.
- **Docs**: https://developer.service.hmrc.gov.uk/api-documentation/docs/api

### 5.2 Republic of Ireland — Revenue Commissioners — CONFIRMED

- **API**: Revenue publishes SOAP/REST web-service specs for software developers via **ROS (Revenue Online Service)** — a PAYE Modernisation REST API and a "Common web service specification" — distinct in shape from HMRC's OAuth model. A **PIT (Public Interface Test)** facility lets software vendors test file/return compatibility.
- **Auth**: **ROS digital certificate** issued to the filer/agent — not an OAuth/API-key model. No formally named public sandbox beyond PIT.
- **Adoption**: Revenue publishes a list of "ROS-compatible" third-party software (while explicitly not testing these itself) — Sage, Xero (via a Parolla plugin), QuickBooks, Surf Accounts, Big Red Cloud all file VAT3/payroll directly.
- **Docs**: https://www.revenue.ie/en/online-services/support/software-developers/index.aspx

### 5.3 Nigeria — FIRS (Federal Inland Revenue Service) — PARTIALLY CONFIRMED

- **E-invoicing — CONFIRMED**: the **FIRS Merchant Buyer Solution (FIRSMBS)** e-invoicing platform is real, UBL/XML- and Peppol-based, with documented mandatory rollout for large taxpayers (₦5bn+ turnover) from Aug 2025, enforced since Jul 2026. Accessed directly or via NITDA-accredited Access Point Providers. This is narrow in scope — invoicing, not general return filing.
- **TIN verification — UNCONFIRMED as public API**: JTB and FIRS offer only web-form lookup tools. Third-party vendors (Commenda, TaxDo, Metamap) claim API bulk-verification access, but no official FIRS/JTB API spec was found.
- **General return filing**: **TaxPro-Max** is FIRS's in-house filing/payment portal — web-based, no evidence of an open third-party filing API beyond the e-invoicing platform above.

### 5.4 Sierra Leone — National Revenue Authority (NRA) — UNCONFIRMED / NO PUBLIC API

- NRA runs internal digitalization (**ITAS**, Integrated Tax Administration System, built with Crown Agents; **ECR**, Electronic Cash Register), both reported "fully operationalized" in 2026, but described only as internal/taxpayer-facing systems, not developer APIs.
- **What exists instead**: taxpayers file/pay through NRA's ITAS web portal or in person; TIN verification is a web-form tool, not an API. No accounting-software vendor lists Sierra Leone support.

### 5.5 Liberia — Liberia Revenue Authority (LRA) — UNCONFIRMED / NO PUBLIC API

- LRA operates **LITAS** (Liberia Integrated Tax Administration System) and an Online Services/eFiling portal covering registration, filing, TIN issuance, tax-clearance certificates, and payments (bank transfer, POS, mobile money, Visa) — all web-portal based.
- **What exists instead**: self-service web portal plus in-person/paper for some processes. LRA has stated plans (partner-bank integration, e-invoicing, VAT-in-LITAS) as forthcoming, but nothing indicates a scheduled external developer API.

## 6. Banking / Open Banking Integration

### 6.1 United Kingdom — CONFIRMED, mature

- FCA-supervised under the Payment Services Regulations 2017 (PSD2 transposition), the CMA's 2017 Retail Banking Market Investigation Order, and Part 5 of the Financial Services (Banking Reform) Act 2013. The **UK Open Banking Standard** (read/write APIs) is mandatory for the "CMA9" largest banks and widely adopted beyond them.
- **Aggregators already operating**: TrueLayer, Yapily, Tink, Plaid.

### 6.2 Republic of Ireland — CONFIRMED, live, no single mandated standard

- Central Bank of Ireland regulates under PSD2 (transposed 13 Jan 2018), defining AISP/PISP categories but **not mandating a specific technical standard** — each bank picks its own PSD2-compliant API. In practice, several major Irish banks (Bank of Ireland, AIB) adopted the UK OBIE-derived standard rather than Berlin Group's NextGenPSD2.
- **Practical integration path**: an aggregator (TrueLayer, Yapily, Plaid, Tink all list Irish coverage under pan-EU PSD2 licenses) rather than a uniform national API.

### 6.3 Nigeria — CONFIRMED framework, rollout materially behind its own plan

**Re-checked 2026-09-13** (the original Feb 2026 finding below was deliberately re-verified rather than relied on as a stale snapshot, given how much time had passed against a "mid-2026" target):

- Central Bank of Nigeria's Regulatory Framework for Open Banking (Feb 2021) and binding Operational Guidelines (March 2023) define an "API Provider"/"API Consumer" model (not UK-style AISP/PISP), with a centralized Open Banking Registry run by NIBSS and BVN-anchored consent.
- **The "phased national go-live... through mid-2026" figure was softer than it first appeared.** CBN's own Fintech Policy Insight Report (dated 2026-02-02) actually lays out a 3-phase plan — Phase 1 (0–3 months): issue an implementation roadmap and begin industry sensitization; Phase 2 (3–9 months): pilot cohort/sandbox 2.0; Phase 3 (9–18 months): advisory council formalization — and as of that report, **CBN had not yet even issued the Phase 1 roadmap.** "Mid-2026" was secondary-source shorthand, not a date the report itself commits to.
- **No source dated later than June 2026 was found** confirming the registry is live, that any bank has formally onboarded as an "API Provider," or that any fintech aggregator (Mono, Okra, OnePipe, Stitch) has integrated with the *regulated* standard as opposed to their existing pre-regulation, direct-to-bank relationships.
- **Whether a foreign-incorporated company could register as an "API Consumer" once the system is live remains unconfirmed either way** — no source addresses residency/incorporation requirements for OBR registration. **This question is now moot for FiSH's own entry**, not because it's been answered, but because of a separate decision: per `docs/FiSH_Localization_Principle.md`, FiSH will establish a local Nigerian legal entity when it actually enters this market (the same pattern as the Irish subsidiary decision), sidestepping the foreign-registration question rather than waiting on an answer to it.
- **Providers already operating** (pre-regulation, adapting to the CBN standard): Mono, Okra, OnePipe, Stitch — genuinely the more realistic near-term path into this market, given the regulated system's own timeline is unconfirmed.

### 6.4 Sierra Leone — NO OPEN BANKING FRAMEWORK

- Bank of Sierra Leone regulates deposit-taking (Banking Act 2019) and payments (National Payment Systems Act 2022), but neither establishes an AIS/PIS regime. A National Payment Switch (live April 2023) provides bank/MMO/PSP settlement interoperability — infrastructure, not a third-party consent/data API.
- **What exists instead for a business**: manual statement/CSV export, or bilateral bank arrangement.
- **The real accessible channel**: **Orange Money's merchant/payment API** (developer.orange.com, OM Web Payment API) is public, documented, OTP/USSD-gated — mobile money genuinely leads banking here.

### 6.5 Liberia — NO OPEN BANKING FRAMEWORK

- Central Bank of Liberia regulates banks and is modernizing the National Payments System, but no AIS/PIS regime or bank-API mandate was found. CBL has driven mobile-money interoperability (Orange Money and Lonestar Cell MTN Mobile Money cross-network transfers, reported live Dec 2025) — not an equivalent for traditional bank accounts.
- **What exists instead for a business**: manual/statement-based bank access.
- **The real accessible channel**: **MTN Lonestar Cell's MoMo Open API** (momo.mtn.com, part of MTN's group-wide MoMo API platform, launched March 2022) is genuine, documented, and open to third-party developers. A comparably documented Orange Money Liberia API was not confirmed.

## 7. Use Cases

Written to reflect what's *actually* buildable per jurisdiction, not an aspirational uniform set — several use cases only apply where §3's matrix shows a real API.

- **UC-EXT01 — Look up a UK/RoI company by registration number.** Company Owner or platform operator queries Companies House or CRO directly for status, registered office, and filing history, surfaced against FiSH's own `Company` record. *Applies to: UK, RoI only.*
- **UC-EXT02 — Verify a Nigerian company via a reseller.** Same intent as UC-EXT01, but routed through a third-party reseller (Mono CAC Lookup or equivalent) since no official CAC API exists — result is explicitly flagged in the UI as "via third-party lookup, not CAC directly." *Applies to: Nigeria only, pending a reseller contract decision.*
- **UC-EXT03 — Record UK VAT return via MTD.** Compute the liability (existing `ComputeTaxUseCase`), then submit the return through HMRC's MTD API using the tenant's own OAuth-granted credentials.
- **UC-EXT04 — Record Irish VAT3 return via ROS.** Same intent, but authenticated with the tenant's ROS digital certificate rather than OAuth — a materially different credential-handling shape from UC-EXT03, not a copy of it.
- **UC-EXT05 — Submit a Nigerian e-invoice via FIRSMBS.** Scoped narrowly to invoicing (not general filing), for large taxpayers subject to the mandatory rollout.
- **UC-EXT06 — Ingest a bank statement (UK/RoI, via an aggregator).** Pull transaction data through TrueLayer/Yapily/Plaid/Tink into Bank Reconciliation's existing statement-line model, gated on the tenant completing that aggregator's own consent flow.
- **UC-EXT07 — Accept a mobile money payment/statement (Sierra Leone).** Integrate Orange Money's Web Payment API for a Company's collections and reconciliation — the actual accessible "banking" channel for this market.
- **UC-EXT08 — Accept a mobile money payment/statement (Liberia).** Same intent via MTN MoMo Open API.
- **Parked, not designed**: any use case requiring a Sierra Leone/Liberia government API for tax or company registration (§4.4, §4.5, §5.4, §5.5) — none exists to build against. A future "manual data-entry with an audit trail" workflow could approximate these, but that's a distinct, smaller piece of scope, not this integration.

## 8. Functional Requirements

- **FR-EXT01**: Each external integration must be scoped to a specific `Company` (via its jurisdiction), never assumed tenant-wide — a Purse Tenant with Companies in multiple jurisdictions ([project_tenancy_boundaries]) will have different integrations active per Company.
- **FR-EXT02**: Credential/consent state (OAuth tokens, ROS certificates, aggregator consent grants, API keys) must be stored per-Company, never hard-coded or shared across tenants — matches the existing service-account credential pattern already used for inter-service calls ([project_cognito_idp]).
- **FR-EXT03**: Every external call must be logged with enough detail to answer "what did we send, what did they return, when" for at least the retention period the relevant regulator requires — this is an audit trail, not just a debug log.
- **FR-EXT04**: A failed external call must never silently drop the underlying FiSH-side fact (a computed tax liability, a bank statement import) — matches the "accept eventual consistency, don't roll back" pattern already established for POP's IM/GL calls.
- **FR-EXT05**: Where no official API exists and a third-party reseller is used instead (Nigeria company lookup), the UI must disclose that provenance rather than presenting reseller data as if it came from the government body directly.

## 9. Non-Functional Requirements

- **NFR-EXT01 — Credential storage**: OAuth tokens, ROS certificates, and API keys are financial-system credentials and must go through the same Secrets Manager discipline already established for this platform ([feedback_secrets_manager_asm_exec_gap]), never plaintext config.
- **NFR-EXT02 — Consent lifecycle**: Banking aggregator consent (TrueLayer/Yapily/Plaid/Tink, or Orange Money/MTN MoMo's own authorization) is time-limited by the provider, not FiSH — the system must handle re-consent gracefully, not treat an expired grant as a bug.
- **NFR-EXT03 — Rate limits**: Companies House (600 req/5 min) and any other rate-limited API must be respected with backoff, not retried aggressively — a shared-tenant platform risks exhausting a rate limit across many Companies' calls if this isn't centrally throttled.
- **NFR-EXT04 — Jurisdiction drift**: given how fast Nigeria's Open Banking rollout and Nigeria's e-invoicing mandate are each moving (both changed materially within the last 12 months per this research), any Nigeria integration needs a documented re-verification step before go-live, not a "we checked once" assumption.

## 10. Architecture placement — open question

Given the precedent of extracting SOP/POP/IM/HR/EA into their own services rather than growing GL/Engine indefinitely ([project_ecosystem_extraction], [project_tenancy_administration_extraction]), an "External Integrations" bounded context is the more consistent shape than bolting OAuth flows and per-jurisdiction credential handling directly into GL. Not decided here — flagged for the same kind of deliberate scoping pass those extractions got, rather than defaulting to "just add it to GL."

## 11. Open questions / parked items

1. **Sierra Leone's true company-registry authority** (CAC-SL, NIB, or OARG) — needs direct confirmation, not a guess (§4.4).
2. **Nigeria Open Banking's actual current go-live status** — re-checked 2026-09-13 (§6.3): still not live, and materially further behind than the "mid-2026" shorthand suggested (CBN's own Feb 2026 report shows Phase 1 of 3 — issuing the roadmap — hadn't happened yet). No new deadline found. Re-check again before any build commitment; this is a moving target, not a settled fact. The separate question of whether a foreign entity could register is now sidestepped, not answered — see §6.3.
3. **Reseller vs. direct integration for Nigeria company lookup** — a commercial/legal decision (which reseller, what contract terms), not a technical one, before UC-EXT02 can proceed.
4. **Whether FiSH pursues Sierra Leone/Liberia tax or company-registry integration at all**, given neither has any API today — the realistic near-term scope for those two markets is the mobile-money use cases (UC-EXT07/08) only.
5. **Bounded-context placement** (§10) — undecided.

## 12. Suggested build sequencing (non-binding)

Ordered by what's actually accessible today, not by business priority (that's a separate call): (1) UK Companies House + HMRC MTD, since both are free, documented, sandboxed, and immediately buildable; (2) Ireland CRO + ROS, same shape, different credential model; (3) UK/Ireland banking via one aggregator (TrueLayer is the common thread across both markets); (4) Sierra Leone/Liberia mobile money (Orange Money, MTN MoMo) as the real "banking" answer for those markets; (5) Nigeria — re-verify Open Banking's live status and settle the CAC-lookup reseller question before committing engineering time.
