# ADR: FiSH runs a microservices architecture

Status: accepted, 2026-10-18 (Femi: "That is the principle of the micro-services architecture we are adopting."). Prepared by CM. Evidence is the project record and this day's releases; items marked *verify* were not re-checked on the day.

## Decision

The platform is a set of independently deployable services, each organised around one business capability and owning its own data. Owning services hold the details and the ageing; GL aggregates control accounts only (Decisions_Log, 2026-10-18).

| Capability | Service | Owns |
|---|---|---|
| Ledger | GL | postings, control accounts |
| Tenancy and access | EA | Tenant, User, Membership, RBAC |
| Purchasing, Accounts Payable | POP | suppliers, orders, bills, payables ageing |
| Sales, Accounts Receivable | SOP | customers, orders, receipts, receivables ageing |
| Inventory and Services | IM | items, stock, service items, VAT category |
| People and pay | HR / Payroll | employees, pay runs |
| Education | Education Runtime | admissions, attendance, assessment, fees (billing through SOP) |
| Cash and Bank Books (CBB) | CBB, its own service (Femi, 2026-10-18); built inside GL today, extraction to be assessed | cash book 1000, bank books, reconciliation |
| Fixed Assets (FA) | FA, its own service (Femi, 2026-10-18, extract now); built inside GL today, cut-over to be planned | asset register, categories, depreciation, disposal, the Owner approval flow for acquisitions |
| One front end | WEB | no business data |

## Test applied (Lewis and Fowler; Fowler's Trade-Offs)

1. Independent deployability: separate repo, Jenkinsfile, ECS service, image and public address per service. Met.
2. Business-capability boundaries: met (table above).
3. Data owned by the service: separate database per service; GL's is still named `fish_production`. Met at database level. *verify* the grants.
4. Lightweight communication: HTTP and JSON, per-service credentials, contract fixtures in fish-contracts, strict decoding of auth payloads. Met.
5. Not a distributed monolith: releases are ordered consumer first (the services that read a producer declare its new fields before the producer ships them: EA, POP, SOP and WEB are consumers of IM; EA is also a consumer of POP, SOP, Payroll, Personnel (HR), GL and CBB), never simultaneous. Met, watched.

## Watch items (what would make this wrong)

1. **Shared failure domain**: one database server and one Terraform state serve every service. Independence is in code and data, not infrastructure. *verify* current layout before relying on it.
2. **Synchronous chains**: the core services (GL, EA, POP, SOP, IM, HR) call each other over HTTP, with no event bus between them; Education Runtime integrates with SOP through a durable outbox (`sop_event_outbox`) with stable event ids. Protection today: idempotency keys, claim-then-post. Revisit if a call chain is on a user's request path more than one deep.
3. **Shared pieces**: `common` is shared as source; WEB is one front end for every service and is the main place one release touches several services (by decision, Femi 2026-10-03).
4. **Ordered releases** (consumer first, then the producer): acceptable while each service can still ship alone. Trigger to act: any change that must go live in two services in the same window. That is a distributed monolith.

## Rules that follow

- A service never reads another service's tables; it calls the owner's route.
- A response shape change is consumer-first, additive, and covered by a contract fixture.
- No `ignoreUnknownKeys` on authorization payloads; tolerant reads only for business data.
- Every money-moving call carries an idempotency key.
- Extract a further service only for a stated trigger (independent failure, different scale, different security boundary, different owner, published boundary). Fixed Assets and Cash and Bank Books are being extracted on the ownership principle (Decisions_Log, 2026-10-18).

## Source

`microservices-architecture-brief.md` (research brief, 2026-10-18). Its description of Prodeo (one modular-monolith product, stub identity layer, event integration) predates the current services and EA's live access control and is not used as a statement of fact here. Its general guidance (independent deployability, own your data, idempotent consumers, no distributed monolith) is.
