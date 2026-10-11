# Decisions log (shared by every session)

**Rule (Femi, 2026-10-11: collaboration and coordination is sacrosanct and prime):** nobody asks Femi a question that is already answered here. Before asking, read this file. After Femi decides anything, in ANY session, the session he told appends one line within minutes (date, decision, his words if short, source session, who must act). CM merges it. Where a decision is recorded here, every other session treats it as decided without asking again.

Format: `date | decision | source session | acts`

## 2026-10-10
- 2026-10-10 | Education Runtime: the Owner is the Business Owner; the head teacher is the school's CEO and acts with authority the Owner gives | Education Runtime (+ER) | ER, WEB
- 2026-10-10 | Teachers enter grades (Operations, not Administration); the head teacher is a teacher; the bursar/accountant never enters grades | +ER | ER (done as T-ER10)
- 2026-10-10 | Attendance in school is approved by the form master (task can be delegated), teachers take it per class; test-mark approval is NOT the form-master default and who approves is still open (in CM's batch) | +ER | ER
- 2026-10-10 | DPID/device binding is per school (one school) | +ER | ER
- 2026-10-10 | A parent may tick "paid" but it only triggers a verification sequence, it is a claim, not a payment (T-ER3, held until after the sitting) | +ER | ER
- 2026-10-10 | Keep PARENT as an alias for GUARDIAN in the Education Runtime role names | +ER | ER

## 2026-10-11
- 2026-10-11 | EA concurrent-writes Playbook APPROVED: per-Tenant lock now (T1 to T7), per-row writes after; changing the modules of an already revoked member is refused with 409 | told EA directly, confirmed to CM | EA builds, CM reviews at HIGH
- 2026-10-11 | Periods: automatic OPENING of the next period, explicit CLOSING (especially because of bank reconciliations). Deferred: nothing built before the sitting fixes; scoped in `docs/GL_Period_Management_Scoping.md` | CM | GL
- 2026-10-11 | Cash and bank books: account 1000 is always the Cash Book; bank accounts (and mobile-money wallets) are further cash books with the reconciliation feature, created as needed; one book per account; the jurisdiction's currency is the primary cash and bank currency, seeded on Company creation; Liberia, Guinea and Cote d'Ivoire seed SLE (the SLE-only Mano River decision stands) | CM | GL, WEB
- 2026-10-11 | Foreign-currency cash and bank accounts: phased; primary currency first; which currencies a Company may open is decided after the IAS 21 design pass | CM | GL
- 2026-10-11 | GL cash and bank stack deployed before the sitting (hold lifted) | CM | CM
- 2026-10-11 | The product decides whether it is VATable, and IM owns the product: Item.vatCategory, written as a SPUTO Playbook first ("SPUTO gives them the Playbook to build against"); SOP mirrors POP's rule (explicit category on every line, no silent trade-finance default) | CM | IM, SOP, POP, WEB
- 2026-10-11 | School admin has READ-ONLY access to student records and student finance (owned by Operations and Finance); admin keeps student writes until a registrar exists; admin loses grade entry, fee desk, curriculum writes and attendance entry | CM | ER, WEB
- 2026-10-11 | GRNI (stock purchase double-count fix) is scheduled after the cash book; SPUTO form | CM | GL, IM, POP
- 2026-10-11 | Principle: SOP, IM and POP are the heartbeat of every organisation and must work seamlessly together; the Cash and Bank Account is the heartbeat of the General Ledger | CM | all
- 2026-10-11 | Principle: collaboration and coordination is sacrosanct and prime | CM | all
- 2026-10-11 | A refused request must not spend an idempotency key (GL stores only 2xx) | CM | GL, POP, HR

## Earlier, still in force
- Only CM pushes, merges and deploys. Coordination is the prime directive. Everything in production is test data until Femi announces the Live switch. RBAC freeze: only add-a-deny changes without CM. Unknown keys are never tolerated in auth payloads (strict decoding). SLE is the only onboarded currency across the Mano River operation.
