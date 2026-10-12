# Generic services and specialist runtimes: the platform contract (SPUTO)

**Status:** 2026-10-12, planning only (SPUTO: Scope, Plan/SRS, Use cases, Tasks, Order). Nothing in this note is built. **Decisions are asked of Femi in section 8.** Written by the EA session at Femi's request, from four read-only research passes made the same day: how Education Runtime depends on the generic services; every service-to-service call; the versioning and extension conventions that exist; and a sourced comparison of messaging options. Prices are AWS list prices for eu-west-2 read on 2026-10-12. Every estimate is mine and unproven. What I could not verify is listed in section 9.

## 1. Scope (S)

**The idea (Femi, 2026-10-12):** the platform is a set of **generic services** (GL, SOP, POP, IM, HR, EA) plus several **specialist runtimes** (Education now; credit unions, banking, investment management, doctor surgeries later). The contract fixtures already approved are "the missing piece" that lets that work. This note says what it takes to make it true, and where a message broker such as Kafka fits.

**In:** (A) the request and response contract between services and runtimes: versioning, change rules, fixtures; (B) how a runtime is registered and what it may use without changing a generic service; (C) the event contract (runtime to platform and platform to runtime); (D) the broker decision. **Out:** WEB's UI work, per-runtime business rules, and any build for a runtime nobody has decided to build.

## 2. What is true today (evidence)

**2.1 The size of the problem.** 31 hand-written copies of response shapes are decoded by consumers across the repos (26 distinct shapes published). `GET /me` alone is copied five times (15 classes). Nearly all are strict, by Femi's rule. Strict decoding is right, but it means every added field is a coordinated change. Drift has broken production twice (2026-09-29, 2026-10-12). No current field-level drift exists after today's fixes.

**2.2 There is no contract layer.** No API version (routes sit under `/api`, which is a routing prefix, not a version), no deprecation or sunset mechanism, no OpenAPI or JSON Schema anywhere. The GL readiness assessment parked versioning "deliberately last". The Education Runtime's own spec demands versioned APIs, six months' deprecation notice and contract tests in CI; nothing implements it.

**2.3 Education Runtime is lighter on the platform than people assume.** It makes exactly **one** outbound call to a generic service (create a Customer in SOP for a guardian, `POST /api/companies/{id}/customers`). It never calls GL, POP, IM, HR or EA. It never reads EA's `GET /me` or module grants: who may do what comes from its own staff table. `EDUCATION_RUNTIME` is only a visibility switch in WEB. EA calls it (two provisioning routes, pipe-delimited text, not JSON). **Its event outbox is written but nothing reads it**, so a fee payment has no financial effect in SOP or GL today.

**2.4 Education is hard-wired into the generic services.** EA: `IndustryType` is a closed enum with two values, provisioning is an `if (industryType == SCHOOL)` branch, `/me` carries a school-specific `schoolId` that all five strict mirrors had to add. SOP: an education-named login provider, an education-specific env var and a Company allow-list (`SOP_ER_COMPANY_IDS`) kept outside Terraform. GL and the others mirror `EDUCATION_RUNTIME` in their module enum. WEB hard-codes education in many places.

**2.5 What a second runtime could NOT reuse (nine blockers).** (1) `IndustryType` is a closed enum plus a code branch and a hard-wired gateway. (2) `ManagedModule` is a per-runtime enum value duplicated in several services, and GL decodes it with `valueOf` (an unknown value throws). (3) `/me` carries a runtime-specific field. (4) SOP's service-account support is Education-only code and env vars. (5) Authorization inside a runtime has no shared model (EA has no runtime-role concept; the Education Runtime does not check that a caller's `schoolId` belongs to their EA Tenant). (6) The event outbox has no consumer. (7) SOP's `Customer` assumes sales-order trade finance; a credit union's member or loan account has no generic party model. (8) Provisioning wire format is bespoke text. (9) Mirrors are hand-copied, drift is found in production.

**2.6 Conventions that already exist and should be built on.** Strict decoding, narrowly applied (access and money payloads strict; the response after a side effect tolerant, by CM's rule of 2026-10-11, already applied in the SOP, POP, IM and HR posting gateways). Service-account auth through Cognito, with a deliberate EA-membership bypass for service calls. Idempotency-Key: GL accepts it on its posting routes and stores only 2xx answers ("a refused request must not spend a key"). Error body `{error, detail?}`. One migration discipline: consumer-first for additive changes. Services deploy independently and roll over each other for a few minutes. Only CM pushes and deploys. Production data is test data until Femi announces the Live switch.

**2.7 Inconsistencies a contract policy must close.** Education Runtime's errors are `{error, message}`, not `{error, detail}`. Only IM's GL client has a request timeout; no client anywhere retries. Several state-changing calls send no Idempotency-Key (IM to GL receipts, SOP to GL sales returns, POP opening AP import, HR leave utilization, ER to SOP customer creation). GL's `valueOf` decoding of EA enums is stricter than the other services' defensive parse. The Industry Type doc says Phase 2 is "deferred" while the code already provisions schools.

**2.8 The riskiest calls today** (side effect, strict decode after it, no key, no real-shape test): HR to EA invite staff and change module grants; SOP to IM stock issue and receive (the decode needs a nested `item.id` SOP does not use, after stock has moved); ER to SOP create customer (a decode miss after creation, then a retry creates a duplicate); then the `/me` mirrors in IM and HR (no wire test), and two SOP to GL reads.

## 3. Requirements (P)

- **R1** A runtime can be built and tested against published fixtures without the generic services running.
- **R2** A generic service can change additively without waiting for any runtime ("a source never waits on a runtime"). A breaking change is versioned and the old version stays for a stated period.
- **R3** Every response one service or runtime reads from another is registered, fixtured and decoded strictly in CI (the approved fixtures plan, extended to runtimes).
- **R4** A response read after a side effect is decoded tolerantly and never turns a success into a failure; every such call is idempotent.
- **R5** Adding a runtime needs no change inside a generic service's code for its own identity, module name, role names and provisioning (data, not branches), once the registry exists.
- **R6** Runtimes publish events in one envelope with a deterministic id, a tenant id and a per-key ordering key; delivery is at-least-once and consumers are idempotent.
- **R7** The mechanism must work unchanged in every hosting region we use (AWS London, Ireland, and a possible Nigerian cloud that is not AWS).
- **R8** One engineer can run it: no new always-on infrastructure until a stated trigger is met.
- **R9** Strict decoding is never relaxed on an access or money payload. Nothing here adds `ignoreUnknownKeys`.
- **Not required:** a runtime for any industry nobody has decided to build.

## 4. Options and the recommendation

The work falls into four layers. They have different urgency, and Kafka belongs only to the last.

### Layer A: the request and response contract (do now)
1. **Platform Contract Policy** (a short document, one page, binding on all repos): which routes are "platform contract" (consumed by another service or runtime) and which are internal (the `index.yaml` in `fish-contracts` is the register); additive-only inside a version; new consumer fields declared optional-with-default first; closed enums at a boundary are breaking unless every consumer decodes an unknown value defensively (an unknown module, role or access means no access, never an exception); remove, rename or retype is breaking; a breaking change ships a side-by-side `/api/v2/<route>`, the old route lives for the agreed period, and every deprecated route returns a `Deprecation` header. **No blanket `/v1` migration**: it needs every consumer to change at once and the readiness plan already parks it. Start versioning the day the first breaking change is needed.
2. **Fixtures** (approved, `fish-contracts`): extend the plan from "the routes EA reads" to **all 26 published shapes** (the inventory is done) and to every runtime consumer.
3. **Close the risky calls first** (section 2.8): tolerant decode after the side effect for HR to EA, SOP to IM and ER to SOP; make customer creation idempotent; add an Idempotency-Key where it is missing; add timeouts to every client; make GL's enum decode defensive; align the Education Runtime error body.

### Layer B: runtime registration and extension (design now, build when a second runtime is decided)
Replace the Education-specific code with data. A **runtime manifest** in EA: runtime id, name, module id (a string, not a code enum), the role names it declares and how they map to the platform's view/enter/approve/administer capabilities (the RBAC SPUTO's R12, still unbuilt), its provisioning route (JSON, versioned, idempotent on the organisation id), the service identities it uses, and the generic routes each identity may call. `/me` carries a generic `runtimeLinks` map in place of `schoolId` (one consumer-first lockstep change in the five strict mirrors, with `schoolId` kept during a stated overlap). SOP's and GL's allow-lists read "runtime enabled for this Company" from EA instead of an env var. Before building anything, run a **paper dry run**: write down how a credit-union runtime would onboard, call SOP, GL and EA, and post a member's contribution, and see which blocker (section 2.5) actually bites. Femi's answer on 2026-10-07 was that nothing is planned for Clinical or Banking: build only what the dry run proves necessary.

### Layer C: the event contract (design now; the first piece is already needed)
One envelope, **CloudEvents 1.0.2** (`id`, `source`, `type`, `subject` as the business key, `time`, plus `tenantid` and the registered `partitionkey` extensions). A catalogue per publisher in **AsyncAPI 3.1**, JSON Schema payloads, and one fully populated fixture per event type in `fish-contracts/events/`, produced by the publisher's own golden test and decoded strictly by each consumer, exactly like the REST fixtures. **First build: the Education Runtime relay.** A small poller reads the existing outbox, claims the oldest unpublished row per business key (ordering by a sequence column, not a timestamp), POSTs the envelope over HTTP to an authenticated, idempotent SOP ingestion route, and records attempts, last error and a `dead` state; SOP keeps an inbox table keyed on `source` and `id`. Alert on the age of the oldest unpublished row and on dead rows. No new infrastructure, and it works unchanged anywhere Postgres and HTTP exist. Put the transport behind a small `Sink` port (`HttpSink` now).

### Layer D: the broker (decide at triggers; not now)
Researched options for async events, at the expected volume (hundreds to low thousands of events a day per tenant):

| Option | Floor cost, eu-west-2 | Fit | Main risk | Portable to a non-AWS cloud |
|---|---|---|---|---|
| Postgres outbox plus relay (no broker) | about $0 to $8 | excellent for one consumer | relay bugs; ordering must come from a sequence column | yes, fully |
| SQS (standard, FIFO) plus SNS | under $10 a month | good for fan-out in London | a failing FIFO message blocks its group; 14-day retention, a transport, not an audit log | no (AWS API) |
| EventBridge, classic bus (London) | about $1 per million events | rules and filtering | no ordering; replay is not ordered | no |
| EventBridge, enhanced bus (ordering, 365-day retention, replay) | not confirmed | the best AWS fit on paper | **not available in London**; Ireland and 13 other regions only | no |
| Amazon MSK | **about $635 (Serverless) to $1,034 (Express) a month floor** per region | a Kafka log with replay | cost floor; idle capacity | the Kafka API is portable, MSK is not |
| Self-run Kafka or Redpanda | about $100 a month for a small cluster (my estimate) | same engine | all operations on one engineer; Redpanda Community is BSL licensed | yes |
| Kinesis | about $13 to $35 a month | ordered by partition key | shard and consumer machinery; AWS-only | no |
| NATS JetStream (self-run) | about $8 to $50 a month (estimate) | light, with replay | smaller ecosystem; no schema registry; state on Fargate not verified | yes |

**Recommendation: no broker now.** The outbox already is a durable, ordered, idempotent, auditable record, and a broker would duplicate it without replacing it. The case for a Kafka-class log is real in three places (replay for audit and new consumers, many independent consumers at their own pace, the Kafka wire protocol as the one portable standard across AWS, Huawei and self-run) but it is a fixed $635 to $1,034 a month per region, repeated for each data-residency cluster, for under one event a second, run by one engineer, to solve a problem we do not have yet. **Staged path:** (1) now, outbox, relay and `HttpSink`, one consumer; (2) when a second consumer needs the same events, add `SnsSink` or `SqsSink` in London (standard queues; FIFO per business key only where order matters, with a dead-letter plan), keeping the outbox as the replay log and the HTTP sink as the portable fallback; (3) **adopt a Kafka-API broker only when a trigger fires**: several independent consumers must re-read history at their own pace; sustained rates near 100 events a second; an auditor or regulator requires an immutable log outside the service databases; or cross-region replication is needed. Because the envelope and the `Sink` port stay the same, that switch is a new adapter, not a redesign. The Nigeria question belongs here: the outbox, relay and HTTP sink are portable, whereas Huawei Cloud's managed Kafka in Lagos could not be confirmed to exist.

## 5. Use cases and expected outcomes (U)

| ID | Situation | Expected |
|---|---|---|
| UC-P1 | A generic service adds a response field | consumers declared it optional first; fixtures updated by the source's own golden test; no outage in any deploy order |
| UC-P2 | A generic service must remove or retype a field | a `/api/v2` route ships beside the old one; consumers move within the agreed period; the old route sends a `Deprecation` header until it is retired |
| UC-P3 | EA adds a module or role value | consumers decode an unknown value as "no access", never as an exception |
| UC-P4 | A parent's fee payment is confirmed in Education Runtime | the event reaches SOP once, is recorded as a collection, and appears in GL; a retry or a crash does not duplicate it |
| UC-P5 | SOP is down for an hour | events wait in the runtime's outbox and are delivered in order per invoice afterwards; the oldest-unpublished-age alert fires |
| UC-P6 | A runtime service retries a customer-creation call after a timeout | one Customer exists |
| UC-P7 | A new runtime (a credit union) is registered | a manifest and Cognito clients, not new branches in EA, SOP and GL (after Layer B) |
| UC-P8 | A runtime team builds its integration offline | it decodes the published fixtures through its real strict client and passes without any generic service running |
| UC-P9 | A second consumer wants the same events | it subscribes through a new sink; the publisher is unchanged |
| UC-P10 | A regulator asks for a year of financial events | produced from the outbox and ledger today; if the trigger in Layer D fires, from the log |

## 6. Tasks (T), each tests-first, one commit each, reviewed by CM (estimates mine)

**Layer A (now)**

| Task | Owner | Content | Size |
|---|---|---|---|
| A1 | EA, CM | Platform Contract Policy document and PR checklist; the `contract: platform or internal` flag in `fish-contracts/index.yaml` | 0.5 d |
| A2 | all sources | the approved fixtures plan T2 to T9, widened to 26 shapes and to Education Runtime's consumers | about 7 d (plus 1 d for the extra shapes) |
| A3 | HR, EA | HR to EA invite and module grants: decode the response tolerantly after the side effect; add real-shape tests | 0.5 d |
| A4 | SOP | SOP to IM issue, receive, adjustments: drop the nested `item.id` requirement, tolerant scoped decode, send an Idempotency-Key; IM's receive route accepts one | 1.5 d (SOP, IM) |
| A5 | ER, SOP | customer creation idempotent (a stable external reference on the SOP route, ER sends it); tolerant decode after creation | 1 d |
| A6 | GL | defensive decode of EA's module, role and access values (unknown means none) | 0.25 d |
| A7 | ER | error body to `{error, detail}`; align the base URL convention (see section 9) | 0.25 d |
| A8 | every client | a request and connect timeout on every service client | 0.5 d |
| A9 | SOP, IM, POP, HR | add the missing Idempotency-Keys (sales return, inventory receipt, opening AP import, leave utilization) | 1.5 d |
| A10 | Omniview, CM | closed: the support-card route is deliberately unbuilt in EA (Femi, 2026-10-05, owner approval first); Omniview fails soft | 0 d |

**Layer B (design now, build later)**

| Task | Owner | Content | Size |
|---|---|---|---|
| B1 | EA, ER | paper dry run of a credit-union runtime against SOP, GL and EA; list the blockers that actually bite | 1 d |
| B2 | EA | runtime manifest and registry design (RBAC SPUTO R12), JSON provisioning contract, `runtimeLinks` in `/me` | 2 d design |
| B3 | EA, five consumers, WEB | build, consumer-first: the `runtimeLinks` map, module id as string, registry-driven provisioning | about 5 to 7 d, only after B1 shows need |
| B4 | SOP, GL | allow-lists read from EA's "runtime enabled for this Company" (the unbuilt T15 M1b) | 2 d |

**Layer C (events)**

| Task | Owner | Content | Size |
|---|---|---|---|
| C1 | EA, ER, SOP | CloudEvents envelope, AsyncAPI catalogue and event fixtures in `fish-contracts/events/` | 1 d |
| C2 | ER, SOP | outbox relay with sequence ordering and dead state, SOP ingestion route, inbox dedup, collection posted through the existing record-collection route, alerts | 3 to 4 d |

**Layer D**

| Task | Owner | Content | Size |
|---|---|---|---|
| D1 | EA, CM | the `Sink` port in the relay (`HttpSink` only); a written trigger review every quarter or when a second consumer asks | 0.5 d |

Total for Layer A, C and D1: about 17 to 19 days across sessions, with the fixtures plan the largest part. Layer B is 3 days of design and dry run now, then 7 to 9 days only if the dry run shows it is needed.

## 7. Order, rollout, rollback

1. **A3, A4, A5, A6** first: they close the riskiest calls (section 2.8) and need no new design.
2. **A1, A2** (policy and fixtures), starting with SOP as already planned.
3. **C1, C2**: the Education Runtime relay, which fixes the one place a real financial effect is missing today.
4. **A7 to A10** alongside.
5. **B1** (paper dry run), then B2; decide on B3 and B4 from what B1 shows.
6. **D1** with C2.
**Why now:** production data is test data until the Live switch, so a breaking cleanup (`/me` shape, error body, enum to string) costs far less before Live than after. **Rollout** is consumer-first for every additive step, and each task is an independent branch; CM sequences and deploys. **Rollback:** every task is code only and reverts by redeploying the previous image; the relay can be switched off and the outbox keeps its rows.
**Risks:** (1) the outbox relay must preserve order per key: a polling relay that claims rows by `SKIP LOCKED` alone can deliver event 2 before event 1; (2) policy without enforcement decays, hence the fixtures and the nightly drift job; (3) Layer B can become speculative work for runtimes nobody has decided to build; (4) cost and time are my estimates and have not been tested.

## 8. Decisions asked of Femi

1. **Approve the layered approach:** the contract policy and fixtures first (Layer A), events (Layer C) with the Education Runtime relay as the first build, the runtime registry (Layer B) designed now and built only if a paper dry run shows the need, and the broker (Layer D) held until a trigger fires. Kafka is not the foundation; it is an option for later.
2. **Broker:** accept "no broker now; outbox plus relay plus HTTP sink; revisit at the triggers in section 4" (recommended), or choose a broker now? If a broker is wanted now, my choice would be SNS and SQS in London, not Kafka, because of cost and operations; a Kafka-API broker only when a trigger fires.
3. **Do the breaking cleanups before the Live switch** (`/me` shape, error body, enum to string, tolerant decodes)? Recommended: yes, because they are cheapest while production data is test data.
4. **Deprecation period** for a retired route once the platform is Live: the Education Runtime spec says 6 months; my suggestion is 3 months before any outside customer depends on it and 6 after. Your call.
5. **Layer B:** do the paper dry run for a credit-union runtime (1 day) now, or wait until a second runtime is decided? Note your earlier answer on 2026-10-07 that nothing is planned for Clinical or Banking.
6. **Priority:** should the Education Runtime relay (C2) go ahead of the remaining Layer A work, since a fee payment currently has no financial effect?

## 9. What I could not verify

- Whether the live Education Runtime to SOP base URL doubles the `/api` prefix (the code and Terraform disagree; the live environment variable decides). CM can check it.
- Whether `SOP_ER_COMPANY_IDS` is set in production (it is not in Terraform).
- Whether anything outside these repos drains the Education Runtime outbox (nothing inside them does).
- Omniview's call to an EA support-card route: **resolved 2026-10-12, not a defect.** EA has deliberately not built it: Femi decided on 2026-10-05 that EA builds the operator support card only after the Owner Admin approves it (a per-tenant switch, default off) and only after the support relay release. Omniview's gateway fails soft (the card shows as unavailable) until then. Task A10 is therefore closed; it was never a missing route.
- Huawei Cloud's managed Kafka in the Lagos region: it could not be confirmed to exist; the only price found, about $672 a month, is marketing and not Nigeria-specific. Which Huawei products match SQS, SNS or Kinesis is also unconfirmed.
- EventBridge's enhanced bus pricing, and whether it will reach London. The newer bus launched on 2026-09-24, the day after the September assessment, and is not in London.
- NATS deduplication details; whether Fargate can safely hold JetStream or Kafka state; the self-run cluster cost estimates.
- ECS rolling-deploy percentages (only inferred), the Ktor server's behaviour on unknown request fields, and the exact `Idempotency-Key` handling of POP and HR beyond what the research read.

*Sources read 2026-10-12: the Education Runtime, SOP, GL, POP, IM, HR, EA, Omniview and WEB code (via read-only research passes), `docs/Event_Messaging_Architecture_Assessment.md`, `docs/Industry_Type_Module_Enablement_Design.md`, `docs/RBAC_SPUTO.md`, `docs/ER_RBAC_SPUTO.md`, `docs/T15_MultiTenant_SPUTO.md`, `docs/Service_Account_Identity_And_EA_Membership_Design_Note.md`, `docs/GL_Production_Readiness_Assessment.md`, `docs/Nigeria_Compliant_Hosting_Opportunity.md`, `docs/FiSH_Product_Description.md`, `docs/Cross_Service_Contract_Fixtures_SPUTO.md`, `docs/Decisions_Log.md`, and AWS, Confluent, Redpanda, NATS, CloudEvents and AsyncAPI documentation (dates in the research record).*
