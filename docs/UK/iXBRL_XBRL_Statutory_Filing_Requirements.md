# iXBRL / XBRL Statutory Filing — Requirements & Use Cases

**Context:** This defines the requirements for producing iXBRL/XBRL-tagged statutory financial filings directly from FiSH, rather than relying on a third-party accounting package to re-key FiSH's ledger data. As previously noted (see prior discussion of XBRL), the near-term reality is that most entities use their accountant's/auditor's filing software for this; this document treats *native FiSH iXBRL generation* as a deliberate build option to evaluate, not an assumption that it must be built in-house. It is scoped across the Group's dual-jurisdiction structure — UK entities filing with HMRC (Corporation Tax, iXBRL-tagged CT600 return) and Companies House (statutory accounts), and Prodeo Capital Ltd filing with Ireland's Revenue Commissioners and the CRO.

**Relationship to other modules:** This sits downstream of Core Banking, Osusu, Payroll, and the future Risk Management module — it consumes FiSH's posted, immutable ledger data as input and produces a regulator-facing artefact as output. It does not itself post any journal entries to FiSH (filing is a reporting event, not a transaction).

---

## Actors

| Actor | Definition |
|---|---|
| **FiSH** | GL of record; source of all trial balance and ledger data used for filing |
| **Finance/Purse Ops** | Prepares, reviews, and approves statutory filings before submission |
| **External Auditor** | Reviews/signs off statutory accounts where required (audit or independent examination) |
| **Taxonomy Mapping Engine** | Maps FiSH's chart-of-accounts concepts to the correct XBRL taxonomy elements per jurisdiction |
| **Tax Authority** | HMRC (UK) or Revenue Commissioners (Ireland) — receiving body for tax-related iXBRL filings |
| **Companies Registrar** | Companies House (UK) or CRO (Ireland) — receiving body for statutory accounts filings |

---

## UC-X1: Chart of Accounts to Taxonomy Mapping

**Actor:** Finance/Purse Ops, Taxonomy Mapping Engine
**Trigger:** New FiSH account/entity onboarded, or annual taxonomy version update issued by a regulator.

**Flow:**
1. Finance/Purse Ops maps each relevant FiSH GL account/concept to the correct taxonomy element in the applicable taxonomy — UK GAAP (FRS 101/102) taxonomy for HMRC/Companies House, or the equivalent Irish taxonomy for Revenue/CRO filings, depending on entity jurisdiction.
2. Mapping is versioned — when a regulator issues an updated taxonomy (these change periodically), the mapping must be re-validated against the new version before it's used for any filing under that version.
3. Unmapped FiSH accounts are flagged as exceptions requiring resolution before any filing can be generated.

**Postconditions:** A validated, versioned mapping exists per entity per taxonomy version, ready to drive filing generation.

**Open decision:** Is mapping maintained manually by Finance/Purse Ops, or does the Taxonomy Mapping Engine suggest/automate mapping based on account naming conventions, with human sign-off required regardless?

---

## UC-X2: Trial Balance Extraction from FiSH

**Actor:** Finance/Purse Ops, FiSH
**Trigger:** Filing period end (e.g., financial year end) reached, or ad hoc extract requested for filing preparation.

**Flow:**
1. System extracts a trial balance from FiSH for the relevant entity and period, using only posted, immutable journal entries as of the extraction point.
2. Extraction is entity-scoped — never a cross-entity blend, consistent with FiSH's segregated multi-entity design already established for Payroll and Banking.
3. Extract is timestamped and retained as the exact snapshot the filing was generated from, so a later query of "what did the filing reflect" doesn't depend on re-querying a ledger that has since had further entries posted.

**Note:** Because FiSH is reversal-only and immutable, this extraction is inherently reproducible and auditable — a key advantage over ledgers that permit direct edits, where a historical trial balance could otherwise be ambiguous.

---

## UC-X3: iXBRL Document Generation

**Actor:** Finance/Purse Ops, Taxonomy Mapping Engine
**Trigger:** Trial balance extracted (UC-X2) and mapping validated (UC-X1).

**Flow:**
1. System applies the validated mapping to the trial balance, tagging each relevant figure with its taxonomy element.
2. System generates the iXBRL document — human-readable HTML with embedded XBRL tags — combining the statutory account/return narrative (directors' report, notes, etc., where applicable) with the tagged financial figures.
3. Draft is presented to Finance/Purse Ops (and External Auditor, where sign-off is required) for review before it's treated as final.

**Open decision:** Does FiSH/the filing module generate the full statutory account narrative (notes, directors' report) natively, or does it generate only the tagged financial statement figures for insertion into a separately authored narrative document? The latter is a smaller, more achievable build scope.

---

## UC-X4: Validation Against Taxonomy & Business Rules

**Actor:** Taxonomy Mapping Engine
**Trigger:** iXBRL document generated (UC-X3).

**Flow:**
1. System validates the generated document against the taxonomy's XML schema (structural validity) and any published validation/business rules (e.g., HMRC's and Companies House's respective validation rule sets — cross-checks like balance sheet totals agreeing, mandatory tags present).
2. Validation failures are surfaced with specific, actionable detail (which tag, which rule, why it failed) — not a generic rejection.
3. Document does not proceed to submission (UC-X5) until validation passes cleanly.

**Note:** This is the step most likely to justify third-party tooling/library integration rather than in-house build, since taxonomy validation rule sets are complex, regulator-maintained, and change periodically — a build-vs-buy decision much like the payroll tax calculation engine discussed for HR Payroll.

---

## UC-X5: Submission to Tax Authority / Companies Registrar

**Actor:** Finance/Purse Ops, Tax Authority, Companies Registrar
**Trigger:** Validated iXBRL document (UC-X4 passed) and internal approval obtained.

**Flow:**
1. Finance/Purse Ops gives final approval (segregation of duties: the preparer should not be the sole approver).
2. Document is submitted via the relevant regulator's electronic filing channel — HMRC's Corporation Tax online service, Companies House's filing API/service, Ireland's ROS, or CRO's filing system, per entity jurisdiction.
3. Submission confirmation/reference number is captured and stored.
4. Any rejection at the regulator's end (post-submission validation failure) routes back to Finance/Purse Ops for correction and resubmission.

---

## UC-X6: Amendment / Resubmission

**Actor:** Finance/Purse Ops
**Trigger:** Error discovered in a previously submitted filing, or regulator requests amendment.

**Flow:**
1. Per FiSH's reversal-only principle, if the error originates in underlying ledger data, the correction follows the standard FiSH reversal process (as already defined for Payroll corrections) — the original journal entries are never edited directly.
2. A new trial balance extraction (UC-X2) reflecting the correction is taken, and a new iXBRL document is generated, validated, and submitted as an amendment per the regulator's amendment process (which differs from an original filing — often a distinct submission type, not a simple resend).
3. Both the original and amended filings are retained permanently, with the amendment clearly linked to the filing it corrects.

---

## UC-X7: Multi-Entity, Multi-Jurisdiction Filing Coordination

**Actor:** Finance/Purse Ops
**Trigger:** Group-wide filing cycle where multiple entities (Scrip, Purse, Prodeo Capital, Property SPV) have filings due, potentially on different jurisdiction-specific deadlines.

**Flow:**
1. System maintains a filing calendar per entity per jurisdiction, since UK and Irish deadlines and requirements differ (and Companies House/CRO deadlines differ from HMRC/Revenue deadlines even within the same entity).
2. Each entity's filing is generated and submitted independently (per UC-X1–X5), using that entity's specific taxonomy and mapping — no shared or blended filing across entities.
3. Finance/Purse Ops has a consolidated dashboard view of filing status across the Group, without any filing itself being cross-entity.

---

## UC-X8: Filed Document Audit Trail & Retention

**Actor:** Finance/Purse Ops, External Auditor
**Trigger:** Ongoing — every completed filing.

**Flow:**
1. Every submitted iXBRL document, its source trial balance extract, mapping version used, validation results, and submission confirmation are retained together as a single auditable package.
2. Retention period meets the longer of UK and Irish statutory record-keeping requirements for corporate filings.
3. External Auditor or regulator can, on request, be shown the exact chain from FiSH's posted ledger entries through to the final filed document.

---

## Functional Requirements

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-X01 | System shall maintain a versioned mapping from FiSH chart-of-accounts concepts to taxonomy elements, per entity and per applicable jurisdiction taxonomy. | UC-X1 |
| FR-X02 | System shall flag any FiSH account lacking a valid taxonomy mapping before filing generation proceeds. | UC-X1 |
| FR-X03 | System shall extract a trial balance from FiSH scoped to a single legal entity and a defined period, using only posted (immutable) entries. | UC-X2 |
| FR-X04 | System shall retain the exact trial balance snapshot used for each filing, independent of any later ledger activity. | UC-X2 |
| FR-X05 | System shall generate an iXBRL document combining tagged financial figures with required statutory narrative content, per jurisdiction requirements. | UC-X3 |
| FR-X06 | System shall route every generated filing through a review step before it is treated as final, including External Auditor sign-off where statutorily required. | UC-X3 |
| FR-X07 | System shall validate every generated filing against the applicable taxonomy schema and published business/validation rules before submission is permitted. | UC-X4 |
| FR-X08 | System shall present validation failures with tag-level and rule-level detail sufficient for correction without manual regulator-documentation lookup. | UC-X4 |
| FR-X09 | System shall require a distinct approver from the preparer before submission (segregation of duties). | UC-X5 |
| FR-X10 | System shall submit filings via the correct regulator-specific electronic channel per entity and filing type. | UC-X5 |
| FR-X11 | System shall capture and retain the regulator's submission confirmation/reference for every filing. | UC-X5 |
| FR-X12 | System shall support amendment filings that correct a prior submission without altering the original FiSH ledger entries directly — via reversal only. | UC-X6 |
| FR-X13 | System shall link every amendment filing explicitly to the original filing it corrects, in a way visible on audit. | UC-X6 |
| FR-X14 | System shall maintain a Group-wide filing calendar covering every entity's jurisdiction-specific deadlines (Tax Authority and Companies Registrar separately). | UC-X7 |
| FR-X15 | System shall generate and submit each entity's filing independently — no blended or consolidated cross-entity filing shall be produced as a single document. | UC-X7 |
| FR-X16 | System shall retain, as a single linked package, every filing's source extract, mapping version, validation results, and submission confirmation. | UC-X8 |
| FR-X17 | Retention period shall meet or exceed the longer of applicable UK and Irish statutory retention requirements. | UC-X8 |

---

## Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-X01 | Accuracy | Every tagged figure in a generated filing shall reconcile exactly to the corresponding FiSH trial balance extract — no manual override that diverges from the ledger without an explicit, logged reason. |
| NFR-X02 | Currency of taxonomy | System shall detect when a regulator publishes a new taxonomy version and prevent filings under an expired version once a grace period (per regulator rules) has passed. |
| NFR-X03 | Timeliness | System shall surface upcoming filing deadlines with enough lead time (configurable, e.g., 60/30/7 days) for review and correction cycles, given HMRC's RTI-adjacent strict timing culture versus generally longer Irish filing windows. |
| NFR-X04 | Security | Draft and filed statutory documents shall be access-controlled to Finance/Purse Ops and External Auditor roles only, given the commercially and legally sensitive nature of statutory accounts pre-filing. |
| NFR-X05 | Auditability | The full chain from FiSH posting to filed document shall be reconstructable without relying on any system outside FiSH and the filing module itself. |
| NFR-X06 | Build-vs-buy readiness | Architecture shall not preclude replacing the in-house Taxonomy Mapping Engine and/or Validation component with a licensed third-party XBRL toolkit, given the complexity and regulator-maintained nature of taxonomies (see UC-X4 note). |

---

## Traceability Summary

- UC-X1 Chart of Accounts to Taxonomy Mapping
- UC-X2 Trial Balance Extraction from FiSH
- UC-X3 iXBRL Document Generation
- UC-X4 Validation Against Taxonomy & Business Rules
- UC-X5 Submission to Tax Authority / Companies Registrar
- UC-X6 Amendment / Resubmission
- UC-X7 Multi-Entity, Multi-Jurisdiction Filing Coordination
- UC-X8 Filed Document Audit Trail & Retention

---

## Open decisions carried forward (unresolved, high-priority)

1. **Build vs buy (UC-X3, UC-X4, NFR-X06)** — native iXBRL generation and taxonomy validation is a substantial, regulator-dependent build. Given FiSH's priority is core ledger integrity, the pragmatic near-term path may be exporting a clean, mapped trial balance from FiSH (UC-X1–X2) and letting the accountant's/auditor's existing filing software (or a licensed XBRL toolkit) handle UC-X3–X5, revisiting native generation only once FiSH's core banking, Osusu, Payroll, and Risk Management modules are stable.
2. **Narrative content ownership (UC-X3)** — whether FiSH/the filing module ever needs to generate statutory narrative (directors' report, notes to the accounts) or only ever produces tagged figures for a separately authored document.
3. **Taxonomy versioning cadence (NFR-X02)** — needs a defined process for who monitors HMRC/Companies House/Revenue/CRO taxonomy release notices and triggers UC-X1's re-mapping.
4. **Segregation of duties enforcement (FR-X09)** — for a small finance function, is there always a genuinely distinct approver available, or does this requirement need an interim exception process while the Group is small?
5. **Companies House filing API access** — Companies House has been moving toward mandatory software-based filing (reducing/removing paper and web-form options); worth confirming current requirements before assuming any particular submission channel is available, since this is exactly the kind of "current state" detail that shifts and should be verified against Companies House's own guidance at build time rather than assumed from general knowledge.
