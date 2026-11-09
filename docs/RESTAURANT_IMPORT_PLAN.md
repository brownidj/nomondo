# Restaurant standardisation and research

Goal: convert the mixed-format restaurant note into uniform SQLite records and
a CSV export, researching missing facts with the OpenAI API.

Scope: extend the existing importer with venue type, region, listed telephone,
original notes and historical ranking. Retain the original source, personal
ratings, API audit records, resume behaviour and evidence requirements.

Tasks:

- Extend structured extraction and research schemas and prompts.
- Add new database columns without replacing existing data.
- Add uniform CSV export and optional refresh of completed research.
- Add regression tests and usage instructions.

Acceptance criteria:

- All supplied separator, hyphenated-town and numbered-list examples can be
  staged and submitted for API extraction without losing source text.
- City and region have separate fields; ranking years are not invented.
- Telephone is stored as text and accepted from research only with retrieved
  source evidence; absent numbers remain blank without a missing-phone flag.
- Notes, historical rankings, ratings and existing data survive research/upgrades.
- Separate known branch addresses are not duplicate candidates; no records merge.
- CSV contains every uniform field and provenance, and preserves punctuation,
  accents and phone formatting. Source/database paths cannot be export targets.
- Runs resume from saved progress; API calls use the configured environment key.

Implementation status: code, documentation and regression cases implemented.
Verification on 2026-11-09 (Codex, project `.venv` interpreter): all 25 unit tests
pass, including null search metadata, field-specific citation recovery, tracking
URLs, raw response retention, adaptive batch retries, the three-failure stop and
the resume workflow, separate web research/structuring and rejection of unsourced
research. Replaying all 15 saved research responses read-only found
128 usable field evidence entries after recovery, compared with one explicit
usable URL before recovery. This checks response handling, not source accuracy.

A SQLite backup was created under `data/backups/` before live retries. The shell
key was rejected, but the updated key in the PyCharm run configuration worked.
A live check exposed unsourced combined search/JSON output; research was changed
to a cited report followed by a separate structured conversion. The successful
retry populated record 481 (Nyhavns Færgekro) with Denmark, its street address,
telephone and official website, retaining 14 evidence entries and no review
reasons. A full detached resume run was then started, with PID and log path in
`data/logs/latest-run.json`. Check process/log/database for current progress;
this document does not imply the complete collection has finished. Source text
and existing research data remain preserved.

Manual verification from the project root (PyCharm's configured interpreter or
the existing `.venv`; record date, tester, command and pass/fail when run):

```zsh
.venv/bin/python -m unittest discover -s tests -v
.venv/bin/python main.py import --limit 25
.venv/bin/python main.py enrich --limit 5
.venv/bin/python main.py export --output data/restaurants.csv
.venv/bin/python main.py review
```

Review that the source file is untouched; inspect exported accents, phone numbers,
notes and rankings, and compare researched phone numbers against evidence URLs.
The API steps incur model/search costs and require a working `OPENAI_API_KEY`.
To finish the collection after the sample review, run `import`, then `enrich`,
then `export` without limits. For older completed research, use
`enrich --refresh-completed` once to populate the new fields.
The single-command equivalent is `main.py resume --refresh-completed`.
