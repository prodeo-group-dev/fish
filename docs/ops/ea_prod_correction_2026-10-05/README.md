# EA production data correction, 2026-10-05: PREPARED, NOT APPLIED

**Nothing here has been run against production.** The scripts were tested on a throwaway Postgres 16 that has EA's schema (migrations V1 to V16) and a copy of the two situations: they commit only on `YES`, roll back on anything else, abort without changing anything if the data is not what was triaged, and refuse to run twice.

## Why

Femi's read-only checks on production EA (A, B, D, E, F) found two rows to correct before the security release (V17's unique index and the new guards) goes in:

| Row | What | Proposed correction |
|---|---|---|
| **B** | membership `08d53478-44c3-4b19-bcb6-087255571067` (tenant `bd14752a-b51e-4df9-8b48-0b1e8677f78a`) holds an ACCOUNTANT/WRITE assignment at company `78b02c68-5fd0-4a8b-9e60-71547954bfd9`, which is **not linked to that tenant** | Remove that one assignment (and its module grants), **if the triage shows it is not legitimate**. If instead the company really belongs to that tenant and only EA's link row is missing, add the link (the ALT script). |
| **E** | company `2ee7984b-1817-4148-ad04-653df9de724a` "Prodeo Trading" (tenant `9fa2198b-2a6f-467d-97ac-6f6fbce6a9fd`) has an EDUCATION_RUNTIME module grant but is stored as an ordinary company with no school | Remove that module grant. (A company's industry never changes, so the grant is removed rather than the company becoming a school.) |

## Order

1. `01_snapshot_read_only.sql`: the "before" record. Run, save the output. Also answers the triage questions (owning tenant of the B company, who the membership and user are, all of that membership's assignments, who holds the E grant).
2. **Decide B** from that output: `02_B_remove_foreign_assignment.sql` (assignment not legitimate) **or** `02_B_ALT_link_company_to_tenant.sql` (company legitimately belongs to the tenant). **Never run both.**
3. `03_E_revoke_education_runtime_grant.sql`.
4. `04_postcheck_read_only.sql`: A, B, F and E must each return **zero rows**; keep the output.
Only then does CM release the security fixes.

## How to run (from a terminal, because the confirmation prompt reads the keyboard)

```
psql "host=... dbname=ea_production user=ea_app" -f 02_B_remove_foreign_assignment.sql | tee b_change.txt
```
Each change script prints every row it is about to remove, then asks `Type YES to COMMIT this change (anything else rolls it back):`. Save the printed rows: they are the audit record. The credential and tunnel steps are the ones CM already gave Femi.

## One thing to decide, not in the scripts

Removing B's assignment may leave that membership with **no assignment at all** (the script prints what remains). A membership with no assignments is an active person with no access; whether to also revoke that membership is a separate decision once Femi knows who the person is.
