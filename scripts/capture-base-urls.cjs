// Frozen document bases and reflected URLs in isolated native Chromium.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),file=path.join(root,'tests/fixtures/base-url-browser.json');
const cases=[
 {name:'first base remains frozen across history',html:'<base id=a href="../first/"><base id=b href="../second/"><a id=link href="item">Item</a>',source:`const a=document.getElementById('a'),b=document.getElementById('b'),link=document.getElementById('link');
 console.log(document.baseURI,a.href,b.href,link.href);history.pushState({},'', '/moved/deep/page');document.title='Changed';console.log(document.baseURI,a.href,b.href,link.href);
 a.setAttribute('href',a.getAttribute('href'));console.log(document.baseURI,a.href,link.href);a.remove();console.log(document.baseURI,b.href,link.href);a.href='../detached/';document.head.prepend(a);console.log(document.baseURI,a.href,link.href);`},
 {name:'becoming first refreezes a base',html:'<base id=a href="../first/"><base id=b href="../second/">',source:`const a=document.getElementById('a'),b=document.getElementById('b');console.log(document.baseURI);history.pushState({},'', '/moved/deep/page');document.head.prepend(b);console.log(document.baseURI,b.href);document.head.prepend(a);console.log(document.baseURI,a.href);a.removeAttribute('href');console.log(document.baseURI,a.href);a.href='';console.log(document.baseURI,a.href);`},
 {name:'missing and detached href uses fallback',html:'<base id=a><base id=b href="../chosen/">',source:`const a=document.getElementById('a'),b=document.getElementById('b'),d=document.createElement('base');console.log(document.baseURI,a.href,b.href,d.href);d.href='../detached/';console.log(document.baseURI,d.href);a.href='../new/';console.log(document.baseURI,a.href,b.href);a.remove();console.log(document.baseURI,a.href);`},
 {name:'foreign namespaced href is inert',html:'<base id=a><base id=b href="../chosen/">',source:`const a=document.getElementById('a');a.setAttributeNS('urn:foreign','p:href','https://ignored.test/');console.log(document.baseURI,a.href,a.getAttributeNS('urn:foreign','href'));a.href='../active/';console.log(document.baseURI,a.href);a.removeAttribute('href');console.log(document.baseURI,a.href);`},
 {name:'base mutations expose expanded attribute names',html:'<base id=a>',source:`const a=document.getElementById('a'),records=[];const observer=new MutationObserver(changes=>{for(const r of changes)records.push(r.attributeName+'|'+r.attributeNamespace+'|'+r.oldValue)});observer.observe(a,{attributes:true,attributeOldValue:true});a.setAttributeNS('urn:foreign','p:href','one');a.setAttributeNS('urn:foreign','q:href','two');a.removeAttributeNS('urn:foreign','href');a.href='../active/';Promise.resolve().then(()=>{console.log(records.join(';'));observer.disconnect()});`},
 {name:'adoption uses the new document fallback',html:'<base id=a href="../first/"><base id=b href="../second/">',source:`const a=document.getElementById('a'),other=document.implementation.createHTMLDocument('Other');other.head.innerHTML='<base id=own href="https://detached.test/root/">';const link=other.createElement('a');link.href='item';other.body.append(link);console.log(other.URL,other.baseURI,link.href);other.adoptNode(a);other.head.prepend(a);console.log(document.baseURI,other.baseURI,a.href,link.href);a.href='https://adopted.test/path/';console.log(other.baseURI,a.href,link.href);document.adoptNode(a);document.head.prepend(a);console.log(document.baseURI,other.baseURI,a.href,link.href);`},
];
(async()=>{
 let current=0;const server=http.createServer((req,res)=>{if(!['/docs/page','/moved/deep/page'].includes(new URL(req.url,'http://local').pathname)){res.writeHead(404);res.end();return;}res.writeHead(200,{'Content-Type':'text/html;charset=utf-8'});res.end('<!doctype html><title>case'+current+'</title>'+cases[current].html);});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const origin='http://127.0.0.1:'+server.address().port,browser=await openBrowser(path.join(root,'build'));
 try{
  const fixtures=[];
  for(current=0;current<cases.length;current++){
   await browser.send('Page.navigate',{url:origin+'/docs/page'});let ready=false;
   for(let tries=0;tries<200;tries++){await new Promise(resolve=>setTimeout(resolve,10));ready=await browser.evaluate(`document.readyState==='complete'&&document.title==='case${current}'`);if(ready)break;}assert.ok(ready,cases[current].name);
   const source=cases[current].source;const result=await browser.evaluate(`(async()=>{const values=[],previous=console.log;console.log=(...args)=>values.push(args.map(String).join(' '));try{${source};await Promise.resolve();await Promise.resolve();return values}finally{console.log=previous}})()`);
   fixtures.push({...cases[current],documentURL:'https://docs.test/docs/page',expected:result.map(value=>value.replaceAll(origin,'https://docs.test'))});
  }
  if(process.argv.includes('--update'))fs.writeFileSync(file,JSON.stringify(fixtures,null,2)+'\n');else assert.deepEqual(fixtures,JSON.parse(fs.readFileSync(file,'utf8')));
  console.log('Frozen bases: '+fixtures.length+' native mutation/history/namespace sequences captured.');
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;});
