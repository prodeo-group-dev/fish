# UAT sitting 2026-10-10: findings by owner (CM)

Source: the tester's report (`docs/reports/FiSH_UAT_Sitting_2026-10-10.md`, kept in Femi's FiSH checkout) plus CM's service-log reads for 11:15-11:40 UTC. New Tenant `2f3fc119-f5df-49a6-854a-5ee731f639d2`, Business One `018f624b-bbf0-4f59-995f-2cd5e10ab80c` (GBP), Business Two, Sitting School.

## What the logs prove (clean)
- EA: `POST /api/tenants` 201 once (11:18:18); company-registration 200 x3 (11:18:21, 11:20:10, 11:20:53); two expected `GET /api/me` 401s during setup; membership invite 201.
- GL: no 4xx/5xx on real routes, no `WOULD REFUSE`, no `BLOCKED`, no `no_cash_account`, no currency refusal. Cash-book routes, receipts, payments, transfers, undo, reconciliation start/match, sales record-sale/collection, inventory receipt/issue: all 200/201. Cash sale settled into 1000 without a policy line.
- SOP, IM, HR, POP: each service's calls on the real routes 200/201 (exception below).
- The GL allow-list under enforce carried real SOP, IM, POP-context and HR(employee, team) traffic: no refusal.

## Findings

| # | Finding | Evidence | Owner |
|---|---|---|---|
| 1 | **PO line has no VAT category field; a SENT PO cannot be edited, so the three-way match is refused (400) for every order made in the UI.** PO currency defaults to USD, not the Company's. | POP 400 at 11:33:26 | POP + WEB |
| 2 | **Inventory dashboard tile "Couldn't load":** EA's dashboard calls the removed flat `GET /api/items` on IM (`EA/.../infrastructure/im/ktor_im_gateway.kt:23`, `listItems(bearerToken)`, no company id); WEB was checked and does not call it. Fix in EA: call `GET /companies/{companyId}/items` for the selected Company. | IM 404 x8 (11:18:43 ... 11:38:40) | **EA** (corrected 2026-10-11) |
| 3 | **No UI to collect payment** on a credit invoice, **no UI for a sales return / credit note**. | tester | SOP + WEB |
| 4 | **Bank reconciliation has no Complete control**; the match picker lists cash-book entries. | tester; GL 11:25:19, 11:25:40 | WEB (GL for the rule) |
| 5 | **Undo row shows raw `JournalEntryId(value=...)`** (journal_entry.kt:91 builds `"Reversal of $id"` from a value class); reversal row order odd. | tester; code | GL (text), WEB (order) |
| 6 | **School provisioning did not reach ER:** the school company was registered (3rd company-registration) but ER logged zero requests and WEB never offered "Set up school profile". Industry option read "School", not "Education". | ER log empty | EA (+WEB) |
| 7 | Stock receipt entered at 500/unit instead of 5: carrying value wrong (UAT scratch), no UI to correct; no warning on a unit cost far from the item's last cost. | tester; IM 11:30:55 | IM (+WEB) |
| 8 | POP "Receive delivery" left IM stock unchanged until IM's own receipt (seam B, known) and gives no quantity confirmation. | POP 11:32:57, IM 11:33:13 | POP, IM (GRNI note), WEB |
| 9 | Hours invoice shows no hours x rate; customer balance shows gross while lines show net. | tester | SOP + WEB |
| 10 | Download PDF opens the print dialog; mixed date formats; phone header covers 40-50% of the viewport; floating buttons overlap; company picker flat; narrow Cash Money-in form; "Cash" vs "Cash Book" label. | tester | WEB |
| 11 | `support@` recovery text still absent. | tester | WEB + CM (Cognito) |
| 12 | Internet scanners hit GL's public URL (404 on `/`, `/wp-json`, `/.svn/wc.db`): harmless today. | GL log | CM (WAF later) |

## Not run (carry to the next sitting)
Isolation (cross-Tenant URL 403), guardian billing (needs `SOP_ER_COMPANY_IDS`), registrar / T-ER1-2 cases, payroll / leave / expense / advance (incl. double-approve), sales return under enforcement, the AP double-count measurement (the match never reached GL), the old-Company 2150 call (checklist 1d), POP pay.

## Scheduling
Blockers for the next sitting: findings 1, 3, 4 (so Buy, Collect and Reconcile can complete). Then 2, 5, 6, 7. Layout items (10) go to the WEB queue by priority.
