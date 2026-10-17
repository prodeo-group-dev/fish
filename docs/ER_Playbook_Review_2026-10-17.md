# ER Playbook and test plans reviewed against the landlord principle and the 2026-10-15/16 decisions (+ER Education, 2026-10-17)

**Scope (CM's brief):** review the Education Runtime Playbook (parts 1 to 4), the assessment build spec (A1 to A5), the school vocabulary, the operator sheet and the ER test plans against the landlord principle and the Decisions_Log of 2026-10-15 and 2026-10-16, plus the two answers relayed to this session (D3, D11). **Docs only: no ER code, no migration, no flag flipped.** Method: I read every document named below in full (not a keyword scan) and re-checked the assessment code claims against ER master `83b94d6` (ER :100).

**Evidence limits, stated plainly.** (1) The Decisions_Log in git (`docs/Decisions_Log.md`, 98 lines) has **no line for D3 or D11**; I took them from the brief I was given and marked them "relayed to the ER session 2026-10-17, Decisions_Log line owed". (2) The test plans live only in the untracked `docs/reports/Playbooks/TestPlans/` tree on CM's disk, not in git, so I list their stale rows here for CM to fix and did not edit them. (3) I did not re-verify HR's, EA's or SOP's behaviour; where the Playbook relies on them I mirrored their decided text and said so.

## 1. What the decisions changed in the ER documents

| Decision | What it makes stale | Where I changed it |
|---|---|---|
| **Online-only banking-style app for every role** (2026-10-15; supersedes the 2026-10-13 offline school app, D1 "Both", server gaps S1 to S6) | Local-first principle; offline requirements; PL-ATT-2; PL-FEE-11 and X5 (offline cash receipts); F11 and F12; D1 and D4; UC-E4's "no connection" register; every "Offline:" line in the use cases; acceptance criteria 1 and 3; offline NFR; the whole per-entity offline table; PL-SET-7 remote wipe; PL-DOC-4, PL-SAF-4, PL-SAF-6 | Parts 1 to 4 (superseded or reworded, history kept with strikethrough or "for the record"); banners on `ER_Offline_Mobile_App_Design.md`, `Education_Runtime_Local_First_Sync_Design.md`, `Local_First_Sync_Build_Plan.md`, and on `Education_Runtime_MVP_Definition.md` section 3; new correction C14; replacement connectivity requirements (retry-safe calls, no persistence, token and lock times, `Cache-Control: no-store`, PDF download audited) |
| **D3: test marks approved by head of department, then head teacher, configurable per school** | "approver is open" in Part 1 table and decision rows, C4, E5, the RBAC matrix, A1's dependency on D3, the build spec's "still awaiting Femi" | Parts 1, 2, 3, 4 and the build spec. **A1 no longer depends on F7** (the form master is not an approver; F7 is needed by A3, T3, E4) |
| **D11: positions ON by default, school-configurable; promotion defaults to overall average plus compulsory subjects** | Part 1 and 4 recommended "off"; PL-ASM-5; build spec found `positionsEnabled` defaulting to `true` as a defect to flip | **No code change is needed**: the structure request already defaults to `true` (re-read at `AssessmentSetupRoutes.kt:117`). Build task A1.5's second half is dropped; A5's default criteria set |
| **Prodeo is a landlord** (2026-10-15) | The operator sheet told the reader that "an engineer has to correct" a school's wrong admissions step, that the platform "adds an admin by hand", and to "collect and escalate" a grade dispute. All imply Prodeo edits or reads a school's records | `ER_School_Playbook_Draft.md` (operator sheet) reworded; Part 1 principle 8 added. The build spec was already clean (head teacher returns an offering) |
| **Preparation is not audit; the Owner is the final authority; Femi decides parking and is the tax professional** (2026-10-13 and 2026-10-16) | D9, D8, D17 and acceptance criterion 5 said "needs counsel / an accountant to be named" as if ER gated on an outside adviser | Reworded to "Femi decides, and may take counsel"; Part 1 principle 9; build spec O-2 now rests on the final-authority rule |
| **Payroll split, Personnel, Q3, PAYROLL backfill** (2026-10-15/16) | E1's default holders ("Proprietor and HR officer set basis; accountant or bursar run") contradict Q3 (Owner Admin only changes pay basis, rate, frequency, bank) and the PAYROLL backfill (Owner Admins and Accountants only) | E1 and PL-STF-9 mirrored and marked owned by HR and EA; Part 4 S4 now says ER has no work beyond displaying the division |
| **Education flag is the definition of a school** (2026-10-13) | F2 and E12 kept the pre-switch "data fix: list real school Companies" as a gate | Retired as a gate in Parts 2 and 4 |
| **IM owns the VAT category, per jurisdiction and date** (2026-10-11/15) | Part 4 M1 had ER build its own effective-dated category list, the exact duplication M1 itself warned against | M1 narrowed to an interim explicit category set by a person, refused when absent, replaced by IM's lookup |
| **Personnel and the school words** (2026-10-12/13/15) | "Staff and roles" still in Part 1, Part 3 and Part 4 | Replaced by "Roles and access" |

## 2. Still stale outside what I may edit (for CM)

1. **`docs/Live_Switch_Checklist.md` section A is "generated from Part 2 section 1.1"** and now disagrees: E1 holders (above); E2 names the flag `ER_ENFORCE_SAFEGUARDING_ADMIN_DENY` while Part 2 calls it `ER_ENFORCE_SAFEGUARDING_BREAK_GLASS`; E5 and E6 conditions mention D3 and D11 as undecided; E12 still names the data fix. Please regenerate it from the revised Part 2.
2. **Decisions_Log lines owed** for D3 and D11 (proposed wording in section 4). Per the log's own rule the session Femi told appends them; I was told second-hand, so I leave the append to CM.
3. **Test plans** (CM's, extracted automatically from the old text). Stale rows:
   - `ER_Playbook_SPUTO_Test_Plan.md`: EP1S-D1, D3, D4, D11 (decided or moot); EP2S-C4 (D3 decided); EP2S-PL-ATT-2, PL-ASM-3, PL-ASM-4, PL-ASM-5, PL-ASM-9, PL-FEE-11, PL-DOC-4, PL-SAF-4, PL-SAF-6, PL-SET-7; EP3UC-UC-E4 (title no longer says offline), UC-E5, UC-E8, UC-E15; EP4TAO-F11, F12, X5 (superseded or dropped), A1 (dependencies changed), M1 (narrowed), S4 (owned by HR and EA), D1, D3, D4, D11, D17; the E1, E5, E6 and E12 rows; acceptance criteria 1, 3 and 5 in section 9.
   - `ER_Local_First_Sync_Test_Plan.md`: **the whole plan** (13 rows) tests a superseded design.
   - `ER_The_Principal_Test_Plan.md`: TPB-W3, TPB-BK-ATT-3, TPB-BK-NFR-2, TPB-BK-NFR-8, TPB-BK-DOC-8, TPB-BK-FIN-10, TPB-BK-PLT-6 (offline or local-first rows from the old backlog).
   - `ER_School_Playbook_Test_Plan.md`: ESPD-NB6 ("offline phone app for teachers" is dropped); rows built on the operator-sheet answers I reworded.
   - `ER_School_Vocabulary_For_WEB_Test_Plan.md`: add rows for the new section 8 (8.1 words to change, 8.2 words that stay).
   - **Floor mapping:** the plans take "In floor" from `Education_Runtime_MVP_Definition.md`, whose section 3 made offline-first a Floor prerequisite. That is superseded (banner added), so every offline row there is no longer Floor.
   - `Retest_Plan_2026-10-15` and the TR-8 wording checks: the expected words are now section 8.1 and 8.2 of the vocabulary; "Business Owner", "Pay runs", "Salary advances", "Run payroll", "Suppliers", "Purchases", "Cash flow", "Trial balance" and similar are **kept on purpose** (8.2), so the tester should stop reporting them as leftovers.
4. **Items I did not touch because they are older source documents**: `The_Principal_Backlog.md` and `The_Principal_SRS.md` (offline epics), `ER_Education_Specialty_Scope.md` (offline sync as a "generic capability"), `EduSys_Separate_App_SPUTO.md` and `FiSH-ER-...-v0.1.md` (the spec, intentionally not rewritten). Part 2 corrections C14 records the supersession; if CM wants banners on those too, say so.
5. **The SOP-through-ER and fixtures work shows as done in `ER :100`** (idempotency key, contract fixtures, the SOP customer-create decode tests); Part 4 F1 and F4 now carry that status. I did not claim anything about F1's "tolerant retry" part because I did not re-check it.

## 3. Open questions this review raised (each with a recommendation; none is decided)

| # | Question | Recommendation | Owner to confirm first |
|---|---|---|---|
| D24 | Do ER school duties (the closed role list the school admin grants) fall under the Business-Owner-approves access rule (Personnel P8)? | P8 covers EA's invite, roles, modules and remove; ER duties follow when the flow exists; until then delegates act directly (Femi 2026-10-15, P7) | EA, then Femi |
| D25 | Does "email first, push later" (decided for the app's notifications) also govern guardian messages, where the spec assumes SMS and the SMS account is blocked? | Email adapter first in the notifications port, SMS when the account exists, since many guardians may lack email | CM, then Femi |
| D26 | With no offline entry, what does a school do on a no-signal day? Is a paper fallback the accepted answer, and is even a short outbox allowed (CM's reading of 2026-10-15 says none; Femi has not confirmed)? | Paper fallback; pick a pilot school with workable connectivity; ask Femi only if a pilot school cannot | CM, then Femi |
| W1 | In a school is the HR area "Personnel" or "Staff"? | Personnel for the area, "Staff members" for the rows | Femi (small) |
| Chart names | Should a school get its own seeded chart names ("Fee income", "Stores", "Proprietor's capital") instead of a display relabel? | GL seeds a school chart template on Company creation; no display relabel; leave existing test Companies | GL, then Femi |
| Web caching | Does the no-persistence rule also limit PWA caching in browsers? (open in the Decisions_Log already) | Follow the same rule for authenticated data, keep the static shell | WEB, Femi |

Also noticed and recorded, not solved: the operator sheet's first-admin sentences describe EA's platform provisioning grant (a landlord handing over the keys at onboarding). I kept the fact and added "only for the Business Owner's own email"; **CM or EA should confirm that is accurate** before the sheet is loaded into Omniview.

## 4. Decisions_Log lines owed (proposed wording, for CM to append or correct)

- `2026-10-17 | ER Playbook D3 decided: test marks are approved by the head of department, then the head teacher, configurable per school; the form master approves attendance, not test marks | Femi (relayed to +ER) | ER (A1 unblocked on this point), CM`
- `2026-10-17 | ER Playbook D11 decided: positions and rankings stay ON by default and are school-configurable; promotion defaults to the overall average plus the compulsory subjects (reverses ER's earlier recommendation of off) | Femi (relayed to +ER) | ER (A2, A5)`

## 5. What is deliberately not done, and why

- **A1 has not started.** Its only remaining gate is Femi's approval of the Playbook (CM asks him). The build spec is current. The four ER code findings are carried into A1: (1) nothing can ever leave SUBMITTED (APPROVED and RETURNED are unreachable), (2) the lock text says "form master" against D3, (3) the whole-term view is not built, (4) two assessment models exist side by side and the Parent Gateway reads only the older one (O-1). The old finding 4 (the `positionsEnabled` default) is withdrawn.
- **`ER_SCHOOL_ROW_MODE` and `ER_DPID_BINDING_MODE` stay in log mode.** The last 24 hours had 38 log events, so zero WOULD REFUSE lines proves nothing; the flip waits for Femi's readout of `docs/reports/ER_Enforcement_Readiness_Query.sql`.
- **Two cleared, additive, code items are not built** because this session's instruction is docs only until the Playbook is approved: T-ER7 (`GET /schools/{id}/me`) and the `Cache-Control: no-store, private` plugin (both in Pending_For_Sessions). I need a go from CM to build either before approval.
- **Nothing pushed, merged or deployed** by this session.
