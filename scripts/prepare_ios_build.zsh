#!/bin/zsh
# Keep generated Flutter build products outside iCloud's metadata management.
set -euo pipefail
BENEEDE_PROJECT_ROOT="${0:A:h:h}"
"$BENEEDE_PROJECT_ROOT/.venv/bin/python" - "$BENEEDE_PROJECT_ROOT" <<'PY'
from pathlib import Path
from datetime import datetime, timezone
import shutil
import subprocess
import sys

root = Path(sys.argv[1])
build = root / 'flutter_app' / 'build'
base = Path.home() / 'Library' / 'Caches' / 'BeneEde'
base.mkdir(parents=True, exist_ok=True)
if build.is_symlink():
    target = build.resolve()
    if not target.is_relative_to(base.resolve()):
        raise SystemExit('Existing build symlink points elsewhere; leave it unchanged and inspect it manually.')
    target.mkdir(parents=True, exist_ok=True)
else:
    target = base / ('flutter-build-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
    if build.exists():
        shutil.move(str(build), str(target))
    else:
        target.mkdir()
    try:
        build.symlink_to(target, target_is_directory=True)
    except OSError:
        if not build.exists():
            shutil.move(str(target), str(build))
        raise

def attributes():
    result = subprocess.run(['/usr/bin/xattr', '-r', str(target)], capture_output=True, text=True, check=True)
    return [line.rsplit(': ', 1) for line in result.stdout.splitlines() if ': ' in line]

bad = {'com.apple.FinderInfo', 'com.apple.ResourceFork'}
found = [(path, name) for path, name in attributes() if name in bad]
for path, name in found:
    subprocess.run(['/usr/bin/xattr', '-d', name, path], check=True)
remaining = [(path, name) for path, name in attributes() if name in bad]
if remaining:
    raise SystemExit('Some signing-blocking attributes remain; inspect the generated build directory.')
print('Generated build output:', target)
print('Removed signing-blocking Finder/resource-fork attributes:', len(found))
print('Project source, signing settings, certificates and Flutter SDK were left unchanged.')
PY
