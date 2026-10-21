// Independent ordinary Chrome reference. Uses only an isolated browser/profile.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/window-close-reference');
const frozenPath=path.join(root,'build/media-reflection-reference/html-target-source');
const frozen=fs.readFileSync(frozenPath),source=frozen.toString('utf8');
const pin=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/media-reflection-browser.json'),'utf8')).target;
if(crypto.createHash('sha256').update(frozen).digest('hex')!==pin.sha256)throw Error('Frozen HTML source changed');
const wait=(ms=100)=>new Promise(resolve=>setTimeout(resolve,ms));
let serial=0;
const server=http.createServer((req,res)=>{
 res.writeHead(200,{'Content-Type':'text/html','Cache-Control':'no-store'});
 if(req.url.startsWith('/child'))res.end(`<!doctype html><style>body{margin:0}button{width:220px;height:70px}</style><button id=activate>Activate</button><script>
 var protectPage=false;function note(phase){opener.trace.push({phase,childClosed:closed,openerClosed:opener.child.closed,ownDocumentAvailable:!!document.body,openerDocumentAvailable:!!opener.child.document.body});}
 activate.onclick=()=>{window.activated=true};
 addEventListener('beforeunload',e=>{note('beforeunload');if(protectPage){e.preventDefault();e.returnValue='edited';}});
 addEventListener('unload',()=>note('unload'));
 function selfClose(){close();note('self sync');queueMicrotask(()=>note('self microtask'));setTimeout(()=>note('self task'),0);}
 </script>`);
 else res.end(`<!doctype html><style>body{margin:0}button{width:220px;height:70px}</style><button id=open>Open</button><script>
 var trace=[];document.getElementById('open').onclick=()=>{window.child=window.open('/child?case='+new URL(location).searchParams.get('case'),'close-reference-'+new URL(location).searchParams.get('case'),'popup,width=400,height=300');};
 function note(phase){const value={phase,closed:child.closed};try{value.documentAvailable=!!child.document.body;value.name=child.name;value.href=child.location.href;}catch(e){value.accessError=e.name;}trace.push(value);}
 </script>`);
});
(async()=>{
 fs.mkdirSync(folder,{recursive:true});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const base='http://127.0.0.1:'+server.address().port;const browser=await openBrowser(folder);let child;
 const result={captured:new Date().toISOString(),target:pin,currentSpecification:{url:'https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-window-close',checked:'2026-10-16',observedLastUpdated:'2026-10-14'},browser:await browser.send('Browser.getVersion'),profile:'Ordinary isolated Chrome; actual HTTP popup and CDP trusted mouse dispatch. Raw values retained. CDP Target.closeTarget is a forced harness disposal, not a browser close-button semantic claim.',cases:[]};
 const evaluate=async(expression,session)=>{
  const value=await browser.send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:false},session);
  if(value.exceptionDetails)throw Error(value.exceptionDetails.exception?.description||value.exceptionDetails.text);
  return value.result.value;
 };
 const click=async(session)=>{for(const type of['mousePressed','mouseReleased'])await browser.send('Input.dispatchMouseEvent',{type,x:30,y:30,button:'left',clickCount:1},session);};
 const setup=async()=>{
  const id=++serial;await browser.send('Page.navigate',{url:base+'/main?case='+id});await wait();await click();await wait();
  const targets=(await browser.send('Target.getTargets')).targetInfos;const target=targets.find(value=>value.url===base+'/child?case='+id);if(!target)throw Error('Actual trusted popup did not open');
  child={id:target.targetId,session:(await browser.send('Target.attachToTarget',{targetId:target.targetId,flatten:true})).sessionId};
  await browser.send('Runtime.enable',{},child.session);await browser.send('Page.enable',{},child.session);await click(child.session);await evaluate('trace=[]');return child;
 };
 const trace=()=>evaluate('trace');
 const physicallyOpen=async()=>Boolean((await browser.send('Target.getTargets')).targetInfos.find(value=>value.targetId===child.id));
 const closeForce=async()=>{if(child&&await physicallyOpen())await browser.send('Target.closeTarget',{targetId:child.id});await wait();};
 try{
  for(const self of[false,true]){
   await setup();const row={name:self?'self unguarded':'opener unguarded'};
   if(self)row.returned=await evaluate('selfClose();undefined',child.session);
   else row.returned=await evaluate("child.close();note('opener sync');child.close();note('opener repeat');queueMicrotask(()=>note('opener microtask'));setTimeout(()=>note('opener task'),0);undefined");
   await wait();row.trace=await trace();row.physicallyOpen=await physicallyOpen();row.closed=await evaluate('child.closed');result.cases.push(row);console.log(row.name,JSON.stringify(row));await closeForce();
  }
  for(const accept of[false,true]){
   await setup();await evaluate('protectPage=true',child.session);const row={name:accept?'beforeunload accept':'beforeunload cancel then retry'};
   const calling=evaluate("child.close();note('guard sync');queueMicrotask(()=>note('guard microtask'));setTimeout(()=>note('guard task'),0);undefined");await wait();
   try{await browser.send('Page.handleJavaScriptDialog',{accept},child.session);row.dialogHandled=true;}catch(error){row.dialogHandled=false;row.dialogError=error.message;}
   row.returned=await calling;await wait();row.trace=await trace();row.closedAfterAnswer=await evaluate('child.closed');row.physicallyOpenAfterAnswer=await physicallyOpen();
   if(!accept&&row.physicallyOpenAfterAnswer){
    await evaluate('protectPage=false',child.session);await evaluate("note('after cancel');child.close();note('retry sync');queueMicrotask(()=>note('retry microtask'));setTimeout(()=>note('retry task'),0);undefined");await wait();row.retryTrace=await trace();row.closedAfterRetry=await evaluate('child.closed');row.physicallyOpenAfterRetry=await physicallyOpen();
   }
   result.cases.push(row);console.log(row.name,JSON.stringify(row));await closeForce();
  }
  await setup();await evaluate('protectPage=true',child.session);const row={name:'forced disposal during beforeunload'};
  const forcing=evaluate("child.close();note('forced sync');queueMicrotask(()=>note('forced microtask'));undefined");await wait();
  row.targetClose=await browser.send('Target.closeTarget',{targetId:child.id});try{await forcing;row.callReturned=true;}catch(error){row.callReturned=false;row.callError=error.message;}await wait();row.trace=await trace();row.closed=await evaluate('child.closed');row.physicallyOpen=await physicallyOpen();result.cases.push(row);console.log(row.name,JSON.stringify(row));
  const excerpts={close:source.slice(source.indexOf('  <p>The <dfn method for="Window"><code data-x="dom-window-close">'),source.indexOf('  <p>The <dfn method for="Window"><code data-x="dom-window-stop">')),
   definite:source.slice(source.indexOf('  <p>To <dfn data-x="definitely close a top-level traversable">'),source.indexOf('  <h5><span id="browsing-context-names">'))};
  fs.writeFileSync(path.join(folder,'pinned-algorithms.json'),JSON.stringify({target:pin,excerpts},null,2)+'\n');
  fs.writeFileSync(path.join(root,'tests/fixtures/window-close-browser.json'),JSON.stringify(result,null,2)+'\n');fs.writeFileSync(path.join(folder,'native.json'),JSON.stringify(result,null,2)+'\n');
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;server.close();});
