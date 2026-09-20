# Northern Ireland — Jurisdiction Specification

**Status**: specification only, 2026-09-13. Grounded in dated, sourced research (Windsor Framework, current as of 2023 onward — not the superseded original NI Protocol). Deliberately short: unlike Republic of Ireland's MVP definition (`docs/IE/IE_MVP_Definition.md`, a genuinely new jurisdiction), Northern Ireland reuses almost all of the UK's own platform and integration work wholesale. This document exists to say so precisely, and to name the one place it doesn't.

## Why this is short

Purse names Northern Ireland as one of its four home markets (alongside UK, RoI, and Sierra Leone), but the original External Regulatory & Banking API research treated "UK" as one jurisdiction without splitting NI out. Confirmed research shows that was the right call for almost everything — NI is not a distinct regulatory jurisdiction for company registration, general tax administration, or banking. It genuinely diverges in exactly one place: VAT on goods.

## Company Registration — same as UK, no distinct integration work

NI companies register with the **same Companies House**, the **same API** (`api.company-information.service.gov.uk`), under the same unified regime since the Companies Act 2006. The only difference is cosmetic: NI company numbers carry an **"NI" prefix** (e.g. `NI030452`), the same convention Scotland uses ("SC"). This is a number-format detail, not an integration difference — the existing UK Companies House integration work (per the External Integrations spec) applies to NI Companies unchanged, with no special-casing beyond accepting the "NI"-prefixed format if any input validation currently assumes a bare numeric format.

## Tax administration — identical, with one dormant watch-item

HMRC administers Corporation Tax, PAYE, and National Insurance **identically** for NI and GB companies — same MTD APIs, same OAuth model, same rates, no NI-specific logic needed. **Watch-item, not a build item**: the Corporation Tax (Northern Ireland) Act 2015 grants Stormont a devolution power to set a distinct NI Corporation Tax rate. It has never been commenced — dormant law, not live policy. If this is ever activated, `RateStructure` would need a jurisdiction-within-jurisdiction concept it doesn't currently have (NI would stop being "just UK" for CIT purposes). Not a current gap; flagged so it isn't a surprise later.

## VAT — the one real carve-out (goods only, currently moot)

Under the Windsor Framework (in force since October 2023, replacing the original NI Protocol), Northern Ireland stays aligned with **EU VAT/excise rules for goods**, while **services follow standard UK VAT identically to GB**. The current mechanism:

- The **UK Internal Market Scheme (UKIMS)** lets an authorised trader declare goods moving GB→NI as "**not at risk**" of onward EU movement — a green-lane path with no tariffs and (from 1 May 2025) no supplementary customs declarations. "At risk" goods take a red-lane path with EU tariffs/declarations.
- NI↔EU/Ireland goods movements follow EU intra-EU VAT rules; NI traders use an **"XI"-prefixed VAT number** for EU-facing goods transactions; NI-to-EU consumer goods sales use the **OSS scheme**.
- Some UK-wide VAT reliefs (e.g. energy-saving materials) that were previously blocked in NI under the original Protocol now extend there under the Windsor Framework.

**This carve-out is currently moot for FiSH**: per `docs/IE/IE_MVP_Definition.md`'s own finding, VAT has no `TaxType` anywhere in the platform yet — this is a platform-wide gap, not an NI-specific one. When VAT computation is eventually built, NI-registered Companies trading goods cross-border (GB↔NI or NI↔EU/Ireland) will need this UKIMS/goods-vs-services distinction; a services-only NI Company needs nothing beyond standard UK VAT logic. Recorded here so the eventual VAT `TaxType` design doesn't have to rediscover it.

## Banking — same UK Open Banking framework, no separate status

NI-based banks (Bank of Ireland (UK) plc, Ulster Bank, Danske Bank, AIB Group (UK) plc) are FCA-regulated participants in the **same UK Open Banking Standard** as GB banks — several are named directly in the original CMA9 mandated-participant list, regardless of their Republic-of-Ireland-headquartered parent groups. No separate PSD2/Open Banking carve-out for NI. The UK banking-aggregator integration planned in the External Integrations spec (TrueLayer or equivalent) applies to NI Companies unchanged.

## Currency — GBP, no surprise

Northern Ireland uses GBP, uniformly with the rest of the UK. (NI banks issue their own GBP-denominated banknotes under Bank of England oversight, the same arrangement as Scotland — not a different currency, not a technical consideration for `Money`/`Company.baseCurrency`.)

## Conclusion for MVP purposes

**A Northern Ireland Company needs no new platform work beyond what the UK MVP already requires.** Treat NI as a UK Company for Core Ledger, GL reporting, Corporate Income Tax, Company Registration integration, and Banking integration — all directly reusable. The only genuine future consideration is the goods-VAT carve-out above, and that only becomes relevant once VAT itself is built as a `TaxType` platform-wide, and only for NI Companies that actually trade goods cross-border rather than services.

## Sources

- [Companies House — live NI-prefixed register entry](https://find-and-update.company-information.service.gov.uk/company/NI030452)
- [gov.uk — Trading and moving goods in and out of Northern Ireland](https://www.gov.uk/guidance/trading-and-moving-goods-in-and-out-of-northern-ireland)
- [gov.uk — VAT: Northern Ireland and the EU (HMRC internal manual)](https://www.gov.uk/hmrc-internal-manuals/vat-northern-ireland-and-the-eu)
- [ICAEW — The Windsor Framework: VAT and duty implications](https://www.icaew.com/insights/tax-news/2023/feb-2023/the-windsor-framework-vat-and-duty-implications)
- [Open Banking Ltd — Regulatory](https://www.openbanking.org.uk/regulatory/)
