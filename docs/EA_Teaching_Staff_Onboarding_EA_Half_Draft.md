# Teaching-staff onboarding: Enterprise Administration's half (DRAFT)

**Status: draft for HR and Education Runtime (ER) to react to, 2026-10-06. Nothing built.** Written by the EA session after Femi's decisions in the EA session:
- **"EA is Owner-Admin. He is the Business Owner. We work with him. He onboards through HR and can sack through HR."** So the owner acts in HR's screens; HR is the source of truth for employment; EA is the owner's surface and the home of access.
- **"EA leads teaching-staff onboarding as the Registry when the industry is Education."** EA is the fan-out caller: HR to EA to ER.
Companion drafts: ER's half (`ER/Principal/docs/ER_Teaching_Staff_Onboarding_ER_Half_Draft.md`) and HR's half (HR is drafting it). Every EA fact below was read from the code on 2026-10-06.

## 1. The flow

1. The Owner-Admin employs a person **in HR** (position, dates). HR saves the employment and sends **one command** to EA.
2. EA derives the person's access (its own Membership and grants) from the **position**, using a mapping table EA owns.
3. If the Company's industry is **Education** (`SCHOOL`) and the position maps to school duties, EA calls ER's staff endpoint for the Company's school.
4. Dismissal: the Owner-Admin ends the employment **in HR**; HR sends the change to EA, which ends the access and tells ER the same.
HR never talks to ER, ER never talks to HR, and nobody is employed twice.

## 2. What EA exposes to HR (proposal)

A route group for **HR's service identity only** (never the human routes with a service token), failing closed when the HR audience is not configured.

| Route | Meaning |
|---|---|
| `PUT /api/internal/tenants/{tenantId}/employments/{employmentId}` | Employ, or change an employment (position, dates, email). Idempotent on `employmentId` + `version` |
| `DELETE /api/internal/tenants/{tenantId}/employments/{employmentId}` | End the employment **immediately** (the explicit cut-off). A future end date is just `validUntil` on the PUT |

PUT body: `{companyId, email, name, position, validFrom, validUntil?, version}`.
- `employmentId` is HR's id, the correlation key. `position` is HR's position code. `version` is HR's last-updated instant, so an older push arriving late is ignored.
- **Nothing about pay**, and nothing else personal beyond email and name.
- `tenantId` is in the path and the Company must belong to it; a Company of another tenant is refused (the same integrity rule as company registration). HR is single-tenant per deployment; EA still checks.

Responses (HR surfaces any non-complete outcome as "not synced" and retries; every call is safe to repeat):
- `200 {membership: APPLIED|UNCHANGED, er: APPLIED|NOT_APPLICABLE|FAILED, complete: bool, reason?}`; `reason` is a fixed token.
- `404 company_not_found` (not the tenant's), `409 employment_conflict` (this email is already linked to a **different** employmentId at this Company; needs an explicit re-key, never a silent overwrite), `422 position_not_mapped`, `422 school_not_linked` (Education Company with no school link yet), `400 validation_failed`, `401/403` for any caller that is not HR's service identity, `503` if ER or EA's own dependencies are unreachable.

## 3. What EA does with it

### 3.1 The mapping table (EA owns it; the CONTENT is a business decision)
`position -> {EA role, EA access level, EA modules, ER duties}`. v1 has one entry: a **teaching position**, mapping to ER duty `TEACHER` and to the `EDUCATION_RUNTIME` module at that Company at READ level. EA never produces anything outside ER's allowlist (`TEACHER` only in v1; never `SCHOOL_ADMIN`, `REGISTRAR`, `BURSAR`, `HEAD_TEACHER`, `HOD`, `HOY`, `FEE_OFFICER`, `TIMETABLER`), and never `OWNER_ADMIN`. A position not in the table is `422 position_not_mapped`: HR is told, nothing is created. Non-teaching staff get no ER duty from a push in v1.

**OPEN, a decision for Femi (the one real blocker): which EA `Role` does a teacher hold?** An EA assignment must name one of `OWNER_ADMIN, ACCOUNTANT, SALES_OFFICER, PURCHASING_OFFICER, INVENTORY_MANAGER, HR_OFFICER`, and none describes a teacher; giving a teacher ACCOUNTANT would be wrong in name and a risk if modules later change. `Role` is a closed enum decoded strictly by GL, POP, SOP, IM, HR and WEB, so a new value is a **lockstep release across all of them**. EA's recommendation: add one generic **`STAFF`** role (no business function implied, so it serves teachers, cleaners and drivers in every industry) in a coordinated change, rather than mislabel teachers.

### 3.2 Membership
- The person is found or created by **verified email** (the identity in EA, ER and HR). EA creates a **pending invite** with one assignment at the Company (role, READ access, the mapped modules) and sends the existing invite email. The person accepts with their own identity. `employmentId`, `validFrom` and `validUntil` are stored on the Membership.
- A repeat of the same `employmentId` + `version` changes nothing. A newer `version` updates position, dates and grants. A **different `employmentId` for the same email at the same Company** is `409`, never an overwrite.
- An email change is an explicit **re-key** (not in v1; until then it is a manual admin step).
- **The Owner-Admin can be employed or dismissed through HR like anyone, but a command can never create, change or end an `OWNER_ADMIN` Membership.**

### 3.3 Validity window (no scheduler anywhere)
The Membership gets `validFrom` and `validUntil` (dates, UTC, `validUntil` inclusive, nullable = open-ended). EA's **active-membership resolution** (what `GET /me` returns, and what every other service trusts) **ignores a Membership outside its window**. So when the date passes, every service stops honouring it with **no sweeper and no change in the other services**, mirroring ER's own window. An explicit `DELETE` revokes immediately. This is authorization-path code, so it gets HIGH review.

### 3.4 Calling ER (Education companies only)
After EA's own part succeeds, EA calls ER's `PUT /schools/{schoolId}/staff/{email}/employment` with the existing `ea-provisioning` service account, carrying `employmentId`, `duties`, `validFrom`, `validUntil`, `version`. The school comes from the Company's school link. ER may be called **at invite time**: it grants nothing until that verified email signs in. If ER fails after EA succeeded, EA answers `complete: false, er: FAILED` and HR retries; because both legs are idempotent, the retry finishes the job. **No queue or outbox in EA** (HR shows "not synced" and re-syncs). A dismissal calls ER's end/delete route the same way.

## 4. Who sees what

- **WEB:** a teacher sees only Education Operations. WEB asks **ER** (`GET /schools/{schoolId}/me`, ER's own small item) for the person's school roles. The ER duty is **not** added to EA's `GET /me`, which five services decode strictly.
- **The Owner-Admin** sees the result in HR (employment) and in EA's Administration/Registry (the person's Membership); EA adds no new owner-facing screen in v1 beyond what the existing team list shows.

## 5. Build list (EA, not started)
1. Migration: `validFrom`, `validUntil` (nullable) and `employment_id` on the Membership data; unique per (Company, email) while linked.
2. The window rule in the active-membership resolution, with tests at both boundaries and for pending/revoked memberships.
3. The mapping table and its validation.
4. The HR-only route group and the two routes, the invite creation reusing the existing invite use case, the ER call behind a gateway port with a fake and a mock-engine test.
5. Tests: idempotency, version ordering, `409` conflict, `position_not_mapped`, `school_not_linked`, company-in-tenant, never-`OWNER_ADMIN`, ER failure then successful retry, human token and other service tokens refused.
Order: after Support is switched on and the held releases; needs CM for the HR service audience and credentials.

## 6. Open questions
1. **Which EA role does a teacher hold** (section 3.1)? Femi: generic `STAFF` role in a lockstep change, or another answer.
2. The position code vocabulary and which positions map to what (HR + Femi).
3. May a school admin extend access past HR's `validUntil`? EA's answer: no, HR's window is authoritative while an `employmentId` is linked (same as ER's recommendation).
4. Two overlapping employments of one email at one Company: modelled as `409` for now; confirm it never legitimately happens.
