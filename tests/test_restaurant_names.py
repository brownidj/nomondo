"""Run manually: catalogue title normalisation and edit validation."""
import unittest

from restaurant_names import clean_restaurant_name
from restaurant_edits import validate_changes


class RestaurantNameTests(unittest.TestCase):
    def test_removes_label_and_normalises_at_without_losing_name_parts(self):
        cases = {
            'Restaurant Gwendolyn': 'Gwendolyn',
            'Bohemia Bar & Restaurant': 'Bohemia Bar',
            'Blue Spoon Restaurant & Bar': 'Blue Spoon & Bar',
            'Claude Bosi at Bibendum': 'Claude Bosi, Bibendum',
            'The Dining Room (at Whatley Manor)': 'The Dining Room, Whatley Manor',
            'RESTAURANT Example AT Hotel': 'Example, Hotel',
            'Alain Ducasse au Plaza Athénée': 'Alain Ducasse, Plaza Athénée',
            'Au Crocodile': 'Crocodile',
            'Example (AU Hotel)': 'Example, Hotel',
            'Core by Clare Smyth': 'Core, Clare Smyth',
            'Example (BY Chef)': 'Example, Chef',
        }
        for original, expected in cases.items():
            with self.subTest(original=original):
                self.assertEqual(clean_restaurant_name(original), expected)
                self.assertEqual(clean_restaurant_name(expected), expected)

    def test_standalone_label_and_unrelated_words_stay_intact(self):
        for value in ('Restaurant', 'RESTAURANT', 'Atlas', 'Restaurantology',
                      'Atelier', '& Sons', "Restaurant's Choice", 'Website: example.at',
                      'Auberge', 'Paul', 'Website: example.au', 'Ruby', 'Website: example.by'):
            self.assertEqual(clean_restaurant_name(value), value)

    def test_edit_validation_applies_rules_only_to_name(self):
        self.assertEqual(validate_changes({'restaurant_name': 'Restaurant Example at Hotel',
                                          'notes': 'Restaurant at Hotel', 'address': 'At Restaurant Road'}),
                         {'restaurant_name': 'Example, Hotel', 'notes': 'Restaurant at Hotel',
                          'address': 'At Restaurant Road'})
