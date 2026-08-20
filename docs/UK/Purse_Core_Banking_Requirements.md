# Purse Credit Union — Banking Requirements & Use Cases

**Document purpose:** This defines the functional and non-functional requirements for Purse's core banking capability, and maps each requirement to the corresponding use case (see companion document *Purse — Core Banking Use Cases*, UC-B1–B11). It assumes the counterparty model already established (*Purse Use Case: Purse as Counterparty of Record*, UC-0) and FiSH as the sole GL of record.

**Scope:** Core banking functions only — onboarding, deposits, withdrawals, transfers, statements, profit-share, closure, safeguarding, dormancy, and fraud monitoring. Osusu and payroll are separate feature/module documents that sit on top of this foundation.

**Regulatory framing:** Purse is pursuing PRA/FCA authorisation as an open-table credit union (open to all, not restricted by faith affiliation), structured so that member participation is via profit-sharing distribution rather than as direct investment — keeping client-money/deposit-taking regulation scoped as narrowly as the model allows. Every requirement below should be read against that framing; several are flagged where the requirement itself carries regulatory weight.

---

## 1. Functional Requirements

### 1.1 Membership & Onboarding

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-01 | System shall capture identity, proof of address, and KYC documentation from applicants before account creation. | UC-B1 |
| FR-02 | System shall run identity verification and PEP/sanctions screening against every applicant before account activation. | UC-B1 |
| FR-03 | System shall support tiered KYC (basic vs enhanced) if adopted, with feature/limit gating tied to tier. | UC-B1 |
| FR-04 | System shall reject and log failed applications with reason, without creating any FiSH ledger entity. | UC-B1 |
| FR-05 | System shall confirm open-table eligibility (no faith-affiliation restriction) is applied consistently at onboarding. | UC-B1 |

### 1.2 Account & Balance Management

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-06 | Every member shall have exactly one Purse account per FiSH entity relationship, created with a zero opening balance. | UC-B1, UC-0 |
| FR-07 | All member transactions shall post as Member ↔ Purse journal entries in FiSH; no Member ↔ Member or Member ↔ third-party-construct entry shall be permitted. | UC-0 |
| FR-08 | System shall compute real-time available balance accounting for any holds (e.g., active Osusu commitments, pending withdrawals). | UC-B6 |
| FR-09 | System shall never derive or cache a balance independently of FiSH's posted journal entries — balance is always a read of the ledger, not a separately maintained figure. | UC-B6, UC-B9 |

### 1.3 Deposits & Withdrawals

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-10 | System shall accept inbound funds via Faster Payments (UK) and SEPA (Ireland) into a unique per-member reference. | UC-B2 |
| FR-11 | System shall post a Member ↔ Purse credit only once funds are confirmed received at the External Payment Rail — never on initiation alone. | UC-B2 |
| FR-12 | System shall restrict withdrawals to the member's own registered external account as a default AML control. | UC-B3 |
| FR-13 | System shall enforce configurable daily/monthly withdrawal limits, adjustable by KYC tier or account history. | UC-B3 |
| FR-14 | System shall provide haptic/notification confirmation (via Buzz Me where applicable) on both successful and failed deposit/withdrawal events. | UC-B2, UC-B3 |

### 1.4 Transfers

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-15 | Member-to-member transfers shall always post as two linked Member ↔ Purse entries, never a direct Member ↔ Member entry. | UC-B4, UC-0 |
| FR-16 | Both legs of an internal transfer shall post atomically — if either leg fails, neither is posted. | UC-B4 |
| FR-17 | Sender and recipient shall each receive independent confirmation, with no visibility into the other party's account details beyond what's needed to identify the transfer. | UC-B4 |

### 1.5 Standing Orders & Scheduled Payments

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-18 | System shall support recurring payments (fixed amount, frequency, optional end date/occurrence count) for both internal and external destinations. | UC-B5 |
| FR-19 | Each scheduled occurrence shall be processed through the same validation and posting logic as a one-off transaction (UC-B3/UC-B4) — no separate, simplified code path. | UC-B5 |
| FR-20 | Repeated standing-order failures shall auto-pause the order after a configurable threshold and notify the member distinctly from a one-off failed transfer. | UC-B5 |

### 1.6 Statements & Reporting

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-21 | System shall generate member statements (in-app and formal PDF) reading directly from FiSH's posted journal entries. | UC-B6 |
| FR-22 | Statements shall include jurisdiction-appropriate regulatory disclosures (protection scheme status, complaints procedure), varying by UK vs Irish membership where applicable. | UC-B6 |

### 1.7 Profit-Share Distribution

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-23 | System shall calculate periodic surplus distribution per an agreed formula (e.g., proportional to average balance) for opted-in members only, unless the Group decides distribution is automatic for all. | UC-B7 |
| FR-24 | Every distribution shall be clearly labelled to members as profit-share, explicitly not interest, in both the transaction record and any related communication. | UC-B7 |
| FR-25 | Distribution postings shall follow the same Member ↔ Purse journal pattern as every other transaction type. | UC-B7, UC-0 |

### 1.8 Account Closure

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-26 | System shall block closure while any non-zero balance, active Osusu commitment, or pending standing order exists, unless resolved or auto-transferred per policy. | UC-B8 |
| FR-27 | Closed account records shall be retained, never deleted, per audit/regulatory retention requirements. | UC-B8 |

### 1.9 Safeguarding & Reconciliation

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-28 | System shall reconcile the sum of all member Purse balances against actual funds held in Purse's real-world safeguarding/settlement account(s) on a daily (or more frequent) basis. | UC-B9 |
| FR-29 | Any reconciliation variance shall trigger an immediate, escalating alert to Purse Ops — not a silent log entry. | UC-B9 |
| FR-30 | Reconciliation results shall be retained in a form suitable for regulatory inspection on demand. | UC-B9 |

### 1.10 Dormancy & Inactivity

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-31 | System shall flag accounts as dormant after a configurable period of no member-initiated activity, with multi-channel notification before restriction applies. | UC-B10 |
| FR-32 | Dormant-account handling of unclaimed balances shall follow the applicable UK/Irish regulatory process for the member's jurisdiction, not a Purse-internal policy. | UC-B10 |

### 1.11 Fraud & Anomaly Monitoring

| ID | Requirement | Related Use Case |
|---|---|---|
| FR-33 | System shall monitor transaction patterns for anomalies (size, frequency, velocity on new accounts, unfamiliar Buzz Me recipients) in real time. | UC-B11 |
| FR-34 | Suspicious activity shall place a hold on the specific transaction, not the whole account, unless severity explicitly warrants broader restriction. | UC-B11 |
| FR-35 | Confirmed fraud shall be corrected via reversal only — FiSH's immutable, reversal-only principle applies without exception, including to fraud corrections. | UC-B11 |
| FR-36 | Where AML/CTF rules restrict disclosure ("tipping off"), member-facing messaging shall remain generic while Purse Ops retains full detail internally. | UC-B11 |

---

## 2. Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-01 | Auditability | Every FiSH posting shall be traceable to the originating use case, actor, and timestamp, with no direct edits possible post-posting. |
| NFR-02 | Data protection | Member PII and financial data shall be encrypted at rest and in transit; access shall be role-based and logged. |
| NFR-03 | Availability | Core balance/transfer functions shall meet an agreed uptime target (to be set with Purse Ops/infra) given members' expectation of near-instant confirmation. |
| NFR-04 | Consistency | Balance and transaction data shall be strongly consistent — no eventual-consistency window where a member could see a stale or incorrect balance after a confirmed transaction. |
| NFR-05 | Latency | Confirmed transactions shall trigger member notification (including Buzz Me haptic) within a defined ceiling (see prior latency discussion — a "still processing" state should appear before the ceiling is reached, not after). |
| NFR-06 | Multi-jurisdiction | System shall correctly apply UK vs Irish regulatory rules (disclosures, dormancy handling, payment rails) based on the member's registered jurisdiction, without manual per-case handling. |
| NFR-07 | Multi-entity | Where Purse interacts with other Group entities (e.g., intercompany transactions), postings shall remain segregated per FiSH legal entity, never commingled. |
| NFR-08 | Segregation of duties | No single role shall be able to both approve a policy-level change (e.g., profit-share formula, withdrawal limits) and execute the resulting transactions unsupervised. |

---

## 3. Traceability Summary

All functional requirements above trace to the existing use-case set in *Purse — Core Banking Use Cases*:

- UC-B1 Member Onboarding & KYC
- UC-B2 Deposit (Funds In)
- UC-B3 Withdrawal (Funds Out)
- UC-B4 Internal Transfer
- UC-B5 Standing Orders / Scheduled Payments
- UC-B6 Balance & Statement Enquiry
- UC-B7 Profit-Share Distribution
- UC-B8 Account Closure
- UC-B9 Safeguarding Reconciliation
- UC-B10 Dormancy & Inactivity
- UC-B11 Fraud & Anomaly Monitoring

No new use cases were required to support the requirements above — this document formalises requirement-level detail against use cases already defined, and should be read alongside that document rather than replacing it.

---

## 4. Open decisions carried forward (unresolved, high-priority)

1. **Safeguarding structure** (FR-28–30) — single pooled account vs per-member designated accounts. Highest-stakes item; needs resolution with the PRA/FCA pathway advisor before FiSH's account architecture is finalised.
2. **Profit-share vs interest boundary** (FR-23–25) — must be legally watertight; drafting of member-facing language should likely be reviewed by whoever is managing the authorisation submission, not finalised as a product-team decision alone.
3. **KYC tiering** (FR-03) — single-tier vs tiered onboarding affects almost every downstream limit (FR-13, FR-18) and should be settled early rather than retrofitted.
4. **Withdrawal/transfer limits** (FR-13) — specific figures, and whether they differ by tier/history, still need to be set.
5. **Uptime/latency targets** (NFR-03, NFR-05) — no concrete figures yet; these should be set jointly with whoever owns FiSH's infrastructure capacity planning.
