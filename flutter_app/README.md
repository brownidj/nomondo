# BeneEde restaurant browser

For the full launch guide, including iOS preparation, see
[Running BeneEde](../docs/RUNNING_THE_APP.md).

Flutter interface for `../data/restaurants.sqlite3`, targeting web and native
macOS. Its columns are restaurant name, city, country and cuisine. Phone and
website icons sit together beneath each restaurant name. Clicking cuisine opens its full text together with special dishes and notes in one dialog. Search covers
all these fields, including the underlying special dish and notes text;
country, city and **Needs review only** filters and a
refresh button are included. The review filter uses the database's `needs_review`
flag and combines with search and country selection. Its count shows all flagged
entries in the collection; the result count reflects the combined filters.
Full text wraps and can be selected/copied. Wide windows show six columns and
smaller windows show restaurant cards. Missing values display as “Not listed”.

## Cuisine previews

Cuisine values of more than three words show the first three words followed by
a clickable **…**. Press cuisine or the ellipsis to open a scrollable dialog with
the full cuisine, special dishes and notes, labelled with the restaurant name.
Close dismisses the dialog.
The ellipsis flows inline with the preview and stays attached to its final word
when it wraps. The whole preview is clickable and keyboard accessible.
Values of three words or fewer remain fully visible; missing values show
“Not listed”. This applies to both desktop rows and compact cards. Searching
and sorting continue to use the complete cuisine value.

## Combined cuisine details

Every cuisine value, including short values and Not listed, is clickable. Its
hover/long-press tooltip says "Click to see cuisine, special dishes and notes".
The modal shows full selectable cuisine first, then 🍽️ Special dishes and their
content, then 📝 Notes and their content. Null, blank and Not listed dish/note
fields are omitted. Icons appear only within this modal, with no second row or
separate dish/note buttons in table rows or compact cards. Missing cuisine can
still be clicked to access any saved notes/dishes. Search/sort use the full values.

Updated 10 November 2026: created cuisine_details.dart and cuisine_details_test.dart;
modified restaurant_list_page.dart and this document. No removed files or data
changes. Interaction regressions cover short/missing cuisine, combined content,
icon placement, omitted placeholders and Close. Dart formatting and whitespace
checks passed; tests/app launches/builds were not run per policy. Implementation
complete; manual verification pending; phase not applicable. David: reload
Flutter, hover/long-press short and long cuisine, click each, verify section order
and complete content, test missing fields and long scrolling notes, and Close.
Optional: flutter test test/cuisine_details_test.dart from flutter_app.
Suggested commit: Combine cuisine dishes and notes in one details modal.

## Contact details

Press the phone icon to show its number; press the website icon to open its page.
Hover or long-press the website icon to show its address. A failed launch or a
failed reachability check turns the website icon red. Telephone numbers use international format, including country codes
and extensions. Missing or “Not listed” contact values have no icon. These fields
are included in the service response and search; no research is
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
- Cuisine opens one modal with full cuisine, then special dishes and notes with
  their icons/content. No separate icons appear in list rows or cards.
- Missing dish/notes fields have no modal section or empty list-row spacer.
- Search finds matches in names, locations, cuisine, dishes, notes and contacts.
- Country and city filtering and clearing filters work together.
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

## City map link

The city name is clickable in table rows and compact cards. Hover or long-press
shows exactly "Click to show map and address". Clicking/tapping opens the venue
in Maps with its saved address; no location icon or separate address display is
shown. If the address is missing, the map searches by name, city and country.
A missing city remains plain "Not listed". Addresses remain searchable and are
included in the local service response.

Updated 10 November 2026: restaurant_list_page.dart, restaurant_maps.dart and this
document. No new/removed files, database changes or tests added/run. Dart format
and whitespace checks passed; no Flutter analysis, app launch or platform build.
Implementation complete; manual verification pending; phase not applicable.
David: reload Flutter, verify the exact tooltip on desktop/touch, click a city
with an address and one without, and inspect the destination in Maps. Check wide
table and narrow cards. Record date/platform/results. Suggested commit:
Open restaurant maps from city names.

## Opening maps

The city link opens Apple Maps in native macOS/iOS apps (with an Apple Maps
web fallback), or Google Maps in a new browser tab on web and externally on
other native platforms. Name, full address, city and country identify the venue.
No map API key or location permission is required. The city tooltip explains the
action. See [implementation and manual checks](../docs/MAP_LINKS.md), with the
current city-link interaction replacing the earlier address-pin control.

After adding `url_launcher`, fully stop and restart Flutter so its native plugin
is registered; hot reload alone is insufficient.

Website checks run only after a press, through the local Python service; they do
not check hundreds of websites on startup. A red icon means unavailable at the
last check. Login/anti-bot responses and checker failures are inconclusive and
leave the icon neutral. Reloading the list may clear session-only check results.
A server check cannot confirm the final rendering of a separate browser tab.
Restart the Python service for the website-status endpoint, then reload Flutter.
See [website checks](../docs/WEBSITE_LINKS.md) for manual verification.

## Cities filter — 10 November 2026

Filter order is Search, Countries, Cities. Cities come from the loaded catalogue,
are deduplicated without case differences and sorted alphabetically. Blank and
Not listed locations are excluded. Selecting a country restricts the city options;
a city outside the new country is cleared. All cities removes just the city filter.
Search, country, city, review filtering and sorting combine. Refresh retains valid
selections and clears options no longer in the catalogue. Filters stack vertically
on smaller windows to keep search and dropdowns usable.

Modified the restaurant list screen and this document. No files/tests were created
or removed. Dart formatting and whitespace checks passed; no tests, app launch,
Flutter analysis or platform build was run under the manual verification policy.
Reload Flutter and check a city alone, country then city, changing countries,
All cities, combined search/review filters and narrow-window layout. Record date,
tester, platform and results. No commit was made; phase not applicable. Suggested
commit: `Add catalogue-based city filtering beside countries`.

## macOS contact tooltips — 10 November 2026

Phone, website and address tooltips now use a shared ContactTooltip wrapper with
explicit mouse enter/movement handling after 300 ms, touch long-press, and a dark
background with readable white text. Phone clicks still explicitly show the
number; website/map clicks still open their destinations. Hover timers are
cancelled when the pointer leaves or the widget is disposed. Exact native failure
cause is not confirmed; default Flutter hover handling is documented as supported
on macOS, so this is an explicit handling/styling change rather than an assertion
that manual trigger mode inherently disables hover.

Created `lib/widgets/contact_tooltip.dart` and `test/contact_tooltip_test.dart`;
modified the list widget and this document. Dart formatting and whitespace checks
passed. Widget tests cover macOS hover, phone press and website action dispatch,
but were not run; no app launch, Flutter analysis or platform build was run under
the project manual verification policy.

Restart/reload the native macOS app and hover over each contact icon, then check
a phone press and website/map actions. Confirm tooltip text is readable near
window edges, and moving away dismisses it. Record date, tester, platform and
results. Run `flutter test test/contact_tooltip_test.dart` manually from
`flutter_app` for the focused tests. Runtime acceptance remains outstanding.
No commit was made; phase not applicable. Suggested commit:
`Make contact tooltips explicitly respond to desktop hover`.

## Special-dish and notes tooltips

These icons now show their actual full field content on hover/long-press, using
the same tooltip styling and timing as contact details. Pressing still opens the
full-content dialog. Blank/Not listed values remain hidden, in both table/card
views. Only the list widget and this documentation changed; no data changed.
Dart formatting and whitespace checks passed. No tests were added or run, and no
app launch, Flutter analysis or platform build was performed. Reload Flutter and
manually hover both icons, then confirm their dialogs still open. Phase: not
applicable. Suggested commit: `Show dish and notes content directly in tooltips`.

## Add restaurant

The right-aligned Add restaurant button opens the same compact form layout as
Edit. Enter name and city, or an internet address on its own. If only those are supplied, choose Yes to
research missing information or No to add manually. Providing a website starts
website lookup. Review lookup results, including all discovered city branches,
then press Add again to save the batch. Blank fields remain blank when no reliable
source is found; existing catalogue branches are not duplicated or overwritten.

The Python service needs OPENAI_API_KEY for name/city web research or optional
interpretation of unstructured website text. Website JSON-LD extraction and
manual entry do not require AI. API usage may incur charges. The key stays in the
service environment. Restart the Python service and reload Flutter after updating.
See [implementation and manual verification](../docs/ADDING_RESTAURANTS.md).


## TestFlight and Transporter

See [the distribution guide](../docs/TESTFLIGHT_AND_TRANSPORTER.md) for the local
IPA build helper, Apple Transporter upload steps, TestFlight invitations and
optional Shorebird initialization. Shorebird is not required for TestFlight.
