# GL Engine — Production Readiness Plan

Turns `docs/GL_Production_Readiness_Assessment.md`'s 12 findings into a sequenced set of increments. That document was deliberately findings-only ("no severity-to-timeline mapping, no prescribed fix order... a findings record, not a build plan") — this is that separate, explicit next step, kept as its own document rather than mutating the findings record, so the two stay distinct: one is what's true about the codebase, this one is what to do about it.

**Re-verified against the current codebase before each revision of this plan, not assumed from the prior version.**

---

## Status as of 2026-08-26 (sixth revision)

Since the fifth revision: the actual reason the first manual deploy's database came up empty was found and fixed - `shadowJar` was silently clobbering Flyway's `META-INF/services` plugin registrations across dependency jars, so Flyway resolved zero migrations from the packaged fat jar (see item 7). Redeployed with the fix; **the Section 9 onboarding flow was then click-tested end-to-end for real** - sign-up, email confirmation, sign-in, the 3-step wizard, and a genuine `POST /tenants` call all the way through to a real Tenant ID, against the live production API. This is the first time any part of this system has been verified working end-to-end outside a test.

Since the fourth revision: GitHub Actions' root cause was found (account-level "Actions has been disabled for this user," support ticket filed), and **a real image is live in production for the first time** via a manual one-off deploy - see items 5 and 6 below. Three previously-latent bugs (Windows CRLF in `gradlew`, missing CORS, an immutable-tag assumption in the deploy step) were found and fixed along the way, none of which `terraform apply`/`plan` could ever have caught, since they only surface when an image actually gets built and pushed.

1. **Finding #3 (exception leak) is done and merged** (commit `adf293c`) — closes the first of the plan's three Critical items.
2. **CI itself was broken** — the `fish-common` submodule migration left `actions/checkout@v4` never fetching submodule content, so every commit since had been landing on a red `master` unnoticed (found via a fresh independent audit, not from the original assessment). Fixed (commit `01bb846`) and confirmed green end-to-end via an actual CI run, not assumed.
3. **Idempotency-key support was built** across every financial-posting endpoint (`RecordSale`/`RecordCollection`/`RecordPayRun`/`PostPayRun`/`PostPurchaseOrder`/`PostSalesOrder`/`PostJournalEntry`/`PostInventoryReceipt`/`PostInventoryIssue`/`RemeasureLeaveAccrual`/`UtilizeLeaveAccrual`) — a gap the original 12 findings didn't cover at all (they were infra/ops-focused; this is a financial-correctness gap the fresh audit surfaced), also committed in `adf293c` and confirmed via a live CI run including a new integration test against real Postgres.
4. **Finding #1 (CD pipeline) — built AND applied, 2026-08-26.** The deploy-target decision this plan flagged as un-guessable is resolved: AWS (already confirmed 2026-08-11, Section 10.19's "are we ready to deploy on AWS?"), ECS/Fargate specifically (confirmed 2026-08-22), region eu-west-2 (confirmed same day — Purse/UK is the near-term market). `infra/terraform/` (ECR, ECS cluster/service/task definition, ALB with a validated HTTPS certificate for `capital.theprodeogroup.com`, GitHub OIDC deploy role, RDS Postgres, Secrets Manager, CloudWatch Logs) plus a `deploy` job in `pipeline.yml` (auto-deploys to production on every push to `master` that passes `test`/`integration-test`/`docker-build`). **`terraform apply` genuinely succeeded against real AWS** — 27 resources live, GitHub Actions repository variables set and confirmed. See Phase 1b below for the full list of real gaps this surfaced along the way (missing IAM permissions, service-linked-role quirks, an RDS Free Tier constraint, a real DNS-topology mixup, an operational near-miss from force-killing a long apply). No staging environment — auto-deploy straight to production was the explicit choice over staging-then-promote, since no staging environment exists.
5. **CI itself stopped triggering entirely, discovered 2026-08-26 — separate from the Phase 1b build above.** After run #25 (2026-08-21 23:43, commit `b7d448d`), the `ci.yml` workflow (id `338476737`) stopped producing any run at all, on any trigger (push, a web-UI-direct commit, and a fresh PR all confirmed dead via the GitHub web UI — `gh run list`/`gh api` were separately found to be giving stale/wrong data all session and are not trustworthy for this). Re-registering the pipeline as `pipeline.yml` (commit `26e5656`) didn't fix it either. **Root cause found the same day**: manually invoking `workflow_dispatch` returned a direct API error - `"Actions has been disabled for this user."` - re-confirmed identically after a full machine reboot (ruling out any local cause). This is an account-level GitHub state (`prodeo-group-dev`), not a repo/workflow issue. A GitHub Support ticket is filed with this exact error. **CI/CD stays unverified via GitHub Actions itself until support re-enables it** - see item 6 for how a real deploy happened anyway.
6. **First real deploy done manually, 2026-08-26, as a stopgap while waiting on GitHub Support.** Docker Desktop installed locally (needed its own WSL2 install + a reboot to clear a stuck engine-startup socket lock), then a manual `docker build` / ECR push / `register-task-definition` / `update-service` - exactly what `pipeline.yml`'s `deploy` job does, just run by hand. **This was the first image ever pushed to this ECR repo**, which surfaced three real, previously-latent bugs nothing had ever exercised:
   - `gradlew` had CRLF line endings on Windows checkouts (`core.autocrlf`), breaking its shebang inside the Linux build container - GitHub's Linux runners never hit this. Fixed with `.gitattributes` (`text eol=lf`).
   - No CORS configuration existed anywhere - any browser-based caller (i.e. the new `fish-gl-web` frontend) would have been silently blocked regardless of request validity. Added (`localhost:5173`/`4173` always allowed for dev; `FISH_CORS_ALLOWED_ORIGIN` for wherever the frontend ends up hosted, not yet decided).
   - ECR's `imageTagMutability = IMMUTABLE` (deliberate, `ecr.tf`) means the `:latest` tag can only ever push successfully *once* - `pipeline.yml`'s deploy step would have failed on every deploy after the first, forever, completely independent of the Actions-disabled issue. `:latest` was unused downstream anyway (the task definition always references the specific `sha-<commit>` tag) - removed from the workflow entirely rather than worked around.

   The app is now live and responding at `https://capital.theprodeogroup.com/health` - the first time this has ever been true. The Terraform-operator IAM user was also granted ECR push permissions it never had before (it only ever managed the repository resource, never pushed images) - a real, ongoing grant, not cleaned up automatically.

7. **The database came up with zero tables after item 6's deploy - root cause found and fixed the same day.** `POST /tenants` 500'd with `relation "tenants" does not exist`. Traced (via CloudWatch logs, a throwaway local Postgres, and a methodical process of elimination - jar-vs-filesystem scanning, locale, encoding, JRE-vs-JDK base image, and a temporary Flyway version bump were all tested and ruled out one by one) to Gradle Shadow's fat-jar packaging: `flyway-core` and `flyway-database-postgresql` each ship `META-INF/services` files Flyway needs for its `ServiceLoader`-based plugin discovery (location resolvers, database-type handlers), and Shadow's default merge behavior is last-one-wins for same-named resources rather than concatenation - leaving Flyway's plugin registry completely empty in the packaged jar. Flyway 10.20.1 fails *silently* on this (logs a warning, skips every migration, and still reports `success: true`); bumping to Flyway 11 as a diagnostic (reverted once confirmed) made the same defect fail loudly instead, which is what made it legible enough to actually diagnose. Fixed with `mergeServiceFiles()` on the `shadowJar` task - Shadow's own documented fix for exactly this problem. `DatabaseMigrator` also now fails loudly if zero migrations resolve at all, a permanent guard against this whole class of failure recurring for any reason, not just this one - the old code's entire exposure was that nobody ever checked `migrate()`'s result. Redeployed; all 9 migrations applied, all 25 tables created, confirmed live.

   **Also surfaced, not yet fixed**: `DatabaseMigratorIntegrationTest` only ever asserted `result.success shouldBe true`, which is true even with zero migrations resolved - it never actually verified a table gets created, which is part of why this went undetected. A second, genuinely unrelated pre-existing bug also surfaced simply by finally running `integrationTest` this session: `TaxRepositoriesIntegrationTest`'s `RateStructure` round-trip fails a numeric-equality assertion (likely a `BigDecimal` scale mismatch in `rate_structure_encoding.kt`) - spun off separately, not investigated further here.

~~**One new, concrete risk this created**: idempotency-key support's own migration claimed `V7__idempotency_keys.sql`, colliding with PR #34's `V7__purchase_order_delivery_terms.sql`.~~ **Resolved** — PR #34 rebased to `V8` before merging, no Flyway collision.

---

## Phase 0 — ~~land what's already written~~ DONE

~~Finding #3 (exception messages leak to API clients)~~ — landed, see above. No longer an open item.

---

## Phase 1 — the two hard Criticals

The two findings that actually block calling this "production ready." 1b is now built (pending real-world verification); 1a is unchanged since the last revision — not started.

### 1a. Database-level tenant isolation (finding #2)

Postgres Row-Level Security + partitioning by `tenant_id` is the persistence strategy already on record — migrations V1–V9 contain zero `ROW LEVEL SECURITY`/`CREATE POLICY` statements. Isolation today is 100% application-layer (`Auth.kt`'s `verifyClaimedTenant`), with no defense-in-depth.

**Needs a decision before building, not a guess:**
- RLS via a session-level `SET app.current_tenant_id` per request (set once per connection checkout, policy reads it) vs. a Postgres role-per-tenant approach — the former is far more common with a connection-pooled app like this one (HikariCP), the latter doesn't fit a shared pool well. Worth confirming this is the intended shape before writing policies.
- Whether table partitioning by `tenant_id` (the other half of the "on record" strategy) is in scope now or a later scaling concern — RLS alone closes the isolation gap; partitioning is a performance/scale decision that can reasonably follow later without blocking this.

Once confirmed: a new migration adding `ENABLE ROW LEVEL SECURITY` + `CREATE POLICY` per tenant-scoped table, a `DatabaseConfig`/repository-layer change to set the session variable per request (likely in the Ktor auth pipeline, right after `verifyClaimedTenant` succeeds), and integration tests proving a query against the wrong tenant's data returns nothing even if application-layer logic were bypassed entirely.

### 1b. CD pipeline (finding #1) — DONE and APPLIED, 2026-08-26

CI used to stop at "the image builds." The deploy-target decision this section used to flag as un-guessable is now resolved, built, **and actually running in AWS**: ECS/Fargate, eu-west-2, `infra/terraform/` plus a `deploy` job in `pipeline.yml` that pushes to ECR and updates the ECS service via OIDC-authenticated GitHub Actions credentials, auto-deploying to production on every push to `master` that passes CI. **Caveat, 2026-08-26: this is what the pipeline does once it runs — whether it actually runs on push is a separate, still-open problem, see item 5 above.**

**`terraform apply` succeeded for real, 2026-08-26 — 27 resources created (23 original + 4 for RDS), 0 errors, verified against live AWS, not just a clean `plan`.** Getting there took several rounds of real, previously-invisible gaps surfacing only at `apply` time (`plan` doesn't fully simulate every IAM check `apply` actually makes):
- `ec2:DescribeVpcAttribute`, `acm:RequestCertificate` (missed entirely when `acm.tf` was first written), `ec2:DescribeInternetGateways`, `secretsmanager:GetResourcePolicy`, `elasticloadbalancing:DescribeListenerAttributes`/`ModifyListenerAttributes` — all missing permissions, fixed in `bootstrap-iam-policy.json` across several policy versions (each push needed a privileged identity, since the scoped Terraform-operator user correctly can't modify its own permissions).
- **A real operational mistake, caught and fixed, not hidden**: an early `apply` attempt appeared to hang on `aws_lb.this` with zero progress output for 40+ minutes — killed on the assumption it was stuck. It wasn't: the ALB (and separately, the Secrets Manager secret) had actually finished creating in AWS moments before the kill, just hadn't been written back to Terraform state yet, leaving both as real, billed resources orphaned from state. Fixed correctly via `terraform import` for the ALB and `secretsmanager restore-secret` + `terraform import` for the secret (which had gone into Secrets Manager's pending-deletion state as a side effect) — not by re-running `apply` blind and risking a duplicate-resource conflict. Lesson banked: don't force-kill a Terraform process without checking AWS directly first.
- **DNS validation surfaced a real infrastructure-topology gap outside this codebase**: the CNAME for ACM validation was added correctly by content but in the wrong system twice in a row — first in cPanel's Zone Editor, then (still not working) in what turned out to also not be the right place, before landing correctly in Namecheap's own **Advanced DNS** tab. `theprodeogroup.com`'s authoritative nameservers (`dns1/dns2.registrar-servers.com`, confirmed via direct nameserver queries, not assumed) are Namecheap's own DNS service — a genuinely different system from cPanel's Zone Editor, which manages a separate zone tied to hosting. Diagnosed by querying the authoritative nameserver directly rather than trusting propagation-delay assumptions.
- **ECS's service-linked role auto-creation didn't work via its normal implicit path even with correct IAM permissions** — `ecs:CreateService`'s internal `AWSServiceRoleForECS` auto-creation kept failing with the same error across two different permission-policy shapes (resource-scoped-with-condition, then wildcarded). Root-caused by calling `iam:create-service-linked-role` directly (which worked immediately, proving the IAM permission itself was fine) — the role now existing was enough for the next `apply` to succeed normally. The underlying "why doesn't ECS's own internal auto-creation path work the same way" is still unexplained, but no longer blocking.

**Database provisioning closed and applied, 2026-08-26** — previously the
one deliberately-out-of-scope item, now built (`rds.tf`): a real RDS
Postgres instance (`db.t4g.micro`, single-AZ, 20GB gp3), the master
password a `random_password` resource generated once and never typed
into a `-var` flag, `db_host` no longer a variable at all (it's
`aws_db_instance.this.address`, computed). Two more real `apply`-time
gaps, same pattern as everything above: a third instance of the
service-linked-role issue (`rds.amazonaws.com` this time, same direct-
creation fix), and a genuine account-level constraint — this AWS
account is on RDS Free Tier, which capped backup retention at 1 day
instead of the originally-configured 7 (`FreeTierRestrictionError`, not
a design choice). Also surfaced a real, generalizable gotcha in `ecs.tf`'s
`ignore_changes` lifecycle rule: changing `FISH_DB_HOST` from a variable
to the new RDS address didn't update the already-existing task
definition on a plain `apply` (`ignore_changes` treats that attribute as
always matching state) — needed `terraform apply
-replace=aws_ecs_task_definition.this` to force a new revision with the
real value in. Only matters for this specific already-applied instance;
a fresh account provisioning RDS from the first `apply` never hits it.

**What's genuinely still open, not glossed over:**
- **The ECS task is not yet healthy** — the task definition's latest revision now has the real DB host/password, but still points at ECR's placeholder `bootstrap` image tag, and JWT config is still `dummy-idp.example.com` (no real IdP exists yet). The service exists and is correctly configured, but nothing real is running behind it yet — that's expected, and matches this document's own "first real deploy comes from CI" note.
- **No rollback tooling beyond "redeploy an older image tag by hand"** — ECR's lifecycle policy keeps the last 20 tagged images, so a rollback target exists, but there's no one-click/automated rollback mechanism.
- **The GitHub Actions repository variables are set** (2026-08-26, via `gh variable set`, confirmed via `gh variable list`) — `AWS_REGION`, `AWS_DEPLOY_ROLE_ARN`, `ECR_REPOSITORY`, `ECS_CLUSTER`, `ECS_SERVICE`, `ECS_TASK_DEFINITION_FAMILY`, `ECS_CONTAINER_NAME` all confirmed live on `prodeo-group-dev/fish-fish-gl-engine`. A push to `master` is the only remaining step for the first real deploy.
- **No staging environment** — auto-deploy straight to production was the explicit, confirmed choice for now.

---

## Phase 2 — High findings, buildable without new decisions

Everything in this phase can be built against the current codebase with no external decision needed first.

- **Finding #6 — `/health` depth.** Smallest item in the whole plan: add a real Postgres connectivity check (a trivial `SELECT 1` against the pool) to `HealthRoutes.kt`, returning 503 if it fails. Confirmed still shallow (`{"status": "ok"}`, no DB check) - unchanged since the last revision.
- **Finding #4 — structured logging.** Add `logback.xml` to `src/main/resources`: JSON encoder (for a log aggregator), per-environment level via env var, and a request-correlation-ID field (Ktor's `CallId` plugin generates/propagates one, then it needs threading into the MDC for Logback to pick up).
- **Finding #5 — metrics.** Micrometer + a Prometheus scrape endpoint (`io.ktor:ktor-server-metrics-micrometer`) is the standard low-effort win: request latency/count/error-rate and JVM metrics essentially for free. OpenTelemetry tracing is a heavier lift (needs a collector target decided) — worth splitting this into "Micrometer now, OTel later" rather than one increment.
- **Finding #7 — rate limiting / CORS / request size limits.** The deploy topology is now known (ALB in front of ECS/Fargate, `infra/terraform/alb.tf`) — an ALB does basic request routing but no rate limiting/CORS/WAF-style filtering on its own, so this still needs building at the app layer (Ktor's own `RateLimit`/`CORS` plugins), not skippable as "redundant with infra" the way it might have been with an API Gateway in front instead.

---

## Phase 3 — Medium findings, cheap and mechanical

All four of these are small, self-contained, and don't block on any external decision — good filler increments or a single "operational hardening" batch. Confirmed still unbuilt: no `dependabot.yml`, no HikariCP tuning beyond `maximumPoolSize`, no graceful-shutdown handling.

- **Finding #8 — HikariCP tuning.** Add `connectionTimeout`, `idleTimeout`, `leakDetectionThreshold` to `database_config.kt`'s existing `HikariConfig` block. Minutes of work.
- **Finding #11 — graceful shutdown.** Ktor/Netty supports this via `ShutDownUrl.EngineMain` or wiring `Runtime.addShutdownHook` to `NettyApplicationEngine.stop(gracePeriodMillis, timeoutMillis)` — small, mechanical.
- **Finding #9 — dependency-vulnerability scanning.** A Dependabot config (`.github/dependabot.yml` watching Gradle) is close to free and needs no code change at all.
- **Finding #10 — backup/DR documentation.** Pure documentation, not code — was deferred pending the managed-database choice, which is now made: RDS Postgres, 1-day automated backups (capped by this AWS account's Free Tier status, not a design choice - see 1b above), `skip_final_snapshot = true`/`deletion_protection = false` (correct only while no real data exists). Unblocked now - still not written.

**Finding #12 — API versioning** is the one Medium item deliberately *not* in this "cheap" bucket: it's mechanical in isolation (`/v1` prefix on `routing { ... }`), but POP/SOP/IM/HR are now real external callers already depending on the current unprefixed contract. Introducing `/v1` needs coordinating a matching change across every consumer repo's own gateway (`KtorGlEngineGateway` in SOP and now HR), not just this repo — sequence it after the consumer set stabilizes, not opportunistically alongside the others.

---

## Suggested build order

1. ~~Phase 0~~ — done.
2. ~~Resolve the V7 migration collision~~ — done.
3. ~~Finding #1 / Phase 1b (CD pipeline)~~ — built 2026-08-22, unverified against real AWS. Running `terraform apply` and confirming a live deploy is the natural next pickup, not a fresh increment.
4. Finding #6 (`/health` depth) — smallest remaining real increment.
5. Finding #8 + #11 (HikariCP tuning + graceful shutdown) — small, pair naturally as "operational hardening."
6. Finding #9 (Dependabot) — no code, just config.
7. Finding #4 + #5 (logging + metrics) — pair naturally as "observability," moderate size.
8. Decide the RLS session-variable approach (unblocks #1a) — the one remaining decision gating "production ready."
9. Build 1a (RLS) once its decision lands.
10. Finding #7 (rate limiting/CORS) — the deploy topology is now known (ALB, no API Gateway), so this is buildable now, not blocked.
11. Finding #10 (backup/DR docs) — unblocked, database hosting choice made (RDS, 2026-08-26). Still not written.
12. Finding #12 (API versioning) once the consumer set (POP/SOP/IM/HR) stabilizes — deliberately last, needs cross-repo coordination.
