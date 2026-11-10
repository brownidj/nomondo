# Restaurant list interface

Goal: provide a Dart/Flutter interface to the existing SQLite restaurant data.

Scope: web and native macOS list with the six requested content fields:
restaurant name, city, country, cuisine, special dish and notes. Include search,
country filtering, manual refresh and responsive layouts. No restaurant editing,
new research calls, database migrations, or changes to the research process.

Tasks: scaffold Flutter; add model/repository/list screen; add a local read-only
Python JSON endpoint; document setup and manual verification.

Acceptance criteria:

- Read actual SQLite data, preserving duplicates and accents.
- Show all six requested fields with full wrapped text and explicit missing values.
- Display a six-column desktop list and cards at narrower widths.
- Search all displayed fields and filter by country; clearing filters restores rows.
- Refresh from the current database; show loading, empty and recoverable error states.
- Keep database access read-only and credentials out of the Flutter app.
- Keep the data service bound to localhost; enable local macOS network access.

Implementation status: implemented; manual verification pending. Platform files
were generated with `flutter create --platforms=web,macos --no-pub --empty`.

Verification on 2026-11-09 (Codex): dependencies resolved with `flutter pub get`,
Dart formatting parsed all four Dart files, and `py_compile` passed for the
Python data service. No application launches, platform builds, tests or Flutter
analysis run. Follow `flutter_app/README.md` for commands and the manual checklist.
Record tester, date, environment and results when those checks are performed.

## Alphabetical sorting — 9 November 2026

Goal: sort the visible restaurant collection by restaurant name, city, country
or cuisine, in ascending or descending alphabetical order.

Scope and tasks: add a shared comparator, a Sort by selector and direction
button for every window width, and clickable headings for the four supported
desktop columns. Apply sorting after all existing filters and retain sort state
across refresh. No database or service changes are required.

Acceptance and done-when conditions:

- Restaurant name A–Z is the initial order.
- Choosing another field starts at A–Z; the direction control and repeated
  clicks on the active heading toggle A–Z / Z–A consistently.
- Comparison ignores letter case; missing values remain last in both directions.
- Equal groups have a deterministic order, retaining separate duplicate records.
- Search, country and Needs review filters still work with every sort option.
- Refresh retains the sort selection; both table and card layouts use that order.
- Manual verification in Chrome or macOS confirms the controls, ordering and
  responsive layout, with the tester, environment, date and results recorded.

Implementation status: implemented. Verification status: source review and Dart
formatting only; no tests, Flutter analysis, app launches or builds run by Codex.
Manual verification remains pending under PROGRAMMING_CRITERIA.md section 4.

Suggested focused commands, from `flutter_app`:

```zsh
flutter analyze lib/models/restaurant_sort.dart lib/screens/restaurant_list_page.dart
flutter run -d chrome
```

Suggested commit: `Add alphabetical sorting to the restaurant collection`.

Done when: manual browser/macOS checks confirm the requested fields, data access,
search, filtering, refresh and responsive layout. No automated tests added.

Suggested commit: `Add Flutter restaurant browser backed by local SQLite service`.

## Review filter

Added `needs_review` to the read-only response and Dart model. A filter chip
restricts the list to flagged records while retaining the existing search and
country conditions; clearing filters resets all three. An explicit shared scroll
controller fixes a desktop scrollbar assertion exposed during the live refresh.

Verification on 2026-11-09 (Codex): Dart formatting and Python syntax check passed;
the service was restarted and Flutter hot-restarted. The visible Chrome app's
review-only selection displayed 202 of 490 restaurants, matching SQLite and the
API. Left the filter enabled for review. No new automated tests or Flutter analysis
were run for this change.

## Cuisine previews — 10 November 2026

Goal and scope: shorten cuisine values longer than three whitespace-separated
words in both table rows and compact cards. Show the first three words and a
clickable ellipsis. Reuse a single cuisine widget across both layouts.

Acceptance: values of zero to three words keep their existing display; longer
values show three words plus **…**. Activating the ellipsis opens a scrollable
modal containing the complete selectable cuisine text and restaurant name.
Close dismisses it. Search and sorting continue to use the original full value.
The preview and ellipsis share one text layout and baseline, with no separate
icon-button padding. A word joiner prevents the ellipsis wrapping onto a line by
itself. The whole preview opens the dialog using pointer or keyboard activation.

Implementation complete; manual verification pending. Check exactly three words,
four or more words, repeated spaces/newlines and missing cuisine in wide and
narrow layouts. No tests added or run, Flutter analysis, builds or app launches.
Also check that ellipses follow the third word at narrow column widths and
increased text sizes, and that keyboard focus can activate the preview.
Formatting and diff whitespace checks are the only automated checks for this
change, following the project's manual-verification policy.

Suggested commit: `Show cuisine previews with an ellipsis detail dialog`.

## Special dish and notes icons — 10 November 2026

Goal and scope: replace populated special dish and notes display values with
distinct clickable icons (🍽️ and 📝) in both rows and cards. Reuse the cuisine
dialog presentation for the complete selectable content.

Acceptance: null, blank and case-insensitive, trimmed “not listed” values have
no icon and show “Not listed”. Populated fields show the appropriate icon.
Activating it by pointer or keyboard opens the correct full content, field label
and restaurant name. Close dismisses the dialog. Cuisine previews and searching
the complete special dish and notes text continue to work.

Implementation complete; manual verification pending. Check populated, missing,
blank and mixed-case placeholder values in wide and narrow layouts, opening and
closing each type of dialog. No tests added or run, analysis, builds or app
launches. Dart formatting and diff whitespace checks only.

Suggested commit: `Show detail icons for populated special dishes and notes`.

## Cuisine detail row and contacts — 10 November 2026

Goal: place special dish and notes icons on a second line within Cuisine and
replace their separate columns with Tel and Internet address. Apply the same
grouping to compact cards.

Scope and tasks: reuse the existing preview and detail dialogs; omit absent
icons and unused spacing; expose the stored `telephone` and `internet_link`
through the read-only endpoint and Dart model; include contact text in search.
The earlier six-field layout and separate detail sections are superseded.

Acceptance: six desktop columns show name, city, country, cuisine, Tel and
Internet address. Available dish/notes icons share a line beneath cuisine and
open their own full content. Neither icon appears for null, blank or trimmed,
case-insensitive “not listed”. No second line is reserved when both are absent.
Contact fields show their stored text or “Not listed”; telephone formatting is
preserved. Cuisine sorting, truncation and full-content dialogs still work.

Implementation complete; manual verification pending. No tests added or run,
Flutter analysis, app launches or builds. Checks: Dart formatting, Python AST
parsing and diff whitespace. Restart the Python service before checking contacts
and hot-restart Flutter. Verify both wide rows and compact cards, absent/present
icon combinations, contact values, search and all four sort fields.

Suggested commit: `Group cuisine detail icons and display restaurant contacts`.
