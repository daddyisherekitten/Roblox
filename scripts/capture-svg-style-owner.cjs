// Isolated native SVG stylesheet-owner reference; never attaches to user browsers.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const html='<!doctype html><html><head><style>body{margin:0}#target{color:rgb(0,0,0)}#rect{fill:rgb(0,0,0)}</style></head><body><div id="target">Outer</div><div id="holder"></div></body></html>';
const source=String.raw`function ownerProbe(mode,name){
 const SVG='http://www.w3.org/2000/svg',holder=document.getElementById('holder');
 const shadow=mode.indexOf('shadow')===0;
 const root=shadow?holder.attachShadow({mode:'open'}):document;
 const container=shadow?root:holder;
 if(shadow){const base=document.createElement('style');base.textContent='#target{color:rgb(0,0,0)}#rect{fill:rgb(0,0,0)}';root.append(base);}
 const target=shadow?document.createElement('div'):document.getElementById('target');
 if(shadow){target.id='target';target.textContent='Inner';container.append(target);}
 const svg=document.createElementNS(SVG,'svg');
 const rect=document.createElementNS(SVG,'rect');rect.id='rect';svg.append(rect);container.append(svg);
 const style=document.createElementNS(SVG,name);
 const parent=mode.indexOf('inside')>=0?svg:container;
 const css=n=>'#target{color:rgb('+n+',20,30)}#rect{fill:rgb('+n+',20,30)}';
 style.append(document.createTextNode(css(10)));parent.append(style);
 function snapshot(previous){const sheet=style.sheet;return {
  color:getComputedStyle(target).color,outer:getComputedStyle(document.getElementById('target')).color,fill:getComputedStyle(rect).fill,
  display:getComputedStyle(style).display,sheet:sheet===undefined?'undefined':sheet===null?'null':'object',disabled:typeof style.disabled,reflectedType:style.type,reflectedMedia:style.media,reflectedTitle:style.title,
  rootCount:root.styleSheets.length,rootListed:Array.from(root.styleSheets).some(s=>s.ownerNode===style),documentListed:Array.from(document.styleSheets).some(s=>s.ownerNode===style),
  owner:sheet?sheet.ownerNode===style:false,ruleCount:sheet?sheet.cssRules.length:null,rules:sheet?Array.from(sheet.cssRules,r=>r.cssText):null,
  samePrevious:previous===undefined?null:sheet===previous,oldOwner:previous?previous.ownerNode===style:false};}
 const rows=[];let previous;
 function take(label){rows.push({label,...snapshot(previous)});previous=style.sheet;}
 take('initial');
 style.firstChild.data=style.firstChild.data;take('identical direct Text.data');
 style.textContent=style.textContent;take('identical style.textContent');
 const comment=document.createComment('ignore #target{color:red}');style.append(comment);take('append direct Comment');
 comment.data=comment.data;take('identical direct Comment.data');
 const span=document.createElement('span');span.append(document.createTextNode(css(70)));style.append(span);take('append child Element with CSS text');
 span.firstChild.data=css(80);take('change grandchild Text.data');
 span.append(document.createTextNode(css(90)));take('append grandchild Text');
 const xml=document.implementation.createDocument(SVG,'svg',null);
 const cdata=xml.createCDATASection(css(40));style.append(cdata);take('append direct CDATA from XML document');
 cdata.data=cdata.data;take('identical direct CDATA.data');
 cdata.data=css(50);take('change direct CDATA.data');
 style.removeChild(cdata);take('remove direct CDATA');
 style.sheet.insertRule('#target{color:rgb(60,20,30)}',style.sheet.cssRules.length);style.sheet.insertRule('#rect{fill:rgb(60,20,30)}',style.sheet.cssRules.length);take('insertRule overlay');
 style.setAttribute('type','not/css');take('live invalid type');
 style.firstChild.data=style.firstChild.data;take('identical direct Text.data with invalid type');
 style.setAttribute('type','text/css');take('restore type alone after invalid update');
 style.firstChild.data=style.firstChild.data;take('identical direct Text.data with restored type');
 for(const type of ['TeXt/CsS',' text/css ','text/css;charset=utf-8','']){
  style.setAttribute('type',type);take('live type '+JSON.stringify(type));
  style.firstChild.data=style.firstChild.data;take('direct Text.data after type '+JSON.stringify(type));
 }
 if(shadow){const old=style.sheet;holder.append(style);take('move owner from ShadowRoot to Document');rows[rows.length-1].oldSheetOwnerIsNull=old.ownerNode===null;rows[rows.length-1].oldRootListed=Array.from(root.styleSheets).some(s=>s===old);}
 const old=style.sheet;style.remove();take('remove owner');rows[rows.length-1].oldSheetOwnerIsNull=old?old.ownerNode===null:null;
 return{mode,name,rows};
}`;
const xmlSource=String.raw`function xmlOwnerProbe(){
 const style=document.getElementById('owner'),rect=document.getElementById('rect');
 const rows=[];let previous;
 function take(label){const sheet=style.sheet;rows.push({label,documentType:document.contentType,color:getComputedStyle(rect).fill,display:getComputedStyle(style).display,sheet:sheet===undefined?'undefined':sheet===null?'null':'object',listed:Array.from(document.styleSheets).some(s=>s.ownerNode===style),owner:sheet?sheet.ownerNode===style:false,ruleCount:sheet?sheet.cssRules.length:null,rules:sheet?Array.from(sheet.cssRules,r=>r.cssText):null,samePrevious:previous===undefined?null:sheet===previous,oldOwner:previous?previous.ownerNode===style:false,children:Array.from(style.childNodes,n=>({type:n.nodeType,name:n.nodeName,data:n.nodeType===3||n.nodeType===4||n.nodeType===8?n.data||null:null}))});previous=sheet;}
 take('parsed XML CDATA initial');
 style.firstChild.data=style.firstChild.data;take('identical parsed CDATA.data');
 const text=document.createTextNode('#rect{fill:rgb(40,50,60)}');style.append(text);take('append direct Text after CDATA');
 const cdata=document.createCDATASection('#rect{fill:rgb(70,80,90)}');style.append(cdata);take('append direct CDATA after Text');
 cdata.data='#rect{fill:rgb(90,80,70)}';take('change direct CDATA');
 const nested=document.createElementNS('http://www.w3.org/2000/svg','g');nested.append(document.createTextNode('#rect{fill:rgb(100,110,120)}'));style.append(nested);take('append child Element with CSS text');
 nested.firstChild.data='#rect{fill:rgb(120,110,100)}';take('change grandchild Text');
 style.remove();take('remove XML owner');return{rows};
}`;
const typeSource=String.raw`function typeProbe(namespace,foreign){
 const style=document.createElementNS(namespace,'style'),target=document.getElementById('target');style.textContent='#target{color:rgb(10,20,30)}';document.body.append(style);
 const rows=[];let previous;
 function take(label){const sheet=style.sheet;rows.push({label,color:getComputedStyle(target).color,sheet:sheet===null?'null':typeof sheet,noNSType:style.getAttributeNS(null,'type'),foreignType:style.getAttributeNS('urn:foreign','type'),attributes:Array.from(style.attributes,a=>({name:a.name,namespace:a.namespaceURI,value:a.value})),samePrevious:previous===undefined?null:sheet===previous,oldOwner:previous?previous.ownerNode===style:false});previous=sheet;}
 take('initial');
 if(foreign!=='none'){style.setAttributeNS('urn:foreign',foreign==='prefixed'?'f:type':'type','invalid');take('add foreign type');}
 style.setAttribute('type','not/css');take('setAttribute type invalid');
 style.setAttributeNS(null,'type','not/css');take('setAttributeNS null type invalid');
 style.firstChild.data=style.firstChild.data;take('identical direct Text with invalid type');
 style.setAttributeNS(null,'type','text/css');take('restore noNS type alone');
 style.firstChild.data=style.firstChild.data;take('identical direct Text after restore');
 return{namespace,foreign,rows};
}`;
const controlSource=String.raw`function directOwnerControl(mode){
 const style=document.createElement('style');style.textContent='.x{color:red}';document.body.append(style);
 const rows=[];let previous;
 function take(label){const sheet=style.sheet;rows.push({label,count:sheet?sheet.cssRules.length:null,rules:sheet?Array.from(sheet.cssRules,r=>r.cssText):null,samePrevious:previous===undefined?null:sheet===previous,oldOwner:previous?previous.ownerNode===style:false});previous=sheet;}
 take('initial HTML control');style.firstChild.data=style.firstChild.data;take('identical direct Text control');
 if(mode==='descendant'){const span=document.createElement('span');span.textContent='.x{color:blue}';style.append(span);take('append direct Element control');span.firstChild.data='.x{color:green}';take('change grandchild Text control');}
 else{const xml=document.implementation.createDocument(null,null,null);const cdata=xml.createCDATASection('.x{color:blue}');style.append(cdata);take('append direct CDATA control');cdata.data='.x{color:green}';take('change direct CDATA control');}
 style.remove();return rows;
}`;
const reflectionSource=String.raw`function reflectionProbe(namespace,name){
 const style=document.createElementNS(namespace,name);style.textContent='#target{color:rgb(10,20,30)}';document.body.append(style);const rows=[];
 function take(label){rows.push({label,typeKind:typeof style.type,mediaKind:typeof style.media,titleKind:typeof style.title,typeValue:style.type,mediaValue:style.media,titleValue:style.title,typeAttribute:style.getAttributeNS(null,'type'),mediaAttribute:style.getAttributeNS(null,'media'),titleAttribute:style.getAttributeNS(null,'title'),color:getComputedStyle(document.getElementById('target')).color});}
 take('initial reflection');style.type='text/css';style.media='not all';style.title='owner title';take('set reflected properties');style.setAttributeNS(null,'media','all');style.setAttributeNS(null,'title','changed title');take('set genuine attributes');style.remove();return{namespace,name,rows};
}`;
const importSource=String.raw`async function importOwnerProbe(){
 const one='data:text/css,.one%7Bcolor%3Ared%7D',two='data:text/css,.two%7Bcolor%3Ablue%7D';
 const style=document.createElement('style');style.textContent='@import url("'+one+'");';document.body.append(style);
 async function settle(){for(let i=0;i<40;i++){if(Array.from(style.sheet.cssRules).every(r=>r.styleSheet))return;await new Promise(r=>setTimeout(r,25));}throw Error('Native data import failed to settle');}
 function snapshot(label,old){return{label,oldOwner:old?old.ownerNode===style:null,rules:Array.from(style.sheet.cssRules,r=>({href:r.href,sheetHref:r.styleSheet?r.styleSheet.href:null,selectors:r.styleSheet?Array.from(r.styleSheet.cssRules,q=>q.selectorText):null}))};}
 await settle();const rows=[snapshot('source import initial')],old=style.sheet;
 old.insertRule('@import url("'+two+'");',0);await settle();rows.push(snapshot('CSSOM import inserted before source import',old));
 style.firstChild.data=style.firstChild.data;await settle();rows.push(snapshot('identical direct Text resets import graph',old));
 style.remove();return{one,two,rows};
}`;
const retainedHTML='<!doctype html><html><head><style>body{margin:0;color:#000}#target{width:220px;height:60px}#notes{color:inherit;width:110px}#outside{width:20px;height:10px}</style></head><body><div id="target" class="one two">Surface<input id="notes" value="kept"></div><div id="outside">Outside</div></body></html>';
const retainedCodes=[
 ['SVG prefixed owner','const input=document.getElementById("notes");input.value="edited";input.setSelectionRange(1,3,"backward");const owner=document.createElementNS("http://www.w3.org/2000/svg","s:style");owner.id="owner";owner.textContent="#target{color:rgb(10,20,30)}";document.body.append(owner);'],
 ['disabled owner','owner.disabled=true;'],['enabled owner','owner.disabled=false;'],
 ['media off','owner.media="not all";'],['media on','owner.media="all";'],
 ['direct source replacement','const first=owner.sheet;owner.textContent="#target{color:rgb(40,50,60)}";if(owner.sheet===first||first.ownerNode!==null)throw Error("source association");'],
 ['CSSOM override','owner.sheet.insertRule("#target{color:rgb(70,80,90)}",1);'],
 ['direct element resets overlay','const span=document.createElement("span");span.textContent="#target{color:red}";owner.append(span);const beforeGrandchild=owner.sheet;'],
 ['grandchild retains source','span.firstChild.data="#target{color:blue}";if(owner.sheet!==beforeGrandchild)throw Error("grandchild replaced sheet");'],
 ['direct CDATA source','const xml=document.implementation.createDocument(null,null,null);const cdata=xml.createCDATASection("#target{color:rgb(90,100,110)}");owner.append(cdata);'],
 ['identical CDATA resets overlay','owner.sheet.cssRules[1].style.color="rgb(200,100,50)";const beforeCDATA=owner.sheet;cdata.data=cdata.data;if(owner.sheet===beforeCDATA||beforeCDATA.ownerNode!==null)throw Error("CDATA association");'],
 ['foreign type remains inert','owner.setAttributeNS("urn:foreign","f:type","not/css");'],
 ['never rendered SVG metadata','owner.style.display="block";'],
 ['source import','owner.textContent="@import url(data:text/css,.one%7Bcolor%3Ared%7D);";'],
 ['CSSOM import overlay','owner.sheet.insertRule("@import url(data:text/css,.two%7Bcolor%3Ablue%7D);",0);'],
 ['identical Text resets imports','owner.firstChild.data=owner.firstChild.data;'],
 ['remove owner','const detached=owner.sheet;owner.remove();if(owner.sheet!==null||detached.ownerNode!==null)throw Error("detached owner");'],
 ['reconnect owner','document.body.append(owner);if(owner.sheet===detached)throw Error("reconnected sheet");'],
];
(async()=>{const browser=await openBrowser(path.resolve(__dirname,'../build'));try{
 const cases=[];
 for(const [mode,name] of [['outside','style'],['inside','style'],['inside','s:style'],['shadow-outside','style'],['shadow-inside','style'],['shadow-inside','s:style']]){
  await browser.load(html);cases.push(await browser.evaluate(source+'\nownerProbe('+JSON.stringify(mode)+','+JSON.stringify(name)+')'));
 }
 const typeCases=[];
 for(const namespace of ['http://www.w3.org/1999/xhtml','http://www.w3.org/2000/svg'])for(const foreign of ['none','prefixed','unprefixed']){await browser.load(html);typeCases.push(await browser.evaluate(typeSource+'\ntypeProbe('+JSON.stringify(namespace)+','+JSON.stringify(foreign)+')'));}
 const controlCases=[];for(const mode of ['descendant','cdata']){await browser.load(html);controlCases.push({mode,rows:await browser.evaluate(controlSource+'\ndirectOwnerControl('+JSON.stringify(mode)+')')});}
 const reflectionCases=[];for(const [namespace,name] of [['http://www.w3.org/2000/svg','style'],['http://www.w3.org/2000/svg','s:style'],['http://www.w3.org/1999/xhtml','h:style'],['urn:foreign','style'],[null,'style']]){await browser.load(html);reflectionCases.push(await browser.evaluate(reflectionSource+'\nreflectionProbe('+JSON.stringify(namespace)+','+JSON.stringify(name)+')'));}
 await browser.load(html);const importCase=await browser.evaluate(importSource+'\nimportOwnerProbe()');
 await browser.load(retainedHTML);const retained=[];
 for(const [name,code] of retainedCodes){await browser.evaluate(code);await browser.evaluate('(async()=>{const el=document.getElementById("owner");if(!el||!el.sheet)return;for(let i=0;i<40;i++){if(Array.from(el.sheet.cssRules).filter(r=>r.type===3).every(r=>r.styleSheet))return;await new Promise(r=>setTimeout(r,25));}throw Error("Retained import did not settle");})()');const expected=await browser.evaluate('(()=>{const el=document.getElementById("owner"),s=el&&el.sheet,input=document.getElementById("notes");return{color:getComputedStyle(document.getElementById("target")).color,value:input.value,selectionStart:input.selectionStart,selectionEnd:input.selectionEnd,selectionDirection:input.selectionDirection,count:s?s.cssRules.length:null,owner:s?s.ownerNode===el:false,listed:Array.from(document.styleSheets).some(s=>s.ownerNode===el)}})()');retained.push({name,code,expected});}
 const xml='<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><style id="owner"><![CDATA[#rect{fill:rgb(10,20,30)}]]></style><rect id="rect" width="10" height="10"/></svg>';
 await browser.send('Page.navigate',{url:'data:image/svg+xml;charset=utf-8,'+encodeURIComponent(xml)});
 // Evaluate only once navigation has settled, without attaching to user surfaces.
 for(let i=0;i<20;i++){if(await browser.evaluate('document.contentType==="image/svg+xml" && !!document.getElementById("owner")'))break;await new Promise(r=>setTimeout(r,50));}
 const xmlCase=await browser.evaluate(xmlSource+'\nxmlOwnerProbe()');
 // Preserve fill declarations/pixels verbatim. This owner slice does not claim
 // the existing SVG-fill CSSOM serializer or alternate titled-sheet selection.
 for(const row of xmlCase.rows)row.ruleCount=row.rules?row.rules.length:null;
 const comparisonKeys={owner:['label','color','outer','sheet','disabled','reflectedType','reflectedMedia','reflectedTitle','rootCount','rootListed','documentListed','owner','ruleCount','samePrevious','oldOwner','oldSheetOwnerIsNull','oldRootListed'],type:['label','color','sheet','noNSType','foreignType','attributes','samePrevious','oldOwner'],reflection:['label','typeKind','mediaKind','titleKind','typeValue','mediaValue','titleValue','typeAttribute','mediaAttribute','titleAttribute'],xml:['label','documentType','sheet','listed','owner','ruleCount','samePrevious','oldOwner','children']};
 const expected=(rows,keys)=>rows.map(r=>JSON.stringify(Object.fromEntries(keys.filter(k=>r[k]!==undefined).map(k=>[k,r[k]]))));
 for(const c of cases)c.expectedJSON=expected(c.rows,comparisonKeys.owner);
 for(const c of typeCases)c.expectedJSON=expected(c.rows,comparisonKeys.type);
 for(const c of reflectionCases)c.expectedJSON=expected(c.rows,comparisonKeys.reflection);
 for(const c of controlCases)c.expectedJSON=c.rows.map(r=>JSON.stringify(r));
 importCase.expectedJSON=importCase.rows.map(r=>JSON.stringify(r));
 xmlCase.expectedJSON=expected(xmlCase.rows,comparisonKeys.xml);
 const result={html,source,xml,xmlSource,typeSource,controlSource,reflectionSource,importSource,cases,typeCases,controlCases,reflectionCases,importCase,xmlCase,retainedHTML,retained,comparisonKeys,userAgent:await browser.evaluate('navigator.userAgent'),standardDisplay:{expected:'none',source:'https://www.w3.org/TR/SVG2/styling.html#StyleElement'},typeBoundary:{source:'https://html.spec.whatwg.org/multipage/semantics.html#update-a-style-block',note:'The listed standard triggers omit type alone; raw genuine no-namespace Chromium type updates are preserved. The predecessor used a foreign unprefixed type attribute.'}};
 fs.writeFileSync(path.join(__dirname,'../tests/fixtures/svg-style-owner-browser.json'),JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({cases:cases.map(c=>({mode:c.mode,name:c.name,rows:c.rows.length})),typeCases:typeCases.length,xmlRows:xmlCase.rows.length}));
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
