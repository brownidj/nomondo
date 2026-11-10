# Website links and availability — 10 November 2026

Goal: open a listed restaurant website from its icon and turn the icon red when
opening or checking the page fails. Hide null, blank and case-insensitive,
whitespace-trimmed Not listed values. Both table/card views share the behaviour.

The new Dart website service accepts only HTTP(S), adding HTTPS to bare domains.
Browser URLs open directly during the press gesture; native apps use url_launcher.
Address tooltips are retained on hover/long-press. Missing plugin errors explain
that Flutter must restart. Duplicate presses during a check are disabled.

The browser's same-origin policy prevents inspecting the actual page opened in
another tab. After a press, the local service therefore checks the stored URL via
GET /api/restaurants/ID/website-status. It does not accept arbitrary supplied URLs.
It uses a bounded GET, follows up to four redirects and closes without downloading
the response body. Successful HTTP responses mean reachable; 404/410, server
errors, DNS/TLS/connection failures mean unavailable. Authentication, bot blocking,
rate limiting and inconclusive responses mean unknown. A missing local checker
also means unknown, never a failed restaurant website. The result is reachability
from the service, not proof of page rendering in the user's browser.

Only public IP destinations on ports 80/443 are checked. All DNS results and
redirect destinations are validated. Connections use the validated IP directly,
retaining HTTPS certificate/hostname verification, to avoid resolving again.
Local/private targets are not probed. Checks occur only on press, with no startup
crawl. There are no database writes. Status is session-only and can be retried by
pressing the icon again. Changed URLs reset icon state; obsolete async responses
cannot change another restaurant's state.

Changed: Python service/package metadata, shared API base URL, restaurant-name
widget and Flutter README. Created: website status helper, Dart website service,
network-free Python tests and this document. No files removed. No commits made.
Phase: not applicable. Suggested commit: `Open restaurant websites and flag unavailable links`.

Python syntax, Dart formatting and diff whitespace checks passed. Tests were
added but not run; no application launches, Flutter analysis, live website
checks or platform builds were performed under the manual verification policy.

Manual checks:

1. Restart the Python service with `.venv/bin/python restaurant_server.py`.
2. Reload/restart Flutter. Press a website icon in wide/narrow views and confirm
   the correct page opens, with URL available on hover/long-press.
3. Check known missing pages and a failed connection: the icon should become red
   and its tooltip should say Website unavailable. Check successful links stay
   neutral and missing/Not listed links have no icon. Confirm a blocked/login site
   is not labelled broken and stopping the local checker does not turn links red.
4. Run `.venv/bin/python -m unittest discover -s tests -p test_website_status.py -v`
   for network-free classification and destination/redirect protection checks.
5. Record date, tester, platform and results. Runtime acceptance remains manual.

References: https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy
and https://pub.dev/documentation/url_launcher/latest/url_launcher/launchUrl.html
