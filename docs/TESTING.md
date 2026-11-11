# BeneEde testing

The testing layers cover existing catalogue behaviour and offline sync. Tests use
fictional restaurants, temporary databases and mocked discovery. They do not
modify the live catalogue, send messages, or call the paid OpenAI API.

## Layers

| Layer | Location | Purpose |
|---|---|---|
| Python unit/regression | `tests/` | Importing, source retention, naming/countries, phone data, duplicate consolidation, audited edits/reviews/deletion, pairing and startup |
| Real HTTP integration | `tests/test_catalogue_http_integration.py` | Temporary real server + SQLite: two-client revision conflicts, idempotent additions, archive/restore, confirmed deletion, version checks and origin rejection |
| Flutter unit/widget | `flutter_app/test/` | Sorting, safe website URLs, dialogs and validation, autocomplete, tooltips, mobile policy, compact layouts and review indicators |
| Offline sync regression | `mobile_catalogue_sync_test.dart` | Dirty flags, no clean-state requests, offline reopen, dependent IDs/revisions, failed saves and stale forms |
| Real SQLite persistence | `mobile_catalogue_persistence_test.dart` | File close/reopen, separate client files, conflicts, interrupted responses, duplicate retries, deletion recovery, concurrent sync and corrupt snapshot rejection |
| Visual regression | `catalogue_golden_test.dart` + `test/goldens/` | Phone, 320px phone, 160% text and desktop screenshots using actual fonts, icons and branding |
| Native iOS integration | `flutter_app/integration_test/offline_catalogue_flow_test.dart` | Actual widgets and native sqflite plugin; offline edit/review/add, close/reopen storage, resolve a second-client conflict, delete and check the idle timer |
| Release packaging | `scripts/check_release_assets.py` | Actual web/macOS/iOS output: display names, native icon references/files, in-app logo and required fonts |
| Manual device QA | Report/checklist below | Radio/network behaviour, OS termination, native maps/browser, app-switcher icon and later second-phone installation |

The native iOS integration suite uses a controllable fake HTTP service while
exercising real SQLite and UI code. The Python HTTP suite separately exercises
actual server/SQLite/HTTP behaviour. Neither is a claim of a physical Wi-Fi test
between two phones. A second physical phone is not required for these automated
layers. Two separate client databases simulate concurrent edits.

Golden references are checked in; failure images are not approval to change a
baseline. Review intentional UI changes before accepting new reference images.
The font/icon loader and logo precache are necessary for meaningful captures;
placeholder test fonts and undecoded images must not become reference images.

## Commands

Run from the project root:

```zsh
./scripts/run_tests.zsh
```

This runs Python tests, Flutter analysis and Flutter tests with line coverage.
Logs go into a timestamped directory under `data/logs/`. The script stops on a
failure and preserves the failing command's status.

Include native integration using an already available simulator/device:

```zsh
/Users/david/development/flutter/bin/flutter devices
./scripts/run_tests.zsh --device 0964BE76-B88B-4875-8682-8C7C17609DBA
```

That ID is the iPhone 17 Pro/iOS 26.5 simulator on David's current Mac; substitute
a device ID from your inventory. The integration test uses a uniquely named
SQLite file, which it closes and deletes after the test. Prefer a simulator:
running an integration test on a physical phone installs an instrumented test
app; restore the normal paired release with `scripts/run_mobile.zsh` afterwards.

Include release builds and package checks:

```zsh
./scripts/run_tests.zsh --builds
./scripts/run_tests.zsh --device 0964BE76-B88B-4875-8682-8C7C17609DBA --builds
```

`--builds-only` repeats packaging checks after an asset-only change without
rerunning unrelated unit suites. Release builds target web, macOS and signed
iOS. They validate compilation/packaging; they do not publish an App Store build
or install the paired mobile configuration. Use the existing paired launcher
for your normal iPhone installation.

Targeted commands from `flutter_app`:

```zsh
flutter test test/mobile_catalogue_sync_test.dart test/mobile_catalogue_persistence_test.dart
flutter test test/catalogue_golden_test.dart
flutter test integration_test/offline_catalogue_flow_test.dart -d 0964BE76-B88B-4875-8682-8C7C17609DBA
```

Only when intentionally updating reviewed visual baselines:

```zsh
flutter test test/catalogue_golden_test.dart --update-goldens
```

Flutter dependencies include `integration_test` and the host-only
`sqflite_common_ffi` test dependency. SQLite factory/path injection enables real
file-based host tests without changing the default native database location.
The app's optional home widget lets UI fixtures use the actual application theme.

## Latest evidence

See [packaged catalogue and sync results](qa/2026-11-11-packaged-catalogue.md)
and the [earlier testing baseline](qa/2026-11-11-testing.md).
Manual testing remains the default for future work unless David explicitly
requests automated runs; this testing task supplied that authorization.

Implementation references: [Flutter testing layers](https://docs.flutter.dev/testing/overview),
[native integration testing](https://docs.flutter.dev/testing/integration-tests),
[SQLite testing guidance](https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/doc/testing.md).
