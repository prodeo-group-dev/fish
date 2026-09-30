# SchoolAdmissions → Education Runtime Rename: Dependency-Ordered Plan

**Status:** design/scoping only, 2026-09-30 - nothing executed yet, per
direct instruction ("Just scope it out for now, don't touch anything
yet"). This is the task breakdown requested as a follow-on to that scope.

**Naming decided, direct instruction 2026-09-30:**
- **Repo/code**: `SchoolAdmissions` → **Education Runtime** (repo
  `fish-school-admissions` → `fish-education-runtime`, package
  `com.theprodeogroup.schooladmissions` → `com.theprodeogroup.educationruntime`,
  submodule path `ER/Principal/SchoolAdmissions` →
  `ER/Principal/EducationRuntime`).
- **Product name**: **Principal's EduSys** - supersedes "The Principal"
  alone. This is a branding/copy change, not a code-identifier change (no
  code anywhere used "The Principal" as an identifier) - tracked as its
  own independent phase (7) below, not gating the technical rename.
- **DNS, decided 2026-09-30: keep `school-api.theprodeogroup.com` as-is.**
  No domain change, no new ACM cert, no DNS cutover/transition window -
  only the AWS resource *names* underneath it change (ECR repo, ECS
  service/task-definition, IAM roles, etc.), not the live endpoint URL
  itself. This removes the entire DNS/ACM half of Phase 4 and the
  cutover-window question (0.4) that depended on it.

**Scope note:** this plan lives at the `FiSH/` top level (not
`docs/GL_POP_IM_SOP_Backlog.md`) because it spans EA/SOP/WEB/Infrastructure/
the target repo itself, not the GL/POP/IM/SOP cluster that backlog is
deliberately scoped to.

**Ownership**: per the platform's own coordination convention, Phase 4
(Infrastructure/Terraform/DNS) and any actual `git push`/deploy at any
phase route through CM - no session pushes anything itself. The
`ER/Principal/SchoolAdmissions/COORDINATION.md` row-claim protocol applies
throughout, same as any other non-trivial change to this repo.

---

## Phase 0 — Decisions to lock before any execution

| # | Decision | Status |
|---|---|---|
| 0.1 | Final repo/package name | **Decided**: `fish-education-runtime` / `com.theprodeogroup.educationruntime` |
| 0.2 | Final product name | **Decided**: "Principal's EduSys" |
| 0.3 | New DNS subdomain string | **Decided: no change.** `school-api.theprodeogroup.com` stays as the live endpoint - only the AWS resource names underneath it are renamed. |
| 0.4 | Cutover strategy (DNS transition window) | **Moot** - no longer applies now that 0.3 keeps the domain unchanged. No ACM/DNS work in Phase 4 at all; EA/SOP/WEB (Phase 5) don't need any base-URL config change either, since the endpoint they call never moves. |
| 0.5 | Whether to rename already-applied Flyway migration filenames (e.g. EA's `V16__company_school_id.sql`) | **Recommend: no** - renaming an already-run migration file is a separate, unrelated risk (Flyway tracks migrations by checksum/filename in its history table) with no real benefit; leave historical migration files alone regardless of the service's new name |
| 0.6 | Whether the GitHub repo rename happens before or after the internal code rename | Recommend: internal code rename first (Phase 1, fully reversible, no external dependency), GitHub rename second (Phase 2) - GitHub auto-redirects the old URL, so this ordering doesn't block anything |

---

## Phase 1 — Internal code rename (self-contained, no cross-repo or infra impact)

Entirely within the target repo. No deploy, no DNS change, no consumer
impact - the service's own HTTP surface and behavior are unchanged, only
its internal Kotlin package names and build identifiers.

| # | Task | Depends on |
|---|---|---|
| 1.1 | Rename package directory `com/theprodeogroup/schooladmissions/` → `.../educationruntime/` across all 126 `.kt` files (10 sub-packages: `application`, `domain.{admissions,assessment,attendance,billing,classroom,curriculum,fees,platform,staff}`, `infrastructure`) - update every file's own `package`/`import` lines | 0.1 |
| 1.2 | `settings.gradle.kts`: `rootProject.name` → `fish-education-runtime` | 0.1 |
| 1.3 | `build.gradle.kts`: `group` → `com.theprodeogroup.educationruntime`, `mainClass` → the moved `ApplicationKt` | 1.1 |
| 1.4 | Repo's own `README.md`/`COORDINATION.md` - update self-references | 1.1 |
| 1.5 | Full test suite run (`./gradlew test`) to confirm the rename didn't break anything - purely mechanical, but 126 files is enough surface area to verify, not assume | 1.1-1.4 |

**Not in this phase**: `Jenkinsfile` identifiers (Phase 3) and anything
in other repos (Phase 5) - those depend on the GitHub rename (Phase 2)
and/or new infra (Phase 4) existing first.

---

## Phase 2 — GitHub repo rename

| # | Task | Depends on |
|---|---|---|
| 2.1 | Rename `fish-school-admissions` → `fish-education-runtime` on GitHub (auto-redirects old clone/fetch URLs, low risk) | Phase 1 complete and merged |
| 2.2 | `FiSH/.gitmodules`: submodule `path` and `url` updated to `ER/Principal/EducationRuntime` / the new repo URL | 2.1 |
| 2.3 | Every existing local checkout of `FiSH/` needs `git submodule sync` + re-init after 2.2 lands - worth a note in the PR/commit, not just silently breaking other sessions' checkouts | 2.2 |

---

## Phase 3 — CI identifiers (Jenkinsfile, within the renamed repo)

| # | Task | Depends on |
|---|---|---|
| 3.1 | `Jenkinsfile`: `ECR_REPOSITORY`, `ECS_SERVICE`, `ECS_TASK_DEFINITION_FAMILY`, `ECS_CONTAINER_NAME`, Docker image tags (`fish-school-admissions:ci` → `fish-education-runtime:ci`), CI Postgres env var names (`SCHOOLADMISSIONS_DB_*` → `EDUCATIONRUNTIME_DB_*`) | Phase 4 (the underlying AWS resources are renamed in place via `terraform state mv`, not newly created - but this still must land in the same change as Phase 4, since the Jenkinsfile's names must match whatever the renamed resources are actually called) |
| 3.2 | Jenkins' own job configuration (the job itself, not just the in-repo `Jenkinsfile`) - CM's territory, same as any Jenkins naming change | 3.1, CM |

**Correction found during Phase 4's actual execution, 2026-09-30, parked rather than fixed (direct instruction - not a live problem yet):**
this task's premise ("the Jenkinsfile's names must match whatever the renamed
resources are actually called") is wrong. Phase 4 only renamed Terraform
*identifiers* via `state mv` - the literal AWS-side name/family strings
(ECR repo name, ECS service name, task family, IAM role names, log group
name, security group name) are still `fish-school-admissions`-styled and
were deliberately left untouched, since all of those are `ForceNew`
attributes in the AWS provider and literally renaming them would force
destroy+recreate on a live production service (real downtime, real risk of
losing the live DB password secret) - which would violate 4.1's own
explicit "no destroy" requirement. Confirmed empirically: a scoped
`terraform plan` across all 40 renamed resources returned "No changes."
**So when Phase 3.1 is actually picked up: `ECR_REPOSITORY`/`ECS_SERVICE`/
`ECS_TASK_DEFINITION_FAMILY`/`ECS_CONTAINER_NAME` should keep pointing at
the SAME literal AWS names as today (still `fish-school-admissions`-styled)
- only rename Jenkinsfile identifiers/variable names if desired for
readability, never the string values that must match real AWS resource
names.** Docker image tags and CI Postgres env var names are unaffected by
this correction (those aren't AWS resource identities).

---

## Phase 4 — Infrastructure (Terraform) - highest risk, CM-owned

**Simplified by 0.3's decision to keep the live domain unchanged** - this
is now purely an internal resource-naming cleanup, not a DNS/ACM cutover.
The certificate resources still get their Terraform *identifier* renamed
(for consistency with the rest of the file), but their `domain_name`
argument value stays `school-api.theprodeogroup.com` - no new cert is
issued, no Route53 change, no consumer-facing URL ever moves.

**Still the phase that can cause real data loss or downtime if done
carelessly.** A naive rename of a Terraform resource's name in the `.tf`
file (rather than a proper `terraform state mv`) makes Terraform plan a
destroy-and-recreate - for the Secrets Manager secret and the ECS
service specifically, that risks losing the live DB password secret or
causing real downtime on a service with real school data flowing through
it. This risk is unchanged by 0.3's decision - it's about the resource
*names* in state, not the domain.

| # | Task | Depends on |
|---|---|---|
| 4.1 | For each of the following resources in `schooladmissions.tf`, use `terraform state mv` (never a bare rename-and-apply) and review the `plan` output shows no destroy before applying: `aws_ecr_repository`, `aws_ecr_lifecycle_policy`, `aws_acm_certificate` (+ `_validation`), `aws_iam_role` ×2 (+ `_managed`/`_secrets` policy attachments), `aws_secretsmanager_secret` (+ `_version`), `aws_cloudwatch_log_group`, `aws_lb_target_group`, `aws_lb_listener_rule`, `aws_lb_listener_certificate`, `aws_security_group`, `aws_ecs_task_definition`, `aws_ecs_service` | CM |
| 4.2 | Rename the `schooladmissions_domain_name` variable identifier in `variables.tf` for consistency - **its default value stays `school-api.theprodeogroup.com` unchanged** | 4.1 |
| 4.3 | Rename the 4 dedicated `.tf` files themselves (`schooladmissions.tf` → `education_runtime.tf`, etc.) - a file rename, not a resource rename, so no `state mv` needed for this part, but do it in the same change as 4.1 to avoid two review passes | 4.1 |
| 4.4 | Update cross-referencing files that mention `schooladmissions`-named resources/variables: `buzzme.tf`, `ea.tf`, `jenkins.tf`, `outputs.tf`, `rds.tf`, `sop.tf`, `variables.tf` | 4.1, 4.2 |
| 4.5 | Discard the 3 stale `.tfplan` cache files (`schooladmissions-scoped.tfplan`, `schooladmissions-secrets-fix.tfplan`, `schooladmissions-sop.tfplan`) - these are point-in-time plan artifacts, not live state; confirm they're safe to remove rather than assuming | none, can run any time |

---

## Phase 5 — Downstream consumers (EA, SOP, WEB)

**Simplified by 0.3's decision.** Since the live domain never changes,
none of these three need a base-URL/env-var/config change and none of
them are coupled to each other's timing - each is a pure identifier
rename (package/file/comment names), independently deployable, with zero
functional or wiring impact. No coordinated rollout window needed the way
an actual URL change would require (contrast POP's own WEB cutover,
`ceb4dc1`, which genuinely did need EA/SOP/WEB to agree on a new URL
shape at the same time - that's not this).

| # | Task | Depends on |
|---|---|---|
| 5.1 | **EA**: rename `infrastructure/schooladmissions/` package → `infrastructure/educationruntime/` (`ktor_school_admissions_gateway.kt`, `school_admissions_gateway.kt`); update `RegisterCompanyUseCase.kt`, `repositories.kt` (naming only, logic unchanged); update `Dtos.kt` comments; rename/update the 3 touched test files | 2.1 (repo renamed, so references make sense) |
| 5.2 | **SOP**: update `ea_dtos.kt`/`ea_membership_gateway.kt` comments referencing the old name; `Auth.kt`, `VerifiedIdentity.kt`; rename test file `SchoolAdmissionsServiceJwtSupport.kt` → `EducationRuntimeServiceJwtSupport.kt` | 2.1 |
| 5.3 | **WEB**: rename `api/schoolAdmissions.ts` → `api/educationRuntime.ts`; update imports in `AdmissionsTab.tsx`, `StudentManagementConsole.tsx`, `TimetableGrid.tsx`, `me.ts` (`config.ts`'s API base URL constant value is unchanged - only rename it if its own identifier name references "school") | 2.1 |

**Confirmed clean, 2026-09-30: GL, HR, POP, and IM need zero changes.**
The original scoping grep (exact strings) found no matches in any of the
four; POP and IM each independently re-ran a broader, case-insensitive
sweep (`school`/`admissions`/`principal`/`education-runtime` and
variants, not just exact strings) across their own `src`, `Jenkinsfile`,
docs, and gradle files and confirmed every hit was a false positive -
spot-checked directly, not just taken on their word:
- A historical Jenkinsfile comment attributing a shared Docker
  container-naming bug fix to "SchoolAdmissions' PR #3" (both POP and IM
  have this identical comment) - narrative only, no functional link.
- `EaCompanySummaryDto.schoolId` (POP/IM's own copy) - EA's generic
  Company-metadata field, populated for any School-type Company
  regardless of provisioning source; an opaque passthrough, never a
  direct call to the SchoolAdmissions service.
- Ktor's own `io.ktor.server.auth.Principal` framework class - pure
  string coincidence with "principal" the word, unrelated to The
  Principal product.

Worth noting: IM's own `Auth.kt` KDoc (written 2026-09-29, unrelated to
this rename) already says "Education Runtime" rather than
"SchoolAdmissions" when describing a scenario - one spot already using
the target terminology organically.

---

## Phase 6 — Docs

| # | Task | Depends on |
|---|---|---|
| 6.1 | Update the 15 files across `FiSH/docs/`, `CLAUDE.md`, and `ER/Principal/`'s own docs that name "SchoolAdmissions" directly, to the new name - lowest risk, do last so docs describe the final, actually-shipped state rather than a still-in-progress rename | Phases 1-5 substantially complete |

---

## Phase 7 — Product naming ("Principal's EduSys")

Independent track - no code identifiers change from this alone (nothing
in the code used "The Principal" as an identifier). Can run in parallel
with any of the phases above, or entirely separately on its own timeline.

| # | Task | Depends on |
|---|---|---|
| 7.1 | Update user-facing copy/branding wherever "The Principal" appears as a product name (WEB UI copy, docs, any pitch/marketing material) to "Principal's EduSys" | 0.2 (decided) |

---

## Summary: what can start today vs. what's blocked

All decisions in Phase 0 are now made (0.1/0.2 direct instruction, 0.3
"no need, school-api is good" - keep the live domain unchanged, 0.4 moot
as a result, 0.5/0.6 recommendations). Nothing is blocked on an open
decision any more - only on sequencing and on CM's availability for the
infra-touching phases.

- **Can start immediately, fully reversible, no coordination needed**: Phase 1 (internal code rename).
- **Needs CM specifically**: Phase 3.2 (Jenkins job config), all of Phase 4 (Terraform resource renames via `state mv`), and the actual push/deploy of every phase per the platform's "only CM pushes" convention.
- **Phase 5 (EA/SOP/WEB) is now low-risk and independently deployable per-repo** - simplified by 0.3, since no base URL/config ever changes, only identifiers.
- **Genuinely independent of the rest**: Phase 7 (product naming) - can happen any time, including right now.
