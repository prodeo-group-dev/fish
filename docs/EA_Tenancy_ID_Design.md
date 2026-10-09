# EA: a human-readable Tenancy ID, Business ID and sign-in by Tenancy ID (design note, SPUTO-style)

**Status:** 2026-10-09. Revision 3 (adds sections 10.8 to 10.14: Femi's purpose, to keep the Owner's email out of sign-in; design only, nothing built). Revision 2 (revision 1, merged as PR #197, was approved to build). Sections 1-8 are the approved Tenancy ID design, updated for Femi's decision to **drop the `FSH-` prefix** (the ID is just the three groups) and for what is already built (branch `feat/ea-tenancy-id`, V22). **Section 9 (Business ID: a per-Company number) and section 10 (sign in with the Tenancy ID) are new design only; nothing in them is built.** Section 10 is an authentication surface: CM reviews it HIGH before any build. Facts are from EA master and the migrations; items marked **(open)** are not decided here.

**Scope (S).** Every Tenant gets one short ID a business owner can quote to support: on the phone, in an email, on a ticket. It exists because UUIDs are unusable by people, and it ends the confusion of this week, when two Tenants (`9fa2198b-...` and `15734cdc-...`) could not be told apart in conversation. Each Company then gets a number within its Tenant (section 9), and the Owner may sign in with the Tenancy ID (section 10).

## 1. Format

`7K3-MQ9-DX4` (illustrative, not a real value). Eight random characters plus one check character, in three groups of three.

| Choice | Decision | Why |
|---|---|---|
| Alphabet | 31 symbols: digits `2-9` and letters `A-Z` **without `I`, `L`, `O`** (no `0`, `1` either) | Nothing that is confused on a phone line or in a typeface. 31 is prime, which the check character wants. |
| Length | 8 data + 1 check = 9, shown as three groups of three | 31^8 is about 850 billion values: collisions are negligible and the unique index settles any that occur. |
| Prefix | **None** (Femi, 2026-10-09: `FSH-` made it too long) | See "cannot be mistaken" below. |
| Random, not sequential | Cryptographic random at onboarding | A global counter would reveal how many customers FiSH has and invite guessing. |
| Check character | Weighted sum of the 8 data characters (weight = position 1-8) mod 31 | Detects every single wrong character and every swap of two adjacent different characters. |
| Case and separators | Stored upper case with hyphens. Input accepts lower case, spaces and missing hyphens. | People type it three ways. |
| Wrong characters | `0 1 I L O` are **rejected**, not mapped | They cannot occur in a real ID, so a typed one is a typo. |

**Cannot be mistaken for anything else.** The only accepted shape is exactly nine alphabet symbols once spaces and hyphens are removed. A UUID (32 hex digits), a Business ID (twelve, section 9), a word of another length, an email: all are `malformed`. Lookups validate the shape first; no route that takes a UUID accepts it (section 5).

## 2. Assigned once, immutable, unique

- Assigned **inside `Tenant.onboard`** from a `TenancyId` value type, so every Tenant has one from its first save.
- Database: `tenancy_id VARCHAR(11)` with the unique index `ux_tenants_tenancy_id`; the application retries up to three times on a collision (practically never).
- **Immutable:** nothing writes it after insert (the repository's update path never touches the column). An optional trigger refusing `UPDATE ... SET tenancy_id` is recommended with the NOT NULL step (section 3).
- **Never reused**; the index is not partial.

## 3. Backfill of existing Tenants (built in V22)

`tenants` has **no creation timestamp**, so no chronological order exists. The Kotlin migration `V22__Tenancy_id`:
- adds the column nullable, backfills **by `tenants.id` ascending**, seeding each ID from the Tenant's own id (so replaying on a restored database assigns the same IDs; a collision tries the next seed), then adds the unique index. It is idempotent;
- uses the same `TenancyId` code as onboarding, so the check rule exists once;
- is **two-step on purpose**: the column stays nullable until a later migration adds `NOT NULL` (and the immutability trigger), because an old task still running during the rolling deploy would otherwise fail every `POST /tenants`. The two real Tenants' values come from the migration and are recorded by CM in the release note.

## 4. Where it is exposed (built, except where marked)

| Surface | Decision |
|---|---|
| `GET /me` | **Kept out.** Adding a field costs six coordinated deploys (the five strict mirrors plus WEB) for a label no service uses. |
| `GET /tenants/{tenantId}/tenancy-id` | Any ACTIVE member reads `{tenantId, tenancyId}`. Built. Section 9 extends the same response with the Company numbers. |
| Support email to the operator | Names the Tenancy ID. Built. |
| Support relay payload to Omniview, and `OperatorTenantOverviewDto` | Add `tenancyId` **only after** Omniview and WEB's `/operator` page confirm they tolerate the field. **Not built; held.** |
| Operator lookup | `GET /operator/tenants/by-tenancy-id/{code}` (named operator token): `400 malformed`, `400 check_failed` (right shape, wrong check character), `404`. Built. |

## 5. A label; section 10 narrows this for one purpose

- **No authorization route accepts the Tenancy ID in place of the UUID.** Every path that carries `tenantId` keeps a UUID and keeps its Membership check; a pinned test sends the ID where a UUID belongs on eleven routes and expects `400`. Cross-service references stay keyed by UUID.
- **Revised by Femi's decision (2026-10-09):** the Owner may use the Tenancy ID as a **sign-in identifier** (like a username). It is still never a secret and never proves identity; the password does. Section 10 specifies exactly how, and what it does not change.
- It may appear in logs and tickets. It must not be used as a secret in an invite link or token.

## 6. Effect on T15

None on resolution or authorization: Company -> Tenant still returns the UUID, services key on the UUID, `docs/T15_EA_Statement.md` is unchanged. Section 10 adds one note on the user pool (10.6).

## 7. Build state

Built on `feat/ea-tenancy-id` (not merged): `TenancyId` value type and tests; assignment at onboarding with retry; V22; the tenant route; the operator lookup; the support email; integration tests on Postgres 16 including the backfill and replay. Held: the relay and overview fields (section 4), the `NOT NULL` step, sections 9 and 10.

## 8. Open questions (Tenancy ID)

1. Owner-facing label wording ("Tenancy ID" or something closer to how owners say it): Femi and WEB; the data field stays `tenancyId`.
2. May staff see it? Built as yes (any member).
3. Does Omniview tolerate an unknown relay field, or must it declare `tenancyId` first?
4. The immutability trigger with the `NOT NULL` step: recommended yes.

## 9. Business ID: a number per Company within its Tenancy

**What.** Each Company gets a number within its Tenant. The quotable **Business ID** is the Tenancy ID plus the number, `7K3-MQ9-DX4-001`, `-002`, and so on. (CM's example had the `FSH-` prefix; it is dropped here for the same reason.)

**9.1 Assigned inside the registration transaction; never reused.**
- Storage cannot be a column on `tenant_companies`: `ExposedTenantRepository.persist` **deletes and re-inserts that table's rows on every save**, so a number there would be lost. New table `company_numbers (company_id PK, tenant_id, number)` with a **unique `(tenant_id, number)`**, and `tenants.next_company_number INTEGER NOT NULL DEFAULT 1` as the counter. Rows are never deleted.
- Allocation happens **in `persist`, in the same database transaction as the `tenant_companies` insert**: for each Company in the Tenant without a row, `UPDATE tenants SET next_company_number = next_company_number + 1 WHERE id = ? RETURNING next_company_number - 1`, then insert the row. The `UPDATE` takes the Tenant row lock, so **two concurrent registrations for one Tenant are serialised and get distinct numbers**; the unique index is the backstop. Because the counter update is in the same transaction, a rolled-back registration also rolls back its number (no gap), and nothing ever decrements it, so **a number is never reused even if a Company is later closed or retired** (EA has no Company removal today; if one is added, its row stays).
- Idempotent: saving a Tenant again assigns nothing for a Company that already has a number.

**9.2 Immutable, unique, format.** Stored as an integer, formatted by zero-padding to three digits (`001` to `999`) and simply growing past that (`1000`, `1001`, ...). Unique per Company and per `(Tenant, number)`. No route or use case updates it. Business ID = `<tenancy id>-<padded number>`; parsing accepts the same normalisation as the Tenancy ID, and a twelve-symbol input with a valid Tenancy ID part is a Business ID.

**9.3 Backfill.** `tenant_companies` has only `PRIMARY KEY (tenant_id, company_id)` and **no creation timestamp**, and `company_names` has none either: **there is no chronological source.** Proposal: a Kotlin migration `V23` numbers each Tenant's existing Companies **by `company_id` ascending**, so `9fa2198b` gets `001` to `004` and `15734cdc` gets `001`, deterministic and replayable, but not in order of creation. **Ask for Femi:** he knows the real order of the four Companies of `9fa2198b` (Prodeo Capital first, say). The migration can take an explicit ordered list for those four, which costs nothing and gives the numbers meaning. The counter is then set to one past the highest number.

**9.4 Exposure.** Not in `/me` (same reasoning as section 4). `GET /tenants/{t}/tenancy-id`, which is built but unreleased and has no consumer, gains `companies: [{companyId, number, businessId}]`. **The Company wall applies:** the Owner sees every Company; a staff member sees only the Companies they are assigned to. Operator: `GET /operator/tenants/by-business-id/{code}` returns the Tenant and that Company's id and name; the operator Tenant overview may list each Company's Business ID once its consumers tolerate the field (as in section 4). The support email names the Business ID when the ticket names a Company.

**9.5 A label.** Authorization and every cross-service reference stay keyed by the **Company UUID**. No route accepts the number or Business ID in place of a `companyId`; the pinned test is extended to send a Business ID where a `companyId` belongs and expect `400`.

**9.6 GL.** Nothing changes and GL does not need to know. The number lives in EA (`company_numbers`), next to `company_names`. A GL report that should print a Business ID must have it composed by WEB from EA, not read from GL. The Company -> Tenant checks between GL and EA (`docs/T15_EA_Statement.md` section 2.2) are unaffected.

**9.7 Build.** A separate migration `V23` in the same release as V22 (reviewed on its own because its backfill differs; V22 is already built and tested, and folding them would reopen it). About 1.5 days with tests, after CM's review of this section.

## 10. Sign in with the Tenancy ID (Owner only; design, no build)

**Decision (Femi, via CM, 2026-10-09).** The Business Owner may sign in with his Tenancy ID. **Owner only**: staff keep signing in with their own email. The Tenancy ID becomes a sign-in **identifier**, like a username. It is not a secret (it is quotable by design); the password, and later MFA, still proves identity.

### 10.1 Mechanism: options and recommendation

The facts that decide it, read from `Infrastructure/cognito.tf` and WEB: the human app client allows **`ALLOW_USER_SRP_AUTH` only**; the pool uses `username_attributes = ["email"]`; `prevent_user_existence_errors = ENABLED`; WEB signs in with Amplify directly against Cognito. **SRP means the browser needs the Cognito username, and the password never leaves the browser.**

| Option | What happens | Verdict |
|---|---|---|
| **A. EA resolves the Tenancy ID to the Owner's Cognito username (the user's `sub`, an opaque UUID), the browser then does normal SRP sign-in with that username + password.** | WEB sends the identifier to EA, gets back a username, then signs in with Cognito as today. | **Recommended.** No pool change, no change to the client's auth flows, the password never reaches EA, the email is never shown. |
| B. EA resolves to the Owner's **email** and returns it | The browser needs the email to sign in. | **Rejected:** it would hand the Owner's email to anyone who knows a quotable ID. CM's preferred variant (email never shown) cannot work with SRP unless the browser holds a username; the opaque `sub` is the username that can be shown. |
| C. EA signs in to Cognito on the server (needs the password) | EA receives the password, calls Cognito, returns tokens. | **Rejected:** EA would handle passwords and the client would need `USER_PASSWORD_AUTH`/admin flows, a security downgrade from SRP, and a second sign-in path to secure. |
| D. Cognito `preferred_username` alias / custom auth Lambda | Cognito resolves the identifier itself. | **Not feasible without a new pool:** `username_attributes = email` cannot be combined with `alias_attributes`, and it is immutable on an existing pool, so it means a new user pool and migrating every user. Custom-auth Lambdas are heavier and a CM-lane build. |

**Option A in detail.**
- WEB's sign-in screen has one field, "Email or Tenancy ID". An input containing `@` takes today's path unchanged. Otherwise WEB calls **`POST /api/sign-in/identifier`** with `{"identifier": "7K3-MQ9-DX4"}` (POST so the ID never sits in a URL or access log). EA answers `200 {"username": "<uuid>"}`. WEB then calls Amplify `signIn` with that username and the password. Everything after is today's flow.
- EA needs the Owner's Cognito username. EA does not store it today. Proposal: a nullable, unique `users.cognito_sub`, **learned from the `sub` claim of the Owner's own verified token** on any authenticated call (set once; if a different `sub` ever appears for the same email, do not overwrite, and log it). An Owner who has not signed in since the deploy has none yet, so the identifier path fails (generically, 10.2) until his next normal sign-in. CM may instead seed it from a read-only `ListUsers`. **To verify before building (CM, a quick test against the pool): that Cognito accepts the user's `sub` as `USERNAME` in SRP sign-in for an email-as-username pool.**
- Only the **Tenant's `businessOwnerId` user** is resolvable. A Tenancy ID never resolves to staff or to another admin Membership.
- The route is **unauthenticated** (it must be: it runs before sign-in), so it is a new public surface on EA and gets the controls in 10.3.

### 10.2 No enumeration

An unknown id, a malformed id, a valid id whose Owner has no known `sub`, a wrong password, and a Tenant whose Owner has no password must all be indistinguishable to the caller:
- **The resolve endpoint always answers `200` with a UUID-shaped username.** For anything that does not resolve to a real Owner `sub`, it returns a **decoy**: an HMAC-SHA256 of the normalised input under a server secret (`EA_SIGNIN_DECOY_KEY`, in Secrets Manager, provisioned by CM), formatted as a UUID. The same input always gets the same decoy, so repeating a request reveals nothing. Same status, same body shape, same size.
- The browser then runs SRP. Cognito rejects a nonexistent username, a wrong password, and (with `prevent_user_existence_errors` enabled) an unconfirmed or password-less user with the **same masked error**. WEB shows one generic message: "Those details did not work."
- **WEB's own sign-in code already tells apart an unconfirmed account**: `AuthContext.signInWithPassword` handles Amplify's `CONFIRM_SIGN_UP` next step specially. On the identifier path that would reveal that an ID is real and its Owner unconfirmed, so **on the identifier path WEB must map every outcome, including `CONFIRM_SIGN_UP` and any thrown error, to the same generic message** and must not offer to resend a confirmation code.
- **The check character is validated server-side only, and only internally**: a malformed ID is not answered with `malformed`/`check_failed` (those belong to the operator lookup, which is authenticated by the operator token). WEB may use the public check rule **locally** to say "that ID looks mistyped" before sending anything; it reveals nothing about which Tenants exist. CM may prefer to drop that nicety.
- **Same work, same timing class:** every request does the same steps in the same order (normalise, compute the HMAC, run one indexed lookup, with a dummy key for malformed input), with no early return on malformed or unknown. **To verify in a test:** response-time distributions for the cases are indistinguishable at the level a remote caller can measure.

### 10.3 Rate limiting and lockout

The Tenancy ID is quotable, so treat it as semi-public.
- **Per source and per identifier** (the normalised ID, or a hash of it) with the existing `FixedWindowRateLimiter`; plus a global ceiling for the route. The over-limit answer is the **same `429` for every input**, so it leaks nothing. CM adds an ALB/WAF rate rule in front (CM lane).
- The per-ID limit throttles **only the resolve call**. It never locks the Owner's account, so an attacker cannot lock an Owner out by hammering his quotable ID; his email sign-in is unaffected.
- Password guessing happens at **Cognito**, which has its own brute-force protection (progressive lockout). The identifier path does not weaken it, and it makes no new password oracle: the resolve answer is the same whether or not the ID is real.
- Guessing a valid ID is not the threat (about 850 billion values, and the answer never says whether a guess hit); the realistic threat is a quoted ID plus a guessed password, which is exactly what rate limits and Cognito's lockout address, and what MFA closes.

### 10.4 It bypasses nothing

- The resolve route returns **only a username**. It issues no token and makes no authorization decision.
- Sign-in is the same Cognito SRP flow, so the result is **the same human token**; EA's `toAuthenticatedCaller` still resolves the User by the token's `email` claim, then Memberships. `/me` and every gate are unchanged. MFA, when enabled at Cognito, applies to this path automatically.
- No EA route accepts a Tenancy ID as authentication or authorization (section 5); the only new unauthenticated route is the resolve call.
- The `cognito_sub` mapping is read only by the resolve route and is not used for any authorization.

### 10.5 Owner not yet verified, or Tenant suspended

Sign-in is **identity, not authorization**, so the resolve answer must **not depend on Tenant or verification status** (it must not reveal them):
- An Owner whose KYC/KYB or phone verification is unfinished **must be able to sign in**: the verification flows require a signed-in Owner, so blocking sign-in would deadlock verification.
- A **suspended** Tenant: the Owner signs in, `/me` reports `tenantStatus: SUSPENDED`, and what a suspended Tenant may do is the open T15 question of uniform status enforcement (`docs/T15_EA_Statement.md` section 8, item 3). Nothing in this feature changes that; it must be decided once for all services.
- A Cognito-disabled Owner: Cognito's masked error, like any wrong password.

### 10.6 T15 and the user pool

One Cognito user pool serves all Tenants and stays so. Tenancy IDs are globally unique, so an identifier maps to at most one Tenant, hence one Owner, and `sub` is unique across the pool. A person who owns two Tenants has two Tenancy IDs that both resolve to the same user: harmless. No per-Tenant pool is implied. The services never see the Tenancy ID or the `sub`; T15's Company -> Tenant resolution is untouched.

### 10.7 What this needs, and what is open

| # | Item | Owner |
|---|---|---|
| S1 | CM verifies in a test that `sub` works as `USERNAME` for SRP in this pool, and that unconfirmed or password-less users give the same masked error | CM |
| S2 | `users.cognito_sub` (nullable, unique) learned from the Owner's own token; optional seeding from a read-only `ListUsers` | EA, CM |
| S3 | `POST /api/sign-in/identifier` with decoy, constant work, rate limits; the HMAC secret `EA_SIGNIN_DECOY_KEY` | EA, CM |
| S4 | WEB sign-in field "Email or Tenancy ID", one generic failure message | WEB |
| S5 | ALB/WAF rate rule for the route; CloudWatch alarm on a spike of resolve calls | CM |
| S6 | Tests: indistinguishable answers, timing class, rate-limit answer, Owner-only, status-independent | EA |

Open: (1) whether WEB shows the local "looks mistyped" hint; (2) whether the identifier path should be limited to Tenants that have completed some verification (EA recommends **no**, per 10.5); (3) MFA timing (not a prerequisite).

### 10.8 Purpose, and what this can and cannot achieve (Femi, 2026-10-09)

**Purpose.** Many people know an Owner's email, and a little social engineering with a known email gets them toward the account. The Tenancy ID should be the **preferred, primary** Owner identifier, so the email stops being a handle for an attack.

**The honest limit.** The Tenancy ID is quotable *by design* (phone calls, tickets, emails), so it is a weak secret. Taking the email out of sign-in raises the attacker's bar from "know the email" to "also learn an ID the Owner says aloud". That is obfuscation, **not authentication**. What actually defeats social engineering is the second factor (10.12) and a hardened recovery flow (10.10). So the plan is staged, strongest first:
1. **MFA for Owner Admins** (10.12), the real protection.
2. **Recovery that starts from the Tenancy ID** and never shows an address (10.10).
3. **Tenancy ID as the preferred identifier** in WEB (10.1, already designed), with the email copy changed (10.11).
4. **Optionally** refuse the email form for Owner Admins at Cognito (10.9), the costliest step with the narrowest benefit once 1 to 3 exist.

### 10.9 Can email sign-in be turned OFF for Owner Admins?

**Fact that frames it.** In this pool the human client accepts the email as USERNAME (it is an alias) as well as the `sub`, so knowing the email still allows a direct Cognito attempt, with no help from EA.

**Option 1 (recommended if Femi wants it): a pre-authentication Lambda trigger that requires proof of the identifier path for Owner Admins.**
- EA's resolve route (10.1) also returns a short-lived **sign-in proof**: an HMAC token bound to the Owner's `sub`, valid about two minutes, single use where practical. WEB passes it in Amplify's `signIn` as `clientMetadata`, which Cognito hands to the trigger as `validationData`.
- The trigger runs for every sign-in. It reads the user's attributes from the event (no call to EA, so Cognito sign-in never depends on EA being up). For users flagged **Owner Admin** (a new custom attribute, `custom:owner_admin`, set by CM's backfill for the two real Owners and at onboarding thereafter) it verifies the proof and **refuses before the password is checked** when it is missing or invalid. Staff, and any user without the flag, pass straight through.
- Effect: an attacker who knows only the email can no longer even reach the password check for an Owner. Anyone holding a Tenancy ID can still obtain a proof (the resolve route is public), so this is "email alone is no longer enough", not "unguessable".
- **To verify in a test (S1b):** the trigger event carries the user's resolved Username and `validationData`, but, as far as I know, **not which alias the caller typed**, which is why the design uses a proof instead of testing "is it an email".
- **Costs, all CM's lane:** a Lambda, its IAM role, deploy and monitoring; a custom attribute on the pool (addable to an existing pool, but permanent); a flag backfill and an onboarding step that sets it (EA needs `cognito-idp:AdminUpdateUserAttributes`, or CM sets it); a little latency on every sign-in (a cold start); and **a failure mode: if the Lambda errors, sign-in is blocked for everyone**, so it needs an alarm and a safe deploy.
- **A small disclosure it adds:** the refusal comes back as a Lambda error, whose text differs from Cognito's native "incorrect username or password", so a probe can tell "this email is a Business Owner account". The attacker already knows the email, so this reveals only that it is an Owner. A different design could make every case identical, but at the price of forcing proof on staff too. CM decides whether the disclosure is acceptable.
- **Owners who are also staff elsewhere** (the tester is Owner of one Tenant and staff of another): the flag is per person, so they use the Tenancy ID path for everything. Acceptable; a note for WEB copy.
- **Effect on SRP and our services:** the SRP exchange is unchanged; WEB adds one `clientMetadata` field. The token, `/me` and every service are unchanged.

**Option 2: a new user pool with no email alias** (Tenancy ID as the username). **Rejected for now.** Passwords cannot be copied between pools (only a user-migration Lambda that rebuilds them as each user signs in once), every user is recreated with a new `sub`, and **every service verifies tokens against this pool's issuer and keys** (EA, GL, POP, SOP, IM, HR, ER), so it means coordinated reconfiguration and a cutover of all of them. The cost is out of proportion to the benefit.

**Not possible:** Cognito offers no setting to refuse an alias for some users, and no trigger on `ForgotPassword` (10.10).

### 10.10 Password recovery starts from the Tenancy ID

Cognito's `ForgotPassword` sends a code to the verified email and, by default, returns a *masked* address (`j***@e***.com`) to the caller. Requirements: it starts from the Tenancy ID, never an email field; the code goes to the registered address; nothing about the address is revealed; unknown IDs get the same answer.
- **Flow.** WEB's "Forgot password?" asks for the Tenancy ID only and calls `POST /api/sign-in/recovery` `{identifier}`. EA **always answers the same `202`** with the same body. For a real Owner with a known `sub`, EA calls Cognito `ForgotPassword` **server-side** with that username and **discards the delivery details** (the masked address), so neither WEB nor the caller ever sees even a masked address. For anything else it does equivalent work and sends nothing (the decoy path of 10.2). WEB then asks for the code and the new password and calls Cognito `ConfirmForgotPassword` **directly**, using the username from a normal resolve call, so the new password never passes through EA.
- **Controls.** Tighter limits than sign-in (for example 5 per hour per ID and 3 per hour per source, the same `429` for everything), a per-ID cooldown, and an alarm on spikes. A "your password was changed" notice goes to the registered address.
- **The limit that cannot be closed here.** Anyone can still call Cognito's `ForgotPassword` **directly with the email**, and receive the masked address; no trigger can refuse it. What reduces the harm: (a) the code only goes to the owner's own inbox; (b) the Custom Message trigger can word the email ("If you did not ask for this, ignore it. Never read this code to anyone, including FiSH staff."); (c) **MFA** (10.12) means a stolen reset code still cannot sign in; (d) an alarm on reset spikes. The real attack here is a phone call asking the Owner to "read out the code we just sent"; only MFA, the email wording and a standing rule that **FiSH staff never ask for a code** address it.

### 10.11 Other places the email is exposed or accepted

| Place | Today | Disposition |
|---|---|---|
| WEB login form | "Email" field and copy | Change to "Tenancy ID or email"; tell Owners to use the ID (WEB). |
| Sign-up wizard, confirmation and resend | The email is how an account is created and confirmed | Unavoidable once. Show the Tenancy ID prominently at the end of onboarding and in a welcome email (EA/WEB). |
| Cognito emails (verification, reset) | Default templates print the username (the `sub`) | CM sets Custom Message templates that print neither the email nor the `sub`. |
| `GET /me` | Returns the caller's **own** email to themselves | Stays; the five strict mirrors need it. |
| Team list `GET /tenants/{t}/memberships` | Returns every member's email, **the Owner's row included**, to the Owner and to an HR delegate at ADMIN | EA: a delegate should not see the Owner's email. To confirm in code and fix, behind CM's go. |
| Staff invites | The invitee's email is their staff sign-in; the invite page shows `invitedEmail` to the secret holder (the invitee) | Fine. |
| Support thread and operator email | The operator email names the sender's email; Omniview shows the Owner's email to named operators | Acceptable for support, but **support must verify a caller by the Tenancy ID, never by the email**. |
| **SOP invoices** | `GET /internal/companies/{id}/owner-contact` gives SOP the **Owner's login email as the invoice Reply-To** (Femi, 2026-10-06), so **every customer who receives an invoice learns the Owner's email** | **Direct conflict with this purpose.** Proposal: an optional `contactEmail` on the Company profile (same pattern as the VAT number) for documents; the owner-contact route returns that, and **nothing** (no Reply-To) when unset, never the login email. A decision for Femi. |
| Education Runtime first admin | EA passes the Owner's email to ER (`PUT /schools/{id}/first-admin`), and ER identifies school admins by email | ER session to say who in ER can see it. |
| HR and other services | Employee records hold emails | Out of scope here. |
| **The Business ID on documents** | Section 9's Business ID **contains the Tenancy ID** | **If it is printed on invoices or other external documents, every recipient learns the Tenancy ID**, which makes it close to public and leaves the password and MFA as the only protection. Either do not print the Business ID externally, or accept that the Tenancy ID is public. A decision for Femi. |

### 10.12 MFA for Owner Admins (the control that answers social engineering)

- **Type.** TOTP (an authenticator app) first. SMS is weaker (SIM swap) and is parked in this project (the SMS channel is not subscribed).
- **Pool (CM).** `mfa_configuration = "OPTIONAL"` with `software_token_mfa_configuration { enabled = true }`. That is a non-destructive change to the live pool, to be tried with a throwaway test user first. No SMS configuration.
- **Requiring it for Owners only.** Cognito cannot require MFA for some users in an OPTIONAL pool. Two ways: (a) `mfa_configuration = "ON"` for **all** users, simple and strongest but it burdens staff; (b) keep OPTIONAL and **enrol every Owner at onboarding**: WEB forces TOTP enrolment (`setUpTOTP`, the QR code, `verifyTOTPSetup`) before the Owner reaches anything else, and the user's own `SetUserMFAPreference` makes it the required method, after which Cognito challenges every sign-in. **The gap in (b):** until enrolment completes, the account has no second factor. The window is the moment right after registration, when the account is new, and for the two existing Owners their next sign-in. An attacker who guessed the password in that window could enrol their own device, so enrolment must be the first thing a new Owner is asked for.
- **On this flow.** After SRP the challenge is `CONFIRM_SIGN_IN_WITH_TOTP_CODE`, which WEB's `signInWithPassword` does not handle today (it throws on any step other than `CONFIRM_SIGN_UP`). WEB builds the code step and the enrolment screen. The sign-in proof (10.9) and MFA are independent and compose.
- **Recovery interplay.** A password reset (10.10) still leaves MFA in force, so a stolen reset code alone is not enough.
- **The new weak spot is device loss.** Cognito has no backup codes. The recovery path is a strict, documented operator process (identity checks beyond the email, Tenancy ID and a recent business fact), with Femi owning the policy, plus encouraging two enrolled devices where the authenticator app allows. This must be decided before MFA is required.

### 10.13 An owner who forgot the Tenancy ID

It is not a secret and is easy to find: it is on the signed-in screens (`GET /tenants/{t}/tenancy-id`), in the welcome email, and any member of the Tenant can read it. The recovery path must not become the new weak spot:
- **Self-service reminder.** A form takes an **email** and always answers the same generic text ("If an account exists, we have sent the Tenancy ID to the address on file") through `POST /api/sign-in/remind`; EA sends the ID **only to the registered address** by email, never on screen. The ID is not a secret, so a reminder to the owner's own inbox gives an attacker nothing, and the answer never confirms whether the email exists. Rate limited per email and per source to prevent mailbox harassment.
- **Support.** An operator may look a Tenant up by the Owner's registered email in Omniview, but **sends the ID only to the registered address and never reads it out or confirms it by phone**, which is the exact social-engineering route this feature is meant to close.
- **Until step 4 of 10.8, email sign-in still works**, so an Owner who has forgotten the ID is never locked out. After step 4, the reminder and the support route above are the way back, plus the colleague route (any member can read it).

### 10.14 Additions to the build list and open questions

| # | Item | Owner |
|---|---|---|
| S7 | TOTP on the pool (`OPTIONAL`), tested with a throwaway user; the Owner enrolment and TOTP-challenge screens | CM, WEB |
| S8 | `POST /api/sign-in/recovery` (server-side `ForgotPassword`, delivery details discarded) and `POST /api/sign-in/remind` (SES) | EA |
| S9 | Optional step 4: the pre-authentication Lambda, the `custom:owner_admin` attribute, the proof from the resolve route, the flag backfill | CM, EA |
| S10 | Custom Message templates (no email or `sub` printed; the "never read out this code" wording) | CM |
| S11 | Hide the Owner's email from delegates in the Team list; the invoice Reply-To change (`contactEmail`) | EA, SOP |

Open for Femi: (1) whether the Business ID is printed on external documents (10.11); (2) the invoice Reply-To (10.11); (3) MFA for all users or Owners only, and the device-loss policy (10.12); (4) whether step 4 (the Lambda) is wanted at all once MFA exists; (5) whether CM accepts the "this is an Owner account" disclosure of step 4.

*Verified 2026-10-09 by reading `Infrastructure/cognito.tf` (SRP only, `username_attributes = email`, `prevent_user_existence_errors`), `WEB/src/auth/`, `Auth.kt`, `ExposedTenantRepository.persist`, `V1__baseline.sql`, `V9`, and the built branch `feat/ea-tenancy-id`. Not verified: that Cognito accepts `sub` as `USERNAME` here (S1) and what the pre-authentication event carries (S1b); Cognito `ForgotPassword` behaviour with the SPA client and no secret; MFA behaviour on this pool, Omniview's decoding strictness, production data.*
