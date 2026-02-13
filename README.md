# speaker

756 million people. 17 million companies. One SQL query away.

```bash
curl -sL https://raw.githubusercontent.com/migsterrrrr/speaker-cli/main/install.sh | sh
```

## What this is

A database of the professional world. People, where they work, where they worked, what they do. Companies, how big they are, what industry, how fast they're growing.

Search it with SQL. From your terminal. No browser, no UI, no API wrapper — just queries in, answers out.

```bash
speaker query "SELECT name, headcount, industry FROM companies WHERE cc = 'de' AND headcount > 1000 ORDER BY headcount DESC LIMIT 10"
```

```bash
speaker query "SELECT first, last, title, org FROM people_roles WHERE org_slug = 'stripe' AND title LIKE '%CTO%' AND end IS NULL"
```

## Get started

Speaker is invite-only. You need an invite code.

```bash
speaker signup
```

Your API key is saved on signup. Start querying immediately.

## What's in the box

| Table | Rows | What it is |
|-------|------|-----------|
| `people` | 756 million | Person profiles — name, headline, location, bio, work history, education |
| `people_roles` | 1.36 billion | One row per person-role — fast search by job title and company |
| `companies` | 17 million | Company profiles — name, headcount, industry, revenue, HQ |
| `companies_full` | 17 million | Same companies with timeseries, department breakdowns, funding |

## Docs

Everything you need to write queries — schema, field names, patterns, pitfalls:

```bash
cat ~/.speaker/SPEAKER.md
```

Or read it on GitHub: [SPEAKER.md](SPEAKER.md)

## Commands

```
speaker signup          Sign up with invite code
speaker query "SQL"     Run a query
speaker schema          Show table structure
speaker count           Total profiles
speaker update          Update to latest version
speaker help            Help
```

## Limits

| Limit | Value |
|-------|-------|
| Max rows per query | 1,000 |
| Max queries per day | 5,000 |

Public data only. Use it however you want.

<div align="center">
<br>
<i>
When you free a human from thinking,
<br>we don't stop.
<br>We feel more.
<br>We become braver.
<br>We become kinder.
<br><br>
Somewhere in the chain,
<br>between the signal and the playbook,
<br>there must be a moment
<br>where a human looks at another human
<br>and says:
<br><br>
<b>I see you.</b>
<br><br>
Not your title.
<br>Not your company.
<br>Not your MQL score.
<br><br>
<b>You.</b>
<br><br>
— speaker.sh
</i>
<br>
</div>
