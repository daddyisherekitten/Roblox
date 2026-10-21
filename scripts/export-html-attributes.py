"""Build the HTML attribute audit register from the standard's factual index.

Descriptions are not copied. Reviewed evidence is retained by stable entry id.
Discovery never promotes a stored attribute to implemented behavior or rendering.
"""
import argparse
import copy
from datetime import date, datetime
import hashlib
import json
import re
from pathlib import Path
from urllib.request import urlopen
from urllib.parse import urljoin, urlsplit

ROOT = Path(__file__).resolve().parent.parent
BASE = 'https://html.spec.whatwg.org/multipage/'
OUTPUT = ROOT / 'docs/html-attributes.v1.json'
AXES = {'parsing', 'reflection', 'behavior', 'rendering', 'combinations'}
STATUSES = {'fulfilled', 'open', 'unchecked', 'technical-boundary', 'deferred'}
SOURCE_URLS = {BASE + 'indices.html', BASE + 'webappapis.html'}


def text(value):
    return isinstance(value, str) and bool(value.strip())


def strings(value):
    return isinstance(value, list) and bool(value) and all(text(item) for item in value)


def dated(value, label):
    assert text(value) and re.fullmatch(r'\d{4}-\d{2}-\d{2}', value), f'Invalid {label}'
    try:
        date.fromisoformat(value)
    except ValueError as error:
        raise AssertionError(f'Invalid {label}') from error


def https(value):
    if not text(value):
        return False
    try:
        parsed = urlsplit(value)
    except ValueError:
        return False
    return parsed.scheme == 'https' and bool(parsed.hostname)


def source_pins(sources):
    assert isinstance(sources, list) and len(sources) == len(SOURCE_URLS), 'Missing frozen catalog source pins'
    pins = {}
    for source in sources:
        assert isinstance(source, dict), 'Invalid frozen catalog source pin'
        url, digest = source.get('url'), source.get('sha256')
        assert text(url) and url in SOURCE_URLS and url not in pins, 'Missing/duplicate frozen catalog source URL'
        assert text(digest) and re.fullmatch(r'[0-9a-f]{64}', digest), 'Missing/invalid frozen catalog source hash'
        pins[url] = digest
    return pins


def retain_source_pins(previous, actual):
    assert source_pins(previous) == source_pins(actual), 'Frozen catalog source changed; reconcile explicitly before export'


def entry_map(entries):
    assert isinstance(entries, list), 'Attribute groups must be a list'
    by_id = {}
    for entry in entries:
        assert isinstance(entry, dict), 'Invalid attribute group'
        key = entry.get('id')
        assert text(key) and key not in by_id, 'Missing/duplicate attribute group ID'
        assert text(entry.get('attribute')) and strings(entry.get('appliesTo')), 'Missing attribute applicability'
        assert len(entry['appliesTo']) == len(set(entry['appliesTo'])), 'Duplicate applicability label'
        assert key == entry['attribute'] + '|' + ';'.join(entry['appliesTo']), 'Attribute group identity changed'
        assert text(entry.get('family')) and strings(entry.get('references')), 'Missing normative applicability'
        by_id[key] = entry
    return by_id


def reviewed_requirements(entries):
    """Validate manual, bounded requirements; catalog discovery is not completion."""
    reviewed = {}
    for key, entry in entry_map(entries).items():
        if 'reviewedRequirements' not in entry:
            continue
        record = entry['reviewedRequirements']
        assert isinstance(record, dict), 'Invalid reviewed requirement record'
        assert text(record.get('mapping')) and record['mapping'] in {'partial', 'complete'}, 'Invalid requirement mapping'
        dated(record.get('reviewed'), 'review date')
        items = record.get('items')
        assert isinstance(items, list) and items, 'An empty mapping is still unmapped'
        identifiers = set()
        for requirement in items:
            assert isinstance(requirement, dict), 'Invalid requirement'
            identifier = requirement.get('id')
            assert text(identifier) and re.fullmatch(r'[a-z0-9][a-z0-9-]*', identifier), 'Invalid requirement ID'
            assert identifier not in identifiers, 'Duplicate requirement ID'
            identifiers.add(identifier)
            assert text(requirement.get('status')) and requirement['status'] in STATUSES, 'Invalid requirement status'
            assert text(requirement.get('scope')) and text(requirement.get('profile')), 'Undelimited requirement'
            elements = requirement.get('elements')
            assert strings(elements) and len(elements) == len(set(elements)), 'Missing/duplicate requirement element subset'
            assert set(elements) <= set(entry['appliesTo']), 'Requirement elements outside attribute applicability'
            standard = requirement.get('standard')
            assert https(standard) and urlsplit(standard).fragment, 'Missing precise standard fragment'
            assert strings(requirement.get('acceptance')), 'Missing acceptance criteria'
            proofs = requirement.get('evidence')
            assert isinstance(proofs, list), 'Missing requirement evidence list'
            for proof in proofs:
                assert isinstance(proof, dict) and all(text(proof.get(field)) for field in ['path', 'scope', 'environment']), 'Undelimited requirement evidence'
                if 'cases' in proof:
                    assert strings(proof['cases']), 'Missing requirement evidence cases'
                if 'runner' in proof:
                    assert text(proof['runner']), 'Invalid requirement evidence runner'
            if requirement['status'] in {'fulfilled', 'technical-boundary', 'deferred'}:
                assert proofs, 'Closure/exception requires evidence'
            source = requirement.get('source')
            assert isinstance(source, dict), 'Missing frozen standard source'
            revision = source.get('revision')
            assert text(revision) and re.fullmatch(r'[0-9a-f]{40}', revision), 'Invalid frozen standard revision'
            dated(source.get('date'), 'source date')
            digest = source.get('sha256')
            assert text(digest) and re.fullmatch(r'[0-9a-f]{64}', digest), 'Invalid frozen standard hash'
            assert https(source.get('url')) and revision in urlsplit(source['url']).path.split('/'), 'Source URL must contain its immutable revision'
            assert text(source.get('provenance')), 'Missing durable source provenance'
            assert text(source.get('record')) and re.fullmatch(r'[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*', source['record']), 'Invalid source provenance record'
        reviewed[key] = record
    return reviewed


def project_file(root, name):
    assert text(name), 'Missing project path'
    relative = Path(name)
    assert not relative.is_absolute() and not relative.drive, f'Invalid project path: {name}'
    root = root.resolve()
    path = (root / relative).resolve()
    assert path.is_relative_to(root) and path.is_file(), f'Invalid project path: {name}'
    return path


def requirement_paths(reviewed, root):
    """Use durable fixture pins, never a downloaded standard/cache or network."""
    for record in reviewed.values():
        for requirement in record['items']:
            project_file(root, requirement['profile'].split('#', 1)[0])
            for proof in requirement['evidence']:
                path = project_file(root, proof['path'])
                if 'runner' in proof:
                    project_file(root, proof['runner'])
                if 'cases' in proof:
                    content = path.read_text(encoding='utf-8')
                    assert all(case in content for case in proof['cases']), 'Requirement evidence assertion not found in source'
            source = requirement['source']
            pin = json.loads(project_file(root, source['provenance']).read_text(encoding='utf-8'))
            for field in source['record'].split('.'):
                assert isinstance(pin, dict) and field in pin, 'Frozen source provenance record missing'
                pin = pin[field]
            assert isinstance(pin, dict), 'Invalid frozen source provenance record'
            assert pin.get('commit') == source['revision'], 'Frozen source revision differs from provenance'
            assert text(pin.get('commitDate')) and pin['commitDate'].startswith(source['date'] + 'T'), 'Frozen source date differs from provenance'
            try:
                datetime.fromisoformat(pin['commitDate'].replace('Z', '+00:00'))
            except ValueError as error:
                raise AssertionError('Invalid frozen source provenance date') from error
            assert pin.get('source') == source['url'], 'Frozen source URL differs from provenance'
            assert pin.get('sha256') == source['sha256'], 'Frozen source hash differs from provenance'


def retain_reviewed_records(entries, previous):
    """Fail before replacing any vanished/changed group or discarding its audit."""
    reviewed = reviewed_requirements(previous)
    old, generated = entry_map(previous), entry_map(entries)
    assert set(old) <= set(generated), 'Attribute group disappeared; reconcile before export'
    retained = {}
    for identifier, original in old.items():
        entry = generated[identifier]
        assert all(entry.get(field) == original.get(field) for field in ['attribute', 'appliesTo', 'family', 'references']), 'Reviewed attribute identity changed; reconcile before export'
        evidence = original.get('evidence')
        assert isinstance(evidence, dict) and set(evidence) == AXES, 'Every evidence axis must remain visible'
        assert all(isinstance(proofs, list) for proofs in evidence.values()), 'Evidence axes must be lists'
        retained[identifier] = {'evidence': copy.deepcopy(evidence)}
        if identifier in reviewed:
            retained[identifier]['reviewedRequirements'] = copy.deepcopy(reviewed[identifier])
    # Validate the entire join before mutating its first generated entry.
    for identifier, fields in retained.items():
        generated[identifier].update(fields)
    return reviewed


def reference(filename):
    from lxml import html
    path = ROOT / ('build/reference/html-' + filename)
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        with urlopen(BASE + filename, timeout=30) as response:
            path.write_bytes(response.read())
    raw = path.read_bytes()
    return html.fromstring(raw), {'url': BASE + filename, 'sha256': hashlib.sha256(raw).hexdigest()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    assert OUTPUT.is_file(), 'Missing frozen HTML attribute register; cannot discover a new dated baseline'
    old = json.loads(OUTPUT.read_text(encoding='utf-8'))
    assert old.get('retrieved') == '2026-10-06', 'Frozen catalog date changed; reconcile explicitly before export'
    source_pins(old.get('sources'))
    index, index_source = reference('indices.html')
    handlers, handler_source = reference('webappapis.html')
    retain_source_pins(old['sources'], [index_source, handler_source])
    entries = []

    def add(name, applies, links, family='content'):
        key = name + '|' + ';'.join(applies)
        entry = {'id': key, 'attribute': name, 'appliesTo': applies,
                        'family': family, 'references': sorted(set(links)),
                        'evidence': {axis: [] for axis in ['parsing', 'reflection', 'behavior', 'rendering', 'combinations']}}
        # The frozen 2026-10-06 index incorrectly links these global attributes
        # to tabindex. Preserve that provenance and use their real definition.
        if name in {'headingoffset', 'headingreset'}:
            entry['indexReferenceCorrection'] = {
                'original': sorted(set(links)), 'reviewed': '2026-10-10',
                'reason': 'Frozen index links the heading attributes to tabindex; corrected to the existing heading-level definition.'}
            entry['references'] = [BASE + 'sections.html#heading-levels-&-offsets']
        entries.append(entry)

    table = index.get_element_by_id('attributes-3').xpath('following::table')[0]
    for row in table.xpath('.//tr')[1:]:
        cells = row.xpath('./th|./td')
        name = ' '.join(cells[0].text_content().split())
        labels = [' '.join(part.split()) for part in cells[1].text_content().split(';') if part.strip()]
        # The live index occasionally omits a separator between adjacent tag
        # links (e.g. video/img). Keep their distinct applicability visible.
        labels = [tag for label in labels for tag in
                  (label.split() if re.fullmatch(r'[a-z][a-z0-9-]*(?: [a-z][a-z0-9-]*)+', label)
                   and label != 'form-associated custom elements' else [label])]
        links = [urljoin(index_source['url'], a.get('href')) for a in cells[1].xpath('.//a[@href]')]
        add(name, labels, links or [index_source['url'] + '#attributes-3'])
    # The index explicitly omits event handler content attributes. Include the
    # normative handler definitions separately; global and Window/body targets
    # must remain distinguishable when real dispatch evidence is recorded.
    names = {}
    for dfn in handlers.xpath('//dfn[@id]'):
        name = ''.join(dfn.itertext()).strip()
        if re.fullmatch(r'on[a-z]+', name) and dfn.get('id').startswith('handler-'):
            names.setdefault(name, []).append(handler_source['url'] + '#' + dfn.get('id'))
    for name, links in sorted(names.items()):
        window_only = any('#handler-window-' in link for link in links)
        add(name, ['body (Window handler)' if window_only else 'HTML elements (event target)'], links, 'event-handler')
    add('data-*', ['HTML elements'], [BASE + 'dom.html#embedding-custom-non-visible-data-with-the-data-*-attributes'], 'pattern')
    reviewed = retain_reviewed_records(entries, old['entries'])
    requirement_paths(reviewed, ROOT)
    result = {'schema': 'html-attribute-audit/v1', 'retrieved': '2026-10-06',
              'scope': 'Conforming HTML content attributes and HTML event handlers; legacy attributes, ARIA semantics, SVG/MathML attributes and arbitrary data-* names are separate scopes.',
              'evidenceRule': 'Every evidence reference proves only its named cases. Empty axis = not audited; parsing alone proves no behavior or appearance. Rendering tests use GUI mocks unless explicitly marked native.',
              'sources': copy.deepcopy(old['sources']), 'entries': sorted(entries, key=lambda item: item['id'])}
    source = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.check:
        if OUTPUT.read_text(encoding='utf-8') != source:
            raise SystemExit('HTML attribute register differs from reference export')
    else:
        OUTPUT.write_text(source, encoding='utf-8')
    print('HTML attribute register: %d applicability groups (%d handler names)' % (len(entries), len(names)))


if __name__ == '__main__':
    main()
