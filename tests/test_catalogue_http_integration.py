"""Real HTTP + SQLite flows using isolated temporary catalogues, never live data."""
import json
from pathlib import Path
import tempfile
from threading import Thread
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from restaurant_additions import create_records
from restaurant_server import RestaurantServer


class CatalogueHttpIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.database = Path(self.directory.name) / 'catalogue.sqlite3'
        self.server = RestaurantServer(0, self.database)
        self.thread = Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop_server)
        self.port = self.server.server_address[1]
        result = create_records(self.database, 'fixture_request_1', [{
            'restaurant_name': 'Test Bistro', 'city': 'London', 'country': 'United Kingdom',
            'notes': 'Keep original notes', 'cuisine': 'French',
        }])
        self.restaurant = result['restaurants'][0]

    def stop_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)

    def request(self, method, path, payload=None):
        body = None if payload is None else json.dumps(payload).encode()
        request = Request(f'http://127.0.0.1:{self.port}{path}', method=method, data=body,
                          headers={'Content-Type': 'application/json', 'X-BeneEde-Edit': '1'})
        try:
            response = urlopen(request, timeout=10)
        except HTTPError as error:
            response = error
        with response:
            return response.status, json.load(response)

    def test_two_clients_conflict_and_preserve_the_first_edit_and_original_sources(self):
        _, alice = self.request('GET', '/api/offline-catalogue')
        _, bob = self.request('GET', '/api/offline-catalogue')
        first = alice['restaurants'][0]
        second = bob['restaurants'][0]
        path = f"/api/restaurants/{first['id']}"
        status, saved = self.request('PATCH', path, {
            'revision': first['revision'], 'changes': {'notes': 'Alice reviewed this venue'}})
        self.assertEqual(status, 200)
        status, error = self.request('PATCH', path, {
            'revision': second['revision'], 'changes': {'notes': 'Bob was offline'}})
        self.assertEqual(status, 409)
        self.assertIn('error', error)
        _, snapshot = self.request('GET', '/api/offline-catalogue')
        self.assertEqual(snapshot['restaurants'][0]['notes'], 'Alice reviewed this venue')
        evidence = snapshot['reviews'][str(first['id'])]
        self.assertEqual(evidence['restaurant']['revision'], saved['restaurant']['revision'])
        self.assertIn('Keep original notes', evidence['sources'][0]['raw_text'])

    def test_repeated_add_request_is_idempotent_over_http(self):
        payload = {'request_id': 'repeatable_add_123', 'lookup_id': None,
                   'records': [{'restaurant_name': 'Another venue', 'city': 'Paris'}]}
        status, first = self.request('POST', '/api/restaurants', payload)
        self.assertEqual(status, 200)
        status, retry = self.request('POST', '/api/restaurants', payload)
        self.assertEqual(status, 200)
        self.assertEqual(first, retry)
        _, snapshot = self.request('GET', '/api/offline-catalogue')
        self.assertEqual(len(snapshot['restaurants']), 2)

    def test_review_archive_restore_and_confirmed_delete_update_snapshot(self):
        row = self.restaurant
        path = f"/api/restaurants/{row['id']}"
        status, rejected = self.request('DELETE', path, {'revision': row['revision'], 'confirmed': False})
        self.assertEqual(status, 400)
        for decision in ('failed', 'restore', 'passed'):
            status, result = self.request('POST', path + '/review', {
                'revision': row['revision'], 'decision': decision, 'note': 'Fixture review reason'})
            self.assertEqual(status, 200)
            row = result['restaurant']
        self.assertEqual(row['review_status'], 'passed')
        self.assertIsNone(row['archived_at'])
        _, before = self.request('GET', '/api/offline-catalogue')
        _, unchanged = self.request('GET', '/api/offline-catalogue?version=' + before['version'])
        self.assertTrue(unchanged['unchanged'])
        status, result = self.request('DELETE', path, {'revision': row['revision'], 'confirmed': True})
        self.assertEqual(status, 200)
        _, after = self.request('GET', '/api/offline-catalogue?version=' + before['version'])
        self.assertEqual(after['restaurants'], [])
        self.assertEqual(after['reviews'], {})
        self.assertNotEqual(after['version'], before['version'])

    def test_unknown_routes_and_disallowed_browser_origins_are_rejected(self):
        status, _ = self.request('GET', '/api/not-a-real-route')
        self.assertEqual(status, 404)
        request = Request(f'http://127.0.0.1:{self.port}/api/offline-catalogue',
                          headers={'Origin': 'https://untrusted.example'})
        with self.assertRaises(HTTPError) as rejected:
            urlopen(request, timeout=10)
        self.assertEqual(rejected.exception.code, 403)
