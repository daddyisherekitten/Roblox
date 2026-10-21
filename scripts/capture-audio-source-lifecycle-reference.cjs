const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),http=require('node:http');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/audio-source-lifecycle-reference'),pin={commit:'ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c',source:'https://raw.githubusercontent.com/whatwg/html/ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c/source',sha256:'49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f'};
function wav(sample){const length=160000,b=Buffer.alloc(44+length*2);b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVE',8);b.write('fmt ',12);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(8000,24);b.writeUInt32LE(16000,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(length*2,40);for(let i=0;i<length;i++)b.writeInt16LE(sample,44+i*2);return b}
const one=wav(0),two=wav(1),fixture=`<!doctype html><body><audio id=m controls muted preload=auto></audio><div id=holder></div></body>`;
const state=`({src:m.getAttribute('src'),currentSrc:m.currentSrc,selected:m.currentSrc===one?'one':m.currentSrc===two?'two':m.currentSrc===''?'empty':'other',paused:m.paused,time:m.currentTime,rate:m.playbackRate,ready:m.readyState,network:m.networkState,muted:m.muted,controls:m.controls,connected:m.isConnected,error:m.error?.code||null,children:Array.from(m.children).map(n=>({name:n.localName,src:n.getAttribute('src'),role:n.getAttribute('data-role')})),events:events.slice()})`;
const cases=[
 ['direct removal pause play controls','direct',[
  ['remove src while playing','m.removeAttribute("src")'],['pause after removal','m.pause()'],['play after removal pause','await m.play()'],['controls remove','m.controls=false'],['controls restore','m.controls=true'],['explicit load selects child','m.load()']]],
 ['direct removal synchronous move','direct',[
  ['remove src while playing','m.removeAttribute("src")'],['remove and reinsert same task','m.remove();document.getElementById("holder").append(m)'],['play after move','await m.play()'],['explicit load after move','m.load()']]],
 ['direct removal stable detach reinsert','direct',[
  ['remove src while playing','m.removeAttribute("src")'],['detach until stable state','m.remove()'],['reinsert after stable state','document.body.append(m)'],['play after detached pause','await m.play()'],['explicit load after reinsert','m.load()']]],
 ['direct removal source edits','direct',[
  ['remove src while playing','m.removeAttribute("src")'],['append new source','const n=document.createElement("source");n.src=one;n.dataset.role="appended";m.append(n)'],['change first child src','m.firstElementChild.src=one'],['remove first source','m.firstElementChild.remove()'],['replace children with two','m.replaceChildren(Object.assign(document.createElement("source"),{src:two}))'],['pause after source edits','m.pause()'],['play after source edits','await m.play()'],['explicit load after source edits','m.load()']]],
 ['child selection mutations','child',[
  ['change selected source src','m.firstElementChild.src=two'],['append one source','m.append(Object.assign(document.createElement("source"),{src:one}))'],['remove selected source','m.firstElementChild.remove()'],['prepend two source','m.prepend(Object.assign(document.createElement("source"),{src:two}))'],['pause after child edits','m.pause()'],['play after child edits','await m.play()'],['explicit load selects new first source','m.load()']]],
 ['empty source insertion and removal','empty',[
  ['pause empty media','m.pause()'],['insert source into empty media','m.append(Object.assign(document.createElement("source"),{src:two}))'],['play inserted source','await m.play()'],['remove only source while playing','m.firstElementChild.remove()'],['pause after last source removal','m.pause()'],['play after last source removal','await m.play()'],['explicit load without source','m.load()']]],
 ['empty source move','empty',[
  ['move source into empty media','document.body.append(Object.assign(document.createElement("source"),{id:"s",src:two}));m.append(document.getElementById("s"))'],['play moved source','await m.play()'],['move source out of active media','document.body.append(document.getElementById("s"))'],['pause after moved source removal','m.pause()'],['play after moved source removal','await m.play()'],['explicit load without moved source','m.load()']]],
 ['direct removal preload-none selected source','direct',[
  ['remove src while playing','m.removeAttribute("src")'],['pause retained resource','m.pause()'],['preload none after removal','m.preload="none"'],['controls remove','m.controls=false'],['controls restore','m.controls=true'],['play retained source despite none','await m.play()'],['explicit load selects child deferred','m.load()']]],
 ['never-connected Audio playback','detached',[
  ['remove never-connected Audio','m.remove()'],['pause never-connected Audio','m.pause()'],['play never-connected Audio','await m.play()'],['controls off on detached Audio','m.controls=false'],['controls on detached Audio','m.controls=true']]],
 ['subtree stable removal','direct',[
  ['move audio into connected subtree','globalThis.box=document.createElement("div");document.body.append(box);box.append(m)'],['remove containing subtree','box.remove()'],['reinsert containing subtree','document.body.append(box)'],['play after subtree reinsertion','await m.play()']]],
 ['shadow host stable removal','direct',[
  ['move audio into connected shadow root','globalThis.host=document.createElement("div");document.body.append(host);host.attachShadow({mode:"open"}).append(m)'],['remove shadow host','host.remove()'],['reinsert shadow host','document.body.append(host)'],['play after shadow reinsertion','await m.play()']]],
 ['empty removal internal pause','empty',[
  ['set rate on empty media','m.playbackRate=1.5'],['remove empty media','m.remove()'],['reinsert empty media','document.body.append(m)']]],
 ['microtask reinsertion boundary','direct',[
  ['remove and reinsert in queued microtask','m.remove();queueMicrotask(()=>document.body.append(m))'],['play after microtask reinsertion','await m.play()']]],
 ['promise reinsertion boundary','direct',[
  ['remove and reinsert in promise reaction','m.remove();Promise.resolve().then(()=>document.body.append(m))'],['play after promise reinsertion','await m.play()']]],
 ['nested microtask reinsertion boundary','direct',[
  ['remove and reinsert after nested microtasks','m.remove();queueMicrotask(()=>queueMicrotask(()=>queueMicrotask(()=>document.body.append(m))))'],['play after nested reinsertion','await m.play()']]],
 ['state-preserving move boundary','direct',[
  ['moveBefore retains audio state','document.getElementById("holder").moveBefore(m,null)'],['remove after preserving move','m.remove()']]],
];
async function captureHints(browser){
 const requests=[],server=http.createServer((req,res)=>{
  requests.push({url:req.url,range:req.headers.range||null});
  if(!req.url.includes('.wav')){res.writeHead(200,{'Content-Type':'text/html'});res.end('<!doctype html><body><audio id=m muted preload="'+new URL(req.url,'http://local/').searchParams.get('preload')+'"></audio></body>');return}
  const bytes=req.url.includes('two')?two:one;res.writeHead(200,{'Content-Type':'audio/wav','Content-Length':bytes.length});res.end(bytes);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const origin='http://127.0.0.1:'+server.address().port,out={cases:[],requests,note:'Actual same-origin HTTP none/NONE defer. Hint upgrades may resume buffering; they do not select a new DOM source. The engine metadata/auto background-load profile remains optional UA behavior.'};
 try{for(const raw of ['none','NONE']){
  await browser.send('Page.navigate',{url:origin+'/?preload='+raw});
  for(let i=0;i<100;i++){await new Promise(r=>setTimeout(r,20));try{if(await browser.evaluate('location.origin==='+JSON.stringify(origin)+'&&!!document.getElementById("m")'))break}catch{}if(i===99)throw Error('HTTP fixture navigation timed out')}
  await browser.evaluate(`globalThis.m=document.getElementById('m');globalThis.one=${JSON.stringify(origin+'/one.wav')};globalThis.two=${JSON.stringify(origin+'/two.wav')};m.append(Object.assign(document.createElement('source'),{src:two}));m.src=one;globalThis.events=[];for(const type of ['loadstart','emptied','abort','play','pause','playing','waiting','loadedmetadata','canplay','suspend','error'])m.addEventListener(type,e=>events.push({type:e.type,trusted:e.isTrusted}));`);
  await browser.evaluate('new Promise(r=>setTimeout(r,120))');const record={name:raw+' hint upgrade retains selection',raw,initial:await browser.evaluate(state),steps:[]};out.cases.push(record);
  for(const [name,action]of [['remove src while selected','m.removeAttribute("src")'],['upgrade preload to auto','m.preload="auto"'],['controls attach after upgrade','m.controls=true'],['play retained source','await m.play()'],['explicit load selects child','m.load()']]){
   const value=await browser.send('Runtime.evaluate',{expression:`(async()=>{events.length=0;${action};return ${state}})()`,userGesture:true,awaitPromise:true,returnByValue:true});if(value.exceptionDetails)throw Error(value.exceptionDetails.exception?.description||value.exceptionDetails.text);
   await browser.evaluate('new Promise(r=>setTimeout(r,120))');record.steps.push({name,action,immediate:value.result.value,settled:await browser.evaluate(state)});
  }
 }
 return out;
 }finally{server.closeAllConnections();await new Promise(r=>server.close(r))}
}
async function captureSelection(browser){
 await browser.load(fixture);
 await browser.evaluate(`globalThis.m=document.getElementById('m');const make=b=>URL.createObjectURL(new Blob([Uint8Array.from(atob(b),c=>c.charCodeAt(0))],{type:'audio/wav'}));globalThis.one=make(${JSON.stringify(one.toString('base64'))});globalThis.two=make(${JSON.stringify(two.toString('base64'))});m.append(Object.assign(document.createElement('source'),{src:two}));m.src=one;globalThis.events=[];for(const type of ['loadstart','emptied','abort','play','pause','playing','waiting','error'])m.addEventListener(type,e=>events.push({type:e.type,trusted:e.isTrusted}));`);
 const run=async expression=>{const v=await browser.send('Runtime.evaluate',{expression,userGesture:true,awaitPromise:true,returnByValue:true});if(v.exceptionDetails)throw Error(v.exceptionDetails.exception?.description||v.exceptionDetails.text);return v.result.value};await run('m.play()');
 const timing={name:'currentSrc changes at stable selection',steps:[]};
 for(const [name,action]of [['set different src while loaded','m.src=two'],['set identical src while loaded','m.setAttribute("src",two)'],['explicit load of changed child source','m.removeAttribute("src");m.firstElementChild.src=one;m.load()'],['set empty src while loaded','m.setAttribute("src","")'],['set invalid URL while selected','m.setAttribute("src","http://[")']]){const immediate=await run(`(async()=>{events.length=0;${action};return ${state}})()`);await browser.evaluate('new Promise(r=>setTimeout(r,120))');timing.steps.push({name,action,immediate,settled:await browser.evaluate(state)})}
 await browser.load(fixture);await browser.evaluate(`globalThis.m=new Audio();globalThis.one=URL.createObjectURL(new Blob([Uint8Array.from(atob(${JSON.stringify(one.toString('base64'))}),c=>c.charCodeAt(0))],{type:'audio/wav'}));globalThis.two='unused';globalThis.events=[];globalThis.playOutcome='pending';for(const type of ['loadstart','emptied','abort','play','pause','playing','waiting','error'])m.addEventListener(type,e=>events.push({type:e.type,trusted:e.isTrusted}));m.defaultPlaybackRate=1.25;m.playbackRate=1.5;m.currentTime=5;`);
 const empty={name:'source-less play survives source insertion',steps:[]},read=`({...${state},outcome:playOutcome})`;
 for(const [name,action]of [['play without a source','m.play().then(()=>playOutcome="played",e=>playOutcome=e.name)'],['append source to pending play','m.append(Object.assign(document.createElement("source"),{src:one}))']]){const immediate=await run(`(async()=>{events.length=0;${action};return ${read}})()`);await browser.evaluate('new Promise(r=>setTimeout(r,120))');empty.steps.push({name,action,immediate,settled:await browser.evaluate(read)})}
 const boundaries=[];
 for(const [name,append]of [['same-task source insertion retains pending play','m.append(s)'],['queued source insertion retains pending play','queueMicrotask(()=>m.append(s))'],['nested source insertion retains pending play','queueMicrotask(()=>queueMicrotask(()=>m.append(s)))']]){
  await browser.load(fixture);await browser.evaluate(`globalThis.m=new Audio();globalThis.one=URL.createObjectURL(new Blob([Uint8Array.from(atob(${JSON.stringify(one.toString('base64'))}),c=>c.charCodeAt(0))],{type:'audio/wav'}));globalThis.two='unused';globalThis.s=document.createElement('source');s.src=one;globalThis.events=[];globalThis.playOutcome='pending';for(const type of ['loadstart','emptied','abort','play','pause','playing','waiting','error'])m.addEventListener(type,e=>events.push({type:e.type,trusted:e.isTrusted}));m.defaultPlaybackRate=1.25;m.playbackRate=1.5;m.currentTime=5;`);
  const action='m.play().then(()=>playOutcome="played",e=>playOutcome=e.name);'+append;
  const immediate=await run(`(async()=>{${action};return ${read}})()`);await browser.evaluate('new Promise(r=>setTimeout(r,120))');boundaries.push({name,steps:[{name:'play and insert source',action,immediate,settled:await browser.evaluate(read)}]});
 }
 return {captured:new Date().toISOString(),timing,empty,boundaries};
}
async function capturePromises(browser){
 const out={captured:new Date().toISOString(),cases:[]},read=`({...${state},outcome:playOutcome,markers:markers.slice()})`;
 for(const [name,mode,action]of [
  ['already-playing Play load settlement','playing','m.play().then(()=>{playOutcome="played";markers.push("fulfilled")},e=>{playOutcome=e.name;markers.push("rejected")});m.load();queueMicrotask(()=>markers.push("marker"))'],
  ['queued playing completion load settlement','paused','m.addEventListener("playing",()=>queueMicrotask(()=>{m.load();queueMicrotask(()=>markers.push("marker"))}),{once:true});m.play().then(()=>{playOutcome="played";markers.push("fulfilled")},e=>{playOutcome=e.name;markers.push("rejected")})'],
  ['playing listener direct load settlement','paused','m.addEventListener("playing",()=>{markers.push("listener");m.load();queueMicrotask(()=>markers.push("marker"))},{once:true});m.play().then(()=>{playOutcome="played";markers.push("fulfilled")},e=>{playOutcome=e.name;markers.push("rejected")})'],
  ['queued pause rejection load settlement','empty','m.play().then(()=>{playOutcome="played";markers.push("fulfilled")},e=>{playOutcome=e.name;markers.push("rejected")});m.pause();m.load();queueMicrotask(()=>markers.push("marker"))'],
 ]){
  await browser.load(fixture);await browser.evaluate(`globalThis.m=new Audio();m.muted=true;globalThis.one=URL.createObjectURL(new Blob([Uint8Array.from(atob(${JSON.stringify(one.toString('base64'))}),c=>c.charCodeAt(0))],{type:'audio/wav'}));globalThis.two='unused';globalThis.events=[];globalThis.playOutcome='pending';globalThis.markers=[];for(const type of ['loadstart','emptied','abort','play','pause','playing','waiting','error'])m.addEventListener(type,e=>events.push({type:e.type,trusted:e.isTrusted}));${mode==='empty'?'':'m.src=one;'}`);
  if(mode!=='empty'){const v=await browser.send('Runtime.evaluate',{expression:'m.play()',userGesture:true,awaitPromise:true,returnByValue:true});if(v.exceptionDetails)throw Error(v.exceptionDetails.text);if(mode==='paused'){await browser.evaluate('m.pause();new Promise(r=>setTimeout(r,30))')}}
  const v=await browser.send('Runtime.evaluate',{expression:`(async()=>{events.length=0;${action};return ${read}})()`,userGesture:true,awaitPromise:true,returnByValue:true});if(v.exceptionDetails)throw Error(v.exceptionDetails.text);
  await browser.evaluate('new Promise(r=>setTimeout(r,120))');out.cases.push({name,mode,steps:[{name:'load preserves queued Play outcome',action,immediate:v.result.value,settled:await browser.evaluate(read)}]});
 }
 return out;
}
async function captureStarts(browser){
 const out={captured:new Date().toISOString(),cases:[]},read=`({...${state},outcome:playOutcome})`;
 for(const [name,mode,steps]of [
  ['empty load retains default start','empty',[['load empty media','m.load()']]],
  ['deferred direct src retains default start','direct',[['set direct source before metadata','m.src=one']]],
  ['deferred child insertion retains default start','child',[['insert source before metadata','m.append(Object.assign(document.createElement("source"),{src:one}))']]],
  ['empty-network load preserves pending play','pending',[['load source-less pending play','m.load()'],['insert source after empty-network load','m.append(Object.assign(document.createElement("source"),{src:one}))']]],
  ['late metadata clamps and consumes default start','metadata',[['select short resource after early seek','m.currentTime=25;m.preload="auto";m.src=one']]],
  ['negative early seek is consumed at metadata','metadata',[['select resource after negative early seek','m.currentTime=-5;m.preload="auto";m.src=one']]],
  ['zero early seek clears default start','empty',[['clear early seek before empty load','m.currentTime=0;m.load()']]],
 ]){
  await browser.load(fixture);await browser.evaluate(`globalThis.m=new Audio();m.muted=true;m.preload='none';globalThis.one=${mode==='empty'||mode==='direct'||mode==='child'?JSON.stringify('https://media.invalid/start/tone.ogg'):`URL.createObjectURL(new Blob([Uint8Array.from(atob(${JSON.stringify(one.toString('base64'))}),c=>c.charCodeAt(0))],{type:'audio/wav'}))`};globalThis.two='unused';globalThis.events=[];globalThis.playOutcome='pending';for(const type of ['loadstart','emptied','abort','play','pause','playing','waiting','error'])m.addEventListener(type,e=>events.push({type:e.type,trusted:e.isTrusted}));m.defaultPlaybackRate=1.25;m.playbackRate=1.5;m.currentTime=5;`);
  if(mode==='pending'){const v=await browser.send('Runtime.evaluate',{expression:'m.play().then(()=>playOutcome="played",e=>playOutcome=e.name);new Promise(r=>setTimeout(r,120))',userGesture:true,awaitPromise:true,returnByValue:true});if(v.exceptionDetails)throw Error(v.exceptionDetails.text)}
  const record={name,mode,before:await browser.evaluate(read),steps:[]};out.cases.push(record);
  if(mode==='pending'&&(record.before.paused||record.before.outcome!=='pending'||record.before.network!==0))throw Error('Source-less user-gesture play must remain pending at NETWORK_EMPTY');
  for(const [step,action]of steps){const v=await browser.send('Runtime.evaluate',{expression:`(async()=>{events.length=0;${action};return ${read}})()`,userGesture:true,awaitPromise:true,returnByValue:true});if(v.exceptionDetails)throw Error(v.exceptionDetails.text);await browser.evaluate('new Promise(r=>setTimeout(r,120))');record.steps.push({name:step,action,immediate:v.result.value,settled:await browser.evaluate(read)})}
 }
 return out;
}
(async()=>{fs.mkdirSync(folder,{recursive:true});const response=await fetch(pin.source);if(!response.ok)throw Error('Frozen HTML fetch '+response.status);const source=await response.text();if(crypto.createHash('sha256').update(source).digest('hex')!==pin.sha256)throw Error('Frozen HTML source mismatch');fs.writeFileSync(path.join(folder,'html-target-source'),source);const browser=await openBrowser(folder);const out={captured:new Date().toISOString(),target:pin,browser:await browser.send('Browser.getVersion'),media:{duration:20,sampleRate:8000,channels:1,format:'16-bit PCM WAV',sources:[one,two].map(b=>({bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')}))},note:'Isolated real audio playback with CDP user gesture. Raw states and trusted event names are retained; blob source labels are supplementary comparisons. No Roblox adapter or pixels. Preload remains an optional UA hint; time and media task timing are raw evidence, not exact engine clock expectations.',normative:{sourceAttributeMutation:[30925,30933],sourceInsertionAndMoving:[31028,31060],sourceRemoval:[31070,31082],srcSetNotRemoval:[38414,38417],load:[38665,38670],noModeRetainsCurrentSrc:[38850,38865],play:[40989,40995],pause:[41060,41070],stableRemoval:[41388,41400]},cases:[]};
 Object.assign(out.normative,{queuedPlaySettlements:[38687,38703],nonEmptyLoadReset:[38714,38799],defaultStartMetadataConsumption:[39661,39667],defaultStartCurrentTime:[40139,40159]});
 out.comparisonScope='The engine compares bounded selected-source/state fields, core playback events, forbidden reselection events, early cursor/rate preservation, and Promise outcomes/order. PCM wall-clock time, decoder readiness/task event timing, full media-task discard and every immediate network transition are raw evidence only. Same-task source insertion reports immediate NETWORK_LOADING in Chromium; the target compares its settled network and immediate pending promise/cursor/rate. Cross-live-realm removal checks only original handle pause suppression, not complete shared media-state transfer.';
 try{if(process.argv.includes('--selection-only')||process.argv.includes('--additive-only')){
 const selection=await captureSelection(browser),promises=await capturePromises(browser),starts=await captureStarts(browser);fs.writeFileSync(path.join(folder,'selection-native.json'),JSON.stringify({target:pin,browser:out.browser,selection,promises,starts},null,2)+'\n');
 const saved=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/audio-source-lifecycle-browser.json'),'utf8'));saved.selection=selection;saved.promises=promises;saved.starts=starts;
 Object.assign(saved.normative,out.normative);saved.comparisonScope=out.comparisonScope;
 if(!process.argv.includes('--build-only'))fs.writeFileSync(path.join(root,'tests/fixtures/audio-source-lifecycle-browser.json'),JSON.stringify(saved,null,2)+'\n');console.log('Additive selection/Promise/start capture: 22 transitions; existing lifecycle/hint snapshots retained');return;
 }for(const [name,mode,actions]of cases){await browser.load(fixture);await browser.evaluate(`globalThis.m=document.getElementById('m');globalThis.makeBlob=base64=>URL.createObjectURL(new Blob([Uint8Array.from(atob(base64),c=>c.charCodeAt(0))],{type:'audio/wav'}));globalThis.one=makeBlob(${JSON.stringify(one.toString('base64'))});globalThis.two=makeBlob(${JSON.stringify(two.toString('base64'))});${mode==='detached'?`m=new Audio(one);m.muted=true;m.preload='auto';`:''}globalThis.events=[];for(const type of ['loadstart','emptied','abort','play','pause','playing','waiting','loadedmetadata','loadeddata','canplay','canplaythrough','suspend','seeking','seeked','ratechange','ended','error'])m.addEventListener(type,e=>events.push({type:e.type,trusted:e.isTrusted,currentSrc:m.currentSrc,time:m.currentTime,network:m.networkState,paused:m.paused}));${mode==='direct'?`m.append(Object.assign(document.createElement('source'),{src:two}));m.src=one;`:mode==='child'?`m.append(Object.assign(document.createElement('source'),{src:one}));`:''}`);
 const run=async expression=>{const value=await browser.send('Runtime.evaluate',{expression,userGesture:true,awaitPromise:true,returnByValue:true});if(value.exceptionDetails)throw Error(value.exceptionDetails.exception?.description||value.exceptionDetails.text);return value.result.value};
 if(mode!=='empty')await run('m.play()');if(mode!=='empty')await browser.evaluate('m.currentTime=3;m.playbackRate=1.5;new Promise(r=>setTimeout(r,80))');
 const record={name,mode,initial:await browser.evaluate(state),steps:[]};out.cases.push(record);
 for(const [step,action]of actions){const immediate=await run(`(async()=>{events.length=0;${action};return ${state}})()`);await browser.evaluate('new Promise(r=>setTimeout(r,120))');const settled=await browser.evaluate(state);record.steps.push({name:step,action,immediate,settled});console.log(name+' / '+step+': '+JSON.stringify({immediate:{selected:immediate.selected,paused:immediate.paused,time:immediate.time,rate:immediate.rate,network:immediate.network},settled:{selected:settled.selected,paused:settled.paused,time:settled.time,rate:settled.rate,network:settled.network},events:settled.events.map(e=>e.type)}))}
 }
 out.selection=await captureSelection(browser);out.promises=await capturePromises(browser);out.starts=await captureStarts(browser);out.hints=await captureHints(browser);
 fs.writeFileSync(path.join(folder,'native.json'),JSON.stringify(out,null,2)+'\n');console.log(out.cases.length+' cases / '+out.cases.reduce((n,c)=>n+c.steps.length,0)+' transitions');
 if(!process.argv.includes('--build-only'))fs.writeFileSync(path.join(root,'tests/fixtures/audio-source-lifecycle-browser.json'),JSON.stringify(out,null,2)+'\n');
 }finally{await browser.close()}})().catch(error=>{console.error(error);process.exitCode=1});
