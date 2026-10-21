const svgFixture=require('./svg-fixtures.cjs');
// Execute the generated parent/frame scripts without navigating a browser.
// The frame DOM is deliberately inaccessible to the parent, as for opaque origins.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const root=path.resolve(__dirname,'..');
class Element {
 constructor(tag,attrs={}){this.tag=tag;this.attrs=attrs;this.id=attrs.id||'';this.children=[];this.style={};this.dataset={};this.listeners={};this.capture=new Set();this.textContent=''}
 append(...nodes){this.children.push(...nodes)} prepend(node){this.children.unshift(node)} replaceChildren(...nodes){this.children=nodes}
 setAttribute(k,v){this.attrs[k]=String(v)} getAttribute(k){return this.attrs[k]??null}
 addEventListener(kind,fn){(this.listeners[kind]??=[]).push(fn)}
 querySelector(){return null} closest(){return null}
 setPointerCapture(id){this.capture.add(id)} hasPointerCapture(id){return this.capture.has(id)}
}
function svgDocument(markup){
 const svg=new Element('svg');svg.markup=markup;svg.namespaceURI='http://www.w3.org/2000/svg';svg.scale=1;
 svg.getScreenCTM=()=>({a:svg.scale,e:0,f:0,inverse:()=>({scale:1/svg.scale})});
 svg.createSVGPoint=()=>({x:0,y:0,matrixTransform(m){return {x:this.x*m.scale,y:this.y*m.scale}}});
 const nodes=new Map();
 for(const match of markup.matchAll(/<([\w:-]+)\b([^>]*)>/g)){
  const attrs=Object.fromEntries([...match[2].matchAll(/([\w:-]+)="([^"]*)"/g)].map(m=>[m[1],m[2]]));
  if(attrs.id)nodes.set(attrs.id,new Element(match[1],attrs));
 }
 if(nodes.has('path'))Object.assign(nodes.get('path'),{getBBox:()=>({width:400,height:150}),getCTM:()=>({e:20,f:20}),getScreenCTM:()=>({a:1}),getTotalLength:()=>400,getPointAtLength:d=>({x:d/4,y:20})});
 const doc=new Element('document');doc.documentElement=svg;doc.getElementById=id=>nodes.get(id);doc.createElementNS=(_,tag)=>new Element(tag);doc.querySelector=q=>q==='svg'?svg:null;doc.fonts={ready:Promise.resolve()};doc.nodes=nodes;
 return doc;
}
async function check(page,expected){
 const html=svgFixture('examples/svg-tests/'+page);const main=html.match(/<script>([\s\S]*?)<\/script>/)[1];
 const host=new Element('div'),handlers={},created=[];
 const document={querySelector:()=>host,querySelectorAll:()=>host.children.filter(n=>n.className==='board'),createElement:tag=>{
  const node=new Element(tag);created.push(node);
  if(tag==='iframe'){node.contentWindow={};Object.defineProperty(node,'contentDocument',{get(){throw Error('Parent must not access frame DOM')}})}return node;
 }};
 const parent=vm.createContext({document,DOMParser:class{parseFromString(s){return svgDocument(s)}},XMLSerializer:class{serializeToString(svg){return svg.markup}},addEventListener:(k,fn)=>handlers[k]=fn,console});
 vm.runInContext(main,parent,{filename:page});
 const frames=created.filter(n=>n.tag==='iframe');assert.equal(frames.length,expected);
 const contexts=[];
 for(const [index,frame] of frames.entries()){
  assert(frame.srcdoc.includes('<script>'),'Frame carries its own script');assert.equal(frame.src,undefined,'No Blob navigation');
  const doc=svgDocument(frame.srcdoc);const script=frame.srcdoc.match(/<script>([\s\S]*?)<\/script>/)[1];let latest='';
  const context=vm.createContext({document:doc,parent:{postMessage:data=>{if(data.kind==='status')latest=data.text;handlers.message({source:frame.contentWindow,data})}},addEventListener(){},queueMicrotask:fn=>fn(),MouseEvent:class{constructor(type,opts){this.type=type;Object.assign(this,opts)}},console});
  // Keyboard activation uses the same element listener as an ordinary click.
  const fire=(id,type,extra={})=>{const node=doc.nodes.get(id);assert(node,id);const event={target:node,pointerId:7,clientX:0,clientY:0,preventDefault(){},...extra};for(const fn of node.listeners[type]||[])fn(event);for(const fn of doc.listeners[type]||[])fn(event)};
  for(const node of doc.nodes.values())node.dispatchEvent=e=>fire(node.id,e.type,e);
  vm.runInContext(script,context,{filename:frame.title});await Promise.resolve();
  assert.equal(frame.dataset.ready,'true');assert(!latest.includes('SVG-Fehler:'),latest);
  contexts.push({frame,doc,fire,latest:()=>latest});
 }
 const byName=name=>contexts.find(c=>c.frame.title===name);
 let c=byName('S37-capture');if(c){
  c.doc.documentElement.scale=2;c.fire('drag','pointerdown');c.fire('drag','pointermove',{clientX:600});assert.equal(c.doc.nodes.get('drag').attrs.cx,'300','Capture drag accounts for SVG scale');
  c.fire('drag','pointermove',{clientX:1200});assert.equal(c.doc.nodes.get('drag').attrs.cx,'445','Captured drag clamps outside board');
  c.doc.nodes.get('drag').capture.clear();c.fire('drag','lostpointercapture');c.fire('drag','pointermove',{clientX:100});assert.equal(c.doc.nodes.get('drag').attrs.cx,'445','Released drag stays still');
 }
 c=byName('S38-geometry');if(c){c.fire('handle','pointerdown',{clientX:350});c.fire('handle','pointermove',{clientX:400});assert.equal(c.doc.nodes.get('target').attrs.points,'40,250 400,100 440,250');c.fire('handle','keydown',{key:'ArrowLeft'});assert.equal(c.doc.nodes.get('handle').attrs.cx,'390')}
 c=byName('S38-resources');if(c){c.fire('button','click');assert.equal(c.doc.nodes.get('stop').attrs['stop-color'],'#16a34a');c.fire('button','keydown',{key:'Enter'});assert.equal(c.doc.nodes.get('stop').attrs['stop-color'],'#ef4444')}
 c=byName('S38-queries');if(c){c.fire('button','click');assert.equal(c.doc.nodes.get('dot').attrs.cx,'25');c.fire('button','click');assert.equal(c.doc.nodes.get('dot').attrs.cx,'50')}
 c=byName('S38-paint');if(c){c.fire('button','click');assert.equal(c.doc.nodes.get('target').attrs.fill,'#16a34a')}
 // Unrelated frames cannot change readouts; old frames cannot affect rebuilt boards.
 const out=host.children[2],original=out.textContent;
 handlers.message({source:{},data:{channel:'svg-runtime',token:'1:0',kind:'status',text:'spoof'}});assert.equal(out.textContent,original);
 handlers.message({source:frames[0].contentWindow,data:{channel:'svg-runtime',token:'1:0',kind:'shortcut',key:'1'}});assert.equal(host.children[0].style.width,'240px');
 handlers.message({source:frames[0].contentWindow,data:{channel:'svg-runtime',token:'1:0',kind:'shortcut',key:'r'}});assert.notEqual(host.children[2],out);
 handlers.message({source:frames[0].contentWindow,data:{channel:'svg-runtime',token:'1:0',kind:'status',text:'stale'}});assert.notEqual(host.children[2].textContent,'stale');
 console.log(page+': isolated frame startup, actions, capture, scaling, keyboard and message routing passed (DOM mocks; native visual comparison pending).');
}
(async()=>{await check('s37-s38.html',8);await check('s37.html',4);await check('s38.html',4)})().catch(e=>{console.error(e);process.exitCode=1});
