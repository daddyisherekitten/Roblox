const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {openBrowser}=require('./native-browser.cjs');
const folder=path.resolve(__dirname,'../build/event-handler-attributes-reference');fs.mkdirSync(folder,{recursive:true});
const cases=[{
 name:'Parsed handler function, argument, current target and return cancellation',
 html:`<!doctype html><button id=sample onclick="window.trace.push(this.id+':'+event.type+':'+(this===event.currentTarget)); return false">Run</button>`,
 action:`(()=>{window.trace=[];const b=document.getElementById('sample');b.addEventListener('click',()=>trace.push('after'));const fn=b.onclick,e=new Event('click',{cancelable:true});const accepted=b.dispatchEvent(e);const constructNode=document.createElement('button');constructNode.setAttribute('onclick','return 7');let construct;try{const instance=new constructNode.onclick();construct=instance.constructor===constructNode.onclick}catch(error){construct=error.name}return JSON.stringify({trace,accepted,canceled:e.defaultPrevented,name:fn.name,length:fn.length,stable:fn===b.onclick,prototype:Object.hasOwn(fn,'prototype'),construct,source:fn.toString()})})()`,
},{
 name:'Attribute and IDL replacement, same source write, deactivate and reactivate order',html:'<!doctype html><button id=sample>Run</button>',
 action:`(()=>{window.trace=[];const b=document.getElementById('sample'),fire=()=>{b.dispatchEvent(new Event('click'));trace.push('|')};b.addEventListener('click',()=>trace.push('one'));b.setAttribute('onclick',"window.trace.push('attribute')");b.addEventListener('click',()=>trace.push('three'));b.onclick=()=>trace.push('assigned');fire();b.setAttribute('onclick',b.getAttribute('onclick'));fire();b.onclick=null;b.addEventListener('click',()=>trace.push('four'));b.onclick=()=>trace.push('five');fire();b.removeAttribute('onclick');fire();b.onclick='window.trace.push(99)';b.setAttribute('onmadeup',"window.trace.push('unknown')");b.dispatchEvent(new Event('madeup'));return JSON.stringify({trace,handler:b.onclick,attribute:b.getAttribute('onclick'),unknown:b.getAttribute('onmadeup')})})()`,
},{
 name:'Lazy syntax failure reports once and retains listener position',html:'<!doctype html><button id=sample>Run</button>',
 action:`(()=>{window.trace=[];let errors=0;window.addEventListener('error',e=>{errors++;e.preventDefault()});const b=document.getElementById('sample');b.addEventListener('click',()=>trace.push('one'));b.setAttribute('onclick','return }');b.addEventListener('click',()=>trace.push('three'));const before=errors,first=b.onclick,after=errors,again=b.onclick; b.setAttribute('onclick',"window.trace.push('two')");b.dispatchEvent(new Event('click'));b.setAttribute('onclick','return }');b.onclick=()=>trace.push('replacement');b.dispatchEvent(new Event('click'));return JSON.stringify({before,after,errors,first,again,trace})})()`,
},{
 name:'Live document form element object scopes, receivers, locals and unscopables',
 html:`<!doctype html><form id=f><input name=peer value=one><button id=sample type=button value=button data-own=own onclick="window.trace.push([id,value,peer.value,scopeToken,docToken,getAttribute('data-own'),document===ownerDocument,typeof outerLocal,globalLexical].join('|')); value='changed';peer.value='two';window.trace.push(delete deletable);window.trace.push(typeof deletable)">Run</button></form>`,
 prep:`let globalLexical='lexical';`,
 action:`(()=>{window.trace=[];const f=document.getElementById('f'),b=document.getElementById('sample');f.scopeToken='form';document.docToken='document';b.scopeToken='element';b.deletable='yes';Object.defineProperty(b,Symbol.unscopables,{value:{scopeToken:true}});const outerLocal='outside';b.dispatchEvent(new Event('click'));const first=trace.slice();f.scopeToken='updated';b.dispatchEvent(new Event('click'));b.setAttribute('onclick',"var value='local';window.trace.push(value);window.trace.push(this.value)");b.dispatchEvent(new Event('click'));return JSON.stringify({first,trace,value:b.value,peer:f.peer.value,ownDeleted:!Object.hasOwn(b,'deletable')})})()`,
},{
 name:'Form owner is captured at compilation and refreshed by source replacement',
 html:`<!doctype html><form id=f1></form><form id=f2></form><button id=sample form=f1 onclick="window.trace.push(scopeToken)">Run</button>`,
 action:`(()=>{window.trace=[];const b=document.getElementById('sample');document.getElementById('f1').scopeToken='first';document.getElementById('f2').scopeToken='second';b.setAttribute('form','f2');const fn=b.onclick;b.setAttribute('form','f1');b.dispatchEvent(new Event('click'));b.setAttribute('onclick',b.getAttribute('onclick'));b.dispatchEvent(new Event('click'));return JSON.stringify({trace,recompiled:fn!==b.onclick})})()`,
},{
 name:'Namespaces do not execute ordinary named onclick attributes',html:'<!doctype html><button id=sample>Run</button><svg><g id=svgSample onclick="window.trace.push(event.type)"></g></svg>',
 action:`(()=>{window.trace=[];const b=document.getElementById('sample');b.setAttributeNS('urn:other','onclick',"window.trace.push('namespaced')");const handler=b.onclick;b.dispatchEvent(new Event('click'));document.getElementById('svgSample').dispatchEvent(new Event('click'));b.removeAttributeNS('urn:other','onclick');b.setAttribute('onclick',"window.trace.push('ordinary')");b.dispatchEvent(new Event('click'));return JSON.stringify({handler,trace})})()`,
},{
 name:'Inert getter preserves raw source until adoption under the HTML Standard',
 specExpected:JSON.stringify({before:null,parsedBefore:null,trace:['template:inside','parsed','parsed'],cloned:true}),
 nativeDifference:'Chromium 154 clears the raw handler when read in a document without a browsing context. HTML get-current-value step 3.2 returns null without changing the raw handler; adoption then enables compilation. The native parsed trace is from the fresh clone, not the original.',
 html:`<!doctype html><template id=t><button id=inside onclick="window.trace.push('template:'+this.id)">Run</button></template>`,
 action:`(()=>{window.trace=[];const node=document.getElementById('t').content.querySelector('button'),before=node.onclick;document.body.appendChild(node);node.dispatchEvent(new Event('click'));const inert=new DOMParser().parseFromString('<button onclick="window.trace.push(\\'parsed\\')">Run</button>','text/html'),parsed=inert.querySelector('button'),parsedBefore=parsed.onclick;document.body.appendChild(parsed);parsed.dispatchEvent(new Event('click'));const clone=parsed.cloneNode(true);document.body.appendChild(clone);clone.dispatchEvent(new Event('click'));return JSON.stringify({before,parsedBefore,trace,cloned:clone.onclick!==parsed.onclick})})()`,
},{
 name:'Body forwarding targets window while ordinary body click stays local',html:'<!doctype html><body><button>Run</button>',
 action:`(()=>{window.trace=[];const b=document.body;b.setAttribute('onload',"window.trace.push('load:'+ (this===window)+':'+(event.currentTarget===window))");b.setAttribute('onclick',"window.trace.push('click:'+ (this===document.body))");const same=b.onload===window.onload;window.dispatchEvent(new Event('load'));b.dispatchEvent(new Event('load'));b.dispatchEvent(new Event('click'));b.onload=()=>trace.push('replacement');window.dispatchEvent(new Event('load'));b.removeAttribute('onload');window.dispatchEvent(new Event('load'));return JSON.stringify({trace,same,removed:window.onload===null,local:b.onclick!==window.onclick})})()`,
},{
 name:'Window error five arguments and plain beforeunload string return coercion',html:'<!doctype html><body><img id=sample>',
 action:`(()=>{window.trace=[];document.body.setAttribute('onerror',"window.trace.push([typeof event,source,lineno,colno,error===null,arguments.length,this===window].join('|'));return true");const error=new ErrorEvent('error',{message:'broken',filename:'source.js',lineno:3,colno:4,error:null,cancelable:true});const accepted=window.dispatchEvent(error),plain=new Event('error',{cancelable:true});window.dispatchEvent(plain);const b=document.getElementById('sample');b.setAttribute('onerror',"window.trace.push('image:'+arguments.length+':'+event.type);return false");const imageAccepted=b.dispatchEvent(new Event('error',{cancelable:true}));document.body.setAttribute('onbeforeunload','return false');const before=new Event('beforeunload',{cancelable:true}),beforeAccepted=window.dispatchEvent(before);return JSON.stringify({trace,accepted,errorCanceled:error.defaultPrevented,plainCanceled:plain.defaultPrevented,imageAccepted,beforeAccepted,beforeCanceled:before.defaultPrevented,arity:window.onerror.length})})()`,
},{
 name:'document.open removes handlers without erasing content attributes',html:`<!doctype html><button id=sample onclick="window.trace.push('old')">Run</button>`,
 action:`(()=>{window.trace=[];const old=document.getElementById('sample');old.dispatchEvent(new Event('click'));window.onclick=()=>trace.push('window');document.open();const inactive=old.onclick,source=old.getAttribute('onclick'),windowInactive=window.onclick;old.dispatchEvent(new Event('click'));document.write('<button id="fresh" onclick="window.trace.push(\\'fresh\\')">New</button>');document.close();const fresh=document.getElementById('fresh');fresh.dispatchEvent(new Event('click'));return JSON.stringify({trace,inactive,windowInactive,source})})()`,
},{
 name:'Handler names distinguish HTML document and window and dispatch aliases',html:'<!doctype html><button id=sample>Run</button>',
 action:`(()=>{window.trace=[];const b=document.getElementById('sample');for(const type of ['copy','dragstart','select','contextlost','webkitanimationend']){b.setAttribute('on'+type,"window.trace.push(event.type)");b.dispatchEvent(new Event(type==='webkitanimationend'?'webkitAnimationEnd':type))}return JSON.stringify({trace,elementWindowOnly:typeof b.onbeforeunload,bodyWindowOnly:document.body.onbeforeunload,documentReady:document.onreadystatechange,elementReady:typeof b.onreadystatechange,windowReady:typeof window.onreadystatechange,media:b.oncanplay,nonHandler:typeof b.onmadeup})})()`,
},{
 name:'Generic form named properties, duplicate live RadioNodeList and past names',html:'<!doctype html><form id=f><input id=a name=peer value=one><input id=b name=peer value=two><input id=r1 type=radio name=choice value=A><input id=r2 type=radio name=choice value=B></form>',
 action:`(()=>{const f=document.getElementById('f'),a=document.getElementById('a'),b=document.getElementById('b');const list=f.peer,initial=[list.length,list[0]===a,list[1]===b,list instanceof RadioNodeList,list.value];f.choice.value='B';const radio=[f.choice.value,document.getElementById('r1').checked,document.getElementById('r2').checked];b.remove();const single=f.peer===a;a.name='renamed';const past=f.peer===a,newName=f.renamed===a;a.remove();return JSON.stringify({initial,radio,single,past,newName,removed:typeof f.peer,listLength:list.length})})()`,
},{
 name:'Untouched inert sources and cloned content attributes activate with independent slots',
 html:`<!doctype html><template id=t><button onclick="window.trace.push('template')">Run</button></template><button id=sample onclick="window.trace.push('source')">Run</button>`,
 action:`(()=>{window.trace=[];const node=document.getElementById('t').content.querySelector('button');document.body.appendChild(node);node.dispatchEvent(new Event('click'));const parsed=new DOMParser().parseFromString('<button onclick="window.trace.push(42)">Run</button>','text/html').querySelector('button');document.body.appendChild(parsed);parsed.dispatchEvent(new Event('click'));const source=document.getElementById('sample');source.addEventListener('click',()=>trace.push('listener'));source.onclick=()=>trace.push('assigned');const clone=source.cloneNode(true);document.body.appendChild(clone);clone.dispatchEvent(new Event('click'));source.dispatchEvent(new Event('click'));return JSON.stringify({trace,independent:source.onclick!==clone.onclick,source:clone.getAttribute('onclick')})})()`,
},{
 name:'Syntax report sees cleared value and preserves a reentrant replacement',html:'<!doctype html><button id=sample>Run</button>',
 action:`(()=>{window.trace=[];const b=document.getElementById('sample');window.addEventListener('error',e=>{trace.push(b.onclick===null?'cleared':'unexpected');b.onclick=()=>trace.push('replacement');e.preventDefault()});b.setAttribute('onclick','return }');const value=b.onclick;trace.push(value===b.onclick?'same':'other');b.dispatchEvent(new Event('click'));return JSON.stringify({trace,callable:typeof value})})()`,
},{
 name:'Form named properties override cached builtins and expose native descriptors',html:'<!doctype html><form id=f><input id=a name=peer value=one></form>',
 action:`(()=>{const f=document.getElementById('f'),a=document.getElementById('a'),method=f.reset,own=Object.getOwnPropertyDescriptor(f,'peer');a.name='reset';const clobbered=f.reset===a;f.reset=17;const assignment=f.reset===a;a.name='next';const past=f.reset===a;a.remove();return JSON.stringify({own:[own.value===a,own.writable,own.enumerable,own.configurable],hasOwn:Object.hasOwn(f,'peer'),clobbered,assignment,past,removed:f.reset===17,method:typeof method,index:typeof f[0]})})()`,
},{
 name:'Form indexed controls exclude image buttons and named images are a fallback',
 html:'<!doctype html><form id=f><input id=picture type=image name=excluded><img id=i1 name=peer><input id=a name=peer><img id=i2 name=peer><input id=b name=other></form><input id=external form=f name=outside>',
 action:`(()=>{const f=document.getElementById('f'),a=document.getElementById('a'),i1=document.getElementById('i1');const initial=[f.length,f.elements.length,f[0]===a,f[2]===document.getElementById('external'),typeof f.picture,typeof f.excluded,f.peer===a];a.name='new';const images=f.peer,duplicate=[images.length,images[0]===i1,images[1]===document.getElementById('i2'),images instanceof RadioNodeList];document.getElementById('i2').remove();const single=f.peer===i1;i1.name='changed';const past=f.peer===i1;i1.remove();return JSON.stringify({initial,duplicate,single,past,removed:typeof f.peer,keys:Object.keys(f)})})()`,
},{
 name:'Form index and named descriptors remain read-only across delete and hidden expandos',
 specExpected:JSON.stringify({own:[true,false,true,true],clobbered:false,removed:true,still:true,keys:['0'],after:'undefined'}),
 nativeDifference:'WebIDL named property visibility step 2 gives an ordinary own expando precedence over names. Chromium 154 exposes the form named property over a preexisting expando, rejecting assignment and define until deletion. The standard expectation retains the existing writable own property.',
 html:'<!doctype html><form id=f><input id=a name=initial></form>',
 action:`(()=>{const f=document.getElementById('f'),a=document.getElementById('a');f.peer=17;a.name='peer';const d=Object.getOwnPropertyDescriptor(f,'0'),own=[d.value===a,d.writable,d.enumerable,d.configurable];let strict,define;try{(()=>{'use strict';f.peer=19})()}catch(e){strict=e.name}try{Object.defineProperty(f,'peer',{value:21})}catch(e){define=e.name}const clobbered=f.peer===a,removed=delete f.peer,still=f.peer===a,keys=Object.keys(f);a.remove();return JSON.stringify({own,strict,define,clobbered,removed,still,keys,after:typeof f.peer})})()`,
},{
 name:'Object-scope presence does not invoke getters or lose undefined own bindings',
 html:`<!doctype html><button id=sample onclick="window.trace.push(scopeToken);window.trace.push(typeof undefinedBinding)">Run</button>`,
 action:`(()=>{window.trace=[];let reads=0;const b=document.getElementById('sample');Object.defineProperty(b,'scopeToken',{get(){reads++;return 'element'}});b.undefinedBinding=undefined;window.undefinedBinding=9;b.dispatchEvent(new Event('click'));return JSON.stringify({trace,reads,present:'undefinedBinding' in b})})()`,
},{
 name:'Cross-realm adoption retains compiled handler realm and compiles untouched source in destination',
 html:'<!doctype html><body></body>',
 sourceHTML:`<!doctype html><button id=compiled onclick="window.trace.push(window.scopeName+':'+(document===ownerDocument))">Run</button><button id=uncompiled onclick="window.trace.push(window.scopeName+':'+(document===ownerDocument))">Run</button>`,
 sourcePrep:`globalThis.trace=[];globalThis.scopeName='source';globalThis.compiled=document.getElementById('compiled');globalThis.uncompiled=document.getElementById('uncompiled');globalThis.original=compiled.onclick;`,
 prep:`globalThis.trace=[];globalThis.scopeName='destination';`,
 action:`(()=>{document.body.appendChild(compiled);document.body.appendChild(uncompiled);compiled.dispatchEvent(new Event('click'));uncompiled.dispatchEvent(new Event('click'));return JSON.stringify({source:foreignSource.trace,destination:trace,unchanged:compiled.onclick===original,compiledRealm:Object.getPrototypeOf(compiled.onclick)===foreignSource.Function.prototype,uncompiledRealm:Object.getPrototypeOf(uncompiled.onclick)===Function.prototype})})()`,
},{
 name:'Window named prototype exposes IDs and permitted names with live collection identity',
 html:'<!doctype html><div id=alpha></div><form id=f name=beta></form><img id=i name=gamma><input name=ignored><div id=duplicate></div><span id=duplicate></span>',
 action:`(()=>{const byId=document.getElementById('alpha'),f=document.getElementById('f'),list=window.duplicate;const initial=[window.alpha===byId,alpha===byId,window.beta===f,window.gamma===document.getElementById('i'),typeof window.ignored,list instanceof HTMLCollection,list.length,list[0]===document.querySelector('div[id=duplicate]')];document.querySelector('span').remove();const after=[list.length,window.duplicate===list[0],Object.hasOwn(window,'alpha')];const np=Object.getPrototypeOf(Object.getPrototypeOf(window)),d=Object.getOwnPropertyDescriptor(np,'alpha');const descriptor=[d.value===byId,d.writable,d.enumerable,d.configurable];return JSON.stringify({initial,after,descriptor,keys:Object.getOwnPropertyNames(np),tag:Object.prototype.toString.call(np),constructor:window instanceof Window,chain:Object.getPrototypeOf(np)===EventTarget.prototype})})()`,
},{
 name:'Named globals respect lexical own global and ordinary prototype precedence',
 html:'<!doctype html><div id=alpha></div><div id=beta></div><div id=toString></div>',
 prep:`let alpha='lexical';`,
 action:`(()=>{const element=document.getElementById('alpha');const initial=[alpha,window.alpha===element,typeof window.toString];window.alpha=7;const overwritten=[alpha,window.alpha,Object.hasOwn(window,'alpha')];delete window.alpha;const restored=[alpha,window.alpha===element,Object.hasOwn(window,'alpha')];beta=9;const assigned=[beta,window.beta];delete window.beta;const removed=window.beta===document.getElementById('beta');const np=Object.getPrototypeOf(Object.getPrototypeOf(window));let define;try{Object.defineProperty(np,'unknown',{value:2})}catch(e){define=e.name}return JSON.stringify({initial,overwritten,restored,assigned,removed,define,deletion:Reflect.deleteProperty(np,'alpha'),extension:Reflect.preventExtensions(np),extensible:Object.isExtensible(np)})})()`,
},{
 name:'Document named scope filters named element IDs and retains duplicate live lists',
 html:'<!doctype html><div id=onlyWindow></div><form name=peer id=f></form><img id=unnamed><img id=named name=image><object id=objectID></object><input name=ignored><form name=duplicate></form><img name=duplicate>',
 action:`(()=>{const list=document.duplicate,initial=[typeof document.onlyWindow,document.peer===document.getElementById('f'),typeof document.unnamed,document.named===document.getElementById('named'),document.image===document.getElementById('named'),document.objectID===document.getElementById('objectID'),typeof document.ignored,list instanceof HTMLCollection,list.length];document.querySelector('img[name=duplicate]').remove();return JSON.stringify({initial,length:list.length,single:document.duplicate===list[0],keys:Object.keys(document).filter(key=>['peer','image','named','objectID','duplicate'].includes(key))})})()`,
},{
 name:'Document named descriptor and own expando visibility follow current WebIDL rules',
 html:'<!doctype html><form id=f name=peer></form><form name=title></form>',
 specExpected:JSON.stringify({descriptor:[true,false,true,true],title:true,assignment:true,strict:'TypeError',define:'TypeError',deletion:false,still:true,expando:18,afterDelete:true}),
 nativeDifference:'Chromium 154 Document named properties expose writable descriptors and support overriding/deleting dynamically installed own names. Current HTML only declares a named getter; WebIDL requires readonly descriptors and rejects a setter/deleter. Ordinary own properties precede named properties under named-property visibility step 2.',
 action:`(()=>{const f=document.getElementById('f'),d=Object.getOwnPropertyDescriptor(document,'peer');const descriptor=[d.value===f,d.writable,d.enumerable,d.configurable],title=document.title instanceof Element;document.peer=17;const assignment=document.peer===f;let strict,define;try{(()=>{'use strict';document.peer=19})()}catch(e){strict=e.name}try{Object.defineProperty(document,'peer',{value:21})}catch(e){define=e.name}const deletion=delete document.peer,still=document.peer===f;document.custom=18;f.name='custom';const expando=document.custom;delete document.custom;return JSON.stringify({descriptor,title,assignment,strict,define,deletion,still,expando:expando instanceof Element?'element':expando,afterDelete:document.custom===f})})()`,
},{
 name:'Document named element methods participate in handler scope and are live after rename',
 html:`<!doctype html><form id=original name=peer></form><button id=sample onclick="window.trace.push(peer.id)">Run</button>`,
 action:`(()=>{window.trace=[];const b=document.getElementById('sample'),f=document.getElementById('original');b.dispatchEvent(new Event('click'));f.name='other';const replacement=document.createElement('form');replacement.id='replacement';replacement.name='peer';document.body.appendChild(replacement);b.dispatchEvent(new Event('click'));const g=document.createElement('form');g.name='getElementById';document.body.appendChild(g);const clobbered=document.getElementById===g;g.remove();return JSON.stringify({trace,clobbered,restored:typeof document.getElementById})})()`,
},{
 name:'Named scopes omit shadow template and namespaced attributes while retaining SVG IDs',
 html:'<!doctype html><div id=host></div><template><form name=inertName id=inertID></form></template><svg><g id=svgID></g></svg>',
 action:`(()=>{const root=document.getElementById('host').attachShadow({mode:'open'});root.innerHTML='<form name=shadowName id=shadowID></form>';const f=document.createElement('form');f.setAttributeNS('urn:x','name','foreignName');f.setAttributeNS('urn:x','id','foreignID');document.body.appendChild(f);const initial=[typeof window.shadowID,typeof document.shadowName,typeof window.inertID,typeof document.inertName,typeof window.foreignID,typeof document.foreignName,window.svgID===document.querySelector('g'),typeof document.svgID];f.removeAttributeNS('urn:x','name');f.setAttribute('name','ordinary');const ordinary=document.ordinary===f;f.remove();return JSON.stringify({initial,ordinary,removed:typeof window.ordinary})})()`,
},{
 name:'Repeated duplicate named reads reuse live collections through membership changes',
 html:'<!doctype html><form id=f><input name=peer><input name=peer></form><form name=group></form><img name=group><div id=duplicate></div><span id=duplicate></span>',
 action:`(()=>{const f=document.getElementById('f'),win=window.duplicate,doc=document.group,list=f.peer,initial=[win===window.duplicate,doc===document.group,list===f.peer];document.querySelector('span').remove();f.firstElementChild.remove();document.querySelector('img').remove();const single=[win.length,doc.length,list.length];const a=document.createElement('input');a.name='peer';f.appendChild(a);const s=document.createElement('span');s.id='duplicate';document.body.appendChild(s);const i=document.createElement('img');i.name='group';document.body.appendChild(i);return JSON.stringify({initial,single,again:[win===window.duplicate,doc===document.group,list===f.peer],lengths:[win.length,doc.length,list.length]})})()`,
},{
 name:'HTML named elements in detached and XHTML documents follow the Document getter algorithm',html:'<!doctype html><body></body>',
 specExpected:JSON.stringify({xml:['form',true,true],detached:['form',true],namespace:[false,false]}),
 nativeDifference:'Current HTML extends Document with its named getter without an active-window or HTML-document restriction. Chromium 154 exposes the tested names only in active HTMLDocument instances, omitting XHTML and detached HTML documents.',
 action:`(()=>{const xml=new DOMParser().parseFromString('<html xmlns="http://www.w3.org/1999/xhtml"><body><form name="peer"/></body></html>','application/xhtml+xml'),detached=document.implementation.createHTMLDocument();detached.body.innerHTML='<form name=peer></form>';const f=document.createElement('form'),input=document.createElement('input');input.setAttributeNS('urn:x','name','foreign');f.appendChild(input);document.body.appendChild(f);return JSON.stringify({xml:[xml.peer?.localName,xml instanceof XMLDocument,'peer' in xml],detached:[detached.peer?.localName,'peer' in detached],namespace:['foreign' in f,Object.hasOwn(f,'foreign')]})})()`,
},{
 name:'Named scope caches and live collections follow real cross-document adoption',
 html:'<!doctype html><body></body>',
 sourceHTML:'<!doctype html><form id=first name=group></form><form id=second name=group></form>',
 sourcePrep:`globalThis.winList=window.group;globalThis.docList=document.group;globalThis.moved=document.getElementById('first');`,
 sourceKeys:['winList','docList','moved'],
 action:`(()=>{document.body.appendChild(moved);const after=[winList.length,docList.length,foreignSource.group===foreignSource.document.getElementById('second'),document.group===moved,window.group===moved,typeof foreignSource.first,moved.ownerDocument===document];moved.name='renamed';const renamed=[typeof document.group,typeof window.group,document.renamed===moved,window.renamed===moved,winList.length];moved.remove();return JSON.stringify({after,renamed,removed:[typeof document.renamed,typeof window.first,winList.length,docList.length]})})()`,
},{
 name:'Command handlers and document visibility attributes use their actual interface targets',
 html:'<!doctype html><button id=sample oncommand="window.trace.push(event.type)">Run</button>',
 action:`(()=>{window.trace=[];const b=document.getElementById('sample');b.dispatchEvent(new Event('command'));document.onvisibilitychange=()=>trace.push('document');document.dispatchEvent(new Event('visibilitychange'));return JSON.stringify({trace,element:typeof b.onvisibilitychange,window:typeof window.onvisibilitychange,document:typeof document.onvisibilitychange})})()`,
}];
const moduleCases=[{
 name:'Content handler imports ignore the external script that first compiles the handler',await:true,
 specExpected:JSON.stringify(['document','compiler']),nativeDifference:'Chromium 154 resolves this trusted click content-handler import at its attribute document URL, ignoring the verified live document base. HTML get-current-value step 11 sets [[ScriptOrModule]] to null, so HostLoadImportedModule must use the current realm API base URL when no caller script is active.',
 html:`<!doctype html><base id=base href="@ORIGIN@/document/"><button id=sample onclick="return window.promise=import('./item.js').then(m=>m.default)">Run</button>`,
 prepURL:'@ORIGIN@/compiler/install.js',prep:`window.compiled=document.getElementById('sample').onclick;window.assigned=()=>import('./item.js').then(m=>m.default)`,
 moduleSources:{'@ORIGIN@/document/item.js':`export default 'document'`,'@ORIGIN@/compiler/item.js':`export default 'compiler'`,'@ORIGIN@/item.js':`export default 'document-url'`},hostActions:[{click:'sample'}],
 action:`Promise.all([promise,assigned()]).then(values=>JSON.stringify(values))`,
},{
 name:'Handler and nested function imports use the live document base on each invocation',await:true,
 specExpected:JSON.stringify(['initial','changed','compiler']),nativeDifference:'Chromium 154 retains the attribute document URL across genuine trusted clicks and changes to the verified document base. HTML null [[ScriptOrModule]] plus Window API base requires the current document base; ordinary externally assigned functions retain their script URL.',
 html:`<!doctype html><base id=base href="@ORIGIN@/initial/"><button id=sample onclick="return window.promise=(()=>import('./item.js').then(m=>m.default))()">Run</button>`,
 prepURL:'@ORIGIN@/compiler/install.js',prep:`window.compiled=document.getElementById('sample').onclick;window.assigned=()=>import('./item.js').then(m=>m.default)`,
 moduleSources:{'@ORIGIN@/initial/item.js':`export default 'initial'`,'@ORIGIN@/changed/item.js':`export default 'changed'`,'@ORIGIN@/compiler/item.js':`export default 'compiler'`,'@ORIGIN@/item.js':`export default 'document-url'`},
 hostActions:[{click:'sample'},{script:`window.first=window.promise;document.getElementById('base').href='@ORIGIN@/changed/'`},{click:'sample'}],
 action:`Promise.all([first,promise,assigned()]).then(values=>JSON.stringify(values))`,
},{
 name:'Source realm and destination realm retain independent live handler import bases after adoption',await:true,
 specExpected:JSON.stringify({values:['source-changed','destination'],unchanged:true}),nativeDifference:'Chromium 154 tries to resolve both trusted click handler imports against the original about:srcdoc attribute URL, yielding TypeError despite absolute live document bases. Under HTML null [[ScriptOrModule]], a compiled handler uses its original realm API base and an untouched adopted source compiles in the destination realm.',
 html:`<!doctype html><base id=base href="@ORIGIN@/destination/"><body></body>`,
 sourceHTML:`<!doctype html><base id=base href="@ORIGIN@/source/"><button id=compiled onclick="return window.promise=import('./item.js').then(m=>m.default)">Run</button><button id=uncompiled onclick="return window.promise=import('./item.js').then(m=>m.default)">Run</button>`,
 sourcePrep:`globalThis.compiled=document.getElementById('compiled');globalThis.uncompiled=document.getElementById('uncompiled');globalThis.original=compiled.onclick`,
 moduleSources:{'@ORIGIN@/source/item.js':`export default 'source'`,'@ORIGIN@/source-changed/item.js':`export default 'source-changed'`,'@ORIGIN@/destination/item.js':`export default 'destination'`,'@ORIGIN@/item.js':`export default 'document-url'`},
 hostActions:[{script:`document.body.appendChild(compiled);document.body.appendChild(uncompiled);foreignSource.document.getElementById('base').href='@ORIGIN@/source-changed/'`},{click:'compiled'},{click:'uncompiled'}],
 action:`Promise.all([foreignSource.promise.catch(e=>e.name),promise.catch(e=>e.name)]).then(values=>JSON.stringify({values,unchanged:compiled.onclick===original}))`,
},{
 name:'Direct eval inside a handler retains the null script import context',await:true,
 specExpected:JSON.stringify({value:'document'}),nativeDifference:'Chromium 154 retains the attribute document URL through direct eval in this trusted click handler. Under HTML null [[ScriptOrModule]], direct eval inherits a null script context and uses the current realm API base.',
 html:`<!doctype html><base id=base href="@ORIGIN@/document/"><button id=sample onclick="return window.promise=eval(&quot;import('./item.js').then(m=>m.default)&quot;)">Run</button>`,
 prepURL:'@ORIGIN@/compiler/install.js',prep:`window.compiled=document.getElementById('sample').onclick`,
 moduleSources:{'@ORIGIN@/document/item.js':`export default 'document'`,'@ORIGIN@/compiler/item.js':`export default 'compiler'`,'@ORIGIN@/item.js':`export default 'document-url'`},
 hostActions:[{click:'sample'}],action:`promise.then(value=>JSON.stringify({value}))`,
},{
 name:'Script-driven handler imports use the nearest caller rather than its compiler script',await:true,
 specExpected:JSON.stringify(['caller','compiler']),nativeDifference:'Chromium 154 retains the attribute document URL even when an external script function directly invokes the compiled handler. HTML sets its [[ScriptOrModule]] to null; ECMAScript GetActiveScriptOrModule selects the topmost non-null caller execution context.',
 html:`<!doctype html><base id=base href="@ORIGIN@/document/"><button id=sample onclick="return import('./item.js').then(m=>m.default)">Run</button>`,
 prepURL:'@ORIGIN@/compiler/install.js',prep:`window.compiled=document.getElementById('sample').onclick;window.invoke=()=>compiled.call(sample)`,
 moduleSources:{'@ORIGIN@/document/item.js':`export default 'document'`,'@ORIGIN@/compiler/item.js':`export default 'compiler'`,'@ORIGIN@/item.js':`export default 'caller'`},
 action:`Promise.all([compiled.call(sample),invoke()]).then(values=>JSON.stringify(values))`,
},{
 name:'Async functions created by a host handler preserve null context after await',await:true,
 specExpected:JSON.stringify({value:'document'}),nativeDifference:'Chromium 154 retains the attribute document URL in the nested async function. HTML null [[ScriptOrModule]] and the resumed function realm API base require the current document base.',
 html:`<!doctype html><base id=base href="@ORIGIN@/document/"><button id=sample onclick="window.promise=(async()=>{await Promise.resolve();return import('./item.js').then(m=>m.default)})()">Run</button>`,
 moduleSources:{'@ORIGIN@/document/item.js':`export default 'document'`,'@ORIGIN@/item.js':`export default 'document-url'`},hostActions:[{click:'sample'}],
 action:`promise.then(value=>JSON.stringify({value}))`,
},{
 name:'A throwing external function does not leak its import context into a handler catch',await:true,
 specExpected:JSON.stringify({value:'document',trace:['caught']}),nativeDifference:'Chromium 154 retains the attribute document URL for the content handler; the caught external function context is nevertheless removed. HTML null [[ScriptOrModule]] requires the current realm API base after the catch.',
 html:`<!doctype html><base id=base href="@ORIGIN@/document/"><button id=sample onclick="try{thrower()}catch(error){window.trace.push('caught');window.promise=import('./item.js').then(m=>m.default)}">Run</button>`,
 prepURL:'@ORIGIN@/compiler/install.js',prep:`window.trace=[];window.thrower=()=>{throw new Error('caught external error')}`,
 moduleSources:{'@ORIGIN@/document/item.js':`export default 'document'`,'@ORIGIN@/compiler/item.js':`export default 'compiler'`,'@ORIGIN@/item.js':`export default 'document-url'`},hostActions:[{click:'sample'}],
 action:`promise.then(value=>JSON.stringify({value,trace}))`,
},{
 name:'Resource disposal restores a throwing caller context before invoking dispose callbacks',await:true,
 specExpected:JSON.stringify({value:'document',trace:['dispose','caught']}),nativeDifference:'Chromium 154 retains the attribute document URL for the content handler and disposer. Under HTML null [[ScriptOrModule]], the throwing external context must be popped before the disposer uses the current realm API base.',
 html:`<!doctype html><base id=base href="@ORIGIN@/document/"><button id=sample onclick="try{{using resource={[Symbol.dispose](){window.trace.push('dispose');window.promise=import('./item.js').then(m=>m.default)}};thrower()}}catch(error){window.trace.push('caught')}">Run</button>`,
 prepURL:'@ORIGIN@/compiler/install.js',prep:`window.trace=[];window.thrower=()=>{throw new Error('caught external error')}`,
 moduleSources:{'@ORIGIN@/document/item.js':`export default 'document'`,'@ORIGIN@/compiler/item.js':`export default 'compiler'`,'@ORIGIN@/item.js':`export default 'document-url'`},hostActions:[{click:'sample'}],
 action:`promise.then(value=>JSON.stringify({value,trace}))`,
},{
 name:'A suspended null-script generator uses its actual resume caller for finally imports',await:true,
 specExpected:JSON.stringify({value:'compiler',first:1,done:true}),nativeDifference:'Chromium 154 retains the attribute document URL in the nested generator. Under HTML null [[ScriptOrModule]], ECMAScript GetActiveScriptOrModule selects the external function which resumes the null-script generator.',
 html:`<!doctype html><base id=base href="@ORIGIN@/document/"><button id=sample onclick="window.iterator=(function*(){try{yield 1}finally{window.promise=import('./item.js').then(m=>m.default)}})();window.first=iterator.next().value">Run</button>`,
 prepURL:'@ORIGIN@/compiler/install.js',prep:`window.resume=()=>iterator.return(0)`,
 moduleSources:{'@ORIGIN@/document/item.js':`export default 'document'`,'@ORIGIN@/compiler/item.js':`export default 'compiler'`,'@ORIGIN@/item.js':`export default 'document-url'`},hostActions:[{click:'sample'}],
 action:`(()=>{const done=resume().done;return promise.then(value=>JSON.stringify({value,first,done}))})()`,
},{
 name:'Cross-realm caller script supplies its own import map to a null-script handler',await:true,
 specExpected:JSON.stringify({value:'destination',sourcePromise:true}),nativeDifference:'Chromium 154 keeps the original attribute document import context and therefore its source import map. Under HTML null [[ScriptOrModule]], the nearest active external caller supplies both its URL and settings object/import map. The import expression promise still belongs to the source function realm.',
 html:`<!doctype html><base id=base href="@ORIGIN@/destination/"><script type=importmap>{"imports":{"channel":"@ORIGIN@/destination/item.js"}}</script><body></body>`,
 sourceHTML:`<!doctype html><base id=base href="@ORIGIN@/source/"><script type=importmap>{"imports":{"channel":"@ORIGIN@/source/item.js"}}</script><button id=compiled onclick="return import('channel')">Run</button>`,
 sourcePrep:`globalThis.compiled=document.getElementById('compiled');globalThis.original=compiled.onclick`,sourceKeys:['compiled','original'],
 importMap:{Imports:{channel:'@ORIGIN@/destination/item.js'}},sourceImportMap:{Imports:{channel:'@ORIGIN@/source/item.js'}},
 prepURL:'@ORIGIN@/compiler/install.js',prep:`document.body.appendChild(compiled);window.invoke=()=>compiled.onclick.call(compiled)`,
 moduleSources:{'@ORIGIN@/source/item.js':`export default 'source'`,'@ORIGIN@/destination/item.js':`export default 'destination'`},
 action:`(()=>{const pending=invoke(),sourcePromise=Object.getPrototypeOf(pending)===foreignSource.Promise.prototype;return pending.then(m=>JSON.stringify({value:m.default,sourcePromise}))})()`,
},{
 name:'A nested source-realm function captures the foreign active script settings independently of its function realm',await:true,
 specExpected:JSON.stringify({value:'destination',sourceRealm:true,sourcePromise:true}),nativeDifference:'Chromium 154 inherits the original attribute document script/import map in the nested function. Under HTML null [[ScriptOrModule]], function creation captures the actual foreign active caller script, while its Function and Promise prototypes/realms stay the source realm.',
 html:`<!doctype html><base id=base href="@ORIGIN@/destination/"><script type=importmap>{"imports":{"channel":"@ORIGIN@/destination/item.js"}}</script><body></body>`,
 sourceHTML:`<!doctype html><base id=base href="@ORIGIN@/source/"><script type=importmap>{"imports":{"channel":"@ORIGIN@/source/item.js"}}</script><button id=compiled onclick="return ()=>import('channel')">Run</button>`,
 sourcePrep:`globalThis.compiled=document.getElementById('compiled');globalThis.original=compiled.onclick`,sourceKeys:['compiled','original'],
 importMap:{Imports:{channel:'@ORIGIN@/destination/item.js'}},sourceImportMap:{Imports:{channel:'@ORIGIN@/source/item.js'}},
 prepURL:'@ORIGIN@/compiler/install.js',prep:`document.body.appendChild(compiled);window.invoke=()=>compiled.onclick.call(compiled)`,
 moduleSources:{'@ORIGIN@/source/item.js':`export default 'source'`,'@ORIGIN@/destination/item.js':`export default 'destination'`},
 action:`(()=>{const inner=invoke(),sourceRealm=Object.getPrototypeOf(inner)===foreignSource.Function.prototype,pending=inner(),sourcePromise=Object.getPrototypeOf(pending)===foreignSource.Promise.prototype;return pending.then(m=>JSON.stringify({value:m.default,sourceRealm,sourcePromise}))})()`,
}];
async function capture(){
 let routes={};const server=http.createServer((request,response)=>{const value=routes[request.url];response.setHeader('Access-Control-Allow-Origin','*');response.setHeader('Content-Type',request.url==='/handler-case.html'?'text/html':'text/javascript');response.statusCode=value===undefined?404:200;response.end(value??'missing native fixture')});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const origin='http://127.0.0.1:'+server.address().port;
 cases.push(...JSON.parse(JSON.stringify(moduleCases).replaceAll('@ORIGIN@',origin)));
 let browser;const fixture={captured:'2026-10-10',standard:'https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-content-attributes',cases};
 const externalPrep=(target,url)=>`new Promise((resolve,reject)=>{const script=${target}.document.createElement('script');script.src=${JSON.stringify(url)};script.onload=resolve;script.onerror=reject;${target}.document.head.appendChild(script)})`;
 try{
  browser=await openBrowser(folder);
  fixture.browser=await browser.evaluate('navigator.userAgent');
  for(const c of cases){
   routes={};for(const [url,source]of Object.entries(c.moduleSources||{}))routes[new URL(url).pathname]=source;if(c.prepURL)routes[new URL(c.prepURL).pathname]=c.prep;
   if(c.moduleSources){
    routes['/handler-case.html']=c.html;const url=origin+'/handler-case.html';c.url=url;await browser.send('Page.navigate',{url});
    let loaded=false;for(let attempt=0;attempt<50;attempt++){try{loaded=await browser.evaluate(`document.URL===${JSON.stringify(url)}&&document.readyState==='complete'`)}catch(error){if(!/context|navigat/i.test(error.message))throw error}if(loaded)break;await new Promise(resolve=>setTimeout(resolve,20))}if(!loaded)throw new Error('Native module case did not load: '+c.name);
   }else await browser.load(c.html);
   if(c.sourceHTML)await browser.evaluate(`(async()=>{const frame=document.createElement('iframe'),loaded=new Promise(resolve=>frame.onload=resolve);frame.srcdoc=${JSON.stringify(c.sourceHTML)};document.body.appendChild(frame);await loaded;globalThis.foreignSource=frame.contentWindow;foreignSource.eval(${JSON.stringify(c.sourcePrep)});for(const key of ${JSON.stringify(c.sourceKeys||['compiled','uncompiled','original'])})globalThis[key]=foreignSource[key]})()`);
   if(c.prep)await browser.evaluate(c.prepURL?externalPrep('window',c.prepURL):c.prep);
   if(c.hostActions)await browser.evaluate(`window.trustedEvents=[];document.addEventListener('click',e=>trustedEvents.push({trusted:e.isTrusted,baseURI:document.baseURI}),true)`);
   for(const host of c.hostActions||[]){
    if(host.script)await browser.evaluate(host.script);
    else{const rect=await browser.evaluate(`(()=>{const r=document.getElementById(${JSON.stringify(host.click)}).getBoundingClientRect();return{x:r.x+r.width/2,y:r.y+r.height/2}})()`);await browser.send('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,...rect});await browser.send('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,...rect})}
   }
   try{c.expected=await browser.evaluate(c.action);if(c.hostActions)c.nativeHostEvents=await browser.evaluate('trustedEvents')}catch(error){throw new Error(c.name+': '+error.message)}
  }
 }finally{try{if(browser)await browser.close()}finally{await new Promise(resolve=>server.close(resolve))}}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/event-handler-attributes-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('HTML event handler attributes: '+cases.length+' native sequences captured.');
}
capture().catch(error=>{console.error(error);process.exitCode=1});
