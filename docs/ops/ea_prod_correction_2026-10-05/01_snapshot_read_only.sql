-- EA production data correction, 2026-10-05. STEP 1 of 4: READ-ONLY SNAPSHOT. Changes nothing.
-- Run first and SAVE THE OUTPUT: it is the "before" record for the audit.
--   psql "host=... dbname=ea_production user=ea_app" -f 01_snapshot_read_only.sql | tee before.txt

\echo '== B: the membership, its tenant, its user and ALL of its assignments'
SELECT m.id AS membership_id, m.tenant_id, t.name AS tenant_name, m.status, m.is_owner_admin, u.email, u.name AS user_name
FROM memberships m
JOIN tenants t ON t.id = m.tenant_id
JOIN users u ON u.id = m.user_id
WHERE m.id = '08d53478-44c3-4b19-bcb6-087255571067';

SELECT mca.membership_id, mca.company_id, mca.role, mca.access_level,
       EXISTS (SELECT 1 FROM tenant_companies tc WHERE tc.tenant_id = m.tenant_id AND tc.company_id = mca.company_id) AS company_linked_to_membership_tenant,
       cn.name AS company_name, cn.industry_type
FROM membership_company_assignments mca
JOIN memberships m ON m.id = mca.membership_id
LEFT JOIN company_names cn ON cn.company_id = mca.company_id
WHERE mca.membership_id = '08d53478-44c3-4b19-bcb6-087255571067'
ORDER BY mca.company_id;

SELECT mam.membership_id, mam.company_id, mam.module
FROM membership_assignment_modules mam
WHERE mam.membership_id = '08d53478-44c3-4b19-bcb6-087255571067'
ORDER BY mam.company_id, mam.module;

\echo '== B: which tenant(s), if any, link the company 78b02c68-5fd0-4a8b-9e60-71547954bfd9'
SELECT tc.tenant_id, t.name AS tenant_name
FROM tenant_companies tc JOIN tenants t ON t.id = tc.tenant_id
WHERE tc.company_id = '78b02c68-5fd0-4a8b-9e60-71547954bfd9';

\echo '== E: the company 2ee7984b-1817-4148-ad04-653df9de724a, its tenant, and who holds EDUCATION_RUNTIME at it'
SELECT cn.company_id, cn.name, cn.industry_type, cn.school_id,
       (SELECT array_agg(tc.tenant_id) FROM tenant_companies tc WHERE tc.company_id = cn.company_id) AS linked_to_tenants
FROM company_names cn
WHERE cn.company_id = '2ee7984b-1817-4148-ad04-653df9de724a';

SELECT mam.membership_id, m.tenant_id, m.status, m.is_owner_admin, u.email, mam.company_id, mam.module
FROM membership_assignment_modules mam
JOIN memberships m ON m.id = mam.membership_id
JOIN users u ON u.id = m.user_id
WHERE mam.company_id = '2ee7984b-1817-4148-ad04-653df9de724a' AND mam.module = 'EDUCATION_RUNTIME';

\echo '== population snapshot (industry and school link)'
SELECT industry_type, (school_id IS NULL) AS no_school, count(*) FROM company_names GROUP BY 1, 2 ORDER BY 1, 2;
