const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const folder=path.resolve(__dirname,'../build/position-area-reference');fs.mkdirSync(folder,{recursive:true});
const modes=['horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'];
const values=['none','top','bottom','left','right','center','span-all','top left','right bottom','span-left top','bottom span-all','span-bottom span-right','x-start y-end','span-x-end y-start','self-x-start self-y-end','block-start inline-end','span-block-end inline-start','self-block-start self-inline-end','start end','span-start end','self-start self-end','center inline-end','span-all block-start','self-block-end span-self-inline-end'];
const syntax=[...values,'CENTER','t\\6f p','left right','top bottom','block-start self-inline-end','self-block-start inline-end','left inline-start','x-start block-start','start block-start','self-start start','span-all span-all','center center','span-all center','span-all self-end','top span-self-x-end'];
const cases=[];
function add(name,area,rootMode='horizontal-tb',rootDir='ltr',selfMode=rootMode,selfDir=rootDir,extra=''){
 if(area==='none')extra+='left:20px;top:25px;'; // Isolate the no-area baseline from ordinary auto-inset static positioning.
 const html='<!doctype html><style>html,body{margin:0;padding:0}#root{position:fixed;left:40px;top:30px;width:400px;height:260px;writing-mode:'+rootMode+';direction:'+rootDir+'}#anchor{position:absolute;anchor-name:--a;left:160px;top:90px;width:70px;height:35px}#tip{position:absolute;position-anchor:--a;position-area:'+area+';inset:auto;margin:0;width:60px;height:25px;writing-mode:'+selfMode+';direction:'+selfDir+';'+extra+'}</style><div id=root><div id=anchor></div><div id=tip></div></div>';
 cases.push({name,area,html});
}
for(const mode of modes)for(const dir of ['ltr','rtl'])for(const value of values)add(mode+'/'+dir+'/'+value,value,mode,dir);
for(const mode of modes)for(const dir of ['ltr','rtl'])for(const value of ['self-block-start self-inline-end','self-start self-end','self-x-start self-y-end','self-block-end span-self-inline-end'])add('self/'+mode+'/'+dir+'/'+value,value,'horizontal-tb','ltr',mode,dir);
for(const [name,area,extra]of [
 ['percentages','bottom right','width:50%;height:25%'],
 ['percent-padding','bottom right','width:50%;height:25%;padding:5%;box-sizing:border-box'],
 ['percent-insets','bottom right','left:10%;right:5%;top:10%;bottom:5%'],
 ['auto-stretch','bottom right','width:auto;height:auto'],
 ['one-inset','bottom right','left:12px'],
 ['auto-margins','bottom right','margin:auto'],
 ['sized-margins','bottom right','margin:5px 10px'],
 ['max-percent','bottom right','width:200px;height:200px;max-width:100%;max-height:100%'],
 ['align-start','bottom right','align-self:start;justify-self:start'],
 ['align-center','bottom right','align-self:center;justify-self:center'],
 ['align-end','top left','align-self:end;justify-self:end'],
 ['align-stretch','bottom right','width:auto;height:auto;align-self:stretch;justify-self:stretch'],
 ['anchor-insets','bottom right','left:anchor(left);top:anchor(bottom)'],
])add(name,area,'horizontal-tb','ltr','horizontal-tb','ltr',extra);
for(const dir of ['ltr','rtl'])for(const [name,area,extra,anchor]of [
 ['oversize-all','span-all','width:450px;height:300px','left:160px;top:90px;width:70px;height:35px'],
 ['outside-left','top','width:140px','left:-50px;top:90px;width:70px;height:35px'],
 ['outside-right','bottom','width:140px','left:390px;top:90px;width:70px;height:35px'],
 ['wide-center','center','width:200px;height:100px','left:10px;top:10px;width:70px;height:35px'],
]){add(name+'/'+dir,area,'horizontal-tb',dir,'horizontal-tb',dir,extra);cases.at(-1).html=cases.at(-1).html.replace('left:160px;top:90px;width:70px;height:35px',anchor);}
const fallbacks=[];
for(const mode of modes)for(const dir of ['ltr','rtl'])for(const recipe of ['flip-block','flip-inline','flip-x flip-y','flip-start','top span-right','self-block-start span-self-inline-end','--above']){
 add('fallback/'+mode+'/'+dir+'/'+recipe,'bottom span-right',mode,dir,mode,dir,'width:80px;height:35px;position-try-fallbacks:'+recipe);
 const c=cases.pop();c.html=c.html.replace('left:160px;top:90px;width:70px;height:35px','left:350px;top:220px;width:40px;height:25px').replace('</style>','@position-try --above{position-area:top span-left}</style>');c.steps=[{}, {left:80,top:60},{left:350,top:220}];fallbacks.push(c);
}
for(const order of ['most-width','most-height','most-inline-size','most-block-size']){
 add('order/'+order,'bottom span-right','horizontal-tb','ltr','horizontal-tb','ltr','width:80px;height:35px;position-try:'+order+' top span-right, bottom span-left, top span-left');
 const c=cases.pop();c.html=c.html.replace('left:160px;top:90px;width:70px;height:35px','left:350px;top:220px;width:40px;height:25px');c.steps=[{}, {left:80,top:60},{left:350,top:220}];fallbacks.push(c);
}
const tries=['top span-right, bottom span-left','self-block-start span-self-inline-end','most-height block-start inline-end, block-end inline-start','flip-block, top','top flip-block','none, bottom','top,','--a flip-x','span-all span-all'];
async function main(){const browser=await openBrowser(folder);const fixture={captured:'2026-10-10',standard:'https://drafts.csswg.org/css-anchor-position/#position-area',cases,fallbacks,syntax:[],syntaxTries:[]};let active='start';
 try{fixture.browser=await browser.evaluate('navigator.userAgent');
  for(const c of cases){active=c.name;await browser.load(c.html);c.expected=await browser.evaluate("(()=>{const r=tip.getBoundingClientRect(),s=getComputedStyle(tip);return {rect:[r.x,r.y,r.width,r.height],area:s.positionArea,declared:tip.style.positionArea,width:s.width,height:s.height,left:s.left,top:s.top,align:s.alignSelf,justify:s.justifySelf}})()");}
  for(const c of fallbacks){await browser.load(c.html);c.expected=[];for(const step of c.steps){active=c.name+'/'+c.expected.length;if(step.left!==undefined)await browser.evaluate('anchor.style.left='+JSON.stringify(step.left+'px')+';anchor.style.top='+JSON.stringify(step.top+'px'));await browser.evaluate('new Promise(r=>setTimeout(r,50))');c.expected.push(await browser.evaluate("(()=>{const r=tip.getBoundingClientRect(),s=getComputedStyle(tip);return {rect:[r.x,r.y,r.width,r.height],area:s.positionArea,tries:s.positionTryFallbacks,order:s.positionTryOrder}})()"));}}
  await browser.load('<!doctype html><div id=tip></div>');
  for(const value of syntax){active='area grammar '+value;fixture.syntax.push(await browser.evaluate(`(()=>{tip.style.positionArea='';tip.style.positionArea=${JSON.stringify(value)};return {source:${JSON.stringify(value)},supported:CSS.supports('position-area',${JSON.stringify(value)}),declared:tip.style.positionArea,computed:getComputedStyle(tip).positionArea}})()`));}
  for(const value of tries){active='try grammar '+value;fixture.syntaxTries.push(await browser.evaluate(`(()=>{tip.style.positionTry='';tip.style.positionTry=${JSON.stringify(value)};return {source:${JSON.stringify(value)},supported:CSS.supports('position-try',${JSON.stringify(value)}),declared:tip.style.positionTry,computed:getComputedStyle(tip).positionTry,fallbacks:getComputedStyle(tip).positionTryFallbacks,order:getComputedStyle(tip).positionTryOrder}})()`));}
 }catch(error){throw new Error(active+': '+error.message)}finally{await browser.close()}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/position-area-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Position areas: '+cases.length+' native geometries, '+fallbacks.reduce((n,c)=>n+c.steps.length,0)+' fallback states, '+syntax.length+' area and '+tries.length+' try grammar/serialization results captured.');
}
main().catch(error=>{console.error(error);process.exitCode=1});
