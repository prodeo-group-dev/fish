# Live-switch checklist (CM)

Status: DRAFT, 2026-10-13. The one list of things that are deliberately OFF, parked or unsafe until Femi announces the switch from Development to Live (Femi announces it explicitly; nobody infers it). Owner: Configuration Manager (CM). Every item has an owner and a condition; an item is done only when CM has reviewed it and Femi has said so. Production is legacy test data until then.

## A. Deferred enforcement (RBAC, flags default OFF)

Generated from `docs/ER_Playbook_2_SRS.md` section 1.1 (Femi, 2026-10-13: "RBAC is still essential but perhaps easier turned on when other features are built"). **When a service adds a new deferred permission it adds a row here in the same change.** Each switch-on is a CM-reviewed change, not a code deploy.

| # | New permission or rule | Requirement | Flag (default OFF) | Where | Default holders (to confirm) | Condition to switch ON |
|---|---|---|---|---|---|---|
| E1 | **Set pay basis**, **run payroll**, **approve a pay run** (three separate; preparer is not the approver) | PL-STF-9 | `HR_ENFORCE_PAY_SPLIT` | HR, EA | **Updated 2026-10-15/16, owned by HR and EA:** changes to pay basis, pay rate, frequency and bank details are **Owner Admin only** (Q3); the PAYROLL module is granted at the switch to **Owner Admins and Accountants only** (the switch-day checklist warns each Tenant who loses Pay runs); a preparer may reject their own run but never approve it; the Owner may approve their own, flagged self-approved | HR/Payroll split Move 1 built (two modules in HR; Payroll (PAY) its own service before the Live switch); Payroll screen under Finance and Personnel under Administration; UAT passed |
| E2 (LATER, parked: safeguarding deprioritised 2026-10-13) | **Break-glass for safeguarding records** (access with a reason, time-limited, alert to the group). The admin-alone deny itself is **not flagged**: D13 is decided and it is an add-a-deny, built on ER branch `feature/safeguarding-admin-deny` (cf1c711) and **not released** | PL-SAF-1 | `ER_ENFORCE_SAFEGUARDING_BREAK_GLASS` | ER | safeguarding lead, pastoral lead | Femi reinstates safeguarding (country-triggered); the safeguarding lead role is assigned in each school; break-glass built |
| E3 | **Admin loses the student writes** (create, CSV, photo, transfer, identity link) | PL-ADM-5, D14 | `ER_ENFORCE_ADMIN_STUDENT_WRITE_DENY` | ER | registrar (and an admin who also holds REGISTRAR) | the Roles-and-access screen is live and every school has a registrar; at the dev-to-Live switch |
| E4 | **Form-master approval of the register** (arm-scoped teacher, delegable) | PL-CLS-3, PL-ATT-8 | `ER_ENFORCE_FORM_MASTER_APPROVAL` | ER | the form master of the arm | the arm-scoped assignment exists and each arm has one (the form master approves attendance only; **D3** decided: test marks go to the head of department, then the head teacher) |
| E5 | **Result approval chain and locking** (published marks locked; changes need approval) | PL-ASM-4 | `ER_ENFORCE_RESULT_APPROVAL` | ER | per **D3, decided (Femi)**: head of department, then head teacher, configurable per school | approvers assigned per school; report-card publication built |
| E6 | **Promotion approval** by the head teacher | PL-ASM-9 | `ER_ENFORCE_PROMOTION_APPROVAL` | ER | head teacher | promotion run built (**D11** decided: positions on by default; promotion by overall average plus compulsory subjects) |
| E7 | **Contact restrictions block release and pickup** (court orders) | PL-CON-6 | `ER_ENFORCE_CONTACT_RESTRICTIONS` | ER | safeguarding lead, head teacher see detail | the contacts model is live; restricted flags captured for existing students |
| E8 | **Vetting data visible only** to the head teacher, safeguarding lead, admin | PL-STF-4 | `ER_ENFORCE_VETTING_VISIBILITY` | ER | as stated | the teaching record is live |
| E9 | **Document sensitivity levels** (a document inherits its record's permission plus a type level) | PL-DOC-2 | `ER_ENFORCE_DOCUMENT_SENSITIVITY` | ER | by document type | documents port built (**D2**) |
| E10 | **Segregation of duties in fees** (who records a payment cannot approve a waiver or void a receipt) | PL-FEE-10 | `ER_ENFORCE_FEE_SEGREGATION` | ER | bursar approves, fee officer records | waivers and receipts built; **D8** decided |
| E11 | **Export of restricted fields** needs the field permission and is logged | PL-RPT-4 | `ER_ENFORCE_EXPORT_FIELD_RESTRICTIONS` | ER | by field | the logging is built (it is not behind a flag); standard reports built |
| E12 | **Service-account scope** for sales, collections and reads at SOP, and the school rule | PL-FEE-2, 3, 7 | existing audience switch (unset audience refuses every ER token) | SOP, EA | the Education Runtime service account | the EA industry route and the SOP school rule live, and CM says so; **the Education industry flag is the definition of a school** (Femi 2026-10-13), so the earlier pre-switch data fix is retired as a gate (a Company that should be a school but lacks the flag is corrected case by case); already a deliberate switch |
| E13 | **Guardian sign-in** (phone and one-time code) and **MFA for school staff** | PL-PRT-1, PL-SET-4 | the owner-MFA flags (existing pattern) | CM, EA, ER | n/a | the Live switch (decided); SMS or Cognito phone path available |

## B. Security and identity

| Item | Owner | Condition |
|---|---|---|
| Full security scope (review of every auth path, secrets, network, data-at-rest/in-transit, logging, backups) | CM | Femi announces the Live switch |
| Owner MFA policy flags (currently OFF; approve at the switch) | CM, EA | UAT passed; Femi approves |
| AWS access: replace the root login used for Terraform with a named admin identity; fix the CLI login | CM, Femi | before Live |
| Terms agreement during onboarding (parked) | EA, Femi | before first external customer |

## C. Data

| Item | Owner | Condition |
|---|---|---|
| Decide what happens to existing production data (all of it is test data today) | Femi, CM | Live switch |
| SOP school rule (E12): the Education industry flag IS the definition of a school (Femi 2026-10-13), so no separate school list is needed; any Company that should be a school but lacks the flag is corrected case by case when found | CM, EA | when E12 is switched on |
| Legacy database names (`schooladmissions_production`, `fish_production`): rename in a planned downtime (docs/Downtime_Maintenance_Backlog.md) | CM | downtime window |

## D. Operations

| Item | Owner | Condition |
|---|---|---|
| Alarm subscription confirmed (dev@theprodeogroup.com) and tested | CM | before Live |
| Branch protection requiring the Jenkins PR check; retire duplicate GitHub Actions checks | CM | before Live |
| Contract fixtures nightly drift job running (docs/Cross_Service_Contract_Fixtures_SPUTO.md) | CM | before Live |
| Database safety (read live 2026-10-13, instance fish-gl-engine-production): automated backups retained for 1 day only, single-AZ, no deletion protection, final snapshot skipped on delete, storage encrypted. Raise retention, turn on deletion protection and a final snapshot, decide on multi-AZ, write and run a restore drill | CM | before real data |

Rules: this file is the single list; items are removed only by CM with a note of who confirmed; new deferred items from any service are added in the change that defers them.

## E. Service go-live flags (from the services' own MVP definitions, 2026-10-13)

| Item | Owner | Condition |
|---|---|---|
| GL: no audit trail written (the store exists, nothing writes to it; a journal entry carries no actor): first writers FS-3 and T17 | GL | before real data |
| GL: no row-level security (docs/GL_RLS_Scoping.md; best done before Live while data is test data) | GL, CM | Femi decides when |
| GL: no route to create, open, close or reopen a Period, and no generic reversal route over HTTP (month-end close and reversal are not possible from the app) | GL, Femi | Femi decided periods auto-open and close explicitly, deferred past UAT: schedule before Live |
| GL: known accounting-correctness gaps (seam A GRNI, sales returns without VAT reversal, fixed-asset gaps, non-atomic aggregate routes, simultaneous-duplicate gap) | GL, POP, IM | each scheduled; none may be left silent at Live |
| IM: opening stock has no route; no stock reservation against open orders | IM | before a customer with existing stock |

## F. Log-first switches now live (CM reads the logs, then flips)

| Switch | Where | Now | Flip to enforce when |
|---|---|---|---|
| `ER_SCHOOL_ROW_MODE` (ER :96, 2026-10-13) | ER task definition | log | a normal day of real use shows no "WOULD REFUSE school_row_missing" in /ecs/fish-school-admissions (or each id shown is fixed by EA reprovision) |
| `ER_DPID_BINDING_MODE` (ER :97, 2026-10-13) | ER task definition | log | each school using BuzzMe/DPID devices has been enabled by its admin (PUT /schools/{id}/integrations/dpid), and no unexpected "WOULD REFUSE dpid_not_enabled" remains |
| `FISH_SETTLEMENT_ACCOUNT_MODE`, `FISH_BANK_RECONCILIATION_MODE` (GL, earlier) | GL task definition | log | CM reads GL logs and finds no would-refuse |

## Added 2026-10-16 (Femi's decisions)

- **P8, access-change approval flow**: a delegate raises an invite, role, module or remove-access change in Personnel and only the Business Owner approves (the Owner may raise and approve in one step, recorded self-approved). REQUIRED before the Live switch. Owner: HR (StaffChangeRequest kinds access grant, change, revoke; FR-PEO-19) with EA executing.
- **PAYROLL switch-day warning**: at the PAYROLL switch only Owner Admins and Accountants get it, so list and warn every other holder of HR at WRITE or above first (EA's read-only report `docs/reports/Switch_Day/payroll_switch_day_report.sql`).
- **Early-payment (settlement) discount VAT**: do not enable any settlement-discount posting until the Settlement Discount VAT SPUTO is approved and a tax professional has confirmed each jurisdiction's rule.

## Added 2026-10-20 (the Payroll, new HR and Cash and Bank Books split)

The three services (payroll-api, hr2-api, cbb-api) are live in production but NOTHING is switched for users. Switch order, each step gated on the one before:

1. **Parity run** (old fish-hr-payroll vs payroll-api + hr2-api on two test Companies, GL trial balance compared) passes. Needs Femi's own token and two test Companies; script `docs/reports/Playbooks/HR/parity_run.py`.
2. **EA enables the modules** and **EA's backfill runs**: `EA_ENABLED_MODULES` (PAYROLL, CASH_BANK_BOOKS) with the manual task-definition push, then each backfill dry-run first, then execute, only after the enabling release is stable. Owner Admins and Accountants get the grants (Femi's decision).
3. **HR and pay runs (Femi's rule, settled 2026-10-20 as relayed):** HR may read pay runs, prepare a run and request advances/claims; approve, reject, retry and resume are Business Owner only; only Payroll runs the payroll. The earlier idea of a release gate (hide Run payroll from HR-only holders only after EA's PAYROLL grants) is WITHDRAWN. Before payroll-api enforcement is turned ON, HR must change the doors so HR can still prepare and approve/reject/retry/resume are Owner Admin only (today with enforcement ON prepare needs PAYROLL WRITE and approve needs PAYROLL APPROVE, which does not match). Until then enforcement stays OFF and the old behaviour already matches.
4. **WEB switches addresses** (config only): `VITE_HR_API_BASE_URL` to hr2-api, `VITE_PAYROLL_API_BASE_URL` to payroll-api, the Cash and Bank base URL to cbb-api, and `VITE_PAY_SPLIT=new`, set together, in ONE WEB release window, only after the WEB reviewer's APPROVED on each branch and Femi's go.
5. **Cash and Bank data gate:** GL's existing bank_reconciliations rows are not migrated into cbb-api. First Femi runs the read-only count (`docs/reports/Switch_Day/count_gl_bank_reconciliations.sh`). Zero or test-only rows: empty-after-switch is accepted and GL's tables stay as the rollback copy. Real rows: GL writes the copy script, one CM/Femi-run step on cbb_production.
6. **Retire the old fish-hr-payroll** only after the above and a stable period; the old service is the rollback until then.

Open Femi decisions that touch this sequence: the self-service leave/claims role (STAFF), mobile-money wallets as Cash or Bank.
