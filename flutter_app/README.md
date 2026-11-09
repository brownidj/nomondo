# Nomondo restaurant browser

For the full launch guide, including iOS preparation, see
[Running Nomondo](../docs/RUNNING_THE_APP.md).

Flutter interface for `../data/restaurants.sqlite3`, targeting web and native
macOS. It displays restaurant name, city, country, cuisine, special dish and notes.
Search covers all six fields; country and **Needs review only** filters and a
refresh button are included. The review filter uses the database's `needs_review`
flag and combines with search and country selection. Its count shows all flagged
entries in the collection; the result count reflects the combined filters.
Full text wraps and can be selected/copied. Wide windows show six columns and
smaller windows show restaurant cards. Missing values display as “Not listed”.

## Alphabetical sorting

Use **Sort by** to choose restaurant name, city, country or cuisine, and the
**A–Z / Z–A** button to reverse the order. On wide screens, clicking one of those
four column headings selects it; clicking the active heading reverses the order.
The arrow marks the current direction. A newly selected field starts at A–Z.

Sorting ignores letter case and keeps missing values at the bottom in either
direction. Equal values are ordered by restaurant name, then the other location
and cuisine fields, then record ID, so duplicates remain predictable. Comparison
uses Unicode text order rather than language-specific collation. Search, country
and review filters combine with sorting; refresh retains the selected order.

## Run

In a terminal at the **repository root**, start the local data service:

```zsh
.venv/bin/python restaurant_server.py
```

In a second terminal at the **repository root**:

```zsh
cd flutter_app
flutter pub get
flutter run -d chrome
```

For a native Mac window, replace the final command with `flutter run -d macos`.
The macOS target requires Xcode and its normal Flutter desktop prerequisites.

The service reads the current SQLite database on every request without writing
to it. Click **Refresh** to see additional research as it completes. Duplicate
source entries remain separate rows. No OpenAI key is needed for browsing.

The service binds only to `127.0.0.1:8765` and allows browser origins on localhost.
This setup targets a browser on this Mac or the native macOS app.

For another local database or port:

```zsh
# Repository root, first terminal
.venv/bin/python restaurant_server.py --db /absolute/path/restaurants.sqlite3 --port 8766

# flutter_app, second terminal
flutter run -d chrome --dart-define=RESTAURANT_API_URL=http://127.0.0.1:8766
```

## Manual verification

Dependencies were resolved with `flutter pub get`; Dart formatting and a Python
syntax check passed. The application has not been launched or built; tests and
Flutter analysis were not run as part of implementation. Run `flutter analyze`
and then the app to verify:

- The displayed total matches the `restaurants` table.
- All six fields display actual data, including accents and long/multiline notes.
- Search finds matches in names, locations, cuisine, dishes and notes.
- Country filtering and clearing filters work together.
- Each of the four sort fields works in both directions; check the heading
  controls on a wide window and the Sort by control on a narrow window.
- Missing values stay last in both directions; filtering and refresh preserve
  the chosen sort field and direction.
- Needs review only excludes unflagged records and combines with other filters.
- Narrow and wide windows remain readable; text can be selected/copied.
- Refresh picks up new database values without changing source records.
- Stopping the service and refreshing shows an error while retaining loaded data.

Loading, empty, filtered-empty and error states are included. A failed refresh
retains the last successfully loaded list. No automated tests were added.

Review-filter check on 2026-11-09: the live local service returned 202 flagged
entries out of 490; enabling the filter in Chrome displayed 202 of 490, matching
SQLite. Dart formatting and the Python syntax check passed for this change.
