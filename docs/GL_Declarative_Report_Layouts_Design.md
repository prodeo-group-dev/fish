# GL declarative report layouts: design note

**Status:** design only, 2026-10-11, GL session. Nothing in this document is built. It answers Femi's question "will it be wise to have the structure of the sections of the reports of a GL designed in XML", and his instruction to write the design note. Several choices are Femi's; they are collected in section 11 with a recommendation each.

## 1. The question, answered in one paragraph

Yes, defining the structure of the financial statements as data is wise, and it will be needed. But the layouts should be authored as **versioned JSON, validated by a schema and by golden-file tests**, not as hand-written XML, and XML should appear only **at the filing edge** (XBRL and iXBRL), where each layout line carries the taxonomy concept it renders to. The layout is one of three separate things: the **layout** (sections, order, subtotals), the **mapping** (which accounts feed which line) and the **renderers** (JSON API, print, CSV, XBRL). Keeping them separate is the design; the file format is a detail. Build it when the first jurisdiction needs a different statement format or a filing obligation arrives, not before.

## 2. What GL does today (verified on master)

- **Balance sheet.** `BalanceSheet.of` builds it from the trial balance: asset, liability and equity lines grouped by `AccountType`, each line carrying its `AccountClassification` (current or non-current); retained earnings is computed as revenue less expense. Totals and the balance check (`isBalanced`) are computed in the domain class. The response is `{assetLines, liabilityLines, equityLines, retainedEarnings, totals, isBalanced}`: flat lists, no sections, no subtotals such as "net current assets".
- **Profit and loss** is revenue less expense for the open Period or a date range; a separate **trading profit and loss** groups expense accounts by `ExpenseClassification` (cost of sales, operating, interest, tax). **Working capital** is current assets less current liabilities. The **statement of cash flows** has the fixed IAS 7 shape (operating, investing, financing). The **trial balance** is the base all of them read.
- **The grouping rules are implicit in code**: which account lands on which line follows from account type, classification and expense classification, plus a few accounts recognised by code (cash `1000`, VAT `2150`, inventory `1300`).
- **Consumers.** EA's dashboard decodes the balance-sheet and profit-and-loss responses **strictly** (an unknown field is an error, by Femi's rule), and WEB renders them. No other service reads them.
- **Jurisdiction as data** already exists: the `jurisdictions` table (code, name, enabled, currency), tax rules, VAT rates.
- **The filing requirement is already written down**: `docs/UK/iXBRL_XBRL_Statutory_Filing_Requirements.md` (UC-X1 to X5) asks for a versioned mapping from chart-of-accounts concepts to a regulator's taxonomy elements, trial-balance extraction, iXBRL generation, validation, submission. It leans toward not building native XBRL in the near term.

## 3. The problem

1. **One layout fits one purpose.** A UK private company's statutory balance sheet follows a prescribed format (fixed assets, current assets, creditors due within one year, net current assets, total assets less current liabilities, creditors due after more than one year, provisions, net assets, capital and reserves). Ireland's follows its Companies Act formats, Nigeria and Sierra Leone their own, and an IFRS entity a different presentation again. Management accounts, statutory accounts and a filing are three different layouts of the same ledger. Today GL has a single layout, so each new one would be a code change and a deploy.
2. **The grouping is not editable by an accountant.** A Company that wants "Prepayments" separate from "Debtors", or a line for its own account, cannot say so; the structure follows account type only.
3. **Filing needs a mapping that does not exist.** UC-X1's mapping from accounts to taxonomy concepts has nowhere to live, and it must be versioned because regulators change taxonomies.

## 4. The proposal: three artefacts, kept apart

### 4.1 Layout (the structure of a statement)

A layout is a tree of **sections** and **lines**, identified by `layoutId` and `version`, scoped to a statement (`BALANCE_SHEET`, `PROFIT_AND_LOSS`, later `CASH_FLOW`), a jurisdiction (or `ANY`) and a framework (for example `UK_FRS102_1A`, `IFRS`). Each line has a stable `key`, a label (per language), an optional `taxonomyConcept`, a **source** and a presentation sign. A source is exactly one of:

- **accounts:** a selector over accounts (section 4.2);
- **sum:** the total of named child lines (a subtotal);
- **difference:** one line minus another (for example "Net current assets" = current assets minus creditors due within one year);
- **carry:** a figure taken from another statement (for example profit for the year into reserves).

That is the whole vocabulary. **No general formula language.** The standard statements need only these four; anything that needs more is a new, reviewed source kind, not an expression string. This is the main guard against the design growing into a programming language.

### 4.2 Mapping (which accounts feed which line)

A selector picks accounts by any of: `type`, `classification`, `expenseClassification`, a `code` range, a `cashBookKind`, a new optional account `reportTag`, or an explicit list of account ids. The **system layouts** use only generic selectors (type, classification, code ranges), so they work for every Company's chart. A Company may add a **per-Company override** that pins specific accounts to a line (stored as rows: company, layout, line key, account ids), which is also where the UC-X1 taxonomy mapping fits: the line's `taxonomyConcept` plus the Company's pinned accounts is the versioned mapping the filing document asks for.

### 4.3 Renderers (what comes out)

One evaluated statement feeds every output: the JSON API, WEB's screen, print and CSV, and later the XBRL/iXBRL render, where each line's `taxonomyConcept` becomes the element tag. The **iXBRL writer is the only XML in the design**, and the standard says what it must be.

## 5. Why JSON, not XML, for the layouts themselves

- XML earns its place where a regulator mandates it: XBRL taxonomies are XML, iXBRL is HTML with XML tags. That is the filing edge, and there it is rendered, not authored.
- For GL's own layouts, JSON (or YAML) carries exactly the same information, is easier for people and tools to read, diff and review in a pull request, needs no namespace or schema-location machinery, and is what every service and screen in this platform already speaks.
- A JSON Schema validates the shape at build time and at start-up; golden-file tests validate the output. XML Schema would give no extra safety here.
- If a regulator later supplies a taxonomy or a layout in XML, an importer can convert it into this model; the model does not change.

So XML is **not unwise**, but it is the wrong thing to hand-write, and the wrong place for the source of truth.

## 6. Evaluation

A pure function: **trial balance in, statement tree out.** It reads each account's balance once, assigns it to the line whose selector matches, computes the sums and differences, and returns a tree of lines with amounts. Rules enforced on every run:

1. **Every account with a balance is assigned to exactly one line.** An account matching none is reported as unmapped (UC-X1's exception); one matching two lines is an error. A layout is refused if it cannot place every account of the Company's chart.
2. **The statement reconciles to the trial balance.** The sum of the leaf lines equals the trial balance's total for the statement's account types; a balance sheet balances.
3. **Per-Company overrides cannot break the layout:** an override that would double-assign an account or leave one unassigned is rejected when saved.
4. Money stays in the Company's one currency (the foreign-currency design keeps the base ledger in the base currency, so this evaluator is unaffected by it, see `docs/GL_Foreign_Currency_Accounts_IAS21_Design.md`).

## 7. API and compatibility

- **New, versioned endpoints**, for example `GET /companies/{id}/statements/{statement}?layout=&asOf=` returning the tree. The existing `reports/balance-sheet`, `reports/profit-and-loss` and the rest are **not changed**: EA decodes them strictly, so a new field or a new shape would break its dashboard (consumer-first applies). They later become thin views over the default layout, once EA has moved.
- A statement response carries `layoutId` and `layoutVersion`, so any figure can be traced to the exact layout that produced it.
- **A filed or issued statement must be reproducible:** when a statement is issued for a filing, store the layout version, the mapping version and the trial-balance snapshot with it (UC-X2's snapshot rule). Changing a layout later never changes a statement already issued.

## 8. Worked example: a UK balance sheet (abridged)

The layout below is an illustration of the model, **not a validated statutory format**: the exact captions, order and the small-company options must be confirmed with an accountant and the FRC taxonomy before it is built.

```json
{
  "layoutId": "uk-frs102-1a-format1", "version": 1, "statement": "BALANCE_SHEET",
  "jurisdictions": ["UK"], "framework": "UK_FRS102_1A",
  "sections": [
    { "key": "fixedAssets", "label": "Fixed assets", "lines": [
        { "key": "tangible", "label": "Tangible assets", "taxonomyConcept": "PropertyPlantEquipment",
          "source": { "accounts": { "type": "ASSET", "classification": "NON_CURRENT" } } } ] },
    { "key": "currentAssets", "label": "Current assets", "lines": [
        { "key": "stocks", "label": "Stocks", "source": { "accounts": { "type": "ASSET", "codes": ["1300"] } } },
        { "key": "debtors", "label": "Debtors", "source": { "accounts": { "type": "ASSET", "codes": ["1100"] } } },
        { "key": "cashAtBank", "label": "Cash at bank and in hand", "source": { "accounts": { "cashBookKind": ["CASH", "BANK"] } } },
        { "key": "currentAssetsTotal", "label": "Current assets", "source": { "sum": ["stocks", "debtors", "cashAtBank"] } } ] },
    { "key": "creditorsWithinOneYear", "label": "Creditors: amounts falling due within one year", "lines": [
        { "key": "creditorsDue1", "label": "Creditors due within one year", "source": { "accounts": { "type": "LIABILITY", "classification": "CURRENT" } } } ] },
    { "key": "netCurrentAssets", "label": "Net current assets", "lines": [
        { "key": "nca", "label": "Net current assets", "source": { "difference": ["currentAssetsTotal", "creditorsDue1"] } } ] },
    { "key": "totalAssetsLessCurrentLiabilities", "label": "Total assets less current liabilities", "lines": [
        { "key": "talcl", "label": "Total assets less current liabilities", "source": { "sum": ["tangible", "nca"] } } ] },
    { "key": "capitalAndReserves", "label": "Capital and reserves", "lines": [
        { "key": "shareCapital", "label": "Called up share capital", "source": { "accounts": { "type": "EQUITY" } } },
        { "key": "profitAndLoss", "label": "Profit and loss account", "source": { "carry": "profitForTheYear" } } ] }
  ]
}
```

Note that **the cash line is one selector, `cashBookKind`**: every cash and bank book a Company adds appears under "Cash at bank and in hand" with no layout change, which is the payoff of having the cash and bank kind on the account. The default layout (section 9, P1) is the same engine reproducing today's flat balance sheet exactly.

## 9. Phasing and size (GL days, rough, tests and mutation checks included)

| Phase | Contents | Days |
|---|---|---|
| P0 | Decisions in section 11 | none |
| P1 | The evaluator, the JSON Schema, the layout loader (system layouts shipped in the repo), the **default layout that reproduces today's balance sheet and profit and loss figure for figure**, with a regression test against the current output; new `statements` endpoint | 4 to 5 |
| P2 | System layouts for the UK and Ireland (balance sheet and profit and loss), golden-file tests | 3 |
| P3 | Cash flow and trading profit and loss as layouts | 3 to 4 |
| P4 | Per-Company overrides (storage, validation, route); WEB screen to see and pin mappings (WEB's own sizing) | 3 GL |
| P5 | Taxonomy concepts on lines and the iXBRL renderer; **build or buy** is decided in UC-X4's terms (taxonomy validation rules are regulator-maintained and change yearly) | 2 to 3 weeks, or buy |

P1 changes nothing for any user and nothing for EA. P2 onward adds statements, never changes an existing response.

## 10. Risks and alternatives considered

- **Formula creep.** Section 4.1's closed vocabulary is the control; new source kinds need a design review.
- **Silent misstatement from a wrong mapping.** The exactly-once rule and the reconciliation to the trial balance (section 6) are the control; the unmapped list is shown, never hidden.
- **Layout churn against filed accounts.** Versioning and the issued-statement snapshot (section 7).
- **Maintained by a developer or an accountant?** If layouts live only in the repo, every change is a deploy. The loader can later read the same JSON from a reference table (as jurisdictions are) so CM can add one as data; per-Company overrides are data from the start.
- **Alternative: XML as the source of truth** (XBRL taxonomy as the layout). Rejected: the taxonomy describes concepts, not a Company's statement structure or chart mapping, it changes every year, and it is a poor authoring format; used at the edge instead.
- **Alternative: keep layouts in code.** The status quo; right for now, wrong once a second jurisdiction's format is needed.
- **Alternative: buy.** An XBRL/iXBRL toolkit is the likely answer for P5 (the filing document says so); it does not replace the layout and mapping, which it needs as input.
- **Labels and languages.** Labels are per language (English first; French for Guinea and Cote d'Ivoire later), kept in the layout, not in code.

## 11. Questions for Femi

1. **Timing:** build P1 now as groundwork (4 to 5 days, no user-visible change), or wait for the first jurisdiction or filing that needs a second layout? Recommendation: wait, unless a UK or Irish statutory format is needed within the next few months.
2. **First format:** which statement set matters first: UK, Ireland, or the management-account formats for Sierra Leone and Nigeria customers? Recommendation: whichever the first paying customer files.
3. **Who edits layouts and mappings:** developers through the repo (recommended for system layouts), and the Company's accountant through WEB for overrides (P4)?
4. **Filing:** is native iXBRL still not wanted near term (the filing requirements document leans no), keeping P5 as a later build-or-buy decision?
5. **Validation:** who confirms a statutory layout is right before it ships (an accountant or an auditor), since a wrong caption is a compliance problem, not a bug?
