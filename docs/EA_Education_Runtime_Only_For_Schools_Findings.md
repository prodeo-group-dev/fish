# Only schools have an Education Runtime: does EA enforce it on every path? (findings)

**Status:** 2026-10-13, findings only, no code. Written by the EA session at CM's request after Femi's rule (Decisions Log): "Only schools should be set up to have an Education Runtime." Every statement below was read in EA's code on `origin/master` (077ccad plus the industry route, 9e4bd8f) on 2026-10-13, except where marked. I did not and cannot read production data.

## 1. Verdict in one table

| # | CM's question | Holds? | Where |
|---|---|---|---|
| 1 | The `EDUCATION_RUNTIME` module can be granted only on a SCHOOL Company | **NO, not on every path.** It holds for registration; it does NOT hold for invites or for changing a member's modules | section 2 |
| 2 | Provisioning in ER is called only for SCHOOL Companies | **YES** (one call site) | section 3 |
| 3 | A Company's industry cannot change after registration | **YES in the application; no database-level guard** | section 4 |
| 4 | The new industry route and the SOP rule use the same flag | **The route does; the SOP rule is not built yet** | section 5 |
| 5 | Any non-school Company in production still holding the module (the V15 case) | **Cannot be answered from code; the fix is not evidenced as done** | section 6 |

## 2. Where the module can be granted, path by path

Every code path that creates or changes a module grant, from a search of EA's source and migrations:

| Path | Enforces "SCHOOL only"? | Detail |
|---|---|---|
| **Company registration** (`RegisterCompanyUseCase.assignOwnerAdminsAt`) | Yes | gives the Owner Admin every module EXCEPT `EDUCATION_RUNTIME` |
| **Company registration, school branch** (`grantEducationRuntimeToAdmins`) | Yes | adds `EDUCATION_RUNTIME` only inside `if (industryType == SCHOOL)`, and only to an Owner-Admin assignment that already exists at that Company |
| **Invite staff** (`POST /tenants/{t}/memberships`, `InviteStaffMemberUseCase`) | **No** | the request names modules per Company; they are parsed with `ManagedModule.valueOf` and stored. The use case checks that the Companies belong to the Tenant and that no assignment is OWNER_ADMIN; it never looks at the Company's industry, so `EDUCATION_RUNTIME` can be granted at a GENERIC Company |
| **Change a member's modules** (`PATCH .../memberships/{m}/companies/{c}/modules`, `UpdateMembershipModulesUseCase`) | **No** | same: any `ManagedModule` value is accepted for any Company in the Tenant |
| `Membership.assignAt` (domain) | No, by design | the domain has no knowledge of industry; it only refuses OWNER_ADMIN for a non-owner and an empty set |
| `Membership.defaultModulesFor(OWNER_ADMIN)` | **Latent trap** | returns every module including `EDUCATION_RUNTIME`; unreachable today because invite refuses OWNER_ADMIN, but anything that used it for an Owner would grant the module everywhere |
| **Migration V15** (2026-09-23, the old Tenant-wide grants expanded per Company) | **No: this was the bug** | the INSERT joined the old Tenant-wide module rows to every Company assignment on `membership_id` alone, so a person who held `EDUCATION_RUNTIME` because they administered one school got it on every Company they held. A later fix-up path exists only as a SQL plan, see section 6 |
| Message channels (`audience_module` of a message) | n/a to access | a channel named `EDUCATION_RUNTIME` can be addressed at a Company the sender has the module for; it grants nothing |
| WEB | UI only | the school screens appear when the selected Company's `grantedModules` contains `EDUCATION_RUNTIME`, so a stray grant makes a non-school Company LOOK like a school; the server does not rely on the UI |

**Consequence.** The module is a UI switch in WEB and, for the Education Runtime, only a visibility flag (ER authorises from its own staff table, see the platform contract SPUTO). So a stray grant does not give a person access to a school's data: it makes a non-school Company show school screens, and it is the flag a future rule might read. That is why it matters that the rule be enforced where it is written, and why EA's industry type, not the module, must be the single source of truth.

## 3. Provisioning (`POST /schools` in ER)

One call site: `RegisterCompanyUseCase.register`, inside `if (industryType == IndustryType.SCHOOL)`, which calls `provisionSchool` and then `grantFirstAdmin`. A GENERIC registration never calls ER. Nothing else in EA references the gateway. ER's `POST /schools` answers only EA's `ea-provisioning` service identity, but ER cannot tell from the request whether the Company is a school: it trusts EA's one caller. **Order matters**: integrity checks (Company owned by another Tenant; a different industry than the one stored) run BEFORE the side effect, so a re-registration with another industry is refused with `IndustryTypeImmutable` and never reaches ER.

## 4. Immutability

- **Application:** `RegisterCompanyUseCase` returns `IndustryTypeImmutable` when a Company already exists with a different industry. `ExposedCompanyNameRepository.save` updates only the name (and a school id if one is given) for an existing Company; its KDoc and code never write `industry_type` on update. No route and no use case in EA updates `industry_type` after the insert.
- **No database guard:** `company_names.industry_type` is a plain `VARCHAR(20) NOT NULL DEFAULT 'GENERIC'`. Nothing in the schema stops an `UPDATE` by hand, or by a future code path, from changing it.
- **Default:** any Company registered before V13 (2026-09-20) holds `GENERIC`, whatever it really is. A school registered before industry types existed is recorded GENERIC and would be refused under the SOP rule (the data gate CM already holds).

## 5. The industry route and the SOP rule

`GET /api/internal/companies/{id}/industry` reads `company_names.industry_type`, the same record registration writes and `IndustryTypeImmutable` protects. The SOP rule that consumes it is not built yet (SOP's idempotency comes first), so today nothing enforces "ER's credential acts only in school Companies": the hand list `SOP_ER_COMPANY_IDS` is unset and the safe default is refuse-everywhere.

## 6. Production data and the V15 case: not answerable from code

The plan recorded on 2026-10-01 (CM's task list V15.1 to V15.8) scoped a read-only check and, if needed, a delete of the stray grant at the Prodeo Trading Company, gated on Femi's credential-split step (V15.1). **I find no evidence in the repositories that it was done**, and I cannot see production. The record at the time said Prodeo Capital and "xyz" were clean, Valiant's Hall legitimately holds the module, and Prodeo Trading held it wrongly. To settle it, one read-only query (run by CM with Femi) answers both directions at once:

```sql
-- Companies holding the module although EA records them as not a school
SELECT mam.company_id, cn.name, cn.industry_type, cn.school_id, COUNT(*) AS assignments
FROM membership_assignment_modules mam
LEFT JOIN company_names cn ON cn.company_id = mam.company_id
WHERE mam.module = 'EDUCATION_RUNTIME' AND cn.industry_type IS DISTINCT FROM 'SCHOOL'
GROUP BY mam.company_id, cn.name, cn.industry_type, cn.school_id;

-- Companies that look like schools but are recorded GENERIC (the data gate for the SOP rule)
SELECT company_id, name, industry_type, school_id FROM company_names
WHERE (school_id IS NOT NULL AND industry_type <> 'SCHOOL')
   OR (industry_type = 'SCHOOL' AND school_id IS NULL);
```
The second query also flags a SCHOOL Company with no school link (provisioning never completed). If the first returns rows, they are the stray grants; the correction is the verify-before, delete, verify-after sequence already written in the 2026-10-01 plan, run only with Femi's go.

## 7. Proposed fixes (none built; each is a proposal)

1. **Add-a-deny at the two grant paths** (invite and change-modules): refuse `EDUCATION_RUNTIME` unless the Company's recorded industry is `SCHOOL` (`422 module_not_allowed_for_industry`, nothing changed). It only adds a refusal, so it fits the freeze's carve-out; about 0.5 d with tests first (a school Company accepts it, a generic Company is refused, an unknown Company is refused, existing behaviour otherwise unchanged). It needs the Company's industry at the use-case level (the repository read already exists).
2. **Remove the latent trap**: make `defaultModulesFor(OWNER_ADMIN)` exclude `EDUCATION_RUNTIME`, or document and test that it is unreachable. About 0.1 d.
3. **A database guard for immutability**: a trigger or constraint that refuses an `UPDATE` of `company_names.industry_type`. A migration, so CM's review and apply order; about 0.25 d. Not urgent, because no code path writes it.
4. **A reconciliation check** (CM's drift job or a scheduled read): the two queries above, alerting when the first returns a row, so a stray grant is found within a day, not by chance.
5. **Data**: the correction for any stray grant and for school Companies recorded GENERIC, as reviewed data fixes, with Femi.

## 8. What I did not verify

Production data (everything in section 6); whether any other service writes module grants (only EA stores them; GL, POP, SOP, IM and HR mirror them read-only, which I checked earlier in the call inventory); ER's own refusal to act for a school EA did not provision (that is ER's to confirm, CM asked it).
