-- EA production data correction, 2026-10-05. STEP 3 of 4, ROW E: remove the EDUCATION_RUNTIME module grant at
-- company 2ee7984b-1817-4148-ad04-653df9de724a ('Prodeo Trading', tenant 9fa2198b-2a6f-467d-97ac-6f6fbce6a9fd),
-- which is stored as an ordinary (GENERIC) company with no school. Industry is immutable by decision, so the
-- wrong grant is removed rather than the company being turned into a school. Only module-grant rows are removed;
-- no assignment, membership or company is touched.
--
-- Same safety as step 2: one transaction, preconditions, prints what it removes, commits only on YES.

\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE company_ok integer; grants integer;
BEGIN
    SELECT count(*) INTO company_ok FROM company_names
    WHERE company_id = '2ee7984b-1817-4148-ad04-653df9de724a' AND industry_type = 'GENERIC' AND school_id IS NULL;
    IF company_ok <> 1 THEN
        RAISE EXCEPTION 'precondition failed: the company is not a GENERIC company with no school link. Nothing was changed.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM tenant_companies
                   WHERE tenant_id = '9fa2198b-2a6f-467d-97ac-6f6fbce6a9fd' AND company_id = '2ee7984b-1817-4148-ad04-653df9de724a') THEN
        RAISE EXCEPTION 'precondition failed: the company is not linked to that tenant. Nothing was changed.';
    END IF;
    SELECT count(*) INTO grants
    FROM membership_assignment_modules mam JOIN memberships m ON m.id = mam.membership_id
    WHERE m.tenant_id = '9fa2198b-2a6f-467d-97ac-6f6fbce6a9fd'
      AND mam.company_id = '2ee7984b-1817-4148-ad04-653df9de724a' AND mam.module = 'EDUCATION_RUNTIME';
    IF grants = 0 THEN
        RAISE EXCEPTION 'precondition failed: no EDUCATION_RUNTIME grant found there (already corrected?). Nothing was changed.';
    END IF;
    RAISE NOTICE 'about to remove % EDUCATION_RUNTIME grant(s)', grants;
END $$;

\echo 'REMOVING these module grants (save this output):'
DELETE FROM membership_assignment_modules mam
USING memberships m
WHERE m.id = mam.membership_id
  AND m.tenant_id = '9fa2198b-2a6f-467d-97ac-6f6fbce6a9fd'
  AND mam.company_id = '2ee7984b-1817-4148-ad04-653df9de724a'
  AND mam.module = 'EDUCATION_RUNTIME'
RETURNING mam.membership_id, mam.company_id, mam.module;

\prompt 'Type YES to COMMIT this change (anything else rolls it back): ' answer
SELECT (:'answer' = 'YES') AS do_commit \gset
\if :do_commit
    COMMIT;
    \echo 'COMMITTED.'
\else
    ROLLBACK;
    \echo 'ROLLED BACK. Nothing was changed.'
\endif
