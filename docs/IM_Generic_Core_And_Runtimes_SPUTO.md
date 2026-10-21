# IM (Inventory and Services Management) as the generic items core, and how runtimes sit on it (SPUTO)

**From:** IM session. **Date:** 2026-10-18. **Status:** PLANNING ONLY. Nothing here is built; no code starts until Femi approves the parts that need his decision (section O). **Part of:** the generic-core-and-runtimes programme (Femi: "Today it is Education Runtime, tomorrow it can be Hospital Runtime, or AutoMechanic Runtime etc."). **Builds on:** `IM_Inventory_And_Services_Management_Coverage_2026-10-18.md` (what IM covers today), `IM_Service_Items_And_Save_As_Item_Design_Note_2026-10-18.md` (service items, accounts), and EA's contract baseline `Platform_Contract_Generic_Services_And_Runtimes_SPUTO.md`, which this document does not repeat.

**What I verified in code and what I assumed.** Verified by reading IM master plus the branches with CM (service items, revenue account, posted amount): everything marked *(IM code)*. Verified in the FiSH checkout of SOP, POP, EA and the Education Runtime, whose submodule pins may be older than their live branches: marked *(checked in the checkout)*. Everything about Hospital and AutoMechanic is **assumed**, from the brief and general knowledge of those trades; no such runtime exists, so none of it is tested against real users.

---

## 1. Scope (S)

**In.** The items core of a platform whose runtimes are Education (live), and, on paper, Hospital and AutoMechanic: the **catalogue** (stock items and service items), its **identity** (code, description, unit, category), its **tax and account defaults** (VAT category, expense and revenue accounts), its **prices**, its **stock life** (receipts, issues, returns, adjustments, counts, valuation, reorder) and **how a runtime and the other generic services read and use it**.

**Out.** What a runtime owns: students, patients, vehicles, admissions, visits, job cards, their roles and vocabulary (the wrapper pattern is ER's part). Receivables and customers (SOP's part), payables and suppliers (POP's part), chart templates and posting (GL's part), runtime registration (EA's part), screens and wording (WEB's part). IM's code stays named `IM`; "Inventory and Services Management" is the label for people.

**The principle I am testing.** A runtime specialises IM **by data and by wrappers, never by changing IM**: it asks IM for items, it stores IM item ids on its own records, and it never grows a second catalogue. If a runtime needs a field IM lacks, the answer is either a generic field every runtime benefits from, or a table in the runtime keyed by the IM item id. Never an `if (runtime == ...)` in IM.

---

## 2. Plan and requirements (P)

### 2.1 Where IM stands on neutrality (evidence)

- **IM contains no Education logic.** A search of IM's domain, application and web code for school, student, tuition, education, hospital, patient and vehicle finds nothing but an EA response field (`schoolId` in `infrastructure/ea/ea_dtos.kt`, a mirror of what EA sends) and a comment in `infrastructure/web/Auth.kt`. *(IM code)* The Education Runtime needs nothing special from IM today: a school fee line is a service item, as any hospital consultation or garage labour hour would be.
- **Trade-finance vocabulary survives in IM and is not neutral.** `ConductStockCountUseCase` names `collateralManagerReportedQuantity` and takes a `facilityId`; `Item` carries an optional `facilityId` and a manufacturing `stage` (raw material, work in progress, finished goods). These come from the original trade-finance deal and mean nothing to a hospital or a garage. They are harmless (optional, unused by the three runtimes) but the names should become generic (R-IM20). *(IM code)*
- **One approval role is a Cognito group, not an EA function.** Approving a stock adjustment requires the caller to be in the `StoreManager` group (`infrastructure/web/Roles.kt`). A pharmacist in charge or a workshop foreman holds the same authority under a different name, and a group in the identity provider is not an EA capability. Fixing it waits for the RBAC freeze to lift (R-IM21). *(IM code)*
- **The catalogue has no code, no category, no active flag, no pagination.** `GET /items` returns every item of the Company in one answer; there is no item code or SKU, no group, no way to retire an item, and no edit of description or unit after creation. EA's inventory tile sums the whole unpaged list. A school has tens of items, a garage hundreds of parts, a hospital formulary thousands. *(IM code; EA tile checked in the checkout)*
- **Consumers already assume a goods-only item.** SOP's availability check reads `quantityOnHand` and its own comment records that IM has no reservation and no "discontinued" state to check; POP's line carries an `itemType` of goods or service, which POP now derives from IM's `kind`. *(checked in the checkout: `SOP/.../CheckInventoryAvailabilityUseCase.kt`, `POP/.../purchase_order_line.kt`)* Services (kind `SERVICE`) are the first place the catalogue stops being goods-only, and that is built and with CM.
- **Everything a runtime needs from the catalogue about money is already on the item or planned:** VAT category (live), default expense account and revenue account (built, with CM), selling price (live, single price). *(IM code)*

### 2.2 Requirements

Each row: **G** = generic (belongs in IM for every runtime), **R** = runtime-specific (belongs in the runtime, never in IM). Status is today's, from the coverage table.

| Id | Requirement | G/R | Status |
|---|---|---|---|
| R-IM1 | The catalogue holds two kinds of item: stock (quantity, cost, stock accounts) and service or expense (no stock, a mandatory VAT category). One item per description per Company. | G | BUILT (service kind with CM) |
| R-IM2 | Every item has a stable identity a person and a system can use: an **item code** unique per Company, plus the description. | G | MISSING |
| R-IM3 | An item's description, unit and code can be corrected after creation, with an audit trail. | G | MISSING |
| R-IM4 | An item can be **retired** (inactive): hidden from pickers, refused on new sales and purchases, still readable on old documents. | G | MISSING |
| R-IM5 | Items can be grouped into a **category** (Fee, Drug, Consumable, Labour, Part...). Categories are data owned by the Company; a runtime may seed a starter set. IM attaches no meaning to a category name. | G | MISSING |
| R-IM6 | Reading the catalogue is paged and filterable (kind, category, code, text, active, a list of ids) and never returns an unbounded list. | G | PARTLY (kind and text only; unpaged) |
| R-IM7 | The VAT category is decided in IM, per item, never defaulted, never typed on a line, and a line freezes a copy. It later resolves by Tax Jurisdiction and date. | G | BUILT (single value); date and jurisdiction MISSING (design: v5 note) |
| R-IM8 | Each item may carry the account a sale posts to and, for a service, the account a purchase posts to; unclassified means Suspense. | G | BUILT (with CM) |
| R-IM9 | Prices: an item has a **selling price**, and a Company may keep several **price lists** (for example a tariff per insurer, a fee schedule per class and year, a staff rate), each price with an effective date. SOP reads the price for the list the order names. | G | PARTLY (one price only) |
| R-IM10 | Stock keeps exact cost and value that reconcile to the ledger; every movement tells GL one exact amount; the answer carries that amount. | G | BUILT (live and with CM) |
| R-IM11 | Receipts, issues, returns in and out, adjustments, counts and transfers work for any reason, not only sale and purchase: an issue states its **reference and reason** (sale, internal use, dispensed, fitted to a job, write-off, return to supplier). The contra account is named by the caller or defaulted per transaction type. | G | PARTLY (reference is free text; contra caller-named; returns inwards MISSING) |
| R-IM12 | Batch and **expiry** tracking, with first-expired-first-out issue, for items flagged as expiring. | G | PARTLY (domain only, no route) |
| R-IM13 | **Serial or lot** tracking for items flagged as serialised, so a unit can be traced to a customer and a supplier (warranty, recall). | G | MISSING |
| R-IM14 | **Pack size and unit conversion**: receive in boxes, issue in tablets or pieces, with one cost basis. | G | MISSING |
| R-IM15 | **Reservation**: stock promised to an order, a job or a procedure is held without being issued, so two promises cannot both succeed. | G | MISSING |
| R-IM16 | Reorder: policy per item, a Company-wide list of items below their reorder point, and owner summaries (value at cost, slow movers) with their basis stated. | G | PARTLY (per item; list and summaries agreed with EA, not built) |
| R-IM17 | A Company can add a **starter catalogue** for its industry in one idempotent action by its Owner Admin or accountant. The content (which fee types, which procedures, which labour rates) is **data declared by the runtime**; the mechanism is generic. | G (mechanism) / R (content) | MISSING |
| R-IM18 | **Kits or packs** (a procedure with its consumables, a service with its parts) are composed by the **runtime** from catalogue lines, not stored in IM, until at least two runtimes ask for the same shape. | R for now | decision D2 |
| R-IM19 | Runtime-only item attributes (a drug's monograph, a part's vehicle compatibility, a fee's term) live in the runtime keyed by the IM item id; IM holds no free-form attribute bag. | R | decision D3 |
| R-IM20 | IM's remaining trade-finance names (`collateralManager...`, `facilityId`) become generic, consumer-first, with contract fixtures. | G | MISSING (small) |
| R-IM21 | Approval of an adjustment or count is an EA capability, not a Cognito group name. | G | MISSING (waits for RBAC) |
| R-IM22 | A runtime that consumes stock **without a sale** (consumables in a procedure, parts fitted to a job) can issue it through a generic route with a reference, called by a runtime service identity that EA allows only in Companies of that industry. | G (route) / R (caller) | decision D5 |
| R-IM23 | The catalogue never carries a runtime's vocabulary. Words ("fee item", "formulary", "parts and labour") are WEB's label map, keyed by the runtime. | G | holds today |

### 2.3 Vocabulary each runtime would use (the API stays neutral; WEB maps words)

| IM concept | Education | Hospital | AutoMechanic |
|---|---|---|---|
| Service item | Fee item (Tuition, Boarding, Exam fee) | Service, procedure, consultation | Labour, service, diagnostic fee |
| Stock item | Stores item (stationery, uniforms, canteen goods) | Drug, consumable | Part, consumable (oil, filters) |
| Category | Fee type, Stores group | Formulary class, Ward stores | Parts group, Labour rate class |
| Price list | Fee schedule (class and year) | Tariff (cash, insurer A, scheme B) | Rate card (retail, fleet, warranty) |
| Receipt | Stores receipt | Goods received note | Parts received |
| Issue | Issue to class or department | Dispense, issue to ward | Fit to job |
| Count | Stock-take | Stock-take (with expiry check) | Stock-take |
| Retire an item | Withdraw a fee | Remove from formulary | Discontinue a part |

---

## 3. Use cases (U)

**Education (live).**
- UC-E1: The Owner Admin adds the school's fee types (Tuition, Boarding, Exam fee) as service items with a VAT category (usually exempt) and a revenue account; each is one item per description, shared by every class that uses it. The Education Runtime stores only the item id on its fee schedule.
- UC-E2: Two classes pay different tuition: one item "Tuition" with two price-list entries (or two items, if they differ in category or account); SOP reads the price for the schedule the invoice names.
- UC-E3: The bursar buys stationery through POP (stock), the store issues it to a class (internal use, with a reference), and the stock value still equals the ledger.
- UC-E4: A new term's fee is a price-list entry with a start date; invoices already raised keep their frozen price.

**Hospital (paper).**
- UC-H1: A consultation and a procedure are service items; each insurer has its own tariff as a price list; the patient's cash rate is the default list. The runtime attaches the item and the list to the visit, SOP raises the receivable to the insurer.
- UC-H2: A drug is a stock item with batches and expiry dates; dispensing issues from the soonest-to-expire batch with the prescription and visit as reference (R-IM11, R-IM12, R-IM22).
- UC-H3: A procedure consumes gloves, a catheter and a drug from ward stores without a separate sale line: internal-use issue with the visit reference; the cost posts to the account named for that transaction type.
- UC-H4: Pharmacy reorder: the list of items below their reorder point, grouped by category, with the pack size the supplier sells (R-IM14, R-IM16); POP orders; the receipt is recorded in boxes and issued in tablets.
- UC-H5: Expired stock is written off by an adjustment with a reason, approved by the person the hospital names (R-IM21), at its exact cost.

**AutoMechanic (paper).**
- UC-A1: Labour is a service item sold by the hour (unit "hour"), with a rate card per customer class (retail, fleet).
- UC-A2: A job card lists labour (service lines) and parts (stock lines). Parts are reserved when the quote is accepted (R-IM15) and issued when fitted (R-IM11, R-IM22); the vehicle itself is the runtime's record, never an item.
- UC-A3: A special-order part not held in stock is bought for one job: POP's "save as an item" creates a service/expense item (or a non-stock part) with its account, so the cost reaches the job's cost of sales, and a repeat picks it.
- UC-A4: A part fails under warranty: it is returned to the supplier (a return out with a named contra), traced by serial or lot to the customer it was fitted to (R-IM13).
- UC-A5: A part is discontinued: retired, no longer offered on new quotes, still readable on old jobs (R-IM4).

---

## 4. Tasks (T), dependency-ordered, sizes in IM working days

Prerequisites already in flight (not re-listed below): the service-items and accounts stack, receipt idempotency (A0), returns inwards, GRNI (seam A), and the contract fixtures.

| # | Task | Owner | Size | Needs |
|---|---|---|---|---|
| T1 | Item code, edit description and unit, retire and un-retire (audited). Refuse retired items on new sale and purchase lines. | IM; consumers SOP, POP, EA, WEB declare the fields first | 1.5 | A0 and the stack merged |
| T2 | Paging and filters on `GET /items` (kind, category, code, text, active, ids), with a default page size; consumers move off the unbounded list | IM; EA, SOP, POP, WEB | 1 | T1 |
| T3 | Item categories (Company data, assigned to items) | IM; WEB | 1 | T2 |
| T4 | Bulk, idempotent **starter catalogue** route (a list of service items by description, category and accounts; existing descriptions are returned, not changed); content declared by the runtime in EA's runtime registration | IM; EA (registration data) | 1 | T3 |
| T5 | **Price lists** and effective-dated prices; SOP reads price by list and date | IM 3; SOP 1 | 4 | T2 |
| T6 | VAT category by Tax Jurisdiction and date (v5 note) | IM 1.5; GL (jurisdiction source) | 1.5 | GL's jurisdiction on the posting context |
| T7 | Route batch and expiry; first-expired-first-out on issue | IM | 2 | T1 |
| T8 | Pack size and unit conversion | IM; POP (orders in pack units) | 2 | T1 |
| T9 | Reservation (hold, release, consume on issue); SOP and the runtime use it | IM 2; SOP 1 | 3 | T1 |
| T10 | Serial and lot tracking | IM | 2 | T7 |
| T11 | Issue with a stated reason and reference; a generic internal-use route for a runtime service identity, allowed only in Companies of that industry | IM 1; EA (the rule, as ER's school rule at SOP) | 1 | decision D5 |
| T12 | Owner summaries: reorder list, valuation summary, slow movers (shapes agreed with EA) | IM; EA | 2.5 | T2 |
| T13 | Generic names for the trade-finance fields, consumer-first, with fixtures | IM; consumers | 0.5 | fixtures |
| T14 | Approval of adjustments and counts as an EA capability instead of a Cognito group | IM 0.5; EA 0.5 | 1 | RBAC unfrozen |

IM total for a runtime-ready catalogue (T1 to T11 without T10): about **16 IM days**, spread over several releases; none depends on a second runtime existing.

---

## 5. Order (O)

**What can ship before a second runtime exists** (each helps Education today, none is speculative): T1 (the Education Runtime already needs a stable fee-item identity and a way to retire a withdrawn fee), T2 and T3 (a school's catalogue is the first place the unpaged list and the absence of groups will hurt), T4 (seeding Tuition, Boarding and Exam fee for a new school is the first real use of a starter catalogue), T12 (the owner view), T13. About **7.5 IM days**.

**What waits for a named trigger, so it is not built on a guess:**
- T5 price lists: when the first Company has two prices for one item (a second school class, or the first insurer).
- T7, T8, T10 (expiry, packs, serials): when a Company holds stock that expires, is bought in a different pack than it is used, or must be traced. The first such customer is the trigger; Hospital would be the first.
- T9 reservation: when a Company's orders compete for scarce stock (a garage with parts held for jobs).
- T11 internal-use route and its runtime identity: with the second runtime that consumes stock without selling it.
- T14: when RBAC unfreezes.

**Recommended sequence:** finish the stack in flight; then T1, T2, T3, T4, T12, T13; then the triggered tasks in the order customers ask.

### Open decisions for Femi, in plain words, with my recommendation

1. **Should a Company be able to have several prices for the same item** (a price list per class, insurer or customer type)? *Recommendation: yes, in IM, and only when the first Company needs a second price. A tariff per insurer and a fee schedule per class are the same thing.*
2. **Should IM store kits** (a procedure with its consumables, a service with its parts)? *Recommendation: not yet. The runtime composes a job or a procedure from catalogue lines. If two runtimes ask for the same shape, we add kits then.*
3. **Where do runtime-only facts about an item live** (a drug's class, a part's vehicle fit)? *Recommendation: in the runtime, in a table keyed by the IM item id. IM keeps no free-form attribute bag, so it never has to know what any runtime means.*
4. **Who adds a new school's, clinic's or garage's starter catalogue?** *Recommendation: the Owner Admin presses "Add the standard items", and the list of items comes from the runtime's registration data in EA. No runtime gets a login to IM for this.*
5. **May a runtime take stock out without a sale** (consumables in a procedure, parts fitted to a job)? If yes, the runtime needs its own service login at IM, allowed only in Companies of its industry. *Recommendation: yes, through one generic route with a stated reason and reference, with the industry rule enforced the way the school rule is enforced at SOP.*
6. **Should an item be retirable?** *Recommendation: yes, now. It is the "discontinued" state SOP's own code says IM lacks.*
7. **What do we call the person who approves a stock adjustment?** Today it is a group named Store Manager. *Recommendation: an EA capability each Company assigns to whoever it chooses (head of stores, pharmacist in charge, workshop foreman), after RBAC unfreezes.*

### What I did not verify
The Hospital and AutoMechanic use cases are paper; I have not seen a real pharmacy, ward store, workshop or insurer tariff. Whether a hospital issues by dispensing record, by ward requisition or both, and how a garage treats customer-supplied parts, are things the first real customer will decide. The pack-size and expiry requirements are the most likely to change shape.
