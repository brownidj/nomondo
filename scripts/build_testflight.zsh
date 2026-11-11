#!/bin/zsh
# Export a local App Store/TestFlight IPA. This script never uploads it.
set -euo pipefail
BENEEDE_PROJECT_ROOT="${0:A:h:h}"
BENEEDE_BUILD_NUMBER=""
BENEEDE_BUILD_NAME=""
BENEEDE_DRY_RUN=false
BENEEDE_IPA_DESTINATION="$BENEEDE_PROJECT_ROOT/build/ios/ipa/beneede_app.ipa"

usage() {
  print 'Usage: scripts/build_testflight.zsh --build-number <integer> [--build-name <x.y.z>] [--dry-run]'
  print 'Builds an App Store IPA with Flutter; upload it manually using Transporter.'
  print 'Packages initial data and a public server URL; never the private pairing key. See docs/TESTFLIGHT_AND_TRANSPORTER.md.'
}
while (( $# )); do
  case "$1" in
    --build-number|--build-name)
      if (( $# < 2 )); then usage >&2; exit 2; fi
      if [[ "$1" == --build-number ]]; then
        BENEEDE_BUILD_NUMBER="$2"
      else
        BENEEDE_BUILD_NAME="$2"
      fi
      shift 2 ;;
    --dry-run) BENEEDE_DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
if [[ ! "$BENEEDE_BUILD_NUMBER" =~ '^[1-9][0-9]*$' ]]; then
  print -u2 -- 'Supply a positive --build-number higher than the last build uploaded to Apple.'
  exit 2
fi
if [[ -n "$BENEEDE_BUILD_NAME" && ! "$BENEEDE_BUILD_NAME" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 -- '--build-name must have the form x.y.z.'
  exit 2
fi
if (( $+commands[flutter] )); then
  BENEEDE_FLUTTER_BIN="${commands[flutter]}"
else
  BENEEDE_FLUTTER_BIN="$HOME/development/flutter/bin/flutter"
fi
BENEEDE_COMMAND=("$BENEEDE_FLUTTER_BIN" build ipa --release --export-method app-store
  "--build-number=$BENEEDE_BUILD_NUMBER"
  "--dart-define-from-file=$BENEEDE_PROJECT_ROOT/data/catalogue_build.json")
if [[ -n "$BENEEDE_BUILD_NAME" ]]; then
  BENEEDE_COMMAND+=("--build-name=$BENEEDE_BUILD_NAME")
fi
if $BENEEDE_DRY_RUN; then
  print -r -- "Working directory: $BENEEDE_PROJECT_ROOT/flutter_app"
  printf '%q ' "${BENEEDE_COMMAND[@]}"
  print
  print -r -- "Move exported IPA to: $BENEEDE_IPA_DESTINATION (replace previous export)"
  exit 0
fi
if [[ ! -x "$BENEEDE_FLUTTER_BIN" ]]; then
  print -u2 -- "Flutter executable not found: $BENEEDE_FLUTTER_BIN"
  exit 1
fi
"$BENEEDE_PROJECT_ROOT/.venv/bin/python" "$BENEEDE_PROJECT_ROOT/scripts/package_catalogue.py"
"$BENEEDE_PROJECT_ROOT/scripts/prepare_ios_build.zsh"
BENEEDE_BUILD_MARKER="$(mktemp -t beneede-testflight)"
trap 'rm -f "$BENEEDE_BUILD_MARKER"' EXIT
cd "$BENEEDE_PROJECT_ROOT/flutter_app"
"${BENEEDE_COMMAND[@]}"
BENEEDE_NEW_IPA=false
for BENEEDE_IPA in "$BENEEDE_PROJECT_ROOT/flutter_app/build/ios/ipa/"*.ipa(N); do
  if [[ "$BENEEDE_IPA" -nt "$BENEEDE_BUILD_MARKER" ]]; then
    mkdir -p "${BENEEDE_IPA_DESTINATION:h}"
    mv -f "$BENEEDE_IPA" "$BENEEDE_IPA_DESTINATION"
    print -r -- "New IPA for Transporter: $BENEEDE_IPA_DESTINATION"
    BENEEDE_NEW_IPA=true
  fi
done
if ! $BENEEDE_NEW_IPA; then
  print -u2 -- 'No new IPA was exported. Check signing/export output or use Xcode Organizer on the archive.'
  exit 1
fi
