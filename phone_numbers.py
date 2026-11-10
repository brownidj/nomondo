"""International presentation of supplied telephone numbers; never invent digits."""
import re
import unicodedata

import phonenumbers

_REGIONS = dict(zip(
    'Argentina|Australia|Austria|Belgium|Brazil|Cambodia|Canada|Chile|China|Colombia|Czech Republic|Denmark|Egypt|Finland|France|Germany|Greece|Guatemala|Hong Kong|India|Indonesia|Ireland|Italy|Jamaica|Japan|Jordan|Malaysia|Mauritius|Mexico|Morocco|Netherlands|New Zealand|Peru|Poland|Portugal|Russia|Saint Barthélemy|Singapore|Slovenia|South Africa|South Korea|Spain|Sri Lanka|Sweden|Switzerland|Thailand|Turkey|United Kingdom|United States|Vietnam'.lower().split('|'),
    'AR AU AT BE BR KH CA CL CN CO CZ DK EG FI FR DE GR GT HK IN ID IE IT JM JP JO MY MU MX MA NL NZ PE PL PT RU BL SG SI ZA KR ES LK SE CH TH TR GB US VN'.split(),
))
_REGIONS.update({'usa': 'US', 'us': 'US', 'uk': 'GB', 'the netherlands': 'NL'})


def country_region(country):
    name = (country or '').strip().lower()
    if 'hong kong' in name:
        return 'HK'
    if any(part in name for part in ('united kingdom', 'england', 'scotland', 'wales')):
        return 'GB'
    return _REGIONS.get(name)


def format_telephone(value, country):
    """Keep alternatives/extensions and unresolved text, format possible numbers.

    Country supplies the dialing region only for national numbers. Explicit
    international prefixes always take precedence. Source/audit text is retained.
    """
    if not value or value.strip().lower() == 'not listed':
        return value
    region = country_region(country)
    text = unicodedata.normalize('NFKC', value)
    text = ''.join(' ' if unicodedata.category(c) == 'Cc' else c for c in text)
    text = re.sub(r',\s*(?!ext(?:ension)?\b)(?=[(+\d])', ' / ', text, flags=re.I)
    text = re.sub(r'[‐‑‒–—−]', '-', text)
    # A slash can separate alternatives OR an area code from its local number.
    parts = re.split(r'\s+or\s+|\s*;\s*|\s*/\s*', text, flags=re.I)
    if any(len(re.sub(r'\D', '', part)) < 7 for part in parts):
        parts = re.split(r'\s+or\s+|\s*;\s*', text, flags=re.I)
        parts = [part.replace('/', ' ') for part in parts]
    result = []
    previous = None
    for part in parts:
        annotation = ''
        suffix = re.search(r'\s*(\([^()]*[a-zA-Z][^()]*\))\s*$', part)
        if suffix:
            annotation = ' ' + suffix[1]
            part = part[:suffix.start()]
        candidate = part.strip()
        if candidate.startswith('00'):
            candidate = '+' + candidate[2:].lstrip()
        try:
            number = phonenumbers.parse(candidate, region)
            if not phonenumbers.is_possible_number(number) and previous is not None:
                # An abbreviated alternative may reuse the preceding area code.
                digits = re.sub(r'\D', '', candidate)
                national = phonenumbers.national_significant_number(previous)
                area_length = phonenumbers.length_of_national_destination_code(previous)
                if digits and area_length and len(digits) == len(national) - area_length:
                    number = phonenumbers.parse('+' + str(previous.country_code) + national[:area_length] + digits, None)
            if not phonenumbers.is_possible_number(number):
                raise ValueError('Incomplete or ambiguous number')
            previous = number
            extension = number.extension
            number.extension = None
            formatted = phonenumbers.format_number(number, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
            if extension:
                formatted += ' ext. ' + extension
        except (phonenumbers.NumberParseException, ValueError):
            formatted = part.strip()
        if formatted + annotation not in result:
            result.append(formatted + annotation)
    return ' / '.join(result)
