# Speaker — B2B Person & Company Search

756 million people. 17 million companies. Query any combination of fields — job title, company, location, headline, headcount, industry, revenue, and more. Full SQL access via `speaker query`.

Use it however you want. Sales prospecting, market research, recruiting, competitive analysis, or things we haven't thought of yet. This doc is guidance based on what we've learned so far — not rules. The data is yours to explore.

## How the tables fit together

Four tables, two layers: **search** then **enrich**.

```
SEARCH (flat, fast)                     ENRICH (rich, detailed)
─────────────────────                   ───────────────────────
people_roles  1.36B rows                people          756M rows
  → title, org, slug, cc                  → full roles[] history, edu[], bio, email
                        ── slug ──▶
companies     17M rows                  companies_full  17M rows
  → name, headcount, industry, cc         → headcount timeseries, dept breakdown, funding
                        ── slug ──▶
```

**Search first, enrich second.** Find who or what you're looking for in the flat tables. Then use the slug to get the full picture.

### What enrichment gives you

**People enrichment** — after finding someone in `people_roles`, look them up in `people` by slug to get:
- **Full work history** (`roles[]` array) — every role they've held, not just the one you matched on. See their career trajectory, how long they stay at companies, what industries they've moved through.
- **Education** (`edu[]` array) — schools, degrees.
- **Bio** — self-written summary, useful for qualification and personalization.
- **Email** — where available (coverage is low for senior roles at large companies).

```sql
-- Found someone interesting in people_roles? Get their full story:
SELECT slug, bio, email, roles, edu FROM people WHERE slug = 'micriedler'
```

**Company enrichment** — after finding a company in `companies`, look it up in `companies_full` by slug to get:
- **Headcount over time** — weekly timeseries, see if they're growing or shrinking.
- **Department breakdown** — how many in Engineering vs Sales vs Marketing.
- **Skills map** — what technologies/skills the workforce has.
- **Funding** — total raised, last round, investor names.

```sql
-- Found an interesting company? Get the deep data:
SELECT headcount_ts, headcount_by_function, funding_total, funding_investors
FROM companies_full WHERE slug = 'stripe'
```

## Quick Reference

```bash
speaker signup                        # Sign up with invite code (interactive)
speaker signup email@x.com INV-xxx    # Sign up non-interactively (agent-friendly)
speaker login <api-key>               # Log in on another machine
speaker query "SQL"                   # Run a query
speaker count                         # Total profiles
speaker schema                        # Show table structure
speaker update                        # Update CLI to latest version
```

## Account Setup

Speaker is invite-only.

```bash
speaker signup                        # Prompts for email + invite code
speaker signup you@x.com INV-abc123   # Non-interactive (for agents)
```

API key saved to `~/.speaker/config` on signup. To log in elsewhere: `speaker login <your-api-key>`

## Tables

### `people_roles` ⭐ PRIMARY TABLE FOR PERSON SEARCH

One row per person-role. 1.36B rows. Sorted by company name.

| Field | Type | Description |
|-------|------|-------------|
| `title` | String | Job title |
| `org` | String | Company name |
| `org_slug` | String | Company identifier (for exact matching) |
| `start` | Nullable(String) | Start date (YYYY-MM) |
| `end` | Nullable(String) | End date. **NULL = current role** |
| `desc` | Nullable(String) | Role description — useful for qualifying scope of responsibility |
| `cc` | String | Country code — **use this for country filtering**, not `loc` |
| `slug` | String | **Person identifier — always include this** |
| `first` | String | First name |
| `last` | String | Last name |
| `headline` | String | Professional headline |
| `loc` | String | Free-text location (city/metro/region). Use for city filtering (`loc ILIKE '%New York%'`), not country |

### `people` — person enrichment & everything else

756 million profiles. One row per person.

| Field | Type | Description |
|-------|------|-------------|
| `first` | String | First name |
| `last` | String | Last name |
| `slug` | String | Unique person identifier |
| `headline` | Nullable(String) | Professional headline |
| `loc` | Nullable(String) | Free-text location (city/metro/region). Use for city filtering, not country |
| `cc` | LowCardinality(String) | Country code (lowercase) — **use this for country filtering**, not `loc` |
| `email` | Nullable(String) | Email (where available) |
| `bio` | Nullable(String) | Short bio (max 200 chars) |
| `roles` | Array(Tuple) | Work history — `title`, `org`, `slug`, `web`, `cc`, `start`, `end`, `desc` |
| `edu` | Array(Tuple) | Education — `school`, `deg`, `slug` |

### `companies` — company search table

17 million company profiles. One row per company. Flat fields for fast filtering.

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Company name |
| `slug` | String | Company identifier (matches `org_slug` in people_roles) |
| `web` | Nullable(String) | Website domain (no protocol) |
| `desc` | Nullable(String) | Company description (max 200 chars) |
| `cc` | LowCardinality(String) | HQ country code (lowercase) |
| `hq` | Nullable(String) | Headquarters location string |
| `founded` | Nullable(UInt16) | Year founded |
| `type` | Nullable(String) | `"Privately Held"`, `"Public Company"`, `"Nonprofit"`, etc. |
| `industry` | Nullable(String) | Primary industry |
| `industries` | Array(String) | All industries (primary + sub-industries) |
| `headcount` | Nullable(UInt32) | Current employee count |
| `revenue_min` | Nullable(UInt64) | Estimated annual revenue lower bound (USD) |
| `revenue_max` | Nullable(UInt64) | Estimated annual revenue upper bound (USD) |
| `updated` | Date | Last refreshed |

### `companies_full` — company enrichment table

Same 17 million companies with timeseries, breakdowns, and deep data. Query by slug for single-company deep dives.

All fields from `companies`, plus:

| Field | Type | Description |
|-------|------|-------------|
| `headcount_ts` | Array(Tuple(date, count)) | Weekly headcount timeseries |
| `headcount_growth` | Tuple(mom, qoq, yoy) | Growth rates (%) |
| `headcount_by_function` | Map(String, UInt32) | `{"Engineering":450,"Sales":200}` |
| `headcount_by_location` | Map(String, UInt32) | `{"New York":300,"London":150}` |
| `headcount_by_skill` | Map(String, UInt32) | `{"Python":120,"AWS":95}` |
| `revenue_ts` | Array(Tuple(date, min, max)) | Monthly revenue range timeseries |
| `funding_total` | Nullable(UInt64) | Total funding raised (USD) |
| `funding_last_round` | Nullable(String) | `"series_b"`, `"seed"`, `"post_ipo_debt"` |
| `funding_investors` | Array(String) | `["Sequoia","a16z"]` |
| `traffic_rank` | Nullable(UInt32) | Global web traffic rank |
| `seo_organic_rank` | Nullable(Float32) | Average organic search rank |

### Which table to use

| If your search involves... | Use | Why |
|---------------------------|-----|-----|
| Job title or company name | `people_roles` | Indexed, fast |
| Company alumni / career tracking | `people_roles` | Subquery on `slug` |
| Headline search | `people` | No role needed |
| Name lookup | `people` | Name + country |
| Email, bio, education | `people` | Only here |
| Find companies by industry, headcount, revenue | `companies` | Flat fields, fast |
| Company headcount trends, department breakdown | `companies_full` | Timeseries data |
| Funding, investors | `companies_full` | Sparse but valuable |
| **Find people at specific types of companies** | **Two-step** | **See below** |

**Rule of thumb**: title or company → `people_roles`. Headline/bio/edu → `people`. Company search → `companies`. Deep dive → `companies_full`.

### Two-step pattern: companies + people

Direct JOINs between people (756 million) and companies (17 million) will timeout. Use a two-step approach:

```sql
-- Step 1: Find target companies
SELECT name, slug, headcount FROM companies
WHERE cc = 'de' AND headcount > 500 AND industry = 'Software Development'

-- Step 2: Find people at those companies (using the slug from step 1)
SELECT DISTINCT first, last, title, org, slug FROM people_roles
WHERE org_slug = 'sap' AND title LIKE '%CTO%' AND end IS NULL

-- Step 3 (optional): Get deep company data
SELECT headcount_by_function, funding_total, funding_investors
FROM companies_full WHERE slug = 'sap'
```

This is the natural agent workflow: search companies → find people → enrich both.

## Critical Rules

### Always SELECT slug

Include `slug` in every query. It's the unique person identifier for:

1. **Enrichment** — look up email/bio from `people`
2. **Profile URLs** — `https://linkedin.com/in/{slug}`
3. **Deduplication** — deduplicate by `slug`, not by name (names are not unique)

```sql
-- BAD: no slug
SELECT first, last, title, org FROM people_roles WHERE ...

-- GOOD
SELECT first, last, title, org, loc, slug FROM people_roles WHERE ...
```

### Always use DISTINCT

`people_roles` has one row per person-role. Without DISTINCT, the same person appears multiple times in many common queries.

```sql
-- Without DISTINCT: someone who had 3 roles at Monzo appears 3 times
SELECT first, last, headline FROM people_roles
WHERE org = 'Monzo Bank' AND end IS NOT NULL LIMIT 20

-- With DISTINCT: one row per person
SELECT DISTINCT first, last, headline FROM people_roles
WHERE org = 'Monzo Bank' AND end IS NOT NULL LIMIT 20
```

Why duplicates appear:
- **Multiple roles at same company** — promotions where old role wasn't end-dated
- **Related entities** — "N26" and "N26 Group" both map to same org_slug
- **Title variations** — "Chief Compliance Officer" vs "Chief Compliance Officer (CCO)"

Deduplicate by `slug` for one row per person, or `(slug, org_slug)` for one row per person per company.

### Always add LIMIT

Results capped at 1,000 rows. Default to `LIMIT 20` for exploration, `LIMIT 100` for exports.

### ILIKE vs LIKE

- `ILIKE` — case-insensitive. `ILIKE '%cto%'` matches "CTO", "cto", "Cto"
- `LIKE` — case-sensitive. `LIKE '%CTO%'` only matches "CTO"
- **Gotcha**: `ILIKE '%CTO%'` also matches "DireCTOr", "eleCTOral". Use `LIKE '%CTO%'` or add exclusions.

**Short keywords (≤3 chars) are substring landmines:**

| You searched | Also matches |
|---|---|
| `%AI%` | **Ai**rcraft, **Ai**rport, **Ai**rline, M**ai**ntenance |
| `%LLM%` | Enro**llm**ent, Fulfi**llm**ent |
| `%CTO%` | Dire**CTO**r, ele**CTO**ral |
| `%ML%` | HT**ML**, X**ML** |

**Rule: if your keyword is ≤3 characters, never use bare ILIKE.** Spell out the full term or use case-sensitive LIKE with word boundaries:

```sql
-- BAD: matches Aircraft, Airport, Tai Chi
WHERE title ILIKE '%AI%'

-- GOOD: spell it out or anchor with spaces/punctuation
WHERE title ILIKE '%Artificial Intelligence%'
   OR title LIKE '%Head of AI%'
   OR title LIKE '%Chief AI Officer%'
   OR title LIKE '% AI %'
   OR title LIKE 'AI %'
```

### Locale-aware searching

Non-English countries use local titles. Include locale variants:

| English | German | French | Spanish |
|---------|--------|--------|---------|
| CEO | Geschäftsführer | PDG, Directeur Général | Director General |
| CTO | Technischer Leiter | Directeur Technique | Director Técnico |
| CFO | Finanzvorstand | Directeur Financier | Director Financiero |
| Founder | Gründer/in | Fondateur/Fondatrice | Fundador/a |
| Head of | Leiter/in | Responsable, Directeur | Jefe de |

## Things That Go Wrong

This is the most important section. Everything above you can figure out from the schema. These are the things that look correct, return results, but are silently wrong.

### loc is for cities, cc is for countries

**The trap**: you want US-based people, so you add `loc ILIKE '%US%'`:

```sql
-- BROKEN: "United States" does NOT contain "US" as a substring
WHERE title ILIKE '%CIO%' AND loc ILIKE '%US%' AND cc = 'us'
-- Kills 93% of results. The 7% it finds are false positives from Houston, Austin, etc.
```

**Why**: `loc` is a free-text location string — `"New York, New York, United States"`, `"San Francisco Bay Area"`, `"Greater Chicago Area"`. There's no standardized format. `ILIKE '%US%'` doesn't match `"United States"` (no contiguous "US" substring) and accidentally matches cities containing "us" (Houston, Austin, Lausanne).

**Fix**: use `cc` for country, `loc` for city/metro:

```sql
-- Country filtering → cc
WHERE cc = 'us'

-- City/metro filtering → loc
WHERE cc = 'us' AND loc ILIKE '%New York%'
WHERE cc = 'us' AND loc ILIKE '%San Francisco%'
WHERE cc = 'uk' AND loc ILIKE '%London%'
```

**Never use `loc` to filter by country.** The `cc` field exists for exactly this purpose and is 100% reliable.

### LIMIT starvation with multi-company queries

**The trap**: you have 40 target companies, so you query them all at once:

```sql
-- Looks right. Returns 500 results. But PayPal eats 152 of them
-- and Remitly gets 3 out of its 18 actual matches.
SELECT first, last, title, org, loc, slug FROM people_roles
WHERE org_slug IN ('paypal', 'revolut', 'stripe', 'remitly', ... 36 more)
AND title ILIKE '%Compliance%' AND end IS NULL
LIMIT 500
```

**Why**: `people_roles` is sorted by company. The engine scans in order, hits LIMIT, stops. Companies early in the scan get full coverage. Companies later get scraps or nothing. You won't notice because you got 500 results.

**Fix**: query each company separately.

```sql
-- Do this for EACH company:
SELECT DISTINCT first, last, title, org, loc, slug FROM people_roles
WHERE org_slug = 'remitly'
AND title ILIKE '%Compliance%' AND end IS NULL
LIMIT 100
```

**Rule: if your IN list has >5 companies, query each one separately.** You have 5,000 queries/day — use them.

### Company names are dangerously ambiguous

**The trap**: `org = 'Mercury'` matches Mercury the fintech, Mercury Shipping, Mercury Insurance, Mercury Marine, Mercury Coaching — 15+ companies.

Even exact match `org = 'Wise'` returns multiple companies literally named "Wise".

**Fix**: always resolve to `org_slug` first.

```sql
SELECT org, org_slug, count() as c FROM people_roles
WHERE org = 'Mercury' AND end IS NULL
GROUP BY org, org_slug ORDER BY c DESC LIMIT 20
```

Then verify:
```sql
SELECT first, last, title FROM people_roles
WHERE org_slug = 'mercuryhq' AND end IS NULL LIMIT 5
```

**Slugs are not guessable:**

| Company | You'd guess | Actual slug |
|---------|-------------|-------------|
| Wise | wise | `wiseaccount` |
| Block | block | `joinblock` |
| Square | square | `joinsquare` |
| Monzo | monzo | `monzo-bank` |
| Mercury | mercury | `mercuryhq` |
| Chime | chime | `chime-card` |
| Siemens | siemens | `siaborsiemens` |
| BMW | bmw | `bmwgroup` |
| Deloitte | deloitte | `deloitte` |
| McKinsey | mckinsey | `mckinsey` |

Name variations share the same slug — "N26", "N26 Group", "Number26" all map to `n26`.

**When org_slug is empty or missing**: some people (especially at small/new companies) have empty `org_slug`. If `org_slug` returns nothing, fall back to `WHERE org = 'CompanyName'`. For very new startups, also try `headline ILIKE '%CompanyName%'` on the `people` table.

### Seniority filters have false positives

**The trap**: you want decision-makers, so you add broad seniority keywords:

```sql
-- Looks like a seniority filter. Actually matches analysts and assistants.
WHERE title ILIKE '%Global%'        -- "Global AML Analyst" ← analyst
WHERE title ILIKE '%Executive%'     -- "Executive Assistant" ← assistant
WHERE title ILIKE '%Senior%'        -- "Senior Analyst" ← not a buyer
```

In one real search, `%Global%` inflated PayPal from 53 real decision-makers to 152 results — nearly 100 false positives from one bad keyword.

**Fix**: be specific:

```sql
WHERE title ILIKE '%Head of%'
   OR title ILIKE '%Chief%Officer%'
   OR title ILIKE '%Director%'
   OR title ILIKE '%VP %'
   OR title ILIKE '%Vice President%'
   OR title ILIKE '%Global Head%'
   OR title ILIKE '%General Counsel%'
```

**Note**: seniority filters like `%Director%` are safe with specific domain keywords (`%Compliance%`), but compound the noise with short keywords — `%Director%` + `%AI%` returns "Director, Aircraft Integration", "Director, Airport Compliance". Fix the short keyword first (see ILIKE section above).

**Better fix**: explore titles at your target companies first (see Workflow below) to see what patterns actually exist.

### Title conventions vary wildly between companies

**The trap**: you search for `%Financial Crime%` and miss Revolut's results because they call it "Fincrime". You search for `%Head%` and miss PayPal's "SVP" people.

**Fix**: always explore title distributions at 2-3 target companies before building your final query:

```sql
SELECT title, count() as c FROM people_roles
WHERE org_slug = 'revolut'
AND (title ILIKE '%Compliance%' OR title ILIKE '%AML%' OR title ILIKE '%Fincrime%')
AND end IS NULL
GROUP BY title ORDER BY c DESC LIMIT 30
```

### Email coverage is near zero for senior roles

For 874 compliance professionals at major fintechs, we got **0 emails**. "Limited" undersells it — email is near zero for senior people at large companies.

| Segment | Email rate |
|---------|-----------|
| Founders / solo operators | Some |
| Mid-level at SMBs | Low |
| Senior execs at large companies | Near zero |

Use `slug` for profile-based outreach: `https://linkedin.com/in/{slug}`

### ARRAY JOIN is 100-300x slower than people_roles

```sql
-- SLOW (12+ seconds):
SELECT first, last FROM people ARRAY JOIN roles AS r WHERE r.org = 'Wise' LIMIT 20

-- FAST (30ms):
SELECT DISTINCT first, last FROM people_roles WHERE org = 'Wise' LIMIT 20
```

Only use ARRAY JOIN when you need the full nested roles array in output.

## The Workflow

This is what we've learned works. Your use case might be different — adapt it.

```
Step 1: Identify targets → resolve org_slugs
Step 2: Explore what the data actually looks like
Step 3: Build filters → query per company (or per segment)
Step 4: Enrich from people table
```

### Broad searches (no target companies)

The workflow above assumes you have target companies. If you're searching broadly — e.g. "find AI leaders in the US" — the pitfalls are different. You can't explore per-company first, and false positive rates go way up because you're scanning millions of rows with ILIKE.

**Strategy**: start with the most specific patterns, review results, then broaden progressively.

```sql
-- Start narrow: exact roles
WHERE title ILIKE '%Chief AI Officer%' OR title ILIKE '%Head of AI%'

-- Review results. Then broaden carefully:
WHERE title ILIKE '%Artificial Intelligence%'
  AND (title ILIKE '%Director%' OR title ILIKE '%VP%')
  AND cc = 'us' AND end IS NULL
```

Don't start broad and filter down — start specific and widen.

### Step 1: Resolve org_slugs

```sql
SELECT org, org_slug, count() as c FROM people_roles
WHERE org = 'Mercury' AND end IS NULL
GROUP BY org, org_slug ORDER BY c DESC LIMIT 20
```

If targeting many companies, build a slug map first. If org_slug is empty, fall back to `org = 'Name'`.

### Step 2: Explore before you filter

Don't guess what titles, keywords, or patterns exist. Look.

```sql
-- What titles exist at this company?
SELECT title, count() as c FROM people_roles
WHERE org_slug = 'revolut' AND end IS NULL
GROUP BY title ORDER BY c DESC LIMIT 30

-- What does the desc field say? (role descriptions — useful for qualification)
SELECT title, desc FROM people_roles
WHERE org_slug = 'stripe' AND title ILIKE '%Compliance%' AND end IS NULL
LIMIT 10
```

The `desc` field contains role descriptions when available — things like "Leading a team of 50 AML analysts across EMEA." Useful for understanding scope of responsibility, team size, and whether someone is a real decision-maker.

### Step 3: Query per company

```sql
SELECT DISTINCT first, last, title, org, loc, slug FROM people_roles
WHERE org_slug = 'revolut'
AND (title ILIKE '%Compliance%' OR title ILIKE '%AML%' OR title ILIKE '%Fincrime%')
AND (title ILIKE '%Head%' OR title ILIKE '%Director%' OR title ILIKE '%VP%'
     OR title ILIKE '%Chief%')
AND end IS NULL
LIMIT 100
```

Repeat per company. Combine results in your script.

### Step 4: Enrich

```sql
SELECT slug, email, bio FROM people
WHERE slug IN ('slug1', 'slug2', ..., 'slug200')
```

Batch in groups of ~200 slugs. Profile URLs: `https://linkedin.com/in/{slug}`

Bio (~20-60% coverage) is useful for qualification and personalization.

## Query Patterns

These cover common use cases beyond prospecting.

### Company search

```sql
-- Software companies in Germany with 100+ employees
SELECT name, slug, headcount, industry, revenue_min FROM companies
WHERE cc = 'de' AND headcount > 100 AND industry = 'Software Development'
ORDER BY headcount DESC

-- High-revenue companies
SELECT name, slug, revenue_min, headcount FROM companies
WHERE revenue_min > 100000000 ORDER BY revenue_min DESC

-- Recently founded companies with traction
SELECT name, slug, founded, headcount, industry, cc FROM companies
WHERE founded >= 2020 AND headcount >= 50
ORDER BY headcount DESC

-- Industry breakdown by country
SELECT industry, count() as n, avg(headcount) as avg_hc FROM companies
WHERE cc = 'at' AND headcount > 50
GROUP BY industry ORDER BY n DESC
```

### Company deep dives

```sql
-- Department breakdown
SELECT headcount_by_function FROM companies_full WHERE slug = 'datadog'

-- Headcount trend over time
SELECT headcount_ts FROM companies_full WHERE slug = 'stripe'

-- Funding and investors
SELECT funding_total, funding_last_round, funding_investors
FROM companies_full WHERE slug = 'revolut'

-- Revenue trajectory
SELECT revenue_ts FROM companies_full WHERE slug = 'sap'
```

### Find people at companies matching criteria

```sql
-- Step 1: Find fintech companies in UK with 500+ headcount
SELECT name, slug, headcount FROM companies
WHERE cc = 'uk' AND headcount > 500
AND (industry ILIKE '%fintech%' OR industry ILIKE '%financial%')

-- Step 2: Find compliance leaders at one of them
SELECT DISTINCT first, last, title, org, slug FROM people_roles
WHERE org_slug = 'revolut'
AND (title ILIKE '%Compliance%' OR title ILIKE '%AML%')
AND (title ILIKE '%Head%' OR title ILIKE '%Director%' OR title ILIKE '%VP%')
AND end IS NULL
```

### Company alumni — where did they go?

```sql
SELECT DISTINCT first, last, title, org, headline FROM people_roles
WHERE slug IN (
    SELECT DISTINCT slug FROM people_roles
    WHERE org_slug = 'monzo-bank' AND end IS NOT NULL
)
AND end IS NULL AND org_slug != 'monzo-bank'
LIMIT 100
```

### People who moved between countries

```sql
SELECT first, last, headline, loc FROM people
WHERE cc = 'uk' AND arrayExists(r -> r.cc = 'de', roles)
LIMIT 20
```

### Education search

```sql
SELECT first, last, headline, loc FROM people
WHERE arrayExists(e -> e.school ILIKE '%Oxford%', edu) AND cc = 'uk'
LIMIT 20
```

### Headline search

```sql
SELECT first, last, headline, loc FROM people
WHERE cc = 'uk' AND headline ILIKE '%artificial intelligence%'
LIMIT 20
```

### Count by country

```sql
SELECT cc, count() as c FROM people GROUP BY cc ORDER BY c DESC LIMIT 20
```

### Name lookup

```sql
SELECT first, last, headline, loc, slug FROM people
WHERE first = 'Michael' AND last = 'Riedler'
```

### People at a company (current)

```sql
SELECT DISTINCT first, last, title FROM people_roles
WHERE org_slug = 'google' AND end IS NULL
LIMIT 20
```

### Title distribution at a company

```sql
SELECT title, count() as c FROM people_roles
WHERE org_slug = 'stripe' AND end IS NULL
GROUP BY title ORDER BY c DESC LIMIT 30
```

### Combine role + person filters

```sql
SELECT DISTINCT first, last, headline, loc FROM people_roles
WHERE org IN ('Wise', 'TransferWise') AND end IS NOT NULL
AND headline ILIKE '%Founder%'
LIMIT 20
```

## Full Example: AML Compliance Buyers at Fintechs

This is a real session that produced 796 prospects across 295 companies.

**1. Resolve org_slugs:**
```sql
SELECT org, org_slug, count() as c FROM people_roles
WHERE org = 'Wise' AND end IS NULL
GROUP BY org, org_slug ORDER BY c DESC
-- wiseaccount | 2341 ← this one
```

**2. Explore titles at a few targets:**
```sql
SELECT title, count() as c FROM people_roles
WHERE org_slug = 'revolut'
AND (title ILIKE '%Compliance%' OR title ILIKE '%AML%' OR title ILIKE '%Fincrime%')
AND end IS NULL GROUP BY title ORDER BY c DESC LIMIT 20
-- Finding: Revolut uses "Fincrime" not "Financial Crime"
```

**3. Query each company separately:**
```sql
SELECT DISTINCT first, last, title, org, loc, slug, desc FROM people_roles
WHERE org_slug = 'revolut'
AND (title ILIKE '%Compliance%' OR title ILIKE '%AML%' OR title ILIKE '%Fincrime%'
     OR title ILIKE '%Financial Crime%' OR title ILIKE '%MLRO%' OR title ILIKE '%KYC%')
AND (title ILIKE '%Head%' OR title ILIKE '%Director%' OR title ILIKE '%VP%'
     OR title ILIKE '%Chief%' OR title ILIKE '%Global Head%')
AND end IS NULL LIMIT 100
```

**4. Enrich:**
```sql
SELECT slug, email, bio FROM people WHERE slug IN ('slug1', ..., 'slug200')
```

**Result**: 796 prospects, 471 at Tier 1 fintechs, with profile URLs and bios — in minutes.

## Checklist

### People searches
```
□ Resolve org_slugs (GROUP BY org, org_slug) — don't trust org names
□ Explore title distributions at target companies before filtering
□ Use DISTINCT to avoid duplicate rows
□ Query each company separately (>5 companies = separate queries)
□ Always SELECT slug
□ Seniority filters: avoid %Global%, %Executive%, %Senior% alone
□ Enrich in batches of ~200 slugs
□ Deduplicate by slug (per person) or (slug, org_slug) (per person per company)
□ Profile URLs: https://linkedin.com/in/{slug}
```

### Company searches
```
□ Use companies for search (flat, fast), companies_full for deep dives (by slug)
□ Don't JOIN people + companies directly — use two-step pattern
□ industry is primary, industries is the full array
□ revenue_min / revenue_max are estimates — use ranges, not exact values
□ headcount_by_function, headcount_by_location are Maps — use mapKeys() to list available keys
□ founded year can be unreliable for older companies — may reflect page creation date
```

## Reference

### Country codes

Lowercase two-letter. Uses `uk` not `gb`:
`us`, `uk`, `de`, `fr`, `at`, `ch`, `in`, `br`, `es`, `it`, `nl`, `ca`, `au`, `cn`, `id`, `mx`, `za`, `co`, `pl`, `se`, `tr`, `ae`, `sa`, `eg`, `ng`, `ke`, `sg`, `jp`, `kr`, `ph`, `my`, `th`, `vn`, `ie`, `dk`, `no`, `fi`, `pt`, `ro`, `cz`, `hu`, `il`, `ar`, `cl`, `pe`, `pk`, `bd`

### Current role

`end IS NULL` means current role:
```sql
WHERE end IS NULL                    -- in people_roles
WHERE arrayExists(r -> r.end IS NULL AND r.title ILIKE '%CTO%', roles)  -- in people
```

### Accessing roles in `people` table

```sql
-- Direct index (1-indexed, most recent first)
SELECT roles[1].title, roles[1].org FROM people WHERE cc = 'uk' LIMIT 5

-- arrayExists (filter by role criteria)
SELECT first, last FROM people WHERE arrayExists(r -> r.org = 'Google', roles) LIMIT 5

-- ARRAY JOIN (slow — avoid unless needed)
SELECT first, last, r.title FROM people ARRAY JOIN roles AS r WHERE r.org = 'Google' LIMIT 5
```

### NULL handling

Missing data is `NULL`, never empty string. Check with `IS NULL` / `IS NOT NULL`.

### title vs headline

| Field | Where | What it is |
|-------|-------|-----------|
| `title` | `people_roles` | Exact job title at a specific company |
| `headline` | both tables | Self-written summary, often aspirational |

`title` is more reliable. `headline` might say "Visionary Technology Leader" instead of "CTO".

### Pagination

Results capped at 1,000 rows. Use OFFSET for larger result sets:
```sql
SELECT ... LIMIT 100 OFFSET 0     -- page 1
SELECT ... LIMIT 100 OFFSET 100   -- page 2
SELECT ... LIMIT 100 OFFSET 200   -- page 3
```
Run `count()` first to know how many pages. For multi-company queries, paginate per company — not with a shared OFFSET (see LIMIT starvation).

### Output

- **Terminal**: pretty-printed JSON
- **Piped**: raw JSON lines

**Note**: piped output may include non-JSON lines (e.g. update notices). Filter when parsing.

### Data coverage

756 million person profiles across 244 countries. 17 million company profiles.

**People — Top 15 countries:**

| Country | Code | Profiles |
|---------|------|----------|
| USA | us | 179M |
| India | in | 83M |
| Brazil | br | 51M |
| China | cn | 33M |
| UK | uk | 30M |
| France | fr | 23M |
| Canada | ca | 19M |
| Indonesia | id | 19M |
| Mexico | mx | 17M |
| Italy | it | 16M |
| Spain | es | 15M |
| Germany | de | 12M |
| Australia | au | 12M |
| Turkey | tr | 11M |
| Colombia | co | 10M |

**Companies — field coverage:**

| Field | Coverage |
|-------|----------|
| name, slug | 100% |
| desc | 93% |
| headcount | 91% |
| cc (country) | 80% |
| web (domain) | 79% |
| industry | 69% |
| hq | 67% |
| founded | 50% |
| revenue | 46% |
| headcount_by_function | 77% |
| funding | 1.2% (sparse, but valuable when present) |

### People — field coverage (UK example)

| Field | Coverage |
|-------|----------|
| first, last, slug, loc, cc | 100% |
| headline | ~91% |
| bio | ~22% |
| roles (at least one) | ~71% |
| edu (at least one) | ~41% |
| email | Near zero for senior/enterprise roles |

### Limits

| Limit | Value |
|-------|-------|
| Max rows per query | 1,000 |
| Max queries per second | 5 |
| Max queries per day | 5,000 |
