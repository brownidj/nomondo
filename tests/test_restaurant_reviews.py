"""Manual-only review/archival regressions, with temporary catalogues."""
from pathlib import Path
import json
import tempfile
import unittest

from beneede import connect
from restaurant_edits import EditError, revision, save_edit
from restaurant_reviews import read_review, save_review, read_offline_catalogue


class RestaurantReviewTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.path = Path(self.temporary.name) / 'restaurants.sqlite3'
        self.db = connect(self.path)
        self.addCleanup(self.db.close)
        with self.db:
            self.db.execute("INSERT INTO source_lines(id,source_file,line_number,raw_text,fingerprint) VALUES(1,'original.txt',1,'Original restaurant notes','unique')")
            self.db.execute('''INSERT INTO restaurants(id,source_id,entry_index,restaurant_name,
                city,country,notes,rating,review_reasons,evidence,extracted_at)
                VALUES(1,1,0,'Example','London','United Kingdom','Preserve this',8,?,?, '2026-11-10')''',
                (json.dumps(['Venue status: closed', 'Missing address']), json.dumps([
                    {'field': 'internet_link', 'url': 'https://example.com', 'detail': 'Official website'}])))
        self.before = dict(self.db.execute('SELECT * FROM restaurants').fetchone())
        self.revision = revision(self.before)

    def test_modal_data_contains_flags_and_original_evidence(self):
        details = read_review(self.path, 1)
        self.assertEqual(details['review_reasons'], ['Venue status: closed', 'Missing address'])
        self.assertEqual(details['sources'][0]['raw_text'], 'Original restaurant notes')
        self.assertEqual(details['evidence'][0]['url'], 'https://example.com')
        self.assertEqual(details['history'], [])

    def test_offline_snapshot_contains_matching_records_and_evidence(self):
        snapshot = read_offline_catalogue(self.path)
        self.assertEqual(snapshot['restaurants'][0], snapshot['reviews']['1']['restaurant'])
        self.assertEqual(snapshot['reviews']['1']['sources'][0]['raw_text'], 'Original restaurant notes')
        self.assertEqual(read_offline_catalogue(self.path, snapshot['version']),
                         {'version': snapshot['version'], 'unchanged': True})

    def test_offline_snapshot_detects_source_changes_and_deleted_records(self):
        before = read_offline_catalogue(self.path)
        with self.db:
            self.db.execute("UPDATE source_lines SET raw_text='Corrected source notes' WHERE id=1")
        changed = read_offline_catalogue(self.path, before['version'])
        self.assertNotEqual(changed['version'], before['version'])
        self.assertEqual(changed['reviews']['1']['sources'][0]['raw_text'], 'Corrected source notes')
        with self.db:
            self.db.execute('DELETE FROM restaurants WHERE id=1')
        empty = read_offline_catalogue(self.path, changed['version'])
        self.assertEqual(empty['restaurants'], [])
        self.assertEqual(empty['reviews'], {})

    def test_pass_clears_queue_without_erasing_flags_or_user_data(self):
        result = save_review(self.path, 1, self.revision, 'passed', 'Confirmed details')
        self.assertEqual(result['review_status'], 'passed')
        self.assertEqual(result['needs_review'], 0)
        after = dict(self.db.execute('SELECT * FROM restaurants').fetchone())
        for key in ('notes', 'rating', 'evidence', 'review_reasons', 'source_id', 'address'):
            self.assertEqual(after[key], self.before[key])
        history = self.db.execute('SELECT * FROM restaurant_review_history').fetchone()
        self.assertEqual(json.loads(history['before_record']), self.before)

    def test_fail_archives_and_restore_retains_same_record_and_sources(self):
        archived = save_review(self.path, 1, self.revision, 'failed', 'Wrong restaurant identity')
        self.assertIsNotNone(archived['archived_at'])
        self.assertEqual(archived['review_status'], 'failed')
        self.assertEqual(self.db.execute('SELECT count(*) FROM restaurants').fetchone()[0], 1)
        restored = save_review(self.path, 1, archived['revision'], 'restore', 'Recheck this venue')
        self.assertIsNone(restored['archived_at'])
        self.assertEqual(restored['review_status'], 'pending')
        self.assertEqual(restored['needs_review'], 1)
        self.assertEqual(restored['id'], 1)
        self.assertEqual(restored['notes'], self.before['notes'])
        self.assertEqual(self.db.execute('SELECT raw_text FROM source_lines').fetchone()[0], 'Original restaurant notes')
        self.assertEqual([item['decision'] for item in read_review(self.path, 1)['history']], ['restore', 'failed'])

    def test_failure_requires_reason_and_stale_decision_does_not_overwrite_edit(self):
        with self.assertRaises(EditError):
            save_review(self.path, 1, self.revision, 'failed', ' ')
        save_edit(self.path, 1, self.revision, {'city': 'Paris'})
        with self.assertRaises(EditError) as error:
            save_review(self.path, 1, self.revision, 'passed', '')
        self.assertEqual(error.exception.status, 409)
        self.assertEqual(self.db.execute('SELECT review_status FROM restaurants').fetchone()[0], 'pending')
        self.assertEqual(self.db.execute('SELECT count(*) FROM restaurant_review_history').fetchone()[0], 0)

    def test_changing_a_passed_record_returns_it_to_pending(self):
        passed = save_review(self.path, 1, self.revision, 'passed', '')
        updated = save_edit(self.path, 1, passed['revision'], {'city': 'Paris'})
        self.assertEqual(updated['review_status'], 'pending')
        self.assertEqual(updated['needs_review'], 1)

    def test_archived_record_must_be_restored_before_another_decision(self):
        archived = save_review(self.path, 1, self.revision, 'failed', 'Incorrect match')
        with self.assertRaises(EditError):
            save_review(self.path, 1, archived['revision'], 'passed', '')
        self.assertEqual(self.db.execute('SELECT review_status FROM restaurants').fetchone()[0], 'failed')
