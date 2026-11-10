# Running BeneEde in Chrome, macOS and iOS

Updated: 10 November 2026.

BeneEde has two parts: a Python service that reads the restaurant database, and
a Flutter interface that displays it. Start the service first and keep it running
while you use the interface. Browsing does not require an OpenAI API key.

## Current platform support

| Platform | Status in this checkout |
| --- | --- |
| Chrome on this Mac | Web target exists; use the launch commands below. |
| Native macOS | macOS target exists; use the launch commands below. |
| iOS simulator | No `flutter_app/ios/` directory yet. Complete the preparation section before attempting to run. |
| Physical iPhone or iPad | Needs an iOS target, signing and a data-service networking change. The current localhost service cannot be reached from a separate device. |

These instructions were checked against the current source and command-line
help. No platform builds or app launches were performed when writing this guide.
The iOS instructions describe preparation that has not yet been applied.

## 1. Open the project and check your tools

The project is currently located here:

```zsh
cd '/Users/david/Library/Mobile Documents/com~apple~CloudDocs/PyCharm projects/BeneEde'
```

All commands labelled **project root** below run from this directory, not from
`flutter_app`. If you move the project, substitute its new location.

In PyCharm, open **Terminal**. You will need two terminal tabs: one for the data
service and one for Flutter. The commands also work in macOS Terminal.

Check Flutter and available targets:

```zsh
flutter --version
flutter doctor -v
flutter devices
```

This Mac currently has Flutter 3.47.1, Dart 3.13.1 and Xcode 27.2. The project
requires Python 3.11 or later and Dart compatible with `^3.13.1`.

If `flutter` is not found, add the installed SDK to the current terminal's path:

```zsh
export PATH="/Users/david/development/flutter/bin:$PATH"
```

Chrome requires Google Chrome to be installed and detected by `flutter devices`.
Native Apple targets require a working Xcode toolchain; resolve relevant
`flutter doctor -v` issues before building. See the official
[web setup](https://docs.flutter.dev/platform-integration/web/setup) and
[macOS setup](https://docs.flutter.dev/platform-integration/macos/setup) guides.

## 2. Start the data service — terminal 1

From the **project root**:

```zsh
.venv/bin/python restaurant_server.py
```

The terminal should print:

```text
BeneEde data service: http://127.0.0.1:8765/api/restaurants
```

Leave this terminal running. The service reads `../data/restaurants.sqlite3` without
modifying it. It does not run restaurant research or incur OpenAI usage charges.

To check it, open
[the restaurant data endpoint](http://127.0.0.1:8765/api/restaurants) in a browser.
You should see JSON containing `restaurants` and `total`. This is the data feed;
the Flutter commands below launch the actual interface.

### If the environment or database is missing

The existing project already has both. Only use these setup steps if needed.
From the **project root**, create a missing environment and install dependencies:

```zsh
python3 -m venv .venv
.venv/bin/python -m pip install -e .
```

To create a missing database from the original note without API calls:

```zsh
.venv/bin/python main.py import-local
```

This produces provisional records; it does not research or verify them. Keep
`../data/restaurants.txt` as the original source. Do not replace an existing researched
database just to launch the interface.

## 3. Run in Chrome — terminal 2

In a **new terminal**, run:

```zsh
cd '/Users/david/Library/Mobile Documents/com~apple~CloudDocs/PyCharm projects/BeneEde/flutter_app'
flutter pub get
flutter run -d chrome
```

Flutter opens Chrome at the interface's development address. Keep the Python
service running in terminal 1. Search or filter the restaurant list, and use
**Refresh** to load changes made to the database by a separate research run.

For a predictable browser address, use this launch command instead:

```zsh
flutter run -d chrome --web-port=8080
```

The interface is then at [localhost:8080](http://localhost:8080); the data service
still uses port **8765**. These are separate services and need separate ports.
This configuration is for Chrome on this Mac, not a browser on your phone.

## 4. Run as a native macOS app — terminal 2

Keep terminal 1 running. In a **new terminal**:

```zsh
cd '/Users/david/Library/Mobile Documents/com~apple~CloudDocs/PyCharm projects/BeneEde/flutter_app'
flutter pub get
flutter run -d macos
```

A native **BeneEde** window should open. Its data comes from the same Python
service as the Chrome version. The project already includes the macOS network
client entitlement and local-network transport configuration.

### Optional: build a macOS application

From `flutter_app`:

```zsh
flutter build macos --release
open 'build/macos/Build/Products/Release/BeneEde.app'
```

The built application still needs the Python service running on this Mac. The
database and Python service are not bundled inside the application.

## 5. Prepare and run in the iOS simulator

**One-time project work is required:** there is currently no iOS runner. The
following steps add one; they are not an already-tested iOS launch procedure.

### Generate the iOS target

Save your current work before generating files. From `flutter_app`:

```zsh
flutter create --platforms=ios --project-name=beneede_app --org=au.com.beneede --no-pub .
flutter pub get
```

Review the generated changes with Git. Keep the existing `lib/` implementation
and dependencies. Set the iOS display name to **BeneEde** in the generated
`ios/Runner/Info.plist`.

The interface uses a local HTTP endpoint. Add this entry **inside the existing
top-level `<dict>`** in `ios/Runner/Info.plist`, merging it with any existing
`NSAppTransportSecurity` dictionary rather than creating duplicate keys:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

Use a local networking exception for development; keep a deployed service on
HTTPS. See Apple's
[NSAllowsLocalNetworking reference](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking).

### Start a simulator and launch

Use Xcode to install an iOS simulator runtime if none is installed. On this
Mac's Xcode 27, open **Device Hub**, choose an iPhone simulator and start it:

```zsh
open -a DeviceHub
```

On Xcode 26 or earlier, the application is called **Simulator** instead.
See Flutter's [iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup).

Start the Python service in terminal 1 as described earlier. In terminal 2,
from `flutter_app`, list devices:

```zsh
flutter devices
```

Copy the simulator's device ID. Replace `SIMULATOR_ID` below with that actual ID:

```zsh
flutter run -d SIMULATOR_ID --dart-define=RESTAURANT_API_URL=http://127.0.0.1:8765
```

The simulator uses the Mac-hosted service at the loopback address. Verify that
the restaurant list loads; native iOS behavior has not yet been checked here.

## 6. Running on a real iPhone or iPad

**The current project is not ready for this yet.** Installing the app alone
does not give the phone access to the restaurant data: `127.0.0.1` on an iPhone
means the iPhone itself, not this Mac.

After generating the iOS target, the remaining work is:

1. Configure a service endpoint reachable by the phone, such as an HTTPS endpoint
   or a deliberately configured LAN development endpoint. The existing Python
   server is hard-coded to `127.0.0.1` and has **no `--host` option**. A LAN option
   requires a code change; changing `RESTAURANT_API_URL` alone is insufficient.
2. For a LAN endpoint, keep the Mac and phone on a network where they can reach
   each other, allow the service through the Mac firewall, and add
   `NSLocalNetworkUsageDescription` to the iOS `Info.plist`. Use wording such as
   “BeneEde connects to your Mac to load your restaurant collection.” Configure
   the local HTTP transport policy as needed, or use HTTPS. Apple explains the
   permission in [Understanding local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy).
3. Open `ios/Runner.xcworkspace` in Xcode, select the **Runner** target and set
   **Signing & Capabilities** to your development team. Check the bundle ID is
   unique to this application. Connect and unlock the phone, trust the Mac and
   enable Developer Mode when prompted. Follow the official
   [iOS device setup instructions](https://docs.flutter.dev/platform-integration/ios/setup).
4. Run `flutter devices` and use the physical device's ID.

Only after the service is reachable, launch from `flutter_app` using the actual
device ID and actual service address:

```zsh
flutter run -d IPHONE_DEVICE_ID --dart-define=RESTAURANT_API_URL=https://YOUR_SERVICE_HOST
```

`IPHONE_DEVICE_ID` and `YOUR_SERVICE_HOST` are placeholders. The URL must point
to a running service implementing `/api/restaurants`; omit that suffix from
the define because the app adds it. For a configured LAN server, use its actual
scheme, Mac address and port instead. This command does not create or deploy
that service. The API address is compiled into the app; relaunch/rebuild after
changing it. A USB connection for installing the app does not by itself expose
the Python service to the phone.

## Stop, restart and troubleshoot

- **Stop the interface:** press `q` in its `flutter run` terminal, or Ctrl+C.
- **Stop the data service:** press Ctrl+C in terminal 1.
- **Restart:** start the service, then repeat your platform's `flutter run` command.
- **Refresh data:** use the interface's Refresh button. Hot reload reloads code;
  it is not a substitute for reloading restaurant data.

| Problem | What to check |
| --- | --- |
| `flutter: command not found` | Add the installed Flutter SDK to `PATH` in that terminal. |
| Chrome/macOS/simulator missing from `flutter devices` | Check `flutter doctor -v`; install the relevant browser/toolchain/runtime and start the simulator. |
| Interface opens but restaurant data fails to load | Keep the Python terminal running and check the JSON endpoint on the Mac. |
| “Database does not exist” | Start from the project root; confirm `../data/restaurants.sqlite3` exists, or use the missing-database steps above. |
| Port occupied | Startup replaces a verified older BeneEde service for this project/database. An unrelated or unverifiable listener is left running; close it yourself or choose another matching service/Flutter port below. |
| iOS target missing | Generate the iOS target first; there is no iOS runner in this checkout yet. |
| iPhone connects to itself or times out | Use a reachable service URL and complete the physical-device networking work above. |
| Native build fails | Read the first substantive build error and check Xcode/toolchain setup. Avoid replacing the database or deleting project files as a troubleshooting step. |

To use another service port, start this in terminal 1 from the **project root**:

```zsh
.venv/bin/python restaurant_server.py --port 8766
```

Then launch from `flutter_app`, matching the port:

```zsh
flutter run -d chrome --dart-define=RESTAURANT_API_URL=http://127.0.0.1:8766
```

Replace `chrome` with `macos` or the prepared simulator ID for those platforms.
For another database, add `--db '/absolute/path/restaurants.sqlite3'` to the
Python service command. The service's interface remains read-only.

### Automatic port recovery

Run `.venv/bin/python restaurant_server.py` as usual. Startup attempts the actual
socket bind first and allows immediate address reuse after shutdown. If the port
is busy, it uses psutil to identify a listener owned by the same user, executing
this exact Python script for the same database and port. Only that matching
service receives an interrupt; startup waits up to five seconds, then binds again.
A different program, another project's service or a service using another
database is left alone. There is no forced kill or silent switch to another port.
The error reports a next step if ownership cannot be verified or shutdown fails.

`psutil` is included in the project's Python dependencies. The current virtual
environment has been updated. Changed server startup, package metadata and this
guide; created `tests/test_restaurant_server_startup.py`. Python syntax and diff
whitespace checks passed. Tests were added but not run, and no application was
launched for verification, following the manual verification policy.

Manual verification: from the project root run
`.venv/bin/python -m unittest discover -s tests -p test_restaurant_server_startup.py -v`.
Start the service in one terminal and run the same command in a second terminal;
the previous service should stop and the new one should serve port 8765. Also
check that a non-BeneEde listener on a spare port is left untouched. Record date,
tester, environment and results. No commit was made; phase not applicable.
Suggested commit: `Recover occupied port from a verified previous restaurant service`.
