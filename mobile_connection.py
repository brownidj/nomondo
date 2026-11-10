"""Private local-network configuration shared by the service and Flutter build."""
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess

ROOT = Path(__file__).resolve().parent
CONFIG = ROOT / 'data' / 'mobile_connection.json'


def ensure_mobile_connection(port=8766):
    existing = json.loads(CONFIG.read_text()) if CONFIG.exists() else {}
    token = existing.get('RESTAURANT_API_TOKEN')
    if not isinstance(token, str) or len(token) < 32:
        token = secrets.token_urlsafe(32)
    try:
        result = subprocess.run(['/usr/sbin/scutil', '--get', 'LocalHostName'],
                                capture_output=True, text=True, check=True)
        host = result.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        host = socket.gethostname().split('.')[0]
    host = host.removesuffix('.local') + '.local'
    config = {'RESTAURANT_API_URL': f'http://{host}:{port}', 'RESTAURANT_API_TOKEN': token}
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(CONFIG, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        json.dump(config, output, indent=2)
        output.write('\n')
    CONFIG.chmod(0o600)
    return config
