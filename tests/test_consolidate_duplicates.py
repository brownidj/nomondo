"""Run manually: preservation of conflicting duplicate data."""
import json
import unittest

from consolidate_duplicates import merge_records, score, DETAILS


def record(ident, **values):
    row = dict.fromkeys(DETAILS)
    row.update(id=ident, source_id=ident, entry_index=0, restaurant_name='Venue',
               rating=0, venue_status='open', confidence=.9, evidence='[]',
               review_reasons='[]', needs_review=0, duplicate_ids='[]')
    row.update(values)
    return row


class ConsolidationTests(unittest.TestCase):
    def test_richer_record_wins_and_blank_is_filled(self):
        first = record(1, city='London', country='UK', notes='Original note')
        second = record(2, telephone='+44 20 1234 5678')
        merged = merge_records([second, first], {1: {'raw_text': 'first'}, 2: {'raw_text': 'second'}})
        self.assertEqual(merged['id'], 1)
        self.assertEqual(merged['telephone'], second['telephone'])
        self.assertIn(first['notes'], merged['notes'])

    def test_conflicting_values_and_full_inputs_survive(self):
        first = record(1, address='3 Main Street', notes='Keep this', cuisine='British')
        second = record(2, address='19 Main Street', notes='Also keep this', cuisine='European', rating=4)
        sources = {1: {'raw_text': 'source one'}, 2: {'raw_text': 'source two'}}
        merged = merge_records([first, second], sources)
        for row in (first, second):
            self.assertIn({'record': row, 'source': sources[row['source_id']]}, json.loads(merged['record_history']))
            self.assertIn(row['notes'], merged['notes'])
            self.assertIn(row['cuisine'], merged['cuisine'])
        alternative = first if merged['id'] == second['id'] else second
        self.assertIn(alternative['address'], merged['notes'])
        self.assertEqual(merged['needs_review'], 1)

    def test_score_ignores_placeholder_fields(self):
        self.assertGreater(score(record(1, city='Paris')), score(record(2, city='Not listed')))

    def test_alternative_phones_and_evidence_are_preserved(self):
        first = record(1, telephone='+1 212-555-0100', evidence='[{"url":"https://one.example"}]')
        second = record(2, telephone='+1 212-555-0101', evidence='[{"url":"https://two.example"}]')
        merged = merge_records([first, second], {1: {}, 2: {}})
        self.assertIn(first['telephone'], merged['telephone'])
        self.assertIn(second['telephone'], merged['telephone'])
        self.assertEqual(len(json.loads(merged['evidence'])), 2)
