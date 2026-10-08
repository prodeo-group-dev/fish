# Assessment cycle, wave S1: domain model and API contract (DRAFT for WEB and Femi)

**Status: DRAFT 2, 2026-10-07 (revised after WEB's review; see section 11). Design only; nothing built, nothing frozen, nothing started until Femi says go.** Written by the Education Runtime (EduSys) against WEB's UX input (`WEB_Education_Assessment_UX_Input_S1_S2.md`, branch `docs/edu-assessment-ux-input`) and the specialty scope (`ER_Education_Specialty_Scope.md`). Requirement ids are the spec's (ER-ASM-001..011). Tags: **[code]** read from `fish-education-runtime` on 2026-10-07; **[WEB]** from WEB's input; **[school]** a rule only a real school can settle (a placeholder default is given, marked, never presented as fact). **Neither this contract nor WEB's input has been validated with a teacher, form master or principal.**

## 1. Where we start **[code]**

Three write routes and no read route: `POST .../assessments/structures` (a free-text name per term and subject), `POST .../assessments/grades` (**one text value** per student, assessment and term) and `POST .../assessments/publish` (releases grades to the parent gateway and emits `AssessmentCompleted`). No scores, components, weights, scales, positions, ratings, remarks, approval, locking, report cards, broadsheets or promotion. Production holds only legacy test data and no screen uses these routes, so S1 **replaces** them (new tables and routes; the three old routes are removed after S1, not kept alive).

## 2. Design rules (apply to every route below)

1. **The server computes; WEB never does** (totals, averages, grades, positions, verdicts), each with an `asOf` time. **[WEB]**
2. **Small, independent, repeatable writes.** One mark per request. Every write carries a client-chosen `opId`; a repeat of the same `opId` with the same content returns the original result and changes nothing; the same `opId` with different content is `409 op_id_reused`. (This is the claim-first ledger already built for sync, `SyncPushLedger`, reused, not rebuilt.) **[WEB, code]**
3. **Optimistic concurrency on a mark:** a write may carry the `version` the client last saw; a stale version is `409 stale_mark` with the current value, never a silent overwrite.
4. **Every refusal is a stable machine code plus a plain message** (section 6), so WEB can show the right words.
4a. **Every resource that has actions returns server-computed `allowedActions`** (state, capability and deadline already taken into account), so WEB never infers "may I edit?" from several fields. **[WEB]**
4b. **Positions are numbers**, never formatted strings: `{position, tied}`; WEB formats the ordinal. **Lists** default to 50 per page, maximum 100, return a `cursor` and a `total`; a bad `cursor` or `limit` is `invalid_cursor` / `invalid_limit`. **[WEB]**
5. **Capability codes, not role lists** (from `GET /schools/{id}/me`, section 7). A person without the capability gets `403`, and the `/me` list is how WEB knows not to show the action at all.
6. **Children's data:** no mark appears in any notification text; a guardian sees nothing until release.
7. New routes use **JSON request and response bodies** (every other write route in this service takes pipe-delimited text; the assessment payloads are structured enough that text would be fragile). **Flagged as a convention change for CM's review.**

## 3. Domain model

| Aggregate | What it holds | Notes |
|---|---|---|
| **GradingScale** | School-level, versioned: ordered bands (`minScore`, `maxScore`, `grade`, `remark`) | Per level and country (ER-ASM-002). Seeded by the school; **no built-in country scale**, since the real scales are a **[school]** input. |
| **ScoreStructure** | Per level and term: components (`code`, `name`, `maximum`, `weight`), which one is the exam, `positionsEnabled`, `decimalsAllowed`, `absentRule`, `excusedRule`, the `gradingScaleId` | ER-ASM-001. **Immutable once any mark exists; a change is a new version** that applies from the next term. Weights must sum to 100 (checked on save). |
| **SubjectOffering** | A class section × subject × term: the teacher(s), the structure used, `deadline`, `status` | The unit a teacher enters scores for and a form master approves. Statuses: `OPEN`, `SUBMITTED`, `RETURNED`, `APPROVED`. |
| **Mark** | `(offering, student, component)` → a number **or** a code `ABSENT` / `EXCUSED`; `state` `SAVED` / `LOCKED`; `version`; who and when | "Not entered" is the *absence of a mark*, never a blank value (so it is never confused with "did not sit"). **[WEB]** |
| **Computed result** | Per student per subject: total, grade, subject position; per student: term total, average, class position; `asOf` | Recomputed when marks change; **frozen at approval**; the frozen copy is what a release publishes. |
| **RatingScale / StudentRating** | The allowed values per affective or psychomotor item, and a student's rating | A fixed set per item (tapped, not typed) (ER-ASM-006). |
| **Remark** | Form master's and principal's remark per student per term | A character limit, returned in the response. |
| **ClassResultState** | Per class and term: `OPEN`, `READY`, `APPROVED`, `RELEASED`; who and when; the **blockers** list | Approval of the class is possible only when every offering is `APPROVED`. |
| **CorrectionRequest** | After a lock or release: student, component, new value, reason, requester, approver, status | Never a silent edit. **[WEB]** |
| **PromotionVerdict** (S2) | Verdict, reason and any override with its mandatory reason and author | Sketched here; contract in S2. |

**New data the model needs that does not exist today:** a **form master** per class section (ER-CLS-002; today a class section is only a name and a year), a **subject catalogue** (S3 gives it structure; S1 can use the existing `subjectCode` strings), and an **admission number** (S4; until then the roster shows `externalRef`).

## 4. Workflow (state machines)

- **Offering:** `OPEN` → (teacher *submits*) `SUBMITTED` → (form master *approves*) `APPROVED`, or (form master *returns* with a comment) `RETURNED` → (teacher edits, resubmits) `SUBMITTED`. Marks are editable only in `OPEN` and `RETURNED`; `SUBMITTED` and `APPROVED` are read-only (`LOCKED`).
- **Submit** refuses with `gaps_present` and the counts per component unless the structure allows submitting with gaps **[school]** (default: not allowed) and the request says `allowGaps: true`.
- **Class:** `OPEN` → `READY` (every offering approved, ratings and remarks present) → `APPROVED` (form master) → `RELEASED` (principal). A release **freezes** the computed results and makes them visible to guardians.
- **After a lock:** a mark changes only through a `CorrectionRequest` approved by the person who can approve that stage (form master before release; principal after release), recorded with before and after.
- Whether a release can be **undone**, and how long a correction window stays open after release, are **[school]** rules; the contract exposes the rule in the response and never implies one. Default for the draft: not undoable; corrections only by request.

## 5. API (all under `/schools/{schoolId}/assessment`; capability in brackets)

**Set-up** `[MANAGE_ASSESSMENT_SETUP]` (an admin-only set of plain forms; WEB designs them last, after the teacher, form master and principal screens)
- `PUT /grading-scales/{id}`, `GET /grading-scales`
- `PUT /structures/{id}`, `GET /structures?level=&term=` (versioned; `409 structure_in_use` if a mark exists)
- `PUT /offerings/{id}` (assign class, subject, term, teacher, structure, deadline), `GET /offerings` (paged)

**Teacher** `[ENTER_SCORES]`, own offerings only (`403 not_your_offering` otherwise)
- `GET /my-offerings?term=&cursor=&limit=`: each with class, subject, term, `progress` (`entered`, `expected` per component), `deadline`, `status`, `lockReason`
- `GET /offerings/{id}`: the structure (components with `maximum` and `weight`, the scale, `decimalsAllowed`), status, deadline, lock reason, completeness counts
- `GET /offerings/{id}/roster?q=&missing=&cursor=&limit=`: **paged (default 50, maximum 100, with `cursor` and `total`) and searchable server-side**; each row has student id, name, admission number (or `externalRef`), each component's cell `{value|code, state, version}`, and `computed {total, grade, asOf}`
- `PUT /offerings/{id}/marks` body `{opId, studentId, component, value | code | clear: true, version?}` -> the saved cell **and that student's recomputed `computed {total, grade, position, tied, asOf}`**, so the row updates without refetching the roster. `clear: true` returns the cell to **not entered** (the typo case: a mark on a student who did not sit); it follows the same `opId` and `version` rules and is refused when the offering is locked.
- `POST /offerings/{id}/marks:batch` body `{marks: [{opId, studentId, component, value | code | clear, version?}, ...]}` (at most 100) -> a **per-item result** (`saved` with the cell, or the refusal code). For flushing after a dropped connection, and later offline; each item is independent and safe to repeat.
- `POST /offerings/{id}/submit` body `{allowGaps}` -> new status, or `409 gaps_present {counts}`

**Form master** `[APPROVE_RESULTS]`, only for the classes they are form master of
- `GET /my-classes?term=`: the classes where **I am form master**, each with its state, completeness and `allowedActions`, so the screen shows only my classes and never an error. (A principal with `RELEASE_RESULTS` sees every class.)
- `GET /classes/{classId}/overview?term=`: subjects by status with who and when, completeness, `blockers`
- `GET /offerings/{id}/review?sort=outliers`: the class with components, total, grade, position, and an `outlier` flag with its reason (far from class mean, a zero, a missing mark)
- `POST /offerings/{id}/approve`, `POST /offerings/{id}/return` body `{comment}` (mandatory)
- `PUT /classes/{classId}/ratings`, `PUT /classes/{classId}/remarks` (the allowed rating values are returned by `GET /rating-scales`)
- `POST /classes/{classId}/approve` -> `409 not_ready {blockers}` if anything is outstanding

**Principal** `[RELEASE_RESULTS]`
- `GET /release-board?term=`: one row per class with state and blockers
- `POST /classes/{classId}/release` body `{confirm: true}`, response says exactly what became visible to whom (counts); `409 not_ready` otherwise

**Corrections** `[ENTER_SCORES]` to request, `[APPROVE_RESULTS]` / `[RELEASE_RESULTS]` to decide
- `POST /corrections`, `GET /corrections?status=&mine=true`, `POST /corrections/{id}/approve|reject` (reason mandatory on reject). `mine=true` lists a teacher's own requests.

**Print (S2, same contract style):** `GET /students/{id}/report-card?term=&format=pdf`, `POST /classes/{id}/report-cards` (renders the whole class as **one server-side PDF**, returns a download), `GET /classes/{id}/broadsheet?term=&format=pdf`; each carries a **"not released" marking** until release. **[WEB]**

## 6. Refusal codes (stable)

`out_of_range {maximum}`, `invalid_value` (not a number), `too_many_decimals {allowed}`, `unknown_component`, `student_not_in_class`, `past_deadline {deadline}`, `locked {reason}`, `not_your_offering`, `not_your_class` (distinct from `not_your_offering`), `stale_mark {current}`, `op_id_reused`, `gaps_present {counts}`, `not_ready {blockers}`, `comment_required` (return, reject), `reason_required` (correction, promotion override), `confirm_required` (release), `structure_in_use`, `weights_not_100`, `version_conflict`, `invalid_cursor`, `invalid_limit`, `forbidden`. Each response is `{"error": "<code>", "message": "<plain words>", ...fields}`.

## 7. Capability codes this adds (extends the agreed `GET /schools/{id}/me` list)

`ENTER_SCORES`, `APPROVE_RESULTS`, `RELEASE_RESULTS`, `MANAGE_ASSESSMENT_SETUP`, `OVERRIDE_PROMOTION` (S2). **Mapping to today's roles is a proposal:** `TEACHER` enters scores for their own offerings; the **form master** is a new per-class assignment, not a role string, and approves their class; `HEAD_TEACHER` (the principal) releases and overrides promotion; `SCHOOL_ADMIN` manages set-up. **[school: who may approve in a form master's absence]**

## 8. What this asks of WEB and what it asks of others

- **WEB** (section 7 of its input, answered): score structure with maxima and weights (**yes**, `GET /offerings/{id}`); a paged, searchable roster (**yes**); each cell's value, state, deadline and lock reason (**yes**); computed values with `asOf` (**yes**); completeness counts, approval and release state (**yes**); capability codes (**yes**); every write safe to repeat (**yes**, `opId`); server-rendered PDFs (**S2**); storage for a crest and signatures (**no, not in S1 or S2**: needs an object store, a CM and Femi decision; headers are text only until then).
- **CM:** a PDF renderer is a new dependency and a CPU/memory cost on the school service (S2); object storage for crests and signatures (S2+); the JSON-body convention (rule 7).
- **A real school** (Femi): the score structure, the grading scale and the report-card template from one past term; see the open list.

## 9. Open decisions **[school]** (placeholders in section 4 stand until answered)

1. A real score sheet, scale and report card from a past term (everything above is a guess until then).
2. Number of components, decimals allowed, how ties show in positions, positions on or off.
3. Treatment of `ABSENT` (counts as zero?) and `EXCUSED` (excluded from the weighting?).
4. Submit with gaps allowed or not; deadline rules.
5. Who approves when the form master is absent.
6. Whether a release can be undone; the correction window.
7. Whether teachers share a phone (changes how "who entered this" is shown).

## 10. Backend tasks and order (none started)

| # | Task | Migration (planned; V31 is the latest) | Tests drive |
|---|---|---|---|
| A1 | `GradingScale`, `ScoreStructure` (versioned, weights = 100, immutable once used) and set-up routes | V32 | real Postgres |
| A2 | `SubjectOffering` and `GET /my-offerings` | V33 | real Postgres |
| A3 | `Mark` entry: `PUT /marks` with `opId` (reusing the sync ledger), versions, range, deadline, lock rules; the paged roster read | V34 | real Postgres, including concurrent writers |
| A4 | Computation: totals, grades, positions (switchable, tie rule), `asOf`; frozen copy at approval | V35 | unit + real Postgres |
| A5 | Submit, return, approve (offering and class), form master assignment, overview and review reads | V36 | real Postgres |
| A6 | Ratings, remarks | V37 | real Postgres |
| A7 | Release (freeze, guardian visibility, `AssessmentCompleted` without any result in the payload) and corrections | V38 | real Postgres |
| A8 | Remove the three old routes and old tables | V39 | n/a |
| S2 | Promotion rules and verdicts; server-side PDFs; broadsheet | later | later |

Every task includes real-Postgres tests (the lesson of the outbox fault), and a contract test for each response shape WEB declares strictly. **Review level for CM: high for A3, A5 and A7** (data integrity and a release that changes who may see children's results), medium for the rest. **No contract is final until WEB has shown it to a real teacher, form master and principal and Femi has said go.**

## 11. Revision 2 (after WEB's review, 2026-10-07)

WEB read draft 1 and asked for: **clear a mark** back to not entered (added: `clear: true`); **`GET /my-classes`** (added, so a form master sees only their classes); the missing refusal codes (added: `not_your_class`, `comment_required`, `reason_required`, `confirm_required`, `invalid_value`, `too_many_decimals`, `student_not_in_class`, `invalid_cursor`, `invalid_limit`); the **recomputed `computed` block in the `PUT /marks` response** (added); an optional **batch write** with per-item results (added: `POST .../marks:batch`); server-computed **`allowedActions`** on every resource with actions (added, rule 4a); positions as **number plus `tied`** (added, rule 4b); roster paging **default 50, max 100, cursor and total** (added); a teacher's own correction list, **`mine=true`** (added). WEB confirmed JSON bodies, the coded-mark rule, and that the three legacy routes are unused by it (so A8 breaks nothing on WEB's side; CM still gates A8 on its own). Set-up forms are designed last. Nothing is validated with real users and nothing is frozen on either side.


## 12. Revision 3 (as built: A1 to A3, 2026-10-08)

Steps A1 (grading scales, score structures), A2 (subject offerings) and A3 (mark entry) are built and tested against real Postgres. A1 and A2 are live in production (ER task `:74`); A3 was reviewed by CM and releasing the same day. This section records **where the built API differs from, or decides, what sections 3 to 7 left open**, so WEB codes against the real shapes. Nothing here is validated with real users; section 9's school questions are still open.

### 12.1 Routes as built (all under `/schools/{schoolId}/assessment`)

| Route | Who | Notes |
|---|---|---|
| `PUT /grading-scales/{id}` body `{name, bands:[{minScore, grade, remark?}]}`; `GET /grading-scales` | write: SCHOOL_ADMIN; read: SCHOOL_ADMIN and teaching roles | **Bands state only `minScore`** (no `maxScore`): a band runs to the next band's `minScore`; the first must be 0; the last runs to 100. Overlaps and gaps are impossible by construction. |
| `PUT /structures/{id}` body `{level, term, components:[{code,name,maximum,weight}], gradingScaleId, examComponentCode?, positionsEnabled, decimalsAllowed, absentRule, excusedRule}`; `GET /structures?level=&term=` | as above | `version` is assigned by the server (max+1 per level and term); a replace of the same id keeps its version. A structure keeps its level and term. |
| `PUT /offerings/{id}` body `{classSectionId, subjectCode, structureId, teacherIds[], deadline?}`; `GET /offerings?term=&cursor=&limit=` | SCHOOL_ADMIN | `deadline` is a UTC instant (`2026-12-04T15:00:00Z`). The **term comes from the structure**; there is no separate term field to send. |
| `GET /my-offerings?term=&cursor=&limit=` | any teaching role | **Always the caller's own**, whatever their role. Each item has `progress:[{component, entered, expected}]` (`expected` = students in the class). |
| `GET /offerings/{id}` | the offering's teacher, or SCHOOL_ADMIN | structure, scale, status, `lockReason`, `deadline`, `completeness` (same shape as `progress`), `allowedActions` (`["ENTER_MARKS","SUBMIT"]` for its teacher while it accepts marks, otherwise `[]`; always `[]` for an administrator). |
| `GET /offerings/{id}/roster?q=&missing=&cursor=&limit=` | as above | Section 5's roster. Sorted by family name, given name. `q` matches name or admission reference; `missing=true` keeps students with any part not entered. `nextCursor` is **opaque**. |
| `PUT /offerings/{id}/marks` body `{opId, studentId, component, version?}` plus exactly one of `value`, `code` or `clear` | a teacher **of that offering** | Reply `{studentId, cell, computed}`. |
| `POST /offerings/{id}/marks:batch` body `{marks:[...same item...]}` | as above | At most 100. Reply `{results:[{opId, studentId, status:"saved"\|"refused", cell, computed, error, message, fields}]}`; every field present, `null` where it does not apply. A refusal carries only that item's own data. |
| `POST /offerings/{id}/submit` body `{allowGaps}` | as above | Reply is the offering detail (status now `SUBMITTED`). |
| `GET /offerings/{id}/marks/history?studentId=&component=` | SCHOOL_ADMIN | The audit trail of one cell, oldest first: old and new value or code, version, actor, time, `opId`. |

Wire numbers (`value`, `total`, `maximum`, `weight`, `minScore`) are JSON numbers (doubles). CM accepted this for non-money assessment values. **Section 5's `my-classes`, ratings, remarks, class approval, release board and corrections are not built** (A4 to A7).

### 12.2 Decisions made while building

1. **A cell is never deleted.** Entering a mark creates it at version 1; **clearing keeps the row** (value and code both empty) and the version keeps counting. The API reports a cleared cell as `state:"NOT_ENTERED"` with its real (non-zero) `version`; a cell nobody ever wrote is `NOT_ENTERED`, version 0. This stops a stale client winning by reusing an old version after a clear and re-entry.
2. **`version` rules.** To change a cell you must send the version you last saw. Sending no `version` is accepted **only** while the cell holds nothing. Anything else is `409 stale_mark`. Writing exactly what the cell already holds changes nothing and adds no history.
3. **`stale_mark` carries the current cell as string fields:** `currentVersion`, and `currentValue` or `currentCode` when entered. Other extra fields in refusals (`maximum`, `allowed`, `deadline`, `status`, `reason`, `total`, `missing_<COMPONENT>`) are also strings.
4. **Replay comes before the rules.** A retry of an operation that was already saved returns the cell as it stands now, even after the offering was submitted or its deadline passed. Only new work meets the lock, deadline, component, class and range checks. A refused attempt is **not** remembered: the same `opId` can be sent again once the cause is fixed. An `opId` is 1 to 56 characters of letters, digits, `.`, `_`, `-`, `:`; the same `opId` with a different mark is `409 op_id_reused`; one still in flight is `409 op_in_progress` (retry shortly).
5. **No administrator bypass.** Writing a mark or submitting needs the teaching capability **and** being one of the offering's named teachers. A SCHOOL_ADMIN who teaches the offering may; otherwise it is `403 not_your_offering`. A later fix to a locked mark goes through a correction request (A7), never an edit.
6. **`student_not_in_class` is deliberately uniform** for a student who does not exist and for one in another class, so it reveals nothing about other classes.
7. **Computed results.** Total is out of 100: for each counted part, `value / maximum x weight`. `ABSENT` counts as zero or drops out of the weighting per `absentRule`; `EXCUSED` per `excusedRule`; dropped parts' weight is spread over the rest. **A part that is simply not entered keeps the whole total `null`** (as do a student with every part dropped), with `complete:false`; the grade follows the total. Positions are competition ranking (1, 2, 2, 4) over the non-null totals, with `tied:true` for equal totals, or `null`/`false` when the structure turns positions off. `asOf` is when the figures were computed. Nothing is stored yet: freezing at approval is A5.
8. **Structures and offerings freeze once a mark exists.** Replacing a structure used by marked offerings is `409 structure_in_use` (new code made real); changing an offering's class, subject or structure is `409 offering_in_use`; its teachers and deadline stay editable while it is open.
9. **The audit trail is append-only and enforced by the database** (no update, delete or truncate), written in the same transaction as every change. It is what A5's freeze and A7's corrections build on.
10. **Lock order** (for anyone writing a second client of the store): the offering first, then the cell, in every path. A submit takes the offering exclusively; a mark takes it shared. So a mark cannot land after a submit commits and the two cannot deadlock.

### 12.3 Refusal codes added or made precise

| Code | Status | Meaning |
|---|---|---|
| `offering_not_found` | 404 | no such offering (also returned for a missing structure behind it) |
| `not_your_offering` | 403 | not one of this offering's teachers (no administrator bypass) |
| `locked` | 409 | offering is `SUBMITTED` or `APPROVED`; fields `status`, `reason` |
| `past_deadline` | 409 | field `deadline`; compared with **server arrival time** (see 12.4) |
| `stale_mark` | 409 | see 12.2 (3) |
| `op_id_reused`, `op_in_progress`, `invalid_op_id` | 409, 409, 400 | see 12.2 (4) |
| `out_of_range` {`maximum`}, `too_many_decimals` {`allowed`}, `unknown_component`, `student_not_in_class`, `invalid_value` | 400 | as section 6; `invalid_value` also covers "give exactly one of value, code or clear" |
| `gaps_present` | 409 | fields `missing_<COMPONENT>` = how many students lack that part |
| `empty_batch`, `too_many_items` | 400 | batch of zero, or more than 100 |
| `invalid_scale`, `invalid_structure`, `weights_not_100` {`total`}, `unknown_grading_scale`, `scale_in_use` | 400/409 | set-up |
| `structure_in_use`, `structure_identity_fixed`, `offering_in_use`, `offering_locked`, `duplicate_offering` | 409 | freezing rules and the one-offering-per-class-subject-term rule |
| `unknown_structure`, `unknown_class_section`, `unknown_teacher` {`teacher`}, `invalid_offering`, `invalid_deadline` | 400 | offering set-up; a teacher must be an **active member of staff who can enter scores** |
| `invalid_cursor`, `invalid_limit`, `invalid_json` | 400 | paging (default 50, maximum 100) and body shape |

### 12.4 Still open (for Femi and the school)

- **Deadline against offline entry.** Today the deadline is compared with server arrival time, so a batch entered offline before the deadline and synced after it is refused whole (replays of already-saved items still succeed). Options: arrival time (strict, simple) or the client's capture time with a sanity bound (for example not earlier than 7 days before arrival). Recommended: capture time within a bound, once an offline client exists. On CM's list as D11.
- The approval and release chain (A4, A5, A7) needs a per-class form-master assignment and approve/release capabilities; see `docs/ER_RBAC_SPUTO.md` section 2.4 and 6, and the school questions D-ER1 to D-ER7 there. Not started.
- Everything in section 9 (a real score sheet, scale, ties, absent and excused treatment, gaps, absent form master, undoing a release, shared phones).
