# fish-gl-web → fish-web Rename: Dependency-Ordered Plan

**Status:** scoping only, 2026-10-03 - nothing executed yet. Direct instruction: "Legacy moniker that ought to be fish-web" - `fish-gl-web` no longer reflects what this app actually is (the shared frontend for GL/SOP/POP/IM/HR/EA, not a GL-specific tool), so the name should drop the `-gl-` segment. Mirrors `docs/SchoolAdmissions_To_EducationRuntime_Rename_Plan.md`'s own phase structure - the one directly comparable precedent in this project, scoped and executed cleanly before.

**Naming decided, direct instruction 2026-10-03:**
- **Repo**: `fish-gl-web` → **`fish-web`**.
- **Folder path**: no change needed. Unlike SchoolAdmissions (whose submodule folder was literally named after the service), this repo's own folder in `FiSH/` is already just `WEB` - generic, not tied to "GL" - confirmed by reading `FiSH/.gitmodules` and the repo table in `CLAUDE.md`. Phase 2 below is a URL change only, no `git mv`.
- **npm package name**: no change needed - confirmed by reading `package.json`, it's already `"name": "web"`, not `"fish-gl-web"`. The legacy name only lives in the GitHub repo name and documentation/prose references.

**Scope note**: this plan lives at the `FiSH/` top level, same reasoning as the Education Runtime precedent - it spans the target repo, `FiSH/.gitmodules`, `CLAUDE.md`, and potentially `Infrastructure/`, not just `WEB/` itself.

**Ownership**: per the platform's standing convention, the actual GitHub rename, any Jenkins job config fix, and all of Infrastructure/Terraform route through CM - no session pushes or touches infra directly. `WEB/COORDINATION.md`'s row-claim protocol applies to any non-trivial change here, same as anywhere else in this repo.

**A known gotcha from the Education Runtime precedent, flagged proactively**: that rename's Phase 3.2 found Jenkins' own multibranch job config (`GitHubSCMSource`'s `<repository>`/`<repositoryUrl>`) hardcodes the old repo name - a GitHub rename alone silently breaks CI triggering until that's also fixed. Expect the same failure mode here; don't assume the GitHub-side auto-redirect is sufficient for Jenkins specifically.

---

## Phase 0 — Decisions to lock before any execution

| # | Decision | Status |
|---|---|---|
| 0.1 | Final repo name | **Decided**: `fish-web` |
| 0.2 | Folder path in `FiSH/` | **Decided: no change** - already generic (`WEB/`) |
| 0.3 | npm package name | **Decided: no change** - already generic (`"web"` in `package.json`) |
| 0.4 | Live domain (`capital.theprodeogroup.com`) | **Assumed no change**, not yet confirmed - needs CM to check whether the domain, S3 bucket, or CloudFront distribution name/comment literally embeds "fish-gl-web" anywhere (this session couldn't reach `Infrastructure/` to check directly - see Phase 4) |
| 0.5 | GitHub rename timing relative to other phases | Recommend the same ordering the precedent used: any internal/doc-only renames first (fully reversible, no external dependency), GitHub rename next (auto-redirects the old clone/fetch URL), Jenkins job fix immediately alongside it (not as an afterthought - this is the exact gotcha flagged above) |

---

## Phase 1 — Internal references within WEB's own repo

Self-contained, no deploy, no consumer impact - confirmed by reading the code first, not assumed.

| # | Task | Depends on | Notes |
|---|---|---|---|
| 1.1 | `package.json` | 0.3 | **Already correct** - no change needed, confirmed `"name": "web"`. |
| 1.2 | Grep the whole repo (`README.md`, source comments, `Jenkinsfile`) for the literal string `fish-gl-web` and update any self-reference found | 0.1 | Not yet run this session - the first real task here. |
| 1.3 | Full build (`npm run build`) + lint (`npm run lint`) to confirm nothing broke | 1.2 | Low risk - this phase touches comments/strings, not code behaviour. |

---

## Phase 2 — GitHub repo rename

| # | Task | Depends on | Notes |
|---|---|---|---|
| 2.1 | Rename `prodeo-group-dev/fish-gl-web` → `prodeo-group-dev/fish-web` on GitHub (auto-redirects old clone/fetch URLs) | Phase 1 complete and merged; CM | CM's action, same as the Education Runtime precedent's 2.1. |
| 2.2 | `FiSH/.gitmodules`: submodule `url` updated to the new repo URL - **`path` stays `WEB`**, unlike the Education Runtime case (0.2 above - no folder move) | 2.1 | |
| 2.3 | Every existing local checkout of `FiSH/` needs its nested `WEB/.git`'s `origin` remote repointed (`git remote set-url origin <new-url>`) after 2.2 lands - same real gotcha the Education Runtime rename hit (this project's checkouts use plain nested `.git` dirs, not git's internal submodule machinery, so `git submodule sync` alone isn't sufficient) | 2.2 | Worth a direct message to every active peer session when this actually happens, not just a commit message - the Education Runtime rename needed that too. |

---

## Phase 3 — CI identifiers (Jenkinsfile + the Jenkins job itself)

| # | Task | Depends on | Notes |
|---|---|---|---|
| 3.1 | `Jenkinsfile`: check for any literal `fish-gl-web` string (image tags, build artifact names) - rename only build-local identifiers (e.g. a `--cache-from` tag), **not** any literal AWS resource name/family string that must keep matching real infrastructure (same correction the Education Runtime precedent had to make to its own Phase 3.1 after finding this out the hard way) | Phase 4's findings on what AWS resource names actually are (don't guess) | |
| 3.2 | Jenkins' own multibranch job configuration (`GitHubSCMSource`'s repository/URL fields) - fix in the **same change** as 2.1, not after discovering CI silently stopped triggering | 2.1, CM | This is the proactively-flagged gotcha from the top of this doc. Doing this reactively (as the Education Runtime rename did, not by original plan) cost real time there - worth doing it deliberately this time. |

---

## Phase 4 — Infrastructure (Terraform) - CM-owned, not yet scoped in detail

**This session could not reach `Infrastructure/` to check real resource names** (permission boundary for this session specifically) - everything below is a question for CM to answer directly, not a guess.

| # | Task | Depends on | Notes |
|---|---|---|---|
| 4.1 | Check whether any Terraform-managed resource (S3 bucket name, CloudFront distribution comment/name, IAM policy names, Jenkins job name itself) literally embeds `fish-gl-web` or `fish_gl_web` | CM | First real task - everything else in this phase depends on what this finds. |
| 4.2 | If an S3 bucket name is affected: **do not rename in place** - S3 bucket names are globally unique and a rename is a genuine create-new-bucket-and-copy-data operation, not a Terraform `state mv`-safe identifier change. Same "ForceNew = real risk, don't touch live" reasoning the Education Runtime precedent applied to its own ECR repo/ECS service/IAM roles. | 4.1 | If this applies, it likely belongs in `docs/Downtime_Maintenance_Backlog.md` alongside the other deferred-to-downtime renames, not done live. |
| 4.3 | If only Terraform *identifiers* (not literal AWS resource names) need renaming for readability, use `terraform state mv`, never a bare rename-and-apply, and confirm `terraform plan` shows no destroy before applying | 4.1 | |

---

## Phase 5 — Docs

| # | Task | Depends on | Notes |
|---|---|---|---|
| 5.1 | `CLAUDE.md`'s own repo table: `WEB/` row's GitHub repo name (`fish-gl-web` → `fish-web`) | Phases 1-4 substantially complete, so docs describe the final shipped state, not a mid-rename one | Mirrors the Education Runtime precedent's own Phase 6 sequencing logic. |
| 5.2 | Other living reference docs that name `fish-gl-web` directly (this doc itself once renamed is done; `docs/GL_POP_IM_SOP_Backlog.md`/`Coordination.md` if they reference it by repo name rather than just "WEB") | 5.1 | Not yet inventoried - a grep across `docs/` for the literal string, same approach the Education Runtime precedent used. |
| 5.3 | **Deliberately NOT touched**: historical/point-in-time records (memory files describing past work, any dated investigation or design doc using "fish-gl-web" as a direct quote of what was true then) - same "point-in-time record" treatment the Education Runtime rename's own Phase 6/7 applied to ADRs and SRS docs, not silently "corrected" after the fact. | n/a | |

---

## Summary: what can start today vs. what's blocked

- **Can start immediately, no coordination needed**: Phase 1 (grep + fix internal self-references within WEB's own repo).
- **Needs CM specifically**: Phase 2.1 (the actual GitHub rename), Phase 3.2 (Jenkins job config), all of Phase 4 (this session has no `Infrastructure/` access to even scope it, let alone execute).
- **Low-risk, follows once 2.1 lands**: Phase 2.2/2.3 (`.gitmodules` + every checkout's remote), Phase 5 (docs).
- **Not yet known**: whether Phase 4 surfaces a real `ForceNew` resource (S3 bucket) that needs deferring to a planned downtime window, same shape as the Education Runtime rename's own Phase 8. CM's Phase 4.1 finding determines this.
