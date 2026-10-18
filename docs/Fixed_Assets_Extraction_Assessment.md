# Fixed Assets extraction assessment (docs only, Femi decides before any build)

GL session, 2026-10-18. Shape follows `docs/Ecosystem_Extraction_DDD_Design.md`. **Nothing built, nothing moved.** Trigger (Femi, via CM): "each subledger owns its own records, GL only aggregates (control accounts)". For fixed assets that means the asset register (assets, categories, depreciation schedules and runs, impairment, disposal, the Owner approval flow FS-7 and evidence, register-to-ledger reconciliation) lives in its own bounded context and service, like POP, SOP, IM and HR. GL keeps the control accounts (1200 cost, 1210 accumulated depreciation, 5500 depreciation expense, gain/loss on disposal) and receives journals. Companion note: `docs/GL_Per_Line_Account_Routing_Audit_And_Design.md` (the same "account chosen by type, Suspense when none" principle).

## Decided (Femi, 2026-10-18, relayed by CM)

- **D1: Option C.** Extract Fixed Assets to its own service now (FA / `fish-fixed-assets` / `fa-api` / `FIXED_ASSETS` module), not the two-move Option B. The plan below (section 6) is for Option C. No build until CM has this plan and confirms the repo and infrastructure claim in `Infrastructure/COORDINATION.md`.
- **D2:** the Owner approval flow (request; Owner Admin approves; may self-approve, flagged; evidence on acquisition) is built in Fixed Assets itself, not first in GL. GL only receives the approved journal.
- **D3:** an asset with no cost account goes to Suspense 3910 and is marked `UNCLASSIFIED`; it cannot be depreciated or impaired until an account is chosen.
- **D4:** categories are configurable per Company with the four defaults; land is not depreciated; no land revaluation.
- **D5:** the ledger refuses every other writer, including manual journals, on the **Fixed Asset accounts only**. Femi: "Fixed Assets ONLY. And not Current Assets. Nor Investments (when they are separated as a category)." Current Assets "are the results of the interaction between POP, IM and SOP" (Inventory, Accounts Receivable, Cash, prepayments and so on) and stay open to their own services and to manual journals as today. The lock is keyed to an explicit account tag, not a number range or a broad "assets" class (section 11).

Wording note: wherever this note says "the FA accounts" it means the explicitly tagged Fixed Asset accounts (cost, accumulated depreciation, accumulated impairment of property, plant and equipment), never "asset accounts" in general.

## 0. What is in GL today (read from master, not assumed)

| Layer | Content | Size |
|---|---|---|
| Domain `domain/fixedassets/` | `FixedAsset` aggregate (cost, acquisition date, useful life, accumulated depreciation and impairment, disposed flag, identifier; `recordDepreciation`, `dispose`, impairment; each builds its own journal lines), `AssetCategory` enum (LAND, BUILDINGS, EQUIPMENT, VEHICLES), `FixedAssetRegister`, ids, repository interface | about 410 lines |
| Use cases | `CreateFixedAsset`, `RecordFixedAssetDepreciation`, `AssessFixedAssetImpairment`, `DisposeFixedAsset`, `ComputeFixedAssetRegister`, `ImportFixedAssets` (opening CSV) | about 720 lines |
| Persistence | `fixed_assets` table (V20; V24 added `identifier`), Exposed table and repository | about 100 lines |
| HTTP | `GET /companies/{id}/fixed-assets`, `GET /companies/{id}/reports/fixed-asset-register`, `POST /fixed-assets`, `.../record-depreciation`, `.../assess-impairment`, `.../dispose`, `POST /companies/{id}/opening-imports/fixed-assets[/validate]` | about 415 lines routes |
| Tests | `FixedAssetTest`, five use-case tests, `FixedAssetRoutesTest`, the import test | |
| Ledger coupling | Funding on create is Cash, On account (AP) or **Already owned (credits Suspense 3910)**; `ModuleOwnedAccounts` already treats 1200 and 1210 as module-owned (no cash-book posting) | |
| Consumers | WEB (`api/fixedAssets.ts`, `financeNav.ts`); no other service calls the FA routes (grep of EA, HR, POP, SOP, IM: none). EA's `ManagedModule` has **no FIXED_ASSETS value**: access is today "WRITE at the Company". | |

Not built in GL (per `docs/reports/Playbooks/GL/Fixed_Assets_Security_Playbook.md` and the register-link SPUTO): the Owner Admin approval step (D-FA-A, F, G), acquisition evidence, actor on each action, a once-per-period depreciation guard, the manual-journal block on 1200, and the register-to-ledger link (the `fixed_assets` table stores neither the asset account nor the acquisition journal id; the register cannot be tied to the ledger today).

**Finding that favours extracting now:** the approval flow and the register link are both unbuilt. Building them in GL first and moving them later means building them twice.

## 1. What moves, what stays

**Moves to Fixed Assets (FA):** the `FixedAsset` aggregate and its state machine, categories (made configurable per Company, section 3), depreciation scheduling and runs, impairment assessment, disposal, the approval flow (FS-7, D-FA-A/F/G) and acquisition evidence, the asset register and its reports, the opening-figures fixed-asset import (the GL-balance import keeps redirecting generic 1200 balances to Suspense), the register-to-ledger reconciliation.

**Stays in GL:** the Chart of Accounts and the control accounts (1200, 1210, 5500, impairment and gain/loss accounts), the Periods and the open-period check, journal posting, the trial balance and statements (the balance sheet reads 1200/1210 as it does today), and the rule that no other writer may post to the tagged Fixed Asset accounts (section 11).

**Becomes a thin posting interface in GL** (the established pattern: `record-obligation`, `record-sale`): FA computes the amounts and the accounts, GL validates and posts. The journal-building logic now inside `FixedAsset` moves with FA; GL gets small, account-validating endpoints.

## 2. The API between them

### 2.1 FA to GL (service account, bypasses the EA membership check by design, like POP/SOP/IM/HR)

New GL thin interfaces, all idempotent on an `Idempotency-Key` (the asset or run id), all returning the journal entry id:

| GL endpoint | Posting |
|---|---|
| `POST /fixed-assets/record-acquisition` | Dr the asset's cost account (or Suspense), Cr Cash/bank, AP (tagged to the supplier) or Suspense, per funding method |
| `POST /fixed-assets/record-depreciation` | Dr depreciation expense, Cr accumulated depreciation |
| `POST /fixed-assets/record-impairment` | Dr impairment expense, Cr accumulated impairment |
| `POST /fixed-assets/record-disposal` | Dr cash/bank (proceeds), Dr accumulated depreciation and impairment, Cr asset cost, gain or loss to the gain/loss account |
| `GET /companies/{id}/fixed-assets/posting-context` | open period, Suspense id, the Company's FA control accounts by role (for the category picker's defaults), currency |

These are the existing journal shapes lifted out of `FixedAsset`/the use cases, so behaviour is unchanged. Rationale for dedicated interfaces rather than the generic journal route: GL can then refuse any other writer on the tagged Fixed Asset accounts (D5, section 11) and validate account roles in one place.

### 2.2 GL to FA

None for posting. FA reads GL for reconciliation (section 5): the control-account balances (the existing trial balance with `?asOf`), and FA calls GL's account list (the `?usableFor` filter from the companion note) to validate the accounts an owner picks.

### 2.3 WEB and EA

WEB's FA screens call FA, not GL. EA gains a `FIXED_ASSETS` managed module, **declared withheld first** and decoded by every consumer before any grant (the PAYROLL precedent: `module_not_yet_available`, a deliberate enabling release). Approval authority comes from EA membership (Owner Admin), checked by an `FaMembershipAuthorizer` like POP's.

### 2.4 Create is no longer "post, then save"

Today GL posts the acquisition and saves the asset only if posting succeeds. In FA the order inverts, safely: FA saves the asset as `PENDING_APPROVAL` (or `PENDING_POSTING` after approval), calls GL with the asset id as the idempotency key, and stores the returned `acquisitionJournalEntryId` and `fixedAssetAccountId` on the asset. A GL failure leaves a retryable pending asset, never an unposted "active" one. This also delivers the register-to-ledger link that GL's register-link SPUTO needs, with no GL migration.

## 3. Per-asset account (the P0 principle applied to fixed assets)

- **Today:** the caller of `POST /fixed-assets` chooses `fixedAssetAccountId` and the depreciation/accumulated accounts per request; the template seeds one cost account (1200) and one accumulated depreciation (1210) and one depreciation expense (5500) per Company, regardless of category. GL validates only the Company. So the register can mix accounts silently (the cause of the 2026-10-08 UAT mismatch).
- **Rule in FA:** each Company defines **asset categories** (Land, Buildings, Equipment, Vehicles by default; the owner may add, e.g. Computer equipment). A category maps to: cost account (ASSET), accumulated depreciation (ASSET contra), depreciation expense (EXPENSE), impairment expense and accumulated impairment, and gain/loss on disposal. Each is chosen from the Company's own chart, validated through GL's account list, defaulting to the standard codes where they exist.
- The asset takes a **frozen copy** of its category's accounts at creation (as a sale line freezes its VAT category), so a later category change never moves an old asset's postings.
- **No account set: the cost goes to Suspense 3910** (Femi). Decided (D3): an asset whose cost account is Suspense is `UNCLASSIFIED` and **cannot be depreciated or impaired** until classified, because there is no sensible accumulated-depreciation pairing for a Suspense cost. Classifying it means picking the category, which posts the accountant's reclassification (Dr cost account, Cr Suspense) through the same acquisition interface.

## 4. Data migration

`fixed_assets` (id, company_id, name, category, cost_amount, currency, acquisition_date, useful_life_years, accumulated_depreciation_amount, accumulated_impairment_amount, is_disposed, identifier) moves to a new FA database. Production data is legacy test data (Femi), so cost and risk are low; the order is still copy, verify, cut over:
1. FA creates its schema and imports GL's rows (one-off, reported, idempotent by asset id).
2. Backfill the link (`fixed_asset_account_id`, `acquisition_journal_entry_id`) with the register-link SPUTO's rule: exactly one matching posted entry on the acquisition date, else leave `UNLINKED` and list them. The Car (known unposted asset) is repaired by the Suspense route in that SPUTO.
3. Row counts and cost totals per Company compared with GL's before and after; difference must be nil.
4. GL's `fixed_assets` table is left in place read-only until the cut-over is verified, then dropped in a later migration (never in the same release).

## 5. Reconciliation (register total equals GL control accounts)

Owned by FA, since it owns the register. For each Company and a date: register cost by cost account, accumulated depreciation and impairment by account, against GL's balances for the same accounts (trial balance `?asOf`). Per-asset status `LINKED` / `UNLINKED` / `ENTRY_REVERSED` / `AMOUNT_DIFFERS`, a total difference, shown on the register and available to EA's dashboard. A difference is a reported fact, never auto-corrected. Prevention: GL refuses any non-FA writer on the tagged Fixed Asset accounts (D5, section 11).

## 6. Cut-over order (Option C: extract straight to a service)

Femi's "Option C" is section 8's Option A below: no two-move carve-out first. Each step is its own branch and tip handed to CM; nothing is built until CM confirms the repo and infrastructure claim (`Infrastructure/COORDINATION.md`).

| # | Step | Owner | Needs |
|---|---|---|---|
| 0 | Plan accepted; CM claims the repo and infrastructure (GitHub repo `fish-fixed-assets`, ECR, ECS service, ALB rule, ACM host `fa-api`, database `fa_production` and role on the shared RDS, Cognito service-account client FA to GL, Jenkins job, Terraform `fa.tf`) | CM | this note |
| 1 | **GL, additive:** the explicit Fixed Asset account tag (section 11) with its migration and backfill; the five thin interfaces (acquisition, depreciation, impairment, disposal, posting-context) with contract fixtures; the lock built but **off** behind a flag (`GL_ENFORCE_FA_LOCK`, default off, the `HR_ENFORCE_PAY_SPLIT` precedent) | GL | step 0 |
| 2 | **EA:** declare `FIXED_ASSETS` in `ManagedModule`, withheld from every grant; GL, POP, SOP, IM, HR and WEB decode it (consumer-first, strict decoding) | EA, all | step 0 |
| 3 | **FA service built:** scaffold; the domain ported from GL test-first (aggregate, categories, the `UNCLASSIFIED` rule, depreciation); the Owner approval flow (request, approve, self-approve flagged, evidence); the GL gateway through a service account; `FaMembershipAuthorizer`; reconciliation; the disposal gain/loss rule (separate gain and loss accounts, Suspense when none) built in from the start | FA (GL session helps) | steps 1, 2 |
| 4 | **Deploy FA with no consumers** (module still withheld) | CM | step 3, infrastructure apply |
| 5 | **Migrate the register** (section 4): FA imports GL's rows through GL's existing `GET /companies/{id}/fixed-assets` with the service account; backfill the register-to-ledger link; totals compared per Company before and after | FA, GL | step 4 |
| 6 | **WEB switches** its fixed-asset screens to FA (account pickers keep using GL's account list); the approval screens are new | WEB | step 5 |
| 7 | **Enable the module** for Companies (EA releases `FIXED_ASSETS`); GL's FA routes stay as deprecated pass-through for one release | EA, CM | step 6 |
| 8 | **Turn the lock on** (`GL_ENFORCE_FA_LOCK`), then **remove GL's FA code and routes** once no caller remains; GL's `fixed_assets` table is dropped in a later migration, never in the same release | GL, CM | step 7 |

Interim: GL's disposal posting is wrong today (a loss lands as negative Sales Revenue; see the disposal note to CM), and is fixed in GL now by a small change, so the ported rule in step 3 is the corrected one.

## 7. Cost and estimate (rough, for planning only)

The GL code to port is about 1,700 lines plus tests; the shape is the same as HR's and POP's extractions. Rough elapsed effort: GL thin interfaces and fixtures 2 days; FA service skeleton and port 4 days; approval flow FS-7 and evidence 3 to 4 days; migration and reconciliation 2 days; WEB cut-over 2 to 3 days (WEB session); infrastructure and CI 2 days (CM). About three weeks of calendar time across sessions, mostly sequential at steps 3, 5 and 7.

**Ongoing cost of one more service:** one more ECS service, ALB rule and ACM host, a database and role on the shared RDS (the manual five-step creation), an ECR repo, a Jenkins job, Terraform (`fa.tf`, `fa_service_account.tf`), a Cognito service-account client for FA to GL, logs and alarms, one more strict `/me` DTO to keep in step with EA. That is the cost list the Payroll scoping request asked for; it is a real, recurring cost for a module with five routes.

## 8. Options (resolved by Femi)

- **A. Extract straight to a service** (sections 1 to 6). **Chosen by Femi, 2026-10-18** (his label for it was "Option C").
- B. Two moves, like Payroll: carve inside GL first, service later. Not chosen.
- C. Keep FA in GL. Not chosen.

## 9. Name, repo, service proposal

- **Name:** Fixed Assets, short form **FA** (the test plans already use `FA-`).
- **Repo:** `fish-fixed-assets`, folder `FA`, package `com.theprodeogroup.fa`, host `fa-api.theprodeogroup.com`, database `fa_production`, EA module `FIXED_ASSETS`.
- **Not Payroll or HR:** payroll's own split is under way and independent.

## 10. Decisions (all taken 2026-10-18)

D1 to D5 are recorded at the top of this note. Nothing in this note is open for Femi except the two points flagged in section 11 (P&L accounts and the Investments tag).

## 11. The ledger lock (D5): keyed to an explicit account tag

**Rule (Femi):** the ledger refuses every other writer, including manual journals, on the Fixed Asset accounts only. Not Current Assets; not Investments, even when Investments become their own category.

**Mechanism:**
- **An explicit tag on the account, not a code or a class.** New nullable field on the account, `fixedAssetRole`, with values `COST`, `ACCUMULATED_DEPRECIATION`, `ACCUMULATED_IMPAIRMENT`. Stored in the chart; nothing is inferred from a code range, from the `ASSET` type or from `NON_CURRENT`. (The `NON_CURRENT` classification is deliberately not used: Investments are non-current assets too, and the Individual chart's 1100 "Investments" is exactly such an account.)
- **Backfill (Flyway, per Company):** tag the Company's existing 1200 (cost), 1210 (accumulated depreciation) and the accumulated impairment account the Company uses, matched by the standard codes **and** the `ASSET` type, only where the Company is a business chart. Anything unmatched stays untagged (and therefore open); the owner can tag further accounts through FA's category setup, which is where new Fixed Asset accounts are created from now on.
- **Enforcement:** in the posting path every writer shares (the generic journal use case, the thin interfaces, record-obligation line resolution, the cash book): a line on a tagged account is refused unless the entry's source is the Fixed Assets service (a service-account call to the five thin interfaces, source `INTEGRATION` from the FA principal). Refusal code `account_owned_by_fixed_assets`, 409, detail the account id. Reversals of an FA entry go through FA.
- **Flag:** `GL_ENFORCE_FA_LOCK` default off; turned on at step 8 of the order, after WEB and FA are live, so nothing breaks mid-migration.
- **Picker rules stay consistent:** the purchase-line and sale-line account lists already exclude 1200 and 1210 by code as module-owned; once the tag exists those exclusions are keyed to the tag as well, and nothing broader.

**Tests that must exist (Femi's condition):**
1. A manual journal to a tagged Fixed Asset account is refused when the flag is on; the same journal is accepted when the flag is off.
2. A **Current Asset** account (Inventory 1300, Accounts Receivable 1100, Cash 1000, a prepayment account) stays writable by manual journals and by its own services with the flag on.
3. An **Investment** account (a non-current `ASSET`, for example the Individual chart's 1100 Investments, or a business Company's own "Investments" account) stays writable with the flag on.
4. An untagged account with a code of 1200 stays writable (the lock follows the tag, not the code).
5. The FA service's own posting to a tagged account is accepted with the flag on; another service's posting is refused.
6. Mutation checks: remove the tag test (everything locked) and remove the enforcement (nothing locked); each must fail a test.

**Two points for Femi (small):** (a) the lock covers the three balance-sheet roles; depreciation expense, impairment expense and gain or loss on disposal are profit and loss accounts and are not locked unless he says so; (b) when an Investments category is introduced it gets no `fixedAssetRole`, so it can never be locked by this mechanism.

## What I did not verify

I did not read WEB's FA screens beyond locating the API file, did not read the FS-7 SPUTO beyond the playbook's references, and the effort numbers are estimates from the size of the code and the earlier extractions, not measurements.
