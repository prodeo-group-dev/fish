-- Education Runtime: is it safe to enforce ER_SCHOOL_ROW_MODE and ER_DPID_BINDING_MODE?
--
-- READ ONLY. Run against the Education Runtime database (schooladmissions_production) as a read-only
-- user. Every statement is a SELECT. It prints opaque school ids and counts only: no names, emails,
-- phone numbers, student data or guardian subject ids.
--
-- Why: ER_SCHOOL_ROW_MODE=enforce refuses every request for a school that has no row in `schools`.
-- A school that has staff or linked guardians but no `schools` row would be locked out.
-- ER_DPID_BINDING_MODE=enforce refuses the BuzzMe/DPID device token in any school that has no
-- `school_integrations` row for DPID.
--
-- How to read the result:
--   Query 1: every row with has_school_row = false is a school that WOULD BE LOCKED OUT. Zero such
--            rows means ER_SCHOOL_ROW_MODE can go to enforce. Any row means: provision that school
--            first (EA's POST /schools), then re-run.
--   Query 2: the DPID switch per school. A school with a device in use must show dpid_enabled = true
--            before ER_DPID_BINDING_MODE goes to enforce. Zero devices live yet is a valid answer.
--   Query 3: sanity count of how many schools rows exist at all.

-- Query 1: every school id that has any ER data, and whether it has a schools row.
WITH referenced AS (
    SELECT school_id, 'staff'    AS source FROM staff_assignments WHERE status = 'ACTIVE'
    UNION ALL
    -- A guardian counts as "linked" when a guardian entry carries a 5th field (the subject id).
    -- Entries are ';'-separated, fields '|'-separated. Approximate (ignores escaped delimiters);
    -- the question asked here is only "does this school id appear at all", so that is enough.
    SELECT school_id, 'guardian_link' AS source FROM students
     WHERE guardians_json ~ '(^|;)([^;|]*\|){4}[^;|]+(;|$)'
    UNION ALL
    SELECT school_id, 'guardian_account' AS source FROM guardian_accounts
    UNION ALL
    SELECT school_id, 'student' AS source FROM students
)
SELECT r.school_id,
       (s.id IS NOT NULL)                                   AS has_school_row,
       count(*) FILTER (WHERE r.source = 'staff')           AS active_staff_rows,
       count(*) FILTER (WHERE r.source = 'guardian_link')   AS students_with_linked_guardian,
       count(*) FILTER (WHERE r.source = 'guardian_account') AS guardian_accounts,
       count(*) FILTER (WHERE r.source = 'student')         AS students
  FROM referenced r
  LEFT JOIN schools s ON s.id = r.school_id
 GROUP BY r.school_id, s.id
 ORDER BY has_school_row, r.school_id;

-- Query 2: DPID switch per known school.
SELECT s.id AS school_id,
       EXISTS (SELECT 1 FROM school_integrations i
                WHERE i.school_id = s.id AND i.integration = 'DPID') AS dpid_enabled
  FROM schools s
 ORDER BY s.id;

-- Query 3: totals.
SELECT (SELECT count(*) FROM schools)             AS schools_rows,
       (SELECT count(*) FROM school_integrations) AS integration_rows;
