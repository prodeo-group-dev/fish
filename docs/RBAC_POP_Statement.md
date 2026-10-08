# POP: statement for the RBAC SPUTO application round

**From:** Purchase Order Processing (POP) session. **Date:** 2026-10-08. **Written against:** `docs/RBAC_SPUTO.md` v0.2 and POP `origin/master` at 3e6a41c (POP :31). Docs only; no code or authorization change, per the freeze. Everything in section 1 was read from the code, not remembered.

## 1. POP's current authorization rules, as the code does them

**Who is asked.** POP keeps no user list. Every route under `/api/companies/{companyId}/...` calls EA `GET /me` with the caller's own bearer token (`PopMembershipAuthorizer`, `Auth.kt`). EA unreachable = 503 (fail closed); no valid token = 401.

**The decision.** For the Company in the URL, POP allows the call when all three hold: the caller has an active Membership in the one Tenant configured for this deployment (`POP_EA_TENANT_ID`); the Company's `accessLevel` from `/me` is at least the route's minimum (ordinal compare on NONE < READ < WRITE < APPROVE < ADMIN); and `"POP"` is among the modules granted at that Company. A Company missing from `/me` is NONE for everyone, the Owner Admin included (the Owner Admin's intrinsic READ floor needs the module grant too, which EA does not give, so an Owner Admin with no assignment is refused everywhere). Refusal is 403 with a reason.

**Minimums per route.**

| Minimum | Routes |
|---|---|
| READ | every GET: purchase order by id, `pending-action`, `fulfillment`, suppliers list, `purchase-order-settings`, `accounts-payable-due-date-aging` |
| WRITE | everything else, with no distinction between kinds of write: create/amend/cancel a PO, **submit-for-approval, approve, send**, receive a line, **record the three-way match (AP recognition), record a supplier payment (cash out)**, supplier create/activate/deactivate, **PUT `purchase-order-settings` (the approval threshold and the match tolerance)**, negotiation proposals accept/reject, discrepancy reports acknowledge/resolve, returns outwards request/approve/reject/**dispatch (moves stock value through IM)**/credit-note |
| APPROVE, ADMIN | **no POP route asks for either.** POP never reads APPROVE or ADMIN specially. |

**Other entry points.**
- Supplier portal (`/supplier-portal/...`): no sign-in. A per-order link token: the secret is stored hashed, has an expiry and a revoked flag, and is issued when the order is sent. A token can attach a waybill, raise a negotiation proposal or raise a discrepancy report on its own order only. I found no rate limiting on them.
- `/health`: open.
- **No inbound service callers.** POP has one JWT verifier (human tokens, `POP_JWT_AUDIENCE` required at start-up) and no service-audience verifier, so it has no `serviceVerifier ?: verifier` fall-back and nothing like F1.
- Outbound: POP calls GL and IM as itself with Cognito client-credentials tokens (`POP_GL_*`, `POP_IM_*`). Those credentials are not bound to a Tenant or Company beyond what GL and IM decide.

**Where the Tenant and Company come from.** The Company is the URL path Company, which every record route then checks owns the record (fixed and live: nested ids 2026-10-07, suppliers 2026-10-07, the GL/IM posting Company 2026-10-08, `POP_GL_ENGINE_COMPANY_ID` no longer read). The Tenant is still fixed per deployment (`POP_EA_TENANT_ID`, `POP_GL_ENGINE_TENANT_ID`).

**What POP records about who did something: nothing.** No purchase order, return, supplier, settings change or payment stores a creator, submitter, approver or actor. Not from the token and not from a body field. (I grepped the domain and application layers.)

## 2. Re-verifying the survey

- **F3 (POP half): confirmed in full.**
  - Approval needs only WRITE and the approver is not recorded: `ApprovePurchaseOrderUseCase` takes only a PO id.
  - The same person can submit, approve and send their own order.
  - The threshold is editable with WRITE: `PUT purchase-order-settings` is `authorizePopForWrite`, so a WRITE user can raise it or clear it.
  - **No threshold = no approval needed**: with no `approvalThresholdAmount`, `send` goes straight from DRAFT. That is the default for every Company today. An unevaluable threshold (currency mismatch) counts as exceeded.
- **F6 (POP half): confirmed.** POP fixes one Tenant in its environment. POP's own outbound service credentials are not scoped. POP has no inbound service credentials.
- **F7 (POP half): not present.** A Company absent from `/me` is NONE in POP, which already matches R8. POP does not apply any Owner Admin uplift.
- **F1, F2, F4, F5, F8: not applicable to POP.**
- **Nothing in the survey names POP's returns outwards, payments or match.** Section 4 raises them.

## 3. Gaps against R1 to R13 and tasks T4 and T9

| Item | POP today | Gap | Estimate (POP side) |
|---|---|---|---|
| R2 approvals need approve, creator != approver, actor from the token | WRITE; no actor; no check | all three missing | see T9 below |
| R3 thresholds ADMIN-only, audited | WRITE; not audited | missing | 1 day, plus the audit shape from T17 |
| R4/T6/T7 Owner's explicit assignments | POP applies none | none to do; works once EA creates them | 0 |
| R6 fail closed | start-up fails if the audience is unset; no fall-back verifier | none | 0 |
| R7/T15 scoped service credentials, Tenant from the Company | one deploy-time Tenant; unscoped outbound credentials | open, waits on D5 and GL's options note | 2 to 3 days after GL decides |
| R8/T4 missing Company = NONE | already NONE | none | 0 |
| R9 canonical email | POP does not match emails itself; EA resolves the token | none now. Recording an actor will use EA's reported email | 0 |
| R10 audit record | none | missing | with T9 |
| R11 WEB gates by capability | WEB's | not POP's | 0 |
| R12 runtime contract | n/a | n/a | 0 |
| R13 operator tokens | n/a | n/a | 0 |

**T9, how it would work.** I suggest splitting it, because the first half changes nobody's permissions.

- **T9a (safe now, additive, no policy change): record who did it.** Add `createdBy`, `submittedBy`, `approvedBy` (EA `userId` plus the email EA reports for the token) to purchase orders, and the acting identity to returns, payments, matches and settings changes. EA's `/me` already carries both values and POP's DTO declares `userId` and the lookup returns the email; passing `userId` through the lookup result to the routes is a small change. Nothing is taken from a body field (P9). One migration (V15), no behaviour change. Estimate: 1 to 1.5 days with tests, including a real-Postgres run.
- **T9b (after T5a/T6, needs the capability model):** approve requires the approve capability; `PUT purchase-order-settings` requires administer; the approver must differ from the creator unless the approver is the Owner.
  - Approval gate: about 1 day.
  - Settings gate and audited before/after: about 1 day.
  - Creator != approver: about 1 day.
  - Integration and tests: about 1 day.
  - Total: about 4 days, after T5a ships and POP has declared the new `/me` field.

**How creator != approver works with the Owner's self-approval (D6).** The rule needs two facts per request: who created the order (stored by T9a) and whether the caller is the Owner. `/me` already reports `isOwnerAdmin` per Tenant membership, and POP already decodes it. The check at approve time: if the approver's user id equals the creator's or submitter's, refuse unless `isOwnerAdmin`; if it is the Owner, allow and store `selfApproved = true` on the approval so the audit record flags it. **POP records the actor**, from `/me` on that request, never from the body. Employees: refused when they created or submitted it. A delegate who is not the creator: allowed.

**What "the Owner" means for a threshold approval in POP.** The Owner holds the approve capability from registration (R4); a delegate holds it by grant. POP only needs to see the approve capability in `/me` for that Company; it does not need to know who granted it.

## 4. Objections and things the SPUTO may have missed

1. **"No threshold = no approval" defeats P3 by default.** With no threshold set, a WRITE user can create, send, receive, match and pay a purchase order alone. R3 makes the threshold ADMIN-only, but the absence of a threshold is itself a policy. **Decision for Femi:** keep "no threshold means no approval step" (the current behaviour, friendliest to a one-person business) or require every Company to set one. I recommend keeping it and showing the Owner a clear prompt to set one; changing it silently would break every existing Company.
2. **Payment and match have no approval step at all.** `pay` is a cash-out and `match` recognises a liability, both plain WRITE with no second person. The SPUTO names approval only for POs. Is separation of duties required for payment (create the PO, pay it)? If yes, POP needs a rule for it (T9c), and I would not size it until the answer.
3. **Return approval and dispatch** are WRITE too, and dispatch posts stock value through IM. IM's adjustments are in T11; POP's returns outwards are not named anywhere. I would treat returns approval like PO approval (same capability, same creator != approver rule).
4. **R1 and the ladder.** If ADMIN stops implying APPROVE and WRITE (D1), any service that compares the level by ordinal compare must change at the same time, or an ADMIN-only person would silently gain or lose access depending on which side moves first. POP's check is an ordinal compare on the level today. POP will move to the capability set only after T5a, with the new field declared first (strict decoding).
5. **Supplier portal links are bearer secrets and I found no rate limiting on them.** Not RBAC strictly, but part of "who can act". Worth a line in the live-switch scope rather than this SPUTO.
6. **Existing records have no creator.** After T9a, every order created before it has `createdBy` null. T9b must define that case; I propose treating null as "different from the approver" (allow), so existing orders can still be approved.

## 5. What POP needs from others

- **EA:** the capability set on `/me` (T5a) with the new field name agreed before it ships, and `isOwnerAdmin` kept on `/me`. EA's `userId` and `email` fields must stay stable; POP records the actor from them.
- **CM:** a go for T9a as "safe now", and the decision on item 4.2 (payment) from Femi.
- **GL:** the Tenant-header decision for R7/T15 before POP removes its deploy-time Tenant.
- **WEB:** hide approve and settings controls by capability (R11), and handle a new refusal reason for "you created this".
- **Femi:** the two decisions in 4.1 and 4.2.

## 6. Proposed order for POP

1. **T9a** (record the actor), as soon as CM says go. Additive, no policy change.
2. **T9b** after EA ships T5a/T6 and POP has declared the new field.
3. **T9c** (payment and returns), only after the answers in 4.2 and 4.3.
4. **T15** (derive the Tenant from the Company), after D5 and GL's options note.

POP's other work (T6 return-dispatch idempotency, held for IM's verification) is unaffected by any of this.
