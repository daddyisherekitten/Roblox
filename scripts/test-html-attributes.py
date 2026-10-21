"""Protect manual HTML requirements and every existing evidence axis on export.

Synthetic provenance/files live in temporary build folders; no register or
engine files are changed and no network/browser/engine tests are run.
"""
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


EXPORT = load('html_attribute_export_test', 'export-html-attributes.py')
CHECK = load('html_attribute_check_test', 'check-html-attributes.py')


class AttributeAudit(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='html-attribute-tests-', dir=ROOT / 'build')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in ['docs', 'tests/fixtures', 'scripts']:
            (self.root / folder).mkdir(parents=True)
        (self.root / 'docs/PROFILE.md').write_text('Checked audio profile\n', encoding='utf-8')
        (self.root / 'tests/Native.luau').write_text('-- mounted case\n-- behavior case\n', encoding='utf-8')
        (self.root / 'scripts/runner.cjs').write_text('// synthetic runner\n', encoding='utf-8')
        self.pin = {'commit': 'a' * 40, 'commitDate': '2026-10-06T09:12:18Z',
                    'source': 'https://raw.githubusercontent.com/whatwg/html/' + 'a' * 40 + '/source',
                    'sha256': 'b' * 64}
        self.provenance = self.root / 'tests/fixtures/pin.json'
        self.provenance.write_text(json.dumps({'target': self.pin}), encoding='utf-8')

    def entry(self):
        proof = {'test': 'tests/Native.luau', 'scope': 'Legacy bounded proof',
                 'cases': ['behavior case'], 'environment': 'Synthetic fixture', 'elements': ['audio']}
        return {'id': 'preload|audio;video', 'attribute': 'preload', 'appliesTo': ['audio', 'video'],
                'family': 'content', 'references': ['https://html.spec.whatwg.org/multipage/media.html#attr-media-preload'],
                'evidence': {axis: [copy.deepcopy(proof)] for axis in EXPORT.AXES},
                'reviewedRequirements': {'mapping': 'partial', 'reviewed': '2026-10-12',
                                        'items': [{'id': 'audio-retained-selection', 'status': 'open',
                                                   'scope': 'Only audio, retained selected resource',
                                                   'elements': ['audio'], 'profile': 'docs/PROFILE.md#checked-audio',
                                                   'standard': 'https://html.spec.whatwg.org/multipage/media.html#attr-media-preload',
                                                   'source': {'revision': self.pin['commit'], 'date': '2026-10-06',
                                                              'sha256': self.pin['sha256'], 'url': self.pin['source'],
                                                              'provenance': 'tests/fixtures/pin.json', 'record': 'target'},
                                                   'acceptance': ['Retain resource through hint upgrade'],
                                                   'evidence': []}]}}

    def generated(self, entry):
        result = {key: copy.deepcopy(value) for key, value in entry.items() if key not in {'evidence', 'reviewedRequirements'}}
        result['evidence'] = {axis: [] for axis in EXPORT.AXES}
        return result

    def register(self, entry):
        return {'schema': 'html-attribute-audit/v1', 'retrieved': '2026-10-06',
                'sources': [{'url': EXPORT.BASE + filename, 'sha256': 'c' * 64}
                            for filename in ['indices.html', 'webappapis.html']], 'entries': [entry]}

    def requirement(self, entry):
        return entry['reviewedRequirements']['items'][0]

    def closed(self):
        entry = self.entry()
        self.requirement(entry).update(status='fulfilled', evidence=[
            {'path': 'tests/Native.luau', 'scope': 'Mounted native counterpart', 'environment': 'Synthetic fixture',
             'cases': ['mounted case'], 'runner': 'scripts/runner.cjs'}])
        return entry

    def catalog(self, include_entry=True, index_hash='c' * 64, handler_hash='c' * 64):
        # Reference discovery alone is synthetic; the export join and writes
        # remain real, without a parser/network dependency in these unit tests.
        name, applies, link, row, table, index, handlers = [mock.Mock() for _ in range(7)]
        name.text_content.return_value = 'preload'
        applies.text_content.return_value = 'audio; video'
        link.get.return_value = 'media.html#attr-media-preload'
        applies.xpath.return_value = [link]
        row.xpath.return_value = [name, applies]
        table.xpath.return_value = [mock.Mock(), row] if include_entry else [mock.Mock()]
        index.get_element_by_id.return_value.xpath.return_value = [table]
        handlers.xpath.return_value = []
        def reference(filename):
            return (index if filename == 'indices.html' else handlers), {
                'url': EXPORT.BASE + filename,
                'sha256': index_hash if filename == 'indices.html' else handler_hash}
        return reference

    def test_export_preserves_every_axis_and_manual_field_without_promotion(self):
        old = self.entry()
        old['evidence']['parsing'][0]['historicalNote'] = {'retained': [False, '']}
        self.requirement(old)['source']['extra'] = {'historical': True}
        frozen = copy.deepcopy(old)
        generated = self.generated(old)
        new = self.generated(old)
        new.update(id='poster|video', attribute='poster', appliesTo=['video'])
        EXPORT.retain_reviewed_records([generated, new], [old])
        self.assertEqual(generated, old)
        self.assertEqual(old, frozen)
        self.assertNotIn('reviewedRequirements', new)
        self.assertTrue(all(not value for value in new['evidence'].values()))
        EXPORT.retain_reviewed_records([generated, new], [generated, new])
        self.assertEqual(generated, frozen)
        generated['evidence']['parsing'][0]['cases'].append('new change')
        self.requirement(generated)['source']['extra']['historical'] = False
        self.assertEqual(old, frozen, 'Generated output must not mutate the prior audit')

    def test_missing_groups_cannot_drop_reviews_or_legacy_evidence(self):
        for reviewed, evidence in [(True, True), (False, True), (False, False)]:
            old = self.entry()
            if not reviewed:
                old.pop('reviewedRequirements')
            if not evidence:
                old['evidence'] = {axis: [] for axis in EXPORT.AXES}
            with self.subTest(reviewed=reviewed, evidence=evidence), self.assertRaisesRegex(AssertionError, 'disappeared'):
                EXPORT.retain_reviewed_records([], [old])

    def test_reused_group_identity_cannot_reassign_old_evidence(self):
        for field, value in [('attribute', 'src'), ('appliesTo', ['video']), ('family', 'pattern'),
                             ('references', ['https://example.test/different#definition'])]:
            old = self.entry()
            generated = self.generated(old)
            generated[field] = value
            with self.subTest(field=field), self.assertRaisesRegex(AssertionError, 'identity changed'):
                EXPORT.retain_reviewed_records([generated], [old])

    def test_failed_join_is_atomic_and_axes_are_never_repaired_silently(self):
        old = self.entry()
        second = copy.deepcopy(old)
        second.update(id='poster|video', attribute='poster', appliesTo=['video'])
        self.requirement(second)['elements'] = ['video']
        generated = [self.generated(old), self.generated(second)]
        generated[1]['references'] = ['https://example.test/changed#definition']
        before = copy.deepcopy(generated)
        with self.assertRaisesRegex(AssertionError, 'identity changed'):
            EXPORT.retain_reviewed_records(generated, [old, second])
        self.assertEqual(generated, before)
        for invalid in [{}, {'unexpected': []}, {**old['evidence'], 'parsing': 'not a list'}]:
            entry = self.entry()
            entry['evidence'] = invalid
            with self.subTest(axes=invalid), self.assertRaises(AssertionError):
                EXPORT.retain_reviewed_records([self.generated(entry)], [entry])

    def test_duplicate_group_and_requirement_ids_are_rejected(self):
        old = self.entry()
        for entries, previous in [([self.generated(old)] * 2, [old]), ([self.generated(old)], [old, old])]:
            with self.assertRaisesRegex(AssertionError, 'duplicate attribute group'):
                EXPORT.retain_reviewed_records(entries, previous)
        self.requirement(old)['evidence'] = []
        old['reviewedRequirements']['items'].append(copy.deepcopy(self.requirement(old)))
        with self.assertRaisesRegex(AssertionError, 'Duplicate requirement ID'):
            EXPORT.reviewed_requirements([old])

    def test_mapping_inventory_does_not_imply_completion(self):
        for mapping in ['partial', 'complete']:
            for status in ['open', 'unchecked']:
                entry = self.entry()
                entry['reviewedRequirements']['mapping'] = mapping
                self.requirement(entry)['status'] = status
                CHECK.validate(self.register(entry), self.root)
                self.assertEqual(self.requirement(entry)['status'], status)
        for status in ['fulfilled', 'technical-boundary', 'deferred']:
            entry = self.entry()
            self.requirement(entry)['status'] = status
            with self.subTest(status=status), self.assertRaisesRegex(AssertionError, 'requires evidence'):
                EXPORT.reviewed_requirements([entry])
            entry = self.closed()
            self.requirement(entry)['status'] = status
            CHECK.validate(self.register(entry), self.root)

    def test_requirement_schema_rejects_undelimited_or_invalid_records(self):
        mutations = [lambda e: e['reviewedRequirements'].update(mapping=[]),
                     lambda e: e['reviewedRequirements'].update(reviewed='2026-99-12'),
                     lambda e: e['reviewedRequirements'].update(items=[]),
                     lambda e: self.requirement(e).update(status='invented'),
                     lambda e: self.requirement(e).update(status=[]),
                     lambda e: self.requirement(e).update(id='bad id'),
                     lambda e: self.requirement(e).update(scope=' '),
                     lambda e: self.requirement(e).update(acceptance='not a criteria list'),
                     lambda e: self.requirement(e).update(standard='https://example.test/no-fragment'),
                     lambda e: self.requirement(e).update(evidence={}),
                     lambda e: self.requirement(e).update(source={}),
                     lambda e: self.requirement(e)['source'].update(revision='latest'),
                     lambda e: self.requirement(e)['source'].update(date='2026-02-30'),
                     lambda e: self.requirement(e)['source'].update(sha256='not a sha'),
                     lambda e: self.requirement(e)['source'].update(url='https://example.test/moving/source'),
                     lambda e: self.requirement(e)['source'].update(record='target[0]')]
        for index, mutation in enumerate(mutations):
            entry = self.entry()
            mutation(entry)
            with self.subTest(index=index), self.assertRaises(AssertionError):
                EXPORT.reviewed_requirements([entry])

    def test_elements_are_a_nonempty_unique_applicability_subset(self):
        for elements in [[], ['img'], ['audio', 'audio'], 'audio']:
            entry = self.entry()
            self.requirement(entry)['elements'] = elements
            with self.subTest(elements=elements), self.assertRaises(AssertionError):
                CHECK.validate(self.register(entry), self.root)
        entry = self.entry()
        self.requirement(entry)['elements'] = ['video', 'audio']
        CHECK.validate(self.register(entry), self.root)

    def test_durable_pin_matches_source_not_fixture_file_hash(self):
        entry = self.closed()
        self.assertNotEqual(hashlib.sha256(self.provenance.read_bytes()).hexdigest(), self.pin['sha256'])
        CHECK.validate(self.register(entry), self.root)
        self.assertFalse((self.root / 'build').exists(), 'No raw standard cache required')
        for field, value in [('commit', 'c' * 40), ('commitDate', '2026-10-05T09:12:18Z'),
                             ('source', 'https://example.test/' + 'a' * 40 + '/source'), ('sha256', 'c' * 64)]:
            altered = dict(self.pin)
            altered[field] = value
            self.provenance.write_text(json.dumps({'target': altered}), encoding='utf-8')
            with self.subTest(field=field), self.assertRaisesRegex(AssertionError, 'differs from provenance'):
                CHECK.validate(self.register(entry), self.root)
        self.provenance.write_text(json.dumps({'outer': {'target': self.pin}}), encoding='utf-8')
        self.requirement(entry)['source']['record'] = 'outer.target'
        CHECK.validate(self.register(entry), self.root)
        self.requirement(entry)['source']['record'] = 'outer.missing'
        with self.assertRaisesRegex(AssertionError, 'record missing'):
            CHECK.validate(self.register(entry), self.root)
        invalid_date = {**self.pin, 'commitDate': '2026-10-06T99:99:99Z'}
        self.provenance.write_text(json.dumps({'outer': {'target': invalid_date}}), encoding='utf-8')
        self.requirement(entry)['source']['record'] = 'outer.target'
        with self.assertRaisesRegex(AssertionError, 'provenance date'):
            CHECK.validate(self.register(entry), self.root)

    def test_paths_and_closure_case_anchors_are_checked(self):
        mutations = [lambda r: r.update(profile='../outside.md'),
                     lambda r: r.update(profile='docs/missing.md'),
                     lambda r: r['evidence'][0].update(path='../outside.luau'),
                     lambda r: r['evidence'][0].update(path=str(self.root / 'tests/Native.luau')),
                     lambda r: r['evidence'][0].update(runner='scripts/missing.cjs'),
                     lambda r: r['evidence'][0].update(cases=['missing assertion']),
                     lambda r: r['source'].update(provenance='../outside.json'),
                     lambda r: r['source'].update(provenance='tests/fixtures/missing.json')]
        for index, mutation in enumerate(mutations):
            entry = self.closed()
            mutation(self.requirement(entry))
            with self.subTest(index=index), self.assertRaises(AssertionError):
                CHECK.validate(self.register(entry), self.root)
        entry = self.entry()
        entry['evidence']['behavior'][0]['cases'] = ['missing legacy assertion']
        with self.assertRaisesRegex(AssertionError, 'Evidence assertion not found'):
            CHECK.validate(self.register(entry), self.root)

    def test_export_main_roundtrip_and_failed_discovery_preserve_saved_register(self):
        entry = self.closed()
        output = self.root / 'docs/html-attributes.v1.json'
        output.write_text(json.dumps(self.register(entry)), encoding='utf-8')
        with mock.patch.object(EXPORT, 'ROOT', self.root), mock.patch.object(EXPORT, 'OUTPUT', output), mock.patch.object(EXPORT, 'reference', side_effect=self.catalog()) as reference, contextlib.redirect_stdout(io.StringIO()):
            with mock.patch.object(sys, 'argv', ['export-html-attributes.py']):
                EXPORT.main()
            saved = output.read_text(encoding='utf-8')
            parsed = json.loads(saved)
            actual = next(e for e in parsed['entries'] if e['id'] == entry['id'])
            self.assertEqual(actual, entry)
            CHECK.validate(parsed, self.root)
            with mock.patch.object(sys, 'argv', ['export-html-attributes.py', '--check']), mock.patch.object(Path, 'write_text', side_effect=AssertionError('Check must not write')):
                EXPORT.main()
            reference.side_effect = self.catalog(include_entry=False)
            with mock.patch.object(sys, 'argv', ['export-html-attributes.py']), self.assertRaisesRegex(AssertionError, 'disappeared'):
                EXPORT.main()
            self.assertEqual(output.read_text(encoding='utf-8'), saved)

    def test_changed_raw_catalog_cannot_rebase_identical_groups(self):
        output = self.root / 'docs/html-attributes.v1.json'
        register = self.register(self.closed())
        for index_hash, handler_hash in [('d' * 64, 'c' * 64), ('c' * 64, 'd' * 64)]:
            saved = json.dumps(register, ensure_ascii=False, indent=2) + '\n'
            output.write_text(saved, encoding='utf-8')
            before = output.read_bytes()
            with self.subTest(index=index_hash, handler=handler_hash), mock.patch.object(EXPORT, 'ROOT', self.root), mock.patch.object(EXPORT, 'OUTPUT', output), mock.patch.object(EXPORT, 'reference', side_effect=self.catalog(index_hash=index_hash, handler_hash=handler_hash)), mock.patch.object(sys, 'argv', ['export-html-attributes.py']), self.assertRaisesRegex(AssertionError, 'Frozen catalog source changed'):
                EXPORT.main()
            self.assertEqual(output.read_bytes(), before, 'Even identical facts cannot rebase the frozen source')

    def test_missing_or_invalid_pins_fail_before_reference_discovery(self):
        output = self.root / 'docs/html-attributes.v1.json'
        invalid_sources = [None, [], [{'url': EXPORT.BASE + 'indices.html', 'sha256': 'c' * 64}],
                           [{'url': EXPORT.BASE + 'indices.html', 'sha256': 'c' * 64}] * 2,
                           [{'url': EXPORT.BASE + filename} for filename in ['indices.html', 'webappapis.html']]]
        for sources in invalid_sources:
            register = self.register(self.closed())
            register['sources'] = sources
            saved = json.dumps(register)
            output.write_text(saved, encoding='utf-8')
            with self.subTest(sources=sources), mock.patch.object(EXPORT, 'OUTPUT', output), mock.patch.object(EXPORT, 'reference') as reference, mock.patch.object(sys, 'argv', ['export-html-attributes.py']), self.assertRaises(AssertionError):
                EXPORT.main()
            reference.assert_not_called()
            self.assertEqual(output.read_text(encoding='utf-8'), saved)
        register = self.register(self.closed())
        register['retrieved'] = '2026-10-12'
        saved = json.dumps(register)
        output.write_text(saved, encoding='utf-8')
        with mock.patch.object(EXPORT, 'OUTPUT', output), mock.patch.object(EXPORT, 'reference') as reference, mock.patch.object(sys, 'argv', ['export-html-attributes.py']), self.assertRaisesRegex(AssertionError, 'catalog date changed'):
            EXPORT.main()
        reference.assert_not_called()
        self.assertEqual(output.read_text(encoding='utf-8'), saved)


if __name__ == '__main__':
    unittest.main()
