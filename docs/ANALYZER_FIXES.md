# Flutter analyzer cleanup — 10 November 2026

Goal/scope: address the 30 diagnostics in David's pasted analyzer output without
changing behaviour. Added braces around all 27 reported multi-line if bodies;
removed the unnecessary confidence cast, unused _Value.prominent parameter and
redundant foundation import in the mobile-add test. _Value keeps its existing
14px/normal-weight appearance; restaurant names already use separate styling.

Modified lib/data/restaurant_repository.dart, lib/models/restaurant.dart,
lib/screens/restaurant_list_page.dart, lib/services/restaurant_website.dart,
lib/widgets/city_autocomplete_field.dart, lib/widgets/edit_restaurant_dialog.dart,
lib/widgets/review_restaurant_dialog.dart, test/mobile_restaurant_add_test.dart
and test/review_restaurant_dialog_test.dart (all under flutter_app). Created this
document. No removed files or data changes. Existing test formatting was updated;
no test cases were added and tests were not run.

All nine files passed dart format; git diff --check passed. Analyzer, tests,
app launches and platform builds were not run per project policy. Implementation
complete; analyzer confirmation pending David's rerun. Phase: not applicable.
Acceptance: rerunning the same command has none of the 30 reported diagnostics.

David, same Flutter environment (record rerun date/result):

```zsh
cd flutter_app
flutter analyze
```

Suggested commit: Fix reported Flutter analyzer warnings and brace lints.

## Generated widget test and iOS signing — 10 November 2026

Reported MyApp creation_with_non_type in test/widget_test.dart was the Flutter
template counter test. Replaced it with a BeneEdeApp browser smoke test checking
the real page and Add button. It does not require the catalogue service. Test
source was updated and formatted, but the test/analyzer was not run.

Inspected the existing Xcode build activity log, without launching a build:
~/Library/Developer/Xcode/DerivedData/Runner-buvlimlkgpaljwaosgykaxnhelbe/Logs/Build/
1E1E0180-7A08-40A2-A318-4A97FC75A13A.xcactivitylog.
The status-255 failure occurred in Prepare Flutter Framework, debug_unpack_ios:
codesign rejected build/ios/Debug-iphoneos/Flutter.framework/Flutter with
"resource fork, Finder information, or similar detritus not allowed".
Inspection confirmed FinderInfo on the generated framework and file-provider
metadata. The Flutter SDK cache had no FinderInfo/ResourceFork attributes;
it was not modified. Package update notices do not explain this signing error.

Created and executed scripts/prepare_ios_build.zsh as the repair. It preserves
generated outputs by moving flutter_app/build to
~/Library/Caches/BeneEde/flutter-build-20261110T134126968823Z, then leaves a build
symlink at the original location. This keeps new build products outside iCloud
sync without relocating the source project. Removed eight FinderInfo/resource-
fork attributes from generated outputs and checked none remained. Source data,
Flutter SDK, certificates, signing team and project signing settings unchanged.
If flutter clean removes the symlink, rerun this helper before the next build.
An existing build symlink outside the helper's cache area is left untouched.

Reference: [Apple QA1940](https://developer.apple.com/library/archive/qa/qa1940/_index.html).
The iCloud recurrence is also reported in the
[Flutter issue](https://github.com/flutter/flutter/issues/185395).
Those reports support the metadata diagnosis; device build success still needs
David's rerun. No dependency upgrades were required or attempted.

Files: modified flutter_app/test/widget_test.dart and this document; created
scripts/prepare_ios_build.zsh. No source files removed or catalogue changes.
Checks run: Dart format, zsh -n, embedded Python syntax, whitespace and generated
metadata cleanup checks. Tests/analyzer/app launches/platform builds not run per
policy. Implementation/repair complete; manual device verification pending;
phase not applicable. Suggested commit: Fix generated widget test and isolate
Flutter build output from iCloud metadata.

David, from flutter_app (record date/device/result):

```zsh
../scripts/prepare_ios_build.zsh
flutter analyze
flutter run
```

Choose the iPhone when prompted, or reuse the same device selector as before.
Acceptance: no MyApp analyzer error and no framework signing detritus error.
If another build error appears, retain its full output; no build success has yet
been verified. The earlier iOS preparation/networking instructions still apply.

## Narrow editor and repeated iOS failure — 10 November 2026

User's follow-up contains a 20px horizontal RenderFlex overflow on the 390px
editor, followed by widget-inspector errors explicitly raised while reporting
another failure. Replaced the fixed Delete/Cancel/Save row with responsive actions:
Delete remains left aligned; narrow/large-text layouts put Save/Cancel in a
separate right-aligned wrapping group. Wide layouts retain the single row.
Helper/error text can wrap over three lines. Existing edit dialog tests already
cover 390x844 and 1200x900 layouts and cancellation; no new tests were added.

The pasted output begins at +16 -10 and omits the first ten primary failures;
their causes cannot be established from the supplied tail. Requested the first
exception/full earlier text. This is separate from the visible overflow repair;
do not interpret this as all 11 failures being diagnosed or tests passing.

The newest saved Xcode activity log,
99E5CFAB-74D7-475D-A6FF-C399F9362885.xcactivitylog, again shows framework signing
detritus. Inspection found flutter_app/build was a normal iCloud folder again.
Ran the preparation helper: moved the new generated directory to
~/Library/Caches/BeneEde/flutter-build-20261110T135052724737Z, restored the symlink
and removed one FinderInfo attribute. Added the helper to the iOS shared scheme
before xcode_backend.sh prepare, so the required preparation also runs after a
clean/recreated build directory. XML/static inspection confirms this order.

Modified edit_restaurant_dialog.dart and the iOS shared Runner.xcscheme. The
related Cmd+Tab native change is in MainFlutterWindow.swift; see APP_ICON.md.
This document updated; no files removed or catalogue changes. No new tests.
Dart formatting, shell syntax, scheme XML and whitespace checks passed. Existing
logs/compiled icon were inspected; no analyzer/test suite/app launch/build was
run. Implementation complete for visible errors; functional verification and
earlier primary-failure diagnosis remain pending. Phase: not applicable.

David: rerun the targeted edit dialog test, then repeat the iPhone launch.
The scheme now prepares build output automatically. Record date/device/result:

```zsh
cd flutter_app
flutter test test/edit_restaurant_dialog_test.dart
```

Suggested commit: Make editor actions responsive and prepare iOS output before signing.

## Platform invariant failures — 10 November 2026

The supplied earlier output identifies nine failures with the same assertion:
"The value of a foundation debug variable was changed by the test."
add_restaurant_dialog_test.dart and contact_tooltip_test.dart set the platform
override in ordinary setUp and reset it in ordinary tearDown. Flutter's widget
binding checks foundation invariants before ordinary tearDown runs, so that
cleanup is too late. Confirmed the ordering from the installed Flutter SDK's
widget_tester.dart and binding.dart; no test execution was required to inspect it.

Replaced those global overrides with TargetPlatformVariant({TargetPlatform.macOS})
on all six Add tests and three tooltip tests. The variant restores its previous
platform in the widget-test callback's finally block before invariant checking.
Removed the now-unnecessary foundation imports. Test assertions and application
code unchanged; mobile tests retain their existing iOS/Android variants.

Modified the two existing test files and this document; no new/removed files,
test cases or data changes. Dart format and whitespace checks passed. Tests,
analyzer, app launches and builds not run per project policy. Implementation
complete; rerun confirmation pending; phase not applicable. The earlier missing
primary failures have now been identified, rather than remaining undiagnosed.

David: from flutter_app, rerun flutter test (or target the two test files) and
confirm all nine foundation-variable failures are gone. This also checks the
previous responsive editor fix. Record date and results. Suggested commit:
Use managed macOS platform variants in widget tests.
