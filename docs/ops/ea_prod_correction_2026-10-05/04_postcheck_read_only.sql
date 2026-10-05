-- EA production data correction, 2026-10-05. STEP 4 of 4: READ-ONLY POST-CHECK. Changes nothing.
-- Every check below must return ZERO ROWS (the population snapshot at the end is for comparison only).
-- Run it BEFORE the security release (V17 and the new guards must go in on clean data) and keep the output.

\echo '== A: a company linked to more than one tenant (must be 0 rows)'
SELECT company_id, count(*) AS n, array_agg(tenant_id) AS tenants
FROM tenant_companies GROUP BY company_id HAVING count(*) > 1;

\echo '== B: assignments at a company outside the membership''s own tenant (must be 0 rows)'
SELECT m.id AS membership_id, m.tenant_id, m.status, mca.company_id, mca.role, mca.access_level
FROM membership_company_assignments mca
JOIN memberships m ON m.id = mca.membership_id
WHERE NOT EXISTS (SELECT 1 FROM tenant_companies tc WHERE tc.tenant_id = m.tenant_id AND tc.company_id = mca.company_id);

\echo '== F: PENDING invites with a foreign company (must be 0 rows)'
SELECT m.id AS membership_id, m.tenant_id, u.email, mca.company_id
FROM membership_company_assignments mca
JOIN memberships m ON m.id = mca.membership_id
JOIN users u ON u.id = m.user_id
WHERE m.status = 'PENDING'
  AND NOT EXISTS (SELECT 1 FROM tenant_companies tc WHERE tc.tenant_id = m.tenant_id AND tc.company_id = mca.company_id);

\echo '== E: EDUCATION_RUNTIME grants on companies stored as GENERIC (must be 0 rows)'
SELECT DISTINCT cn.company_id, cn.name, cn.industry_type, (cn.school_id IS NULL) AS no_school, m.tenant_id
FROM membership_assignment_modules mam
JOIN memberships m ON m.id = mam.membership_id
JOIN company_names cn ON cn.company_id = mam.company_id
WHERE mam.module = 'EDUCATION_RUNTIME' AND cn.industry_type = 'GENERIC';

\echo '== population snapshot, for comparison with the before-snapshot (company industries should be unchanged)'
SELECT industry_type, (school_id IS NULL) AS no_school, count(*) FROM company_names GROUP BY 1, 2 ORDER BY 1, 2;
