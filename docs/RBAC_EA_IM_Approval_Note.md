# EA + IM: replacing the `StoreManager` group with an EA approve capability (W-H3, T11 c)

**Status:** design note, docs only, 2026-10-08. Written by the EA session for CM; IM has fact-checked the IM-side facts against its master (section 3). No authorization code is written or proposed for release before CM's go; the RBAC freeze holds.

**Femi's decision (via CM, 2026-10-08):** no Cognito stopgap. "Fix it once and for all, collaborate with EA." The Owner must be able to approve and reject stock adjustments, and the answer must come from EA, not from a group nobody can see.

## 1. What is wrong today (verified in code)

- IM approves and rejects an adjustment only if the human token carries the Cognito group `StoreManager` (`Roles.kt` `requireStoreManager`, called at `AdjustmentAndStockCountRoutes.kt:98,138`). EA is not consulted for that decision.
- EA already says the Owner may approve: his registration assignment is `OWNER_ADMIN` at `ADMIN` with every business module including `IM` (RegisterCompanyUseCase, since 2026-09-23; migration V15 for older owners). Under today's ladder `ADMIN` includes `APPROVE`. So the permission **exists in EA and `/me` already reports it**; IM simply never reads it. This is why the Owner is refused (W-H3).
- The group is pool-wide, not per Company, and invisible in EA (SPUTO F13).
- **A trap in the obvious fix.** IM's `authorizeIm` returns `true` for any service account before it looks at EA (`Auth.kt:301`). If `requireStoreManager` were replaced by `authorizeImForApprove` built the same way, **POP's and SOP's service tokens could approve adjustments**. Today the group check excludes them by accident (service tokens carry no `cognito:groups`). The new check must refuse service principals explicitly (SPUTO R2: "a service principal may enter a record but never approve one").

## 2. What EA exposes (no new EA endpoint is needed)

| Need | Today (already on `GET /me`, per Company) | After T5a step 2 (additive) |
|---|---|---|
| May this person approve at this Company? | `companies[].accessLevel` is `APPROVE` or `ADMIN` | `companies[].capabilities` contains `approve` |
| Is the IM module granted? | `"IM" in companies[].grantedModules` | unchanged |
| Who is the actor (audit)? | `userId` (stable) and `email` | unchanged |
| Is he the Owner (D6 self-approval flag)? | `tenants[].isOwnerAdmin` | unchanged |
| Not assigned at this Company | `accessLevel: null`, `grantedModules: []` = no access | `capabilities: []` = no access (R8) |

**Owner holds approve explicitly (D2/D4):** already true as an explicit assignment. T6 (EA) adds the rule that this capability cannot be removed from the Owner, and a one-off check that every legacy Company has it. **Delegation (D2):** the Owner gives a person `APPROVE` (later: the `approve` capability) with the `IM` module at that Company through the existing invite/re-assign flow; a grantor can grant only what they hold there. Nothing new to build in EA for that.

One modelling point for Femi, not decided here: EA's approve is **per Company, combined with the module set**. A person with `APPROVE` at a Company and modules `IM`+`POP` can approve in both. Approving in IM but not POP (a separate approve per module) would need per-module capabilities, which T5a does not propose. Recommendation: keep it per Company until a real case needs more.

## 3. What IM changes (T11, shipped as ONE increment: IM's recommendation, EA agrees)

IM fact-checked this note against its master. Confirmed: `requireStoreManager` is called at exactly two places (approve `AdjustmentAndStockCountRoutes.kt:98`, reject `:138`); stock counts need only WRITE despite `Roles.kt`'s comment; `isServiceAccount` is true only for tokens that authenticated through the POP or SOP providers, so it is the right test; and today's exclusion of service tokens is **incidental** (service accounts are Cognito users, so one added to the group would pass today), which makes the explicit refusal essential, not belt-and-braces.

IM's order of checks today is `authorizeImForWrite` at the **URL's** Company, then the group check, then load the adjustment and its Item, then `requireOwnedBy(item, URL Company)` (404 otherwise). That is equivalent to taking the Company from the adjustment's Item, so an approver can approve only at a Company where they hold approve. **Keep that order** for the new check.

The increment, in this order inside IM:
1. **Record the actor** (migration: `created_by`, `decided_by`, `decided_at`; actor = EA `userId` from `/me`). Without it, steps 2 and 3 cannot be enforced or even audited (T11 a, T22).
2. **Creator is not approver; the Owner is exempt and his self-approval is flagged** in the record (P3, D6; T11 b).
3. **`authorizeImForApprove(companyId)`**: refuses service principals with 403; otherwise the same `ImMembershipAuthorizer` path, minimum `APPROVE`, `IM` module required (T11 c). Approve and reject use it; `requireStoreManager` and `ROLE_STORE_MANAGER` are deleted.
   **Required tests (CM's review, 2026-10-08):** a POP token and a SOP token are each refused (403) on approve and reject; a human with `APPROVE` but **no `IM` module** at that Company is refused; a human with `APPROVE`+`IM` at a *different* Company is refused (404 via `requireOwnedBy`); the Owner is allowed and, when he is also the creator, the record carries the self-approval flag; an employee who created the adjustment is refused.
4. After T5a step 3 the check becomes `"approve" in capabilities` instead of `accessLevel >= APPROVE`; step 2 of T5a derives capabilities from the same ladder, so no decision changes at that swap.

**Why not ship the ladder check alone (IM's objection, accepted).** The group is deliberately narrow: someone was made an approver on purpose. `accessLevel >= APPROVE` lets **every** person holding ADMIN with the IM module at a Company approve, which is wider, and the SPUTO's B1 migration maps ADMIN to the full set, so the width carries into the capability model. Today only the Owner and any delegate Femi or the Owner has deliberately set to ADMIN hold it, so the practical widening is small, but it must be confirmed before cutover, not assumed.

**Precondition (EA and CM):** before cutover, (a) EA lists who holds `APPROVE` or `ADMIN` with `IM` at each Company, from the database (CM's RDS lane), and the Owner confirms those are the intended approvers; (b) CM lists the `StoreManager` group members in Cognito (IM cannot see it) and anyone in it gets an `APPROVE`+`IM` assignment in EA first, so nobody loses approval. Femi's "prod data is legacy test data" applies, but the check is a few minutes.

WEB: IM is adding an `allowedActions` field to pending adjustments **from the current rule**, so WEB needs no change when the rule moves from the group to EA.

## 4. Order

| Step | Owner | Depends on | Release |
|---|---|---|---|
| A. Precondition lists (section 3) | EA, CM | CM's go for the reads | first |
| B. WEB shows the interim message (section 5) | WEB | none | before or with C |
| C. IM increment: actor + creator != approver + `authorizeImForApprove` on the ladder, service principals refused, group check removed | IM | CM's go (it changes who may approve), A done | **May ship before T5a** (it reads data EA already publishes and is the proper design, not a Cognito stopgap), but **only as the whole increment, never the ladder check alone** |
| D. T5a steps 1-2: consumers declare `capabilities`, EA publishes it | all, EA | CM's clearance | per EA statement 3.1 |
| E. IM swaps `accessLevel >= APPROVE` for `approve in capabilities` | IM | D step 3 | one line, no behaviour change |
| F. T6: approver capability not removable from the Owner | EA | T5a | with T5a |

CM asked for this "behind T5a". The note keeps C ahead of T5a as a possibility because the data already exists and the Owner stays refused until it ships; E is the part strictly behind T5a. **CM decides.** If CM prefers everything behind T5a, C and E collapse into one step after D.

## 5. Interim answer for the Owner (WEB)

Until A ships, an approve or reject returns IM's 403 `forbidden`. WEB should show, on that 403 for these two actions: **"Approval is being moved to your role. It is not available yet."** (CM's wording) instead of the raw "Requires the StoreManager role". When A ships, the same 403 means the person genuinely lacks approval at that Company; WEB should then say "You do not have approval rights for this Company. Ask the Owner." Both messages are WEB's to word and build.

## 6. Out of scope here

Whether ordinary receipts and issues need an approver (D7, Femi's); a route allow-list for POP/SOP service tokens (T15); anything in EA's authorization code (frozen until CM's go).
