# Whistleblowing / Safe Reporting System — Domain-Driven Design (design-only, no code yet)

**Status: design scoping, 2026-08-20. Nothing built.** Recognized the same day it was needed: `docs/HR_Payroll_DDD_Design.md` §5's Performance Review design hit a real gap — its category-based, pattern-triggered upward-appraisal escalation (UC-SA5) can never catch a genuinely serious incident reported by only one person. Rather than build a bespoke fix inside Performance Review, the gap was recognized as a symptom of a missing general capability: employees need to be able to report serious misconduct (harassment, discrimination, bullying, safety, financial misconduct, safeguarding) **at any time, independent of whether any particular cycle or process happens to be running.** This document scopes that capability, same "record the decision, don't build it yet" treatment already given HR/Payroll and Lending before they were designed in full (`docs/DDD_Design.md` §2.3/§2.7's own closing lines).

**Lives at the `FiSH/` top level, not nested inside `docs/HR_Payroll_DDD_Design.md`, deliberately.** A report of financial misconduct or a safety concern isn't an HR/Payroll matter any more than it's a GL Engine one — this needs to work for any employee across any of the four ventures (Purse, Scrip, Osusu, BuzzMe) or a B2B tenant, about anything serious, regardless of whether HR/Payroll, Performance Review, or any other module is even involved in the specific incident. Same reasoning that already separated Lending and HR/Payroll from the GL Engine applies here a second time: this is a sibling system, not a package of the thing that happened to surface the need for it.

---

## 0. Relationship to other systems

- **Zero FiSH/GL Engine involvement.** No financial transactions, same "financial effect only, never operational detail" boundary (`docs/DDD_Design.md` §2.1) that already keeps HR/Payroll's `Employee` and Performance Review's `PerformanceReview` out of the Ledger.
- **Not a subdomain of HR/Payroll.** Genuinely broader — HR/Payroll's own scope is staff cost analysis, performance review, and staff development (`docs/HR_Payroll_DDD_Design.md` §2); this system needs to handle reports that have nothing to do with any of those (e.g. a financial-misconduct report about a non-staff matter, a safety concern unrelated to any Employee).
- **The one confirmed consumer so far: Performance Review's escalation path.** `docs/HR_Payroll_DDD_Design.md` §5 already names the likely destination for an escalated report as the same 3-person committee designed for upward-appraisal escalation (Head of HR + the safeguarding/compliance role holder + Legal/Compliance counsel, `docs/UK/Staff_Appraisal_360_Requirements_Use_Cases.md` NFR-SA04) — **reused here as the default recipient, not re-invented**, since the committee's whole shape (independent, restricted, no single member can suppress a case) was designed exactly for this kind of decision. Whether every category of report routes to this same committee, or only the ones that overlap with appraisal-adjacent conduct, is flagged in §3, not assumed.
- **Resolved 2026-08-20: build vs. buy — buy.** A licensed third-party whistleblowing/ethics-hotline provider, not an in-house build. This has a real, deliberate consequence for how much of this document remains live design surface — see §3.

---

## 1. Ubiquitous Language

| Term | Meaning |
|---|---|
| **Report** | A single submission describing a serious concern — category, description, optional evidence, submission timestamp. The core aggregate of this system. |
| **Reporter** | The person filing a Report. May be anonymous — see §3's open question. |
| **Category** | One of a pre-defined set of serious-concern types. Reuses the same category taxonomy already named in `docs/UK/Staff_Appraisal_360_Requirements_Use_Cases.md` UC-SA5 (harassment, discrimination, bullying, safety/safeguarding-adjacent conduct) rather than inventing a second, divergent list — extended here to also cover **financial misconduct**, since that's a real category this broader system needs that appraisal-escalation never did. |
| **Escalation Committee** | The same 3-person restricted committee already designed for Performance Review's upward-appraisal escalation (§0) — reused as this system's default review body, not a new governance structure. |

---

## 2. Bounded Context

One bounded context, standalone — sibling to Lending, Scrip, Osusu, BuzzMe, and HR/Payroll, not nested inside any of them (§0). Whether it ends up as its own separate codebase/deployment or shares infrastructure with HR/Payroll (given the one confirmed cross-reference is to HR/Payroll's escalation committee) is genuinely open — flagged in §4, not decided here, the same "record the split, don't force the deployment question yet" treatment `docs/HR_Payroll_DDD_Design.md` §2 gave its own three subdomains.

---

## 3. What "buy" changes about this design

**The `Report` aggregate below is now superseded, kept for history rather than deleted.** With a licensed third-party provider holding the actual submission data, `com.theprodeogroup.fish` (or wherever HR/Payroll ends up living) has no reason to model, store, or own `Report` at all — that's the vendor's domain model, not this project's. The design work that's actually still live is narrower: **how does the Escalation Committee (§0/§1) receive and act on an alert from the vendor platform?** That's an integration/access question (who on the committee gets vendor-platform accounts, how an escalation surfaces to them, whether any reference/summary needs to exist inside FiSH-adjacent systems at all) — not a domain-modeling question. Not designed further here; needs its own pass once a specific vendor is selected (§4 item 2 is now really "which vendor," not "build vs. buy" in the abstract).

~~Minimal, since this is a first design pass with no supplied requirements document (unlike HR/Payroll's `docs/UK/HR_Payroll_Requirements_Use_Cases.md` and the appraisal system's `docs/UK/Staff_Appraisal_360_Requirements_Use_Cases.md`, both user-authored specs this system doesn't have an equivalent of):~~

~~- `id`, `category` (from the extended taxonomy in §1), `description` (freeform text), `submittedAt`.~~
~~- `reporterId: EmployeeId?` — resolved 2026-08-20: anonymous by default. Genuine anonymity (matching NFR-SA01's "not cosmetic" standard, already established for peer/upward appraisal) means `reporterId` is not captured at all by default — not captured-and-then-access-restricted, which is a materially weaker guarantee. Mirrors the peer-appraisal precedent (`docs/UK/Staff_Appraisal_360_Requirements_Use_Cases.md` FR-SA04: anonymised by default, "individual attribution only where a peer explicitly opts in") — a Reporter can presumably choose to self-identify when filing, the same opt-in shape, though that opt-in mechanism itself isn't designed here.~~
~~- `status` — some lifecycle (received → under review → resolved, or similar), shape not designed here.~~
~~- `routedTo` — which Escalation Committee (or other body) the report is routed to. Defaulting every category to the same 3-person committee named in §0 is the simplest starting assumption, but not confirmed — a financial-misconduct report may need a different reviewing body (e.g. involving Finance/Audit) than a harassment report does, and forcing everything through one committee risks the same "wrong tool for a different kind of concern" problem `docs/DDD_Design.md` §2.3 already flagged when it separated Lending from ordinary company lending.~~

**Still valid regardless of build vs. buy, since these were policy decisions about the *system's behaviour*, not its implementation:** anonymous-by-default (a requirement to put to any vendor, not a field this project builds) and the extended category taxonomy in §1 (still useful as the spec of what a chosen vendor's platform needs to support).

---

## 4. Open Questions

1. ~~Anonymous-by-default, or reporter's choice?~~ — **resolved 2026-08-20: anonymous by default.** Now a requirement to put to whichever vendor gets selected, not a field this project builds (§3).
2. ~~Build vs. buy~~ — **resolved 2026-08-20: buy.** A licensed third-party whistleblowing/ethics-hotline provider. **Reframes, doesn't eliminate, item 3 below** and **narrows item 6 to "which vendor," not "build vs. buy."** See §3 for the full consequence.
3. **Which vendor — skipped for now, 2026-08-20, not decided against being picked later.** The user's own qualifier: "only for now" — this is a sequencing choice (not this turn), not a decision to leave vendor selection permanently open. Revisit when ready. **Items 4–6 below are reframed accordingly: they're requirements to evaluate any candidate vendor against, not questions that wait on a vendor being chosen first.** Whenever vendor selection does happen, it should be checked against 4–6, not treated as independent of them.
4. **Does every report category route to the same 3-person committee**, or do some (financial misconduct, in particular) need a different reviewing body? Still open — a routing requirement to configure in whichever vendor platform gets chosen, not a `routedTo` field this project builds.
5. **Retention policy — structure resolved 2026-08-20, specific periods deliberately left open pending legal input.** Coupled with item 6 (regulatory grounding), not independent of it — retention periods are normally *derived from* regulatory requirements, not decided in isolation, so specific year-figures are not invented here the same reason UK PAYE/NI tax bands weren't invented in `docs/HR_Payroll_DDD_Design.md` §3.3.

   **The resolved structure — differentiate retention by report outcome, not treat every report the same:**
   - **Substantiated reports that led to action** (disciplinary outcome, legal proceedings, a confirmed safeguarding issue) — retained long-term. Most likely category to have a real statutory floor (UK employment tribunal limitation periods, AML-adjacent recordkeeping given Purse's credit-union posture) — actual duration needs legal confirmation, not a guess.
   - **Unsubstantiated or no-action reports** — retained for a defined, shorter period, then reviewed for deletion. GDPR's data-minimisation principle applies hardest here, the same tension already named for HR data generally (`docs/UK/HR_Payroll_Requirements_Use_Cases.md` cross-cutting requirement 4: "don't retain more personal data than legally required").
   - **Exception within the short-retention category:** an unsubstantiated report may still be worth retaining longer *in aggregate/anonymised form* if it's part of a pattern (repeated reports about the same subject) — a legitimate reason to keep something beyond the short default, distinct from keeping full case detail indefinitely "just in case."
   - **Precision on whose data this retains:** since the Reporter is anonymous by default (item 1), the retention question is really about the *content* of the allegation and the *subject* named in it, not Reporter data — worth stating explicitly when this goes to legal, so the retention conversation doesn't default to thinking about reporter privacy alone.

   **Still genuinely open:** specific retention durations for each category, and confirming whatever the eventually-selected vendor (item 3) actually offers is compatible with this structure, not assumed.
6. **Regulatory grounding** — UK whistleblowing protections (e.g. statutory protected-disclosure frameworks) may impose specific requirements on how this needs to work, given Purse's credit-union/FCA-adjacent regulatory posture. **Partially de-risked by buying** — established vendors typically build to these requirements already — but not a substitute for actual legal confirmation; still flagged for legal input, not guessed at.
7. ~~Standalone codebase or shared infrastructure with HR/Payroll?~~ — **effectively resolved by the buy decision: neither.** There's no FiSH-side codebase to place, standalone or shared — see §3. The real remaining question is vendor selection and the Escalation Committee's access/integration into the vendor's platform, not a deployment-architecture choice this project controls.

None of these block recording this system's existence — they block moving from design to code, the same "record the decision, don't build it yet" precedent this whole document follows.
