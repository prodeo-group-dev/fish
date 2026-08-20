# Purse — Core Banking Use Cases

**Context:** These are the foundational banking use cases Purse needs as a credit union (open table, PRA/FCA regulated pathway), independent of any specific feature like Osusu or Buzz Me. They assume the counterparty model already established (see *Purse Use Case: Purse as Counterparty of Record*, UC-0): every member transacts with Purse, and FiSH posts Member ↔ Purse double-entry journals throughout. Osusu and other features sit on top of this layer as allocation logic, not as separate banking primitives.

## Actors

- **Applicant** — a prospective member not yet onboarded
- **Member** — a Purse account holder in good standing
- **Purse** — the credit union, counterparty of record for every member transaction
- **FiSH** — ledger engine; posts all journal entries
- **Buzz Me** — transfer initiation + haptic confirmation layer
- **Purse Ops** — back-office, compliance, and member services function
- **External Payment Rail** — Faster Payments (UK), SEPA (Ireland), or other bank-to-bank rail for money entering/leaving Purse

## UC-B1: Member Onboarding & KYC

**Actor:** Applicant, Purse Ops
**Trigger:** Individual applies to join Purse.

**Flow:**
1. Applicant submits identity documents, proof of address, and (per open-table principle) confirms understanding that Purse is open to all, not restricted by faith affiliation.
2. Purse Ops runs KYC/AML checks (identity verification, PEP/sanctions screening) per FCA/PRA requirements.
3. On pass, FiSH creates a new Member entity and an associated Purse account with a zero opening balance.
4. Member receives onboarding confirmation and is issued access credentials (app login, Buzz Me pairing).

**Failure path:** KYC failure → application declined, reason logged per regulatory record-keeping requirements, applicant notified within required timeframe. No FiSH entity is created.

**Open decision:** Tiered KYC (basic tier with lower limits, enhanced tier unlocking full features) or single-tier onboarding?

## UC-B2: Deposit (Funds In)

**Actor:** Member
**Trigger:** Member wants to add funds to their Purse account from an external bank account.

**Flow:**
1. Member initiates deposit via bank transfer (Faster Payments/SEPA) to their unique Purse account reference, or via card/open banking payment if supported.
2. External Payment Rail confirms funds received into Purse's own settlement account.
3. FiSH posts: debit Purse's external settlement position, credit Member's Purse account.
4. Member notified (buzz + push) once posted.

**Reconciliation note:** This is where Purse's internal ledger (member balances) must reconcile against the actual pooled funds sitting in Purse's real-world settlement/safeguarding account — a control critical for regulatory audit (see UC-B9).

## UC-B3: Withdrawal (Funds Out)

**Actor:** Member
**Trigger:** Member wants to move funds from Purse to an external bank account.

**Flow:**
1. Member requests withdrawal, specifying destination account (own external bank account — first-party payout as an AML control) and amount.
2. FiSH validates sufficient available balance (accounting for any holds, e.g., active Osusu circle commitments).
3. FiSH posts: debit Member's Purse account, credit Purse's external settlement position.
4. Purse initiates outbound payment via External Payment Rail.
5. Member notified on confirmed send (buzz success) or failure (buzz failure — e.g., rail rejection, destination account mismatch).

**Open decision:** Same-day withdrawal as standard, with instant/Faster Payments as a premium/priority option? Any withdrawal limits per day/month for risk purposes?

## UC-B4: Internal Transfer (Member to Member, via Buzz Me)

**Actor:** Member (sender), Member (recipient)
**Trigger:** Member sends money to another Purse member.

**Flow:**
1. Sender initiates via Buzz Me (NFC tap, QR, or contact lookup).
2. Per the counterparty model: FiSH posts two linked entries — debit sender's Purse account / credit Purse, and debit Purse / credit recipient's Purse account — never a single sender-to-recipient entry.
3. Both legs post atomically; if either fails, both are rolled back (or neither is posted in the first place).
4. Sender and recipient each receive their own buzz confirmation, independently.

**Note:** This is the general-purpose version of the pattern also used for Osusu contributions/payouts — Osusu is simply this same primitive with allocation-layer bookkeeping layered on top.

## UC-B5: Standing Orders / Scheduled Payments

**Actor:** Member
**Trigger:** Member sets up a recurring payment (e.g., regular savings contribution, recurring Osusu contribution, regular payment to another member).

**Flow:**
1. Member defines: amount, frequency, start date, destination (external account or another Purse member), optional end date/number of occurrences.
2. System schedules recurring execution; each occurrence follows UC-B3 (external) or UC-B4 (internal) as applicable.
3. Failed occurrence (insufficient funds) triggers same failure handling as the underlying use case, plus a notification specific to standing-order failure (distinct from a one-off failed transfer, since the member may not be actively watching).

## UC-B6: Balance & Statement Enquiry

**Actor:** Member
**Trigger:** Member wants to view balance, transaction history, or a formal statement.

**Flow:**
1. Member requests via app (real-time balance, filterable transaction list) or formal statement (PDF, for a given period — needed for mortgage applications, proof of funds, etc.).
2. FiSH's immutable, reversal-only ledger is the single source of truth — statement generation reads directly from posted journal entries, never from a cached or derived balance that could drift.

**Note:** Given FiSH's double-entry, reversal-only design, this use case is largely a read/reporting layer over the existing ledger rather than new transactional logic — but statement formatting and regulatory-required content (e.g., FSCS-equivalent protection disclosures, if applicable) need explicit design.

## UC-B7: Profit-Share Distribution

**Actor:** Purse, Member
**Trigger:** Periodic (e.g., annual) distribution of Purse's surplus to opted-in members, per the credit union's profit-sharing (not interest-bearing deposit) structure.

**Flow:**
1. Purse Ops calculates distributable surplus and each opted-in member's share (per whatever formula is set — e.g., proportional to average balance held, or a flat per-member distribution).
2. FiSH posts: debit Purse's surplus/reserve account, credit each participating member's Purse account — same Member ↔ Purse pattern as every other transaction.
3. Members notified of distribution with a clear statement that this is a profit share, not interest, preserving the regulatory distinction that keeps Purse outside deposit-taking/interest-bearing account rules.

**Open decision:** Is distribution automatic for all members, or does it require explicit opt-in (relevant to the "Purse members participate via profit-sharing, not as direct investors" framing already established)?

## UC-B8: Account Closure

**Actor:** Member, Purse Ops
**Trigger:** Member requests to close their Purse account, or Purse closes it (e.g., prolonged dormancy, regulatory requirement, breach of terms).

**Flow:**
1. System checks for open obligations: active Osusu circle commitments, pending standing orders, non-zero balance.
2. Non-zero balance must be withdrawn (UC-B3) before closure completes, or auto-transferred to the member's registered external account.
3. Active circle commitments must be resolved per UC-5 (Osusu member exit) before account closure can proceed.
4. FiSH marks the member entity closed; historical transaction record is retained (never deleted) per audit/regulatory retention requirements.

**Open decision:** Minimum retention period for closed-account records, and whether closure is instant or has a cooling-off/reversal window.

## UC-B9: Safeguarding Reconciliation

**Actor:** Purse Ops, System
**Trigger:** Ongoing — typically daily/end-of-day.

**Flow:**
1. System sums all member Purse account balances (per FiSH) as of the reconciliation point.
2. This sum is compared against the actual funds held in Purse's real-world safeguarding/settlement account(s).
3. Any variance is flagged immediately — this is a critical control, since a mismatch indicates either a ledger error or a real funds shortfall, both requiring urgent investigation.
4. Reconciliation result logged and retained for regulatory inspection.

**Note:** This use case is arguably the single most important one in the whole banking layer — it's the control that proves member balances shown in the app actually correspond to real money Purse is holding, which is the core trust proposition of any deposit-taking-adjacent institution.

## UC-B10: Dormancy & Inactivity

**Actor:** System, Member, Purse Ops
**Trigger:** No member-initiated activity for a defined period (e.g., 12 months).

**Flow:**
1. System flags account as dormant; member notified via multiple channels before any restriction applies.
2. Dormant accounts may have restricted functionality (e.g., no new standing orders) until member re-authenticates/reactivates.
3. Long-term unclaimed balances follow applicable dormant-account regulatory process (varies UK/Ireland) rather than being absorbed by Purse.

## UC-B11: Fraud & Anomaly Monitoring

**Actor:** System, Purse Ops, Member
**Trigger:** Ongoing — transaction pattern monitoring.

**Flow:**
1. System monitors for anomalous patterns (unusual transaction size/frequency, rapid Buzz Me taps to unfamiliar recipients, velocity checks on newly onboarded accounts).
2. Suspicious activity triggers a hold on the specific transaction (not the whole account, unless severity warrants it) and a Purse Ops review.
3. Member notified of hold with a clear reason where legally permissible, or a generic "under review" message where AML/CTF rules restrict tipping off.
4. Confirmed fraud triggers reversal (per FiSH's reversal-only correction principle — never a silent edit) and, where required, regulatory reporting (e.g., SAR filing).

## Cross-cutting questions to resolve before build

1. **Safeguarding structure** (UC-B9) — is member money held in a single pooled safeguarding account, or per-member designated accounts? This is likely the single highest-stakes regulatory decision in the whole banking layer and should be settled with the PRA/FCA pathway advisor before FiSH's account architecture is finalised.
2. **Withdrawal/transfer limits** — daily/monthly caps, and whether these differ by KYC tier (UC-B1) or account age/history.
3. **Interest vs profit-share boundary** (UC-B7) — the distinction between profit-share and interest needs to be legally watertight, since it's load-bearing for keeping Purse outside interest-bearing deposit account regulation.
4. **Standing order / recurring payment failure UX** — how many consecutive failures before a standing order is auto-paused, and how is the member alerted in a way that doesn't get lost among transactional notifications?
5. **Statement/reporting regulatory content** — what disclosures (protection scheme status, complaints procedure, etc.) are mandatory on every statement, and does this differ between UK and Irish members given the dual-jurisdiction structure?
