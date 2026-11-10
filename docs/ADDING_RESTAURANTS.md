# Adding restaurants — 10 November 2026

The Add restaurant button opens a compact modal using the existing edit form.
Enter name and city, or an internet address on its own. Other fields are optional; no existing record is
changed just by opening or looking up a draft.

## User flow

- Name/city only: Add opens a Yes/No question about researching missing details.
  No creates the manual entry. Yes runs web research, shows progress and fills
  missing form fields for review. API usage is disclosed in the question.
- Website supplied: read the site and relevant contact/location/menu pages. Parse
  JSON-LD venue records locally. If OPENAI_API_KEY is configured, the service also
  interprets the fetched page text through structured API extraction.
- Lookup results: show all matching-city branches and lookup notes. The first
  branch uses the editable form; additional branches are listed under All venues.
  Press Add again to save all proposed distinct branches. No records are written
  merely by completing a lookup. User-entered fields are not silently replaced.
- Existing branches are reported as already in the catalogue and are left
  unchanged. Their original records are not overwritten. Different addresses
  remain separate records; an incomplete matching address is flagged for review.
- Save updates the catalogue and location-filter options. Current filters remain
  active, so an added restaurant may be outside the displayed results.

The feature is implemented with Python scripts, not the ChatGPT application.
Manual entry and structured website extraction need no OpenAI API key. General
web discovery and unstructured text interpretation use the existing Responses
API integration with web search and JSON-schema outputs. The model remains the
existing OPENAI_ENRICH_MODEL setting, default gpt-4.1; no model migration was made.
The key is read only by the Python service, using the existing environment setup.
A ChatGPT window or subscription is not used by the integration. API usage is
separate from simply running the local app.

Official API references:
- https://developers.openai.com/api/docs/guides/tools-web-search
- https://developers.openai.com/api/docs/guides/structured-outputs

## Lookup, branches and limits

The service has POST /api/restaurant-lookups and GET /api/restaurant-lookups/ID.
Lookups run off the request thread, with up to two active and four outstanding
jobs; the UI polls for progress. Finished jobs expire after one hour and jobs do
not survive a service restart. Cancelling closes the draft without saving; an
already started API request may continue to complete. Lookup failure retains
entered text and presents an error so the user can retry or choose Add entered
details only to save the visible draft without another lookup.

Website retrieval prioritises location/branch/store/outlet pages before
contact/about/menu pages. It is limited to 64 relevant same-host pages, one MiB
per page, bounded requests and redirects, and a 180-second traversal budget
(an in-flight request may finish afterwards). If pages remain unread, lookup
notes explicitly report incomplete discovery and the number of queued pages. Every HTTP
redirect destination and DNS address is checked before connecting; private/local
addresses and nonstandard ports are rejected. Connections use the validated IP
and retain HTTPS certificate/host checks. The service never follows website text
as instructions. Website results without a matching sourced street/city are not
invented; an unhelpful site falls back to the submitted draft with lookup notes.

Web research requests all matching branches and retains retrieved-source URLs.
Each discovered branch must have a sourced address and city; only supported
fields are accepted. Facts not found remain missing, and uncertainty is flagged.
Different countries returned for a country-less query require country input to
identify the intended city. Structured-data city matching supports a small number
of explicit aliases (e.g. Bangalore/Bengaluru); it is not a worldwide geocoder.
A website can omit branches, use dynamic pages, block retrieval or provide stale
information. Research therefore adds all distinct branches actually discovered,
not a guarantee of exhaustive worldwide/local coverage. Limits and incomplete
results are surfaced in lookup notes, not silently presented as exhaustive.
More than 100 proposed venues returns an error rather than truncating a save.

When multiple sources describe the same normalized address, complementary fields
are combined and source alternatives are retained in the lookup history. Source
conflicts stay flagged. User-supplied branch-specific contacts are not spread
across unrelated branches. An entered address not confirmed among discovered
branches is preserved as a separate manual proposal for review.

## Persistence and safety

POST /api/restaurants takes a stable request ID, validated records and an optional
completed lookup ID. The server retains the lookup/evidence itself rather than
trusting evidence supplied by the browser. It uses the existing local Host/origin,
JSON/custom-header checks and strict editable-field allowlist. All input records
are validated before insertion. Creation, source records, API audits and the add
receipt commit together. A failed batch rolls back all record inserts.

Restaurant name/city and supplied facts become protected manual fields. Personal
ratings are never supplied by the AI. Telephone numbers use the existing formatter.
Original submitted values, proposed venue details, source alternatives and lookup
notes are retained in source_lines. Complete API responses used for additions are
retained in api_runs with phase add_lookup. Source status allows later explicit
research while protecting manual facts.

restaurant_add_requests records input signatures, resulting IDs and already-known
IDs. Retrying the same request returns its prior result; reusing its key with
changed input is rejected. Existing name/city/address matches are skipped rather
than duplicated or modified. New active records use IDs above active/deletion
history IDs. This does not perform fuzzy automatic deletion or consolidation.
CSV is refreshed by the normal export command, not each add endpoint call.

## Setup and manual acceptance

Restart the Python service to load the new schema/endpoints. For automatic API
research, set OPENAI_API_KEY in that service's shell/PyCharm environment first;
.env is not automatically loaded. Never put the key in Flutter configuration.

```zsh
.venv/bin/python restaurant_server.py
```

Reload Flutter. Test required fields, Cancel, name/city-only No, and name/city-only
Yes with a configured API key. Test a website with structured branch data without
a key, and plain website text with a key. Review all branch addresses, add them,
refresh, and confirm separate records; repeat the add to confirm known branches
are reported without duplication. Verify manual notes/contacts, source evidence,
failed lookups, and stale/retried requests. Use a disposable database for live
acceptance to avoid unintended catalogue additions. Record date, tester, platform
and results.

Focused, isolated tests were added but not run under the manual verification
policy. Python tests use temporary catalogues and fake pages/API clients; widget
tests use MockClient, including No without any lookup, branch preview/batch save,
required fields and a failed lookup retaining text.

```zsh
.venv/bin/python -m unittest discover -s tests -p test_restaurant_additions.py -v
# From flutter_app:
flutter test test/add_restaurant_dialog_test.dart
```

Python/package syntax, Dart formatting and diff whitespace checks passed. No
test suite, Flutter analysis, application launch, platform build or live restaurant
lookup/API call was run. No real restaurant records were added during development.
Runtime and research-quality acceptance remain manual.

Created restaurant_lookup.py, restaurant_additions.py, Python/widget tests and
this document. Updated the shared modal, repository, list button/callback, server,
website reader, existing research query hook, package metadata and READMEs. No
files/records were deleted. No commit/push was made. Phase: not applicable.
Suggested commit: Add manual and researched restaurant creation with branch discovery.

## Revised entry criteria

Accepted alternatives are (restaurant name AND city) OR an internet address alone.
The modal and backend enforce the same rule; supplying a valid website removes
both name/city requirements. Website lookup accepts absent name/city and infers
those facts from sourced venue data. If no city is entered, discovered website
locations retain their own cities rather than being forced into an empty city.
If the website cannot identify the name, an explicitly provisional Website: host
label permits preserving the URL for review, with city left missing and the record
flagged. No restaurant identity or location is fabricated. Entered notes and
other details remain protected. Invalid/missing alternatives are rejected.

Regression coverage includes website-only form submission, inferred names/cities
and a provisional website-only manual record. Tests were updated but not run.
Dart formatting, Python syntax and whitespace checks passed; no catalogue records
were changed and no live website/API lookups were run for this criteria change.
Suggested commit: Accept website-only restaurant additions.

## MTR branch discovery correction — 10 November 2026

Goal and scope: make a homepage or location-directory lookup follow the complete
linked branch list within the documented bounds, retaining one proposal per
distinct address. Website-only input must include locations across cities and
countries; an explicitly entered city/country still filters results.

The supplied [MTR locations page](https://mavallitiffinrooms.com/locations) links
23 branches. Direct inspection of its homepage, directory and two branch pages
found readable JSON-LD restaurant data on the branch pages. The previous eight-page
cap prevented traversal of the full list. Matching only a branch's name also
rejected expanded names such as Mavalli Tiffin Rooms when the branch was named
MTR. Matching now also considers explicit parent-organisation/brand names and
the expanded part of a catalogue name containing a parenthesised acronym.
No initials-based guesses or site-specific restaurant records were added.

Acceptance: a synthetic 23-branch directory reached from a homepage produces
23 proposals across different cities/countries without an API key; branch pages
take priority over menus; an explicit parent name permits an abbreviated branch
name while unrelated names are rejected; reaching the crawl limit reports
incomplete results. Existing city filtering remains in effect. The API extraction
prompt now consistently applies city restrictions only when a city was entered.

Modified: restaurant_lookup.py, tests/test_restaurant_additions.py, and this
document. No files removed or catalogue records changed. Added regression tests
for the acceptance cases. Tests/app/API calls: not run; only the public website
was inspected for diagnosis. Static Python AST and whitespace checks are recorded
in the completion response. Implementation complete; manual verification pending.
Phase: not applicable.

Manual verification (David, local macOS; date/result to record): restart the
Python service, open Add restaurant, enter only
https://mavallitiffinrooms.com (leave name, city and country blank), and review
all proposed addresses before saving. Expect the directory's linked branches;
check for incomplete-discovery notes or inaccessible pages. Repeat with the
locations URL and with a city to confirm filtering. Tests may be run manually:
`.venv/bin/python -m unittest discover -s tests -p test_restaurant_additions.py`.
Website omissions, blocked pages and the documented limits can still prevent
exhaustive discovery. Suggested commit: `Follow full restaurant branch directories
and match explicit parent names`.

## Cleared website fallback

<!-- UI maintenance, 10 November 2026: removed the standalone visible/total
restaurant count and its extra spacing from restaurant_list_page.dart. The
Needs review filter remains. Acceptance: no count row between filters and list;
loading indicator still appears. Implementation complete; visual verification
pending David reloading the app. Dart format and git diff --check passed.
No tests created/run, files removed, catalogue changes or commits. This document
and the list screen were modified. No new files. No known functional risks;
phase not applicable. Suggested commit: Remove restaurant count row. -->

Removing the website after a previous lookup switches the next attempt to web
research using name/city. This also works when country, notes or other fields
are populated; such details no longer bypass the automatic-research offer. A
stale website-mode request with no website but valid name/city is likewise
rerouted by the server. The cleared URL is not fetched again. A newly discovered
website can fill the empty field for review. Explicit Add entered details only
still bypasses research. API-backed name/city search requires the configured key.
Regression cases cover this transition in the modal and server. Python syntax,
Dart formatting and whitespace checks passed; tests were updated but not run.
No live lookups or catalogue changes were made. Suggested commit:
`Fall back to name and city when a website is removed`.

## Mobile behaviour — 10 November 2026

Goal/acceptance: iOS and Android retain adding, editing, review/archive/restore
and city completion. Adding saves entered details directly without automatic
website/AI branch research or the automatic-details prompt, even when the Python
service has an API key. Existing required-field rules still apply: name plus city,
or website alone. Website-only manual records use the existing provisional name
and review flags until a user supplies the missing identity.

app_capabilities.dart centralises platform policy using Flutter's target platform
(including browsers reporting iOS/Android); a narrow desktop window remains a
desktop. The modal forces manual adding on mobile, and repository.lookup refuses
mobile research before HTTP. Desktop discovery retains its existing behaviour.
This is application feature policy, not server-side authentication/access control.
No keys are placed in the Flutter app. Manual editing/review/city completion still
requires access to the configured catalogue service. Device networking and native
target preparation described in RUNNING_THE_APP.md are separate from this change.

Created app_capabilities.dart and mobile_restaurant_add_test.dart. Modified
edit_restaurant_dialog.dart, restaurant_repository.dart, desktop Add test platform
setup and this document. No files removed or catalogue data changed. Added iOS/
Android regressions for name/city and website-only manual additions, and a direct
repository guard preventing discovery requests. Existing Add tests explicitly
use macOS to preserve desktop discovery coverage. Dart formatting/whitespace
checks passed; tests, app launches/builds and API research calls were not run.
Implementation complete; manual functional verification pending; phase not applicable.

David: reload/rebuild for the target platform as appropriate. On iOS/Android,
add by name/city and by website; confirm no AI prompt/research and successful
manual save. Check edit, review decisions and city completion still work. On
macOS/desktop Chrome, confirm automatic discovery remains available. Optional:

```zsh
cd flutter_app
flutter test test/mobile_restaurant_add_test.dart test/add_restaurant_dialog_test.dart
```

Personal ChatGPT accounts: official documentation checked 10 November 2026
describes Sign in with ChatGPT and optional plan usage for eligible Plus/Pro
users in supported apps. BeneEde does not currently implement that integration.
Commercial availability is limited to selected partners; open-source partners and
selected private clients have a plan-usage integration path. Signing in for identity
alone does not authorise inference; separate consent/scopes are required. Free
plan inference is not documented as eligible here. No account integration was
added or enabled as part of the manual-mobile policy change.
Sources: https://developers.openai.com/siwc/quickstart and
https://learn.chatgpt.com/docs/sign-in-with-chatgpt.
Suggested commit: Keep mobile restaurant additions manual and retain desktop research.

## Compact Add control — 11 November 2026

Replaced the catalogue's labelled Add restaurant button with a bold white plus on a green filled button
in the same right-aligned position. Its Add restaurant tooltip/accessible label,
loading-disabled state and modal action remain. This applies to desktop and
mobile; the modal's own submit button is unchanged. Modified the list screen,
existing app smoke-test finder and this document; no new/removed files or data
changes. Dart formatting and whitespace checks passed; tests/app builds not run.
Implementation complete, manual check pending; no phase. David: reload Flutter,
confirm the white plus/green background and tooltip, and press it to open Add. Suggested commit:
Use a bold white plus on a green Add button.
