# Speaker — B2B Person Search

A CLI tool for searching 756M+ B2B person profiles via SQL. Run `speaker query "SELECT ..."` to search.

## Quick Reference

```bash
speaker query "SQL"       # Run a query
speaker count             # Total profiles
speaker schema            # Show table structure
speaker help              # All commands
```

## Table: `people`

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

## Country Codes

Lowercase two-letter. Uses `uk` not `gb`. Examples:
`us`, `uk`, `de`, `fr`, `at`, `ch`, `in`, `br`, `es`, `it`, `nl`, `ca`, `au`, `cn`, `id`, `mx`, `za`, `co`, `pl`, `se`, `tr`, `ae`, `sa`, `eg`, `ng`, `ke`, `sg`, `jp`, `kr`, `ph`, `my`, `th`, `vn`, `ie`, `dk`, `no`, `fi`, `pt`, `ro`, `cz`, `hu`, `il`, `ar`, `cl`, `pe`, `pk`, `bd`

## Query Patterns

### Search by headline/title
```sql
-- CTOs in Germany
SELECT first, last, headline, loc
FROM people
WHERE cc = 'de' AND headline LIKE '%CTO%'
LIMIT 20

-- Founders in the UK
SELECT first, last, headline, loc
FROM people
WHERE cc = 'uk' AND headline ILIKE '%founder%'
LIMIT 20
```

### Search by company (current)
```sql
SELECT first, last, r.title, r.org
FROM people ARRAY JOIN roles AS r
WHERE r.org ILIKE '%Google%' AND r.end IS NULL
LIMIT 20
```

### Search by company (past)
```sql
SELECT first, last, headline, loc
FROM people
WHERE arrayExists(r -> r.org ILIKE '%McKinsey%' AND r.end IS NOT NULL, roles)
AND cc = 'uk'
LIMIT 20
```

### Search by current role title
```sql
SELECT first, last, r.title, r.org, loc
FROM people ARRAY JOIN roles AS r
WHERE r.title ILIKE '%VP Sales%' AND r.end IS NULL AND cc = 'us'
LIMIT 20
```

### People who moved between companies
```sql
SELECT first, last, headline, loc
FROM people
WHERE arrayExists(r -> r.org ILIKE '%Deloitte%' AND r.end IS NOT NULL, roles)
AND arrayExists(r -> r.end IS NULL AND r.org NOT ILIKE '%Deloitte%', roles)
AND cc = 'uk'
LIMIT 20
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
Two patterns for querying arrays:

**ARRAY JOIN** — returns one row per role (use when you need role details):
```sql
SELECT first, last, r.title, r.org
FROM people ARRAY JOIN roles AS r
WHERE r.org ILIKE '%Google%'
LIMIT 20
```

**arrayExists** — returns one row per person (use for filtering):
```sql
SELECT first, last, headline
FROM people
WHERE arrayExists(r -> r.org ILIKE '%Google%', roles)
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

**How to know if there are more results**: if a query returns exactly the number you set in LIMIT, there are likely more. Run a `count()` first to check:

```sql
-- How many total?
SELECT count() FROM people WHERE cc = 'uk' AND headline LIKE '%CTO%'

-- Then paginate through them
SELECT ... LIMIT 100 OFFSET 0
SELECT ... LIMIT 100 OFFSET 100
-- etc.
```

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
