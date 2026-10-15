# Education Runtime: assessment cycle build spec (A1 to A5)

**Status:** design only, for Femi's approval, 2026-10-16. Nothing in this document is built, and nothing here is built before the Playbook is approved. Author: +ER Education. Reviewer: CM (every item that touches an access gate, below).
**Parent:** `ER_Playbook_4_Tasks_And_Order.md` section 1, tasks A1 to A5 (requirements PL-ASM-4 to PL-ASM-9, use cases UC-E5, UC-E6, UC-E16).
**Method:** every statement about the current code was read at Education Runtime master `e6f7661` (deployed as ER :99). Where something is an assumption or a recommendation, it says so.

---

## 1. What is already built (checked in code, not remembered)

| Piece | State | Where |
|---|---|---|
| Grading scales, score structures (components, weights summing to 100, absent and excused rules, `positionsEnabled`) | built | `domain/assessment/AssessmentSetup.kt`, `AssessmentSetupService` |
| Subject offerings (class section x subject x term, teachers, deadline) with status `OPEN, SUBMITTED, RETURNED, APPROVED` | built | `domain/assessment/SubjectOffering.kt` |
| Mark entry per cell with version compare-and-swap, append-only history, claim-first idempotency (`mark:<opId>`), crash-retry safe (R8) | built | `MarkService`, `MarkStore`, V35, V36 |
| **Per-offering** total out of 100, grade from the scale, class position (competition ranking, tie flag) | built | `ResultComputation` in `domain/assessment/Marks.kt` |
| **Submit** (OPEN or RETURNED to SUBMITTED, with a gaps check under the offering lock) | built | `POST .../offerings/{id}/submit`, `MarkService.submit` |
| Roster view with live totals | built | `GET .../offerings/{id}/roster` |

## 2. What is missing (the findings that shape this spec)

1. **Nothing can ever leave `SUBMITTED`.** `APPROVED` and `RETURNED` exist in the enum, but no service, store or route moves an offering into either. `grep` for every use of `OfferingStatus.APPROVED`, `OfferingStatus.RETURNED` and `.transition(` finds only the submit path. So a submitted offering is locked for good: marks are refused (`acceptsMarks` is false) and there is no way back. This is test data today, but it is the first thing A1 must fix.
2. **The lock text is wrong against a decision.** `SubjectOffering.lockReason` says "Submitted to the form master" and "Approved by the form master". Femi decided (2026-10-10) that the form master is **not** the default approver of test marks. The wording must follow the configured chain (D3).
3. **A2 is half done.** Per-offering totals and positions exist. Missing: a student's whole-term picture across subjects (sum, average, class position across all subjects), and per-subject highest, lowest and average for the class.
4. **`positionsEnabled` defaults to `true`** in the structure request (`AssessmentSetupRoutes.kt`, `val positionsEnabled: Boolean = true`). Decision **D11** (proposed) is positions **off** by default. Changing the default affects only structures created afterwards; existing ones keep their stored value.
5. **Two assessment models exist side by side.** The older `AssessmentService` (a free-text grade string per student and term, `publish` raising `AssessmentCompleted` through the outbox, `releasedToParentGateway` read by the Parent Gateway) and the S1 model (offerings and marks). The Parent Gateway still reads only the older one. How approved S1 results reach guardians is a decision (O-1 below).
6. **Concepts the playbook assumes that do not exist yet:** a department (so "head of department" is only a role, not scoped to a subject area), a form master (no assignment of a person to a class section, which E4 and A3 both need), a level ladder (what class follows JSS1), and any PDF library (`build.gradle.kts` has none).

---

## 3. A1: approval chain and locking (PL-ASM-4, needs D3, F7, F9)

### 3.1 Behaviour

- **Chain.** Each school configures an ordered list of approver roles, for example `[HOD, HEAD_TEACHER]`. A chain of one or two steps is expected; the cap is three. **Default chain: `[HOD, HEAD_TEACHER]`** (the D3 recommendation, still awaiting Femi).
- **Offering lifecycle.**
  `OPEN` -> submit -> `SUBMITTED` (awaiting step 1) -> approve -> awaiting step 2 -> ... -> approve at the last step -> `APPROVED` (**locked**).
  At any step an approver may **return** with a mandatory comment: `RETURNED` (marks open again), and the next submit starts again at step 1. Only that one offering is reopened.
- **Locked means locked.** In `APPROVED`, mark writes are refused as today (`acceptsMarks` is false). No new code is needed for the refusal; the existing lock order (offering first, then cell) already makes a write racing an approval safe.
- **Changing a mark after approval** is a **change request**, not a reopen: a teacher (or the approver) states offering, student, component, new value or code, and a **reason**. The last-step approver approves or rejects it. On approval the system writes the mark through the normal mark path (history keeps the original value; the actor is the requester, the approver is recorded on the request; the request id is the operation id so a retry writes once). A change to a mark already **published on a report card** also flags the card for re-issue (A4).
- **Separation of duties.** A person cannot approve an offering they teach, and cannot approve their own change request. If the chain has no eligible person left at a step (for example the only head teacher teaches the offering), the approval is refused with a plain message and the school must name another approver; **the system never self-approves**. Open point O-2 asks Femi whether the Owner (Proprietor) should be the fallback.
- **Who may approve.** A step names a role. In version one **any holder of that role at the school** may act (department scoping needs a department entity that does not exist; that is a later refinement, not guessed now).
- **Messages never say "contact support".** A stuck offering is recovered by the school's own head teacher (return it), which is the landlord principle applied: no Prodeo route touches a school's marks.

### 3.2 Access gate (CM reviews at HIGH)

New capability **approve results**, held by the roles named in the school's chain. It is **purely additive**: nobody loses anything, and no existing deny changes. Per the deferred-enforcement rule:

- Flag `ER_ENFORCE_RESULT_APPROVAL`, default **log**. It controls the **consumer**, not the routes: with the flag in log mode, publishing a report card (A4) from an offering that is not `APPROVED` is allowed and writes a rate-limited `WOULD REFUSE offering_not_approved offering=<id>` line; in enforce mode it is refused naming the offering (UC-E6 alternate).
- The approve and return routes themselves exist from the first release (they only add a way out of `SUBMITTED`) and are gated by the chain roles from day one.

### 3.3 Data (migrations provisional; numbers claimed on `Infrastructure/COORDINATION.md` row at build time, next free after V37)

- `approval_chains(school_id, step, role)` primary key `(school_id, step)`; absent rows mean the default chain. Per-school, CHECK `step BETWEEN 1 AND 3`, role must be one of the assignable roles.
- `subject_offerings` gains `approval_step INT NOT NULL DEFAULT 0` (0 when not awaiting approval) and `returned_comment TEXT NULL`.
- `offering_approvals(id, school_id, offering_id, step, decision [APPROVED|RETURNED], actor, comment, at, op_id)` **append-only** (same DB triggers as `mark_history`: no update, no delete, no truncate).
- `mark_change_requests(id, school_id, offering_id, student_id, component, new_value, new_code, reason, requested_by, requested_at, status [PENDING|APPROVED|REJECTED], decided_by, decided_at, decision_comment, op_id)`.

### 3.4 Routes (all `PUT`/`POST`/`GET` under `/schools/{schoolId}/assessment/...`, strict DTOs, no `ignoreUnknownKeys`)

| Route | Who | Does |
|---|---|---|
| `PUT approval-chain` / `GET approval-chain` | school admin writes, teaching roles read | set or read the chain |
| `POST offerings/{id}/approve` | the current step's role | advance one step or lock; body `{opId, comment?}` |
| `POST offerings/{id}/return` | the current step's role | reopen; body `{opId, comment}` (comment required) |
| `GET approvals/pending` | approver roles | inbox: offerings awaiting my step (paged) |
| `POST offerings/{id}/change-requests` | teacher of the offering | ask to change a locked mark |
| `POST change-requests/{id}/decide` | last-step role | approve or reject |
| `GET offerings/{id}/approvals` | chain roles and the offering's teachers | the trail |

### 3.5 Safety properties (each gets a real-Postgres test, per the retry-safety audit)

- Approve and return run under the existing offering lock and a compare-and-swap on `(status, approval_step)`. Two approvers racing the same step: one wins, the other gets `409 offering_changed`. Approve racing return: same.
- Claim-first idempotency on `opId` through `sync_push_ops` (key `approval:<opId>`): a retry returns the first outcome and writes one approval row. A refusal releases the claim.
- A mark write racing an approve: the mark either lands before the approval commits or is refused as locked, never after.
- A change request applied twice (retry) writes the mark once.

### 3.6 Tests first (declared equals executed)

Unit: chain validation, step advance, return reopens, self-approval refused, no-eligible-approver refused, lock text follows the chain, flag log versus enforce. Integration (real Postgres): the four races above, trail append-only (update and delete refused by trigger), idempotent replay of approve, return and change request, migration applies on a database with existing SUBMITTED offerings (they are treated as awaiting step 1).

### 3.7 Tasks and size

| Task | Content | Size |
|---|---|---|
| A1.1 | chain table, default chain, routes for the chain, validation | S |
| A1.2 | approve and return, state machine, trail, locks and idempotency | M |
| A1.3 | change requests after lock | M |
| A1.4 | `ER_ENFORCE_RESULT_APPROVAL` flag plumbing and `WOULD REFUSE` log line (consumed by A4) | S |
| A1.5 | fix `lockReason` wording; set `positionsEnabled` default per D11 | S |

---

## 4. A2: totals, averages, positions, highest, lowest (PL-ASM-5, needs A1, D11)

### 4.1 Behaviour

For one class section and term, over its **approved** offerings only (an unapproved offering is shown as "awaiting approval" and excluded, never guessed):

- **Per student:** total of subject totals, average, number of subjects counted, class position across the whole term (competition ranking, tie flag), subject grades from the scale.
- **Per subject:** highest, lowest, class average (over students who have a total).
- **Completeness rule (no guessing):** a student's overall position is computed only if they have a total in **every** approved offering of the class; otherwise position is empty with the reason `incomplete`, and the average is over the subjects they do have, labelled as such. This matches the existing per-offering rule that a missing component keeps the total empty.
- **Positions are a school setting.** Off unless the score structure (which is already per level and term) says on, per D11. When off, positions are omitted from every output including A4.
- **Computed on read for working views; fixed at publication.** The numbers shown in the approvals and results screens are computed from current approved marks. The report card (A4) uses a **snapshot** taken at publication so a later correction never silently changes a printed card.

### 4.2 Open modelling point (flagged, not decided)

There is no student-to-offering enrolment: every offering applies to the **whole class section** roster (`studentsInSection`). Optional subjects (electives, a student taking French or Yoruba but not both) cannot be expressed. Version one assumes whole-section offerings and says so on the screen. Electives are a recorded gap (O-3), needed before a school with options can use the term view.

### 4.3 Shape

Pure functions in the domain layer (`TermResultComputation`), unit-testable without a database. One read route: `GET /schools/{schoolId}/assessment/classes/{classSectionId}/terms/{term}/results` (paged, strict DTO, a contract fixture in `fish-contracts` with WEB as consumer). Readable by the class's oversight roles and teachers; guardians see only their own child through the Parent Gateway (A4/P1), never this route.

### 4.4 Tests

Ranking with ties and gaps (1, 2, 2, 4), incomplete student, a class with one offering unapproved, positions off, rounding half-up to two decimals matching the per-offering rule, empty class, one student only.

### 4.5 Size: M. No migration (pure computation over existing tables).

---

## 5. A3: affective and psychomotor ratings and comments (PL-ASM-6, needs A1)

- **Configuration per school:** a rating scale (for example 1 to 5 with labels) and a list of traits, each tagged `AFFECTIVE` or `PSYCHOMOTOR` (punctuality, neatness, honesty; handwriting, sports). A starter set is offered but editable.
- **Per student per term:** one rating per trait; a **form master comment** and a **head teacher comment**.
- **Same safety as marks:** version compare-and-swap per row, append-only history, claim-first idempotency, offline-capable later (it rides the same sync ledger).
- **Who writes:** the form master for ratings and their comment; the head teacher for theirs. **Dependency found:** there is no form-master assignment in the code (no person is tied to a class section). Version one therefore uses a small explicit assignment `class_section_form_master(school_id, class_section_id, subject_id)`, set by the school admin, which is also the missing half of E4 (form-master approval of the register). This is a **new access fact**, so CM reviews it, and enforcement of "only the form master may write ratings" stays behind a flag defaulting to log, as above; until the flag is enforced any teaching role of the school may write (today's behaviour for marks).
- **Lock:** ratings and comments freeze when the term's report cards are published; a later change is a change request like A1.3.
- **Tables (provisional):** `rating_scales`, `rating_traits`, `student_term_ratings`, `student_term_comments`, `rating_history` (append-only), `class_section_form_master`.
- **Size: S to M.**

---

## 6. A4: report cards, broadsheets, batch (PL-ASM-7, PL-ASM-8, needs A2, A3)

- **Template, not free-form.** A card template is a **structured configuration** (which sections appear: marks table, positions, attendance summary, ratings, comments, next-term date, an optional fee line per D8) with the school's name, crest and wording fields. **No user-supplied HTML** (it would be an injection route into the PDF). The fee line stays off by default and is never a withholding mechanism (D8 not decided).
- **Publication.** The head teacher publishes a class's term. It is refused (enforce mode) or logged (log mode) when any offering is not `APPROVED`. Publishing writes an **immutable snapshot** (`published_results`) so the card is reproducible exactly as issued; a later authorised correction creates a new issue number, never edits the old one. Guardians are told through the notifications port when it exists (D2; not part of this spec).
- **Guardian access** is read-only through the existing Parent Gateway with custody and restriction enforcement (P1); a guardian never sees another child or class results.
- **PDF.** The project has **no PDF library**. Recommendation (to be confirmed in a short spike before approval of A4): a pure-JVM HTML-to-PDF library, rendering from the structured template into an internal fixed layout, so nothing native is needed on the container. A wrong choice here is cheap to swap because rendering sits behind a port.
- **Broadsheet.** One sheet per arm and level: students down, subjects across, totals, averages, positions if on, highest, lowest and average per subject, generated from the same snapshot.
- **Batch generation in the background** needs somewhere to keep the finished PDFs. That is object storage and a worker, which is infrastructure (CM). Recommendation: version one generates **on demand** (one student, or one class streamed) with no storage; the batch job and its storage come as a separate task once CM confirms a bucket (O-4). This keeps A4 shippable without an infrastructure dependency.
- **Size: L** (template config, snapshot, PDF, broadsheet, WEB screens). WEB builds the preview and the print layout; ER supplies the structured data and the PDF.

---

## 7. A5: promotion, repeat, probation (PL-ASM-9, PL-IMP-1, needs A2, D11)

- **Criteria, configured per school and level** (version one): minimum overall average; minimum number of subjects passed; named compulsory subjects that must be passed (for example English and Mathematics); optional minimum attendance. Outcome per student: `PROMOTE`, `REPEAT` or `PROBATION` (probation = promoted on condition, a flag, with a note).
- **Run.** The head teacher starts a promotion run for a session. The system **proposes** an outcome per student from the criteria (using A2 results). Nothing moves yet.
- **Preview.** A reviewable list with the proposed destination class for each student; the head teacher may **override** any student with a reason; the preview can be thrown away.
- **Approve and apply.** The head teacher approves; applying moves each student with the same single-transaction `transferStudentClass` already hardened in the retry-safety audit (R2). The run records each student's previous class so the whole run can be **reversed** while no marks or attendance have yet been recorded in the new classes. A run is idempotent on its run id (a retry applies once) and locked at run level so two applies cannot interleave.
- **Dependency found:** there is **no level ladder** (which class follows JSS1, what the final level graduates to). A small `level_progression(school_id, from_level, to_level)` is configured by the school admin; the last level maps to `GRADUATE`. Which arm a student lands in (same arm letter, or bulk reassignment) is a school decision at preview time.
- **Guardian notice** uses the notifications port (D2) and is outside this spec; the run records "notice pending".
- **Access gate:** `ER_ENFORCE_PROMOTION_APPROVAL` (E6), default log; approval by the head teacher.
- **Tables (provisional):** `promotion_criteria`, `level_progression`, `promotion_runs`, `promotion_proposals` (with previous and proposed class, override reason, status), `promotion_run_history` (append-only).
- **Size: M.**

---

## 8. Order, dependencies and what can start first

`A1.1 -> A1.2 -> A1.3 -> (A1.4, A1.5)`, then `A2`; `A3` can run beside `A2` once the form-master assignment is agreed; then `A4`; `A5` after `A2` and before or beside `A4`. WEB is briefed before each response shape reaches a screen: an **approvals inbox** (A1), a **class results grid** (A2), a **ratings and comments entry** (A3), a **report-card preview and print** and **broadsheet** (A4), and a **promotion preview** (A5). Each new response shape gets a fixture in `fish-contracts` and a strict consumer decode before WEB builds against it.

**Release discipline for every task:** its own branch off master, built in my own checkout, tests first, real Postgres for the races and migrations, declared tests equal executed, handed to CM as branch and tip. CM reviews A1, A3 (form master) and A5 as access-gate work at HIGH; the others at normal effort. Nothing pushes or deploys from here.

## 9. Open points for Femi (each with a recommendation)

| # | Point | Recommendation |
|---|---|---|
| **D3** | Who approves test marks (already open) | head of department, then head teacher, configurable per school |
| **D11** | Positions and promotion defaults (already open) | positions **off** by default, school-configurable; promotion by average plus compulsory subjects |
| O-1 | How approved S1 results reach guardians, given the Parent Gateway reads only the older grade-string model | the Parent Gateway reads the **published snapshot** (A4); the older grade-string path is retired once A4 ships. Until then both exist |
| O-2 | If the only eligible approver teaches the offering, who may approve | the school names an alternate approver; the Proprietor is the last resort and the approval is recorded as such (no silent self-approval) |
| O-3 | Optional subjects (electives) | out of version one; a student-to-offering enrolment is added when the first school with options needs it |
| O-4 | Batch report-card generation needs storage | on-demand first; ask CM for a bucket before the batch job |
| O-5 | Department entity (so a head of department approves their own subject area only) | role-level for now; add departments when staff structure (S-series) lands |

## 10. Checked against today's decisions (2026-10-15)

- **Prodeo is a landlord:** no support route, no Prodeo operator action, and no wording that sends a school to "support" for its own data; recovery is tenant-side (the school's head teacher returns the offering).
- **Deferred enforcement:** every new gate is behind a flag defaulting to log, with a rate-limited `WOULD REFUSE` line first; nothing here denies anything that works today.
- **RBAC freeze:** the only access additions are new capabilities (approve results, form-master assignment); no existing deny is changed. CM reviews them.
- **Ledger:** nothing in this cycle posts to the ledger or touches SOP. The fee line on a card (if ever turned on) is read through SOP, never computed here.
- **Vocabulary:** screens use school terms ("Results", "Report card", "Promotion"), through WEB.
