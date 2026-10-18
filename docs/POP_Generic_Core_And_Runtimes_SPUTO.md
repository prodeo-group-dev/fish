# POP as the generic Accounts Payable and purchasing core, under any runtime (SPUTO)

Written by the POP session, 2026-10-18. DOCS ONLY: planning, nothing is built. Part of CM's programme (Femi: "Today it is Education Runtime, tomorrow it can be Hospital Runtime, or AutoMechanic Runtime etc."). It builds on `docs/reports/Platform_Contract_Generic_Services_And_Runtimes_SPUTO.md` (EA, the contract layer; not repeated here) and on `docs/POP_Accounts_Payable_Completeness_Assessment.md` (the payables subledger; not repeated either). Design only: no tester text and no customer details.

**What I verified in code and what I assumed.** Verified by reading POP master (`83fdbbc`, live as :55) and the local branches named: every "evidence" line below cites a file. Assumed, and marked so: how a hospital or a garage actually buys, which comes from general knowledge of those trades and not from any customer; the paper runtimes are the test of genericity, not a plan to build them.

## 1. Scope (S)

**The idea.** POP, SOP and IM are the heartbeat of any organisation. POP is where an organisation **buys and owes**: suppliers, purchase orders, receipts, the supplier's bill, payments, credits and returns, and the payables ledger behind account 2000. A runtime (Education today, Hospital or AutoMechanic tomorrow) keeps its own domain, roles and vocabulary and **buys through POP**, exactly as a school raises its tuition invoice in SOP and sells Tuition as an IM service item. A runtime specialises by data and wrappers; it never duplicates a generic service.

**In:** what POP must be so that three different runtimes can buy through it unchanged; where today's POP is not runtime-neutral; what a runtime may call and what POP never does; the order of work and what can ship before a second runtime exists.

**Out:** the contract layer (EA's document), the runtime wrapper pattern (ER's), the chart of accounts per industry (GL's), words and navigation (WEB's), receivables (SOP's), the catalogue (IM's).

## 2. Plan (P)

### 2.1 What POP is, in one paragraph

The payables subledger and the buying workflow. It owns suppliers, orders, receipts (quantities), the supplier invoice register, payments, credit notes and returns, and ageing by due date and by supplier. It never owns the catalogue (IM), the VAT calculation or the ledger (GL), or the runtime's domain (a patient, a vehicle, a pupil). It carries a runtime's opaque reference so cost can be traced back, and it never interprets it.

### 2.2 Requirements (numbered; G = generic, R = runtime-specific)

| # | Requirement | G / R |
|---|---|---|
| R1 | No runtime's word or concept appears in POP's model, routes or error codes. A runtime's vocabulary lives in the runtime and in WEB. | G |
| R2 | A purchase line is one of three kinds: a **stock item** (IM, received into stock), a **service item** (IM, no stock; performed, not received), or an **ad-hoc line** (an explicit VAT category and a chart account, which Femi wants saveable as a reusable service item). | G |
| R3 | Quantities are **decimals**: services are bought by the hour, supplies by the litre or the kilo. | G |
| R4 | A supplier **bill without an order** (rent, utilities, a locum agency, a one-off repair) is a first-class way in; an order is optional. | G |
| R5 | An order and each line may carry an **opaque runtime reference** (`{kind, id}`, for example a job card, a ward, a class) that POP stores, returns and passes on, and never interprets. | G |
| R6 | A line may carry GL **dimension tags** (cost centre, department, project, location) chosen from the Company's own list, so spending can be reported by department or fund without the runtime. | G |
| R7 | Each line's ledger account comes from the **transaction type** through the Company's chart (the sacrosanct rule); none means Suspense 3910. | G |
| R8 | Delivery terms are **optional** (a service has none; a trade-finance import has Incoterms). | G |
| R9 | The supplier master is neutral: name, contacts, payment terms from the shared list, bank details for payment runs, optional **category tags** and optional **attributes with an expiry** (a licence, a certificate). Enforcement of an attribute is a runtime or Company rule, not POP's. | G (attributes), R (the rule) |
| R10 | Approval is **per Company** by value today; a runtime may need it by category or role (a controlled drug, a capital item). POP offers the mechanism (a band and a capability); the policy is data. | G (mechanism), R (policy) |
| R11 | The payables ledger is complete (gross VAT, credits and returns applied, ageing by due date and supplier, statements, payment runs, reconciliation to 2000), as in the AP assessment. | G |
| R12 | A runtime reaches POP **only through its public API with a service identity**: create an order or a bill, record a receipt, read a status. Every state-changing call takes an `Idempotency-Key`. POP never calls a runtime. | G |
| R13 | Returns to a supplier take off what we owe the supplier's price plus VAT, reverse the VAT, and show the difference from stock cost as a cost difference (Femi, 2026-10-18); a warranty or core return carries the runtime reference. | G |
| R14 | The order or bill document sent to a supplier carries the Company's identity, not Prodeo's (Prodeo is a landlord), and the supplier-facing portal and links are generic. | G |
| R15 | One currency per Company today; multi-currency is a platform item (IAS 21), not a runtime item. | G (later) |

### 2.3 Where today's POP is, and is not, runtime-neutral (evidence)

**Neutral, verified:** a search of POP's source for school, education, guardian and student finds one file only: `infrastructure/ea/ea_dtos.kt` (a strict mirror of EA's `/me`, which carries `schoolId`, 2026-09-29). The module grant is the plain string `"POP"` (`infrastructure/web/Auth.kt:159`). POP has no import of any runtime, no call to one, and the Education Runtime makes **no call to POP at all** (the EA baseline, section 2.3). So POP is neutral in code, but it has **never been used by a second kind of organisation**, so its fitness is untested.

**Not neutral, verified:**
1. **Quantities are whole numbers.** `PurchaseOrderLine.quantity: Int` (`domain/purchaseorder/purchase_order_line.kt`) and `quantity: Int` in the DTO (`infrastructure/web/Dtos.kt:67`). A locum agency billed by the hour, or a drug bought by the millilitre, cannot be ordered. IM's quantities are already decimals. (R3)
2. **Delivery terms are mandatory.** `require(deliveryTerms.isNotBlank())` (`domain/purchaseorder/purchase_order.kt:279`, "UC-PO2"). A rent bill or a repair has none. (R8)
3. **Trade-finance remnants shape the model.** `DealRole` and the legacy `prodeoRole` (null, accepted and ignored), `ExecutingParty` with `TENANT_LENDER`, the supplier's `facilityId` and `bankAvalArrangement` (`domain/purchaseorder/supplier.kt:44-45`), waybills and the supplier negotiation portal (`e_order.kt`, `order_access_token.kt`). They are optional and harmless, but a hospital would meet them in the API and the screens. (R1, R14)
4. **An order is the only way to owe.** The only route to a payable is order, send, receive, match. There is no supplier bill without an order. (R4)
5. **A line carries no reference and no dimension.** `PurchaseLine` to GL is `{netAmount, vatCategory}` plus the new `accountId`; GL has the dimensions `COST_CENTER`, `DEPARTMENT`, `PROJECT`, `LOCATION`, `PRODUCT_LINE` (`GL domain/common/dimension_type.kt`) and POP sends none. (R5, R6)
6. **Item type is POP's own pair.** `ItemType {GOODS, SERVICE}` (`item_type.kt`) against IM's `kind {STOCK, SERVICE}`; IM's playbook says POP derives the type from `kind` (R21 there), not yet built. (R2)
7. **No idempotency on creating an order.** Match and payment carry keys; creating and sending an order do not (the POP playbook, known limit). A runtime that retries would create two orders. (R12)
8. **Approval is a single Company value threshold** (`CompanyPurchaseOrderSettings`); there is no approval by category or role, and no second-person rule (T9b, T9c are open decisions). (R10)
9. **Single currency** per Company (R15).

### 2.4 The three paper runtimes (assumed, not customers)

| | **Education** (live) | **Hospital** (paper) | **AutoMechanic** (paper) |
|---|---|---|---|
| **Buys** | stationery and books, lab supplies, catering, uniforms; rent, utilities, transport, repairs; equipment | drugs and consumables (stock, batch and expiry), lab reagents; equipment maintenance; locum and agency staff by the hour; utilities; waste disposal | parts (stock) bought for the shelf; **a part ordered for one customer's job**; consumables; sublet work (a specialist does a task); tools |
| **Mostly without an order** | rent, utilities, transport | utilities, waste disposal, agency bills | rent, utilities, sublet invoices |
| **Special needs** | spending by department or class fund; capital items | licensed wholesalers (an attribute that expires); controlled-drug approvals (two people); restricted donor funds (a project); cold-chain stock | the purchase tied to a **job card** so its cost is recovered on the customer's invoice (SOP's side); warranty and core returns to the supplier; month-end supplier accounts |
| **Their words** | "Supplies", "Bursar's bills" | "Procurement", "Pharmacy orders" | "Parts orders", "Trade accounts" |
| **Generic requirements that serve them** | R3, R4, R6, R7, R11 | R3, R4, R5, R6, R9, R10 | R4, R5, R9, R11, R13 |

Every special need above maps to a generic requirement plus data (a reference, a dimension, an attribute, a band). None needs a hospital-shaped or garage-shaped POP.

### 2.5 What POP will not do, whatever the runtime

Interpret the runtime reference; compute VAT (GL does); hold the catalogue (IM does); call a runtime; enforce a profession's rule (a licence, a controlled-drug policy) itself. A rule like that is a **Company or runtime setting** that POP honours through a generic mechanism (attributes, bands, capabilities).

## 3. Use cases in plain words (U)

**Education**
1. The bursar buys exercise books for Science and English departments: one order, two lines, each tagged to its department, received in part; the invoice arrives and is matched; the cost shows by department.
2. The electricity bill arrives with no order: it is recorded as a bill, one line in the Utilities account with input VAT, due in 30 days.
3. A laptop for the office: a capital line; its account is the equipment asset, not an expense.

**Hospital**
4. The pharmacy orders 40 litres of a solution and 12 hours of an agency pharmacist: decimal quantities, a stock line and a service line.
5. A wholesaler's licence expires next month: the supplier shows an attribute with its expiry; the Company's setting decides whether ordering is blocked.
6. An order of a controlled drug above a band needs a second approver: the band and capability are data, the policy is the hospital's.

**AutoMechanic**
7. A customer's job needs a part the shop does not stock: the order carries the job card reference; when the part is invoiced, the cost is traceable to the job and the runtime's invoice in SOP recovers it.
8. A part is faulty under warranty: a return to the supplier takes off what we owe the supplier's price plus VAT; the credit note arrives later and is compared.
9. The supplier's month-end statement arrives: POP's statement for that supplier shows invoices, credits and payments, and the difference is visible.

## 4. Tasks (T), dependency-ordered, with sizes and owners

Items already planned or in flight are named, not repeated: per-line accounts (held for GL), the VAT-inclusive amount owed and the credit application (with CM), payment terms (core built), returns to a supplier (design agreed with GL and IM), the AP completeness groups 1 to 3.

| # | Task | Owner | Size | Depends on |
|---|---|---|---|---|
| G1 | Decimal quantities on order lines, receipts and the match tolerance (migration, DTOs, IM alignment) | POP | 1.5 d | IM (already decimal) |
| G2 | Delivery terms optional; a service line is "performed" rather than "received" | POP | 0.5 d | none |
| G3 | **Runtime reference** `{kind, id}` on an order and on a line, returned everywhere, never interpreted | POP | 1 d | none |
| G4 | **Dimension tags** on a line (cost centre, department, project, location), picked from the Company's list and sent to GL | POP then GL | POP 1 d, GL 1 d | GL accepting line dimensions (consumer-first) |
| G5 | **Supplier bill without an order** (the AP assessment's task 7) | POP | 2.5 d | per-line accounts (GL) |
| G6 | **Idempotency-Key on creating an order and a bill**; the runtime-callable routes published with fixtures in fish-contracts | POP | 1 d | none |
| G7 | Supplier **category tags** and **attributes with an expiry** (a licence, a certificate), shown and returned; no enforcement | POP | 1 d | none |
| G8 | Approval bands by category or amount with a capability; policy is data | POP | 3 d | the platform capability model (T9b) and Femi |
| G9 | Item type derived from IM's `kind` (R21 there) | POP | 0.5 d | IM slice B live |
| G10 | Retire the trade-finance remnants from the public API and screens (`prodeoRole`, `DealRole`, waybill and negotiation hidden unless used); keep data | POP then WEB | 1 d | WEB stops sending `prodeoRole` |
| G11 | Multi-currency payables | platform | a platform item | IAS 21 |
| G12 | Words per runtime on the screens | WEB | WEB's estimate | none |

POP total for G1 to G10: about **13 days**, of which G5 (2.5 d) is already counted in the AP assessment, so about **10.5 days are new**. G8 (3 d) waits for the capability model and Femi.

## 5. Order (O)

**1. Before any second runtime exists (all of it is worth doing for Education today).** G2 and G6 first (small, remove blockers and double-create risk); G1 (Education buys services by the hour too); G3 and G4 (an Education Company already wants spending by department); G5 (rent and utilities are Education's daily bills); G7 and G9 as small follow-ups. These make POP better for the live runtime and cost nothing extra for the next.

**2. Wait for a second runtime, or a decision:** G8 (the approval policy of a particular profession), G11, and any enforcement of an attribute (a licence, a controlled-drug rule).

**3. Never in POP:** a runtime's domain, vocabulary or profession rules.

What this does to the work already in flight: nothing changes. The per-line accounts, the VAT-inclusive amount owed, the credit application, the payment terms and the returns design are all generic and are first in the order above.

## 6. Decisions for Femi, in plain words, with my recommendation

- **D1.** Should quantities allow decimals (hours, litres)? **Recommendation: yes**; the catalogue (IM) already does, and services by the hour need it.
- **D2.** May a runtime raise a purchase order or a bill in POP through its public API (as the Education Runtime raises a tuition invoice in SOP), with POP never calling the runtime? **Recommendation: yes.**
- **D3.** Are cost centres, departments and projects a list the owner keeps in one place, with a line choosing from it? **Recommendation: yes**; free text would make the reports unreliable.
- **D4.** For a purchase tied to a customer's job, is POP's part only to carry the reference, with the cost recovery being the runtime's invoice through SOP? **Recommendation: yes**; POP does not know about customers' jobs.
- **D5.** A supplier's licence or certificate: shown with its expiry, and enforced (ordering blocked) only if the Company or runtime turns that on. **Recommendation: show now, enforce later.**

## 7. What I could not verify

That any real hospital or garage buys the way section 2.4 describes (assumed from general trade knowledge); that the Education Runtime will want departments from POP (it makes no call to POP today); the exact size of G1 (it touches the match tolerance and the receive path, and IM alignment may add a day); and G8, which depends on the capability model that does not exist yet.
