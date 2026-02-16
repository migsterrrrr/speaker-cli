# speaker

756 million people. 17 million companies. One SQL query away.

## What this is

A database of the professional world. People, where they work, where they worked, what they do. Companies, how big they are, what industry, how fast they're growing.

Search it with SQL. From your terminal. No browser, no UI, no API wrapper — just queries in, answers out.

```bash
speaker query "SELECT name, headcount, industry FROM companies WHERE cc = 'de' AND headcount > 1000 ORDER BY headcount DESC LIMIT 10"
```

## What's in the box

| Layer | Table | Rows | What it is |
|-------|-------|------|-----------|
| Search | `people_roles` | 1.36 billion | One row per person-role — fast search by title, company, location |
| Search | `companies` | 17 million | Company profiles — headcount, industry, revenue, HQ |
| Enrich | `people` | 756 million | Full person record — work history, education, bio, email |
| Enrich | `companies_full` | 17 million | Company detail — headcount timeseries, department breakdown, funding |

Search first, enrich second. Full schema in [SPEAKER.md](SPEAKER.md).

## Install

```bash
curl -sL https://raw.githubusercontent.com/migsterrrrr/speaker-cli/main/install.sh | sh
```

Custom install directory:
```bash
curl -sL https://raw.githubusercontent.com/migsterrrrr/speaker-cli/main/install.sh | INSTALL_DIR="$HOME/.local/bin" sh
```

## Get started

Speaker is invite-only.

```bash
speaker signup
```

## Commands

```
speaker signup          Sign up with invite code
speaker login <key>     Log in on another machine
speaker query "SQL"     Run a query
speaker schema          Show table structure
speaker count           Total profiles
speaker update          Update to latest version
speaker logout          Remove credentials
speaker help            Quick reference
```

## Limits

| Limit | Value |
|-------|-------|
| Max rows per query | 1,000 |
| Max queries per day | 5,000 |

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
