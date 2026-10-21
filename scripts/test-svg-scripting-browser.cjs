const svgFixture=require('./svg-fixtures.cjs');
// Runs the real fixture JavaScript in Node with a small explicit DOM test double.
// No browser navigation and no claim of native SVG rendering verification.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
class Element{
 constructor(tag,attrs={},doc){this.tagName=tag;this.namespaceURI='http://www.w3.org/2000/svg';this.attrs=attrs;this.doc=doc;this.children=[];this.parentNode=null;this.listeners={};this.text='';this.style={};this.dataset={};}
 append(...nodes){for(const n of nodes)this.appendChild(n)}
 prepend(n){n.remove();n.parentNode=this;this.children.unshift(n)}
 replaceChildren(...nodes){for(const n of this.children)n.parentNode=null;this.children=[];this.append(...nodes)}
 querySelector(selector){return this.children.map(c=>c.tagName===selector?c:c.querySelector(selector)).find(Boolean)||null}
 get id(){return this.attrs.id||''}set id(v){this.attrs.id=String(v)}
 get textContent(){return this.text+this.children.map(c=>c.textContent).join('')}set textContent(v){this.text=String(v);this.children=[]}
 setAttribute(k,v){this.attrs[k]=String(v)}getAttribute(k){return this.attrs[k]??null}removeAttribute(k){delete this.attrs[k]}
 appendChild(n){n.remove();n.parentNode=this;this.children.push(n);return n}
 removeChild(n){assert.equal(n.parentNode,this);this.children.splice(this.children.indexOf(n),1);n.parentNode=null;return n}
 remove(){if(this.parentNode)this.parentNode.removeChild(this)}
 addEventListener(k,fn){(this.listeners[k]??=[]).push(fn)}
 removeEventListener(k,fn){this.listeners[k]=(this.listeners[k]||[]).filter(f=>f!==fn)}
 fire(k,data={}){for(const fn of this.listeners[k]||[])fn({type:k,target:this,currentTarget:this,preventDefault(){},...data})}
}
function documentFor(source){
 const doc={createElementNS(ns,name){assert.equal(ns,'http://www.w3.org/2000/svg');return new Element(name,{},doc)}};
 const holder=new Element('document',{},doc),stack=[holder];
 for(const token of source.match(/<[^>]*>|[^<]+/g)||[]){
  if(token.startsWith('</')){stack.pop();continue}if(token.startsWith('<')){if(token.startsWith('<!'))continue;const name=token.match(/^<([\w:-]+)/)[1],attrs=Object.fromEntries([...token.matchAll(/([\w:-]+)="([^"]*)"/g)].map(m=>[m[1],m[2]]));const n=new Element(name,attrs,doc);stack.at(-1).appendChild(n);if(!token.endsWith('/>'))stack.push(n)}else stack.at(-1).text+=token;
 }
 doc.documentElement=holder.children[0];doc.getElementById=id=>{const search=n=>n.id===id?n:n.children.map(search).find(Boolean);return search(holder)||null};return doc;
}
for(const page of ['s41-s42.html','s41.html','s42.html']){
 const html=svgFixture('examples/svg-tests/'+page);const data=html.match(/const sources=(.*?),fonts=/s)[1];const cases=JSON.parse(data);
 for(const item of cases){
  const doc=documentFor(item.SVG),context=vm.createContext({document:doc,console});for(const code of item.Scripts)vm.runInContext(code,context,{timeout:1000,filename:item.Name});
  const id=v=>doc.getElementById(v);
  if(item.Name==='S41-create'){assert.equal(id('host').children[0].attrs.r,'35');id('action').fire('click');assert.equal(id('host').children[0].attrs.r,'43');assert.equal(id('count').textContent,'1')}
  if(item.Name==='S41-closures'){id('circle1').fire('click');id('circle1').fire('click');id('circle3').fire('click');assert.equal(id('circle0').attrs.r,'28');assert.equal(id('circle1').attrs.r,'38');assert.equal(id('circle3').attrs.r,'33')}
  if(item.Name==='S41-remove'){id('action').fire('click');assert.equal(id('dot'),null);assert.equal(id('status').textContent,'Entfernt');id('action').fire('keydown',{key:'Enter'});assert(id('dot'));assert.equal(id('status').textContent,'Sichtbar')}
  if(item.Name==='S41-resource'){id('action').fire('click');assert.equal(id('stop').attrs['stop-color'],'#16a34a');id('action').fire('click');assert.equal(id('stop').attrs['stop-color'],'#2563eb')}
  if(item.Fragment){const svg=svgFixture('examples/svg-tests/'+item.Name+'.svg');assert(svg.includes('id="'+item.Fragment+'"'));assert(svg.includes('width="100%"'));assert(html.includes("frame.src=item.Name+'.svg#'+item.Fragment"),'Native view fragment route')}
 }
 console.log(page+': native JS execution against DOM mocks matches Luau fixture assertions; SVG fragment files validated.');
}

(async()=>{
 for(const page of ['s41-s42.html','s41.html','s42.html']){
  const html=svgFixture('examples/svg-tests/'+page),main=html.match(/<script>([\s\S]*?)<\/script>/)[1];
  const host=new Element('host'),handlers={},created=[];
  const document={querySelector:()=>host,querySelectorAll:()=>host.children.filter(n=>n.className==='board'),createElement:tag=>{const n=new Element(tag);created.push(n);if(tag==='iframe'){n.contentWindow={};Object.defineProperty(n,'contentDocument',{get(){throw Error('Parent DOM access forbidden')}})}return n}};
  const parent=vm.createContext({document,DOMParser:class{parseFromString(source){const doc=documentFor(source);doc.querySelector=q=>q==='parsererror'?null:doc.documentElement.querySelector(q);doc.documentElement.markup=source;return doc}},XMLSerializer:class{serializeToString(svg){return svg.markup}},addEventListener:(k,fn)=>handlers[k]=fn,console});
  vm.runInContext(main,parent,{filename:page});const frames=created.filter(n=>n.tagName==='iframe');
  for(const frame of frames){
   if(frame.src){assert(frame.src.includes('.svg#'));continue}
   const markup=frame.srcdoc.match(/<svg[\s\S]*?<\/svg>/)[0],doc=documentFor(markup);doc.querySelector=q=>q==='svg'?doc.documentElement:doc.documentElement.querySelector(q);doc.fonts={ready:Promise.resolve()};doc.addEventListener=()=>{};
   let status='';const context=vm.createContext({document:doc,parent:{postMessage:data=>{if(data.kind==='status')status=data.text;handlers.message({source:frame.contentWindow,data})}},addEventListener(){},queueMicrotask:fn=>fn(),console});
   for(const match of frame.srcdoc.matchAll(/<script>([\s\S]*?)<\/script>/g))vm.runInContext(match[1],context,{timeout:1000,filename:frame.title});
   await Promise.resolve();assert.equal(frame.dataset.ready,'true');assert(!status.includes('SVG-Fehler'),status);
  }
  const original=host.children[2];handlers.keydown({key:'1'});assert.equal(host.children[0].style.width,'240px');handlers.keydown({key:'r'});assert.notEqual(host.children[2],original);
  handlers.message({source:frames[0].contentWindow,data:{channel:'svg-runtime',token:'1:0',kind:'status',text:'stale'}});assert.notEqual(host.children[2].textContent,'stale');
  console.log(page+': generated frame startup, native JS installation, view URLs, resize/reset and stale-message isolation passed (DOM mocks).');
 }
})().catch(e=>{console.error(e);process.exitCode=1});
