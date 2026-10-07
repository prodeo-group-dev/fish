# Epic 13: fee billing moves into SOP (FiSH core). SPUTO: Scope and Problem Definition

**Status:** SPUTO started 2026-10-07 on Femi's instruction ("SPUTO all the way"), full Epic 13 migration chosen over an interim cash-sale bridge. This document is the **S** (scope and problem). The **P** (plan/SRS), **U** (use cases), **T** (task lists) and **O** (dependency order) are written by the owners named in section 6, each in their own half, and merged here by reference. Nothing is built yet.

## 1. The problem

Education Runtime (ER) holds its own fee invoices and payment confirmations inside its own tables. A fee marked paid in ER, and a student enrolment, **never reach SOP or the ledger.** ER writes `StudentPaymentReceived` and `StudentEnrolled` to a local outbox (`sop_event_outbox`), and nothing delivers them (confirmed in code by the ER session, 2026-10-07; `Infrastructure/education_runtime.tf` says the same). The only live ER to SOP call today is creating a guardian as an SOP `Customer`.

The decision already on record (ER MVP Definition, 2026-10-01): **"FiSH core" for school billing is SOP, extended**, not a new dedicated GL/AR layer. SOP owns billing accounts, invoices, payments, receipt numbering and balances; ER narrows to **fee rules and clearance policy** and consumes SOP's events. SOP posts to GL. Femi confirmed on 2026-10-07 that the full migration, not an interim bridge, is the direction.

## 2. Starting point (verified 2026-10-07)

- **ER:** `FeeService` creates `FeeInvoice` rows, `confirmPaymentStub` marks them paid, and the event publisher (`OutboxSopEventPublisher`) exists but only writes. `GuardianAccount.customerId` links a guardian to an SOP `Customer` (live).
- **SOP:** has `Customer`, `SalesOrder`, a record-sale and record-collection path to GL, a cash-sale route (live, dark), invoice PDF and email (live, inert), and an Idempotency-Key build in progress. It has **no** fee/billing-item model, price lists, bulk billing runs, per-school receipt numbering or payment-session API.
- **GL:** posts sales and collections generically; VAT rates are data (V30). A jurisdiction with no verified VAT rows refuses every sale (409 `no_vat_rate_schedule`).
- **Spec:** 20 FIN-INT requirements (v0.1 spec section 4.16), already split in the ER backlog as BK-FIN-1 to BK-FIN-11.

## 3. Goal and scope

Goal: every fee a school charges and every payment it receives is an SOP record that posts to the ledger, with ER as the rules and clearance layer, so school finance is ledger-grade.

In scope (the existing BK-FIN items): tenant mapping and shared identity (1), student and payer events to billing accounts (2), fee schedules as billing items (3), billing runs producing invoices (4), payments and balances flowing back to ER (5), waivers and refunds (6), pass-through fees (7), delivery guarantees (8), daily reconciliation (9), offline receipting (10, after local-first sync), contract versioning (11).

Out of scope here: parent payment channels and gateways (separate spec), exam registration beyond pass-through, FX, dashboards (FIN-INT-016/020).

## 4. Constraints already found (these gate design choices)

1. **VAT schedule per country.** Education fees are usually exempt or zero-rated, but GL refuses any sale for a jurisdiction without verified VAT rows. Ireland and the UK are verified; Sierra Leone is seeded but unverified; **Nigeria has no rows**, and it is the arrowhead market. Needs a GL decision (an exempt-only path, or seeded schedules).
2. **Currency.** The platform recognises SLE only by policy; NGN is in the web currency list but not onboarded as a policy.
3. **Accounts mapping.** Fee items map to GL accounts (revenue, deferred income, receivables, pass-through liability, bank or cash). The spec's account examples are illustrative only (BK-FIN-7). Needs Femi or finance sign-off per school type.
4. **Idempotency.** Billing runs and payment events must be idempotent end to end. GL honours `Idempotency-Key` and keeps keys forever; SOP's own support is being built (V14).
5. **Identity and access.** An ER school must map to an EA Company and an SOP entity. A school's Bursar role maps to a SOP-side role. Service identities between ER and SOP exist in one direction only today.
6. **Data.** All production data is legacy test data until the switch to live. The migration is a change of system of record, not a data migration. At the live switch the reset covers both services.
7. **Offline receipting (BK-FIN-10)** depends on local-first sync and cannot be built meaningfully before it.

## 5. Proposed architecture decision (CM, for the owners to confirm or change)

**Event transport, version 1: HTTPS push from each producer's transactional outbox to the consumer, with an inbox table that de-duplicates by event id.** It reuses the pattern already proven between services (service-account token, one outbox, retry with backoff, failed rows kept for replay) and needs **no new infrastructure**. A queue (SNS/SQS) can replace it behind the same contract later without changing producers or consumers. Per-account ordering is achieved by delivering in outbox order per billing account. The dead-letter queue is the failed-outbox state plus an admin replay route. Both directions are needed: ER to SOP (enrolment, schedule, billing run requests) and SOP to ER (invoice issued, payment received, balance changed), so ER must accept a service-principal caller, which it does not today.

Strangler order: SOP becomes the system of record for new invoices first, ER stops creating `FeeInvoice` rows, and ER's `confirmPaymentStub` is retired last.

## 6. Ownership and the halves to write

| Part | Owner | Writes |
|---|---|---|
| Epic lead, ER half (fee rules, clearance, consuming SOP events, ER-side outbox delivery) | **+ER Education** | P, U, T for ER |
| SOP half (billing accounts, billing items, invoice and payment domain, receipt numbering, inbox, API and event contract) | **SOP** | P, U, T for SOP |
| Posting rules, VAT exempt path, chart-of-accounts mapping, any GL change | **GL** | P, T for GL, plus the VAT decision |
| Tenant mapping (school to Company), roles, service identities in EA | **EA** | the BK-FIN-1 identity leg |
| Screens (Bursar invoicing, payments, balances, runs) | **WEB** | U and T for screens |
| Cross-cutting: release order, service identities and secrets wiring, delivery infrastructure, high-risk reviews, contract tests in CI | **CM** | the O (order) and the infrastructure legs |

## 7. Decisions needed (not decided here)

- Femi: fee-to-GL account mapping per school type; whether Nigerian schools post fees as VAT-exempt; first pilot school and country; whether the live switch waits for this epic.
- GL: exempt-only path versus seeded schedules for countries without VAT rows.
- Owners: confirm or change the transport decision in section 5.

## 8. Next steps

Each owner writes its half as a docs branch and sends a final tip. CM merges each, then writes the dependency order across them. Peers register their dependency rows in `docs/GL_POP_IM_SOP_Coordination.md`. No code is started until the order is agreed and Femi has answered the section 7 questions.
