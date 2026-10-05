-- EA production data correction, 2026-10-05. STEP 2 (ALTERNATIVE) for row B. USE ONLY IF the read-only snapshot
-- (step 1) shows the company 78b02c68-5fd0-4a8b-9e60-71547954bfd9 LEGITIMATELY belongs to tenant
-- bd14752a-b51e-4df9-8b48-0b1e8677f78a and only the EA link row is missing (for example GL created the company
-- but EA's registration step never ran). It adds the missing link instead of removing the assignment.
-- It refuses to run if the company is already linked to ANY tenant (that would be the cross-tenant situation
-- the new unique index forbids). Never run this and 02_B_remove_foreign_assignment.sql together.

\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE linked integer;
BEGIN
    SELECT count(*) INTO linked FROM tenant_companies WHERE company_id = '78b02c68-5fd0-4a8b-9e60-71547954bfd9';
    IF linked <> 0 THEN
        RAISE EXCEPTION 'precondition failed: the company is already linked to % tenant(s). Nothing was changed.', linked;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM tenants WHERE id = 'bd14752a-b51e-4df9-8b48-0b1e8677f78a') THEN
        RAISE EXCEPTION 'precondition failed: tenant not found. Nothing was changed.';
    END IF;
END $$;

\echo 'ADDING this link (save this output):'
INSERT INTO tenant_companies (tenant_id, company_id)
VALUES ('bd14752a-b51e-4df9-8b48-0b1e8677f78a', '78b02c68-5fd0-4a8b-9e60-71547954bfd9')
RETURNING *;

\prompt 'Type YES to COMMIT this change (anything else rolls it back): ' answer
SELECT (:'answer' = 'YES') AS do_commit \gset
\if :do_commit
    COMMIT;
    \echo 'COMMITTED.'
\else
    ROLLBACK;
    \echo 'ROLLED BACK. Nothing was changed.'
\endif
