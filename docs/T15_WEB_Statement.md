# T15: WEB's statement (everything in the app that assumes one Tenant, or one Company)

**From:** FiSH+ER WEB. **Date:** 2026-10-09. **Asked by:** CM, on Femi's decision that T15 (multi-Tenant) comes first. **Status:** statement only; no WEB change is made by this document. Read from the `WEB` tree on `origin/master` (6da9cc9) on the date above. Nothing was run against a live service for this document, except that a live CORS preflight sweep earlier today (see section 6) was used for the header facts. Paths are relative to `WEB/src`.

**Femi's two walls (CM, 2026-10-09):** Tenant versus Tenant, AND Company versus Company inside one Tenant (each business has its own GL and data; consolidation later). Sections 3 and 4 answer the second wall.

---

## 1. Where WEB assumes one Tenant

**Short answer: WEB itself already handles several Tenants. It is the four services bound to one Tenant by deployment config that do not.**

| Item | What the code does | One-Tenant assumption? |
|---|---|---|
| Build-time config (`config.ts`) | API base URLs only. No Tenant or Company id anywhere. | No |
| Login (`App.tsx`, `loadProfileAndRoute`) | Calls EA `GET /me`, which returns `tenants[]`, each with its own `companies[]`. WEB flattens them into one list of (Tenant, Company) options (`companyOptionsFor`). | No: it supports several |
| Which Tenant is picked | None is picked as such. With more than one option the person always lands on the company chooser (Femi, 2026-09-18); with exactly one option that one is used. Choosing a Company sets `myTenant` to the Tenant that owns it. A deep link `/fish/{companyId}/{view}` (built 2026-10-09, with CM for release) selects that Company, but only if the signed-in person's own `/me` lists it. | No |
| Chooser display | Shows Company name, role, and the Tenant name, grouped as "owned" (Owner Admin of that Tenant) and "staff". | No: Tenant-aware |
| A Tenant with no Companies | `profile.tenants[0]` is used (`App.tsx` line ~219). With two Tenants and no Company in either, which one is shown is arbitrary. | Weak, minor |
| `X-Tenant-Id` | Sent only on calls to **GL** (`tenantFetch`: reports, journals, accounts, fixed assets, tax, VAT categories, sales invoice, customers, aging, bank reconciliation). The value is the selected Company's Tenant id. Not sent to EA (EA refuses it; fixed 2026-10-08), SOP, POP, IM, HR or Education Runtime. | No |
| EA calls | Tenant id in the path (`/tenants/{t}/...`) from the selected Company's Tenant. | No |
| SOP, POP, IM, HR | WEB sends **no Tenant id** to them; they take the Tenant from their own deployment config and check the caller's Membership in it. So a person in a different Tenant gets 403 on every call, whichever Company is selected. | **This is the gap (T15).** Nothing in WEB can fix it |
| Education Runtime | Identified by `schoolId` (from `/me` `schoolId` per Company, or a manual id stored locally). No Tenant id. | No |

**Two Tenants for one person (the case CM asked about):**
- The chooser lists both Tenants' Companies; the person picks one; WEB sends GL and EA calls for that Company's Tenant. This already works for GL and EA.
- For SOP, POP, IM and HR it works for the Company whose Tenant is the deployment's Tenant, and answers 403 for the others (the live failure of 2026-10-09: the tester's second Tenant `15734cdc-...` against services bound to `9fa2198b-...`).
- **What the UI does today on that 403:** each screen shows its own message ("You don't have access to Sales at this company", HR's reason copy, and so on). They do not say "this company belongs to a different organisation". **What it should do once T15 ships:** nothing different, because the services will answer by Company. **Until then:** a single screen-level message on any 403 from these four services, "This company is not set up for this module yet. Ask support." WEB can build it on request; it needs no contract.
- **Onboarding trap found this week:** `App.tsx` sends a signed-in person to the new-Tenant wizard whenever `/me` fails for any reason (401 for a person EA has no Membership for, but also a 5xx or a network failure at load). The tester created a second Tenant exactly this way (`POST /api/tenants` one minute after a 401 on `/me`). WEB should send a person to onboarding only for the "no Membership yet" answer (401/404 from EA), and show a "couldn't load, try again" screen for any 5xx or network failure. WEB will make that change (small, in `loadProfileAndRoute`). EA's possible `EA_ONBOARDING_CLOSED` flag (403 `onboarding_closed` on `POST /tenants`) would need a screen: "Ask the business owner to invite you"; WEB can build it once EA confirms.

## 2. Flat routes WEB calls (no Company in the path) and the Company-scoped alternatives

Where a call has no Company in the path, the Company comes from the body, a query string, or from the service's own lookup of the record's id.

| Service | Call | How the Company is carried | Company-scoped alternative exists? |
|---|---|---|---|
| SOP | `GET /api/sales?companyId=X` | query | none known (CM named this as the flat route); SOP to say |
| SOP | `POST /api/sales` | `companyId` in body | no |
| SOP | `POST /api/sales-orders/{id}/collections` | by order id | no (the id belongs to one Company) |
| SOP | customers: `/api/companies/{c}/customers...` | path | already scoped |
| HR | `POST /employees`, `PUT /employees/{id}` | body / id | needs HR to say |
| HR | `GET /payroll/last-run?companyId=` | query | no |
| HR | `POST /payroll/run` (`companyId` in body), `GET/POST /payroll/run-submissions/{id}...`, `/employees/{id}/salary-advances`, `/salary-advances/{id}/approve|reject` | body / id | by record id; list is `GET /companies/{c}/payroll-run-submissions` (scoped) |
| GL | `POST /journal-entries`, `POST /fixed-assets`, `/fixed-assets/{id}/...`, `POST /sales/create-invoice` | body | GL derives the Tenant from the Company; `X-Tenant-Id` is sent and validated |
| GL | `GET /jurisdictions` | none (reference data) | not Company data |
| POP | everything is `/companies/{c}/purchase-orders...` | path | already scoped |
| IM | everything is `/companies/{c}/items...` (scoped 2026-09-29) | path | already scoped |
| EA | `/tenants/{t}/companies/{c}/...`, `/tenants/{t}/support/tickets` | path | already scoped |

**The conclusion for T15:** WEB can adopt whatever convention the services settle on. If the services derive the Tenant from the Company, WEB changes nothing: it already sends the Company id on every call, in the path, query or body. If a service wants a Tenant header instead, WEB can send `X-Tenant-Id` to it (a CORS change in that service's allowed headers, per the lesson of 2026-10-09: check a real browser preflight first).

## 3. Company wall: can the app show or keep one Company's data under another?

**What was checked, and the answer:**
- **Switching Company always goes through the chooser,** which unmounts the whole dashboard. Every screen's state (lists, forms, selected rows, drafts) is React state inside that tree, so it is discarded. A deep link opens exactly one Company and is honoured only if the person's own `/me` lists it.
- **Browser storage is keyed per Company or per Tenant where it holds business data:** `school-id:{companyId}` (a manual School ID), the last VAT category chosen (`vatCategories`, remembered per Company), the verification-banner dismissal (per Tenant, session only). Not keyed: `fish-news-seen` and the dismissed-notices list (Omniview notices are not business data) and the theme.
- **No module-level caches or singletons** hold API results across Companies (no query cache, no global store). Every screen refetches for its Company on mount.
- **The floating support widget lives outside the dashboard** (it is rendered once in `App.tsx`) and therefore survives a Company switch. It is given the selected Company as a prop. **One thing to verify and I will fix in WEB:** its internal state (the chosen channel, loaded messages) is not keyed by Company, so after a switch it can show the previous Company's module chat until its next fetch. WEB will key the widget and the notices strip by (Tenant, Company) so they remount on a switch. Small change, no contract.
- **Module chat fallback:** `api/messages.ts` tries the per-Company route first and falls back to the Tenant-level module route if EA answers that route is missing. The Tenant-level route is shared across every Company of the Tenant, so with two Companies under one owner it would mix chat between them. This fallback should be removed once EA confirms the per-Company routes are live everywhere (WEB can do that; it is a one-line deletion plus a test).

**Screens that aggregate across Companies today: none.** There are no cross-Company totals, tiles or reports. Every report, list and dashboard is for one Company. The only multi-Company surfaces are lists of Companies themselves: the chooser and Administration > Companies (names and the person's role, no figures). Consolidation, when it comes, will be a new screen.

**Tenant-level facts shown in a Company view:** the verification banner and the Verification tab are about the Tenant (business check, the Owner Admin's identity and phone). They do not show Company data, but they appear while a Company is selected; it is correct, since verification is the Tenant's.

## 4. The support thread (CM's question for EA's isolation tests)

**Does WEB show or post to the Tenant support thread for non-owner staff anywhere? No.**
- The only tenant-side support surface is the **product-support ticket panel** (`ProductSupportPanel`, calls `/tenants/{t}/support/tickets...`). It is Owner-Admin only: a non-owner sees "only the Owner Admin can use product support" and no call is made. The unread count in the floating widget is also fetched only for the Owner Admin (`enabled: isOwnerAdmin`).
- WEB does **not** call `/tenants/{t}/support-thread/messages` (GET or POST) anywhere; the only references to a "support-thread" in WEB are the **operator** routes (`/operator/support-threads`, `/operator/tenants/{t}/support-thread/messages`), used by the operator console, not staff.
- **So making the tenant support-thread route Owner-only changes nothing in WEB, and staff would see exactly what they see today** (the Owner-only notice). WEB supports the proposed add-a-deny.
- Related and not the same route: announcements (`/tenants/{t}/messages/everyone`) are intentionally Tenant-wide (the Owner's broadcast to all staff); posting is Owner-only in WEB (`canBroadcast`).

## 5. What WEB will do (small, none changes a contract)

1. Key the support widget and the notices strip by (Tenant, Company) so a Company switch remounts them.
2. Send a person to onboarding only for EA's "no Membership yet" answer; for a 5xx or a network failure show a retry screen. (Prevents a transient failure creating a second Tenant.)
3. Remove the Tenant-level module-chat fallback once EA confirms.
4. A single plain 403 message across SOP, POP, IM and HR screens until T15 ships ("This company is not set up for this module yet. Ask support."), if CM wants it.
5. If a service settles on a Tenant header for T15: send it, after a real browser preflight against that service.

## 6. What WEB needs

- From the services, the T15 convention (derive the Tenant from the Company, or a header), stated before it ships so WEB declares it first.
- From EA: whether `EA_ONBOARDING_CLOSED` goes ahead, and the per-Company chat routes confirmed live (item 3).
- Lesson recorded 2026-10-09: any request header WEB sends must be checked with a real browser preflight against every service that receives it. A live sweep today found every current header and method accepted except two (both fixed), so the current state is clean.
