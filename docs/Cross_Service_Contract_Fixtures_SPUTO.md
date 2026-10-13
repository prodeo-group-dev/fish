# Cross-service contract fixtures: catching mirror drift in CI (SPUTO)

**Status (updated 2026-10-13):** approved by Femi on 2026-10-12 (Decisions Log, Option A, Phases 1 and 2, nightly drift job; Phase 3 starts with an inventory). Femi chose a **new private repository, `prodeo-group-dev/fish-contracts`** (not `common`, which is public); CM created it with the layout, README rules, `index.yaml` and the loader (task T1 done; the loader was revised on EA's review and merged as fish-contracts master `534092d`). **No fixture has been written yet**; SOP's is first (task T2). This document was first written 2026-10-12 against `common/` and is now brought in line with what exists. It is extended by `docs/Platform_Contract_Generic_Services_And_Runtimes_SPUTO.md`, which widens the scope to all 26 published shapes and to the runtimes. Written by the EA session at CM's request, after the 2026-10-12 audit. **Decisions are asked of Femi in section 7.** Facts below were read in code on 2026-10-12; estimates are mine and unproven.

## 1. Scope (S)

**In:** every place one FiSH service decodes another service's JSON response into its own hand-written, strictly decoded mirror DTO. Phase 1: the routes EA consumes (SOP 2, IM 2, GL 7, HR 1, POP 1, Omniview 6, Education Runtime 2). Phase 2: `GET /me`, mirrored strictly by GL, POP, IM, SOP (and read by WEB). Phase 3: service-to-service posting calls (SOP/POP/IM/HR to GL, SOP to IM, POP to IM): **not inventoried yet**; the first task there is to list them. **Out:** request bodies, WEB's TypeScript types (no runtime validation exists there), and a shared-DTO library (rejected, section 4).

## 2. The problem, with evidence

Strict decoding is a decision (Femi, 2026-09-29: unknown keys are never tolerated in auth payloads; the same discipline protects money figures). The price: every field a source adds must be declared in every consumer's mirror, by hand, at the right time. Nothing checks that. It has failed twice:

| Date | What drifted | Effect |
|---|---|---|
| 2026-09-29 | EA's `GET /me` gained `userId` and `kycStatus`; four strict mirrors lagged | a live 500 on every human request in SOP (and GL before it) |
| 2026-10-12 | four EA mirrors: SOP `/sales` (decimal quantity, VAT and sale fields), SOP `/return-requests` (a renamed field), IM `/adjustments/pending` (`allowedActions`), HR `/payroll-run-submissions` (`employeeName`, `submittedBy`, `decidedBy`, `postings`) | "Sales today: Couldn't load" in UAT; payroll and stock adjustments missing from the approvals queue |

**Why it hid:** an EMPTY list decodes fine, so every drift stayed invisible until real data existed. Each consumer's gateway test used a hand-written sample (the HR "well-formed" test encoded the OLD shape and kept passing). Nothing ties a consumer's sample to the source's real output, and a source change to a response has no visible link to its consumers.

## 3. Requirements (P)

- **R1** A source cannot change a response it publishes to another service without a visible, reviewed change to a shared record of that response (the fixture).
- **R2** The fixture is the source's REAL output, generated and verified by the source's own tests through its real mapper, never hand-typed.
- **R3** Every consumer's strict decoder is tested against that fixture, so a field the mirror lacks fails CI, not production.
- **R4** Fixtures are NON-EMPTY and fully populated: every list has an element, every key present, and each nullable field appears both null and non-null (the empty-list blind spot is the whole point).
- **R5** Each fixture names its consumers, so the person changing the source sees who to tell.
- **R6** No new runtime coupling: services stay independently buildable and deployable. No shared DTO classes, no runtime dependency.
- **R7** Deploy order must not matter for ADDITIVE changes: new fields are declared in mirrors as optional with a default BEFORE the source ships; a removed or retyped field is a coordinated change by definition.
- **R8** Strict decoding is unchanged: never `ignoreUnknownKeys` on any of this.

## 4. Options considered, and the recommendation

| | Idea | For | Against |
|---|---|---|---|
| **A (chosen)** | **Golden fixtures** published by each source into the private `fish-contracts` repository, consumed as a pinned submodule; source golden test verifies, consumers decode | no runtime coupling; the same pinned-submodule mechanism `common` already uses, but a separate repo so fixture churn never forces a bump of shared code; a source change shows as a fixture diff in review | submodule pointers are bumped by hand, so a consumer that never bumps never sees drift (mitigated by the nightly drift job below); two PRs per source change |
| B | Shared DTO module (one Kotlin class used by both sides) | compile-time safety | breaks the deliberate "duplicate, loosely coupled" decision recorded in `common/README.md` and in every gateway's KDoc; couples release cycles; the mirror's strictness is the point |
| C | Consumer-driven contracts (Pact-style broker) | the strongest model | a new tool, broker and CI stage for a team of one; overkill at six services |
| D | Lenient consumers that log unknown fields | no outage | contradicts Femi's rule (strict decoding of what the platform reads); money and access figures would silently go missing |

## 5. Design of A (as built or agreed, 2026-10-13)

- **Where:** the private repository `prodeo-group-dev/fish-contracts` (Femi's choice), consumed as a pinned git submodule **named `contracts`** in every repo that writes or reads a fixture; a bump of the pointer is a deliberate, explicit per-repo act, exactly as for `common`. Layout: `contracts/<source>/<route-name>.json` (one fixture per response), `contracts/<source>/error-body.json` (the refusal body consumers read, `{error, detail?}`), `index.yaml`, and `kotlin/ContractFixtures.kt`. **Synthetic data only**: invented ids, names and amounts, never a real tenant, person, email or token.
- **`index.yaml` format:** one entry per fixture with `source`, `route` (including the query when it is part of the contract, for example `cash-balance-series?days=30`), `kind` (`response` or `error-body`), `fixture` (the path), `consumers` (the repos whose strict mirror must decode it, R5) and an optional `since` date for the drift job's report.
- **The loader (`ContractFixtures`, copied into each repo's test sources, `package contracts`):** needs `kotlinx-serialization-json`, which every service has, and the system property `contracts.dir`, set in `build.gradle.kts` as `tasks.test { systemProperty("contracts.dir", "$projectDir/contracts") }`. There is **no default**: a missing setting fails loudly. API: `read(path)` returns the fixture text; `assertSameJson(path, actualJson)` compares parsed JSON (object key order and whitespace ignored; array order and the text of numbers count) and shows both pretty-printed on failure; `verifyOrUpdate(path, actualJson)` is for sources (it rewrites the fixture when `UPDATE_CONTRACTS=1`, otherwise checks); `write(path, json)` pretty-prints with a fixed two-space indent and is refused without `UPDATE_CONTRACTS=1`.
- **Source side (golden test):** a test in the source repo drives the REAL route (its existing `testApplication` end-to-end style, with in-memory repositories) seeded with a populated, deterministic sample (fixed ids and timestamps, R4: every list non-empty, every key present, each nullable field both null and non-null across the fixture) and calls `verifyOrUpdate`. A difference fails the test; an `UPDATE_CONTRACTS=1` run rewrites the fixture. So the fixture can never be hand-edited into a lie.
- **Consumer side:** the consumer's gateway test reads the fixture through `read(path)` and answers it from a `MockEngine` through the REAL gateway with its REAL strict, production-configured client, and asserts it decodes and key values map. It replaces the hand-written samples.
- **Change workflow (the order that makes R7 true):** (1) the consumer adds the new field to its mirror as optional with a default and ships; (2) the source ships the field and updates the fixture in `fish-contracts` (its golden test forces this); (3) consumers bump their `contracts` pointer when convenient and their contract test exercises the new field. A source PR template line asks "does this change a response in `index.yaml`? Who consumes it?".
- **Who owns what.** *Sources* own their fixtures and golden tests (SOP, IM, GL, HR, POP, Omniview, and EA for `GET /me` and its internal routes). *Consumers* own their decode tests (EA for T8; GL, POP, IM, SOP and HR for the `/me` mirrors). *CM* owns the repository, the loader, the submodule wiring and recursive checkout in Jenkins, and the nightly drift job. *EA* owns this plan, T8 and T9. Only CM pushes and merges, as everywhere.
- **Drift job (catches the "never bumps" gap):** a scheduled Jenkins job (CM's) checks out each consumer's master, moves the `contracts` submodule to its latest master, and runs only the contract tests; red names the consumer and the field.
- **Honest limits:** fixtures prove the SHAPE the source's current code produces, not that the deployed version equals master; they do not cover behaviour, status codes or auth. A consumer whose gateway builds a different client than production (as `lenientOutboundHttpClient` does for POP) must use the production client configuration in the test. **WEB (TypeScript) is not covered by the Kotlin loader**: its response types are a plain cast with no runtime check; a WEB-side fixture type-check test is a possible later step. Request bodies are also out of scope.

## 6. Use cases and tasks (U, T)

| ID | Situation | Expected |
|---|---|---|
| UC-F1 | SOP adds a field to `/sales` and forgets to update the fixture | SOP's golden test fails with the diff |
| UC-F2 | SOP updates the fixture; EA has not declared the field | EA's contract test (after the pointer bump) fails naming the field |
| UC-F3 | A source adds a field, consumer pre-declared it optional | everything green in any deploy order (R7) |
| UC-F4 | A list is empty in a real response | fixtures are never empty, so the decoder is still exercised (R4) |
| UC-F5 | Nobody bumps `contracts` in a consumer for a month | the nightly drift job goes red for that consumer |

| Task | Where | Content | Size (estimate) |
|---|---|---|---|
| T1 | CM (**done**; EA reviewed) | the `fish-contracts` repository: layout, `index.yaml` with `kind` and `since`, the loader (package `contracts`, required `contracts.dir`, `assertSameJson`, `verifyOrUpdate`), README rules; revised 2026-10-12, merged as master `534092d` | 1 d |
| T2 | SOP **(next, first fixture)** | add the `contracts` submodule and `contracts.dir` wiring, copy the loader, golden tests for `GET /sales` and `GET /return-requests` plus the SOP `error-body` fixture; SOP's own Playbook or backlog should carry this row (I have not read it) | 0.5 d |
| T3 | IM | `/items`, `/adjustments/pending` | 0.5 d |
| T4 | GL | `cash-flow`, `profit-and-loss`, `balance-sheet`, `working-capital`, `trading-profit-and-loss`, `cash-balance-series`, `receivables-payables-summary` | 1.5 d |
| T5 | HR | `/payroll-run-submissions` | 0.25 d |
| T6 | POP | `/purchase-orders/fulfillment` | 0.25 d |
| T7 | Omniview | tickets, messages, unread (six routes) | 0.5 d |
| T8 | EA (consumer) | gateway tests read fixtures for SOP, IM, GL, HR, POP, Omniview; hand-written samples removed | 1 d |
| T9 | EA (provider) + GL, POP, IM, SOP, HR | `GET /me` golden test in EA (this also wires EA's own `contracts` submodule and loader), the five strict mirrors decode it; plus the fixture of EA's new `GET /api/internal/companies/{id}/industry` route (source EA, consumer SOP) and EA's `error-body` | 1.25 d |
| T10 | CM | the nightly drift job | 0.5 d |
| T11 | all | inventory of Phase 3 service-to-service calls, then fixtures for them | 0.5 d to inventory, then about 0.25 d per route |

**Order:** T1 (done), then T2 (SOP's fixture: it is the live pain and it proves the loader and wiring), then T8's SOP slice, then T9, then T3 to T7 one source at a time with T8 following each, T10, and T11 last. About 7 days across all repos for Phases 1 and 2, spread over the owning sessions (each owns its own source tests; EA owns T8, T9; CM owns T1, T10).

## 7. Order, rollout, rollback, and the decisions

**Rollout:** tests and a data folder only; no production behaviour changes, no deploy risk. **Rollback:** delete the contract tests; nothing else depends on them.
**Cost to watch:** every response change now touches two repos (source plus `fish-contracts`). That friction is the feature, but it costs a little each time; it is the right trade only for the responses another service reads.
**Decisions (all taken 2026-10-12, Decisions Log):** option A and Phases 1 and 2 approved; the nightly drift job approved; Phase 3 starts with an inventory (done 2026-10-12, 31 mirrors, see the platform contract SPUTO); home of the fixtures is the new private repository `fish-contracts`.

*Evidence read 2026-10-12 and 2026-10-13: the `fish-contracts` repository (README, `index.yaml`, `kotlin/ContractFixtures.kt`, master `534092d`), `common/README.md` (submodule consumption), `EA/build.gradle.kts` (srcDir wiring), EA's gateways and mirrors, SOP/IM/HR/GL/POP/Omniview source DTOs (via the audit), the 2026-09-29 and 2026-10-12 incidents. Not verified: that each source repo's existing end-to-end tests can seed the populated samples cheaply; that Omniview already carries a submodule setup (it needs the `contracts` one); the real Jenkins capacity for a nightly job.*
