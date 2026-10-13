# Binding the DPID attendance service token to the schools it may act in (T-ER4): design note

**Status:** 2026-10-13, **design only, no code until CM has reviewed.** Written by the Education Runtime (+ER) session. CM's request: the DPID or device service token "must be bound to the schools it may act in, not any schoolId"; design the binding, the failure behaviour and the effect on BuzzMe and DPID calls and the attendance device flow, then send the tip. This is **a cross-school write path, so it is a security fix, not a feature**, and an add-a-deny inside the RBAC carve-out. Evidence tags: **[code]** read in `fish-education-runtime` on 2026-10-13; **[proposal]** mine, to be reviewed.

## 1. The gap **[code]**

`CognitoErIdentityGateway.resolveForSchool` (lines 88 to 91): when the verified token's service audience is `dpid`, it returns a principal **at whatever `schoolId` the request names**, holding only `DEVICE_ATTENDANCE_CAPTURE`. There is no list of schools the integration may act in and no check that the school exists. The role is narrow (`canMarkAttendance` and `canLookupByDpidIdentity` only: it can mark attendance for any student of any school it can name, and resolve a DPID identity to a student id), so the blast radius is **writing attendance marks into, and reading student ids from, any school on the platform** if the token leaks or the integration misbehaves. That is cross-school, and the deny-by-default rule says it must be closed.

## 2. Options for how the token proves its school set

| Option | How | Verdict |
|---|---|---|
| A. An environment allow-list of school ids | `ER_DPID_SCHOOL_IDS=...` | simplest, but it is a hand-kept list in a deploy variable: the thing Femi rejected for SOP (every new school is a config change and a redeploy) |
| B. A claim on the token | the token names its schools | Cognito machine-to-machine tokens are per app client, not per request, so a claim cannot vary per school; one client per school is unmanageable |
| C. **A per-school integration switch in ER's own data, enabled by the school's admin** | a row per (school, integration) with who enabled it and when; the service token acts only where a row exists | **recommended**: it is how the real world works (BuzzMe readers are installed at a school that chose them), it needs no deploy, it is logged, and it fails closed |
| D. Ask EA or BuzzMe at call time | a remote check per request | adds a runtime dependency on each attendance mark and fails when the other side is down, for no gain over C |

## 3. The design (option C) **[proposal]**

- **Data.** A small table `school_integrations(school_id, integration, enabled_by, enabled_at)` with a unique key on `(school_id, integration)`; `integration` is a closed value, `DPID` for now (the same table serves a future runtime integration). One Flyway migration (next free number, reserved on the coordination row).
- **Who enables it.** A **school admin** (or the Business Owner who is the first admin), by an authenticated route, `PUT /schools/{id}/integrations/dpid` and `DELETE` to switch it off. It is a **deliberate, logged act**: `enabled_by` and `enabled_at` are kept; a later `DELETE` removes the row (history is the audit log, see the shallow-audit limit in the safeguarding note). A registrar cannot (it is an integration, not register work): admin only.
- **The check.** In `resolveForSchool`, for a `dpid` audience: **the school must exist in the `schools` table (the other add-a-deny CM cleared) and a `DPID` row must exist for it**; otherwise return no principal, which the existing gate answers as 403. The check lives in the one place that resolves a service principal, so every route it can reach is covered, including the attendance auto-mark and the DPID identity lookup.
- **Fail closed, one answer.** No registry row, no integration row, a database error: the same 403 the route already gives an unknown caller (`cross-tenant`), with **no hint** about whether the school exists or why. The reason goes to the log (a structured line, no tokens, no student data).
- **No widening.** The role the token holds does not change; the human routes do not change; nothing is allowed that was refused before.

## 4. Effect on BuzzMe and DPID and the device flow **[proposal, to confirm with BuzzMe]**

- BuzzMe is **a separate system, not a FiSH venture**; its calls already carry the `schoolId` in the path and a service token. **Nothing in its request shape changes.** What changes is that a school must have **switched the integration on** first; until then BuzzMe gets 403 for that school.
- **Existing schools** that already receive DPID marks need a **one-time enable** by their admin (production is test data until the Live switch, so no real school is stranded; CM or Femi lists which test schools use it, and the enable is done through the route or, once, by a reviewed data change).
- **The attendance device flow** for staff devices (registered devices, the sync feed and push) is **unaffected**: those are human staff tokens bound to a registered device, a different path.
- **WEB** gets a small admin screen under School Administration: "Attendance readers (BuzzMe): on or off", with who enabled it and when.

## 5. Tests **[proposal]**

A DPID token is **refused** for a school with no row, for a school id that does not exist, and for school B when only school A is enabled; **accepted** for A; switching it off takes effect on the next call; a database failure answers the same 403; the admin route is refused for a registrar and a teacher and allowed for an admin; the human routes are unchanged; and the existing attendance-device and DPID tests are rewritten to enable the integration, not deleted. Real-Postgres tests for the unique key and the enable and disable.

## 6. Order and size

**The schools-row check first** (small, already cleared, no new data), then this binding: a migration, a store, the admin route, the resolve check and tests; size **M**, with a HIGH review because it changes how a service credential is authorised. WEB's screen follows separately. Build only after CM clears this note.

## 7. Open questions

1. **Who enables the integration** (admin only, as proposed, or also CM at provisioning)? **Proposal:** admin only.
2. **Which schools use DPID today?** CM or BuzzMe to list, so each gets its one-time enable.
3. **Should switching it on also require a BuzzMe-side registration of the school?** **Proposal:** no, not in this change; it would need a BuzzMe contract and is a later hardening.
