# Omniview Support, Wave S5: onboarding, health signals and outreach

**Status:** DRAFT 1, 2026-10-05, written by the Omniview session for EA, GL, CM and Femi. Backlog rows S5.1 to S5.5 in
`docs/Omniview_Support_Model_Backlog.md`; requirements FR-SUP-E1 to E4, UC-SUP-7 and UC-SUP-8.
**Built and tested on Omniview's side** (fish-er-omniview branch `feat/omniview-support-s5`, migrations V10 and V11, awaiting CM).
It needs **no new route from anyone** to work: it reads a route EA already serves. What it cannot do yet, and exactly what
would unblock each part, is in section 4. **Nothing here changes a route EA or GL already serves.**

## 0. What it is for

A business that never finishes setting up never becomes a customer, and a missed verification deadline becomes a support
problem later. S5 shows the support team **which businesses need a nudge**, why, and for how long, and lets an operator send
a short reminder to that one business. It also gives operators a fixed checklist for the longest piece of support work, moving a
business onto FiSH.

## 1. What is built

### 1.1 Health worklist (S5.1, S5.2)

The console's **Worklist** tab. When it is opened (or refreshed) Omniview makes **one read-only call** to EA's existing
platform-operator list, `GET /api/operator/tenants`, forwarding the signed-in operator's own `X-Operator-Token`; it is the same list
the Tenants tab already shows, so it exposes **nothing new**, and it is **not** behind the Owner Admin approval switch (that
switch gates the richer support card, which is a different route). It works out five signals:

| Signal | Raised when | Counts once seen for |
| --- | --- | --- |
| `VERIFICATION_FLAGGED` | the business's verification is flagged | at once |
| `VERIFICATION_OVERDUE` | verification pending and its deadline has passed | at once |
| `VERIFICATION_DUE_SOON` | verification pending and the deadline is within 14 days | at once |
| `ONBOARDING_NO_COMPANY` | a draft business with no company | 3 days |
| `PHONE_NOT_VERIFIED` | the owner's phone verification is pending | 7 days |

A suspended or closed business raises nothing. **Time is counted from when Omniview first saw the signal**, because EA's list
carries no set-up date; it is stored as an *episode* per tenant and signal (a tenant id and name, the signal, first and last seen,
cleared at; no business data). An episode closes when the signal clears, and a later return starts a fresh clock. The list is
sorted most urgent first, then longest seen.

**Onboarding progress** per business states what EA can answer (company added, business verified, phone verified, someone besides
the owner has access, business active). The three ledger steps (chart of accounts, first posting, period opened) are shown as
**unknown**, never guessed.

**Strict reading.** Omniview decodes EA's list strictly (the platform rule: no `ignoreUnknownKeys`). An unknown or missing
field makes the worklist unavailable with the fixed code `ea_response_shape_changed`, never silently incomplete. **A new field on EA's
`OperatorTenantOverviewDto` is therefore a lockstep change** EA announces first, exactly as for the support card. If EA cannot be
read the worklist answers `503 ea_unavailable` with a fixed code, **and changes and clears nothing**.

**No background refresh.** The worklist is worked out only when an operator opens it. A scheduled job would need its own
credential for EA (backlog S2.4, a dedicated service identity, not built); until then there is no automatic escalation, and
the "escalates to Femi at the deadline" step of UC-SUP-7 is **not built** (section 4).

### 1.2 Outreach by notice (S5.3, SD9)

An operator can write a reminder for a signal on a business. It goes out as **a notice addressed to that one tenant**, which FiSH
already pulls (`GET /internal/tenants/{id}/notices`, built in S4); it is never published openly. Omniview **sends no email and
opens no thread**. The rule (SD9, accepted at its default):

- only for these signals, all tied to the business's own set-up or deadlines; **no marketing**;
- **at most two reminders per episode, at least three days apart**: there is no third contact;
- the text is plain and about the business's own account, **with no business name and no figures**; the operator sees the
  draft first and may edit it (control characters and length are still checked);
- each send is in the operator access log and recorded against the episode;
- **when the signal clears, the reminders sent for it are withdrawn**, so a verified business stops seeing "your verification
  is due".

**Not built: operator-initiated threads.** SD9 allows them, but a thread opened by support needs a ticket with no tenant author,
which changes what the relay and the widget show. Notices cover UC-SUP-7's alternate 2a (notice only). A thread is a separate
decision (section 5).

Routes (operator token): `GET /operator/worklist`; `GET /operator/worklist/{tenantId}/{signal}/draft`;
`POST /operator/worklist/{tenantId}/{signal}/outreach` with `{ "body": "optional edited text" }`. Errors: `signal_not_present`,
`not_stuck_yet`, `outreach_too_soon`, `outreach_limit_reached`, `tenant_not_found`, `ea_unavailable`.

### 1.3 Migration case template (S5.5)

A fixed checklist an operator attaches to a ticket (**Case** tab): anchor date, modules, chart of accounts, the receivables and
payables are itemised and never one control-account total, unclassified balances go to the Suspense account to be itemised
later, figures loaded, the accountant confirms the opening trial balance reconciles, the owner confirms. Attached once; each step
records who ticked it and when; every change is in the ticket's history and the access log. Operator-only: nothing reaches a tenant.
It is not yet linked to the CSV opening-figures upload, which is design-only.

## 2. What EA needs to know

1. **Nothing to build.** The worklist reads `GET /api/operator/tenants` exactly as it is today.
2. **That DTO is now a contract, and EA has agreed.** EA will not add, remove or rename a field on `OperatorTenantOverviewDto`
   (today: tenantId, name, status, segment, kybStatus, kybVerificationDeadline?, adminPhoneVerificationStatus, companyCount, staffCount,
   supportMessageCount, awaitingSupportReply) without messaging Omniview first.
3. **`createdAt` is not available.** EA stores no tenant creation time (no column), so adding one is a migration, and older tenants would
   have no real value (a backfill would be a guess, so it would be nullable). EA will raise it with Femi rather than do it unasked.
   Until then Omniview's "first seen" clock is the honest basis, and the console labels it that way.
4. **The list is not paged** and EA does not plan to page it. Omniview's 1,000-tenant cap, refusing above it with `ea_too_many_tenants`,
   is the right guard.

## 3. What GL can and cannot back (a proposal, corrected by GL's own reading of its schema and code)

Nothing here is a request to start. Three of the eight onboarding steps and some signals need facts only the ledger holds.
**GL read its schema (V1 to V29) and code for this draft; its answer, and what that does to the proposal:**

| Fact | What GL can honestly give |
| --- | --- |
| Chart of accounts set up | **Yes.** A boolean from the count of the Company's accounts |
| A period left open | **Yes.** The oldest open period's end date, from each Company's periods |
| First and last posting | **Only approximately.** `journal_entries` keeps `entry_date`, a date the caller chooses and can backdate, and no posted-at time. "First/last posting" would mean the earliest and latest `entry_date` among posted, system and reversed entries; a backdated entry can hide "no posting after go-live". A true timestamp needs the audit trail's `occurred_at`, which exists only once Audit Trail Wave 2 (the write-path rollout) is built; today nothing writes to it |
| Failed postings | **Not available.** GL records nothing about rejected posts (a 4xx response only; no table). It would need new storage and a decision on what counts as a failure. **Dropped from S5 v1**, to be scoped as separate GL work if wanted |

So the shape worth designing is smaller than first drafted, and it is **not "an operator-token route"** (my first wording was wrong):
GL has no operator identity and does not verify EA's operator tokens. It would follow the pattern GL is already designing for the Market
aggregate: **a separate, named service-principal provider for Omniview**, a required non-null verifier, a 401 for human tokens, and never
the service-account bypass. That provider is shared with the Market route, so **the two must be designed together** (S9-era work for CM, GL
and Omniview).

```
GET <GL>/operator/tenants/{tenantId}/activity     (Omniview's service principal)
{ "companies": [ { "companyId": "uuid", "chartOfAccountsConfigured": true,
                   "earliestEntryDate": "2026-09-01", "latestEntryDate": "2026-10-04", "oldestOpenPeriodEnd": "2026-08-31" } ] }
```

Booleans and dates only: no amounts, no accounts, no counterparties. **Dates are entry dates, not posting times, and the doc says so wherever it shows them.**

**Consent.** GL cannot see EA's Owner Admin approval switch and **should not be where it is enforced**. If the approval must gate this,
either the route takes EA's consent as its source (as the Market route would), or Omniview and EA filter before calling. Not decided.

**Risk class.** GL's point, recorded: a per-Company "last posting date" is an activity fact about one named business. That is
a different class from the Market aggregate's cohort-protected figures, which are protected by design; a per-Company route has no cohort
protection and is identifying. Whether that is acceptable is Femi's decision (section 5, question 1), not GL's or mine.

## 4. Not built, and what blocks each

| Item | Blocked on |
| --- | --- |
| Ledger onboarding steps and the ledger signals (S5.1, S5.2) | A GL route behind Omniview's own service principal (designed with the Market route), a consent source, and Femi's answer on whether per-Company activity facts are acceptable (section 5). "Failed postings" is dropped from v1 |
| Escalation to Femi at a verification deadline (UC-SUP-7) | A background refresh, which needs the dedicated EA service credential (S2.4: CM and EA) |
| Month-end load forecast (S5.4) | The ledger's period and close dates: the same GL route (the oldest open period end) |
| Operator-initiated threads | A decision on whether support may open a ticket (section 5), and relay and widget work |
| Link from the migration case to the CSV upload | The opening-figures upload being built |

## 5. Decisions for Femi

1. **Is ledger activity "business data"?** SD1 (default A) says no business data on the support surface. The facts in section 3 are
   dates and booleans, no amounts or names, **but per-Company, so identifying** (GL's point). **Recommendation:** allow them, behind the same Owner Admin approval switch the
   card uses, so a business that has not allowed support to see its setup is not read at all. The open design question for EA and
   GL is where that approval is enforced: GL cannot see EA's switch, so either EA gates it or Omniview only calls GL after EA's card says approved.
2. **Operator-initiated threads.** Notice-only reminders work today and are the lower-risk shape. A thread lets the owner reply in
   place but needs relay and widget changes. **Recommendation:** stay with notices until owners are actually asking to reply to them.
3. **Lawful basis per jurisdiction** (SD9's open note). The reminders are about the business's own account and deadlines, not
   promotion. Before the first Irish or Nigerian customer, have the solicitor confirm that reading holds there.
