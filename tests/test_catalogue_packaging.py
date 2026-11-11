"""Read-only dataset packaging, with isolated SQLite fixtures."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from beneede import connect
from restaurant_additions import create_records
from restaurant_reviews import read_offline_catalogue

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/package_catalogue.py'
spec = importlib.util.spec_from_file_location('catalogue_packaging_script', SCRIPT)
packaging = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packaging)


class PackagingTests(unittest.TestCase):
    def test_package_preserves_records_evidence_and_excludes_credentials(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            database = root / 'source.sqlite3'
            with connect(database):
                pass
            create_records(database, 'package_fixture_1', [{'restaurant_name': 'Bistro', 'city': 'London', 'notes': 'Keep notes'}])
            before = read_offline_catalogue(database)
            seed, defines = root / 'seed.json', root / 'defines.json'
            count = packaging.package_catalogue(database, seed, defines, 'http://Owner-Mac.local:8766')
            self.assertEqual(count, 1)
            self.assertEqual(json.loads(seed.read_text())['restaurants'], before['restaurants'])
            self.assertEqual(json.loads(seed.read_text())['reviews'], before['reviews'])
            self.assertEqual(json.loads(defines.read_text()), {'RESTAURANT_API_URL': 'http://Owner-Mac.local:8766'})
            self.assertNotIn('RESTAURANT_API_TOKEN', seed.read_text() + defines.read_text())
            self.assertEqual(read_offline_catalogue(database), before)

    def test_public_server_url_cannot_contain_credentials_or_be_a_remote_site(self):
        for url in ['https://example.com', 'http://user:password@Owner-Mac.local:8766', 'http://127.0.0.1:8766']:
            with self.subTest(url=url), self.assertRaises(ValueError):
                packaging.package_catalogue(Path('/not-read.sqlite3'), Path('/not-written.json'), Path('/not-written-2.json'), url)
