# EduSys as a separate installable app: Scope, Plan, Use cases, Tasks, Order (SPUTO)

**Status: DRAFT 1, 2026-10-07. Design only; nothing built, nothing decided.** Femi asked for this design pass (reopening the 2026-10-05 "KIV"), to be done by the `+ER Education` session with CM. Reason he gave: FiSH+ER (EduSys) is the arrowhead into the Nigerian market. Written by the +ER Education session. Facts are tagged **[verified]** (read from code or probed live by me on 2026-10-07), **[CM]** (infrastructure facts CM verified in Infrastructure master and sent me, 2026-10-07) or **[open]** (not known; named so nobody assumes it).

## 1. Scope

**In:** how a school gets "EduSys" as its own installable app, separate from the FiSH app: where it is hosted, what it shares with fish-web, what it must not share, how it installs and updates, and what each choice costs CM, WEB and each backend.
**Out:** building anything; the app's screens (WEB's, once decided); the teacher register and offline client contents (separate SPUTOs); the EduSys brand/icon work (Femi chose "EduSys" wordmark alone, Fraunces 600, gold on paper, 2026-10-05).

**What is already decided by Femi:** schools get their own installable app led by "EduSys"; it is a separate installable app, not just an alternate icon.

## 2. Plan: what has to be true (requirements) and the facts behind them

| ID | Requirement | Why |
|---|---|---|
| FR-APP-1 | A school user installs "EduSys" from the browser and it launches into the school app, not the FiSH app or the marketing page. | Separate installable app (Femi). |
| FR-APP-2 | Installing or updating one app never breaks the other. | Two apps from one codebase on one origin share one service worker and cache unless scoped apart. |
| FR-APP-3 | A school's data stored on a device (including future offline marks on a shared classroom phone) is not readable by the FiSH app, and vice versa. | Children's personal data; browsers isolate storage by **origin**, not by path. |
| FR-APP-4 | Sign-in and access are unchanged: the same Cognito identity, EA's `/me` decides which Companies and modules a person holds, Education Runtime decides their school roles. **Cost to accept under option B:** tokens live in browser storage, which is per origin, so a person with both apps signs in **twice**. | One identity; no second source of truth. |
| FR-APP-5 | Works on low-end Android phones on weak connections in Nigeria. | The arrowhead market. |
| FR-APP-6 | Every backend the school app calls accepts its origin (CORS). | Browsers block cross-origin calls otherwise. |

**Facts that decide the options**
- fish-web is one React PWA that routes by `window.location.pathname` (`/fish` the app, `/operator` the support inbox, anything else the marketing landing page). The manifest has `start_url: '/fish'`, and no explicit scope (the file's own comment says the scope stays `/`). The service worker is `autoUpdate` with `skipWaiting` and `clientsClaim`. **[verified, WEB `vite.config.ts` and `App.tsx`]**
- **Education Runtime had no CORS handling at all.** A live preflight from the WEB origin returned a bare 404 with no `Access-Control-*` headers, so a browser could not call Education Runtime. Fix reviewed and merged by CM as ER PR #11 (e08defe), env var `SCHOOLADMISSIONS_CORS_ALLOWED_ORIGIN` already live on task definition :70, **a comma-separated list**, so adding a second origin later is an env change only. **[verified, live probe and code; CM merged, deploy in progress: live confirmation pending, update this line when CM confirms]**
- GL, EA, HR, IM, POP, SOP each allow exactly **one** CORS origin, `https://capital.theprodeogroup.com` (`*_CORS_ALLOWED_ORIGIN`). **[CM]** A second origin means a code change (list support) plus env and redeploy in each service the school app calls.
- CloudFront serves `capital.theprodeogroup.com`, sends `/api/*` to the GL load balancer, and deliberately has **no single-page-app fallback**. WEB's deploy already serves `/fish` and `/operator` by copying `index.html` to extensionless S3 keys (WEB `Jenkinsfile`), so a sub-path is **one more copy line**; a CloudFront Function is needed only for **deep links** under it. A subdomain needs a new distribution or origin, an ACM certificate in us-east-1 (validated by a manual CNAME at the external DNS provider), DNS records Femi adds there, and **its own deploy leg** (bucket or prefix, plus its own invalidation) in WEB's Jenkinsfile. **[CM, corrected 2026-10-07]**
- Sign-in uses direct Cognito flows with no hosted-UI redirect URLs, so neither option needs callback changes. **[CM]** EA module grants (`EDUCATION_RUNTIME`) and `/me` are unchanged either way. **[CM]**
- Which backends a school-only app calls: Education Runtime always; EA for sign-in context (`/me`); HR once teaching-staff onboarding screens exist; IM and POP only if "School Operations" keeps showing them to school tenants (the 2026-09-29 tab mapping says it does). **[open: WEB to confirm the exact list; it decides how many services need CORS work under option B]**

## 3. The two options (path or subdomain), honestly compared

| | **A. Path on the same origin** (`capital.theprodeogroup.com/edusys/`) | **B. Own subdomain** (e.g. `edusys.theprodeogroup.com`) |
|---|---|---|
| CORS | none; the origin is already allowed everywhere | Education Runtime (list support done in the fix), EA, plus HR/IM/POP if called: code change + env + redeploy each **[CM]** |
| Hosting | one more `index.html` copy line in WEB's deploy (as `/fish` and `/operator`); a CloudFront Function only for deep links **[CM]** | new distribution/origin, cert (us-east-1, manual CNAME), DNS by Femi, plus its own deploy leg in WEB's Jenkinsfile **[CM]** |
| Sign-in | one origin, one sign-in | **per origin**: signing in to both apps means signing in twice **[CM]** |
| Installed FiSH app | must narrow scope from `/` to `/fish/`; already-installed copies update on their own cycle **[CM]** | untouched |
| Service worker and caches | one origin, so the two apps must be kept apart by scope by hand; a mistake affects both (FR-APP-2) | separate origin, separate worker and caches by construction |
| **Stored data on the phone** | **shared**: localStorage, IndexedDB and caches are per origin, so FiSH and EduSys can read each other's data (FR-APP-3) | **isolated by the browser** |
| Cookies/session | shared origin | separate |
| Brand | a path under the FiSH domain | its own address, matches "EduSys alone" |
| Effort | smaller infrastructure, more careful scoping | more infrastructure steps, simpler runtime |

**Recommendation (for Femi and CM to accept or reject): B, the subdomain.** The deciding reason is not hosting effort but **FR-APP-3 and FR-APP-2**: this app is meant to carry children's attendance and, later, an offline store on shared classroom phones, and only a separate origin makes the browser enforce the separation instead of our code. The extra cost is bounded now that Education Runtime's CORS takes a list; the work in the other services depends on the open list in section 2. Path-based is the right answer only if we decide the school app will never hold offline data and the two apps may share storage.

## 4. Use cases

- **UC-APP-1** A teacher opens the EduSys address on an Android phone, signs in, is offered "Install EduSys", installs it, and later launches it straight into the school screens.
- **UC-APP-2** A person with both a FiSH business and a school installs both apps; each launches its own app, each updates independently, neither sees the other's stored data.
- **UC-APP-3** A school admin on a laptop uses the same address in a normal browser tab, no install.
- **UC-APP-4** A new version is deployed; installed copies pick it up without breaking an open lesson register.
- **UC-APP-5** A person with only a school role (a teacher) sees only school screens (needs Education Runtime's roles route, tracked in the teaching-staff drafts).

## 5. Tasks (dependency-ordered; none started)

| # | Task | Owner | Depends on |
|---|---|---|---|
| 1 | Land Education Runtime's CORS fix and set `SCHOOLADMISSIONS_CORS_ALLOWED_ORIGIN` (this fixes today's live breakage regardless of this SPUTO) | Education Runtime code (ready), CM review/env/deploy | none |
| 2 | **Decision:** path vs subdomain; and whether the school app shows IM/POP | Femi (CM/WEB advise) | this document |
| 3 | WEB confirms which backends the school screens call | WEB | 2 |
| 4 | If B: list-origin support and env in each other service the school app calls (EA first) | each service owner, CM deploys | 2, 3 |
| 5 | If B: distribution/origin, certificate, DNS; if A: CloudFront Function and FiSH scope narrowing | CM (+ Femi for DNS) | 2 |
| 6 | A second web build of fish-web: its own manifest (name EduSys, icons, `start_url`/scope), entry route, and service worker; no FiSH screens bundled | WEB | 2, 5 |
| 7 | Role-based visibility so a teacher sees only school screens | WEB (needs Education Runtime's roles route) | teaching-staff drafts |
| 8 | Install-flow check on a real low-end Android phone on a throttled connection | WEB, CM | 6 |

## 6. Order

1 first (it is a live bug and independent). Then the **decision (2)**. Everything else follows from it; 4 and 5 can run in parallel once 2 and 3 are known; 6 needs 5; 8 last.

## 7. Decisions for Femi

1. **Path or subdomain** (recommendation: subdomain, reasons in section 3).
2. **Does the school app also show Inventory and Purchasing**, or only school screens? (Changes how many services need CORS work.)
3. **Is this app also the home of the teachers' offline register**, or is the offline client a separate native app? (Decided 2026-10-03 as "a separate client for hardware and offline"; the WEB scope reading was that the two fit together. If EduSys is a PWA, an offline store in the browser is possible, and origin isolation (FR-APP-3) then matters most.) **[open]**
4. **The EduSys address.** Femi has said "I will have to create edusys.theprodeogroup.com" **[CM, 2026-10-07]**, a strong indication he leans to option B with that address. Recorded as an indication, **not a decision**: he confirms. DNS is added by Femi at the external provider **[CM]**.

## 8. Risks

- **Today's live bug (task 1) is bigger than this design pass**: no browser call from WEB to Education Runtime can succeed until Education Runtime has CORS. Treat it as urgent on its own.
- Installed copies update on their own cycle, so any scope or manifest change reaches users late and unevenly **[CM]**.
- Two apps from one codebase can drift: keep the school build a subset of fish-web, not a fork.
- iOS PWA limits (install prompts, storage eviction) are **[open]**: not researched; matters if schools use iPhones, less so for the Android-first Nigerian target.
- Data cost: precaching two bundles on a metered connection **[open]**: needs a measured bundle size before promising "works on weak connections".
