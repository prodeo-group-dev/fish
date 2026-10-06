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
| `DELETE /api/internal/tenants/{tenantId}/employments/{employmentId}` | End **that employment only**, immediately (the explicit cut-off). The person keeps access if another of their employments at the Company is still active. A future end date is just `validUntil` on the PUT |

PUT body: `{companyId, email, name, position, validFrom, validUntil?, version}`.
- `employmentId` is HR's id, the correlation key. `position` is HR's position code. `version` is HR's last-updated instant, so an older push arriving late is ignored.
- **Nothing about pay**, and nothing else personal beyond email and name.
- `tenantId` is in the path and the Company must belong to it; a Company of another tenant is refused (the same integrity rule as company registration). HR is single-tenant per deployment; EA still checks.

Responses (HR surfaces any non-complete outcome as "not synced" and retries; every call is safe to repeat):
- `200 {membership: APPLIED|UNCHANGED|STALE, er: APPLIED|UNCHANGED|STALE|NOT_APPLICABLE|FAILED, complete: bool, reason?}`; `reason` is a fixed token. ER's `STALE` (an older version arrived late) and `UNCHANGED` count as success.
- `404 company_not_found` (not the tenant's), `409 version_conflict` (the same `employmentId` and `version` arrives with different content; a **lower** version is not an error, it is `STALE` inside a `200`), `409 existing_unlinked_assignment` (ER's token, passed through: at ER the person has a hand-entered assignment not yet tied to an employment; needs an explicit, owner-confirmed adoption, never a silent overwrite), `422 position_not_mapped`, `422 school_not_linked` (Education Company with no school link yet), `400 validation_failed`, `401/403` for any caller that is not HR's service identity, `503` if ER or EA's own dependencies are unreachable.

## 3. What EA does with it

### 3.1 The mapping table (EA owns it; the CONTENT is a business decision)
`position -> {EA role, EA access level, EA modules, ER duties}`. v1 has one entry: a **teaching position**, mapping to ER duty `TEACHER` and to the `EDUCATION_RUNTIME` module at that Company at READ level. EA never produces anything outside ER's allowlist (`TEACHER` only in v1; never `SCHOOL_ADMIN`, `REGISTRAR`, `BURSAR`, `HEAD_TEACHER`, `HOD`, `HOY`, `FEE_OFFICER`, `TIMETABLER`), and never `OWNER_ADMIN`. A position not in the table is `422 position_not_mapped`: HR is told, nothing is created. Non-teaching staff get no ER duty from a push in v1.

**OPEN, a decision for Femi (the one real blocker): which EA `Role` does a teacher hold?** An EA assignment must name one of `OWNER_ADMIN, ACCOUNTANT, SALES_OFFICER, PURCHASING_OFFICER, INVENTORY_MANAGER, HR_OFFICER`, and none describes a teacher; giving a teacher ACCOUNTANT would be wrong in name and a risk if modules later change. `Role` is a closed enum in EA, and a new value must reach the consumers before EA emits it. **Checked in the code on 2026-10-06:** only **GL** converts the role string into a strict enum (`Role.valueOf(it)` in its EA membership gateway, which would throw for an unknown value); POP, SOP, IM and HR hold the role as a plain string and WEB treats it as a string for display. So the lockstep is small (section 7.2). EA's recommendation: add one generic **`STAFF`** role (no business function implied, so it serves teachers, cleaners and drivers in every industry) rather than mislabel teachers.

### 3.2 Membership and employment links (revised 2026-10-06 after ER and HR: employments overlap and repeat)
HR confirmed that one email at one Company legitimately has **several employments**: a rehire is a new HR Employee with the same email, and a salaried post plus hourly cover are two concurrent Employees. So EA keeps a **set of employment links**, not one employment on the Membership.
- The person is found or created by **verified email** (trim + lowercase, applied identically by HR and EA). The first link creates a **pending invite** with one assignment at the Company (mapped role, READ access, the mapped modules) and sends the existing invite email; the person accepts with their own identity.
- EA stores one **employment link** per `employmentId` (tenant, Company, email, position, `validFrom`, `validUntil?`, `version`, ended or not). A **different `employmentId` is simply another link**: no `409`, a rehire just works.
- An assignment created from a link is marked `source = EMPLOYMENT`. Hand-made assignments (the owner's own invites) stay `MANUAL` and are never touched by HR commands, in either direction.
- Same `employmentId`: same `version` and same content changes nothing (`UNCHANGED`); a **newer** `version` updates the link; a **lower** `version` is ignored (`STALE`, still `200`); the same `version` with **different content** is `409 version_conflict`.
- **Roles:** every v1 position maps to the same role, so two active links can never disagree. When the mapping table grows, two active links at one Company that map to different roles are refused with `422 position_role_conflict` rather than guessed.
- An email change is an explicit **re-key** (not in v1; until then a manual admin step).
- **The Owner-Admin can be employed or dismissed through HR like anyone, but a command can never create, change or end an `OWNER_ADMIN` Membership.**

### 3.3 Effective access = union of active windows (no scheduler anywhere)
An `EMPLOYMENT` assignment is honoured **only while at least one of its links is active today**: not ended, `validFrom <= today`, and `validUntil` empty or `today <= validUntil` (dates, UTC, inclusive). Grants are the union of the grants of the active links. EA's **active-membership resolution** (what `GET /me` returns, and what every other service trusts) applies this rule, so a gap between a resignation and a rehire is **not** access, a future-dated rehire grants nothing until its date, and when the last window passes every service stops honouring the assignment with **no sweeper and no change in the other services**. `DELETE` ends one link at once. Nothing new is added to `GET /me`. This is authorization-path code, so it gets HIGH review, with tests at both boundaries, for a gap between two links, two overlapping links (one ends, access stays), a future link only, and pending or revoked Memberships.

### 3.4 Calling ER (Education companies only)
After EA's own part succeeds, EA calls ER's `PUT /schools/{schoolId}/staff/{email}/employment` with the existing `ea-provisioning` service account, carrying `employmentId`, `duties`, `validFrom`, `validUntil`, `version`. The school comes from the Company's school link. ER may be called **at invite time**: it grants nothing until that verified email signs in. If ER fails after EA succeeded, EA answers `complete: false, er: FAILED` and HR retries; because both legs are idempotent, the retry finishes the job. **No queue or outbox in EA** (HR shows "not synced" and re-syncs). A dismissal calls ER's end/delete route the same way.

## 4. Who sees what

- **WEB:** a teacher sees only Education Operations. WEB asks **ER** (`GET /schools/{schoolId}/me`, ER's own small item) for the person's school roles. The ER duty is **not** added to EA's `GET /me`, which five services decode strictly.
- **The Owner-Admin** sees the result in HR (employment) and in EA's Administration/Registry (the person's Membership); EA adds no new owner-facing screen in v1 beyond what the existing team list shows.

## 5. Build list (EA, not started)
1. Migration: an `employment_links` table (tenant, Company, email, `employment_id` unique per tenant, position, `valid_from`, `valid_until?`, `version`, `ended_at?`) and a `source` column on assignments (`MANUAL` default, `EMPLOYMENT`).
2. The union-of-windows rule in the active-membership resolution (injected clock), with the tests listed in 3.3.
3. The mapping table and its validation.
4. The HR-only route group and the two routes, the invite creation reusing the existing invite use case, the ER call behind a gateway port with a fake and a mock-engine test.
5. Tests: idempotency, version ordering (`STALE`, `version_conflict`), rehire as a second link, overlapping links, `position_not_mapped`, `school_not_linked`, company-in-tenant, never-`OWNER_ADMIN`, ER failure then successful retry, human token and other service tokens refused.
Order: after Support is switched on and the held releases; needs CM for the HR service audience and credentials.

## 6. Open questions
1. **Which EA role does a teacher hold** (section 3.1)? Femi: generic `STAFF` role in a lockstep change, or another answer.
2. The position code vocabulary and which positions map to what (HR + Femi).
3. May a school admin extend access past HR's `validUntil`? EA's answer: no, HR's window is authoritative while an `employmentId` is linked (same as ER's recommendation).

## 7. Binding, release plan and wiring (CM review notes, 2026-10-06)

### 7.1 How the school is bound (the widening of `ea-provisioning`)
- **EA can only name the school of one of the tenant's own Companies.** HR never supplies a school id. The route's path names the tenant, the body names a Company, EA checks the Company belongs to that tenant (the company-registration integrity rule), and EA reads the school id from **its own** Company-to-school link. No link means `422 school_not_linked` and no call.
- **ER side (requested of ER, to confirm):** EA's call also carries the Company id and tenant id; ER already stores `organisationId` (the Company id) and `tenantId` when the school is provisioned, and should **refuse** a staff call whose Company or tenant does not match the school's own record. That turns a wrong id into a refusal on both sides.
- **The honest limit:** `ea-provisioning` is a platform-wide service credential. These checks stop mistakes and any caller other than EA, but they do not stop a compromised EA from naming a real (tenant, company, school) combination; the credential's reach is "teacher rows at any provisioned school", bounded by ER's allowlist (`TEACHER` only in v1).

### 7.2 Release plan if a generic `STAFF` role is chosen (consumers first, EA last)
1. **GL:** add `STAFF` to its `Role` enum (the only strict consumer). Deploy, verify the running image.
2. **WEB (cosmetic, optional before step 4):** a label for `STAFF` and the invite option. Role is a string there, so nothing breaks without it.
3. **POP, SOP, IM, HR:** no change required (the role is a string and nothing gates on its value; each owner confirms with a grep for any comparison).
4. **EA:** add `STAFF` to its `Role` enum and the mapping table, and start emitting it. EA ships last.
Nothing new is added to `GET /me` for the validity window: an expired membership is simply not returned, so no consumer needs to declare a new field.

### 7.3 Wiring for the HR-only route group
No new Cognito client or audience: HR's service identity already authenticates to EA with the configured HR service audience (`EA_JWT_SERVICE_AUDIENCE_HR`). The new group is mounted under a **service-principal-only provider on that same verifier** (no user or membership lookup, no human fallback, not registered and answering `503 service_unavailable` when the audience is unset), distinct from the existing HR provider that resolves to a user for `/me`. No new environment variable.
