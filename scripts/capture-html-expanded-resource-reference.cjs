const fs=require('node:fs'),path=require('node:path'),{openBrowser}=require('./native-browser.cjs');
const html='<!doctype html><html><head><title>Expanded resource paths</title><style>html,body{margin:0;padding:0}#photo{display:inline;width:20px;height:10px}#drawing{display:inline;width:20px;height:10px}#sound{display:inline;width:140px;height:40px}#movie{display:inline;width:120px;height:60px}#caption{display:block;width:60px;height:20px;padding:0;border:0}#other{display:block;width:40px;height:20px;padding:0;border:0}#foreign-inline,#plain-inline{display:inline}</style></head><body><script></script></body></html>';
const source=String.raw`function expandedResourcesSetup(first,second,sound){
 const H='http://www.w3.org/1999/xhtml',F='urn:foreign';
 function make(ns,name,id){const n=document.createElementNS(ns,name);n.id=id;return n;}
 const photo=make(H,'h:img','photo');photo.src=first;photo.alt='First image';
 const drawing=make(H,'h:canvas','drawing');drawing.width=2;drawing.height=2;
 const audio=make(H,'h:audio','sound');audio.controls=true;
 const badSource=make(F,'source','foreign-source');badSource.setAttribute('src',second);badSource.setAttribute('type','audio/wav');
 const plainSource=make(null,'source','plain-source');plainSource.setAttribute('src',second);plainSource.setAttribute('type','audio/wav');
 const realSource=make(H,'h:source','real-source');realSource.src=sound;realSource.type='audio/wav';audio.append(badSource,plainSource,realSource);
 const movie=make(H,'h:video','movie');movie.setAttribute('controls','');movie.setAttribute('src',sound);movie.setAttribute('poster',first);
 const badTrack=make(F,'track','foreign-track');badTrack.setAttribute('kind','captions');
 const plainTrack=make(null,'track','plain-track');plainTrack.setAttribute('kind','captions');
 const track=make(H,'h:track','real-track');track.setAttribute('kind','captions');track.setAttribute('label','Native');movie.append(badTrack,plainTrack,track);
 const caption=make(H,'h:button','caption');caption.textContent='First';
 const other=make(H,'h:input','other');other.type='button';other.value='First';
 const foreignInline=make(F,'img','foreign-inline');foreignInline.textContent='Foreign';
 const plainInline=make(null,'img','plain-inline');plainInline.textContent='Plain';
 document.body.append(photo,drawing,audio,movie,caption,other,foreignInline,plainInline);
 window.resources={photo,drawing,audio,movie,caption,other,foreignInline,plainInline,second,realSource,track};
 window.resizeRecords=[];window.resourceObserver=new ResizeObserver(entries=>{for(const e of entries)resizeRecords.push([e.target.id,e.contentRect.width,e.contentRect.height]);});
 for(const n of [photo,drawing,audio,movie,caption,other,foreignInline,plainInline])resourceObserver.observe(n);
 return [audio.tagName,track.localName,track.prefix,realSource.localName,realSource.prefix,photo.localName,photo.prefix];
}
function expandedResourceRects(){return ['photo','drawing','sound','movie','caption','other'].map(id=>{const n=document.getElementById(id),r=n.getBoundingClientRect();return[id,r.width,r.height,getComputedStyle(n).display];});}
function expandedResourceDraw(){const c=resources.drawing.getContext('2d');c.clearRect(0,0,2,2);c.drawImage(resources.photo,0,0);return Array.from(c.getImageData(0,0,1,1).data);}
function expandedResourceUpdate(){resources.caption.textContent='Next';resources.other.setAttribute('value','Next');resources.photo.src=resources.second;return [resources.caption.textContent,resources.other.value];}
function expandedResourceForeignAttributes(){resources.photo.setAttributeNS('urn:foreign','src','ignored.png');resources.audio.setAttributeNS('urn:foreign','controls','');return [resources.photo.getAttribute('src')===resources.second,resources.audio.controls];}
function expandedResourceDirectText(){resources.caption.firstChild.data='Direct';return resources.caption.textContent;}
function expandedResourceEdges(mode){return [resources.photo,resources.drawing,resources.audio,resources.movie].map(n=>{n.style.cssText='display:inline;width:20px;height:10px;padding:3px 5px;border:2px solid black;margin:7px 11px;box-sizing:'+ (mode==='border'?'border-box':'content-box')+';transform:'+(mode==='scaled'?'translate(4px,6px) scale(2)':'none');const r=n.getBoundingClientRect();return[n.id,r.width,r.height];});}
`;
(async()=>{const browser=await openBrowser(path.resolve(__dirname,'../build'));try{
 await browser.load(html);
 const assets=await browser.evaluate(`(()=>{const c=document.createElement('canvas');c.width=1;c.height=1;const ctx=c.getContext('2d');ctx.fillStyle='red';ctx.fillRect(0,0,1,1);const first=c.toDataURL();c.width=2;ctx.fillStyle='blue';ctx.fillRect(0,0,2,1);const second=c.toDataURL();const b=new Uint8Array(44+800),v=new DataView(b.buffer);function text(p,s){for(let i=0;i<s.length;i++)b[p+i]=s.charCodeAt(i)}text(0,'RIFF');v.setUint32(4,836,true);text(8,'WAVEfmt ');v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);v.setUint32(24,8000,true);v.setUint32(28,8000,true);v.setUint16(32,1,true);v.setUint16(34,8,true);text(36,'data');v.setUint32(40,800,true);b.fill(128,44);return {first,second,sound:'data:audio/wav;base64,'+btoa(String.fromCharCode(...b))};})()`);
 const setup=await browser.evaluate(source+`expandedResourcesSetup(${JSON.stringify(assets.first)},${JSON.stringify(assets.second)},${JSON.stringify(assets.sound)})`);
 await browser.evaluate('resources.photo.decode()');
 const rects=await browser.evaluate('expandedResourceRects()'),first=await browser.evaluate('expandedResourceDraw()');
 const trackControl=await browser.evaluate('[resources.audio.textTracks.length,resources.movie.textTracks.length,resources.track.track.label]');
 const initialResize=await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve(resizeRecords.slice().sort((a,b)=>a[0]<b[0]?-1:a[0]>b[0]?1:0)))))');
 const update=await browser.evaluate('expandedResourceUpdate()');await browser.evaluate('resources.photo.decode()');
 const second=await browser.evaluate('expandedResourceDraw()'),foreign=await browser.evaluate('expandedResourceForeignAttributes()');
 const natural=await browser.evaluate('[resources.photo.complete,resources.photo.naturalWidth,resources.photo.naturalHeight]');
 const visibility=await browser.evaluate(`(()=>{const a=resources.audio;const r=()=>{const q=a.getBoundingClientRect();return[q.width,q.height,a.controls,getComputedStyle(a).display]};a.controls=false;const off=r();a.controls=true;return[off,r()]})()`);
 const directText=await browser.evaluate('expandedResourceDirectText()');
 const edges=[];for(const mode of ['plain','scaled','border']){const rects=await browser.evaluate('expandedResourceEdges('+JSON.stringify(mode)+')');const resize=await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>{const latest={};for(const e of resizeRecords)latest[e[0]]=e;resolve(["photo","drawing","sound","movie"].map(id=>latest[id]));})))');edges.push({mode,rects,resize,rectsJson:JSON.stringify(rects),resizeJson:JSON.stringify(resize)});}
 const output={html,source,assets,setup,rects,first,trackControl,initialResize,update,second,foreign,natural,visibility,directText,directTextJson:JSON.stringify(directText),edges,userAgent:await browser.evaluate('navigator.userAgent'),references:['https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element','https://html.spec.whatwg.org/multipage/media.html#the-audio-element','https://drafts.csswg.org/cssom-view/#dom-element-getboundingclientrect','https://drafts.csswg.org/resize-observer/#calculate-box-size']};
 for(const [field,value]of Object.entries({assets:output.assets,setup:output.setup,rects:output.rects,first:output.first,resize:output.initialResize,update:output.update,second:output.second,foreign:output.foreign,natural:output.natural,off:output.visibility[0],on:output.visibility[1]}))output[field+'Json']=JSON.stringify(value);
 output.assetsJson=[output.assets.first,output.assets.second,output.assets.sound].map(JSON.stringify).join(',');
 fs.writeFileSync(path.join(__dirname,'../tests/fixtures/html-expanded-resource-browser.json'),JSON.stringify(output,null,2)+'\n');console.log(JSON.stringify({...output,source:undefined,html:undefined,assets:undefined,assetsJson:undefined}));
 }finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
