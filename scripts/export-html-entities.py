"""Export factual named reference data from the WHATWG HTML standard.

The checked-in Luau table is the runtime input; no runtime HTTP request occurs.
Use --check against the cached source to detect accidental generator drift.
"""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent.parent
URL = 'https://html.spec.whatwg.org/entities.json'
CACHE = ROOT / 'build/reference/html-entities.json'
OUTPUT = ROOT / 'src/HTMLEngine/HTML/NamedEntities.luau'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if not CACHE.exists():
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        with urlopen(URL, timeout=30) as response:
            CACHE.write_bytes(response.read())
    raw = CACHE.read_bytes()
    data = json.loads(raw)
    rows = ['--!strict', '-- Generated factual data; scripts/export-html-entities.py.',
            '-- Source: ' + URL, '-- SHA256: ' + hashlib.sha256(raw).hexdigest(),
            '-- Both semicolon and explicitly allowed legacy spellings are keys.', 'return {']
    for name, entry in sorted(data.items()):
        value = ''.join('\\%03d' % byte for byte in entry['characters'].encode('utf-8'))
        rows.append('\t["%s"] = "%s",' % (name[1:], value))
    source = '\n'.join(rows + ['}', ''])
    if args.check:
        if OUTPUT.read_text(encoding='utf-8') != source:
            raise SystemExit('NamedEntities.luau differs from the reference export')
    else:
        OUTPUT.write_text(source, encoding='utf-8')
    print('HTML named references: %d spellings, source SHA256 %s' % (len(data), hashlib.sha256(raw).hexdigest()))


if __name__ == '__main__':
    main()
