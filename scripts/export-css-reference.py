"""Freeze names and normative links, never support claims or copied spec prose.

Webref is pinned. Other sources are dated extracts with original-content hashes;
their extracted facts remain in the checked-in register when a live draft changes.
"""
import hashlib
import json
import re
import sys
from pathlib import Path
from lxml import html

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'build/reference'
REVISION = 'c6e1630adecd5acac338fd9166232ff3324b6781'
OUT = ROOT / 'scripts/data/css-reference-2026-10-06.json'


def read(path):
    return path.read_text(encoding='utf-8')


def main():
    entries, sources, ids = [], [], set()

    def source(file, url, kind):
        data = (CACHE / file).read_bytes()
        sources.append({'file': file, 'url': url, 'kind': kind,
                        'sha256': hashlib.sha256(data).hexdigest()})
        return data

    def add(kind, name, url, context=None, **fields):
        name = ' '.join(name.split())
        key = json.dumps([kind, name, context, url], ensure_ascii=False)
        if key in ids:
            return
        ids.add(key)
        item = {'id': kind + '-' + hashlib.sha256(key.encode()).hexdigest()[:16],
                'kind': kind, 'name': name, 'spec': url}
        if context:
            item['context'] = context
        item.update(fields)
        entries.append(item)

    webref = json.loads(source('webref-css-pinned.json',
        f'https://raw.githubusercontent.com/w3c/webref/{REVISION}/ed/css.json', 'pinned-webref'))
    for plural, singular in [('properties','property'), ('selectors','selector'),
                             ('atrules','at-rule'), ('functions','function'), ('types','type')]:
        for item in webref[plural]:
            facts = {k:item[k] for k in ['syntax','legacyAliasOf','longhands','resetLonghands'] if k in item}
            add(singular, item['name'], item['href'], item.get('for'), **facts)
            for extension in item.get('extended', []):
                # Webref stores extension definition links, not support flags.
                add(singular,item['name'],extension,item.get('for'),extended=True)
            if plural == 'atrules':
                for descriptor in item['descriptors']:
                    add('descriptor', descriptor['name'], descriptor['href'], [item['name']],
                        **{k:descriptor[k] for k in ['syntax'] if k in descriptor})

    snapshot = html.fromstring(source('css-snapshot-2026.html',
        'https://www.w3.org/TR/2026/NOTE-css-2026-20260622/', 'dated-css-snapshot'))
    classifications = []
    for level in ['css-official','reliable-cr','fairly-stable','rough-interop']:
        heading = snapshot.xpath(f'//*[@id="{level}"]')[0]
        for sibling in heading.itersiblings():
            if sibling.tag in ['h2','h3']:
                break
            for a in sibling.xpath('.//dt/a[@href]'):
                link = a.get('href')
                if link.startswith('https://www.w3.org/TR/') and '#' not in link:
                    classifications.append({'module': link.rstrip('/').split('/')[-1],
                                             'category': level, 'spec': link})
    for index, kind in [('selectors','selector'),('at-rules','at-rule'),('properties','property'),('values','value')]:
        container = snapshot.xpath(f'//*[@id="{index}"]')[0].getnext()
        for a in container.xpath('.//a[@href]'):
            url = a.get('href')
            if not url.startswith(('https://','http://')):
                continue
            name = a.text_content().strip()
            # Multi-definition indices have anonymous "in module" sublinks.
            li = a.getparent()
            if name.startswith('in '):
                outer = li.getparent().getparent()
                name = (outer.text or '').strip()
            if name:
                add(kind, name, url, snapshotIndex=True)

    for file, url, kind in [('css-values-4.html','https://drafts.csswg.org/css-values-4/','unit'),
                             ('css-contain-3.html','https://drafts.csswg.org/css-contain-3/','unit'),
                             ('mediaqueries-5.html','https://drafts.csswg.org/mediaqueries-5/','media-feature')]:
        document = html.fromstring(source(file,url,'dated-editor-draft'))
        for d in document.xpath('//dfn[@id]'):
            if kind == 'unit':
                if d.get('data-dfn-type') != 'value' or d.get('data-dfn-for') not in ['<length>','<angle>','<time>','<frequency>','<resolution>']:
                    continue
            elif d.get('data-dfn-type') != 'descriptor' or d.get('data-dfn-for') != '@media':
                continue
            add(kind, d.text_content().strip(), url+'#'+d.get('id'), d.get('data-dfn-for'))
    add('unit','fr','https://drafts.csswg.org/css-grid-2/#fr-unit','<flex>')

    idl_files = json.loads(read(CACHE/'webref-css-idl-files.json'))
    for file in idl_files:
        raw = source('css-idl/'+file,
            f'https://raw.githubusercontent.com/w3c/webref/{REVISION}/ed/idl/{file}', 'pinned-webidl')
        text = raw.decode('utf-8')
        spec = re.search(r'// Source:.*\((https?://[^\s]+)\)',text).group(1)
        text = re.sub(r'//[^\n]*|/\*.*?\*/','',text,flags=re.S)
        for declaration in re.finditer(r'(?:partial\s+)?(?:interface(?:\s+mixin)?|namespace|dictionary|enum)\s+(\w+)(?:\s*:\s*(\w+))?\s*\{(.*?)\}\s*;',text,re.S):
            owner, parent, body = declaration.groups()
            prefix = declaration.group(0).split('{',1)[0]
            kind = 'api-dictionary' if 'dictionary' in prefix else 'api-enum' if 'enum' in prefix else 'api-interface'
            add(kind,owner,spec,idlSource=file,inherits=parent,partial='partial' in prefix)
            if kind == 'api-enum':
                for value in re.findall(r'"([^\"]*)"',body):
                    add('api-enum-value',owner+'.'+value,spec,[owner],idlSource=file)
            for member in body.split(';'):
                # IDL types and annotations stay in the pinned source. We only
                # enumerate names; overloads retain their own signatures.
                clean = re.sub(r'\[[^\]]*\]','',member).strip()
                if not clean or kind == 'api-enum':
                    continue
                clean = ' '.join(clean.split())
                attr = re.search(r'\battribute\b.+\s+(\w+)$',clean)
                operation = re.search(r'(\w+)\s*\(',clean)
                other = re.search(r'(\w+)\s*(?:=.*)?$',clean)
                name = attr.group(1) if attr else operation.group(1) if operation else other.group(1) if other else clean.split('<',1)[0]
                category = 'attribute' if attr else 'operation' if operation else 'dictionary-member' if kind == 'api-dictionary' else 'constant' if clean.startswith('const ') else 'collection-protocol'
                add('api-member',owner+'.'+name,spec,[owner,clean],idlSource=file,
                    memberKind=category,signature=clean)
        for child,parent in re.findall(r'\b(\w+)\s+includes\s+(\w+)\s*;',text):
            add('api-includes',child+' includes '+parent,spec,idlSource=file)
    entries.sort(key=lambda x:(x['kind'],x['name'],x.get('spec',''),str(x.get('context',''))))
    result = {'schema':'css-standard-reference/v1','date':'2026-10-06','webrefCommit':REVISION,
              'scope':'All named entries and extended grammars in the pinned Webref CSS extract, CSS Snapshot 2026 indices, units/media features and every declaration/member in 38 CSS-related WebIDL extracts. Not a browser conformance claim.',
              'sources':sources,'snapshotModules':classifications,'entries':entries}
    encoded = json.dumps(result,ensure_ascii=False,indent=2)+'\n'
    if '--check' in sys.argv:
        assert read(OUT)==encoded, 'CSS reference export differs; inspect the source update before regenerating'
    else:
        OUT.write_text(encoded,encoding='utf-8')
    counts = {}
    for entry in entries:
        counts[entry['kind']] = counts.get(entry['kind'],0)+1
    print('CSS reference facts:',len(entries),counts)


if __name__ == '__main__':
    main()
