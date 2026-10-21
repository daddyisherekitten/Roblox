const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),{openBrowser}=require(path.join(root,'scripts/native-browser.cjs'));
const folder=path.join(root,'build/responsive-source-reference-20261016');fs.mkdirSync(folder,{recursive:true});
const png=fs.readFileSync(path.join(root,'tests/fixtures/object-view-box-source.png'));
const cases=[
 ['bare','a.png',null,1],['exponent','a.png 1e0x',null,1],['exponent-plus','a.png 1E+0x',null,1],['fraction','.invalid 1.x, a.png .5x',null,1],
 ['zero-density','a.png 0x',null,1],['minus-zero','a.png -0x',null,1],['negative-density','a.png -1x','fallback.png',1],['plus-density','a.png +1x','fallback.png',1],
 ['trailing-dot','a.png 1.x','fallback.png',1],['decimal-width','a.png 1.5w','fallback.png',1],['exponent-width','a.png 1e2w','fallback.png',1],['plus-width','a.png +100w','fallback.png',1],
 ['width-height','a.png 100w 50h',null,1],['height-width','a.png 50h 100w',null,1],['height-only','a.png 50h','fallback.png',1],['zero-width','a.png 0w','fallback.png',1],
 ['duplicate-width','a.png 100w 100w','fallback.png',1],['duplicate-density','a.png 1x 1x','fallback.png',1],['width-density','a.png 100w 1x','fallback.png',1],
 ['density-height','a.png 1x 50h','fallback.png',1],['duplicate-height','a.png 100w 50h 50h','fallback.png',1],['parens-recovery','a.png nope(1,2), b.png 1x',null,1],
 ['comma-url','a,b.png 1x',null,1],['trailing-commas','a.png,,, b.png 2x',null,1],['ascii-whitespace','a.png\t1x, b.png\n2x',null,2],
 ['vertical-tab-url','a\u000bb.png 1x',null,1],['vertical-tab-descriptor','a.png 1\u000bx','fallback.png',1],
 ['duplicate-density-first','a.png 1x, b.png 1x',null,1],['duplicate-width-first','a.png 100w, b.png 100w',null,1,'100px'],
 ['mixed-width-density','a.png 10w, b.png 1x',null,1,'20px'],['mixed-bare-width','a.png, b.png 400w',null,2,'200px'],
 ['img-src-one-x','a.png 2x','fallback.png',1],['img-src-two-x','a.png 2x','fallback.png',2],['img-src-explicit-one','a.png 1x, b.png 2x','fallback.png',1],
].map(([id,srcset,src,density,sizes])=>({id,group:'srcset',srcset,src,density,sizes:sizes??'100px'}));
for(const [id,sizes]of[
 ['sizes-calc','calc(50vw - 20px)'],['sizes-min','min(50vw, 300px)'],['sizes-clamp','clamp(200px, 50vw, 500px)'],
 ['sizes-comma-function','min(200px, 80vw), 100vw'],['sizes-range','(width >= 600px) 200px, 100vw'],['sizes-and','(width >= 600px) and (height >= 400px) 200px, 100vw'],
 ['sizes-or','(width < 300px) or (height > 400px) 200px, 100vw'],['sizes-not','not (width < 300px) 200px, 100vw'],
 ['sizes-inches','2in'],['sizes-rem','12.5rem'],['sizes-vh','50vh'],['sizes-zero','0'],['sizes-negative','-1px, 200px'],['sizes-calc-negative','calc(-1px), 200px'],
 ['sizes-percent','50%, 200px'],['sizes-zero-percent','calc(200px + 0%), 100vw'],['sizes-invalid-tail','(width >= 600px) 200px junk, 100vw'],['sizes-type-invalid','screen 200px, 100vw'],
 ['sizes-comment','(width >= 600px)/**/ 200px,100vw'],['sizes-eager-auto','auto, 200px'],['sizes-missing',null],
])cases.push({id,group:'sizes',srcset:'a.png 200w, b.png 800w',src:null,density:1,sizes});
const pictureCases=[
 ['picture-before','<picture><source srcset="a.png"><img id="image" src="b.png"></picture>'],
 ['picture-after','<picture><img id="image" src="b.png"><source srcset="a.png"></picture>'],
 ['picture-first','<picture><source srcset="a.png"><source srcset="b.png"><img id="image" src="c.png"></picture>'],
 ['picture-empty','<picture><source srcset=""><source srcset="b.png"><img id="image" src="c.png"></picture>'],
 ['picture-media-height','<picture><source media="(height >= 500px)" srcset="a.png"><img id="image" src="b.png"></picture>'],
 ['picture-media-height-miss','<picture><source media="(height < 500px)" srcset="a.png"><img id="image" src="b.png"></picture>'],
 ['picture-resolution','<picture><source media="(resolution >= 2dppx)" srcset="a.png 2x"><img id="image" src="b.png"></picture>',2],
 ['picture-other-img','<picture><source srcset="a.png"><img src="other.png"><source srcset="b.png"><img id="image" src="c.png"></picture>'],
 ['picture-source-dimensions','<picture><source srcset="a.png" width="90" height="80"><img id="image" src="b.png" width="60" height="30"></picture>'],
 ['picture-source-width-only','<picture><source srcset="a.png" width="90"><img id="image" src="b.png" width="60" height="30"></picture>'],
].map(([id,html,density=1])=>({id,group:'picture',html,density}));
const allCases=[...cases,...pictureCases];
const htmlFor=(input,index,base)=>'<!doctype html><base href="'+base+index+'/">'+(input.html||'<img id="image">')+'\n<script>const i=document.getElementById("image");const row='+JSON.stringify(input)+';window.captureId='+index+';if(row.src!==undefined&&row.src!==null)i.src=row.src;if(row.sizes!==undefined&&row.sizes!==null)i.sizes=row.sizes;if(row.srcset!==undefined)i.srcset=row.srcset;<\/script>';
const server=http.createServer((req,res)=>{if(req.url.startsWith('/case?')){const id=Number(new URL(req.url,'http://x').searchParams.get('id'));res.writeHead(200,{'Content-Type':'text/html','Cache-Control':'no-store'});res.end(htmlFor(allCases[id],id,'http://'+req.headers.host+'/'));return;}res.writeHead(200,{'Content-Type':'image/png','Cache-Control':'no-store'});res.end(png)});
(async()=>{await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const base='http://127.0.0.1:'+server.address().port+'/';let browser;
 try{browser=await openBrowser(folder);const version=await browser.send('Browser.getVersion');const rows=[];
 for(let index=0;index<allCases.length;index++){const input=allCases[index];await browser.send('Emulation.setDeviceMetricsOverride',{width:800,height:600,deviceScaleFactor:input.density,mobile:false});
 await browser.send('Page.navigate',{url:base+'case?id='+index});
 for(let wait=0;;wait++){let ready=false;try{ready=await browser.evaluate('window.captureId==='+index+'&&document.readyState==="complete"&&document.getElementById("image").complete')}catch{}if(ready)break;if(wait>100)throw new Error('Load timeout '+input.id);await new Promise(r=>setTimeout(r,10));}
 const result=await browser.evaluate('(()=>{const i=document.getElementById("image");return {currentSrc:i.currentSrc,complete:i.complete,naturalWidth:i.naturalWidth,naturalHeight:i.naturalHeight,width:i.width,height:i.height,dpr:devicePixelRatio,viewport:[innerWidth,innerHeight],baseURI:document.baseURI}})()');
 const selected=result.currentSrc?decodeURIComponent(new URL(result.currentSrc,base+index+'/').pathname.split('/').slice(2).join('/')):'';rows.push({...input,index,raw:result,selected});
 }
 const sourceURL='https://raw.githubusercontent.com/whatwg/html/ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c/source',sourcePath=path.join(folder,'html-target-source');
 let target;if(fs.existsSync(sourcePath))target=fs.readFileSync(sourcePath);else{const response=await fetch(sourceURL);if(!response.ok)throw new Error('Pinned HTML source HTTP '+response.status);target=Buffer.from(await response.arrayBuffer());fs.writeFileSync(sourcePath,target);}
 const hash=crypto.createHash('sha256').update(target).digest('hex');if(hash!=='49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f')throw new Error('Frozen HTML source hash mismatch');
 const report={captured:new Date().toISOString(),browser:version,target:{revision:'ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c',sha256:hash,url:sourceURL,lines:{picture:[33715,33827],srcset:[33833,34069],sizes:[34076,34147],densities:[34163,34198]}},image:{path:'tests/fixtures/object-view-box-source.png',sha256:crypto.createHash('sha256').update(png).digest('hex'),width:200,height:100},scope:'Independent isolated Chromium currentSrc and natural-dimension observations. Fresh unique base for every input; same PNG for all candidate URLs; no renderer expectation projection. Candidate choice is implementation-defined.',cases:rows.filter(r=>r.group!=='picture'),pictureCases:rows.filter(r=>r.group==='picture')};
 fs.writeFileSync(path.join(folder,'native.json'),JSON.stringify(report,null,2)+'\n');fs.writeFileSync(path.join(root,'tests/fixtures/responsive-source-browser.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(rows.map(r=>({id:r.id,selected:r.selected,natural:[r.raw.naturalWidth,r.raw.naturalHeight]}))));
 }finally{if(browser)await browser.close();server.close()}})().catch(e=>{console.error(e);process.exitCode=1});
