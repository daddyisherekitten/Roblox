// Native physical inline border/background rectangles and collapsed-space ranges.
const fs=require('node:fs'),path=require('node:path');const {openBrowser}=require('./native-browser.cjs');
(async()=>{const browser=await openBrowser(path.resolve(__dirname,'../build/vertical-fragments-reference'));
 try{
  await browser.load('<!doctype html><meta charset="utf-8"><div id="sample"></div><span id="measure"></span>');
  const data=await browser.evaluate(String.raw`(()=>{
   const sample=document.getElementById('sample'),measure=document.getElementById('measure'),range=document.createRange(),records=[],measurements={};
   const sources=['天地','ABC','天地 ABC','天地\nABC'];
   for(const writingMode of ['horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'])for(const orientation of ['mixed','upright','sideways'])for(const direction of ['ltr','rtl'])for(const source of sources)for(const decoration of ['slice','clone']){
    const css='font:16px/24px monospace;white-space:'+(source.includes('\n')?'pre':'normal')+';text-autospace:no-autospace;width:120px;height:240px;writing-mode:'+writingMode+';text-orientation:'+orientation+';direction:'+direction;
    const spanCSS='border-style:solid;border-width:2px 3px 4px 5px;padding:6px 7px 8px 9px;background:rgb(10,80,160);box-decoration-break:'+decoration;
    sample.style.cssText=css;sample.innerHTML='';const span=document.createElement('span');span.id='fragment';span.style.cssText=spanCSS;span.textContent=source;sample.appendChild(span);
    const base=sample.getBoundingClientRect(),rects=Array.from(span.getClientRects()).map(r=>({x:r.left-base.left,y:r.top-base.top,width:r.width,height:r.height}));
    const node=span.firstChild,chars=[];for(let offset=0;offset<source.length;offset++){
     range.setStart(node,offset);range.setEnd(node,offset+1);chars.push({start:offset,text:source[offset],rects:Array.from(range.getClientRects()).map(r=>({x:r.left-base.left,y:r.top-base.top,width:r.width,height:r.height}))});
    }
    records.push({writingMode,orientation,direction,source,decoration,css,spanCSS,rects,chars});
   }
   measure.style.cssText='position:absolute;left:0;top:0;white-space:pre;font:16px/24px monospace;width:max-content;direction:ltr;unicode-bidi:normal';
   const values=new Set(['',' ','0']);for(const source of sources)for(let first=0;first<source.length;first++)for(let last=first+1;last<=source.length;last++)values.add(source.slice(first,last));
   for(const text of values)for(const control of ['','\u202d','\u202e']){const value=control+text+(control?'\u202c':'');measure.textContent=value;measurements[value]=measure.getBoundingClientRect().width;}
   range.selectNodeContents(measure);return {userAgent:navigator.userAgent,records,measurements,nativeHeight:range.getBoundingClientRect().height};
  })()`);
  fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/vertical-fragments-browser.json'),JSON.stringify(data,null,2)+'\n');console.log('Vertical fragments:',data.records.length,'actual native border/background layouts');
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});
