# Editing restaurants — 10 November 2026

Goal: an edit icon after the website icon opens a compact modal and saves user
changes without discarding existing restaurant/source information. The icon is
always available in both desktop rows and compact cards. Blank contact fields do
not hide the editor. The modal uses two columns where space permits, scrolls on
small screens, and keeps less-used fields under More details.

Main fields: restaurant name, city, country, address, telephone, website, cuisine,
special dishes and notes. More details: region, venue type, historical rankings,
personal numeric rating and venue status. IDs, provenance, API audit metadata,
confidence, review flags and consolidation snapshots are not editable. Name is
required; optional fields can deliberately be cleared. Ratings must be finite and
non-negative; website values must be HTTP(S), with HTTPS added to bare domains.
Phone changes use the existing international formatter. Addresses are saved as
entered: no automatic country suffix is added.

## Save behaviour and preservation

The editor submits only changed fields using PATCH /api/restaurants/ID. The local
server validates a strict field allowlist and a revision of the entire record.
A concurrent change returns 409 and leaves the form open with an instruction to
cancel, refresh and reopen. Failed saves keep typed values in the modal. Save and
Cancel are disabled during a save, and dismissal cannot interrupt an in-flight
save. Cancel/no changes performs no write. A lost response can leave the result
uncertain; a retry is protected by the same revision check.

Each successful edit and a full before/after snapshot are committed atomically in
restaurant_edit_history, including changed field names and timestamp. IDs, source
lines, source links, ratings not explicitly changed, evidence and consolidation
history stay intact. The entire original row is retained in edit history even
when an optional field is deliberately cleared. This is edit history rather
than destructive replacement of previous data. No catalogue records were edited
as part of implementing the feature.

A manual_fields JSON column tracks fields changed by the user. Subsequent API
research preserves those fields, including deliberate blanks and venue status;
API extraction refuses to replace manually edited seeds. CSV export includes the
manual-fields metadata. The separate historical source and API payloads remain
unchanged. Edits do not automatically mark a record reviewed or run new research.
CSV output can be refreshed separately using the normal export command.

The service binds to loopback. Writes require a local Host/origin, a JSON PATCH
request and the custom edit header; CORS preflight allows these headers only for
the supported local origins. The database is opened in existing-file read/write
mode for saves; browser reads remain read-only. Protected/unknown fields cannot
be updated through the request. No OpenAI key or API research is involved.

Successful saves return the new record/revision. The list replaces that row,
reapplies sorting/search and rebuilds country/city options. Invalidated filter
selections clear. If an edited row no longer matches a filter it can disappear
from the current results, as expected. Contact icons update with the new values.

## Restart and manual checks

Restart the Python service to load the new endpoint, then restart/reload Flutter:

```zsh
.venv/bin/python restaurant_server.py
```

From flutter_app, use `flutter run -d macos` or `flutter run -d chrome` if starting
again. The updated server supports safely replacing its verified previous copy.

Check the edit icon in wide/narrow views, including a record with no website.
Change a detail, save, refresh the app and verify persistence. Cancel another edit
and verify no change. Check invalid/blank name and website validation, optional
clearing, phone formatting and country/city filter updates. Open the same record
in two sessions: after saving one, the stale session must not overwrite it.
Confirm prior values in restaurant_edit_history and unchanged original sources.
Record date, tester, platform and pass/fail results.

Focused tests were added but not run under the manual verification policy:

```zsh
.venv/bin/python -m unittest discover -s tests -p test_restaurant_edits.py -v
# From flutter_app:
flutter test test/edit_restaurant_dialog_test.dart
```

Python syntax, Dart formatting and diff whitespace checks passed. No test suites,
Flutter analysis, application launches, live API requests or platform builds were
run. Runtime acceptance remains manual.

Created: Python edit service, Flutter modal, focused Python/widget tests and this
document. Modified: local server, restaurant model/repository/list, shared schema
and research guards, package metadata and run/README documentation. No files or
records were removed. No commit/push was made. Phase: not applicable. Suggested
commit: `Add compact restaurant editing with audited conflict-safe saves`.

## Intrinsic layout correction

The first editor layout used LayoutBuilder inside AlertDialog. AlertDialog's
intrinsic measurement cannot measure LayoutBuilder, producing the RenderIntrinsicWidth
and cascading missing-size/hit-test assertions in the reported trace. Paired fields
now choose their columns using the window width minus the dialog/content insets,
without a layout-time builder inside the intrinsic measurement subtree. Wide
windows retain paired fields and narrow windows stack them; modal scrolling and
save behaviour are unchanged.

Added regression cases for opening the modal and expanding More details at desktop
and narrow-phone sizes. Dart formatting and diff whitespace checks passed; the
widget tests were not run under the manual verification policy. Rerun the app and
open the editor, expand More details and resize it to confirm the error is gone.
Focused manual command from flutter_app:
`flutter test test/edit_restaurant_dialog_test.dart`.
No records were changed. Suggested commit: `Fix edit dialog intrinsic layout conflict`.

## Confirmed deletion

A red Delete button is left-aligned in the same action row as Cancel and Save.
It opens a separate confirmation naming the restaurant; cancellation or dismissal
makes no request and leaves the editor intact. Confirmation explicitly warns that
unsaved editor changes are discarded. During deletion all editor actions/fields
are disabled. Success closes the editor, removes the row from the local list and
updates counts/country/city filters. Failures leave the editor open with a message.

DELETE /api/restaurants/ID requires the same local Host/origin, JSON/custom header
and revision safeguards as edits, plus confirmed=true. It refuses stale records.
The transaction saves the full row and complete source mappings in
restaurant_deletion_history before removing the active row. Consolidation source
mappings are archived and removed to satisfy foreign keys; source lines, API
history, edit history and consolidation history are retained. Source occurrences
are recorded in deleted_restaurant_sources so normal import/resume does not
recreate intentionally deleted entries. Remaining duplicate pointers are cleaned.
A failure rolls back archive/mapping/deletion changes together. No real restaurant
was deleted while implementing this feature. CSV is updated on the next normal
export, not automatically by the delete endpoint.

Changed: edit modal/result handling, list callbacks, repository, local service,
archive helper, import guards and focused tests. Python syntax, Dart formatting
and whitespace checks passed. Tests were extended for confirmation cancellation,
left alignment, missing confirmation, stale deletion and archival/source safety,
but were not run; no app launches, analysis or platform builds were performed.
Restart the Python service, reload Flutter and manually check Delete alignment,
confirmation cancellation, and confirmed removal/persistence using a disposable
record or a database copy. Check its full archive and retained source history.
Record date, tester and results. No commit was made; phase not applicable.
Suggested commit: `Add confirmed restaurant deletion with archival history`.
