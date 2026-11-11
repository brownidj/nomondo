#!/bin/zsh
# Owner runs this explicitly; do not include the key in a shared application.
set -euo pipefail
BENEEDE_PROJECT_ROOT="${0:A:h:h}"
"$BENEEDE_PROJECT_ROOT/.venv/bin/python" - "$BENEEDE_PROJECT_ROOT/data/mobile_connection.json" <<'PY' | pbcopy
import json
from pathlib import Path
import sys
path = Path(sys.argv[1])
if not path.exists():
    raise SystemExit('Prepare the mobile catalogue service first.')
sys.stdout.write(json.loads(path.read_text())['RESTAURANT_API_TOKEN'])
PY
print 'Pairing key copied to the Mac clipboard. Paste it into Pair with Mac on the trusted phone.'
