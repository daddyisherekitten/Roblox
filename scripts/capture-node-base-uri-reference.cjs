// Native Node.baseURI follows the node document, independent of connectivity.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/node-base-uri-reference'),file=path.join(root,'tests/fixtures/node-base-uri-browser.json');
const target={date:'2026-10-06',commit:'b76da7af5fe35a2a368127cc9ec22449ac8fd559',commitDate:'2026-10-05T19:51:51Z',url:'https://raw.githubusercontent.com/whatwg/dom/b76da7af5fe35a2a368127cc9ec22449ac8fd559/dom.bs',sha256:'a7e26185022e0f29650bcd30be7df091419096f6d9bd96bb493662efa34d1e7f'};
const cases=[
 {name:'node kinds share document base',html:'<base href="../assets/"><div id=host title=hello>Text<!--comment--></div>',source:`
 const host=document.getElementById('host'),frag=document.createDocumentFragment(),pi=document.createProcessingInstruction('probe','value'),attr=host.getAttributeNode('title');
 const nodes=[document,document.doctype,document.documentElement,host,host.firstChild,host.lastChild,frag,pi,attr,document.createAttribute('fresh'),document.createElementNS('urn:test','p:item')];
 console.log(JSON.stringify(nodes.map(n=>[n.nodeType,n.baseURI,n===document?null:n.ownerDocument===document])));
 host.remove();console.log(JSON.stringify(nodes.map(n=>n.baseURI)));`},
 {name:'live base and detached owners',html:'<base id=base href="../assets/"><div id=host title=value>Text</div>',source:`
 const base=document.getElementById('base'),host=document.getElementById('host'),text=host.firstChild,attr=host.getAttributeNode('title'),frag=document.createDocumentFragment();
 const own=document.implementation.createHTMLDocument('Other');own.head.innerHTML='<base id=b href="https://other.invalid/root/">';
 function read(){console.log(JSON.stringify([document.baseURI,own.baseURI,host.baseURI,text.baseURI,attr.baseURI,frag.baseURI]));}
 read();base.href='../second/';read();host.remove();read();own.adoptNode(host);read();own.adoptNode(frag);read();
 own.getElementById('b').href='https://other.invalid/changed/';read();document.adoptNode(host);read();base.remove();read();`},
 {name:'template and shadow bases',html:'<base id=base href="../assets/"><div id=host></div><template id=tpl><span title=inside>Template</span></template>',source:`
 const host=document.getElementById('host'),shadow=host.attachShadow({mode:'open'}),text=document.createTextNode('Shadow'),tpl=document.getElementById('tpl');shadow.append(text);
 const content=tpl.content,inside=content.firstChild,own=document.implementation.createHTMLDocument('Other');own.head.innerHTML='<base href="https://other.invalid/root/">';
 function read(){console.log(JSON.stringify([host.baseURI,shadow.baseURI,text.baseURI,tpl.baseURI,content.baseURI,inside.baseURI,inside.getAttributeNode('title').baseURI]));}
 read();document.getElementById('base').href='../changed/';read();own.adoptNode(host);read();own.adoptNode(tpl);read();document.adoptNode(host);document.adoptNode(tpl);read();`},
 {name:'xml bases and adopted attributes',html:'<base href="../assets/">',source:`
 const xml=new DOMParser().parseFromString('<root xml:base="https://ignored.invalid/"><child a="value"><![CDATA[content]]><!--comment--><?probe data?></child></root>','text/xml');
 const child=xml.documentElement.firstChild,attr=child.getAttributeNode('a');
 console.log(JSON.stringify([xml,xml.documentElement,child,child.firstChild,child.childNodes[1],child.lastChild,attr].map(n=>[n.nodeType,n.baseURI])));
 child.setAttributeNS('http://www.w3.org/XML/1998/namespace','xml:base','https://also-ignored.invalid/');console.log(JSON.stringify([child.baseURI,attr.baseURI]));
 document.adoptNode(child);console.log(JSON.stringify([child.baseURI,child.firstChild.baseURI,attr.baseURI,xml.baseURI]));`},
 {name:'constructed XML doctype and detached document',html:'<base href="../assets/">',source:`
 const type=document.implementation.createDocumentType('root','',''),xml=document.implementation.createDocument('urn:root','r:root',type);
 const text=xml.createTextNode('text'),cdata=xml.createCDATASection('content'),pi=xml.createProcessingInstruction('probe','data');xml.documentElement.append(text,cdata,pi);
 console.log(JSON.stringify([xml,type,xml.documentElement,text,cdata,pi].map(n=>[n.nodeType,n.baseURI])));
 document.adoptNode(type);console.log(JSON.stringify([type.baseURI,xml.baseURI,xml.doctype]));`},
 {name:'descriptor readonly branding and own override',html:'<base href="../assets/"><div id=host></div>',source:`
 const host=document.getElementById('host'),desc=Object.getOwnPropertyDescriptor(Node.prototype,'baseURI');
 function outcome(fn){try{return fn()}catch(e){return e.name}}
 console.log(JSON.stringify([desc.enumerable,desc.configurable,typeof desc.set,desc.get.name,desc.get.length,desc.get.call(host),desc.get.call(document)]));
 console.log(JSON.stringify([null,undefined,{},42,Node.prototype].map(n=>outcome(()=>desc.get.call(n)))));
 host.baseURI='changed';console.log(JSON.stringify([host.baseURI,Object.prototype.hasOwnProperty.call(host,'baseURI')]));
 console.log(outcome(()=>{function strict(){'use strict';host.baseURI='changed'}strict();return 'accepted'}));
 Object.defineProperty(host,'baseURI',{value:'own',configurable:true});console.log(JSON.stringify([host.baseURI,desc.get.call(host)]));delete host.baseURI;console.log(host.baseURI);`},
 {name:'history fallback and frozen first base',html:'<div id=host>Text</div>',source:`
 const host=document.getElementById('host'),text=host.firstChild,frag=document.createDocumentFragment();
 function read(){console.log(JSON.stringify([document.baseURI,host.baseURI,text.baseURI,frag.baseURI]));}
 read();history.pushState({},'', '/moved/deep/page');read();const base=document.createElement('base');base.href='../first/';document.head.append(base);read();
 history.pushState({},'', '/elsewhere/page');read();base.setAttribute('href',base.getAttribute('href'));read();base.remove();read();`},
];
async function main(){
 fs.mkdirSync(folder,{recursive:true});
 const sourceResponse=await fetch(target.url);assert(sourceResponse.ok,'Pinned DOM source unavailable');
 const source=await sourceResponse.text(),sha=crypto.createHash('sha256').update(source).digest('hex');
 assert.equal(sha,target.sha256,'Pinned DOM source changed');
 assert(source.includes('baseURI'),'Pinned source lacks baseURI');fs.writeFileSync(path.join(folder,'dom-target-source'),source);
 fs.writeFileSync(path.join(folder,'dom-target-metadata.json'),JSON.stringify(target,null,2)+'\n');
 let current=0;const server=http.createServer((req,res)=>{if(!cases[current]||req.url==='/favicon.ico'){res.writeHead(404);res.end();return;}res.writeHead(200,{'Content-Type':'text/html;charset=utf-8'});res.end('<!doctype html><title>nodebase'+current+'</title>'+cases[current].html);});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const origin='http://127.0.0.1:'+server.address().port,browser=await openBrowser(folder);
 try{
  const fixtures=[];
  for(current=0;current<cases.length;current++){
   await browser.send('Page.navigate',{url:origin+'/docs/page'});let ready=false;
   for(let tries=0;tries<200;tries++){await new Promise(resolve=>setTimeout(resolve,10));ready=await browser.evaluate(`document.readyState==='complete'&&document.title==='nodebase${current}'`);if(ready)break;}
   assert(ready,cases[current].name);
   const result=await browser.evaluate(`(()=>{const values=[],previous=console.log;console.log=value=>values.push(String(value));try{${cases[current].source};return values}finally{console.log=previous}})()`);
   fixtures.push({...cases[current],documentURL:'https://base.invalid/docs/page',expected:result.map(value=>value.replaceAll(origin,'https://base.invalid'))});
  }
  const fixture={target,browser:await browser.send('Browser.getVersion'),cases:fixtures};
  if(process.argv.includes('--update'))fs.writeFileSync(file,JSON.stringify(fixture,null,2)+'\n');else {const previous=JSON.parse(fs.readFileSync(file,'utf8'));assert.deepEqual(target,previous.target);assert.deepEqual(fixtures,previous.cases);}
  console.log('Node base URI: '+fixtures.length+' native kinds/mutations/adoption/descriptor sequences captured; DOM '+target.commit+' SHA '+sha);
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
}
main().catch(error=>{console.error(error);process.exitCode=1;});
