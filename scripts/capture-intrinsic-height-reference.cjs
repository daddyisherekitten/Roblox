const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const modes=['horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'],cases=[];
const names=['width','height','inline-size','block-size','min-height','max-height','min-width','max-width'];
const image='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="40"><rect width="80" height="40" fill="red"/></svg>');
function add(name,content,css,steps,tag='div',parent='height:75px;'){
 const replaced=tag==='img'||tag==='input';
 cases.push({name,inputImage:tag==='input',html:'<!doctype html><style>body{margin:0}#parent{width:400px;'+parent+'}#target{font:16px/20px "Courier New";text-orientation:sideways;box-sizing:content-box;padding:3px;border:2px solid black;'+(replaced?'display:block;':'')+css+'}</style><div id=parent><'+tag+' id=target'+(replaced?(tag==='input'?' type=image':'')+' src="'+image+'"':'')+'>'+content+(replaced?'':'</'+tag+'>')+'</div>',steps:steps.map(style=>typeof style==='string'?{style,width:800}:{width:800,...style})});
}
for(const mode of modes){
 const vertical=mode!=='horizontal-tb',logical=vertical?'inline-size':'block-size';
 add('Direct text physical/logical intrinsic height '+mode,'ALPHA BETA GAMMA','width:80px;writing-mode:'+mode+';', ['height:min-content','height:max-content','height:fit-content',logical+':min-content',logical+':max-content',logical+':fit-content','height:min-content;min-height:60px;max-height:25px','height:max-content;max-height:65px','height:auto']);
 add('Forced breaks and nowrap intrinsic height '+mode,'ALPHA BETA<br>GAMMA','width:80px;writing-mode:'+mode+';', ['height:min-content','height:max-content','height:fit-content','height:min-content;white-space:nowrap','height:max-content;box-sizing:border-box']);
 add('Definite opposite-axis ratio intrinsic height '+mode,'ALPHA BETA GAMMA','width:100px;aspect-ratio:1/1;writing-mode:'+mode+';', ['height:min-content','height:max-content','height:fit-content','height:auto','height:min-content;min-height:80px;max-height:60px']);
 if(vertical){
  add('Parallel-mode short text automatic height '+mode,'A','width:80px;writing-mode:'+mode+';', ['height:auto','height:min-content','height:fit-content'], 'div','height:75px;writing-mode:'+mode+';');
  add('Parallel-mode empty automatic height '+mode,'','width:80px;writing-mode:'+mode+';', ['height:auto','height:min-content','height:fit-content'], 'div','height:75px;writing-mode:'+mode+';');
  for(const parallel of [false,true])add('Retained containing height changes '+(parallel?'parallel ':'orthogonal ')+mode,'ALPHA BETA GAMMA','width:80px;writing-mode:'+mode+';', [
   {style:'height:fit-content',parentHeight:30},{style:'height:fit-content',parentHeight:200},
   {style:'height:auto',parentHeight:200},{style:'height:auto',parentHeight:30},{style:'height:auto',parentHeight:75}
  ],'div','height:75px;'+(parallel?'writing-mode:'+mode+';':''));
 }
}
add('Horizontal block content, collapsed margins and intrinsic fallback','<div style="height:30px;margin:7px 0 11px"></div><div style="height:20px;margin:5px 0 0"></div>','width:100px;', ['height:min-content','height:max-content','height:fit-content','height:min-content;min-height:80px;max-height:40px']);
add('Intrinsic height is indefinite for percentage children','<div id=child style="height:50%;font:16px/20px Courier New">A</div>','width:100px;', ['height:min-content','height:max-content','height:fit-content','height:100px','height:auto']);
add('Preferred intrinsic block height preserves aspect ratio transfer','A','width:100px;aspect-ratio:1/1;', ['height:min-content','height:max-content','height:fit-content','height:auto','height:min-content;min-height:50px;max-height:30px']);
add('Intrinsic block height preserves bottom margin collapse','<div style="height:30px;margin:7px 0 11px"></div>','width:100px;padding:0;border:0;', ['height:min-content','height:max-content','height:fit-content','height:auto','height:0px']);
add('Retained content/font/width changes with intrinsic height','ALPHA BETA GAMMA','width:80px;', ['height:max-content','height:max-content;width:140px','height:max-content;font-size:20px;line-height:24px','height:min-content;width:80px']);
for(const mode of modes)add('Replaced image preferred intrinsic sizing '+mode,'','width:160px;writing-mode:'+mode+';', ['height:min-content','height:max-content','height:fit-content','height:auto','height:max-content;min-height:60px;max-height:25px','width:min-content;height:100px','width:max-content;height:max-content','height:max-content;box-sizing:border-box'],'img');
for(const mode of modes){
 const vertical=mode!=='horizontal-tb',axis=vertical?'inline':'block',limits=[];
 for(const bound of ['min','max'])for(const keyword of ['min-content','max-content','fit-content'])for(const height of [10,200])limits.push('height:'+height+'px;'+bound+'-height:'+keyword);
 limits.push('height:10px;min-'+axis+'-size:max-content','height:200px;max-'+axis+'-size:min-content','height:100px;min-height:min-content;max-height:25px','height:100px;max-height:min-content;min-height:120px');
 add('Intrinsic height limits direct text '+mode,'ALPHA BETA GAMMA','width:80px;writing-mode:'+mode+';',limits);
 add('Intrinsic height limits definite ratio '+mode,'ALPHA BETA GAMMA','width:100px;aspect-ratio:1/1;writing-mode:'+mode+';',limits);
 for(const tag of ['img','input'])add('Intrinsic height limits replaced '+tag+' '+mode,'','width:160px;writing-mode:'+mode+';',limits,tag);
}
const blockLimits=[];
for(const layout of ['flex','grid']){
 const widthLimits=[];
 for(const bound of ['min','max'])for(const keyword of ['min-content','max-content','fit-content'])for(const width of [10,200])widthLimits.push('width:'+width+'px;'+bound+'-width:'+keyword);
 widthLimits.push('width:min-content','width:max-content','width:fit-content','width:100px;min-width:min-content;max-width:25px');
 add('Horizontal '+layout+' item intrinsic width limits','ALPHA BETA GAMMA','height:80px;',widthLimits,'div','height:200px;display:'+layout+';align-items:start;'+(layout==='grid'?'grid-template-columns:minmax(0,1fr);':''));
}
for(const mode of modes){
 const vertical=mode!=='horizontal-tb',axis=vertical?'block':'inline',limits=[];
 for(const bound of ['min','max'])for(const keyword of ['min-content','max-content','fit-content'])for(const width of [10,200])limits.push('width:'+width+'px;'+bound+'-width:'+keyword);
 limits.push('width:10px;min-'+axis+'-size:max-content','width:200px;max-'+axis+'-size:min-content','width:100px;min-width:min-content;max-width:25px','width:100px;max-width:min-content;min-width:120px');
 add('Intrinsic width limits direct text '+mode,'ALPHA BETA GAMMA','height:80px;writing-mode:'+mode+';',limits);
 add('Intrinsic width limits definite ratio '+mode,'ALPHA BETA GAMMA','height:100px;aspect-ratio:1/1;writing-mode:'+mode+';',limits);
 for(const tag of ['img','input'])add('Intrinsic width limits replaced '+tag+' '+mode,'','height:80px;writing-mode:'+mode+';',limits,tag);
}
for(const bound of ['min','max'])for(const keyword of ['min-content','max-content','fit-content'])for(const height of ['auto','100px','300px'])blockLimits.push('height:'+height+';'+bound+'-height:'+keyword);
blockLimits.push('height:100px;min-height:min-content;max-height:50px','height:100px;max-height:min-content;min-height:120px');
for(const direction of ['row','column'])add('Horizontal flex '+direction+' item intrinsic height limits','ALPHA BETA GAMMA','width:80px;',blockLimits,'div','height:200px;display:flex;flex-direction:'+direction+';align-items:start;');
add('Intrinsic block height limits preserve percentage child basis','<div id=child style="height:50%"><div style="height:150px"></div></div><div style="height:30px"></div>','width:100px;',blockLimits);
add('Intrinsic block height limits and child margins','<div style="height:30px;margin:7px 0 11px"></div>','width:100px;padding:0;border:0;',blockLimits);
for(const quirks of [false,true])for(const tag of ['html','body'])cases.push({
 name:'Real document preferred intrinsic height '+(quirks?'quirks ':'standards ')+tag,
 html:(quirks?'':'<!doctype html>')+'<html'+(tag==='html'?' id="target"':'')+'><head><style>body{margin:8px}#target{font:16px/20px "Courier New"}</style></head><body'+(tag==='body'?' id="target"':'')+'><div style="height:30px">A</div></body></html>',
 steps:['height:auto','height:min-content','height:max-content','height:fit-content','height:100px'].map(style=>({style,width:800}))
});
(async()=>{
 const browser=await openBrowser(path.resolve(__dirname,'../build/intrinsic-height-reference'));
 const fixture={captured:'2026-10-10',standard:'https://drafts.csswg.org/css-sizing-3/#sizing-values',names,cases};
 try{
  fixture.browser=await browser.evaluate('navigator.userAgent');
  for(const c of cases){await browser.load(c.html);c.expected=[];
   await browser.evaluate('Promise.all(Array.from(document.images).map(image=>image.decode()))');
   if(c.inputImage)await browser.evaluate('(()=>{const image=new Image();image.src=document.getElementById("target").src;return image.decode().then(()=>[image.naturalWidth,image.naturalHeight])})()');
   for(const step of c.steps)c.expected.push(await browser.evaluate(`(()=>{const t=document.getElementById('target');t.style.cssText=${JSON.stringify(step.style)};if(${step.parentHeight!==undefined})document.getElementById('parent').style.height=${JSON.stringify(String(step.parentHeight))}+'px';const r=t.getBoundingClientRect(),s=getComputedStyle(t),child=document.getElementById('child');let lines=null;if(t.childNodes.length===1&&t.firstChild.nodeType===3){const text=t.firstChild,vertical=s.writingMode!=='horizontal-tb',positions=[];lines=[];for(const match of text.data.matchAll(/\\S+/g)){const range=document.createRange();range.setStart(text,match.index);range.setEnd(text,match.index+match[0].length);const box=range.getBoundingClientRect(),position=vertical?box.left:box.top;let line=positions.findIndex(v=>Math.abs(v-position)<.1);if(line<0){line=positions.length;positions.push(position)}lines.push(line+1)}}return {rect:[r.width,r.height],values:${JSON.stringify(names)}.map(n=>s.getPropertyValue(n)),lines,child:child?[child.getBoundingClientRect().width,child.getBoundingClientRect().height]:null,natural:t.tagName==='IMG'?[t.naturalWidth,t.naturalHeight]:${c.inputImage?'[80,40]':'null'}}})()`));
  }
  fixture.glyphWidths=await browser.evaluate(`(()=>{const canvas=document.createElement('canvas'),ctx=canvas.getContext('2d'),out={};for(const size of [16,20]){ctx.font=size+'px "Courier New"';out[size]=ctx.measureText('A').width}return out})()`);
 }finally{await browser.close()}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/intrinsic-height-browser.json'),JSON.stringify(fixture,null,2)+'\n');
 console.log('Intrinsic height: '+cases.length+' cases, '+cases.reduce((sum,c)=>sum+c.steps.length,0)+' native states captured.');
})().catch(error=>{console.error(error);process.exitCode=1});
