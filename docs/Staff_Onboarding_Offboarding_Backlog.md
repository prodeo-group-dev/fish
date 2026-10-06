# Staff Onboarding and Offboarding — Backlog (Task breakdown and dependency order)

**Status:** DRAFT, 2026-10-06. SPUTO passes **T** and **O**. Requirements: `docs/Staff_Onboarding_Offboarding_SRS.md`; use cases: `docs/Staff_Onboarding_Offboarding_Use_Cases.md`. **Design only: nothing below starts until Femi says go.** Format follows `docs/Omniview_Backlog.md` and `docs/GL_POP_IM_SOP_Backlog.md`: claim a row (session and date) before starting, mark Done with a commit reference, never edit another session's row.

**Lead:** EA (the Owner Admin's toolkit; the Owner Admin is the business owner). HR and payroll administration are grouped under EA. **Essential collaborators:** WEB (every screen) and CM (release order, review, wiring). Also HR (owns the employment and the request) and ER (the school duty).

## Coordination register (every peer dependency, per the prime directive)
| Peer | What this work depends on them for |
|---|---|
| HR | the request aggregate and its routes (2.x); Employee email and terminate (1.4); HR's own payroll-approval SPUTO (`Payroll_Approval_*`, branch `docs/payroll-approval-sputo` `ce81bd6`) for the shared Approvals place; the version contract for the EA route |
| WEB | every screen (6.x); role-based visibility; hiding the Dashboard tab for non-owners before EA ships that gate; the STAFF label; mirroring these rows in `WEB/COORDINATION.md` |
| CM | release order, HIGH review of each leg that changes who can do what, the HR service audience (already set in live task definition `fish-enterprise-administration:67`), any new env var, the data-handling questions (OI-10); pushes and deploys everything |
| ER | the staff/employment routes, the `ea-provisioning` allowlist and `GET /schools/{id}/me` (4.x); adopt-or-refuse (OI-9) and dormant-roles-on-rehire (OI-11) decisions; their migration waiting on ER PR #9 |
| GL | accepting a new `STAFF` role value before EA emits it (1.3) |
| Femi | decisions in Wave 0 |

## Wave 0 — Decisions (Femi; blocks the rows named)
| # | Decision | Blocks |
|---|---|---|
| 0.1 | OI-2: delegate = HR module at WRITE+ at the Company (recommended), or an explicit switch | 2.2 |
| 0.2 | OI-3: interim, make EA invite/remove Owner-Admin only (recommended). Revises Femi's 2026-09-23 direction that an HR Officer at ADMIN keeps staff management, so it is a question for him, not a build step | 1.1 |
| 0.3 | OI-4: how unpaid staff are modelled in HR | 1.4, 2.1 |
| 0.4 | OI-5: does an offboarding trigger anything in payroll (final pay, leave payout, advances) | 2.4 |
| 0.5 | OI-8: which EA role a non-function staff member (teacher) holds; `STAFF` recommended | 1.3, 3.3 |
| 0.6 | OI-9: adopt or refuse a hand-entered ER assignment (ER recommends refuse; if ever approved it is an explicit owner-confirmed `adoptExisting: true` on the same PUT, answered `APPLIED_ADOPTED`, never automatic) | 4.2 |
| 0.9 | OI-11: dormant admin-granted ER roles reviving on a rehire; ER leans to clearing them when the LAST active link is explicitly DELETEd (undecided) | 4.1 |
| 0.7 | OI-1: where the request lives (HR proposed); agreed by HR | 2.1 |
| 0.10 | OI-12: **settled in principle by D7 (Owner Admin is the sole approver)**: a delegate's change to pay rate, pay frequency or bank details cannot take effect without the Owner Admin. Mechanism: v1 = those three fields on `PUT /employees/{id}` become Owner-Admin-only direct acts (HR's and CM's recommendation; the edit form hides them for a delegate, WEB), delegates keep name, email and hours; a `PAY_CHANGE` request kind later if wanted. Old and new values recorded in an audit trail; lands with HR's pay-integrity change, CM HIGH review | 2.2, 1.4 |
| 0.8 | OI-10: retention and access of personal data in these records | 2.1 |

## Wave 1 — Independent first moves (can run in parallel)
| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 1.1 | EA invite and remove become Owner-Admin only (interim, FR-ONB-19); roster read stays for delegates; update the two existing HR_OFFICER tests; own deploy, HIGH review | EA | 0.2; CM review; WEB: confirm TeamTab already gates by `isOwnerAdmin` | Not started |
| 1.2 | EA Approvals Queue becomes Owner-Admin only (FR-ONB-15); no WEB consumer exists yet, so low blast radius; own deploy | EA | CM review; WEB (will be the only consumer) | Not started |
| 1.3 | GL accepts a `STAFF` role value (and maps it to no elevated access); then verified live | GL, reviewed by CM | 0.5; CM running-image check | Not started |
| 1.4 | HR: Employee email required and normalised on the request path; a derived employment status (`UPCOMING`/`ACTIVE`/`ENDED`, no stored status); a monotonic integer `employmentVersion`; employment type `UNPAID`; the `employee_ended` payroll-line rule; Owner-only direct `POST /employees` and end-date edits (FR-ONB-18) | HR | 0.3 (needed for `UNPAID` only); WEB accepts `UNPAID` and new statuses first (consumers before producer) | Not started |
| 1.5 | EA dashboard Owner-Admin only (done, `fix/dashboard-owner-admin-only` `1374ae6`, CM-approved) | EA | WEB hides the Dashboard tab for non-owners first (the condition CM set); ratios release lands first | Built, held |

## Wave 2 — The request (HR)
| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 2.1 | `StaffChangeRequest` aggregate, statuses, audit, migration (FR-ONB-1,2,7), modelled on `PayrollRunSubmission` | HR | 0.1, 0.3, 0.7, 0.8; HR's payroll SPUTO conventions (V9 migration order) | Not started |
| 2.2 | Raise, list, get and cancel routes; delegate gate = HR grant (FR-ONB-4); owner self-approves (FR-ONB-5) | HR | 2.1, 0.1; WEB (screens) | Not started |
| 2.3 | Approve and reject routes, owner-only via `requireOwnerCaller` (FR-ONB-3,6); decision and execution separate; execution uses the **atomic claim shared with HR's payroll approval**, so HR's payroll SPUTO Wave 2 comes first | HR | 2.1; HR payroll SPUTO Wave 2 (branch `docs/payroll-approval-sputo`); CM HIGH review | Not started |
| 2.4 | Execution on approval: create Employee or record end date, then call EA's internal route, per-leg outcomes, retry (FR-ONB-8..12) | HR | 2.3, 3.4 (a fake of the EA route is enough to begin), 0.4 | Not started |

## Wave 3 — The access leg (EA); each deploy separate, consumers first
| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 3.1 | Migration: `employment_links` and assignment `source` | EA | CM migration order | Not started |
| 3.2 | Union-of-active-windows in the active-membership resolution, tests at both boundaries, gaps and overlaps. **Behavioural only: `GET /me` keeps exactly the same fields, only the set of memberships it lists changes, so no consumer needs to declare anything new (strict-DTO rule).** The HIGH review includes a before-and-after `/me` fixture for a rehired person with overlapping contracts | EA | 3.1; **HIGH review (CM), own deploy** | Not started |
| 3.3 | Position mapping table and validation; `STAFF` added to EA's role enum and emitted | EA | 0.5; **1.3 verified live (GL first, EA last)**; HR's position vocabulary | Not started |
| 3.4 | HR-only internal route group `PUT`/`DELETE /api/internal/tenants/{t}/employments/{id}` (service principal only, 503 when unset), idempotent on `employmentId` + `version` | EA | 3.1, 3.3; HR (contract); CM (audience already set live) | Not started |
| 3.5 | ER gateway with a fake and a mock-engine test; pass ER's tokens through literally. Tested against ER's fake until 4.1 is live; the gateway is switched on only after ER's deploy (consumer before producer) | EA | 4.1 live for go-live (not for development); ER pinned shapes | Not started |
| 3.6 | Offboarding of a Membership with no employment link (FR-ONB-11) reuses the existing revoke; never the Owner Admin | EA | 3.4 | Not started |

## Wave 4 — The school duty (ER)
| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 4.1 | `PUT`/`DELETE /schools/{id}/staff/{email}/employment[/{employmentId}]`, employment-link set, TEACHER-only allowlist. DELETE ends ONE link; the person loses ER access only when no other link is active | ER | ER's own draft; Femi go; **ER's migration (V31 or later) can land only after ER PR #9 (V28-V30, in CM's queue) has merged and deployed**; 0.9 | Not started |
| 4.2 | Refuse-by-default for an existing hand-entered assignment (`existing_unlinked_assignment`) | ER | 0.6; same migration dependency as 4.1 | Not started |
| 4.3 | `GET /schools/{schoolId}/me`: the person's ER roles, server-computed capability codes, employment window and active flag (agreed with WEB, section 6 of ER's draft). EA's `/me` deliberately does not carry ER roles, so WEB gets them here | ER | Femi go; WEB (agreed shape); same migration order | Not started |

## Wave 5 — Showing it to the Owner Admin (EA, then WEB)
| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 5.1 | Approvals Queue gains `HR_ONBOARDING_REQUEST` and `HR_OFFBOARDING_REQUEST` sources | EA | 2.2 (HR list route), 1.2 | Not started |
| 5.2 | One Approvals place in Administration listing onboarding, offboarding and payroll-run approvals, each opening the HR detail screen | WEB | 5.1; HR payroll SPUTO's list and approve routes (FR-PA); OI-7 | Not started |
| 5.3 | HR screens: Add a person, Offboard, My requests, Approve and Reject with reasons, per-leg status and Retry | WEB | 2.2, 2.3, 2.4; HR | Not started |
| 5.4 | Role-based visibility (a teacher sees no Administration or Finance); `STAFF` label; hide Dashboard and Approvals for non-owners | WEB | 1.3, 1.5, 1.2, **4.3** (without it WEB cannot know a teacher's ER role) | Not started |
| 5.5 | Tell the Owner Admin something awaits approval (OI-7) | WEB, EA | 5.1; communication centre contract | Not started |

## Wave 6 — Release and verification (CM)
| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 6.1 | Sequence the deploys, consumers before producers: GL role value; ER (PR #9 migrations, then 4.1-4.3) before EA's ER gateway goes live; HR; EA legs (one deploy per auth change); WEB last for anything that exposes a screen | CM | all | Not started |
| 6.2 | HIGH review of each leg that changes who can do what: delegated trigger, Owner Admin final approval, `STAFF` role, validity window, `ea-provisioning` reuse | CM | 1.1, 2.3, 3.2, 3.3, 3.4 | Not started |
| 6.3 | Wiring: HR service audience (already set live), any new env var for the HR to EA call, secrets | CM | 3.4, 2.4 | Not started |
| 6.4 | Personal-data handling questions (OI-10), recorded now, answered at the live switch | CM, Femi | 0.8 | Not started |
| 6.5 | End-to-end check on a throwaway tenant: delegate raises, owner approves, access appears, owner offboards, access ends; plus a rehire and a rejected request | EA, HR, WEB, CM | all | Not started |
