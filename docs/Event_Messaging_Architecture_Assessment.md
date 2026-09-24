# Event/Messaging Architecture Assessment — Would Kafka (or an AWS-Native Equivalent) Help FiSH?

**Status:** reference/findings, 2026-09-23. Assessment only — no code, no implementation proposal, no
architecture decision made here. Method: confirmed by direct inspection of the current codebase (every
gateway/pattern cited below was read, not assumed), cross-checked against this project's own recent
incident history and design notes, and weighed against the `aws-messaging-and-streaming` skill's
service-selection guidance for the AWS-native comparison. Written in the same spirit as
`docs/GL_Production_Readiness_Assessment.md` and `docs/Nigeria_Compliant_Hosting_Opportunity.md`: grounded,
dated, cites real files, ends with a clear recommendation and honestly-flagged open questions.

---

## 1. Current architecture, as it actually is today

FiSH is eleven repos/submodules (`GL`, `SOP`, `POP`, `IM`, `HR`, `EA`, `WEB`, `common`, `Infrastructure`,
`ER/Principal/SchoolAdmissions`, and the parent `FiSH` repo), all deployed as ECS Fargate services in a
single shared AWS region (`eu-west-2`), one Postgres database per service, deployed via a self-hosted
Jenkins instance (one `Jenkinsfile` per repo). **Every inter-service call in this codebase today is
synchronous HTTP.** There is no message broker, queue, or event bus anywhere in the platform. Confirmed by
grepping every `.tf` file in `FiSH/Infrastructure` (`sqs|sns|eventbridge|kinesis|msk|kafka`, case-insensitive):
the only hits are `notifications.tf`'s **SES** (transactional email) and **SNS** (Cognito SMS verification
codes) resources, both application-to-person channels for Cognito's own signup flow, not an
application-to-application messaging layer. There is no `aws_sqs_queue`, `aws_sns_topic` (for pub/sub),
`aws_cloudwatch_event_bus`, `aws_msk_cluster`, or `aws_kinesis_stream` resource in this Terraform project.

Two authenticated shapes carry all of that synchronous HTTP traffic:

### 1.1 Forwarded-caller-token gateways (human-context calls)

EA's own Dashboard (UC-BO01) calls sibling services **on behalf of the signed-in Business Owner**, forwarding
that person's own bearer token rather than using a service identity:

- `EA/src/main/kotlin/com/theprodeogroup/ea/infrastructure/sop/sop_gateway.kt` / `ktor_sop_gateway.kt` —
  `SopGateway.listSalesOrders(bearerToken)`, a plain `GET $baseUrl/sales` with
  `Authorization: Bearer $bearerToken` forwarded verbatim. The KDoc is explicit about why no Cognito
  service account is involved: "SOP's `sopAuthenticated` wrapper already accepts it directly (SOP's own
  `SOP_JWT_AUDIENCE` is the same shared Cognito app client id every sibling's human-facing auth uses)."
- `EA/src/main/kotlin/com/theprodeogroup/ea/infrastructure/im/im_gateway.kt` / `ktor_im_gateway.kt` —
  identical shape, `ImGateway.listItems(bearerToken)` against `GET $baseUrl/items`.
- `EA/src/main/kotlin/com/theprodeogroup/ea/infrastructure/gl/gl_gateway.kt` / `ktor_gl_gateway.kt` —
  same shape again, `GlGateway.getCashFlow`/`getProfitAndLoss` against GL's `/companies/{companyId}/reports/*`
  routes.

All three are near-identical: a plain Ktor `HttpClient.get(...)`, one header, a `GatewayCallResult`
success/failure wrapper, and an explicit `..._unreachable` failure mapped to HTTP 503 when the `try/catch`
around the call fails. There is no retry, no circuit breaker, no timeout override beyond Ktor's client
defaults, and no queuing — if SOP/IM/GL is down or slow when the Business Owner opens their dashboard, that
one widget's data simply fails to load for that one request. This is a low-stakes failure mode by design:
it's a read-only reporting call inside an interactive page load, not a state-changing operation, so a
failed call just means "try refreshing the dashboard."

### 1.2 Service-account-authenticated gateways (machine-to-machine calls)

A service calling another **as itself** authenticates via a dedicated Cognito service-account identity,
through `CognitoServiceAccountTokenProvider` — found as near-verbatim copies (per-repo package rename only,
confirmed by direct comparison) in eight locations: `GL/common`, `common` (top-level), `SOP/common`,
`POP/common`, `IM/common`, `EA/common`, `HR/src/.../infrastructure/gl/cognito_service_account_token_provider.kt`,
and `ER/Principal/SchoolAdmissions/src/.../infrastructure/sop/CognitoServiceAccountTokenProvider.kt`. Read
`HR`'s copy end to end: it calls Cognito's `InitiateAuth` (`USER_PASSWORD_AUTH` flow) directly over HTTPS
(no AWS SDK dependency), computes the `SECRET_HASH` by hand (HMAC-SHA256), caches the resulting ID token with
a 2-minute refresh buffer, and exposes itself as a plain `() -> String` to match the calling gateway's
`bearerTokenProvider` contract. Its own KDoc documents a real, dated incident this pattern already caused
in production: Cognito's real `InitiateAuth` response carries more fields (`AccessToken`, `RefreshToken`,
`TokenType`) than the DTO declared, and the strict top-level `Json` singleton (`ignoreUnknownKeys = false`
by default) threw on the first response that included one — "a live production incident: every
cross-service call through this provider — SOP/IM/POP/HR calling GL or each other — started failing 500
the moment Cognito's response actually included one" (2026-09-12), fixed with a dedicated lenient `Json`
instance for decoding only that response.

This pattern backs POP→IM, SOP→IM, HR→GL, POP→GL, and EA→SchoolAdmissions
(`EA/src/main/kotlin/com/theprodeogroup/ea/infrastructure/schooladmissions/`). On the receiving side, GL's
`AuthenticatedCaller` (`GL/src/main/kotlin/com/theprodeogroup/fish/infrastructure/web/AuthenticatedCaller.kt`)
carries an `isServiceAccount: Boolean` flag set per named JWT provider in `Auth.kt` (`FISH_JWT_SERVICE_AUTH_NAME_IM`/
`_HR`/`_POP`, one Ktor `jwt(...)` block per caller audience) — GL never asks EA whether a service-account
caller is a valid Tenant member; per `docs/Service_Account_Identity_And_EA_Membership_Design_Note.md`, that
is Option B, a **permanent architectural decision** (v1.8, 2026-09-16), not an interim shortcut:
"module-to-module (service-account) calls permanently bypass the EA membership check by design, since
Prodeo shouldn't be in the business of gating any Tenant's own internal integrations." All six
service-account pairs (POP/SOP→IM, SOP/IM/HR/POP→GL) are on this same rule as of `GL@d376f66`.

### 1.3 What's actually provisioned in Terraform for inter-service trust

`FiSH/Infrastructure` (`fish-infrastructure`, relocated out of `GL/infra/terraform/` 2026-09-17 per
`docs/Platform_Infrastructure_Extraction_Design.md`) has a `*_service_account.tf` file per caller pair
(`pop_service_account.tf`, `sop_im_service_account.tf`, `pop_gl_service_account.tf`, `sop_service_account.tf`,
`im_service_account.tf`, `hr_service_account.tf`, `ea_schooladmissions_service_account.tf`,
`dpid_schooladmissions_service_account.tf`) — each provisions a Cognito app client and a
`*-service@theprodeogroup.com` user, nothing message-broker-shaped. `network.tf`/`ecs.tf`/`alb.tf` describe
one shared VPC, one shared ECS cluster, and per-service ALB target groups/listener rules — every inter-service
"connection" in this platform is an ALB-routed HTTP call, full stop.

---

## 2. The one existing event-shaped precedent: SchoolAdmissions' SOP outbox

The closest thing to real event-driven architecture anywhere in the platform is
`ER/Principal/SchoolAdmissions`'s outbound event mechanism, built incrementally across W2–W5.1
(`723ccbb` "StudentEnrolled outbox" → `18456ff` "durable SOP outbox" → `0b7cf44` "deterministic SOP
eventIds + outbox-first"). It is genuinely well-built for what it does, and genuinely narrower in scope
than "event-driven architecture" might suggest:

- **The shape**: `SopEventEnvelope` (`domain/platform/SopEventEnvelope.kt`) — `eventId` (UUID by default,
  but see below), `timestamp`, `type`, `schoolId`, and a flat `Map<String, String>` payload — published
  through a `SopEventPublisher` interface with two implementations: `OutboxSopEventPublisher` (an
  in-memory `ConcurrentHashMap`, used for hermetic tests) and `ExposedSopEventPublisher` (the real,
  Postgres-backed one, writing to a durable `sop_event_outbox` table via Exposed, inside a transaction,
  idempotent on `eventId` with a check-then-insert that falls back to catching a unique-constraint
  violation as `PublishResult.Duplicate` if two callers race).
- **Idempotency, hardened twice**: the W5.1 commit (`0b7cf44`) moved event IDs from random UUIDs to
  **deterministic** ones derived from business identity — the README documents the exact scheme:
  `StudentEnrolled:{applicationId}`, `AttendanceRecorded:{school}|{student}|{class}|{date}|{code}`,
  `AssessmentCompleted:{school}|{student}|{term}|{gradeSummary}`, `StudentPaymentReceived:{invoiceId}`.
  That means a retried enrollment or a re-run attendance mark produces the *same* `eventId` and is a
  guaranteed no-op on replay, not merely "probably won't collide." The same commit also switched the write
  order to "outbox then domain save" (outbox-first) for enrol/attendance, so a crash between the two steps
  leaves a recorded-but-not-yet-reflected event rather than a silently lost one, and `FeeService`'s own
  `reconcileStuckInvoices()` (`POST /schools/{schoolId}/fees/reconcile`) exists specifically to recover
  payment confirmations left stuck mid-flow.
- **What it is not, confirmed directly**: `SopEventEnvelope.kt`'s own KDoc states plainly, "Wire shape
  ready; no live SOP emit until W2+" — and grepping the whole `SchoolAdmissions` source tree for any
  worker, scheduler, poller, or HTTP call that drains `sop_event_outbox` and actually delivers an event to
  SOP turns up nothing. `AppFactory.kt` wires a separate `sopHttpClient` for `KtorSopCustomerGateway` (a
  different, synchronous customer-sync gateway, not the event path) but no dispatcher for the outbox
  table. **As of this reading, the outbox is a durable, idempotent local ledger of "events that should
  eventually reach SOP" — correctly built, genuinely production-grade in its write-side guarantees — but
  with no live delivery mechanism wired up yet.** This is exactly the shape of a proper outbox pattern
  (the standard fix for "how do I atomically write my own state and publish an event without a distributed
  transaction"), just not yet paired with a relay/dispatcher, whether that relay ends up being a scheduled
  poll-and-POST job, Debezium-style CDC, or a real message broker.
- **Why this exists at all**: `SopEventEnvelope.kt`'s KDoc also states the actual architectural rule
  driving it — "SchoolAdmissions must NEVER write FiSH GL directly. Financial effects go only via SOP
  events (e.g. `StudentPaymentReceived`) — not a GL client." This is a bounded-context discipline
  (SchoolAdmissions is not a GL client, SOP is the financial front door for trade/sales-shaped activity),
  not a decision that async delivery specifically is required for correctness.

**Accurate characterization**: this is a well-executed **outbox pattern with a still-missing relay**, not
a working pub/sub system. It is the single piece of evidence in the whole codebase that anyone here has
already reached for eventing/async-delivery *thinking*, but it stops one increment short of being an
operating example of it.

---

## 3. Would Kafka/MSK specifically help, versus the AWS-native alternatives, versus no change?

### 3.1 What Kafka (or MSK) would actually add

Per the `aws-messaging-and-streaming` skill's own framing: Kafka/MSK is a **streaming** service — an
ordered, durable, replayable log, built for sustained high-throughput ingestion, multiple independent
consumers reading the same data at different positions, and event-sourcing/CDC-style workloads. Its
differentiators (partitioned ordering, long/indefinite retention, replay-from-any-offset, a broad connector
ecosystem) are real capabilities FiSH does not have today.

### 3.2 Does FiSH's current workload look like a streaming problem?

No, on the evidence gathered. Every inter-service interaction found in this codebase is a **discrete
command or query** — "record this sale," "fetch this cash-flow report," "check this membership" — not a
continuous flow of events multiple independent systems need to replay or reprocess. The one place an
event *shape* actually appears (SchoolAdmissions' outbox) has exactly one intended consumer (SOP) and four
event types, none replayed for analytics or reprocessed by a second consumer. Nothing in the codebase
resembles clickstream/IoT/telemetry ingestion, CDC, or a need for multiple heterogeneous consumers to read
the same event independently at their own pace. Kafka/MSK's core differentiators — partition-ordered
replay, sustained high-throughput, multi-consumer fan-out at different offsets — don't correspond to a
problem this platform currently has anywhere.

### 3.3 Does FiSH's current workload look like a messaging problem?

Closer, but still thin. Messaging (SNS+SQS, EventBridge) fits **decoupling and fan-out of discrete
events** — exactly the outbox-relay gap identified in §2, and plausibly the pending-approval /
notify-both-parties flows the Unified Communication design work just scoped
(`docs/Unified_Communication_SRS.md`/`Unified_Communication_Use_Cases.md`, both 2026-09-23). Concretely:

- **The SchoolAdmissions outbox relay** is the single clearest candidate. Today the outbox table has no
  drainer. A durable queue (SQS) or event bus (EventBridge) sitting between "write to `sop_event_outbox`"
  and "POST to SOP" would give at-least-once delivery with retry/backoff and a dead-letter queue for a
  poison event, for less new operational surface than standing up Kafka for four event types and one
  consumer. It would **complement**, not replace, the outbox table itself — the table's job (durable,
  idempotent local record of "this happened") stays exactly as designed; a queue's job would be reliable
  delivery of that record to SOP, which the codebase doesn't have yet.
- **The Unified Communication approval workflow** (FR-COMM-04, `Requested → Pending Approval →
  Approved/Denied`) and its "notify the Owner-Admin" / "notify both parties once approved" steps are
  presently not even designed, let alone built — `docs/Unified_Communication_SRS.md` §5 marks FR-COMM-04
  "NOT BUILT" outright. If and when that workflow is built, its notification fan-out is a plausible
  SNS/EventBridge use case (one state transition, multiple interested parties) — but that is speculative
  against a design that itself doesn't exist yet, not a current, felt need.
- **`WEB/src/components/SupportChatWidget.tsx`'s 15-second poll** (`POLL_INTERVAL_MS = 15_000`, confirmed
  directly in the file) is the one concrete, already-shipped example of "this could plausibly be
  event-driven instead" the task raised. Its own code comment already makes the counter-argument
  explicitly: "Polls on an interval while open rather than a real-time connection — a genuinely simpler v1
  for a feature whose reply latency is 'whenever the platform operator (or a teammate) gets to it,' not
  sub-second — matching this project's own minimal-build convention." That reasoning holds today. Nothing
  in the six Unified Communication requirements (all reviewed in §5 of that SRS) currently demands
  sub-15-second latency; several are still unbuilt. Swapping polling for WebSockets/SSE/EventBridge would
  be solving a latency problem nobody has reported yet, for a support-chat feature whose own design
  explicitly chose the simpler option and named why.

### 3.4 Is there evidence of actual current pain from synchronous HTTP + service accounts?

This is the load-bearing question, and the honest answer is **no, not from the messaging pattern itself**.
The real, documented multi-day incidents in this project's history are not "a service was unreachable and
a synchronous call had nowhere to queue" — they are **deployment/configuration drift** problems, a
different failure class entirely:

- The HR audience-drift incident (`FISH_JWT_SERVICE_AUDIENCE_HR` added to Terraform 2026-09-02 but never
  pushed into a live ECS task definition — "HR->GL 401s" for days until caught 2026-09-05) — a Jenkins
  deploy-stage limitation (it patches `.image` on the live task definition, never re-reads
  `container_definitions` from Terraform), not a synchronous-call-coupling problem. A message broker would
  not have prevented this; the service-account JWT itself was simply never valid in that window, regardless
  of transport.
- The GL Jenkins drift-check incident (`docs/Service_Account_Identity_And_EA_Membership_Design_Note.md`'s
  sibling history, and this project's own memory record) — a dead CI stage silently blocked every `master`
  deploy for three days after an unrelated file relocation, caught only when someone happened to check.
  Again a CI/deploy-pipeline gap, unrelated to HTTP-vs-broker.
- Jenkins' own shared-executor contention (2 executors, 512MB Gradle daemon cap, shared across eight
  repos) causing OOM build failures under concurrent pushes — a CI capacity problem, not a runtime
  messaging problem.

None of these would have been prevented, mitigated, or even meaningfully changed by Kafka, MSK, SNS/SQS,
or EventBridge — they are Terraform/Jenkins/CI-pipeline gaps sitting one layer below where a message broker
would operate. The one *runtime* coupling risk synchronous HTTP genuinely does carry — "if the callee is
down, the caller's request fails right now instead of queuing for later" — has **zero documented
occurrences** in this project's history to date, on either the forwarded-token side (explicitly designed as
a best-effort dashboard read, already gracefully degrading to a `..._unreachable` failure) or the
service-account side.

### 3.5 Team/scale reality check

Per the project's own established conventions and status: this is a **pre-launch, no-real-paying-customer,
effectively solo-founder** platform (`user_prodeo_group_founder` context; `docs/Women_SME_Support_Build_Brief.md`'s
"no paying tenants exist yet" as a named blocking gap for other work). The project's own stated
engineering discipline is "minimal builds — confirmed features stay deferred if not load-bearing"
(`feedback_minimal_builds`) and "park, don't guess" (`feedback_park_dont_guess`) — the same discipline that
produced `docs/Database_Tenant_Isolation_RLS_Scope.md`'s recent, explicit decision *not* to build
Row-Level-Security tenant isolation despite finding a real gap, on the reasoning that the concrete
app-layer bugs mattered more right now and RLS could be tracked as deliberate future work instead. A
message broker — Kafka/MSK most of all — is real, new, always-on infrastructure: a cluster (or managed
service) to provision, secure (the skill's own callout: broker/SASL credentials belong in Secrets Manager
with customer-managed KMS keys, `AmazonMSK_`-prefixed secret naming, `BatchAssociateScramSecret` wiring),
monitor, and reason about failure modes for — on top of a Jenkins pipeline that is *already* under-provisioned
for the current eight repos (2 executors, 512MB daemon cap causing real OOM failures today) and a Terraform
project that already has an open, flagged gap of its own (no remote state backend — `versions.tf`'s
documented limitation, directly implicated in both drift incidents above). Adding a message broker on top
of infrastructure that is already showing operational strain from its *existing*, much simpler footprint is
a real cost, not a hypothetical one.

### 3.6 Head-to-head, if something were adopted

| Option | Fits the workload found? | Operational cost | Verdict |
|---|---|---|---|
| **Kafka (self-managed on EC2/EKS)** | No — no streaming-shaped workload exists | Highest — cluster ops, ZooKeeper/KRaft, patching, scaling, entirely new expertise for a team of ~1 | Not fit for purpose or scale |
| **Amazon MSK** | No — same mismatch, AWS-managed doesn't change the workload shape | High — still a cluster to size, secure (SASL/SCRAM + customer-managed KMS), and monitor; genuinely less ops than self-managed, still more than the alternatives below | Solves a streaming problem FiSH doesn't have |
| **Amazon SNS + SQS** | Partially — matches the one concrete gap found (the SchoolAdmissions outbox relay) and would fit a future approval-notification fan-out | Low — fully managed, no cluster, pay-per-use, already has a working precedent pattern in this account (SES/SNS already provisioned for Cognito) | Best-fit *if and when* the outbox relay or approval-notification work is actually prioritized |
| **Amazon EventBridge** | Partially — same fit as SNS+SQS, plus content-based filtering/schema registry if event types multiply later | Low — fully managed, no cluster; slightly more setup than a single SQS queue for a single-consumer relay | Reasonable alternative to SNS+SQS for the same gap, marginally more suited if multiple consumer types emerge later |
| **No change** | N/A | None | Matches the evidence: no current pain traceable to the synchronous-HTTP pattern itself, and the one real gap (outbox relay) doesn't yet need more than a scheduled job or a single SQS queue |

---

## 4. Recommendation

**Not Kafka, not MSK, and not a platform-wide messaging-layer adoption right now.** The workload evidence
doesn't support it (§3.2–3.3), the documented pain in this project's history sits in a different layer
entirely — deployment/CI drift, not runtime service-to-service coupling (§3.4) — and the team/scale reality
(pre-launch, no paying tenants, a CI/infra footprint already showing strain at its current, much smaller
size) argues directly against taking on a new class of always-on infrastructure before it's load-bearing,
consistent with this project's own "minimal builds" and "park, don't guess" conventions applied elsewhere
(most recently, the RLS decision).

**The one concrete, narrow exception worth flagging, not queuing**: the SchoolAdmissions SOP-event outbox
(§2) already has the harder half of an outbox pattern built and hardened (durable, idempotent, outbox-first
ordering) and is missing only the relay/delivery half. If and when that gets built, it is a genuinely
better fit for **SQS or EventBridge** than for Kafka/MSK — single consumer (SOP), low event-type count,
no replay/analytics requirement, and both are a fully-managed, pay-per-use, comparatively small operational
addition next to a cluster. This document does not schedule that work; it only names it as the one place
in the codebase where the eventing question is already partially answered by existing code, not
hypothetical.

**Revisit this whole question, not a specific tool, when one of these becomes true**: (a) FiSH has real
paying tenants generating enough concurrent cross-service traffic that synchronous HTTP coupling starts
producing actual documented incidents (not currently the case — see §3.4), (b) a genuine multi-consumer or
replay requirement appears (e.g., an analytics/reporting consumer that needs to independently replay the
same event stream SOP consumes, which does not exist today), or (c) the Unified Communication approval
workflow (FR-COMM-04) is actually designed and built, at which point its notification fan-out is worth a
real SNS-vs-EventBridge comparison against the workflow's real requirements — not before.

---

## 5. Open questions

Recorded rather than answered, per this project's own convention of parking genuine unknowns instead of
guessing:

1. **Who owns draining the SchoolAdmissions outbox, and on what timeline?** The write side is done and
   hardened; the relay is not scoped anywhere in this project's docs today. Not decided here whether that
   relay should be a scheduled poll-and-POST job (simplest, no new infra), a queue-based push (SQS/EventBridge,
   per §4), or something else — this document only confirms the gap exists and names the two AWS-native
   options that would fit it if/when it's prioritized.
2. **Does the eventual GL/POP/SOP/IM/HR EA-membership check for *human* callers ever need an async
   notification leg** (e.g., "notify a Business Owner their staff invite was accepted") that isn't covered
   by today's synchronous request/response model? Not investigated here — out of this assessment's scope,
   which was inter-service data/command calls, not user notification delivery generally (SES/SNS already
   handle the one channel found, Cognito verification codes).
3. **If the Unified Communication approval workflow (FR-COMM-04) is built, does its "notify both parties"
   step actually need to be async at all**, or is a synchronous write-then-poll (matching the existing
   `SupportChatWidget.tsx` pattern) sufficient given the same "reply latency is fine at minutes, not
   sub-second" reasoning that justifies the current 15-second poll? Not decided — this is exactly the kind
   of decision that belongs with that workflow's own design pass, not pre-empted here.
4. **Is there a real remote-Terraform-state-backend and Jenkins-capacity fix already overdue** ahead of
   *any* new infrastructure category being added? Both gaps are already flagged elsewhere in this project
   (`docs/Platform_Infrastructure_Extraction_Design.md`'s open remote-backend question;
   `project_jenkins_shared_executor_contention` memory) and directly implicated in the two real multi-day
   incidents cited in §3.4. Not this document's job to resolve, but worth naming as a more load-bearing
   infrastructure investment than a message broker would be right now, if infrastructure investment is
   the question on the table.
5. **Was every relevant `.tf` file actually captured by the grep in §1.3?** The Terraform tree was searched
   by keyword (`sqs|sns|eventbridge|kinesis|msk|kafka`) across `FiSH/Infrastructure` specifically; if any
   sibling repo carries its own, separate Terraform (none were found — `GL/CLAUDE.md` confirms
   infrastructure-as-code was fully centralized into `fish-infrastructure` 2026-09-17) this conclusion could
   need revisiting, but no evidence of that was found.
