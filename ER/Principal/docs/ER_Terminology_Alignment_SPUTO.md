# Aligning "FiSH" and "ER" across the Education Runtime documents (short SPUTO)

**Status: DRAFT, 2026-10-07. Documentation only.** Requested by Femi via CM: align the Principal SRS definitions, and any other Education Runtime docs, with `docs/FiSH_Product_Description.md` (sections 1, 4 and 5). Rule applied: **align, do not redefine.** Femi's answers are taken as given; anything that contradicts them is flagged, not silently resolved.

## 1. Scope

**In:** the wording of "FiSH", "ER", "FiSH+ER" and "The Principal's EduSys" in the documents under `ER/Principal/docs/`, and the SRS glossary above all.
**Out:** renaming files, folders or repos; code identifiers and requirement-ID prefixes; documents owned by other sessions (HR, EA, GL, SOP, Omniview, BuzzMe); the `.docx` copy of the SRS (binary, see section 5).

## 2. The target wording (Femi, as recorded in `FiSH_Product_Description.md`)

- **FiSH on its own is the Enterprise Runtime** (ER): a complete business platform (ledger, sales, purchasing, inventory, HR and payroll, administration).
- **Specialist runtimes** sit on top of it and add an industry's abilities; **Education is the first**. FiSH plus the Education Runtime is written **"FiSH+ER"**, and that combination is **The Principal's EduSys**.
- "ER" alone is therefore ambiguous. Rule (section 5 of that document): *say "Enterprise Runtime" when you mean FiSH on its own, and "Education Runtime" or "FiSH+ER (The Principal's EduSys)" when you mean the school product; do not write a bare "ER" where either could be meant.*

## 3. What was found (audit of `ER/Principal/docs/`)

Bare "ER" carries **two different meanings** in these documents, which is the real alignment problem:
- **The Principal SRS** used it for the **Enterprise Runtime as "shared Admin, Operations and UX services"** and defined **FiSH narrowly as "the Financial Spine"**. That is the one document that **contradicts** Femi's usage: it treats FiSH and ER as two separate things beside the school product, where he says FiSH on its own *is* the Enterprise Runtime.
- **The Technical Requirements Specification v0.1 (101 prose uses), the Backlog (35) and the drafts** use it for the **Education Runtime**. Inside those documents the meaning is clear, but beside the SRS the same two letters mean the opposite thing.
- Most other bare "ER" is a **requirement-ID prefix** (`ER-ATT-008`, `ER-FEE-008`) or part of "FiSH+ER": identifiers and a correct compound, both kept.

## 4. What was done (this branch)

| Document | Change |
|---|---|
| `The_Principal_SRS.md` | Glossary rewritten: **FiSH** is now the Enterprise Runtime (financial engine = **FiSH GL**); a new **Education Runtime** entry (abbreviated ER only inside "FiSH+ER", the SRS writes the name out); a new **FiSH+ER** entry (= The Principal's EduSys). The scope sentence, the out-of-scope list, the architecture diagram label and paragraph, the assumptions line and the interfaces line no longer present "ER" as a separate shared-services layer; they say FiSH's shared services (the Enterprise Runtime). |
| Technical Requirements Specification v0.1, `The_Principal_Backlog.md` | A **terminology note** at the top: here a bare "ER" means the Education Runtime; IDs keep their prefix; new text writes the name out. The bodies are **not** rewritten (supplied specification text and 35 backlog rows; a mass rewrite would risk altering meaning and requirement references). |
| `ER_Teaching_Staff_Onboarding_ER_Half_Draft.md`, `EduSys_Separate_App_SPUTO.md` | The bare "ER" in the prose was written out as "Education Runtime" (drafts written this month, safe to change; a quotation of Femi's own words was left exactly as he said it). |
| `ER_School_Playbook_Draft.md` | Already wrote the name out; no change. |

## 5. Flagged, not changed (decisions or owners elsewhere)

1. **`The_Principal_SRS.docx`** is a binary copy of the SRS and still carries the old definitions. It needs regenerating from the markdown (or retiring); I did not edit it.
2. **The SRS mentions "the ER SRS" and "the FiSH SRS"** as separate documents. I changed the wording to point at FiSH's shared services, but whether those separate SRS documents exist, and under which names, is not something I can confirm from this folder.
3. **`FiSH_Product_Description.md` section 4, item 4** says the EduSys separate-app question "remains parked". Femi has since reopened it (a design pass, `EduSys_Separate_App_SPUTO.md`), so that line is stale. Its owner should update it; I did not edit another session's document.
4. **The folder `ER/`, the session name "+ER Education", the repo name `fish-education-runtime`** and similar are short forms that are ambiguous under the new rule. Renaming paths and sessions breaks links and habits for little gain; I recommend leaving them and relying on the glossary. Femi's call.
5. **Other places outside `ER/Principal/docs/`** (the top-level `CLAUDE.md`, EA, HR, WEB, Omniview documents and sessions' names) use "ER" and "FiSH+ER" too, some for the Enterprise Runtime and some for the Education Runtime. Not audited here; each owner should apply section 5 of the Product Description to their own text.
6. **"The Principal" versus "The Principal's EduSys":** Femi says FiSH+ER *is* The Principal's EduSys. The SRS still describes "The Principal" as a product *inside* FiSH+ER. I aligned the glossary but did not restructure the SRS's framing; whether "The Principal" is the school-facing product within EduSys or the same thing is his to settle.

## 6. Decisions for Femi

- Leave `ER/`, "+ER Education" and `fish-education-runtime` as they are (recommended), or rename?
- Is "The Principal" the same thing as "The Principal's EduSys", or the school-facing product inside it? (Section 5, item 6.)
- Retire or regenerate the SRS `.docx`?
