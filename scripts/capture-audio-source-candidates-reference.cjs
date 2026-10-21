const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),http=require('node:http');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/audio-source-candidates-reference'),pin={commit:'ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c',sha256:'49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f'};
const frozenPath=path.join(root,'build/media-reflection-prep/html-target-source');let frozen=fs.existsSync(frozenPath)?fs.readFileSync(frozenPath):null;
if(frozen&&crypto.createHash('sha256').update(frozen).digest('hex')!==pin.sha256)throw Error('Frozen HTML source changed');
function wav(value){const b=Buffer.alloc(320044);b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVE',8);b.write('fmt ',12);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(8000,24);b.writeUInt32LE(16000,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(320000,40);for(let i=44;i<b.length;i+=2)b.writeInt16LE(value,i);return b}
const one=wav(0),two=wav(1),requests=[],pending=new Map(),released=new Set();let browser;
const server=http.createServer((req,res)=>{requests.push({path:req.url,range:req.headers.range||null});const url=new URL(req.url,'http://local');
 if(url.pathname.endsWith('/hold.wav')){if(released.has(url.pathname)){res.writeHead(404,{'Content-Length':0});res.end()}else pending.set(url.pathname,res);return}
 if(url.pathname.endsWith('/404.wav')){res.writeHead(404,{'Content-Length':0});res.end();return}
 if(url.pathname.endsWith('/corrupt.wav')){res.writeHead(200,{'Content-Type':'audio/wav'});res.end('not a wave');return}
 if(url.pathname.endsWith('/index.html')){res.writeHead(200,{'Content-Type':'text/html'});res.end('<!doctype html><body><audio id=m muted preload=auto controls></audio>');return}
 const b=url.pathname.endsWith('/two.wav')?two:one,range=req.headers.range?.match(/^bytes=(\d+)-(\d*)$/);
 if(range){const first=+range[1],last=range[2]?Math.min(+range[2],b.length-1):b.length-1;res.writeHead(206,{'Content-Type':'audio/wav','Content-Length':last-first+1,'Content-Range':`bytes ${first}-${last}/${b.length}`,'Accept-Ranges':'bytes'});res.end(b.subarray(first,last+1))}
 else{res.writeHead(200,{'Content-Type':'audio/wav','Content-Length':b.length,'Accept-Ranges':'bytes'});res.end(b)}
});
const state=`({src:m.getAttribute('src'),currentSrc:m.currentSrc,paused:m.paused,ready:m.readyState,network:m.networkState,error:m.error?.code||null,time:m.currentTime,rate:m.playbackRate,outcome,events:events.slice(),children:Array.from(m.children).map(n=>({id:n.id,src:n.getAttribute('src'),type:n.getAttribute('type'),media:n.getAttribute('media')}))})`;
const cases=[
 ['404 candidate then playable source',`m.append(make('a','404.wav'),make('b','one.wav'));play()`],
 ['corrupt candidate then playable source',`m.append(make('a','corrupt.wav'),make('b','one.wav'));play()`],
 ['missing empty invalid then playable',`m.append(make('a',null),make('b',''),make('c','http://['),make('d','one.wav'));play()`],
 ['false media before playable',`m.append(make('a','one.wav',{media:'(min-width: 99999px)'}),make('b','two.wav'));play()`],
 ['unsupported type before playable',`m.append(make('a','one.wav',{type:'audio/x-no-such; codecs="foo"'}),make('b','two.wav'));play()`],
 ['invalid MIME declaration still sniffed',`m.append(make('a','one.wav',{type:'not a MIME type'}),make('b','two.wav'));play()`],
 ['direct failure never falls back to child',`m.append(make('b','one.wav'));m.src=base+'404.wav';play()`],
 ['all candidates failed waiting',`m.append(make('a','404.wav'),make('b','corrupt.wav'));play()`],
 ['error listener inserts at candidate pointer',`const a=make('a','404.wav'),b=make('b','two.wav');a.addEventListener('error',()=>m.insertBefore(make('inserted','one.wav'),b),{once:true});m.append(a,b);play()`],
 ['error listener prepends before candidate pointer',`const a=make('a','404.wav'),b=make('b','two.wav');a.addEventListener('error',()=>m.prepend(make('prepended','one.wav')),{once:true});m.append(a,b);play()`],
 ['waiting pointer later insertion',`m.append(make('a','404.wav'));play()`],
 ['held failure candidate removed',`m.append(make('a','hold.wav'),make('b','one.wav'));play()`],
 ['held failure following candidate removed',`m.append(make('a','hold.wav'),make('b','one.wav'),make('c','two.wav'));play()`],

  [
    "held failure candidate removed global ref",
    "m.append(make('a','hold.wav'),make('b','one.wav'));play()"
  ],
  [
    "held failure candidate moved outside audio global ref",
    "m.append(make('a','hold.wav'),make('b','one.wav'));play()"
  ],
  [
    "held failure candidate removed mutated global ref",
    "m.append(make('a','hold.wav'),make('b','one.wav'));play()"
  ],
  [
    "held failure candidate removed then reinserted global ref",
    "m.append(make('a','hold.wav'),make('b','one.wav'));play()"
  ],
  [
    "held failure following candidate removed then inserted at gap",
    "m.append(make('a','hold.wav'),make('b','one.wav'),make('c','two.wav'));play()"
  ],
  [
    "all missing empty invalid wait pending",
    "m.append(make('a',null),make('b',''),make('c','http://['));play()"
  ],
  [
    "audio wav declared positive",
    "m.append(make('a','one.wav',{type:'audio/wav'}),make('b','two.wav'));play()"
  ],
  [
    "unsupported wav codec before playable",
    "m.append(make('a','one.wav',{type:'audio/wav; codecs=\"unrecognized\"'}),make('b','two.wav'));play()"
  ],
  [
    "source error listener switches direct src",
    "const a=make('a','404.wav'),b=make('b','one.wav');a.addEventListener('error',()=>m.src=base+'two.wav',{once:true});m.append(a,b);play()"
  ],
  [
    "source error listener removes all candidates",
    "const a=make('a','404.wav'),b=make('b','one.wav');a.addEventListener('error',()=>m.replaceChildren(),{once:true});m.append(a,b);play()"
  ],
  [
    "source error listener removes audio",
    "const a=make('a','404.wav'),b=make('b','one.wav');a.addEventListener('error',()=>m.remove(),{once:true});m.append(a,b);play()"
  ]
,["none first candidate resumes on play","m.preload='none';m.append(make('a','404.wav'),make('b','one.wav'))"],
["none first candidate resumes on hint upgrade","m.preload='NONE';m.append(make('a','404.wav'),make('b','one.wav'))"],
["early cursor rate survive candidate retry","m.defaultPlaybackRate=1.25;m.playbackRate=1.5;m.currentTime=5;m.append(make('a','404.wav'),make('b','one.wav'));play()"],
["author matchMedia override is bypassed","globalThis.matchMedia=()=>{throw new Error('author matchMedia must not be invoked')};m.append(make('a','one.wav',{media:'(min-width: 99999px)'}),make('b','two.wav'));play()"],
["positive media candidate","m.append(make('a','one.wav',{media:'(min-width: 1px)'}),make('b','two.wav'));play()"],
["foreign and nested sources do not select","const foreign=document.createElementNS('urn:foreign','source');foreign.id='foreign';foreign.setAttribute('src','one.wav');const box=document.createElement('div');box.innerHTML='<source src=\"one.wav\">';m.append(foreign,box);play()"],
["source error listener explicit load cancels old loop","const a=make('a','404.wav'),b=make('b','one.wav');a.addEventListener('error',()=>m.load(),{once:true});m.append(a,b);play()"],
["source error listener adds another pending play","const a=make('a','404.wav'),b=make('b','one.wav');a.addEventListener('error',()=>play(),{once:true});m.append(a,b);play()"],
["waiting pointer append after exhaustion","m.append(make('a','404.wav'));play()"],
["fragment insertion after removing gap neighbor","const a=make('a','404.wav'),b=make('b','two.wav');a.addEventListener('error',()=>{b.remove();const f=document.createDocumentFragment();f.append(document.createTextNode(''),document.createComment('gap'),make('inserted','one.wav'));m.append(f)},{once:true});m.append(a,b);play()"],
["held failure candidate reordered with moveBefore","m.append(make('a','hold.wav'),make('b','one.wav'),make('c','two.wav'));play()"],
["replaceChildren in source error preserves gap","const a=make('a','404.wav'),b=make('b','two.wav');a.addEventListener('error',()=>m.replaceChildren(document.createTextNode(''),make('replacement','one.wav')),{once:true});m.append(a,b);play()"]];
async function run(action){const result=await browser.send('Runtime.evaluate',{expression:`(()=>{${action};return ${state}})()`,returnByValue:true,userGesture:true});if(result.exceptionDetails)throw Error(result.exceptionDetails.exception?.description||result.exceptionDetails.text);return result.result.value}
async function settled(){await browser.evaluate('new Promise(r=>setTimeout(r,160))');return browser.evaluate(state)}
async function init(origin,index){const base=origin+'/'+index+'/';await browser.send('Page.navigate',{url:base+'index.html'});await new Promise(r=>setTimeout(r,60));await browser.evaluate(`globalThis.m=document.getElementById('m');const baseElement=document.createElement('base');baseElement.href=${JSON.stringify(base)};document.head.append(baseElement);globalThis.base=${JSON.stringify(base)};globalThis.events=[];globalThis.outcome='pending';globalThis.make=(id,src,attrs={})=>{const s=document.createElement('source');s.id=id;if(src!==null)s.setAttribute('src',src);for(const [k,v]of Object.entries(attrs))s.setAttribute(k,v);s.addEventListener('error',e=>events.push({target:s.id,type:e.type,trusted:e.isTrusted,currentSrc:m.currentSrc,network:m.networkState,error:m.error?.code||null}));return s};globalThis.play=()=>m.play().then(()=>outcome='played',e=>outcome=e.name);for(const type of ['loadstart','loadedmetadata','play','playing','waiting','error','abort','emptied'])m.addEventListener(type,e=>events.push({target:'media',type:e.type,trusted:e.isTrusted,currentSrc:m.currentSrc,network:m.networkState,error:m.error?.code||null}));`);return base}
const orderingCases=[
 ['missing source error observes next selected resource',"const a=make('a',null),b=make('b','hold.wav');a.addEventListener('error',()=>observe('handler'));m.append(a,b);play()"],
 ['404 source error observes next selected resource',"const a=make('a','404.wav'),b=make('b','hold.wav');a.addEventListener('error',()=>observe('handler'));m.append(a,b);play()"],
 ['error listener insertion precedes already selected source',"const a=make('a','404.wav'),b=make('b','hold.wav');globalThis.heldSource=b;a.addEventListener('error',()=>{observe('before');m.insertBefore(make('inserted','one.wav'),b);observe('after')});m.append(a,b);play()"],
 ['error listener removes selected next source and appends replacement',"const a=make('a','404.wav'),b=make('b','hold.wav');globalThis.heldSource=b;a.addEventListener('error',()=>{observe('before');b.remove();m.append(make('replacement','one.wav'));observe('after')});m.append(a,b);play()"],
 ['error listener replaces children after next source selected',"const a=make('a','404.wav'),b=make('b','hold.wav');globalThis.heldSource=b;a.addEventListener('error',()=>{observe('before');m.replaceChildren(document.createTextNode(''),make('replacement','one.wav'));observe('after')});m.append(a,b);play()"],
 ['queued qualification errors survive ordinary candidate advances',"const a=make('a',null),b=make('b',''),c=make('c','http://['),d=make('d','hold.wav');for(const s of [a,b,c])s.addEventListener('error',()=>observe(s.id));m.append(a,b,c,d);play()"],
 ['source error direct reset invalidates selection continuation',"const a=make('a','404.wav'),b=make('b','hold.wav');a.addEventListener('error',()=>{observe('before');m.src=base+'two.wav';observe('after')});m.append(a,b);play()"],
 ['source error explicit load invalidates selection continuation',"const a=make('a','404.wav'),b=make('b','hold.wav');a.addEventListener('error',()=>{observe('before');m.replaceChildren(make('replacement','two.wav'));m.load();observe('after')},{once:true});m.append(a,b);play()"]
];
if(cases.length!==36||new Set(cases.map(([name])=>name)).size!==36||orderingCases.length!==8||new Set(orderingCases.map(([name])=>name)).size!==8)throw Error('SOURCE capture inventory changed');
async function captureOrdering(origin){
 const out={browser:await browser.send('Browser.getVersion'),cases:[]};
 for(let i=0;i<orderingCases.length;i++){
  const[name,action]=orderingCases[i],index='order'+i;await init(origin,index);
  await browser.evaluate(`globalThis.order=[];globalThis.observe=label=>{const snapshot=()=>({label,currentSrc:m.currentSrc,network:m.networkState,ready:m.readyState,paused:m.paused,outcome,children:Array.from(m.children).map(n=>n.id)});order.push(snapshot());queueMicrotask(()=>order.push({...snapshot(),label:label+':microtask'}));};`);
  const before=requests.length,record={name,action,immediate:await run(action)};const expected=i===5?6:i<2?2:4;
  for(let attempt=0;attempt<100&&(await browser.evaluate('order.length'))<expected;attempt++)await new Promise(r=>setTimeout(r,20));
  record.settled=await settled();record.ordering=await browser.evaluate('order');if(record.ordering.length!==expected)throw Error('SOURCE ordering handler inventory: '+name);
  record.requestsBeforeRelease=requests.slice(before);
  const heldPath='/'+index+'/hold.wav',res=pending.get(heldPath);if(res){pending.delete(heldPath);released.add(heldPath);res.writeHead(404,{'Content-Length':0});res.end();record.afterRelease=await settled()}
  record.requests=requests.slice(before);out.cases.push(record);console.log(name+': '+JSON.stringify({order:record.ordering,requests:record.requests.map(x=>x.path)}));
 }
 return out;
}
function project(out){
 const order={steps:['Failed with elements: queue error task','Await a stable state: queue microtask','Find next candidate','Process candidate'],sourceLines:[39026,39063],stableStateLines:[123740,123756]};
 const orderReason='Frozen HTML queues SOURCE.error, then immediately queues the stable-state continuation microtask. The next candidate is selected before the error task; HTTP-failure Chromium handlers run before that selection. Raw qualification-failure handlers already observe the next selection.';
 out.normative={selection:[38802,39122],sourceErrors:[39026,39033],gap:[38952,38983],waitingResume:[39038,39085],beforeMetadataFailure:[39499,39519],stableState:[123740,123756]};
 out.deltas=[
  {case:'invalid MIME declaration still sniffed',reason:'Raw Chromium skips malformed MIME. Frozen HTML type qualification only skips a parsed type known unrenderable; the target unknown-type profile attempts the valid URL.',steps:['Process candidate: parsed type known unrenderable'],sourceLines:[39012,39016],targetRequests:['one.wav'],targetSourceErrors:[],targetState:{suffix:'one.wav'}},
  {case:'waiting pointer later insertion',reason:'Raw Chromium prepending before exhausted gap restarts selection. Frozen gap keeps prepended nodes before the pointer; only later append resumes, without a new loadstart.',steps:['pointer updates','Waiting','Find next candidate'],sourceLines:[38952,38983],waitingLines:[39043,39085],targetRequests:['404.wav','two.wav'],targetSourceErrors:['a'],targetLoadstarts:1},
  {case:'waiting pointer append after exhaustion',reason:'Frozen waiting continuation processes nodes inserted at the exhausted gap without repeating loadstart. Chromium remains pending after this append.',steps:['Waiting','Find next candidate'],sourceLines:[39043,39085],targetLoadstarts:1,targetRequests:['404.wav','two.wav'],targetSourceErrors:['a'],targetContinuation:{suffix:'two.wav',network:1,ready:4,outcome:'played'}},
  ...['error listener inserts at candidate pointer','fragment insertion after removing gap neighbor','replaceChildren in source error preserves gap'].map(name=>({case:name,...order,reason:orderReason,targetRequests:['404.wav','two.wav'],targetSourceErrors:['a'],targetState:{suffix:'two.wav',network:1,ready:4,outcome:'played'}})),
  {case:'source error listener removes all candidates',...order,reason:orderReason+' Removing children does not restart the resource already selected.',targetRequests:['404.wav','one.wav'],targetSourceErrors:['a'],targetState:{suffix:'one.wav',network:1,ready:4,outcome:'played'}},
  {case:'source error listener switches direct src',...order,reason:orderReason+' The direct src reset invalidates the already started attempt.',targetRequests:['404.wav','one.wav','two.wav'],targetSourceErrors:['a']},
  {case:'source error listener explicit load cancels old loop',...order,reason:orderReason+' Explicit load invalidates the attempt selected before each error handler.',targetRequests:['404.wav','one.wav','404.wav','one.wav'],targetSourceErrors:['a','a']},
  ...['held failure candidate removed','held failure candidate removed global ref','held failure candidate moved outside audio global ref','held failure candidate removed mutated global ref','held failure candidate reordered with moveBefore'].map(name=>({case:name,reason:'Frozen queues error at retained candidate even when removed or moved; raw Chromium may omit it.',steps:['Failed with elements: fire at candidate'],sourceLines:[39026,39028],targetSourceErrors:['a']})),
  {case:'held failure candidate removed then reinserted global ref',reason:'Frozen removal+reinsertion at the gap puts candidate after pointer, so it is retried. Raw Chromium skips the moved candidate and omits its error.',steps:['pointer updates','Find next candidate','Failed with elements'],sourceLines:[38952,38983],selectionLines:[39026,39063],targetRequests:['hold.wav','hold.wav','one.wav'],targetSourceErrors:['a','a']}
 ];
 out.orderingProjections=orderingCases.map(([name],i)=>({case:name,...order,rawDelta:i!==0&&i!==5,reason:i===0||i===5?'Raw and frozen qualification-failure ordering agree.':orderReason,handlerSuffix:'hold.wav',beforeReleaseRequests:i===0||i===5?['hold.wav']:i>=6?['404.wav','hold.wav','two.wav']:['404.wav','hold.wav'],requests:i===0||i===5?['hold.wav']:i>=6?['404.wav','hold.wav','two.wav']:i===3||i===4?['404.wav','hold.wav','one.wav']:['404.wav','hold.wav'],sourceErrors:i===0?['a','b']:i===5?['a','b','c','d']:i>=6?['a']:['a','b'],final:i>=6?{suffix:'two.wav',network:1,ready:4,outcome:'AbortError',paused:true}:i===3||i===4?{suffix:'one.wav',network:1,ready:4,outcome:'played',paused:false}:{suffix:'hold.wav',network:3,ready:0,outcome:'pending',paused:false}}));
 out.openAxes={directFailurePaused:{case:'direct failure never falls back to child',raw:'Chromium paused=true',target:'Existing audio profile remains paused=false after internal play. No paused assignment is present in dedicated failure steps.',sourceLines:[39088,39122],scope:'Preserved separate axis; not claimed by SOURCE fallback parity.'}};
 out.scope='Fresh isolated same-origin HTTP browser reference. Original13+5 and held11 are preserved verbatim under preparations. The original36+5 raw blocks are preserved when adding ordering-only probes. Raw states/requests/trusted events remain unnormalized. Target compares bounded source order, state, SOURCE errors and explicitly scoped normative counterparts, including the HTTP-failure task-versus-microtask delta. Roblox mapping/type profile is separate from browser codecs/HTTP PCM; historical owner/base timing, full task discard, cross-realm shared playback and no-realm SOURCE selection are not closed.';
}
(async()=>{fs.mkdirSync(folder,{recursive:true});
 if(!frozen){const response=await fetch('https://raw.githubusercontent.com/whatwg/html/'+pin.commit+'/source');if(!response.ok)throw Error('Frozen HTML fetch '+response.status);frozen=Buffer.from(await response.arrayBuffer())}
 if(crypto.createHash('sha256').update(frozen).digest('hex')!==pin.sha256)throw Error('Frozen HTML source changed');fs.writeFileSync(path.join(folder,'html-target-source'),frozen);
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const origin='http://127.0.0.1:'+server.address().port;browser=await openBrowser(folder);const out={target:pin,browser:await browser.send('Browser.getVersion'),server:{origin,duration:20,format:'16-bit mono PCM/8000Hz',wavHashes:[one,two].map(b=>crypto.createHash('sha256').update(b).digest('hex'))},scope:'Exploratory raw native only; no engine or conformance normalization.',cases:[]};
 try{if(process.argv.includes('--ordering-only')){
  const previous=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/audio-source-candidates-browser.json'),'utf8'));previous.ordering=await captureOrdering(origin);project(previous);
  fs.writeFileSync(path.join(folder,'ordering-native.json'),JSON.stringify(previous.ordering,null,2)+'\n');fs.writeFileSync(path.join(folder,'native-ordering-expanded.json'),JSON.stringify(previous,null,2)+'\n');
  if(!process.argv.includes('--build-only'))fs.writeFileSync(path.join(root,'tests/fixtures/audio-source-candidates-browser.json'),JSON.stringify(previous,null,2)+'\n');return;
 }
 for(let index=0;index<cases.length;index++){const [name,action]=cases[index],base=await init(origin,index),before=requests.length,record={name,action,immediate:await run(action),steps:[]};
  if(name.startsWith('held failure')){for(let i=0;i<100&&!pending.has('/'+index+'/hold.wav');i++)await new Promise(r=>setTimeout(r,10));if(!pending.has('/'+index+'/hold.wav'))throw Error('Held request not received');record.held=await browser.evaluate(state);const mutation=name.includes('reordered')?'globalThis.heldSource=document.getElementById("a");m.moveBefore(heldSource,null)':name.includes('following candidate removed then inserted')?'globalThis.heldSource=document.getElementById("b");heldSource.remove();m.insertBefore(heldSource,document.getElementById("c"))':name.includes('moved outside')?'globalThis.heldSource=document.getElementById("a");document.body.append(heldSource)':name.includes('mutated global ref')?'globalThis.heldSource=document.getElementById("a");heldSource.remove();heldSource.src=base+"two.wav"':name.includes('reinserted global ref')?'globalThis.heldSource=document.getElementById("a");heldSource.remove();m.prepend(heldSource)':name.includes('removed global ref')?'globalThis.heldSource=document.getElementById("a");heldSource.remove()':name.includes('following')?'document.getElementById("b").remove()':'document.getElementById("a").remove()';record.steps.push({name:'remove candidate around live pointer',action:mutation,immediate:await run(mutation)});const res=pending.get('/'+index+'/hold.wav');pending.delete('/'+index+'/hold.wav');released.add('/'+index+'/hold.wav');res.writeHead(404,{'Content-Length':0});res.end()}
  record.settled=await settled();
  if(name.startsWith('none first candidate')){const mutation=name.endsWith('play')?'play()':'m.preload="auto"';record.steps.push({name:'resume retained first candidate',action:mutation,immediate:await run(mutation),settled:await settled()})}
  if(name==='waiting pointer append after exhaustion'){const mutation="m.append(make('appended','two.wav'))";record.steps.push({name:'append after exhausted gap',action:mutation,immediate:await run(mutation),settled:await settled()})}
  record.heldReference=await browser.evaluate("globalThis.heldSource?({id:heldSource.id,connected:heldSource.isConnected,parent:heldSource.parentElement?.localName||null,src:heldSource.getAttribute('src')}):null");
  if(name==='waiting pointer later insertion'){for(const [stepName,mutation]of [['prepend before exhausted pointer',`m.prepend(make('prepended','one.wav'))`],['append at exhausted pointer',`m.append(make('appended','two.wav'))`]]){record.steps.push({name:stepName,action:mutation,immediate:await run(mutation),settled:await settled()})}}
  record.requests=requests.slice(before);out.cases.push(record);console.log(name+': '+JSON.stringify({current:record.settled.currentSrc,network:record.settled.network,error:record.settled.error,outcome:record.settled.outcome,events:record.settled.events.map(e=>e.target+':'+e.type),requests:record.requests.map(r=>r.path)}))}
  const baseControls=[['direct set then base mutation',`m.src='one.wav';document.querySelector('base').href=base+'later/'`],['direct selected then base then load',`m.src='one.wav'`],['child set then base mutation',`const s=make('a','one.wav');document.querySelector('base').href=base+'later/';m.append(s)`],['child selected then base then load',`m.append(make('a','one.wav'))`],['detached source created old doc adopted',`const other=document.implementation.createHTMLDocument('other');other.head.innerHTML='<base href="'+base+'original/">';const s=other.createElement('source');s.id='a';s.src='one.wav';m.append(document.adoptNode(s))`]];
  out.bases=[];for(let i=0;i<baseControls.length;i++){const [name,action]=baseControls[i],base=await init(origin,'base'+i),before=requests.length,record={name,action,immediate:await run(action),settled:await settled()};if(name.includes('then load')){const mutation=`document.querySelector('base').href=base+'later/';m.load()`;record.load={action:mutation,immediate:await run(mutation),settled:await settled()}}record.requests=requests.slice(before);out.bases.push(record);console.log(name+': '+JSON.stringify({current:record.settled.currentSrc,load:record.load?.settled.currentSrc,requests:record.requests.map(r=>r.path)}))}
  const previousPath=path.join(root,'tests/fixtures/audio-source-candidates-browser.json');const previous=fs.existsSync(previousPath)?JSON.parse(fs.readFileSync(previousPath,'utf8')):null;
  out.preparations=previous?.preparations||{original:JSON.parse(fs.readFileSync(path.join(root,'build/audio-source-candidates-prep/native.json'),'utf8')),held:JSON.parse(fs.readFileSync(path.join(root,'build/audio-source-candidates-prep/held-reference-supplement.json'),'utf8'))};
  out.ordering=await captureOrdering(origin);project(out);
  fs.writeFileSync(path.join(folder,'native.json'),JSON.stringify(out,null,2)+'\n');
  if(!process.argv.includes('--build-only'))fs.writeFileSync(path.join(root,'tests/fixtures/audio-source-candidates-browser.json'),JSON.stringify(out,null,2)+'\n');console.log(out.cases.length+' source candidate cases + '+out.bases.length+' base timing controls')
 }finally{if(browser)await browser.close();for(const res of pending.values())res.destroy();server.closeAllConnections();await new Promise(r=>server.close(r))}
})().catch(async e=>{if(browser)await browser.close();if(server.listening){for(const res of pending.values())res.destroy();server.closeAllConnections();server.close()}console.error(e);process.exitCode=1});
