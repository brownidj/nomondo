# Duplicate consolidation — 10 November 2026

Completed 28 reviewed groups: 490 active records became 455 by deleting 35
redundant rows. The surviving ID is selected by the number of meaningful populated
restaurant detail fields (excluding blank, Unknown, Not listed and N/A), then
combined detail length, then the lower ID for a deterministic tie. Audit payload
length does not affect this choice.

Missing fields are filled, distinct cuisine/dish/notes/ranking text is combined,
phone alternatives and evidence are unioned. The primary identity, single website
and numeric metadata stay with the richer record; differing values are preserved
as labelled alternative details in Notes and in exact record history. Disagreements
remain marked for review rather than being silently resolved. For example Brahmin’s
Coffee Bar retains the conflicting street numbers, and MTR retains both phones.

Every input row, including all IDs, source IDs, ratings, timestamps, models, review
flags and evidence, plus its complete source-line row, is saved in the survivor's
`record_history` JSON. An additional immutable `consolidation_history` event stores
the originals and the reviewed reason. `consolidation_sources` maps all source
occurrences to the survivor; import/extraction skip already consolidated sources,
preventing the deleted occurrences from being reinserted on normal resume.
The original source_lines and api_runs tables are unchanged.

Reviewed matching used names, country/city variants, addresses, phones and website
identity. The same-name Artichoke venues in Singapore and the UK were kept separate.
Fuzzy matches such as Hashem/Abu Hatem and Marble/AtholPlace were rejected as distinct
venues. Similar spelling alone never authorizes consolidation.

## Files and recovery

- Database backup: `data/backups/restaurants-before-consolidation-20261110T030414909354Z.sqlite3`.
- Previous CSV backup: same backup basename with `.csv` extension.
- Reviewed groups, reasons and input fingerprints: `data/review/duplicate-consolidation-plan-20261110.json`.
- Per-group survivors, deleted IDs and completeness scores: `data/review/duplicate-consolidation-result-20261110.json`.
- The refreshed `data/restaurants.csv` contains 455 records and full `record_history`.

A backup is made before any writes, under a database write lock. The maintenance
script refuses changed input fingerprints, validates exact input snapshots in each
survivor, counts, foreign keys, integrity and unaffected records before committing.
All groups apply in one transaction; failure rolls back the whole operation.
The source text was not edited; an exact comparison against the backup confirmed
all 501 source-line rows and all 556 API audit rows are unchanged. The original
CSV was backed up before regenerating it. Backup and history contain enough data
to recover removed occurrences; do not delete them during routine cleanup.

`consolidate_duplicates.py --db PATH --plan PATH` is for explicitly reviewed plans.
The plan applied here is historical; rerunning it intentionally fails because its
input records have changed/disappeared. Do not regenerate a plan blindly from
fuzzy matches. No automatic merges are performed during application startup.

## Implementation and manual checks

Created the consolidation utility, preservation tests and this document; modified
schema/import guards, CSV export, Python package module list and README. Database,
backup, reviewed plan/result and CSV were updated as described above. The deleted
rows are the redundant active records; source/API rows and source files remain.

The authorized data migration and CSV export were run. Python syntax and diff
whitespace checks passed, as did the migration's preservation/integrity checks.
Unit tests, Flutter analysis, application launches and platform builds were not
run under the manual verification policy. No tests of live APIs were performed.

Press Refresh in BeneEde: expect 455 restaurants. Inspect Notes for retained
recommendations and alternative details, especially the conflicting addresses;
check phone alternatives. For manual tests run:

```zsh
.venv/bin/python -m unittest discover -s tests -p test_consolidate_duplicates.py -v
```

Record date, tester, platform and results. Phase: not applicable. No commit/push
was made. Suggested commit: `Consolidate reviewed duplicates while preserving every source record`.
