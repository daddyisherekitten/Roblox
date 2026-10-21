"""Pinned Unicode 17 Vertical_Orientation and enclosing-mark data.

Network access occurs only with --download; ordinary generation is offline.
"""
from pathlib import Path
import argparse, hashlib, json, urllib.request

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / 'scripts/data/unicode-vertical-17.0.0'
BASE = 'https://www.unicode.org/Public/17.0.0/ucd/'

def generate():
    parser = argparse.ArgumentParser()
    parser.add_argument('--download', action='store_true')
    args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    target = CACHE / 'VerticalOrientation.txt'
    if args.download:
        target.write_bytes(urllib.request.urlopen(BASE + target.name, timeout=30).read())
    data = target.read_bytes()
    if not data.startswith(b'# VerticalOrientation-17.0.0.txt'):
        raise ValueError('Unexpected Unicode vertical-orientation version')
    unicode = ROOT / 'scripts/data/unicode-17.0.0/UnicodeData.txt'
    manifest = {'version': '17.0.0', 'algorithm': 'https://www.unicode.org/reports/tr50/tr50-33.html',
                'license': '../../../src/HTMLEngine/JavaScript/Unicode.LICENSE.txt',
                'sources': {target.name: {'url': BASE + target.name, 'sha256': hashlib.sha256(data).hexdigest()},
                            'UnicodeData.txt': {'url': BASE + unicode.name, 'sha256': hashlib.sha256(unicode.read_bytes()).hexdigest()}}}
    ranges = []
    for line in data.decode('utf8').splitlines():
        value = line.split('#', 1)[0].strip()
        if not value: continue
        interval, kind = [part.strip() for part in value.split(';')]
        ends = interval.split('..'); first, last = int(ends[0], 16), int(ends[-1], 16)
        if kind == 'R': continue
        if ranges and ranges[-1][1]+1 == first and ranges[-1][2] == kind:
            ranges[-1][1] = last
        else: ranges.append([first, last, kind])
    enclosing = [int(line.split(';')[0], 16) for line in unicode.read_text(encoding='utf8').splitlines()
                 if line.split(';')[2] == 'Me']
    license_lines = (ROOT / 'src/HTMLEngine/JavaScript/Unicode.LICENSE.txt').read_text(encoding='utf8').splitlines()
    lines = ['--!strict', '-- Generated Unicode 17.0.0 UAX50 data; scripts/generate-vertical-orientation.py.',
             '-- SHA256 provenance: scripts/data/unicode-vertical-17.0.0/manifest.json.',
             *['-- ' + line for line in license_lines], 'return {Version="17.0.0",Ranges={']
    lines.extend('{%d,%d,"%s"},' % tuple(value) for value in ranges)
    lines.extend(['},Enclosing={', *['[%d]=true,' % value for value in enclosing], '}}\n'])
    (ROOT / 'src/HTMLEngine/Layout/VerticalOrientationData.luau').write_text('\n'.join(lines), encoding='utf8')
    (CACHE / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf8')
    print('Unicode17 vertical orientation:', len(ranges), 'non-R intervals;', len(enclosing), 'enclosing marks')

if __name__ == '__main__': generate()
