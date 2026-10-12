# CI/CD reliability: SPUTO Playbook (CM, 2026-10-12)

Femi, 2026-10-12: "SPUTO this case so we have a reliable solution that can be a template for all services." Scope, Plan (SRS), Use cases, Tasks, Order. Owner: CM (Configuration Management). Docs only until approved.

## 1. Scope
**The case.** Between 10 and 12 October, ER's T-ER10 could not get a Jenkins build: no pull-request job was ever created, no check appeared, and my release script waited, timed out and gave up. The same session surfaced six other CI faults. They are all one family: **a change reaches production only when Jenkins reports on it, and Jenkins' reporting is not reliable or uniform across the eight repositories.** This Playbook makes the path from "a branch is pushed" to "the image is live" the same, observable and self-healing for every service, and makes the release tool a reviewed, versioned part of the platform.

**In scope:** GitHub webhooks, Jenkins multibranch discovery, PR build triggering, the release/merge gate (my scripts), CI capacity and disk, the duplicate GitHub Actions workflows, runbooks. **Out of scope:** the services' own pipelines' stages (tests, docker build, deploy), Terraform for ECS, application code.

## 2. Evidence (what actually happened)
| # | Fault | Evidence |
|---|---|---|
| E1 | **Webhooks are not uniform.** GL, EA, WEB and `common` hooks subscribe to `pull_request` + `push`; **POP, SOP, IM, HR and ER subscribe to `push` only.** | `gh api repos/.../hooks` on all repos, 2026-10-12 |
| E2 | A PR on a push-only repo gets no pull-request job until some later scan finds it; ER's T-ER10 never did (PR 25, then PR 26). Closing and reopening a PR sends a `pull_request` event, which those hooks ignore. | ER hook deliveries are all `push`; PR 25/26 have "no checks reported" |
| E3 | The hooks were created by hand ("remaining manual steps" in `jenkins.tf`), not by code, so nothing keeps them equal. | `Infrastructure/jenkins.tf` |
| E4 | **"This commit cannot be built"** appears intermittently as an `error` status, sometimes on a build that did run (e.g. EA PR 46 build 3: tests failed; later builds on the same head showed the same wording for a different reason). It does not say why. | EA PR 44, 46, IM PR 17, GL PR 87 `branch` context |
| E5 | **Two contexts per branch** (`jenkins/branch` and `jenkins/pr-merge`): one can fail or stay stale while the other passes (GL PR 87). | commit statuses |
| E6 | **My release script treated "no checks reported yet" as a pass** and merged GL PR 83 with no CI having run. Fixed 2026-10-11. | script log |
| E7 | **The script gave up after 10 minutes** while Jenkins, a single serialized node, needed up to an hour for a queue of builds; later passes were then never merged. Lengthened to 60 minutes. | many logs |
| E8 | **Disk fills and takes the node offline** (95% on 2026-10-08; 85% now, 5.6 GB free). Recovery is a manual Docker prune. | SSM `df` |
| E9 | **The release tooling lives in `/tmp` on one machine**, untracked and unreviewed. | CM |
| E10 | **GitHub Actions** workflows also run on the repos (unit, integration, "Deploy to ECS: skipping"), show "pending" for long periods and add noise next to the real (Jenkins) gate. | `gh pr checks` |
| E11 | A rebased branch cannot be force-pushed by the release path (blocked), so a PR sits on its old head and its status is stale. | EA PR 44 |
| E12 | Jenkins reports to GitHub only as commit statuses; nothing alerts when a build is stuck or the queue is long. | n/a |

## 3. Requirements
R1 Every repository's webhook has the same events (`push`, `pull_request`) and points at the same Jenkins endpoint; a script proves it. R2 If a webhook is missed, Jenkins finds the branch or PR anyway within 15 minutes (periodic scan). R3 One pull-request check is the merge gate: `jenkins/pr-merge` must be `success`; the `branch` context is informational and never blocks or approves. R4 The merge tool treats anything other than an explicit `success` as not-yet, never as a pass; "no checks" = pending with a visible reason. R5 The merge tool waits as long as the queue needs (default 90 minutes), reports queue position, and can be resumed. R6 "Cannot be built" is classified: infrastructure error (retry once automatically, then alert) vs test failure (stop and report the failing test). R7 The release tool is versioned, reviewed and installed from the Infrastructure repository, with tests. R8 CI disk never fills unattended: scheduled prune and an alarm below 20% free. R9 One CI gate per service: duplicate Actions workflows are removed or marked informational. R10 A branch protection rule requires the `pr-merge` check on every service's `master` (where the plan allows), so a merge without CI is impossible even by hand. R11 A runbook, and a status command ("show me every open PR and its state"), so nobody needs the Jenkins UI.

## 4. Use cases
UC-1 Push a branch: a PR job appears within one minute. UC-2 Push to a repo whose hook was missed: found within 15 minutes. UC-3 CM merges a PR: only on `pr-merge` success; if red, the failing test is printed. UC-4 Jenkins queue is long: the tool waits and shows "3rd in queue". UC-5 A build errors for a platform reason: retried once, then CM is told. UC-6 The disk falls below 20%: an alert, and the prune has already run. UC-7 A new service is added: one command configures its webhook, its Jenkins job, its branch protection (the template). UC-8 Anyone asks "what is blocking the release of X?": one command answers.

## 5. Tasks (dependency order)
- **T1 Make the webhooks uniform (immediate unblock).** Add the **Pull requests** event to the five push-only repos (POP, SOP, IM, HR, ER). Today this is a one-time GitHub setting change that needs repository admin: either Femi edits each hook (Settings, Webhooks, Edit, tick "Pull requests", Save: five clicks), or Femi grants the CLI token the `admin:repo_hook` scope once (`gh auth refresh -h github.com -s admin:repo_hook`) and CM does it and all later checks. 0.25 d. Unblocks ER PR 26, IM PR 17 at once.
- **T2 Webhooks as code** (`Infrastructure/scripts/ci/webhooks.sh` or Terraform's GitHub provider): create/verify the hook per repo from a list; a `--check` mode that fails if any repo differs; run weekly. Depends on T1's scope. 0.5 d.
- **T3 Safety net: periodic scan.** Configure every multibranch job (JCasC in `jenkins.tf`) to also scan every 15 minutes. 0.25 d (a Jenkins config change; Femi/CM apply).
- **T4 Release tool v2** in `Infrastructure/scripts/release/`: `svc_release`/`web_release`/`docs_merge` rewritten as one tested script. Gate = `pr-merge` success only; ignore `branch`; pending reasons; configurable wait; resumable; classify "cannot be built" (fetch the failing test from the build log through SSM when it is a test failure); no force-push (a new branch name when a rebase is needed, automated); `status` command listing every open PR, its head, its state and its queue position. 1.5 d, with tests against a fake `gh`.
- **T5 Disk and capacity.** A scheduled prune (systemd timer) and a CloudWatch disk alarm; measure queue wait over a week to decide whether a second executor or a larger instance is needed. 0.5 d + measurement.
- **T6 One gate: retire or demote the duplicate GitHub Actions workflows** (they show "pending" noise). Decision per repo. 0.25 d.
- **T7 Branch protection** on `master` of each service requiring `jenkins/pr-merge` (needs the plan to allow it on private repos; if not, the release tool is the only gate and T4 is the control). 0.25 d.
- **T8 Runbook + template** for a new service (`Infrastructure/docs/CI_Runbook.md`): the one-command onboarding of a service. 0.5 d.

## 6. Order
T1 (unblocks ER and IM today) first, then T3 and T4 in parallel, then T2, T5, T6, T7, T8. Nothing here touches application code or production data. Rollback: each step is a configuration change that can be reverted; T4 keeps the old script until the new one has released three services.

## 7. Decisions for Femi
1. **T1 now:** edit the five webhooks yourself (five clicks), or grant the `admin:repo_hook` scope so CM can do it and keep them uniform (recommended: the scope is limited to webhook administration).
2. Approve the Playbook (T2 to T8), in particular the periodic scan, the retirement of duplicate Actions workflows, and branch protection if the plan allows it.
3. CI capacity: accept the one-week measurement first, then decide a second executor or a larger instance (about 15 days since the last disk emergency; the node is a single t3.medium).

## 8. Risks
A periodic scan adds load on a busy single node; the measurement in T5 decides. Branch protection can block an emergency fix: the owner (Femi/CM) keeps the bypass. Rewriting the release tool touches the only path to production: T4 is released service by service, the old script kept until the new one is proven.
