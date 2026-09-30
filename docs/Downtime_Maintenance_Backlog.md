# Downtime Maintenance Backlog

**Status:** living document, started 2026-09-30. Collects every fix
Femi has flagged as real but deliberately deferred to a planned downtime
window - things that can't be done live without either forcing a
destroy-and-recreate on a production AWS resource, or requiring a
service to stop querying its own database mid-rename. Nothing here has
a target date; this is a holding list, not a scheduled plan.

**Why one shared doc, not scattered notes:** these items span multiple
unrelated efforts (the Education Runtime rename, GL's own legacy naming)
and will likely keep accumulating one at a time as they're noticed -
better to have one place to check before/when a downtime window is
actually being planned, rather than hunting through several phase plans
and memory entries for "what did we defer."

**Relationship to go-live:** worth checking whether any of this coincides
with the eventual Development→Live security-hardening pass (see the
`project_development_to_live_switch` memory - Femi confirmed that switch
comes with its own dedicated security/data-safety plan) rather than
being a separate outage. Not decided either way yet.

---

## Items

| # | Item | Why it needs downtime | Source |
|---|---|---|---|
| 1 | Rename the `schooladmissions_production` Postgres database (name TBD, e.g. `education_runtime_production`) and update `SCHOOLADMISSIONS_DB_NAME`/its Terraform variable to match | `ALTER DATABASE ... RENAME TO ...` requires zero active connections - the service must stop querying it during the rename | `docs/SchoolAdmissions_To_EducationRuntime_Rename_Plan.md` Phase 8, direct instruction 2026-09-30 ("We will fix during downtime") |
| 2 | Rename GL's `fish_production` Postgres database to something GL-specific (e.g. `gl_production`) - "fish" is the whole platform's name, not GL's; every sibling service's database is already named after the service itself (`pop_production`, `sop_production`, `im_production`, `hr_production`, `ea_production`) except GL's own, a legacy holdover from before the platform had siblings | Same reason as item 1 - live database rename needs the service stopped | Direct instruction 2026-09-30 ("This is a legacy naming problem. It should be fixed when we have downtime") |

## Parked, not yet added here as a firm item

- Phase 4's own deferred list (`docs/SchoolAdmissions_To_EducationRuntime_Rename_Plan.md` Phase 8.3): whether to also rename the Education Runtime ECR repo, ECS service/task family, IAM roles, log group, and security group in the same window - lower priority than the database name since none of these are visible to a human operator day-to-day. Not decided whether these belong in this list at all or stay a separate, lower-priority question.

## Format for a new item

When Femi flags something else as "fix during downtime," add a row here
with: what needs to change, why it specifically needs downtime (not just
"it's risky" - the concrete technical reason, e.g. ForceNew replacement
or an active-connections requirement), and where the instruction came
from (a specific message, or a cross-referenced phase plan).
