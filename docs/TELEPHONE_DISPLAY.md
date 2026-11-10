# Telephone display — 10 November 2026

Phone numbers appear in a tooltip when the phone icon beneath the restaurant
name is pressed. This applies to desktop rows and compact cards. The Tel column
and separate card telephone field have been removed. Missing/Not listed values
have no phone icon. The tooltip stays visible for ten seconds.

`phone_numbers.py` uses python-phonenumbers international formatting with the
stored restaurant country as the region for national numbers. Existing explicit
country codes take precedence. Extensions and distinct alternative numbers are
retained; duplicate representations of the same number are consolidated.
Unparseable or ambiguous future values are preserved rather than inventing digits.
The read-only JSON service applies the same formatter to future records.
See the [library documentation](https://github.com/daviddrysdale/python-phonenumbers).

All 471 populated telephone entries were converted to international format;
343 stored values changed. The database was backed up before the update in
`data/backups/restaurants-before-phone-format-20261110T021434Z.sqlite3`.
Original/converted pairs are recorded in `data/backups/phone-format-20261110T021434Z.json`.
Original source text and API audit payloads remain intact. The country was absent
for L’Entrecôte (ID 760); France was used for phone formatting based on its stored
Bordeaux address and .fr website, without changing its country field.

Modified: restaurant list widgets, Python service, package metadata and READMEs.
Created: phone formatting helper and this document. No tests were added or run;
no Flutter analysis, app launch or platform build was run. Python syntax, Dart
formatting and diff whitespace checks were performed. Runtime/UI checks remain
manual under the project policy.

After restarting the Python service and reloading Flutter, manually check a phone
icon in desktop and card views, an international number, alternatives/extensions,
and a record without a number. Confirm that there is no Tel column. Record date,
platform, tester and results. Existing data-service restart commands are in
[Running the app](RUNNING_THE_APP.md).

No commit was made. Suggested commit: `Show international telephone numbers beneath restaurant names`.
Phase: not applicable.

## Website icon update — 10 November 2026

A website icon now sits beside the phone icon beneath the restaurant name in
both desktop and card views. Pressing it shows the internet address in a tooltip.
Missing/Not listed internet addresses have no icon. The Internet address column
and separate card field have been removed. Contact values remain searchable.

Changed the restaurant name widget and contact documentation. Dart formatting
and diff whitespace checks passed; no tests, Flutter analysis, app launches or
platform builds were run. Reload Flutter and manually check both icons, a
website-only entry and an entry without contact values in wide and narrow layouts.
No tests were added, files removed or commits made. Phase: not applicable.
Suggested commit: `Move internet address into a tooltip beside the phone icon`.
