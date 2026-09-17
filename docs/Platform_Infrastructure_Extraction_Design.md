# Platform Infrastructure Extraction — Design Note

Status: **design-only, nothing moved yet**. Scopes pulling the shared
Terraform project out of `GL/infra/terraform/` into its own repo, per the
user's own framing: GL's repo shouldn't have to "conflate with things that
have to do with GL" — i.e., GL's own application code shouldn't carry the
operational detail of five sibling services it has nothing to do with
functionally. Same reasoning this project already applied to POP, SOP, IM,
HR, and EA (`docs/Ecosystem_Extraction_DDD_Design.md`,
`docs/Tenancy_Administration_Extraction_DDD_Design.md`) — GL's sole purpose
is financial effect, never operational detail, and that boundary currently
stops at application code. It doesn't extend to infrastructure, which is
the actual inconsistency this closes.

## Confirmed current state

`GL/infra/terraform/` is 29 `.tf` files, ~5,700 lines, provisioning
infrastructure for **all six live services plus shared platform pieces**,
not just GL:

- Per-service: `ea.tf`, `pop.tf`, `sop.tf`, `im.tf`, `hr.tf` (ECS
  services/task definitions, ALB target groups/listener rules, ACM certs,
  service-account credentials) alongside GL's own equivalents split across
  `ecs.tf`/`alb.tf`/`acm.tf`.
- Shared, not owned by any one service: `network.tf` (VPC), `ecs.tf` (the
  one shared ECS cluster every service runs on), `rds.tf` (the one shared
  RDS instance, one logical database per service), `cognito.tf` (the one
  shared User Pool), `jenkins.tf` (the self-hosted CI/CD box every
  service's own `Jenkinsfile` deploys through), `frontend.tf` (`WEB`'s
  CloudFront/S3), `ecr.tf`, `iam.tf`, `secrets.tf`, `notifications.tf`,
  `github_runner.tf` (declared, never applied - see below).

**State is local, not remote** — `versions.tf` already documents this as a
known, deliberate-for-now limitation ("move to a remote backend (S3 +
DynamoDB lock table)" flagged, not done). `terraform.tfstate` is gitignored
and exists only on whichever machine last ran `terraform apply` — it has
never been committed anywhere. This actually simplifies an extraction: there
is no git history of state to preserve, only a file to relocate alongside
the `.tf` files.

**No service's own `Jenkinsfile` depends on `.tf` files being present.**
Confirmed this session: every deploy stage calls `aws ecr`/`aws ecs`
directly by hardcoded resource name/ARN — none use
`terraform_remote_state` or read anything from the Terraform project at
apply time. Moving `infra/terraform/` out of `GL/` doesn't touch any
service's deploy pipeline.

## Proposed scope

A new repo (name open — `fish-infrastructure` or `fish-platform-infra`),
added as a ninth `FiSH/` submodule, containing the entire current
`infra/terraform/` directory verbatim: all 29 `.tf` files, the local state
file (relocated, not recreated — same AWS resource IDs, same ARNs, nothing
re-provisioned), and the gitignore/backend-config conventions already
established.

**One shared repo, not six per-service ones.** Unlike POP/SOP/IM/HR/EA's
own extractions (each got its own repo because each is an independently
deployable service), the infrastructure here is genuinely cross-cutting —
one RDS instance, one ECS cluster, one ALB, one Cognito pool, one Jenkins
box — shared *by* all six services. Splitting it per-service would fragment
a resource graph that's actually one interconnected thing (e.g., every
service's ALB listener rule and target group already lives beside every
other service's in `alb.tf`-equivalent files) into arbitrary pieces with
cross-repo references between them, trading one coupling problem for a
worse one.

**What stays in `GL/`:** nothing infrastructure-related. `GL/CLAUDE.md`'s
own AWS-agent guidance already documents this project's Terraform/Jenkins
conventions in prose; that guidance would need a light update to point at
the new repo location rather than `GL/infra/terraform/`, but the guidance
content itself doesn't change.

## Open questions (not resolved here)

- **Repo name and exact scope boundary** — does `pitch_basic_auth.tf` (a
  Prodeo Capital pitch-deck concern, not a GL/EA/POP/SOP/IM/HR one) and
  `claude_readonly.tf`/`fish_gl_engine_terraform_permissions.tf` (AI-agent
  operational access, not service infra) belong in the same repo, or is
  there a second, narrower split hiding inside this one? Flagged, not
  picked.
- **CI/CD for the infra repo itself** — every service repo has its own
  Jenkins pipeline; does this new repo get one too (auto-`plan` on PR, at
  minimum, given how easy it's been this session to introduce silent drift
  without one), or does it stay manual-apply-only, matching today?
- **Remote state backend** — this extraction is a natural moment to also
  close the already-flagged local-state gap (`versions.tf`'s own comment),
  since a shared infra repo with local-only state is a worse single point
  of failure than GL owning it was. Worth deciding together, not
  necessarily in the same change.
- **Migration mechanics** — a plain file move plus updating `FiSH/`'s
  `.gitmodules`/submodule pointer, or something more careful given the
  state file's size (~500KB) and the number of already-open questions
  above. Sequencing (new repo first vs. resolving the questions above
  first) not decided.

## Explicitly not done in this note

No files moved, no new repo created, no `.gitmodules` change, no state
file relocated. This is a scoping pass only, matching how every other
extraction in this project started.
