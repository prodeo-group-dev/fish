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
| 0.1 | Create `fish-er-omniview` GitHub repo + remote | CM | — | Not started |
| 0.2 | Kotlin/Ktor/Exposed skeleton, package `com.theprodeogroup.omniview`, mirroring the established sibling shape (`build.gradle.kts`, wrapper, `Application.kt` entrypoint) | CM | 0.1 | Not started |
| 0.3 | `GET /health` route (ALB target-group check, same pattern as every sibling) | CM | 0.2 | Not started |
| 0.4 | Jenkinsfile (build/test/deploy pipeline, mirroring an existing sibling's) | CM | 0.2 | Not started |
| 0.5 | Terraform: ECS/ALB/ACM for `omniview.theprodeogroup.com`, no RDS (no persistence required — SRS §4) | CM | 0.1 | Not started |
| 0.6 | Wire `fish-er-omniview` as a submodule of top-level `FiSH/`, update `.gitmodules` and `CLAUDE.md`'s repo table | CM | 0.2 | Not started |

**Corrected 2026-10-03**: there is no frontend to build. `fish-gl-web`'s
`OperatorSupportInboxPage.tsx` already implements all four use cases
(`PlatformHealthStrip`, `TenantsOverview`, `OperatorInbox`, the
sign-in gate) — confirmed by the FiSH+ER WEB session checking the real
code, not assumed. Waves 1–2 below are backend-only; WEB's own change
(a single base-URL swap) is Wave 3, after both backend waves are done,
not interleaved per-capability — avoids WEB juggling two base URLs
mid-transition. See `Omniview_Extraction_DDD_Design.md` §3's corrected
"Web UI" section for the full reasoning.

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

## Wave 3 — WEB repoints to Omniview (one swap, not three)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 3.1 | Swap `api/operatorSupport.ts`'s `EA_API_BASE_URL` constant to Omniview's base URL, same `X-Operator-Token` header, no other code change | WEB | 2.1, 2.2 | Not started — **claim a row in `WEB/COORDINATION.md` when starting, per their own process** |
| 3.2 | Verify all four use cases (UC-OV-1 through 4) against Omniview in production for at least one real operating cycle before anything on EA's side is touched | WEB + Omniview | 3.1 | Not started |

## Wave 4 — cleanup (depends on Wave 3 being verified)

**Note**: EA's `/operator/tenants`/`/operator/support-threads`/`.../messages`
routes are **not removed** — Omniview's Wave 2 routes proxy to them
forever (DDD design §1's resolved seam); only the now-genuinely-dead
health gateway is removable, since Omniview's own health check is a
fully independent implementation, not a proxy.

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 4.1 | Remove `PlatformHealthGateway`/`OperatorPlatformHealthRoutes` from EA — the one piece that's genuinely dead once Omniview's own version is live and WEB's swapped | EA-fork | 3.2 | Not started — **EA-fork's own call, their checkout** |
| 4.2 | Update `FiSH/CLAUDE.md` and any stale docs still describing EA's `/operator` as the live operator console's backend | Omniview or CM | 3.2 | Not started |

## Wave 5 — future, explicitly out of scope for this backlog

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 5.1 | ER/Education Runtime status data (FR-OV-12) | — | A fresh design pass, not scoped here | **Parked** |
| 5.2 | GL/sibling financial data (FR-OV-13) | — | A fresh design pass, not scoped here | **Parked** |
| 5.3 | Real operator identity system, replacing the token bridge | — | A fresh design pass, not scoped here | **Parked** |

---

## Dependency chain, summarized

```
0.1 → 0.2 → { 0.3, 0.4, 0.6 }
0.1 → 0.5
0.2 → 1.1 → { 1.2 → 2.1, 1.2 → 2.2, 1.3 }
{ 2.1, 2.2 } → 3.1 (WEB) → 3.2
3.2 → 4.1 (EA-fork), 3.2 → 4.2
```

Wave 0 is entirely CM's. Waves 1–2 are backend-only, no peer
dependency beyond CM's skeleton existing and EA's current routes not
changing underneath (no action needed from EA-fork, just
non-interference). Wave 3 is WEB's own single swap — the only wave
that needs WEB to actually act, deliberately sequenced after both
backend waves so it happens once, not three times. Wave 4 is the only
wave needing EA-fork to act, and only removes what's genuinely dead
(the health gateway) — EA's tenant-overview/messaging routes are
permanent, not a cutover target.
