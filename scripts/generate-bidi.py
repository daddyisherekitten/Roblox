"""Pinned Unicode 17 bracket/mirror data and full UAX9 conformance corpus.

Only --download accesses the network; later regeneration uses recorded bytes.
"""
from pathlib import Path
import argparse, hashlib, json, urllib.request

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / 'scripts/data/unicode-bidi-17.0.0'
BASE = 'https://www.unicode.org/Public/17.0.0/ucd/'
FILES = ['BidiBrackets.txt', 'BidiMirroring.txt', 'BidiTest.txt', 'BidiCharacterTest.txt']

def generate():
    parser = argparse.ArgumentParser(); parser.add_argument('--download', action='store_true'); args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    manifest = {'version': '17.0.0', 'algorithm': 'https://www.unicode.org/reports/tr9/tr9-51.html',
                'license': '../../../src/HTMLEngine/JavaScript/Unicode.LICENSE.txt', 'sources': {}}
    for name in FILES:
        target = CACHE / name
        if args.download:
            target.write_bytes(urllib.request.urlopen(BASE + name, timeout=30).read())
        data = target.read_bytes()
        if not data.startswith(('# ' + name.replace('.txt', '-17.0.0.txt')).encode()):
            raise ValueError('Unexpected Unicode version: ' + name)
        manifest['sources'][name] = {'url': BASE + name, 'sha256': hashlib.sha256(data).hexdigest()}
    license_lines = (ROOT / 'src/HTMLEngine/JavaScript/Unicode.LICENSE.txt').read_text(encoding='utf8').splitlines()
    lines = ['--!strict', '-- Generated Unicode 17.0.0 bracket/mirror data; scripts/generate-bidi.py.',
             '-- SHA256 provenance: scripts/data/unicode-bidi-17.0.0/manifest.json.', *['-- ' + line for line in license_lines], 'return {Version="17.0.0",Brackets={']
    brackets, mirrors = {}, {}
    for name, result in [('BidiBrackets.txt', brackets), ('BidiMirroring.txt', mirrors)]:
        for line in (CACHE / name).read_text(encoding='utf8').splitlines():
            value = line.split('#', 1)[0].strip()
            if value:
                parts = [part.strip() for part in value.split(';')]
                result[int(parts[0], 16)] = (int(parts[1], 16), parts[2]) if result is brackets else int(parts[1], 16)
    lines.extend(f'[{code}]={{Pair={pair},Open={str(kind == "o").lower()}}},' for code, (pair, kind) in sorted(brackets.items()))
    lines.append('},Mirrors={'); lines.extend(f'[{code}]={value},' for code, value in sorted(mirrors.items())); lines.append('}}\n')
    (ROOT / 'src/HTMLEngine/Layout/BidiData.luau').write_text('\n'.join(lines), encoding='utf8')
    (CACHE / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf8')
    print('Unicode17 bidi:', len(brackets), 'paired brackets,', len(mirrors), 'mirror mappings; full conformance files cached')

if __name__ == '__main__':
    generate()
