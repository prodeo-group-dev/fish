# Accountant / CFO — Use Cases & Requirements

**Context:** Every module built so far (Core Banking, Osusu, Payroll, the emerging Risk Management module, and iXBRL filing) posts to or reads from FiSH, but none of them define the role that sits *above* all of them — the person accountable for the Group's financial integrity as a whole. This document defines that role's use cases and requirements: the CFO/Accountant function that reviews, consolidates, forecasts, and ultimately signs off on what the individual modules produce.

**Scope note:** Where a role title matters, this document uses "CFO/Accountant" to mean whoever holds ultimate financial accountability at a given point in the Group's growth — this may be Femi directly in the near term, an external accountant/fractional CFO at the current stage, and a dedicated in-house CFO once the Group's scale warrants it. The use cases are written to the *function*, not a specific headcount decision.

**Relationship to other modules:** This is a consumer of every other module's output (Banking, Osusu, Payroll, Risk Management, iXBRL) rather than a peer generating its own transaction types. Its primary FiSH interaction is read (trial balances, journal review) plus a narrow, high-control write path (period-end adjusting entries, consolidation entries) — never routine transactional posting, which stays with the module that owns the transaction.

---

## Actors

| Actor | Definition |
|---|---|
| **CFO/Accountant** | Accountable for the Group's financial integrity, reporting, and regulatory financial obligations across all entities |
| **Finance/Purse Ops** | Operational finance function reporting into the CFO/Accountant; executes day-to-day reconciliation, filing preparation, and module-level review |
| **FiSH** | GL of record across all entities; source of every trial balance, journal, and consolidated figure the CFO/Accountant works from |
| **External Auditor** | Independent reviewer/signer of statutory accounts; the CFO/Accountant is the primary internal liaison |
| **Board/Directors** | Recipients of management accounts and financial oversight reporting; approve budgets and major financial decisions |
| **Regulator** | PRA/FCA (Purse), CBI/FCA (Scrip), Revenue/CRO or HMRC/Companies House (statutory) — recipients of regulatory returns the CFO/Accountant is accountable for |

---

## UC-CFO1: Period-End Close

**Actor:** CFO/Accountant, Finance/Purse Ops, FiSH
**Trigger:** Financial period end (monthly, quarterly, annual) reached.

**Flow:**
1. Finance/Purse Ops confirms all module-level postings for the period are complete (Banking transactions, Osusu contributions/payouts, Payroll runs, any Risk Management provisioning entries) — no module should have unposted transactions bleeding into the next period.
2. CFO/Accountant reviews period-end adjusting entries needed (accruals, prepayments, depreciation, provisions) that don't originate from any transactional module but are the CFO/Accountant's own responsibility to post.
3. Adjusting entries are posted to FiSH following the same immutable, reversal-only principle as every other entry — no special "CFO override" path that bypasses the audit trail.
4. Period is formally closed; a closed period's figures become the basis for management accounts (UC-CFO2) and, where applicable, statutory filing (UC-CFO8).

**Open decision:** What is the formal "closed period" control in FiSH itself — does closing a period technically prevent new entries from posting against it (requiring a dated reversal + new-period correction instead), or is closure a reporting-level convention only, with FiSH itself remaining open to entries indefinitely?

---

## UC-CFO2: Management Accounts & Board Reporting

**Actor:** CFO/Accountant, Board/Directors
**Trigger:** Period close complete (UC-CFO1), or ad hoc board request.

**Flow:**
1. CFO/Accountant produces management accounts (P&L, balance sheet, cash flow) per entity and consolidated across the Group, drawing directly from FiSH's closed-period trial balances.
2. Commentary is added covering variance against budget/forecast (UC-CFO3), key risks, and any regulatory or covenant-relevant metrics.
3. Report is presented to the Board, with figures traceable back to FiSH on request — no management account figure should exist that can't be reconciled to a posted journal entry.

---

## UC-CFO3: Budget & Forecast Management

**Actor:** CFO/Accountant, Board/Directors
**Trigger:** Annual budgeting cycle, or periodic re-forecast.

**Flow:**
1. CFO/Accountant builds a budget/forecast per entity, informed by prior-period actuals pulled from FiSH.
2. Budget is approved by the Board and stored as a comparison baseline — held separately from FiSH's actuals (a budget is a plan, not a transaction, and should never be posted as if it were a ledger entry).
3. Each period close (UC-CFO1) triggers an actual-vs-budget variance view feeding into management accounts (UC-CFO2).

**Open decision:** Does the budget live inside the FiSH-adjacent tooling (so variance reporting is native) or in a separate planning tool (e.g., spreadsheet or dedicated FP&A software) that's manually reconciled against FiSH each period?

---

## UC-CFO4: Cash Flow & Liquidity Monitoring

**Actor:** CFO/Accountant
**Trigger:** Ongoing — daily/weekly cash position review, escalating in importance for Purse given deposit-taking-adjacent obligations.

**Flow:**
1. CFO/Accountant monitors real cash/bank positions per entity against FiSH's recorded cash-related balances — this is closely related to, but broader than, Purse's own UC-B9 safeguarding reconciliation (which is member-balance-specific; this use case is whole-of-entity cash, including operating accounts, not just member safeguarding).
2. For Purse specifically, liquidity monitoring must account for Osusu circle timing (funds held between contribution and payout are a liquidity consideration even though they're not literally "Purse's money" in a P&L sense) and any Lending/Risk Management drawdown obligations once that module exists.
3. Shortfall risk or unusual cash movement triggers escalation to the CFO/Accountant regardless of which module generated the underlying transaction.

---

## UC-CFO5: Intercompany & Group Consolidation

**Actor:** CFO/Accountant
**Trigger:** Period-end consolidated reporting requirement (UC-CFO2), or ad hoc Group-level view requested.

**Flow:**
1. CFO/Accountant pulls trial balances from each entity's segregated FiSH books (Scrip, Purse, Prodeo Capital, Property SPV).
2. Intercompany balances (e.g., a payroll recharge flagged in the HR Payroll module, UC-HR12) are eliminated on consolidation — the consolidated Group view should not double-count a transaction that is genuinely just money moving between two Group entities.
3. Consolidated figures are produced without ever merging entities' underlying FiSH ledgers themselves — consolidation is a reporting-layer operation, not a change to how each entity's books are kept.

---

## UC-CFO6: External Audit Liaison

**Actor:** CFO/Accountant, External Auditor
**Trigger:** Annual (or as required) statutory audit cycle.

**Flow:**
1. CFO/Accountant provides the External Auditor with access to relevant FiSH extracts, supporting schedules, and documentation (per entity), leveraging FiSH's immutable audit trail as the primary evidence source.
2. Audit queries and requested adjustments are resolved via the same reversal-only correction principle as any other FiSH correction — an audit adjustment is not a special case that bypasses the ledger's integrity rules.
3. Signed-off financial statements feed into UC-CFO8 (statutory filing).

---

## UC-CFO7: Regulatory Capital & Liquidity Reporting

**Actor:** CFO/Accountant, Regulator
**Trigger:** Periodic regulatory return deadline (e.g., PRA returns for Purse once authorised, CBI/FCA returns for Scrip once authorised).

**Flow:**
1. CFO/Accountant produces the specific regulatory return format required — these are typically not the same as standard management accounts or statutory filings; they follow prescribed regulator templates (e.g., capital adequacy ratios, liquidity coverage metrics specific to credit unions or investment firms).
2. Figures are drawn from FiSH but transformed into the regulator's required structure — this is conceptually similar to the iXBRL mapping/tagging problem (UC-X1) but for prudential returns rather than statutory accounts, and may follow an entirely different submission mechanism per regulator.
3. Submission and confirmation are retained per the same audit-trail discipline as statutory filings (UC-X8).

**Open decision:** Given Purse and Scrip are both pre-authorisation at present, this use case is largely a future-state placeholder — worth revisiting in detail once authorisation is closer and the exact PRA/CBI return requirements are known, rather than speculatively building against assumed formats now.

---

## UC-CFO8: Statutory Filing Sign-off

**Actor:** CFO/Accountant, External Auditor
**Trigger:** Statutory filing prepared (see iXBRL/XBRL document, UC-X1–X8).

**Flow:**
1. CFO/Accountant reviews the generated/validated iXBRL filing (or externally-prepared equivalent) before approval.
2. Sign-off satisfies the segregation-of-duties requirement already defined in the iXBRL document (FR-X09) — the CFO/Accountant is explicitly the distinct approver from whoever prepared the filing, not the same person wearing two hats without a second reviewer.
3. Approved filing proceeds to submission (UC-X5).

---

## UC-CFO9: Risk Oversight & Provisioning Review

**Actor:** CFO/Accountant, Risk Management module (once defined)
**Trigger:** Period-end, or whenever the Risk Management module flags a material exposure (loan arrears, Osusu default under Option B, concentration risk).

**Flow:**
1. CFO/Accountant reviews aggregate risk exposure across all sources — Lending (once built), Osusu default liabilities (UC-4, Option B), and any other credit-risk-shaped position — as a single consolidated view rather than per-module silos.
2. CFO/Accountant approves or adjusts provisioning levels (loan-loss provisions, expected-default reserves) as period-end adjusting entries (UC-CFO1) — this is the accounting consequence of Risk Management's assessments.
3. Provisioning judgement and rationale is documented, since this is one of the more judgement-heavy (versus purely mechanical) entries the CFO/Accountant is responsible for, and is a common area of audit scrutiny.

---

## UC-CFO10: Journal Entry Review & Exception Approval

**Actor:** CFO/Accountant
**Trigger:** Ongoing, or triggered by module-level exception flags (e.g., a payroll correction, an Osusu default, a large or unusual transaction flagged by fraud monitoring).

**Flow:**
1. CFO/Accountant has read access to all posted journal entries across all entities and modules, with the ability to filter/flag unusual activity for review.
2. Where a module's own process requires escalation beyond its normal operational approver (e.g., a payroll reversal per UC-HR9, a fraud hold per UC-B11), the CFO/Accountant is the final internal approver before resolution.
3. This use case is explicitly review/approval, not routine posting — the CFO/Accountant should rarely, if ever, be the one entering routine transactional data; that stays with the owning module.

---

## Functional Requirements

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-CFO01 | System shall confirm all module-level postings for a period are complete before period close is finalised. | UC-CFO1 |
| FR-CFO02 | System shall allow CFO/Accountant-initiated adjusting entries, posted under the same immutable/reversal-only rules as all other FiSH entries — no bypass path. | UC-CFO1 |
| FR-CFO03 | System shall produce entity-level and consolidated management accounts directly from closed-period FiSH trial balances. | UC-CFO2 |
| FR-CFO04 | Every management account figure shall be traceable back to its originating FiSH journal entries on request. | UC-CFO2 |
| FR-CFO05 | System shall store budget/forecast data separately from actuals, never as a FiSH transaction, while supporting variance reporting against actuals. | UC-CFO3 |
| FR-CFO06 | System shall provide a consolidated, whole-of-entity cash/liquidity view, distinct from and broader than Purse-specific member-balance safeguarding reconciliation (UC-B9). | UC-CFO4 |
| FR-CFO07 | System shall eliminate intercompany balances on consolidation without altering any individual entity's underlying FiSH ledger. | UC-CFO5 |
| FR-CFO08 | System shall provide External Auditor access to relevant FiSH extracts and supporting documentation, scoped per entity and per audit engagement. | UC-CFO6 |
| FR-CFO09 | System shall support generation of regulator-specific prudential return formats from FiSH data, structurally similar to but distinct from statutory (iXBRL) filing generation. | UC-CFO7 |
| FR-CFO10 | System shall require CFO/Accountant sign-off, as a distinct approver from the filing preparer, before any statutory filing proceeds to submission. | UC-CFO8, FR-X09 |
| FR-CFO11 | System shall provide a consolidated cross-module view of credit-risk-shaped exposures (Lending, Osusu default liabilities, and equivalents) for CFO/Accountant review. | UC-CFO9 |
| FR-CFO12 | System shall allow the CFO/Accountant to post provisioning entries as period-end adjustments, with documented rationale retained against the entry. | UC-CFO9 |
| FR-CFO13 | System shall give the CFO/Accountant read access to all posted journal entries across every entity and module, with filtering for unusual/flagged activity. | UC-CFO10 |
| FR-CFO14 | System shall route module-level escalations requiring approval beyond the normal operational approver to the CFO/Accountant as final internal reviewer. | UC-CFO10 |

---

## Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-CFO01 | Segregation of duties | The CFO/Accountant's review/approval role shall remain structurally distinct from routine transactional posting performed by Banking, Osusu, Payroll, or Risk Management modules — the role is a control, not a data-entry function. |
| NFR-CFO02 | Traceability | Every figure the CFO/Accountant reports externally (Board, Auditor, Regulator) shall be reconstructable to specific FiSH journal entries without manual, undocumented adjustment. |
| NFR-CFO03 | Access scope | CFO/Accountant access shall span all entities and modules by design (the role is Group-wide), distinct from operational roles that are typically entity- or module-scoped. |
| NFR-CFO04 | Timeliness | Period-close (UC-CFO1) shall complete within a defined window (to be set) after period end, sufficient to meet downstream management reporting and, where applicable, statutory filing deadlines already defined in the iXBRL document (NFR-X03). |
| NFR-CFO05 | Judgement documentation | Any entry involving accounting judgement (provisioning, accruals, estimates) shall require a documented rationale field, not just a bare figure — this is both good practice and an audit expectation. |

---

## Traceability Summary

- UC-CFO1 Period-End Close
- UC-CFO2 Management Accounts & Board Reporting
- UC-CFO3 Budget & Forecast Management
- UC-CFO4 Cash Flow & Liquidity Monitoring
- UC-CFO5 Intercompany & Group Consolidation
- UC-CFO6 External Audit Liaison
- UC-CFO7 Regulatory Capital & Liquidity Reporting
- UC-CFO8 Statutory Filing Sign-off
- UC-CFO9 Risk Oversight & Provisioning Review
- UC-CFO10 Journal Entry Review & Exception Approval

This document sits above and cross-references every module-specific document produced so far (Core Banking, Osusu, HR Payroll, iXBRL/XBRL) — it does not duplicate their transactional use cases, only the oversight layer that consumes their output.

---

## Open decisions carried forward (unresolved, high-priority)

1. **Period-close mechanics in FiSH (UC-CFO1)** — whether "closing" a period is enforced at the ledger level (blocking new entries) or is a reporting convention only. This affects control strength and should be settled as a FiSH architecture decision, not just a process document.
2. **Budget/forecast tooling (UC-CFO3)** — native to the FiSH ecosystem versus external FP&A tooling reconciled manually; affects how automatic variance reporting can be.
3. **Regulatory return format (UC-CFO7)** — genuinely undefined until Purse/Scrip authorisation is further along; flagged as future-state rather than something to build against speculative requirements now.
4. **Role concentration risk (NFR-CFO01, NFR-CFO03)** — at current Group size, the CFO/Accountant function may be one person (or Femi directly) who is also close to or involved in operational decisions elsewhere in the Group. Worth naming explicitly how segregation of duties is maintained in practice while the organisation is small, rather than assuming the org-chart separation this document implies already exists.
5. **Consolidation scope (UC-CFO5)** — confirm whether all four entities consolidate under one Group set of accounts, or whether Purse's regulatory status (credit union) requires it to be reported on a standalone basis even where Group management accounts are consolidated for internal purposes.
