// Native writing-mode observations. Unicode orientation is never calculated
// inside the browser; Range geometry and source selection are recorded raw.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
(async()=>{
 const browser=await openBrowser(path.resolve(__dirname,'../build/vertical-mixed-reference'));
 try{
  await browser.load('<!doctype html><meta charset="utf-8"><div id="sample"></div><span id="measure"></span>');
  const data=await browser.evaluate(String.raw`(()=>{
   const sample=document.getElementById('sample'),measure=document.getElementById('measure'),range=document.createRange(),records=[],measurements={};
   const inputs=['天地ABC天地','カタカナ xyz 한글','A\u0308天地12','AB\u20dd天地CD','אבג天地123','天地\nABC\nカナ','A👩‍💻B','天地ー、。「」'];
   for(const source of inputs)for(const writingMode of ['vertical-rl','vertical-lr','sideways-rl','sideways-lr'])for(const orientation of ['mixed','upright','sideways'])for(const direction of ['ltr','rtl']){
    sample.style.cssText='margin:0;padding:0;border:0;font:16px/24px monospace;text-autospace:no-autospace;white-space:pre;text-align:start;width:120px;height:240px;writing-mode:'+writingMode+';text-orientation:'+orientation+';direction:'+direction;
    sample.textContent=source;const base=sample.getBoundingClientRect(),node=sample.firstChild,chars=[];
    for(let offset=0;offset<source.length;){const length=source.codePointAt(offset)>65535?2:1;
     range.setStart(node,offset);range.setEnd(node,offset+length);
     chars.push({start:offset,finish:offset+length,text:source.slice(offset,offset+length),rects:Array.from(range.getClientRects()).map(r=>({x:r.left-base.left,y:r.top-base.top,width:r.width,height:r.height}))});offset+=length;
    }
    const selection=getSelection();selection.removeAllRanges();range.selectNodeContents(sample);selection.addRange(range);
    const geometryLimit=writingMode.startsWith('sideways-')||orientation==='sideways'?null:source.includes('한')?'fallback-font vertical metrics':source.includes('\u20dd')?'Chrome enclosing-mark grapheme orientation':source.includes('👩')?'emoji vertical metrics and joining':source.includes('אב')&&orientation==='upright'?'Chrome upright strong-LTR ordering and fallback metrics':null;
    records.push({source,writingMode,orientation,direction,width:120,height:240,chars,copied:selection.toString(),computedDirection:getComputedStyle(sample).direction,geometryLimit});
   }
   measure.style.cssText='position:absolute;left:0;top:0;white-space:pre;font:16px/24px monospace;width:max-content;direction:ltr;unicode-bidi:normal';
   const values=new Set(['',' ','0']);
   for(const source of inputs){const points=Array.from(source);for(let first=0;first<points.length;first++)for(let last=first+1;last<=points.length;last++)values.add(points.slice(first,last).join(''));}
   for(const text of values)for(const control of ['','\u202d','\u202e']){const value=control+text+(control?'\u202c':'');measure.textContent=value;measurements[value]=measure.getBoundingClientRect().width;}
   range.selectNodeContents(measure);
   return {userAgent:navigator.userAgent,records,measurements,nativeHeight:range.getBoundingClientRect().height};
  })()`);
  fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/vertical-mixed-browser.json'),JSON.stringify(data,null,2)+'\n');
  console.log('Vertical orientation reference:',data.records.length,'actual layouts');
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});
