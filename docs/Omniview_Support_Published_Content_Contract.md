# Omniview Support: published content (option D) contract

**Status:** DECIDED 2026-10-05 (Femi: "D now, a relay later"; GL will not host a relay and EA's decline stands).
**Omniview's side is built** (branch `feat/omniview-support-s4`): generator, local and S3 publishers, runner.
**Hosting is applied and live** (fish-infrastructure PR #12; distribution `E26EUCBT46B3CR`). Base URL:
`https://d2y9d7psy2v7dv.cloudfront.net/support-content/v1/`. Nothing is published until Omniview's S4 branch is deployed with
`OMNIVIEW_PUBLISH_S3_BUCKET` and `OMNIVIEW_PUBLISH_CLOUDFRONT_DISTRIBUTION_ID` set, so the index answers 403 until then.
**CORS is settled as production origin only** (`https://capital.theprodeogroup.com`; fish-infrastructure PR #13): local
development serves the generated files same-origin instead. The S3 and S4 routes remain relay-agnostic, so a relay later changes the
transport, not the content.

## 0. The idea in one paragraph

Instead of FiSH asking a live, authenticated service for articles and notices, Omniview **publishes the approved,
tenant-free content as versioned JSON files to a private S3 bucket served through CloudFront**, and the FiSH web app
reads them like any static asset. No new always-on service, nothing to keep alive at 3 a.m., nothing for an attacker
to reach that holds a secret, and Omniview stays never internet-facing: it only **writes out**. The price is a few
things a live route does for free (section 6), and one hard rule: **only content that is already safe to show every
tenant goes through it** (section 1).

## 1. What may be published, and what may not

| Content | On published files? | Why |
| --- | --- | --- |
| Published help articles | **Yes** | Written by Prodeo for everyone; no tenant, no user in them |
| Notices with **no tenant list** (maintenance, incidents, releases, statutory changes) | **Yes** | Broadcast by definition |
| Notices that **name tenants** (for example "the problem you reported is fixed") | **Never** | Their existence and wording say something about one business. They stay on the authenticated pull route, or are not delivered through content at all (the reply on the person's own ticket already is, over the existing ticket routes) |
| Tickets, replies, ratings, the tenant card, anything about one tenant | **Never** | Not content |
| Incidents, problems, post-incident notes, internal notes | **Never** | Internal records; tenants see only the notices written about them |

The generator **enforces** this, it does not rely on care: it refuses to emit a notice with a tenant list, a field with
a control character, or anything that is not plain text, and a refusal is a loud failure (an alert), never a silent
skip.

## 2. Where the files live

One private bucket (CM names it), no public access, served only by CloudFront through an origin access control. One
prefix, **versioned in the path** so a layout change never breaks an old client:

```
support-content/v1/index.json
support-content/v1/articles/{articleKey}/v{version}.json
```

### 2.1 `index.json` (small, changes often)

```json
{ "schema": 1,
  "generatedAt": "2026-10-05T10:00:00Z",
  "articles": [
    { "key": "uuid", "version": 3, "path": "articles/uuid/v3.json", "title": "How to reopen a period",
      "summary": "Reopen a closed accounting period.", "family": "PERIOD_END", "jurisdiction": "IE",
      "industry": "GENERIC", "module": "GL", "language": "en", "updatedAt": "2026-10-05T09:00:00Z" } ],
  "notices": [
    { "id": "uuid", "kind": "MAINTENANCE", "severity": "WARNING", "title": "Planned maintenance",
      "body": "FiSH is unavailable Sunday 02:00 to 03:00 UK time.", "effectiveFrom": "...", "effectiveTo": "...",
      "articleKey": "uuid", "appliesTo": { "modules": ["GL"], "jurisdictions": ["IE", "UK"], "industries": [] },
      "updatedAt": "..." } ] }
```

Field names and meanings are **identical** to the S3 article routes and the S4 notice route (the same DTOs), so a
client can use one parser for the pull route and the published file. Absent means "for everyone", as before.
`index.json` carries **no article bodies**; bodies are in the article files.

### 2.2 `articles/{key}/v{n}.json`

The article as the S3 read route returns it (card fields plus `body`). A new version is a **new file**; an existing file
is never overwritten, so the index pointing at it can be swapped atomically.

## 3. Publishing: how files get there

1. **About once a minute** the runner rebuilds the intended content and compares a fingerprint (everything except the
   generation time) with the last successful publish. Nothing changed means nothing is uploaded. This needs no change
   hooks: a publish or withdrawal shows on the next cycle, and a notice whose window ended drops out by itself.
2. The generator builds the **whole intended file set** from the database: pure, deterministic, no network.
3. Upload **article files first** (skip any that already exist), then `index.json` **last**. The index is the pointer, so
   a reader sees either the whole old state or the whole new one, never an index pointing at a file that is not there.
4. Invalidate `/support-content/v1/index.json` in CloudFront so a withdrawal shows within seconds, not at cache expiry.
5. Delete the files of articles that are no longer published, and invalidate their paths.

A failed publish is **retried on the next cycle** and **logged loudly** (`SUPPORT CONTENT NOT PUBLISHED`); the last
good files keep serving meanwhile. Because the output is a pure function of the database, a retry or a duplicate run is
harmless. (This replaces the change-recorded-first outbox idea in the first draft: it is simpler and cannot lose a change.)

**Cache headers:** `index.json` `max-age=60`; article files `max-age=3600`; both `Content-Type: application/json`,
`X-Content-Type-Options: nosniff`.

## 4. Withdrawing: what is and is not promised

Withdrawing an article or notice removes it from the index and deletes its file, and the index is invalidated, so **new
page loads stop showing it within about a minute**. It is **not a recall**: a person who already opened it has seen it,
and a browser that cached an article file may hold it for up to the hour in its header. Withdrawal means "stop showing
this", never "make it as if it were never public". That is acceptable **because section 1 means only content already
meant for everyone is ever published**; it is exactly why a notice naming a tenant must never use this path.

## 5. Size budget (hard limits, enforced by the generator)

- `index.json`: at most **256 KB**. At about 400 bytes a card that is several hundred articles plus the active notices.
- At most **50** active broadcast notices in the index (the app shows at most 20 anyway).
- An article file: at most **40 KB** (the article rules already cap the body at 20,000 characters).
- Over any limit the publish **fails loudly and keeps the last good files**; it never truncates silently. When the index
  nears the limit, the answer is a second index file split by language or module, a schema bump, not a bigger file.

## 6. What a live route does that this does not (decide knowingly)

| Capability | With option D | What to do |
| --- | --- | --- |
| **Search** | Only over the index: title, summary, family, country, industry, module. **Body search is lost**, because bodies are not in the index | Acceptable at first: write good titles and summaries. If body search matters later, publish a small token index (a schema bump) |
| **View counts** per article | Lost: a static file cannot count itself | Count from CloudFront logs (a daily job), or accept no counts at first. The Articles tab then shows none, which it already tolerates |
| **Per-viewer targeting of notices** | The **app does it**, from `appliesTo`. The rule must be implemented **identically** to the server's (section 7) | Provided as test vectors, below |
| **Ratings, ticket `viewedArticles`** | Unchanged: they ride on the existing authenticated ticket routes | Nothing |
| **Tenant-addressed notices** | Not delivered by this path (section 1) | The fix reply on the ticket already reaches them; a tenant-addressed notice needs the authenticated route and a relay, which is still open |
| **Freshness** | Up to about a minute for a withdrawal, up to the 15-minute tick for an expiry | Fine for help and notices; not for anything that must be instant |

## 7. The targeting rule the app must implement (with test vectors)

For each notice, the viewer is the person looking: the modules on screen or enabled, their Company's industry, their
Company's country, any of which may be **unknown (empty)**.

```
dimension(wanted, have) = wanted is empty  OR  have is empty  OR  some value in have is in wanted
shown = active(now)  AND  dimension(modules) AND dimension(industries) AND dimension(jurisdictions)
active(now) = effectiveFrom <= now AND (effectiveTo is absent OR now < effectiveTo)
```

Unknown is **fail open**: an unknown country shows a country-specific notice rather than hiding it. Order: most serious
first (CRITICAL, WARNING, INFO), then newest `effectiveFrom`; show at most 20.

| Notice targets | Viewer | Shown? |
| --- | --- | --- |
| modules GL | modules GL | yes |
| modules GL | modules HR | no |
| modules GL | modules unknown | **yes** (fail open) |
| countries IE | country NG | no |
| countries IE, UK | country UK | yes |
| countries IE | country unknown | **yes** (fail open) |
| industries SCHOOL | industry GENERIC | no |
| no targets | anything | yes |
| window starts tomorrow | now | no |
| window ended an hour ago | now | no |

These are the cases `NoticeContract` already asserts server-side; WEB should assert the same table.

## 8. Cost, access and who does what

**Infrastructure (CM, merged as fish-infrastructure PR #12, applied by Femi):** a dedicated private bucket
`fish-gl-engine-production-support-content-827709230476` (public access blocked) and a dedicated CloudFront distribution
with an origin access control, on the default CloudFront domain. Dedicated, not a second origin on WEB's distribution,
because WEB's deploy runs `s3 sync --delete` on its own bucket and would erase these files, and Omniview's
invalidation right must reach only this distribution. Files are at `support-content/v1/index.json` and
`support-content/v1/articles/{key}/v{n}.json`. CORS: GET, HEAD and OPTIONS only, no credentials, from
`https://capital.theprodeogroup.com` and `http://localhost:5173` (a variable removes the dev origin). Omniview's task role
(`fish-omniview-publish-support-content`) gets **only**: `s3:PutObject` and `s3:DeleteObject` on `support-content/v1/*`,
`s3:ListBucket` restricted to that prefix, and `cloudfront:CreateInvalidation` on that one distribution. **No
`s3:GetObject`**, so the uploader learns what already exists from the listing, not a HEAD. Cost is pennies a month.

**Omniview (built):** the pure generator, `LocalDirectoryPublisher` (development; inspect exactly what would go out),
`S3ContentPublisher` (articles first, index last, delete withdrawn articles, invalidate the index and the deleted
paths), and the runner. Configuration, none of it secret: `OMNIVIEW_PUBLISH_S3_BUCKET` plus
`OMNIVIEW_PUBLISH_CLOUDFRONT_DISTRIBUTION_ID` (both required together; the bucket alone logs an error and publishes
nothing, because without invalidation a withdrawn article would stay visible until its cache expires),
`OMNIVIEW_PUBLISH_S3_PREFIX` (default `support-content/v1/`), or `OMNIVIEW_PUBLISH_DIR` for development. With none set,
publishing is off. The distribution id and base URL exist only after the apply (terraform outputs
`support_content_distribution_id` and `support_content_base_url`).

**WEB:** read `index.json`, apply section 7, render notices as in the S4 contract and articles as in S3. Same parser as
the pull route.

**EA:** nothing, which is the point: this path needs no EA route at all. (The ticket relay EA is already building is
untouched and still needed for tickets, ratings and the context.)

## 9. Decision (made)

Femi, 2026-10-05: **D now, a relay later only if needed.** GL will not host a relay (a ledger's functions are ledger
functions), and EA's decline stands (it is not in EA's purview). Option C (an API Gateway in front of Omniview) was ruled
out because it would make Omniview internet-reachable. The Omniview routes behind a relay are already built, and the
published files use the same field names, so a relay later changes the transport, not the content.
