"""Join a frozen standards inventory with actual engine registrations/probes.

All availability claims are narrower than conformance. Source hits and related
tests are navigation aids, never evidence that an algorithm is implemented.
"""
import collections
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
REFERENCE=ROOT/'scripts/data/css-reference-2026-10-06.json'
OUTPUT=ROOT/'docs/css-features.v1.json'
LIST=ROOT/'docs/CSS-GAPS-20261006.md'


def read(path):
    return path.read_text(encoding='utf-8')


def reviewed_requirements(entries):
    """Read manual requirements without treating catalog probes as completion.

    The generated register is also the authoritative home of these records.
    A changed/disappearing definition must be reconciled before exporting.
    """
    by_id = {entry['id']: entry for entry in entries}
    assert len(by_id) == len(entries), 'Duplicate CSS coverage ID'
    reviewed = {}
    for entry in entries:
        if 'reviewedRequirements' not in entry:
            continue
        record = entry['reviewedRequirements']
        assert record['mapping'] in {'partial', 'complete'}, 'Invalid requirement mapping'
        assert re.fullmatch(r'\d{4}-\d{2}-\d{2}', record['reviewed']), 'Missing review date'
        assert record['items'], 'An empty mapping is still unmapped'
        identifiers = set()
        for requirement in record['items']:
            key = requirement['id']
            assert re.fullmatch(r'[a-z0-9][a-z0-9-]*', key), 'Invalid requirement ID'
            assert key not in identifiers, 'Duplicate requirement ID'
            identifiers.add(key)
            assert requirement['status'] in {'fulfilled', 'open', 'unchecked', 'technical-boundary', 'deferred'}, 'Invalid requirement status'
            assert requirement['scope'] and requirement['profile'], 'Undelimited requirement'
            assert requirement['standard'].startswith('https://'), 'Missing standard version/source'
            assert requirement['acceptance'] and all(requirement['acceptance']), 'Missing acceptance criteria'
            assert isinstance(requirement['evidence'], list), 'Missing evidence list'
            for evidence in requirement['evidence']:
                assert evidence['path'] and evidence['scope'] and evidence['environment'], 'Undelimited requirement evidence'
            if requirement['status'] in {'fulfilled', 'technical-boundary', 'deferred'}:
                assert requirement['evidence'], 'Closure/exception requires evidence'
        reviewed[entry['id']] = record
    return reviewed


def retain_reviewed_requirements(entries, previous):
    reviewed = reviewed_requirements(previous)
    by_id = {entry['id']: entry for entry in entries}
    assert len(by_id) == len(entries), 'Duplicate CSS coverage ID'
    assert set(reviewed) <= set(by_id), 'Reviewed CSS definition disappeared; reconcile before export'
    originals = {entry['id']: entry for entry in previous}
    for identifier, record in reviewed.items():
        entry = by_id[identifier]
        assert all(entry.get(key) == originals[identifier].get(key) for key in ['kind', 'name', 'spec', 'context']), 'Reviewed CSS identity changed; reconcile before export'
        entry['reviewedRequirements'] = record
    return reviewed


def main():
    previous = json.loads(read(OUTPUT))['entries'] if OUTPUT.exists() else []
    reference=json.loads(read(REFERENCE))
    names=lambda kind:sorted({x['name'] for x in reference['entries'] if x['kind']==kind})
    arguments={':dir()':'ltr',':lang()':'de',':state()':'ready',':heading()':'2',':host()':'.active',':host-context()':'.theme',
               ':has()':'> span',':not()':'.a',':is()':'.a',':where()':'.a',':matches()':'.a',
               '::part()':'panel','::slotted()':'span','::picker()':'select','::highlight()':'search',
               '::cue()':'b','::cue-region()':'#region','::scroll-button()':'right'}
    cases=json.loads(read(ROOT/'scripts/data/css-probe-cases.v1.json'))
    assert cases['schema']=='css-declaration-probe-cases/v1'
    assert set(cases['functions'])<=set(names('function')), 'Probe function outside dated reference'
    probes={'selectors':[], 'lengthUnits':[], 'mediaFeatures':[],
            'propertyAliases':[{'name':name,'source':name+':'+('vertical' if name=='-webkit-box-orient' else 'initial')}
                               for name in names('property') if name!='--*'],
            'functions':[{'name':name,'sources':source if isinstance(source,list) else [source]}
                         for name,source in sorted(cases['functions'].items())]}
    for name in names('selector'):
        if name=='&':
            continue  # Needs a nesting context, checked by existing nesting tests.
        source=name
        if name in ['+','>','~','||']:
            source='div '+name+' span'
        elif name.endswith('()'):
            source=name[:-1]+arguments.get(name,'2n+1' if 'nth' in name else '*' if 'view-transition' in name else 'a')+')'
        if source.startswith(':'):
            source='div'+source
        elif not source.startswith('div '):
            source='div:'+source if re.fullmatch('[a-z-]+',source) else source
        probes['selectors'].append({'name':name,'source':source})
    for entry in reference['entries']:
        if entry['kind']=='unit' and entry.get('context')=='<length>':
            probes['lengthUnits'].append({'name':entry['name'],'source':'1'+entry['name']})
        elif entry['kind']=='media-feature':
            name=entry['name']
            value={'width':'600px','height':'600px','aspect-ratio':'4/3','orientation':'portrait','hover':'hover',
                   'any-hover':'hover','pointer':'fine','any-pointer':'fine','prefers-reduced-motion':'reduce',
                   'prefers-color-scheme':'dark','forced-colors':'none','resolution':'1dppx',
                   'color':'8','color-index':'0','monochrome':'0','grid':'0'}.get(name,'none')
            probes['mediaFeatures'].append({'name':name,'source':f'({name}: {value})'})
    input_path=ROOT/'build/css-coverage-probe-input.json'
    input_path.write_text(json.dumps(probes,ensure_ascii=False),encoding='utf-8')
    catalog_path=ROOT/'build/css-coverage-catalog.json'
    subprocess.run(['node',str(ROOT/'scripts/export-engine-catalog.cjs'),str(catalog_path),str(input_path)],check=True,cwd=ROOT)
    catalog=json.loads(read(catalog_path));properties=catalog['properties'];probe_results=catalog['probes']
    api=json.loads(read(ROOT/'docs/javascript-api-register.v1.json'))
    api_paths={d['path'] for d in api['descriptors']}
    owners={o['id']:o for o in api['owners']}
    descriptors=api['descriptors']
    api_members=collections.defaultdict(set)
    for descriptor in descriptors:
        for alias in owners.get(descriptor['owner'],{}).get('aliases',[]):
            owner=alias.removeprefix('globalThis.').removesuffix('.prototype')
            if alias=='globalThis.'+owner or alias=='globalThis.'+owner+'.prototype':
                api_members[(owner,descriptor['key'])].add(descriptor['path'])
    sources={p.relative_to(ROOT).as_posix():read(p) for p in (ROOT/'src/HTMLEngine').rglob('*.luau')}
    svg_source=sources['src/HTMLEngine/SVG/Style.luau']
    # Private defaults are navigation evidence only; do not claim all SVG values.
    svg_header=svg_source.split('local function trim',1)[0]
    svg_names=set(re.findall(r"\['([^']+)'\]",svg_header))
    svg_names.update(re.findall(r'(?<=[{,])([a-z][\w-]*)=',svg_header))
    rules={'@container':'CSS/ContainerQueries','@counter-style':'CSS/CounterStyles','@keyframes':'CSS/Motion',
           '@layer':'CSS/CascadeLayers','@media':'CSS/MediaQueries','@property':'CSS/RegisteredProperties',
           '@scope':'CSS/ScopeRules','@starting-style':'CSS/Stylesheet','@supports':'CSS/Stylesheet',
           '@position-try':'CSS/Stylesheet'}
    profile_links=['docs/CSS-COMPLETION.md','docs/CSS-VISUAL-LIMITS.md','docs/JAVASCRIPT-CSS-ANIMATIONS-20261005.md','docs/CSS-ATELIER-20261007.md']
    entries=[]
    locator_cache={}
    def locators(name):
        token=name.split('(',1)[0].lstrip(':@')
        if len(token)<3:
            return []
        if token in locator_cache:
            return locator_cache[token]
        found=[]
        pattern=re.compile(r"(['\"])"+re.escape(token)+r"\1")
        for path,source in sources.items():
            if '/Websites/' in path or not any('/'+part+'/' in path for part in ['CSS','Layout','Rendering','SVG']):
                continue
            hit=pattern.search(source)
            if hit:
                found.append({'path':path,'line':source.count('\n',0,hit.start())+1})
        locator_cache[token]=found
        return found
    def category(entry):
        name,spec=entry['name'],entry['spec']
        if name.startswith('-webkit-') or entry.get('legacyAliasOf'):
            return 'legacy-compatibility'
        if any(part in spec for part in ['css-page','css-gcpm','css-page-floats','css-speech']):
            return 'optional-print-or-speech'
        if any(part in spec for part in ['css-paint-api','css-layout-api','css-animation-worklet']):
            return 'optional-worklet-host'
        if any(part in spec for part in ['css-mixins','css-functions','css-extensions','css-regions','css-round-display']):
            return 'draft-or-special-profile'
        return 'website-profile'
    for reference_entry in reference['entries']:
        entry=dict(reference_entry);kind,name=entry['kind'],entry['name']
        availability='not-individually-audited';evidence=[];limits=[]
        if kind=='property':
            if name in properties:
                availability='registered-html-profile'
                entry['catalog']=properties[name]
                limits=[properties[name]['Limitations']] if properties[name].get('Limitations') else []
                evidence=[{'kind':'registration','path':'src/HTMLEngine/CSS/Properties.luau','scope':'Catalog entry, not all grammars, cascade or rendering combinations'}]
            elif name=='--*':
                availability='custom-property-profile'
                evidence=[{'kind':'source-path','path':'src/HTMLEngine/CSS/Variables.luau','scope':'Custom property family with its existing substitution/inheritance profile; each arbitrary name is not a distinct standard feature'}]
            elif probe_results['propertyAliases'].get(name,{}).get('accepted'):
                result=probe_results['propertyAliases'][name]
                availability='consumed-compatibility-hint' if name=='-webkit-box-orient' else 'accepted-html-alias-profile'
                evidence=[{'kind':'parser-probe','path':'src/HTMLEngine/CSS/InlineStyle.luau','source':result['source'],
                           'scope':'Accepted reset or compatibility hint without a direct property catalog entry; not proof of all alias values'}]
                limits=['Consumed compatibility hint, not an independent layout implementation'] if name=='-webkit-box-orient' else ['Alias/shorthand expansion accepts the saved reset; full alias value grammar is not established']
            elif name in svg_names:
                availability='svg-path-only'
                evidence=[{'kind':'source-path','path':'src/HTMLEngine/SVG/Style.luau','scope':'SVG defaults/dispatch; HTML layout has no corresponding catalog registration'}]
            else:
                availability='not-registered-html'
                evidence=[{'kind':'absent-registration','path':'src/HTMLEngine/CSS/Properties.luau','scope':'No entry in the executed HTML property catalog; not an assertion about every SVG or API context'}]
        elif kind=='selector':
            result=probe_results['selectors'].get(name)
            if result:
                availability='rule-parser-accepts-example' if result['accepted'] else 'rule-parser-rejects-example'
                evidence=[{'kind':'parser-probe','runner':'scripts/export-engine-catalog.cjs','source':result['source'],
                           'scope':'One stylesheet selector example; matching, specificity, state and pixels require separate regressions'}]
            if name in [':host',':host()',':host-context()','::slotted()','::part()','&']:
                availability='contextual-selector-profile'
                limits=['Requires shadow/nesting context; the plain-document parser probe does not establish its absence or completeness']
        elif kind=='at-rule':
            if name in rules:
                availability='implemented-rule-profile'
                evidence=[{'kind':'source-path','path':'src/HTMLEngine/'+rules[name]+'.luau','scope':'Existing rule handler; full rule grammar and context combinations remain scoped'}]
            elif name=='@font-face':
                availability='accepted-and-ignored-by-html-cascade'
                limits=['CSS stylesheet collection skips the block; font family mapping and the JS font host do not implement all face descriptors/source selection']
            else:
                availability='no-html-stylesheet-handler'
                limits=['No corresponding handler in Stylesheet.collect; CSSOM storage or another renderer is a separate question']
        elif kind=='unit' and name in probe_results['lengthUnits']:
            result=probe_results['lengthUnits'][name]
            availability='length-parser-accepts-example' if result['accepted'] else 'length-parser-rejects-example'
            evidence=[{'kind':'parser-probe','path':'src/HTMLEngine/CSS/LengthExpression.luau','source':result['source'],
                       'scope':'HTML length parser only; angles, times, grid fractions and SVG lengths have other parsers'}]
        elif kind=='media-feature':
            result=probe_results['mediaFeatures'][name]
            availability='media-parser-accepts-example' if result['accepted'] else 'media-parser-rejects-example'
            evidence=[{'kind':'parser-probe','path':'src/HTMLEngine/CSS/MediaQueries.luau','source':result['source'],
                       'scope':'One value-form query; boolean/range syntax and host environment values are separate'}]
        elif kind=='function' and name in probe_results['functions']:
            result=probe_results['functions'][name]
            availability=('declaration-parser-mixed-examples' if result['rejectedExample'] else 'declaration-parser-accepts-example') if result['accepted'] else 'declaration-parser-rejects-example'
            evidence=[{'kind':'parser-probe','path':'src/HTMLEngine/CSS/InlineStyle.luau','source':example['source'],
                       'accepted':example['accepted'],
                       'scope':'Only this author declaration/property context; no complete function grammar, computed value or rendering claim'}
                      for example in result['examples']]
            if name=='var()':
                limits=['Compiler defers variable substitution; this probe alone does not validate the resulting property value']
        elif kind=='api-interface':
            matches=sorted(p for p in api_paths if p=='globalThis.'+name)
            if matches:
                availability='installed-api-binding'
                evidence=[{'kind':'descriptor-presence','path':'docs/javascript-api-register.v1.json','members':matches,'scope':'Installed descriptor without invoking constructor/getter; not browser conformance'}]
            elif entry.get('partial') or entry.get('inherits'):
                availability='instance-or-partial-api-not-probed'
            else:
                availability='no-global-binding-in-api-probe'
        elif kind=='api-member':
            owner,member=name.rsplit('.',1)
            matches=list(api_members.get((owner,member),[]))
            if member=='constructor' and 'globalThis.'+owner in api_paths:
                matches.append('globalThis.'+owner)
            if matches:
                availability='installed-api-member'
                evidence=[{'kind':'descriptor-presence','path':'docs/javascript-api-register.v1.json','members':sorted(set(matches)),
                           'scope':'Exact owner/key descriptor only; instance wrappers, options and behavior need family-specific proof'}]
            else:
                availability='api-member-not-individually-probed'
        entry.update({'priorityCategory':category(entry),'availability':availability,'evidence':evidence,
                      'limitations':limits,'codeLocators':locators(name) if kind in ['function','descriptor','type','value'] else [],
                      'conformance':'no-full-standard-completion-claim'})
        entries.append(entry)
    # Keep engine-only registrations visible rather than forcing a false
    # normative mapping to a similarly named newer property.
    ref_properties=set(names('property'))
    for name,property in sorted(properties.items()):
        if name not in ref_properties:
            entries.append({'id':'engine-property-'+name,'kind':'property','name':name,'spec':None,
                            'priorityCategory':'engine-registration-not-in-reference','availability':'registered-html-profile',
                            'catalog':property,'evidence':[{'kind':'registration','path':'src/HTMLEngine/CSS/Properties.luau','scope':'No exact entry in this dated reference; naming/alias mapping requires review'}],
                            'limitations':[property['Limitations']] if property.get('Limitations') else [],
                            'codeLocators':[],'conformance':'no-full-standard-completion-claim'})
    reviewed = retain_reviewed_requirements(entries, previous)
    result={'schema':'css-feature-coverage/v1','date':'2026-10-06','reference':'scripts/data/css-reference-2026-10-06.json',
            'referenceSha256':hashlib.sha256(REFERENCE.read_bytes()).hexdigest(),
            'profileDocuments':profile_links,
            'probeCases':'scripts/data/css-probe-cases.v1.json',
            'probeCasesSha256':hashlib.sha256((ROOT/'scripts/data/css-probe-cases.v1.json').read_bytes()).hexdigest(),
            'scope':'Complete named reference inventory for the declared snapshot; per-entry availability is not complete semantic or visual proof',
            'statusMeaning':{'registered-html-profile':'Registered property; catalog values/limitations remain scoped',
                'not-registered-html':'No HTML property catalog entry; SVG/API paths must be examined separately',
                'parser-probe':'Only the saved concrete example was accepted/rejected by actual engine code',
                'not-individually-audited':'No per-entry conformance proof; source locator is only for navigation'},
            'entries':entries}
    encoded=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
    report=render_report(entries,reference,properties)
    if '--check' in sys.argv:
        assert read(OUTPUT)==encoded,'CSS coverage changed; review and regenerate'
        assert read(LIST)==report,'CSS human-readable list differs from the authoritative register'
    else:
        OUTPUT.write_text(encoded,encoding='utf-8');LIST.write_text(report,encoding='utf-8')
    print('CSS coverage:',len(entries),'entries;',dict(collections.Counter(e['availability'] for e in entries)))
    print('Reviewed requirement mappings:', len(reviewed), '(partial mappings do not close a definition)')


def render_report(entries,reference,properties):
    text=['# CSS: Bestand, offene Funktionen und Hostgrenzen','',
          'Stand: 6. Oktober 2026. Automatisch aus dem [CSS-Register](css-features.v1.json) erzeugt.', '',
          'Die Liste erfasst alle benannten Einträge der festgehaltenen Referenz: W3C Webref, CSS Snapshot 2026, Einheiten, Medienmerkmale und 38 CSS-bezogene WebIDL-Dateien. Sie enthält auch Entwürfe und ältere Kompatibilitätsnamen. Vollständig ist dieser datierte Referenzbestand, keine Behauptung einer vollständigen Browserimplementierung. Grammatik, Vererbung, Kaskade, Layout, Paint, Änderungen, Kombinationen und Abbau müssen pro Profil nachgewiesen werden.', '',
          'Quellen: [CSS Snapshot 2026](https://www.w3.org/TR/2026/NOTE-css-2026-20260622/), [W3C Webref](https://github.com/w3c/webref/tree/'+reference['webrefCommit']+'), [CSS Values](https://drafts.csswg.org/css-values-4/), [Media Queries](https://drafts.csswg.org/mediaqueries-5/). Prüfsummen und einzelne Definitionslinks stehen im [eingefrorenen Referenzbestand](../scripts/data/css-reference-2026-10-06.json).', '',
          '## Status richtig lesen','',
          '- **HTML-Profil:** tatsächlicher Katalogeintrag; die angegebenen Werte und Grenzen gelten weiterhin.',
          '- **SVG-Pfad:** Eigenschaft läuft durch SVG; das beweist keinen entsprechenden HTML-Pfad.',
          '- **Fehlt im HTML-Katalog:** tatsächliche Abwesenheit einer Registrierung.',
          '- **Alias/Kompatibilitätshinweis:** wird trotz fehlender eigener Registrierung angenommen beziehungsweise konsumiert; nicht als fehlende Eigenschaft zählen.',
          '- **Parserprobe:** ein konkreter gültiger Beispielausdruck wird angenommen oder verworfen; kein vollständiger Wirkungs-/Pixelnachweis.',
          '- **Nicht einzeln belegt:** offen im Nachweis; ein Texttreffer im Code zählt nicht als Umsetzung.', '',
          'Die bisherigen Fachprofile und Regressionen behalten ihre Gültigkeit für ihren konkreten Umfang. Das Register erweitert den Vergleichsmaßstab; es erklärt bestehende, funktionierende Profile nicht pauschal für fehlend.', '',
          'Ausbau vom 7. Oktober: [CSS Atelier](CSS-ATELIER-20261007.md) verbindet neue Funktionsprofile mit derselben Browser-/Roblox-Seite. Die breite Restliste unten nennt vollständige Standardfamilien; konkret ergänzte Teilfälle sind im neuen Profil abgegrenzt. Das Datum oben bezeichnet den eingefrorenen Referenzbestand.', '',
          '## Für normale Websites zuerst relevant','',
          '| Familie | Noch notwendiger Abgleich / Ausbau |', '| --- | --- |',
          '| Syntax und Kaskade | Vollständige Tokenisierung, Escapes/Unicode-Bezeichner, Fehlerkorrektur, alle CSS-weiten Werte und ungültige Werte nach Variablenersetzung; User-/UA-Ursprünge; vollständige Import-/Namespace-Regeln. |',
          '| Selektoren | Fehlende Zustände, Sprache/Richtung, Links/Ziel/Offen-Zustände; `nth-child(... of ...)`, Namespaces, vollständige Shadow-/Pseudo-Syntax; Spezifität und Invalidierung in Kombinationen. |',
          '| Maße und responsive Regeln | Fehlende absolute, Schrift-, kleine/große/dynamische Viewport- und Container-Einheiten; boolesche und Bereichs-Mediaqueries, weitere Medienmerkmale; Query-Abhängigkeiten. |',
          '| Text und Schriften | Vollständiges Bidi-/Schreibmodus-Verhalten, Glyphenformung, OpenType/variable Fonts, Sprachen und Umbruchregeln, Initial Letters, Text Box und native Fontquellen/-deskriptoren. |',
          '| Layout | Vollständige Block-/Inline-/Float-/Table-/Flex-/Grid-/Subgrid-/Fragmentierungsfälle, Intrinsic-/Min-/Max-Größen, Baselines, auto/min-content/max-content und Prozentzyklen; neue Layoutentwürfe getrennt priorisieren. |',
          '| Bilder, Farben und Effekte | Gesamte Bildgrammatik, Sourceauswahl und Farbräume; Masken/Filter/Clip/Compositing und 3D mit exakten Paint-, Treffer- und Resize-Regeln. Vorhandene CPU-Profile bleiben angenähert. |',
          '| Eingabe und Scrolling | Vollständige UA-/Pseudoelementdarstellung, Scroll-/View-Timelines und Bereiche, Anchor Positioning mit Fallbacks, interaktive Zustände/Forced Colors und vollständige Zoom-Regeln. |',
          '| Animationen | Vollständige Interpolation jeder animierbaren Eigenschaft, intrinsische Größen, Komposition/Accumulation/Iteration und wechselnde Basen; CSS-/JS-Timingkombinationen. |',
          '| CSSOM / Typed OM / Übergänge | Unten und im Register einzeln erfasste Interfaces/Member prüfen. Deskriptorpräsenz ersetzt keine Semantik. Typed OM, View Transitions, Highlight-/Pseudo- und Worklet-APIs separat nach Profilbedarf. |', '',
          '## Für unser Websiteprofil optional oder derzeit nicht nativ verfügbar','',
          '| Kategorie | Einordnung |', '| --- | --- |',
          '| Print/Paged Media/Footnotes/Bookmarks | Für die Anzeige auf einem Roblox-Bildschirm derzeit nicht erforderlich. Die CSS-Semantik ist implementierbar; native Betriebssystem-Druckausgabe ist kein vorhandener Enginehost. |',
          '| CSS Speech | Für das aktuelle visuelle Websiteprofil optional. Audio-Wiedergabe ersetzt keinen sprachabhängigen Screenreader-/Sprachsynthesehost. |',
          '| Herstellerpräfixe und Legacy-Aliase | Kompatibilität für alte Websites; nachrangig gegenüber den heutigen Standardnamen. Nicht pauschal unnötig, wenn importierte Seiten sie tatsächlich verwenden. |',
          '| Neue oder spezielle Entwürfe | Mixins/Funktionen, Regions, runde Displays und andere Spezialprofile sind separat sichtbar. Standardentwürfe sind keine LESS-/Sass-Erweiterungen; Eintrag im Entwurf verpflichtet nicht zur sofortigen Umsetzung. |',
          '| Paint/Layout/Animation Worklets | Ein eigener VM-/CPU-Host ist grundsätzlich möglich. Eine unmittelbare Anbindung an den echten Browser-Compositor oder beliebige native GPU-Shader existiert in unserem Roblox-Host nicht. |',
          '| Fonts / Farbausgabe / Systemdarstellung | Unsere Font-/Bild-/GUI-Adapter liefern nicht beliebige native Webfontdateien, Browser-Glyphenrasterung, HDR-Ausgabe oder pixelgleiche OS-Picker. Das ist eine Grenze der aktuellen Hostanbindung; Software-/Assetadapter sind gesonderte Möglichkeiten. |',
          '| Betriebssystem-Dateiauswahl / Clipboard / Geräte-APIs | Das sind HTML-/JavaScript-/Hostfunktionen, keine fehlenden CSS-Eigenschaften. Der File-Button bleibt nach Nutzerentscheidung vorerst reine Darstellung. |', '',
          'Die konkrete Hostbeschreibung steht in [HostCapabilities](../src/HTMLEngine/Diagnostics/HostCapabilities.luau). „Noch nicht eingebaut“ bedeutet nicht „unmöglich“. Für Sprache, Parser, Layout oder Softwareeffekte wird hier keine grundsätzliche Unmöglichkeit behauptet.', '',
          '## Umfang','', '| Art | Definitions-/Kontexteinträge | Unterschiedliche Namen |', '| --- | --- |']
    for kind in sorted({e['kind'] for e in entries}):
        selected=[e for e in entries if e['kind']==kind]
        text.append(f'| {kind} | {len(selected)} | {len({e["name"] for e in selected})} |')
    text += ['',f'Der ausgeführte Enginekatalog enthält {len(properties)} HTML-Eigenschaften. Für Typen, Werte/Grammatiken, Deskriptoren sowie sämtliche API-Member enthält das JSON jeden Referenzeintrag samt Kontext und offenem Nachweisstatus. Sie werden nicht aufgrund eines gleichnamigen Codewortes als erledigt markiert.', '',
             '## Eigenschaften ohne HTML-Registrierung und Eigenschaften nur im SVG-Pfad','',
             '| Eigenschaft | Status / Prioritätskategorie | Definition |','| --- | --- | --- |']
    seen=set()
    labels={'not-registered-html':'Fehlt im HTML-Katalog','svg-path-only':'SVG-Pfad'}
    for e in entries:
        if e['kind']=='property' and e['availability'] in labels and e['name'] not in seen:
            seen.add(e['name']);text.append(f'| `{e["name"]}` | {labels[e["availability"]]} · {e["priorityCategory"]} | [Standard]({e["spec"]}) |')
    text += ['', '## Registrierte HTML-Eigenschaften: tatsächlicher Teilumfang','',
             'Dies ist kein Vollständigkeits-Häkchen. Ohne eingetragene Grenze bleibt der vollständige Standardumfang unbewiesen.', '',
             '| Eigenschaft | Katalogwerte / ausdrückliche Grenzen |','| --- | --- |']
    for name,record in sorted(properties.items()):
        value='; '.join(v for v in [record.get('Values',''),record.get('Limitations','')] if v)
        value=value.replace('|',' / ').replace('\n',' ')
        text.append(f'| `{name}` | {value or "Registriert; vollständige Semantik/Kombinationen nicht daraus ableiten."} |')
    text += ['', '## Zusätzliche Alias-/Kompatibilitätspfade','',
             '| Name | Konkreter Nachweis / Grenze |','| --- | --- |']
    seen=set()
    for e in entries:
        if e['kind']=='property' and e['availability'] in ['accepted-html-alias-profile','consumed-compatibility-hint'] and e['name'] not in seen:
            seen.add(e['name'])
            text.append(f'| `{e["name"]}` | {e["evidence"][0]["source"]}; {" ".join(e["limitations"])} |')
    labels={'rule-parser-accepts-example':'Selektorprobe angenommen; Wirkung/Kombinationen gesondert prüfen',
            'rule-parser-rejects-example':'Selektorprobe verworfen; dieser Fall offen',
            'contextual-selector-profile':'Shadow-/Nestingprofil; gesonderter Kontext erforderlich',
            'implemented-rule-profile':'Vorhandener Regelhandler mit begrenztem Fachprofil',
            'accepted-and-ignored-by-html-cascade':'Block wird beim HTML-Stilabgleich übersprungen',
            'no-html-stylesheet-handler':'Kein HTML-Stylesheethandler',
            'length-parser-accepts-example':'HTML-Längenprobe angenommen',
            'length-parser-rejects-example':'HTML-Längenprobe verworfen; dieser Fall offen',
            'media-parser-accepts-example':'Medienprobe angenommen; boolesche/Bereichsformen gesondert prüfen',
            'media-parser-rejects-example':'Medienprobe verworfen; dieser Fall offen',
            'declaration-parser-accepts-example':'Deklarationsprobe angenommen; Werte/Wirkung/Kombinationen gesondert prüfen',
            'declaration-parser-mixed-examples':'Teilprofil: einige Deklarationsproben angenommen, andere verworfen; Kontexte im Register',
            'declaration-parser-rejects-example':'Deklarationsprobe verworfen; dieser Fall offen',
            'not-individually-audited':'Nicht einzeln belegt; Grammatik/Kontext noch abgleichen',
            'installed-api-binding':'Globale Bindung vorhanden; vollständige Semantik nicht daraus ableiten',
            'no-global-binding-in-api-probe':'Keine globale Bindung im API-Profil; Instanzpfade gesondert prüfen',
            'instance-or-partial-api-not-probed':'Instanz-/Mixin-/Teilinterface gesondert prüfen'}
    for kind,title in [('selector','Selektoren'),('at-rule','At-Regeln'),('unit','Einheiten'),('media-feature','Medienmerkmale'),('function','Funktionen')]:
        text += ['', '## '+title,'','| Name | Verfügbarkeit / Nachweisstatus |','| --- | --- |'];seen=set()
        for e in entries:
            if e['kind']==kind and e['name'] not in seen:
                seen.add(e['name'])
                text.append(f'| `{e["name"].replace("|","&#124;")}` | {labels.get(e["availability"],e["availability"])} |')
    text += ['', '## API-Familien','',
             'Alle einzelnen Methoden, Properties, Konstruktoren, Dictionaries, Enum-Werte, Überladungen und Includes stehen im JSON. „Keine globale Bindung“ beweist bei Mixins, partiellen Interfaces und instanzabhängigen Wrappern keine grundsätzliche Abwesenheit.', '',
             '| Interface / Namespace | Verfügbarkeit / Nachweisstatus |','| --- | --- |']
    seen=set()
    for e in entries:
        if e['kind']=='api-interface' and e['name'] not in seen:
            seen.add(e['name']);text.append(f'| `{e["name"]}` | {labels.get(e["availability"],e["availability"])} |')
    text += ['', '## Pflege und Prüfung','',
             '`node scripts/export-engine-catalog.cjs` liest die tatsächlichen Registrierungen. `python scripts/export-css-coverage.py --check` vergleicht das Register und diese Liste mit den gespeicherten Referenzdaten, dem aktuellen Code, konkreten Parserproben und dem API-Register. `python scripts/export-css-reference.py --check` prüft zusätzlich gegen die lokal erhaltenen Originalauszüge; veränderte Live-Entwürfe dürfen den datierten Bestand nicht still überschreiben.', '',
             'Neue funktionale oder visuelle Nachweise gehören in ein konkretes Fachprofil. Der Generator erzeugt keine Gesamt-Konformitätsbehauptung und verwendet keine fremden Beschreibungstexte.', '']
    return '\n'.join(text)


if __name__=='__main__':
    main()
