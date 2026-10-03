# Omniview Backlog — Task Breakdown & Dependency Order

**Status:** living document, 2026-10-03. The dependency-ordered task
list for standing up Omniview per `docs/Omniview_Extraction_DDD_Design.md`,
`docs/Omniview_Software_Requirements_Specification.md`, and
`docs/Omniview_Use_Cases.md` — the SPUTO pass's **T** and **O** steps.
Format mirrors `docs/GL_POP_IM_SOP_Backlog.md`'s own Wave convention.

**How to use this backlog:** same protocol as `GL_POP_IM_SOP_Backlog.md`
— claim a row (session name + start date) before starting, push the
claim as its own small commit first, mark `Done` with a commit
reference rather than deleting the row, never edit another session's
row. Per the prime directive, every row below that names a peer
dependency must list it explicitly, not just the most salient one.

---

## Wave 0 — repo skeleton (CM, no dependencies)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 0.1 | Create `fish-er-omniview` GitHub repo + remote | CM | — | **Done** |
| 0.2 | Kotlin/Ktor/Exposed skeleton, package `com.theprodeogroup.omniview`, mirroring the established sibling shape (`build.gradle.kts`, wrapper, `Application.kt` entrypoint) | CM | 0.1 | **Done** — compile + fat-jar verified locally |
| 0.3 | `GET /health` route (ALB target-group check, same pattern as every sibling) | CM | 0.2 | **Done** |
| 0.4 | Jenkinsfile (build/test/deploy pipeline, mirroring an existing sibling's) | CM | 0.2 | **Written; blocked on Jenkins GitHub-scanning PAT not yet scoped to this repo — Femi's own action, in progress** |
| 0.5 | Terraform: ECS/ALB/ACM for `omniview.theprodeogroup.com`, no RDS (no persistence required — SRS §4) | CM | 0.1 | Not started |
| 0.6 | Wire `fish-er-omniview` as a submodule of top-level `FiSH/`, update `.gitmodules` and `CLAUDE.md`'s repo table | CM | 0.2 | **Done** |
| 0.7 | **New 2026-10-03**: frontend build + serving for the migrated UI (Wave 3) — Vite/React build step, served via Ktor `staticResources` from the same ECS deployment (no separate CloudFront/S3, per DDD design §3's "no bespoke infrastructure" default — confirm or override) | CM | 0.2 | Not started — **not needed until Wave 2 is done, flagging early per the prime directive, not urgent** |

**Corrected 2026-10-03, then corrected again same day by Femi directly**:
`fish-gl-web`'s `OperatorSupportInboxPage.tsx` already implements all
four use cases (`PlatformHealthStrip`, `TenantsOverview`,
`OperatorInbox`, the sign-in gate) — that part never changed. What
changed twice is *where it ends up*: not a base-URL swap staying in
WEB, but a **full migration** into `fish-er-omniview` — Omniview is
exempt from the new shared-frontend convention specifically because
it's not client-facing. Waves 1–2 below are backend-only regardless;
Wave 3 is now "stand up Omniview's own frontend + migrate the
component in," not "swap one constant in WEB." See
`Omniview_Extraction_DDD_Design.md` §3's twice-corrected "Web UI"
section for the full reasoning.

## Wave 1 — platform health backend (lowest-risk first slice, no EA/WEB dependency)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 1.1 | Port `PlatformHealthGateway`/`KtorPlatformHealthGateway` from EA into Omniview, unchanged in behavior (FR-OV-1 through FR-OV-5) | Omniview | 0.2 | Not started |
| 1.2 | `GET /operator-health` route serving it (route naming per SRS §7.1) | Omniview | 1.1 | Not started |
| 1.3 | Port the existing gateway test suite (GL X-Request-Id case, 2xx/non-2xx, timeout, unconfigured-URL cases — already written and passing in EA, straightforward port) | Omniview | 1.1 | Not started |

## Wave 2 — platform overview + messaging backend (EA stays unchanged — pure proxy)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 2.1 | Backend route accepting the operator's token and proxying `GET /operator/tenants` to EA (UC-OV-2, FR-OV-6/7/8) | Omniview | 1.2 | Not started — **depends on EA's route staying stable; zero EA-side change needed per DDD §1** |
| 2.2 | Backend routes proxying EA's `GET /operator/support-threads` + `POST .../messages` (UC-OV-3, FR-OV-9/10/11) | Omniview | 1.2 | Not started — **same EA-stability dependency as 2.1** |

## Wave 3 — Omniview stands up its own frontend, full migration (depends on Wave 2 + CM's build/serving infra)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 3.1 | Confirm Omniview's frontend build/serving shape (0.7 — Ktor `staticResources` default, or CM overrides) | CM | 2.1, 2.2, 0.7 | Not started |
| 3.2 | WEB hands over `OperatorSupportInboxPage.tsx` + `api/operatorSupport.ts` content | WEB | 3.1 | Not started — **coordinated handover, WEB's own message offered this directly** |
| 3.3 | Port the component into Omniview's new frontend, repointed at Omniview's own backend routes (2.1/2.2 + the Wave 1 health route) instead of EA's — expected close to verbatim per WEB's own assessment (already isolated from the Tenant app shell, no Cognito dependency) | Omniview | 3.2 | Not started |
| 3.4 | Deploy and verify all four use cases (UC-OV-1 through 4) against Omniview in production, side-by-side with WEB's still-live `/operator`, for at least one real operating cycle | Omniview | 3.3 | Not started |
| 3.5 | WEB removes its own `/operator` route, in the same coordinated window as 3.4's verification — not speculatively early, per WEB's own stated sequencing | WEB | 3.4 | Not started — **claim a row in `WEB/COORDINATION.md`; coordinate the exact cutover window directly with WEB, don't act unilaterally** |

## Wave 4 — cleanup (depends on Wave 3 being verified)

**Note**: EA's `/operator/tenants`/`/operator/support-threads`/`.../messages`
routes are **not removed** — Omniview's Wave 2 routes proxy to them
forever (DDD design §1's resolved seam); only the now-genuinely-dead
health gateway is removable, since Omniview's own health check is a
fully independent implementation, not a proxy.

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 4.1 | Remove `PlatformHealthGateway`/`OperatorPlatformHealthRoutes` from EA — the one piece that's genuinely dead once Omniview's own version is live and WEB's cut over | EA-fork | 3.5 | Not started — **EA-fork's own call, their checkout** |
| 4.2 | Update `FiSH/CLAUDE.md` and any stale docs still describing EA's `/operator` or WEB's `/operator` as the live operator console | Omniview or CM | 3.5 | Not started |

## Wave 5 — future, explicitly out of scope for this backlog

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 5.1 | ER/Education Runtime status data (FR-OV-12) | — | A fresh design pass, not scoped here | **Parked** |
| 5.2 | GL/sibling financial data (FR-OV-13) | — | A fresh design pass, not scoped here | **Parked** |
| 5.3 | Real operator identity system, replacing the token bridge | — | A fresh design pass, not scoped here | **Parked** |

---

## Dependency chain, summarized

```
0.1 → 0.2 → { 0.3, 0.4, 0.6, 0.7 }
0.1 → 0.5
0.2 → 1.1 → { 1.2 → 2.1, 1.2 → 2.2, 1.3 }
{ 2.1, 2.2, 0.7 } → 3.1 (CM) → 3.2 (WEB) → 3.3 → 3.4 → 3.5 (WEB)
3.5 → 4.1 (EA-fork), 3.5 → 4.2
```

Wave 0 is entirely CM's, now including frontend build/serving infra
(0.7) once the full-migration decision landed. Waves 1–2 are
backend-only, no peer dependency beyond CM's skeleton existing and
EA's current routes not changing underneath (no action needed from
EA-fork, just non-interference). Wave 3 now needs both CM (confirm
the serving shape) and WEB (hand over the component, then remove their
own route in a coordinated window) — not a single swap anymore, a real
coordinated migration. Wave 4 is the only wave needing EA-fork to act,
and only removes what's genuinely dead (the health gateway) — EA's
tenant-overview/messaging routes are permanent, not a cutover target.
