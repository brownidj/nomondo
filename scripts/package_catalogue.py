"""Package a consistent read-only catalogue snapshot; never package credentials."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sys
import tempfile
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from mobile_connection import ensure_mobile_connection
from restaurant_reviews import read_offline_catalogue


def write_json(path, payload, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        try:
            json.dump(payload, output, ensure_ascii=False, separators=(',', ':'))
            output.write('\n')
            output.flush()
            os.fsync(output.fileno())
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise
    temporary.chmod(mode)
    temporary.replace(path)


def package_catalogue(database, seed_path, defines_path, server_url):
    url = urlsplit(server_url)
    if url.scheme != 'http' or not url.hostname or not url.hostname.endswith('.local') or url.username or url.password:
        raise ValueError('Use the Mac local-network .local URL, without credentials.')
    snapshot = read_offline_catalogue(database)
    snapshot['packaged_at'] = datetime.now(timezone.utc).isoformat()
    write_json(seed_path, snapshot, mode=0o644)
    # An explicit allowlist prevents the owner pairing key entering a shared build.
    write_json(defines_path, {'RESTAURANT_API_URL': server_url.rstrip('/')})
    return len(snapshot['restaurants'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=Path, default=ROOT / 'data/restaurants.sqlite3')
    args = parser.parse_args()
    config = ensure_mobile_connection()
    count = package_catalogue(args.db, ROOT / 'flutter_app/assets/catalogue/initial_catalogue.json',
                              ROOT / 'data/catalogue_build.json', config['RESTAURANT_API_URL'])
    print(f'Packaged {count} restaurants and saved review evidence for offline first launch.')
    print('Public server URL configured; no pairing key was packaged.')


if __name__ == '__main__':
    main()
