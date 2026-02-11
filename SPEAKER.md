# Speaker — B2B Person Search

A CLI tool for searching 756M+ B2B person profiles via SQL. Run `speaker query "SELECT ..."` to search.

## Quick Reference

```bash
speaker signup            # Create account (pending approval)
speaker status            # Check if approved (auto-saves API key)
speaker query "SQL"       # Run a query
speaker count             # Total profiles
speaker schema            # Show table structure
speaker update            # Update CLI to latest version
speaker help              # All commands
```

## Account Setup

New accounts require approval. The flow:

```bash
speaker signup            # Enter email + password → account is pending
speaker status            # Check back later → once approved, API key is saved automatically
speaker query "SELECT ..." # Start searching
```

## Table: `people_roles` ⭐ PRIMARY TABLE

**Start here for most searches.** One row per person-role. Sorted by company name. The `title` field is the most valuable field — it tells you exactly what someone does right now.

| Field | Type | Description |
|-------|------|-------------|
| `title` | String | **Job title** — the money field. Search here first. |
| `org` | String | Company name |
| `org_slug` | String | Company identifier (for exact matching) |
| `start` | Nullable(String) | Start date (YYYY-MM) |
| `end` | Nullable(String) | End date. **NULL = current role** |
| `desc` | Nullable(String) | Role description |
| `cc` | String | Country code |
| `slug` | String | Person identifier |
| `first` | String | First name |
| `last` | String | Last name |
| `headline` | String | Professional headline |
| `loc` | String | Location |

### Key queries with `title`

```sql
-- Current CTOs in London
SELECT first, last, title, org FROM people_roles
WHERE title ILIKE '%CTO%' AND cc = 'uk' AND loc ILIKE '%London%' AND end IS NULL
LIMIT 20

-- VP Sales at SaaS companies in the US
SELECT first, last, title, org FROM people_roles
WHERE title ILIKE '%VP%Sales%' AND end IS NULL AND cc = 'us'
LIMIT 20

-- Current CFOs in manufacturing
SELECT first, last, title, org FROM people_roles
WHERE (title ILIKE '%CFO%' OR title ILIKE '%Chief Financial%')
AND (org ILIKE '%manufactur%' OR org ILIKE '%industrial%')
AND end IS NULL AND cc = 'uk'
LIMIT 20

-- HR Directors in healthcare
SELECT first, last, title, org FROM people_roles
WHERE title ILIKE '%HR Director%'
AND (org ILIKE '%NHS%' OR org ILIKE '%health%' OR org ILIKE '%hospital%')
AND end IS NULL AND cc = 'uk'
LIMIT 20
```

### `title` vs `headline`

| Field | Where | What it is | Use when |
|-------|-------|-----------|----------|
| `title` | `people_roles` | Exact job title from a specific role | You want current/past title at a company |
| `headline` | both tables | Self-written summary, often aspirational | You want how someone describes themselves |

`title` is more reliable — it's "CTO at Acme Corp". `headline` might say "Visionary Technology Leader | AI Enthusiast | Speaker".

---

## Table: `people` — enrichment & headline searches

### Person Fields
| Field | Type | Description |
|-------|------|-------------|
| `first` | String | First name |
| `last` | String | Last name |
| `slug` | String | Unique profile identifier |
| `headline` | Nullable(String) | Professional headline |
| `loc` | Nullable(String) | Location (city, country) |
| `cc` | LowCardinality(String) | Country code (lowercase) |
| `email` | Nullable(String) | Email (where available) |
| `bio` | Nullable(String) | Short bio (max 200 chars) |
| `roles` | Array(Tuple) | Work history, most recent first |
| `edu` | Array(Tuple) | Education history |

### Role Fields (inside `roles` array)
| Field | Type | Description |
|-------|------|-------------|
| `title` | String | Job title |
| `org` | String | Company name |
| `slug` | Nullable(String) | Company identifier |
| `web` | Nullable(String) | Company website domain |
| `cc` | Nullable(String) | Country code of role |
| `start` | String | Start date (YYYY-MM) |
| `end` | Nullable(String) | End date (YYYY-MM). NULL = current role |
| `desc` | Nullable(String) | Role description (max 120 chars) |

### Education Fields (inside `edu` array)
| Field | Type | Description |
|-------|------|-------------|
| `school` | String | Institution name |
| `deg` | Nullable(String) | Degree and field of study |
| `slug` | Nullable(String) | Institution identifier |

## Table: `people_roles`

**Use this table for any company or role search. It's 100-300x faster than ARRAY JOIN on `people`.**

Pre-flattened: one row per person-role combination (1.36B rows). Sorted by company name, so lookups by org are instant.

| Field | Type | Description |
|-------|------|-------------|
| `org` | String | Company name |
| `org_slug` | String | Company identifier |
| `title` | String | Job title |
| `start` | Nullable(String) | Start date (YYYY-MM) |
| `end` | Nullable(String) | End date. NULL = current role |
| `desc` | Nullable(String) | Role description |
| `cc` | String | Country code |
| `slug` | String | Person identifier |
| `first` | String | First name |
| `last` | String | Last name |
| `headline` | String | Professional headline |
| `loc` | String | Location |

### When to use which table

| Query type | Use | Why |
|------------|-----|-----|
| **"Find CTOs in London"** | `people_roles` | Search by `title`, fast |
| **"Who works at Google?"** | `people_roles` | Indexed by `org`, instant |
| **"VP Sales at SaaS companies"** | `people_roles` | `title` + `org` combo |
| **"Ex-McKinsey, now founders"** | `people_roles` | `org` + `headline` |
| **"Where did ex-Monzo CEOs go?"** | `people_roles` | Subquery on `slug` |
| "Headline contains 'AI'"  | `people` | Headline-only, no role needed |
| "Lookup by name" | `people` | Name + country, fast |
| "Get email/bio for a slug" | `people` | Enrichment after role search |
| "Education at Oxford" | `people` | `edu` array only in `people` |
| "Full role history for a person" | `people` | All roles nested in one row |

**Rule of thumb**: if your search involves a job title or company name, use `people_roles`. For everything else, use `people`.

## Country Codes

Lowercase two-letter. Uses `uk` not `gb`. Examples:
`us`, `uk`, `de`, `fr`, `at`, `ch`, `in`, `br`, `es`, `it`, `nl`, `ca`, `au`, `cn`, `id`, `mx`, `za`, `co`, `pl`, `se`, `tr`, `ae`, `sa`, `eg`, `ng`, `ke`, `sg`, `jp`, `kr`, `ph`, `my`, `th`, `vn`, `ie`, `dk`, `no`, `fi`, `pt`, `ro`, `cz`, `hu`, `il`, `ar`, `cl`, `pe`, `pk`, `bd`

## Query Patterns

### Search by job title (use `people_roles`)
```sql
-- Current CTOs in Germany
SELECT first, last, title, org, loc
FROM people_roles
WHERE title ILIKE '%CTO%' AND cc = 'de' AND end IS NULL
LIMIT 20

-- VP Sales in the US
SELECT first, last, title, org
FROM people_roles
WHERE title ILIKE '%VP%Sales%' AND cc = 'us' AND end IS NULL
LIMIT 20

-- Founders in the UK (by title)
SELECT DISTINCT first, last, title, org
FROM people_roles
WHERE title ILIKE '%Founder%' AND cc = 'uk' AND end IS NULL
LIMIT 20
```

### Search by company (use `people_roles`)
```sql
-- Current employees at Google
SELECT first, last, title, org
FROM people_roles
WHERE org = 'Google' AND end IS NULL
LIMIT 20

-- Alumni of McKinsey
SELECT first, last, title, org, headline
FROM people_roles
WHERE org IN ('McKinsey', 'McKinsey & Company') AND end IS NOT NULL
LIMIT 20
```

### Combine title + company
```sql
-- CTOs at top fintech companies
SELECT DISTINCT first, last, title, org
FROM people_roles
WHERE org IN ('Revolut','Monzo','Wise','Starling Bank','Checkout.com','GoCardless')
AND title ILIKE '%CTO%' AND end IS NULL
LIMIT 20

-- CFOs in manufacturing
SELECT first, last, title, org
FROM people_roles
WHERE (title ILIKE '%CFO%' OR title ILIKE '%Chief Financial%')
AND (org ILIKE '%manufactur%' OR org ILIKE '%industrial%')
AND end IS NULL AND cc = 'uk'
LIMIT 20
```

### People who moved between companies
```sql
-- Where did ex-Monzo CEOs go?
SELECT DISTINCT first, last, headline, title, org
FROM people_roles
WHERE slug IN (
    SELECT slug FROM people_roles WHERE org = 'Monzo Bank' AND title ILIKE '%CEO%' AND end IS NOT NULL
)
AND end IS NULL
LIMIT 20
```

### Search by headline (use `people`)
```sql
-- People who describe themselves as AI experts
SELECT first, last, headline, loc
FROM people
WHERE cc = 'uk' AND headline ILIKE '%artificial intelligence%'
LIMIT 20

-- Founders in the UK (by headline)
SELECT first, last, headline, loc
FROM people
WHERE cc = 'uk' AND headline ILIKE '%founder%'
LIMIT 20
```

### Enrich with email/bio (use `people`)
```sql
-- After finding people in people_roles, get their email/bio
SELECT slug, first, last, email, bio
FROM people
WHERE slug IN ('john-smith-abc123', 'jane-doe-xyz789')
```

### People who worked in one country but now live in another
```sql
SELECT first, last, headline, loc
FROM people
WHERE cc = 'uk' AND arrayExists(r -> r.cc = 'de', roles)
LIMIT 20
```

### Count by country
```sql
SELECT cc, count() as c FROM people GROUP BY cc ORDER BY c DESC LIMIT 20
```

### Search by education
```sql
SELECT first, last, headline, loc
FROM people
WHERE arrayExists(e -> e.school ILIKE '%Oxford%', edu)
AND cc = 'uk'
LIMIT 20
```

### Search by name
```sql
SELECT first, last, headline, loc, slug
FROM people
WHERE first = 'Michael' AND last = 'Riedler'
```

### Combine filters
```sql
SELECT first, last, headline, loc
FROM people
WHERE cc = 'uk'
AND headline ILIKE '%founder%'
AND arrayExists(r -> r.org ILIKE '%NHS%' AND r.end IS NOT NULL, roles)
LIMIT 20
```

## Limits

| Limit | Value |
|-------|-------|
| Max rows per query | 1,000 |
| Max queries per second | 5 |
| Max queries per day | 5,000 |

## Common Pitfalls

### Use `people_roles` for company/role searches — not ARRAY JOIN
ARRAY JOIN on the `people` table is slow (full-scans 756M rows) and produces duplicates. Use `people_roles` instead:

```sql
-- SLOW (12+ seconds, duplicates): ARRAY JOIN on people
SELECT first, last, headline FROM people ARRAY JOIN roles AS r
WHERE r.org = 'Wise' LIMIT 20

-- FAST (30ms, no duplicates): people_roles
SELECT DISTINCT first, last, headline
FROM people_roles
WHERE org = 'Wise'
LIMIT 20
```

Only use ARRAY JOIN on `people` when you need the full nested roles array in the output.

### Company name matching is noisy
`ILIKE '%Wise%'` matches Wise, ConnectWise, WiseClick, NourishWise, etc. Be specific:

```sql
-- TOO BROAD
WHERE org ILIKE '%Wise%'

-- BETTER: exact match or known variations
WHERE org IN ('Wise', 'TransferWise', 'Wise (formerly TransferWise)')

-- BEST: use company slug if you know it
WHERE org_slug = 'wiseaccount'
```

To find the right slug, search for a known employee first:
```sql
SELECT org, org_slug FROM people_roles WHERE org ILIKE '%Wise%' LIMIT 5
```

### Combining role filters with person filters
Use `people_roles` — it has both role and person fields in the same row:

```sql
-- Find ex-Wise people who are now founders
SELECT DISTINCT first, last, headline, loc
FROM people_roles
WHERE org IN ('Wise', 'TransferWise') AND end IS NOT NULL
AND headline ILIKE '%Founder%'
LIMIT 20
```

## Critical Rules

### Always add LIMIT
Every query MUST have a LIMIT clause. Results are capped at 1,000 rows per query. Default to `LIMIT 20` for exploratory queries, `LIMIT 100` for exports. Use OFFSET to paginate beyond 1,000 (see Pagination section).

### ILIKE vs LIKE
- `ILIKE` is case-insensitive: `ILIKE '%cto%'` matches "CTO", "cto", "Cto"
- `LIKE` is case-sensitive: `LIKE '%CTO%'` only matches "CTO"
- **Gotcha**: `ILIKE '%CTO%'` also matches "DireCTOr", "eleCTOral", etc. For CTO specifically, use `LIKE '%CTO%'` or add exclusions.

### Locale-aware searching
People in non-English countries use local job titles. Always include locale variants when searching by title:

| English | German | French | Spanish |
|---------|--------|--------|---------|
| CEO | Geschäftsführer, Vorstandsvorsitzender | PDG, Directeur Général | Director General |
| CTO | Technischer Leiter | Directeur Technique | Director Técnico |
| CFO | Finanzvorstand | Directeur Financier, DAF | Director Financiero |
| Founder | Gründer, Gründerin | Fondateur, Fondatrice | Fundador, Fundadora |
| Managing Director | Geschäftsführer | Directeur Général | Director General |
| Sales Manager | Vertriebsleiter | Directeur Commercial | Director Comercial |
| Head of | Leiter, Leiterin | Responsable, Directeur | Jefe de, Director de |

Example — finding CEOs in Germany:
```sql
SELECT first, last, headline, loc FROM people
WHERE cc = 'de' AND (
    headline LIKE '%CEO%'
    OR headline ILIKE '%Geschäftsführer%'
    OR headline ILIKE '%Vorstandsvorsitzender%'
    OR headline ILIKE '%Chief Executive%'
)
LIMIT 20
```

### Accessing roles and education
Three patterns:

**`people_roles` table** — fastest for company/role searches (100-300x faster):
```sql
SELECT first, last, title, org
FROM people_roles
WHERE org = 'Google' AND end IS NULL
LIMIT 20
```

**`arrayExists`** — filter people by role criteria, one row per person:
```sql
SELECT first, last, headline
FROM people
WHERE arrayExists(r -> r.org = 'Google', roles)
LIMIT 20
```

**Direct index** — access most recent role:
```sql
SELECT first, last, roles[1].title, roles[1].org
FROM people
WHERE cc = 'uk'
LIMIT 20
```
Note: ClickHouse arrays are 1-indexed. `roles[1]` is the most recent role.

**ARRAY JOIN** — avoid unless you need full nested output. Slow on 756M rows.

### Current role
A current role has `end IS NULL`:
```sql
-- Using ARRAY JOIN
WHERE r.end IS NULL

-- Using arrayExists
WHERE arrayExists(r -> r.end IS NULL AND r.title ILIKE '%CTO%', roles)
```

### NULL handling
- Missing data is `NULL`, never empty string
- Check with `IS NULL` / `IS NOT NULL`
- `headline` and `bio` can be NULL — filter with `headline IS NOT NULL AND headline != ''`

## Pagination

Results are capped at 1,000 rows per query. If a search has more results, use `OFFSET` to paginate:

```sql
-- Page 1 (first 100)
SELECT first, last, headline, loc FROM people
WHERE cc = 'uk' AND headline LIKE '%CTO%'
LIMIT 100 OFFSET 0

-- Page 2 (next 100)
SELECT first, last, headline, loc FROM people
WHERE cc = 'uk' AND headline LIKE '%CTO%'
LIMIT 100 OFFSET 100

-- Page 3
LIMIT 100 OFFSET 200
```

**How to know if there are more results**: there is no pagination metadata. Run a `count()` first to know the total, then paginate:

```sql
-- Step 1: how many total?
SELECT count() FROM people WHERE cc = 'uk' AND headline LIKE '%CTO%'
-- → 4,832

-- Step 2: paginate through them
SELECT ... LIMIT 100 OFFSET 0     -- page 1
SELECT ... LIMIT 100 OFFSET 100   -- page 2
SELECT ... LIMIT 100 OFFSET 200   -- page 3
-- ...continue until you have all 4,832 or enough
```

Always run the count first. Don't just paginate blindly until empty results — you won't know how far to go.

## Output

- **Terminal**: pretty-printed JSON (one object per line)
- **Piped**: raw JSON lines (for jq, scripts, files)

```bash
# Save to file
speaker query "SELECT ..." > results.json

# Pipe to jq
speaker query "SELECT first, last FROM people WHERE cc = 'uk' LIMIT 5" | jq '.first'

# Count results
speaker query "SELECT first FROM people WHERE cc = 'de' LIMIT 100" | wc -l
```

## Data Coverage

756M+ profiles across 244 countries. Top 15:

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

### Field coverage (varies by country, UK example)
| Field | Coverage |
|-------|----------|
| first, last, slug, loc, cc | 100% |
| headline | ~91% |
| bio | ~22% |
| roles (at least one) | ~71% |
| edu (at least one) | ~41% |
| email | Limited |
