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

Done when: manual browser/macOS checks confirm the requested fields, data access,
search, filtering, refresh and responsive layout. No automated tests added.

Suggested commit: `Add Flutter restaurant browser backed by local SQLite service`.
