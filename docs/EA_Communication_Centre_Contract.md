# EA Communication Centre: who can talk to whom, and the routes (CONTRACT)

**Status (2026-10-05).** The rules below are Femi's. They are **built on local EA branches and not deployed** (the company-links branch `feat/ea-company-links-messaging`, then `feat/ea-module-channels-per-company`; CM reviews and releases them after the security fixes and the support relay). WEB builds against this text. Product Support (tickets to Prodeo) is a different feature with its own contract (`Omniview_v2_EA_Route_Contracts.md`) and is not covered here.

## 1. Purpose (Femi, 2026-10-05)

The communication centre is for:
1. the **owner** to communicate with his team, however distributed, from within the app;
2. the **members of a company** to communicate with each other;
3. the members of **different companies** of one tenant to communicate across companies **only if the owner approves**. Approval is **per pair of companies**.

## 2. The rules

| Who | Can message |
|---|---|
| The owner (Owner-Admin) | anyone in the tenant, one to one; every channel of every company |
| Anyone | the owner, one to one |
| A member | any other **active** member of **the same company** (one to one), and their own company's channel |
| A member | a member of a **different** company one to one, **only if the owner has linked those two companies** |
| A member | a **module channel** of a company only if they hold that module **at that company** (the owner always can) |

- **A link joins exactly the two companies it names** and nothing else (A-B and B-C do **not** make A-C). It is unordered (A-B is B-A). By default **no two companies are linked.**
- **A link enables one-to-one messages only.** It does not open a company's channel or module channels to the other company's members.
- Removing a link stops new cross-company one-to-one messages; **history stays readable.**
- A pending invitee or a removed member cannot be messaged (404).
- Every approval and removal is recorded (who, when) in an append-only audit table. There is no route to read it yet.

## 3. Routes

All routes are `/api/tenants/{tenantId}/...`, human tokens only (a service-account token is `401`), Cognito ID token as `Authorization: Bearer`. Error bodies are `{error, detail?}`. A caller who is not a member of the tenant gets `403 forbidden`.

### 3.1 Owner approval of cross-company messaging (new, owner only)

| Route | Body | Success | Errors |
|---|---|---|---|
| `GET /company-links` | none | `200 [{companyA, companyB, approvedAt}]` | `403 forbidden` (not the owner) |
| `PUT /company-links` | `{companyA, companyB}` | `200 {companyA, companyB, approvedAt}` | `400 invalid_company_link` (same company twice), `400 bad_request` (`invalid_body`, `invalid_company_id`), `404 company_not_found` (either company is not the tenant's), `403 forbidden` |
| `DELETE /company-links/{companyA}/{companyB}` | none | `204` (also when the pair was not linked) | `400 bad_request`, `403 forbidden` |

The pair is unordered, in any order is the same link, approving twice changes nothing (the first approval stands). Ids are returned in a stable canonical order, not necessarily the order sent: show "A and B". **Ids only, no company names**: resolve names from `GET /me`'s company list.

### 3.2 One to one

| Route | Notes |
|---|---|
| `POST /messages/direct/{userId}` body `{body}` | `201` the message. `404 user_not_found` (not an active member of this tenant). **`403 cross_company_not_approved`** when the two people work in different companies the owner has not linked (the owner is exempt on both sides). `400 bad_request` for a blank body |
| `GET /messages/direct/{userId}` | `200` the thread between the caller and that user, oldest first; **not** restricted by links, so history survives unlinking |

### 3.3 Company channel

| Route | Notes |
|---|---|
| `POST /messages/company/{companyId}` body `{body}` | **Any member with access to that company** (and the owner) can post (before this change only the owner could). `403 forbidden` for others, including members of a linked company. `404 company_not_found` if the company is not the tenant's |
| `GET /messages/company/{companyId}` | `200` the channel, oldest first; same access rule |

### 3.4 Module channel (per company; replaces the tenant-wide one)

| Route | Notes |
|---|---|
| `POST /companies/{companyId}/messages/module/{module}` body `{body}` | `201`. The caller must be the owner **or** hold `{module}` at that company (`grantedModules` in `GET /me`, at least READ). `403 forbidden` otherwise (including a linked company's members); `404 company_not_found`; `400 bad_request` for an unknown module |
| `GET /companies/{companyId}/messages/module/{module}` | `200`, oldest first; same access rule |

**The old `/messages/module/{module}` (tenant-wide) is removed** (it now answers `404`). Messages written there before are kept in the database but are no longer reachable.

### 3.5 Unchanged

`POST/GET /messages/everyone` (the owner posts, every member reads), `POST/GET /messages/role/{role}` (the owner posts, members holding the role read), and `POST /messages/{id}/seen`. `seen` is now also refused with `403 channel_access_denied` for a module message the caller is not part of, and `403 company_access_denied` for a company message of a company the caller has no access to.

## 4. Message shape

`{id, tenantId, senderId?, fromOperator, audience, body, sentAt, seenBy[]}`. `body` is trimmed plain text, must not be blank; **no maximum length and no paging are enforced today.** `audience` is one of: `{type:"DIRECT", userId}`, `{type:"ROLE", role}`, `{type:"COMPANY", companyId}`, `{type:"EVERYONE"}`, `{type:"OPERATOR_THREAD"}`, and **`{type:"MODULE", module, companyId}`** (**`companyId` is new**: it was `{type:"MODULE", module}` before).

## 5. What WEB needs to build (for planning)

1. An **owner-only screen** to link and unlink pairs of his companies (section 3.1), showing company names resolved from `/me`.
2. Copy for `403 cross_company_not_approved` on one-to-one messages (for example "You can only message people in your own company unless the owner has linked your companies") and `404 user_not_found`.
3. **Company channel posting** for members, with the other-company `403` handled.
4. **Team chat moves to the per-company module path** (section 3.4): the picker works in the company the user is working in and lists the modules they hold there; the owner can open any.
Release: CM deploys EA and WEB as a pair, because the old module path disappears and the new one only exists after EA deploys. WEB may ship first with a one-release fallback to the old path on `404`.

## 6. Not built, deliberately

- A shared channel for two linked companies (a link only enables one-to-one messages).
- A route to read the link audit trail.
- Message length limits and paging (not asked for yet).
- Notifications for new messages.
