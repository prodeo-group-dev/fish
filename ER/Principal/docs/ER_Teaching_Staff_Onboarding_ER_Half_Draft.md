# Teaching-staff onboarding: Education Runtime's half (DRAFT)

**Status: draft for HR and EA to react to, 2026-10-06. Nothing built, nothing decided.** Written by the `+ER Education` session after Femi's relayed instruction ("ER needs to work with HR on onboarding teaching staff") and HR's reply on direction, key and validity windows. HR drafts its own half separately; the two are reconciled once EA has weighed in. Every ER fact below was read from the code on 2026-10-06.

## 1. What exists today (ER side)

- A person is identified by the **verified email claim**, not the Cognito `sub` (`CognitoErIdentityGateway.authenticate`). `ErPrincipal.subjectId` is that email. Every `teacherId` in ER (lessons, subject assignments, `markedBy`, the roster check) is the same email.
- `StaffAssignment` = `(schoolId, subjectId, roles, status ACTIVE|REVOKED, grantedBy, updatedAt)`, one row per person per school. Created by `POST /schools/{id}/staff` (a school admin or registrar types `subjectId|role1,role2`), revoked by `POST .../staff/{subjectId}/revoke`.
- Nothing links a `StaffAssignment` to an HR employee or an EA membership.
- Machine callers already exist: `requireServiceAccount(identity, audience)` gates `POST /schools` for EA (audience `ea-provisioning`).

## 2. Proposed contract

### 2.1 Direction and caller
HR pushes once; **EA is the caller into ER** (HR's recommendation, because only EA knows the Company-to-School link and EA is already ER's provisioning caller). That reuses the existing EA service-account trust, so **no new credential is needed in ER**. Fallback if EA declines the fan-out role: HR calls ER directly, which needs a new service-account audience and Cognito client (a Configuration Management task, flagged not assumed).

### 2.2 Endpoint (proposal)
`PUT /schools/{schoolId}/staff/{email}/employment`, service-account only, idempotent.

Body fields:
- `employmentId` (HR's employee id, a correlation attribute, not the key)
- `duties` (default duty set, see 2.4)
- `validFrom`, `validUntil` (dates, `validUntil` nullable = open-ended)
- `version` (HR's last-updated instant, so ER ignores an older push that arrives after a newer one)

Responses: `200` applied or unchanged (idempotent on `employmentId` + `version`); `404` unknown school; `409` if the email at this school is already linked to a **different** `employmentId` (needs an explicit re-key, never a silent overwrite); `400` for a duty outside the pushable set.

### 2.3 Validity window enforced by ER (no scheduler anywhere)
`StaffAssignment` gains `employmentId`, `validFrom`, `validUntil`. In `resolveForSchool`, an assignment **that has an employmentId** resolves to roles only while `status = ACTIVE` and today (UTC date for now, school timezone once BK-ATT-R10 exists) is inside the window. An assignment **with no employmentId** (every row today, and any manually added one) behaves exactly as before, so this is backward compatible. The window gates **all** of that person's duties at the school, including admin-granted HOD/HOY, because someone no longer employed should not keep them.

Ending employment: push `validUntil` = a date (a future end date needs no second event). The window is inclusive of the `validUntil` day. **Immediate cut-off is an explicit revoke** (the existing revoke route, or a new `DELETE .../employment/{employmentId}`), not `validUntil = today`, which would leave access until midnight.

### 2.4 Duties: who owns what
`StaffAssignment.roles` today is one admin-managed set. A push must not overwrite it, or it would wipe an admin-granted HOD. So the row gets a second set, **`employmentDuties`** (managed only by the push); **effective roles = `roles` ∪ `employmentDuties`**.

**Privilege boundary (security-relevant):** a push may only grant an allowlist of duties, `TEACHER` only in v1. It can **never** grant `SCHOOL_ADMIN`, `REGISTRAR`, `BURSAR`, `FEE_OFFICER`, `TIMETABLER`, `HEAD_TEACHER`, `HOD` or `HOY`; those stay with a school admin, as HR recommended. Otherwise a compromised or buggy push path becomes a privilege-escalation path into the register and fees.

Non-teaching staff (cleaners, drivers) get **no** ER assignment from a push in v1; the allowlist is the vocabulary. The mapping from an HR position to `TEACHER` is **owned outside ER** (HR/EA); ER only validates what it receives.

### 2.5 Key and email changes
Key stays the email (normalised: trimmed, lower-cased, which ER should also start doing on the existing manual route). `employmentId` is stored so an email change is a deliberate **re-key** of that employment from the old email to the new one (`POST .../staff/{old}/rekey`, service-account, matched on `employmentId`), not an orphaned row. Optional for v1; without it a changed email needs manual admin work.

### 2.6 Multi-school
One person at two schools = two employments at two Companies in HR = two `StaffAssignment` rows in ER, each pushed and ended independently. Assumes each school is exactly one Company (how EA's `schoolId` link reads). **Open:** two overlapping employments at the *same* school for one email is not modelled (the 409 above would fire); confirm it never legitimately happens.

### 2.7 Failure handling
If HR saved the employment but the push failed, ER simply does not know yet. v1: HR surfaces "not synced" with a manual re-sync; a durable outbox is a later decision (HR's note). ER's idempotency on `employmentId` + `version` makes a re-sync safe.

## 3. ER work this implies (not started)
1. Migration (V31 or later; re-check numbering at build time, PR #9 holds V28-V30): three nullable columns plus `employment_duties`.
2. `StaffAssignment` model + stores + effective-role and window logic in the gateway, with tests including the window boundary and the allowlist.
3. The `PUT .../employment` route (+ optional re-key and delete), service-account gate, idempotency.
4. A test that existing manual assignments (no employmentId) behave unchanged.

## 4. Open questions
- **Lead:** Femi has not yet named who leads (EA is willing to be the fan-out caller; see section 5).
- **Allowlist:** is `TEACHER`-only right for v1, or should a position also be able to default to something like `REGISTRAR`? (My recommendation: no, never via push.)
- **Does ER mirror HR's `validUntil` exactly,** or may a school admin extend access past it? (My recommendation: no, the window is authoritative while an `employmentId` is linked; unlink first.)
- **Visibility in WEB:** Femi's rule (a teacher sees only Education Operations) needs the ER role to reach WEB, which today comes from EA only. Separate from this contract, but this contract is where ER's role would be known.

## 5. EA's answers (2026-10-06) - folded in

EA read this draft and agrees, pending Femi naming the lead. Nothing is built on any side.
- **Fan-out caller: yes**, if Femi confirms. EA does its Membership/grants first, then calls the endpoint in 2.2 with the existing `ea-provisioning` service account, as a thin, stateless, idempotent command keyed on `employmentId` + `version`. EA keeps no queue; HR retries a failed push. A missing Company-to-School link (only Companies registered through the school flow have one) is a clean refusal back to HR, not an ER concern.
- **Position-to-access mapping:** EA owns the table (position -> EA role + module grants + ER duties); the content is a business decision. v1 has one entry (a teaching position -> `TEACHER` at ER). EA never emits anything outside ER's allowlist, and **ER's allowlist stays the real guard**. No new EA `Role` value.
- **Invite acceptance:** no need to wait. Identity is the normalised email everywhere, so the link *is* the email; EA stores `employmentId` on the Membership at invite time. ER may be pushed at invite time because it grants nothing until that email signs in. An "accepted" callback to HR is an optional later extra.
- **End dates:** EA will give its Membership `validFrom/validUntil` too and ignore an out-of-window membership in `/me`, mirroring 2.3, so both layers expire on their own with no sweeper. (Auth-path code in EA, HIGH review by CM.) Immediate cut-off is still an explicit revoke on both.
- **The ER duty is NOT added to EA's `/me`** (every service decodes it strictly; a school-only field would force a lockstep release across GL/POP/SOP/IM/HR). **WEB should ask ER for the caller's school roles.** That is a **new, small ER item**: a read route returning the caller's own effective roles at a school (`GET /schools/{schoolId}/me`, any authenticated principal at that school, returns roles and the employment window if any). Not built; needed before WEB's role-based visibility can work. WEB to confirm the shape it wants.

## 6. `GET /schools/{schoolId}/me` shape requested by WEB (2026-10-06) and Femi's clarification

**Shape (agreed in principle, not built):** `200 { schoolId, roles[], capabilities[], validFrom|null, validUntil|null, active }`, every field always present, explicit `null` where empty (WEB decodes strictly).
- `roles`: effective roles as computed today (staff roles, plus the computed `GUARDIAN`).
- `capabilities`: **server-computed from the same `ErPrincipal` checks that guard the routes**, as stable code strings (for example `MARK_ATTENDANCE`, `ENTER_GRADES`, `VIEW_ANY_CLASS_DATA`, `MANAGE_REGISTER`, `MANAGE_FEES`, `MANAGE_TIMETABLE`, `ACCESS_PARENT_GATEWAY`). WEB asks "what can I do?" and never copies ER's role-to-permission table (one source). ER picks the names and publishes the list; adding one later is additive.
- `validFrom`/`validUntil`/`active`: the employment window, `null` when none; `active = false` when the person has an assignment that is revoked or outside its window (roles and capabilities are then `[]`).
- A signed-in person with **no** assignment at a known school: `200` with `roles: []`, `capabilities: []`, `active: false`.

**Two behaviours that differ from every other ER school route, flagged on purpose:**
1. Today every school route answers `403` to someone with no assignment (`resolveForSchool` returns null). Here that case becomes `200` empty, so the route authenticates (a valid token is still required, `401` otherwise) but does **not** use `requireSchoolAccess`'s 403. This is safe only because the response contains nothing about the school beyond the caller's own (empty) access.
2. ER's registry lets us tell "unknown school id" (`404`) from "known school, no access" (`200` empty). The cost: any authenticated user can learn whether a school id exists. School ids are unguessable UUIDs, so this is judged acceptable; **CM to confirm in review**. WEB only calls it for Companies registered through the school flow, so a registered school is the normal case.

**Femi, 2026-10-06 ("EA is Owner-Admin. He is the Business Owner... He onboards through HR and can sack through HR"):** the human who employs and dismisses teaching staff is the Business Owner, through the HR screens in WEB. So an **immediate cut-off is a first-class path, not an edge case**: the explicit revoke (`DELETE /schools/{schoolId}/staff/{email}/employment/{employmentId}`, service-account, reachable by EA on the Owner's behalf) is **required in v1**, not optional as 2.3 left it; the scheduled `validUntil` is the other path. Both layers (EA Membership, ER assignment) must be cut by the one HR action.

**Capability codes, one per ErPrincipal check (checked against the code 2026-10-06; final list is published with the route contract at build time):**

| Code | ErPrincipal check | Roles today | WEB screen |
|---|---|---|---|
| `MANAGE_REGISTER` | `canManageRegister` | SCHOOL_ADMIN, REGISTRAR | Students console |
| `MANAGE_ADMISSIONS` | `canManageAdmissions` | SCHOOL_ADMIN, REGISTRAR, ADMISSIONS_OFFICER | Admissions tab (a **separate** permission from `MANAGE_REGISTER`: an admissions officer is not a register admin) |
| `MANAGE_TIMETABLE` | `canManageTimetable` | SCHOOL_ADMIN, TIMETABLER | Timetable |
| `MANAGE_FEES` | `canManageFees` | SCHOOL_ADMIN, FEE_OFFICER, BURSAR | Fees and billing |
| `MARK_ATTENDANCE` | `canMarkAttendance` | TEACHER, SCHOOL_ADMIN, HEAD_TEACHER, HOD, HOY (+ the device account) | Attendance register |
| `ENTER_GRADES` | `canEnterGrades` | TEACHER, SCHOOL_ADMIN, HEAD_TEACHER, HOD, HOY | Grades; **also gates the class roster route**, so the register screen needs both `MARK_ATTENDANCE` and `ENTER_GRADES` |
| `VIEW_ANY_CLASS_DATA` | `canViewAnyClassData` | SCHOOL_ADMIN, HEAD_TEACHER, HOD, HOY | (a plain teacher sees only classes they teach) |
| `ACCESS_SAFEGUARDING` | `canAccessSafeguarding` | SCHOOL_ADMIN, SAFEGUARDING_LEAD, PASTORAL_LEAD | none yet (D3: no safeguarding flag until its own SPUTO) |
| `ACCESS_PARENT_GATEWAY` | `canAccessParentGateway` | GUARDIAN, PARENT | Parent view |

`LOOKUP_BY_DPID_IDENTITY` is machine-only and is not returned to humans.
