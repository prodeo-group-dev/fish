# The school admin alone loses safeguarding access: form and timing (short note)

**Status:** 2026-10-13, docs only; no code until CM reviews. Written by the Education Runtime (+ER) session. **Decided (Femi, Decisions_Log, 2026-10-13, D13):** yes, the school admin alone loses access to child-protection records. This note proposes the form and the timing, as CM asked.

## What the code does today **[code]**

One predicate decides everything: `ErPrincipal.canAccessSafeguarding()` is true for SCHOOL_ADMIN, SAFEGUARDING_LEAD and PASTORAL_LEAD. It gates (a) the unmasking of safeguarding fields and flags in every student read and list (the Exposed and in-memory stores), (b) the safeguarding columns of the student CSV import, and (c) `GET /schools/{id}/students/{id}/audit` (the change history and the pastoral access log). **HEAD_TEACHER is not in it.**

## Recommendation: an add-a-deny now, by removing SCHOOL_ADMIN from that one predicate

- **Form:** change `canAccessSafeguarding()` to SAFEGUARDING_LEAD and PASTORAL_LEAD only. One line, one predicate, every use site follows; the 403 and masking behaviour for other roles is unchanged. This is a **tightening** (an add-a-deny), inside the RBAC carve-out, with CM's review before the build and again before release (no flag).
- **Why now and not behind the E2 flag:** it is **children's data**; production is test data until the Live switch, so no real school is stranded; a flag that defaults OFF would leave the very exposure Femi has just decided to close. A person who is admin **and** safeguarding lead holds both roles and keeps access.
- **Not part of this change (kept separate, needs its own review because it widens access):** giving the **head teacher** safeguarding access. The head teacher does not have it today, so "the head teacher keeps it" in my earlier wording was wrong: it would be a **gain**. If the head teacher is the school's designated safeguarding lead they hold the SAFEGUARDING_LEAD role. Whether HEAD_TEACHER should be added to the predicate is a separate question for Femi (new decision **D13b**; my recommendation: no, designate the role, because the person responsible for child protection should be a deliberate appointment).
- **Break-glass** (access with a reason, time-limited, alerting the safeguarding group) is a **new feature**, so it stays **behind the E2 flag**, default OFF, built after the roles screen (Part 2, E2). Until it exists nobody outside the two leads can open the records; that is the intended default.

## The dead end to avoid

A school with **no safeguarding or pastoral lead assigned** would show masked records to everyone, as the T-ER10 dead end did for grades and fees. So: (1) the Roles-and-access screen must exist (F6) and its empty-state hint says "no one can see safeguarding records yet: appoint a safeguarding lead"; (2) the first admin can grant themselves SAFEGUARDING_LEAD: that is allowed (a deliberate, role-change-audited act, F9), not prevented, because the school must have someone; it is no longer implicit.

## Size, tests, order

Size **S** (one predicate, test updates). Tests: admin alone refused or masked on the student read, list, CSV safeguarding columns and the audit route; SAFEGUARDING_LEAD and PASTORAL_LEAD allowed; an admin who also holds SAFEGUARDING_LEAD allowed; existing tests that assume an admin sees safeguarding fields are rewritten, not deleted; integration run on Postgres as for T-ER10. Order: after CM's review; independent of the other Playbook tasks; WEB briefed so it does not show safeguarding controls to an admin-only user and shows the appointment hint.

## Consequence for the Playbook

Part 2 PL-SAF-1 and the deferred-enforcement row E2 are updated: the **deny** is an add-a-deny now (no flag), only **break-glass** stays flagged (E2), and D13b (head teacher) is added to the decisions.
