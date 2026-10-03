# Omniview Extraction

**Status, 2026-10-03: design scoping. Nothing extracted, nothing deleted yet.** Configuration Manager CM has been flagged early (per "Coordination is the prime directive") and is standing by to handle the repo/Jenkinsfile/Terraform side once this is scoped, the same way as every prior extraction. The Enterprise Administration - EA (fork) session has been flagged separately, since the code that needs to move currently lives in their live checkout, not a neutral location — removal is sequenced after their reply, not before.

**The instruction this exists to enforce**, given directly: *"The Omniview should be its own Repo. It is where I oversee everything in the FiSH+ERverse."* Followed by the boundary that resolves the one real design ambiguity this doc would otherwise have to guess at: *"EA is for each tenancy."*

That second line is the whole architecture in one sentence. EA's job is **one Tenant at a time** — its own Users, Memberships, Companies, support threads, KYB status. Omniview's job is **across every Tenant and every service at once** — the platform operator's own view, never a Tenant's own. This is the same kind of boundary this codebase has drawn four times already (Lending/HR/POP/SOP/IM all left GL once they stopped being "financial effect" and became something else) — Omniview leaving EA is the same move: platform-operator oversight was never "Tenant administration," it just didn't have anywhere else to live yet.

---

## 0. What's actually in EA today (confirmed by direct code inventory, not guessed)

Everything below lives in `EA/` right now, mixed in with EA's own actual (per-tenant) domain:

| Type | File | Role |
|---|---|---|
| `PlatformHealthGateway` / `KtorPlatformHealthGateway` | `infrastructure/platformhealth/PlatformHealthGateway.kt` | Cross-service reachability for GL/POP/SOP/IM/HR — built 2026-09-19 as Omniview's first cross-service data source, deliberately the lightest possible one (no business data) |
| `operatorTenantOverviewRoutes` | `infrastructure/web/OperatorTenantOverviewRoutes.kt` | Every Tenant at once — onboarding/KYB/phone status, staff headcount, support activity. Explicitly **not** business/financial data, per this file's own KDoc |
| `operatorPlatformHealthRoutes` | `infrastructure/web/OperatorPlatformHealthRoutes.kt` | `GET /operator/platform-health`, serving the gateway above |
| `ReplyToOperatorThreadUseCase`, `SubmitToOperatorThreadUseCase`, `OperatorMessagesRoutes`, `message_audience.kt` | `application/`, `infrastructure/web/` | The operator messaging surface — grown since 2026-09-19 (was "support thread," now broader "operator messages") under EA fork's own development, not reviewed in detail by this document yet |
| `authorizeOperator`, `EA_OPERATOR_TOKENS` | `infrastructure/web/Auth.kt` (or adjacent) | The interim bridge auth for all of the above — named per-operator tokens, not a real identity system, "until real identities exist" per its own original KDoc |
| `PlatformHealthStrip`, `TenantsOverview`, `OperatorSupportInboxPage.tsx` | `WEB/src/screens/OperatorSupportInboxPage.tsx`, `WEB/src/api/operatorSupport.ts` | The browser-facing operator console, reached at `/operator` in WEB, bypassing Cognito entirely (same shape as the Supplier portal's `?token=` bypass) |

None of this is Tenant-scoped in the way the rest of EA is. `operatorTenantOverviewRoutes` *reads* every Tenant, but an operator viewing it isn't a Tenant's own Membership acting within their own Tenant — it's Prodeo's own staff looking at the whole platform. That's the tell this belongs somewhere else.

---

## 1. What moves out vs. what stays

**Moves out, in full:** every row in the table above — the platform-health gateway, the tenant-overview route, the operator-messaging surface, the operator-token auth bridge, and the WEB-side `/operator` console. This becomes a new sibling system — own repo, own deployment, alongside `GL/POP/SOP/IM/HR/EA/ER-EducationRuntime` — whose whole reason for existing is *"the view across all of them, held by the person who owns all of them."*

**Stays in EA, unchanged:** `Tenant`, `User`, `Membership`, `Role`, `AccessLevel`, `ManagedModule`, onboarding, staff invitation, KYB tracking, `GET /me` — everything that answers "what can this caller do, in this Tenant." EA keeps being the per-tenant system; nothing about its own charter shrinks.

**The one real seam, mirroring every prior extraction's own "the one real seam" section:** Omniview's tenant-overview and operator-messaging surfaces don't own Tenant/Membership/Message data — EA still does. Rather than migrating that data (and taking on a second system of record for something EA already owns correctly), Omniview calls EA's own API for it, the same way EA itself already calls SOP/IM/GL for the Business Owner Dashboard (`ComputeDashboardUseCase` → `SopGateway`/`ImGateway`/`GlGateway`).

**Confirmed against the real code, 2026-10-03, by the EA-fork session** — this seam is sharper than "tenant-overview and messaging both read EA data": `OperatorTenantOverviewRoutes.kt` takes `TenantRepository`/`MembershipRepository`/`SupportMessageRepository` directly as parameters, and `OperatorMessagesRoutes.kt` reads/writes `MessageAudience.OperatorThread` on EA's own core `Message` aggregate (`message_audience.kt`) — the exact same aggregate a Tenant's own support-thread/Announcement/Team-chat sends also write to (`MessageRoutes.kt`, staying in EA per `EA_Development_Backlog.md` item 09, "only the operator's own half moved to Omniview, not the Tenant's own send/read surface"). Moving either file wholesale would either strand EA's own remaining routes without their data access, or fork `MessageAudience` into two copies. **`PlatformHealthGateway.kt` is the only genuinely clean, zero-EA-dependency move** — it's pure outbound HTTP to GL/POP/SOP/IM/HR, no EA repository involved at all.

**Auth mechanism for the EA-calling piece, resolved 2026-10-03 — NOT a new service account.** First proposal (a Cognito service-account client, mirroring GL/POP/SOP/IM/HR's own calls into EA) was wrong and EA-fork correctly pushed back on it before either side built anything: that mechanism is for genuine machine-to-machine calls with no human behind them. Omniview's calls to EA are a human operator's own actions, routed through a console — collapsing that into one shared "Omniview" service identity would undo the exact per-operator attribution/revocation property `EA_OPERATOR_TOKENS` was built to fix (2026-09-16 HIGH-severity finding: "shared `EA_OPERATOR_TOKEN`, no per-operator identity, a leaked token couldn't be revoked without cutting off everyone"). **Instead: zero new EA routes, zero new auth mechanism.** Omniview's backend calls EA's *existing* `/operator/tenants`, `/operator/support-threads`, `/operator/tenants/{tenantId}/support-thread/messages` directly, forwarding the logged-in operator's own `X-Operator-Token` — the same header `authorizeOperator()` already checks today. Omniview's backend does the proxying (not the browser calling EA directly), so no EA-side CORS change is needed either. This is less work on both sides than the service-account version, not just the more correct choice.

This also answers the data-ownership question for every future data source Omniview grows into (GL financial signals, ER/Education Runtime status, eventually BuzzMe): **Omniview never owns another service's data. It only ever calls out and aggregates/presents.** That's the architectural promise that keeps it from becoming a second, competing copy of everyone else's domain — the same promise `Company` staying in GL, not moving to EA, already made for the Ledger.

---

## 2. What the new system is responsible for

1. **Cross-service platform health** — GL/POP/SOP/IM/HR/EA(/ER once wired) reachability, exactly as `PlatformHealthGateway` already does, just relocated.
2. **Cross-tenant platform overview** — every Tenant's onboarding/support status at once, by calling EA's existing `/operator/tenants` route, forwarding the operator's own token (see §1's resolved auth mechanism).
3. **Operator messaging** — the support/communication surface, same relocation treatment.
4. **The single place the platform operator (today: Femi; later: Prodeo's own ops/support staff) looks to answer "how is everything doing right now," across both FiSH and ER** — this is the part that doesn't exist as a single place today at all; it's currently "check EA's `/operator`, then separately check whatever ER/Education Runtime exposes, then separately check AWS directly."

**Explicitly not yet in scope** (per the user's own original staged plan, 2026-09-19 — "start with lightweight health, grow into ER status, then GL financial data as need for support and data analysis increases"): no financial/revenue data, no deep per-service business data beyond what already exists. Phase 2 (ER/Education Runtime status) and Phase 3 (GL financial signals) stay explicitly future work, sequenced the same way the original plan already set out — this extraction moves what exists today, it doesn't expand scope at the same time.

---

## 3. Architecture

**Mechanism**: plain HTTP outbound calls, no auth at all, for the platform-health checks (GL/POP/SOP/IM/HR's public `/health` endpoints — unauthenticated today, unchanged). For EA specifically, Omniview's backend forwards the logged-in operator's own `X-Operator-Token` to EA's existing `/operator/*` routes — see §1's resolved auth mechanism. No Cognito service-account client needed for either case; the service-account pattern (`KtorGlGateway`/`KtorSopGateway`/`KtorImGateway` precedent) stays reserved for genuine machine-to-machine calls, which this isn't.

**Inbound auth**: keeps the existing interim operator-token bridge (`X-Operator-Token`, named per-operator tokens) rather than inventing something new at extraction time — a real identity system for platform operators is a separate, future decision, not blocking this move. Open question §4.3 covers how an operator's EA token gets into Omniview in the first place.

**Persistence**: none required for the data this extraction actually moves (health checks are stateless; tenant-overview and messages are read-through to EA). If a later phase needs Omniview-owned state (e.g. acknowledged alerts, an operator's own saved filters), that's a new, scoped decision at that time — not assumed now, per this project's own "minimal builds" discipline.

**Web UI — resolved 2026-10-03 by Femi directly, superseding this section's own prior two drafts.** `fish-gl-web`'s `OperatorSupportInboxPage.tsx` (reached at `/operator`) is confirmed to already implement all four of this document's use cases (sign-in, `PlatformHealthStrip`, `TenantsOverview`, `OperatorInbox`), built 2026-09-13 through 09-19 — that fact never changed across either draft. What changed is the decision about where it should *live* going forward: **Omniview is exempt from the new platform-wide shared-frontend convention, specifically because it is not client-facing.** Every other service's UI belongs in the one shared Tenant-facing app; Omniview's console has no Tenant anywhere near it, ever — a structurally different kind of frontend, not a shard of the same one. Decision: **full migration**, not a base-URL swap. `OperatorSupportInboxPage.tsx` and its API client move into `fish-er-omniview` outright, taking real ownership, not staying a WEB-owned component pointed at a different backend.

The component itself is a clean lift — already fully self-contained, `App.tsx`'s `isOperatorPath` check renders it before `AuthProvider` even mounts, same isolation `SupplierPortalPage`'s `?token=` bypass already uses — so it should port close to verbatim.

**What this actually requires, that the prior "just a base-URL swap" draft didn't**: `fish-er-omniview` needs its own frontend build (Vite/React, matching WEB's own tooling for the lifted component) and a way to serve it — not something this repo has needed yet, backend-only through Wave 2. Simplest shape, consistent with NFR-OV-5 ("no bespoke infrastructure") and this project's "minimal builds" discipline: Ktor serves the built static bundle directly (`staticResources`, one ECS deployment, no separate CloudFront/S3 the way `capital.theprodeogroup.com`'s own frontend needed) — flagged for CM to confirm or override, not assumed as final.

**Cutover sequencing, per WEB's own stated terms**: WEB's `/operator` route stays live and serving until Omniview's new frontend is deployed and verified; WEB removes it from their side in the same coordinated window, not speculatively early. Coordinated directly between the two sessions when Omniview's frontend is actually ready to stand up, not before.

---

## 4. Open questions — parked, not guessed

1. **Resolved 2026-10-03 by Femi — repo `fish-er-omniview`.** Local folder `Omniview/`, package `com.theprodeogroup.omniview`, following the same `fish-<name>`/`<Name>/`/`com.theprodeogroup.<name>` shape every sibling uses, with `er` marking that it spans FiSH and ER rather than being FiSH-only.

2. **Resolved 2026-10-03 by Femi — domain `omniview.theprodeogroup.com`.** No `-api` suffix, matching Jenkins' own bare-domain treatment as an operator-facing (not machine-facing) surface.

3. **Resolved 2026-10-03 — no EA-side route repurposing needed.** EA's existing operator routes stay exactly as they are (same `authorizeOperator()` gate, same paths); Omniview's backend calls them directly, forwarding the operator's own token. The one small remaining open item: how that token gets *into* Omniview in the first place. Simplest candidate, not yet built: Omniview's own sign-in gate (mirroring WEB's existing operator-token entry pattern) asks for the same EA token — one more hop on the existing "bridge until real identities exist" mechanism, not a new one.

4. **Whether the operator-messaging surface's underlying `SupportMessage`/thread data should eventually move to Omniview too**, now that Omniview is the cross-tenant view and messaging is inherently cross-tenant (an operator corresponds with many Tenants, not one). Flagged, not decided — EA keeping that data and Omniview reading through it is the safe default per §1's seam; moving ownership outright is a bigger, separate call.

---

## 5. Build order

Dependency-ordered, mirroring how every prior extraction sequenced itself:

1. **CM**: new repo, GitHub remote, Kotlin/Ktor/Exposed skeleton (mirroring the established sibling shape), Jenkinsfile, `/health` route. No real feature yet — just a deployable skeleton, same first step every prior extraction took.
2. **Omniview-side**: port `PlatformHealthGateway` + its route in, unchanged in behavior. Lowest-risk first slice — no EA dependency, no data-ownership question, already stateless.
3. **Omniview-side**: the browser-facing operator-token-gated routes + the ported `/operator` web UI, calling EA's *existing* `/operator/tenants`/`/operator/support-threads`/`/operator/tenants/{tenantId}/support-thread/messages` directly, forwarding the operator's own token. No EA-side change needed at all (per §1's resolved auth mechanism) — this step no longer depends on EA-fork building anything new.
4. **Cutover**: EA's own operator-token-gated routes get removed once Omniview's equivalent is live and verified (EA-fork's own call, their checkout); WEB's `/operator` page gets removed/redirected to Omniview's own domain.
5. **Future, explicitly out of scope here**: Phase 2 (ER/Education Runtime data) and Phase 3 (GL financial data), per the original staged plan.
