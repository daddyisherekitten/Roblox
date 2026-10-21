// Isolated Chromium checks of the local game archive. Never uses user tabs.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),cp=require('node:child_process'),net=require('node:net');
const {openBrowser}=require('./native-browser.cjs');
const workspace=path.resolve(__dirname,'..'),args={};
for(let index=2;index<process.argv.length;index+=2){assert.ok(process.argv[index].startsWith('--')&&process.argv[index+1],'Expected --option value');args[process.argv[index].slice(2)]=process.argv[index+1];}
const fullCatalog=path.join(workspace,'scripts/data/wttg2-full-catalog.json');
const catalogPath=path.resolve(args.catalog||(fs.existsSync(fullCatalog)?fullCatalog:path.join(workspace,'scripts/data/wttg2-catalog.json')));
const out=path.resolve(args.output||path.join(workspace,'build/wttg2-full-20261019/browser'));
const port=Number(args.port||(args.root?8001:8000));assert.ok(Number.isInteger(port)&&port>0&&port<65536);
const origin='http://localhost:'+port,pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));

async function temporaryServer(){
 if(!args.root)return null;
 const directory=path.resolve(args.root);assert.ok(fs.statSync(directory).isDirectory());
 const available=await new Promise(resolve=>{const check=net.createServer();check.once('error',()=>resolve(false));check.listen(port,'127.0.0.1',()=>check.close(()=>resolve(true)));});
 assert.ok(available,'Temporary test port is already in use; existing servers are never stopped');
 const child=cp.spawn(args.python||'C:/Python310/python.exe',['-m','http.server',String(port),'--bind','127.0.0.1','--directory',directory],{windowsHide:true,stdio:'ignore'});
 let failure;child.once('error',error=>{failure=error;});
 for(let attempt=0;attempt<100;attempt++){
  if(failure)throw failure;
  if(child.exitCode!==null)throw Error('Temporary test server exited');
  try{if((await fetch(origin+'/')).status<500)return child;}catch{}
  await pause(30);
 }
 child.kill();throw Error('Temporary test server did not become ready');
}

// A second connection to OUR headless page handles every request before it is
// sent. Only this loopback origin may use the network, including redirects.
async function isolateNetwork(beforeProfiles){
 const profiles=fs.readdirSync(out).filter(name=>name.startsWith('chrome-')&&!beforeProfiles.has(name));assert.equal(profiles.length,1);
 const debugPort=fs.readFileSync(path.join(out,profiles[0],'DevToolsActivePort'),'utf8').trim().split('\n')[0];
 const targets=await(await fetch('http://localhost:'+debugPort+'/json/list')).json();const target=targets.find(item=>item.type==='page');assert.ok(target);
 const socket=new WebSocket(target.webSocketDebuggerUrl),pending=new Map();let sequence=0;
 const evidence={requests:[],responses:[],blocked:[],failures:[]};
 await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
 function send(method,params={}){return new Promise((resolve,reject)=>{const id=++sequence;pending.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params}));});}
 socket.addEventListener('message',event=>{
  const item=JSON.parse(event.data);
  if(item.id){const response=pending.get(item.id);if(response){pending.delete(item.id);item.error?response.reject(Error(item.error.message)):response.resolve(item.result);}return;}
  if(item.method==='Network.responseReceived')evidence.responses.push({url:item.params.response.url,status:item.params.response.status,type:item.params.type});
  if(item.method!=='Fetch.requestPaused')return;
  const request=item.params;let local=false;
  try{const url=new URL(request.request.url);local=url.origin===origin||url.protocol==='data:'||url.protocol==='blob:';}catch{}
  const record={url:request.request.url,type:request.resourceType};evidence.requests.push(record);if(!local)evidence.blocked.push(record);
  send(local?'Fetch.continueRequest':'Fetch.failRequest',local?{requestId:request.requestId}:{requestId:request.requestId,errorReason:'BlockedByClient'}).catch(error=>evidence.failures.push(error.message));
 });
 await send('Network.enable');await send('Fetch.enable',{patterns:[{urlPattern:'*',requestStage:'Request'}]});
 return {evidence,reset(){for(const value of Object.values(evidence))value.length=0;},async close(){if(socket.readyState===WebSocket.OPEN){await send('Fetch.disable');socket.close();}}};
}

async function run(){
 const manifest=JSON.parse(fs.readFileSync(catalogPath,'utf8')),modules=manifest.Modules,sites=manifest.siteConfiguration||[];assert.ok(modules?.length);
 const realSites=sites.filter(site=>!site.dead&&!/^Wiki[123]$/.test(site.name||''));
 const wikis=manifest.wikis||[{index:1,path:'/wiki1/index.html',siteNames:sites.map(site=>site.name||site.host)}];
 const missing=manifest.MissingReferences||[],excluded=manifest.ExcludedReferences||[],external=manifest.ExternalReferences||[];
 if(realSites.length===60){assert.equal(modules.length,175);assert.equal(wikis.length,3);}
 fs.mkdirSync(out,{recursive:true});const server=await temporaryServer();let browser,network;
 const results=[],wikiRosters=[],navigations=[];
 try{
  const before=new Set(fs.readdirSync(out));browser=await openBrowser(out);network=await isolateNetwork(before);
  await browser.send('Emulation.setDeviceMetricsOverride',{width:1100,height:760,deviceScaleFactor:1,mobile:false});
  await browser.send('Page.addScriptToEvaluateOnNewDocument',{source:"window.__portErrors=[];addEventListener('error',function(e){__portErrors.push({kind:e.target===window?'script':'resource',message:e.message||'',url:e.target.src||e.target.href||'',tag:e.target.tagName||''});},true);"});
  function knownProblem(resource,module){
   let url;try{url=new URL(resource,origin+module.sourcePath);}catch{return null;}
   const dependencies=new Set([module.sourcePath,...(module.dependencies?.styles||[]),...(module.dependencies?.scripts||[])]);
   const record=[...missing,...excluded].find(item=>dependencies.has(item.sourcePath)&&item.resolvedPath?.toLowerCase()===url.pathname.toLowerCase());
   if(record)return {kind:missing.includes(record)?'original-missing':'withheld-dependency',...record};
   const remote=external.find(item=>dependencies.has(item.sourcePath)&&new URL(item.url,origin+item.sourcePath).href===url.href);
   return remote?{kind:'original-external-blocked',...remote}:null;
  }
  async function load(sourcePath){
   const url=origin+sourcePath;network.reset();await browser.send('Page.navigate',{url});let state;
   for(let attempt=0;attempt<400;attempt++){
    state=await browser.evaluate("({ready:document.readyState,href:location.href,images:Array.from(document.images).map(x=>({src:x.currentSrc||x.src,loaded:x.complete&&x.naturalWidth>0,complete:x.complete})),errors:window.__portErrors||[]})");
    if(state.href===url&&state.ready==='complete'&&state.images.every(image=>image.complete))break;
    await pause(30);
   }
   if(state.href!==url||state.ready!=='complete')fs.writeFileSync(path.join(out,'load-failure.json'),JSON.stringify({sourcePath,state,network:network.evidence},null,2)+'\n');
   assert.equal(state.href,url,sourcePath+' retains its document URL');assert.equal(state.ready,'complete',sourcePath+' load completes');
   await pause(50);state.errors=await browser.evaluate('window.__portErrors||[]');return state;
  }
  for(const module of modules){
   const sourcePath=module.sourcePath||new URL(module.url).pathname;module.sourcePath=sourcePath;
   const state=await load(sourcePath),known=[];
   for(const error of state.errors){assert.equal(error.kind,'resource',module.name+' runtime exception: '+error.message);const problem=knownProblem(error.url,module);assert.ok(problem,module.name+' unexpected resource error: '+error.url);known.push(problem);}
   for(const image of state.images.filter(image=>!image.loaded)){const problem=knownProblem(image.src,module);assert.ok(problem,module.name+' unexpected missing image: '+image.src);known.push(problem);}
   for(const response of network.evidence.responses.filter(item=>item.status>=400)){
    if(new URL(response.url).pathname==='/favicon.ico'&&response.type==='Other')continue;
    const problem=knownProblem(response.url,module);assert.ok(problem,module.name+' unexpected HTTP '+response.status+': '+response.url);known.push(problem);
   }
   for(const request of network.evidence.blocked){const problem=knownProblem(request.url,module);assert.ok(problem,module.name+' unexpected external request was blocked: '+request.url);known.push(problem);}
   assert.deepEqual(network.evidence.failures,[]);
   const info=await browser.evaluate("({title:document.title,links:document.querySelectorAll('#wikiLinks li').length,bodyHeight:document.body?document.body.scrollHeight:0,globals:['LinkClick','SiteClick','LinkHover','LinkOut'].every(x=>typeof window[x]==='function')})");assert.ok(info.globals,module.name+' host hooks connected');
   const wiki=wikis.find(item=>item.path===sourcePath);
   if(wiki){
    const anchors=await browser.evaluate("Array.from(document.querySelectorAll('#wikiLinks a')).map(x=>({title:x.textContent,click:x.getAttribute('onclick')}))");
    const expected=wiki.siteNames?.length||sites.length;assert.equal(info.links,expected,module.name+' complete roster');assert.equal(anchors.length,expected);
    if(realSites.length===60){
     const observedNames=anchors.map(anchor=>{const host=(anchor.click||'').match(/https?:\/\/([^"'\/\s)]+)/)?.[1];return sites.find(site=>site.host===host)?.name;});
     assert.ok(observedNames.every(Boolean),module.name+' rendered links resolve to named catalog sites');
     assert.deepEqual([...observedNames].sort(),[...wiki.siteNames].sort(),module.name+' rendered destinations match its complete roster');
     const actual=observedNames.filter(name=>!/^Wiki[123]$/.test(name)&&!sites.find(site=>site.name===name)?.dead);assert.equal(expected,32);assert.equal(actual.length,20);wikiRosters.push(actual);
    }
    const shot=await browser.send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(out,'wiki'+wiki.index+'-browser.png'),Buffer.from(shot.data,'base64'));
   }else if(sourcePath==='/fortuneCookie/index.html'){
    const shot=await browser.send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(out,'fortune-cookie-browser.png'),Buffer.from(shot.data,'base64'));
   }
   results.push({name:module.name,url:origin+sourcePath,status:module.status||'original',...info,imageCount:state.images.length,loadedImages:state.images.filter(image=>image.loaded).length,knownOriginalResourceProblems:[...new Map(known.map(item=>[JSON.stringify(item),item])).values()],blockedExternalRequests:network.evidence.blocked.length,localRequestCount:network.evidence.requests.length-network.evidence.blocked.length,runtimeErrors:[]});
   if(results.length%25===0)console.log('Native browser checked '+results.length+'/'+modules.length+' documents');
  }
  if(realSites.length===60)assert.equal(new Set(wikiRosters.flat()).size,60,'Three disjoint rosters cover every real site');
  async function nativeWikiClick(from,to,alias){
   await load(from);
   const point=await browser.evaluate(`(()=>{const element=Array.from(document.querySelectorAll('#wikiLinks a')).find(x=>(x.getAttribute('onclick')||'').includes(${JSON.stringify(alias)}));if(!element)return null;element.scrollIntoView({block:'center'});const r=element.getBoundingClientRect();return{x:r.left+r.width/2,y:r.top+r.height/2};})()`);
   assert.ok(point,'Native link to '+alias+' exists');
   await browser.send('Input.dispatchMouseEvent',{type:'mouseMoved',...point});
   await browser.send('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,clickCount:1,...point});
   await browser.send('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,clickCount:1,...point});
   for(let attempt=0;attempt<100;attempt++){if(await browser.evaluate('location.pathname')===to)break;await pause(30);}
   assert.equal(await browser.evaluate('location.pathname'),to,'Actual mouse click reaches '+to);navigations.push({from,to,alias,nativeMouse:true});
  }
  if(wikis.length===3){await nativeWikiClick('/wiki1/index.html','/wiki2/index.html','wiki2');await nativeWikiClick('/wiki2/index.html','/wiki3/index.html','wiki3');await nativeWikiClick('/wiki3/index.html','/wiki1/index.html','wiki1');}
  const ordinary=sites.find(site=>site.name==='FortuneCookie')||realSites[0];assert.ok(ordinary);
  const owner=wikis.find(wiki=>wiki.siteNames?.includes(ordinary.name))||wikis[0];await nativeWikiClick(owner.path,ordinary.path,ordinary.host.replace(/\.ann$/,''));
  const dead=sites.find(site=>site.dead);assert.ok(dead);
  const deadPath=dead.path||'/unavailable/index.html';
  if(realSites.length===60)assert.equal(deadPath,'/NotFound/index.html','Full archive uses its original unavailable-page document');
  const deadOwner=wikis.find(wiki=>wiki.siteNames?.includes(dead.name))||wikis[0];
  await nativeWikiClick(deadOwner.path,deadPath,dead.host.replace(/\.ann$/,''));
  const deadStatus=(await fetch(origin+deadPath)).status,expectedDeadStatus=modules.some(module=>module.sourcePath===deadPath)?200:404;
  assert.equal(deadStatus,expectedDeadStatus,'Unavailable destination matches the explicit catalog');
  if(expectedDeadStatus===200)assert.equal(await browser.evaluate('location.pathname'),deadPath,'Dead-link navigation reaches the local original unavailable document');
  const proof={date:'2026-10-19',host:'isolated headless Chromium',catalogPath,origin,pages:results,realSites:realSites.length,documents:modules.length,wikis:wikis.map(wiki=>({path:wiki.path,entries:wiki.siteNames?.length||sites.length})),uniqueRealWikiSites:new Set(wikiRosters.flat()).size,nativeNavigations:navigations,deadLinkHTTPStatus:deadStatus,externalNetworkRequestsAllowed:0,missingReferenceInventory:missing,excludedReferenceInventory:excluded,externalReferenceInventory:external,screenshotScope:[...wikis.map(wiki=>wiki.path),'/fortuneCookie/index.html']};
  fs.writeFileSync(path.join(out,'browser-acceptance.json'),JSON.stringify(proof,null,2)+'\n');console.log(modules.length+' local documents passed: resources, scripts, wiki rosters and native navigation; external network denied.');
 }finally{if(network)await network.close().catch(()=>{});if(browser)await browser.close();if(server&&server.exitCode===null)server.kill();}
}
run().catch(error=>{console.error(error);process.exitCode=1;});
