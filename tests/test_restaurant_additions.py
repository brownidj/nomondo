"""Manual tests use temporary catalogues, fake pages and no live API calls."""
import json
import os
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch

from beneede import connect
from restaurant_edits import EditError
from restaurant_additions import create_records
from restaurant_lookup import Page, structured_venues, research, required_fields, website_pages
from website_status import fetch_website_page


class AdditionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'catalogue.sqlite3'
        db = connect(self.path); db.close()

    def test_name_and_city_are_required_without_writes(self):
        for record in ({'restaurant_name': 'Example'}, {'restaurant_name': '', 'city': 'London'},
                       {'restaurant_name': 'Example', 'city': 'Not listed'}):
            with self.assertRaises(EditError):
                create_records(self.path, 'request-001', [record])
        with sqlite3.connect(self.path) as db:
            self.assertEqual(db.execute('SELECT count(*) FROM restaurants').fetchone()[0], 0)
            self.assertEqual(db.execute('SELECT count(*) FROM source_lines').fetchone()[0], 0)

    def test_website_alone_is_valid_and_unresolved_identity_is_flagged(self):
        result = create_records(self.path, 'website-only-001', [{'internet_link': 'https://example.com'}])
        record = result['restaurants'][0]
        self.assertEqual(record['internet_link'], 'https://example.com')
        self.assertEqual(record['restaurant_name'], 'Website: example.com')
        self.assertIsNone(record['city'])
        self.assertEqual(record['needs_review'], 1)

    def test_manual_add_and_retry_do_not_duplicate(self):
        record = {'restaurant_name': 'Example', 'city': 'London', 'notes': 'Keep exactly this note'}
        first = create_records(self.path, 'request-001', [record])
        second = create_records(self.path, 'request-001', [record])
        self.assertEqual(first, second)
        self.assertEqual(first['added_count'], 1)
        self.assertEqual(first['restaurants'][0]['notes'], record['notes'])
        with sqlite3.connect(self.path) as db:
            self.assertEqual(db.execute('SELECT count(*) FROM restaurants').fetchone()[0], 1)
            self.assertEqual(db.execute('SELECT count(*) FROM source_lines').fetchone()[0], 1)
            raw = db.execute('SELECT raw_text FROM source_lines').fetchone()[0]
            self.assertEqual(json.loads(raw)['entered']['notes'], record['notes'])

    def test_same_request_cannot_be_reused_for_changed_input(self):
        create_records(self.path, 'request-001', [{'restaurant_name': 'Example', 'city': 'London'}])
        with self.assertRaises(EditError) as error:
            create_records(self.path, 'request-001', [{'restaurant_name': 'Different', 'city': 'Paris'}])
        self.assertEqual(error.exception.status, 409)

    def test_all_researched_branches_are_saved_and_existing_ones_skipped(self):
        fields = [{'restaurant_name': 'Example', 'city': 'London', 'country': 'UK',
                   'address': f'{number} Main Road, London, UK', 'venue_status': 'open'} for number in (1, 20)]
        lookup = {'input': {'restaurant_name': 'Example', 'city': 'London'}, 'issues': [], 'audits': [],
                  'venues': [{'fields': field, 'evidence': [], 'issues': [], 'confidence': .9} for field in fields]}
        first = create_records(self.path, 'request-001', fields, 'lookup-001', lambda _: lookup)
        second = create_records(self.path, 'request-002', fields, 'lookup-001', lambda _: lookup)
        self.assertEqual(first['added_count'], 2)
        self.assertEqual(second['added_count'], 0)
        self.assertEqual(second['existing_count'], 2)
        self.assertEqual(len(first['restaurants']), 2)
        with sqlite3.connect(self.path) as db:
            self.assertEqual(db.execute('SELECT count(*) FROM restaurants').fetchone()[0], 2)

    def test_partial_invalid_batch_leaves_catalogue_unchanged(self):
        with self.assertRaises(EditError):
            create_records(self.path, 'request-001', [
                {'restaurant_name': 'Example', 'city': 'London'}, {'restaurant_name': 'Missing city'},
            ], 'lookup-001', lambda _: {})
        with sqlite3.connect(self.path) as db:
            self.assertEqual(db.execute('SELECT count(*) FROM restaurants').fetchone()[0], 0)


class LookupTests(unittest.TestCase):
    def test_expanded_parent_name_matches_abbreviated_branch_name(self):
        node = {'@type': 'Restaurant', 'name': 'MTR Example Branch',
                'parentOrganization': {'@type': 'Organization', 'name': 'MTR — Mavalli Tiffin Rooms'},
                'address': {'streetAddress': '1 Example Road', 'addressLocality': 'Bengaluru'}}
        page = Page('<script type="application/ld+json">' + json.dumps(node) + '</script>')
        for name in ('Mavalli Tiffin Rooms', 'Mavalli Tiffin Room (MTR)'):
            venues = structured_venues(page, 'https://example.com/locations/example',
                                       {'restaurant_name': name, 'city': 'Bangalore'})
            self.assertEqual(len(venues), 1)
            self.assertEqual(venues[0]['fields']['restaurant_name'], name)
        self.assertEqual(structured_venues(page, 'https://example.com',
                                         {'restaurant_name': 'Different Restaurant', 'city': None}), [])

    def test_homepage_lookup_follows_all_23_branches_without_api_key(self):
        root = 'https://example.com'
        directory = ''.join(f'<a href="/locations/branch-{i}">Branch {i}</a>' for i in range(23))
        pages = {root: '<a href="/menu">Menu</a><a href="/locations">Locations</a>',
                 root + '/locations': directory, root + '/menu': '<p>Menu</p>'}
        for i in range(23):
            node = {'@type': 'Restaurant', 'name': f'Example Branch {i}',
                    'address': {'streetAddress': f'{i + 1} Example Road',
                                'addressLocality': f'City {i}', 'addressCountry': 'GB' if i % 2 else 'AU'}}
            pages[root + f'/locations/branch-{i}'] = '<script type="application/ld+json">' + json.dumps(node) + '</script>'
        visited = []

        def fetch(url):
            visited.append(url)
            return url, pages[url]

        with patch.dict(os.environ, {}, clear=True), patch('restaurant_lookup.fetch_website_page', side_effect=fetch), patch('restaurant_lookup.api_client') as api:
            result = research({'internet_link': root}, 'website', lambda _: None)
            self.assertEqual(len(result['venues']), 23)
            self.assertEqual(len({venue['fields']['city'] for venue in result['venues']}), 23)
            self.assertEqual(visited[1], root + '/locations')
            self.assertEqual(visited[-1], root + '/menu')
            self.assertFalse(any('incomplete' in issue for issue in result['issues']))
            api.assert_not_called()

    def test_branch_limit_reports_incomplete_discovery(self):
        root = 'https://example.com'
        html = '<a href="/locations">Locations</a>'
        with patch('restaurant_lookup.MAX_WEBSITE_PAGES', 1), patch('restaurant_lookup.fetch_website_page', return_value=(root, html)):
            _, pages, issues = website_pages({'internet_link': root})
            self.assertEqual(len(pages), 1)
            self.assertTrue(any('incomplete' in issue and '1 queued' in issue for issue in issues))

    def test_structured_page_extracts_all_matching_city_branches(self):
        nodes = [{'@type': 'Restaurant', 'name': 'Example', 'address': {
            'streetAddress': street, 'addressLocality': city, 'addressCountry': 'UK'},
            'telephone': '020 7946 0123'} for street, city in [('1 Main Road', 'London'), ('20 Main Road', 'London'), ('9 Other Road', 'Manchester')]]
        page = Page('<script type="application/ld+json">' + json.dumps(nodes) + '</script>')
        venues = structured_venues(page, 'https://example.com', {'restaurant_name': 'Example', 'city': 'London'})
        self.assertEqual(len(venues), 2)
        self.assertTrue(all(venue['fields']['city'] == 'London' for venue in venues))

    def test_website_only_lookup_infers_names_and_cities(self):
        nodes = [{'@type': 'Restaurant', 'name': 'Example', 'address': {
            'streetAddress': street, 'addressLocality': city, 'addressCountry': 'UK'}}
            for street, city in [('1 Main Road', 'London'), ('20 King Road', 'Manchester')]]
        page = Page('<script type="application/ld+json">' + json.dumps(nodes) + '</script>')
        fields = required_fields({'restaurant_name': None, 'city': None, 'internet_link': 'https://example.com'})
        venues = structured_venues(page, 'https://example.com', fields)
        self.assertEqual({venue['fields']['city'] for venue in venues}, {'London', 'Manchester'})
        self.assertTrue(all(venue['fields']['restaurant_name'] == 'Example' for venue in venues))

    def test_website_lookup_works_without_openai_key(self):
        fields = {'restaurant_name': 'Example', 'city': 'London', 'internet_link': 'https://example.com'}
        candidate = {'fields': {**fields, 'address': '1 Main Road, London'}, 'evidence': [], 'issues': [], 'confidence': .9}
        with patch.dict(os.environ, {}, clear=True), patch('restaurant_lookup.website_pages', return_value=([candidate], [], [])), patch('restaurant_lookup.api_client') as api:
            result = research(fields, 'website', lambda _: None)
            self.assertEqual(len(result['venues']), 1)
            api.assert_not_called()

    def test_web_research_requires_key_instead_of_inventing_results(self):
        with patch.dict(os.environ, {}, clear=True), patch('restaurant_lookup.api_client') as api:
            with self.assertRaises(EditError) as error:
                research({'restaurant_name': 'Example', 'city': 'London'}, 'web', lambda _: None)
            self.assertEqual(error.exception.status, 422)
            api.assert_not_called()

    def test_cleared_website_falls_back_to_name_city_research(self):
        with patch.dict(os.environ, {}, clear=True), patch('restaurant_lookup.website_pages') as pages:
            with self.assertRaises(EditError) as error:
                research({'restaurant_name': 'Example', 'city': 'London', 'country': 'UK', 'internet_link': None}, 'website', lambda _: None)
            self.assertEqual(error.exception.status, 422)
            self.assertIn('OPENAI_API_KEY', str(error.exception))
            pages.assert_not_called()

    def test_private_website_is_not_requested(self):
        addresses = [(2, 1, 6, '', ('127.0.0.1', 443))]
        with patch('website_status.socket.getaddrinfo', return_value=addresses), patch('website_status.PublicConnection') as connect:
            with self.assertRaises(ValueError): fetch_website_page('https://localhost')
            connect.assert_not_called()
