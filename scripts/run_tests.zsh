#!/bin/zsh
# Host regressions by default; native integration and release builds are explicit.
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
FLUTTER_BIN="${FLUTTER_BIN:-/Users/david/development/flutter/bin/flutter}"
DEVICE_ID=""
BUILD_RELEASES=false
RUN_HOST=true
while (( $# )); do
  case "$1" in
    --device) DEVICE_ID="$2"; shift 2 ;;
    --builds) BUILD_RELEASES=true; shift ;;
    --builds-only) BUILD_RELEASES=true; RUN_HOST=false; shift ;;
    *) print -u2 'Usage: scripts/run_tests.zsh [--device <id>] [--builds | --builds-only]'; exit 2 ;;
  esac
done
TEST_OUTPUT="${TEST_OUTPUT:-$PROJECT_DIR/data/logs/testing-$(date +%Y-%m-%d-%H%M%S)}"
mkdir -p "$TEST_OUTPUT"

run_check() {
  local check_name="$1"
  shift
  print "Running $check_name"
  "$@" 2>&1 | tee "$TEST_OUTPUT/$check_name.log"
}

cd "$PROJECT_DIR"
if $RUN_HOST; then
  run_check python .venv/bin/python -m unittest discover -s tests -v
  cd "$PROJECT_DIR/flutter_app"
  run_check analyze "$FLUTTER_BIN" analyze
  run_check flutter "$FLUTTER_BIN" test --coverage --reporter expanded
fi
cd "$PROJECT_DIR/flutter_app"
if [[ -n "$DEVICE_ID" ]]; then
  run_check integration "$FLUTTER_BIN" test integration_test/offline_catalogue_flow_test.dart -d "$DEVICE_ID" --reporter expanded
fi
if $BUILD_RELEASES; then
  run_check package-catalogue "$PROJECT_DIR/.venv/bin/python" "$PROJECT_DIR/scripts/package_catalogue.py"
  run_check web-release "$FLUTTER_BIN" build web --release
  run_check macos-release "$FLUTTER_BIN" build macos --release
  run_check ios-prepare "$PROJECT_DIR/scripts/prepare_ios_build.zsh"
  run_check ios-release "$FLUTTER_BIN" build ios --release
  run_check release-assets "$PROJECT_DIR/.venv/bin/python" "$PROJECT_DIR/scripts/check_release_assets.py"
fi
print "Requested checks passed. Logs: $TEST_OUTPUT"
