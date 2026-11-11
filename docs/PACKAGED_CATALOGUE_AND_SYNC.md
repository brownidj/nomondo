# Packaged starting catalogue and network-return sync

Implemented 11 November 2026. You remain the sole owner/administrator; invited
users are clients of the same catalogue, not App Store Connect administrators.

## First launch and offline use

Mobile/TestFlight builds include a snapshot of the Mac catalogue, including
restaurant details, notes, ratings and saved review/source evidence. A fresh
installation copies that snapshot into its private SQLite database and opens
without contacting the Mac. The current snapshot contains 502 restaurant records
and is about 5 MB before packaging/compression.

The starting snapshot is used only for an uninitialized local catalogue. App
updates do not replace existing local copies or pending edits with a newer seed.
Offline additions, edits, review decisions, archival and deletions stay in the
persistent local queue. The owner's Mac catalogue is not changed while unreachable.
The existing revision/conflict workflow preserves both sides when needed.

## Returning to the Mac's network

While the app is active, Wi-Fi/Ethernet connection events and foreground resume
trigger a debounced sync attempt. Pending changes are sent, then the app fetches
the current catalogue/version. Even a clean client checks once on network return
or resume so it can receive changes made on the Mac while away. Afterwards a
clean catalogue makes no idle sync requests. Pending work keeps its dirty flag
until successful confirmation and download; failed or conflicting work is retained.

Wi-Fi availability is only a hint, not proof of being on the correct LAN. The app
uses the configured Mac's `.local` hostname and verifies a fresh challenge response
made with the pairing key before sending credentials or changes. Another server
with the same hostname cannot pass that check without knowing the key.

The Mac must be awake with the updated LAN service running. Ordinary mobile data
is not used for catalogue sync. OS network events can be delayed while suspended;
iOS background synchronization is not guaranteed. Reopen the app on the Mac's
network or press Sync now if necessary. A connection check that fails while there
is no pending work is retried on the next connection/resume/manual action, not
continually polled. This remains a private LAN HTTP service, not an internet host.

## Pair each invited phone once

The open sync details window now closes after a successful sync with no pending
changes or conflicts, including automatic sync and the sync after pairing. Errors
and conflicts leave it open. Opening an already-synced catalogue's details does
not close the window until another sync completes. Idle checks run every 15
seconds, require at least 5 seconds without interaction, and only run while the
app is in the foreground. A pending edit normally starts syncing after 5–20
seconds; returning to the Mac network uses a separate 2-second debounce.

Implementation verification: regression coverage was added to
`flutter_app/test/mobile_pairing_dialog_test.dart` for failure retention and
automatic completion. Tests and a replacement distribution build have not been
run for this UI change; verify on the iPhone after rebuilding.

On the Mac, start/update the service:

```zsh
cd '/Users/david/Library/Mobile Documents/com~apple~CloudDocs/PyCharm projects/BeneEde'
.venv/bin/python scripts/prepare_mobile.py
./scripts/copy_pairing_key.zsh
```

The second command copies the existing pairing key to the Mac clipboard without
printing it in the terminal. Give it only to the invited user. While on the Mac's
network, they open BeneEde's small sync status line, press **Pair with Mac**, paste
the key and press **Pair**. The app verifies the Mac, saves the key in iOS Keychain
(Android uses secure platform storage), and syncs. Future connections sync without
re-entering the key. A failed pairing attempt does not replace a saved key.

The pairing dialog provides **Paste key** and **Show key / Hide key** controls.
Copy the entire key to the iPhone clipboard, then press Paste key; surrounding
spaces and line breaks are trimmed. Do not type the long key by hand. The key
remains hidden by default and is sent only when Pair is pressed. These controls
require a new app build; existing build 3 users can touch and hold the field and
choose Paste using the standard iOS menu.

This is a shared catalogue-access key for trusted clients, not an Apple Account
password or a separate ownership role. It is not a per-device revocation system.
The iOS item is device-only and the app's own keychain group is configured. No
location/SSID permission, App Group or access to another app's keychain is needed.
Existing owner builds with compiled private pairing configuration remain supported.

## Build and refresh the included data

The normal helpers refresh the snapshot before building:

```zsh
./scripts/build_testflight.zsh --build-name 0.1.0 --build-number 3
./scripts/run_mobile.zsh -d 00008110-001E48A02187601E --release --no-resident
```

Build 3 is an example replacement for the previously exported build 2. Use the
next unused number for subsequent uploads. The TestFlight helper embeds only the
public server URL from `data/catalogue_build.json`; it does not embed the pairing
key. The personal run_mobile helper retains its owner pairing configuration.

For another build workflow, run this first and pass the public defines file:

```zsh
.venv/bin/python scripts/package_catalogue.py
cd flutter_app
flutter build ipa --release --export-method app-store --build-number 3 --dart-define-from-file=../data/catalogue_build.json
```

The package generator reads SQLite in a consistent read-only transaction and
atomically writes `flutter_app/assets/catalogue/initial_catalogue.json` plus the
allowlisted public configuration. Generated snapshots/configuration are ignored
by Git; the actual app bundle contains the data. Anyone given the app can read
that included catalogue and its notes/evidence. Review the dataset before sharing.
The packaging script never changes restaurant records or exports pairing keys.

## Verification and limits

Added tests cover offline first launch from the seed, no accidental reseeding of
existing edits, automatic connection-return sync, clean-state quietness, server
identity proof, credential isolation, pairing UI error/success paths, read-only
packaging, native SQLite and native Keychain persistence. The owner service startup
helper now verifies the new server process ID, avoiding a race where the previous
service could be mistaken for the just-started version.

Tests and compiled-package checks are recorded in the latest QA report. No second
physical iPhone was available. Real Wi-Fi transitions, actual radio disconnection
and a new invited user's installation still need device acceptance; simulated
network/transport changes are not claimed as physical network tests.

Scope: mobile bootstrap/reconnection/pairing and associated build/docs/tests.
Existing server audits and conflict semantics are retained. No App Store delivery,
invitation or Shorebird publication was performed. Phase: not applicable. Suggested
commit: `Bundle the initial catalogue and sync paired devices on network return`.
