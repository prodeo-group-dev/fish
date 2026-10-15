# Discounts Received: POP's half, and the request to GL (SPUTO)

**Status: DECIDED 2026-10-15 (Femi approved all seven decisions in section 7, recorded in `docs/Decisions_Log.md`), POP session. Nothing is built or deployed yet. Build order is section 6: T-D1 first; the early-payment discount (T-D4) waits for T8 (T-D2), GL's supplier half of S8 (T-D3), and a tax professional's confirmation of Ireland's VAT treatment.** Written because Femi, asked about "Discounts Received", answered on 2026-10-15: *"Early Payment is just one type of discount. There are various discounts that exist in today's high octane business environment which must be factored in."* My earlier question had only covered the early-payment (settlement) discount; this note covers the whole family.

**Written from.** POP master `2670f76` (POP `:46`), GL's design note `docs/Sales_Returns_Credit_Notes_GL_Half.md` (section 2.4, D-SR7, FR-SR60 to FR-SR64, task S8), the Decisions Log (2026-10-13: "Discounts Given, Discounts Received"), `docs/IFRS_GL_Posting_Matrix.md` (A.5), and three outside sources for the VAT and accounting treatment (section 9). Everything marked **checked** was read in code or in the named document; everything marked **not verified** says so.

---

## 0. In one paragraph

A business gets *discounts received* from its suppliers in at least seven different shapes (a lower price, a discount on the invoice total, a bulk-buying price, a reward for paying early, a price allowance after the invoice, a rebate at the end of a period, free extra goods). They look alike to a customer but differ in **when the amount is known**, **where it must be recorded**, **what it does to the VAT**, and **whether it changes the cost of stock**. POP today knows none of them: a purchase order line is a quantity and one unit price, and a payment is one amount. Three of the seven need **no new accounting at all** (the discount is folded into the net price before anything is posted); the others need a small, typed addition in POP and a matching optional field in GL, which GL has already designed for the sales side and is waiting for POP to ask for on the purchase side. This note makes that request, in the order that keeps each step safe.

---

## 1. Scope (S)

**In scope.** Every discount a Tenant receives from a supplier on goods or services it buys (stock, services, assets): how POP captures it, stores it, shows it, and what it asks GL to post. It follows Femi's principle (Decisions Log, 2026-10-13): accountants treat these as **Discounts Received**, a named account, never a silent change of price.

**Out of scope here (noted, not decided).**
- Discounts a Tenant *gives* its customers: that is `Discounts Given`, SOP's and GL's half (already designed in GL's note, 2.4).
- Supplier-funded promotions that are not a discount on a purchase (a contribution to marketing, a card cashback): recorded by hand as other income.
- Discounts on purchases *from* the Tenant's own group companies, and foreign-currency discounts (platform-wide currency decisions apply).
- Prodeo has no part in any of this: it is a Tenant's own purchase from its own supplier (Decisions Log 2026-10-15).

---

## 2. The family of supplier discounts, and what each one needs (P)

Facts that shape every row (**checked**): a POP purchase line holds `quantity` and one `unitPrice` and nothing else; the three-way match posts `net amount + VAT category` per line to GL (GL works out the VAT from the net); a payment is one amount that debits Accounts Payable and credits cash or bank; POP stores no discount anywhere; GL's chart has no `Discounts Received` account yet (GL plans `4920`); a Supplier's payment terms are a free-text string such as `Net 30`.

| # | Kind | When is the amount known? | What the accountant does | VAT | Needs in POP | Needs in GL |
|---|---|---|---|---|---|---|
| **A** | **Trade discount** (a lower agreed price, a negotiated price, a customer-specific price) | At ordering | Not a separate entry: the cost is the net price (IAS 2.11 "trade discounts ... are deducted"). GL's matrix A.5.1: "no separate posting". | Charged on the net price | Keep the **list price and the discount** on the line for display and audit; the **net unit price** is what the line carries and posts | **Nothing.** GL already receives net amounts |
| **B** | **Invoice-level discount** (5% off the invoice total, or a fixed amount off) | On the supplier invoice | Spread across the lines (pro rata to each line's net) so each line's cost and VAT are right | On the net of each line | Record the discount at the three-way match; **allocate it across the lines** by a fixed rounding rule; the net lines go to GL as today | **Nothing.** GL gets the allocated net lines |
| **C** | **Volume or quantity-break discount at ordering** (buy 100, price falls) | At ordering | Same as A | On the net | A **supplier price list** (item, minimum quantity, unit price, valid from and to) that fills the net price at entry; later and optional | Nothing |
| **D** | **Settlement discount** (a reward for paying early, e.g. `2/10 net 30`) | The right to it is known at ordering or on the invoice; it is *taken* only at payment, if paid in time | Payment is less than the invoice; the difference is **Discounts Received** (GL matrix A.5.2: Dr Payable full, Cr Cash paid, Cr Purchase Discount Income) | **Differs by country** (section 3) | Structured terms (percent, days) on the supplier and the invoice; a payment that records "discount taken"; a "pay by this date and save X" view; the **payment must first track amounts paid (T8)** | `discountAmount` on `record-payment` (GL's S8), the account, a VAT leg |
| **E** | **Price allowance or credit note after the invoice** (damaged but kept, a price correction, goodwill) | After the invoice, from the supplier's credit note | A **supplier credit note of kind DISCOUNT**: Dr Payable, Cr Discounts Received, VAT reversed | The input VAT is reduced by the credit note | A new `SupplierCreditNote` record (kind, amount, VAT per category, supplier, optional order); today's Returns Outwards credit note is tied to goods going back, a price allowance has no return | Credit note kind DISCOUNT on the purchase side (GL's S8, supplier half) |
| **F** | **Volume rebate** (a retrospective reward for buying a lot over a period, paid or credited afterwards) | After the period, per a contract | Reduces the cost of purchases (IAS 2.11). Many accountants accrue it when it is probable and measurable (a practitioner view, not the standard's text). | Reduced by the credit note | Same `SupplierCreditNote` with kind REBATE, tied to a supplier and a period, not one order. **Accruing an expected rebate is a later phase** | As E |
| **G** | **Bonus goods** ("buy 10, get 1 free") | At ordering or on delivery | The cost of the goods received is spread over all units, no separate account | On what was charged | A **bonus quantity** on the line (received, not charged); the real unit cost = amount / (quantity + bonus) must reach the stock; touches IM | Nothing for posting; IM must take the spread cost (**not verified**: whether POP's receive step allows more than the ordered quantity) |

**What POP does *not* do:** it never guesses a discount, never applies one by default, and never lets one be a free number: every discount is a typed record with a kind, a basis (percentage or fixed amount), and a source (an agreement, an invoice, a credit note).

---

## 3. The VAT effect (the part that differs by country)

A discount after the sale changes the VAT, but how depends on the country and on how the discount is documented. What the sources say (section 9; **not legal advice, confirm with a tax professional per country before build**):

- **Ireland** (Revenue): VAT must be adjusted when a discount or price reduction is given **after** a supply; where an invoice was already issued, a **credit note** is issued. The search did **not** find Revenue guidance specifically on settlement (prompt-payment) discounts, so the Irish treatment of D is **not confirmed**.
- **United Kingdom** (HMRC VAT guide and valuation manual): a prompt-payment discount is valued on the amount actually paid when it is taken; the customer adjusts the input VAT it claims **when it pays** if the invoice says "no credit note will be issued", or **when the credit note arrives** otherwise. A payment outside the terms is not a prompt-payment discount and the full VAT stands. (My search found nothing supporting a 2025 change; the rules in force date from 1 April 2015. Re-check HMRC's current guide before relying on this.)
- **Sierra Leone, Liberia, Guinea, Côte d'Ivoire, Nigeria:** not researched. The platform's VAT work to date is Ireland first (`docs/IE/IE_VAT_MVP_Design.md`).

**Consequence for the design.** The VAT effect of D, E and F is a **per-country, per-period rule**, the same shape as Femi's VAT-category rule of 2026-10-15 ("VAT ... depends on the Tax Jurisdiction and the Fiscal Year and Accounting Period"). So POP does not compute it. POP sends the discount and the lines it relates to; **GL** applies the jurisdiction's rule and posts the VAT leg tagged `INPUT`, as GL's note already says for the Returns Outwards mirror. For the first build, A, B and C need no VAT leg at all (the VAT is on the net).

---

## 4. Requirements (P)

| # | Requirement |
|---|---|
| R1 | A discount is a **typed record**: kind (`TRADE`, `INVOICE`, `SETTLEMENT`, `PRICE_ALLOWANCE`, `REBATE`, `BONUS_GOODS`), basis (percentage or fixed amount), and where it came from. No free-number "discount" field, no default, never inferred. |
| R2 | **A and B fold into the net price.** The net amounts are what POP posts to GL, so the cost and the VAT are right with GL unchanged. The gross amount and the discount are kept for display and audit. |
| R3 | **An invoice-level discount is allocated across the lines** pro rata to each line's net, to the smallest currency unit, with a fixed, tested rounding rule so the lines add up to the invoice exactly (the largest-remainder method). |
| R4 | **A settlement discount is taken only by an explicit act at payment**, inside the terms' window; outside it the full amount is paid and nothing is recorded as a discount. |
| R5 | **Partial payments are tracked first (T8).** A payment records how much was paid; the order closes and the invoice settles only when **paid plus discount** equals what is owed. |
| R6 | A posting with a discount is **GL-first and idempotent like match and pay** (the order id is the key; a refused request spends nothing; a changed retry after a crash is a loud 422). |
| R7 | A discount is **frozen on the document** once the order is sent or the invoice matched (Femi's snapshot rule): a later change of a supplier's terms never alters an order already placed. |
| R8 | **Credit notes of kind DISCOUNT and REBATE are supplier credit notes**, a record of their own (kind, amount, VAT per category, supplier, optional order, optional period), posted by GL as Dr Payable, Cr Discounts Received, with the VAT reversed per the jurisdiction's rule. |
| R9 | The `Discounts Received` account is **GL's `4920`** (seeded in every business chart, presented as other income; GL's FR-SR60). POP never names an account number; it asks GL's purchase-side posting context for it, exactly as it asks for the AP and VAT accounts. |
| R10 | The **three-way match** must not misread a discount as a mismatch: the invoice's line figures arrive with the gross, the discount and the net; the tolerance check compares like with like. |
| R11 | Reports can show what was saved and what was **lost** (a settlement discount offered and missed), so the owner sees the cost of paying late. Later. |
| R12 | Same access as paying: whoever may pay may take a discount; every discount taken is audited (who, when, amount, kind). |
| R13 | Nothing here involves Prodeo. A discount is between the Tenant and its supplier. |

---

## 5. Use cases (U)

| # | Use case |
|---|---|
| UC-1 | **A negotiated price.** The buyer enters the list price and a 10% trade discount; the order shows both and carries the net price. |
| UC-2 | **A discount on the invoice total.** The supplier's invoice takes 5% off; at the match the buyer enters it, POP spreads it across the lines, and the cost and VAT per line reflect it. |
| UC-3 | **Pay early and save.** The invoice says `2/10 net 30`; the pay screen shows "pay by 12 Nov and save 40.00"; the buyer pays 1,960 on day 8; the books show a 40.00 discount received and the invoice closed. |
| UC-4 | **Pay late.** The same invoice paid on day 25: the full 2,000 is paid, no discount, and a report shows the 40.00 was lost. |
| UC-5 | **Part payment.** Half is paid now, the rest later; the order stays open until paid plus discount covers the invoice. |
| UC-6 | **A price allowance.** The supplier credits 150.00 for damaged-but-kept goods; the buyer records the credit note as a discount; the payable falls and Discounts Received rises, with the VAT reversed. |
| UC-7 | **A year-end rebate.** The supplier's credit note for last year's volume arrives; the buyer records it against the supplier and the period. |
| UC-8 | **Bonus goods.** Ten units ordered, eleven arrive; the buyer receives eleven and the unit cost falls accordingly. |
| UC-9 | **A mistaken discount.** A discount is entered on an order not yet sent: it is corrected before posting; after the match it is posted and a correction is a credit note, never an edit. |
| UC-10 | **A country whose VAT rule on a settlement discount is not yet known.** The settlement discount is refused for that Company with a plain message; trade and invoice-level discounts still work. |

---

## 6. Tasks (T), order (O), and sizes

Sizes are my estimates and unproven.

| Task | Where | Content | Size |
|---|---|---|---|
| T-D1 | POP | **Trade and invoice-level discounts (A, B):** list price and discount on the line, net price posted; invoice-level discount at the match with the allocation rule; gross, discount and net shown and audited; tests for rounding and for the three-way tolerance (R10) | 3 d |
| T-D2 | POP | **T8: partial supplier payments** (track amount paid; close and settle only when covered). A prerequisite for D and a correctness fix in its own right | 2 d |
| T-D3 | GL | **The supplier half of GL's S8:** `4920` in the templates, `discountAmount` on `record-payment`, `discountsReceivedAccountId` on the purchase-side posting context (the read route GL's FR-SR62 says "waits for POP's request"), the VAT leg tagged `INPUT` with the jurisdiction rule | 1 d on top of S8's 1.5 d |
| T-D4 | POP | **Settlement discount (D):** structured terms on the supplier and the invoice (percent, days), the pay screen's "pay by and save", the explicit "take the discount" act, the date window, the audit; refused where GL has no VAT rule for the jurisdiction | 2 d (needs T-D2, T-D3) |
| T-D5 | POP + GL | **Supplier credit notes of kind DISCOUNT and REBATE (E, F):** the record, the route, GL's credit note kind DISCOUNT on the purchase side, VAT reversal | 2.5 d (POP) + GL's S8 share |
| T-D6 | POP | **Supplier price lists (C)** with effective dates: item, minimum quantity, unit price, valid from and to | 3 d (later, optional) |
| T-D7 | POP + IM | **Bonus goods (G):** a bonus quantity on the line, the spread cost reaching IM's receipt | 1.5 d POP + IM (first verify where IM's receipt cost comes from; POP does not send it today) |
| T-D8 | WEB | The screens for each of the above (the list price and discount on the order line, the invoice discount at the match, the pay-early prompt, the credit note form), built after each POP piece | per piece |
| T-D9 | POP | **Reports: discounts received and discounts lost (R11)**; rebate accrual (F) | later |

**Order.** T-D1 first (it needs nothing from GL and covers the three most common cases: A, B and, once entered by hand, C). Then T-D2, which also fixes the payment flaw that closes an order on any amount. In parallel GL builds T-D3 (its own S8 already scoped). Then T-D4 and T-D5. T-D6, T-D7 and T-D9 wait for demand. Total POP effort for D1, D2, D4, D5: **about 9.5 days**, plus GL's addition.

---

## 7. Decisions for Femi (plain words, each with my recommendation): ALL SEVEN APPROVED 2026-10-15, as recommended

1. **Which kinds first?** *Recommendation:* trade discount, invoice discount, early-payment discount and the price-allowance credit note first; the yearly rebate when its credit note arrives (recorded, not accrued); price lists and bonus goods only when a customer asks.
2. **Where does a discount received go in the accounts?** GL plans one account, `Discounts Received` (4920), shown under other income. Some accountants instead treat a rebate or an early-payment discount as a **reduction of the cost of what was bought** (the accounting standard says trade discounts and rebates reduce the cost of stock, and a 2004 interpretation says discounts actually received for early payment do too). *Recommendation:* use the one account for the first build and let the accountant choose how it is shown in reports; adjusting the stock's cost is a later step, only for stock still on hand. Needs an accountant's confirmation.
3. **The VAT on an early-payment discount.** It differs by country and I have not confirmed it for Ireland. *Recommendation:* build the early-payment discount only once Ireland's treatment is confirmed by a tax professional, and make the rule a per-country, per-period setting in GL, never a hard-coded one; until then trade and invoice discounts work everywhere.
4. **Structured payment terms.** Today a supplier's terms are free text ("Net 30"). *Recommendation:* add optional structured terms (percent, days, net days) beside the text, so "2/10 net 30" can be understood by the system; the text stays for suppliers with terms we cannot express.
5. **Who may take a discount?** *Recommendation:* the same people who may pay, always audited.
6. **Rounding of a discount spread over lines.** *Recommendation:* the largest-remainder method, the same answer every time.
7. **Accrue expected rebates?** *Recommendation:* not in the first build; record the rebate when the supplier's credit note arrives.

---

## 8. Risks and things nobody asked

1. **Partial payments must come first.** Today POP closes an order on any successful payment, so a settlement discount built on that would close an order with money still owed. T8 is a prerequisite, not a nicety.
2. **A discounted invoice can look like a mismatch.** The three-way match compares the invoice with the order; a lower invoice price may fall outside the tolerance or hide a real error. R10 is the guard; it needs real test data.
3. **Stock cost.** A trade discount changes the cost of stock only if the net price reaches IM. **Not verified:** POP does not send the cost on a receipt today (POP's receive step is a status change; IM's receipt takes a caller-supplied cost), so where the cost comes from for a purchased item must be checked with IM before promising that stock cost reflects the discount.
4. **The seam A (GRNI) double count** (a stock purchase received in IM and matched in POP counts the payable and cost twice) is still open; discounts interact with it (the receipt cost and the match amount must agree). Do not treat discounted stock purchases as correct until GRNI lands.
5. **Account class and VAT** are accountant and tax-adviser decisions (decisions 2 and 3), not engineering ones.
6. **A missed discount is invisible today.** Without R11, an owner never sees what late payment costs.
7. **One account for every kind** loses the distinction between a rebate and a settlement discount in reports; a dimension can separate them later without a new account (GL's note makes the same point for scholarships).

---

## 9. Sources

Outside sources used for section 3 and decision 2 (practitioner and official guidance, **not the standard's own text**; confirm before relying on any of it):
- [Revenue (Ireland): Returned goods and discounts](https://www.revenue.ie/en/vat/charging-vat/returned-goods-and-discounts/index.aspx)
- [GOV.UK: VAT guide (Notice 700)](https://www.gov.uk/guidance/vat-guide-notice-700) and the [VAT Valuation Manual, VATVAL08500 (prompt payment discounts)](https://www.gov.uk/hmrc-internal-manuals/vat-valuation/vatval08500)
- [Grant Thornton IFRS viewpoint: inventory discounts and rebates](https://www.grantthornton.global/globalassets/1.-member-firms/global/insights/article-pdfs/2015/issue-3-inventory-discounts-and-rebates.pdf) and the [IFRS Community summary of IAS 2](https://ifrscommunity.com/knowledge-base/cost-of-inventories/)

Inside the repo: `docs/Sales_Returns_Credit_Notes_GL_Half.md` (2.4, D-SR7, FR-SR60 to FR-SR64, S8), `docs/IFRS_GL_Posting_Matrix.md` (A.5), `docs/Decisions_Log.md` (2026-10-13 and 2026-10-15), `docs/IE/IE_VAT_MVP_Design.md`.

---

## 10. What I am not claiming

I do not know the Irish VAT treatment of a settlement discount, any other country's, or how a given accountant would classify a rebate; I have not checked how IM's receipt cost is set when a purchase arrives; and I have not confirmed whether POP's receive step accepts more than the ordered quantity (needed for bonus goods). Section 7 asks for exactly those answers before anything beyond T-D1 and T-D2 is built.
