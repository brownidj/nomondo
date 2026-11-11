import csv
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import beneede as n


def restaurant(name='Nyhavns Færgekro', **overrides):
    fields = {f: None for f in n.FIELDS}
    fields.update(restaurant_name=name, city='Copenhagen', issues=[])
    fields.update(overrides)
    return n.Restaurant(**fields)


class Response:
    id = 'test-response'
    output = [SimpleNamespace(type='web_search_call')]

    def model_dump(self):
        return {'output': [{'type': 'web_search_call', 'action': {
            'sources': [{'url': 'https://example.com/menu'}]}}]}

    def model_dump_json(self):
        return json.dumps(self.model_dump())


class ImportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.db = n.connect(self.root / 'restaurants.sqlite3')

    def tearDown(self):
        self.db.close()
        self.temp.cleanup()

    def stage(self, text):
        source = self.root / 'restaurants.txt'
        source.write_text(text, encoding='utf-8')
        return n.stage(self.db, source)

    def test_examples(self):
        examples = [
            ('Nyhavns Færgekro - herring - Copenhagen', 'Nyhavns Færgekro', 'Copenhagen', None, 'herring'),
            ('Al Ameer - Middle Eastern - Detroit', 'Al Ameer', 'Detroit', 'Middle Eastern', None),
            ('Zum Stanntisch; German; New York; USA', 'Zum Stanntisch', 'New York', 'German', None),
            ('Cocktail Club; cocktails; Jakarta; Indonesia', 'Cocktail Club', 'Jakarta', None, 'cocktails'),
            ('La Mesa; Philippine; Sydney; Australia', 'La Mesa', 'Sydney', 'Philippine', None),
            ('Crooked Billet - Cockles - Leigh-on-Sea', 'Crooked Billet', 'Leigh-on-Sea', None, 'Cockles'),
            ('Fu Hua Zhai - imperial Chinese - Beijing', 'Fu Hua Zhai', 'Beijing', None, 'imperial Chinese'),
            ('Yat Lok - best roast goose - Hong Kong', 'Yat Lok', 'Hong Kong', None, 'best roast goose'),
            ('Yin yang coastal - Cantonese seafood - Hong Kong', 'Yin yang coastal', 'Hong Kong', None, 'Cantonese seafood'),
            ('Lung King Heen Four Seasons dim sum - Hong Kong', 'Lung King Heen Four Seasons dim sum', 'Hong Kong', None, None),
            ('Sagar Ratna - family dosa - New Delhi', 'Sagar Ratna', 'New Delhi', None, 'family dosa'),
            ('28.\u00a0Blue Hill at Stone Barns\u00a0(Pocantico Hills, New York)', 'Blue Hill, Stone Barns', 'Pocantico Hills, New York', None, None),
            ('29.\u00a0Piazza Duomo\u00a0(Alba, Italy)', 'Piazza Duomo', 'Alba', None, None),
            ('30.\u00a0Elkano\u00a0(Getaria, Spain)', 'Elkano', 'Getaria', None, None),
            ('31.\u00a0Le Calandre\u00a0(Rubano, Italy)', 'Le Calandre', 'Rubano', None, None),
            ('1.\u00a0Mirazur\u00a0(Menton, France)', 'Mirazur', 'Menton', None, None),
            ('2.\u00a0Noma\u00a0(Copenhagen, Denmark) Highest-ever new entry', 'Noma', 'Copenhagen', None, None),
            ('• Restaurant Gordon Ramsay, West London', 'Gordon Ramsay', 'West London', None, None),
            ('• Casamia, Bristol', 'Casamia', 'Bristol', None, None),
        ]
        for raw, name, city, cuisine, dish in examples:
            with self.subTest(raw=raw):
                records, reason = n.local_records(raw)
                self.assertIsNone(reason)
                self.assertEqual(len(records), 1)
                r = records[0]
                self.assertEqual((r.restaurant_name, r.city, r.cuisine, r.special_dish), (name, city, cuisine, dish))
                self.assertIsNone(r.address)

    def test_split_joined_entries_and_mixed_delimiters(self):
        records, _ = n.local_records('MoVida Aqui; Tapas; Melbourne; Australian Osteria Ilaria; Italian, classic (Tommy Ruff); Melbourne; Australian')
        self.assertEqual([r.restaurant_name for r in records], ['MoVida Aqui', 'Osteria Ilaria'])
        records, _ = n.local_records('Keeps & Co, Middle Eastern, Sydney; Australia')
        self.assertEqual(records[0].cuisine, 'Middle Eastern')
        self.assertEqual(records[0].country, 'Australia')

    def test_idempotent_staging_and_offline_import_preserves_rating(self):
        self.assertEqual(self.stage('1. Mirazur (Menton, France)\n'), 1)
        n.import_local(self.db)
        self.assertEqual(self.db.execute('SELECT rating FROM restaurants').fetchone()[0], 0)
        self.db.execute('UPDATE restaurants SET rating=4.5')
        self.db.commit()
        self.assertEqual(self.stage('1. Mirazur (Menton, France)\n'), 0)
        n.import_local(self.db)
        self.assertEqual(self.db.execute('SELECT count(*),rating FROM restaurants').fetchone()[:], (1, 4.5))

    def test_prose_retained_without_fake_restaurant(self):
        self.stage('Restaurants\nTaking the top spot is Restaurant Nathan Outlaw in Cornwall.\n')
        n.import_local(self.db)
        self.assertEqual(self.db.execute('SELECT count(*) FROM restaurants').fetchone()[0], 0)
        self.assertEqual(self.db.execute('SELECT count(*) FROM source_lines WHERE ignored_reason IS NOT NULL').fetchone()[0], 2)

    def test_duplicate_flags_without_merging(self):
        self.stage('Plachutta - Tafelspitz - Vienna\nPlachutta; Tafelspitz; Vienna; Austria\n')
        n.import_local(self.db)
        rows = self.db.execute('SELECT * FROM restaurants').fetchall()
        self.assertEqual(len(rows), 2)
        for r in rows:
            self.assertIn('Possible duplicate', json.loads(r['review_reasons']))
            self.assertEqual(len(json.loads(r['duplicate_ids'])), 1)

    def test_partial_api_batch_rolls_back(self):
        self.stage('A - Rome\nB - Paris\n')
        result = n.Extraction(lines=[n.ExtractedLine(source_id=1, restaurants=[restaurant()], ignored_reason=None)])
        with patch.object(n, 'request', side_effect=[(Response(), result), TimeoutError()]):
            with self.assertRaises(TimeoutError):
                n.extract(self.db, None, 'test-model', 25, None)
        self.assertEqual(self.db.execute('SELECT count(*) FROM restaurants').fetchone()[0], 0)
        self.assertEqual(self.db.execute("SELECT count(*) FROM source_lines WHERE extraction_status='pending'").fetchone()[0], 2)

    def test_api_refines_seeds_and_resumes(self):
        self.stage('Nyhavns Færgekro - herring - Copenhagen\n')
        n.import_local(self.db)
        result = n.Extraction(lines=[n.ExtractedLine(source_id=1, restaurants=[restaurant(special_dish='herring')], ignored_reason=None)])
        with patch.object(n, 'request', return_value=(Response(), result)) as request:
            n.extract(self.db, None, 'test-model', 25, None)
            n.extract(self.db, None, 'test-model', 25, None)
            self.assertEqual(request.call_count, 1)
        self.assertEqual(self.db.execute('SELECT count(*) FROM restaurants').fetchone()[0], 1)
        self.assertEqual(self.db.execute('SELECT extraction_status FROM source_lines').fetchone()[0], 'extracted')

    def seed_for_research(self):
        self.stage('Nyhavns Færgekro - herring - Copenhagen\n')
        n.import_local(self.db)
        self.db.execute("UPDATE source_lines SET extraction_status='extracted'")
        self.db.execute('UPDATE restaurants SET rating=4')
        self.db.commit()

    def test_enrichment_requires_retrieved_evidence_and_preserves_rating(self):
        self.seed_for_research()
        result = n.Enrichment(restaurant=restaurant(country='Denmark', address='Made up address', special_dish='herring'),
            confidence=0.95, venue_status='closed', evidence=[
                n.Evidence(field='country', url='https://example.com/menu', detail='Copenhagen, Denmark'),
                n.Evidence(field='address', url='https://invented.example/address', detail='Unsupported'),
            ])
        with patch.object(n, 'request', return_value=(Response(), result)) as request:
            self.assertEqual(n.enrich(self.db, None, 'test-model', None, False), 0)
            n.enrich(self.db, None, 'test-model', None, False)
            self.assertEqual(request.call_count, 1)
        row = self.db.execute('SELECT * FROM restaurants').fetchone()
        self.assertEqual(row['country'], 'Denmark')
        self.assertIsNone(row['address'])
        self.assertEqual(row['rating'], 4)
        self.assertEqual(row['needs_review'], 1)
        self.assertIn('Venue status: closed', json.loads(row['review_reasons']))

    def test_failed_enrichment_saved_and_retryable(self):
        self.seed_for_research()
        with patch.object(n, 'request', side_effect=TimeoutError('secret test text')):
            self.assertEqual(n.enrich(self.db, None, 'test', None, False), 1)
        row = self.db.execute('SELECT * FROM restaurants').fetchone()
        self.assertEqual(row['enrichment_status'], 'failed')
        self.assertTrue(row['last_error'].startswith('TimeoutError'))
        self.assertNotIn('secret test text', row['last_error'])
        with patch.object(n, 'request', side_effect=TimeoutError()) as request:
            self.assertEqual(n.enrich(self.db, None, 'test', None, False), 0)
            self.assertEqual(n.enrich(self.db, None, 'test', None, True), 1)
            self.assertEqual(request.call_count, 1)

    def test_local_records_must_be_api_extracted_before_research(self):
        self.stage('A - Rome\n')
        n.import_local(self.db)
        with patch.object(n, 'request') as request:
            n.enrich(self.db, None, 'test', None, False)
            request.assert_not_called()

    def test_api_extraction_keeps_phone_notes_region_and_ranking(self):
        raw = ('28. Blue Hill at Stone Barns (Pocantico Hills, New York); '
               'tel +1 914 366 9600 ext 02; book ahead')
        self.stage(raw)
        record = restaurant('Blue Hill at Stone Barns', city='Pocantico Hills',
            region='New York', telephone='+1 914 366 9600 ext 02', notes='book ahead',
            historical_ranking='Rank 28; list/year unspecified')
        result = n.Extraction(lines=[n.ExtractedLine(source_id=1,
            restaurants=[record], ignored_reason=None)])
        with patch.object(n, 'request', return_value=(Response(), result)):
            n.extract(self.db, None, 'test-model', 25, None)
        row = self.db.execute('SELECT * FROM restaurants').fetchone()
        for field in ('telephone', 'region', 'notes', 'historical_ranking'):
            self.assertEqual(row[field], getattr(record, field))
        self.assertEqual(row['rating'], 0)
        self.assertEqual(self.db.execute('SELECT raw_text FROM source_lines').fetchone()[0], raw)

    def test_researched_phone_requires_retrieved_evidence(self):
        self.seed_for_research()
        result = n.Enrichment(restaurant=restaurant(telephone='+45 0012 3456'),
            confidence=0.95, venue_status='open', evidence=[
                n.Evidence(field='telephone', url='https://invented.example/phone', detail='Telephone')])
        with patch.object(n, 'request', return_value=(Response(), result)):
            n.enrich(self.db, None, 'test-model', None, False)
        row = self.db.execute('SELECT * FROM restaurants').fetchone()
        self.assertIsNone(row['telephone'])
        self.assertIn('Unsupported proposed telephone', row['review_reasons'])
        self.assertEqual(json.loads(row['evidence']), [])
        result.evidence[0].url = 'https://example.com/menu'
        with patch.object(n, 'request', return_value=(Response(), result)):
            n.enrich(self.db, None, 'test-model', None, False, refresh_completed=True)
        row = self.db.execute('SELECT * FROM restaurants').fetchone()
        self.assertEqual(row['telephone'], '+45 0012 3456')
        self.assertEqual(row['rating'], 4)
        self.assertEqual(json.loads(row['evidence'])[0]['field'], 'telephone')
        # A later refresh that leaves the number unchanged must retain its citation.
        result.evidence = []
        with patch.object(n, 'request', return_value=(Response(), result)):
            n.enrich(self.db, None, 'test-model', None, False, refresh_completed=True)
        refreshed = self.db.execute('SELECT telephone,evidence FROM restaurants').fetchone()
        self.assertEqual(refreshed['telephone'], '+45 0012 3456')
        self.assertEqual(json.loads(refreshed['evidence'])[0]['url'], 'https://example.com/menu')

    def test_unlisted_phone_is_optional_and_source_notes_survive_research(self):
        self.seed_for_research()
        self.db.execute("UPDATE restaurants SET notes='Order 48 hours ahead',historical_ranking='Rank 28'")
        self.db.commit()
        result = n.Enrichment(restaurant=restaurant(), confidence=0.95, venue_status='open', evidence=[])
        with patch.object(n, 'request', return_value=(Response(), result)):
            n.enrich(self.db, None, 'test-model', None, False)
        row = self.db.execute('SELECT * FROM restaurants').fetchone()
        self.assertIsNone(row['telephone'])
        self.assertNotIn('Missing telephone', json.loads(row['review_reasons']))
        self.assertEqual(row['notes'], 'Order 48 hours ahead')
        self.assertEqual(row['historical_ranking'], 'Rank 28')

    def test_offline_rank_does_not_invent_year(self):
        records, _ = n.local_records('28. Blue Hill at Stone Barns (Pocantico Hills, New York)')
        self.assertEqual(records[0].historical_ranking, 'Rank 28; list/year unspecified')
        self.assertIsNone(records[0].country)

    def test_csv_export_preserves_phone_accents_notes_and_source(self):
        self.seed_for_research()
        self.db.execute('UPDATE restaurants SET telephone=?,notes=?,region=?',
                        ('+45 0012 3456 ext 02', 'Try herring, then dessert\nBook ahead', 'Capital Region'))
        self.db.commit()
        output = self.root / 'restaurants.csv'
        n.export_csv(self.db, output)
        with output.open(encoding='utf-8-sig', newline='') as handle:
            rows = list(csv.DictReader(handle))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['restaurant_name'], 'Nyhavns Færgekro')
        self.assertEqual(rows[0]['telephone'], '+45 0012 3456 ext 02')
        self.assertEqual(rows[0]['notes'], 'Try herring, then dessert\nBook ahead')
        self.assertEqual(rows[0]['country'], '')
        self.assertEqual(rows[0]['raw_text'], 'Nyhavns Færgekro - herring - Copenhagen')
        self.assertEqual(rows[0]['rating'], '4.0')
        for protected in (self.root / 'restaurants.txt', self.root / 'restaurants.sqlite3'):
            with self.assertRaises(ValueError):
                n.export_csv(self.db, protected)

    def test_migration_adds_fields_without_changing_records_or_rating(self):
        self.seed_for_research()
        added = {'venue_type', 'region', 'telephone', 'notes', 'historical_ranking'}
        old_columns = [row['name'] for row in self.db.execute('PRAGMA table_info(restaurants)')
                       if row['name'] not in added]
        legacy_path = self.root / 'legacy.sqlite3'
        # Materialise the prior schema/record in a separate database fixture.
        self.db.execute('ATTACH DATABASE ? AS legacy', (str(legacy_path),))
        self.db.execute(f"CREATE TABLE legacy.restaurants AS SELECT {','.join(old_columns)} FROM main.restaurants")
        self.db.commit()
        self.db.execute('DETACH DATABASE legacy')
        migrated = n.connect(legacy_path)
        try:
            row = migrated.execute('SELECT * FROM restaurants').fetchone()
            self.assertEqual(row['rating'], 4)
            self.assertEqual(row['restaurant_name'], 'Nyhavns Færgekro')
            for field in added:
                self.assertIsNone(row[field])
            self.assertEqual(migrated.execute('SELECT count(*) FROM restaurants').fetchone()[0], 1)
        finally:
            migrated.close()

    def test_different_branches_are_not_duplicate_candidates(self):
        self.stage('A; Italian; Sydney; Australia\nA; Italian; Sydney; Australia\n')
        n.import_local(self.db)
        rows = self.db.execute('SELECT id FROM restaurants ORDER BY id').fetchall()
        for row, address in zip(rows, ('1 First Street', '2 Second Street')):
            self.db.execute('UPDATE restaurants SET address=? WHERE id=?', (address, row['id']))
        self.db.commit()
        n.flag_duplicates(self.db)
        for row in self.db.execute('SELECT duplicate_ids FROM restaurants'):
            self.assertEqual(json.loads(row['duplicate_ids']), [])

    def test_invalid_extraction_batch_is_split_and_resumed(self):
        self.stage('A - Rome\nB - Paris\n')
        first = n.Extraction(lines=[n.ExtractedLine(source_id=1,
            restaurants=[restaurant('A')], ignored_reason=None)])
        second = n.Extraction(lines=[n.ExtractedLine(source_id=2,
            restaurants=[restaurant('B')], ignored_reason=None)])
        with patch.object(n, 'request', side_effect=[
                (Response(), first), (Response(), first), (Response(), second)]) as request:
            n.extract(self.db, None, 'test-model', 25, None)
        self.assertEqual(request.call_count, 3)
        self.assertEqual([r[0] for r in self.db.execute('SELECT restaurant_name FROM restaurants ORDER BY id')], ['A', 'B'])
        self.assertEqual(self.db.execute("SELECT count(*) FROM source_lines WHERE extraction_status='extracted'").fetchone()[0], 2)

    def test_null_search_metadata_and_field_specific_citations(self):
        self.seed_for_research()
        result = n.Enrichment(restaurant=restaurant(telephone='+45 0012 3456', country='Denmark'),
            confidence=0.95, venue_status='open', evidence=[
                n.Evidence(field='telephone', url='', detail='Listed contact number'),
                n.Evidence(field='country', url='', detail='Country guessed without a citation')])
        text = result.model_dump_json()
        start = text.index('Listed contact number')
        data = {'output': [
            {'type': 'web_search_call', 'action': {'type': 'search', 'sources': None}},
            {'type': 'web_search_call', 'action': None},
            {'type': 'message', 'content': [{'type': 'output_text', 'text': text, 'annotations': [
                {'type': 'url_citation', 'url': 'https://example.com/contact?utm_source=openai',
                 'start_index': start, 'end_index': start + len('Listed contact number')}]}]}]}
        response = Mock(id='null-sources', output=Response.output)
        response.model_dump.return_value = data
        response.model_dump_json.return_value = json.dumps(data)
        with patch.object(n, 'request', return_value=(response, result)):
            self.assertEqual(n.enrich(self.db, None, 'test-model', None, False), 0)
        row = self.db.execute('SELECT * FROM restaurants').fetchone()
        self.assertEqual(row['telephone'], '+45 0012 3456')
        self.assertIsNone(row['country'])
        self.assertEqual(json.loads(row['evidence'])[0]['field'], 'telephone')

    def test_evidence_recovers_inline_links_and_tracking_variants(self):
        result = n.Enrichment(restaurant=restaurant(telephone='001234'),
            confidence=0.95, venue_status='open', evidence=[
                n.Evidence(field='telephone', url='', detail='Contact ([menu](https://example.com/menu))'),
                n.Evidence(field='address', url='https://example.com/menu/?utm_source=openai', detail='Menu address'),
                n.Evidence(field='country', url='https://unretrieved.example/', detail='No source')])
        recovered = n.resolved_evidence(Response(), result)
        self.assertEqual({e.field for e in recovered}, {'telephone', 'address'})
        self.assertTrue(all(e.url == 'https://example.com/menu' for e in recovered))

    def test_raw_response_is_retained_when_structured_output_is_invalid(self):
        response = Mock(status='completed', output_text='not JSON')
        client = Mock()
        client.responses.create.return_value = response
        with self.assertRaises(n.ResponseError) as failure:
            n.request(client, 'test-model', n.Extraction, 'instructions', {})
        self.assertIs(failure.exception.response, response)
        options = client.responses.create.call_args.kwargs
        self.assertEqual(options['text']['format']['type'], 'json_schema')
        self.assertTrue(options['text']['format']['strict'])
        self.assertFalse(options['store'])

    def test_web_research_and_structuring_preserve_sources_in_separate_calls(self):
        result = n.Enrichment(restaurant=restaurant(telephone='+45 001234'),
            confidence=0.95, venue_status='open', evidence=[n.Evidence(
                field='telephone', url='https://example.com/menu', detail='Listed phone')])
        research = Mock(id='research', status='completed', output_text='Phone +45 001234 (https://example.com/menu)',
                        output=Response.output)
        research.model_dump.return_value = Response().model_dump()
        formatted = Mock(id='structured', status='completed', output_text=result.model_dump_json(), output=[])
        formatted.model_dump.return_value = {'id': 'structured', 'output': []}
        client = Mock()
        client.responses.create.side_effect = [research, formatted]
        response, parsed = n.request(client, 'test-model', n.Enrichment, 'Research the venue',
            {'record': {f: getattr(result.restaurant, f) for f in n.FIELDS}, 'original_line': 'Venue'}, web=True)
        first, second = client.responses.create.call_args_list
        self.assertIn('tools', first.kwargs)
        self.assertNotIn('{', first.kwargs['input'])
        self.assertNotIn('text', first.kwargs)
        self.assertNotIn('tools', second.kwargs)
        self.assertEqual(second.kwargs['text']['format']['type'], 'json_schema')
        self.assertEqual(parsed.restaurant.telephone, '+45 001234')
        self.assertEqual(n.resolved_evidence(response, parsed)[0].url, 'https://example.com/menu')
        self.assertIn('research_response', json.loads(response.model_dump_json()))

    def test_unsourced_research_stops_before_structuring(self):
        response = Mock(status='completed', output_text='Unverified guesses')
        response.model_dump.return_value = {'output': []}
        client = Mock()
        client.responses.create.return_value = response
        with self.assertRaises(n.ResponseError):
            n.request(client, 'test-model', n.Enrichment, 'Research',
                {'record': {'restaurant_name': 'A'}}, web=True)
        self.assertEqual(client.responses.create.call_count, 1)

    def test_three_consecutive_failures_stop_research_and_leave_rest_pending(self):
        self.stage('A - Rome\nB - Paris\nC - London\nD - Sydney\n')
        n.import_local(self.db)
        self.db.execute("UPDATE source_lines SET extraction_status='extracted'")
        self.db.commit()
        with patch.object(n, 'request', side_effect=TypeError('private provider text')) as request:
            with self.assertRaises(RuntimeError):
                n.enrich(self.db, None, 'test-model', None, False)
        self.assertEqual(request.call_count, 3)
        self.assertEqual(self.db.execute("SELECT count(*) FROM restaurants WHERE enrichment_status='pending'").fetchone()[0], 1)
        for row in self.db.execute('SELECT last_error FROM restaurants WHERE last_error IS NOT NULL'):
            self.assertNotIn('private provider text', row['last_error'])

    def test_resume_runs_extraction_retry_research_and_export(self):
        self.stage('A - Rome\n')
        with patch('sys.argv', ['main.py', '--db', str(self.root / 'restaurants.sqlite3'),
                'resume', '--source', str(self.root / 'restaurants.txt'), '--refresh-completed']), \
                patch.object(n, 'api_client', return_value='client'), \
                patch.object(n, 'extract') as extract, \
                patch.object(n, 'enrich', return_value=0) as enrich, \
                patch.object(n, 'export_csv') as export:
            n.main()
        self.assertEqual(extract.call_args.args[1:], ('client', 'gpt-4.1-mini', 10, None))
        self.assertEqual(enrich.call_args.args[1:], ('client', 'gpt-4.1', None, True, True))
        export.assert_called_once()


if __name__ == '__main__':
    unittest.main()
