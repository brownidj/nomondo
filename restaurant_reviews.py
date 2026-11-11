"""Audited human review and reversible archival, without deleting source data."""
from contextlib import closing
from datetime import datetime, timezone
import json
import hashlib
import sqlite3

from restaurant_edits import EditError, public_record, revision

REVIEW_COLUMNS = {
    'review_status': "TEXT NOT NULL DEFAULT 'pending'",
    'reviewed_at': 'TEXT',
    'review_note': "TEXT NOT NULL DEFAULT ''",
    'archived_at': 'TEXT',
}


def ensure_review_schema(db):
    columns = {row[1] for row in db.execute('PRAGMA table_info(restaurants)')}
    for name, definition in REVIEW_COLUMNS.items():
        if name not in columns:
            db.execute(f'ALTER TABLE restaurants ADD COLUMN {name} {definition}')
    db.execute('''CREATE TABLE IF NOT EXISTS restaurant_review_history (
        id INTEGER PRIMARY KEY, restaurant_id INTEGER NOT NULL, reviewed_at TEXT NOT NULL,
        decision TEXT NOT NULL, note TEXT NOT NULL,
        before_record TEXT NOT NULL, after_record TEXT NOT NULL)''')


def read_review(database, ident):
    with closing(sqlite3.connect(database.resolve().as_uri() + '?mode=ro', uri=True)) as db:
        db.row_factory = sqlite3.Row
        row = db.execute('SELECT * FROM restaurants WHERE id=?', (ident,)).fetchone()
        if row is None:
            raise EditError(404, 'Restaurant no longer exists. Refresh the list.')
        return _review_details(db, row)


def _review_details(db, row):
    ident = row['id']
    source_ids = {row['source_id']}
    source_ids.update(item[0] for item in db.execute(
        'SELECT source_id FROM consolidation_sources WHERE survivor_id=?', (ident,)))
    sources = [dict(source) for source in db.execute(
        'SELECT source_file,line_number,raw_text FROM source_lines WHERE id IN ('
        + ','.join('?' for _ in source_ids) + ') ORDER BY id', sorted(source_ids))]
    history = [dict(item) for item in db.execute('''SELECT reviewed_at,decision,note
        FROM restaurant_review_history WHERE restaurant_id=? ORDER BY id DESC''', (ident,))]
    return {'restaurant': public_record(row), 'review_reasons': json.loads(row['review_reasons']),
            'evidence': json.loads(row['evidence']), 'duplicate_ids': json.loads(row['duplicate_ids']),
            'confidence': row['confidence'], 'sources': sources, 'history': history,
            'alternatives': json.loads(row['record_history'])}


def read_offline_catalogue(database, known_version=''):
    """One read transaction keeps records and source evidence in the same snapshot."""
    with closing(sqlite3.connect(database.resolve().as_uri() + '?mode=ro', uri=True, timeout=5)) as db:
        db.row_factory = sqlite3.Row
        db.execute('BEGIN')
        rows = db.execute('SELECT * FROM restaurants ORDER BY id').fetchall()
        records = [public_record(row) for row in rows]
        reviews = {str(row['id']): _review_details(db, row) for row in rows}
        snapshot = {'restaurants': records, 'reviews': reviews}
        version = hashlib.sha256(json.dumps(snapshot, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
        if version == known_version:
            return {'version': version, 'unchanged': True}
        return {'version': version, **snapshot}


def save_review(database, ident, expected_revision, decision, note):
    if not isinstance(decision, str) or decision not in {'passed', 'failed', 'pending', 'restore'}:
        raise EditError(400, 'Choose Passed, Failed and archive, Pending, or Restore.')
    if not isinstance(note, str) or len(note) > 4000:
        raise EditError(400, 'Review notes must be text up to 4,000 characters.')
    note = note.strip()
    if decision == 'failed' and not note:
        raise EditError(400, 'Enter a reason before failing and archiving this restaurant.')
    with closing(sqlite3.connect(database.resolve().as_uri() + '?mode=rw', uri=True, timeout=5)) as db:
        db.row_factory = sqlite3.Row
        with db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT * FROM restaurants WHERE id=?', (ident,)).fetchone()
            if row is None:
                raise EditError(404, 'Restaurant no longer exists. Refresh the list.')
            if not isinstance(expected_revision, str) or revision(row) != expected_revision:
                raise EditError(409, 'This restaurant changed. Reload its review before deciding.')
            if bool(row['archived_at']) != (decision == 'restore'):
                raise EditError(409, 'Restore archived restaurants before reviewing them; only archived restaurants can be restored.')
            stamp = datetime.now(timezone.utc).isoformat()
            status = 'pending' if decision == 'restore' else decision
            db.execute('''UPDATE restaurants SET review_status=?,reviewed_at=?,review_note=?,
                archived_at=?,needs_review=? WHERE id=?''',
                (status, stamp, note, stamp if decision == 'failed' else None,
                 int(status == 'pending'), ident))
            after = db.execute('SELECT * FROM restaurants WHERE id=?', (ident,)).fetchone()
            db.execute('''INSERT INTO restaurant_review_history(
                restaurant_id,reviewed_at,decision,note,before_record,after_record)
                VALUES(?,?,?,?,?,?)''', (ident, stamp, decision, note,
                json.dumps(dict(row), ensure_ascii=False), json.dumps(dict(after), ensure_ascii=False)))
            return public_record(after)
