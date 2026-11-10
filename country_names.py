"""English country names from the already bundled telephone metadata."""
from phonenumbers.geodata.locale import LOCALE_DATA
import re


def _name_key(value):
    text = value.casefold().replace('engalnd', 'england').replace('kingom', 'kingdom')
    return ' '.join(re.findall(r'[a-z]+', text))


NAME_ALIASES = {'the netherlands': 'Netherlands'}
UK_COUNTRIES = ('England', 'Scotland', 'Wales', 'Northern Ireland')
for part in UK_COUNTRIES:
    for form in (part, f'{part} United Kingdom', f'United Kingdom {part}', f'{part} UK', f'UK {part}'):
        NAME_ALIASES[_name_key(form)] = f'{part}, United Kingdom'
for form in ('Hong Kong', 'Hong Kong China', 'Hong Kong SAR', 'Hong Kong SAR China',
             'Hong Kong Special Administrative Region', 'Hong Kong Special Administrative Region China'):
    NAME_ALIASES[_name_key(form)] = 'Hong Kong'

def _english_name(names):
    # Telephone metadata compresses repeated translations as '*language' links.
    value = names.get('en', '')
    seen = set()
    while value.startswith('*'):
        if value in seen:
            raise ValueError('Circular country-name metadata reference')
        seen.add(value)
        value = names[value[1:]]
    return value


COUNTRY_NAMES = {code: _english_name(names) for code, names in LOCALE_DATA.items() if names.get('en')}
COUNTRY_NAMES.update({'GB': 'United Kingdom', 'US': 'United States'})
ALIASES = {'UK': 'GB', 'USA': 'US', 'UAE': 'AE', 'RSA': 'ZA'}
NAME_CODES = {name.casefold(): code for code, name in COUNTRY_NAMES.items()}


def country_code(value):
    if not isinstance(value, str):
        return None
    value = full_country_name(value)
    if value in {f'{part}, United Kingdom' for part in UK_COUNTRIES}:
        return 'GB'
    key = value.strip().upper().replace('.', '')
    key = ALIASES.get(key, key)
    return key if key in COUNTRY_NAMES else NAME_CODES.get(value.strip().casefold())


def full_country_name(value):
    """Expand codes and equivalent spellings; preserve unknown source text."""
    if not isinstance(value, str):
        return value
    alias = NAME_ALIASES.get(_name_key(value))
    if alias:
        return alias
    key = value.strip().upper().replace('.', '')
    return COUNTRY_NAMES.get(ALIASES.get(key, key), value)
