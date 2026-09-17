# Nigeria Compliant Hosting — A Real Business Opportunity, Not Just a Compliance Cost

**Status**: vision/design-only, 2026-09-13. Nothing built. This document corrects an overclaim made earlier the same day (in `docs/FiSH_Localization_Principle.md` and a board report draft) — that Nigeria's 2027 data-localization deadline was an unsolved infrastructure problem. It isn't. That correction is what turned this from a risk into an opportunity worth writing down properly.

## The opportunity, stated precisely

Nigeria's central bank has a real, dated mandate (2027) forcing financial institutions to keep data in-country. **Every financial institution operating in Nigeria faces this same deadline** — not just FiSH. Compliant infrastructure already exists (below), but most competitors are almost certainly built on AWS, Azure, or GCP — none of which have a live Nigerian region. **Whoever gets there first, correctly architected, has a real edge with every Nigerian financial-institution prospect for whom this deadline is a live concern.**

## The correction that opened this up

Earlier the same day, this constraint was described (in this project's own docs and a board report) as effectively unsolved — "AWS has no region in Nigeria" got summarized as "no compliant in-country hosting option exists." That summary was wrong, confirmed by direct research:

- **Huawei Cloud already operates a live, customer-provisionable hyperscaler region physically inside Nigeria** — launched December 2024, explicitly marketed for CBN/NDPC data-sovereignty compliance, with named commercial customers already using it (e.g., OPay).
- **Multiple Tier III-certified, carrier-neutral colocation facilities already operate in Lagos**, independent of any hyperscaler — Rack Centre, MDXi (MainOne/Equinix), and Africa Data Centres — already serving banks and fintechs today.
- Azure, Google Cloud, and Oracle genuinely have **no** live Nigerian region (nearest are Johannesburg/Cape Town/Nairobi) — so this isn't a gap unique to AWS; it's a gap shared by most of the industry's default infrastructure choices.

This means the real fact is: **a compliant path exists today, it just isn't the default choice most companies (including FiSH, today) have made.** That's exactly the shape of an early-mover opportunity, not a blocked problem.

## The two possible business shapes — a real choice, not resolved here

1. **Internal-only**: FiSH architects its own Nigerian-tenant hosting on Huawei Cloud or a Lagos colocation provider, satisfying the 2027 mandate as a normal cost of doing business there. Straightforward, lower-risk, no new product.
2. **Productized**: FiSH (or a Prodeo Group entity) packages this as a service — "we already know how to get a Nigerian financial institution compliant with the 2027 data-localization mandate" — sold to other institutions who face the identical deadline and haven't solved it, most of whom are on infrastructure that doesn't. This could range from consulting/advisory (a lighter lift) to actually hosting other institutions' data on infrastructure FiSH has already stood up (a heavier, more infrastructure-business commitment, closer in shape to a hosting provider than a ledger company).

These are genuinely different commitments — (2) pulls FiSH toward being an infrastructure business in Nigeria specifically, which is a different kind of company than a ledger/ERP platform, even if the underlying technical work overlaps. Worth a deliberate choice between them, not a default assumption that "productize it" is obviously right just because the opportunity is real.

### A specific version of (2) considered and ruled out, plus one that actually holds up

One concrete idea floated: could Prodeo Group become "the portal through which AWS provides service in Nigeria/Africa" — i.e., the local channel that brings AWS's own infrastructure into the market? Checked directly, this doesn't hold up as conceived:

- **AWS Outposts can't be resold to third parties** — each unit is tied to a single AWS account, and Outposts isn't on AWS's own partner resale list. A company can host the hardware, but can't repackage it as an "AWS-in-a-box" service for unrelated customers.
- **AWS Local Zones are AWS-built and AWS-operated only** — never partner-operated, and Nigeria already has one anyway (see Phase 1 above).
- The one real precedent for a partner extending AWS into an underserved market — **AWS Wavelength + Orange in Morocco and Senegal (2024)** — runs through AWS's formal Wavelength telecom/carrier program (Verizon, Vodafone, Orange...). Prodeo Group isn't a telecom operator, so this specific mechanism isn't open.

**What does hold up**: the **AWS Partner Network (MSP/Solution Provider track)** is real, active, and open to a company like Prodeo Group — not as "AWS's portal into Nigeria" (AWS already has its own Lagos Local Zone), but as a **services business helping other Nigerian financial institutions get CBN-compliant on infrastructure that already exists** (Huawei Cloud, AWS's Lagos Local Zone for workloads that fit its constraints, or Lagos colocation). This is a legitimate shape for option (2) above — services/expertise, not infrastructure ownership — worth folding into that decision rather than treated as a separate idea.

## Why this stays gated, not queued

The same reasoning as `docs/Inter_Tenant_Trade_Automation_Vision.md`: this competes for the same thin (currently solo-founder) team's time as the active RoI/VAT MVP work, and — per `docs/External_Regulatory_And_Banking_API_Integrations_Requirements_Specification.md` and `docs/FiSH_Localization_Principle.md`'s own Nigeria gating — Nigeria market entry generally is already deliberately deferred behind the country's own Open Banking rollout actually completing.

**One genuine nuance worth flagging, not resolved here**: the hosting/compliance opportunity above may not need to wait for that same gate. Open Banking rollout maturity is specifically about *bank-data-sharing API access* — the 2027 data-localization mandate and the hosting decision it forces are a separate concern that could, in principle, be pursued (or at least explored) independent of whether FiSH has live banking integrations in Nigeria yet. Whether that's a reason to move faster here than on the rest of Nigeria market entry is a real strategic question, not a default "yes."

## Decided — a staged plan, not a permanent choice

**Phase 1, decided 2026-09-13: Huawei Cloud first — re-opened and confirmed, not assumed.** Before locking this in, a genuine alternative was checked directly: could FiSH stay on its existing cloud provider by using **AWS's own Lagos Local Zone** (live since January 2023, hosted in Rack Centre's facility) instead of adopting a second cloud provider? Checked against the platform's real architecture, this option has two confirmed, specific problems, not just inconvenience:

- **ECS on AWS Fargate — the exact compute model every one of FiSH's six services runs on — is explicitly unsupported in Local Zones**, per AWS's own documentation. Using Lagos would mean abandoning Fargate for self-managed EC2 containers specifically for Nigeria, a real re-architecture, not a lift-and-shift.
- **The Lagos Local Zone's control-plane depends on its *parent region* — `af-south-1`, Cape Town, South Africa, not Nigeria.** IAM, API calls, and CloudTrail run there regardless; Secrets Manager has no confirmed Local Zone presence either, so those calls likely cross to Cape Town too. Whether that satisfies Nigeria's actual data-localization law is genuinely unresolved — no regulator or legal source found addresses this specific dependency. Standing up a Local Zone doesn't cleanly answer "is this actually in-country" the way the 2027 mandate needs answered.

Huawei Cloud's own full-service parity to a complete region elsewhere wasn't confirmed either — but it doesn't carry that same structural half-measure problem: it's a standalone hyperscaler presence physically in Nigeria, not an extension whose control-plane quietly depends on infrastructure somewhere else. **Huawei Cloud stays Phase 1**, now for a verified reason rather than an assumed one. Lagos colocation (Rack Centre / MDXi / Africa Data Centres) remains a live option to revisit later, not ruled out.

**Phase 2, conditional: invest in owning infrastructure, if the figures agree.** The explicit instruction is to treat Huawei Cloud as a starting point, not an endpoint — **if a real financial analysis shows the numbers support it** (cost of sustained Huawei Cloud usage vs. the capital cost of owning infrastructure directly — a data-center build, a stake in a facility, or equivalent), **Prodeo Group invests in owning its own Nigerian infrastructure** rather than remaining solely a Huawei Cloud customer indefinitely. This is explicitly conditional, not a foregone conclusion — "if the figures agree" is a real gate, not a formality. **The financial analysis itself is a genuine open action item, not yet done** — someone needs to actually run the comparison before Phase 2 can be decided either way.

## Open questions

1. **Internal-only vs. productized** (above) — a real strategic choice, not a technical one.
2. **The Phase 2 financial analysis itself** — cost of sustained Huawei Cloud usage vs. capital cost of owning infrastructure directly. Not started; this is the concrete next action item this document surfaces, and Phase 2's own decision depends entirely on it.
3. **Does pursuing this require Prodeo Group's own Nigerian legal entity** (already decided in principle per the Localization Principle doc) **to be stood up first**, or could early technical exploration happen before that's formed?
4. **Timing relative to the rest of Nigeria market entry** — the nuance below: does this jump the existing Nigeria gate, or wait behind it?
5. **Who else in Nigeria is already solving this**, and how — worth a real competitive-landscape check before committing to either business shape, not assumed to be greenfield.

## Concrete gating condition

Revisit once Nigeria is actually prioritized as a near-term market (per the existing gating in `docs/FiSH_Localization_Principle.md` and the External Integrations spec) — **or sooner, specifically to explore Open Question 4 above**, if there's appetite to treat the hosting/compliance angle as a faster-moving opportunity distinct from the rest of Nigeria's market-entry timeline. Until either trigger, this stays documented, not built. **Phase 1 (Huawei Cloud) and the Phase 2 financial analysis (Open Question 2) can both start independent of this broader gate**, since they're prerequisites to *any* Nigerian hosting decision, not tied to when Nigeria market entry itself is prioritized.

## Relationship to other documents

Corrects `docs/FiSH_Localization_Principle.md`'s original framing of the AWS Nigeria-region gap (that document is being corrected alongside this one, same day). Sits alongside `docs/Inter_Tenant_Trade_Automation_Vision.md` as a second explicitly-gated, forward-looking opportunity captured precisely so it isn't lost — neither competes with the active RoI/VAT MVP work for engineering time right now.
