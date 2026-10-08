# RBAC: WEB's statement (reply to `docs/RBAC_SPUTO.md` v0.2, R11 and T16)

**From:** FiSH+ER WEB (the shared front end, `fish-web`). **Date:** 2026-10-08. **Status:** statement only. No gating has been changed (freeze respected). Everything below was read from the `WEB` working tree on `origin/master` (fb0e2cf) on the date above; nothing was run against a live service. File references are relative to `WEB/src`.

---

## 1. What WEB gates on today

WEB has exactly **three** inputs to its show/hide decisions, all from EA's `GET /me` (`api/me.ts`):

1. `tenant.isOwnerAdmin` (Tenant-wide boolean).
2. The Company's `grantedModules` list, read through `grantedModulesAt(tenant, selectedCompanyId)`.
3. The Company's `role`, read through `roleLabelAt` (a display label only; no decision uses it).

**WEB never reads the access level to decide anything.** `accessLevelAt()` exists in `api/me.ts` (it returns the explicit Company level, else `READ` for the Owner Admin, else `NONE`) but **no component calls it**. A user with `READ` sees every write control for every module they are granted. The server refusing the call (403) is the only thing that stops them, and the screen then shows the server's message.

### Gates by `isOwnerAdmin`

| Where | What is gated | File |
|---|---|---|
| Administration > Dashboard (nav item) | Shown to the Owner Admin only | `screens/EaHomeScreen.tsx` (adminNav filter) |
| Verification banner | Owner Admin only | `EaHomeScreen.tsx` |
| HR > Team (invite / remove staff) | `canManageTeam = tenant.isOwnerAdmin`; HR delegates see the list but no invite/remove | `HrTab.tsx` > `TeamTab.tsx` (`canInvite`) |
| HR > Employees (pay rate, currency, frequency, bank details) | `canEditPay = tenant.isOwnerAdmin`; others see the stored values resent unchanged | `HrEmployeesList.tsx` |
| HR > Salary advances (Approve button, posting-context fetch) | `isOwnerAdmin` (prop named `isOwnerAdmin` but fed `canManageTeam`) | `SalaryAdvancesTab.tsx` |
| Support: product-support tickets panel | Owner Admin only (non-owner gets a "not the Owner Admin" notice) | `ProductSupportPanel.tsx` |
| Support chat: unread count, announcements broadcast | `isOwnerAdmin` / `canBroadcast = isOwnerAdmin` | `SupportChatWidget.tsx`, `App.tsx` |
| Company picker | Groups the list into "owned" (isOwnerAdmin) and "staff" | `CompanyPickerScreen.tsx` |
| Header label | "You're the Business Owner" vs "You're Staff - {role}" | `TenantDashboard.tsx` |

### Gates by granted modules (per selected Company)

| Where | Rule |
|---|---|
| Operations tabs (SOP, POP, IM) | A module tab is shown only if its code is in `grantedModulesAt(...)`. If the Company is an `EDUCATION_RUNTIME` Company, the Students and Timetable tabs are added and SOP is hidden. |
| Finance tabs (GL, TAX) | Same filter. Education Companies also get "Fees & Billing". |
| Administration > HR & Payroll | Shown only if `HR` is granted. |
| Administration > Admissions | Shown only if `EDUCATION_RUNTIME` is granted. |
| Administration > Companies, Verification | Always shown. |

The module filter **fails open by design** where the field is missing (older cached response): extra tabs are shown, because "each module's own routes are the real enforcement point" (comments in `BusinessOperationsScreen.tsx`, `EaHomeScreen.tsx`).

### What a READ-only user sees today

Everything a write user sees, for every module they are granted. Concretely these write controls are all visible and enabled: new sale and invoice email (SOP Sales), create customer (SOP), create/submit/approve purchase order, receive goods, return outwards and its approve (POP), item create, receive, issue, transfer, bin assignment, stock count, adjustment and **approve adjustment** (IM), employee create, run payroll (HR), journal posting, bank reconciliation matching, fixed assets (GL), tax computation (TAX), fees billing (Education), admissions and student management (Education Runtime). A READ user clicking one gets the server's refusal as an error banner.

The Owner Admin (READ at a Company with no modules, as EA reports on master) sees **no module tabs at all** at such a Company: Operations and Finance are empty. Only Administration (Dashboard, Companies, Verification) and, if a module is granted, HR.

### Approval controls today (all visible to anyone who reaches the tab)

| Control | Screen | WEB gate |
|---|---|---|
| Approve purchase order | `PurchasesTab.tsx`, `CreatePurchaseOrderTab.tsx` | module only |
| Approve return outwards | `PurchasesTab.tsx` | module only |
| Approve inventory adjustment | `ImPendingAdjustmentsTab.tsx` | module only |
| Approve salary advance | `SalaryAdvancesTab.tsx` | `isOwnerAdmin` |
| Payroll approve / reject / retry | not built (screens waited on HR Wave 2; being built now, see section 5) | n/a |

---

## 2. Survey findings that name WEB, re-verified

| Finding (SPUTO) | Verdict | Evidence |
|---|---|---|
| WEB hides/shows by `isOwnerAdmin` and the module list; never by level (F7, section 1 table) | **Confirmed** | Only `isOwnerAdmin`, `grantedModulesAt`, `roleLabelAt` drive UI. `accessLevelAt` has zero call sites outside `api/me.ts`. |
| WEB comments still describe a READ floor (F7) | **Confirmed, stale** | `api/me.ts` KDoc on `CompanySummary`, `MyTenant.isOwnerAdmin` and `accessLevelAt` still describe an "intrinsic Tenant-wide READ floor" for the Owner Admin. SPUTO R4 replaces this with explicit assignments. Comments only; no logic depends on it except the `accessLevelAt` fall-back itself. |
| HR delegates hidden from invite/remove | **Confirmed, and it is a UI-only gate** | `HrTab` passes `tenant.isOwnerAdmin` as `canManageTeam`, so an HR_OFFICER with ADMIN (who EA's own routes would allow to invite, F5) sees no invite button. That hides a server capability, it does not enforce anything. |
| Owner-only pay fields | **Confirmed** | `canEditPay` is `isOwnerAdmin`. For a delegate WEB resends the stored pay values on PUT (so the server sees no change). Under T10 (initial pay on create becomes owner/ADMIN-only) the Create Employee form also needs a gate; today it shows pay fields to everyone who reaches it. |
| Salary-advance Approve is Owner-only in WEB, matching HR | **Confirmed** | `SalaryAdvancesTab.tsx:362`. |
| Added by WEB's own read: PO approve, return approve and adjustment approve are shown to every WRITE user | **New** | These are the F3 routes. Nothing in WEB distinguishes the creator from the approver. |

---

## 3. How WEB would gate by capability

### The field shape WEB wants from `/me` (consumers-first)

Per Company, in `CompanySummary`:

```json
{
  "id": "...", "name": "...", "schoolId": null,
  "role": "ACCOUNTANT",
  "grantedModules": ["GL", "SOP"],
  "capabilities": {
    "GL":  ["read", "write"],
    "SOP": ["read", "write", "approve"],
    "ADMINISTRATION": ["administer"]
  },
  "isOwnerAdmin": false
}
```

Why this shape:

- **Capabilities per module, not one set per Company.** A user may approve in POP but only read in GL; one Company-wide set cannot express that, and WEB's tabs are per-module.
- **A closed list of four lowercase tokens** (`read`, `write`, `approve`, `administer`), declared as a type in WEB. Strict decoding: an unknown token is a decode error, not silently ignored (matches the standing rule for auth payloads). If EA wants to add a fifth, it ships the type first.
- **`administer` is its own key (`ADMINISTRATION`) and a module-level entry,** because "invite staff", "set thresholds", "set policy" are configuration, not a module's data.
- **Keep `grantedModules` and `accessLevel` during the migration** so each consumer can switch independently; WEB switches module by module, then drops `accessLevelAt`.
- **`isOwnerAdmin` stays as a display fact** (header label, company picker grouping, verification banner), but stops gating controls (R11).
- Optional but useful: `selfApprovalAllowed: boolean` per Company for the Owner (D6), so the screen can show the flag without WEB inferring it (see section 4).

### Every screen/control that needs a capability

`W` = write, `A` = approve, `AD` = administer, `R` = read. "Hide" means not rendered; the server still checks (P8).

| Module | Screen / control | Needs |
|---|---|---|
| SOP | Sales list, customer list | R |
| SOP | New sale, invoice email, create customer | W |
| SOP | Customer-cancellation return / credit note: request (no screen in WEB today) | W |
| SOP | Return / credit-note approve (no screen in WEB today) | A |
| POP | Purchases list, supplier schedule | R |
| POP | Create / submit PO, supplier create, receive, three-way match, pay | W |
| POP | Approve PO, approve return outwards | A |
| POP | Approval threshold / settings (not in WEB today; will be needed) | AD |
| IM | Items, locations, stock velocity | R |
| IM | Create item, receive, issue, transfer, assign bin, stock count, request adjustment | W |
| IM | Approve adjustment (Pending adjustments tab) | A |
| GL | Reports, ledger views | R |
| GL | Journals, bank reconciliation, fixed asset register | W |
| GL | Period / account configuration (not in WEB today) | AD |
| TAX | Tax view | R |
| TAX | Compute tax | W |
| HR | Employees list | R |
| HR | Create employee, edit employee (non-pay), run payroll (submit) | W |
| HR | Edit pay / bank details | AD or owner only (T10 decides) |
| HR | Payroll approve / reject / retry; salary advance approve; leave approve | A |
| HR > Team | Invite / remove staff | AD |
| Administration | Companies list | R |
| Administration | Add company (`AddCompanyForm`), verification | AD |
| Administration | Dashboard | R (Owner-only today; keep as an explicit capability, not `isOwnerAdmin`) |
| Support | Product-support tickets, announcements broadcast | AD |
| Education | Students, timetable, admissions, fees: lists | R |
| Education | Create / edit students, admissions, fee billing | W (ER's own SPUTO decides any approve-type steps) |

### How the check would be written

One helper replacing `accessLevelAt` call sites: `can(tenant, companyId, module, capability): boolean`, backed by the strictly decoded `capabilities` map, defaulting to **false** when the Company or module is missing (R8, fail closed in the UI too). Tabs filter on `can(..., 'read')`, buttons render only when `can(..., 'write' | 'approve' | 'administer')`. Today's fail-open behaviour for a missing `grantedModules` field goes away with it.

---

## 4. Objections and things the SPUTO misses

1. **One-person business UX (UC-R9).** If the Owner gets every role as explicit assignments at registration (R4), a one-person business sees the full app, which is right. But two things need EA's guarantee, not WEB's guess: (a) the **backfill** (T6) must complete before WEB stops treating `isOwnerAdmin` as a display shortcut, or an existing Owner at a Company with no assignments will see an empty Operations/Finance; (b) a **Company created after the Owner joined** (second Company of a group) must get the same assignments automatically, or the company picker will list a Company the Owner cannot work in. WEB needs EA to say so in the contract; I will not paper over it by treating `isOwnerAdmin` as "all capabilities".
2. **Self-approval flag display (D6).** The server records it; WEB needs to *show* it where the Owner approves their own record, and to the next reader of the record. Needs from services: a boolean on the approval record (`selfApproved`) on every approve response and in every list/detail that shows an approved item, and a stable wording agreed once ("Approved by the Owner on their own entry"). WEB will not compute it from `createdBy == approvedBy`, because the identity forms differ across services today (T2).
3. **Creator != approver for employees (R2).** WEB should hide the Approve button on a record the signed-in user created unless they are the Owner. That is only possible if each list/detail response carries `createdBy` in the same canonical email form as `/me`. Today POP's approval records no actor at all (F3). Until then WEB cannot show the right state and will keep showing Approve and letting the server refuse.
4. **A refused action must read as a permission refusal, not a failure.** Services return different 403 shapes (HR has `reason: no_membership | insufficient_access | module_not_granted`, others return a bare error). R11 should add: every service returns `{ error: "forbidden", reason, requiredCapability }` so WEB shows "You can view this but not change it" consistently. Today each screen maps errors by hand.
5. **Delegation UI (R5).** Capped delegation means the invite form must offer only capabilities the inviter holds, at Companies the inviter administers. That needs `/me` to also say which Companies the caller can `administer`; it is covered by the `capabilities` map above, but the Team screen currently invites per Company with a free role choice and would need rework, not just a hidden button.
6. **Education Runtime roles (R12).** ER keeps its own staff roles (`staff_assignments`). WEB's Education tabs are gated today by `EDUCATION_RUNTIME` in the module list only. Until ER's capability mapping exists, WEB cannot show a Registrar a different screen from a School Admin. Needs ER's contract (what `my-classes` / `allowedActions` already give for assessment is the pattern to extend).
7. **Operator console is out of scope for WEB** (Omniview owns its own token auth), so R13 does not touch this app.
8. **The freeze and in-flight WEB work.** Two builds the SPUTO should know about, neither changes who can do what: the payroll approve/reject/retry screens (HR Wave 2 is live) and the Wave 3 preview/postings list. Both will be written with the approve button shown only where the server's `allowedActions`/status says so, not with a new role assumption. If CM wants them held until T5a, say so and they wait.

---

## 5. What WEB needs from EA and others

**From EA (T5a, T6):**
- The `capabilities` field on `CompanySummary` as in section 3, **declared in WEB's decoder before EA releases** (tell me the final shape and I ship the type first; I will not pre-empt it with a guess).
- A written statement of the Owner's assignments at registration, and a backfill for existing Companies and for Companies created after the Owner joined.
- Whether `accessLevel` and `grantedModules` stay during the migration, and for how long.
- The list of Companies where the caller may `administer`, for the Team screen.

**From each service (T8 to T11, T17):**
- `createdBy`, `approvedBy` and `selfApproved` on every approvable record, in canonical form.
- A uniform 403 body (`error`, `reason`, `requiredCapability`).
- For each approve route, the exact capability it requires, so the table in section 3 becomes a contract rather than WEB's reading.

**From ER:** the capability mapping for ER roles (R12) so the Education tabs can be gated per role.

**From CM:** a decision on whether to hold the payroll approval screens until T5a, and sign-off that WEB should drop the fail-open module fall-back when `capabilities` lands.

**What WEB will do, in order, once the contract exists:** declare the type; add `can()`; move one module at a time behind it (SOP first, since its Sales uplift is the first to be removed, T7); delete `accessLevelAt` and the stale READ-floor comments last. No WEB change to who sees what will ship before then.
