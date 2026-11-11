# Offline mobile catalogue and sync

Implemented 11 November 2026 for native iOS and Android. Desktop and browser
clients retain their existing server-backed behaviour.

## Goal and acceptance

Open, search, filter and read the catalogue without the Mac. Add, edit, review,
archive and delete locally, with changes surviving an app restart. Send pending
changes when the paired Mac is reachable, download its changes, and preserve both
versions if the same record has changed on both devices.

Acceptance requires first launch from the packaged catalogue, a cold restart in Airplane
Mode, local changes surviving another restart, successful reconnection, and a
conflict that can be inspected and resolved without silently overwriting data.
Implementation and deployment evidence are separate from manual acceptance.

## How it works

The phone keeps `beneede_catalogue.sqlite3` in the application's private database
location. The database stores the last Mac snapshot, review evidence and original
source notes, a persistent change queue, and resolved-conflict history. State and
queue are committed together in one SQLite transaction. Saves are acknowledged
only after that transaction completes. A local pending record is projected over
the Mac snapshot, so a download cannot erase an unsynced edit.

The database is scoped to the paired server URL. Pairing credentials are not
written to it. App updates preserve the database; deleting the app removes its
local storage. Sync pending changes or use the history copy button before
removing an installation. A new server URL selects a separate local catalogue.

A fresh mobile installation initializes from the packaged catalogue without the
Mac. An empty but valid packaged/downloaded catalogue is also supported. Existing
local copies and queued edits survive app updates; subsequent launches stay local.
Review modals use the downloaded evidence and identify it as saved evidence.
New local additions have no fetched source evidence. Offline city completion
uses city names in the local catalogue; the full GeoNames index stays on the Mac.
Maps, websites and telephone services still depend on the device's facilities.
Mobile OpenAI discovery remains disabled.

While the app is foregrounded, a timer checks every 15 seconds and syncs after
at least five seconds without pointer activity, only when the persisted change
flag indicates retryable work (or an initial/unfinished download is needed). A
clean catalogue makes no idle HTTP requests. It sends one queued mutation at
a time, then downloads a consistent snapshot. Pausing the app stops that timer;
resuming restarts it. Returning to Wi-Fi/Ethernet or foregrounding the app triggers
a single check for Mac-side changes, even if locally clean. Explicit Refresh/Sync
now is also available. Continuous clean-state polling remains disabled. iOS
suspended/terminated background sync is not promised.
Refresh and **Sync now** drain independent pending changes until complete,
blocked or disconnected. A failed attempt preserves the queue for a later retry.

The small status line opens sync details, shows outstanding changes and the last
download time, offers **Sync now**, and exposes conflicts. Local saves are
explicitly described as saved on this device until synced.

## Conflict and retry rules

- Edits, deletions and review decisions retain the revision originally edited.
  A changed Mac revision produces a visible conflict; it is never automatically
  overwritten. Later operations on that same record wait; other records can sync.
- New local venues have temporary negative IDs. The server's confirmed ID and
  revision are substituted into dependent queued operations after a successful
  addition. Only dependent operations following this device's confirmed saves
  are automatically rebased.
- Additions retain their original request ID, using the existing server receipt
  to prevent duplicate additions after a connection loss.
- A lost response to an edit/review/delete can conservatively produce a conflict
  on retry. It is retained for inspection rather than assumed successful.
- **Use Mac version** removes that record's queued changes after confirmation,
  preserving them in local conflict history. **Apply my changes** explicitly
  retries against the current Mac revision. Deleted Mac records and failed
  additions cannot be automatically rebased; their local details remain saved.
- Server validation failures are retained as sync issues, with local details
  available. They are not treated as successful remote saves.
- **Copy pending changes and conflict history** copies the retained details for
  recovery. Server-confirmed edits/reviews/deletions continue using the existing
  server audit history.

`GET /api/offline-catalogue` requires the same pairing authorization as existing
catalogue endpoints. A single read transaction collects restaurants and review
sources/history consistently. A version digest covers the complete snapshot,
including sources. Subsequent unchanged checks return only a version marker;
restaurant or evidence changes return a replacement snapshot. Missing server
records disappear locally unless a pending local operation needs preservation.
No database schema change or restaurant-data migration is needed on the Mac.

## Files and verification

Created `flutter_app/lib/data/mobile_catalogue.dart`,
`mobile_catalogue_store.dart`, `flutter_app/lib/widgets/mobile_sync_status.dart`,
`flutter_app/test/mobile_catalogue_sync_test.dart`, and this document.
Modified the authenticated client factory, catalogue screen, review dialog,
Python server/review reader, Python review tests, pubspec and lockfile, generated
plugin registration, and connection documentation. No source files removed and
no catalogue records intentionally changed. Build output may update the existing
cache symlink and generated native plugin files.

The new Dart tests cover offline reopen with pending edits/evidence, temporary
ID and revision remapping through add/edit/review/delete, conflict retention,
failed durable writes, and stale local forms. Python tests cover complete
snapshot/version behaviour and source-only changes and deletions.
Tests were written, not executed, following the project's manual test policy.
Dart formatting, Python AST syntax and whitespace checks are recorded below.

Focused checks for David:

```zsh
cd '/Users/david/Library/Mobile Documents/com~apple~CloudDocs/PyCharm projects/BeneEde'
.venv/bin/python -m unittest discover -s tests -p 'test_restaurant_reviews.py'
cd flutter_app
flutter test test/mobile_catalogue_sync_test.dart test/mobile_catalogue_layout_test.dart
```

Manual device acceptance (David, iOS; results pending):

1. Open once with the Mac reachable; wait for the saved/synced status.
2. Enable Airplane Mode, close and reopen. Search and open saved review evidence.
3. Add a disposable venue; edit it, review it, then close and reopen again.
   Check the pending count and saved values. Try a confirmed local deletion too.
4. Reconnect, use Sync now, and confirm the resulting records/review status on
   the Mac. Check that the queue reaches zero and deletions are propagated.
5. Edit a record offline and edit the same record on the Mac before reconnecting.
   Check that both versions are shown. Resolve once in favour of each side using
   disposable changes; verify that conflict history retains the local details.
6. Check iOS large text and Android separately. Android deployment and real
   interrupted-write/conflict scenarios remain unverified on devices.

Phase: not applicable. Suggested commit:
`Add offline mobile catalogue with durable queued sync and conflict handling`.

Implementation references: [Flutter SQLite persistence](https://docs.flutter.dev/cookbook/persistence/sqlite)
and [sqflite package documentation](https://pub.dev/packages/sqflite).

## Completion evidence — 11 November 2026

Dart formatting and `git diff --check` passed; Python AST parsing passed for the
server, review reader and amended Python tests. No automated tests or analyzer
were run. The final physical-iPhone release built successfully (Xcode 15.9s),
installed/launched wirelessly in 6.6s and the launcher exited successfully.
The phone then requested the offline endpoint using a previously saved version,
showing that database state survived the release replacement/relaunch. Initial
and subsequent version checks returned HTTP 200. A phone-originated review save
also returned HTTP 200 during live use and was followed by a snapshot update.
The assistant did not submit a restaurant mutation for verification.

Airplane Mode operation, interrupted writes, conflict choices, Android deployment
and large-text visual acceptance still require the manual checks above. Successful
builds and live connected syncs do not substitute for those scenarios.


## Change flag follow-up — 11 November 2026

Goal: stop idle network checks when there is no pending work. Added persisted
`has_changes` and `needs_download` flags. Local additions, edits, reviews and
deletions set the change flag atomically with the outbox. An acknowledged upload
sets the download marker; only a successful snapshot download/version confirmation
clears it. The change flag then clears when the outbox is empty. Existing database
state is reconciled from its outbox on load. Conflicts without retryable operations
wait for a decision rather than repeatedly polling. First downloads still retry.
Explicit Refresh/Sync now remain available for Mac-only changes.

Modified the mobile sync engine/status widget and added focused tests for zero
requests while clean, flag persistence/clearing, explicit refresh and failed
post-upload downloads. No data migrations, source removals or catalogue mutations
were needed. Automated tests/analyzer were not run. Formatting and whitespace
checks passed. Manual acceptance: observe no idle snapshot requests after a clean
sync; edit a disposable record, confirm one upload/download and flag clearing;
restart and verify pending work survives. Phase: not applicable. Suggested commit:
`Skip idle sync when the local catalogue has no pending changes`.

Deployment: release compiled successfully (Xcode 17.5s). Flutter's deployment
wrapper failed; a direct CoreDevice installation succeeded. Automatic launch
was then explicitly denied because the iPhone was locked. David must unlock
and open BeneEde. Idle-network observation on the running updated app remains
pending; no automated tests/analyzer were run.


## Layered verification completed — 11 November 2026

David subsequently authorized automated testing. The earlier “not run” notes
record the state at initial implementation, not the latest verification. See
[the layered testing report](qa/2026-11-11-testing.md) for the passing Python,
Flutter, real SQLite, visual, native iOS and release-package checks, plus the
remaining physical-device scenarios. Repeatable commands are in
[TESTING.md](TESTING.md).


## Packaged data and network-return follow-up

Initial data is now bundled with shared builds. New phones pair once using a key
kept in secure storage; network return/resume attempts synchronization with the
verified Mac. See [the current setup and build instructions](PACKAGED_CATALOGUE_AND_SYNC.md).
Historical initial-download/manual-refresh-only notes describe earlier revisions.
