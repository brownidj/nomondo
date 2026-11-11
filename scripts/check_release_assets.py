"""Read-only checks on the actual release packages, including branding and fonts."""
import json
from pathlib import Path
import plistlib
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1] / 'flutter_app' / 'build'
FAMILIES = {'MaterialIcons', 'packages/cupertino_icons/CupertinoIcons',
            'NotoSans', 'NotoSansCJK', 'NotoSansThai', 'NotoEmoji'}


def check_fonts(assets):
    manifest = json.loads((assets / 'FontManifest.json').read_text())
    found = {entry['family'] for entry in manifest}
    missing = FAMILIES - found
    if missing:
        raise AssertionError(f'Missing fonts in {assets}: {sorted(missing)}')
    for entry in manifest:
        for font in entry['fonts']:
            path = assets / font['asset']
            if not path.is_file() or path.stat().st_size == 0:
                raise AssertionError(f'Missing/empty font asset: {path}')
    seed = json.loads((assets / 'assets/catalogue/initial_catalogue.json').read_text())
    assert isinstance(seed['restaurants'], list) and isinstance(seed['reviews'], dict), 'Missing starting catalogue'
    assert seed['version'], 'Missing snapshot version'
    assert 'RESTAURANT_API_TOKEN' not in seed, 'Unexpected credentials in catalogue'
    icon = assets / 'assets' / 'beneede-icon.png'
    if not icon.is_file():
        raise AssertionError(f'Missing in-app BeneEde icon: {icon}')


def main():
    ios = ROOT / 'ios' / 'iphoneos' / 'Runner.app'
    info = plistlib.loads((ios / 'Info.plist').read_bytes())
    assert info['CFBundleDisplayName'] == 'BeneEde'
    primary = info['CFBundleIcons']['CFBundlePrimaryIcon']
    assert primary['CFBundleIconName'] == 'AppIcon'
    assert list(ios.glob('AppIcon*.png')), 'Missing compiled iOS app icons'
    check_fonts(ios / 'Frameworks' / 'App.framework' / 'flutter_assets')
    print('PASS: iOS release name, compiled app icons, logo and all required fonts')

    mac = ROOT / 'macos' / 'Build' / 'Products' / 'Release' / 'BeneEde.app' / 'Contents'
    info = plistlib.loads((mac / 'Info.plist').read_bytes())
    assert info['CFBundleName'] == 'BeneEde'
    assert info['CFBundleIconName'] == 'AppIcon'
    assert (mac / 'Resources' / 'AppIcon.icns').is_file()
    check_fonts(mac / 'Frameworks' / 'App.framework' / 'Resources' / 'flutter_assets')
    print('PASS: macOS release name, application icon, logo and all required fonts')

    web = ROOT / 'web'
    manifest = json.loads((web / 'manifest.json').read_text())
    assert manifest['name'] == 'BeneEde'
    for icon in manifest['icons']:
        assert (web / unquote(urlsplit(icon['src']).path)).is_file(), 'Missing web application icon'
    check_fonts(web / 'assets')
    print('PASS: web manifest, application icons, logo and all required fonts')


if __name__ == '__main__':
    main()
