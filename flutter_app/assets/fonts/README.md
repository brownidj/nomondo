# Bundled font assets

Downloaded 10 November 2026 from the official Noto and Google Fonts repositories.
`SOURCES.json` records source URLs, SHA-256 checksums and byte lengths.
All fonts use the SIL Open Font License; corresponding license files are included
in the source tree and Flutter asset bundle.

Noto Sans supplies Latin (including Vietnamese), Greek and Cyrillic, with regular,
semibold and bold files. Noto Sans CJK JP supplies Chinese/Japanese/Korean fallback
glyphs. Noto Sans Thai and Noto Emoji provide Thai and monochrome symbols/emoji.
These are full upstream fonts to support new restaurant entries, not subsets of
current data. Assets total approximately 19.3 MiB, mostly the CJK font.

Families are declared in `pubspec.yaml` and configured in `lib/main.dart`.
Static inspection of their character maps found coverage for all visible
characters in the current displayed restaurant fields and dish/notes symbols
(200 distinct characters inspected, including whitespace and formatting controls).
Control characters and variation selectors do not require standalone visible glyphs.
This is a coverage check, not proof of runtime rendering or shaping.

After changing font assets, stop and rerun Flutter; hot reload is insufficient
for reliable font-bundle refresh. Manually check Byeokje Galbi, the Thai website
URL, Japanese/Chinese names, Vietnamese accents and the dish/notes icons, including
their dialogs/tooltips. Confirm the missing-Noto-font warning is gone. Record the
date, platform, tester and result. No app launch, platform build, Flutter analysis
or test suite was run. No tests were added. Dart formatting and diff whitespace
checks passed. No commit was made; phase not applicable.

Files changed: pubspec and app theme. Files created: these font assets, licenses,
source manifest and this document. No files removed.
Suggested commit: `Bundle Noto fonts for restaurant scripts and detail symbols`.

Reference: https://docs.flutter.dev/cookbook/design/fonts
