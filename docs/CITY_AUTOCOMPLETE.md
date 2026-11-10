# City autocomplete

Implemented 10 November 2026. Goal/acceptance: predictive completion in Add/Edit
after two typed characters, retaining manual entry. Show distinct region/country
labels for same-named cities. Choosing a result fills city, country and region.
A recognised entered country narrows suggestions; a UK constituent country
restricts to that constituent country. Do not select automatically or rename
existing restaurant cities. Failure must leave manual entry/save available.

The local index contains 171,818 places from the GeoNames cities1000 snapshot.
It includes populated places above the dataset threshold and specified
administrative seats, not every hamlet/suburb. Aliases and accent-insensitive
prefixes are searchable; exact matches precede population-ranked matches.
GET /api/cities?q=PREFIX&country=COUNTRY returns up to 12 distinct places from
the separate data/cities.sqlite3. Flutter debounces requests, ignores stale
responses and clears old options when country changes. Keyboard/touch work through
RawAutocomplete. No external API calls, key or per-search fee; the local Python
service must be available. Missing index/service leaves manual entry available.

Data: [GeoNames](https://www.geonames.org/),
[downloads](https://download.geonames.org/export/dump/),
[coverage/format](https://download.geonames.org/export/dump/readme.txt), licensed
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
BeneEde adapts the snapshot into a prefix index and normalises accents/country
labels. The source/build timestamp is retained in index metadata; the form shows
GeoNames attribution. Explicitly build/refresh with:

```zsh
.venv/bin/python city_index.py --download
```

Or use --archive PATH/cities1000.zip --admins PATH/admin1CodesASCII.txt. Rebuild
replaces only the index atomically; interrupted/empty builds preserve the old
index. Generated data/*.sqlite3 files are already ignored; rebuild after a fresh
checkout. Runtime never downloads automatically. No restaurant data was changed.

Created city_index.py, city_autocomplete_field.dart, Python/Flutter regression
tests and this document. Modified restaurant_server.py, restaurant_repository.dart,
edit_restaurant_dialog.dart, pyproject.toml and README.md. Existing Add modal test
mocks now handle independent city-completion GETs separately. No files removed.
Downloaded/built the initial dataset. Static Python syntax, Dart formatting and
whitespace checks passed; tests, app launches/builds and restaurant/API research
were not run. Implementation complete, functional verification pending; no phase.

David, macOS/Chrome/iOS (record date/results): restart service, reload Flutter,
open Add and Edit, type Lon, and compare UK/Canada suggestions. Set country first
to narrow matches. Check Sao/São and Bangalore/Bengaluru, choose by keyboard and
mouse/touch, and confirm country/region. Save an unlisted city manually. Check a
narrow screen with keyboard open. Optional targeted tests:

```zsh
.venv/bin/python -m unittest discover -s tests -p test_city_index.py
cd flutter_app
flutter test test/city_autocomplete_field_test.dart
```

Suggested commit: Add offline GeoNames city autocomplete to restaurant forms.
