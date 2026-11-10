"""Country normalisation regressions; run manually per project policy."""
import unittest

from country_names import COUNTRY_NAMES, full_country_name
from phone_numbers import country_region
from restaurant_edits import validate_changes


class CountryNameTests(unittest.TestCase):
    def test_telephone_metadata_references_are_resolved(self):
        self.assertEqual(full_country_name('AE'), 'United Arab Emirates')
        self.assertEqual(full_country_name('IN'), 'India')
        self.assertTrue(all(name and not name.startswith('*') for name in COUNTRY_NAMES.values()))

    def test_common_aliases_share_full_names(self):
        for code in ('US', 'USA', 'U.S.A.'):
            self.assertEqual(full_country_name(code), 'United States')
        for code in ('GB', 'UK', 'U.K.'):
            self.assertEqual(full_country_name(code), 'United Kingdom')

    def test_unknown_or_qualified_names_are_preserved(self):
        for value in (None, '', 'Not listed', 'Scotland, United Kingdom', 'Unconfirmed location'):
            self.assertEqual(full_country_name(value), value)

    def test_edits_normalise_country_without_rewriting_address(self):
        self.assertEqual(validate_changes({'country': 'SG', 'address': 'Example address, SG'}),
                         {'country': 'Singapore', 'address': 'Example address, SG'})

    def test_full_names_keep_telephone_regions(self):
        for code in ('AE', 'NP', 'IN', 'GB', 'US'):
            self.assertEqual(country_region(full_country_name(code)), code)

    def test_equivalent_uk_country_names_share_one_label(self):
        for value in ('England (United Kingdom)', 'England, United Kingdom',
                      'United Kingdom (England)', 'Engalnd (United Kingom)', 'England, UK'):
            self.assertEqual(full_country_name(value), 'England, United Kingdom')
        self.assertEqual(full_country_name('Scotland'), 'Scotland, United Kingdom')
        self.assertEqual(full_country_name('United Kingdom (Wales)'), 'Wales, United Kingdom')
        self.assertEqual(full_country_name('United Kingdom'), 'United Kingdom')
        self.assertEqual(country_region('Northern Ireland'), 'GB')

    def test_equivalent_territory_and_article_variants(self):
        for value in ('Hong Kong (China)', 'Hong Kong (SAR), China', 'Hong Kong SAR'):
            self.assertEqual(full_country_name(value), 'Hong Kong')
        self.assertEqual(full_country_name('The Netherlands'), 'Netherlands')
