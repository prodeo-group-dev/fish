# Women-Owned SME Support — Build Brief (design-only, no code yet)

**Status: build brief, 2026-08-31. Nothing built yet.** Source: `docs/FiSH_Women_SME_Problem_Case.docx` (Prodeo Capital, working draft, August 2026) — the problem case for why women-owned SMEs in the Mano River region can't get formal credit, and where FiSH fits. This brief translates that document into what FiSH would actually need to build, checked against real current code state (not guessed), per the same discipline the rest of `docs/` uses.

---

## 1. The ask, restated narrowly

The source document's core claim: women traders have real repayment histories but no lender-legible record of them. FiSH's proposed role (source §5) is not to lend — it's to turn ledger activity into a "repayment picture" that AFAWA/We-Fi/MUNAFA-style partner banks and gender-lens funds will act on.

---

## 2. What already exists that this leans on (verified against code, not memory)

- `MoneyVelocityRoutes.kt` + `MeRoutes.kt` (`GL/`, shipped [`228e84d`](https://github.com/prodeo-group-dev/fish-fish-gl-engine/commit/228e84d)) already compute a real-time cash-velocity KPI off the posted ledger, surfaced on the tenant dashboard. This is the seed of the source doc's "repayment picture" — the ledger-derived signal already exists; what's missing is a funder-facing shape for it (§4).
- SL's tax/currency settings (`docs/SL/SL_Tax_And_Currency_Settings.md`) are the most complete of the four Mano River jurisdictions, and SL is already the confirmed entry point in the GTM sequencing — not a disposable pilot market, but the arrowhead into the wider Mano River operation, which is itself the arrowhead into the much larger Nigerian market (Phase 2, timed past Nigeria's 2027 general election). The source doc's own four-country framing sits inside that same sequencing, not apart from it.
- Osusu (rotating savings/microlending) is the formal analogue of the savings-group behavior the source doc describes women already using in place of credit (source §2.1) — not a new market to chase, an existing adjacent product aimed at the same behavior.

---

## 3. Gaps that block this specific offer, not general FiSH gaps

Four, each blocking, none guessed around:

1. **Currency scope excludes 3 of the 4 named countries.** The 2026-08-22 decision was that only `SLE` is onboarded across the Mano River operation; LRD (Liberia) and GNF (Guinea) are documented for reference only, `onboarded: false`. The source doc's funding table (§6) names AFAWA and the Mano River/AfDB $4.2M cross-border trader grant, both explicitly Liberia-inclusive. This isn't a question of whether Liberia/Guinea matter — the whole Mano River region is the deliberate arrowhead into Nigeria, so they do. It's a sequencing question: either the pilot stays SL-only first (consistent with SL's existing role as entry point into that arrowhead) and the Liberia-specific funder rows become the next step as Mano River build-out continues, or the currency decision needs revisiting sooner, before any Liberia-facing pitch goes out. **Not decided here — flagged for a decision, not picked.**
2. **No basic-phone channel.** WEB is a PWA (React/Vite) — it needs a smartphone and data. The source doc's own accessibility claim ("on a basic phone," source §5) has no corresponding USSD/SMS entry path anywhere in the codebase today.
3. **No consent/sharing mechanism.** Source §7 requires "no data sold to lenders without consent." `Role`/`Membership` today scope access within a tenant's own team, not to an external partner. There is no mechanism to grant a named external party read access to one tenant's data or export.
4. **No paying tenants yet.** Any funder-facing material drawn from this brief must describe the ledger/KPI engine as real and running, and describe a women-SME pilot as a plan — not conflate the two, per the standing correction already applied to the pitch deck's own Ask slide.

---

## 4. The one concrete build: a funder-ready export

The smallest real step toward source §5/§7 (a "repayment picture" a lender will accept, "reported in a format funders already use") is to extend the existing money-velocity KPI plus a revenue/cash-flow history view into an export shaped for funder consumption, gated behind an explicit per-tenant consent grant.

**In scope for a first build:**
- A new read endpoint (working name, not final: `GET /companies/{companyId}/funder-export`) assembling cash-velocity trend, revenue/expense history over a requested window, and account-standing summary — all already derivable from posted `JournalLine`s, no new aggregate needed. Same "reports derive from tagged `JournalLine`s, never from operational aggregate state" pattern `AccountsPayableAging`/`AccountsReceivableAging` already established.
- A consent flag on the tenant (or company) that must be explicitly set before the export endpoint returns data to any caller other than the tenant's own authenticated members.

**Deliberately out of scope / parked, not guessed:**
- Exact field names/shape to match 2X's or AFAWA's own reporting templates — the source doc names these programs but not their field-level schemas. Needs a real template pulled from AFAWA/We-Fi/2X, not an invented one.
- Who the "caller other than the tenant" actually is — a partner bank's own system calling an API, or a PDF/CSV the tenant downloads and forwards themselves? The source doc doesn't specify a delivery mechanism, and picking wrong here changes the whole authorization model.
- The basic-phone channel (§3.2) — a separate, larger build, not scoped by this brief.

---

## 5. Recommended sequencing

1. Decide the currency-scope question (§3.1) before any Liberia-facing material goes out — a business decision, not an engineering one.
2. Confirm the export's actual consumer (§4, second parked item) — determines whether this is an API integration or a document export, which are very different builds.
3. Build the consent flag + export endpoint, scoped to SL tenants only, matching current currency/tax coverage.
4. Revisit the basic-phone channel and multi-country currency support only once a real pilot is confirmed, not ahead of it — matches the "minimal builds" discipline already applied elsewhere in this project: even a confirmed, designed feature stays deferred until it's load-bearing for the current phase.
