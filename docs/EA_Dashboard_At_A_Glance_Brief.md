# Business Owner dashboard: "at a glance" additions (brief)

**Status:** brief only, 2026-10-11, from EA. Direction approved by Femi in the EA session the same day (see `Decisions_Log.md`); not a build go-ahead. Nothing is built.
**Prompted by:** a comparison of freee Accounting's home screen (Japanese help article, "個人事業主版 freee会計のホーム画面の見方", updated 2026-03-18) with our current Owner-Admin dashboard, read in code on 2026-10-11, not on the live screen.

## What the Owner sees today
Administration, Dashboard (Owner-Admin only): financial pulse (money velocity, expense velocity, sales-to-expense ratio); business snapshot (sales today, inventory value, cash flow, profitability); accounting ratios (four collapsible groups); a verification banner. Source: `WEB/src/components/EaTab.tsx`, `GlDashboard.tsx`, `DashboardRatios.tsx`; backend `EA .../DashboardRoutes.kt`, `ComputeDashboardUseCase`.

Where we are ahead of freee: the velocity gauges, the accounting ratios, and inventory value.

## The gap
Our dashboard describes performance. freee's also says what needs the owner today. Approved order of additions:

1. **"Needs your attention" box.** Each line one tap to the item:
   - Pending approvals. EA already has `GET /tenants/{t}/companies/{c}/approvals-queue` (`ComposeApprovalsQueueUseCase`), composing SOP customer returns, IM stock adjustments, POP supplier returns and HR payroll runs, read-only, each item carrying `source` + `id` to deep-link. **WEB does not call it today.**
   - Overdue receivables and payables. The aging data exists and WEB has `AgingReport.tsx` / `api/agingReports.ts`, but only as a Finance report.
   - Outstanding verification (already a banner; fold it in).
2. **Money owed to you / money you owe**: two plain totals, the overdue part highlighted.
3. **Next due**: the 5 nearest upcoming payments and collections (freee shows 5, nearest first; overdue items shown oldest first when any exist).
4. **Cash over time**: a small balance trend. Needs history we do not expose. The GL cash and bank books were deployed 2026-10-11, which may unblock it; to be confirmed with GL.

## Routing (per CLAUDE.md)
- Screens are WEB's to build (front-end coordination). EA supplies the data contract.
- Backend: add the attention summary and receivable/payable totals to EA's dashboard response (or a sibling route). The response is strictly decoded by GL/POP/IM/SOP-side mirrors only for `/me`; the dashboard response is consumed by WEB, so WEB declares any new field first. **`GET /me` stays unchanged.**
- Only CM pushes, merges and deploys.

## Not verified (to check before building, not assumed here)
- The exact shape of GL's aging endpoints and whether they give one total per side cheaply.
- Whether SOP/POP expose due dates in a list that can be sorted into "next due" without a fan-out per record.
- Whether the approvals queue is fast enough to call on every dashboard load, or should load lazily after the tiles.
- Whether a non-Owner staff role should ever see any of this (today the whole dashboard is Owner-Admin only; keep that).

## Deliberately not copied from freee
Bank-feed-driven items (unmatched statement lines, book vs. bank balance side by side) wait on bank reconciliation. A tax-return guidance panel only makes sense where a jurisdiction's tax settings exist.
