// Independent XHR VM/transport and real Chromium references; no shared bundle mutation.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build','javascript-xml-http-request');
fs.mkdirSync(out,{recursive:true});
function bundle(){
 const sources=new Map();
 function resolve(base){for(const file of [base+'.luau',path.join(base,'init.luau')])if(fs.existsSync(file))return file;throw Error(base);}
 function add(file){file=path.resolve(file);if(sources.has(file))return sources.get(file).id;const entry={id:sources.size+1,source:''};sources.set(file,entry);
  entry.source=fs.readFileSync(file,'utf8').replace(/require\(script((?:\.[\w]+)+)\)/g,(_,chain)=>{let base=file.endsWith(path.sep+'init.luau')?path.dirname(file):file.slice(0,-5);for(const part of chain.slice(1).split('.'))base=part==='Parent'?path.dirname(base):path.join(base,part);return `loadModule(${add(resolve(base))})`;});return entry.id;}
 const names=['JavaScript/VM','JavaScript/Promises','JavaScript/AsyncFunctions','JavaScript/EventLoop','JavaScript/HostEvents','JavaScript/NetworkData','HTML/Parser','JavaScript/DOM','JavaScript/CustomElements'];
 const ids=names.map(name=>add(resolve(path.join(root,'src/HTMLEngine',name))));
 let source=`local Vector2={new=function(x,y)return {X=x,Y=y}end}\nlocal Color3={new=function(r,g,b)return {R=r,G=g,B=b}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}\nlocal Enum={Font={Arial='Arial',SourceSans='SourceSans',Ubuntu='Ubuntu'}}\nlocal factories,loaded={},{}\nlocal function loadModule(id)if loaded[id]==nil then loaded[id]=factories[id]()end;return loaded[id]end\n`;
 for(const entry of sources.values())source+=`factories[${entry.id}]=function()\n${entry.source}\nend\n`;
 source+=`local run=(function()\n${fs.readFileSync(path.join(root,'tests/JavaScriptXMLHttpRequest.luau'),'utf8')}\nend)()\nrun(${ids.map(id=>`loadModule(${id})`).join(',')})\n`;
 const file=path.join(out,'tests-'+process.pid+'.luau');fs.writeFileSync(file,source);return file;
}
async function native(){
 const {openBrowser}=require('./native-browser.cjs');const server=require('node:http').createServer((req,res)=>{
  if(req.url==='/error'){req.socket.destroy();return;}if(req.url==='/slow')return;
  if(req.url==='/params'){let body='';req.on('data',part=>body+=part);req.on('end',()=>res.end(body));return;}
  if(req.url==='/text'){res.writeHead(201,'Created',{'content-type':'text/plain;charset=UTF-8','content-length':'5','x-a':'first','x-z':'last','set-cookie':'hidden'});res.end('hello');return;}
  res.setHeader('content-type','text/html');res.end('<!doctype html><body>XHR native reference</body>');
 });await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));let browser;
 try{browser=await openBrowser(out);const base='http://127.0.0.1:'+server.address().port;await browser.send('Page.navigate',{url:base+'/'});await browser.evaluate('new Promise(r=>document.readyState==="complete"?r():window.addEventListener("load",r,{once:true}))');
  const results=await browser.evaluate(`(async()=>{
   const text=await new Promise(resolve=>{const x=new XMLHttpRequest(),states=[],events=[];x.onreadystatechange=()=>states.push(x.readyState+':'+x.responseText);for(const name of ['loadstart','progress','load','loadend'])x.addEventListener(name,e=>events.push(name+':'+x.readyState+':'+e.loaded+':'+e.total+':'+e.lengthComputable+':'+(e instanceof ProgressEvent)+':'+e.isTrusted));x.onloadend=()=>resolve({states:states.join('|'),events:events.join('|'),status:x.status,body:x.response,setCookie:x.getResponseHeader('set-cookie')});x.open('GET','/text');x.send();});
   const abort=(()=>{const x=new XMLHttpRequest(),trace=[];x.onreadystatechange=()=>trace.push('s'+x.readyState);x.onabort=()=>trace.push('abort'+x.readyState);x.onloadend=()=>trace.push('end'+x.readyState);x.open('GET','/slow');x.send();x.abort();trace.push('after'+x.readyState);return trace.join('|');})();
   const error=await new Promise(resolve=>{const x=new XMLHttpRequest(),trace=[];x.onerror=()=>trace.push('error'+x.readyState+':'+x.status);x.onloadend=()=>{trace.push('end');resolve(trace.join('|'));};x.open('GET','/error');x.send();});
   const timeout=await new Promise(resolve=>{const x=new XMLHttpRequest(),trace=[];x.timeout=15;x.ontimeout=()=>trace.push('timeout'+x.readyState);x.onloadend=()=>{trace.push('end');resolve(trace.join('|'));};x.open('GET','/slow');x.send();});
   const worker=await new Promise(resolve=>{const url=URL.createObjectURL(new Blob(["const x=new XMLHttpRequest();x.responseType='document';postMessage({type:x.responseType,xml:typeof x.responseXML});"],{type:'text/javascript'}));const w=new Worker(url);w.onmessage=e=>{resolve(e.data);w.terminate();URL.revokeObjectURL(url);};});
   const reopen={};for(const kind of ['load','abort','error','timeout'])reopen[kind]=await new Promise(resolve=>{const x=new XMLHttpRequest(),trace=[];x['on'+kind]=()=>{trace.push(kind+x.readyState);x.open('GET','/next');};x.onloadend=e=>{trace.push('end'+x.readyState+':'+e.loaded+':'+e.total);resolve(trace.join('|'));};x.open('GET',kind==='load'?'/text':kind==='error'?'/error':'/slow');if(kind==='timeout')x.timeout=15;x.send();if(kind==='abort')x.abort();});
   const params=await new Promise(resolve=>{let conversions=0;const p=new URLSearchParams('a=b');p.toString=()=>{conversions++;return 'overridden';};const x=new XMLHttpRequest();x.onloadend=()=>resolve({conversions,body:x.responseText});x.open('POST','/params');x.send(p);});
   return {text,abort,error,timeout,worker,reopen,params};
  })()`);
  fs.writeFileSync(path.join(out,'native-results.json'),JSON.stringify(results,null,2)+'\n');
  assert.equal(results.text.states,'1:|2:|3:hello|4:hello');assert.equal(results.text.events,'loadstart:1:0:0:false:true:true|progress:3:5:5:true:true:true|load:4:5:5:true:true:true|loadend:4:5:5:true:true:true');assert.equal(results.text.status,201);assert.equal(results.text.body,'hello');assert.equal(results.text.setCookie,null);
  assert.equal(results.abort,'s1|s4|abort4|end4|after0');assert.equal(results.error,'error4:0|end');assert.equal(results.timeout,'timeout4|end');assert.deepEqual(results.worker,{type:'',xml:'undefined'});
  // Preserve raw Chromium output. The engine separately retains 5/5 according
  // to WHATWG handle-response-end-of-body steps 3/4/10/11 after onload reopens.
  assert.deepEqual(results.reopen,{load:'load4|end1:0:0',abort:'abort4|end1:0:0',error:'error4|end1:0:0',timeout:'timeout4|end1:0:0'});assert.deepEqual(results.params,{conversions:0,body:'a=b'});
  fs.writeFileSync(path.join(out,'normative-differences.json'),JSON.stringify([{case:'onload reopens before loadend',source:'https://xhr.spec.whatwg.org/#handle-response-end-of-body',steps:[3,4,10,11],native:results.reopen.load,engine:'load4|end1:5:5',reason:'Standard captures transmitted/length before dispatch; Chromium resets counts after open. Raw browser output is retained, not rewritten to normative expectation.'}],null,2)+'\n');
  console.log('Native Chrome XHR reference: HTTP state/progress, abort/error/timeout, terminal reopen, URLSearchParams and worker exposure passed; 1 explicit normative/raw-browser count delta retained.');
 }finally{if(browser)await browser.close();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
}
(async()=>{const args=new Set(process.argv.slice(2));if(!args.has('--luau-only'))await native();if(!args.has('--native-only')){
 const file=bundle();const result=cp.spawnSync(process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe'),['-O2',file],{encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:8*1024*1024});fs.writeFileSync(path.join(out,'luau.log'),(result.stdout||'')+(result.stderr||''));process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
}})().catch(error=>{console.error(error);process.exitCode=1});
