# FiSH: how we describe the product

**Status:** product statement, 2026-10-07. Written down at Femi's request after he was asked to describe the product. The statement is his; the sections after it say what exists today and what is still open, so the description is never read as more than the code supports.

## 1. The statement

> FiSH is built to run on its own, or with runtimes that inherit the whole of FiSH and add their own Runtimes.
>
> FiSH + [Education Runtime, Clinical Runtime, Banking Runtime]

In plain terms: FiSH is a complete business platform on its own (ledger, sales, purchasing, inventory, HR and payroll, administration). An industry runtime sits on top of it and carries everything FiSH does, then adds what that industry needs.

**Clarification, 2026-10-07 (Femi):** FiSH on its own **is the Enterprise Runtime** (ER). The name was adopted during the Education build and was not spelled out at the time. Industries that need more are served by **specialist runtimes** on top of it: Education, Banking (for example Purse), and doctors' surgeries (the "Clinical Runtime" above). The first specialist runtime to inherit FiSH is **Education**. FiSH (an Enterprise Runtime) plus the Education Runtime is written **"FiSH+ER"**, and that combination is **The Principal's EduSys**. So "ER" on its own means Enterprise Runtime (FiSH), while in "FiSH+ER" the ER is the Education Runtime. Runtimes add special industrial abilities to the Enterprise abilities.

## 2. What exists today (checked 2026-10-07)

| Piece | Status | Evidence |
|---|---|---|
| **FiSH on its own = the Enterprise Runtime (ER)** | Live in production. A generic business can use it with no runtime. | GL, SOP, POP, IM, HR, EA and the shared web app are deployed. |
| **Education Runtime** | Built and live. Its school product is **EduSys** ("The Principal's EduSys"). | Own backend (`fish-education-runtime`, repo folder `ER/Principal/EducationRuntime`). A tenant whose industry is `SCHOOL` is granted the `EDUCATION_RUNTIME` module and sees school tabs inside the shared web app. |
| **Clinical Runtime** (doctors' surgeries) | Stated intent. **Nothing exists**: no code, no design document. | No mention anywhere in the repos. |
| **Banking Runtime** (for example Purse) | Stated intent. **Nothing exists** as a runtime. | Purse is the intended banking customer. Its core-banking requirements are separate reference material, not a built runtime. |

Only the Education Runtime is real. Any external wording must not suggest the other two exist (the project's rule is credibility over persuasion).

## 3. How "inherits the whole of FiSH" works in the code today

The Education Runtime is the one worked example, and it shows the shape runtimes already follow:

- **Generic core, industry layer on top.** FiSH's screens, ledger and modules are generic. An industry is a setting on the business (`IndustryType`: today only `GENERIC` and `SCHOOL`), and it switches on extra modules and labels, it does not fork the product.
- **A runtime owns its operations, FiSH owns the money.** The Education Runtime runs school operations (admissions, students, timetable, attendance). Its financial events (fees, payments) post through FiSH's sales order processing into the ledger. It does not keep its own books.
- **One shared web app.** A runtime does not get its own front end by default. It gets tabs inside the shared FiSH web app, built by the same session so code is reused. (A separate installable EduSys app was proposed and parked.)
- **Access comes from Enterprise Administration.** A person sees a runtime's tabs only if EA has granted that module at that Company.

"Inherit" here therefore means: everything FiSH offers stays available and unchanged to a runtime's customers, the runtime adds to it, and the runtime never replaces or duplicates FiSH's financial core.

## 4. Questions raised, and Femi's answers (2026-10-07)

These four were put to Femi as open questions. His answers are recorded as given. **They are for information, not a direction to build.**

1. **"Inherit" versus "delegate".** Is it right that the runtime calls FiSH over APIs and events? *Answer: yes.* FiSH does what it would normally do within that industry, and the industry adds its own events and the rest.
2. **Two meanings of "ER".** *Answer:* FiSH is an Enterprise Runtime on its own. Its first industry runtime that inherited it is Education, making FiSH an ER + ER (Enterprise + Education), which is the "FiSH+ER" we call The Principal's EduSys. Both runtimes abbreviate to "ER", so the context decides which is meant: standing alone it is the Enterprise Runtime, in "FiSH+ER" it is the Education Runtime. *Still for the SRS owner:* The Principal's SRS defines FiSH narrowly (the financial engine) and ER as shared admin, operations and UX services, which is narrower than "FiSH on its own is the Enterprise Runtime". It should be aligned. This document does not change it.
3. **Adding a third runtime** (a new industry type and module in Enterprise Administration, released consumers first). *Answer: not at the moment.* Nothing is planned for Clinical or Banking.
4. **Separate app or shared app.** *Answer given:* "Runtimes will add special industrial abilities to Enterprise abilities." The question of EduSys as its own installable app was not answered by this and **remains parked**.

## 5. Wording to use

- Short: "FiSH runs on its own, or with an industry runtime that builds on all of FiSH."
- Examples: "FiSH + Education Runtime" is available today. Clinical and Banking are planned, not built.
- Do not say a runtime "includes its own accounting"; the ledger is FiSH's.
- Say "Enterprise Runtime" when you mean FiSH on its own, and "Education Runtime" or "FiSH+ER (The Principal's EduSys)" when you mean the school product. Do not write a bare "ER" where either could be meant.
