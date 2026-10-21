// Frozen target source and genuine isolated CDP input. Raw results are never
// overwritten with the specified first-shape precedence expectations.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {openBrowser}=require('./native-browser.cjs');
const folder=path.resolve(__dirname,'../build/image-map-reference');
const commit='ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c';
const sourceURL='https://raw.githubusercontent.com/whatwg/html/'+commit+'/source';
const image='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="192" height="128"><rect width="192" height="128" fill="#ddd"/></svg>');
const base='<style>body{margin:0}#stage{padding:180px 0 0 220px}img{display:block;width:192px;height:128px;border:0;padding:0}</style>';
function html(extra='',usemap='#a'){return '<!doctype html>'+base+'<div id="stage"><img id="image" src="'+image+'"'+(usemap===null?'':' usemap="'+usemap+'"')+'>'+extra+'</div>';}
const full='<map id="mapA" name="a"><area id="areaA" shape="default" href="#a"></map><map id="mapB" name="b"><area id="areaB" shape="default" href="#b"></map>';
const points=[[30,30],[80,80]];
const cases=[];
cases.push({name:'live association',html:html(full),steps:[
 ['initial',''],['useMap b','image.useMap="#b"'],['unknown','image.useMap="#missing"'],['no useMap','image.removeAttribute("usemap")'],['restore a','image.useMap="#a"'],
 ['name renamed','mapA.name="renamed"'],['useMap renamed','image.useMap="#renamed"'],
 ['replace map','globalThis.replacement=document.createElement("map");replacement.name="renamed";replacement.id="replacement";replacement.innerHTML="<area id=areaReplacement shape=default href=#replacement>";mapA.replaceWith(replacement)'],
 ['detach map','replacement.remove()'],['reinsert map','stage.append(replacement)'],
 ['duplicate first','globalThis.duplicate=document.createElement("map");duplicate.name="renamed";duplicate.id="duplicate";duplicate.innerHTML="<area id=areaDuplicate shape=default href=#duplicate>";stage.prepend(duplicate)'],
 ['duplicate last','stage.append(duplicate)'],['remove primary','replacement.remove()'],['restore a map','duplicate.name="a";image.useMap="#a"'],
 ['case mismatch','image.useMap="#A"'],['hash percent','image.useMap="#%61"'],['leading space','image.useMap=" #a"'],['absolute fragment','image.useMap="https://example.test/#a"'],
 ['id alone','duplicate.removeAttribute("name");duplicate.id="a";image.useMap="#a"'],['name restore','duplicate.name="a"']
 ],points:[[30,30]]});
for(const shape of [null,'','rect','RECT','rectangle','Rectangle','unknown',' rect ','circle','CIRCLE','circ','Circ','poly','POLY','polygon','Polygon','default','DEFAULT',' circle ',' default ']){
 const attrs=shape===null?'':' shape="'+shape+'"';
 const shapeClass=shape?.toLowerCase();
 const coords=['circle','circ'].includes(shapeClass)?'40,40,20': ['poly','polygon'].includes(shapeClass)?'10,10,60,10,10,60':'10,10,60,60';
 cases.push({name:'shape '+JSON.stringify(shape),html:html('<map name="a" id="mapA"><area id="subject"'+attrs+' coords="'+coords+'" href="#subject"><area id="fallback" shape="default" href="#fallback"></map>'),steps:[['initial','']],points});
}
for(const [label,shape,coords,probe] of [
 ['zero radius','circle','40,40,0',[[40,40],[41,40]]],['negative radius','circle','40,40,-1',[[40,40]]],['circle boundary','circle','40,40,20',[[60,40],[60.25,40],[59.75,40]]],
 ['circle extra','circle','40,40,20,999',[[40,40]]],['polygon odd','poly','10,10,60,10,10,60,999',[[20,20],[50,50]]],['polygon insufficient','poly','10,10,60,10,10',[[20,20]]],
 ['polygon boundary','poly','10,10,60,10,10,60',[[10,10],[20,10],[10,20],[35,35],[36,35]]],['rectangle reverse','rect','60,60,10,10',[[30,30]]],
 ['rectangle zero width','rect','30,10,30,60',[[30,30],[30.25,30]]],['rectangle boundaries','rect','10,10,60,60',[[10,10],[60,60],[60.25,30],[59.75,30]]],
 ['rectangle extra','rect','10,10,60,60,999',[[30,30]]],['float coords','rect','10.5,10.5,60.5,60.5',[[30,30],[10,10],[10.5,10.5]]],
 ['scientific coords','rect','1e1,1e1,6e1,6e1',[[30,30]]],['plus coords','rect','+10,+10,+60,+60',[[30,30]]],
 ['empty separators','rect','10,,10,,,60,60',[[30,30]]],['junk middle','rect','10,10,junk,60,60',[[30,30]]],['junk suffix','rect','10x,10x,60x,60x',[[30,30]]],
 ['junk prefix','rect','x10,x10,x60,x60',[[30,30]]],['hex coords','rect','0xA,0xA,0x3C,0x3C',[[30,30]]],['semicolon coords','rect','10;10;60;60',[[30,30]]],
 ['default ignores coords','default','junk',[[30,30]]]
])cases.push({name:label,html:html('<map name="a" id="mapA"><area id="subject" shape="'+shape+'" coords="'+coords+'" href="#subject"><area id="fallback" shape="default" href="#fallback"></map>'),steps:[['initial','']],points:probe});
cases.push({name:'live area precedence and dead shapes',html:html('<map id="mapA" name="a"><area id="dead" shape="rect" coords="10,10,60,60"><area id="subject" shape="default" href="#subject"></map><map id="mapB" name="b"></map>'),steps:[
 ['dead first',''],['move dead last','mapA.append(dead)'],['move subject other map','mapB.append(subject)'],['change coords','dead.coords="90,90,110,110"'],['insert area','mapA.insertAdjacentHTML("afterbegin","<area id=newArea shape=default href=#new>")'],['reparent nested','globalThis.nest=document.createElement("div");mapA.append(nest);nest.append(newArea)'],['remove new','newArea.remove()']
 ],points:[[30,30],[100,100]]});
cases.push({name:'namespace map and areas',html:html('<map id="mapA" name="a"><area id="areaA" shape="default" href="#a"></map>'),steps:[
 ['foreign map first','globalThis.foreign=document.createElementNS("urn:foreign","map");foreign.setAttribute("name","a");foreign.append(document.createElementNS("http://www.w3.org/1999/xhtml","area"));foreign.firstChild.id="foreignMapArea";foreign.firstChild.shape="default";stage.prepend(foreign)'],
 ['foreign area first','globalThis.foreignArea=document.createElementNS("urn:foreign","area");foreignArea.id="foreignArea";foreignArea.setAttribute("shape","default");mapA.prepend(foreignArea)'],
 ['prefixed HTML map','globalThis.prefixed=document.createElementNS("http://www.w3.org/1999/xhtml","p:map");prefixed.setAttribute("name","p");globalThis.prefixedArea=document.createElementNS("http://www.w3.org/1999/xhtml","p:area");prefixedArea.id="prefixedArea";prefixedArea.shape="default";prefixedArea.href="#p";prefixed.append(prefixedArea);stage.append(prefixed);image.useMap="#p"']
 ],points:[[30,30]]});
cases.push({name:'shadow root association',html:html(full),steps:[
 ['light root',''],['shadow image with light maps','globalThis.host=document.createElement("div");stage.append(host);globalThis.shadow=host.attachShadow({mode:"open"});shadow.append(image)'],
 ['shadow own map','shadow.append(mapB);image.useMap="#b"'],['shadow own named clone','globalThis.shadowMap=document.createElement("map");shadowMap.name="a";shadowMap.innerHTML="<area id=shadowArea shape=default href=#shadow>";shadow.append(shadowMap);image.useMap="#a"'],
 ['light image shadow map','stage.prepend(image);mapA.remove()']
 ],points:[[30,30]]});
cases.push({name:'default finite precedence',html:html('<map name="a" id="mapA"><area id="firstDefault" shape="default" href="#first"><area id="subject" shape="rect" coords="10,10,60,60" href="#subject"><area id="lastDefault" shape="default" href="#last"></map>'),steps:[['default first',''],['last default remove','lastDefault.remove()'],['finite last','mapA.append(subject)'],['default sole','subject.remove()']],points});
cases.push({name:'padding border content bounds',html:html('<map name="a"><area id="subject" shape="default" href="#subject"></map>')+'<style>img{padding:8px;border:4px solid black}</style>',steps:[['initial','']],points:[[2,2],[8,8],[12,12],[42,42],[203,40],[206,40],[214,40]]});
cases.push({name:'broken image association bounds',html:html('<map name="a"><area id="subject" shape="default" href="#subject"></map>').replace(image,'data:image/png,invalid')+'<style>img{padding:8px;border:4px solid black}</style>',steps:[['initial','']],points:[[2,2],[8,8],[12,12],[42,42],[203,40],[206,40],[214,40]]});
async function main(){
 fs.mkdirSync(folder,{recursive:true});
 const response=await fetch(sourceURL);if(!response.ok)throw new Error('Frozen WHATWG source: '+response.status);
 const source=await response.text();fs.writeFileSync(path.join(folder,'html-target-source'),source);
 const metadata={targetDate:'2026-10-06',commit,commitDate:'2026-10-06T09:12:18Z',source:sourceURL,sha256:crypto.createHash('sha256').update(source).digest('hex')};
 const starts=['interface <dfn interface>HTMLMapElement','interface <dfn interface>HTMLAreaElement','Image maps are','rules for parsing a hash-name reference','rules for parsing a list of floating-point numbers'];
 metadata.excerpts=starts.map(term=>{const at=source.indexOf(term);return{term,at,context:at<0?'':source.slice(Math.max(0,at-800),at+1800)}});
 fs.writeFileSync(path.join(folder,'html-target-metadata.json'),JSON.stringify(metadata,null,2)+'\n');
 const browser=await openBrowser(folder);const result={captured:'2026-10-11',target:metadata,cases:[],reflection:[],collections:[],keyboard:[],downMutation:[]};
 try{
  result.browser=(await browser.send('Browser.getVersion')).product;
  for(const c of cases){
   await browser.load(c.html);await browser.evaluate('Promise.all(Array.from(document.images,e=>e.decode().catch(()=>{})))');
   await browser.evaluate('globalThis.image=document.getElementById("image");globalThis.stage=document.getElementById("stage");globalThis.events=[];for(const type of ["pointerdown","pointerup","click","pointerover","pointerout"])document.addEventListener(type,e=>{if(type==="click")e.preventDefault();const inner=e.composedPath()[0];events.push({type,target:e.target.id,innerTarget:inner.id,localName:inner.localName,namespace:inner.namespaceURI,trusted:e.isTrusted,cancelled:e.defaultPrevented,href:inner.getAttribute("href")})},true)');
   const record={name:c.name,html:c.html,steps:[]};
   for(const [label,action] of c.steps){
    await browser.evaluate('events.length=0');if(action)await browser.evaluate(action);
    await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');
    const entry={label,action,useMap:await browser.evaluate('image.useMap'),stationary:await browser.evaluate('({events:events.slice(),hover:Array.from(document.querySelectorAll("area,img"),e=>[e.id,e.matches(":hover")])})'),probes:[]};
    for(const [x,y] of c.points){
     const rect=await browser.evaluate('(()=>{const r=image.getBoundingClientRect();return{x:r.x,y:r.y,w:r.width,h:r.height}})()');
     await browser.evaluate('events.length=0');await browser.send('Input.dispatchMouseEvent',{type:'mouseMoved',x:rect.x+x,y:rect.y+y});
     await browser.send('Input.dispatchMouseEvent',{type:'mousePressed',x:rect.x+x,y:rect.y+y,button:'left',clickCount:1});
     await browser.send('Input.dispatchMouseEvent',{type:'mouseReleased',x:rect.x+x,y:rect.y+y,button:'left',clickCount:1});
     entry.probes.push({point:[x,y],rect,events:await browser.evaluate('events.slice()')});
    }
    record.steps.push(entry);
   }
   result.cases.push(record);
  }
  await browser.load(html('<map id="mapA" name="a"><area id="areaA" name="alpha"><div id="nested"><area id="areaB" name="beta"></div></map>'));
  result.reflection=await browser.evaluate('(()=>{const area=document.createElement("area"),out=[];for(const value of [null,"","rect","RECT","circ","polygon","rectangle","unknown"," rect "]){if(value===null)area.removeAttribute("shape");else area.setAttribute("shape",value);out.push({value,property:area.shape,attribute:area.getAttribute("shape")})}for(const value of ["CIRC","junk",null,undefined]){area.shape=value;out.push({assigned:String(value),property:area.shape,attribute:area.getAttribute("shape")})}return out})()');
  await browser.evaluate('globalThis.mapA=document.getElementById("mapA");globalThis.keptAreas=mapA.areas;globalThis.areaA=document.getElementById("areaA");globalThis.areaB=document.getElementById("areaB")');
  for(const [label,action] of [
   ['initial',''],['append HTML','globalThis.areaC=document.createElement("area");areaC.id="areaC";areaC.setAttribute("name","gamma");mapA.append(areaC)'],
   ['foreign excluded','globalThis.foreign=document.createElementNS("urn:foreign","area");foreign.id="foreign";mapA.prepend(foreign)'],
   ['prefixed included','globalThis.prefixed=document.createElementNS("http://www.w3.org/1999/xhtml","p:area");prefixed.id="prefixed";mapA.append(prefixed)'],
   ['nested map included','globalThis.nestedMap=document.createElement("map");nestedMap.innerHTML="<area id=nestedArea name=inside>";mapA.append(nestedMap)'],
   ['shadow excluded','globalThis.host=document.createElement("div");mapA.append(host);globalThis.shadow=host.attachShadow({mode:"open"});shadow.innerHTML="<area id=shadowArea>"'],
   ['move area out','document.body.append(areaB)'],['remove first','areaA.remove()'],['named mutation','areaC.setAttribute("name","changed");areaC.id="newC"'],
   ['reserved names','globalThis.reserved=document.createElement("area");reserved.id="length";reserved.setAttribute("name","item");mapA.append(reserved);globalThis.namedReserved=document.createElement("area");namedReserved.id="namedItem";mapA.append(namedReserved)'],
   ['adopt whole map','globalThis.other=document.implementation.createHTMLDocument("other");other.adoptNode(mapA);other.body.append(mapA)'],
   ['insert in adopted map','globalThis.adopted=other.createElement("area");adopted.id="adopted";mapA.append(adopted)'],
   ['detached map live','mapA.remove();areaC.remove()'],['reinsert original document','document.body.append(mapA)']
  ]){if(action)await browser.evaluate(action);result.collections.push({label,action,value:await browser.evaluate('({same:mapA.areas===keptAreas,length:keptAreas.length,ids:Array.from(keptAreas,x=>x.id),item0:keptAreas.item(0)?.id||null,itemEnd:keptAreas.item(keptAreas.length),alpha:keptAreas.namedItem("alpha")?.id||null,gamma:keptAreas.namedItem("gamma")?.id||null,changed:keptAreas.namedItem("changed")?.id||null,lengthNamed:keptAreas.namedItem("length")?.id||null,itemNamed:keptAreas.namedItem("item")?.id||null,namedItemNamed:keptAreas.namedItem("namedItem")?.id||null,methodTypes:[typeof keptAreas.item,typeof keptAreas.namedItem],ownerIsOriginal:mapA.ownerDocument===document})')})}
  await captureInteraction(browser,result);
  fs.writeFileSync(path.join(folder,'native.json'),JSON.stringify(result,null,2)+'\n');
  const states=result.cases.reduce((n,c)=>n+c.steps.length,0),probes=result.cases.reduce((n,c)=>n+c.steps.reduce((s,v)=>s+v.probes.length,0),0);
  console.log(JSON.stringify({browser:result.browser,cases:result.cases.length,states,probes,reflection:result.reflection.length,collections:result.collections.length,keyboard:result.keyboard.length,downMutation:result.downMutation.length,source:metadata},(k,v)=>k==='excerpts'?undefined:v));
  for(const c of result.cases)console.log(c.name+': '+c.steps.map(s=>s.label+'='+s.probes.map(p=>p.events.find(e=>e.type==='click')?.innerTarget??'NOCLICK').join('/')).join(' | '));
  for(const c of result.keyboard)console.log('keyboard '+c.label+': '+c.focused.join('/')+'; '+c.events.map(e=>e.target).join('/'));
  for(const c of result.downMutation)console.log('downmutation '+c.label+': '+c.events.map(e=>e.type+'='+e.target).join('/'));
 }finally{await browser.close()}
}
async function captureInteraction(browser,result){
 // Real Tab/Enter, not dispatched synthetic DOM events.
 result.keyboardHTML='<!doctype html>'+base+'<button id="before">before</button><div id="stage"><img id="image" src="'+image+'" usemap="#a">'+full+'</div><button id="after">after</button>';
 result.downMutationHTML=html(full);
 await browser.load(result.keyboardHTML);
 await browser.evaluate('Promise.all(Array.from(document.images,e=>e.decode().catch(()=>{})))');
 await browser.evaluate('globalThis.image=document.getElementById("image");globalThis.stage=document.getElementById("stage");globalThis.mapA=document.getElementById("mapA");globalThis.mapB=document.getElementById("mapB");globalThis.areaA=document.getElementById("areaA");globalThis.areaB=document.getElementById("areaB");globalThis.events=[];document.addEventListener("click",e=>{e.preventDefault();events.push({type:e.type,target:e.target.id,trusted:e.isTrusted,cancelled:e.defaultPrevented,href:e.target.getAttribute("href")})},true)');
 for(const [label,action] of [
  ['initial',''],['href removed','areaA.removeAttribute("href")'],['href added','areaA.setAttribute("href","#changed")'],['useMap changed','image.useMap="#b"'],
  ['map detached','mapB.remove()'],['map reinserted','stage.append(mapB)'],['image hidden','image.style.display="none"'],['image visible','image.style.display="block"'],
  ['image no map','image.removeAttribute("usemap")'],['area tabindex without image','areaB.tabIndex=0'],['association restored','image.useMap="#b"'],
  ['map replaced','globalThis.replace=document.createElement("map");replace.name="b";replace.innerHTML="<area id=areaReplacement shape=default href=#replace>";mapB.replaceWith(replace)'],
  ['map style hidden','replace.style.display="none"']
 ]){
  if(action)await browser.evaluate(action);await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');
  await browser.evaluate('document.getElementById("before").focus();events.length=0');const focused=[];
  for(let i=0;i<3;i++){await browser.send('Input.dispatchKeyEvent',{type:'keyDown',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});await browser.send('Input.dispatchKeyEvent',{type:'keyUp',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});focused.push(await browser.evaluate('document.activeElement.id||document.activeElement.localName'));if(i===0){await browser.send('Input.dispatchKeyEvent',{type:'keyDown',key:'Enter',code:'Enter',windowsVirtualKeyCode:13});await browser.send('Input.dispatchKeyEvent',{type:'keyUp',key:'Enter',code:'Enter',windowsVirtualKeyCode:13})}}
  result.keyboard.push({label,action,focused,events:await browser.evaluate('events.slice()')});
 }
 for(const [label,action] of [['useMap during press','image.useMap="#b"'],['href removed during press','areaA.removeAttribute("href")'],['area removed during press','areaA.remove()'],['coords moved during press','areaA.shape="rect";areaA.coords="90,90,110,110"']]){
  await browser.load(html(full));await browser.evaluate('Promise.all(Array.from(document.images,e=>e.decode().catch(()=>{})))');
  await browser.evaluate('globalThis.image=document.getElementById("image");globalThis.areaA=document.getElementById("areaA");globalThis.events=[];for(const type of ["pointerdown","pointerup","click"])document.addEventListener(type,e=>{if(type==="click")e.preventDefault();events.push({type,target:e.target.id,trusted:e.isTrusted,cancelled:e.defaultPrevented,href:e.target.getAttribute("href")})},true)');
  const rect=await browser.evaluate('(()=>{const r=image.getBoundingClientRect();return{x:r.x,y:r.y}})()');const point={x:rect.x+30,y:rect.y+30,button:'left',clickCount:1};
  await browser.send('Input.dispatchMouseEvent',{type:'mouseMoved',...point});await browser.send('Input.dispatchMouseEvent',{type:'mousePressed',...point});await browser.evaluate(action);await browser.send('Input.dispatchMouseEvent',{type:'mouseReleased',...point});
  result.downMutation.push({label,action,events:await browser.evaluate('events.slice()')});
 }
}
main().then(()=>{
 require('node:child_process').execFileSync(process.execPath,[path.join(__dirname,'capture-image-maps-supplement.cjs')],{windowsHide:true,stdio:'inherit'});
 const primary=JSON.parse(fs.readFileSync(path.join(folder,'native.json'),'utf8'));
 const supplement=JSON.parse(fs.readFileSync(path.join(folder,'supplement.json'),'utf8'));
 const fixture={...primary,supplement,normative:{source:sourceURL,defaultPrecedence:[
  {case:'shape "default"',step:0,targets:['subject','subject']},
  {case:'shape "DEFAULT"',step:0,targets:['subject','subject']},
  {case:'default ignores coords',step:0,targets:['subject']},
  {case:'default finite precedence',step:0,targets:['firstDefault','firstDefault']},
  {case:'default finite precedence',step:1,targets:['firstDefault','firstDefault']},
  {case:'default finite precedence',step:2,targets:['firstDefault','firstDefault']},
  {case:'live area precedence and dead shapes',step:1,targets:['subject','subject']},
  {case:'live area precedence and dead shapes',step:4,targets:['newArea','newArea']}
 ],note:'Frozen HTML image-map processing layers ALL shapes in reverse tree order, first area topmost. Chromium treats default as a fallback and keeps the last default; raw events, rectangles and mutations remain in cases. Border-box origin matches the native loaded/broken controls; arbitrary transforms/object-fit remain outside this fixture.'}};
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/image-maps-browser.json'),JSON.stringify(fixture,null,2)+'\n');
 console.log('Image-map durable native fixture saved');
}).catch(e=>{console.error(e);process.exitCode=1});
