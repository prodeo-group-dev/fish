# GL Engine — Production Readiness Assessment (reference, 2026-08-21)

**Scope: `fish-fish-gl-engine` (`GL/`) only.** Of the five repos, `GL/` is the only one with actual deployable infrastructure (Dockerfile, CI, Postgres, JWT auth, a running HTTP server) — `POP/`, `SOP/`, and `IM/` are still domain-layer-only (no persistence, no HTTP, no deployment target), so "production readiness" doesn't apply to them the same way yet. This document doesn't cover them.

**Method: confirmed by direct inspection, 2026-08-21, not guessed** — `Dockerfile`, `.github/workflows/ci.yml`, `DatabaseConfig.kt`, `Auth.kt`, `HealthRoutes.kt`, `Application.kt`'s `StatusPages` block, migrations V1–V6, and `build.gradle.kts`'s dependency versions were all read directly, matching this project's "park, don't guess" discipline applied to an audit rather than a design decision.

---

## 0. What's already solid

- **No baked-in secrets.** `DatabaseConfig`'s `FISH_DB_USER`/`FISH_DB_PASSWORD` and `Auth.kt`'s `FISH_JWT_ISSUER`/`FISH_JWT_AUDIENCE`/`FISH_JWT_JWKS_URL` are all required environment variables with no unsafe default — the same "no safe default for a security-relevant value" reasoning applied consistently in both files.
- **JWT verified in-process against an external IdP's JWKS** (`buildJwksVerifier`), with a cached + rate-limited key fetch (`JwkProviderBuilder`) rather than a hand-rolled auth scheme.
- **A real multi-tenancy leak check** (`verifyClaimedTenant` in `Auth.kt`) — every write route resolves the *actual* owning Tenant from the targeted resource and checks it against the caller-claimed `X-Tenant-Id` header, not just trusting the header at face value.
- **Docker image runs as a non-root user**, multi-stage build (JDK build stage, slim JRE runtime stage — the runtime image never carries the Gradle wrapper, build cache, or source tree).
- **CI runs unit tests + integration tests against a real Postgres service container + confirms the Docker image builds**, on every PR and every push to `master` (`.github/workflows/ci.yml`).

---

## 1. Gaps

### Critical — blocks calling this "production ready" at all

1. **No CD.** CI stops at "the image builds" (`docker-build` job) — nothing pushes it to a registry (ECR or otherwise) and nothing deploys it. No environment promotion story (staging → prod), no rollback mechanism.
2. **No database-level tenant isolation.** The persistence-strategy decision on record calls for Postgres Row-Level Security + partitioning by `tenant_id`; migrations V1–V6 contain zero `ROW LEVEL SECURITY`/`CREATE POLICY` statements. Isolation today is entirely application-layer (`Auth.kt`'s checks) — a single bug in one route handler is the only thing standing between tenants, with no defense-in-depth at the database layer.
3. **Exception messages leak to API clients.** `Application.kt`'s `StatusPages` catch-all responds with `cause.message` directly in the 500 body. Fine for local dev; in production this can expose stack internals, exception class names, or fragments of a failed SQL statement to any caller able to trigger a 500.

### High

4. **No structured logging configuration.** No `logback.xml` (or equivalent) anywhere in `src/main/resources` — SLF4J/Logback runs on pure defaults: no per-environment log level tuning, no JSON output for a log aggregator (CloudWatch/Datadog/etc.), no request-correlation-ID field to trace a single request across log lines.
5. **No metrics or tracing.** No Micrometer/Prometheus endpoint, no OpenTelemetry integration — an operator has no dashboard for request latency, error rate, or DB pool saturation once this is actually serving traffic.
6. **`/health` is shallow.** `HealthRoutes.kt` returns a static `{"status": "ok"}` with no database connectivity check — an orchestrator (ECS/ALB) would keep routing traffic to an instance whose Postgres connection is dead.
7. **No rate limiting, request size limits, or CORS policy enforced by the app itself.** Currently relies entirely on whatever sits in front of it (a load balancer, API Gateway) — a reasonable posture *if* that's a confirmed part of the deploy target, but nothing in this repo enforces it as a fallback if it isn't.

### Medium

8. **HikariCP pool has minimal tuning.** `DatabaseConfig` sets only `maximumPoolSize` (env-configurable, default 10) — no `connectionTimeout`, `idleTimeout`, or `leakDetectionThreshold`, so a connection leak or a slow-query storm has no early warning signal.
9. **No dependency-vulnerability scanning in CI.** No Dependabot config, no Snyk/OWASP dependency-check step. Current versions (Exposed 0.56.0, Flyway 10.20.1, Ktor 2.3.12, Kotlin 2.0.21) aren't unreasonable today, but nothing is watching for CVEs going forward.
10. **No backup/restore or disaster-recovery story documented anywhere** for the Postgres data. Reasonable to defer to whatever managed database service is eventually chosen (e.g. RDS automated snapshots), but nothing in this repo even names the plan.
11. **No graceful shutdown handling.** Netty's default shutdown behavior isn't overridden in `Application.kt`, so in-flight requests during a rolling deploy aren't explicitly drained before the process exits.
12. **No API versioning.** Routes are unprefixed (`/journal-entries`, `/purchasing/record-obligation`, `/sales-orders/{id}/post`, etc.) — a breaking change has no `/v2` escape hatch, which matters more now that POP/SOP are real external callers starting to depend on this contract rather than hypothetical future ones.

---

## 2. What this document deliberately doesn't do

No severity-to-timeline mapping, no prescribed fix order, no owner assignment — this is a findings record, not a build plan, matching the "record the decision/finding, don't build it yet" discipline already applied throughout this project (e.g. `Ecosystem_Extraction_DDD_Design.md`'s own closing section). Turning any of the above into an actual increment is a separate, explicit next step.

---

## 3. What this document changes right now

**Nothing in `fish-fish-gl-engine`.** Every finding above reflects the codebase exactly as it stood on 2026-08-21 — no code, config, or CI changed by writing this.
