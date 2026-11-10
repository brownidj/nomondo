"""Run manually; all edits use isolated temporary databases."""
from email.message import Message
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock

from beneede import connect
from restaurant_edits import EditError, public_record, save_edit
from restaurant_server import RestaurantHandler


class EditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'restaurants.sqlite3'
        self.db = connect(self.path)
        self.addCleanup(self.db.close)
        with self.db:
            self.db.execute("INSERT INTO source_lines(id,source_file,line_number,raw_text,fingerprint) VALUES(1,'original.txt',1,'Original source','one')")
            self.db.execute("""INSERT INTO restaurants(id,source_id,entry_index,restaurant_name,city,country,notes,
                rating,extracted_at,record_history,evidence) VALUES(1,1,0,'Original','London','UK','Keep notes',4,
                'original-date','[{"record":{"id":99}}]','[{"field":"city","url":"original"}]')""")
        self.original = dict(self.db.execute('SELECT * FROM restaurants').fetchone())
        self.revision = public_record(self.original)['revision']

    def test_edit_preserves_original_and_other_fields(self):
        result = save_edit(self.path, 1, self.revision, {'city': 'Paris', 'country': 'France'})
        self.assertEqual(result['city'], 'Paris')
        after = dict(self.db.execute('SELECT * FROM restaurants').fetchone())
        for key in ('id','source_id','entry_index','notes','rating','record_history','evidence'):
            self.assertEqual(after[key], self.original[key])
        history = self.db.execute('SELECT before_record,after_record FROM restaurant_edit_history').fetchone()
        self.assertEqual(json.loads(history['before_record']), self.original)
        self.assertEqual(json.loads(history['after_record']), after)
        self.assertEqual(self.db.execute('SELECT raw_text FROM source_lines').fetchone()[0], 'Original source')

    def test_optional_clear_is_explicit_and_protected(self):
        save_edit(self.path, 1, self.revision, {'notes': None})
        after = self.db.execute('SELECT * FROM restaurants').fetchone()
        self.assertIsNone(after['notes'])
        self.assertIn('notes', json.loads(after['manual_fields']))
        self.assertEqual(after['city'], 'London')

    def test_stale_edit_cannot_overwrite_newer_save(self):
        save_edit(self.path, 1, self.revision, {'city': 'Paris'})
        with self.assertRaises(EditError) as error:
            save_edit(self.path, 1, self.revision, {'city': 'Rome'})
        self.assertEqual(error.exception.status, 409)
        self.assertEqual(self.db.execute('SELECT city FROM restaurants').fetchone()[0], 'Paris')

    def test_invalid_fields_and_names_do_not_write(self):
        for changes in ({'id': 10}, {'source_id': 2}, {'restaurant_name': ''}, {'rating': -1},
                        {'internet_link': 'javascript:alert(1)'}, {'notes': ['wrong type']}):
            with self.subTest(changes=changes), self.assertRaises(EditError):
                save_edit(self.path, 1, self.revision, changes)
        self.assertEqual(dict(self.db.execute('SELECT * FROM restaurants').fetchone()), self.original)

    def test_foreign_browser_origin_cannot_edit(self):
        handler = object.__new__(RestaurantHandler)
        handler.headers = Message()
        handler.headers['Origin'] = 'https://foreign.example'
        handler.headers['Host'] = '127.0.0.1:8765'
        handler.respond = Mock()
        handler.do_PATCH()
        self.assertEqual(handler.respond.call_args.args[0], 403)

    def test_delete_archives_record_and_sources(self):
        from restaurant_edits import delete_record
        with self.db:
            self.db.execute("INSERT INTO consolidation_sources VALUES(1,0,1)")
        delete_record(self.path, 1, self.revision)
        self.assertEqual(self.db.execute('SELECT count(*) FROM restaurants').fetchone()[0], 0)
        archive = self.db.execute('SELECT * FROM restaurant_deletion_history').fetchone()
        self.assertEqual(json.loads(archive['original_record']), self.original)
        self.assertEqual(json.loads(archive['source_links'])[0]['source']['raw_text'], 'Original source')
        self.assertEqual(self.db.execute('SELECT count(*) FROM consolidation_sources').fetchone()[0], 0)
        self.assertEqual(self.db.execute('SELECT source_id FROM deleted_restaurant_sources').fetchone()[0], 1)
        self.assertEqual(self.db.execute('SELECT count(*) FROM source_lines').fetchone()[0], 1)
        self.assertFalse(self.db.execute('PRAGMA foreign_key_check').fetchall())

    def test_stale_delete_does_not_remove_changed_record(self):
        from restaurant_edits import delete_record
        save_edit(self.path, 1, self.revision, {'city': 'Paris'})
        with self.assertRaises(EditError) as error:
            delete_record(self.path, 1, self.revision)
        self.assertEqual(error.exception.status, 409)
        self.assertEqual(self.db.execute('SELECT city FROM restaurants').fetchone()[0], 'Paris')

    def test_http_delete_requires_explicit_confirmation(self):
        import io
        from unittest.mock import patch
        body = json.dumps({'revision': self.revision, 'confirmed': False}).encode()
        handler = object.__new__(RestaurantHandler)
        handler.headers = Message()
        for key, value in {'Host': '127.0.0.1:8765', 'Content-Type': 'application/json',
                           'X-BeneEde-Edit': '1', 'Content-Length': str(len(body))}.items():
            handler.headers[key] = value
        handler.path = '/api/restaurants/1'
        handler.rfile = io.BytesIO(body)
        handler.respond = Mock()
        with patch('restaurant_server.delete_record') as delete:
            handler.do_DELETE()
            delete.assert_not_called()
        self.assertEqual(handler.respond.call_args.args[0], 400)
