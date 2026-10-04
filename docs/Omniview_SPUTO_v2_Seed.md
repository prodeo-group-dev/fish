# Omniview: SPUTO v2 Seed

**Status:** seed document, 2026-10-04. Written by CM at Femi's direction as the starting point for Omniview's second SPUTO pass (Scope, Plan, Use cases, Tasks, Order). The Omniview session adopts it, challenges it, and completes it. **Planning only: build and deploy stay suspended** until Femi says otherwise. Where this document differs from the 2026-10-03 SPUTO (`Omniview_Software_Requirements_Specification.md`, `Omniview_Use_Cases.md`, `Omniview_Backlog.md`, `Omniview_Extraction_DDD_Design.md`), this one reflects the newer direction. §7 lists every difference.

**How to read the labels.**
- **DECIDED**: said directly by Femi.
- **PROPOSED**: CM's suggestion, not yet agreed.
- **OPEN**: not decided; the SPUTO must resolve it.

---

## 1. S: Scope

### 1.1 Purpose (DECIDED)

Omniview is Prodeo Capital's read-only view across all tenancies. It exists for two purposes:

1. **Product Support.** A tenant's Owner Admin raises a ticket from inside FiSH. A Prodeo operator answers it from Omniview.
2. **Market Support.** Aggregate, non-identifying market reports for Prodeo Capital.

The platform-health strip and the tenant overview stay as supporting tools for those two purposes (DECIDED: "implied").

### 1.2 Principles (all DECIDED)

- **Read-only toward every other FiSH service.** Omniview may read; it never writes into any tenancy's data. It writes only to its own database.
- **Omniview owns its own data**: support tickets and replies, the gold rate table, and optionally aggregate report snapshots. Nothing else.
- **EA is not Omniview.** EA is the tenancy's own mini-Omniview. Tenancy communication (owner and staff of one tenant) continues in EA, unchanged. Product support to Prodeo Capital is a separate channel.
- **Only a tenant's Owner Admin raises a ticket.** Employees do not.
- **FiSH pulls, Omniview never pushes.** The chat reads replies from Omniview. Omniview never pushes a reply or notification into a tenant's side.
- **Resolving a ticket changes only Omniview's own record.** A change a ticket calls for in a tenancy is made by whoever owns that data.
- **Non-identification is sacrosanct.** No cohort size ever waives it.
- **Reports are unaudited.** Prodeo Capital is engaged as accountants, not auditors. Every report says so.
- **Gold is the base currency** for Prodeo Capital's market analysis; all fiat is translated to gold value.
- **Omniview is never internet-facing.** It is reachable only on Prodeo's private network. A tenant's browser never reaches it: a ticket arrives only through a FiSH service, over the private network, and replies come back the same way. (Femi, 2026-10-04: "Omniview is never internet facing".)

### 1.3 In scope / deferred / out of scope

| In scope | Deferred (own SPUTO later) | Out of scope |
|---|---|---|
| Product Support tickets | **Education Runtime status.** ER is a market subsector, a specialisation of industry (DECIDED) | Any per-tenant financial figure, ever |
| Market reports: tenant count, staff count, aggregate shareholders' funds, leverage (liabilities/equity and debt/equity) | Per-industry specialisations beyond the generic segment | Any write into EA, GL or any sibling |
| Health strip and tenant overview (supporting) | | Audit assurance |

### 1.4 Actors

- **Tenant Owner Admin**: raises tickets from inside FiSH; reads replies there.
- **Prodeo operator**: answers tickets, views health, overview and reports.
- Prodeo Capital is the consumer of market reports (via the operator).

### 1.5 Context

```
Owner Admin --FiSH chat--> a public FiSH service (PROPOSED: EA) --private network--> Omniview
                            (ticket in; replies pulled back the same way; never a tenant browser to Omniview)
Operator    --private access only--> Omniview   (how: OPEN, §6)
Omniview --GET--> EA  (tenant overview, staff and tenant counts; Owner Admin identity)
Omniview --GET--> GL  (NEW operator-only, totals-only aggregate route; does not exist yet)
Omniview --GET--> public /health of GL, POP, SOP, IM, HR
Omniview --own DB--> tickets, replies, gold rates, optional aggregate snapshots
```

---

## 2. P: Plan (requirements)

Existing IDs are kept where unchanged so nothing already written breaks. The v2 spec may renumber.

### 2.1 Product Support

| ID | Requirement | Status |
|---|---|---|
| FR-OV-S1 | A chat started inside FiSH by a tenant's Owner Admin creates a ticket owned by Omniview | DECIDED |
| FR-OV-S2 | A Prodeo operator triages and answers tickets from Omniview | DECIDED |
| FR-OV-S3 | Tickets and replies live in Omniview's own database, never written into EA or any service | DECIDED |
| FR-OV-S4 | The Owner Admin sees replies in the FiSH chat, pulled from Omniview | DECIDED |
| FR-OV-S5 | EA's tenancy-internal communication is unchanged and separate | DECIDED |
| FR-OV-S7 | Closing a ticket changes only Omniview's own record | DECIDED |
| FR-OV-S8 | Ticket states: Open, Answered, Closed | PROPOSED |
| FR-OV-S6 | Disposition of EA's existing operator-thread messages: migrate history or leave as legacy | OPEN |

### 2.2 Market Support

| ID | Requirement | Status |
|---|---|---|
| FR-OV-M1 | Report number of tenants and number of staff | DECIDED |
| FR-OV-M2 | Capitalisation = aggregate shareholders' funds, standard balance-sheet figures | DECIDED |
| FR-OV-M3 | Leverage: both liabilities-to-equity and debt-to-equity, each as an aggregate across the SME market. PROPOSED reading: ratio of aggregate totals, never an average of per-tenant ratios | DECIDED (ratio-of-totals PROPOSED) |
| FR-OV-M4 | Whole market and by segment. Industry is a segment dimension (DECIDED); jurisdiction and tenant segment are PROPOSED | DECIDED / PROPOSED |
| FR-OV-M5 | All fiat translated to gold value; gold is the base currency | DECIDED |
| FR-OV-M6 | Every figure obeys NFR-OV-7 | DECIDED |
| FR-OV-M7 | Every report carries an "unaudited, compiled from tenants' own books, no audit assurance" label plus the gold rate and date used | DECIDED |

### 2.3 Non-functional

- **NFR-OV-6 (DECIDED):** read-only toward every other service; verified by a test that outbound gateways expose no write method.
- **NFR-OV-7 (DECIDED): non-identification.** No per-tenant figure or breakdown anywhere: view, API, export, log, or stored snapshot. Minimum cohort determined statistically (minimum sample sizes), plus a concentration rule (max share any one tenant may hold of a published total), stricter test governs, plus suppression that defeats differencing. Enforced in code with tests. Tenants' permission taken first.
- **NFR-OV-8 (DECIDED): never internet-facing.** Omniview is reachable only on Prodeo's private network. Its inbound callers are a FiSH service relaying tickets and operators over private access, never a tenant's browser. Calls into it are authenticated service-to-service and size-limited, and ticket content is treated as untrusted input.
- **NFR-OV-9 (PROPOSED): a new privileged read path in GL is audited**, returns totals only, and enforces the cohort and concentration rules at the source.

### 2.4 Data ownership

| Data | Owner |
|---|---|
| Tenants, staff, KYB, Owner Admin identity | EA (Omniview reads) |
| Balance-sheet figures | GL (Omniview reads aggregates only) |
| Tickets and replies | **Omniview** |
| Gold rate table | **Omniview** |
| Aggregate report snapshots | **Omniview** (OPEN: store or compute fresh) |

---

## 3. U: Use cases

| ID | Use case | Source |
|---|---|---|
| UC-1 | Operator signs in (operator-token bridge) | existing UC-OV-1 |
| UC-2 | Operator views tenant overview | existing UC-OV-2 |
| UC-3 | Operator views platform health | existing UC-OV-4 |
| UC-4 | Owner Admin raises a ticket from FiSH | existing draft UC-OV-5 |
| UC-5 | Owner Admin reads replies in the FiSH chat (FiSH pulls) | new |
| UC-6 | Operator triages, answers and closes a ticket | existing draft UC-OV-6, extended |
| UC-7 | Operator views the market report (whole market or segment) | existing draft UC-OV-7 |
| UC-8 | Operator reads EA's existing operator threads (interim) | existing UC-OV-3, read-only. PROPOSED: retire once tickets exist |

---

## 4. T: Tasks by owner

| Owner | Tasks |
|---|---|
| **Omniview session** | Remove the write path (backlog 3.6). Ticket domain and schema. Ticket API (inbound). Operator ticket UI. Market report UI. Non-identification enforcement module with tests. Gold rate table and translation. v2 SRS, use cases, backlog |
| **GL session** | Design and build an operator-only, totals-only aggregate route: per-currency equity, liabilities and debt, by segment, with cohort and concentration enforced at source. Audited. GL has no operator concept or cross-tenant read path today |
| **WEB session** | Chat widget raises tickets through the FiSH service that relays to Omniview (never directly to Omniview), Owner Admin only, and reads replies the same way. Retires `/operator` only after Product Support is live (backlog 3.5) |
| **EA session** | PROPOSED: relay tickets and fetch replies over the private network, since EA already authenticates the Owner Admin and knows the tenant. Tenancy communication unchanged |
| **CM** | Rework `omniview.tf`: **private only**. The merged version puts a public ALB rule, a public certificate and a public DNS name on it, which contradicts the decision. Needs an internal path for operators, a database on the shared RDS, secrets and a security group. Jenkins PAT scope, targeted Terraform apply (state has drifted, a full plan is unsafe). Backups and recovery for a now-stateful service |
| **Femi / legal / statistician** | Tenants' permission wording and mechanism. Registering body's confidentiality rules. Cohort and concentration method and values. Gold price source, which price, as of which date. What counts as "debt". Segment list. The ticket model (who sees what) |

---

## 5. O: Order (PROPOSED)

- **Phase A: decide.** Resolve the blocking open decisions (§6). Nothing is built.
- **Phase B: foundation.** Remove the write path. Provision the database and secrets. Build the private relay path and its service-to-service authentication. Build the ticket domain.
- **Phase C: Product Support live.** Ticket intake from WEB, operator UI, pull-based replies. Then WEB retires `/operator` (backlog 3.5).
- **Phase D: Market Support.** GL aggregate route, gold translation, non-identification enforcement, the legal gates, then the report UI.
- **Phase E: deferred.** Education Runtime status gets its own SPUTO.

*Why Support before Market:* Product Support is self-contained and unblocks retiring WEB's `/operator`. Market reporting needs a new GL route, a gold source, a statistician-set threshold and tenants' permission, so it waits on people and decisions, not just code.

---

## 6. Open decisions

| # | Decision | Owner |
|---|---|---|
| 1 | Does the interim read-only EA thread view (UC-8) retire when tickets exist? | Femi |
| 2 | Disposition of EA's existing operator-thread messages (FR-OV-S6) | Femi |
| 3 | Which FiSH service relays tickets to Omniview (PROPOSED: EA) and how it authenticates to Omniview privately | CM + EA |
| 4 | How operators reach a private Omniview (VPN, SSM port-forward, or another internal-only path). The shared load balancer is public, so Omniview needs a different path | CM + Femi |
| 5 | Ticket model: fields, who sees which tickets, attachments, retention, notifications | Omniview + Femi |
| 6 | What counts as "debt"; the segment list beyond industry | Femi |
| 7 | Gold: price source, which price, as of which date (PROPOSED: closing rate at the balance-sheet date) | Femi |
| 8 | Cohort method and values; concentration threshold | Femi + statistician |
| 9 | Tenants' permission: wording and mechanism; registering body's rules | Femi + solicitor |
| 10 | Where aggregates are computed (PROPOSED: GL, totals only, per currency) | GL + Omniview + CM |
| 11 | Store aggregate snapshots, or compute fresh each time | Omniview |

---

## 7. Variance against the 2026-10-03 SPUTO

| Dimension | 2026-10-03 | 2026-10-04 |
|---|---|---|
| Purpose | Operator oversight console | Product Support + Market Support; health and overview supporting |
| Data | Stateless | Owns tickets, gold rates, optional snapshots (database) |
| Inbound callers | None | FiSH chat, Owner Admin only |
| Writes | Reply written into EA (FR-OV-10) | None into any other service |
| Financial data | Out of scope | Aggregate-only, gold, unaudited |
| Dependencies | EA + public health | + GL aggregate route, WEB widget, gold source, Owner Admin auth |
| Rules | Read-only | + non-identification, permission, unaudited label |
| Infra | No database | Database and secrets; `omniview.tf` reworked |
| EA | Message source | Not Omniview |
| Education Runtime status | Phase 2 | Deferred; ER is an industry segment |
| Exposure | Internal tool | Still internal, never internet-facing (DECIDED); tickets arrive via a FiSH service |

**Effect on what is already built (merged, not live):**
- **Keep:** health strip, tenant overview, thread reading, frontend scaffold, Dockerfile.
- **Remove:** the reply POST proxy and the reply box (backlog 3.6).
- **Rework:** `omniview.tf` (add database and secrets).
- **Not built yet:** tickets, owner auth, market reports, anything in GL.

---

## 8. Risks CM wants on the table early

1. **A GL aggregate route is a new privileged, cross-tenant read path** in a system built on strict per-tenant isolation. It must return totals only, be audited, and enforce cohort and concentration at the source.
2. **Intake crosses a trust boundary.** Tickets come from tenants' Owner Admins via a FiSH service. Omniview stays private, but the relay must authenticate the Owner Admin, and Omniview must treat ticket content as untrusted input (size limits, no HTML injection into the operator UI).
3. **Stateful service.** A database brings backups, recovery and connection slots. The shared RDS instance already hit a connection-exhaustion incident in September, so pool sizes must stay small.
4. **Operator token is an interim bridge** (named per-operator tokens, held in browser storage). That is acceptable for a handful of operators, not for a wider audience.
5. **Terraform state has drifted from code.** A full plan would replace the Jenkins admin password. Any Omniview infra apply must be targeted, with a reviewed plan, run by Femi.
6. **Non-identification failure is the worst outcome**, and it is a trust issue for an accounting firm. It needs tests that try to defeat it, not just tests that it works.
