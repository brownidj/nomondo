"""Shared display-name rules for catalogue imports, additions and edits."""
import re


def clean_restaurant_name(value):
    if not isinstance(value, str):
        return value
    original = value.strip()
    name = original
    words = re.findall(r'\w+', name)
    if any(word.casefold() != 'restaurant' for word in words):
        without_label = re.sub(r"\brestaurant\b(?!['’]s\b)", '', name, flags=re.I)
        if without_label != name:
            name = re.sub(r'\(\s*\)', '', without_label)
            # Remove connectors orphaned by a leading/trailing Restaurant label.
            name = name.strip(' \t\r\n,;:–—-&')
    # Parenthetical venue descriptions read naturally as a comma suffix.
    name = re.sub(r'\(\s*(?:at|au|by)\s+([^()]*)\)', r', \1', name, flags=re.I)
    name = re.sub(r'(?<![\w@./])(?:at|au|by)(?![\w@./])', ',', name, flags=re.I)
    name = re.sub(r'(?:\s*,\s*)+', ', ', name)
    name = ' '.join(name.split()).strip(' ,')
    return name or original
