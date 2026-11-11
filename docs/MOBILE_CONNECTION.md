# Paired mobile catalogue connection — 11 November 2026

Problem: the user's physical iPhone screenshot showed the app shell with a
catalogue connection error. Both Python binding and the Flutter default endpoint
were loopback-only. The phone was trying to reach itself, while server write
guards rejected non-localhost hosts. Goal: connect the physical phone to the same
Mac catalogue, preserving edit/review/manual-add and disabling remote AI discovery.

Implemented an explicit --lan service mode on port 8766, separate from desktop
localhost port 8765. A stable Mac .local hostname and random pairing token are
written to data/mobile_connection.json with mode 0600; that path is gitignored.
Only private peers presenting the token may use LAN endpoints. Existing origin,
host and revision guards remain, with Mac LAN hosts recognised. Public peers are
rejected, and remote research POSTs are denied even with a valid pairing token.
The health endpoint exposes a token fingerprint for local startup verification,
not the token. Proven same-script/user/database port recovery supports LAN mode.

The shared Flutter HTTP client adds pairing authorization only for the configured
catalogue origin, covering loading, saves/deletes, reviews, city suggestions and
website availability. Website/map launches do not receive the token. API secrets
are not included in Flutter. The iOS plist permits local HTTP hostnames and
explains local-network access. Mobile load errors now refer to the Mac/Wi-Fi.
The one-command scripts/run_mobile.zsh explicitly starts/prepares the service,
waits for the expected pairing fingerprint, prepares build output and runs Flutter
with the ignored private defines file. The Mac must stay awake/reachable; this is
a paired local development connection, not an offline catalogue or hosted service.

Acceptance/manual checks (David; record device/date/results): run
./scripts/run_mobile.zsh from the project root, select the phone and allow local
network access. Verify real rows/country/city options and confidence indicators,
save one deliberate edit, add manually, review/archive/restore, refresh and
confirm desktop sees the same changes. No automatic-details prompt or remote
OpenAI research is allowed. A missing/wrong pairing token must reject LAN reads
and writes; the normal local desktop flow must continue to work. Guest Wi-Fi
isolation/firewalls can still prevent device-to-Mac connectivity.

Created mobile_connection.py, scripts/prepare_mobile.py, scripts/run_mobile.zsh,
catalogue_client.dart, tests/test_mobile_connection.py and this document. Modified
restaurant_server.py, pyproject.toml, .gitignore, restaurant_repository.dart,
restaurant_website.dart, app_capabilities.dart, restaurant_list_page.dart,
ios/Runner/Info.plist and RUNNING_THE_APP.md. Created the ignored private pairing
configuration. No restaurant records were changed or source files removed.
Python/metadata parsing, Dart formatting, zsh/plist syntax and whitespace checks
passed. Regression tests were written for pairing persistence/permissions,
private/public peer authorization and remote-research denial. No tests, service
or app launches/builds, or external research API calls were run by the assistant;
the launcher performs those startup actions only when David runs it explicitly.
Implementation/setup files complete; device connectivity verification pending.
Phase: not applicable. Optional targeted test:

```zsh
.venv/bin/python -m unittest discover -s tests -p test_mobile_connection.py
```

Suggested commit: Connect mobile clients to a paired local-network catalogue service.

## Reopenable physical-device build — 11 November 2026

The mobile launcher now defaults to flutter run --release, retaining private
pairing defines, service startup and iCloud build preparation. Explicit --profile
or --debug overrides are supported without passing conflicting mode flags.
Release is the normal phone installation; debug depends on the debugger for
physical-iPhone launches. See [Flutter build modes](https://docs.flutter.dev/testing/build-modes)
and [the iOS home-screen launch note](https://api.flutter.dev/flutter/material/showDialog.html).
The catalogue still requires the Mac service; reopening the app does not require
Flutter's debugger. The background service continues after the launcher exits.

The user explicitly requested a profile/release build. Started the paired service
and a release build/install targeting the connected iPhone named David in this
session. The approved artwork was also applied to every native iOS AppIcon size
and the display name corrected; see APP_ICON.md. Modified run_mobile.zsh and the
icon/plist resources and documentation. No restaurant data or source files were
removed. No automated test suite was requested/run. Build outcome is recorded
below when available. Phase: not applicable.

For subsequent installations, from flutter_app:

```zsh
../scripts/run_mobile.zsh
```

Optional development mode: ../scripts/run_mobile.zsh --profile. Manual acceptance:
close the installed release app and reopen it from its new BeneEde icon with no
Flutter debugger attached; confirm the catalogue loads while the Mac service is
running. Suggested commit: Default paired mobile installations to release mode.

Build/deployment evidence, 11 November 2026: user-requested release build completed
successfully (Xcode 20.7s), installed and launched on the connected physical iPhone
(installation/launch 7.5s). Stopped the Flutter runner, then launched
com.example.beneedeApp with devicectl without attaching a Flutter debugger. Also
used --terminate-existing to force a cold standalone relaunch; CoreDevice reported
success with new process ID 67297. The Mac service recorded a phone-origin
GET /api/restaurants returning HTTP 200. The built release plist shows display
name BeneEde, AppIcon primary icon, local-network description and no debug-only
VM Bonjour service entry. No automatic test suite/analyzer was run. The user must
still visually confirm the home-screen artwork and tap-to-reopen experience;
the standalone process launch has been verified programmatically.

## Debug-launch regression and compact phone controls — 11 November 2026

The repeated VM timeout was traced to an active plain Flutter iPhone launch in
default debug mode. A separate macOS debug session was also active. Stopped only
the stalled phone launcher and reinstalled with the paired release launcher.
Generated iOS settings then matched both the Mac endpoint and the saved pairing
token. The Mac and configured .local health endpoint were reachable, the live
catalogue response contained 502 valid records, and the newly launched phone
recorded a successful HTTP 200 catalogue fetch. No restaurant data was changed.
For iPhone reinstalls, use run_mobile.zsh; plain flutter run may replace the paired
release with a default debug/loopback configuration again.

User-requested mobile layout: Countries/Cities now share a row; the sort selector
(Restaurant name by default), direction and Add share another row. The selector
flexes and ellipsises to fit. Needs review/Archived chips are hidden on mobile;
individual amber review controls remain available. Desktop layout is unchanged.
The plus explicitly sets its Text colour to white, fixing the black text shown
in the screenshot (IconButton foreground colour affects IconTheme, not its Text).

Modified restaurant_list_page.dart; created mobile_catalogue_layout_test.dart with
iOS/Android checks for row positions, hidden chips and white plus. Updated this
document. No source files removed or database changes. Dart formatting and
whitespace checks passed. The new test was written but not run. The previously
authorised release/deployment workflow was used to install the layout update;
build/deployment result is recorded below. Manual visual acceptance: two adjacent
location selectors, sort and Add together, no review/archive filter row, white plus,
and real catalogue results. Phase: not applicable. Suggested commit: Compact
mobile catalogue filters and fix white Add symbol.

Deployment result: the updated physical-iPhone release compiled successfully
(Xcode 14.8s), installed/launched in 1.569s and the non-resident launcher exited
successfully. No automated tests or analyzer run were performed. Visual checks
of the new rows on the device remain for David.

## Dense mobile records — 11 November 2026

Goal and acceptance: maximise visible records on iOS/Android, with telephone,
website and edit actions right-aligned beside the restaurant name. Show
`City: <city>` and `Country: <country>` together on the next row, followed by
cuisine. Keep map, review, telephone, website and editing interactions working.

Implemented mobile cards with 8px horizontal/6px vertical padding, no internal
spacers, a 3px gap between records, compact action buttons and a smaller pending
review control. Reduced mobile header/list gaps as well. Long values can still
wrap instead of losing information. Desktop presentation remains unchanged.
Mobile tablets also use these compact cards.

Modified `restaurant_list_page.dart` and `restaurant_review_indicator.dart`;
extended `mobile_catalogue_layout_test.dart` with a mocked catalogue checking
action positions, the shared location row and compact record height on iOS and
Android. Optional repository injection supports that test without a live server.
No files removed and no catalogue data changed. This documentation was updated.

Dart formatting and `git diff --check` passed. Automated tests and analysis were
not run. For focused verification from `flutter_app`, run:

```zsh
flutter test test/mobile_catalogue_layout_test.dart
```

Manual acceptance remains for David: inspect short and long names/cities on the
phone, confirm more cards fit, and check each action and the clickable city.
Large accessibility text can increase record height. Implementation complete;
visual acceptance pending. Phase: not applicable. Suggested commit:
`Compact mobile restaurant records and align actions beside names`.

The paired physical-iPhone release built successfully (Xcode 14.9s), installed
and launched in 1.994s. The launcher exited successfully. Device visual checks
remain pending; this deployment does not represent an automated test run.

## Offline mobile catalogue — 11 November 2026

Native mobile now uses a local SQLite snapshot and durable mutation queue.
The app now includes its starting catalogue. Keep the paired service running
for subsequent syncs; it is not needed for offline browsing or local edits.
A small sync status line exposes pending work, manual sync and conflicts.
The service includes the authenticated `/api/offline-catalogue` snapshot endpoint.
See [offline behaviour, conflict rules and manual checks](OFFLINE_MOBILE.md).


## Current bundle identifier — 11 November 2026

The iOS/macOS bundle identifier is now `org.topository.beneede`. Older deployment
notes above refer to the former identifier used for those historical builds.
New devicectl launches should target the new ID once that build is installed.
The new ID uses a separate app data container; sync old pending edits first.


## Shared build bootstrap and pairing

See [packaged catalogue and network-return sync](PACKAGED_CATALOGUE_AND_SYNC.md).
Shared builds include data/public URL, while invited phones enter the Mac pairing
key once. The key is saved securely on the phone and is never included in the
packaged snapshot or shared build defines. The updated service supplies the server
identity proof. The prepare helper waits for the new process, not an older listener.
