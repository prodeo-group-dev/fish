**FiSH GL / The Purse**

*A Digital Credit & Ledger Infrastructure for Sierra Leone's Agrifinance Ecosystem*

**Business Plan — Draft v1**

Prepared for internal planning purposes. Confidential.

# 1\. Executive Summary

FiSH GL (the ledger and credit-scoring engine) and its consumer-facing product, The Purse, together form a digital financial infrastructure layer aimed at Sierra Leone's most persistent development-finance bottleneck: the inability of smallholder farmers and SMEs to access formal credit, despite strong demand for the crops and goods they produce.

Rather than competing directly with large agribusiness producers, commodity traders, or government microcredit schemes — all of whom are already well capitalised and active in Sierra Leone's agrifood sector — FiSH GL positions itself as the underwriting and data layer those players lack. It digitises informal Osusu (rotating savings) practices, layers in social-graph-based micro-lending, and builds the transaction history needed to make smallholders and SMEs "investible" in the terms used by the World Bank's own analysis of the sector.

The initial go-to-market wedge is agri-lending tied to Sierra Leone's rice value chain — the single largest, most policy-supported, and most clearly quantified financing gap in the country's economy — with an architecture (SIM Toolkit/USSD access, gold-referenced treasury, ECOWAS-aware settlement design) built to extend into the wider Mano River Union over time.

# 2\. The Problem

## 2.1 A national and regional financing gap, not a production gap

Sierra Leone imports over $160 million of rice annually despite favourable agronomic conditions (3,800mm of annual rainfall; 5.4 million hectares of arable land, 75% of it uncultivated). Regionally, ECOWAS produces roughly 24 million tonnes of rice per year against demand of over 34 million tonnes, importing the shortfall at a cost of approximately $3.5 billion annually — a gap the region has committed to closing by 2035 through a $24 billion Regional Rice Roadmap.

This is not, primarily, a shortage of land, labour, or even capital at the macro level. Large-scale investment is already flowing into Sierra Leone's agrifood sector: outgrower schemes, multinational commodity traders, and DFI-backed SME facilities are all active. The persistent bottleneck is underwriting — the ability to determine, cheaply and reliably, which smallholder farmers and SMEs can be trusted with credit.

## 2.2 Existing efforts have not closed the gap

* Government MUNAFA Fund: disbursed to over 6,800 SMEs by 2023, yet a national survey found only 8.5% of all firms had ever received microfinance funding — the World Bank attributes this to poor targeting and fragmented delivery, not lack of capital.

* Munafa (NGO, unrelated to the government fund): effective but small in scale — two branches, under 2,000 beneficiaries.

* Conventional bank/DFI facilities (e.g. the EIB–Vista Bank €10m SME line): use traditional collateral-based underwriting, which structurally excludes the large informal smallholder and micro-SME population.

The result: capital exists, demand exists, but the connective tissue — trustworthy, low-cost, digitally native credit data — does not.

# 3\. Market Opportunity

## 3.1 Sierra Leone

* Rice import substitution: c. $160m annual spend that could, in part, be redirected to domestic value chains if production and financing scale together.

* Agriculture employs c. 65% of Sierra Leone's labour force and contributes c. 60% of GDP — overwhelmingly via smallholder, subsistence-adjacent farming that is functionally unbanked.

* Government tailwinds: the National Agricultural Transformation Programme (2023) and an active Agrifood Investor Summit (Oct 2025, 25 international \+ 40 domestic firms) show strong policy and capital interest in the sector — but almost none of it targets the underwriting layer directly.

## 3.2 Regional (ECOWAS / Mano River Union)

* The ECOWAS Regional Rice Roadmap (2025–2035) targets 34 million tonnes of annual milled rice production, backed by an estimated $24 billion investment programme — a decade-long tailwind for agri-finance infrastructure specifically.

* Neighbouring Liberia and Guinea share similar informal-economy and access-to-finance profiles, offering a natural expansion path once the Sierra Leone model is proven.

# 4\. Competitive Landscape and Positioning

The instinct to avoid this space because "the numbers point in a direction" — implying serious, well-capitalised competition — is correct at the production and trading layer. It is not correct at the financing/data layer, which remains structurally underserved even as production-side investment accelerates.

| Player | Role in the value chain | What they lack (the gap FiSH GL fills) |
| :---- | :---- | :---- |
| West African Rice Company (WARC) | Outgrower model scaling smallholder rice production in Sierra Leone | No embedded credit-scoring or digital ledger to underwrite its own outgrower farmers |
| Louis Dreyfus Company | Global rice merchandiser; potential future off-taker of Sierra Leonean rice | No local financial-inclusion infrastructure; sources rather than finances smallholders |
| EIB / Vista Bank SME facility | Conventional €10m SME lending facility across rice, cocoa, palm oil, cassava | Traditional underwriting; no alternative/social-graph credit data for informal farmers |
| MUNAFA Fund (Government) | National microcredit scheme distributed via financial service providers | Reach under 10% of firms; targeting and data-fragmentation issues per World Bank review |
| Munafa (NGO, Entrepreneurs du Monde) | Social microfinance with farmer-tailored loans since 2019 | Small scale (branches in Freetown slums); no digital ledger or regional interoperability |

The strategic position for FiSH GL / The Purse is therefore not to compete with WARC, Louis Dreyfus, or government microcredit schemes for market share — it is to sell underwriting and credit-scoring infrastructure into their existing supply chains and lending programmes. This is a materially better fit for a company at this stage: lower capital intensity than becoming a producer or trader, a clearer and narrower value proposition, and a customer base (institutions, not thousands of individual farmers) that is far cheaper to acquire.

# 5\. Product & Technology

## 5.1 Core components

* FiSH GL — the ledger engine: records contributions, withdrawals, advances, and repayment history across Osusu-style savings circles and individual/SME accounts.

* The Purse — the consumer/SME-facing product: automated Osusu/thrift savings, social-graph-based micro-lending ("Osusu Advance"), and an agri-harvest-cycle lending product with repayment timed to harvest and sale.

* Access layer — SIM Toolkit (STK) / USSD menus provisioned via MNO partnership (Orange, Africell), rather than a locked/subsidised handset. This removes hardware dependency, works on any SIM-capable phone, and sidesteps the consumer-protection concerns associated with device-locking as loan collateral.

* Treasury layer — pooled deposits laddered into Bank of Sierra Leone T-bills for short-duration liquidity, with a smaller gold-referenced reserve tranche for longer-duration capital preservation, taking advantage of Sierra Leone's own emerging gold sector (Baomahun Gold Project, first production 2026\) as a naturally correlated local hedge against Leone volatility.

## 5.2 Credit-scoring approach

Rather than relying on collateral, the credit-scoring engine draws on transaction history within the ledger (Osusu contribution consistency, repayment behaviour, social-graph vouching) and, for the agri-lending product specifically, harvest-cycle cash-flow modelling — a structured, seasonal underwriting problem suited to quantitative modelling techniques (time-series forecasting, risk segmentation) rather than ad hoc judgment.

# 6\. Regulatory Pathway

* Dual-track registration: SACCO status under Sierra Leone's Cooperative Societies Act 1977, with NaCCUA affiliation for governance and audit, run in parallel with a Bank of Sierra Leone Sandbox application covering the alternative credit-scoring engine and digital wallet.

* Progression to full PSP/MFI licensing, or a partnership with an existing licensed bank, in Phase 2\.

* Tiered KYC via phone number plus Voter ID/National ID, aligned with FIU requirements.

* Institutional relationships to build in parallel: SMEDA (as coordinating/advisory partner and potential data-sharing counterpart), the MUNAFA Fund (as a potential channel for its existing lending capital, targeted more effectively via FiSH GL's data), and ICASL (as the standards body whose recognition gives FiSH GL's output credibility with banks and auditors).

# 7\. Revenue Model

* Osusu/thrift administration fee: 1–2% on payout cycles.

* Micro-overdraft / agri-advance interest margin.

* Treasury yield share from pooled deposits (T-bills and gold-referenced reserve).

* B2B credit-scoring-as-a-service fees charged to outgrower schemes, commodity buyers, and SME lenders who need underwriting data on smallholders/SMEs in their supply chain (the core "sell into the competition" revenue line).

# 8\. Phasing & Funding Requirements

| Phase | Focus | Duration | Funding Required |
| :---- | :---- | :---- | :---- |
| Phase 0 — Foundation | Legal structuring (UK Ltd \+ SL entity), SACCO/Cooperative registration prep, BSL Sandbox application, initial MoUs (SMEDA, ICASL) | Months 1–6 | $110,000 |
| Phase 1 — Pilot | USSD/STK gateway build, ledger engine (FiSH GL core), pilot cohort of smallholder rice farmers \+ 1 anchor buyer (e.g. an outgrower scheme) | Months 6–12 | $150,000–$200,000 |
| Phase 2 — Commercial Expansion | Credit-scoring engine live, device-agnostic onboarding via MNO partnership, agri-lending book scale-up, treasury layer (T-bills \+ gold-referenced reserve) | Months 12–24 | $250,000–$400,000 |
| Phase 3 — Regional Expansion | Liberia/Guinea (Mano River Union) cross-border wallets, PAPSS settlement integration | Year 3+ | To be raised on Phase 2 traction |

Bank of Sierra Leone statutory minimum capital requirements (estimated $100,000–$250,000, to be confirmed) apply once progressing beyond Sandbox status and are additive to the operating budget above.

# 9\. Founder Positioning

This venture is intentionally structured to be led from a position of financial and professional credibility rather than pure entrepreneurial risk-taking:

* UK-based trading/consultancy income (leveraging EPAT and CQF quantitative finance training) funds the initial Sierra Leone investment tranches, keeping core income in a stable, well-regulated jurisdiction while capital is deployed into Sierra Leone.

* A PgDip in Accounting (Ulster University, from September) followed by professional qualification through CAI, CIMA, and/or CIPFA builds the accounting and public-finance credibility needed to engage SMEDA, the Ministry of Finance, and eventually ICASL on equal terms.

* ICASL membership (Associate/Fellow route, on the strength of a recognised foreign qualification) is targeted as a later-stage step, once a first professional qualification is complete — giving standing within Sierra Leone's own audit and standards regime rather than approaching it as an outsider.

* The FX/commodity risk-advisory practice (drawing on CQF/EPAT skills) can run as a parallel UK-based income stream and functions as a live case study for the same risk-modelling discipline the credit-scoring engine requires.

# 10\. Risks and Mitigations

* Currency risk: Leone volatility (c. 6% depreciation over the past 12 months, with periods of appreciation) affects any SLE-denominated investment. Mitigation: structure investment tranches in USD/GBP, convert only at point of local spend; use gold-referenced reserves as a partially correlated hedge given Sierra Leone's own gold export growth.

* Competitive/positioning risk: entering the production or trading layer directly would pit a fledgling company against Louis Dreyfus-scale traders and DFI-backed facilities. Mitigation: the business is explicitly scoped as an infrastructure/data-layer play sold into that ecosystem, not a competitor within it.

* Regulatory timeline risk: SACCO registration and BSL Sandbox approval may not clear on the stated timeline. Mitigation: dual-track structure avoids being blocked by either single pathway; phased funding avoids over-committing capital ahead of regulatory clearance.

* Execution/bandwidth risk: the founder's qualification pathway (EPAT, PgDip, CAI/CIMA/CIPFA) runs concurrently with early venture stages. Mitigation: Phase 0 is deliberately limited to relationship-building, monitoring, and light documentation — no capital commitment or entity registration — until qualification milestones are reached.

# 11\. Immediate Next Steps

* Maintain informal contact with the Sierra Leone-based collaborator on The Purse proposal; do not commit timelines.

* Monitor ECOWAS Rice Roadmap funding rounds, Baomahun gold production ramp-up, and Leone/USD movements at low time-cost (background awareness only).

* Defer CAC incorporation, sector licensing, and capital deployment until at least the first professional qualification (CAI, CIMA, or CIPFA) is complete.

* Revisit this plan at the completion of the PgDip (targeted September start) to convert it into an active Phase 0 workplan.