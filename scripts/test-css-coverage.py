"""Protect reviewed requirements when generated CSS availability changes."""
import copy
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location('css_coverage_export', Path(__file__).with_name('export-css-coverage.py'))
EXPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXPORT)


class CoveragePreservation(unittest.TestCase):
    def previous(self):
        return [{'id': 'property-example', 'kind': 'property', 'name': 'example',
                 'spec': 'https://example.test/frozen/#example',
                 'availability': 'registered-html-profile',
                 'reviewedRequirements': {'mapping': 'partial', 'reviewed': '2026-10-10',
                                         'items': [{'id': 'live-change', 'status': 'open',
                                                    'scope': 'Retained live rendering',
                                                    'profile': 'docs/CSS-COMPLETION.md',
                                                    'standard': 'https://example.test/frozen/#example',
                                                    'acceptance': ['Retain GUI identity through recascade'],
                                                    'evidence': []}]}}]

    def test_new_availability_preserves_reviewed_records_exactly(self):
        old = self.previous()
        generated = [{key: value for key, value in old[0].items()
                      if key not in {'availability', 'reviewedRequirements'}}]
        generated[0]['availability'] = 'not-registered-html'
        frozen = copy.deepcopy(old)
        EXPORT.retain_reviewed_requirements(generated, old)
        self.assertEqual(generated[0]['reviewedRequirements'], old[0]['reviewedRequirements'])
        self.assertEqual(generated[0]['availability'], 'not-registered-html')
        self.assertEqual(old, frozen)
        EXPORT.retain_reviewed_requirements(generated, generated)
        self.assertEqual(generated[0]['reviewedRequirements'], old[0]['reviewedRequirements'])

    def test_removed_or_reused_identity_cannot_erase_review(self):
        old = self.previous()
        with self.assertRaisesRegex(AssertionError, 'disappeared'):
            EXPORT.retain_reviewed_requirements([], old)
        for field in ['name', 'kind', 'spec', 'context']:
            generated = copy.deepcopy(old)
            generated[0][field] = 'changed'
            with self.assertRaisesRegex(AssertionError, 'identity changed'):
                EXPORT.retain_reviewed_requirements(generated, old)

    def test_invalid_mapping_or_unproved_closure_is_rejected(self):
        for status in ['fulfilled', 'technical-boundary', 'deferred', 'invented']:
            entries = self.previous()
            entries[0]['reviewedRequirements']['items'][0]['status'] = status
            with self.assertRaises(AssertionError):
                EXPORT.reviewed_requirements(entries)
        entries = self.previous()
        entry = entries[0]['reviewedRequirements']['items'][0]
        entries[0]['reviewedRequirements']['items'].append(copy.deepcopy(entry))
        with self.assertRaisesRegex(AssertionError, 'Duplicate requirement ID'):
            EXPORT.reviewed_requirements(entries)


if __name__ == '__main__':
    unittest.main()
