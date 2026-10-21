"""Check documentation ownership, local links and the immutable original snapshot.

No engine execution, native performance measurements or external requests.
Historical broken links are explicit baseline records, not feature test evidence.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import sys
import zipfile
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
INDEX = 'docs/documentation-index.json'
SNAPSHOT = 'docs/history/2026-10-06/preservation.json'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def project_path(root, name):
    require(isinstance(name, str) and name and '\\' not in name,
            f'Expected a repository-relative POSIX path: {name!r}')
    target = (root / name).resolve()
    require(target.is_relative_to(root.resolve()) and not Path(name).is_absolute(),
            f'Path leaves the project: {name}')
    return target


def sha256(raw):
    return hashlib.sha256(raw).hexdigest()


def without_code(source, keep_inline=False):
    """Remove fenced blocks and inline code before reading prose links/headings."""
    lines = []
    fence = None
    for line in source.splitlines():
        match = re.match(r'^\s{0,3}(`{3,}|~{3,})', line)
        if fence:
            if match and match[1][0] == fence[0] and len(match[1]) >= len(fence):
                fence = None
            lines.append('')
        elif match:
            fence = match[1]
            lines.append('')
        else:
            lines.append(line)
    return re.sub(r'(`+)(.*?)\1', lambda match: match[2] if keep_inline else '', '\n'.join(lines))


def markdown_links(source):
    source = without_code(source)
    # All current repository Markdown uses inline links. Angle destinations
    # retain spaces; ordinary destinations allow balanced parentheses.
    result = []
    for match in re.finditer(r'!?\[[^\]\n]*\]\(', source):
        start = match.end()
        if start >= len(source):
            continue
        if source[start] == '<':
            end = source.find('>', start + 1)
            if end >= 0:
                result.append(source[start + 1:end])
            continue
        depth = 0
        end = start
        while end < len(source):
            char = source[end]
            if char == '\\' and end + 1 < len(source):
                end += 2
                continue
            if char == '(':
                depth += 1
            elif char == ')':
                if depth == 0:
                    break
                depth -= 1
            elif char.isspace() and depth == 0:
                break
            end += 1
        if end > start:
            result.append(source[start:end])
    return result


def heading_ids(source):
    seen = {}
    result = set()
    for match in re.finditer(r'^#{1,6}\s+(.+?)\s*#*$', without_code(source, keep_inline=True), re.MULTILINE):
        text = re.sub(r'\[([^]]+)\]\([^)]*\)', r'\1', match[1]).lower()
        slug = re.sub(r'[^\w\- ]', '', text).replace(' ', '-')
        suffix = seen.get(slug, 0)
        seen[slug] = suffix + 1
        result.add(slug if not suffix else f'{slug}-{suffix}')
    result.update(re.findall(r'<(?:a|span)\b[^>]*\bid=["\']([^"\']+)', source))
    return result


def link_problem(root, source_path, destination, original_texts=None):
    parsed = urlsplit(destination)
    if parsed.scheme or parsed.netloc:
        return None
    target = (root / source_path).parent / unquote(parsed.path) if parsed.path else root / source_path
    target = target.resolve()
    if not target.is_relative_to(root.resolve()):
        return 'outside-project'
    name = target.relative_to(root.resolve()).as_posix()
    original_texts = original_texts or {}
    if not target.exists() and name not in original_texts:
        return 'missing-target'
    if parsed.fragment and target.suffix.lower() == '.md':
        text = original_texts.get(name)
        if text is None:
            text = target.read_text(encoding='utf-8-sig')
        if unquote(parsed.fragment) not in heading_ids(text):
            return 'missing-heading'
    return None


def verify_snapshot(root, receipt):
    archive_path = project_path(root, receipt['archive'])
    require(sha256(archive_path.read_bytes()) == receipt['archiveSha256'],
            'Original documentation archive was altered')
    originals = receipt['originals']
    names = [item['path'] for item in originals]
    require(len(names) == len(set(names)), 'Duplicate snapshot record')
    with zipfile.ZipFile(archive_path) as archive:
        require(len(archive.namelist()) == len(set(archive.namelist())), 'Duplicate ZIP entry')
        require(set(archive.namelist()) == set(names), 'Snapshot entries differ from receipt')
        for item in originals:
            project_path(root, item['path'])
            raw = archive.read(item['path'])
            require(len(raw) == item['bytes'] and sha256(raw) == item['sha256'],
                    f'Original content mismatch: {item["path"]}')
    return len(originals)


def tree_fingerprint(root, directory):
    digest = hashlib.sha256()
    files = sorted(path for path in directory.rglob('*') if path.is_file())
    for path in files:
        digest.update(path.relative_to(root).as_posix().encode() + b'\0')
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return len(files), digest.hexdigest()


def check(root, verify_cleanup=False):
    root = root.resolve()
    index = json.loads((root / INDEX).read_text(encoding='utf-8'))
    require(index['schema'] == 'documentation-index/v1', 'Unsupported documentation index')
    receipt = json.loads((root / SNAPSHOT).read_text(encoding='utf-8'))
    require(receipt['schema'] == 'documentation-preservation/v1', 'Unsupported snapshot receipt')
    preserved = verify_snapshot(root, receipt)
    records = index['documents']
    names = [record['path'] for record in records]
    require(len(names) == len(set(names)), 'Duplicate documentation path')
    actual = {name for name in ('README.md', 'PLAN.md') if (root / name).is_file()} | {
        path.relative_to(root).as_posix() for path in (root / 'docs').rglob('*')
        if path.is_file() and path.suffix.lower() in {'.md', '.json', '.zip'}
    }
    require(set(names) == actual,
            f'Unregistered: {sorted(actual - set(names))}; missing: {sorted(set(names) - actual)}')
    require(set(index['authorities']) == {'entry', 'index', 'plan', 'architecture', 'handoff',
                                        'reviews', 'html', 'css', 'javascript',
                                        'javascript-plan', 'svg', 'svg-plan'},
            'Missing or unexpected documentation authority')
    authorities = set(index['authorities'].values())
    require(authorities <= actual, 'An authoritative document is missing')
    evidence_roots = index.get('evidenceRoots', [])
    require(len({record['path'] for record in evidence_roots}) == len(evidence_roots),
            'Duplicate evidence directory')
    for record in evidence_roots:
        require(project_path(root, record['path']).is_dir() and record['owner'] in authorities,
                f'Missing evidence directory or owner: {record["path"]}')
    links = 0
    inherited = []
    allowance = {(item['source'], item['link']): item['problem'] for item in index['legacyBrokenLinks']}
    require(len(allowance) == len(index['legacyBrokenLinks']), 'Duplicate historical broken-link record')
    with zipfile.ZipFile(root / receipt['archive']) as archive:
        old_texts = {name: archive.read(name).decode('utf-8-sig')
                     for name in archive.namelist() if name.endswith('.md')}
    for key, problem in allowance.items():
        source, destination = key
        require(source in old_texts and destination in markdown_links(old_texts[source]),
                f'Historical exception is not in the original: {key}')
        require(link_problem(root, source, destination, old_texts) == problem,
                f'Historical exception is not a pre-existing broken link: {key}')
    expected_kinds = {'entry', 'index', 'plan', 'architecture', 'handoff', 'review-index',
                      'coverage', 'profile', 'historical-profile', 'historical-plan',
                      'audit', 'stage-record', 'generated', 'history', 'migration'}
    expected_assessments = {'navigation', 'scoped-not-reaudited', 'needs-reconciliation',
                            'historical', 'generated-availability', 'preservation', 'scoped-reviewed'}
    old_records = {item['path']: item for item in receipt['originals']}
    for record in records:
        name = record['path']
        require(record['kind'] in expected_kinds and record['assessment'] in expected_assessments,
                f'Unknown documentation classification: {name}')
        require(record['domain'] in index['domains'] and record['owner'] in authorities,
                f'Unknown domain or owner: {name}')
        path = project_path(root, name)
        if record.get('originalPath'):
            original = old_records[record['originalPath']]
            require(sha256(path.read_bytes()) == original['sha256'], f'Readable original was altered: {name}')
        if not name.endswith('.md') or record['kind'] == 'history':
            continue
        for destination in markdown_links(path.read_text(encoding='utf-8-sig')):
            links += 1
            problem = link_problem(root, name, destination)
            if not problem:
                continue
            require(name not in authorities and name not in index['strictDocuments']
                    and allowance.get((name, destination)) == problem,
                    f'Broken local link in {name}: {destination} ({problem})')
            inherited.append((name, destination, problem))
    require(set(index['strictDocuments']) <= actual, 'A strictly checked document is missing')
    # Record inventory changes explicitly, and never leave an original active
    # path silently deleted. Relocations can keep a small redirect document.
    for item in receipt['originals']:
        require((root / item['path']).is_file(), f'Original path removed without a redirect: {item["path"]}')
    protected_files = 0
    if verify_cleanup:
        for item in receipt['protectedTrees']:
            count, digest = tree_fingerprint(root, project_path(root, item['path']))
            require(count == item['files'] and digest == item['sha256'],
                    f'Code tree changed during documentation cleanup: {item["path"]}')
            protected_files += count
    return {'documents': len(records), 'links': links, 'preservedOriginals': preserved,
            'historicalBrokenLinks': len(set(inherited)), 'unchangedCodeFiles': protected_files}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify-cleanup', action='store_true',
                        help='Also compare src/examples/tests to their cleanup baseline')
    args = parser.parse_args()
    try:
        print('Documentation check passed: ' + json.dumps(check(ROOT, args.verify_cleanup), sort_keys=True))
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
        print(f'Documentation check failed: {error}', file=sys.stderr)
        sys.exit(1)
