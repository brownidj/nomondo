"""Manual-only city-index tests using a tiny synthetic GeoNames snapshot."""
from pathlib import Path
import tempfile
import unittest
import zipfile

from city_index import build_index, suggest_cities


class CityIndexTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.index = root / 'cities.sqlite3'
        archive = root / 'cities1000.zip'
        admins = root / 'admin1CodesASCII.txt'
        admins.write_text('GB.ENG\tEngland\nUS.MA\tMassachusetts\nUS.IL\tIllinois\n', encoding='utf-8')
        records = []
        for ident, name, ascii_name, aliases, code, admin, population in (
            (1, 'London', 'London', 'Londres', 'GB', 'ENG', 9000000),
            (2, 'London', 'London', '', 'CA', '08', 400000),
            (3, 'São Paulo', 'Sao Paulo', '', 'BR', '27', 12000000),
            (4, 'Bengaluru', 'Bengaluru', 'Bangalore', 'IN', '19', 10000000),
            (5, 'Springfield', 'Springfield', '', 'US', 'MA', 150000),
            (6, 'Springfield', 'Springfield', '', 'US', 'IL', 110000),
        ):
            row = [str(ident), name, ascii_name, aliases, '0', '0', 'P', 'PPL', code, '', admin, '', '', '', str(population), '', '0', 'Etc/UTC', '2026-11-10']
            records.append('\t'.join(row))
        with zipfile.ZipFile(archive, 'w') as output:
            output.writestr('cities1000.txt', '\n'.join(records))
        build_index(archive, admins, self.index)

    def test_same_named_cities_keep_distinct_countries_and_regions(self):
        cities = suggest_cities('Lon', index=self.index)
        self.assertEqual([city['country'] for city in cities], ['England, United Kingdom', 'Canada'])
        cities = suggest_cities('Spring', 'United States', self.index)
        self.assertEqual({city['region'] for city in cities}, {'Massachusetts', 'Illinois'})

    def test_country_and_constituent_country_filters(self):
        self.assertEqual(len(suggest_cities('Lon', 'UK', self.index)), 1)
        self.assertEqual(suggest_cities('Lon', 'Scotland', self.index), [])
        self.assertEqual(suggest_cities('Lon', 'Canada', self.index)[0]['id'], 2)

    def test_aliases_and_accents_find_same_place_once(self):
        self.assertEqual(suggest_cities('Bangal', index=self.index)[0]['name'], 'Bengaluru')
        self.assertEqual(len(suggest_cities('Sao', index=self.index)), 1)
        self.assertEqual(suggest_cities('São', index=self.index)[0]['name'], 'São Paulo')

    def test_unavailable_or_short_query_leaves_manual_entry_possible(self):
        self.assertEqual(suggest_cities('L', index=self.index), [])
        self.assertEqual(suggest_cities('London', index=self.index.with_name('missing.sqlite3')), [])

    def test_query_is_literal_and_results_are_bounded(self):
        self.assertEqual(suggest_cities("Lo' OR 1=1 --", index=self.index), [])
        self.assertEqual(len(suggest_cities('Lon', index=self.index, limit=1)), 1)
