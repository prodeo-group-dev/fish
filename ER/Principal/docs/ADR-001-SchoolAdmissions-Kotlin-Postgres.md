# ADR-001 — SchoolAdmissions language and datastore

**Status:** Accepted (Femi, 2026-09-17)  
**Context:** The Principal (`C:\Users\femif\Claude\Projects\FiSH\ER\Principal`) under FiSH+ER  
**Build:** W0+W1 unparked 2026-09-17 for Code Writer; later waves still held

## Decision

1. **SchoolAdmissions (backend / domain):** Kotlin + Ktor + Exposed — same stack family as FiSH GL/EA/POP/SOP/IM/HR.
2. **Web UI:** React + TypeScript (per SRS §5.1).
3. **Mobile (optional first release):** Flutter; local offline store (e.g. SQLite) syncing to SchoolAdmissions.
4. **System of record:** **PostgreSQL** (relational), multi-tenant by school; align with FiSH RDS patterns.
5. **Offline:** Client local store only; authoritative sync to Postgres (conflict: most recent authoritative submission per SRS).
6. **Uploads:** Object storage (S3), not a document DB as SoR.
7. **Not for v1:** Graph database as primary store; Kotlin Multiplatform for UI; direct FiSH GL writes (SOP events only).

## Consequences

- Code Writer implements SchoolAdmissions in Kotlin/Postgres when Femi unparks a wave.
- Code Reviewer reviews against SRS/backlog + this ADR.
- Fee Desk / payments remain event-sourced into FiSH SOP → GL.


## Amendment 2026-09-17

Domain layer name: **SchoolAdmissions** (replaces SchoolAdmissions in code/package naming). Stack decision unchanged. Bulk CSV student initialise is in W1 scope.
