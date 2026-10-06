# Omniview Support, Wave S4: notices, incidents and problems (contract)

**Status:** DRAFT 1, 2026-10-05, written by the Omniview session for EA's, WEB's and CM's review. Backlog rows S4.1 to
S4.4 in `docs/Omniview_Support_Model_Backlog.md`; requirements FR-SUP-D1 to D10, UC-SUP-9 to 13.
**Omniview's side is built and tested** (fish-er-omniview branch `feat/omniview-support-s4`, stacked on S3, awaiting CM).
Everything here is **additive**: no route EA already relays changes. The only thing EA and WEB need to build is the
**one pull route** in section 1 and a **banner** in the app. Incidents and problems never reach a browser directly: what
people see is a notice or a reply on their own ticket.

**Where the relay lives is still open** (EA declined; options A to D are with CM and Femi). Section 4 is the
relay-agnostic contract: the routes below are service-authenticated, and the published-content alternative (option D)
is in `docs/Omniview_Support_Published_Content_Contract.md`.

## 1. The pull route (the only new thing the relay calls)

```
GET /internal/tenants/{tenantId}/notices?module=GL&module=HR&industry=SCHOOL&jurisdiction=IE
```

Authenticated exactly like the other `/internal` routes (the relay's service credential). Strict, like every route:
`400 validation_failed` with a detail for a malformed `tenantId` or a bad value (`module_invalid`, `industry_invalid`,
`jurisdiction_invalid`, `too_many_values`: at most 10 of each).

The three filters say **what this person is looking at**, so the app asks per screen or per session, not per tenant:

- `module`: the modules the person's Company has enabled, or the module on screen (`GL`, `HR`, `SOP`, `POP`, `IM`,
  `TAX`, `EDUCATION_RUNTIME`). Repeat the parameter for several.
- `industry`: the Company's industry (`GENERIC`, `SCHOOL`).
- `jurisdiction`: the Company's country code (a two or three capital letter code; Northern Ireland is `UK`).

**Any of them may be omitted. An omitted dimension means "I do not know", and the answer then fails open** for that
dimension (a maintenance or statutory notice is shown rather than hidden by missing data). A notice that names
**tenants** is **strict**: only those tenants ever see it, whatever else is passed.

Response `200`, at most **20**, most serious first, then newest:

```json
[ { "id": "uuid", "kind": "STATUTORY_CHANGE", "severity": "WARNING",
    "title": "Irish VAT rate change on 1 July", "body": "The 9 percent rate applies from 1 July 2026.",
    "effectiveFrom": "2026-10-05T08:00:00Z", "effectiveTo": "2026-11-05T08:00:00Z", "articleKey": "uuid",
    "appliesTo": { "modules": ["GL"], "jurisdictions": ["IE"], "industries": [] },
    "updatedAt": "2026-10-05T08:00:00Z" } ]
```

`effectiveTo` and `articleKey` are **absent** when not set. `kind` is MAINTENANCE, INCIDENT, RELEASE,
STATUTORY_CHANGE or GENERAL; `severity` is INFO, WARNING or CRITICAL. **No tenant list, no author, no status** is
ever returned: the relay need not (and must not) add one. `appliesTo` lets the app say "applies to: Ireland";
an empty list means no restriction on that dimension.

**Body format:** plain text, exactly as articles: a blank line starts a paragraph, a line starting `- ` is a list item,
no HTML, no Markdown, no links. Render as text. `articleKey` is a help article the notice links to: fetch it with the
S3 article routes and open it in the help screen (never build a URL from it).

### What the app does with it

- **CRITICAL**: a banner across the top that stays until the notice stops applying.
- **WARNING**: a banner the person can dismiss for the session.
- **INFO**: an entry in a "News" list, with a small unread dot.
- Poll when the app opens and about every 5 minutes while it is open; the result is small and cheap. Never cache
  past the next poll: a withdrawn notice must disappear.
- Show nothing on a failure. A notice that cannot be fetched is the same as no notice, never an error screen.

## 2. What the operators can do (Omniview console, no contract needed)

For EA and WEB to understand what they will see, not to build:

- **Notices**: write a draft, publish, withdraw. A published notice is **never edited**; to change one, withdraw it
  and publish another, so what tenants were told stays a true record. Targets: services, industries, countries,
  an explicit tenant list (at most 200), a window of dates. Plain text, title at most 120, body at most 2000.
- **Incidents**: declare with a severity (P1 to P4) and the services affected; the state only moves forward
  (investigating, cause identified, monitoring, resolved); every update is kept. Linking tickets. Resolving
  **withdraws the incident's published notices** and, by default, publishes a one-day "Resolved" notice to the same
  services. A **post-incident note** is written after resolution and is internal only: it is never relayed.
- **Problems**: one cause behind several tickets, tracked against the owning service's backlog item (an id such as
  `IM-412`, never free text). Marking one **fixed in a release** closes the loop, once and only once, in a single
  transaction: every **still-open** linked ticket gets an operator reply ("fixed in release X; reply here if you still
  see it") and **one notice** is published to exactly the tenants who reported it for 14 days. Closed tickets are left
  alone. Closing a problem without a fix tells nobody anything. A stale list shows open problems nobody has
  touched for 7 days.

## 3. What a tenant experiences (so WEB can test it)

| Event at Prodeo | What the Owner Admin sees |
| --- | --- |
| Maintenance planned | A WARNING banner for the affected modules and countries until the window ends |
| Incident declared, notice written | A CRITICAL or WARNING banner for the affected modules |
| Incident resolved | The banner goes; a one-day INFO "Resolved: ..." appears |
| Their reported problem is fixed | A new reply on their ticket (the existing unread dot and ticket flow, no new code) and one INFO notice addressed to them |
| Statutory change in their country | A WARNING notice for that country, linked to the help article |

The reply on the ticket uses the **existing** ticket routes and unread summary: nothing new for the relay to carry.

## 4. Staff alerts (no contract, for CM)

Declaring and resolving an incident queue an alert through the **same transactional outbox** as tickets, and the same
SNS topic and mailbox deliver them. Subject: `[Omniview] P1 incident declared: <title>`; the incident title is written
by an operator, so it is safe to put in staff mail. No tenant name or ticket text is in any alert. **V9 migration**
adds the incident, problem and link tables and lets an outbox row be about an incident instead of a ticket. It is
purely additive (`ticket_id` becomes nullable; a check keeps every row about exactly one of the two). Applied cleanly
to a database already at V8.

## 5. Not built here

- The **relay route** in EA (or wherever option A to D lands) and the **WEB banner and News list**.
- **S4.5 public status page** (CM; a separate, tiny, public thing).
- **Tenant-specific content through option D**: a notice that names tenants must never go on published static content;
  it stays on the authenticated pull route in section 1 (see the published-content contract).
- Merge and link of tickets as a general feature (S1.9): problems and incidents link tickets themselves, so they do not
  wait for it.

## 6. Open questions

1. **Relay home** (A to D): Femi to decide. Nothing in Omniview changes either way.
2. **Who writes the first notices and articles**: Prodeo. The tooling is ready; the content is not.
3. **On-call**: alerts go to one mailbox today. An on-call roster is S5 and is not designed.
