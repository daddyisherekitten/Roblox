// Native paint evidence: unique character colors reveal which source glyphs
// Chromium actually hides. DOM range rectangles alone cannot prove ellipsing.
const fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib');
const {openBrowser}=require('./native-browser.cjs');
function pixels(data){
 const input=Buffer.from(data,'base64'),parts=[];let width,height,channels;
 for(let at=8;at<input.length;){const size=input.readUInt32BE(at),kind=input.toString('ascii',at+4,at+8),body=input.subarray(at+8,at+8+size);at+=size+12;
  if(kind==='IHDR'){width=body.readUInt32BE(0);height=body.readUInt32BE(4);channels=body[9]===2?3:body[9]===6?4:0;if(body[8]!==8||!channels||body[12])throw Error('Unsupported native PNG format');}
  else if(kind==='IDAT')parts.push(body);
 }
 const raw=zlib.inflateSync(Buffer.concat(parts)),stride=width*channels,out=Buffer.alloc(height*stride);
 const paeth=(a,b,c)=>{const p=a+b-c,pa=Math.abs(p-a),pb=Math.abs(p-b),pc=Math.abs(p-c);return pa<=pb&&pa<=pc?a:pb<=pc?b:c;};
 for(let y=0;y<height;y++){const filter=raw[y*(stride+1)];for(let x=0;x<stride;x++){
  const a=x>=channels?out[y*stride+x-channels]:0,b=y?out[(y-1)*stride+x]:0,c=y&&x>=channels?out[(y-1)*stride+x-channels]:0;
  const value=filter===0?0:filter===1?a:filter===2?b:filter===3?Math.floor((a+b)/2):filter===4?paeth(a,b,c):NaN;
  if(!Number.isFinite(value))throw Error('Unsupported native PNG filter');out[y*stride+x]=(raw[y*(stride+1)+x+1]+value)&255;
 }}return {out,width,height,channels};
}
(async()=>{
 const browser=await openBrowser(path.resolve(__dirname,'../build/bidi-ellipsis-reference'));
 try{
  await browser.load('<!doctype html><meta charset="utf-8"><style>body{margin:0;background:white}</style><div id="sample"></div><div id="measure"></div>');
  const records=[],measurements={};
  const words=['שלום 123456','123456 שלום','ABCאבג123XYZ','אבגדהוזחט','ABCDEFGHIJ'];
  for(const source of words)for(const direction of ['ltr','rtl'])for(const width of [20,50,80]){
   const record=await browser.evaluate(`(()=>{const source=${JSON.stringify(source)},direction=${JSON.stringify(direction)},width=${width},sample=document.querySelector('#sample'),measure=document.querySelector('#measure');
    sample.style.cssText='margin:0;padding:0;border:0;background:white;color:black;font:16px/24px monospace;white-space:pre;text-autospace:no-autospace;text-align:start;overflow:hidden;text-overflow:ellipsis;direction:'+direction+';width:'+width+'px';
    const points=Array.from(source),palette=points.map((_,i)=>[40+(i%4)*55,35+(Math.floor(i/4)%4)*55,30+((i*7)%4)*55]);
    sample.replaceChildren(...points.map((text,i)=>{const span=document.createElement('span');span.textContent=text;span.style.color='rgb('+palette[i].join(',')+')';return span;}));
    const bounds=sample.getBoundingClientRect(),selection=getSelection(),range=document.createRange();selection.removeAllRanges();range.selectNodeContents(sample);selection.addRange(range);const copied=selection.toString();selection.removeAllRanges();
    const chars=[...sample.children].map((span,i)=>{range.selectNodeContents(span);const r=range.getBoundingClientRect();return {index:i+1,text:span.textContent,x:r.left-bounds.left,width:r.width,color:palette[i]};});
    measure.style.cssText='position:absolute;top:100px;left:0;white-space:pre;font:16px/24px monospace;direction:ltr;unicode-bidi:normal;width:max-content';const values=new Set(['',' ','0','…']);
    for(let first=0;first<points.length;first++)for(let last=first+1;last<=points.length;last++)values.add(points.slice(first,last).join(''));
    const metrics={};for(const text of values)for(const control of ['', '\u202d','\u202e']){const value=control+text+(control?'\u202c':'');measure.textContent=value;metrics[value]=measure.getBoundingClientRect().width;}
    return {source,direction,width,chars,copied,metrics,bounds:{x:bounds.left,y:bounds.top,width:bounds.width,height:bounds.height},userAgent:navigator.userAgent};})()`);
   const screenshot=await browser.send('Page.captureScreenshot',{format:'png',clip:{...record.bounds,scale:1}}),image=pixels(screenshot.data);
   for(const char of record.chars){let count=0;for(let at=0;at<image.out.length;at+=image.channels)if(image.out[at]===char.color[0]&&image.out[at+1]===char.color[1]&&image.out[at+2]===char.color[2])count++;char.solidPaintPixels=count;}
   measurements[source]=record.metrics;delete record.metrics;records.push(record);
  }
  const target=path.resolve(__dirname,'../tests/fixtures/bidi-ellipsis-browser.json');fs.writeFileSync(target,JSON.stringify({records,measurements,evidence:'Unmodified Chromium ellipsis paint. Per-source-character RGB pixels reveal hidden glyphs; range geometry and logical selection remain raw.'},null,2)+'\n');
  console.log('Bidi ellipsis paint reference:',records.length,'actual native painted overflow cases');
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
