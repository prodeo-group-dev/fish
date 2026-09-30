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
- Not yet decided: the actual new DNS subdomain string (current live
  domain is `school-api.theprodeogroup.com` - needs a real replacement
  value before Phase 4 can execute, e.g. something under
  `education-runtime` or `edu-runtime`).

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
| 0.3 | New DNS subdomain string | **Open** - needs a real value before Phase 4 |
| 0.4 | Cutover strategy: hard cutover vs. a transition window running both old (`school-api...`) and new DNS names live simultaneously | **Open** - recommend a transition window (matches the low-risk pattern GL/POP/IM/SOP already use for their own rollouts), but this is a real call the user should make given it affects live integrations (SOP's Guardian-as-Customer flow, EA's provisioning callback) |
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
| 3.1 | `Jenkinsfile`: `ECR_REPOSITORY`, `ECS_SERVICE`, `ECS_TASK_DEFINITION_FAMILY`, `ECS_CONTAINER_NAME`, Docker image tags (`fish-school-admissions:ci` → `fish-education-runtime:ci`), CI Postgres env var names (`SCHOOLADMISSIONS_DB_*` → `EDUCATIONRUNTIME_DB_*`) | Phase 4 (new AWS resources must exist under the new names before this can actually build/deploy against them) |
| 3.2 | Jenkins' own job configuration (the job itself, not just the in-repo `Jenkinsfile`) - CM's territory, same as any Jenkins naming change | 3.1, CM |

---

## Phase 4 — Infrastructure (Terraform/DNS) - highest risk, CM-owned

**This is the phase that can cause real data loss or downtime if done
carelessly.** A naive rename of a Terraform resource's name in the `.tf`
file (rather than a proper `terraform state mv`) makes Terraform plan a
destroy-and-recreate - for the Secrets Manager secret and the ECS
service specifically, that risks losing the live DB password secret or
causing real downtime on a service with real school data flowing through
it.

| # | Task | Depends on |
|---|---|---|
| 4.1 | Decide the new DNS subdomain string (0.3) | 0.3 |
| 4.2 | For each of the following resources in `schooladmissions.tf`, use `terraform state mv` (never a bare rename-and-apply) and review the `plan` output shows no destroy before applying: `aws_ecr_repository`, `aws_ecr_lifecycle_policy`, `aws_acm_certificate` (+ `_validation`), `aws_iam_role` ×2 (+ `_managed`/`_secrets` policy attachments), `aws_secretsmanager_secret` (+ `_version`), `aws_cloudwatch_log_group`, `aws_lb_target_group`, `aws_lb_listener_rule`, `aws_lb_listener_certificate`, `aws_security_group`, `aws_ecs_task_definition`, `aws_ecs_service` | 4.1, CM |
| 4.3 | Rename the 4 dedicated `.tf` files themselves (`schooladmissions.tf` → `education_runtime.tf`, etc.) - a file rename, not a resource rename, so no `state mv` needed for this part, but do it in the same change as 4.2 to avoid two review passes | 4.2 |
| 4.4 | Update cross-referencing files that mention `schooladmissions`-named resources/variables: `buzzme.tf`, `ea.tf`, `jenkins.tf`, `outputs.tf`, `rds.tf`, `sop.tf`, `variables.tf` | 4.2 |
| 4.5 | Provision the new ACM cert + Route53 record for the new domain (0.3/4.1) - can happen in parallel with 4.2 if the cutover strategy (0.4) is a transition window, since the old domain keeps serving during this | 4.1 |
| 4.6 | Discard the 3 stale `.tfplan` cache files (`schooladmissions-scoped.tfplan`, `schooladmissions-secrets-fix.tfplan`, `schooladmissions-sop.tfplan`) - these are point-in-time plan artifacts, not live state; confirm they're safe to remove rather than assuming | none, can run any time |
| 4.7 | Retire the old domain/DNS record once the transition window (0.4) ends and every consumer (Phase 5) has cut over | Phase 5 complete, 0.4's chosen window elapsed |

---

## Phase 5 — Downstream consumers (EA, SOP, WEB)

Depends on Phase 4's new domain existing (can start coding against it
once 4.5 lands, even before 4.7 retires the old one - this is exactly
what a transition window buys).

| # | Task | Depends on |
|---|---|---|
| 5.1 | **EA**: rename `infrastructure/schooladmissions/` package → `infrastructure/educationruntime/` (`ktor_school_admissions_gateway.kt`, `school_admissions_gateway.kt`); update `RegisterCompanyUseCase.kt`, `repositories.kt` (naming only, logic unchanged); update `Application.kt`'s base-URL env var to point at the new domain; update `Dtos.kt` comments; rename/update the 3 touched test files | 4.5 |
| 5.2 | **SOP**: update `ea_dtos.kt`/`ea_membership_gateway.kt` comments referencing the old name; `Application.kt`'s service-account/base-URL naming; `Auth.kt`, `VerifiedIdentity.kt`; rename test file `SchoolAdmissionsServiceJwtSupport.kt` → `EducationRuntimeServiceJwtSupport.kt` | 4.5 |
| 5.3 | **WEB**: rename `api/schoolAdmissions.ts` → `api/educationRuntime.ts`; update imports in `AdmissionsTab.tsx`, `StudentManagementConsole.tsx`, `TimetableGrid.tsx`, `me.ts`; update `config.ts`'s API base URL constant to the new domain | 4.5 |
| 5.4 | Coordinated deploy of 5.1-5.3 together (same shape as POP's own WEB cutover, `ceb4dc1`) - these three need to land in the same rollout window, not independently, since EA/SOP need to agree on the URL WEB calls and the URL the renamed service itself answers on | 5.1, 5.2, 5.3 |

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

- **Can start immediately, fully reversible, no coordination needed**: Phase 1 (internal code rename).
- **Needs 0.3 decided first**: everything from Phase 4 onward.
- **Needs CM specifically**: Phase 3.2 (Jenkins job config), all of Phase 4 (Terraform/DNS), and the actual push/deploy of every phase per the platform's "only CM pushes" convention.
- **Genuinely independent of the rest**: Phase 7 (product naming).
