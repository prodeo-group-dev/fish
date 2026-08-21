# GL Engine — Production Readiness Plan (2026-08-21)

Turns `docs/GL_Production_Readiness_Assessment.md`'s 12 findings into a sequenced set of increments. That document was deliberately findings-only ("no severity-to-timeline mapping, no prescribed fix order... a findings record, not a build plan") — this is that separate, explicit next step, kept as its own document rather than mutating the findings record, so the two stay distinct: one is what's true about the codebase, this one is what to do about it.

**Re-verified against the current codebase before planning, not assumed from the prior doc.** All 12 findings are confirmed still open on `master` today. One exception: finding #3 (exception leak) already has an uncommitted fix sitting in this exact `GL/` checkout, on a local branch (`feature/statuspages-generic-error-message`) that was never pushed — see Phase 0.

---

## Phase 0 — land what's already written (no new work)

**Finding #3 (exception messages leak to API clients).** A fix already exists, uncommitted, in this checkout: `Application.kt`'s `StatusPages` handler now logs `cause` server-side via `call.application.log.error(...)` and responds with a generic `ErrorResponseDto("internal_error")` (no `cause.message`), plus a new `StatusPagesTest.kt`. It was never committed or pushed — `git branch -r` shows no `origin/feature/statuspages-generic-error-message`, and there's no open PR for it (confirmed via `gh pr list`).

Action: commit that work on its own branch, push, open a PR, merge. This closes one of the three Critical findings for close to zero new effort — do this before starting anything else below, since it's already done and just needs landing.

---

## Phase 1 — the two hard Criticals

These are the findings that actually block calling this "production ready," and both are larger than a single sitting: they involve real infrastructure/deployment decisions, not just application code.

### 1a. Database-level tenant isolation (finding #2)

Postgres Row-Level Security + partitioning by `tenant_id` is the persistence strategy already on record — migrations V1–V7 (V7 is in open PR #34, not yet merged) contain zero `ROW LEVEL SECURITY`/`CREATE POLICY` statements. Isolation today is 100% application-layer (`Auth.kt`'s `verifyClaimedTenant`), with no defense-in-depth.

**Needs a decision before building, not a guess:**
- RLS via a session-level `SET app.current_tenant_id` per request (set once per connection checkout, policy reads it) vs. a Postgres role-per-tenant approach — the former is far more common with a connection-pooled app like this one (HikariCP), the latter doesn't fit a shared pool well. Worth confirming this is the intended shape before writing policies.
- Whether table partitioning by `tenant_id` (the other half of the "on record" strategy) is in scope now or a later scaling concern — RLS alone closes the isolation gap; partitioning is a performance/scale decision that can reasonably follow later without blocking this.

Once confirmed: a new migration adding `ENABLE ROW LEVEL SECURITY` + `CREATE POLICY` per tenant-scoped table, a `DatabaseConfig`/repository-layer change to set the session variable per request (likely in the Ktor auth pipeline, right after `verifyClaimedTenant` succeeds), and integration tests proving a query against the wrong tenant's data returns nothing even if application-layer logic were bypassed entirely.

### 1b. CD pipeline (finding #1)

CI stops at "the image builds" — nothing pushes to a registry or deploys anywhere, no environment promotion, no rollback story.

**Needs a decision before building:** deploy target isn't decided anywhere in this codebase or its docs. Common options for a Ktor/Postgres service: ECS/Fargate, a plain EC2 + systemd, Fly.io/Railway-style PaaS, Kubernetes. This genuinely can't be guessed — it determines the registry (ECR vs. Docker Hub vs. GHCR), the deploy mechanism (ECS task definition update, `kubectl apply`, a PaaS CLI), and the rollback story (previous task definition revision, previous image tag, etc.) all at once.

---

## Phase 2 — High findings, buildable without new decisions

Everything in this phase can be built against the current codebase with no external decision needed first — good candidates for the next actual increment after Phase 0/1a's decision is made (or in parallel with Phase 1b waiting on a deploy-target answer).

- **Finding #6 — `/health` depth.** Smallest item in the whole plan: add a real Postgres connectivity check (a trivial `SELECT 1` against the pool) to `HealthRoutes.kt`, returning 503 if it fails. Good first increment — self-contained, no dependencies on anything else here.
- **Finding #4 — structured logging.** Add `logback.xml` to `src/main/resources`: JSON encoder (for a log aggregator), per-environment level via env var, and a request-correlation-ID field (Ktor's `CallId` plugin generates/propagates one, then it needs threading into the MDC for Logback to pick up).
- **Finding #5 — metrics.** Micrometer + a Prometheus scrape endpoint (`io.ktor:ktor-server-metrics-micrometer`) is the standard low-effort win: request latency/count/error-rate and JVM metrics essentially for free. OpenTelemetry tracing is a heavier lift (needs a collector target decided) — worth splitting this into "Micrometer now, OTel later" rather than one increment.
- **Finding #7 — rate limiting / CORS / request size limits.** This one *does* have a lightweight version of the Phase 1b problem: whether the app needs to self-enforce this depends on whether a load balancer/API Gateway sits in front in the real deploy topology (the same unanswered question from 1b). Ktor's own `RateLimit`/`CORS` plugins are trivial to add either way, so the actual build cost is low — the open question is only "is this redundant with infra that already does it," not "can we build it."

---

## Phase 3 — Medium findings, cheap and mechanical

All four of these are small, self-contained, and don't block on any external decision — good filler increments or a single "operational hardening" batch.

- **Finding #8 — HikariCP tuning.** Add `connectionTimeout`, `idleTimeout`, `leakDetectionThreshold` to `database_config.kt`'s existing `HikariConfig` block. Minutes of work.
- **Finding #11 — graceful shutdown.** Ktor/Netty supports this via `ShutDownUrl.EngineMain` or wiring `Runtime.addShutdownHook` to `NettyApplicationEngine.stop(gracePeriodMillis, timeoutMillis)` — small, mechanical.
- **Finding #9 — dependency-vulnerability scanning.** A Dependabot config (`.github/dependabot.yml` watching Gradle) is close to free and needs no code change at all.
- **Finding #10 — backup/DR documentation.** Pure documentation, not code — but reasonable to defer until the managed-database choice (RDS or otherwise) is made, since the actual backup mechanism follows from that choice. Loosely coupled to Phase 1b's deploy-target decision.

**Finding #12 — API versioning** is the one Medium item deliberately *not* in this "cheap" bucket: it's mechanical in isolation (`/v1` prefix on `routing { ... }`), but POP/SOP/IM/HR are now real external callers already depending on the current unprefixed contract (`RecordSaleUseCase`/`RecordCollectionUseCase`/`RecordPayRunUseCase`/`GetOrCreateLeaveAccrualUseCase` routes, the `Post*UseCase` routes). Introducing `/v1` needs coordinating a matching change across every consumer repo's own gateway (`KtorGlEngineGateway` in SOP and now HR), not just this repo — sequence it after the consumer set stabilizes, not opportunistically alongside the others.

---

## Suggested build order

1. Phase 0 (land the existing StatusPages fix) — immediate, no new work.
2. Finding #6 (`/health` depth) — smallest real increment, good to confirm the pattern.
3. Finding #8 + #11 (HikariCP tuning + graceful shutdown) — small, pair naturally as "operational hardening."
4. Finding #9 (Dependabot) — no code, just config.
5. Finding #4 + #5 (logging + metrics) — pair naturally as "observability," moderate size.
6. Decide the deploy target (unblocks #1b) and the RLS session-variable approach (unblocks #1a) — these two decisions are the actual gate on calling this "production ready."
7. Build 1a (RLS) and 1b (CD) once their decisions land.
8. Finding #7 (rate limiting/CORS) once the deploy topology from #6's decision is known.
9. Finding #10 (backup/DR docs) once the database hosting choice is known.
10. Finding #12 (API versioning) once the consumer set (POP/SOP/IM/HR) stabilizes — deliberately last, needs cross-repo coordination.
