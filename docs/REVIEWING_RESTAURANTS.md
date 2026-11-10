# Reviewing and archiving restaurants

Implemented 10 November 2026. Goal/acceptance: inspect saved review reasons,
record a human decision and archive failures reversibly. Passed clears the review
queue. Failed requires a reason/confirmation, then hides the entry from the active
catalogue. Archived shows complete data/history and Restore returns the same ID
to active review. Stale decisions cannot overwrite newer records. No restaurant
or source record is deleted by reviewing/archiving.

Press the checklist icon after Edit beneath the name. The modal shows review
status/previous note, automatic flags, possible duplicate IDs, confidence, all
restaurant details, field-level evidence/source links, original source entries,
preserved consolidated records and human review history. Opening it reads saved
information, without fresh web research. Open evidence links or Edit details to
investigate identity/branch, trading status, address, contacts, cuisine/dishes and
duplicates. Missing optional information can be acceptable.

Pass records time/note, clears needs_review, and shows a Passed label while hiding
the review icon.
Original flags remain for audit and are identified as historical. Editing a passed
entry returns it to Pending/Needs review. Keep pending records a note without
passing/archiving. Fail & archive requires a new reason and confirmation, records
Failed and archived_at, and hides the entry from active/review lists. Turn on
Archived to inspect it, then Restore to return all facts and the same ID to the
active queue. Archived entries show a red icon/label. Needs review only returns
to active records; other country/city/search filters still apply to Archived.
Close makes no decision.

Review outcome and venue trading status are separate. Existing closed flags
require evidence checking; they do not trigger automatic failure. Old entries are
Pending until a human decision, even when they have no automatic review flags.
No existing records were automatically passed, failed or archived.

Storage: additive review_status, reviewed_at, review_note and archived_at columns.
restaurant_review_history saves full before/after records for decisions/restores.
GET /api/restaurants/ID/review loads context; POST uses the existing localhost,
origin, JSON/header and revision protections. Sources, notes, ratings, flags and
duplicate history are retained. Archived records remain in the database/API/export
data, separated in the app views. Background enrichment skips archived entries.

The live catalogue received only additive schema, backed up to
data/backups/restaurants-before-review-metadata-20261110T120650233663Z.sqlite3.
Migration checks confirmed original IDs/count/fields unchanged and zero archived
entries. Restart the service and refresh before editing: added columns change
revision hashes.

Created restaurant_reviews.py, review_restaurant_dialog.dart, Python/Flutter
tests and this document. Modified beneede.py, restaurant_edits.py,
restaurant_server.py, restaurant.dart, restaurant_repository.dart,
restaurant_list_page.dart, pyproject.toml and README.md. No files removed.
Regression coverage: evidence display, pass/queue removal, fail/restore without
data loss, failure reason and confirmation cancellation, stale revisions and
pass invalidation after edit. Static Python syntax, Dart formatting and whitespace
checks passed. Tests/app launches/builds/paid API research were not run per project
policy. Implementation complete; manual functional verification pending. No phase.

David, macOS/Chrome/iOS (record date/results): restart service and reload Flutter.
Inspect a flagged record's details/sources, Pass and confirm it leaves the queue
and remains Passed after refresh. Edit it and confirm it returns to review. Fail
another with a reason, cancel confirmation once and verify nothing changed, then
confirm. Check it appears only in Archived with all original details and can be
restored under the same ID. Check narrow screens and stale concurrent decisions.
Optional targeted tests:

```zsh
.venv/bin/python -m unittest discover -s tests -p test_restaurant_reviews.py
cd flutter_app
flutter test test/review_restaurant_dialog_test.dart
```

Suggested commit: Add audited restaurant reviews and reversible archives.

## Review controls follow-up — 10 November 2026

Goal/acceptance: passed entries have no review icon, while retaining their Passed
label and ordinary Edit icon. Editing a passed entry returns it to Pending and
the review icon reappears. Restaurant details remain read-only in review. An
outlined Edit details button is placed within the expanded Restaurant details
section, where it opens the existing editor with Save and Cancel. Save refreshes
the underlying review with the persisted record; Cancel discards the editor's
draft and leaves the review unchanged. Review notes remain separate.

Modified restaurant_list_page.dart, review_restaurant_dialog.dart, the review
modal regression tests and this document. No new/removed files or catalogue
changes. Added a regression for opening Edit details, finding Save, cancelling
an edited name and preserving the underlying review. Tests not run per policy;
Dart formatting, Python syntax and whitespace checks passed. Implementation
complete, manual verification pending; no phase.

David: reload Flutter, Pass a restaurant and confirm its checklist disappears.
Open another review, press Edit details, change a value and Cancel: review details
must remain unchanged. Repeat with Save: the review must show the saved value,
and a subsequent review decision must use the updated revision. Edit a passed
entry from its normal Edit icon and confirm it returns to review. Use the targeted
review test command above if desired. Suggested commit: Hide passed review icons
and make review editing controls clearer.

## Failure note placement — 10 November 2026

Clicking Fail & archive moves the new review-note field immediately below the
red validation message. An empty required reason receives focus and scrolls into
view. The same controller retains entered text when moving; other review actions
keep the usual note location until failure is selected. Archival still requires
a reason and confirmation. Modified the review modal, its existing failure
regression (placement/focus assertions), and this document. No new/removed files
or catalogue changes. Dart formatting and whitespace checks passed; tests/app
launches were not run. Implementation complete; manual UI verification pending.
David: click Fail & archive with an empty note on a narrow and wide screen;
confirm the field sits below the red text, is focused, and retains typed text
when cancelling/retrying confirmation. Phase: not applicable. Suggested commit:
Place failure review notes below validation message.

## Confidence beside Review — 10 November 2026

Goal/acceptance: show saved research confidence as a rounded percentage beside
the review icon, grouped to stay on the same line. Unknown/invalid scores show
no percentage; valid zero shows 0%. Passed records hide the entire review group.
The tooltip identifies the value as research confidence, not review completion.
Modified restaurant_edits.py to include confidence in API records, restaurant.dart
to read valid 0–1 scores, restaurant_list_page.dart to display the percentage,
and this document. No files created/removed, database changes or tests added/run.
Python syntax, Dart formatting and whitespace checks passed. Implementation
complete; manual UI verification pending; phase not applicable. David: restart
the Python service, reload Flutter and refresh. Check a scored pending record,
an unknown score and a passed record. Suggested commit: Show research confidence
beside restaurant review icon.

## Review queue order — 10 November 2026

Selecting Needs review only now selects Review confidence, lowest first.
Unscored restaurants come first; equal scores use restaurant name and existing
stable location/ID tie breakers. Confidence uses the saved numeric score, not
the rounded display percentage. The sort menu offers Review confidence; Low–high
and High–low direction labels replace A–Z/Z–A for this numeric sort. Users can
still explicitly choose a different sort. Re-selecting the review filter restores
the lowest-first default.

Modified restaurant_sort.dart, restaurant_list_page.dart and this document.
No files created/removed, catalogue changes or tests added/run. Dart formatting
and whitespace checks passed. Implementation complete; manual verification
pending; phase not applicable. David: reload Flutter, select Needs review only,
and confirm unscored entries precede increasing confidence values. Reverse order
and confirm numeric sorting; re-select the filter and check lowest-first resets.
Suggested commit: Default review queue to ascending confidence.

## Inline LED review indicators — 10 November 2026

Goal/acceptance: replace the active checklist control with a small LED after the
restaurant name. Passed entries show a non-interactive green light, without a
percentage or Passed text label. Pending entries show an amber light plus the
saved rounded confidence, when known; both belong to one button opening the
existing review modal. Unscored entries show just amber. The dot is 10 pixels,
styled with a highlight/gradient and subtle glow; pending buttons have a larger
touch target and support keyboard activation. Tooltips and semantics identify
status without relying only on colour. The name remains selectable and the
indicator is an inline span, including wrapped names. Phone/site/Edit stay on the
second row. Archived records retain their archive/review access and status label.

Created restaurant_review_indicator.dart and its interaction regression tests;
modified restaurant_list_page.dart and this document. No files removed or data
changes. Tests cover tapping either amber light or percent and the informational
passed indicator; tests/app launches/builds were not run per policy. Dart
formatting and whitespace checks passed. Implementation complete; manual visual
and functional verification pending; phase not applicable.

David: reload Flutter, inspect green/amber indicators immediately after names in
both wide table and narrow cards, including long wrapped names. Tap/click the
amber dot and percentage separately and confirm both open review. Pass an entry
and check green replaces amber/percent; edit it and check amber returns. Confirm
unknown confidence shows no invented percentage and archived entries can still
be restored. Optional: flutter test test/restaurant_review_indicator_test.dart
from flutter_app. Suggested commit: Show inline LED restaurant review status.
