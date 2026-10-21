// Real delayed HTTP stylesheet responses in an isolated browser.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),file=path.join(root,'tests/fixtures/stylesheet-loading-browser.json');
const script=source=>'<script>'+source+'</script>';
const setup=script("document.addEventListener('DOMContentLoaded',()=>console.log('dcl',document.readyState));window.addEventListener('load',()=>console.log('load',document.readyState));document.addEventListener('load',e=>{if(e.target.localName==='link'){console.log((e.target.id==='sheet'?'sheet':e.target.id)+' load',e.target.sheet!==null)}},true);document.addEventListener('error',e=>{if(e.target.localName==='link')console.log('sheet error',e.target.sheet===null)},true);");
const link=(url,attrs='')=>'<link id=sheet rel=stylesheet href="'+url+'" crossorigin=anonymous '+attrs+'>';
const resources={
 '/slow.css':{Source:'#probe { color: rgb(12, 34, 56); }',MIME:'text/css',Delay:60},
 '/fast.css':{Source:'#probe { color: rgb(78, 90, 12); }',MIME:'text/css',Delay:10},
 '/wrong.css':{Source:'not CSS',MIME:'text/plain',Delay:20},
 '/missing.css':{Source:'missing',MIME:'text/css',Delay:20,Status:404},
 '/async.js':{Source:"console.log('async',document.getElementById('future')!==null,document.getElementById('sheet').sheet===null);",MIME:'text/javascript',Delay:10},
 '/defer.js':{Source:"console.log('defer',document.getElementById('sheet').sheet!==null,document.getElementById('future')!==null);",MIME:'text/javascript',Delay:10},
 '/import.css':{Source:'@import "slow.css"; #root {color:red}',MIME:'text/css',Delay:10},
 '/nested.css':{Source:'@import "import.css"; #outer {color:blue}',MIME:'text/css',Delay:10},
 '/failed-import.css':{Source:'@import "missing.css"; #root {color:red}',MIME:'text/css',Delay:10},
 '/conditional-import.css':{Source:'@import "slow.css" supports(unknown-property: no); #root {color:red}',MIME:'text/css',Delay:10},
 '/print-import.css':{Source:'@import "slow.css" print; #root {color:red}',MIME:'text/css',Delay:10},
 '/cycle-a.css':{Source:'@import "cycle-b.css"; #a {color:red}',MIME:'text/css',Delay:10},
 '/cycle-b.css':{Source:'@import "cycle-a.css"; #b {color:blue}',MIME:'text/css',Delay:10},
 '/duplicate-import.css':{Source:'@import "slow.css"; @import "slow.css";',MIME:'text/css',Delay:10},
 '/redirect.css':{Source:'@import "child.css";',URL:'https://styles.test/folder/root.css',Redirect:'/folder/root.css',MIME:'text/css',Delay:10},
 '/folder/root.css':{Source:'@import "child.css";',MIME:'text/css',Delay:10},
 '/folder/child.css':{Source:'#probe{color:red}',MIME:'text/css',Delay:10},
 '/inspect-import.js':{Source:"globalThis.pendingOwner=document.getElementById('sheet').sheet;globalThis.pendingRule=pendingOwner?.cssRules[0];console.log('pending import owner',pendingOwner!==null,pendingRule?.styleSheet===null);",MIME:'text/javascript',Delay:20},
 '/delete-import.js':{Source:"const s=document.getElementById('sheet').sheet;globalThis.removedRule=s.cssRules[0];s.deleteRule(0);console.log('delete import',s.cssRules.length,removedRule.parentStyleSheet===null,removedRule.styleSheet===null);",MIME:'text/javascript',Delay:20},
};
const cases=[
 ['inline parser script waits for CSS',link('/slow.css')+script("console.log('inline',document.getElementById('sheet').sheet!==null,document.styleSheets.length,document.getElementById('future')===null);")+"</head><body><p id=future>Later</p>"],
 ['external parser script waits for CSS',link('/slow.css')+'<script src="/defer.js"></script></head><body><p id=future>Later</p>'],
 ['deferred script waits for CSS',link('/slow.css')+'<script defer src="/defer.js"></script></head><body><p id=future>Later</p>'],
 ['module script waits for CSS',link('/slow.css')+'<script type=module>console.log("module",document.getElementById("sheet").sheet!==null,document.getElementById("future")!==null);</script></head><body><p id=future>Later</p>'],
 ['async script passes CSS barrier',link('/slow.css')+'<script async src="/async.js"></script></head><body><p id=future>Later</p>'],
 ['nonmatching media does not block parser',link('/slow.css','media=print')+script("console.log('print',document.getElementById('sheet').sheet===null);")+'</head><body>'],
 ['initial disabled stylesheet does not block',link('/slow.css','disabled')+script("console.log('disabled',document.getElementById('sheet').sheet===null);")+'</head><body>'],
 ['CSS HTTP error releases parser',link('/missing.css')+script("console.log('after error',document.getElementById('sheet').sheet===null);")+'</head><body>'],
 ['CSS MIME error releases parser',link('/wrong.css')+script("console.log('after MIME',document.getElementById('sheet').sheet===null);")+'</head><body>'],
 ['CSS completion before parser and microtask',link('/slow.css')+script("console.log('after sheet task');")+'</head><body>',script("document.addEventListener('load',e=>{if(e.target.localName==='link')Promise.resolve().then(()=>console.log('sheet microtask'))},true);")],
 ['two CSS barriers complete out of order',link('/slow.css').replace('id=sheet','id=slow').replace('sheet load','slow load')+link('/fast.css').replace('id=sheet','id=fast').replace('sheet load','fast load')+script("console.log('both',document.styleSheets.length);")+'</head><body>'],
 ['dynamic stylesheet delays load without blocking parser',script("const s=document.createElement('link');s.id='sheet';s.rel='stylesheet';s.href='/slow.css';s.crossOrigin='anonymous';document.head.append(s);")+script("console.log('dynamic next',document.getElementById('sheet').sheet===null);")+'</head><body>'],
 ['remove pending sheet releases parser',link('/slow.css')+script("console.log('after removed',document.getElementById('sheet')===null);")+'</head><body>',script("setTimeout(()=>document.getElementById('sheet')?.remove(),10);")],
 ['replace pending stylesheet URL',link('/slow.css')+script("console.log('replaced',document.getElementById('sheet').sheet!==null);")+'</head><body>',script("setTimeout(()=>document.getElementById('sheet').href='/fast.css',10);")],
 ['cross-origin CSS rules are protected',link('@CROSS@/slow.css').replace(' crossorigin=anonymous','')+script("const s=document.getElementById('sheet').sheet;for(const method of ['cssRules','insertRule','deleteRule']){try{if(method==='cssRules')s.cssRules;else if(method==='insertRule')s.insertRule('p{color:red}');else s.deleteRule(0);console.log(method,'incorrect')}catch(e){console.log(method,e.name)}}")+'</head><body>'],
 ['CORS-clean CSS rules are accessible',link('@CROSS@/slow.css')+script("console.log('clean rules',document.getElementById('sheet').sheet.cssRules.length);")+'</head><body>'],
 ['shadow CSS delays load without blocking document scripts','</head><body><div id=host><template shadowrootmode=open>'+link('/slow.css').replace('id=sheet','id=shadow')+'</template></div>'+script("const s=document.getElementById('host').shadowRoot.getElementById('shadow');s.addEventListener('load',()=>console.log('shadow load',s.sheet!==null));console.log('shadow next',s.sheet===null,document.styleSheets.length);")],
 ['imported CSS keeps parser barrier',link('/import.css')+script("const s=document.getElementById('sheet').sheet;console.log('import rules',s.cssRules.length,s.cssRules[0].styleSheet.cssRules.length);")+'</head><body>'],
 ['inline CSS import keeps parser barrier','<style id=sheet>@import "slow.css"; #root {color:red}</style>'+script("const s=document.getElementById('sheet').sheet;console.log('inline import',s.cssRules[0].styleSheet.cssRules.length);")+'</head><body>'],
 ['nested CSS imports keep parser barrier',link('/nested.css')+script("const s=document.getElementById('sheet').sheet;console.log('nested imports',s.cssRules[0].styleSheet.cssRules[0].styleSheet.cssRules.length);")+'</head><body>'],
 ['failed CSS import releases parent barrier',link('/failed-import.css')+script("const s=document.getElementById('sheet').sheet;console.log('failed import',s.cssRules.length,s.cssRules[0].styleSheet===null);")+'</head><body>'],
 ['unsupported import supports avoids request',link('/conditional-import.css')+script("console.log('conditional import',document.getElementById('sheet').sheet.cssRules[0].styleSheet===null);")+'</head><body>'],
 ['nonmatching imported media still loads',link('/print-import.css')+script("console.log('print import',document.getElementById('sheet').sheet.cssRules[0].styleSheet===null);")+'</head><body>'],
 ['cyclic import does not recur forever',link('/cycle-a.css')+script("const s=document.getElementById('sheet').sheet;console.log('cycle',s.cssRules[0].styleSheet.cssRules[0].styleSheet===null);")+'</head><body>'],
 ['remove owner cancels imported barrier',link('/import.css')+script("console.log('removed import',document.getElementById('sheet')===null);")+'</head><body>',script("setTimeout(()=>document.getElementById('sheet')?.remove(),20);")],
 ['duplicate imports own separate sheets',link('/duplicate-import.css')+script("const s=document.getElementById('sheet').sheet,a=s.cssRules[0],b=s.cssRules[1],v=a.styleSheet;console.log('import identities',v!==b.styleSheet,v===a.styleSheet,v.ownerRule===a,v.parentStyleSheet===s,v.ownerNode===null,v.media===a.media);")+'</head><body>'],
 ['redirected CSS imports use response base',link('/redirect.css')+script("const s=document.getElementById('sheet').sheet,c=s.cssRules[0].styleSheet;console.log('redirect base',new URL(s.href).pathname,new URL(c.href).pathname,c.cssRules.length);")+'</head><body>'],
 ['linked sheet preserves association during import completion',link('/import.css')+'<script async src="/inspect-import.js"></script>'+script("console.log('loaded import',pendingOwner===document.getElementById('sheet').sheet,pendingRule===pendingOwner.cssRules[0],pendingRule.styleSheet.cssRules.length);")+'</head><body>'],
 ['CSSOM import insertion begins asynchronous load','<style id=sheet></style>'+script("const s=document.getElementById('sheet').sheet;s.insertRule('@import \"slow.css\";',0);const r=s.cssRules[0];console.log('insert sync',r.styleSheet!==null);document.addEventListener('load',e=>{if(e.target.localName==='style')console.log('style loaded',r.styleSheet===null?'none':r.styleSheet.cssRules.length)},true);")+script("console.log('after inserted import',document.getElementById('sheet').sheet.cssRules[0].styleSheet===null);")+'</head><body>'],
 ['CSSOM removes pending inserted import','<style id=sheet></style>'+script("const s=document.getElementById('sheet').sheet;s.insertRule('@import \"slow.css\";',0);const r=s.cssRules[0];s.deleteRule(0);document.addEventListener('load',e=>{if(e.target.localName==='style')console.log('deleted owner load',r.styleSheet===null)},true);console.log('deleted inserted',s.cssRules.length,r.parentStyleSheet===null,r.styleSheet===null);")+script("console.log('after deleted insert');")+'</head><body>'],
 ['CSSOM removes pending original import',link('/import.css')+'<script async src="/delete-import.js"></script>'+script("console.log('after deleted original',document.getElementById('sheet').sheet.cssRules.length);")+'</head><body>'],
 ['CSSOM removes loaded original import',link('/import.css')+script("const s=document.getElementById('sheet').sheet,r=s.cssRules[0],c=r.styleSheet;s.deleteRule(0);console.log('deleted loaded',r.styleSheet===c,c.parentStyleSheet===s,c.ownerRule===r,r.parentStyleSheet===null);")+'</head><body>'],
 ['CSSOM insertion owner removal cancels load','<style id=sheet></style>'+script("const node=document.getElementById('sheet'),s=node.sheet;s.insertRule('@import \"slow.css\";',0);node.addEventListener('load',()=>console.log('obsolete owner load'));node.remove();console.log('removed insert',document.styleSheets.length);")+script("console.log('after removed insert');")+'</head><body>'],
];
(async()=>{
 let current=0;
 const handler=(req,res)=>{
  const url=new URL(req.url,'http://local');
  if(url.pathname==='/page'){
   const entry=cases[current];res.writeHead(200,{'Content-Type':'text/html'});
   res.end(('<!doctype html><html><head>'+setup+(entry[2]||'')+entry[1]).replaceAll('@CROSS@',crossOrigin));return;
  }
  const resource=resources[url.pathname];if(!resource){res.writeHead(404);res.end();return;}
  if(resource.Redirect){setTimeout(()=>{if(res.destroyed)return;res.writeHead(302,{Location:resource.Redirect});res.end();},resource.Delay);return;}
  setTimeout(()=>{if(res.destroyed)return;res.writeHead(resource.Status||200,{'Content-Type':resource.MIME,'Access-Control-Allow-Origin':'*','Cache-Control':'no-store'});res.end(resource.Source);},resource.Delay);
 };
 const server=http.createServer(handler),crossServer=http.createServer(handler);
 await new Promise(resolve=>crossServer.listen(0,'127.0.0.1',resolve));const crossOrigin='http://127.0.0.1:'+crossServer.address().port;
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const origin='http://127.0.0.1:'+server.address().port;
 const browser=await openBrowser(path.join(root,'build'));
 try{
  await browser.send('Page.addScriptToEvaluateOnNewDocument',{source:"window.trace=[];console.log=(...args)=>trace.push(args.map(String).join(' '));window.addEventListener('error',e=>{if(e.message)trace.push('UNCAUGHT '+e.message)});"});
  const fixtures=[];
  for(current=0;current<cases.length;current++){
   await browser.send('Page.navigate',{url:origin+'/page?case='+current});
   let trace=[];for(let tries=0;tries<200;tries++){await new Promise(resolve=>setTimeout(resolve,10));const state=await browser.evaluate('({url:document.URL,trace:window.trace||[]})');trace=state.trace;if(state.url===origin+'/page?case='+current&&trace.some(x=>x==='load complete'))break;}
   const timeout=!trace.some(x=>x==='load complete');
   assert.ok(!timeout||cases[current][0]==='CSSOM removes pending inserted import'||cases[current][0]==='CSSOM removes pending original import',cases[current][0]+' failed to load: '+trace.join(' | '));assert.ok(!trace.some(x=>x.startsWith('UNCAUGHT ')),cases[current][0]+': '+trace.join(' | '));
   const entry=cases[current],html=('<!doctype html><html><head>'+setup+(entry[2]||'')+entry[1]).replaceAll('@CROSS@','https://cross.styles.test');
   const mapped={};for(const [url,value]of Object.entries(resources))mapped['https://styles.test'+url]=value;
   mapped['https://cross.styles.test/slow.css']={...resources['/slow.css'],OriginClean:entry[0]!=='cross-origin CSS rules are protected'};
   const fixture={name:entry[0],html,expected:trace,resources:mapped};
   if(timeout){fixture.timeout=true;fixture.profileExpected=[...trace,...(entry[0]==='CSSOM removes pending inserted import'?['after deleted insert']:['sheet load true','after deleted original 1']),'dcl interactive','load complete'];fixture.difference='Chromium stalled its document parser after a pending import was removed through CSSOM. The engine cancellation profile releases removed import requests and preserves document progress; the observed browser timeout is retained separately.';}
   // Keep captured differences visible. These expectations follow the
   // linked-resource processing algorithm, not Chromium's legacy associations.
   if(entry[0]==='CSS HTTP error releases parser'){
    fixture.standardExpected=trace.map(x=>x==='after error false'?'after error true':x==='sheet error false'?'sheet error true':x);
    fixture.difference='HTML linked stylesheet failure creates no associated sheet; Chromium retains an empty sheet after HTTP error.';
   }else if(entry[0]==='CSS MIME error releases parser'){
    fixture.standardExpected=trace.map(x=>x==='after MIME false'?'after MIME true':x==='sheet load true'?'sheet error true':x);
    fixture.difference='HTML requires text/css MIME; Chromium accepted this same-origin text/plain response without nosniff.';
   }else if(entry[0]==='replace pending stylesheet URL'){
    fixture.standardExpected=trace.map(x=>x==='replaced false'?'replaced true':x);
    fixture.difference='Parser-created enabled stylesheet remains script-blocking for its replacement fetch in the HTML profile; Chromium releases the original barrier early.';
   }else if(entry[0]==='shadow CSS delays load without blocking document scripts'){
    fixture.standardExpected=['shadow next true 0','dcl interactive','shadow load true','load complete'];
    fixture.difference='Current HTML script-blocking conditions require the stylesheet element root to be Document; Chromium also blocks outer scripts on this declarative-shadow stylesheet.';
   }else if(entry[0]==='unsupported import supports avoids request'){
    fixture.standardExpected=trace.map(x=>x==='conditional import false'?'conditional import true':x);
    fixture.difference='CSS Cascade requires a false supports condition to expose null CSSImportRule.styleSheet; Chromium retains an empty associated sheet.';
   }else if(entry[0]==='duplicate imports own separate sheets'){
    fixture.standardExpected=trace.map(x=>x==='import identities true true true true true false'?'import identities true true true true true true':x);
    fixture.difference='CSSOM specifies CSSImportRule.media returning the associated sheet media value; Chromium exposes a separate MediaList object.';
   }
   fixtures.push(fixture);
  }
  if(process.argv.includes('--update'))fs.writeFileSync(file,JSON.stringify(fixtures,null,2)+'\n');else assert.deepEqual(fixtures,JSON.parse(fs.readFileSync(file,'utf8')));
  console.log('Chromium stylesheet loading: '+fixtures.length+' native parser/defer/async/load references captured.');
 }finally{await browser.close();await Promise.all([new Promise(resolve=>server.close(resolve)),new Promise(resolve=>crossServer.close(resolve))]);}
})().catch(error=>{console.error(error);process.exitCode=1;});
