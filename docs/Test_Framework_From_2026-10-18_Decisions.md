# Test framework from the 2026-10-18 decisions (CM synopsis, essentials only)

Prepared by CM for Femi, 2026-10-18. This replaces an earlier draft that mixed in release status. Release state changes hourly and does not belong in a framework. What lasts is the principles, who owns what, and the rule that **tests come from the Playbooks, and Playbooks come from SPUTO exercises** (Scope, Plan, Use case, Task, Order). Nothing is tested that a SPUTO has not first said should be true.

## 1. The chain

The Playbook is SPUTO-driven: it is derived from the SPUTO exercises, not written from memory or from what happens to be built. A Playbook statement that no SPUTO supports is a drift and is corrected or removed.

SPUTO (the decision and its reasoning) -> Playbook (how the service behaves, in plain words) -> Test plan (one per Playbook, in `Playbooks/TestPlans`) -> Test result (written in the Playbooks' `TestResults` folder, `docs/reports/Playbooks/TestPlans/TestResults`) -> CM response (`TestResultsResponses`, inside it, named `<SERVICE>_Response_to_<result>.md`). Any decision of Femi's lands in `Decisions_Log.md` first, then in the owning SPUTO and Playbook, and only then does a test row change. If a test and a Playbook disagree, the Playbook wins and the test is corrected; if the Playbook and a decision disagree, the decision wins and the Playbook is corrected.

## 2. The principles every test plan is read against

| # | Principle | Where it lives |
|---|---|---|
| P1 | The account of every posting line is determined by the transaction type from the Company's chart. No account configured -> Suspense, never a silent default. | GL per-line account design; GL Playbook |
| P2 | Owning services hold the details; GL aggregates control accounts only. POP owns Accounts Payable, SOP owns Accounts Receivable, IM owns Inventory and Services, Payroll and Fixed Assets own theirs. Each reconciles to its control account. | Each service's Playbook |
| P3 | A VAT category lives only in IM, on the item (goods or services). It is never defaulted, never copied elsewhere. | IM VAT-category SPUTO |
| P4 | Prodeo is a landlord, with no role in any Tenant's data, orders, accounts or transactions. | Every Playbook |
| P5 | FiSH prepares and analyses; the Tenant owns the records and is audited. Calculation accuracy is our bar. | Tax and GL Playbooks |
| P6 | Ledger locks apply to Fixed Asset accounts only, never Current Assets (results of POP, IM and SOP working together) and never Investments. | Fixed Assets SPUTO |
| P7 | Words: Sales, Purchases, Inventory, Personnel; schools keep their own terms. Support is for FiSH faults, the administrator for the Tenant's own business matters. | WEB Playbook, Layout Principles |
| P8 | UI/UX is as important as features. | Layout Principles, WEB UI/UX plan |
| P9 | Approvals: a delegate raises, the Owner approves (may self-approve, flagged). Foundations (idempotency, concurrency) come before money features. | EA and RBAC SPUTOs |

## 3. One test pattern, applied to each service

For each service, three questions, taken from its Playbook, with a row in its test plan for each:
1. **Does it do the thing its Playbook says?** (the happy path, in the owner's words)
2. **Does its total agree with GL?** (POP vs 2000, SOP vs 1100, IM vs 1300, Fixed Assets vs its accounts, Payroll vs its liabilities)
3. **Does it refuse what it must refuse, plainly?** (no account -> Suspense; no VAT category -> refused with a reason; wrong role -> refused; repeat of the same request -> same result)

## 4. The three subledger services (the heartbeat)

Femi asked POP, SOP and IM each to state what they cover end to end. The same list is the test checklist for each: register, due dates from payment terms, ageing, partial payments or collections, credit notes, discounts, statements, payment runs or follow-ups, reconciliation to the control account. IM's version covers the whole stock and service life cycle (item master, opening stock, receipts, issues, returns, adjustments, counts, costing, valuation). Each service's built/partly/missing table goes into its Playbook first; the test plan is then built from the Playbook, never directly from the table.

## 5. What is waiting on a decision (tests cannot be finalised until Femi answers)

Interim fee-invoice route for schools; credit limit warn or block; reminders manual first; POP's three AP questions; payroll: first countries and whether automatic PAYE gates going live, who signs off tax tables, lock on payroll-owned liabilities, parallel-run length, what HR may see of pay; whether "Inventory and Service Management" is confirmed as the IM label.

## 6. What needs Femi's go before it is tested with data

Any write: setting a selling price then a sale, the fixed-asset cycle, cash-book writes, sending PO-000002 and everything after it, supplier payments, and the per-line account cases. Everything else is read-only.

## 7. Where the detail is

Per-service test plans and `INDEX.md` in this folder; decisions in `docs/Decisions_Log.md`; the Live-switch checklist in `docs/reports/Live_Switch_Checklist.md`. Release and deployment state is not recorded here; CM answers it from the live system when asked.
