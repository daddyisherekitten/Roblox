"""Validate the complete frozen CSS inventory and narrow evidence provenance.

No network/native rendering, and no claim that a registration is conformance.
Run export-css-coverage.py --check separately to repeat actual compiler probes.
"""
import collections
import hashlib
import json
import importlib.util
from functools import cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('css_coverage_export', Path(__file__).with_name('export-css-coverage.py'))
EXPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXPORT)


@cache
def project_file(name):
    path = (ROOT / name).resolve()
    assert path.is_relative_to(ROOT) and path.is_file(), f'Invalid source path: {name}'
    return path


@cache
def source_lines(name):
    return project_file(name).read_text(encoding='utf-8').splitlines()


def main():
    coverage = json.loads(project_file('docs/css-features.v1.json').read_text(encoding='utf-8'))
    reference_path = project_file(coverage['reference'])
    cases_path = project_file(coverage['probeCases'])
    reference = json.loads(reference_path.read_text(encoding='utf-8'))
    cases = json.loads(cases_path.read_text(encoding='utf-8'))
    assert coverage['schema'] == 'css-feature-coverage/v1'
    assert reference['schema'] == 'css-standard-reference/v1'
    assert cases['schema'] == 'css-declaration-probe-cases/v1'
    assert coverage['date'] == reference['date'] == '2026-10-06'
    for path, key in [(reference_path, 'referenceSha256'), (cases_path, 'probeCasesSha256')]:
        assert hashlib.sha256(path.read_bytes()).hexdigest() == coverage[key], f'Stale source hash: {path.name}'
    entries = coverage['entries']
    reviewed = EXPORT.reviewed_requirements(entries)
    for record in reviewed.values():
        for requirement in record['items']:
            project_file(requirement['profile'].split('#', 1)[0])
            for evidence in requirement['evidence']:
                project_file(evidence['path'])
    by_id = {entry['id']: entry for entry in entries}
    assert len(by_id) == len(entries), 'Duplicate coverage ID'
    expected = {entry['id']: entry for entry in reference['entries']}
    assert len(expected) == len(reference['entries']), 'Duplicate reference ID'
    assert set(expected) <= set(by_id), 'A frozen standard definition disappeared'
    for identifier, original in expected.items():
        actual = by_id[identifier]
        assert all(actual.get(key) == value for key, value in original.items()), f'Changed standard fact: {identifier}'
    assert all(by_id[key]['priorityCategory'] == 'engine-registration-not-in-reference'
               for key in set(by_id) - set(expected)), 'Unattributed reference extension'
    for entry in entries:
        assert entry['conformance'] == 'no-full-standard-completion-claim'
        assert entry['availability'] and entry['priorityCategory']
        for locator in entry['codeLocators']:
            assert 1 <= locator['line'] <= len(source_lines(locator['path'])), 'Invalid code locator'
        for evidence in entry['evidence']:
            assert evidence['scope'], 'Evidence must delimit its actual proof'
            for key in ['path', 'runner']:
                if key in evidence:
                    project_file(evidence[key])
        if entry['kind'] == 'function' and entry['name'] in cases['functions']:
            sources = cases['functions'][entry['name']]
            sources = sources if isinstance(sources, list) else [sources]
            assert [e['source'] for e in entry['evidence']] == sources, 'Function example was lost'
            assert all(isinstance(e['accepted'], bool) for e in entry['evidence'])
    for profile in coverage['profileDocuments']:
        project_file(profile)
    counts = collections.Counter(entry['kind'] for entry in entries)
    print('CSS reference coverage:', len(expected), 'definitions,', len(entries), 'coverage entries;', dict(counts))
    print('Reviewed requirement mappings:', len(reviewed), '(not a complete remaining-work count)')


if __name__ == '__main__':
    main()
