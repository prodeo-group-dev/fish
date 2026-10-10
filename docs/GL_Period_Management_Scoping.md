# GL Period management: scoping (month-end close, monthly Periods, legacy history)

**Status:** scoping only, 2026-10-10, GL session. Nothing in this document is built. Femi's decision (relayed by CM, 2026-10-10): **defer, nothing on Periods before the combined UAT sitting**; month-end close (open/close routes + WEB screen, auto-open of monthly Periods, legacy-history handling) is a planned design change to be scoped after the sitting. This is that scoping.

## 0. Correction to what GL said earlier

On 2026-10-10 GL reported a "Period wall": that a Company's single Period would stop accepting postings after one month. **That was wrong.** Read again from master (`6ea02f8`): no posting use case compares an entry's date with a Period's start and end date, and nothing ever closes a Period, so the opening Period stays OPEN indefinitely and takes postings of any date. Nothing breaks at the end of the first month. The change below is therefore a design improvement (real month-end close, per-month reports), not a fix for a blocked go-live. The Company `13de72e4` 409s that prompted the question are most likely a missing VAT control account (2150) in an older chart, not a Period issue (to be confirmed by a read of the response body).

## 1. What the code does today (verified on master `6ea02f8`)

- **Creation.** A Period is created in exactly one place: `AddCompanyToTenantUseCase`, once per Company, `PeriodType.MONTH`, from the requested opening start date to start + 1 month, opened immediately. No other use case or route creates a Period. There is no route with "periods" in its path.
- **Lifecycle.** `PeriodStatus`: DRAFT -> OPEN -> CLOSED -> (OPEN again | LOCKED). Only OPEN allows posting. `Period.close()`, `reopen()`, `lock()` exist and raise `PeriodClosed`/`PeriodLocked` events, but **`ClosePeriodUseCase` is not referenced by any route or caller.** It already refuses to close a Period that has non-final (unresolved) journal entries (`UnresolvedEntriesExist`), which is the "unposted drafts" rule in code.
- **Which Period a posting goes to.** The caller chooses. Every `Record*` use case, `PostJournalEntryUseCase`, `ReverseJournalEntryUseCase` and the fixed-asset, leave-accrual and FX use cases take a `periodId` in the request and check only that it belongs to the Company (`findOwnedBy`, T19) and `allowsPosting()`. The posting-context use cases (`ComputeSales/Purchase/Inventory/PayrollPostingContextUseCase`) and `CreateSalesInvoiceUseCase` hand callers `firstOrNull { it.allowsPosting() }`, "the" open Period, without regard to date.
- **No date check.** `JournalEntry.create(periodId, date, ...)` has no bounds check, and neither does any use case, except `RecordOpeningBalanceUseCase`, which looks for an OPEN Period whose dates contain the entry date (and answers `NoOpenPeriod` if none does).
- **Schema.** `periods(id, company_id, period_type, start_date, end_date, status)` with an index on `company_id`. **No unique key on (company_id, start_date)** and no overlap guard.

## 2. What is actually missing

1. **No month structure.** Each Company has one Period holding its whole history. "Per-month" reporting exists only through the date-range reports added in UAT v2.2 (`?from=&to=` on profit-and-loss and cash-flow).
2. **No close of books.** Nothing can close a month or year, so "no posting into a closed Period" is untested in real use and unreachable from the UI.
3. **Opening balances dated outside the first month fail.** `RecordOpeningBalanceUseCase` (and therefore the opening-import routes that call it) answers `NoOpenPeriod` for an anchor date outside the opening Period's one month. This is the one place a date/Period mismatch already bites.
4. **"Open Period" reports mean "lifetime".** P&L (no range), trading P&L, sales-to-expense ratio, money and expense velocity (days elapsed since `period.startDate`), and cash-flow (no range) all read "the open Period", which today is the Company's whole history.

## 3. The decision to implement (Femi, relayed 2026-10-10)

- GL opens the next **calendar-month** Period automatically on the first posting dated past the end of the Company's latest Period. Ledger Periods are calendar months for every Company; payroll cadence does not drive them.
- Preference is auto-open **with explicit close of books**; open/close routes and a WEB screen for accountants come later, but this build must make that later close work.
- Constraints given: a posting into an explicitly CLOSED Period stays refused (409, never auto-reopened); auto-open only extends forward, contiguous (fills missing months up to the posting date), capped, idempotent, race-safe under concurrent first postings (unique key company + start), and Company/Tenant scoped like everything else. Unposted-drafts rule: not for this build (but see 1: `ClosePeriodUseCase` already has one).

## 4. Proposed design

**4.1 One resolver.** A single application service, `PeriodForDate`, the only code that decides which Period an entry date belongs to: (a) find the Period of that Company containing the date; (b) if found and OPEN, use it; if found and not OPEN, `409 period_closed` (new distinct error; never reopen); (c) if none and the date is after the latest Period's end and within the caps, create the missing calendar months contiguously and use the right one; (d) if the date is before the earliest Period, refuse (`409 date_before_first_period`), never extend backwards (see 7, opening balances). Every posting use case calls it instead of trusting a caller-supplied `periodId` blindly, and a source-scan test (like `PeriodOwnershipGuardTest`) fails the build if a use case reads `allowsPosting()` on a Period it did not get from the resolver.

**4.2 Caps (GL proposes; Femi to confirm).** Forward: refuse a date more than 1 month after the server date (`date_too_far_ahead`), because future-dated entries are rare and a typo like 2062 must not create 430 Periods. Catch-up: create at most 24 missing months in one posting (a dormant Company posting again after a long gap); beyond that, refuse and ask for an explicit action. So **N = 1 month ahead, 24 months of catch-up.**

**4.3 Schema.** One Flyway migration: `UNIQUE (company_id, start_date)` on `periods`; optionally `EXCLUDE USING gist (company_id WITH =, daterange(start_date, end_date, '[]') WITH &&)` for overlap (needs `btree_gist`; decide with CM whether the extension is acceptable on RDS). Creation is `INSERT ... ON CONFLICT DO NOTHING` followed by a re-read, so two concurrent first postings produce one Period and both use it. A per-Company advisory lock during the catch-up fill avoids two sessions interleaving different months.

**4.4 Wire contract (consumers-first).** Today SOP/POP/IM/HR read `periodId` from the posting-context and send it back. Proposal: make `periodId` **optional** in every posting request body (additive); when absent GL resolves by `date`; when present GL still checks it contains the date (`409 date_outside_period` if not). Posting-context responses keep returning `periodId` (the Period of today's date, or the latest), so no consumer breaks. Services can drop `periodId` later, in their own time. No consumer needs to change on day one.

**4.5 Reads.** The "open Period" reports resolve against the **Period of the current date, else the latest Period**, instead of `409 no_open_period` when none is OPEN (CM's request). Response field shapes do not change (EA decodes P&L and balance-sheet strictly), but their **meaning changes** from "since inception" to "this month", which affects money velocity (days elapsed since period start), expense velocity, the sales-to-expense ratio and the dashboard ratios. WEB and EA must agree the labels before release.

**4.6 Close of books (the later build, designed for now).** Routes `POST /companies/{id}/periods/{periodId}/close|reopen|lock`, `GET /companies/{id}/periods`; `ClosePeriodUseCase` reused as is (including its unresolved-entries refusal); a WEB screen; EA gets `PeriodClosed` if it wants it. Who may close/reopen is an authorization decision, not an add-a-deny, so it needs the RBAC SPUTO's answer (suggest Owner-Admin/ADMIN to close, Owner-Admin only to reopen) and lands after the RBAC freeze lifts. Year-end (rolling P&L into retained earnings) is separate: retained earnings is computed on the fly today, so it needs no posting to start with.

## 5. Legacy history: three options

Existing Companies have one Period holding all entries, with dates unrelated to its bounds, so "date must lie in a Period" cannot simply be switched on.

| Option | What | Cost | Verdict |
|---|---|---|---|
| **L1** Cutover | Leave the old Period as a "legacy" Period accepting dates up to a cutover month; apply monthly Periods from the cutover. Needs the legacy bounds stretched to cover its entries, and the current month's entries moved into a new monthly Period. | About 1 d plus a one-off script per Company; two behaviours forever. | Fallback only. |
| **L2** Re-slice | One Flyway migration: for every Company, create calendar-month Periods covering its entries' date range and move each entry to the Period containing its date; set the first Period to start at the month start and mark all but the current month OPEN or CLOSED per policy. | About 1.5 d, plus a dry run and a before/after trial-balance check per Company (totals by account must be unchanged). | **Recommended, and cheapest now:** production data is still development/test data until the live switch, so there is no real history to protect. It gets harder after go-live. |
| **L3** New Companies only | Monthly rule only for Companies created after the cutover. | 0.5 d | Rejected: two ledger behaviours, and existing test Companies stay different from new ones. |

Verification before any L2 run (read-only SQL, to be run by Femi or CM through the existing script route, not by GL):

```sql
-- how many Periods per Company, their span and statuses
select company_id, count(*) periods, min(start_date) first_start, max(end_date) last_end,
       count(*) filter (where status <> 'OPEN') not_open
from periods group by company_id;

-- entries whose date lies outside their own Period's bounds, per Company
select p.company_id, count(*) entries_outside_period
from journal_entries e join periods p on p.id = e.period_id
where e.entry_date < p.start_date or e.entry_date > p.end_date
group by p.company_id;
```

## 6. Impacts

- **GL:** about 20 use cases switch to the resolver (the `Record*` family, `PostJournalEntry`, `ReverseJournalEntry`, fixed-asset, leave-accrual, FX, `CreateSalesInvoice`, the four posting contexts, opening balance); about 9 reads switch to current-or-latest Period.
- **SOP, POP, IM, HR:** none on day one (4.4); later they may stop sending `periodId`.
- **EA:** the dashboard reads P&L, balance-sheet, cash-flow, working-capital and trading P&L strictly; shapes unchanged, meanings shift to "this month" for the period-based ones.
- **WEB:** report labels ("since the start" vs "this month"), later the Periods screen and a close action.
- **Tenancy:** all new reads/writes use `findOwnedBy` and the resolver takes the Company from the authorized request; isolation matrix routes added for the new endpoints.

## 7. Related gaps found on the way

- **Opening balances before the first Period** (section 2, item 3): an anchor date earlier than the opening Period start is refused today. If the resolver never extends backwards, the opening import needs an explicit "create the opening Period at the anchor date" step. Decide with the opening-figures design (`docs/Opening_Figures_CSV_Upload_DDD_Design.md`).
- **Older Companies missing accounts that newer chart templates have** (likely `13de72e4` and VAT control 2150): sales-posting-context answers 409 `vat_control_account_not_configured`. A small, separate "add missing template accounts to an existing Company" use case would close this class (about 1 d). Not part of Periods; listed so it does not get lost.

## 8. Tests that must exist

Closed Period stays closed (409, no auto-reopen, nothing posted); contiguous catch-up fills every month; forward cap and catch-up cap both refuse; two concurrent first postings create one Period (real database, two threads); the resolver cannot be bypassed (source scan); cross-Company and cross-Tenant isolation on every new route; legacy migration leaves every Company's trial balance unchanged to the cent; reads fall back to the latest Period when none is OPEN; entry dated before the first Period is refused.

## 9. Sizes (GL, own estimates)

| Piece | Days |
|---|---|
| Resolver, schema, caps, wire into the posting use cases, concurrency and isolation tests | 4 to 5 |
| Reads move to current-or-latest Period, plus tests | 1 |
| L2 legacy re-slice migration with per-Company before/after checks | 1.5 |
| Close/reopen/lock/list routes, RBAC wiring, tests (after the RBAC freeze lifts) | 2 |
| **Total GL** | **about 8.5 to 9.5** |
| WEB (labels, Periods screen, close action), EA label check | not GL; WEB to size |

The first three rows are the build Femi described (auto-open) and are roughly 6.5 to 7.5 days; the close routes come later.

## 10. Questions for Femi

1. Caps: forward 1 month, catch-up 24 months: confirm or change.
2. Legacy: L2 (re-slice everything now, before go-live): confirm. This is cheapest while the data is test data.
3. Is `btree_gist` acceptable on the shared RDS (CM)? If not, uniqueness plus an application overlap check is enough.
4. Who may close and reopen a month (RBAC SPUTO), and may a reopened month be locked later?
5. Should the reports' default become "this month", or stay "since the start" with an explicit month picker? (This is the WEB/EA decision behind 4.5.)
