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
