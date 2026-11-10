"""Apply an explicitly reviewed duplicate plan, with reversible, lossless history."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sqlite3
import unicodedata

DETAILS = ('restaurant_name', 'venue_type', 'city', 'region', 'country', 'address',
           'telephone', 'internet_link', 'cuisine', 'special_dish', 'notes', 'historical_ranking')
COMBINE = ('cuisine', 'special_dish', 'notes', 'historical_ranking')


def meaningful(value):
    return value is not None and str(value).strip().lower() not in {'', 'not listed', 'unknown', 'n/a'}


def normalized(value):
    return ' '.join(unicodedata.normalize('NFKC', str(value or '')).casefold().split())


def score(row):
    values = [str(row[field]) for field in DETAILS if meaningful(row.get(field))]
    return len(values), sum(len(value) for value in values), -row['id']


def fingerprint(row):
    return hashlib.sha256(json.dumps(row, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def union(values):
    result = []
    for value in values:
        if value not in result:
            result.append(value)
    return result


def merge_records(rows, sources):
    ordered = sorted(rows, key=score, reverse=True)
    result = dict(ordered[0])
    history = []
    for row in ordered:
        history.extend(json.loads(row.get('record_history') or '[]'))
        history.append({'record': dict(row), 'source': sources[row['source_id']]})
    # Full exact inputs, including conflicting metadata, are part of the survivor.
    result['record_history'] = json.dumps(union(history), ensure_ascii=False)
    for field in DETAILS:
        if not meaningful(result.get(field)):
            result[field] = next((row[field] for row in ordered if meaningful(row.get(field))), result.get(field))
    for field in COMBINE:
        values = []
        for row in ordered:
            if meaningful(row.get(field)) and normalized(row[field]) not in [normalized(v) for v in values]:
                values.append(row[field])
        if values:
            result[field] = '\n\n'.join(values)
    phones = union(part.strip() for row in ordered if meaningful(row.get('telephone'))
                   for part in row['telephone'].split(' / '))
    if phones:
        result['telephone'] = ' / '.join(phones)
    variants = []
    for row in ordered[1:]:
        for field in (*DETAILS, 'rating', 'venue_status', 'confidence'):
            if field in (*COMBINE, 'telephone') or not meaningful(row.get(field)):
                continue
            if normalized(row[field]) != normalized(result.get(field)):
                variants.append(f"{field.replace('_', ' ').title()} (record #{row['id']}): {row[field]}")
    if variants:
        result['notes'] = '\n\n'.join(v for v in (result.get('notes'), 'Preserved alternative details:\n' + '\n'.join(union(variants))) if v)
    result['evidence'] = json.dumps(union(item for row in ordered for item in json.loads(row['evidence'])), ensure_ascii=False)
    reasons = union(reason for row in ordered for reason in json.loads(row['review_reasons']) if reason != 'Possible duplicate')
    if variants:
        reasons = union([*reasons, 'Consolidated record has preserved alternative details to review'])
    result['review_reasons'] = json.dumps(reasons, ensure_ascii=False)
    result['needs_review'] = int(bool(reasons) or any(row['needs_review'] and not json.loads(row['review_reasons']) for row in ordered))
    result['duplicate_ids'] = '[]'
    return result


def apply_plan(database, plan_path):
    plan = json.loads(plan_path.read_text())
    groups = plan['groups']
    ids = [ident for group in groups for ident in group['ids']]
    if len(ids) != len(set(ids)) or any(len(g['ids']) < 2 for g in groups):
        raise ValueError('Groups must be disjoint and contain at least two records')
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup = database.parent / 'backups' / f'restaurants-before-consolidation-{stamp}.sqlite3'
    backup.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(database)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys=ON')
    try:
        db.execute('BEGIN IMMEDIATE')
        before = {row['id']: dict(row) for row in db.execute('SELECT * FROM restaurants')}
        for ident in ids:
            if ident not in before or fingerprint(before[ident]) != plan['fingerprints'][str(ident)]:
                raise ValueError(f'Record {ident} changed since review; regenerate plan')
        # A separate read connection backs up the locked, committed input snapshot.
        with sqlite3.connect(database.resolve().as_uri() + '?mode=ro', uri=True) as source, sqlite3.connect(backup) as target:
            source.backup(target)
        sources = {row['id']: dict(row) for row in db.execute('SELECT * FROM source_lines')}
        source_count, api_count = len(sources), db.execute('SELECT count(*) FROM api_runs').fetchone()[0]
        if 'record_history' not in next(iter(before.values())):
            db.execute("ALTER TABLE restaurants ADD COLUMN record_history TEXT NOT NULL DEFAULT '[]'")
        db.execute('''CREATE TABLE IF NOT EXISTS consolidation_history (
            id INTEGER PRIMARY KEY, merged_at TEXT NOT NULL, survivor_id INTEGER NOT NULL,
            reason TEXT NOT NULL, original_records TEXT NOT NULL)''')
        db.execute('''CREATE TABLE IF NOT EXISTS consolidation_sources (
            source_id INTEGER NOT NULL REFERENCES source_lines(id), entry_index INTEGER NOT NULL,
            survivor_id INTEGER NOT NULL REFERENCES restaurants(id),
            PRIMARY KEY(source_id,entry_index))''')
        report = []
        mapping = {}
        for group in groups:
            rows = [before[ident] for ident in group['ids']]
            merged = merge_records(rows, sources)
            winner = merged['id']
            db.execute('INSERT INTO consolidation_history(merged_at,survivor_id,reason,original_records) VALUES(?,?,?,?)',
                       (stamp, winner, group['reason'], merged['record_history']))
            fields = [key for key in merged if key != 'id']
            db.execute('UPDATE restaurants SET ' + ','.join(f'{field}=?' for field in fields) + ' WHERE id=?',
                       [merged[field] for field in fields] + [winner])
            removed = [row['id'] for row in rows if row['id'] != winner]
            for ident in removed:
                db.execute('UPDATE consolidation_sources SET survivor_id=? WHERE survivor_id=?', (winner, ident))
            for row in rows:
                db.execute('INSERT INTO consolidation_sources(source_id,entry_index,survivor_id) VALUES(?,?,?) '
                           'ON CONFLICT(source_id,entry_index) DO UPDATE SET survivor_id=excluded.survivor_id',
                           (row['source_id'], row['entry_index'], winner))
            db.executemany('DELETE FROM restaurants WHERE id=?', [(ident,) for ident in removed])
            mapping.update({ident: winner for ident in removed})
            saved = json.loads(db.execute('SELECT record_history FROM restaurants WHERE id=?', (winner,)).fetchone()[0])
            if any({'record': row, 'source': sources[row['source_id']]} not in saved for row in rows):
                raise ValueError('Exact source-record preservation failed')
            report.append({'survivor': winner, 'name': merged['restaurant_name'], 'removed': removed,
                           'scores': {str(row['id']): score(row) for row in rows}})
        # Redirect/remove stale duplicate pointers, without changing unrelated records.
        for row in db.execute('SELECT id,duplicate_ids,review_reasons,needs_review FROM restaurants').fetchall():
            peers = union(mapping.get(ident, ident) for ident in json.loads(row['duplicate_ids']))
            peers = [ident for ident in peers if ident != row['id']]
            if peers != json.loads(row['duplicate_ids']):
                reasons = json.loads(row['review_reasons'])
                if not peers:
                    reasons = [reason for reason in reasons if reason != 'Possible duplicate']
                db.execute('UPDATE restaurants SET duplicate_ids=?,review_reasons=?,needs_review=? WHERE id=?',
                           (json.dumps(peers), json.dumps(reasons), int(bool(reasons)), row['id']))
        after = {row['id']: dict(row) for row in db.execute('SELECT * FROM restaurants')}
        if len(after) != len(before) - len(mapping):
            raise ValueError('Unexpected record count')
        for ident in set(before) - set(ids):
            if any(after[ident][key] != value for key, value in before[ident].items()):
                raise ValueError(f'Unrelated record {ident} changed')
        if len(sources) != db.execute('SELECT count(*) FROM source_lines').fetchone()[0] or api_count != db.execute('SELECT count(*) FROM api_runs').fetchone()[0]:
            raise ValueError('Source/API history changed')
        if db.execute('PRAGMA foreign_key_check').fetchall() or db.execute('PRAGMA quick_check').fetchone()[0] != 'ok':
            raise ValueError('Database integrity check failed')
        db.commit()
        result = {'backup': str(backup), 'before': len(before), 'after': len(after),
                  'removed': len(mapping), 'groups': report, 'source_lines': source_count, 'api_runs': api_count}
        path = backup.with_suffix('.json')
        path.write_text(json.dumps(result, ensure_ascii=False, indent=2))
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except BaseException:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=Path, required=True)
    parser.add_argument('--plan', type=Path, required=True)
    args = parser.parse_args()
    if not args.db.is_file():
        parser.error('Database not found')
    apply_plan(args.db, args.plan)
