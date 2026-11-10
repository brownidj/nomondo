"""Validated, audited local edits with optimistic concurrency control."""
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import sqlite3
from urllib.parse import urlsplit

from phone_numbers import format_telephone
from country_names import full_country_name
from restaurant_names import clean_restaurant_name

EDIT_FIELDS = ('restaurant_name', 'city', 'country', 'address', 'telephone',
               'internet_link', 'cuisine', 'special_dish', 'notes', 'region',
               'venue_type', 'historical_ranking', 'rating', 'venue_status')


class EditError(ValueError):
    def __init__(self, status, message):
        self.status = status
        super().__init__(message)


def revision(row):
    return hashlib.sha256(json.dumps(dict(row), sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def public_record(row):
    fields = ('id', *EDIT_FIELDS, 'needs_review', 'confidence')
    result = {field: row[field] for field in fields}
    result['revision'] = revision(row)
    result['telephone'] = format_telephone(result['telephone'], result['country'])
    for field, default in (('review_status', 'pending'), ('reviewed_at', None),
                           ('review_note', ''), ('archived_at', None)):
        result[field] = row[field] if field in row.keys() else default
    return result


def validate_changes(changes):
    if not isinstance(changes, dict) or not changes or set(changes) - set(EDIT_FIELDS):
        raise EditError(400, 'Only editable restaurant fields can be changed.')
    cleaned = {}
    for field, value in changes.items():
        if field == 'rating':
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                raise EditError(400, 'Rating must be a non-negative number.')
        else:
            if value is not None and not isinstance(value, str):
                raise EditError(400, f'Invalid value for {field}.')
            value = value.strip() or None if isinstance(value, str) else None
            if value is not None and len(value) > 100000:
                raise EditError(400, f'{field} is too long.')
            if field == 'restaurant_name':
                value = clean_restaurant_name(value)
            if field == 'restaurant_name' and not value:
                raise EditError(400, 'Restaurant name is required.')
            if field == 'venue_status' and value not in {'open', 'closed', 'renamed', 'unknown'}:
                raise EditError(400, 'Choose a valid venue status.')
            if field == 'internet_link' and value and value.lower() != 'not listed':
                if '://' not in value:
                    value = 'https://' + value
                try:
                    parsed = urlsplit(value)
                    valid = parsed.scheme in {'http', 'https'} and parsed.hostname and not parsed.username and not parsed.password
                    parsed.port
                except ValueError:
                    valid = False
                if not valid:
                    raise EditError(400, 'Website must be an HTTP or HTTPS address.')
        cleaned[field] = full_country_name(value) if field == 'country' else value
    return cleaned


def save_edit(database: Path, ident: int, expected_revision: str, changes: dict):
    cleaned = validate_changes(changes)
    with closing(sqlite3.connect(database.resolve().as_uri() + '?mode=rw', uri=True, timeout=5)) as db:
        db.row_factory = sqlite3.Row
        with db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT * FROM restaurants WHERE id=?', (ident,)).fetchone()
            if row is None:
                raise EditError(404, 'Restaurant no longer exists. Refresh the list.')
            if not isinstance(expected_revision, str) or revision(row) != expected_revision:
                raise EditError(409, 'This record changed. Cancel, refresh the list and reopen the editor.')
            before = dict(row)
            if 'manual_fields' not in before:
                db.execute("ALTER TABLE restaurants ADD COLUMN manual_fields TEXT NOT NULL DEFAULT '[]'")
            if 'telephone' in cleaned or 'country' in cleaned:
                phone = cleaned.get('telephone', row['telephone'])
                cleaned['telephone'] = format_telephone(phone, cleaned.get('country', row['country']))
            changes = {field: value for field, value in cleaned.items() if value != row[field]}
            if not changes:
                return public_record(db.execute('SELECT * FROM restaurants WHERE id=?', (ident,)).fetchone())
            db.execute('''CREATE TABLE IF NOT EXISTS restaurant_edit_history (
                id INTEGER PRIMARY KEY, restaurant_id INTEGER NOT NULL, edited_at TEXT NOT NULL,
                before_record TEXT NOT NULL, after_record TEXT NOT NULL, changed_fields TEXT NOT NULL)''')
            manual = sorted(set(json.loads(before.get('manual_fields') or '[]')) | set(changes))
            db.execute('UPDATE restaurants SET ' + ','.join(f'{field}=?' for field in changes)
                       + ',manual_fields=? WHERE id=?', [*changes.values(), json.dumps(manual), ident])
            if before.get('review_status') == 'passed':
                db.execute("UPDATE restaurants SET review_status='pending',needs_review=1 WHERE id=?", (ident,))
            after = db.execute('SELECT * FROM restaurants WHERE id=?', (ident,)).fetchone()
            db.execute('INSERT INTO restaurant_edit_history(restaurant_id,edited_at,before_record,after_record,changed_fields) VALUES(?,?,?,?,?)',
                       (ident, datetime.now(timezone.utc).isoformat(), json.dumps(before, ensure_ascii=False),
                        json.dumps(dict(after), ensure_ascii=False), json.dumps(list(changes))))
            return public_record(after)


def delete_record(database: Path, ident: int, expected_revision: str):
    """Archive a confirmed record and source mappings before removing its active row."""
    with closing(sqlite3.connect(database.resolve().as_uri() + '?mode=rw', uri=True, timeout=5)) as db:
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA foreign_keys=ON')
        with db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT * FROM restaurants WHERE id=?', (ident,)).fetchone()
            if row is None:
                raise EditError(404, 'Restaurant no longer exists. Cancel and refresh the list.')
            if not isinstance(expected_revision, str) or revision(row) != expected_revision:
                raise EditError(409, 'This record changed. Cancel, refresh and reopen it before deleting.')
            db.execute('''CREATE TABLE IF NOT EXISTS restaurant_deletion_history (
                id INTEGER PRIMARY KEY, restaurant_id INTEGER NOT NULL, deleted_at TEXT NOT NULL,
                original_record TEXT NOT NULL, source_links TEXT NOT NULL)''')
            db.execute('''CREATE TABLE IF NOT EXISTS deleted_restaurant_sources (
                source_id INTEGER NOT NULL REFERENCES source_lines(id), entry_index INTEGER NOT NULL,
                restaurant_id INTEGER NOT NULL, deleted_at TEXT NOT NULL,
                PRIMARY KEY(source_id,entry_index))''')
            links = {(row['source_id'], row['entry_index'])}
            has_consolidation = db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='consolidation_sources'").fetchone()
            if has_consolidation:
                links.update((link['source_id'], link['entry_index']) for link in db.execute(
                    'SELECT * FROM consolidation_sources WHERE survivor_id=?', (ident,)))
            sources = []
            stamp = datetime.now(timezone.utc).isoformat()
            for source_id, entry_index in sorted(links):
                source = db.execute('SELECT * FROM source_lines WHERE id=?', (source_id,)).fetchone()
                sources.append({'source_id': source_id, 'entry_index': entry_index,
                                'source': dict(source) if source else None})
                db.execute('INSERT OR REPLACE INTO deleted_restaurant_sources VALUES(?,?,?,?)',
                           (source_id, entry_index, ident, stamp))
            db.execute('INSERT INTO restaurant_deletion_history(restaurant_id,deleted_at,original_record,source_links) VALUES(?,?,?,?)',
                       (ident, stamp, json.dumps(dict(row), ensure_ascii=False), json.dumps(sources, ensure_ascii=False)))
            if has_consolidation:
                db.execute('DELETE FROM consolidation_sources WHERE survivor_id=?', (ident,))
            db.execute('DELETE FROM restaurants WHERE id=?', (ident,))
            for peer in db.execute('SELECT id,duplicate_ids,review_reasons FROM restaurants').fetchall():
                original = json.loads(peer['duplicate_ids'])
                remaining = [value for value in original if value != ident]
                if original != remaining:
                    reasons = json.loads(peer['review_reasons'])
                    if not remaining:
                        reasons = [reason for reason in reasons if reason != 'Possible duplicate']
                    db.execute('UPDATE restaurants SET duplicate_ids=?,review_reasons=?,needs_review=? WHERE id=?',
                               (json.dumps(remaining), json.dumps(reasons), int(bool(reasons)), peer['id']))
