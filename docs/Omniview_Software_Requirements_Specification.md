# Omniview — Software Requirements Specification

**Status:** draft, 2026-10-03. Companion to `docs/Omniview_Extraction_DDD_Design.md`
(the architecture/extraction design, already agreed with CM and the
EA-fork session) — this document formalizes that agreed design into
requirements form; it does not re-open anything already decided there
(repo name, domain, auth mechanism, data-ownership seam).

---

## 1. Introduction

### 1.1 Purpose

This SRS defines the functional and non-functional requirements for
**Omniview**, the Prodeo Group's cross-platform operator oversight
console. It guides the initial build (repo `fish-er-omniview`) and
serves as the baseline Femi, CM, and the EA-fork session are building
against.

### 1.2 Scope — the problem this solves

**The problem, stated plainly:** there is no single place to see how
the whole platform is doing. Today, answering "is everything healthy,
which Tenants need attention, what's in the support queue" means
checking EA's `/operator` page for Tenant/support status, separately
checking each service's own `/health` endpoint or AWS console for
reachability, and having no visibility into ER/Education Runtime at
all from any of it. As the platform has grown from one service to
eleven repos across two product families (FiSH and ER), this
fragmentation has grown with it — and Prodeo is actively hiring an
operations team who will need this view and currently have nowhere to
get it.

**What Omniview is:** *"where I oversee everything in the
FiSH+ERverse"* (direct instruction, 2026-10-03) — a single,
operator-facing console giving cross-service, cross-tenant visibility
platform-wide. Internal tooling only; never client-facing, the same
"strictly for management and support" boundary the original operator
overview inside EA was built under.

**What Omniview is not:** a second system of record for anything.
Every sibling service keeps owning its own data; Omniview calls out
and aggregates/presents, never absorbs. It is also explicitly not
(yet) a financial-data or deep business-data surface — see §3.4 and
the DDD design's own staged-phase framing.

In scope for this SRS: the three capabilities that exist today inside
EA and are being extracted out (platform health, cross-tenant
overview, operator messaging), plus the console itself (sign-in,
layout). Out of scope: any new data source beyond what already exists
(ER/Education Runtime status, GL financial signals — both explicitly
future work, not designed here).

### 1.3 Definitions, Acronyms and Abbreviations

| Term | Definition |
|---|---|
| Operator | Prodeo's own platform management/support staff (today: Femi alone; an ops team is being hired) — never a Tenant's own staff |
| Tenant | A FiSH/ER customer organization, as EA already models it |
| Sibling service | Any of GL, POP, SOP, IM, HR, EA, ER/Education Runtime — the services Omniview observes but never owns data for |
| Operator token | `X-Operator-Token`, EA's existing interim per-operator auth bridge (`EA_OPERATOR_TOKENS`) — reused, not replaced, by Omniview |
| FiSH+ERverse | The user's own term for the combined FiSH (financial/GL-rooted) and ER (Education/operations-rooted) platform family Omniview oversees |

### 1.4 References

- `docs/Omniview_Extraction_DDD_Design.md` — the architecture this SRS formalizes; read first for the *why* behind every design call referenced here.
- `EA/EA_Development_Backlog.md` item 09 — the original "operator's own half moved to Omniview, not the Tenant's own send/read surface" boundary.
- `docs/Tenancy_Administration_Extraction_DDD_Design.md` — the precedent extraction this one's structured after.

### 1.5 Overview

Section 2 describes Omniview at a product level. Section 3 states
functional requirements by capability. Section 4 covers data
requirements (what's read, never owned). Section 5 covers external
interfaces (every sibling Omniview calls). Section 6 covers
non-functional requirements. Section 7 holds open items.

---

## 2. Overall Description

### 2.1 Product Perspective

Omniview is a new, standalone sibling service — not a module inside
any existing one. It sits *above* every other service, observing
them, rather than beside them in the usual peer-to-peer calling
pattern:

```
flowchart TD
  Op[Operator, browser] --> OV[Omniview backend]
  OV -->|forwards operator token| EA[EA /operator/*]
  OV -->|public, unauthenticated| GL[GL /health]
  OV -->|public, unauthenticated| POP[POP /health]
  OV -->|public, unauthenticated| SOP[SOP /health]
  OV -->|public, unauthenticated| IM[IM /health]
  OV -->|public, unauthenticated| HR[HR /health]
```

Every arrow out of Omniview is read-only today. No sibling service
calls *into* Omniview — it has no callers, only a browser-facing
operator and outbound calls to everyone else.

### 2.2 Product Functions (Summary)

| Capability | Primary function |
|---|---|
| Platform Health | At-a-glance reachability for GL/POP/SOP/IM/HR |
| Platform Overview | Every Tenant's onboarding/KYB/support status at once |
| Operator Messaging | Read and reply to Tenant support threads, operator side |
| Console | Sign-in (operator token entry), layout hosting the above |

### 2.3 User Classes and Characteristics

| User class | Description | Technical proficiency |
|---|---|---|
| Platform operator | Prodeo's own management/support staff; views cross-tenant, cross-service status; replies to support threads | Moderate — internal staff, not a general public user |

There is exactly one user class. Unlike every client-facing FiSH/ER
product, Omniview has no Tenant-side user at all — that's the whole
point of the EA/Omniview split (§1.2; *"EA is for each tenancy"*).

### 2.4 Operating Environment

- Cloud-first SaaS, AWS (ECS/Fargate), same infrastructure shape as every sibling.
- Kotlin/Ktor/Exposed backend, matching the established platform stack — no new technology introduced.
- Desktop-first (an operator's own workstation); no stated mobile requirement, unlike client-facing products.
- Domain `omniview.theprodeogroup.com`.

### 2.5 Design and Implementation Constraints

- **Never a second system of record.** Every requirement in §3 is read-through to a sibling's own data; Omniview persists nothing of another service's domain state (§4).
- **No new auth mechanism.** Reuses EA's existing operator-token bridge end-to-end — resolved 2026-10-03 after a real design correction (a service-account approach was proposed, then withdrawn once it was shown to undo per-operator attribution; see DDD design §1).
- **No EA-side code changes required.** EA's existing `/operator/*` routes are called as-is.
- Must not introduce any new financial/revenue/transaction data surface — the same boundary the original operator overview inside EA was built under.

### 2.6 Assumptions and Dependencies

- EA's `/operator/tenants`, `/operator/support-threads`, `/operator/tenants/{tenantId}/support-thread/messages` routes remain stable and reachable — Omniview has no fallback if EA is down (its own platform-health check would simply show EA as unreachable, same as any other sibling).
- GL/POP/SOP/IM/HR's public `/health` endpoints stay unauthenticated, as they are today.
- An operator already holds (or is issued) a valid EA operator token — Omniview does not provision or rotate these; that stays EA's own `EA_OPERATOR_TOKENS` secret.

---

## 3. System Features (Functional Requirements)

Each requirement is `FR-OV-<n>`, priority per MoSCoW (M = Must, S =
Should, C = Could).

### 3.1 Platform Health

| ID | Requirement | Priority |
|---|---|---|
| FR-OV-1 | System shall check GL, POP, SOP, IM, HR reachability in parallel, not sequentially | M |
| FR-OV-2 | System shall treat GL specially: liveness determined by the presence of an `X-Request-Id` response header on its `/api` root (GL's own `/health` is deliberately ALB-only, unreachable publicly), not by HTTP status | M |
| FR-OV-3 | System shall treat a non-2xx response, a connection failure, or a timeout as "down," each distinguishable in the response (`detail` field) | M |
| FR-OV-4 | System shall report per-service latency when reachable | S |
| FR-OV-5 | System shall report a service with no configured URL as down without attempting a call | S |

### 3.2 Platform Overview

| ID | Requirement | Priority |
|---|---|---|
| FR-OV-6 | System shall show every Tenant at once: name, status, segment, KYB status, phone-verification status, company count, staff count, support-message count, awaiting-reply flag | M |
| FR-OV-7 | System shall source this data by calling EA's existing `GET /operator/tenants`, forwarding the operator's own token — never by querying EA's database directly or duplicating its schema | M |
| FR-OV-8 | System shall display no revenue, transaction, or other financial/business data in this view | M |

### 3.3 Operator Messaging

| ID | Requirement | Priority |
|---|---|---|
| FR-OV-9 | System shall list every Tenant's operator-thread messages, grouped by Tenant, most recent first | M |
| FR-OV-10 | System shall let the operator reply within a Tenant's thread | M |
| FR-OV-11 | System shall source and persist this via EA's existing operator-messages routes, forwarding the operator's own token — Omniview holds no message data of its own | M |

### 3.4 Explicitly Out of Scope

Per the DDD design's staged-phase framing (2026-09-19 original
instruction: *"start with lightweight health, grow into ER status,
then GL financial data as need for support and data analysis
increases"*):

| ID | Requirement | Priority |
|---|---|---|
| FR-OV-12 | ER/Education Runtime status data | **Future** — not designed, not built |
| FR-OV-13 | GL or any sibling's financial/revenue data | **Future** — not designed, not built |

These are named here only so a future SRS revision has an explicit
anchor point — building either without a fresh design pass is
out of scope for this document.

---

## 4. Data Requirements

Omniview's own persistence (if any) is limited to its own operational
concerns — **never** another service's domain data:

| Data | Owned by | Omniview's relationship |
|---|---|---|
| Tenant/Membership/KYB status | EA | Read-through, via API call, never cached beyond the request/response |
| Support/operator messages | EA | Read-through and write-through (reply), via API call |
| Service health | N/A (derived) | Computed fresh on each request, not stored |
| Operator token | Operator's own browser (entered at sign-in) | Held client-side for the session, forwarded per-request — see §7.1 for the open question on exactly how |

No database is required for the scope in this document. If a future
phase needs Omniview-owned state (an acknowledged-alert flag, a saved
filter), that is a new, separately-scoped decision — not assumed here,
per this project's own "minimal builds" discipline.

---

## 5. External Interface Requirements

| Interface | Direction | Purpose |
|---|---|---|
| EA `/operator/tenants` | Outbound | Platform overview (FR-OV-6/7) |
| EA `/operator/support-threads`, `/operator/tenants/{id}/support-thread/messages` | Outbound | Operator messaging (FR-OV-9/10/11) |
| GL `/api` (root, `X-Request-Id`-based check) | Outbound | Health (FR-OV-2) |
| POP, SOP, IM, HR `/health` | Outbound | Health (FR-OV-1/3/4) |
| Omniview's own `/operator-health`, `/operator-overview`, `/operator-messages` (naming TBD, see §7.2) | Inbound | The browser console's own calls to its backend |

No service calls *into* Omniview (§2.1) — there is no inbound
interface for siblings to integrate against.

---

## 6. Non-Functional Requirements

| ID | Requirement |
|---|---|
| NFR-OV-1 | Health checks across all five services shall complete in roughly the time of the single slowest check, not their sum (parallel execution, already built — `coroutineScope`/`async`) |
| NFR-OV-2 | Per-operator action attribution and individual token revocation shall be preserved end-to-end for every EA-calling capability — the explicit reason the service-account approach was rejected (DDD design §1) |
| NFR-OV-3 | No EA-side route, auth mechanism, or schema change required to ship this — a constraint, not just a nicety, agreed directly with the EA-fork session |
| NFR-OV-4 | No new financial/business data of any kind surfaced in this release (§3.4) |
| NFR-OV-5 | Deployed the same way every sibling is (ECS/Fargate, Jenkins CI/CD) — no bespoke infrastructure |

---

## 7. Appendices

### 7.1 Open Issues / TBDs

- **How an operator's EA token gets into Omniview.** Candidate (not yet built): Omniview's own sign-in gate asks for the same EA operator token directly, mirroring WEB's existing pattern — one more hop on the existing "bridge until real identities exist" mechanism, not a new one. See DDD design §4.3.
- **Whether operator-messaging's underlying data should eventually move to Omniview outright**, now that messaging is inherently cross-tenant. Flagged, not decided (DDD design §4.4).
- **Exact Omniview-side route names** for the browser-facing API (§5's "naming TBD") — not yet designed; see the Use Case document's own flows for the shape these need to support.

### 7.2 Traceability to the DDD Design

Every FR-OV requirement in §3 traces to a decision already made and
agreed in `docs/Omniview_Extraction_DDD_Design.md`:

- FR-OV-1 through FR-OV-5 → DDD §0/§2 item 1, `PlatformHealthGateway` (the one clean, zero-dependency move).
- FR-OV-6 through FR-OV-11 → DDD §1's resolved auth mechanism and "one real seam" — the gateway-via-token-forwarding pattern, not a data migration.
- FR-OV-12/13 → DDD §2's explicit staged-phase boundary.
