# Epic 13, Education Runtime half: fee rules, clearance, and the event link to SOP (P, U, T, O)

**Status: DRAFT 1, 2026-10-07. Design only; nothing built, nothing decided.** Written by the `+ER Education` session as epic lead for the Education Runtime half, following `docs/Fee_Billing_Epic13_SPUTO_Scope.md` (the **S**). The SOP, GL, EA and WEB halves are written by their owners; CM writes the cross-service order. Facts are tagged **[code]** (read from `fish-education-runtime` on 2026-10-07), **[spec]** (the v0.1 requirements, FIN-INT-001..020 and ER-FEE-001..014) or **[open]**. Requirement ids here are the spec's own.

## 0. Before anything else: two live faults found while writing this

1. **The outbox column rejected every real event id.** `sop_event_outbox.event_id` was `VARCHAR(36)`; the ids this service generates are 52 to unbounded characters, so enrolment, payment confirmation, attendance marks and assessment completion all fail at the outbox write on the production Postgres store. **[code, reproduced]** Hotfix `V31` is prepared (branch `fix/outbox-event-id-length`, with CM). **Nothing in this epic can start until that is live**, and it shows the outbox has never delivered an event in production.
2. **Browser calls from WEB to this service were blocked** (no CORS). Fixed and merged (ER PR #11); live confirmation with CM.

Lesson that shapes the tasks below: this epic moves money-relevant events across a service boundary, and the Postgres path of the outbox had **no test**. Every outbox and inbox task here therefore carries a real-Postgres test as part of its definition of done.

## 1. What the Education Runtime keeps, stops doing, and gains

**Keeps (the rules and clearance layer):** fee schedule *rules* (what is charged to whom, when), the clearance policy and its verdicts, approval workflows for waivers and refunds, the student register, and the Parent Gateway views. **[spec ER-FEE-001/005/006/008]**

**Stops doing (strangler, last):** creating `FeeInvoice` rows and `confirmPaymentStub` marking them paid. Today `FeeService` issues invoices, stores amounts as decimal strings, and confirms payment with no provider. **[code]** SOP becomes the system of record for billing accounts, invoices, payments, receipts and balances; SOP posts to GL. **[S, ER MVP Definition 2026-10-01]**

**Gains:** (a) an **outbound relay** that delivers its outbox to SOP, (b) an **inbound endpoint and inbox** for SOP's events, (c) read models for invoice status, balance and clearance fed by those events, (d) a versioned, typed event contract.

## 2. Plan: Education Runtime requirements

| ID | Requirement | Spec | Today **[code]** |
|---|---|---|---|
| FR-F1 | **Outbound relay.** Deliver outbox events to SOP over HTTPS with a service account (token for SOP's audience). Per-row delivery state (pending, delivered, failed), attempts, next-attempt time, last error; retry with backoff; **failed after N attempts is the dead-letter state, with an admin replay route**; delivery in order **per billing account** (the ordering key, see FR-F5). | FIN-INT-011 | The outbox only writes; **no delivery state at all**, no reader, no relay. The only live call to SOP is `Customer` creation (`KtorSopCustomerGateway`). |
| FR-F2 | **Relay only event types SOP consumes** (an allowlist): `StudentEnrolled`, `StudentUpdated`, `StudentStatusChanged`, `FeePayerChanged`, `FeeScheduleChanged`, `BillingRunRequested`, `WaiverApproved`, `RefundRequested`. `AttendanceRecorded` and `AssessmentCompleted` stay local until a consumer exists. | FIN-INT-002/003/004/005/008 | Four event types are written today: `StudentEnrolled`, `StudentPaymentReceived`, `AttendanceRecorded`, `AssessmentCompleted`. `StudentUpdated`, `StudentStatusChanged`, `FeePayerChanged`, `FeeScheduleChanged`, `BillingRunRequested` do not exist. |
| FR-F3 | **Typed, versioned event contract**, backward compatible, with contract tests in CI shared with SOP. The envelope carries `schemaVersion` and the school's **Company id** (see FR-F9), not Education Runtime's own `schoolId`. | FIN-INT-014 | `SopEventEnvelope.payload` is a `Map<String,String>` with no version. |
| FR-F4 | **Inbound endpoint and inbox.** `POST` accepting SOP's events from a **pure service principal** (token for SOP's audience; no user lookup; never falls back to the human verifier when unset, as EA's owner-contact route does). An **inbox table de-duplicates by event id** and checks per-account order. Handles `InvoiceIssued`, `PaymentReceived`, `PaymentReversed`, `AccountBalanceChanged`. | FIN-INT-005/006/009/011 | None. The gateway has verifiers for DPID and EA only. |
| FR-F5 | **Payer model.** A student-to-payer link (family, sibling consolidation) that can change (`FeePayerChanged`) and is the **ordering key** for events. | FIN-INT-002/003, ER-FEE-002 | **Not modelled.** `Guardian` is an embedded contact on the student; `GuardianAccount` is only a billing identity, linked to an invoice, not to a student. **[open: decide the payer and family model first; everything billing-account-shaped depends on it]** |
| FR-F6 | **Fee schedules as versioned rules.** Per session, term, campus, level, stream and boarding status; mandatory and optional items; **a published schedule is immutable, a change creates a new version**; publishing emits `FeeScheduleChanged`. Account mapping stays in SOP/GL (FIN-INT-015), never here. | FIN-INT-004, ER-FEE-001 | `FeeScheduleItem` is flat (code, name, amount, currency; default NGN), no term, level, campus or version. |
| FR-F7 | **Clearance policy and verdict (ER-FEE-008).** Configurable policy; the verdict is computed from SOP's balance (the single source of truth), stored with the **time computed**, the **reason** and the **policy version**, readable per student. Safeguards are hard rules: never blocks attendance, safeguarding, medical or emergency information, the student's education, statutory returns or any legally required information; each block needs an approved policy, parent notification and principal override, and is logged. **Lawfulness is marked TBC per country in the spec.** | FIN-INT-009, ER-FEE-008, ER-PPT-005 | **Not built at all.** |
| FR-F8 | **Waivers and refunds.** The Education Runtime owns the request and approval workflow with an approver reference; SOP posts. **A user who records payments cannot approve waivers or void receipts.** | FIN-INT-008, ER-FEE-006/009/012 | Not built. |
| FR-F9 | **Tenant mapping.** School to Company is 1:1 and keyed by the Company id already stored as `School.organisationId`; events carry the Company id and Education Runtime resolves its own school from it (`SchoolRegistryStore.findByOrganisationId`). EA stays out of the runtime path. | FIN-INT-001/017 | Exists (`School.organisationId`, set by EA's provisioning). |
| FR-F10 | **Daily reconciliation.** Compare Education Runtime's read models with SOP (billing accounts, invoices, payments, balances); raise discrepancies to the Bursar and support. | FIN-INT-012 | None. |
| FR-F11 | **Read APIs for WEB.** `GET /schools/{id}/me` with capability codes; the clearance verdict per student; **student name and class on invoice and student responses (or a batch lookup)**; **paging on every list**. | (WEB's asks, 2026-10-07) | Lists are unpaged and invoices return raw student ids; the roles route is designed in the teaching-staff drafts, not built. |
| FR-F12 | **Retire the stub last.** Stop issuing `FeeInvoice` rows once SOP is the system of record for new invoices; retire `confirmPaymentStub` only after real payments flow. At the live switch all production data is legacy test data and is reset in both services. | S section 5, 4.6 | `FeeInvoice` and `confirmPaymentStub` are live code paths. |
| FR-F13 | **Offline cash receipting** (receipt ranges per registered device): later, after the local-first client exists. Reserved, not designed here. | FIN-INT-013 | The device trust and sync server side exist (PR #9); no client. |

**What stays out of the Education Runtime, by design:** card, wallet or bank credentials (the parent pays only through SOP's payment session, FIN-INT-007); any chart-of-accounts mapping; any direct GL write (`NoDirectGlWrites` already enforces this). **[spec, code]**

## 3. Use cases (Education Runtime side)

- **UC-FE1** A Bursar defines a term's fee schedule for a level and **publishes** it (a new immutable version); SOP receives `FeeScheduleChanged` and creates or updates billing items. *(FR-F6, F1, F3)*
- **UC-FE2** A Registrar enrols a student; `StudentEnrolled` reaches SOP, which creates or links the family's billing account. *(FR-F1, F2, F5)*
- **UC-FE3** A guardian or payer changes, or a student withdraws; SOP re-assigns or closes the account and stops future billing. *(FR-F5, F2)*
- **UC-FE4** A Bursar requests a **term billing run** (dry run first); SOP issues the invoices and returns `InvoiceIssued`, which the Education Runtime shows. *(FR-F2, F4)*
- **UC-FE5** A parent pays through SOP's payment session; `PaymentReceived` arrives, the Education Runtime updates fee status and re-evaluates clearance within the agreed time (the spec proposes five minutes). *(FR-F4, F7)*
- **UC-FE6** A registrar prints a report card for a student whose fees are outstanding; the **clearance verdict** says what is withheld, why, and when it was computed; a principal override is logged. *(FR-F7)*
- **UC-FE7** A fee officer requests a waiver; a **different person** approves it; `WaiverApproved` goes to SOP, which posts the discount. A refund follows the same path. *(FR-F8)*
- **UC-FE8** Overnight, the reconciliation finds an invoice in SOP that the Education Runtime has not seen and raises it to the Bursar. *(FR-F10)*
- **UC-FE9** An operator or engineer finds events stuck in the failed state and **replays** them. *(FR-F1)*
- **UC-FE10** A guardian views the family balance and statements in the Parent Gateway (payment goes through SOP's payment session, never through the Education Runtime). *(FR-F4, F11)*

## 4. Tasks (Education Runtime; dependency-ordered)

| # | Task | Depends on |
|---|---|---|
| E0.1 | **Land the V31 outbox hotfix** (event id to TEXT). | none (urgent) |
| E0.2 | **CORS live and confirmed** (ER PR #11). | CM confirmation |
| E1.1 | Decide the **payer and family model** (FR-F5) and the **ordering key**. | Femi/Bursar input, SOP |
| E1.2 | Agree the **typed, versioned event contract** with SOP and add **shared contract tests** (FR-F3). | SOP half, E1.1 |
| E1.3 | Accept a **pure service principal for SOP's audience** (FR-F4): verifier wiring, no human fallback. | CM (Cognito client and secret), EA identity leg |
| E2.1 | **Outbox delivery state** (migration: status, attempts, next-attempt, last error) and the **relay worker** with backoff, failed state and an **admin replay route**; allowlist of relayed types (FR-F1, F2). Real-Postgres tests, including a crash between claim and send. | E0.1, E1.2, E1.3 |
| E2.2 | **Inbound endpoint and inbox** with de-dup and per-account order check (FR-F4). Real-Postgres tests. | E1.2, E1.3 |
| E3.1 | **Versioned fee schedules** with applicability and immutability; emit `FeeScheduleChanged` (FR-F6). | E1.2, E2.1 |
| E3.2 | New outbound events: `StudentUpdated`, `StudentStatusChanged`, `FeePayerChanged`, `BillingRunRequested` (FR-F2). | E1.1, E2.1 |
| E3.3 | Read models fed by `InvoiceIssued`, `PaymentReceived`, `PaymentReversed`, `AccountBalanceChanged` (FR-F4). | E2.2, SOP half |
| E4.1 | **Clearance** policy, verdict (with reason, time computed, policy version), logging and override (FR-F7). | E3.3, **lawfulness decision per country** |
| E4.2 | **Waiver and refund** requests and approvals with segregation of duties (FR-F8). | E2.1, GL/SOP posting paths |
| E4.3 | WEB read APIs: roles route, names and class on responses, paging on every list (FR-F11). | teaching-staff drafts (roles route) |
| E5.1 | **Daily reconciliation** (FR-F10). | E3.3, a SOP list API |
| E6.1 | **Strangler:** stop issuing `FeeInvoice`; retire `confirmPaymentStub`; reset legacy data at the live switch (FR-F12). | SOP system of record, real payments |
| E7.1 | Offline receipting (FR-F13). | local-first client |

Every task that writes or reads the outbox, inbox or a posting-adjacent table includes a **real-Postgres test**, and every cross-service call a contract test; no exceptions (section 0).

## 5. Order (Education Runtime's part; CM sequences the whole epic)

**E0** (hotfixes) first, independent of everything. Then the **decisions** E1.1 to E1.3 (payer model, contract, service identity), which block all delivery work. **E2** (relay and inbox) next: it can be proven end to end with only enrolment events before SOP's billing exists. **E3** follows, in step with SOP's billing items and invoices. **E4** (clearance, waivers) is last among the build tasks because it consumes balances; the lawfulness question can run in parallel from today. **E5** with E3, **E6** only after real payments flow, **E7** after the local-first client.

## 6. Constraints and questions for others

- **SOP is bound to one Tenant per deployment** (EA's identity leg: `SOP_EA_TENANT_ID`), so the **pilot school's Tenant must be the one SOP is configured for**, or SOP must become multi-tenant. This belongs in the order and in Femi's pilot question. **[EA]**
- **Bursar:** no new EA role; the school's `BURSAR` duty stays assigned by hand in the Education Runtime and never comes from EA or HR; SOP-side access for that person is EA `SALES_OFFICER` at `WRITE` on the school's Company. **[EA]**
- **Waiver and refund approver (Femi to decide):** my recommendation is that a fee officer or bursar requests, a **school administrator** (not the requester) approves, recorded with an approver reference per FIN-INT-008, honouring ER-FEE-009.
- **Clearance lawfulness** is marked TBC per country in the spec; no clearance block ships for a country until it is settled. **[spec]**
- **Currency and VAT** (S section 4): NGN is not an onboarded currency and Nigeria has no VAT rows in GL; both gate the first live fee. Not an Education Runtime decision.
- **Guardian side:** the Parent Gateway already resolves a guardian by the **email on the student's record** and shows the student's invoices and outstanding balance; today a linked guardian can also confirm payment through the stub, which must go when payment moves to SOP's payment session. WEB has no guardian sign-in, so that use case is **not scoped**. **[code, WEB]**
- **Order of events across the two services** is per billing account, so E1.1 (the ordering key) must precede any delivery code.

## 7. Decisions for Femi (Education Runtime half only)

1. The **payer and family model** (who pays for which student; sibling consolidation).
2. **Who approves a waiver or refund** (recommendation above).
3. **Clearance:** does the first release ship without any block (verdict visible, nothing withheld), until lawfulness is settled per country? (Recommendation: yes.)
4. The **pilot school and country**, given SOP's one-Tenant binding.
