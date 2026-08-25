# GL Engine — Production Readiness Plan

Turns `docs/GL_Production_Readiness_Assessment.md`'s 12 findings into a sequenced set of increments. That document was deliberately findings-only ("no severity-to-timeline mapping, no prescribed fix order... a findings record, not a build plan") — this is that separate, explicit next step, kept as its own document rather than mutating the findings record, so the two stay distinct: one is what's true about the codebase, this one is what to do about it.

**Re-verified against the current codebase before each revision of this plan, not assumed from the prior version.**

---

## Status as of 2026-08-22 (third revision)

Since the second revision: the V7 migration collision was resolved (PR #34 rebased to `V8`, merged), and **Phase 1b (CD pipeline, finding #1) is now built** — see below. Nothing else in this plan has moved.

1. **Finding #3 (exception leak) is done and merged** (commit `adf293c`) — closes the first of the plan's three Critical items.
2. **CI itself was broken** — the `fish-common` submodule migration left `actions/checkout@v4` never fetching submodule content, so every commit since had been landing on a red `master` unnoticed (found via a fresh independent audit, not from the original assessment). Fixed (commit `01bb846`) and confirmed green end-to-end via an actual CI run, not assumed.
3. **Idempotency-key support was built** across every financial-posting endpoint (`RecordSale`/`RecordCollection`/`RecordPayRun`/`PostPayRun`/`PostPurchaseOrder`/`PostSalesOrder`/`PostJournalEntry`/`PostInventoryReceipt`/`PostInventoryIssue`/`RemeasureLeaveAccrual`/`UtilizeLeaveAccrual`) — a gap the original 12 findings didn't cover at all (they were infra/ops-focused; this is a financial-correctness gap the fresh audit surfaced), also committed in `adf293c` and confirmed via a live CI run including a new integration test against real Postgres.
4. **Finding #1 (CD pipeline) — built, 2026-08-22, but not yet fully live.** The deploy-target decision this plan flagged as un-guessable is resolved: AWS (already confirmed 2026-08-11, Section 10.19's "are we ready to deploy on AWS?"), ECS/Fargate specifically (confirmed 2026-08-22), region eu-west-2 (confirmed same day — Purse/UK is the near-term market). `infra/terraform/` (ECR, ECS cluster/service/task definition, ALB over plain HTTP, GitHub OIDC deploy role, Secrets Manager for the DB password, CloudWatch Logs) plus a new `deploy` job in `ci.yml` (auto-deploys to production on every push to `master` that passes `test`/`integration-test`/`docker-build`). **Genuinely unverified** — written with no `terraform` CLI and no AWS credentials available, so untested against real AWS; needs `terraform apply` plus setting six GitHub Actions repository variables (`infra/terraform/README.md`'s step-by-step) before it does anything. Database/RDS provisioning was deliberately kept out of scope — `db_host`/`db_user`/`db_password` are required Terraform variables with no defaults, pointing at wherever Postgres ends up living. No staging environment — auto-deploy straight to production was the explicit choice over staging-then-promote, since no staging environment exists.

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

### 1b. CD pipeline (finding #1) — DONE, 2026-08-22, pending real-world verification

CI used to stop at "the image builds." The deploy-target decision this section used to flag as un-guessable is now resolved and built: AWS ECS/Fargate, eu-west-2, `infra/terraform/` (Terraform, applied by hand — not this session, no AWS credentials were available to run it) plus a `deploy` job in `ci.yml` that pushes to ECR and updates the ECS service via OIDC-authenticated GitHub Actions credentials, auto-deploying to production on every push to `master` that passes CI.

**What's genuinely still open, not glossed over:**
- **`terraform fmt`/`init`/`validate` now actually run and pass** (2026-08-22, once Terraform was installed) — and `validate` earned its keep immediately: caught a hand-typed GitHub OIDC thumbprint that was only 39 hex characters, not the required 40. Fixed properly, not patched — replaced the hardcoded value with a `data "tls_certificate"` fetch of GitHub's real certificate at `apply` time, removing the whole "did I copy this right / has GitHub rotated it" class of risk. A `terraform plan` with dummy variable values got as far as resolving that data source (a real network call to GitHub succeeded) before stopping at "No valid credential sources found" for AWS — the correct, expected boundary with no AWS credentials available. **Still never run against real AWS** — `plan`/`apply` with real credentials is the next real signal, not this session's syntax/graph-level checks.
- **No HTTPS** — plain HTTP only, since no domain name or ACM certificate exists anywhere in this project. A real gap for production traffic carrying JWTs, not a cosmetic one.
- **No database provisioning** — deliberately kept out of scope; `infra/terraform/` expects Postgres to already exist somewhere reachable, via required `db_host`/`db_user`/`db_password` variables with no defaults. Where that Postgres instance actually lives (RDS or otherwise) is still an open decision.
- **No rollback tooling beyond "redeploy an older image tag by hand"** — ECR's lifecycle policy keeps the last 20 tagged images, so a rollback target exists, but there's no one-click/automated rollback mechanism.
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
- **Finding #10 — backup/DR documentation.** Pure documentation, not code — but reasonable to defer until the managed-database choice (RDS or otherwise) is made, since the actual backup mechanism follows from that choice. Still open — `infra/terraform/` deliberately didn't provision a database (see 1b above).

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
11. Finding #10 (backup/DR docs) once the database hosting choice is known (`infra/terraform/` deliberately didn't decide this).
12. Finding #12 (API versioning) once the consumer set (POP/SOP/IM/HR) stabilizes — deliberately last, needs cross-repo coordination.
