const fs=require('node:fs'),path=require('node:path'),pixels=require('./native-png.cjs');
const {openBrowser}=require('./native-browser.cjs');
(async()=>{const browser=await openBrowser(path.resolve(__dirname,'../build/vertical-shadow-reference'));
 try{
  await browser.send('Emulation.setDeviceMetricsOverride',{width:192,height:192,deviceScaleFactor:1,mobile:false});
  const records=[];for(const writingMode of ['horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'])for(const orientation of ['mixed','upright','sideways'])for(const direction of ['ltr','rtl'])for(const source of ['天地','ABC'])for(const offset of [[40,40],[-40,40],[40,-40],[-40,-40]])records.push({writingMode,orientation,direction,source,offset});
  for(let start=0;start<records.length;start++){
   await browser.load('<!doctype html><meta charset="utf-8"><style>body{margin:0;background:white}</style><div id="samples"></div>');
   const batch=await browser.evaluate(`(()=>{const records=${JSON.stringify(records.slice(start,start+1))},host=document.getElementById('samples');return records.map((record,index)=>{
    const x=56,y=56,sample=document.createElement('div');sample.id='sample';sample.style.cssText='position:absolute;left:'+x+'px;top:'+y+'px;width:80px;height:80px;font:16px/24px monospace;white-space:pre;text-autospace:no-autospace;writing-mode:'+record.writingMode+';text-orientation:'+record.orientation+';direction:'+record.direction+';color:black;text-shadow:none';sample.textContent=record.source;host.appendChild(sample);return {...record,x,y};
   });})()`);
   for(let index=0;index<batch.length;index++){
    const record=batch[index];for(const key of ['foreground','shadow']){let left=Infinity,right=-Infinity,top=Infinity,bottom=-Infinity,count=0;
     if(key==='shadow')await browser.evaluate(`(()=>{const s=document.getElementById('sample');s.style.color='transparent';s.style.textShadow='${record.offset[0]}px ${record.offset[1]}px black';})()`);
     await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');
     const shot=await browser.send('Page.captureScreenshot',{format:'png',clip:{x:0,y:0,width:192,height:192,scale:1}}),image=pixels(shot.data);
     // Separate actual foreground-only and shadow-only screenshots avoid RGB
     // coverage-ray assumptions under LCD versus grayscale antialiasing.
     for(let y=0;y<image.height;y++)for(let x=0;x<image.width;x++){const at=(y*image.width+x)*image.channels;if(Math.min(image.out[at],image.out[at+1],image.out[at+2])<245){left=Math.min(left,x);right=Math.max(right,x+1);top=Math.min(top,y);bottom=Math.max(bottom,y+1);count++;}}
     record[key+'Paint']=count?{x:left-record.x,y:top-record.y,width:right-left,height:bottom-top,count}:null;
    }
    delete record.x;delete record.y;records[start+index]=record;
   }
  }
  const decoration=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../tests/fixtures/vertical-decoration-browser.json'),'utf8'));
  fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/vertical-shadow-browser.json'),JSON.stringify({records,measurements:decoration.measurements,nativeHeight:decoration.nativeHeight,userAgent:decoration.userAgent,evidence:'Actual independent foreground-only and shadow-only black-ink screenshots. Raw glyph antialiasing bounds/counts retained; no CSS text or Range position substitutes for painted shadow geometry.'},null,2)+'\n');
  console.log('Vertical shadows:',records.length,'actual native signed X/Y painted offsets');
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});
