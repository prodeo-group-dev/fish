# GL: tying the Fixed Asset Register to the ledger (UAT 2026-10-08, H1)

**Status: 2026-10-08. Scope and plan only; nothing built.** Written by the GL session. Trigger: the 2026-10-08 UAT found the Fixed Asset Register showing GBP 6,200 (Car 5,000 + Verification Laptop 1,200) while GL account 1200 showed 1,200: the Car has no GL posting. CM asked for the finding before any change; the evidence query (read-only, all companies) is with Femi, results pending. Companion to `docs/Opening_Figures_CSV_Upload_DDD_Design.md` (the "already owned" funding rule) and the Fixed Asset Register wiring (Phase 1, live).

## What the code says (GL master `da75fce`)

1. **Today's create path cannot leave an asset without a posting.** `CreateFixedAssetUseCase` posts the acquisition journal first and saves the asset only if the posting succeeds. `ALREADY_OWNED` is not "post nothing": it debits the asset account and credits the Suspense account (3910). The register's own `ImportFixedAssetsUseCase` uses the same path.
2. **The `fixed_assets` table (migration V20) predates posting-at-creation (2026-09-12).** It has no `created_at`, and it stores neither the asset account nor the acquisition journal entry. An asset created before 2026-09-12 is in the register with no GL posting, and nothing in the schema can say so.
3. **The register can never be tied to the ledger today, for any asset, because the link is not stored.** `ComputeFixedAssetRegisterUseCase` sums asset costs from the `fixed_assets` table alone. Each create call also chooses its own `fixedAssetAccountId`, so "register total versus account 1200" is not even a valid comparison when assets sit in different asset accounts.
4. **No path removes or voids an asset.** There is no delete; `dispose` posts a disposal. So a test asset (SN-VERIFY-001) cannot leave the register by a normal route, and reversing its acquisition entry (H2) alone would leave the register overstated.

Three candidate causes for the UAT figure, which the evidence query separates: (a) the Car predates 2026-09-12 and was never posted; (b) the Car was posted to a different asset account than 1200 and the UAT compared the wrong figure; (c) the Car's acquisition entry was reversed or is not POSTED.

## Scope

In: store each asset's link to its acquisition (entry id and asset account); a register-vs-ledger check computed from that link and shown on the register; a backfill rule for existing assets; a repair path for any unposted asset.
Out: depreciation or disposal postings (unchanged); a delete/void for assets (raised below as a question, not decided here); the opening-figures CSV upload.

## Plan

**P1. Additive migration (V31).** `fixed_assets` gains nullable `fixed_asset_account_id` and `acquisition_journal_entry_id` (both nullable: old rows stay valid). `FixedAsset` carries them; `CreateFixedAssetUseCase` sets both on every new asset in the same save. No change to any existing posting.

**P2. Backfill rule for existing assets (run once, reported, not silent).** For each asset with a null link: find POSTED entries in the same Company, dated on the asset's `acquisition_date`, whose description is `Acquisition - <name>` and which have exactly one debit line of the asset's cost. If exactly one entry matches, link it (asset account = that debit line's account). Zero or several matches: leave unlinked and list it. Nothing is guessed and no posting is created by the backfill.

**P3. The reconciliation check.** The register response gains, per asset, `glStatus` and in total `glCost`, `registerCost`, `difference`. Statuses: `LINKED` (entry exists, POSTED, not reversed, debit equals cost), `UNLINKED` (no link: legacy or unmatched), `ENTRY_NOT_POSTED_OR_REVERSED`, `AMOUNT_MISMATCH`. The total `difference` is the sum of cost over assets that are not `LINKED`. WEB shows it on the register. These are additive fields on the register response; every Kotlin reader of that response must declare them tolerant before GL ships (the additive-field rule), which I'd confirm with EA first.

**P4. Repair path for an unposted (legacy) asset.** Either (i) post a dated acquisition entry, debit the asset account, credit the Suspense account 3910, using the same "already owned" mechanism, then link it; or (ii) if the asset is a test or mistaken record, take it out of the register. (i) needs no new rule. (ii) needs the void/delete question answered.

## Open questions for Femi

1. Legacy unposted assets (the Car is the known one): post a dated opening entry against Suspense 3910 (so the balance sheet carries it and the Suspense balance flags it for proper itemisation), or something else?
2. Test assets (SN-VERIFY-001): should there be a supported way to void an asset record (with its acquisition reversed), or is a one-off data repair enough?
3. Backfill: is "exactly one matching entry, otherwise leave unlinked and list" the right rule, or should an unmatched asset block the register check until fixed?

## Order and gates

Evidence query result first (decides which of (a)/(b)/(c)); then P1 and P3 with tests first (migration, use case, route, register DTO); P2 as a reported one-off run; P4 per Femi's answer to question 1. CM reviews each; no production data is changed by GL. Consumers: WEB builds the register's reconciliation display on the contract above.
