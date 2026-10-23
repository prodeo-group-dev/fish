# A readable transaction number on every posted entry, and keeping posted rows unchanged: design note

**Status:** DRAFT, 2026-10-23, design only. Nothing here is built. Written by the GL session at CM's request after Femi asked "Do we have transaction ids???" and ruled "The audit trail will need one". **Femi ruled 2026-10-23 (via CM): the number is GAPLESS and any gap must be auditable and explained (Q12; Decisions_Log 2026-10-23); it is migration V38 and stays design only until the audit-trail Playbook is approved. Section 6c below sets out what that means.** Section 6 (the posted-row protection, V37) is built and released separately; see docs/GL_Posted_Entry_Immutability_Requirements.md in the GL repo. **Evidence tags:** **[code]** read on `origin/master` (GL `b0a106a` plus the open reversal PR); **[unverified]** believed, not read.

## 1. The requirement and what exists today

A posted entry must carry a **human-readable, sequential transaction number**, shown in the journal list, the audit read and every correction. Today **[code]** an entry has:

| What | Where | Readable? | Per Company? |
|---|---|---|---|
| `id` (UUID) | `journal_entries.id` | no | globally unique |
| `recorded_seq` (identity, V35) | `journal_entries.recorded_seq` | no, and not meant to be: it orders entries inside a day | **global across all Companies**, gaps possible |
| `recorded_at` (V35) | `journal_entries.recorded_at` | a time, not a number | n/a |
| `source_ref_number` (V36) | `journal_entries.source_ref_number` | yes (an invoice or receipt number) | the owning module's number, **not** GL's; optional; one document can post several entries |

So there is no number GL itself issues. `journal_entries` has **no `company_id` column** (the Company is reached through the Period), which matters below.

## 2. Recommendation in one paragraph

Give every **posted** entry a **per-Company, gapless, immutable integer** `transaction_number`, issued from a **locked per-Company counter in the same database transaction as the insert**, shown as `T-000123` (the prefix and width are presentation, not stored). A **reversal takes its own next number** and is linked to the original. Backfill existing entries per Company in `recorded_seq` order. Keep `recorded_seq` (internal ordering) and `source_ref_number` (the business document's number) exactly as they are: three different things, none replaces another. Add `company_id` to `journal_entries` in the same migration (it is also T15's "Company key on every child table", so one migration serves both).

## 3. The decisions, with the options

**3.1 Scope: per Company (recommended), not global, not per Tenant.** A Company's books are the unit an accountant and an auditor read; numbers that skip because another Company posted would be noise. Per Tenant mixes books that are separate legal entities. Global is `recorded_seq` today.

**3.2 Gapless or not: gapless (recommended).** A database `SEQUENCE` is fast but skips on rollback and on a crash, so a missing number would not mean "something was removed". For an audit trail a gap must mean something. A **locked counter row per Company** (`UPDATE company_entry_counter SET next_number = next_number + 1 WHERE company_id = ? RETURNING next_number`, inside the posting transaction) is gapless because a rolled-back post undoes the increment. Cost: postings of one Company serialise on one row lock. At GL's current volume that is acceptable; the counter is the only contention point and there is no cross-Company lock. CBB's receipt series already uses a locked counter, so the pattern exists on the platform.

**3.3 What gets a number.** Every entry that becomes POSTED: manual journals, every module posting, imports, depreciation, **and every reversal**. A DRAFT entry (rare; none of GL's routes stores one) gets none until posted. Reversals and the generic reversal (GL-RF-RV1) go through the same insert path (`recordReversal` calls `insertIfAbsent`), so they number themselves with no special case. The reversal's number is its own, and the link runs **both ways**: the existing `reversal_of_entry_id` on the reversal, and the structured reversed-by link the journal list already returns for the original (PR #126), so a read can say "reverses T-000123" and "reversed by T-000130" (derived, nothing stored twice). The original keeps its number and is never deleted, edited or renumbered. A later `correctsEntryId` (the audit design's T-41) would link a correcting journal to the entry it corrects the same way.

**3.4 Format.** Store the integer; present `T-` plus six digits (wider if needed; the width is a display rule). No per-year or per-source prefix in the first build: a source prefix would split one ledger's sequence into several series, which defeats "gapless", and the entry already shows its source. Femi to confirm the letter and whether a fiscal-year restart is wanted (my recommendation is no restart: a restart turns the number into a pair and every report must carry the year).

**3.5 Interplay with `source_ref_number`.** They stay separate and both are shown. The **transaction number** is GL's ledger sequence (one per entry, always present). The **source reference number** is the owning module's document number (invoice `INV-0077`, receipt `RCT-0042`), optional, and one document can post several entries (a sale, then its collection). Searching by either must work. Femi's "receipt number on every entry" (CBB's design note) is the source-reference side and is not decided in GL.

**3.6 Idempotency and concurrency.** A retried request returns the existing entry with its existing number (the derived-id routes and the replay store already return the stored answer; the number is part of the stored entry). A new insert takes the counter lock, so two simultaneous distinct postings of one Company get consecutive numbers. One hazard to design for, not to forget: `insertIfAbsent` can find the id already present AFTER the counter was incremented in the same transaction; that increment must be rolled back (the loser of a race must not leave a gap), so the insert path takes the lock only when the id is absent and rolls the whole unit back on a lost insert. Exposed re-runs a failed transaction block, so the claim-and-post helper needs `defaultMaxAttempts = 1` (noted earlier for the claim-first design).

## 4. Migration sketch (V37 is the next free number; to be claimed)

*Illustrative; the real migration is written, tested against a restored copy, and reviewed by CM.*

1. `ALTER TABLE journal_entries ADD COLUMN company_id UUID;` backfill from `periods.company_id`; `SET NOT NULL`; index `(company_id, recorded_seq)`.
2. `ALTER TABLE journal_entries ADD COLUMN transaction_number BIGINT;` and `transaction_number_backfilled_on DATE` (null for a number issued at posting; the migration date for a number assigned at backfill, so a read can say "assigned at backfill on 2026-xx-xx" and the audit trail never overclaims). Backfill `ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY recorded_seq)` for POSTED and REVERSED entries; `UNIQUE (company_id, transaction_number)`. **Backfill order (a choice the audit design asked about):** the audit draft suggested (entry date, recorded_seq, id); I recommend `recorded_seq` alone (it is unique, so no tie-break is needed): new entries are numbered in the order they are POSTED, so numbering old ones in the order they were STORED keeps one meaning for the whole series, whereas ordering by entry date would place a back-dated entry before earlier-posted ones and make old and new numbers mean different things. Either is deterministic and either is flagged as backfilled; this is a small decision for Femi and the audit design. **Backfill before Live is the cheapest time:** the data is legacy test data until Femi announces Live, so nothing real is renumbered.
3. `CREATE TABLE company_entry_counter (company_id UUID PRIMARY KEY, next_number BIGINT NOT NULL)`, seeded with `max(transaction_number) + 1` per Company.
4. Application: assign the number in the insert path, inside the posting transaction (section 3.6).

**Backfill honesty.** Entries older than V35 have a `recorded_seq` that is only "the order Postgres stored them"; the true order of two same-day old entries is not known and is not guessed (V35's own rule). Their numbers inherit that: stable from now on, but not proof of the original entry order. Production data is legacy test data until Femi announces Live, so the backfill can be done before then at no real cost. **Numbering of the refresher's V37:** the Tax rate refresher also claimed a state table; whichever is built first takes V37 and the other V38, and each is announced before it opens.

## 5. How the number appears (additive; consumers declare first)

- **Audit read** (`?include=audit`, opt-in, so only consumers that asked for audit): add `transactionNumber` first, since a consumer that asks for audit is ready for it.
- **Journal list default answer, the posting answers (`record-sale` and the rest), the cash-book rows and the account postings read:** add the field only after each strict consumer (WEB, CBB, Tax, EA, SOP, POP, IM) has declared it, with a contract fixture each, in the platform's consumer-first order. The reversal answers (`POST .../reverse`, the undo) should return the reversal's number in the same release as the field appears elsewhere.
- Strict decoding stays everywhere: no `ignoreUnknownKeys`.

## 6. Keeping posted rows unchanged: two findings and what I recommend

Femi's rule: **a posted transaction is never changed or deleted** (a correction is a reversing entry). Two things in the code today do not match it. **Femi has not ruled on these; I recommend, I do not build.**

**(a) `save()` rewrites every line of an entry each time it saves an existing one [code].** `ExposedJournalEntryRepository.save()` on an existing entry runs `UPDATE journal_entries SET ... ` (period, date, source, description, status, reversal link) and then `DELETE FROM journal_lines WHERE journal_entry_id = ?` followed by an `INSERT` of every line. The only existing-entry save GL makes in practice is marking the original REVERSED (`recordReversal`), so the lines are deleted and re-inserted with identical content, inside one transaction. The audit columns are not touched on update (`stampProvenance` runs only on insert), which is right.
*Recommendation:* when the stored entry already exists and is POSTED or REVERSED, `save()` updates **only `status`** and **does not touch `journal_lines`**; if the lines or any other field differ from the stored entry it **refuses** (an exception, which would be a programming error, never a user path). A DRAFT may still be rewritten while it is a draft. Small, no migration, tests first (a stored entry's lines are byte-for-byte unchanged after it is reversed; an attempt to change a posted entry's description or lines is refused).

**(b) Nothing in the database stops an UPDATE or DELETE of posted rows [code: no trigger or rule exists in any migration].** The application is the only guard, and the repository is the only writer in the source, but a script, a migration or a person with database access is not stopped.
*Recommendation:* a migration adding triggers: (1) `BEFORE UPDATE` on `journal_entries` raising unless the row is a DRAFT, or the only change is `status` `POSTED -> REVERSED` with every other column `IS NOT DISTINCT FROM` its old value; (2) `BEFORE DELETE` on `journal_entries` raising unless the row is a DRAFT; (3) `BEFORE UPDATE OR DELETE` on `journal_lines` raising unless the parent entry is a DRAFT; (4) a `BEFORE TRUNCATE` guard on both tables. **Rollout in two steps:** first as `RAISE WARNING` for one release, to find any hidden writer, then switch to `RAISE EXCEPTION`. **Check before the second step:** UAT or Switch-Day reset tooling, test-database cleanup and any one-off script that deletes journal rows; I found none in GL's source, but I cannot see scripts outside it and CM's search of the repos is the right check. The application database role should also lose `DELETE` and `TRUNCATE` on those tables as a second wall (an operations change for CM).
*Order:* (a) first (code only), then (b); both before the transaction number goes live is ideal, because a number on a row that can still be edited or deleted is not an audit trail.

## 6a. Requirements from the audit-trail design (FR-AUD-23 to 29, T-AUD-GL3), checked against this note

| # | Requirement | Where met |
|---|---|---|
| 1 | Assigned by GL at posting; no caller supplies one; a refused or unposted attempt has none | 3.3, 3.6: issued inside the posting transaction; a refusal rolls back and consumes none |
| 2 | Per Company, one sequence across all sources; never Tenant-wide or platform-wide | 3.1, 3.3 |
| 3 | Gapless, allocated inside the posting transaction; replay returns the same number; say so if too costly | 3.2, 3.6; the cost (one row lock per Company) is stated and judged acceptable |
| 4 | A reversal has its own number, linked both ways; the original is never changed | 3.3 |
| 5 | Backfill once, deterministic, per Company from 1, flagged as assigned at backfill, never renumbered | 4 (flag column; order recommendation) |
| 6 | Not the document number; both shown, either searchable | 3.5 |
| 7 | Every posting response and every audit-carrying read returns it, opt-in and strict-decoded | 5 (consumer-first; audit read first) |
| 8 | Nothing in the format identifies another Tenant or total volume; sayable aloud | 3.4: a per-Company counter never exposes the global `recorded_seq`, which is shared across all Companies and Tenants and must not be shown |
| 9 | "Never deleted" is a stated, tested rule | 6: the save() change, the triggers and tests |

One caution on 8: a per-Company number still tells a reader how many entries THAT Company has; that is the Company's own information and is what the series is for.

## 6b. The audit-trail session's six review points, answered

1. **Bulk and multi-entry acts (a pay run; a CSV import of thousands).** The counter lock is held until the posting transaction commits, so a long batch would hold up every other posting of that Company. Recommendation: a **single-entry post allocates its number at insert** (the lock is held for a few milliseconds); a **batch (import, multi-entry pay run) validates and inserts first and takes ONE counter bump at the very end of its transaction** (`next_number = next_number + N`), then writes the N numbers to the batch's rows in `recorded_seq` order. This makes `transaction_number` a **write-once column**: NULL to a value once, in the posting transaction, never again (the trigger of section 6 allows exactly that and nothing else). A batch stays one unit: it commits or fails as a whole, and a failed batch consumes no numbers. If a very large import must not be all-or-nothing, it is chunked by the owning service and each chunk is its own unit; that is an import-design choice, not a numbering one.
2. **Replay.** The number lives ON THE ENTRY ROW. Routes that derive the entry id from the Idempotency-Key (the cash-book routes) find the existing entry by id and return it with its number, so a purged key still converges on the same entry and number. Routes that use the replay store return the stored answer (which carries the number once the field is added). If a replay-store key has been purged, a re-send is a new posting regardless of numbering; that gap is closed by the claim-first design (the entry id derives from the key), not by the number.
3. **Gap visibility.** By construction there are none: the invariant is `count(numbers) = max(number)` per Company, tested with N concurrent postings and with rolled-back postings (they must consume nothing). I recommend also a small **check read** for auditors (count, max, and the missing numbers if any), so "none exist" is shown, not just claimed.
4. **Protection of posted rows.** The triggers of section 6 cover **both `journal_entries` and `journal_lines`**: DELETE refused, UPDATE of a line refused, UPDATE of an entry refused except `status` POSTED to REVERSED (and the write-once number), and a **TRUNCATE guard** on both. Femi agreed (2026-10-23).
5. **The counter row.** A trigger on `company_entry_counter` refuses DELETE and TRUNCATE, and refuses an UPDATE that does not increase `next_number`; the unique index on `(company_id, transaction_number)` makes a duplicate impossible; a manual jump upward would create a gap that the check read of point 3 shows. A table owner can always bypass a trigger; that is not preventable inside the database, and is why the application role should hold no DELETE or TRUNCATE on these tables.
6. **Width.** `T-000123` is a minimum width; the integer is the truth. Past 999,999 it prints wider (`T-1000000`); nothing caps it.

## 6c. Femi's ruling on gaps (Q12, 2026-10-23), and what it asks of the design

Ruling, in his words: "Gapless... any gaps must be auditable for explanations." Recorded by CM as: the number is allocated inside the posting itself, a failed posting uses no number, a retry returns the same number, and if a gap ever appears the audit trail must be able to show it and explain it (never silently skipped).

What this settles in the design above: section 3.2's locked per-Company counter is the choice (a SEQUENCE is out); section 6b point 1's rule stands (a single post takes its number at insert; a batch takes ONE bump at the end of its transaction, so a rolled-back batch consumes nothing); point 2 already gives "a retry returns the same number" through the entry row.

What is new, and is a PROPOSAL until the audit-trail Playbook is approved (nothing is built):

1. **A gap should be impossible in normal running, so "explainable" has to cover the abnormal causes:** a database restore to an earlier point, an owner-level manual change to the counter or the entries (the trigger of 6b point 5 cannot stop the table owner), a defect, or a migration. Each either removes a numbered entry or moves the counter without an entry.
2. **Detect:** the check read of 6b point 3 becomes a contract, not an extra: per Company, `count`, `max`, the counter's `next_number - 1`, and the list of missing numbers (and any number beyond `max`). Read-only, tenant-scoped, one query on the unique index. A mismatch of `count`, `max` and the counter is the signal.
3. **Explain:** an append-only `transaction_number_gap_notes` record (Company, first and last missing number, a reason, who recorded it, when), written only through a deliberate route by a platform operator or the Owner Admin, never by editing an entry and never deleted. A gap with no note shows as UNEXPLAINED in the check read; a note never closes a gap, it explains it. This table is itself immutable by the same kind of triggers as V37.
4. **Backfill (V38) is the one planned source of unusual numbers:** entries stored before V38 are numbered in recorded order, flagged as assigned at backfill, in one migration. The V37 triggers must let that happen: either disable them deliberately for that one statement (table owner, inside the migration's transaction), or give the entry trigger a write-once NULL-to-value allowance for `transaction_number`. The second keeps the guard on, and is my preference.
5. **Who reads it:** Q13 (same day) says the Owner Admin alone reads the audit trail first, the Accountant later; the check read and the notes follow that rule.

Open for Femi or the audit-trail session, not decided here: whether an unexplained gap should also BLOCK further posting for that Company or only show (I recommend only show, and tell CM); who may write a gap note; and whether a note needs a second person's approval.

## 7. Questions for Femi (plain words)

1. Is a **per-Company** series right, written `T-000123`, with **no restart each year**? Or a different letter, or a year in the number?
2. ANSWERED 2026-10-23: gapless, and gaps auditable (section 6c). Was: must the number be **gapless** (my recommendation, at a small cost in speed when one Company posts at the same instant), or is a number that can skip after a failed posting acceptable?
3. Do you rule on (a) and (b): may GL stop re-saving lines, and may the database refuse any change to a posted entry except marking it reversed?
4. Should entries that existed before the number was introduced be numbered after the fact in the order they were STORED (my recommendation) or by their entry DATE first (the audit draft's suggestion)? Either is flagged as assigned at backfill; doing it before Live is the cheapest.

## 8. Not decided here

Where the number is shown on a printed receipt or invoice (that is the owning module's document number, not this one). The format of CBB's receipt number (CBB's own design note). Whether the number appears in the posting answers of SOP, POP, IM, HR and Payroll: consumer-first, after each declares it.
