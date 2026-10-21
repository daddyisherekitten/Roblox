// Actual native line pixels, including their physical side and inline extent.
const fs=require('node:fs'),path=require('node:path'),pixels=require('./native-png.cjs');
const {openBrowser}=require('./native-browser.cjs');
(async()=>{const browser=await openBrowser(path.resolve(__dirname,'../build/vertical-decoration-reference'));
 try{
  await browser.send('Emulation.setDeviceMetricsOverride',{width:1280,height:1280,deviceScaleFactor:1,mobile:false});
  await browser.load('<!doctype html><meta charset="utf-8"><style>body{margin:0;background:white}</style><div id="samples"></div><span id="measure"></span>');
  const records=[];for(const writingMode of ['horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'])for(const orientation of ['mixed','upright','sideways'])for(const direction of ['ltr','rtl'])for(const position of ['auto','from-font','under','left','right','under left','under right','from-font left','from-font right'])for(const kind of ['underline','overline','line-through'])for(const source of ['天地','ABC'])records.push({writingMode,orientation,direction,position,kind,source});
  for(let start=0;start<records.length;start+=100){
   // Fresh document paint avoids Chromium retaining stale decoration pixels
   // when many orthogonal inline boxes replace one another at the same point.
   await browser.load('<!doctype html><meta charset="utf-8"><style>body{margin:0;background:white}</style><div id="samples"></div><span id="measure"></span>');
   const batch=records.slice(start,start+100);
   const captured=await browser.evaluate(`(()=>{const records=${JSON.stringify(batch)},host=document.getElementById('samples'),range=document.createRange();host.replaceChildren();return records.map((record,index)=>{
    const x=index%10*128+20,y=Math.floor(index/10)*128+20,sample=document.createElement('div');sample.style.cssText='position:absolute;left:'+x+'px;top:'+y+'px;width:80px;height:80px;font:16px/24px monospace;white-space:pre;text-autospace:no-autospace;color:transparent;writing-mode:'+record.writingMode+';text-orientation:'+record.orientation+';direction:'+record.direction;
    const color=[240,index*2,20],span=document.createElement('span');record.spanCSS='text-decoration-line:'+record.kind+';text-decoration-color:rgb('+color.join(',')+');text-decoration-thickness:2px;text-decoration-skip-ink:none;text-underline-position:'+record.position+';text-underline-offset:0px';span.style.cssText=record.spanCSS;span.textContent=record.source;sample.appendChild(span);host.appendChild(sample);range.selectNodeContents(span);const base=sample.getBoundingClientRect(),r=range.getBoundingClientRect();return {...record,x,y,color,computed:getComputedStyle(span).textUnderlinePosition,textRect:{x:r.x-base.x,y:r.y-base.y,width:r.width,height:r.height}};
   });})()`);
   await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');
   const shot=await browser.send('Page.captureScreenshot',{format:'png',clip:{x:0,y:0,width:1280,height:1280,scale:1}}),image=pixels(shot.data);
   for(let index=0;index<captured.length;index++){
    const record=captured[index];let left=Infinity,right=-Infinity,top=Infinity,bottom=-Infinity,count=0;
    for(let y=record.y-15;y<record.y+100;y++)for(let x=record.x-15;x<record.x+100;x++){const at=(y*image.width+x)*image.channels;if(image.out[at]===record.color[0]&&image.out[at+1]===record.color[1]&&image.out[at+2]===record.color[2]){left=Math.min(left,x);right=Math.max(right,x+1);top=Math.min(top,y);bottom=Math.max(bottom,y+1);count++;}}
    record.paint=count?{x:left-record.x,y:top-record.y,width:right-left,height:bottom-top,count}:null;delete record.x;delete record.y;records[start+index]=record;
   }
  }
  const metrics=await browser.evaluate(String.raw`(()=>{const measure=document.getElementById('measure'),range=document.createRange();measure.style.cssText='position:absolute;left:0;top:0;white-space:pre;font:16px/24px monospace;width:max-content';const values=new Set(['',' ','0']);for(const source of ['天地','ABC'])for(let first=0;first<source.length;first++)for(let last=first+1;last<=source.length;last++)values.add(source.slice(first,last));const measurements={};for(const text of values)for(const control of ['','\u202d','\u202e']){const value=control+text+(control?'\u202c':'');measure.textContent=value;measurements[value]=measure.getBoundingClientRect().width;}range.selectNodeContents(measure);const grammar=['auto','from-font','under','left','right','under left','left under','under right','right under','from-font left','left from-font','from-font right','right from-font','auto left','auto right','under under','left right','from-font under','under auto','left left','none','', 'RIGHT UNDER'].map(value=>({value,supported:CSS.supports('text-underline-position',value)}));return {measurements,nativeHeight:range.getBoundingClientRect().height,grammar,userAgent:navigator.userAgent};})()`);
  fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/vertical-decoration-browser.json'),JSON.stringify({...metrics,records,evidence:'Unmodified Chromium decoration paint, isolated by per-element RGB decoration color and transparent glyph color. Exact-color pixel bounds are physical; UA/font-specific cross offsets are stored without claiming exact Roblox font calibration.'},null,2)+'\n');
  console.log('Vertical decoration:',records.length,'actual native painted line cases');
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});
