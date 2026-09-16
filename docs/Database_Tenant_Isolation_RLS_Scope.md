# Database Tenant Isolation (RLS) — Scope Note

Status: **scoping only, nothing built**. Written in response to the code
review finding "Tenancy only at app layer (no RLS)" — the last of the
original six findings, after CommunicationRoutes/TenantRoutes/DashboardRoutes/
staff-invite-secrets/EA_OPERATOR_TOKEN were each investigated, fixed, tested,
and shipped this session. This one gets the same treatment the Service
Account identity cutover got (`Service_Account_Principal_Cutover_Scope.md`):
ground-truth the current state fully, then bring options back rather than
writing `CREATE POLICY`/`PARTITION BY` blind, because the blast radius here
is at least as large and touches the actual financial system of record.

## Confirmed facts

**No RLS or partitioning exists anywhere today.** Grepped every migration in
GL, EA, POP, SOP, IM, and HR for `ROW LEVEL SECURITY`, `CREATE POLICY`, and
`PARTITION BY` — zero matches. A 2026-08-11 persistence-strategy decision
(`project_persistence_strategy` memory) called for tenant_id partitioning
+ RLS as the plan; it was never implemented, and the memory's own last line
already flagged that gap.

**No session-context mechanism exists either.** Grepped for `SET LOCAL`,
`set_config`, `current_setting` across GL's and EA's persistence layers —
zero matches. Every RLS scheme needs some way to tell Postgres "this
connection is acting for tenant X" per request; nothing in this codebase
does that today, and Exposed's `transaction { }` blocks are called ad hoc
throughout each service with no central point that could inject one.

**This finding's real blast radius is GL, EA, and HR only — not POP/SOP/IM.**
POP, SOP, and IM each run on their *own* logical Postgres database and
database role, one per service, on the shared `fish-gl-engine-production`
RDS instance (`feedback_shared_rds_manual_database_creation` memory:
`CREATE DATABASE <x>_production; CREATE USER <x>_app`). Grepping their
migrations for `tenant_id`/`company_id` found zero matches in any of the
three — confirmed separately by the fact that each is deployed single-tenant
today (one fixed Tenant per deployment via `*_GL_ENGINE_TENANT_ID`/
`*_EA_TENANT_ID` env vars, per the §2.4 rollout this session). A same-database
cross-tenant leak is structurally impossible there right now: there's only
one tenant's data in the database at all. The real gap those three carry is
an *operational* one, not a security one — onboarding a second tenant onto
POP means standing up an entirely new database + role via the same manual
five-step runbook, not a code change. Worth tracking, but it's not this
finding.

GL, EA, and HR are the services that actually hold more than one tenant's
data in one database, so they're where an app-layer authorization bug (the
exact class of bug just fixed four times this session) can leak across
tenants at the database level.

**GL's core Ledger tables are scoped by `company_id`, not `tenant_id`
directly.** `V2__core_ledger_tables.sql`: `accounts`, `periods`, and by
extension `journal_entries`/`journal_lines` all carry `company_id UUID NOT
NULL`. `V3__tenancy_tables.sql`: `companies` carries `tenant_id UUID NOT
NULL REFERENCES tenants(id)`. Tenant is one join away from every Ledger
row, not a column on it. 24 migrations, 29 `CREATE TABLE` statements total
in GL — the majority of them (fixed_assets, purchase_orders,
sales_invoice_records, tax computations, leave_accruals, idempotency_keys,
and more) follow the same `company_id`-not-`tenant_id` shape.

EA's own tables are the opposite shape: `memberships`, `tenant_companies`,
and `tenant_admin_memberships` (`V1__baseline.sql`) all carry `tenant_id`
directly — no join needed. HR's `employees` table carries `company_id`
directly, same shape as GL.

**Every service's DB role owns its own tables — a real RLS gotcha, not a
hypothetical one.** The onboarding runbook has each service's app role
(`<x>_app`) created as the schema owner (`ALTER SCHEMA public OWNER TO
<x>_app`) before Flyway ever runs — so every `CREATE TABLE` Flyway issues is
owned by that same role, and that same role is what the running application
connects as. **Postgres RLS policies are bypassed by default for the table
owner.** A naive `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` +
`CREATE POLICY` here would compile, look correct, and do *nothing* at
runtime — the app's own connection would silently see every row regardless
of policy, because it's always connecting as the owner. Closing that gap
needs `ALTER TABLE ... FORCE ROW LEVEL SECURITY` on every affected table,
easy to miss and worse than not having RLS at all if missed (false
confidence rather than a known gap).

## Why this is a bigger lift than the six findings already closed

Every finding closed this session was a bounded code change: one missing
check, one route, one migration, verified against the existing test suite.
This one needs a genuinely new capability (per-request tenant-context
propagation) that doesn't exist in any of these codebases today, applied to
the system that records every financial fact in the platform, where a
mistake fails dangerously in either direction — fail-open (a forgotten
`FORCE ROW LEVEL SECURITY`, silently inert) is a false sense of security;
fail-closed (a policy or session variable bug) means legitimate ledger
queries start returning empty results or erroring, in production, against
real money.

## Options

**A — RLS via session-context + subquery policies (GL/EA/HR only).** Add a
Ktor interceptor that runs `SET LOCAL app.tenant_id = ...` (or resolves via
`company_id` where that's the direct column) at the start of every request's
transaction, then `CREATE POLICY ... USING (tenant_id = current_setting(...))`
per table, with `FORCE ROW LEVEL SECURITY` everywhere. EA's tables are the
natural pilot (`tenant_id` is already a direct column, no join needed) before
attempting GL's Ledger tables, which need a join-based policy
(`company_id IN (SELECT id FROM companies WHERE tenant_id = ...)`) or a
denormalized `tenant_id` column added to every Ledger table first.

**B — Native partitioning by `tenant_id`.** The original 2026-08-11 decision.
Bigger migration than A (touches every table's physical layout, and GL's
tables would need a `tenant_id` column added before they could even be
partitioned by it, since none exists today). Also doesn't close this
finding by itself — partitioning is a performance/scale mechanism; a query
missing its own `WHERE tenant_id = ...` still reads every partition unless
RLS or the app layer enforces the scope, so B is really "A, plus," not an
alternative to it.

**C — Hold, and treat the app-layer checks as the real control for now.**
Don't build RLS yet. The four concrete cross-tenant bugs this exact review
found were all app-layer authorization gaps, and all four are now fixed and
regression-tested; RLS's payoff here is defense-in-depth against a *future*
bug of the same shape, not closing a currently-known hole. Revisit when
there's a concrete forcing function — a compliance/audit requirement, or
onboarding a second real Tenant that shares GL's database at meaningful
scale — rather than building the plumbing speculatively.

## Recommendation

**C for now, with A tracked as the deliberate next step once there's a
forcing function** — not built today. This mirrors how
`Inter_Tenant_Trade_Automation_Vision.md` is gated (documented, not queued,
until it's load-bearing) rather than either building blind or dropping the
finding. If/when it's picked up, pilot on EA first (direct `tenant_id`,
smallest blast radius, same "pilot small then generalize" pattern the §2.4
membership-check rollout used successfully this session), and treat GL's
Ledger tables — the harder, join-based case — as its own follow-on phase
given they're the actual system of record.

## Open questions (for the user, not picked)

- Is there a known compliance/audit timeline that should pull this forward
  rather than waiting for a second real Tenant?
- If A is picked up: is a denormalized `tenant_id` column on GL's Ledger
  tables acceptable (simpler policies, one migration touching every Ledger
  table), or must the join-based policy be used to avoid that schema change?
- Is partitioning (B) still wanted independently, for performance reasons
  unrelated to isolation, once real data volume justifies it?

## Not done as part of this note

No `CREATE POLICY`, `FORCE ROW LEVEL SECURITY`, `PARTITION BY`, or
session-context interceptor code has been written. No terraform touched.
