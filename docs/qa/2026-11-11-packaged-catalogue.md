# Packaged catalogue and sync verification — 11 November 2026

The app now starts from a packaged catalogue on a new installation, stores edits
locally, and synchronizes with the paired Mac when its local network becomes
available. Existing local databases and queued changes are preserved. Clean
clients do not repeatedly synchronize during idle time; network return or resume
can trigger one remote change check. Pairing credentials are entered once on the
recipient device and stored in Keychain, rather than distributed in the IPA.

## Automated results

- Python suite: 101 passed, including snapshot packaging and service readiness.
- Flutter suite: 69 passed; analyzer reported no issues.
- Native iOS integration: 2 passed, including SQLite persistence, simulated
  network-return synchronization and native Keychain persistence.
- Web, macOS and signed iOS release builds passed. Packaged asset checks passed.
- App Store IPA export: version 0.1.0, build 3, org.topository.beneede.
- Exported IPA verified to contain 502 initial restaurant records and AppIcon
  configuration. The packaged catalogue contains no pairing key.
- The original build 2 icon was extracted and visually verified as BeneEde.
  Transporter's generic preview cause remains unconfirmed.
- Replaced the separate default blank iOS launch images with BeneEde artwork;
  final build 3 export completed without the default-launch-image warning.

Logs are local under `data/logs/packaged-catalogue/`. The distinctly named export
is `data/releases/BeneEde-0.1.0-3.ipa`; both directories are ignored by Git.

## Limits

No upload, invitation or physical-device installation was performed for this
change. Real Wi-Fi transitions, a second iPhone, suspended/background execution,
and App Store Connect's processed icon display remain manual checks. iOS native
integration used a simulator and simulated transport/network events. No live
restaurant records were modified by the automated tests.

See [packaging, pairing and synchronization](../PACKAGED_CATALOGUE_AND_SYNC.md).

Suggested commit: `Package initial catalogue and sync local mobile changes on network return`.

## Pairing test repair after sync-modal changes

David's later run passed all 101 Python tests and Flutter analysis, but one of
70 Flutter tests failed. On the 390 × 844 test viewport, the longer sync help
text placed Pair with Mac below the visible scroll area. The test attempted a
tap without scrolling, so no pairing dialog opened and enterText failed with
`Bad state: No element`.

Updated `mobile_pairing_dialog_test.dart` to scroll the actual pairing button
into view, tap it, and assert the key field exists before entering text. No
production code change was required. Reran that test file: both tests passed,
including clipboard paste/show-key and successful pairing, plus sync failure
retention and automatic dismissal after successful sync. The full suite and
IPA build were not rerun for this test-only repair. Dependency update notices
in the supplied output are informational, not test failures.

Suggested commit: `Scroll pairing button into view before interacting in widget test`.
