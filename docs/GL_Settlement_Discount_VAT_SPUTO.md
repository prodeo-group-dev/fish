# Settlement (early-payment) discounts and VAT: the full SPUTO

**Status:** DRAFT, 2026-10-15, planning only, nothing in this document is built or released. Written by the GL session at Femi's decision, relayed by CM: *"We must fully research the exact treatment before they build that part"* (settlement-discount VAT is out of scope until a full SPUTO exists). **Owner: GL**, for the ledger half, the rule table and the reporting effect. POP (the supplier side) and SOP (the customer side) each own their half of the tasks; every task here is a proposal for its owner to confirm. Same shape as `docs/Payroll_SPUTO.md`.

**Evidence tags used throughout:** **[code]** read in the repository, with the file; **[primary]** a statute, a regulation or a tax authority's own manual, read by me from its official host; **[secondary]** a practitioner or vendor page, never enough on its own; **[not found]** I looked and could not find it; **[unverified]** I believe it but did not read it. **Nothing in this document is tax advice. No jurisdiction's rule is confirmed by a tax professional yet; GL must not behave as if one were.**

**Related documents (read, not repeated here):** `docs/POP_Discounts_Received_SPUTO.md` (POP's seven kinds of supplier discount, and the request to GL), `docs/Sales_Returns_Credit_Notes_GL_Half.md` (section 2.4: Discounts Given and Discounts Received, D-SR4 the VAT direction tag), `docs/IE/IE_VAT_MVP_Design.md` (the single netting VAT control account, the five Irish bands), `docs/IFRS_GL_Posting_Matrix.md` (A.5), `docs/Decisions_Log.md` (2026-10-13 and 2026-10-15 entries).

**Decisions already made and not re-litigated here:** two accounts, `Discounts Given` (4910) and `Discounts Received` (4920); the first four supplier kinds (trade, invoice, early-payment, price allowance), one account 4920 for all of them in the first build, no stock-cost reclassification; **trade and invoice discounts need no GL change** (the caller sends net amounts); the VAT on an **early-payment (settlement) discount** is rules per country and per period and is built **only after this SPUTO exists and a tax professional confirms each country** (Femi, 2026-10-15). Femi's earlier rule for VAT category (2026-10-15): it depends on the Tax Jurisdiction and the Fiscal Year and Accounting Period.

---

## 1. Scope (S)

**The problem.** A supplier offers "2/10 net 30": take 2% off if you pay within 10 days. If the buyer takes it, the cash paid is less than the invoice. The accounting is simple (the difference is Discounts Received for the buyer, Discounts Given for the seller). **The VAT is not simple, and it is different in every country**: whether the VAT charged falls, who adjusts, when, on what document, and whether a credit note is needed. Posting the wrong VAT here puts a wrong figure on a tax return, which is a legal filing. So GL refuses to guess.

**In scope.**
1. The settlement (early-payment) discount only: what each jurisdiction we operate in says about its VAT (UK, Ireland, Sierra Leone, Liberia, Guinea, Côte d'Ivoire, Nigeria), with sources and what is unverified.
2. Both sides: the **supplier side** (the buyer's input VAT falls, `Discounts Received`, POP's payment) and the **customer side** (the seller's output VAT falls, `Discounts Given`, SOP's collection).
3. The **per-jurisdiction, per-period rule table**: its design, how GL uses it, how it is governed.
4. The **reporting effect** on `VatReturn` (what changes, what must not).
5. What a tax professional must confirm, per jurisdiction, before any rule is switched on.

**Out of scope.** Trade and invoice discounts, volume and bonus discounts (no VAT leg needed, decided). Rebate accruals. Discounts from group companies. Foreign-currency discounts (one currency per Company). Filing any return with a tax authority (GL computes a figure only). The wording of invoices (a customer's own business process, though section 4 says what the rule needs from them).

**What "settlement discount" means here.** A reduction in price that the supplier offers **for payment within a stated time or in a stated way**, taken or lost at payment. It is not a price reduction known at the time of the sale (a trade discount) and not a later price correction (a credit note for a price allowance). The three differ in VAT everywhere we looked, and the distinction decides which rule applies.

---

## 2. What is true today (evidence)

| Fact | Tag | Where |
|---|---|---|
| `record-payment` takes one `amount` and posts Dr Accounts Payable / Cr settlement account, nothing else. No discount, no VAT. | [code] | `application/RecordSupplierPaymentUseCase.kt` on master |
| `VatReturn` reads the single netting VAT Control Account (2150): output VAT is credits, input VAT is debits, net due is output minus input, the category breakdown is signed per category. | [code] | `domain/tax/vat_return.kt` |
| **A line can now carry `VAT_DIRECTION` (`OUTPUT` or `INPUT`).** `VatReturn` classifies a line by the tag when it is valid, otherwise by side exactly as before. A debit tagged OUTPUT reduces output VAT; a credit tagged INPUT reduces input VAT. Net due and the breakdown never depend on the tag. Built, tested (golden test for the legacy mix, mutation caught), handed to CM for release; nothing writes the tag yet. | [code] | branch `gl/vat-direction-dimension`, commit 9df83b4 |
| VAT rates are data (`vat_rates` rows), with a `verified` flag: GL uses only verified schedules. UK (3 bands) and Ireland (5 bands) verified; Sierra Leone 15% loaded **unverified** and refuses (`no_vat_rate_schedule`); Liberia, Guinea, Côte d'Ivoire, Nigeria have no rows. | [code] | `VatRateRepository.findVerifiedScheduleFor`, `TestVatRates` |
| The rate in force is chosen **by the transaction date** (Ireland's second reduced band fell from 13.5% to 9% on 1 July 2026). | [code] | `VatRateSchedule.rateFor` |
| Nothing records who verified or changed a rate. An audit trail for that is a stated prerequisite before any further country is switched on. | [code] | `docs/GL_Playbook_Draft.md`, NOT BUILT list |
| Account 4920 `Discounts Received` (REVENUE type) is in the business templates, module-owned (a cash book may not post to it), and added to older Companies by standard-accounts. Built, handed to CM. | [code] | branch `gl/discounts-received-account`, commit ae4591c |
| **A prototype of the supplier-side posting exists and is parked.** `record-payment` with optional discount lines `[{netAmount, vatCategory}]` plus `originalSupplyDate`: computes the VAT on the discount at the rate on the supply date, posts Dr AP (cash + net + VAT) / Cr settlement (cash) / Cr 4920 (net) / Cr VAT control (VAT, tagged INPUT), returns what it computed, and **refuses with 409 `discount_vat_rule_not_verified`** when the discount carries VAT and no confirmed rule covers the jurisdiction and supply date. The confirmed-rule list is empty in code. Use case and rule tests pass; route tests not written. Not for release. | [code] | local branch `gl/supplier-payment-discount`, commit c114b17 |
| POP accepted the lines shape, the returned figures (`payableCleared`, `discount {net, vat}`) and the refusal code. | cross-session | POP to GL message, 2026-10-15 |
| Reports sum every REVENUE-type account as "revenue", so a discount received counts inside revenue on the profit and loss and the trading profit and loss: gross margin reads slightly high, net profit is right. FR-SR64 already asks to check this. | [code] | `profit_and_loss.kt`, `ComputeTradingProfitAndLossUseCase` |

**What the prototype proves, and what it does not.** It proves the shape of the request, the arithmetic and the refusal. It does **not** prove the rule: it assumes one treatment (the buyer's input VAT falls **when the discount is taken at payment**). Section 3 shows that treatment is the UK's where the invoice says "no credit note will be issued", and **not** (on the statute text I read) Ireland's. That is exactly why Femi paused it.

---

## 3. What each jurisdiction says (research, with sources)

### 3.1 The summary

| Jurisdiction | Evidence level | What I found | Status for GL |
|---|---|---|---|
| **United Kingdom** | [primary] HMRC manual | VAT is accounted on **the amount actually paid**, from 1 April 2015. Two invoice modes decide how the buyer adjusts: a credit note, or "no credit note will be issued" wording. Conditions apply. | **No verified rule.** Well evidenced, but from one official manual page I read, not yet confirmed by a tax professional. |
| **Ireland** | [primary] statute text; **[not found]** Revenue guidance on settlement discounts | The statute ties the supplier's relief for a discount to **a credit note being issued**, and reduces the buyer's deduction by the tax on **the credit note**. Nothing I found says a conditional early-payment discount avoids the credit note. | **No verified rule.** The Irish treatment of a settlement discount is **unconfirmed**; the statute points to a credit-note mechanism, not the UK's. |
| **EU background** (Ireland is a member state) | [primary-via-summary] Directive 2006/112/EC Art 79(a), Art 90 | The directive's taxable amount excludes "price reductions by way of discount for early payment" (Art 79(a)); Art 90 covers a price reduced after the supply, "under conditions determined by the Member States". | Context for Ireland only. How Ireland implements Art 79(a) is the unanswered question. |
| **Sierra Leone** | [not found] operative text | The GST Act 2009 has "Value of supply" (s.21), "Post-supply adjustments for GST adjustment events" (s.22), bad debts (s.23); I saw headings only. The 15% rate is loaded unverified. | **No rule. Text not read.** |
| **Liberia** | [primary] Revenue Code (as amended 2020) | The taxable amount is the consideration "reduced by any price discounts or rebates allowed **and accounted for at the time of the supply**" (goods tax s.1004(e); services tax s.1025(d)). That language fits a discount known at sale, not obviously a conditional early-payment discount taken later. The post-sale adjustment section I found (s.1005) covers goods tax for registered manufacturers only; I found no equivalent for services. GST rate rose 12% to 13% in 2026 and a VAT replaces it planned for 1 January 2027. | **No rule, and the regime itself is changing.** Do not build for the old GST. |
| **Guinea** | [not found] | The CGI (revised, validation workshop December 2020) is published; I did not find the VAT base article on discounts. | **No rule. Text not read.** |
| **Côte d'Ivoire** | [not found] | A member of UEMOA. The harmonised VAT directive (02/98/CM/UEMOA) defines the base as the consideration obtained or to be obtained (Art 27, per a secondary reading). The ivorian CGI article on discounts was not found. | **No rule. Text not read.** |
| **Nigeria** | [not found] | VAT now sits in the Nigeria Tax Act 2025 (from 1 January 2026, 7.5%). No source I found addresses value-of-supply discounts or VAT credit notes. | **No rule. Nothing found.** |

### 3.2 United Kingdom (the best evidenced)

**Source.** HMRC VAT Valuation Manual, VATVAL08500 (published 26 April 2016, updated 15 June 2021), read at gov.uk on 2026-10-15; the VAT guide (Notice 700) paragraph 7.3.2(b) says only that the tax value "is based on the actual amount paid". **[primary]**. The manual cites VAT Act 1994 Schedule 6 paragraph 4 (conditions for a prompt payment discount, PPD), section 19, and the VAT Regulations 1995 regs 14, 29 and 38.

**What it says.**
- The supplier accounts for VAT **on the amount actually paid**. Before 1 May 2014 HMRC allowed output tax on the discounted amount even if the customer paid in full; **from 1 April 2015** the actual-payment rule applies to all businesses (1 May 2014 for broadcasting and telecoms).
- The supplier chooses one of two invoicing modes: (1) **full-value invoice plus PPD offer**, with a **credit note** issued if the discount is taken; or (2) an invoice stating the PPD terms (including the deadline) and that the customer can only recover the VAT actually paid, with the words **"No credit note will be issued"**, relying on the VAT invoice and proof of the discounted receipt to reduce output tax under reg 38.
- **The customer's input VAT:** full payment, no adjustment; discounted payment on receipt per the terms, record the discounted price and its VAT, no later adjustment; **late discounted payment**: record the full amount first, then, if the invoice says no credit note will be issued, **adjust input VAT when paying**, otherwise **adjust when the credit note arrives**.
- Conditions: the consideration is a price in money; the terms allow a PPD; **payment is not by instalments**; the discount is **realised under the stated terms**. An underpayment outside the terms is not a PPD: VAT stands on the full amount, and a later agreed price reduction is a reg 38 adjustment.

**What this means for the rule table.** The UK treatment has **two triggers**, chosen by the supplier's invoice wording: **on payment** (invoice says no credit note) or **on the credit note** (otherwise). GL cannot know the wording unless the caller says. It also needs a **window** (the payment terms) and a **no-instalments** condition. A rule that only says "UK: reduce input VAT at payment" is **wrong half the time**.

**Worked example (UK, 20%).** Invoice 1,000.00 net + 200.00 VAT = 1,200.00, 2% settlement discount on the net. Discount 20.00 net + 4.00 VAT. Paid within the window in mode 2: cash 1,176.00. Buyer: Dr Accounts Payable 1,200.00 / Cr Cash 1,176.00 / Cr Discounts Received 20.00 / Cr VAT control 4.00 (tagged INPUT). Input VAT reclaimed falls from 200.00 to 196.00. Seller (the mirror): Dr Cash 1,176.00 / Dr Discounts Given 20.00 / Dr VAT control 4.00 (tagged OUTPUT) / Cr Accounts Receivable 1,200.00; output VAT falls from 200.00 to 196.00. In mode 1 the same VAT leg posts when the **credit note** arrives (buyer) or is issued (seller), not at payment.

**What I did not establish for the UK:** that nothing has changed since the 2021 update (the POP note also asked to re-check HMRC's current guide); how Notice 700 section 18 (credits and debts) words it (the page text was cut off before it); the rounding convention; how partial payment inside the window works.

### 3.3 Ireland (the active MVP market, and the least certain)

**What I read [primary].** The Value-Added Tax Consolidation Act 2010, Law Reform Commission revised text, read at revisedacts.lawreform.ie on 2026-10-15:
- **Section 39(1):** where the consideration actually received is **more** than the supplier was entitled to, tax is charged on the amount actually received (excluding the tax itself).
- **Section 39(2) and (4):** relief for a shortfall in consideration may be given as regulations provide; **where a supplier issues an invoice and then allows a reduction or discount, that relief "shall not be given until he or she issues the credit note required" by section 67(1)(b).**
- **Section 67(1)(b):** on a reduction or discount the supplier "shall issue … a document (… a 'credit note')"; if the customer is an accountable person, their deduction "shall, in accordance with regulations, be reduced by the amount of tax shown on that credit note".
- **Section 67(5):** where a reduction or discount is agreed but the tax on the invoice stays the same, the customer's deduction is **not** reduced (not applicable where the supplier accounts on a cash-receipts basis).
- **Section 120** lets Revenue make regulations on the adjustment when a discount is allowed and on the content of credit notes.

**What I read about timing [secondary, from an earlier Revenue tax briefing and the 1992 invoice regulations, not re-verified]:** a credit note for a discount allowance is to be issued **within fifteen days of the date of receipt of the money to which the discount relates**; Revenue allowed latitude for long-term agreements (a credit note need not cross-reference every invoice). The 1997 briefing predates the 2010 consolidation, so it may have been renumbered or amended. The regulation itself (S.I. 276 of 1992) could not be fetched (HTTP 403).

**What Revenue's own page says.** "Returned goods and discounts" (revenue.ie): adjust the VAT payable where a discount or price reduction is given **after** a supply; "you must issue a credit note in cases where you have issued an invoice and later reduced the price of a supply". It says **nothing** about settlement or prompt-payment discounts **[not found]**.

**What I could not find.** Any Revenue manual or guidance on how a **conditional** early-payment discount is treated, and whether Ireland follows the UK's post-2015 "amount actually paid" approach. A software vendor's help page says Irish VAT is always charged on the full invoice value regardless of settlement discounts **[secondary, unreliable]**. The EU directive excludes early-payment discounts from the taxable amount (Art 79(a)); how Irish law implements that is **the** open question.

**What this means for the rule table.** On the statute I read, the Irish trigger is **the credit note** for both sides: the supplier's output VAT does not fall, and the buyer's input VAT does not fall, until a credit note for the discount exists. That is a **different mechanism from the UK's "on payment"** and it needs a supplier credit note record (POP's T-D5) and a customer credit note (SOP). **Do not extend the UK rule to Ireland.** The rule for Ireland stays blank until an Irish tax adviser answers the questions in section 8.

### 3.4 The other jurisdictions (nothing confirmed)

- **Sierra Leone.** The Goods and Services Tax Act 2009 (parliament.gov.sl) lists "Value of supply" (s.21), "Post-supply adjustments for GST adjustment events" (s.22) and bad debts (s.23). I could read headings only (the PDF host failed certificate verification and search returned only the contents page). The 15% rate is loaded unverified; a settlement discount would be refused here for that reason alone.
- **Liberia.** See the table. The 2020 Revenue Code text I extracted says the taxable amount is the consideration reduced by discounts "allowed and accounted for **at the time of the supply**". A discount that is only conditional until payment is not obviously "accounted for at the time of the supply". The GST is being replaced by a VAT on 1 January 2027, so any rule written now has a short life; treat Liberia as **unstable** (the platform's own tax doc already says so).
- **Guinea.** Revised CGI exists; the VAT base article on discounts was not found. Standard VAT 18% (platform tax doc).
- **Côte d'Ivoire.** UEMOA-harmonised VAT: the base is the consideration (secondary reading of Art 27, Directive 02/98/CM/UEMOA); French law is **not** a substitute and I did not use it. The Ivorian CGI text was not found. A 9% agricultural rate changed three times in January 2026 (platform tax doc): treat the VAT regime as volatile.
- **Nigeria.** The Nigeria Tax Act 2025 replaced the VAT Act from 1 January 2026; no source found on value-of-supply discounts. A Nigerian entity is planned; settlement-discount VAT there is a question for that entity's tax adviser.

**Honest conclusion of section 3.** One jurisdiction (the UK) has a clearly described treatment from an official source and even that has two triggers; Ireland's looks different and is unconfirmed; five have nothing I could verify. The right default for every one of them today is **refuse**.

---

## 4. What a rule has to express

From the evidence, a settlement-discount VAT rule is not a boolean. The fields it must carry:

| Field | Why (evidence) |
|---|---|
| `jurisdiction`, `effective_from`, `effective_to` | per country and per period (Femi); keyed on the **date of the supply**, as POP asked, because the rate and the regime are those of the supply |
| `trigger`: `ON_PAYMENT`, `ON_CREDIT_NOTE`, `NONE` (VAT unchanged) | UK has both `ON_PAYMENT` (invoice says no credit note) and `ON_CREDIT_NOTE`; Ireland's statute points to `ON_CREDIT_NOTE`; some countries may be `NONE` |
| `requires_invoice_wording` (UK: "no credit note will be issued") and whether the caller must tell GL which mode | the same payment posts its VAT leg at different times by mode |
| `window` conditions: payment within the stated terms, **no instalments** | UK conditions; an underpayment outside terms is not a settlement discount |
| `credit_note_deadline_days` (Ireland: 15 days from receipt of money, **unverified**) | a statutory deadline changes the document flow |
| `date_basis` for the **rate**: supply date, payment date or credit note date | UK and Ireland differ; the rate band can change between supply and payment (Ireland, 1 July 2026) |
| `confirmed_by`, `confirmed_on`, `source_reference`, `evidence_note`, `verified` | traceability; a rule without a named confirmation is not loaded as verified |

**GL refuses when:** the discount carries VAT and no verified rule covers `(jurisdiction, supply date)`; or the rule's trigger needs a document the caller did not supply (a credit note reference in `ON_CREDIT_NOTE`); or the payment is outside the stated window or instalmental where the rule requires neither. Refusal code `discount_vat_rule_not_verified` (409), nothing posted, key not spent, no fall back to a VAT-free discount (POP agreed).

**Partial payments and late payment.** A late payment gets no discount and no VAT change (UK: not a PPD; the full VAT stands). A partial payment inside the window is **undecided** in every jurisdiction: ask the tax professional (section 8).

---

## 5. The two sides, and the reporting effect

### 5.1 Supplier side (buyer): input VAT, `Discounts Received` (POP)

- **`ON_PAYMENT`:** one posting at payment, as in the worked example (the prototype). Input VAT reduced by a credit to VAT control tagged `INPUT`.
- **`ON_CREDIT_NOTE`:** the payment posts **net only** (Dr AP cash + net discount / Cr settlement / Cr 4920), and the **VAT leg posts when the supplier credit note arrives**: Dr AP VAT amount / Cr VAT control tagged `INPUT`. That needs POP's supplier credit note record (T-D5) and a GL posting for it. So the Irish path **cannot** be a payment-only change.
- The returned figures POP asked for (`payableCleared`, `discount {net, vat}`) must tell POP how much of the invoice each posting cleared.

### 5.2 Customer side (seller): output VAT, `Discounts Given` (SOP)

Mirror image: Dr cash (received) / Dr 4910 (net discount) / Dr VAT control (the VAT on the discount, tagged `OUTPUT`) / Cr Accounts Receivable (received + net + VAT), at the trigger the jurisdiction's rule names. Irish statute: the supplier's relief is **withheld until the credit note is issued** (s.39(4)), so SOP must be able to issue the credit note and GL must not reduce output VAT before it is posted. Not designed in detail: SOP owns it (`docs/Sales_Returns_Credit_Notes_SOP_Half.md`).

### 5.3 Reporting effect on `VatReturn` (from my review of the code)

- **What changes:** with `VAT_DIRECTION`, a settlement discount that reduces input VAT shows as **a reduction of input VAT**, not as extra output VAT; a seller's discount shows as **a reduction of output VAT**, not as extra input VAT. Without the tag a credit to VAT control would be read as output VAT, which would put the adjustment in the wrong box.
- **Worked reporting example.** Output VAT 1,000.00 and input VAT 400.00 before. A 4.00 input-VAT adjustment: output 1,000.00, input 396.00, net due 604.00. A 4.00 output adjustment (seller side): output 996.00, input 400.00, net due 596.00 (net moves by exactly the amount, the split by side is right).
- **What must not change:** net VAT due and the per-category breakdown are credits less debits and never depend on the tag; every posting made before the tag is unchanged and keeps being classified by side. A golden test pins that.
- **Return box mapping is a separate unverified question.** The UK return's box 1 (VAT due on sales) and box 4 (VAT reclaimed on purchases) and Ireland's VAT3 sales and purchases lines would receive these adjustments; I did not verify how each authority wants a discount adjustment shown (net within the box, or separately). **[unverified]**. GL computes a figure only; filing is out of scope.
- **Reports:** a discount received sits in a REVENUE-type account, so total revenue includes it. Before posting to 4920 in production, check the trading profit and loss presentation (FR-SR64: under other income, outside gross margin).

---

## 6. The rule table design (T)

**Recommendation: data, not code, like the VAT rates (Option B, 2026-10-06).** A table `settlement_discount_vat_rules` with the fields in section 4, a `verified` flag, and **GL reads only verified rows**. My parked prototype uses an empty code constant; that is fine for a prototype and wrong for production, because enabling a country must be a **data change CM prepares and Femi runs**, with a record of who confirmed it, not a code change.

**Governance (prerequisites).**
1. **An audit trail for rate and rule changes.** The Playbook already says nothing records who verified or changed a VAT rate and that an audit trail is required before any further country is switched on. The same gap applies here, and applies first: a rule changes what goes on a tax return. Prerequisite for loading even one verified row.
2. **Confirmation evidence stored with the row** (who, when, which document), not in a chat.
3. **Effective dating** by supply date; a rule never edited in place: end the old row, add the new one.
4. **Seeded empty.** No row ships verified. UK and Ireland rows are loaded **only** after section 8's questions are answered.

**How callers learn the rule.** They do not. They send lines and (where the rule needs it) the invoice mode and credit note reference; GL decides and refuses with `discount_vat_rule_not_verified`. A read route that lists which jurisdictions allow an early-payment discount (so a screen can hide the option) is **optional** and later.

**Test strategy.** One golden test per verified rule per trigger, from the tax professional's own worked example; a test that an unconfirmed jurisdiction refuses; a test that a refusal posts nothing and spends no key.

---

## 7. Requirements, use cases, tasks (P, U, T, O)

**Requirements (MoSCoW).**
- **M1** GL never posts a VAT leg for a settlement discount without a verified rule for `(jurisdiction, supply date)`; it refuses, never falls back to VAT-free.
- **M2** The rule names its trigger; GL posts the VAT leg at that trigger only.
- **M3** The VAT leg is tagged `VAT_DIRECTION`, so `VatReturn` shows adjustments on the correct side; legacy postings are unchanged.
- **M4** The rate is the rate on the date the rule's `date_basis` names; the supply date by default.
- **M5** A rule is data with a named confirmation and effective dates, and a change is audited.
- **M6** A refused request posts nothing and does not spend its idempotency key.
- **S1** The returned figures say how much of the payable each posting cleared.
- **S2** A read route tells a screen whether a settlement discount is available for a Company.
- **C1** Partial-payment and instalment handling per the confirmed rules.

**Use cases.** (UC-1) UK buyer pays within terms, invoice says no credit note: one posting at payment. (UC-2) UK buyer, invoice offers a credit note: net at payment, VAT when the credit note arrives. (UC-3) UK buyer pays late: no discount, no VAT change. (UC-4) Irish buyer: credit note flow, not a payment-only change (once confirmed). (UC-5) A Company in a jurisdiction with no verified rule: a discount carrying VAT is refused with a plain message; a discount whose lines are all exempt or zero-rated posts with no VAT leg. (UC-6) The seller's mirror of UC-1 and UC-2 (Discounts Given). (UC-7) A VAT return over a period containing adjustments shows output and input on the right sides.

**Tasks and order (sizes are my estimates, unproven).**

| Wave | Task | Owner | Size | Depends on |
|---|---|---|---|---|
| 0 (decisions, no code) | Ask Femi to commission a tax professional for the section 8 questions, **Ireland first** (the active market), UK second | Femi via CM | n/a | this document |
| 0 | Decide whether an all-exempt/zero-rated discount (no VAT leg) may post before any rule exists (the parked prototype allows it; CM and POP did not object) | Femi via CM | n/a | |
| 1 | `VAT_DIRECTION` + `VatReturn` (built, with CM) | GL | done | |
| 1 | `4920` account (built, with CM) | GL | done | |
| 2 | **Audit trail for VAT rate and rule changes** (prerequisite) | GL | to scope | GL audit trail design |
| 2 | `settlement_discount_vat_rules` table, repository, refusal path, seeded empty, tests | GL | about 1.5 d | wave 1 |
| 3 | Optional discount lines on `record-payment` for `ON_PAYMENT` rules (the parked prototype, rebuilt on the data table) | GL | about 1.5 d | wave 2 + a confirmed rule |
| 3 | Supplier credit note record and GL posting for `ON_CREDIT_NOTE` (buyer VAT leg) | POP + GL | POP 2.5 d + GL about 2 d | wave 2 + a confirmed rule; POP's T-D5 |
| 4 | Customer side: discount on `record-collection`, DISCOUNT credit note kind, output VAT leg | SOP + GL | per S8 | Sales Returns approval |
| 4 | `VatReturn` golden tests per confirmed rule from the professional's worked examples | GL | 0.5 d per rule | confirmations |
| 5 | `GET` route for "is a settlement discount available" (S2); WEB screens | GL + WEB | small | waves 3 |

**Order:** nothing in waves 2 to 5 starts before wave 0 is answered. Waves 2 and 3 are inert without a confirmed rule. The one thing that can start now without anyone's confirmation is the audit trail scoping, which the VAT work needs regardless of this discount.

---

## 8. What a tax professional must confirm (per jurisdiction)

**Ireland (first):**
1. When a supplier offers a **conditional early-payment discount** on an invoice, and the buyer pays early and takes it: does the supplier's taxable amount and the buyer's deductible VAT fall **at payment**, or **only when a credit note is issued**? Is a credit note mandatory in every case, or can the invoice itself state the discount (so the discount counts as given at the time of supply)? How does the **EU Directive Art 79(a)** (early-payment discounts excluded from the taxable amount) apply in Irish law, if at all, beside s.39(4) and s.67(1)(b)?
2. Is the **fifteen-day credit note deadline** (from receipt of the money) current law, and which instrument is it in today?
3. Which VAT3 lines do the supplier's and the buyer's adjustments go in, and in which period (the period of the credit note, of the payment, or of the original supply)?
4. Partial payment inside the discount window: pro-rata, or no discount?
5. A supplier accounting on a **cash-receipts basis** (s.67(5), s.39): is the answer different?
6. The rate for the adjustment: the rate on the **supply date** or the **credit note date**? (Matters across Ireland's 1 July 2026 change.)

**United Kingdom:**
1. Confirm HMRC's current position matches VATVAL08500 (2021 update) and Notice 700 section 18.
2. Both modes: how must the buyer's system know the supplier's mode (invoice wording)? Is there a default when the invoice is silent?
3. Partial payment in the window; the "no instalments" condition with a multi-payment settlement.
4. The date of the adjustment for the return period; rounding; how the adjustment is shown on the return.
5. Northern Ireland (Windsor Framework, "XI" VAT numbers): any difference for goods-in-scope transactions? (`docs/UK/NI_Jurisdiction_Specification.md` says NI VAT-on-goods differs; settlement discount unexamined.)

**Sierra Leone, Liberia, Guinea, Côte d'Ivoire, Nigeria (each, when its entity or customer demands it):** read the operative text; confirm whether a settlement discount reduces the taxable amount, at what trigger, with what document, and (Liberia, Côte d'Ivoire, Nigeria) whether the regime in force at that date is the one changing. **Liberia: wait for the January 2027 VAT.**

**Every jurisdiction:** the VAT leg when the discount is taken **outside** the window (none expected), when the buyer is **not VAT-registered** (no input VAT to adjust; the seller's output still falls), and when the supply is **part-exempt**.

---

## 9. Risks

1. **Wrong VAT on a filed return.** The reason for refusing by default. A wrong rule is worse than no rule.
2. **Extending the UK rule to Ireland by analogy.** The statute text I read points to a credit-note mechanism; the UK's is payment-based. The prototype does the UK thing.
3. **Two documents, two dates.** In `ON_CREDIT_NOTE` regimes the payment and the VAT adjustment are separate events, possibly in different VAT periods; the design must allow VAT to post later without re-posting the payment.
4. **Rate changes between supply and adjustment.** Ireland's 1 July 2026 change makes the date basis a real correctness issue, not a theory.
5. **No audit trail for rate and rule changes** (existing gap). Loading a rule without it means nobody can answer "who switched on this country".
6. **Reporting drift.** A discount received counted in revenue changes gross margin; check before 4920 is used in production.
7. **Rules that go out of date.** Liberia (GST to VAT in 2027), Côte d'Ivoire, Nigeria (new Act from 2026): effective dating must be real, not decoration.
8. **Parked prototype lingering.** It must not be released; it is a design aid and its tests describe one treatment only.

---

## 10. Decisions asked of Femi (one batch, via CM)

1. **Commission a tax professional**, Ireland first, with the section 8 questions. (Femi already flagged this to CM as an action for him.)
2. **May a discount whose lines are all EXEMPT or ZERO_RATED post before any rule exists?** Recommendation: yes (no VAT leg, no tax effect). Today's prototype allows it.
3. **Where does the audit trail for rate and rule changes sit in the order?** Recommendation: before the first verified rule, and it serves the existing VAT-rate gap too.
4. **Rule table as data (recommended) or a code list for the first rules?** Recommendation: data.
5. **Liberia, Nigeria, Côte d'Ivoire, Guinea, Sierra Leone: confirm none of them is built before its entity or first customer exists.** Recommendation: yes; they are researched to "nothing found" only.

---

## 11. What I could not verify

- **Revenue (Ireland) guidance on settlement or prompt-payment discounts:** none found on revenue.ie, in a Tax and Duty Manual, or via search.
- **S.I. 276 of 1992 and the Irish Tax Adviser magazine article** on discounts: HTTP 403 on both; the fifteen-day rule and the Argos history come from search summaries of them.
- **The EU Directive text and CJEU cases** (Art 79, Art 90, Almos, Kraft Foods, and others): read as search summaries of the legislation.gov.uk copy, not the full text; the CJEU judgments were not read.
- **Sierra Leone GST Act ss.21, 22:** certificate error on the Parliament PDF host; headings only. Guinea CGI, Côte d'Ivoire CGI, Directive 02/98 Art 27: not read. Nigeria Tax Act 2025 sections: not found.
- **UK Notice 700 section 18** and any change after the VATVAL08500 June 2021 update.
- **VAT return box mapping** for both countries.
- **How partial payment works** in any jurisdiction.
- **Liberia GST to VAT 2027 details:** the sources differ on scope; the platform's own tax doc already marks it unstable.

## Sources

- HMRC, [VAT Valuation Manual VATVAL08500, Prompt payment discounts](https://www.gov.uk/hmrc-internal-manuals/vat-valuation/vatval08500) (read 2026-10-15; published 26 April 2016, updated 15 June 2021)
- HMRC, [VAT guide (Notice 700)](https://www.gov.uk/guidance/vat-guide-notice-700), paragraph 7.3.2(b)
- Revenue (Ireland), [Returned goods and discounts](https://www.revenue.ie/en/vat/charging-vat/returned-goods-and-discounts/index.aspx)
- Law Reform Commission, Revised Acts, [Value-Added Tax Consolidation Act 2010, section 39](https://revisedacts.lawreform.ie/eli/2010/act/31/section/39/revised/en/html), [section 67](https://revisedacts.lawreform.ie/eli/2010/act/31/section/67/revised/en/html), [section 120](https://revisedacts.lawreform.ie/eli/2010/act/31/section/120/revised/en/html)
- Revenue Tax Briefing, Issue 27 (1997), via [Chartered Accountants Ireland TaxSource](https://www.charteredaccountants.ie/taxsourcetotal/2010/en/act/pub/0031/tb/sec0067-2-tb.html) (secondary, predates the 2010 consolidation)
- Council Directive 2006/112/EC, Articles [79](https://www.legislation.gov.uk/eudr/2006/112/article/79/2020-01-01/data.html) and 90 (via search summary)
- Liberia Revenue Code as amended 2020, [Part III, Chapter 10](https://disasterlaw.ifrc.org/sites/default/files/media/disaster_law/2021-10/REVENUE-CODE-LIBERIA-REVENUE-CODE-AMENDEMENT-2020-min.pdf), sections 1004, 1005, 1025 (text extracted from the PDF)
- Sierra Leone, [Goods and Services Tax Act 2009](https://www.parliament.gov.sl/uploads/acts/THE%20GOODS%20AND%20SERVICES%20TAX%20ACT,%202009.pdf) (contents page only)
- Platform documents named at the top, and the platform's own country tax documents under `docs/UK/`, `docs/IE/`, `docs/SL/`, `docs/LR/`, `docs/GN/`, `docs/CI/`, `docs/NG/`
