# FiSH: how we describe the product

**Status:** product statement, 2026-10-07. Written down at Femi's request after he was asked to describe the product. The statement is his; the sections after it say what exists today and what is still open, so the description is never read as more than the code supports.

## 1. The statement

> FiSH is built to run on its own, or with runtimes that inherit the whole of FiSH and add their own Runtimes.
>
> FiSH + [Education Runtime, Clinical Runtime, Banking Runtime]

In plain terms: FiSH is a complete business platform on its own (ledger, sales, purchasing, inventory, HR and payroll, administration). An industry runtime sits on top of it and carries everything FiSH does, then adds what that industry needs.

## 2. What exists today (checked 2026-10-07)

| Piece | Status | Evidence |
|---|---|---|
| **FiSH on its own** | Live in production. A generic business can use it with no runtime. | GL, SOP, POP, IM, HR, EA and the shared web app are deployed. |
| **Education Runtime** | Built and live. Its school product is **EduSys** ("The Principal's EduSys"). | Own backend (`fish-education-runtime`, repo folder `ER/Principal/EducationRuntime`). A tenant whose industry is `SCHOOL` is granted the `EDUCATION_RUNTIME` module and sees school tabs inside the shared web app. |
| **Clinical Runtime** | Stated intent. **Nothing exists**: no code, no design document. | No mention anywhere in the repos. |
| **Banking Runtime** | Stated intent. **Nothing exists** as a runtime. | Purse's core-banking requirements are separate reference material, not a runtime. |

Only the Education Runtime is real. Any external wording must not suggest the other two exist (the project's rule is credibility over persuasion).

## 3. How "inherits the whole of FiSH" works in the code today

The Education Runtime is the one worked example, and it shows the shape runtimes already follow:

- **Generic core, industry layer on top.** FiSH's screens, ledger and modules are generic. An industry is a setting on the business (`IndustryType`: today only `GENERIC` and `SCHOOL`), and it switches on extra modules and labels, it does not fork the product.
- **A runtime owns its operations, FiSH owns the money.** The Education Runtime runs school operations (admissions, students, timetable, attendance). Its financial events (fees, payments) post through FiSH's sales order processing into the ledger. It does not keep its own books.
- **One shared web app.** A runtime does not get its own front end by default. It gets tabs inside the shared FiSH web app, built by the same session so code is reused. (A separate installable EduSys app was proposed and parked.)
- **Access comes from Enterprise Administration.** A person sees a runtime's tabs only if EA has granted that module at that Company.

"Inherit" here therefore means: everything FiSH offers stays available and unchanged to a runtime's customers, the runtime adds to it, and the runtime never replaces or duplicates FiSH's financial core.

## 4. Open questions (not decided; park until the owner decides)

1. **"Inherit" versus "delegate".** The Principal's SRS describes the school product as *delegating* ledger accounting to FiSH and shared operations to a separate layer. This statement is stronger: the runtime *includes* all of FiSH. In practice the Education Runtime calls FiSH over APIs and events. Is that the intended meaning, or should a runtime also reuse FiSH's screens and modules directly?
2. **Two meanings of "ER".** The SRS defines ER as *Enterprise Runtime* (shared admin, operations and UX services). In use, "FiSH+ER" now means *Education Runtime*. Which name is canonical, and does an Enterprise Runtime layer exist separately?
3. **Adding a runtime is a platform change.** `IndustryType` is a closed list. A Clinical or Banking runtime means a new industry type, a new module, and a release that every service decodes before Enterprise Administration emits it (strict decoding), plus new runtime-specific labels in the web app.
4. **Separate app or one app.** Whether a runtime's customers install its own app (EduSys) or use the shared one is parked.

## 5. Wording to use

- Short: "FiSH runs on its own, or with an industry runtime that builds on all of FiSH."
- Examples: "FiSH + Education Runtime" is available today. Clinical and Banking are planned, not built.
- Do not say a runtime "includes its own accounting"; the ledger is FiSH's.
