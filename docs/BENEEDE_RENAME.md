# BeneEde rename — 10 November 2026

The app display name and local project directories are now **BeneEde**.
The Python package/module is `beneede`; the Flutter package is `beneede_app`.

## Canonical directories

- Application, Git repository, database and Python environment: `/Users/david/Library/Mobile Documents/com~apple~CloudDocs/PyCharm projects/BeneEde`
- Codex workspace directory: `/Users/david/Documents/ChatGPT/BeneEde`

The former `Restaurants` directory at each location is a symbolic link to its
new sibling. These compatibility links keep the current PyCharm agent session,
registered interpreter and Codex workspace working. Retain the links while any
of these still use the old path.

## Files changed

- Renamed `nomondo.py` to `beneede.py` and `tests/test_nomondo.py` to `tests/test_beneede.py`; updated their imports and package metadata.
- Renamed the shared PyCharm module to `.idea/beneede.iml` and run configuration to `.idea/runConfigurations/BeneEde.xml`; set `.idea/.name` to BeneEde.
- Updated Flutter branding, web metadata, macOS product/scheme names, README files and launch instructions.
- Updated the local virtual environment and reinstalled this project as the editable `beneede` package; refreshed Flutter package metadata with `flutter pub get`.
- Created this document. Existing dish/notes/contact UI changes were retained.

The live PyCharm session may retain or regenerate its old `Restaurants` module
metadata until reopened. Its registered interpreter name also contains the old
path, which resolves through the compatibility link. Do not remove that link
until the interpreter and all active sessions have been moved to the new path.

The macOS bundle identifier remains `au.com.nomondo.nomondoApp` so installed app
identity stays consistent. The visible app name and executable are BeneEde.

## Data preservation

Before changing stored source paths, an SQLite backup was created at
`data/backups/restaurants-before-beneede-rename-20261110T015711Z.sqlite3`.
All 490 restaurant records and 556 API audit records were compared and preserved;
the original `data/restaurants.txt` contents are unchanged. Paths and derived
fingerprints for 501 source lines were migrated together so future imports
recognize the same source lines after the directory move.
The migration record is `data/backups/beneede-rename-20261110T015711Z.json`.

## Reopen and check manually

Wait for the existing PyCharm agent session to finish, then reopen the canonical
application directory above. The title should be BeneEde. If PyCharm retains an
old interpreter label, select the existing `.venv/bin/python` inside BeneEde.
Stop any existing server or Flutter run before restarting from the new directory.

Terminal 1:

```zsh
cd '/Users/david/Library/Mobile Documents/com~apple~CloudDocs/PyCharm projects/BeneEde'
.venv/bin/python restaurant_server.py
```

Terminal 2:

```zsh
cd '/Users/david/Library/Mobile Documents/com~apple~CloudDocs/PyCharm projects/BeneEde/flutter_app'
flutter run -d chrome
# Or use: flutter run -d macos
```

Confirm that the title is BeneEde, restaurant rows load, and cuisine/dish/notes
dialogs and Tel/Internet address columns still work. Record the date, platform,
tester and results when carrying out these manual checks. iOS preparation is
unchanged; see [Running the app](RUNNING_THE_APP.md).

Tests were renamed and their module import updated; no test cases were added.
No test suites, Flutter analysis, app launches or platform builds were run for
this rename, following the project's manual verification policy. Static syntax,
configuration and whitespace checks were performed, alongside the recorded
data-preservation checks. Runtime and visual verification remain manual.

## External names still outstanding

The GitHub repository and `origin` remain `brownidj/nomondo`: the available browser
session was not authenticated, so the remote repository could not be renamed.
The Codex sidebar project is still labelled Restaurants; the available project
tools do not support renaming its label or updating its workspace path. Its
existing path continues to resolve through the compatibility link.

No commit or push was made. Suggested commit message: `Rename Nomondo to BeneEde`.
This is an unphased change; local implementation is complete, with the external
names and manual runtime checks outstanding as described above.
