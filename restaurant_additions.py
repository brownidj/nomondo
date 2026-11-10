"""Atomic, idempotent creation of manual and researched restaurant branches."""
from datetime import datetime, timezone
import hashlib
import json
import re
from urllib.parse import urlsplit

from beneede import connect, FIELDS, REQUIRED_FIELDS, normalized
from phone_numbers import format_telephone
from restaurant_edits import EditError, public_record
from restaurant_lookup import required_fields, city_key, country_key, branch_address_key


def meaningful(value):
    return value is not None and str(value).strip().lower() not in {'', 'not listed', 'unknown', 'n/a'}


def existing_branch(db, values):
    matches = []
    for row in db.execute('SELECT * FROM restaurants'):
        if normalized(re.sub(r'^(?:the |restaurant )', '', row['restaurant_name'], flags=re.I)) != normalized(re.sub(r'^(?:the |restaurant )', '', values['restaurant_name'], flags=re.I)) or city_key(row['city']) != city_key(values['city']):
            continue
        if meaningful(row['country']) and meaningful(values.get('country')):
            left = country_key(row['country'])
            right = country_key(values['country'])
            if left != right: continue
        old_address, new_address = row['address'], values.get('address')
        if meaningful(old_address) and meaningful(new_address):
            if branch_address_key(old_address, row['country']) == branch_address_key(new_address, values.get('country')):
                return row, []
        elif not meaningful(old_address) and not meaningful(new_address):
            if not values['restaurant_name'].startswith('Website: ') or row['internet_link'] == values.get('internet_link'):
                return row, []
        else:
            matches.append(row['id'])
    return None, matches


def create_records(database, request_id, records, lookup_id=None, lookup_result=None):
    if not isinstance(request_id, str) or not re.fullmatch(r'[A-Za-z0-9_-]{8,100}', request_id):
        raise EditError(400, 'Invalid add request ID.')
    if not isinstance(records, list) or not 1 <= len(records) <= 100:
        raise EditError(400, 'Provide between one and 100 restaurant venues.')
    if lookup_id is not None and not isinstance(lookup_id, str):
        raise EditError(400, 'Invalid lookup ID.')
    cleaned = [required_fields(record) for record in records]
    signature = hashlib.sha256(json.dumps([records, lookup_id], sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    db = connect(database)
    try:
        with db:
            db.execute('BEGIN IMMEDIATE')
            db.execute('''CREATE TABLE IF NOT EXISTS restaurant_add_requests (
                request_id TEXT PRIMARY KEY, signature TEXT NOT NULL, created_at TEXT NOT NULL,
                record_ids TEXT NOT NULL, added_ids TEXT NOT NULL, matched_ids TEXT NOT NULL,
                input_record TEXT NOT NULL)''')
            receipt = db.execute('SELECT * FROM restaurant_add_requests WHERE request_id=?', (request_id,)).fetchone()
            if receipt:
                if receipt['signature'] != signature:
                    raise EditError(409, 'This add attempt was already saved with different details. Cancel and refresh the catalogue.')
                rows = [db.execute('SELECT * FROM restaurants WHERE id=?', (ident,)).fetchone() for ident in json.loads(receipt['record_ids'])]
                return {'restaurants': [public_record(row) for row in rows if row],
                        'added_count': len(json.loads(receipt['added_ids'])), 'existing_count': len(json.loads(receipt['matched_ids']))}
            lookup = lookup_result(lookup_id) if lookup_id else None
            if lookup and len(lookup['venues']) != len(records):
                raise EditError(400, 'The lookup venues changed. Run the lookup again.')
            if not lookup and len(records) != 1:
                raise EditError(400, 'Multiple venues require a completed lookup.')
            stamp = datetime.now(timezone.utc).isoformat()
            raw = json.dumps({'entered': lookup['input'] if lookup else records[0], 'submitted': records,
                              'lookup_id': lookup_id, 'lookup_issues': lookup.get('issues', []) if lookup else [],
                              'lookup_venues': lookup['venues'] if lookup else []}, ensure_ascii=False)
            fingerprint = hashlib.sha256((request_id + '\0' + raw).encode()).hexdigest()
            cursor = db.execute('INSERT INTO source_lines(source_file,line_number,raw_text,fingerprint,extraction_status) VALUES(?,?,?,?,?)',
                                (f'manual:{request_id}', 1, raw, fingerprint, 'extracted'))
            source_id = cursor.lastrowid
            added, matched, ids = [], [], []
            for index, values in enumerate(cleaned):
                unresolved_name = not meaningful(values.get('restaurant_name'))
                if unresolved_name:
                    values['restaurant_name'] = 'Website: ' + urlsplit(values['internet_link']).hostname
                existing, possible = existing_branch(db, values)
                if existing:
                    if existing['id'] not in ids: ids.append(existing['id']); matched.append(existing['id'])
                    continue
                candidate = lookup['venues'][index] if lookup else None
                original = lookup['input'] if lookup else values
                manual = {key for key, value in original.items() if meaningful(value) and values.get(key) == value}
                if unresolved_name: manual.discard('restaurant_name')
                if candidate:
                    manual.update(key for key, value in values.items() if value != candidate['fields'].get(key)
                                  and (key in candidate['fields'] or (meaningful(value)
                                       and not (key == 'rating' and value == 0)
                                       and not (key == 'venue_status' and value == 'unknown'))))
                fields = {field: values.get(field) for field in FIELDS}
                fields['telephone'] = format_telephone(fields['telephone'], fields['country'])
                reasons = [f'Missing {field}' for field in REQUIRED_FIELDS if not meaningful(fields[field])]
                evidence = []
                confidence = None
                if candidate:
                    reasons.extend(candidate['issues']); confidence = candidate.get('confidence')
                    if confidence is None or confidence < .85: reasons.append('Low confidence in venue identity')
                    if values.get('venue_status') != 'open': reasons.append('Venue status: ' + (values.get('venue_status') or 'unknown'))
                    evidence = [entry for entry in candidate['evidence'] if entry['field'] not in manual
                                and values.get(entry['field']) == candidate['fields'].get(entry['field'])]
                if unresolved_name:
                    manual.discard('restaurant_name')
                    reasons.append('Restaurant name not yet identified from website; provisional website label')
                if possible: reasons.append('Possible duplicate: another same-name venue has incomplete address details')
                reasons = sorted(set(reasons))
                # Never reuse IDs retained in deletion history.
                max_id = db.execute('SELECT coalesce(max(id),0) FROM restaurants').fetchone()[0]
                if db.execute("SELECT 1 FROM sqlite_master WHERE name='restaurant_deletion_history'").fetchone():
                    max_id = max(max_id, db.execute('SELECT coalesce(max(restaurant_id),0) FROM restaurant_deletion_history').fetchone()[0])
                ident = max_id + 1
                extras = {'id': ident, 'source_id': source_id, 'entry_index': index,
                          'rating': values.get('rating', 0), 'venue_status': values.get('venue_status') or 'unknown',
                          'needs_review': int(bool(reasons)), 'review_reasons': json.dumps(reasons),
                          'duplicate_ids': json.dumps(possible), 'confidence': confidence,
                          'evidence': json.dumps(evidence, ensure_ascii=False), 'manual_fields': json.dumps(sorted(manual)),
                          'enrichment_status': 'completed' if candidate else 'pending', 'extracted_at': stamp,
                          'extraction_model': 'manual-add', 'enriched_at': stamp if candidate else None,
                          'enrichment_model': lookup['audits'][0]['model'] if lookup and lookup['audits'] else ('website-jsonld' if candidate else None)}
                data = {**fields, **extras}
                db.execute('INSERT INTO restaurants('+','.join(data)+') VALUES('+','.join('?' for _ in data)+')', list(data.values()))
                added.append(ident); ids.append(ident)
            if lookup:
                for audit in lookup['audits']:
                    db.execute('INSERT INTO api_runs(phase,model,response_id,created_at,payload) VALUES(?,?,?,?,?)',
                               ('add_lookup', audit['model'], audit['id'], stamp, audit['payload']))
            db.execute('INSERT INTO restaurant_add_requests VALUES(?,?,?,?,?,?,?)',
                       (request_id, signature, stamp, json.dumps(ids), json.dumps(added), json.dumps(matched), raw))
            return {'restaurants': [public_record(db.execute('SELECT * FROM restaurants WHERE id=?', (ident,)).fetchone()) for ident in ids],
                    'added_count': len(added), 'existing_count': len(matched)}
    finally:
        db.close()
