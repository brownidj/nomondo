# Restaurant title rules — 10 November 2026

Goal/acceptance: remove the standalone word Restaurant when another word remains,
preserving Restaurant as a standalone name. Replace standalone at with a comma,
case-insensitively, using normal comma spacing. Preserve embedded words such as
Atlas/Atelier/Restaurantology, possessive names and URL components. Parenthetical
at descriptions become comma suffixes. Clean empty parentheses and connectors
orphaned by removing the label. Apply to additions, edits, imports and previews.

Examples: Restaurant Gwendolyn → Gwendolyn; Blue Spoon Restaurant & Bar →
Blue Spoon & Bar; Claude Bosi at Bibendum → Claude Bosi, Bibendum;
The Dining Room (at Whatley Manor) → The Dining Room, Whatley Manor.

Created restaurant_names.py, tests/test_restaurant_names.py and this document.
Modified restaurant_edits.py (addition/edit validation), beneede.py (model
validation for imports/research), restaurant_lookup.py (structured preview titles),
pyproject.toml (packaging) and the catalogue. No files removed. Original input,
source entries and evidence remain intact; saved names are protected as manual
fields. The migration updated 62 names in one transaction, recording full
before/after values in restaurant_edit_history. Backup and JSON report:
data/backups/restaurants-before-name-cleanup-20261110T130913638191Z.
Migration checks confirmed IDs/count and all other fields unchanged except manual
field protection, including review decisions and archival. Cosmetic cleanup does
not revoke past decisions. Future ordinary edits retain the existing rule that
an actual saved change returns a passed record to pending.

Also changed LED diameter from 10 to 12 pixels in
flutter_app/lib/widgets/restaurant_review_indicator.dart; touch targets unchanged.
Tests added for case/whole-word handling, punctuation, idempotence, preservation
and edit validation restricted to the name. Tests/app launches/builds/API research
were not run per policy. Python syntax, Dart formatting and whitespace checks
passed. Implementation/data migration complete; manual visual/functional
verification pending; phase not applicable.

David: restart Python, reload Flutter and refresh. Check the examples and LED
size on desktop/mobile. Add/edit titles containing Restaurant/at and check the
saved names. Confirm Restaurant alone is retained, notes/addresses remain intact,
and no records disappeared. Optional targeted test:

```zsh
.venv/bin/python -m unittest discover -s tests -p test_restaurant_names.py
```

Suggested commit: Normalise restaurant titles and enlarge review LEDs.

Follow-up 10 November 2026: standalone au now follows the same comma rule as at,
case-insensitively, including parenthetical venue suffixes. Leading/trailing
separator commas are trimmed (Au Crocodile → Crocodile); embedded words and URL
components remain intact. Updated four catalogue names, backed up to
data/backups/restaurants-before-au-title-cleanup-20261110T132555805270Z.sqlite3
with a JSON report and original names in edit history. Other fields, IDs/count
and review decisions were checked unchanged. The shared helper applies this to
future adds/edits/imports. Modified restaurant_names.py, its existing regression
tests and this document; no new/removed source files. Python syntax and whitespace
checks passed; tests not run. Implementation/migration complete; manual verification
pending; phase not applicable. David: restart Python, refresh, and add/edit a name
using au to verify the saved form. Suggested commit: Normalise au in restaurant titles.

Follow-up 10 November 2026: added standalone by to the same comma rule, including
parenthetical suffixes. Updated six titles; backup/JSON report:
data/backups/restaurants-before-by-title-cleanup-20261110T132758806362Z.sqlite3.
Original names are in edit history. IDs/count, review decisions and all other
fields were checked unchanged. Updated the shared helper, existing regression
tests and this document; no new/removed source files. Syntax/whitespace checks
passed; tests not run. Implementation/data migration complete, manual verification
pending; no phase. David: restart Python, refresh and confirm Core, Clare Smyth;
add/edit another by title and check the saved form. Suggested commit: Normalise
by in restaurant titles.
