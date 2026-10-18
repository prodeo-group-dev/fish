# IM: playbooks and test plan reviewed against the landlord principle and the 2026-10-14 to 2026-10-16 decisions

From the IM session, 2026-10-17. Docs only. Method: I read the IM code and docs for the terms the decisions retire (Prodeo as a party, "contact support", financier, Team/People), then read each IM document for content that conflicts with a decision, not only for words. Companion to CM's `Playbook_Review_2026-10-15.md`, whose scan found nothing in the IM Playbooks; a content review was the open item.

## Result in one line

IM's **code** has no Prodeo-as-a-party logic. IM's **reference requirements** still describe Prodeo Group's own trade-finance business in places. The **VAT Playbook and decisions sheet were stale** on four decisions and are now fixed. Two **real findings** surfaced that are not wording: the valuation rounding (own file) and a gap in the opening-stock scope.

## 1. Landlord principle (Prodeo has no role in a Tenant's data, accounts or transactions)

| Where | Finding | Action |
|---|---|---|
| IM code (`IM/src`) | No "Prodeo", no financier role, no deal role, no "support" path. `Item.facilityId` is a plain reference to the Tenant's own facility. Nothing provides, arranges or confirms finance. | None. Checked by search, 2026-10-17. |
| `IM/docs/Inventory_Management_Requirements_Use_Cases.md` (reference, user-supplied 2026-08-20) | Context says "the Group's active trade finance business (the sugar import structure ... independent Collateral Manager)"; actors list "Bank: financing party relying on the reported inventory as facility collateral"; UC-IM5, FR-IM05, NFR-IM02 model the Collateral Manager and Bank covenants as if FiSH's operator were a party. | **Wording to change, behaviour stays** (Femi, trade finance final 2026-10-15: keep, generic, for the Tenant's own lender). Read "the Group" as "the Tenant", "the Bank" as "the Tenant's own lender". I have NOT edited this reference file (it is Femi's text); I propose the one-paragraph note below be added at its top, and will do it on a docs branch if CM wants it. |
| `IM_Product_VAT_Category_SPUTO.md` risk 12 | "worth knowing for support" | **Fixed:** now says the Tenant's administrator, and that there is no "Prodeo support" step. |
| `IM_MVP_Definition_REFRESHED_2026-10-13.md` | No Prodeo wording. Says Collateral Manager reconciliation "not built, not in floor". | None. |
| `TestPlans/IM_Test_Plan.md` | No test of a Prodeo step. Reference rows for per-deal margin, Collateral Manager reconciliation and in-transit are correctly "Not in floor"/"Enhancement". | Review block added at the top of the plan, reading "the Bank" as the Tenant's own lender. |

Proposed note for the top of the reference Use Cases file: *"2026-10-17: Prodeo is a landlord with no role in any Tenant's data (Decisions Log, 2026-10-15). Where this document says 'the Group', read 'the Tenant'; where it says 'the Bank' or 'the financing party', read 'the Tenant's own lender'. The collateral and covenant features are kept, generic, for whoever a Tenant chooses to get trade finance from; FiSH provides the ledger only."*

## 2. Decisions that made IM's own documents stale (now fixed)

| Decision | Where it was stale | Fixed |
|---|---|---|
| 2026-10-14: Playbook v4 APPROVED ("Yes to all four") | SPUTO header said DRAFT, "no code starts until Femi approves" | Header rewritten: approved, slice A built, slices B/A0/W5 not. |
| D2 ruled: Owner Admin or accountant only | R5 and D2 said "any human with WRITE" | R5 and the D2 row rewritten; built that way in slice A. |
| D11 answered: six values, EXEMPT also means out of scope | D11 still posed as a question | Marked answered. |
| 2026-10-15: category depends on Tax Jurisdiction and date (answers D10 "yes") | `IM_Decisions_Needed` row 8 said "not for now" | Marked superseded; design in `IM_Product_VAT_Category_v5_Extension_Note.md`. |
| 2026-10-14 and 2026-10-15: Femi's answers | The decisions sheet listed D1 to D10 as all open | Update block added at the top: what is answered, what is still open. |

## 3. Approval-rule and phone-check decisions (checked, no change needed)

- Approval rule ("the Owner is the final authority"): IM's only approval is the stock adjustment/count approval, by a Store Manager role (`requireStoreManager`) at WRITE. This predates the rule and is **not** the Owner. The adjustment approver moving to EA's approve capability (RBAC T11) is already tracked and is RBAC-frozen. I am **not** changing it; recording it so the owner-final-authority rule is considered when RBAC unfreezes: should an adjustment above some size need the Owner Admin? Needs Femi.
- Phone check (EA SPUTOs): IM has no approval screen of the Business Owner's today. The VAT category set dialog (WEB) will be an Owner Admin/accountant act and should be checked at phone width when WEB builds it. Nothing for IM code.
- Mobile app (online-only, nothing persisted): nothing for IM; confirmed, no offline work. Cache-Control (`no-store, private`) on IM's authenticated responses is owed (Pending sheet); queued, small, add-only.

## 4. Test plan accuracy

Rows resting on unapproved documents (66 in the plan's count) are now mostly approved: the VAT Playbook is approved (v4). Row-by-row notes are in the review block at the top of `IM_Test_Plan.md` (what is built but not deployed, what changed meaning, new rows to add after deploy). I did not edit the generated tables.

## 5. Real findings raised by the review (not wording)

1. **Valuation rounding** (0.48): `TestResultsResponses/IM_Response_to_RT-5_Supplier_Tile_2026-10-15.md`. Needs Femi, option A recommended.
2. **Opening stock has no route** (go-live flag 1) and it is now first-cohort scope. See `IM_Opening_Stock_First_Cohort_Scope_2026-10-17.md`.
3. **Decision sheets drift quickly.** `IM_Decisions_Needed` was five days old and wrong on four items. Suggest CM treat any "decisions needed" sheet as superseded by the Decisions Log the moment the log has a newer line, and the owning session re-check it on restart (done here).
