# EA: a human-readable Tenancy ID (design note, SPUTO-style)

**Status:** 2026-10-09, docs only, nothing built. Written by the EA session at CM's request (Femi's requirement). Do not build until CM has reviewed this. Facts are from EA master (`bcc25a6`): `tenants` has no creation timestamp, `/me` is mirrored strictly by GL, POP, SOP, IM, HR and WEB, and the operator surface is `/operator/tenants` plus the support relay.

**Scope (S).** Every Tenant gets one short ID a business owner can quote to support: on the phone, in an email, on a ticket. It exists because UUIDs are unusable by people. It also fixes a real confusion from this week, where two Tenants (`9fa2198b-...` and `15734cdc-...`) could not be told apart in conversation. **Out of scope:** any authorization role (section 5), Company ids, user ids.

## 1. Format (recommendation: random-looking, 9 characters plus a check character, grouped in threes)

`FSH-7K3-MQ9-DX4` (illustrative, not a real value).

| Choice | Recommendation | Why |
|---|---|---|
| Alphabet | 31 symbols: digits `2-9` and letters `A-Z` **without `I`, `L`, `O`** (no `0`, `1` either) | Nothing that is confused on a phone line or in a typeface. 31 is prime, which the check character wants. |
| Length | 8 data characters + 1 check character = 9, shown as three groups of three | 31^8 is about 850 billion values: collisions are negligible and the unique index settles any that occur. Three groups of three are easy to read aloud and to copy. |
| Prefix | `FSH-` (display only) | Says whose ID this is when quoted out of context. Not stored in the data part. **(open: Femi may prefer another prefix or none.)** |
| **Random, not sequential** | **Random-looking** (cryptographic random at onboarding) | A sequential ID (like POP's per-Tenant PO numbers) is fine inside one business, but a **global** counter would tell anyone the count and growth of FiSH customers, and invites guessing the next one. Per-Tenant PO numbers leak nothing of this kind; a global Tenancy ID would. |
| Check character | One check character, **weighted sum mod 31** (weight = position, 1 to 8) | Detects every single mistyped character and every swap of two adjacent different characters, so support can say "that ID is mistyped" instead of "not found". Simple enough to implement identically in Kotlin and in a test. |
| Case and separators | Stored canonical: uppercase, hyphens as shown. Input accepts lower case, spaces and missing hyphens; they are normalised before the check. | People type it three ways. |
| Wrong characters | `0`, `1`, `I`, `L`, `O` are **rejected**, not silently mapped | They cannot occur in a real ID, so a typed one is a typo; the response says so. |

## 2. Assigned once, immutable, unique

- Assigned **inside `Tenant.onboard`** from a `TenancyId` value type (`generate(random)`, `parse(text)`, `isValid`), so every Tenant has one from its first save. No Tenant exists without one.
- Database: `tenancy_id VARCHAR(15) NOT NULL UNIQUE` (the unique index is the backstop; the application retries up to three times on a collision, which is practically never).
- **Immutable:** no route and no use case writes it after creation, and the repository's save never updates the column. Belt and braces: a small trigger refusing `UPDATE ... SET tenancy_id` (optional, **recommended**, because "immutable" is a promise support will rely on when quoting it years later).
- **Never reused.** An ID is retired with its Tenant; the unique index is not partial.

## 3. Backfill of existing Tenants

EA has two real Tenants today (`9fa2198b-2a6f-467d-97ac-6f6fbce6a9fd` and `15734cdc-a4c4-4630-8b76-761b0c38372f`) and any test Tenants. `tenants` has **no `created_at`**, so a chronological order does not exist to follow. Instead:
- **Deterministic order: by `tenants.id` ascending.** Not chronological, but stable and reproducible.
- **Deterministic values:** the backfill seeds the generator from each Tenant's own id, so replaying the migration on a restored copy of the database assigns the same IDs. New Tenants after the migration use real random values. A collision during backfill re-draws with the next seed step.
- **Mechanism:** a Flyway **Kotlin migration** (`BaseJavaMigration`) so the backfill uses exactly the same `TenancyId` code as onboarding rather than a second SQL copy of the check-character rule. (A SQL-only backfill is possible but would duplicate the algorithm.)
- **Two-step rollout, because EA deploys with a rolling window.** Step 1 (this migration): add the column nullable, backfill, add the unique index; onboarding code starts assigning one. Step 2 (a later migration, once step 1 is verified live): `SET NOT NULL` and add the trigger. Doing both at once would make an old task, still running during the deploy, fail any `POST /tenants` with a null violation.
- The actual values for the two real Tenants are produced by the migration and **recorded by CM in the release note**; they are not invented here.

## 4. Where it is exposed

| Surface | Recommendation | Rollout constraint |
|---|---|---|
| **`GET /me`** | **Keep it out of `/me` for now.** | Adding a field means GL, POP, SOP, IM, HR (strict mirrors) and WEB must each declare it **before** EA ships (six deploys) for a label that none of those services use. Fold it into `/me` later, if ever, with the next change those mirrors need anyway. |
| **A Tenant route (new)** | `GET /tenants/{tenantId}/tenancy-id` -> `{tenantId, tenancyId}`. Any ACTIVE member of the Tenant may read it (it is a label, not a secret); the Owner Admin is the one who needs it, and WEB shows it in the business header or help menu. | Additive, no consumer affected. WEB builds against it. |
| **Support thread and tickets** | Add the Tenancy ID to (a) the operator notification email (`From: x (Tenant <uuid>)` becomes `... Tenancy ID FSH-...`), and (b) the support relay payload to Omniview as an additive `tenancyId` beside `tenantId`/`tenantName`. | Omniview must declare the field before EA sends it if its decoding is strict **(open: Omniview to confirm)**. |
| **Operator console** (`/operator/tenants`) | Add `tenancyId` to each row of `OperatorTenantOverviewDto`. **New operator-only lookup:** `GET /operator/tenants/by-tenancy-id/{code}` returns that Tenant's overview row; answers `400 check_failed` when the check character is wrong, `404` when well-formed but unknown. | Two consumers read the overview today (WEB `/operator` and Omniview's own console): both must tolerate the new field before EA ships. |

## 5. A label, never a credential

- **No authorization route accepts the Tenancy ID in place of the UUID.** Every path that carries `tenantId` keeps a UUID and keeps its Membership check. The only lookup by Tenancy ID is the **operator-only** route above (named per-operator token), whose job is "which Tenant is this caller talking about", answering with data the operator could already list.
- Knowing or guessing an ID grants nothing, reveals nothing to a non-operator, and is not rate-limit sensitive; the check character exists for typos, **not** as a security feature (it is public and trivially recomputed).
- It may appear in logs and tickets (that is its purpose). It must not be used as a secret in an invite link, token or URL that grants access.
- A test asserts that every `/tenants/{tenantId}/...` route returns 400 (not a lookup) when given a Tenancy ID instead of a UUID.

## 6. Effect on T15

None on resolution or authorization: Company -> Tenant still returns the **UUID**, services still key on the UUID, and `docs/T15_EA_Statement.md` is unchanged. It helps T15 in practice: with several Tenants side by side, support and the owner can name the right one unambiguously.

## 7. Build outline (after CM's review and go)

1. `TenancyId` value type + tests (alphabet, check character, normalisation, every single-character error detected, adjacent swaps detected).
2. `Tenant.onboard` assigns it; table column and unique index; repository; retry on collision.
3. Kotlin backfill migration with an integration test on Postgres 16 (existing Tenants get stable, unique, valid IDs; a second run changes nothing).
4. `GET /tenants/{t}/tenancy-id`; operator row field and `by-tenancy-id` lookup; support email and relay payload field.
5. Later migration: `NOT NULL` + immutability trigger.
Estimate: about 2 days for 1-4 with tests, plus the consumer declarations in WEB and Omniview.

## 8. Open questions

1. **Wording** of the label shown to the owner: "Tenancy ID" (Femi's term) or a name closer to how owners think of their business. WEB and Femi decide; the data field stays `tenancyId`.
2. Prefix `FSH-` or something else, or none.
3. May **staff** see it, or the Owner Admin only? (EA recommends any member: it is not a secret.)
4. Does Omniview's support-relay decoding tolerate an unknown field, or must it declare `tenancyId` first?
5. Whether to add the immutability trigger (EA recommends yes).

*Verified 2026-10-09 by reading `V1__baseline.sql`, `Tenant`, `OperatorTenantOverviewRoutes.kt`, `SubmitToOperatorThreadUseCase.kt`, `SupportRelayService.kt`, `MeRoutes.kt`/`Dtos.kt`. Not verified: Omniview's decoding strictness, production data.*
