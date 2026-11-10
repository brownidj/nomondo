# BeneEde app icon — 10 November 2026

The approved plate/globe artwork is used in the app header, macOS AppIcon asset
catalogue, web favicon, PWA icons and Apple touch icon. Canonical source:
`flutter_app/assets/beneede-icon.png` (1024px). A standalone macOS ICNS version is
`flutter_app/assets/beneede.icns`. Original generated artwork, prompt and size
exports remain in `flutter_app/assets/branding/beneede-icon-v1/`.

The Flutter header loads the declared PNG asset at 48 logical pixels with a
144px decode target. Seven macOS PNG sizes populate all ten 1x/2x catalogue slots.
All build configurations already select the AppIcon catalogue. Info.plist now
explicitly names AppIcon in CFBundleIconFile and CFBundleIconName, providing the
bundle identity used by Finder, the Dock and Cmd+Tab. Standard/maskable PWA icons
are 192/512px, the favicon is 32px and the touch icon is 180px. Web icon links have
a version query to refresh browser icon caches. The web description also uses
the current good-eats tagline.

Fully quit and restart the native app so its bundle icon is rebuilt:

```zsh
cd '/Users/david/Library/Mobile Documents/com~apple~CloudDocs/PyCharm projects/BeneEde/flutter_app'
flutter run -d macos
```

Hot reload does not replace the native app bundle icon. Cmd+Tab branding belongs
to the native app; running the site inside Chrome uses Chrome's application
identity. Restart/reload the web app for the header/favicon. If an already installed
web shortcut retains its cached icon, recreate the shortcut after refreshing.
No existing installed application bundle or system icon cache was modified here.

PNG sizes and JSON/plist references were checked statically. Dart formatting,
Flutter dependency resolution and whitespace checks passed. iconutil generated
an ICNS file (asset conversion only); no platform application builds, app launches,
Flutter analysis or test suites were run under the manual verification policy.
No tests were added for this asset replacement. Manually verify the header,
favicon, PWA shortcut and native Dock/Cmd+Tab appearance after restarting, recording
date, tester, platform and result.

Modified header/asset declarations, native/web icon resources and native/web icon
metadata; created the canonical PNG, ICNS, touch icon and this document. No data
or source records were changed. No commit/push was made. Phase: not applicable.
Suggested commit: `Apply BeneEde branding across app and platform icons`.
Reference: https://developer.apple.com/documentation/xcode/configuring-your-app-icon

## Native app-switcher follow-up — 10 November 2026

Inspected the running native BeneEde executable and its compiled AppIcon.icns:
the expected plate/globe image is already present. The app is running from the
earlier cache build location while flutter_app/build had been recreated, making
an old running bundle/cache identity a possible contributor. No system icon
caches were purged and no running app was stopped.

MainFlutterWindow.swift now explicitly loads the bundled AppIcon.icns and sets
NSApplication.shared.applicationIconImage during native window initialisation,
in addition to existing asset-catalogue/Info.plist configuration. Acceptance:
native Dock/Cmd+Tab show the supplied artwork after a complete Mac app restart;
hot reload cannot update Swift initialisation. Artwork/other platform resources
were not changed. No new files, tests, database changes or removed files. Native
build/app tests were not run; source, bundled image and whitespace were inspected.
Implementation complete; visual/native build verification pending; no phase.

David: quit the running native BeneEde fully with Cmd+Q, then from flutter_app:

```zsh
flutter run -d macos
```

Check the Dock and Cmd+Tab after launch and record the result. Suggested commit:
Set the bundled BeneEde native application icon explicitly at launch.

## iPhone/iPad branding — 11 November 2026

The generated iOS target still contained Flutter's default icons. Replaced all
15 distinct PNG files serving the 19 AppIcon catalogue slots with scaled copies
of assets/beneede-icon.png. The 1024px master is opaque; every generated size was
checked against Contents.json and PNG transparency metadata. No artwork was
redesigned or removed. AppIcon remains selected in Debug/Profile/Release. The iOS
display name is now BeneEde. A native rebuild/install is needed; hot reload cannot
update the home-screen icon. No icon caches or installed app data were deleted.

Modified ios/Runner/Assets.xcassets/AppIcon.appiconset PNGs, ios/Runner/Info.plist,
and this document. No new icon files or test cases were needed. Asset dimensions,
opacity, catalogue references, shell/plist syntax and whitespace were checked.
The user explicitly requested a profile/release build, so a release build and
installation on the connected physical iPhone were initiated in this follow-up;
the final build outcome is recorded in MOBILE_CONNECTION.md.
Manual acceptance: BeneEde artwork appears on the phone home screen and app
switcher after installation. Date/device/user visual confirmation still required.
Suggested commit: Apply approved BeneEde artwork to all native iOS icon sizes.

Release outcome: the new artwork was included in the successful physical-iPhone
release installation on 11 November 2026. The compiled bundle's primary icon is
AppIcon and its home-screen PNG resources are present; all 19 source slots have
correct dimensions and no alpha. Standalone release relaunch succeeded without
Flutter. Device visual confirmation of the displayed icon remains with David.
