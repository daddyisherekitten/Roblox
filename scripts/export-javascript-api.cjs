// Export installed Runtime descriptors. This is an availability inventory,
// never an assertion that the Web platform or a method family is complete.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const result=cp.spawnSync(process.execPath,[path.join(root,'scripts/run-html-tests.cjs'),'JavaScriptAPIInventory'],{cwd:root,encoding:'utf8',maxBuffer:32*1024*1024});
if(result.error)throw result.error;
if(result.status!==0){process.stderr.write(result.stderr||'');process.stderr.write(result.stdout||'');process.exit(result.status||1)}
const lines=result.stdout.split(/\r?\n/),owners=[],records=[];let header,end;
for(const line of lines){for(const [tag,consume]of [
 ['API_INVENTORY_HEADER',v=>header=v],['API_INVENTORY_OWNER',v=>owners.push(v)],['API_INVENTORY_RECORD',v=>records.push(v)],['API_INVENTORY_END',v=>end=v]]){
 if(line.startsWith(tag+' ')){consume(JSON.parse(line.slice(tag.length+1)));break}
}}
assert.ok(header&&end,'Missing completed Runtime inventory');assert.equal(end.getterReads,0);assert.equal(end.scriptsRun,0);assert.equal(owners.length,end.owners);assert.equal(records.length,end.records);
const bundlePath=path.join(root,`build/html-tests-${result.pid}.luau`);const bundle=fs.readFileSync(bundlePath,'utf8');
const moduleRanges=[];let currentLine=0;
for(const line of bundle.split('\n')){currentLine++;const match=line.match(/^(?:modules|loaders)\["([^"]+)"\]\s*=\s*function\(\)/);if(match)moduleRanges.push({module:'src/HTMLEngine/'+match[1]+'.luau',start:currentLine+1})}
assert.ok(moduleRanges.length>0,'Module declaration provenance was not found in the bundle');
function declaration(source){if(!source||!Number.isInteger(source.line)||source.line<=0)return undefined;
 const range=moduleRanges.findLast(r=>r.start<=source.line);if(!range)return undefined;
 return{module:range.module,line:source.line-range.start+1};}
const specs={
 R00:'https://webidl.spec.whatwg.org/',R01:'https://tc39.es/ecma262/',R02:'https://dom.spec.whatwg.org/',R03:'https://html.spec.whatwg.org/multipage/custom-elements.html',
 R04:'https://w3c.github.io/selection-api/',R05:'https://drafts.csswg.org/cssom/',R06:'https://drafts.csswg.org/web-animations-1/',
 R07:'https://url.spec.whatwg.org/',R08:'https://tc39.es/ecma402/',R09:'https://fetch.spec.whatwg.org/',R10:'https://streams.spec.whatwg.org/',
 R11:'https://w3c.github.io/IndexedDB/',R12:'https://w3c.github.io/ServiceWorker/#cache-objects',R13:'https://html.spec.whatwg.org/multipage/scripting.html',
 R14:'https://html.spec.whatwg.org/multipage/browsers.html',R15:'https://html.spec.whatwg.org/multipage/canvas.html',R16:'https://html.spec.whatwg.org/multipage/media.html',
 R17:'https://html.spec.whatwg.org/multipage/workers.html',R18:'https://html.spec.whatwg.org/multipage/canvas.html#the-offscreencanvas-interface',
 R19:'https://w3c.github.io/ServiceWorker/',R20:'https://webidl.spec.whatwg.org/'};
const idleSpec='https://www.w3.org/TR/2025/WD-requestidlecallback-20250521/';
const mediaCaptureSpec='https://www.w3.org/TR/2025/CRD-mediacapture-streams-20251009/';
const permissionsSpec='https://www.w3.org/TR/permissions/#permissionstatus-interface';
const moduleSpecs={SimpleDialogs:'https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#simple-dialogs',DocumentLifecycle:'https://html.spec.whatwg.org/multipage/browsing-the-web.html#unloading-documents',IdleCallbacks:idleSpec,MediaDevices:mediaCaptureSpec,MediaStreams:mediaCaptureSpec,
 Scheduler:'https://wicg.github.io/scheduling-apis/',TaskSignals:'https://wicg.github.io/scheduling-apis/',XMLHttpRequest:'https://xhr.spec.whatwg.org/',WebLocks:'https://www.w3.org/TR/web-locks/'};
function stage(module){const name=path.basename(module,'.luau');
 if(module.includes('/Diagnostics/'))return'R00';
 if(/^(CustomElements|ElementInternals|ShadowDOM)$/.test(name))return'R03';
 if(/^(Selection|SelectionNavigation|Editing|TextControlSelection|PointerCapture|HostEvents|FormDataDOM|FormDirectionData)$/.test(name))return'R04';
 if(/^(DOMCanvas|DOMCanvasPaths)$/.test(name))return'R15';
 if(/^DOM|^(RangeContents|XMLSerialization)$/.test(name))return'R02';
 if(/^(CSSOM|CSSDeclarations|ComputedStyle|Style|TypedOM|TypedNumeric|TypedTokens|TypedTransforms|TypedIndexed)/.test(name))return'R05';
 if(name==='WebAnimations')return'R06';
 if(/^Geometry/.test(name))return'R15';
 if(/^(Strings|Identifier|RegExp|LibraryURL|UnicodeNormalization|LibraryStringNormalization|FileData|ObjectURLs)/.test(name))return'R07';
 if(/^Intl|^LibraryDate/.test(name))return'R08';
 if(/^(ImageResources|FontLoading|AudioElements|VideoElements|MediaDevices|MediaStreams)$/.test(name))return'R16';
 if(name==='NetworkData'||name==='FormData')return'R09';
 if(name==='XMLHttpRequest')return'R10';
 if(name==='WebLocks')return'R12';
 if(/Stream|^EncodingStreams$/.test(name))return'R10';
 if(name==='Storage')return'R11';
 if(name==='Modules'||name==='ScriptLoader')return'R13';
 if(/^(EventLoop|Navigation|Performance|LayoutObservers|MutationObserver|BrowsingWindows|Fullscreen|SimpleDialogs|DocumentLifecycle|IdleCallbacks|Scheduler|TaskSignals)$/.test(name))return'R14';
 if(name==='RealmAccess')return'R02';
 if(/^(WorkerAdapter|WorkerRealm|Messaging)$/.test(name))return'R17';
 return'R01';}
const runner=fs.readFileSync(path.join(root,'scripts/run-html-tests.cjs'),'utf8');
const registrations=[...runner.matchAll(/\[\s*['"]((?:JavaScript[^'"]+|DocumentLifecycle|BrowsingWindows|WindowManager))['"]\s*,\s*['"]([^\r\n]+?)(?:\r?\n|\]\);)/g)].map(m=>({name:m[1],arguments:m[2]}));
const owningFamilyTests={SimpleDialogs:['JavaScriptSimpleDialogs','WindowManager'],DocumentLifecycle:['DocumentLifecycle','WindowManager'],IdleCallbacks:['JavaScriptIdleCallbacks','JavaScriptClock','JavaScriptSimpleDialogs'],MediaDevices:['MediaDevicePermissions','PermissionHost','PermissionDialogUI','MediaStreamCapture'],MediaStreams:['MediaStreamCapture']};
const sourceFiles=fs.readdirSync(path.join(root,'src/HTMLEngine/JavaScript')).filter(f=>f.endsWith('.luau')).map(f=>'src/HTMLEngine/JavaScript/'+f);
sourceFiles.push('src/HTMLEngine/Diagnostics/HostCapabilities.luau');
const modules=sourceFiles.sort().map(module=>{const source=fs.readFileSync(path.join(root,module),'utf8');const id=module.replace('src/HTMLEngine/','').replace('.luau','');return{
 module,stage:stage(module),sha256:crypto.createHash('sha256').update(source).digest('hex'),spec:moduleSpecs[path.basename(module,'.luau')]||specs[stage(module)],
 tests:[...new Set([...registrations.filter(r=>r.arguments.includes('require("'+id+'")')).map(r=>r.name),...(owningFamilyTests[path.basename(module,'.luau')]||[])])].sort(),
 testMeaning:owningFamilyTests[path.basename(module,'.luau')]?'Registered direct dependency or explicit owning-family regression; per-member conformance is not implied':'Registered direct dependency; per-member conformance is not implied'};});
const moduleByPath=new Map(modules.map(m=>[m.module,m]));
function normalizeFunction(info){if(!info)return undefined;return{...info,call:declaration(info.call),construct:declaration(info.construct)};}
for(const owner of owners){owner.functionInfo=normalizeFunction(owner.functionInfo);owner.aliases.sort();}
for(const record of records){record.functionInfo=normalizeFunction(record.functionInfo);record.get=normalizeFunction(record.get);record.set=normalizeFunction(record.set);
 const provenance=record.functionInfo?.call||record.functionInfo?.construct||record.get?.call||record.set?.call;
 if(provenance)record.declaration=provenance;
 const module=provenance&&moduleByPath.get(provenance.module);record.stage=module?.stage;
 record.validation='installed descriptor only; semantics require family regressions';
}
// Getter sentinel is private test infrastructure, not a public API export.
const sentinelIds=new Set(owners.filter(o=>o.path==='<getter-sentinel>').map(o=>o.id));
const publicOwners=owners.filter(o=>!sentinelIds.has(o.id));const publicRecords=records.filter(r=>!sentinelIds.has(r.owner));
const ownerById=new Map(publicOwners.map(o=>[o.id,o]));
function interfaceStage(record){
 const global=record.path.match(/^globalThis\.([^.[]+)/)?.[1];
 if(!global)return undefined;
 if(/^(PageTransitionEvent|BeforeUnloadEvent|IdleDeadline|requestIdleCallback|cancelIdleCallback|alert|confirm|prompt|onpageshow|onpagehide|onbeforeunload|onunload)$/.test(global))return'R14';
 if(/^(Selection|PointerEvent|Touch|TouchList|TouchEvent|InputEvent|KeyboardEvent|MouseEvent|WheelEvent|Event|EventTarget|UIEvent|FocusEvent)$/.test(global))return'R04';
 if(/^(CustomElementRegistry|ElementInternals|CustomStateSet|ShadowRoot|customElements)$/.test(global))return'R03';
 if(/^(Node|NodeList|Document|XMLDocument|DOMParser|XMLSerializer|DocumentFragment|DocumentType|CharacterData|Text|Comment|CDATASection|ProcessingInstruction|Attr|NamedNodeMap|Element|HTMLCollection|DOMImplementation|HTML.*Element)$/.test(global)){
  if(/^(attachShadow|shadowRoot|attachInternals|assignedNodes|assignedElements|assignedSlot|slotAssignment)$/.test(record.key))return'R03';
  if(/^(setPointerCapture|releasePointerCapture|hasPointerCapture|getSelection)$/.test(record.key))return'R04';
  if(record.key==='style'||record.key==='attributeStyleMap'||record.key==='computedStyleMap')return'R05';
 if(record.key==='animate'||record.key==='getAnimations')return'R06';
  if(/^(requestFullscreen|exitFullscreen|fullscreenEnabled|fullscreenElement)$/.test(record.key))return'R14';
  if(global==='Document'&&/^(hidden|visibilityState|onvisibilitychange)$/.test(record.key))return'R14';
  if(global==='HTMLImageElement'&&/^(complete|naturalWidth|naturalHeight|currentSrc|width|height|decode)$/.test(record.key))return'R16';
  if(global==='HTMLMediaElement'&&record.key==='srcObject')return'R16';
  if(global==='HTMLScriptElement'&&record.key==='supports')return'R13';
  return'R02';
 }
 if(/^CSS|^(MediaQueryList|StyleSheet|MediaList)$/.test(global))return'R05';
 if(/^(Image|FontFace|FontFaceSet|FontFaceSetLoadEvent|MediaStream|MediaStreamTrack)$/.test(global))return'R16';
 if(global==='PermissionStatus')return'R14';
 if(/^(Animation|AnimationEffect|KeyframeEffect|DocumentTimeline|AnimationTimeline|AnimationPlaybackEvent)$/.test(global))return'R06';
 if(/^(Canvas|Path2D|ImageData|DOMMatrix|DOMPoint|DOMRect|DOMQuad)/.test(global))return'R15';
 return undefined;
}
// Data constants inherit their owner's family where possible. Unknown opaque
// protocol members remain R00 inspection gaps rather than disappearing.
for(const record of publicRecords){if(!record.stage){const owner=ownerById.get(record.owner),declaration=owner?.functionInfo?.call||owner?.functionInfo?.construct;
 record.stage=declaration&&moduleByPath.get(declaration.module)?.stage||publicRecords.find(r=>r.owner===record.owner&&r.stage)?.stage||'R00';}
 const semanticStage=interfaceStage(record);if(semanticStage&&semanticStage!==record.stage){record.declarationStage=record.stage;record.stage=semanticStage;}
 const declarationModule=record.declaration&&moduleByPath.get(record.declaration.module);
 record.spec=/^globalThis\.(?:PermissionStatus(?:\.|$)|navigator\.permissions(?:\.|$))/.test(record.path)?permissionsSpec:
 /^(?:globalThis\.|<intrinsic>\.)(?:IdleDeadline|requestIdleCallback|cancelIdleCallback)(?:\.|$)/.test(record.path)?idleSpec:
  declarationModule?.stage===record.stage?declarationModule.spec:specs[record.stage];
 record.tests=declarationModule?.tests||[];
}
const roadmap=fs.readFileSync(path.join(root,'docs/JAVASCRIPT-ROADMAP.md'),'utf8');
const families=[...roadmap.matchAll(/^\| (R\d\d) ([^|]+)\| ([^|]+)\| ([^|]+)\| ([^|]+)\|/gm)].map(m=>({id:m[1],name:m[2].trim(),target:m[3].trim(),dependencies:m[4].trim(),completionEvidence:m[5].trim(),
 status:'open family; installed members and documented profiles do not establish completion',spec:specs[m[1]],modules:modules.filter(x=>x.stage===m[1]).map(x=>x.module)}));
assert.equal(new Set(families.map(f=>f.id)).size,21,'Keep all R00–R20 target families in the register');
const inventory={schema:header.schema,revision:1,generatedUTC:new Date().toISOString(),profile:header.profile,
 toolchain:{node:process.version,luau:'official CLI selected by LUAU_BIN or build/tools/luau/luau.exe'},
 evidence:{getterReads:end.getterReads,scriptsRun:end.scriptsRun,availabilityOnly:true,nativeStudioProbe:false,publishedGameProbe:false},
 limitations:[
  'Descriptor presence does not prove that a method, constructor, event or renderer implements its complete standard.',
  'Accessor return values and runtime-created objects are intentionally not evaluated. Instance-only surfaces require explicit family fixtures.',
  'Legacy opaque wrappers without an own-descriptor protocol are retained as inspection gaps.',
  'Module provenance identifies the installed function declaration; generic registration wrappers may differ from the algorithm implementation.',
  'Direct test dependencies establish discoverability, not per-member conformance. Open roadmap targets remain present even without exports.',
  'The standard references are living sources. Node/V8 differential profile and imported data versions are documented separately.'
 ],hostProfile:'docs/JAVASCRIPT-HOST-CAPABILITIES.md',r01Profile:'docs/JAVASCRIPT-R01-CORE.md',
 profiles:{R01:'docs/JAVASCRIPT-R01-CORE.md',R02:'docs/JAVASCRIPT-DOCUMENTS-R02.md',R03:'docs/JAVASCRIPT-COMPONENTS.md',R04:'docs/JAVASCRIPT-INPUT-R04.md',
  R05:'docs/JAVASCRIPT-CSS-ANIMATIONS-20261005.md',R06:'docs/JAVASCRIPT-CSS-ANIMATIONS-20261005.md',
  R07:'docs/JAVASCRIPT-TEXT-DATA-20261005.md',R08:'docs/JAVASCRIPT-TEXT-DATA-20261005.md',
  R10:'docs/JAVASCRIPT-IMPLEMENTATION.md#asynchrones-xmlhttprequest--18-oktober-2026',R12:'docs/JAVASCRIPT-IMPLEMENTATION.md#web-locks-im-hostspeicher--18-oktober-2026',
  R13:'docs/JAVASCRIPT-LOADING-20261005.md',R14:'docs/JAVASCRIPT-IMPLEMENTATION.md#dialoge-und-dokumentlebenszyklus--15-oktober-2026',R16:'docs/JAVASCRIPT-LOADING-20261005.md'},
 audioProfile:'docs/JAVASCRIPT-AUDIO-20261006.md',idleProfile:'docs/JAVASCRIPT-IMPLEMENTATION.md#kooperative-idle-callbacks--15-oktober-2026',schedulerProfile:'docs/JAVASCRIPT-IMPLEMENTATION.md#priorisierte-aufgaben--18-oktober-2026',families,modules,owners:publicOwners,descriptors:publicRecords,
 eventHandlers:publicRecords.filter(r=>/^on[a-z]/.test(r.key)).map(r=>({path:r.path,stage:r.stage})),
 eventInterfaces:publicRecords.filter(r=>r.owner===1&&/Event$/.test(r.key)&&r.functionInfo).map(r=>({name:r.key,stage:r.stage})),
 missingEventCatalog:'Arbitrary dispatchEvent type strings and native-host delivery are not inferred from interface names; see host profile and Input/Events fixtures.'};
const output=path.join(root,'docs/javascript-api-register.v1.json');
if(process.argv.includes('--check')){
 const previous=JSON.parse(fs.readFileSync(output,'utf8'));const stable=value=>({...value,generatedUTC:undefined});
 assert.ok(JSON.stringify(stable(inventory))===JSON.stringify(stable(previous)),'Runtime API register is stale; run node scripts/export-javascript-api.cjs');
 console.log('Runtime API register is current; getter sentinel untouched.');
}else{
 fs.writeFileSync(output,JSON.stringify(inventory,null,2)+'\n');
 console.log(`Runtime API register: ${publicRecords.length} descriptors, ${publicOwners.length} owners, ${modules.length} modules; getter reads 0. ${path.relative(root,output)}`);
}
