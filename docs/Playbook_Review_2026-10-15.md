# Playbook review against today's decisions (CM, 2026-10-15)

Femi: "Review the Playbooks". Scope taken: every service playbook, SPUTO and test plan in `docs/reports/Playbooks/` checked against the decisions made today (`docs/Decisions_Log.md`, 2026-10-15 entries). Method: CM scanned all of them for terms the decisions retire, then asked each running session to review its own area and fix its own docs (docs only, claim a row, hand CM the tip). Sessions that are not running get the list below instead.

## The decisions every playbook must now agree with

1. **Prodeo is a landlord** with no role in a Tenant's data, purchase orders, accounts or transactions. FiSH delivers GLaaS for SMEs. No "Prodeo's role", "Prodeo executes", "Prodeo support in the database", no Prodeo operator route that edits Tenant data. Recovery of a stuck record is tenant-side (identical retry, or a route for the Tenant's Owner Admin or accountant). "Contact support" for a tenant-data problem becomes "contact your administrator".
2. **Trade finance** stays, generic, for the Tenant's own lender; Prodeo never finances, arranges or confirms anything. POP's `executingParty` is now `TENANT` / `TENANT_LENDER` (old `PRODEO`/`BANK` still accepted); `prodeoRole` is ignored and always null (POP :47).
3. **Names:** the HR area is **Personnel** (not "People", not "Team"); no separate Access label; each employee row has "Give access" / "Remove access" and one "Invite someone who isn't an employee" button.
4. **Approval rule:** a delegate raises an access change, only the Business Owner approves (the Owner may raise and approve in one step, recorded self-approved). Delegates keep acting directly until the request flow exists.
5. **Payroll split** is the top priority: PAYROLL module declared but withheld; at the switch only Owner Admins and Accountants get it; Q3 pay changes Owner Admin only; one access level per assignment (per module is KIV); PAYE and employer costs recorded as ledger liabilities, staged (D-PAY-A yes).
6. **Dashboard** "Sales today" is net, "(excluding VAT)"; form defaults: the user chooses the sale type; submit disabled with a reason until required fields are filled; dash for no data.
7. **Mobile app:** one app for every role, online only, nothing persisted, PDF downloads audited; access token 15 min, refresh 7 days, lock after about 2 minutes; email first, push later; store accounts held by the UK parent company.
8. **Supplier discounts:** first four kinds, one account 4920, settlement-discount VAT only after a full SPUTO and a tax professional.
9. **Fixed assets:** request then Owner Admin approves, may self-approve flagged, evidence on acquisition.
10. **Phone check** (EA SPUTOs): the Business Owner's approval acts must work on one phone screen; SPUTOs create playbooks.

## What the scan found (stale or conflicting text)

| Where | Finding | Owner |
|---|---|---|
| `POP/POP_Playbook_Draft.md`, `POP/POP_MVP_Definition_REFRESHED_2026-10-13.md` | "Prodeo support" / "Prodeo operator" recovery; `ExecutingParty`/full financier wording | POP (already fixing in its docs branch) |
| `Omniview/*` (SRS, v2 SRS, SPUTO seed, support model, backlogs, test plans) | "Prodeo operator" and "operator route": must be checked that no Omniview action edits or reads Tenant business data (support tickets and platform operations only) | EA (Omniview owner) |
| `EA/EA_Playbook.md`, `EA/EA_Payroll_Module_Design.md`, `TestPlans/EA_Playbook_Test_Plan.md` | "Team tab / Team screen" wording; "People (HR)" in `Payroll_SPUTO.md` | EA |
| `SOP/SOP_Playbook_Draft.md` | "contact support" and any Prodeo-as-financier wording in trade finance | SOP (no running session: CM task, below) |
| `TestPlans/Retest_Plan_2026-10-15.md`, `TR-7_VAT_Preselect` | tests the "Prodeo's role" field and "Full financier" default: those controls are removed (WEB PR 164+) | CM updates the test plans for the tester |
| `Platform/Decisions_Log.md` | the POP line saying `prodeoRole` picks the payment account was corrected by POP (it is `executingParty`) | done |
| every playbook | no "phone check" acceptance list for the Owner's approval screens yet | EA writing it into Payroll and Personnel playbooks |

## Not yet reviewed, needs a session

- IM, SOP, ER playbooks: no session is running. CM did the term scan only (nothing found for IM and ER; SOP one hit). A real content review against the decisions needs those sessions started.
- GL and HR playbooks: asked their sessions to review (below).

## Requests sent

EA, GL, POP, HR and WEB were each asked to review their own playbooks and test plans against this list, fix stale text in a docs-only branch, and hand CM the tip. CM updates the tester's retest plan and the SOP line.
