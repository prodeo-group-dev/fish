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

## Wave 1 — platform health (lowest-risk first slice, no EA dependency)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 1.1 | Port `PlatformHealthGateway`/`KtorPlatformHealthGateway` from EA into Omniview, unchanged in behavior (FR-OV-1 through FR-OV-5) | Omniview | 0.2 | Not started |
| 1.2 | `GET /operator-health` route serving it (route naming per SRS §7.1) | Omniview | 1.1 | Not started |
| 1.3 | Port the existing gateway test suite (GL X-Request-Id case, 2xx/non-2xx, timeout, unconfigured-URL cases — already written and passing in EA, straightforward port) | Omniview | 1.1 | Not started |
| 1.4 | Minimal frontend: health strip only, no sign-in required yet (UC-OV-4 can work standalone) | Omniview | 1.2 | Not started |
| 1.5 | Remove `PlatformHealthGateway`/`OperatorPlatformHealthRoutes` from EA once 1.1–1.4 are deployed and verified live | EA-fork | 1.4 | Not started — **EA-fork's own call, their checkout** |

## Wave 2 — platform overview + messaging (depends on Wave 1's console existing)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 2.1 | Operator sign-in gate (UC-OV-1) — token entry, client-side storage, 401/403 handling | Omniview | 1.4 | Not started |
| 2.2 | Backend proxy to EA's `GET /operator/tenants`, forwarding the operator's token (UC-OV-2, FR-OV-6/7/8) | Omniview | 2.1 | Not started — **depends on EA's route staying stable; no EA-side change needed per DDD §1** |
| 2.3 | Tenant-overview frontend view | Omniview | 2.2 | Not started |
| 2.4 | Backend proxy to EA's `GET /operator/support-threads` + `POST .../messages` (UC-OV-3, FR-OV-9/10/11) | Omniview | 2.1 | Not started — **same EA-stability dependency as 2.2** |
| 2.5 | Messaging frontend view | Omniview | 2.4 | Not started |

## Wave 3 — cutover (depends on Wave 2 being live and verified)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 3.1 | Verify Omniview's tenant-overview + messaging views in production, side-by-side against EA's existing `/operator` page, for at least one real operating cycle before removing anything | Omniview | 2.3, 2.5 | Not started |
| 3.2 | Remove `OperatorTenantOverviewRoutes`/`OperatorMessagesRoutes`' operator-token gate from EA (or the routes entirely, if nothing else calls them) | EA-fork | 3.1 | Not started — **EA-fork's own call, their checkout; not Omniview's to remove unilaterally** |
| 3.3 | Remove/redirect WEB's `/operator` page to `omniview.theprodeogroup.com` | WEB | 3.1 | Not started — **needs the FiSH+ER WEB session looped in, not yet done** |
| 3.4 | Update `FiSH/CLAUDE.md` and any stale docs referencing EA's `/operator` as the live operator console | Omniview or CM | 3.2, 3.3 | Not started |

## Wave 4 — future, explicitly out of scope for this backlog

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 4.1 | ER/Education Runtime status data (FR-OV-12) | — | A fresh design pass, not scoped here | **Parked** |
| 4.2 | GL/sibling financial data (FR-OV-13) | — | A fresh design pass, not scoped here | **Parked** |
| 4.3 | Real operator identity system, replacing the token bridge | — | A fresh design pass, not scoped here | **Parked** |

---

## Dependency chain, summarized

```
0.1 → 0.2 → { 0.3, 0.4, 0.6 }
0.1 → 0.5
0.2 → 1.1 → 1.2 → 1.4 → 1.5 (EA-fork)
1.1 → 1.3
1.4 → 2.1 → { 2.2 → 2.3, 2.4 → 2.5 }
{ 2.3, 2.5 } → 3.1 → { 3.2 (EA-fork), 3.3 (WEB) } → 3.4
```

Wave 0 is entirely CM's; Wave 1 has no peer dependency beyond CM's
skeleton existing; Wave 2 depends on EA's existing routes staying
stable (no action needed from EA-fork, just non-interference); Wave 3
is the only wave that needs EA-fork and WEB to actually act, and is
explicitly sequenced last so nothing gets cut over before it's proven
live.
