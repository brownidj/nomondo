"""Prepare pairing and start the Mac catalogue service; invoked explicitly."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from mobile_connection import ensure_mobile_connection


def main():
    config = ensure_mobile_connection()
    log = ROOT / 'data' / 'logs' / 'mobile_service.log'
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open('a') as output:
        process = subprocess.Popen([sys.executable, str(ROOT / 'restaurant_server.py'), '--lan', '--port', '8766'],
                                   cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
    expected = hashlib.sha256(config['RESTAURANT_API_TOKEN'].encode()).hexdigest()[:16]
    for _ in range(60):
        if process.poll() is not None:
            raise SystemExit(f'The mobile catalogue service could not start. See {log}')
        try:
            with urlopen('http://127.0.0.1:8766/api/health', timeout=1) as response:
                status = json.load(response)
            if status.get('service') == 'BeneEde' and status.get('pairing_fingerprint') == expected:
                print('Mobile catalogue:', config['RESTAURANT_API_URL'])
                print('Keep this Mac awake and both devices on the same private Wi-Fi.')
                return
        except (OSError, ValueError):
            pass
        time.sleep(.25)
    raise SystemExit(f'The mobile service did not become ready. See {log}')


if __name__ == '__main__':
    main()
