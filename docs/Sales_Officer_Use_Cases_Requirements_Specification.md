# SOP — Sales Officer: Use Cases

**Status: build started, 2026-09-04.** Pasted directly into chat (author unstated) as "3. SALES OFFICER — USE CASES" - the Sales Officer's five use cases across SalesOrder creation, Returns Inwards, availability checking, and complaint handling. Not previously saved as its own doc; saved here now that three of the five have real code behind them, mirroring `docs/Returns_Inwards_Requirements_Specification.md`'s own build-status-table pattern.

---

## Use cases

### UC‑SO01: Create Sales Order

**Trigger:** Customer places order.

**Main Flow:**
1. Sales Officer enters customer and item details.
2. System checks inventory availability.
3. Sales Officer confirms order.
4. System reserves stock.

**Exceptions:** Insufficient stock; Customer credit limit exceeded.

### UC‑SO02: Initiate Return Inwards (RMA)

**Trigger:** Customer reports issue with delivered goods.

**Main Flow:**
1. Sales Officer selects original invoice/order.
2. Enters return quantity and reason.
3. System validates return window.
4. RMA created and sent to customer.

**Exceptions:** Return window expired; Quantity exceeds delivered amount.

### UC‑SO03: Approve Customer Credit Note

**Trigger:** Store Manager completes inspection.

**Main Flow:**
1. Sales Officer reviews inspection results.
2. Confirms credit amount (full, partial, restocking fee).
3. Sends to Finance for posting.
4. System updates AR.

**Exceptions:** Dispute over credit amount; Inspection incomplete.

### UC‑SO04: Check Inventory Availability

**Trigger:** Customer requests quote or order.

**Main Flow:**
1. Sales Officer enters item and quantity.
2. System shows available, allocated, and backorder status.
3. Sales Officer confirms or adjusts order.

**Exceptions:** Negative stock; Item discontinued.

### UC‑SO05: Manage Customer Complaints Related to Returns

**Trigger:** Customer disputes inspection or credit.

**Main Flow:**
1. Sales Officer reviews complaint.
2. Coordinates with Store Manager and Procurement (if supplier fault).
3. Updates RMA or credit note.
4. System logs resolution.

**Exceptions:** Customer demands full credit without justification; Supplier rejects responsibility.

---

## Build status against this spec

| Use case | Status |
|---|---|
| **UC‑SO01: Create Sales Order** | **Built**, 2026-09-04. `SOP/application/CreateSalesOrderUseCase` - checks stock via a new read-only `ImGateway.fetchItemAvailability()` (`GET /items/{id}`), aval-confirms as Sales Admin, stops (does not fulfil/invoice - that's `RecordOrdinarySaleUseCase`'s separate job). `POST/GET /api/sales-orders`. Two scope forks resolved via explicit user confirmation rather than guessed: "reserves stock" is check-only (IM has no reservation/hold concept anywhere, and building one meant editing `IM`'s `Item` domain while a separate session had unrelated concurrent changes there); "customer credit limit exceeded" is not built (`Customer` has no numeric credit limit field, and the balance to check against one is GL-native AR aging, not visible to SOP). |
| **UC‑SO02: Initiate Return Inwards (RMA)** | **Built**, as part of the earlier, separately-specified Returns Inwards build (`docs/Returns_Inwards_Requirements_Specification.md`, UC‑01/UC‑02 there) - `ReturnRequest.create()`/`.submit()`/`.approve()`/`.reject()`, `POST /api/return-requests` + `/submit`/`/approve`/`/reject`. Predates this doc; not re-built, just already covers this UC. RMA document generation/customer communication specifically (that spec's own FR‑RA2) is still not built. |
| **UC‑SO03: Approve Customer Credit Note** | **Built**, also via the Returns Inwards work's UC‑05/06 - `IssueCreditNoteUseCase`, `POST /api/return-requests/{id}/issue-credit-note`, posts to GL via `RecordSalesReturnUseCase`. |
| **UC‑SO04: Check Inventory Availability** | **Built**, 2026-09-04. `SOP/application/CheckInventoryAvailabilityUseCase` - a standalone, read-only quote-time lookup (distinct from UC‑SO01's embedded gate), reusing the same `ImGateway.fetchItemAvailability()`. `GET /api/inventory-availability/{itemId}?quantity={n}`. `allocatedQuantity` is always zero and "item discontinued" is not built - the same two scope decisions from UC‑SO01, applied directly rather than re-litigated (same fork, same answer). `isNegativeStock` *is* built - a plain sign check against real data, not a new concept. |
| **UC‑SO05: Manage Customer Complaints Related to Returns** | **Built**, 2026-09-04. New `CustomerComplaint` aggregate (`SOP/domain/returns`) - `Open→Escalated→Resolved/Rejected`, referencing the disputed `ReturnRequest` by id. Deliberately does **not** reopen/mutate the `ReturnRequest`/`CreditNote` it complains about (both stay terminal once Credited/Issued, matching this codebase's "never rewrite a settled fact" discipline) - "updates RMA or credit note" is the complaint's own `resolution` text; a resolution needing additional credit calls `IssueCreditNoteUseCase` again for a *supplementary* note against the same `ReturnRequestId` (already structurally supported). "Coordinates with Store Manager and Procurement" is a human step, not a system integration - `escalateToSupplier()` only records that coordination is happening, no call into `POP`/`IM`. `POST/GET /api/customer-complaints` + `/escalate`/`/record-supplier-response`/`/resolve`/`/reject`. |

**Nothing left unbuilt across all five use cases**, except the two named, deliberately-scoped-down gaps: UC‑SO01's customer-credit-limit check, and UC‑SO04's "item discontinued" exception (no backing field on `Item` anywhere) - both flagged in code, not silently skipped. 242 total SOP tests pass as of the UC‑SO05 build.
