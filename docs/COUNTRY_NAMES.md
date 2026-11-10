# Full country names — 10 November 2026

Goal: expand all recognised country abbreviations in the active catalogue and
normalise future manual/API/structured-website entries. Scope is the country
field; preserve addresses, notes, missing values, source text and qualified names.

Implemented a shared country_names.py helper using English country metadata in
the existing phonenumbers dependency, resolving its compressed translation
references. Supports country codes and common aliases such as UK/USA/UAE/RSA,
including dotted forms. Full names and unrecognised values are preserved. Used
by beneede.Restaurant validation, restaurant_edits validation, structured website
extraction and telephone-region lookup; registered in pyproject.toml.

Catalogue update: 40 records changed. IN→India (12), USA→United States (13),
UK→United Kingdom (4), GB→United Kingdom (3), and AE/AU/CA/MY/NP/SG/TH/US
(one each). Backup and JSON report are in data/backups under
restaurants-before-country-expansion-20261110T115310524518Z.
Each change is recorded in restaurant_edit_history. An initial unresolved metadata
reference affected 19 entries; these were corrected from the backup in the same
session, with corrective audit entries retained. Final data checks confirmed all
40 expected full names and no remaining recognised codes or metadata references.

Acceptance: known abbreviations expand consistently, no records are removed, no
other restaurant fields change, future additions/edits retain full country names,
and telephone formatting still recognises their dialing regions. Implementation
and catalogue migration complete; visual/manual verification pending. No phase.

Created country_names.py, tests/test_country_names.py and this document. Modified
beneede.py, phone_numbers.py, restaurant_edits.py, restaurant_lookup.py,
pyproject.toml and the catalogue. No files removed. Original source/audit data
was retained. Regression tests cover reference resolution, aliases, preservation,
edit normalisation and telephone regions; tests and app builds were not run.
Static Python syntax and whitespace checks passed. No API calls were made.

Manual verification (David, macOS; record date/result): restart the Python service
and refresh the list. Confirm Countries includes India, United Kingdom, United
States and United Arab Emirates, without the old standalone codes. Add/edit a
country code and confirm it saves as a full name. Other name variants such as
Scotland, United Kingdom are intentionally preserved; this is not a geopolitical
reclassification or an address rewrite. Optional targeted tests:

```zsh
.venv/bin/python -m unittest discover -s tests -p test_country_names.py
```

Suggested commit: Expand country abbreviations and normalise future entries.

## Equivalent country labels — 10 November 2026

User-requested follow-up supersedes the earlier preservation of equivalent
qualified-name spellings. Goal/acceptance: equivalent country labels produce
one filter option, retaining known UK constituent-country distinctions and
preserving other restaurant fields and every record. Canonical forms are
England, United Kingdom; Scotland, United Kingdom; Wales, United Kingdom;
Northern Ireland, United Kingdom; Hong Kong; and Netherlands. Bare United Kingdom
remains unchanged because the constituent country is not known. Explicit England
and Kingdom misspellings from the request are recognised, without fuzzy matching.

Applied to 15 records, with before/after entries in restaurant_edit_history and
a backup/JSON report named
data/backups/restaurants-before-country-deduplication-20261110T115542749741Z.
country_names.py and tests/test_country_names.py modified; this document updated.
No new source files or removed files. The existing shared normaliser also applies
these labels to future entries and edits. Dialling-region lookup recognises
Northern Ireland as United Kingdom.

Static syntax/whitespace and migration data checks passed, including unchanged
record count and unchanged non-country fields for each modified record. Tests
were extended but not run; no app launches/builds or API calls. Implementation
and data migration complete, manual visual verification pending; phase not
applicable. David: restart the service, refresh the app and check Countries for
one option per canonical label. Optional test command remains the one above.
No restaurant records were deduplicated or deleted. No country subdivision was
inferred for records with only United Kingdom. Suggested commit: Canonicalise
equivalent country labels.
