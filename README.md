# BeneEde

Your world of good eats.

A SQLite restaurant collection imported from `data/restaurants.txt` (the source
file is `.txt`, not `.tex`). The original QJotter export is left unchanged.

Rename details, compatibility paths and reopening steps are recorded in
[the BeneEde rename notes](docs/BENEEDE_RENAME.md).

## Setup

Use Python 3.11 or later, or the existing PyCharm `.venv` interpreter:

```sh
.venv/bin/python -m pip install -e .
```

Set `OPENAI_API_KEY` in your shell or PyCharm run configuration. An OpenAI API
key is required for API commands. The script reads environment variables;
it does not load `.env` automatically. Never commit your key.

## Flutter interface

See [Running BeneEde](docs/RUNNING_THE_APP.md) for Chrome and macOS launch commands,
iOS preparation, the two-terminal workflow and troubleshooting.

The Dart/Flutter application in `flutter_app` lists restaurant name, city, country,
and cuisine. Phone and website icons beneath each restaurant name show
the international-format number and internet address in tooltips when pressed. Special dish and notes icons sit beneath the
cuisine preview and open dialogs with their full content. It includes search
across the displayed fields and the dish/notes content, country
filtering, a **Needs review only** filter and refresh, with desktop columns and
compact cards on smaller windows.

Start the local data service from the project root:

```zsh
.venv/bin/python restaurant_server.py
```

Then, in a second terminal:

```zsh
cd flutter_app
flutter pub get
flutter run -d chrome
```

Use `flutter run -d macos` for a native Mac window. The interface reads live
SQLite data through the local service; it needs no API key. See
[`flutter_app/README.md`](flutter_app/README.md) for configuration and manual checks.

Add/Edit city fields offer offline GeoNames completion, with country and region.
Build/refresh the separate local city index with:

```zsh
.venv/bin/python city_index.py --download
```

See [City suggestions](docs/CITY_AUTOCOMPLETE.md) for coverage and attribution,
and [Review and archive](docs/REVIEWING_RESTAURANTS.md) for recording Passed/Failed
decisions, inspecting source evidence and restoring archived restaurants.

## Import and research

```sh
# Offline import: populate provisional records without calling OpenAI
.venv/bin/python main.py import-local

# Refine all source lines with structured API extraction
.venv/bin/python main.py import

# Look up missing details using the API's web search tool
.venv/bin/python main.py enrich --limit 5

# Research all remaining extracted records
.venv/bin/python main.py enrich

# Export one uniform row per restaurant, including telephone and original text
.venv/bin/python main.py export --output data/restaurants.csv

# Inspect progress and problematic records
.venv/bin/python main.py status
.venv/bin/python main.py review

# Finish extraction, retry failed research, refresh prior research, then export
.venv/bin/python main.py resume --refresh-completed
```

`data/restaurants.sqlite3` stores active restaurant records. Reviewed duplicates
are consolidated with full original records preserved in `record_history`; see
[duplicate consolidation](docs/DUPLICATE_CONSOLIDATION.md). Use
`status` to see current progress: it changes as imports and research complete.
Run `import` with a working key before `enrich`; locally parsed seeds are not
eligible for research until API extraction has refined them. `resume` performs
both steps and writes CSV at the end; omit `--refresh-completed` on ordinary
subsequent runs to avoid repeating completed research.

Both API phases resume from saved progress. `import --limit 25` limits source
lines; `enrich --limit 5` limits restaurants. Each successful extraction batch
and each researched record is committed separately. Failed research is flagged
and retried with `enrich --retry-failed`. Authentication failures during import
leave the current batch pending. API commands incur model costs; web research
also incurs search costs.

Incomplete or invalid extraction batches are saved for inspection and retried as
smaller batches. A failing single-line request remains pending for the next run.
Research tolerates null search-source metadata and recovers missing evidence URL
properties from the same field's inline link or citation annotation. URL matching
ignores `utm_*` tracking parameters and fragments, but retains meaningful query
parameters. It never uses an unrelated result as evidence for another field.
Failure records retain the exception type and code location without provider
error text or credentials; available raw responses are audited with a failed
phase. Three consecutive research failures stop the run, as do account/model
configuration errors, to avoid repeating failures across the entire collection.

Research now uses two API calls per venue: a web search with a readable venue
query and cited factual report, followed by conversion of that report into the
structured record. The second call receives the retrieved source URLs, so its
field evidence can be checked against the first call. Both responses and their
usage are preserved together in the audit payload. Unsourced research is flagged
as a failure rather than saved as a completed research result.

Existing databases receive the additional columns automatically when opened by
any command. Existing IDs, ratings, research and original text are retained.
If records were already researched with an older version, run
`enrich --refresh-completed` to research them again for the new fields, including
telephone numbers. Add `--limit 5` for a small first run. Ordinary `enrich` keeps
skipping completed records. API extraction still refines pending/offline records;
it does not re-extract previously completed source lines.

Extraction defaults to `gpt-4.1-mini`, research to `gpt-4.1`. Override each using
`--model` or the `OPENAI_EXTRACT_MODEL` / `OPENAI_ENRICH_MODEL` environment
variables. The research model must support Responses, structured output and
web search. Use `--db /path/to/collection.sqlite3` **before** the command to use
another database; `import` and `import-local` accept `--source /path/to/note.txt`.
`init` creates the schema and stages lines without extracting restaurants.

## Data and review

The uniform restaurant fields are:

| Column | Contents |
| --- | --- |
| `restaurant_name` | Name, preserving accents; corrections require research evidence |
| `venue_type` | Restaurant, bar, cafe, bakery, market, food stall, food tour or other |
| `city` | City or town |
| `region` | State, province or district, separate from city and country |
| `country` | Normalised country name |
| `address` | Verified full street address |
| `telephone` | Listed telephone number(s), stored as text with +, zeros and extensions |
| `internet_link` | Official website where available |
| `cuisine` | Cuisine or food style |
| `special_dish` | Recommended dishes or drinks |
| `notes` | Original recommendations, descriptive details and ordering instructions |
| `historical_ranking` | Original rank/award and list/year when supplied; never an inferred year |
| `rating` | Personal numeric rating, default 0; never set by the API |

The database also contains:

- `needs_review`, JSON `review_reasons`, possible `duplicate_ids`, venue status,
  identity confidence, enrichment status, model names and timestamps.
- Field-level JSON `evidence` and a link to the original source line.

`export` writes UTF-8 CSV with a header and one row per active restaurant,
including all these fields, source file, line number, original text and
`record_history` with the complete source records of consolidated duplicates. Unknown
values become empty CSV cells; JSON metadata remains JSON in its cells. Commas,
quotes, newlines and accents are preserved. Exporting again replaces the CSV,
but output paths matching the original source or database are rejected. When
opening CSV in a spreadsheet, import `telephone` as **text** to retain its exact
formatting and leading zeros. CSV export needs no API key.

`review_queue` is a SQL view that includes the original text and line number:

```sql
SELECT restaurant_name, city, country, review_reasons, raw_text
FROM review_queue ORDER BY id;
```

Every nonempty source line is preserved in `source_lines`. Ignored prose and
headings retain a reason; the `review` command also shows lines skipped by the
offline parser. Full successful API responses, search metadata and usage are
stored in `api_runs` for inspection. API calls use `store=False`.

Offline parsing is deliberately provisional. API extraction handles mixed
separators, numbered and bulleted rankings, pasted articles and multiple venues
on one line. Extraction uses supplied facts only; enrichment searches for the
precise venue and branch, including spelling corrections and closure status.
Unknown values remain SQL NULL. Historical rankings never become user ratings.
New or changed facts require evidence URLs present in the search tool metadata
or citation annotations; unsupported proposals are flagged and not applied.
This verifies source provenance, not that every claim on the page is correct.

Telephone numbers are included only when listed in the input or a researched
source for the matching venue/branch. The API must not invent digits or infer a
calling code. Unlisted numbers remain NULL, without a missing-telephone review
flag. Region, special dishes, notes and historical rankings are optional too.
Research retains existing source notes and rankings. Refreshes retain evidence
for unchanged facts from previous runs.

Missing core fields, low identity confidence (below 0.85), uncertain status, closures,
ambiguity and invalid links trigger review. Duplicate detection compares names
and locations after removing accents, punctuation and case. Conflicting known
countries, regions or street addresses exclude separate branches from duplicate
candidates. The reviewed consolidation workflow also handles confirmed spelling,
country and address variants; it preserves conflicts and the complete originals
before deleting redundant rows. The detector does not merge records automatically. Read the source and evidence
before resolving a review flag. Ratings survive enrichment and repeated imports.
API extraction refuses to replace offline seeds that already have a nonzero
rating or research results.

Treat the input file as an immutable snapshot. Re-running an unchanged file is
idempotent. Editing or moving it introduces new source identities; use a new
database for a revised snapshot, or reconcile it manually to avoid duplicates.

The API implementation follows the official OpenAI documentation for
[Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
and [web search](https://developers.openai.com/api/docs/guides/tools-web-search).

## Tests

```sh
.venv/bin/python -m unittest discover -s tests -v
```

Tests use mocked API responses and temporary databases, including all supplied
formats, combined records, prose, idempotency, duplicates, partial batch failures,
evidence checks, research retries and rating preservation.
Additional regression cases cover all the supplied sample formats, listed and
unsupported telephone numbers, optional missing phone numbers, note/ranking
preservation, new-column migration, branch handling and CSV round trips. These
are mocked tests; they do not prove live API extraction or web research quality.

## Editing restaurants

An edit icon follows the website icon beneath each restaurant name, including
records without contact details. It opens a compact, scrollable modal. Save updates
the database and the displayed record; Cancel leaves it unchanged. Main details
are shown directly, with region, venue type, rankings, rating and venue status
under More details. See [editing and manual verification](docs/EDITING_RECORDS.md).

## Adding restaurants

Use **Add restaurant** on the Sort/A–Z row. Enter restaurant name and city, or an internet address on its own.
With only those fields, the form asks whether to research missing details. No
adds manually; Yes uses the configured OpenAI API and presents the found branches
for review before saving. A supplied website is read first for missing details
and branches. Structured website data works without AI; interpreting unstructured
page text uses the API when configured. All distinct discovered branches can be
added together, while known existing branches are reported and left unchanged.
See [adding restaurants](docs/ADDING_RESTAURANTS.md) for setup and manual checks.
