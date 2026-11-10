#!/bin/zsh
# One command prepares a paired Mac service and launches the selected phone.
set -euo pipefail
BENEEDE_PROJECT_ROOT="${0:A:h:h}"
"$BENEEDE_PROJECT_ROOT/.venv/bin/python" "$BENEEDE_PROJECT_ROOT/scripts/prepare_mobile.py"
"$BENEEDE_PROJECT_ROOT/scripts/prepare_ios_build.zsh"
if (( $+commands[flutter] )); then
  BENEEDE_FLUTTER_BIN="${commands[flutter]}"
else
  BENEEDE_FLUTTER_BIN="$HOME/development/flutter/bin/flutter"
fi
cd "$BENEEDE_PROJECT_ROOT/flutter_app"
# A release installation can be reopened from the iPhone home screen without
# Flutter's debugger. Explicit mode flags remain available for development.
BENEEDE_BUILD_MODE=(--release)
for BENEEDE_ARGUMENT in "$@"; do
  case "$BENEEDE_ARGUMENT" in
    --debug|--profile|--release) BENEEDE_BUILD_MODE=();;
  esac
done
exec "$BENEEDE_FLUTTER_BIN" run \
  "${BENEEDE_BUILD_MODE[@]}" \
  --dart-define-from-file="$BENEEDE_PROJECT_ROOT/data/mobile_connection.json" "$@"
