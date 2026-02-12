# Speaker — B2B Person Search

756M+ person profiles. Query any combination of fields — job title, company, location, headline, education, bio, and more. Full SQL access via `speaker query`.

Use it however you want. Sales prospecting, market research, recruiting, competitive analysis, or things we haven't thought of yet. This doc is guidance based on what we've learned so far — not rules. The data is yours to explore.

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

### `people_roles` ⭐ PRIMARY TABLE

One row per person-role. 1.36B rows. Sorted by company name.

| Field | Type | Description |
|-------|------|-------------|
| `title` | String | Job title |
| `org` | String | Company name |
| `org_slug` | String | Company identifier (for exact matching) |
| `start` | Nullable(String) | Start date (YYYY-MM) |
| `end` | Nullable(String) | End date. **NULL = current role** |
| `desc` | Nullable(String) | Role description — useful for qualifying scope of responsibility |
| `cc` | String | Country code |
| `slug` | String | **Person identifier — always include this** |
| `first` | String | First name |
| `last` | String | Last name |
| `headline` | String | Professional headline |
| `loc` | String | Location |

### `people` — enrichment & everything else

756M profiles. One row per person.

| Field | Type | Description |
|-------|------|-------------|
| `first` | String | First name |
| `last` | String | Last name |
| `slug` | String | Unique person identifier |
| `headline` | Nullable(String) | Professional headline |
| `loc` | Nullable(String) | Location (city, country) |
| `cc` | LowCardinality(String) | Country code (lowercase) |
| `email` | Nullable(String) | Email (where available) |
| `bio` | Nullable(String) | Short bio (max 200 chars) |
| `roles` | Array(Tuple) | Work history — `title`, `org`, `slug`, `web`, `cc`, `start`, `end`, `desc` |
| `edu` | Array(Tuple) | Education — `school`, `deg`, `slug` |

### Which table to use

| If your search involves... | Use | Why |
|---------------------------|-----|-----|
| Job title or company name | `people_roles` | Indexed, fast |
| Company alumni / career tracking | `people_roles` | Subquery on `slug` |
| Headline search | `people` | No role needed |
| Name lookup | `people` | Name + country |
| Email, bio, education | `people` | Only here |

**Rule of thumb**: title or company → `people_roles`. Everything else → `people`.

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

### Field coverage (UK example)

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
