# Nomondo restaurant browser

Flutter interface for `../data/restaurants.sqlite3`, targeting web and native
macOS. It displays restaurant name, city, country, cuisine, special dish and notes.
Search covers all six fields; a country filter and refresh button are included.
Full text wraps and can be selected/copied. Wide windows show six columns and
smaller windows show restaurant cards. Missing values display as “Not listed”.

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
- Narrow and wide windows remain readable; text can be selected/copied.
- Refresh picks up new database values without changing source records.
- Stopping the service and refreshing shows an error while retaining loaded data.

Loading, empty, filtered-empty and error states are included. A failed refresh
retains the last successfully loaded list. No automated tests were added.
