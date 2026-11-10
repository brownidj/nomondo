"""Offline GeoNames city completion; separate from the restaurant catalogue."""
import argparse
from contextlib import closing
from datetime import datetime, timezone
import io
import json
from pathlib import Path
import sqlite3
import tempfile
import unicodedata
from urllib.request import urlopen
import zipfile

from country_names import country_code, full_country_name

ROOT = Path(__file__).resolve().parent
DEFAULT_INDEX = ROOT / 'data' / 'cities.sqlite3'
SOURCE = 'https://download.geonames.org/export/dump/'
ATTRIBUTION = 'GeoNames, CC BY 4.0 — https://www.geonames.org/'
UK_PARTS = {'ENG': 'England', 'SCT': 'Scotland', 'WLS': 'Wales', 'NIR': 'Northern Ireland'}


def search_key(value):
    decomposed = unicodedata.normalize('NFKD', value.casefold())
    return ' '.join(''.join(c for c in decomposed if not unicodedata.combining(c)).split())


def build_index(archive, admin_file, destination=DEFAULT_INDEX):
    """Build atomically from a downloaded snapshot, retaining names/aliases."""
    admins = {}
    for line in Path(admin_file).read_text(encoding='utf-8').splitlines():
        columns = line.split('\t')
        if len(columns) >= 2:
            admins[columns[0]] = columns[1]
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=destination.parent) as temporary:
        target = Path(temporary) / 'cities.sqlite3'
        with closing(sqlite3.connect(target)) as db, zipfile.ZipFile(archive) as zipped:
            db.executescript('''
                CREATE TABLE cities(id INTEGER PRIMARY KEY, name TEXT NOT NULL,
                    country_code TEXT NOT NULL, country TEXT NOT NULL, region TEXT NOT NULL,
                    population INTEGER NOT NULL, name_key TEXT NOT NULL);
                CREATE TABLE names(name_key TEXT NOT NULL, city_id INTEGER NOT NULL,
                    PRIMARY KEY(name_key, city_id)) WITHOUT ROWID;
                CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            ''')
            with zipped.open('cities1000.txt') as raw:
                for line in io.TextIOWrapper(raw, encoding='utf-8'):
                    row = line.rstrip('\n').split('\t')
                    if len(row) != 19 or row[6] != 'P' or not row[8]:
                        continue
                    ident, name, code, admin = int(row[0]), row[1], row[8], row[10]
                    country = full_country_name(code)
                    if code == 'GB' and admin in UK_PARTS:
                        country = full_country_name(UK_PARTS[admin])
                    region = admins.get(f'{code}.{admin}', '')
                    db.execute('INSERT INTO cities VALUES(?,?,?,?,?,?,?)',
                               (ident, name, code, country, region, int(row[14] or 0), search_key(name)))
                    keys = {search_key(alias) for alias in [name, row[2], *row[3].split(',')] if alias.strip()}
                    db.executemany('INSERT OR IGNORE INTO names VALUES(?,?)', ((key, ident) for key in keys))
            count = db.execute('SELECT count(*) FROM cities').fetchone()[0]
            if not count:
                raise ValueError('The GeoNames archive contained no cities; existing index was preserved.')
            db.executemany('INSERT INTO metadata VALUES(?,?)', [
                ('source', SOURCE + 'cities1000.zip'), ('attribution', ATTRIBUTION),
                ('built_at', datetime.now(timezone.utc).isoformat()), ('cities', str(count)),
            ])
            db.commit()
        target.replace(destination)
    return count


def suggest_cities(query, country='', index=DEFAULT_INDEX, limit=12):
    key = search_key(query.strip())
    if len(key) < 2 or len(key) > 80 or not Path(index).exists():
        return []
    code = country_code(country)
    canonical_country = full_country_name(country)
    conditions = ['n.name_key >= ?', 'n.name_key < ?']
    params = [key, key + '\U0010ffff']
    if code:
        conditions.append('c.country_code = ?')
        params.append(code)
    if canonical_country in {full_country_name(part) for part in UK_PARTS.values()}:
        conditions.append('c.country = ?')
        params.append(canonical_country)
    with closing(sqlite3.connect(Path(index).resolve().as_uri() + '?mode=ro', uri=True)) as db:
        db.row_factory = sqlite3.Row
        rows = db.execute('''SELECT c.id, c.name, c.country_code, c.country, c.region,
                max(n.name_key = ?) AS exact
            FROM names n JOIN cities c ON c.id = n.city_id
            WHERE ''' + ' AND '.join(conditions) + '''
            GROUP BY c.id ORDER BY exact DESC, c.population DESC, c.name, c.id LIMIT ?''',
                          [key, *params, min(20, max(1, limit))]).fetchall()
    return [{field: row[field] for field in ('id', 'name', 'country_code', 'country', 'region')} for row in rows]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download', action='store_true', help='Download the current GeoNames snapshot and build the local index')
    parser.add_argument('--archive', type=Path, help='Saved cities1000.zip')
    parser.add_argument('--admins', type=Path, help='Saved admin1CodesASCII.txt')
    parser.add_argument('--output', type=Path, default=DEFAULT_INDEX)
    args = parser.parse_args()
    if args.download:
        with tempfile.TemporaryDirectory() as temporary:
            files = []
            for name in ('cities1000.zip', 'admin1CodesASCII.txt'):
                path = Path(temporary) / name
                with urlopen(SOURCE + name, timeout=45) as response, path.open('wb') as output:
                    while chunk := response.read(1024 * 1024):
                        output.write(chunk)
                files.append(path)
            count = build_index(*files, args.output)
    elif args.archive and args.admins:
        count = build_index(args.archive, args.admins, args.output)
    else:
        parser.error('Use --download, or provide --archive and --admins.')
    print(json.dumps({'cities': count, 'index': str(args.output), 'attribution': ATTRIBUTION}))


if __name__ == '__main__':
    main()
