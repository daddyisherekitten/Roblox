"""Regression checks for documentation preservation and reference validation."""
from pathlib import Path
import importlib.util
import json
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location('documentation', Path(__file__).with_name('check-documentation.py'))
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


class DocumentationChecks(unittest.TestCase):
    def minimal_project(self, root):
        authority_names = ['entry', 'index', 'plan', 'architecture', 'handoff', 'reviews',
                           'html', 'css', 'javascript', 'javascript-plan', 'svg', 'svg-plan']
        authorities = {name: f'docs/{name}.md' for name in authority_names}
        authorities['entry'] = 'README.md'
        authorities['plan'] = 'PLAN.md'
        (root / 'docs/history/2026-10-06').mkdir(parents=True)
        for name in authorities.values():
            (root / name).write_text('# Fixture\n', encoding='utf-8')
        archive_name = 'docs/history/2026-10-06/originals.zip'
        raw = (root / 'README.md').read_bytes()
        with zipfile.ZipFile(root / archive_name, 'w') as archive:
            archive.writestr('README.md', raw)
        receipt = {'schema': 'documentation-preservation/v1', 'archive': archive_name,
                   'archiveSha256': CHECKER.sha256((root / archive_name).read_bytes()),
                   'originals': [{'path': 'README.md', 'bytes': len(raw), 'sha256': CHECKER.sha256(raw)}],
                   'protectedTrees': []}
        (root / CHECKER.SNAPSHOT).write_text(json.dumps(receipt), encoding='utf-8')
        (root / CHECKER.INDEX).write_text('{}', encoding='utf-8')
        actual = [root / 'README.md', root / 'PLAN.md', *(
            path for path in (root / 'docs').rglob('*') if path.is_file())]
        index = {'schema': 'documentation-index/v1', 'authorities': authorities,
                 'domains': {'documentation': 'Fixture'}, 'strictDocuments': [],
                 'legacyBrokenLinks': [], 'documents': [
                     {'path': path.relative_to(root).as_posix(), 'domain': 'documentation',
                      'kind': 'profile', 'assessment': 'navigation', 'owner': 'README.md'}
                     for path in actual]}
        (root / CHECKER.INDEX).write_text(json.dumps(index), encoding='utf-8')
        return index

    def test_new_documents_need_registration_and_missing_files_fail(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            self.minimal_project(root)
            self.assertEqual(CHECKER.check(root)['preservedOriginals'], 1)
            extra = root / 'docs/unregistered.md'
            extra.write_text('# New\n', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'Unregistered:.*unregistered'):
                CHECKER.check(root)
            extra.unlink()
            (root / 'PLAN.md').unlink()
            with self.assertRaisesRegex(ValueError, "missing:.*PLAN"):
                CHECKER.check(root)

    def test_new_broken_link_cannot_be_hidden_as_history(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            index = self.minimal_project(root)
            (root / 'README.md').write_text('[new](absent.md)\n', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'Broken local link'):
                CHECKER.check(root)
            index['legacyBrokenLinks'] = [{'source': 'README.md', 'link': 'absent.md', 'problem': 'missing-target'}]
            (root / CHECKER.INDEX).write_text(json.dumps(index), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'exception is not in the original'):
                CHECKER.check(root)

    def test_links_preserve_spaces_parentheses_and_ignore_code(self):
        source = '[one](<a b.md>) [two](shape(1).md#value) [three](same.md "Title")\n'
        source += '`[fake](missing.md)`\n```html\n[also fake](missing.md)\n```\n'
        self.assertEqual(CHECKER.markdown_links(source), ['a b.md', 'shape(1).md#value', 'same.md'])

    def test_heading_anchors_keep_inline_code_and_duplicate_suffix(self):
        source = '# `Audio` laden\n## Audio laden\n```md\n# not a heading\n```\n'
        self.assertEqual(CHECKER.heading_ids(source), {'audio-laden', 'audio-laden-1'})

    def test_local_links_and_missing_anchors(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            (root / 'guide.md').write_text('# Grüße\n', encoding='utf-8')
            self.assertIsNone(CHECKER.link_problem(root, 'README.md', 'guide.md#gr%C3%BC%C3%9Fe'))
            self.assertEqual(CHECKER.link_problem(root, 'README.md', 'guide.md#absent'), 'missing-heading')
            self.assertEqual(CHECKER.link_problem(root, 'README.md', 'absent.md'), 'missing-target')
            self.assertEqual(CHECKER.link_problem(root, 'README.md', '../escape.md'), 'outside-project')
            self.assertIsNone(CHECKER.link_problem(root, 'README.md', 'https://example.test/absent'))

    def test_snapshot_checks_original_bytes_and_rejects_tampering(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            raw = b'# Original\r\n\r\nDo not normalize this.\r\n'
            with zipfile.ZipFile(root / 'originals.zip', 'w') as archive:
                archive.writestr('README.md', raw)
            receipt = {'archive': 'originals.zip',
                       'archiveSha256': CHECKER.sha256((root / 'originals.zip').read_bytes()),
                       'originals': [{'path': 'README.md', 'bytes': len(raw), 'sha256': CHECKER.sha256(raw)}]}
            self.assertEqual(CHECKER.verify_snapshot(root, receipt), 1)
            wrong_record = json.loads(json.dumps(receipt))
            wrong_record['originals'][0]['sha256'] = '0' * 64
            with self.assertRaisesRegex(ValueError, 'content mismatch'):
                CHECKER.verify_snapshot(root, wrong_record)
            with (root / 'originals.zip').open('ab') as archive:
                archive.write(b'changed')
            with self.assertRaisesRegex(ValueError, 'archive was altered'):
                CHECKER.verify_snapshot(root, receipt)

    def test_snapshot_rejects_extra_entries_even_with_new_container_hash(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            raw = b'# Original\n'
            with zipfile.ZipFile(root / 'originals.zip', 'w') as archive:
                archive.writestr('README.md', raw)
                archive.writestr('unexpected.md', b'different')
            receipt = {'archive': 'originals.zip',
                       'archiveSha256': CHECKER.sha256((root / 'originals.zip').read_bytes()),
                       'originals': [{'path': 'README.md', 'bytes': len(raw), 'sha256': CHECKER.sha256(raw)}]}
            with self.assertRaisesRegex(ValueError, 'entries differ'):
                CHECKER.verify_snapshot(root, receipt)

    def test_code_fingerprint_detects_rename_and_edit(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            code = root / 'src'
            code.mkdir()
            (code / 'a.luau').write_text('return 1\n', encoding='utf-8')
            original = CHECKER.tree_fingerprint(root, code)
            (code / 'a.luau').rename(code / 'b.luau')
            renamed = CHECKER.tree_fingerprint(root, code)
            self.assertNotEqual(original, renamed)
            (code / 'b.luau').write_text('return 2\n', encoding='utf-8')
            self.assertNotEqual(renamed, CHECKER.tree_fingerprint(root, code))


if __name__ == '__main__':
    unittest.main()
