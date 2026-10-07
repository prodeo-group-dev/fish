# What a Playbook is (platform definition)

**Status: 2026-10-07. Defined by Femi ("I would expand playbook definitions to include all SPUTO docs, i.e. SRS, use case docs, dependency-ordered task lists"). Applies to every service. Supersedes the narrower meaning used by the first two drafts (the ER School Playbook and the SOP Playbook), which were only the operator cheat sheet.**

A **Playbook** is everything a person needs to run, support and build on one service, kept together and kept honest about what the code does today. It has six parts:

| # | Part | What it answers | Typical form |
|---|---|---|---|
| 1 | **Operator sheet** | What does the system do TODAY, what do its errors mean, what must not be promised, what to collect before escalating | Plain text for Omniview's Playbooks tab, Q:/A: pairs, an error glossary, a NOT BUILT list. Written from the code, with a verified date and commit. |
| 2 | **Scope (S)** | What problem the service solves and where it stops | The SPUTO scope section / MVP definition |
| 3 | **Plan / SRS (P)** | The numbered requirements the service must meet | Requirements specification |
| 4 | **Use cases (U)** | Who does what, main flow, alternate and error flows | Use-case document |
| 5 | **Tasks (T)** | The work, broken down | Task list / backlog |
| 6 | **Order (O)** | The dependency order of the tasks: foundations before features | Dependency-ordered backlog, with the safety foundations (idempotency, concurrency guards, fail-closed configuration) first |

SPUTO = Scope, Plan (SRS), Use cases, Tasks, Order. Parts 2 to 6 are the SPUTO set; part 1 is the operator-facing view of the same service.

## Rules

- **One index per service.** The operator sheet opens with a "PLAYBOOK CONTENTS" section that links each of the six parts (a part that does not exist yet is listed as "not written", never omitted).
- **Honest status.** Every document says what it was written from (a commit or a date) and what is built, not deployed, or only designed. The operator sheet always ends with a NOT BUILT / not deployed / not yet exercised list, and is updated in the same change as the code it describes.
- **Docs-only changes stay out of service repos.** A docs-only merge to a service repo's master redeploys the service, so playbooks live in the FiSH repo (`docs/`), and the service repo's own `docs/` holds only its requirements material.
- **Foundations first.** Part 6 must list the safety foundations a feature depends on before the feature (Femi, 2026-10-07).
- **Owners.** The service's own session owns its playbook. Cross-service items (a change that needs two services) are written by the owner of the service that needs the change and registered in `docs/GL_POP_IM_SOP_Coordination.md`.

## Where each service stands (update as parts are written)

| Service | Operator sheet | Scope / SRS / Use cases | Tasks and order |
|---|---|---|---|
| SOP | `docs/SOP_Playbook_Draft.md` (draft, 2026-10-07) | `SOP/docs/SOP_MVP_Definition.md`, `SOP/docs/Sales_Order_Processing_Requirements_Use_Cases.md`, `docs/Sales_Order_Processing_DDD_Design.md`, `SOP/docs/Trade_Finance_Collection_Software_Requirements_Specification.md`, `SOP/docs/Trade_Finance_Collection_Use_Cases.md`, `docs/Sales_Processing_Requirements_Specification.md` | `SOP/docs/Trade_Finance_Collection_Backlog.md`, `docs/GL_POP_IM_SOP_Backlog.md`, `docs/Purchase_Inventory_Sales_Cycle_And_Reversals_Scoping.md`, `docs/IM_Goods_Issue_Idempotency_SPUTO.md`, `docs/Fee_Billing_Epic13_SPUTO_Scope.md` (SOP half in progress) |
| IM | not written (IM session owns it) | `IM/docs/Inventory_Management_Requirements_Specification.md`, `IM/docs/Inventory_Management_Requirements_Use_Cases.md`, `IM/docs/IM_MVP_Definition.md` | `docs/IM_Goods_Issue_Idempotency_SPUTO.md`, backlog rows in `docs/GL_POP_IM_SOP_Backlog.md` |
| POP | not written | `POP/docs/Purchase_Order_Processing_Requirements_Use_Cases.md`, `docs/Purchase_Order_Processing_DDD_Design.md` | `docs/GL_POP_IM_SOP_Backlog.md` |
| Education Runtime | `ER/Principal/docs/ER_School_Playbook_Draft.md` | `ER/Principal/docs/The_Principal_SRS.md`, `The_Principal_MVP_Definition.md` | `ER/Principal/docs/The_Principal_Backlog.md` |
| GL, EA, HR, WEB, Omniview | not written | each service's own requirements docs | each service's own backlog |
