// Real parent/child document barriers in an isolated browser, with delayed HTTP CSS.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),file=path.join(root,'tests/fixtures/stylesheet-embedded-browser.json');
const script=source=>'<script>'+source+'</script>';
const setup=prefix=>script(`document.addEventListener('DOMContentLoaded',()=>console.log('${prefix} dcl',document.readyState));window.addEventListener('load',()=>console.log('${prefix} load',document.readyState));`);
const child=source=>'<!doctype html><html><head>'+source+'</head><body><p>Child</p>';
const cases=[
 ['child classic waits for parent CSS',child(script("console.log('child classic');")),''],
 ['child defer waits for parent CSS',child('<script defer src="/child-defer.js"></script>'),''],
 ['child module waits for parent CSS',child('<script type=module>console.log("child module");</script>'),''],
 ['child async passes parent CSS',child('<script async src="/child-async.js"></script>'),''],
 ['nonmatching parent CSS allows child',child(script("console.log('child classic');")),'media="print"'],
 ['removed parent CSS releases child',child(script("console.log('child classic');")),'',script("setTimeout(()=>{document.getElementById('sheet').remove();console.log('parent CSS removed');},10);")],
 ['child CSS delays containing document load',child('<link rel=stylesheet href="/child.css">'+script("console.log('child classic');")) ,null],
 ['child without scripts still delays parent load','<!doctype html><link rel=stylesheet href="/child.css"><p>Child</p>',null],
 ['child load microtasks precede frame load',child(script("window.addEventListener('load',()=>Promise.resolve().then(()=>console.log('child load microtask')));")),null],
 ['child load document replacement completes new generation',child(script("window.addEventListener('load',()=>{document.open();document.write('<p>Replacement</p><script>console.log(\"child replacement\");<\\/script>');document.close();});")),null],
];
const resources={
 '/parent.css':{Source:'p{color:red}',MIME:'text/css',Delay:120},
 '/child.css':{Source:'p{color:blue}',MIME:'text/css',Delay:60},
 '/child-defer.js':{Source:"console.log('child defer');",MIME:'text/javascript',Delay:10},
 '/child-async.js':{Source:"console.log('child async');",MIME:'text/javascript',Delay:10},
};
function html(entry){const srcdoc=entry[1].replaceAll('&','&amp;').replaceAll('"','&quot;');return '<!doctype html><html><head>'+setup('parent')+(entry[3]||'')+'</head><body><iframe id=frame onload="console.log(\'frame load\')" srcdoc="'+srcdoc+'"></iframe>'+(entry[2]===null?'':'<link id=sheet rel=stylesheet href="/parent.css" '+entry[2]+' onload="console.log(\'parent CSS load\')">')+script("console.log('parent after');")+'<p>Parent</p>';}
(async()=>{
 let current=0;
 const server=http.createServer((req,res)=>{const pathname=new URL(req.url,'http://local').pathname;if(pathname==='/page'){res.writeHead(200,{'Content-Type':'text/html'});res.end(html(cases[current]));return;}const resource=resources[pathname];if(!resource){res.writeHead(404);res.end();return;}setTimeout(()=>{if(res.destroyed)return;res.writeHead(200,{'Content-Type':resource.MIME,'Cache-Control':'no-store'});res.end(resource.Source);},resource.Delay);});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const origin='http://127.0.0.1:'+server.address().port;
 const browser=await openBrowser(path.join(root,'build'));
 try{
  await browser.send('Page.addScriptToEvaluateOnNewDocument',{source:"if(window===top)window.trace=[];console.log=(...args)=>top.trace.push(args.map(String).join(' '));window.addEventListener('error',e=>{if(e.message)top.trace.push('UNCAUGHT '+e.message)});if(window!==top){document.addEventListener('DOMContentLoaded',()=>console.log('child dcl',document.readyState));window.addEventListener('load',()=>console.log('child load',document.readyState));}"});
  const fixtures=[];
  for(current=0;current<cases.length;current++){
   await browser.send('Page.navigate',{url:origin+'/page?case='+current});
   let trace=[];for(let tries=0;tries<300;tries++){await new Promise(resolve=>setTimeout(resolve,10));const state=await browser.evaluate('({url:document.URL,trace:window.trace||[]})');trace=state.trace;if(state.url===origin+'/page?case='+current&&trace.includes('parent load complete'))break;}
   assert.ok(trace.includes('parent load complete'),cases[current][0]+': '+trace.join(' | '));assert.ok(!trace.some(x=>x.startsWith('UNCAUGHT ')),cases[current][0]+': '+trace.join(' | '));
   const mapped={};for(const[url,resource]of Object.entries(resources))mapped['https://styles.test'+url]=resource;
   const fixture={name:cases[current][0],html:html(cases[current]),childHTML:cases[current][1],resources:mapped,expected:trace};
   if(current<3){const label=['child classic','child defer','child module'][current];fixture.standardBefore=[['parent CSS load',label]];fixture.difference='HTML styling/scripting includes the immediate container document script-blocking stylesheet set. Chromium lets this srcdoc child script execute before the parent stylesheet completes; its original trace is preserved.';}
   if(current===5)fixture.standardBefore=[['parent CSS removed','child classic']];
   fixtures.push(fixture);
  }
  if(process.argv.includes('--update'))fs.writeFileSync(file,JSON.stringify(fixtures,null,2)+'\n');else assert.deepEqual(fixtures,JSON.parse(fs.readFileSync(file,'utf8')));
  console.log('Embedded stylesheet loading: '+fixtures.length+' native parent/child references captured.');
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;});
