# Live-switch checklist (CM)

Status: DRAFT, 2026-10-13. The one list of things that are deliberately OFF, parked or unsafe until Femi announces the switch from Development to Live (Femi announces it explicitly; nobody infers it). Owner: Configuration Manager (CM). Every item has an owner and a condition; an item is done only when CM has reviewed it and Femi has said so. Production is legacy test data until then.

## A. Deferred enforcement (RBAC, flags default OFF)

Generated from `docs/ER_Playbook_2_SRS.md` section 1.1 (Femi, 2026-10-13: "RBAC is still essential but perhaps easier turned on when other features are built"). **When a service adds a new deferred permission it adds a row here in the same change.** Each switch-on is a CM-reviewed change, not a code deploy.

| # | New permission or rule | Requirement | Flag (default OFF) | Where | Default holders (to confirm) | Condition to switch ON |
|---|---|---|---|---|---|---|
| E1 | **Set pay basis**, **run payroll**, **approve a pay run** (three separate; preparer is not the approver) | PL-STF-9 | `HR_ENFORCE_PAY_SPLIT` | HR, EA | Proprietor and HR officer set basis; accountant or bursar run; a different person approves | Pay basis on the employment record built; HR's run and approve are separate steps; the Payroll screen is split by division; UAT passed |
| E2 | **Admin alone loses safeguarding access**; break-glass with reason, time limit and alert | PL-SAF-1 | `ER_ENFORCE_SAFEGUARDING_ADMIN_DENY` | ER | safeguarding lead, pastoral lead, head teacher | **D13** decided (if Femi chooses "now" it ships as an add-a-deny instead and this flag is dropped); the safeguarding lead role is assigned in each school |
| E3 | **Admin loses the student writes** (create, CSV, photo, transfer, identity link) | PL-ADM-5, D14 | `ER_ENFORCE_ADMIN_STUDENT_WRITE_DENY` | ER | registrar (and an admin who also holds REGISTRAR) | the Roles-and-access screen is live and every school has a registrar; at the dev-to-Live switch |
| E4 | **Form-master approval of the register** (arm-scoped teacher, delegable) | PL-CLS-3, PL-ATT-8 | `ER_ENFORCE_FORM_MASTER_APPROVAL` | ER | the form master of the arm | the arm-scoped assignment exists and each arm has one; **D3**-style default confirmed |
| E5 | **Result approval chain and locking** (published marks locked; changes need approval) | PL-ASM-4 | `ER_ENFORCE_RESULT_APPROVAL` | ER | per **D3** (head of department then head teacher, proposed) | approvers assigned per school; **D3** decided; report-card publication built |
| E6 | **Promotion approval** by the head teacher | PL-ASM-9 | `ER_ENFORCE_PROMOTION_APPROVAL` | ER | head teacher | promotion run built; **D11** defaults decided |
| E7 | **Contact restrictions block release and pickup** (court orders) | PL-CON-6 | `ER_ENFORCE_CONTACT_RESTRICTIONS` | ER | safeguarding lead, head teacher see detail | the contacts model is live; restricted flags captured for existing students |
| E8 | **Vetting data visible only** to the head teacher, safeguarding lead, admin | PL-STF-4 | `ER_ENFORCE_VETTING_VISIBILITY` | ER | as stated | the teaching record is live |
| E9 | **Document sensitivity levels** (a document inherits its record's permission plus a type level) | PL-DOC-2 | `ER_ENFORCE_DOCUMENT_SENSITIVITY` | ER | by document type | documents port built (**D2**) |
| E10 | **Segregation of duties in fees** (who records a payment cannot approve a waiver or void a receipt) | PL-FEE-10 | `ER_ENFORCE_FEE_SEGREGATION` | ER | bursar approves, fee officer records | waivers and receipts built; **D8** decided |
| E11 | **Export of restricted fields** needs the field permission and is logged | PL-RPT-4 | `ER_ENFORCE_EXPORT_FIELD_RESTRICTIONS` | ER | by field | the logging is built (it is not behind a flag); standard reports built |
| E12 | **Service-account scope** for sales, collections and reads at SOP, and the school rule | PL-FEE-2, 3, 7 | existing audience switch (unset audience refuses every ER token) | SOP, EA | the Education Runtime service account | the **data fix** (real school Companies correct in EA), the EA route live, and CM says so; already a deliberate switch |
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
| Data fix: every real school Company must have industry type SCHOOL in EA before the SOP school rule is turned on (E12) | CM with Femi (credential-split query) | before E12 |
| Legacy database names (`schooladmissions_production`, `fish_production`): rename in a planned downtime (docs/Downtime_Maintenance_Backlog.md) | CM | downtime window |

## D. Operations

| Item | Owner | Condition |
|---|---|---|
| Alarm subscription confirmed (dev@theprodeogroup.com) and tested | CM | before Live |
| Branch protection requiring the Jenkins PR check; retire duplicate GitHub Actions checks | CM | before Live |
| Contract fixtures nightly drift job running (docs/Cross_Service_Contract_Fixtures_SPUTO.md) | CM | before Live |
| Backups and restore drill documented | CM | before Live |

Rules: this file is the single list; items are removed only by CM with a note of who confirmed; new deferred items from any service are added in the change that defers them.
