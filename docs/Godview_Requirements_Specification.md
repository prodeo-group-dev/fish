# FiSH — Godview (Platform Operator Overview): Requirements Specification

**Version:** 0.1 (draft)
**Date:** 2026-09-15
**Author:** Code Reviewer (for Femi)
**Status: draft — captures product intent + current build; gaps listed for scheduling.**
**Product framing (2026-09-13):** Godview is **“strictly for the management and support of the software… not client software at all.”** It is the platform operator’s console over **every Tenant**, not a tenant-admin dashboard and not a financial cross-tenant report.

**Owning service:** Enterprise Administration (EA), with WEB UI at `/operator`.  
**Related:** operator support inbox (same shell); `authorizeOperator` / `EA_OPERATOR_TOKEN`; `TenantRepository.findAll()`; `docs/Tenancy_Administration_Extraction_DDD_Design.md`; Support thread use cases (`SubmitSupportMessageUseCase`, `ReplyToSupportThreadUseCase`).

**Naming:** “Godview” / “God view” / “platform overview” / “Tenants” tab in the operator shell are the same product surface. Prefer **Godview** in product/requirements copy; keep route/API names (`/operator/tenants`, `OperatorTenantOverview`) unless a rename is explicitly scheduled.

---

## 1. Purpose

Define requirements for FiSH **Godview**: the platform operator’s cross-tenant overview used to **manage and support the FiSH platform** — onboarding progress, verification state, capacity signals (companies/staff), and support-thread activity — without exposing client business or financial data.

Godview answers: *Which tenants need attention from Prodeo as the software operator?*  
It does **not** answer: *How is Tenant X’s revenue or ledger performing?*

---

## 2. System overview

```
┌─────────────────────────────────────────────────────────┐
│  WEB  /operator  (no Cognito; operator token)           │
│  ┌──────────────────┐  ┌─────────────────────────────┐  │
│  │ Godview          │  │ Support inbox               │  │
│  │ (Tenants tab)    │→ │ (per-tenant thread)         │  │
│  └────────┬─────────┘  └──────────────▲──────────────┘  │
└───────────┼───────────────────────────┼─────────────────┘
            │ GET /operator/tenants     │ GET/POST support
            ▼                           │
┌───────────────────────────────────────┴─────────────────┐
│  EA  authorizeOperator (X-Operator-Token)                 │
│  Tenant + Membership + SupportMessage repositories        │
└───────────────────────────────────────────────────────────┘
```

Support inbox is a **sibling** concern in the same operator shell; this spec owns Godview (tenant overview) and the **hand-off** into a thread. Full support-chat UX beyond that hand-off may be detailed in a separate support SRS if needed.

---

## 3. Stakeholders

- **Platform operator (Prodeo)** — primary user; monitors tenants, prioritises support and onboarding risk
- **Support staff** (same or future role) — uses Godview to find awaiting-reply tenants, then replies in inbox
- **Compliance / KYB ops** — watches verification deadlines and phone/KYB status
- **Security** — must keep operator access tightly gated; no accidental tenant financial exposure
- **Tenant users** — **not** stakeholders of this UI; they never see Godview

---

## 4. Goals and non-goals

### 4.1 Goals

- **G1**: Show **every Tenant** regardless of status (Active, Draft, Suspended, Closed, …) — management tool, not `findAllActive`-style billing slice.
- **G2**: Surface **onboarding / trust** signals: KYB status + deadline, admin phone verification, tenant status, segment.
- **G3**: Surface **scale / footprint** signals EA owns: company count, active staff (membership) count.
- **G4**: Surface **support attention** signals: message count, awaiting-operator-reply flag; one click into that tenant’s thread.
- **G5**: Remain **EA-only data** — no joins to GL/SOP/POP/IM/HR for money, volumes, or inventory.
- **G6**: Accessible only to platform operators (not via tenant Cognito membership).

### 4.2 Non-goals (hard)

- **NG1**: No revenue, margins, journal activity, AR/AP aging, inventory value, payroll, or other **client business/financial** metrics.
- **NG2**: Godview is **not** client software — no tenant-facing equivalent, no “superuser into their books” from this screen.
- **NG3**: Not a replacement for AWS/ops dashboards (ECS health, RDS) — those stay infra.
- **NG4**: Not multi-tenant financial consolidation / group reporting (different product).

---

## 5. Functional requirements

### 5.1 Access and identity

- **FR‑GV1**: Godview is reachable only after successful **operator authentication** (today: shared `EA_OPERATOR_TOKEN` via `X-Operator-Token`; see §8 for identity evolution).
- **FR‑GV2**: Missing/invalid operator credentials → 401; operator access not configured → 503 `not_configured`.
- **FR‑GV3**: WEB entry at `/operator` (and `/operator/*`) **bypasses Cognito** tenant login — operator has no Tenant/Membership.
- **FR‑GV4**: Operator session in WEB may persist the token in browser storage for repeat visits (current pattern); sign-out clears it. Token must never appear in shareable URLs (unlike one-time supplier portal links).

### 5.2 Tenant overview (core Godview)

- **FR‑GV5**: List **all** tenants from `TenantRepository.findAll()` (every status).
- **FR‑GV6**: For each tenant, display at minimum:
  - Business name  
  - Tenant status  
  - Segment  
  - KYB status  
  - KYB verification deadline (if any)  
  - Admin phone verification status  
  - Company count  
  - Active staff count (`MembershipStatus.ACTIVE`)  
  - Support message count  
  - Awaiting support reply (true iff latest message exists and is **from the tenant**, not the operator; empty thread → not awaiting)
- **FR‑GV7**: Refresh overview on a short poll interval while the page is open (current target ~15s) or on manual refresh.
- **FR‑GV8**: From a tenant row with support activity, operator can **open that tenant’s support thread** in the Support inbox tab (same shell).
- **FR‑GV9**: Overview payload must **not** include financial or operational metrics from GL/SOP/POP/IM/HR.

### 5.3 Filtering, sorting, and attention (gaps / next increments)

*Partial or not built today — specify as product intent:*

- **FR‑GV10**: Filter by status, segment, KYB status, phone verification status, and “awaiting reply”.
- **FR‑GV11**: Sort by name, KYB deadline (soonest first), awaiting reply, staff/company counts.
- **FR‑GV12**: Attention summary strip: counts of awaiting-reply, KYB overdue/approaching deadline, Draft/Suspended tenants.
- **FR‑GV13**: Search by tenant name (and optionally tenant id).

### 5.4 Operator actions from Godview (optional increments — confirm before build)

*Not required for the 2026-09-13 MVP framing; list so they are not invented ad hoc:*

- **FR‑GV14** (optional): Navigate to tenant support thread (already implied by FR‑GV8).
- **FR‑GV15** (optional): View read-only tenant admin contact hints EA already stores (e.g. admin email) — still no financial data.
- **FR‑GV16** (optional): Trigger or deep-link existing EA operator-safe actions (e.g. reply templates) without leaving the shell.
- **FR‑GV17** (out of default scope until asked): Suspend/close tenant, extend KYB deadline, reset verification — only if separate use cases/APIs exist and are explicitly approved for operator UI.

### 5.5 Audit and abuse resistance

- **FR‑GV18**: All operator API calls authenticated; failed attempts do not leak tenant lists.
- **FR‑GV19** (increment): Audit log of operator overview access and support replies (who/when/tenant) once real operator identities exist (§8).
- **FR‑GV20**: Do not log full operator token values.

---

## 6. Non-functional requirements

- **Security**: Shared-token is interim; treat as high-privilege secret (env/Secrets Manager). Rotate without code change. Long-term: named operator identities + MFA (§8).
- **Tenancy boundary**: Godview is the **one** intentional cross-tenant read in EA for operators; it must not become a pattern for tenant JWTs to call `findAll()`.
- **Performance**: Overview for hundreds of tenants returns in a few seconds; avoid N+1 that loads all support messages into memory as the estate grows (see §11 — current implementation loads all messages once per request).
- **Availability**: Follows EA service availability; degrade gracefully if support repo fails (prefer empty support columns over failing the whole overview — design choice to confirm).
- **Usability**: Dense table OK for operators; badges for status/KYB/phone; clear “awaiting reply” affordance.
- **Privacy**: No client P&L; minimise PII in the grid (name + verification flags are enough for MVP).

---

## 7. Use case catalogue

- **UC‑GV01**: Sign in to operator shell with operator token  
- **UC‑GV02**: View Godview tenant table (all statuses)  
- **UC‑GV03**: Identify tenants awaiting support reply  
- **UC‑GV04**: Identify KYB / phone verification risk (deadline, status)  
- **UC‑GV05**: Open support thread for a tenant from Godview  
- **UC‑GV06**: Sign out / clear operator session  
- **UC‑GV07** (increment): Filter/sort/search Godview  
- **UC‑GV08** (increment): Attention summary dashboard strip  

---

## 8. Operator identity evolution

**Today (bridge):** single deployment secret `EA_OPERATOR_TOKEN`; header `X-Operator-Token`; compared in constant time in `authorizeOperator()`. Documented as bridge until real operator identities exist (same pattern as supplier portal token auth, but reusable not one-time).

**Target (when scheduled):**

- Named operator users (Prodeo staff) with MFA  
- Fine-grained roles if support-only vs full platform ops diverge  
- FR‑GV19 audit attribution  
- Retire shared token (or keep as break-glass only)

This spec does **not** mandate the target identity design — only that Godview stay behind operator-class auth, never tenant Cognito.

---

## 9. API and UI contract (current)

| Surface | Contract |
|---------|----------|
| API | `GET /operator/tenants` → `OperatorTenantOverviewDto[]` |
| Auth | `X-Operator-Token` / `authorizeOperator()` |
| WEB | `/operator` → Operator shell → **Tenants** (Godview) + **Support inbox** |
| Client API | `getPlatformOverview(token)` in `WEB/src/api/operatorSupport.ts` |
| Poll | ~15s while Godview mounted |

DTO fields: `tenantId`, `name`, `status`, `segment`, `kybStatus`, `kybVerificationDeadline`, `adminPhoneVerificationStatus`, `companyCount`, `staffCount`, `supportMessageCount`, `awaitingSupportReply`.

---

## 10. Acceptance criteria

1. Operator with valid token sees all tenants including non-Active.  
2. Tenant Cognito user **cannot** call `GET /operator/tenants` successfully.  
3. Overview contains no revenue/transaction/ledger fields.  
4. `awaitingSupportReply` is true only when the latest message is from the tenant.  
5. Clicking support activity opens that tenant in the Support inbox.  
6. Invalid token → sign-in / 401 path; unset `EA_OPERATOR_TOKEN` → 503.  
7. (When FR‑GV10–13 built) filters/sort/search match §5.3 without loading financial systems.

---

## 11. Build status against this spec

| Area | Status (2026-09-15) |
|------|---------------------|
| Product intent: management/support only, no financials | **Documented in code** (EA routes/DTOs, WEB Godview KDoc) |
| `GET /operator/tenants` + DTO (FR‑GV5, FR‑GV6, FR‑GV9) | **Built** (`OperatorTenantOverviewRoutes.kt`) |
| `authorizeOperator` / token gate (FR‑GV1–2) | **Built** (interim shared token) |
| WEB `/operator` shell + Tenants table (FR‑GV3–4, FR‑GV7–8) | **Built** (`OperatorSupportInboxPage.tsx`) |
| Support inbox sibling + reply APIs | **Built** (separate from Godview core; hand-off works) |
| Filter / sort / search / attention strip (FR‑GV10–13) | **Not built** |
| Real operator identities + audit (FR‑GV19, §8 target) | **Not built** |
| Optional management actions (FR‑GV15–17) | **Not built** / not scheduled |
| Overview query scalability (avoid full message scan) | **Gap** — current route loads `supportMessageRepository.findAll()` then filters in memory |

**Recommended next increments (when asked to implement):** (1) attention strip + awaiting-reply filter, (2) KYB deadline sort/filter, (3) replace all-messages scan with per-tenant aggregates, (4) operator identity design — **not** financial widgets.

---

## 12. Open questions

1. Confirm hard non-goal NG1 permanently (no “just one GL KPI” creep).  
2. Priority of FR‑GV10–13 vs operator identity (§8).  
3. Should Draft/Suspended/Closed be visually default-filtered or always shown?  
4. Break-glass shared token after named operators exist?  
5. Any operator actions beyond support reply that belong on the Godview row menu?
