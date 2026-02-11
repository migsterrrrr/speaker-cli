# speaker

Search 756M+ B2B person profiles from your terminal. SQL-native. Public data only.

## Install

```bash
curl -sL https://raw.githubusercontent.com/migsterrrrr/speaker-cli/main/install.sh | sh
```

Or manually:

```bash
curl -sL https://raw.githubusercontent.com/migsterrrrr/speaker-cli/main/speaker -o /usr/local/bin/speaker
chmod +x /usr/local/bin/speaker
```

## Get started

```bash
# Create an account (pending approval)
speaker signup

# Check if approved (auto-saves your API key when ready)
speaker status

# Search
speaker query "SELECT first, last, headline, loc FROM people WHERE cc = 'uk' AND headline LIKE '%CTO%' LIMIT 20"
```

## Commands

| Command | Description |
|---------|-------------|
| `speaker signup` | Create an account (pending approval) |
| `speaker status` | Check approval status (auto-saves API key when approved) |
| `speaker login` | Log in with email/password |
| `speaker login <key>` | Log in with an API key directly |
| `speaker query "SQL"` | Run a query |
| `speaker count` | Total profiles |
| `speaker schema` | Show table structure |
| `speaker logout` | Remove credentials |
| `speaker update` | Update to latest version |
| `speaker help` | Help |

## Schema

### `people` table

**Person fields**

| Field | Type | Description |
|-------|------|-------------|
| `first` | String | First name |
| `last` | String | Last name |
| `slug` | String | Unique profile identifier |
| `headline` | String | Professional headline |
| `loc` | String | Location (city, country) |
| `cc` | String | Country code (`us`, `uk`, `de`, `fr`, etc.) |
| `email` | String | Email (where available) |
| `bio` | String | Short bio |

**Work history** — `roles` array, most recent first

| Field | Description |
|-------|-------------|
| `roles[].title` | Job title |
| `roles[].org` | Company name |
| `roles[].slug` | Company identifier |
| `roles[].web` | Company website |
| `roles[].cc` | Country of role |
| `roles[].start` | Start date (YYYY-MM) |
| `roles[].end` | End date (YYYY-MM, NULL = current) |
| `roles[].desc` | Role description |

**Education** — `edu` array

| Field | Description |
|-------|-------------|
| `edu[].school` | Institution |
| `edu[].deg` | Degree and field |
| `edu[].slug` | Institution identifier |

## Examples

```bash
# CTOs in Germany
speaker query "SELECT first, last, headline, loc FROM people WHERE cc = 'de' AND headline LIKE '%CTO%' LIMIT 20"

# People currently at Google
speaker query "SELECT first, last, r.title, r.org FROM people ARRAY JOIN roles AS r WHERE r.org ILIKE '%Google%' AND r.end IS NULL LIMIT 20"

# Founders in the UK
speaker query "SELECT first, last, headline, loc FROM people WHERE cc = 'uk' AND headline ILIKE '%founder%' LIMIT 20"

# Country distribution
speaker query "SELECT cc, count() as c FROM people GROUP BY cc ORDER BY c DESC LIMIT 20"

# People who worked at Deloitte but now work somewhere else
speaker query "SELECT first, last, headline, loc FROM people WHERE arrayExists(r -> r.org ILIKE '%Deloitte%' AND r.end IS NOT NULL, roles) AND cc = 'uk' LIMIT 20"

# Export to JSON
speaker query "SELECT first, last, headline FROM people WHERE cc = 'fr' LIMIT 100" > france.json

# Pipe to jq
speaker query "SELECT first, last FROM people WHERE cc = 'us' LIMIT 5" | jq '.first'
```

## Coverage

756M+ profiles across 244 countries. Strongest coverage:

| Region | Profiles |
|--------|----------|
| North America | 215M |
| Europe (West) | 131M |
| South America | 100M |
| South Asia | 96M |
| East & SE Asia | 87M |
| MENA | 32M |
| Sub-Saharan Africa | 32M |

## Limits

| Limit | Value |
|-------|-------|
| Max rows per query | 1,000 |
| Max queries per second | 5 |
| Max queries per day | 5,000 |

For result sets larger than 1,000, use `OFFSET` to paginate:

```bash
speaker query "SELECT ... LIMIT 100 OFFSET 0"    # page 1
speaker query "SELECT ... LIMIT 100 OFFSET 100"   # page 2
```

## Tables

| Table | Rows | Use for |
|-------|------|---------|
| `people_roles` ⭐ | 1.36B | **Start here.** Search by job title, company, role. |
| `people` | 756M | Headline, country, education, name lookups, email/bio enrichment. |

```bash
# Find CTOs in London — search by title in people_roles
speaker query "SELECT first, last, title, org FROM people_roles WHERE title ILIKE '%CTO%' AND cc = 'uk' AND loc ILIKE '%London%' AND end IS NULL LIMIT 20"

# Search by company
speaker query "SELECT first, last, title, org FROM people_roles WHERE org = 'Google' AND end IS NULL LIMIT 20"

# Search by headline — use people
speaker query "SELECT first, last, headline FROM people WHERE cc = 'uk' AND headline LIKE '%CTO%' LIMIT 20"
```

## How it works

Speaker is built for **iterative search** — start broad, refine, export. Don't write the perfect query first. Explore.

```
1. Scope     → SELECT count() FROM people_roles WHERE org ILIKE '%NHS%'
2. Explore   → SELECT title, count() ... GROUP BY title ORDER BY c DESC
3. Refine    → Add filters: title, location, current/past role
4. Export    → LIMIT 100 OFFSET 0, OFFSET 100, ...
5. Enrich   → SELECT email, bio FROM people WHERE slug IN (...)
```

## Tips

- **Search by job title**: `title` in `people_roles` is the most precise field. Use it for "find me CTOs", "VP Sales", etc.
- **`title` vs `headline`**: `title` = actual job title at a company. `headline` = self-written summary. Title is more reliable.
- **Use `people_roles` for title + company searches**: 100-300x faster than ARRAY JOIN. Indexed by company name.
- **Use `people` for everything else**: headline searches, name lookups, education, email/bio enrichment.
- **Company matching**: `ILIKE '%Wise%'` matches ConnectWise, WiseClick, etc. Use exact match (`org = 'Wise'`) or slug (`org_slug = 'wiseaccount'`).
- **Pagination**: Run `count()` first to know total results, then paginate with `LIMIT`/`OFFSET`.

## Notes

- Country codes are **lowercase**: `us`, `uk`, `de`, `fr`, `at`, `ch`
- UK uses `uk` not `gb`
- Dates are `YYYY-MM` format
- `ILIKE '%CTO%'` also matches "Director" — use `LIKE` for case-sensitive
- Current role = `roles[1]` or `WHERE r.end IS NULL`
- All data sourced from public B2B records.

## Requirements

- macOS or Linux
- `curl` (pre-installed on both)
- That's it. No runtimes, no dependencies.
