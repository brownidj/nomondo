# Building BeneEde for TestFlight and uploading with Transporter

Updated 11 November 2026.

## Which tools do we need?

For BeneEde, use **Flutter to export an IPA → Apple Transporter to upload it →
App Store Connect/TestFlight to invite testers**. Shorebird is optional: it adds
Dart code-push updates, rather than being a requirement for TestFlight. Flutter
already supplies the iOS archive/export tooling.

The Shorebird CLI is installed on David's Mac, but BeneEde has not been registered
with Shorebird and has no `shorebird.yaml`. No Shorebird app, release or patch was
created by this documentation task. Optional setup is below if code push is wanted.
Do not copy Sudoku_01's Shorebird app ID: each application needs its own identity.

See the [Flutter iOS release guide](https://docs.flutter.dev/deployment/ios) and
[Shorebird concepts](https://docs.shorebird.dev/concepts/).

## Initial data and paired syncing

The build helper now packages the current restaurant catalogue for offline first
launch. Invited users can work on their local copy without reaching your Mac.
When they return to its network, the app syncs while active after a one-time
pairing-key entry. The key is kept in secure device storage, not in the shared IPA.
See [packaged data and pairing instructions](PACKAGED_CATALOGUE_AND_SYNC.md).

The helper regenerates `assets/catalogue/initial_catalogue.json` and supplies only
the public server URL via `data/catalogue_build.json`. `data/mobile_connection.json`
remains private to your own paired installation. You are the sole owner; invited
users do not need App Store Connect access.

## One-time Apple setup

1. Use your Apple Developer Program membership and sign into Xcode with the
   account that owns the app.
2. From `flutter_app`, open `ios/Runner.xcworkspace`. Select the **Runner target →
   Signing & Capabilities** and check the team and distribution signing setup.
3. The current iOS/macOS bundle ID is `org.topository.beneede`. Register/use that exact
   identifier in Apple Developer and when creating BeneEde in App Store Connect.
   If you choose a different identifier before first distribution, update the
   project and Apple registration together; this guide does not change it.
4. In **App Store Connect → Apps → + → New App**, create BeneEde for iOS with the
   matching bundle ID. Choose an internal SKU of your own. This is a separate app
   record from Sudoku_01.

These Apple records must exist before Transporter can deliver the app. Account
Holder, Admin, App Manager or Developer access can upload builds. See
[Apple's upload-build guidance](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).

## Build the IPA using Flutter

Run from the project root:

```zsh
cd '/Users/david/Library/Mobile Documents/com~apple~CloudDocs/PyCharm projects/BeneEde'
./scripts/run_tests.zsh
./scripts/build_testflight.zsh --build-name 0.1.0 --build-number 3
```

`3` is an example replacement for the older build 2. Choose a build number higher than the last one uploaded to
Apple. The helper requires you to supply it; it does not query Apple or silently
edit `pubspec.yaml`. The project currently declares `0.1.0+1`.

Preview the command without building or changing generated files:

```zsh
./scripts/build_testflight.zsh --build-name 0.1.0 --build-number 3 --dry-run
```

The helper refreshes the included catalogue/public URL, prepares the existing
clean build-cache location, then invokes:

```zsh
cd flutter_app
flutter build ipa --release --export-method app-store --build-name 0.1.0 --build-number 3 --dart-define-from-file=../data/catalogue_build.json
```

Outputs are beneath `flutter_app/build/ios/`:

- `archive/Runner.xcarchive`: the Xcode archive.
- `ipa/*.ipa`: the exported file to upload. Its actual filename depends on the
  product settings; the helper prints each freshly exported IPA.

An ordinary `flutter build ios --release` produces an `.app`, which is not the IPA
Transporter expects. Development/ad-hoc exports are also different from the
App Store export needed here. If archive creation succeeds but IPA export fails,
resolve signing/export settings and export again. The helper checks for a new IPA
so an old file is not mistaken for a successful export.

## Upload the IPA with Transporter

Transporter is installed on David's Mac. Otherwise obtain
[Transporter by Apple from the Mac App Store](https://apps.apple.com/app/transporter/id1450874784).

1. Open Transporter:

   ```zsh
   open -a Transporter
   ```

2. Sign in with the Apple Account that has upload access to the BeneEde app. If
   multiple providers/teams appear, choose the one that owns BeneEde.
3. Reveal the export folder in Finder from the project root:

   ```zsh
   open flutter_app/build/ios/ipa
   ```

4. Drag the **new `.ipa` file** onto Transporter, or select it through **Add App**.
   Check the displayed app identity, version and build number before delivery.
5. Click **Deliver**. Transporter validates and sends the package. Keep it open
   until the delivery finishes.
6. If it reports issues, open the issue details and fix errors before retrying.
   A failed upload is not a delivered build. Duplicate-build errors require a new
   build number and a rebuilt IPA.
7. Confirm the file appears in **Delivered**. Apple still needs to process it;
   delivery does not mean TestFlight review or public App Store approval.

Transporter does not build the app or send tester invitations. See Apple's
[Transporter overview](https://support.apple.com/en-gb/guide/transporter-app/apdac1c9a477/mac)
and [Deliver a package file](https://support.apple.com/en-gb/guide/transporter-app/apda158c5f7c/mac).

## Make the build available to your tester

In **App Store Connect → Apps → BeneEde → TestFlight**, wait for the matching build
to finish processing. Complete any compliance questions Apple displays and supply
beta test information/contact details. Create an external testing group and add
the build; external testing can require Beta App Review. Once approved, invite the
person by email. They install Apple's TestFlight app and accept the invitation.

Email invitations suit the intended small private audience. Uploading with
Transporter does not automatically invite anyone or publicly release the app.
TestFlight builds expire after 90 days, so publish replacement builds as needed.
[Apple's TestFlight workflow](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
describes processing, review and invitations.

## Optional: use Shorebird as in Sudoku_01

Use this if you decide you want Shorebird's code-push updates. No Dart updater
package is required just to initialize the project and create a Shorebird release.

From the Flutter project directory, perform the one-time account/project setup:

```zsh
cd '/Users/david/Library/Mobile Documents/com~apple~CloudDocs/PyCharm projects/BeneEde/flutter_app'
shorebird login
shorebird init --display-name BeneEde
```

`init` registers a new app with Shorebird, creates `shorebird.yaml`, and adds it to
Flutter assets in `pubspec.yaml`. Keep the real generated ID; it is not a password.
Do not use `--force` on an existing released app. See
[Shorebird initialization](https://docs.shorebird.dev/code-push/initialize/).

Then prepare the build location and create a release, using your intended version
and a new build number:

```zsh
cd '/Users/david/Library/Mobile Documents/com~apple~CloudDocs/PyCharm projects/BeneEde'
.venv/bin/python scripts/package_catalogue.py
./scripts/prepare_ios_build.zsh
cd flutter_app
shorebird release ios --flutter-version 3.47.1 --build-name 0.1.0 --build-number 3 --export-method app-store --dart-define-from-file=../data/catalogue_build.json
```

Flutter 3.47.1 is the version tested for this project. If Shorebird does not offer
that version, choose an available version deliberately and rerun the relevant
checks. The installed CLI's help supports these options; it reports that a newer
CLI is available, but no global CLI/SDK upgrade was performed here.

A Shorebird release uploads a baseline to **Shorebird**; it does not upload the IPA
to **Apple**. Send its exported IPA through Transporter using the same instructions
above. For later Dart-only fixes, Shorebird offers patches; native plugins,
permissions, icons/fonts/assets or engine changes need an appropriate new store
release. Code patches do not update the restaurant database or extend TestFlight's
90-day lifetime. The updater's network activity is separate from data syncing.
See [Shorebird releases](https://docs.shorebird.dev/code-push/release/) and
[Shorebird FAQ](https://docs.shorebird.dev/faq/).

## Work completed and checks

Added this guide and `scripts/build_testflight.zsh`, and linked it from both
READMEs. Shorebird initialization was unnecessary for the selected Flutter/
Transporter workflow. No app IDs, signing identities or version numbers were
changed; no IPA, Shorebird baseline or Apple upload was created in this task.

Checked installed Flutter/Shorebird help, zsh syntax, help/dry-run argument
handling and Git whitespace. The build helper itself was not used to create an
App Store IPA, so certificate/export and actual Transporter delivery remain to be
verified when you choose to distribute. Prior compiled release checks are recorded
in `docs/qa/2026-11-11-testing.md`; they are not proof of an App Store IPA export.
Phase: not applicable. Suggested commit:
`Document TestFlight IPA builds, Transporter uploads and optional Shorebird setup`.


## Bundle identity update — 11 November 2026

At David's request, iOS and macOS now use `org.topository.beneede`.
RunnerTests uses `org.topository.beneede.RunnerTests` in all configurations.
Changed the iOS/macOS Xcode project settings, macOS AppInfo.xcconfig and this
guide. No signing team, product name, app icon or catalogue data was changed.
Project plist syntax and identifier consistency were checked; no signing build,
Apple registration or upload was performed for this edit. Register the new ID
in Apple Developer and select the matching ID in App Store Connect before upload.

A changed bundle ID has a separate installed-app data container. Sync pending
changes from the old iPhone installation before replacing/removing it. The new
installation can download the catalogue from the Mac using the paired launcher.
Historical deployment notes mentioning the former ID describe the earlier builds.
Suggested commit: `Set BeneEde Apple bundle identifier to org.topository.beneede`.


## Transporter icon preview and replacement build

The build 2 IPA was inspected directly: its primary AppIcon settings and native
PNG artwork contain the BeneEde logo. The generic icon in Transporter's Active
list is therefore not evidence of a missing packaged app icon. The exact reason
for that preview is not established; confirm App Store Connect/TestFlight display
when Apple has processed the upload. Apple obtains app icons from the uploaded
build: https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon/.

That earlier IPA did not contain the starting catalogue. Use a newly exported
build (for example 0.1.0 build 3), remove the old Active entry in Transporter, add
the replacement IPA and verify its displayed build number before Deliver.
