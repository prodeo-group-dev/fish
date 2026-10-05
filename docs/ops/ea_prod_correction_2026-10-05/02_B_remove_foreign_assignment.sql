-- EA production data correction, 2026-10-05. STEP 2 of 4, ROW B: remove ONE assignment at a company that is
-- not linked to the membership's own tenant. USE ONLY IF the read-only snapshot (step 1) shows the assignment
-- is NOT legitimate. (If the company really does belong to that tenant and only the link row is missing, use
-- 02_B_ALT_link_company_to_tenant.sql INSTEAD. Never run both.)
--
-- Safe by construction: one transaction; aborts if the data is not exactly what was triaged; prints every row it
-- removes (save the output: it is the audit record); and does NOT commit until you type YES.
--   psql "host=... dbname=ea_production user=ea_app" -f 02_B_remove_foreign_assignment.sql | tee b_change.txt
-- NB: piping to tee is fine for output, but the YES prompt reads the keyboard, so run it from a terminal.

\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n
    FROM membership_company_assignments mca
    JOIN memberships m ON m.id = mca.membership_id
    WHERE mca.membership_id = '08d53478-44c3-4b19-bcb6-087255571067'
      AND mca.company_id    = '78b02c68-5fd0-4a8b-9e60-71547954bfd9'
      AND m.tenant_id       = 'bd14752a-b51e-4df9-8b48-0b1e8677f78a'
      AND NOT EXISTS (SELECT 1 FROM tenant_companies tc WHERE tc.tenant_id = m.tenant_id AND tc.company_id = mca.company_id);
    IF n <> 1 THEN
        RAISE EXCEPTION 'precondition failed: expected exactly 1 foreign assignment, found %. Nothing was changed.', n;
    END IF;
END $$;

\echo 'REMOVING these module grants (save this output):'
DELETE FROM membership_assignment_modules
WHERE membership_id = '08d53478-44c3-4b19-bcb6-087255571067'
  AND company_id    = '78b02c68-5fd0-4a8b-9e60-71547954bfd9'
RETURNING *;

\echo 'REMOVING this assignment (save this output):'
DELETE FROM membership_company_assignments
WHERE membership_id = '08d53478-44c3-4b19-bcb6-087255571067'
  AND company_id    = '78b02c68-5fd0-4a8b-9e60-71547954bfd9'
RETURNING *;

\echo 'What that membership still has after the change:'
SELECT membership_id, company_id, role, access_level FROM membership_company_assignments
WHERE membership_id = '08d53478-44c3-4b19-bcb6-087255571067';

\prompt 'Type YES to COMMIT this change (anything else rolls it back): ' answer
SELECT (:'answer' = 'YES') AS do_commit \gset
\if :do_commit
    COMMIT;
    \echo 'COMMITTED.'
\else
    ROLLBACK;
    \echo 'ROLLED BACK. Nothing was changed.'
\endif
