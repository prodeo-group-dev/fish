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

**The one real seam, mirroring every prior extraction's own "the one real seam" section:** Omniview's tenant-overview and operator-messaging surfaces don't own Tenant/Membership/Message data — EA still does. Rather than migrating that data (and taking on a second system of record for something EA already owns correctly), Omniview calls EA's own API for it, the same way EA itself already calls SOP/IM/GL for the Business Owner Dashboard (`ComputeDashboardUseCase` → `SopGateway`/`ImGateway`/`GlGateway`). EA's existing operator routes get repurposed: instead of being directly operator-token-gated and browser-facing, they become a service-account-gated API **for Omniview to call** — same Cognito-service-account pattern every other inter-service call in this platform already uses. Omniview's own new routes become the real operator-token-gated, browser-facing surface.

**Confirmed against the real code, 2026-10-03, by the EA-fork session** — this seam is sharper than "tenant-overview and messaging both read EA data": `OperatorTenantOverviewRoutes.kt` takes `TenantRepository`/`MembershipRepository`/`SupportMessageRepository` directly as parameters, and `OperatorMessagesRoutes.kt` reads/writes `MessageAudience.OperatorThread` on EA's own core `Message` aggregate (`message_audience.kt`) — the exact same aggregate a Tenant's own support-thread/Announcement/Team-chat sends also write to (`MessageRoutes.kt`, staying in EA per `EA_Development_Backlog.md` item 09, "only the operator's own half moved to Omniview, not the Tenant's own send/read surface"). Moving either file wholesale would either strand EA's own remaining routes without their data access, or fork `MessageAudience` into two copies. **`PlatformHealthGateway.kt` is the only genuinely clean, zero-EA-dependency move** — it's pure outbound HTTP to GL/POP/SOP/IM/HR, no EA repository involved at all. Everything else gets the gateway treatment below.

**Proposed API shape** (EA-fork reviewing, not yet built): `GET /operator-api/tenants-overview` (same response shape `OperatorTenantOverviewDto` already returns, behind a service-account check instead of `authorizeOperator`), `GET /operator-api/messages` + `POST /operator-api/messages/{tenantId}/reply` (filtered to `MessageAudience.OperatorThread` as today, EA's own `MessageRepository`/`SendMessageUseCase` doing the real work, Omniview calling through) — authenticated by a new Omniview Cognito service-account client, same mechanism GL/POP/SOP/IM/HR's own service-account calls into EA already use, just one more named caller.

This also answers the data-ownership question for every future data source Omniview grows into (GL financial signals, ER/Education Runtime status, eventually BuzzMe): **Omniview never owns another service's data. It only ever calls out and aggregates/presents.** That's the architectural promise that keeps it from becoming a second, competing copy of everyone else's domain — the same promise `Company` staying in GL, not moving to EA, already made for the Ledger.

---

## 2. What the new system is responsible for

1. **Cross-service platform health** — GL/POP/SOP/IM/HR/EA(/ER once wired) reachability, exactly as `PlatformHealthGateway` already does, just relocated.
2. **Cross-tenant platform overview** — every Tenant's onboarding/support status at once, by calling EA's (new, service-account-gated) tenant-overview API rather than EA's own operator-token route directly.
3. **Operator messaging** — the support/communication surface, same relocation treatment.
4. **The single place the platform operator (today: Femi; later: Prodeo's own ops/support staff) looks to answer "how is everything doing right now," across both FiSH and ER** — this is the part that doesn't exist as a single place today at all; it's currently "check EA's `/operator`, then separately check whatever ER/Education Runtime exposes, then separately check AWS directly."

**Explicitly not yet in scope** (per the user's own original staged plan, 2026-09-19 — "start with lightweight health, grow into ER status, then GL financial data as need for support and data analysis increases"): no financial/revenue data, no deep per-service business data beyond what already exists. Phase 2 (ER/Education Runtime status) and Phase 3 (GL financial signals) stay explicitly future work, sequenced the same way the original plan already set out — this extraction moves what exists today, it doesn't expand scope at the same time.

---

## 3. Architecture

**Mechanism**: HTTP, service-account-authenticated outbound calls from Omniview to each sibling (EA included), same shape as every other inter-service call in this platform (`KtorGlGateway`/`KtorSopGateway`/`KtorImGateway` precedent). Omniview gets its own Cognito service-account identity per sibling it calls, provisioned in `Infrastructure/` the same way `pop_gl_service_account.tf` etc. already are for every other cross-service caller — this is CM's side of the work once the repo exists.

**Inbound auth**: keeps the existing interim operator-token bridge (`X-Operator-Token`, named per-operator tokens) rather than inventing something new at extraction time — a real identity system for platform operators is a separate, future decision, not blocking this move.

**Persistence**: none required for the data this extraction actually moves (health checks are stateless; tenant-overview and messages are read-through to EA). If a later phase needs Omniview-owned state (e.g. acknowledged alerts, an operator's own saved filters), that's a new, scoped decision at that time — not assumed now, per this project's own "minimal builds" discipline.

**Web UI**: bundled into the new backend repo as a thin served frontend, not a new separate frontend repo. The current `/operator` page is a single page with two tabs — standing up a whole second Vite/React/WEB-shaped repo for that is more infrastructure than the current UI justifies. Revisit if Omniview's own UI grows enough to need WEB's own tooling (shadcn, the Tailwind/brand theme system, etc.).

---

## 4. Open questions — parked, not guessed

1. **Repo name and package.** Every existing sibling follows `fish-<name>`/`<Name>/`/`com.theprodeogroup.<name>` (`fish-enterprise-administration`/`EA`/`com.theprodeogroup.ea`). Omniview is different in kind — it's not a FiSH-specific service, it spans FiSH **and** ER (and this session's own display name is already "FiSH+ER OmniView," not "FiSH Omniview"). Candidate: repo `fish-er-omniview` or `omniview` (no `fish-` prefix, since it isn't one), local folder `Omniview/`, package `com.theprodeogroup.omniview`. Not picked yet — flagging for Femi/CM rather than guessing, since a repo name is expensive to change once Jenkins/Terraform/DNS reference it.

2. **Domain.** Every service gets `<name>-api.theprodeogroup.com`; this one's operator-facing, not machine-facing, so it may want a plain `omniview.theprodeogroup.com` instead — same reasoning Jenkins (`jenkins.theprodeogroup.com`, no `-api`) already got.

3. **Exact sequencing of the EA-side route repurposing** (operator-token-gated → service-account-gated) — needs the EA-fork session's own input, since it's their live checkout and possibly their own in-flight work on the messaging surface. Not resolved in this document.

4. **Whether the operator-messaging surface's underlying `SupportMessage`/thread data should eventually move to Omniview too**, now that Omniview is the cross-tenant view and messaging is inherently cross-tenant (an operator corresponds with many Tenants, not one). Flagged, not decided — EA keeping that data and Omniview reading through it is the safe default per §1's seam; moving ownership outright is a bigger, separate call.

---

## 5. Build order

Dependency-ordered, mirroring how every prior extraction sequenced itself:

1. **CM**: new repo, GitHub remote, Kotlin/Ktor/Exposed skeleton (mirroring the established sibling shape), Jenkinsfile, `/health` route. No real feature yet — just a deployable skeleton, same first step every prior extraction took.
2. **Omniview-side**: port `PlatformHealthGateway` + its route in, unchanged in behavior. Lowest-risk first slice — no EA dependency, no data-ownership question, already stateless.
3. **EA-side** (coordinated with EA-fork session): add the service-account-gated tenant-overview + operator-messages API for Omniview to call; **CM**: provision Omniview's service-account credential to reach it.
4. **Omniview-side**: the browser-facing operator-token-gated routes + the ported `/operator` web UI, calling EA through step 3's API rather than EA's own operator-token route directly.
5. **Cutover**: EA's own operator-token-gated routes (`operatorTenantOverviewRoutes`, `OperatorMessagesRoutes`'s current auth) get removed once Omniview's equivalent is live and verified; WEB's `/operator` page gets removed/redirected to Omniview's own domain.
6. **Future, explicitly out of scope here**: Phase 2 (ER/Education Runtime data) and Phase 3 (GL financial data), per the original staged plan.
