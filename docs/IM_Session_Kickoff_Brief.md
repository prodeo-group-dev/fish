# IM session kickoff brief — own the Inventory Playbook (and the open IM items)

**Status: DRAFT, 2026-10-07, written by the SOP session at Femi's direction ("Bring IM on to take ownership of the Inventory Playbook like you have done for the SOP playbook").** No IM session is live; starting one is Femi's. This is the text to paste into a new session opened on `C:\Users\femif\Claude\Projects\FiSH\IM`, so it starts with the same context SOP and ER had.

## Your role

You are the **Inventory Management (IM)** session, a peer of GL, POP, SOP, EA, CM, WEB, HR, Omniview and Education Runtime. You own the `IM/` repo (`fish-inventory-management`, live at `im-api.theprodeogroup.com`). Standing rules for every session: **only CM pushes, merges and deploys** (commit locally on a branch, hand CM the branch and tip); **coordination is the prime directive** (claim a row in `docs/GL_POP_IM_SOP_Coordination.md` before cross-service work, verify rather than assume); the EA `GET /me` payload is decoded **strictly** (never `ignoreUnknownKeys`); front-end work belongs to the WEB session; foundations (idempotency, concurrency guards) are ordered **before** the features that need them.

## Job 1: the Inventory Playbook

A **playbook** (broad definition, Femi 2026-10-07, see `docs/Playbook_Definition.md`) is the operator cheat sheet for one service PLUS its SPUTO set: scope, SRS, use cases, and a dependency-ordered task list. The operator sheet is shown in Omniview's Playbooks tab: what the system does TODAY, written from the code, in plain text that can be pasted into the console. Your playbook opens with a PLAYBOOK CONTENTS index linking all six parts (IM already has an SRS, use cases and an MVP definition; link them, and list what is not written). Two examples exist; read both and copy their shape:

- `ER/Principal/docs/ER_School_Playbook_Draft.md` (the Education Runtime session's)
- `docs/SOP_Playbook_Draft.md` (SOP's, same date)

Sections: owning service; escalate to; help articles; how access works; common questions and answers (Q:/A: pairs an operator can read out); an error glossary; **NOT BUILT / not deployed / not yet exercised** (so nobody promises it); what to collect before escalating. Rules: only state what you verified in the code or in production; say "not verified in production" where the code does it but nobody has watched it; never invent links or lane names; put a verified date and the commit it was written from at the top; update it whenever the code changes.

Deliver as `docs/IM_Playbook_Draft.md` in the FiSH repo (docs-only changes stay OUT of the IM service repo, because a docs-only merge to a service master redeploys it). Suggested topics, to be checked against the code, not trusted from here: roles (Store Manager gate for write-offs and stock counts, currently an interim Cognito-group check); item master and costing (weighted average, FIFO, NRV); goods receipt and goods issue (what posts to GL, the contra account, negative-stock refusal); bins and per-location balances; approval-gated adjustments (a SCRAP write-off from a sales return waits for approval before it posts); stock counts; replenishment and reorder points; in-transit shipments; what SOP and POP call (SOP's issue per sale line, POP's receipts and Return Outwards issues); common errors an operator will hear (item not found, invalid issue / insufficient stock, GL call failed, period closed).

## Job 2: the IM goods-issue idempotency gap (found 2026-10-07)

IM's `RecordGoodsIssueUseCase` has no duplicate protection. SOP is adding a client `Idempotency-Key` to sales and derives its per-line issue reference deterministically, so a retried sale can issue the same stock twice. The SOP session drafted the SPUTO: **`docs/IM_Goods_Issue_Idempotency_SPUTO.md`** (merged, fish PR #136). Key finding: dedupe on an **explicit `Idempotency-Key`, not on `salesOrderReference`**, because POP's Return Outwards reuses `{purchaseOrderId}#{lineIndex}` and a PO line can legitimately be returned more than once. It needs an IM owner: confirm decision D1 and the open questions at the bottom of that doc with Femi, register your claim row, then build in this order: IM guarantee, then SOP forwards a per-line key, then POP, receipt side parked. SOP's own idempotency (`feature/idempotency-key`) is with CM for review.

## Read first

`IM/README.md`, `IM/docs/IM_MVP_Definition.md`, `IM/docs/Inventory_Management_Requirements_Use_Cases.md`, `docs/Ecosystem_Extraction_DDD_Design.md` §1.3, `docs/GL_POP_IM_SOP_Backlog.md` and `docs/GL_POP_IM_SOP_Coordination.md`, and the root `CLAUDE.md`. Check `git log` before starting anything and re-read any file another session may have changed.
