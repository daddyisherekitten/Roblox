"""Import upstream document-tree expectations without running another parser.

The resulting fixtures are independent expectations, not snapshots of our engine.
Fragment fixtures use a distinct contextual contract and fixture collection.
"""
import json
import hashlib
import argparse
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent.parent
FILES = ['tests1', 'tests2', 'tests3', 'tests4', 'tests5', 'tests6', 'tests7',
         'tests8', 'tests9', 'tests10', 'adoption01', 'adoption02', 'tables01',
         'comments01', 'entities01', 'doctype01', 'inbody01', 'template', 'svg', 'math',
         'tests11','tests12','tests14','tests15','tests16','tests17','tests18','tests19',
         'tests20','tests21','tests22','tests23','tests24','tests25','tests26',
         'tricky01','webkit01','webkit02','blocks','pending-spec-changes','domjs-unsafe',
         'plain-text-unsafe','ruby','noscript01','search-element','isindex']
REVISION = '9710d2af7737513c93d823fddf364c36b2574c4c'
BASE = 'https://github.com/web-platform-tests/wpt/blob/' + REVISION + '/html/syntax/parsing/resources/'
RAW = 'https://raw.githubusercontent.com/web-platform-tests/wpt/' + REVISION + '/html/syntax/parsing/resources/'
OUTPUT = ROOT / 'tests/fixtures/html-document-tree.json'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    cases, sources, fragments = [], [], []
    for filename in FILES:
        cache = ROOT / ('build/reference/' + filename + '.dat')
        if not cache.exists():
            cache.parent.mkdir(parents=True, exist_ok=True)
            with urlopen(RAW + filename + '.dat', timeout=30) as response:
                cache.write_bytes(response.read())
        raw = cache.read_bytes()
        sources.append({'url': BASE + filename + '.dat', 'sha256': hashlib.sha256(raw).hexdigest()})
        for index, part in enumerate(raw.decode('utf-8').split('#data\n')[1:], 1):
            sections, key = {}, 'data'
            for line in part.splitlines(keepends=True):
                if line.startswith('#'):
                    key = line.strip()[1:]
                    sections.setdefault(key, '')
                else:
                    sections[key] = sections.get(key, '') + line
            source = sections['data'].removesuffix('\n')
            expected = sections['document'].rstrip('\n')
            case = {'id': filename + ':' + str(index), 'html': source,
                    'scripting': 'script-off' not in sections, 'expected': expected}
            if 'document-fragment' in sections:
                case['context'] = sections['document-fragment'].strip()
                fragments.append(case)
            else:
                cases.append(case)
    result = {'schema': 'html-document-tree-fixtures/v1', 'retrieved': '2026-10-06',
              'upstreamRevision': REVISION, 'license': 'html-document-tree.LICENSE',
              'sources': sources, 'cases': cases, 'fragments': fragments}
    output = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.check:
        if OUTPUT.read_text(encoding='utf-8') != output:
            raise SystemExit('HTML tree fixtures differ from the pinned upstream references')
    else:
        OUTPUT.write_text(output, encoding='utf-8')
    print('Imported %d independent document cases and %d contextual fragment cases' % (len(cases), len(fragments)))


if __name__ == '__main__':
    main()
