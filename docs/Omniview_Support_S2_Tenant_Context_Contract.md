# Omniview Support, Wave S2: tenant context contract (EA, WEB, Omniview)

**Status:** DRAFT 2, 2026-10-05. Draft 1 was the Omniview session's; Draft 2 folds in EA's reply (shape corrections, the answers to the three questions) and **Femi's decision, relayed by EA: the card is shown only after the tenant's Owner Admin approves it, and EA builds it after the Product Support release**. Backlog rows
S2.1 to S2.5 in `docs/Omniview_Support_Model_Backlog.md`; requirements FR-SUP-B1 to B4 and UC-SUP-2 in
`docs/Omniview_Support_Model_SRS.md` and `..._Use_Cases.md`. **Planning for EA and WEB; Omniview's own side
is being built against this draft with a fake EA.** Nothing here changes the Product Support v1 routes
EA's relay already calls except one **optional, additive** field on ticket create (section 2).

## 0. What this is for

An operator working a ticket needs to see **what kind of business this is**: which Companies, what
industry, which modules, who is the Owner Admin, whether verification is pending, how many staff and in
which roles. Today the operator sees a tenant's name and an opaque id. S2 gives them a **tenant card**
(read-only) and gives each new ticket **the context it was raised in**.

**No ledger data, ever, on this path** (FR-SUP-B4, SD1 default A). Nothing below returns a balance, a
journal, a customer or a supplier.

## 1. EA support-card route (S2.1)

**Approval gate (DECIDED by Femi, relayed by EA, 2026-10-05).** EA keeps an owner-controlled switch per tenant,
"Prodeo Support may see this business's setup", **off by default**, changed only by the tenant's Owner Admin and
recorded with who and when. While it is off the route answers `403 {"error":"support_access_not_approved"}` and
returns **no data**. Omniview treats that as a **normal state**: the card shows "the owner has not allowed support
to see this business's setup", and tickets work exactly as before. (Whether the approval is a standing, revocable
switch or per ticket is Femi's open choice with EA; the route and the code are the same either way.)

One new **read-only** route in EA. Omniview calls it **forwarding the signed-in operator's own
`X-Operator-Token`**, exactly as it already calls EA's `GET /api/operator/tenants`
(`EaOperatorProxy`); EA authorises it with its existing `authorizeOperator` and so also knows **which
named operator** asked. This needs the same operator name and token value in `EA_OPERATOR_TOKENS` and
`OMNIVIEW_OPERATOR_TOKENS`, which CM has arranged. A dedicated Cognito service identity for Omniview-to-EA
reads (backlog S2.4) is a later hardening, not a precondition.

```
GET /api/operator/tenants/{tenantId}/support-card
X-Operator-Token: <the operator's token>
```

**Success `200`:**

```json
{
  "tenantId": "uuid",
  "name": "Acme Ltd",
  "status": "ACTIVE",
  "segment": "EXTERNAL_B2B",
  "kybStatus": "PENDING",
  "kybVerificationDeadline": "2027-03-12T00:00:00Z",
  "adminPhoneVerificationStatus": "VERIFIED",
  "phoneVerificationDeadline": "2027-02-01T00:00:00Z",
  "baseCurrency": "SLE",
  "ownerAdmin": { "userId": "uuid", "name": "Amara Kamara" },
  "companies": [
    {
      "companyId": "uuid",
      "name": "Acme Trading",
      "industryType": "GENERIC",
      "modulesGranted": ["GL", "SOP", "POP", "IM"],
      "staffByRole": { "OWNER_ADMIN": 1, "ACCOUNTANT": 2, "SALES_OFFICER": 3 }
    }
  ]
}
```

Rules:

1. **Every field is EA's own data.** `modulesGranted` is the union of modules granted to any **active**
   Membership's assignment at that Company (EA's definition). It means "modules some active person holds at
   this Company", not a tenant-level "enabled modules" setting, so **Omniview labels it "modules in use"**; the
   wire name stays `modulesGranted`. `staffByRole` counts **active** assignments at that Company by role; the
   Owner Admin appears only under a Company they were assigned at. Omit a role with a zero count.
   `baseCurrency` is **per tenant** (set at onboarding), not per Company. The two deadlines are ISO-8601
   instants.
2. **Data minimisation (D17).** `ownerAdmin.name` is the display name only, nullable. **No email, no phone,
   no address, no identity documents.** Support talks to the Owner Admin in the app, so contact details are
   not needed; adding any is a decision for Femi and a solicitor.
3. **Optional fields are omitted, not null.** `kybVerificationDeadline` and `ownerAdmin.name` may be absent.
4. **Strict on fields, plain on enum values.** **Omniview decodes the response strictly** (the platform's
   rule: no `ignoreUnknownKeys`): an **unknown or missing field** makes the card **unavailable**, never silently
   incomplete, so a new field is a **lockstep change** EA announces first. The enum-like values (`status`, `segment`,
   `kybStatus`, `adminPhoneVerificationStatus`, `industryType`, each module and each role) are carried **as the strings
   EA sent** and only displayed, so a new enum value does not break the card. EA's current values: `status`
   DRAFT / ACTIVE / SUSPENDED / CLOSED; `kybStatus` and `adminPhoneVerificationStatus` PENDING / VERIFIED / FLAGGED;
   `segment` INTERNAL_VENTURE / EXTERNAL_B2B (EA will send the full list); `industryType` GENERIC / SCHOOL.
5. **Errors:** `401 unauthorized` (bad or missing operator token), `403` with
   `{"error":"support_access_not_approved"}` (the owner has not allowed it), `404` with
   `{"error":"tenant_not_found"}` for an unknown tenant, `503 not_configured` when no operator token is configured.
   Anything else Omniview treats as "EA unavailable". **In every case the card still renders its Omniview-side
   parts** (section 3), and nothing from EA's response body is ever echoed into an error code or a log line.
6. **Not in this route, deliberately:** per-Company currency and **jurisdiction** (they belong to GL's `Company`;
   EA holds no jurisdiction; a GL read is a later row, S2.6), plan and subscription (no subscription system exists), onboarding
   progress (S5), any staff names or counts by person.
7. **Limits:** at most 50 Companies per card; `companies` is ordered by name. A response over 256 KiB is a
   defect, not a case to page.
8. **Cost:** assembled on demand, no per-request fan-out beyond EA's own repositories; Omniview calls it with a
   3-second budget and no retry, and shows the card without it when it is slow.

## 2. Ticket creation context (S2.2): one optional, additive field

`POST /internal/tickets` (EA's relay to Omniview) gains **one optional object**. Existing callers that do
not send it keep working unchanged.

```json
{
  "tenantId": "uuid", "tenantName": "Acme Ltd", "userId": "uuid", "companyId": "uuid", "body": "...",
  "context": {
    "screen": "journal-entry",
    "module": "GL",
    "appVersion": "2026.10.05-1a2b3c4",
    "industryType": "GENERIC"
  }
}
```

| Field | Rule |
|---|---|
| `context` | Optional object. If present, every field inside it is optional. **Unknown keys are refused (400 `validation_failed`)** as everywhere else |
| `screen` | At most 80 characters, `[a-z0-9._/-]`, a stable screen key from WEB, **never a URL, a title or user text** |
| `module` | One of EA's `ManagedModule` names (`GL`, `HR`, `SOP`, `POP`, `IM`, `TAX`, `EDUCATION_RUNTIME`); an unknown value is a 400, so a new module is a lockstep change |
| `appVersion` | At most 40 characters, `[A-Za-z0-9._+-]`; WEB's build id |
| `industryType` | One of EA's `IndustryType` names; the Company's industry **at the time of the call** (it is immutable, so this is a convenience, not a copy that can drift) |

**The approval switch does not gate the ticket context.** It is part of a ticket the owner chose to raise, so it
travels with the ticket; it carries no business data beyond the screen, the module, the build and the industry.
(EA agreed this reading; Femi may overrule it.)

**Where each value comes from:** `screen`, `module` and `appVersion` come from WEB (new optional fields
on the widget's create call to EA); `industryType` EA reads from the Company the ticket is raised for;
`companyId` is already sent today. **Omniview stores them with the ticket and shows them to operators only;
they are never returned through the relay** (the tenant-facing shapes in SRS 13.2 are unchanged).

**Rollout order (this is what keeps strict decoding from breaking anyone):**

1. **Omniview first**: it accepts the optional `context` and has the card, gateway and console ready (built, awaiting CM). Old EA keeps working.
2. **EA**, **after its Product Support release**, builds the approval switch, the support-card route and the context pass-through.
   Until then the card honestly says "unavailable" and tickets are unaffected.
3. **WEB** starts sending `screen`, `module` and `appVersion`, and shows the Owner Admin the approval switch (EA serves it).

Nothing is required of a later step before an earlier one ships.

## 3. What Omniview adds on its own side (no peer work)

The card also shows what Omniview already holds about the tenant: how many tickets it has open, how many
it has raised in total, when it last raised one, and its recent tickets (subject and status). It adds
**nothing** from EA that is not in section 1. Opening the card is logged against the operator
(`TENANT_CARD_VIEW`, FR-SUP-F4).

## 4. What each session does

| Session | Work | Order |
|---|---|---|
| **Omniview** | Accept the optional `context` and store it; the EA gateway (strict, read-only, forwards the operator's token); the card route and console panel; tests against a fake EA. Branch stacked on the S1 branch | now |
| **EA** | The route in section 1 (one repository-backed read), a test for the unknown-tenant 404 and for the operator gate; in a second step, send `industryType` (and pass WEB's fields) on ticket create | route first, create-context second |
| **WEB** | Send `screen`, `module`, `appVersion` on ticket create; a stable screen key per screen (a small table, owned by WEB) | last |
| **CM** | Nothing new: the operator tokens are already the same value in both secrets. Review as usual | |

## 5. Questions (answered in Draft 2, kept for the record)

1. **Owner Admin name:** EA holds `User.name`; `{userId, name}` is fine; email and phone stay out. **Answered.**
2. **`modulesGranted`:** the union over active memberships' assignments is EA's real data; Omniview labels it "modules in use". **Answered.**
3. **Jurisdiction and currency:** EA holds `Tenant.baseCurrency` (per tenant) and no jurisdiction; per-Company currency and jurisdiction are GL's. **Answered; added `baseCurrency`, kept S2.6 for GL.**

**Still open, EA with Femi:** whether the owner's approval is a standing, revocable switch (EA's recommendation) or per ticket.
