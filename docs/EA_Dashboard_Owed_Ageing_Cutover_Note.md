# Dashboard "money owed": cutting the ageing over from GL to POP and SOP (EA design note, docs only)

**Status:** 2026-10-18, planning only, nothing built. Written by the EA session at CM's request, relaying Femi's architecture principle (Decisions Log, 2026-10-18): **"They hold the details, GL aggregates."** POP (payables), SOP (receivables), Payroll, Fixed Assets and IM each hold their details and do their own ageing and registers; GL serves control-account balances and totals only. Builds on `docs/EA_Dashboard_At_A_Glance_Playbook.md` (P2, approved 2026-10-12) and `docs/Payment_Terms_Shared_Definition_Design.md`. Evidence tags: **[code]** read in EA on 2026-10-18; **[doc]** read in a repo doc; **[proposed]** this note's proposal to the owner, not agreed.

## 1. Where it stands today

| Fact | Tag |
|---|---|
| The dashboard's "Owed to you / You owe" tile comes from ONE GL call, `getReceivablesPayablesSummary`: per side `total`, `overdueTotal`, `overdueCount`, plus `currency` and `asOf`. EA maps it into `DashboardResult.receivablesPayables`; if the call fails the tile is left out and `unavailable` says why (one failing source never blanks the page). | [code] `ComputeDashboardUseCase` |
| "Overdue" there means **unpaid and older than 30 days, by GL's first-in-first-out rule since the sale or purchase date**, always labelled so (Femi, 2026-10-12). Not a due-date overdue. | [doc] Decisions Log 2026-10-12 |
| GL holds no customer or supplier master data, so its ageing is a ledger-only approximation of what SOP and POP actually know. POP already ages payables by invoice due date (`accounts-payable-due-date-aging`, with `undatedAmount` and `totalOutstanding`), but its CURRENT bucket mixes "not yet due" with "up to 30 days overdue". SOP has no receivables ageing. | [doc] Dashboard Playbook section 2 |
| Payment terms are being defined once for SOP and POP (a fixed list of codes, an invoice due date), so a true due-date overdue becomes possible on both sides. | [doc] Decisions Log 2026-10-18, Payment_Terms_Shared_Definition_Design |

## 2. The rule

1. **Totals stay with GL.** "Owed to you" is control account 1100's balance, "You owe" is 2000's. That is the figure the books say, and it never comes from a sub-ledger.
2. **Ageing and detail come from the holder.** The overdue figure and count come from SOP (receivables) and POP (payables) once they serve them. Per-customer and per-supplier detail never enters the dashboard response; the tile links to the POP or SOP screen (WEB's deep link).
3. **Never a number that is not true (Playbook R2).** Every overdue figure says what it means and where it came from. The meaning travels with the number, so the label cannot drift from the figure.
4. **Fall back, do not blank.** Until a service ships its ageing, or when its call fails, the tile keeps GL's 30-day approximation, labelled as GL's. A figure from the holder replaces it only when it agrees with the books (section 4).

## 3. The shape EA needs from POP and SOP [proposed]

One small Company-scoped read per service, answered for the caller's own token (the person's module and role rules apply, as for every other dashboard source). Same shape on both sides so EA has one mirror pattern.

`GET /companies/{companyId}/payables-ageing-summary` (POP) and `GET /companies/{companyId}/receivables-ageing-summary` (SOP):

```json
{
  "currency": "SLE",
  "asOf": "2026-10-18",
  "totalOutstanding": "12500.00",
  "overdueTotal": "3000.00",
  "overdueCount": 4,
  "overdueBasis": "INVOICE_DATE_30",
  "undatedAmount": "0.00"
}
```

| Field | Meaning |
|---|---|
| `totalOutstanding` | Everything unpaid in the sub-ledger, in the Company's currency. This is what EA reconciles against GL's control-account balance. |
| `overdueTotal`, `overdueCount` | The overdue part and the number of unpaid invoices in it, under `overdueBasis`. |
| `overdueBasis` | **`INVOICE_DATE_30`** (unpaid and older than 30 days by invoice date; what both services can say today) or **`DUE_DATE`** (past the invoice's due date; possible once payment terms exist on that side). The service states which; EA never infers. |
| `undatedAmount` | Unpaid amount the service cannot age (no date or no terms). Counted in `totalOutstanding`, never in `overdueTotal`. |

Money fields are strings (decimal), like every other money field EA mirrors. One currency per Company today (SLE-only decision); a service that holds more than one currency answers 409 `multiple_currencies` and EA falls back to GL, never summing.

An optional second step (**P3, "Next due"**, already in the Dashboard Playbook): `nextDue` as the nearest five unsettled invoices (`invoiceId`, `counterpartyName`, `dueDate`, `amountOutstanding`), POP first. Not part of the cut-over itself.

## 4. How EA combines them (use-case rules) [proposed]

For each side, `ComputeDashboardUseCase` calls GL (already) and, in parallel, the holder's ageing read. Then:

| Situation | The tile shows | `overdueSource` |
|---|---|---|
| Holder answered, and its `totalOutstanding` equals GL's control-account total (to the currency's minor unit) | GL total; holder's `overdueTotal` / `overdueCount`; holder's `overdueBasis` | `POP` or `SOP` |
| Holder answered but the totals differ | GL total; holder's overdue figures; `reconciles: false`, so WEB can say "the Purchases ledger and the accounts differ, ask your accountant" | `POP` or `SOP` |
| Holder not shipped, call failed, or `multiple_currencies` | GL total and GL's 30-day overdue | `GL` (basis `INVOICE_DATE_30`) |

The totals always come from GL. The holder only ever replaces the overdue half, and the reason for a fallback is logged (service, status, no figures).

**Additive response fields** (WEB declares them first, Playbook R6): per side, `overdueSource` (`GL`, `POP`, `SOP`), `overdueBasis` (`INVOICE_DATE_30`, `DUE_DATE`), and `reconciles` (boolean, absent when the source is GL). The existing `total`, `overdueTotal`, `overdueCount` keep their names and meaning, so nothing breaks while WEB catches up. WEB's label comes from `overdueBasis`: "older than 30 days" or "past due date".

## 5. Tasks and order (consumer-first)

| # | Item | Owner | Depends on |
|---|---|---|---|
| 1 | Confirm the shape in section 3 (or counter-propose), and say whether `overdueBasis = DUE_DATE` is available now on either side or waits for payment terms | POP, SOP (via CM) | none |
| 2 | WEB declares `overdueSource`, `overdueBasis`, `reconciles` on the owed tile and maps the two labels; unknown values show the neutral label, never a guess | WEB | none |
| 3 | Providers ship the two ageing reads, with fixtures in `fish-contracts` (strict, synthetic data) | POP, SOP | 1 |
| 4 | EA declares the two strict DTO mirrors and gateway methods, and decodes the fixtures through them (T8-style consumer test) | EA | 3 (fixtures) |
| 5 | EA reads both in parallel in `ComputeDashboardUseCase`, applies the section 4 rules, tests first (all three rows, plus a failing holder, plus a currency mismatch) | EA | 2, 4 |
| 6 | Run side by side for a month of real data; the log shows how often `reconciles` is false and why | EA, CM | 5 |
| 7 | GL may retire its overdue computation from the summary route (its decision); totals stay | GL | 6 clean |

**Rollback:** each step is a separate release and the fallback to GL is the default, so reverting step 5 returns today's behaviour exactly.

## 6. Open points

- Whether SOP can state `DUE_DATE` for receivables before payment terms ship on the sales side (until then its basis is `INVOICE_DATE_30`, which is the same label as GL's, but from the sub-ledger).
- Who owns the reconciliation difference when `reconciles` is false: the Business Owner's accountant, not FiSH (preparation, not audit, Decisions Log 2026-10-16). The tile only says that it differs.
- Payroll, Fixed Assets and IM follow the same principle for their own dashboard figures when those tiles are added; nothing is planned for them here.
