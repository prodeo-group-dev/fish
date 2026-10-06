# Omniview Support, Wave S3: self-serve contract (EA relay, WEB, Omniview)

**Status:** DRAFT 1, 2026-10-05, written by the Omniview session for EA's and WEB's review. Backlog rows S3.1 to
S3.3, S3.5, S3.6 and S1.8 in `docs/Omniview_Support_Model_Backlog.md`; requirements FR-SUP-C1 to C5 and UC-SUP-6.
**Omniview's side is built and tested** (fish-er-omniview branch `feat/omniview-support-s3`, awaiting CM). EA and
WEB build theirs against this draft, **after** EA's Product Support relay release; nothing here changes a route
EA already relays except one **optional, additive** field on ticket create (section 3).

## 0. What this is for

The cheapest ticket is the one that is never raised. A help library the Owner Admin (and their staff) can search
inside FiSH, suggested answers while typing a ticket, and a one-tap rating when a ticket is closed. Omniview owns
the articles and the ratings; FiSH **pulls** them through the relay (Omniview never pushes, and is never reached by a
browser).

## 1. Omniview private API (already built)

All under `/internal`, authenticated as a service exactly like the ticket routes (the relay's credential; no other
caller). Strict decoding on requests (an unknown field is `400 validation_failed`). Errors are `{error, detail?}`.

### 1.1 Articles: published, tenant-free, read-only

```
GET  /internal/articles?q=&family=&jurisdiction=&industry=&module=&language=
GET  /internal/articles/{key}
POST /internal/articles/{key}/view
```

Nothing here takes or returns a tenant or a user, so the relay needs no per-tenant check on these three, and a view is
counted **anonymously** (a daily counter per article, no tenant, no user).

**Search** returns at most **20** published articles, best match first (a title hit, then a summary hit, then a body
hit; newest first within each). A filter value matches an article **for exactly that value or for everyone** (an article
with no country is for all countries), so asking for Ireland also returns the general articles. `language` defaults to
`en`. `q` is at most 200 characters; `%`, `_` and `\` in it are ignored. Invalid filter values are `400
validation_failed` with a detail (`family_invalid`, `jurisdiction_invalid`, `industry_invalid`, `module_invalid`,
`language_invalid`, `q_too_long`).

```json
[ { "key": "uuid", "title": "How to reopen a period", "summary": "Reopen a closed accounting period.",
    "family": "PERIOD_END", "jurisdiction": "IE", "industry": "GENERIC", "module": "GL", "language": "en",
    "updatedAt": "2026-10-05T10:00:00Z" } ]
```

`family`, `jurisdiction`, `industry` and `module` are **absent** when the article is for everyone. **No body in the list.**

**Read** returns the same fields plus `body`; `404 {"error":"article_not_found"}` for an unknown, draft or retired key.

**View** returns `204`; `404 article_not_found` for anything not published. Call it **once when a user opens an
article**, not on every render.

**Body format (WEB renders it):** plain text. A blank line starts a new paragraph; a line starting with `- ` is a list
item. **No HTML, no Markdown, no links.** Render it as text (React escapes it); never as HTML. The same rule the widget
already applies to ticket text.

Values: `family` is one of GETTING_STARTED, VERIFICATION, MIGRATION, HOW_TO, ACCESS, FAULT, PERIOD_END, TAX_STATUTORY,
BILLING, SECURITY, DATA_REQUEST, SERVICE_STATUS, FEEDBACK, OTHER. `jurisdiction` is UK, IE, NG, SL, LR, GN or CI.
`industry` is GENERIC or SCHOOL. `module` is EA's `ManagedModule` names. A new value is a lockstep change Omniview
announces first.

### 1.2 Rating a closed ticket (S1.8, S3.6)

```
POST /internal/tenants/{tenantId}/tickets/{ticketId}/rating     { "userId": "uuid", "rating": 1..5, "comment"?: "..." }
GET  /internal/tenants/{tenantId}/tickets/{ticketId}/rating
```

Tenant-scoped like every ticket route (another tenant's ticket is `404 ticket_not_found`). **Rules:** the ticket must
be CLOSED (`409 ticket_not_closed`); a rating is given **once**: the same rating and comment again is a `200` replay,
a different one is `409 rating_already_given`; `rating` outside 1 to 5 is `400 validation_failed` (`rating_invalid`);
`comment` is optional, trimmed, at most 500 characters, no control characters (`comment_invalid`). The comment is
tenant-written text: plain text, shown to operators only.

Both answer `200` with a **strict, closed shape**:

```json
{ "rated": true, "rating": 4, "comment": "Clear answer" }        // or { "rated": false }
```

The **existing ticket summary and message shapes are unchanged**; whether a ticket has been rated is read from this
GET, so EA's strict decoding of the ticket routes is not touched.

## 2. What EA relays (new routes; EA's design, proposed here)

| Route (EA, public) | Who | Calls |
|---|---|---|
| `GET /support/articles?...` | **any signed-in FiSH user** (not only an Owner Admin) | `GET /internal/articles` |
| `GET /support/articles/{key}` | same | `GET /internal/articles/{key}` |
| `POST /support/articles/{key}/view` | same | `POST /internal/articles/{key}/view` |
| `POST /tenants/{tenantId}/support/tickets/{ticketId}/rating` | Owner Admin of the tenant | `POST .../rating` with the caller's `userId` |
| `GET /tenants/{tenantId}/support/tickets/{ticketId}/rating` | Owner Admin of the tenant | `GET .../rating` |

**Why any signed-in user may read articles:** ticket raising stays Owner-Admin-only (decided), but an employee who is
told "ask your Owner Admin" should at least be able to read the answer first. The articles are Prodeo's own help text,
not tenant data, so there is no tenant check; EA should still require a signed-in user and **rate-limit** the three
article routes per user (the view route especially) so nobody scrapes or inflates the counters. Per-user limits are
EA's to size; Omniview does not limit them.

EA relays Omniview's errors and shapes unchanged and maps an unreachable Omniview to its existing `503
support_unavailable`. EA does not store article text.

## 3. Ticket create: one more optional field (S3.3)

`POST /internal/tickets` already accepts the optional `context` object (S2, `docs/Omniview_Support_S2_Tenant_Context_Contract.md`).
It gains one optional key:

```json
"context": { "viewedArticles": ["uuid", "uuid"] }
```

The keys of the articles the user opened **before raising this ticket** (at most 5, UUIDs, deduplicated). Omniview
keeps only keys of articles that exist and shows their titles to the operator ("had already read: ..."), so the operator
does not repeat them; an unknown key is ignored, never an error for the tenant. It is part of the idempotency
fingerprint, never returned through the relay, and an invalid value (not a UUID, more than 5) is `400 validation_failed`
(`context_viewed_articles_invalid`). Old callers that omit it keep working.

## 4. What WEB builds (proposed)

1. **A help screen**: a search box and filters (country, industry; module defaulted from the screen the user came from).
   Industry defaults from the Company in view. **Country has no source in EA** (jurisdiction is GL's), so offer a
   chooser and default to "all countries" until a source exists. Results are titles and summaries; opening one calls
   the read route and then the view route, and renders the body as plain text.
2. **Suggested answers while typing a ticket**: after a short pause, search with the words typed (at most 3 results),
   shown above the send button. Sending the ticket stays one tap. Remember the keys the user opened this session and
   send them as `viewedArticles`.
3. **A rating prompt on a closed ticket**: five choices and an optional short comment; call the rating route once; hide the
   prompt when `GET .../rating` says `rated`. A failed call keeps what the user typed.
4. Employees see the help library and the "ask your Owner Admin" note, as decided.

## 5. Rollout order

1. **Omniview** (done, awaiting CM): the routes above and the `viewedArticles` key.
2. **EA**, after its Product Support relay release: the five relay routes (and passing `viewedArticles` through on create).
3. **WEB**: the help screen, suggestions and the rating prompt.

Until the articles are written there is nothing to show, so **Prodeo writes a first set** (the how-to and access
questions, per the support catalogue) in the Omniview Articles tab before WEB turns the screen on.

## 6. Questions

1. **EA:** may any signed-in user read the articles (section 2)? What per-user limits suit the three article routes?
2. **WEB:** is the country chooser acceptable until a jurisdiction source exists, or should WEB offer none for now?
3. **Both:** is `language` a user setting today? Omniview filters on it and defaults to `en`; French is a precondition for Guinea and Côte d'Ivoire (SD6).
