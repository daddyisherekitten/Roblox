"""Check evidence provenance; references do not prove browser conformance."""
import json
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('html_attribute_export', Path(__file__).with_name('export-html-attributes.py'))
EXPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXPORT)
AXES = EXPORT.AXES


def validate(register, root):
    assert register['schema'] == 'html-attribute-audit/v1'
    assert register.get('retrieved') == '2026-10-06', 'Frozen catalog date changed'
    EXPORT.source_pins(register.get('sources'))
    entries = register['entries']
    identifiers = EXPORT.entry_map(entries)
    reviewed = EXPORT.reviewed_requirements(entries)
    EXPORT.requirement_paths(reviewed, root)
    for entry in register['entries']:
        assert isinstance(entry['evidence'], dict) and set(entry['evidence']) == AXES, 'Every evidence axis must remain visible'
        for axis, proofs in entry['evidence'].items():
            assert isinstance(proofs, list), 'Evidence axes must be lists'
            for proof in proofs:
                path = EXPORT.project_file(root, proof['test'])
                assert path.is_relative_to((root / 'tests').resolve()), 'Invalid evidence source'
                assert EXPORT.text(proof['scope']) and EXPORT.strings(proof['cases']) and EXPORT.text(proof['environment']), 'Missing evidence scope'
                if axis != 'parsing':
                    assert EXPORT.strings(proof['elements']), 'Proof must identify the tested element subset'
                    source = path.read_text(encoding='utf-8')
                    assert all(case in source for case in proof['cases']), 'Evidence assertion not found in source'
    counts = {axis: sum(bool(e['evidence'][axis]) for e in register['entries']) for axis in sorted(AXES)}
    return len(identifiers), counts, len(reviewed)


def main():
    register = json.loads((ROOT / 'docs/html-attributes.v1.json').read_text(encoding='utf-8'))
    groups, counts, reviewed = validate(register, ROOT)
    print('HTML attribute evidence:', groups, 'groups;', counts)
    print('Reviewed requirement mappings:', reviewed, '(not a complete remaining-work count)')


if __name__ == '__main__':
    main()
