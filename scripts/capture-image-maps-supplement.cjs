// Supplement of the isolated native image-map capture.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {openBrowser}=require('./native-browser.cjs');
const folder=path.resolve(__dirname,'../build/image-map-reference');
const target=JSON.parse(fs.readFileSync(path.join(folder,'html-target-metadata.json'),'utf8'));
const image='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="192" height="128"><rect width="192" height="128" fill="#ddd"/></svg>');
const style='<style>body{margin:0;font:16px/20px Arial}#stage{padding:160px 0 0 210px}img{display:block;width:192px;height:128px;border:0;padding:0}</style>';
function html(map,extra=''){return '<!doctype html>'+style+extra+'<button id="before">before</button><div id="stage"><img id="image" src="'+image+'" usemap="#a">'+map+'</div><button id="after">after</button>'}
const map='<map id="mapA" name="a"><area id="areaA" shape="default" href="#destination"></map>';
async function ready(browser){await browser.evaluate('Promise.all(Array.from(document.images,e=>e.decode().catch(()=>{})))')}
async function pointer(browser,point){const r=await browser.evaluate('(()=>{const r=document.getElementById("image").getBoundingClientRect();return{x:r.x,y:r.y,width:r.width,height:r.height}})()');await browser.evaluate('events.length=0');for(const type of ['mouseMoved','mousePressed','mouseReleased'])await browser.send('Input.dispatchMouseEvent',{type,x:r.x+point[0],y:r.y+point[1],button:'left',clickCount:1});return{point,rect:r,events:await browser.evaluate('events.slice()')}}
async function keys(browser,key,code,number){for(const type of ['keyDown','keyUp'])await browser.send('Input.dispatchKeyEvent',{type,key,code,windowsVirtualKeyCode:number})}
async function main(){const browser=await openBrowser(folder);const result={target,geometry:[],mapChildren:[],tabIndex:[],visibility:[],navigation:[],stationary:[],defaultCounterparts:[],focusOrder:[],cursor:[],imgTabIndex:[],scriptedClicks:[]};let server;
 try{
  result.browser=(await browser.send('Browser.getVersion')).product;
  for(const broken of [false,true]){
   const markup=html('<map name="a"><area id="subject" shape="rect" coords="0,0,10,10" href="#subject"><area id="fallback" shape="default" href="#fallback"></map>','<style>img{padding:8px;border:4px solid black}</style>');
   await browser.load(broken?markup.replace(image,'data:image/png,invalid'):markup);await ready(browser);
   await browser.evaluate('globalThis.events=[];document.addEventListener("click",e=>{e.preventDefault();events.push({target:e.target.id,href:e.target.getAttribute("href"),trusted:e.isTrusted})},true)');
   const probes=[];for(const point of [[2,2],[8,8],[10,10],[12,12],[15,15],[21.75,21.75],[22,22],[30,30],[203,40],[214,40]])probes.push(await pointer(browser,point));result.geometry.push({broken,html:broken?markup.replace(image,'data:image/png,invalid'):markup,probes});
  }
  result.imgTabIndexHTML=html(map);await browser.load(result.imgTabIndexHTML);await ready(browser);await browser.evaluate('globalThis.image=document.getElementById("image");image.tabIndex=0');
  for(const [name,action]of [['mapped IMG tabindex',''],['unmapped IMG tabindex','image.removeAttribute("usemap")']]){
   if(action)await browser.evaluate(action);await browser.evaluate('document.getElementById("before").focus()');const focused=[];
   for(let i=0;i<2;i++){await keys(browser,'Tab','Tab',9);focused.push(await browser.evaluate('document.activeElement.id||document.activeElement.localName'))}result.imgTabIndex.push({name,action,focused});
  }
  const children='<!doctype html><style>body{margin:0;font:16px/20px Arial}#stage{width:260px;margin:20px}#block{height:32px;background:#ddd}</style><div id="stage">Before <map id="mapA" name="a">inside <span id="inline">inline text</span><area id="areaA" shape="default"><div id="block">block child</div> after</map><div id="guard">following</div></div>';
  await browser.load(children);await browser.evaluate('globalThis.mapA=document.getElementById("mapA")');
  for(const [label,action] of [['initial',''],['display none','mapA.style.display="none"'],['inline reveal','mapA.style.display="inline"'],['block map','mapA.style.display="block"'],['hidden map','mapA.hidden=true'],['unhide','mapA.hidden=false']]){
   if(action)await browser.evaluate(action);result.mapChildren.push({label,action,html:children,value:await browser.evaluate('({boxes:["stage","mapA","inline","areaA","block","guard"].map(id=>{const e=document.getElementById(id),r=e.getBoundingClientRect(),s=getComputedStyle(e);return{id,rect:[r.x,r.y,r.width,r.height],display:s.display,visibility:s.visibility}}),text:document.getElementById("stage").innerText})')});
  }
  await browser.load(html(map));
  result.tabIndex=await browser.evaluate('(()=>{const out=[],area=document.getElementById("areaA");for(const href of [null,"","#destination"]){if(href===null)area.removeAttribute("href");else area.setAttribute("href",href);for(const value of [null,"","0","-1","4","garbage","4tail","+3"," 2 ","2147483648","4294967295"]){if(value===null)area.removeAttribute("tabindex");else area.setAttribute("tabindex",value);out.push({href,attribute:value,property:area.tabIndex})}}area.removeAttribute("tabindex");area.href="#destination";area.remove();out.push({detached:true,property:area.tabIndex});document.body.append(area);document.getElementById("image").removeAttribute("usemap");out.push({noAssociation:true,property:area.tabIndex});for(const namespace of ["urn:foreign","http://www.w3.org/1999/xhtml"]){const node=document.createElementNS(namespace,"p:area");node.setAttribute("href","#test");out.push({namespace,qualified:node.nodeName,tabIndexType:typeof node.tabIndex,tabIndex:node.tabIndex??null,shapeType:typeof node.shape,shape:node.shape??null})}return out})()');
  for(const [name,extra,action] of [
   ['map hidden','','mapA.hidden=true'],['area display none','<style>#areaA{display:none}</style>',''],['area visibility hidden','<style>#areaA{visibility:hidden}</style>',''],['area hidden','','areaA.hidden=true'],
   ['map visibility hidden','<style>#mapA{visibility:hidden}</style>',''],['map inert','','mapA.inert=true'],['image visibility hidden','<style>#image{visibility:hidden}</style>',''],
   ['image inert','','image.inert=true'],['image ancestor inert','','stage.inert=true'],
   ['multiple images one hidden','','globalThis.other=image.cloneNode();other.id="otherImage";stage.prepend(other);image.style.display="none"'],
   ['multiple visible images','','globalThis.other=image.cloneNode();other.id="otherImage";stage.prepend(other)']
  ]){
   await browser.load(html(map,extra));await ready(browser);await browser.evaluate('globalThis.image=document.getElementById("image");globalThis.stage=document.getElementById("stage");globalThis.mapA=document.getElementById("mapA");globalThis.areaA=document.getElementById("areaA");globalThis.events=[];document.addEventListener("click",e=>{e.preventDefault();events.push({target:e.target.id,href:e.target.getAttribute("href"),trusted:e.isTrusted})},true)');if(action)await browser.evaluate(action);
   const probe=await pointer(browser,[30,30]);await browser.evaluate('document.getElementById("before").focus();events.length=0');const focused=[];for(let i=0;i<4;i++){await keys(browser,'Tab','Tab',9);focused.push(await browser.evaluate('document.activeElement.id||document.activeElement.localName'));if(i===0)await keys(browser,'Enter','Enter',13)}result.visibility.push({name,html:html(map,extra),extra,action,probe,focused,events:await browser.evaluate('events.slice()')});
  }
  for(const [name,markup] of [
   ['map before image', '<!doctype html>'+style+map+'<button id="before">before</button><div id="stage"><img id="image" src="'+image+'" usemap="#a"></div><button id="after">after</button>'],
   ['two areas before image','<!doctype html>'+style+'<map name="a"><area id="areaA" shape="rect" coords="0,0,80,80" href="#a"><area id="areaB" shape="default" href="#b"></map><button id="before">before</button><div id="stage"><img id="image" src="'+image+'" usemap="#a"></div><button id="after">after</button>']
  ]){
   await browser.load(markup);await ready(browser);await browser.evaluate('document.getElementById("before").focus()');const focused=[];
   for(let i=0;i<3;i++){await keys(browser,'Tab','Tab',9);focused.push(await browser.evaluate('document.activeElement.id||document.activeElement.localName'))}result.focusOrder.push({name,html:markup,focused});
  }
  result.cursorHTML=html(map,'<style>#mapA{cursor:wait}#image{cursor:crosshair}.help{cursor:help}.variable{cursor:var(--shape-cursor)}.hover:hover{cursor:help}</style>');
  await browser.load(result.cursorHTML);await ready(browser);
  await browser.evaluate('globalThis.areaA=document.getElementById("areaA");globalThis.image=document.getElementById("image");globalThis.events=[];document.addEventListener("click",e=>{e.preventDefault();events.push({target:e.target.id})},true)');
  for(const [name,action]of [['IMG inheritance',''],['explicit area','areaA.className="help"'],['area var','areaA.className="variable";image.style.setProperty("--shape-cursor","move")'],['CSSOM auto','areaA.style.cursor="auto"'],['CSSOM inherit','areaA.style.cursor="inherit"']]){
   if(action)await browser.evaluate(action);const probe=await pointer(browser,[30,30]);result.cursor.push({name,action,probe,value:await browser.evaluate('({area:getComputedStyle(areaA).cursor,image:getComputedStyle(image).cursor})')});
  }
  result.inertCursor=[];
  for(const [name,action]of [['inert IMG ancestor cursor','image.inert=true'],['inert stage body cursor','stage.inert=true']]){
   const markup=html(map,'<style>body{cursor:pointer}#stage{cursor:help}#image{cursor:crosshair}</style>');await browser.load(markup);await ready(browser);
   await browser.evaluate('globalThis.image=document.getElementById("image");globalThis.stage=document.getElementById("stage");globalThis.events=[];document.addEventListener("click",e=>{e.preventDefault();events.push({target:e.target.id,trusted:e.isTrusted})},true)');await browser.evaluate(action);
   result.inertCursor.push({name,html:markup,action,probe:await pointer(browser,[30,30]),value:await browser.evaluate('({body:getComputedStyle(document.body).cursor,stage:getComputedStyle(stage).cursor,image:getComputedStyle(image).cursor})')});
  }
  // Independent native finite-rectangle counterparts for exactly the frozen
  // first-shape/default deltas. Keep the original actions/events unmodified.
  const primary=JSON.parse(fs.readFileSync(path.join(folder,'native.json'),'utf8'));
  for(const [name,indices]of [['shape "default"',[0]],['shape "DEFAULT"',[0]],['default ignores coords',[0]],['default finite precedence',[0,1,2]],['live area precedence and dead shapes',[1,4]]]){
   const c=primary.cases.find(c=>c.name===name);await browser.load(c.html);await ready(browser);
   await browser.evaluate('for(const id of ["image","stage","mapA","mapB","dead","subject","firstDefault","lastDefault"])globalThis[id]=document.getElementById(id)');
   for(let step=0;step<c.steps.length;step++){
    if(c.steps[step].action)await browser.evaluate(c.steps[step].action);if(!indices.includes(step))continue;
    const markup=await browser.evaluate('(()=>{const copy=document.documentElement.cloneNode(true);for(const e of copy.querySelectorAll("area")){if(e.getAttribute("shape")?.toLowerCase()==="default"){e.setAttribute("shape","rect");e.setAttribute("coords","0,0,192,128")}}return "<!doctype html>"+copy.outerHTML})()');
    // A second isolated tab preserves the original live sequence in this tab.
    const control=await openBrowser(path.join(folder,'default-'+result.defaultCounterparts.length));
    try{await control.load(markup);await ready(control);await control.evaluate('globalThis.events=[];document.addEventListener("click",e=>{e.preventDefault();events.push({target:e.target.id,href:e.target.getAttribute("href"),trusted:e.isTrusted})},true)');const probes=[];for(const p of c.steps[step].probes)probes.push(await pointer(control,p.point));result.defaultCounterparts.push({name,step,html:markup,probes})}finally{await control.close()}
   }
  }
  // Retain an actually stationary pointer over the image while mutating href,
  // association or shape; flush two frames without sending mouseMoved again.
  await browser.load(html('<map id="mapA" name="a"><area id="areaA" shape="rect" coords="10,10,60,60" href="#a"></map><map id="mapB" name="b"><area id="areaB" shape="default" href="#b"></map>'));await ready(browser);
  await browser.evaluate('globalThis.image=document.getElementById("image");globalThis.areaA=document.getElementById("areaA");globalThis.mapA=document.getElementById("mapA");globalThis.events=[];for(const type of ["pointerover","pointerout","mouseover","mouseout"])document.addEventListener(type,e=>events.push({type,target:e.target.id,related:e.relatedTarget?.id||null,trusted:e.isTrusted}),true)');const r=await browser.evaluate('(()=>{const r=image.getBoundingClientRect();return{x:r.x,y:r.y}})()');await browser.send('Input.dispatchMouseEvent',{type:'mouseMoved',x:r.x+30,y:r.y+30});
  for(const [name,action] of [['initial',''],['href remove','areaA.removeAttribute("href")'],['coords move','areaA.coords="90,90,110,110"'],['useMap b','image.useMap="#b"'],['map name rename','document.getElementById("mapB").name="renamed"'],['useMap renamed','image.useMap="#renamed"'],['map remove','document.getElementById("mapB").remove()']]){
   await browser.evaluate('events.length=0');if(action)await browser.evaluate(action);await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');result.stationary.push({name,action,value:await browser.evaluate('({events:events.slice(),hover:Array.from(document.querySelectorAll("area,img"),e=>[e.id,e.matches(":hover")])})')});
  }
  // Same-origin fragments provide an actual navigation oracle, independent of
  // the prevented-click records above and without opening another user's app.
  server=http.createServer((request,response)=>{response.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});response.end(html(map)+'<div id="destination">destination</div><script>globalThis.captureReady=true</script>')});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const url='http://127.0.0.1:'+server.address().port+'/';
  for(const [name,action,keyboard] of [['pointer navigate','',false],['pointer cancelled','document.addEventListener("click",e=>e.preventDefault())',false],['dead area','document.getElementById("areaA").removeAttribute("href")',false],['keyboard navigate','',true]]){
   const current=url+'?case='+encodeURIComponent(name);await browser.send('Page.navigate',{url:current});for(let i=0;i<100;i++){try{if(await browser.evaluate('location.href==='+JSON.stringify(current)+'&&globalThis.captureReady===true'))break}catch{}await new Promise(resolve=>setTimeout(resolve,10));if(i===99)throw new Error('HTTP capture readiness')}
   await ready(browser);await browser.evaluate('globalThis.events=[];document.addEventListener("click",e=>events.push({target:e.target.id,href:e.target.getAttribute("href"),trusted:e.isTrusted}),true)');if(action)await browser.evaluate(action);
   if(keyboard){await browser.evaluate('document.getElementById("before").focus()');await keys(browser,'Tab','Tab',9);await keys(browser,'Enter','Enter',13)}else await pointer(browser,[30,30]);await new Promise(resolve=>setTimeout(resolve,25));result.navigation.push({name,action,keyboard,value:await browser.evaluate('({hash:location.hash,active:document.activeElement.id,events:events.slice()})')});
  }
  for(const [name,setup,action]of [
   ['scripted area navigate','','areaA.click()'],['scripted area cancelled','document.addEventListener("click",e=>e.preventDefault())','areaA.click()'],
   ['scripted area empty href','areaA.setAttribute("href","")','areaA.click()'],['scripted area missing href','areaA.removeAttribute("href")','areaA.click()'],
   ['scripted prefixed HTML area','var p=document.createElementNS("http://www.w3.org/1999/xhtml","p:area");p.id="prefixedArea";p.setAttribute("href","#destination");mapA.append(p)','document.getElementById("prefixedArea").click()'],
   ['scripted anchor navigate','var a=document.createElement("a");a.id="anchor";a.href="#destination";stage.append(a)','document.getElementById("anchor").click()'],
   ['scripted prefixed HTML anchor','var a=document.createElementNS("http://www.w3.org/1999/xhtml","p:a");a.id="prefixedAnchor";a.setAttribute("href","#destination");stage.append(a)','document.getElementById("prefixedAnchor").click()']
  ]){
   const current=url+'?script='+encodeURIComponent(name)+'#initial';await browser.send('Page.navigate',{url:current});
   for(let i=0;i<100;i++){try{if(await browser.evaluate('location.href==='+JSON.stringify(current)+'&&globalThis.captureReady===true'))break}catch{}await new Promise(resolve=>setTimeout(resolve,10));if(i===99)throw Error('Script capture readiness')}
   await ready(browser);await browser.evaluate('globalThis.areaA=document.getElementById("areaA");globalThis.mapA=document.getElementById("mapA");globalThis.stage=document.getElementById("stage");globalThis.events=[];document.addEventListener("click",e=>events.push({target:e.target.id,href:e.target.getAttribute("href"),trusted:e.isTrusted}),true)');
   if(setup)await browser.evaluate(setup);const events=await browser.evaluate('(()=>{'+action+';return events.slice()})()');await new Promise(resolve=>setTimeout(resolve,25));
   result.scriptedClicks.push({name,html:html(map),setup,action,events,hash:await browser.evaluate('location.hash')});
  }
  fs.writeFileSync(path.join(folder,'supplement.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify({browser:result.browser,geometry:result.geometry.length,mapChildren:result.mapChildren.length,tabIndex:result.tabIndex.length,visibility:result.visibility.length,stationary:result.stationary.length,navigation:result.navigation.length}));
  for(const c of result.geometry)console.log('geometry '+c.broken+': '+c.probes.map(p=>p.point.join(',')+'='+p.events.map(e=>e.target).join('/')).join(' | '));
  for(const c of result.visibility)console.log(c.name+': click='+c.probe.events.map(e=>e.target).join('/')+'; tab='+c.focused.join('/')+'; enter='+c.events.map(e=>e.target).join('/'));
  for(const c of result.stationary)console.log('stationary '+c.name+': '+JSON.stringify(c.value));
  for(const c of result.navigation)console.log('navigation '+c.name+': '+JSON.stringify(c.value));
 }finally{await browser.close();if(server)await new Promise(resolve=>server.close(resolve))}
}
main().catch(e=>{console.error(e);process.exitCode=1});
