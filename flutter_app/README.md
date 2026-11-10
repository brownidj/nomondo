# BeneEde restaurant browser

For the full launch guide, including iOS preparation, see
[Running BeneEde](../docs/RUNNING_THE_APP.md).

Flutter interface for `../data/restaurants.sqlite3`, targeting web and native
macOS. Its columns are restaurant name, city, country and cuisine. Phone and
website icons sit together beneath each restaurant name. Special dish and notes icons appear on a second line beneath
the cuisine preview, with their full text available in dialogs. Search covers
all these fields, including the underlying special dish and notes text;
country and **Needs review only** filters and a
refresh button are included. The review filter uses the database's `needs_review`
flag and combines with search and country selection. Its count shows all flagged
entries in the collection; the result count reflects the combined filters.
Full text wraps and can be selected/copied. Wide windows show six columns and
smaller windows show restaurant cards. Missing values display as “Not listed”.

## Cuisine previews

Cuisine values of more than three words show the first three words followed by
a clickable **…**. Press the ellipsis to open a scrollable dialog with the full,
selectable cuisine text and the restaurant name. Close dismisses the dialog.
The ellipsis flows inline with the preview and stays attached to its final word
when it wraps. The whole preview is clickable and keyboard accessible.
Values of three words or fewer remain fully visible; missing values show
“Not listed”. This applies to both desktop rows and compact cards. Searching
and sorting continue to use the complete cuisine value.

## Special dish and notes icons

Special dishes show **🍽️** and notes show **📝** when their fields contain
content. The icons sit together on a second line inside Cuisine; they no longer
have separate columns or card sections. Click an icon to open the full,
selectable text in a scrollable dialog labelled with the field and restaurant
name. Both table rows and compact cards use this behavior. Null, blank and
“not listed” values have no icon; placeholder matching ignores case and
surrounding whitespace. No second line is reserved when both icons are absent.

## Contact details

Press the phone or website icon to show its telephone number or internet address
in a tooltip. Telephone numbers use international format, including country codes
and extensions. Missing or “Not listed” contact values have no icon. These fields
are included in the read-only service response and search; no research is
triggered by displaying them.

After updating from the earlier interface, restart the Python service to load
the new response fields, then restart Flutter and refresh the list. An old
running service does not return contact fields and will show them as missing.

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
- The four columns show name, city, country and cuisine.
- Phone and website icons appear beneath each name in table and card views;
  pressing each shows the correct contact value in a tooltip. Missing/Not listed
  contacts have no icon. There are no separate contact columns or card fields.
- Populated special dish and notes icons sit together beneath Cuisine and open
  the correct full content. Their old columns/card sections are absent.
- Missing special dish/notes fields have no icon or empty second-line spacer.
- Search finds matches in names, locations, cuisine, dishes, notes and contacts.
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

## Bundled fonts

Noto Sans, CJK, Thai and monochrome emoji fonts are bundled and configured as
fallbacks. See [font assets and manual checks](assets/fonts/README.md). After
adding/updating fonts, stop Flutter and start it again to rebuild its asset bundle.

## Address tooltip

When an address is listed, a location-pin icon appears beneath the city name
in table rows and compact cards. Press it to open the restaurant in Maps;
hover on desktop or long-press on touch devices to display the address tooltip. Null, empty and “Not listed” addresses have no icon. Addresses are also
searchable and are included in the local service response.

For this change, the Python service, restaurant model and list widgets were
updated. No tests were added or run; no Flutter analysis, UI launch or platform
build was run. Dart formatting, Python syntax and whitespace checks were used.
Manually verify listed/missing addresses in wide and narrow views after reloading
Flutter. Record date, tester, platform and results. No commit was made; phase is
not applicable. Suggested commit: `Show address tooltip beneath the city name`.

## Opening maps

The address pin opens Apple Maps in native macOS/iOS apps (with an Apple Maps
web fallback), or Google Maps in a new browser tab on web and externally on
other native platforms. Name, full address, city and country identify the venue.
No map API key or location permission is required. Address tooltips remain
available on hover or long-press. See [implementation and manual checks](../docs/MAP_LINKS.md).

After adding `url_launcher`, fully stop and restart Flutter so its native plugin
is registered; hot reload alone is insufficient.
