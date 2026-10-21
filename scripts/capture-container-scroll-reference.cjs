const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/container-scroll-reference');fs.mkdirSync(folder,{recursive:true});
const queries=[];
for(const name of ['scrollable','scrolled','stuck','snapped']){
 queries.push(`scroll-state(${name})`);
 const values=name==='snapped'?['none','x','y','inline','block','both']:['none','top','right','bottom','left','inline-start','inline-end','block-start','block-end',...(name==='stuck'?[]:['x','y','inline','block'])];
 for(const value of values)queries.push(`scroll-state(${name}:${value})`);
}
queries.push('scroll-state((scrollable:bottom) and (scrollable:right))','scroll-state(not (scrollable:none))','not scroll-state(scrolled)','not scroll-state(unknown)','scroll-state(stuck: invalid)','scroll-state(snapped > x)');
(async()=>{
 const browser=await openBrowser(folder),cases=[];
 try{
  const userAgent=await browser.evaluate('navigator.userAgent');
  for(const scenario of ['scrollable','relative','sticky','snap'])for(const direction of ['ltr','rtl']){
   const targets=scenario==='snap'?['one','two','three']:['target'];
   const rules=targets.flatMap(target=>queries.map((q,i)=>`@container ${q}{#${target} #p${target}${i}{--match:yes}}`)).join('\n');
   const probes=target=>queries.map((_,i)=>`<span id="p${target}${i}"></span>`).join('');
   const common='html,body{margin:0}span{font-size:0}#port{width:200px;height:100px;overflow:auto;direction:'+direction+'}';
   const portQuery=scenario==='scrollable'||scenario==='relative';
   const html=portQuery?'<div id="port"><div id="target">'+probes('target')+'<div style="width:400px;height:300px"></div></div></div>':scenario==='sticky'?'<div id="port"><div style="height:40px"></div><div id="target">'+probes('target')+'</div><div style="height:300px"></div></div>':'<div id="port">'+targets.map(id=>'<div id="'+id+'">'+probes(id)+'</div>').join('')+'</div>';
   const css=portQuery?'#port{container-type:scroll-state}':scenario==='sticky'?'#target{container-type:scroll-state;position:sticky;top:0;height:20px}':'#port{scroll-snap-type:y mandatory}#port>div{container-type:scroll-state;height:100px;scroll-snap-align:start}';
   await browser.load('<!doctype html><style>'+common+css+rules+'</style>'+html);
   // The scrollable query's nearest container is the port; others are targets.
   for(const requested of scenario==='relative'?[0,50,150,-100,0]:scenario==='scrollable'?[0,50,200,50,0]:scenario==='sticky'?[0,20,80,260,0]:[0,100,200,100,0]){
    const result=await browser.evaluate(`(async()=>{const p=document.getElementById('port');${scenario==='relative'?`p.scrollBy(0,${requested})`:`p.scrollTop=${requested}`};await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(()=>requestAnimationFrame(r))));return {scrollTop:p.scrollTop,scrollLeft:p.scrollLeft,scrollWidth:p.scrollWidth,scrollHeight:p.scrollHeight,clientWidth:p.clientWidth,clientHeight:p.clientHeight,targets:${JSON.stringify(targets)}.map(id=>({id,matches:${JSON.stringify(queries)}.map((source,i)=>({source,matches:getComputedStyle(document.getElementById('p'+id+i)).getPropertyValue('--match').trim()==='yes'}))}))}})()`);
    for(const target of result.targets)for(const query of target.matches){
     if(scenario!=='sticky'&&query.source==='scroll-state(stuck:none)')Object.assign(query,{normativeMatches:false,deviation:'CSS Conditional 5: no stuck value matches a non-sticky container; native Chromium matches none.'});
     if(!portQuery){
      if(['scroll-state(scrollable:none)','scroll-state(scrolled:none)'].includes(query.source))Object.assign(query,{normativeMatches:false,deviation:'CSS Conditional 5: no value matches a container that is not a scroll container; native Chromium matches none.'});
      if(query.source==='scroll-state(not (scrollable:none))')Object.assign(query,{normativeMatches:true,deviation:'CSS Conditional 5: scrollable:none is false for a non-scroll container, so its known negation is true.'});
     }
    }
    cases.push({scenario,direction,requested,...result});
   }
  }
  fs.writeFileSync(path.join(root,'tests/fixtures/container-scroll-browser.json'),JSON.stringify({browser:userAgent,captured:'2026-10-09',source:'https://drafts.csswg.org/css-conditional-5/',cases},null,2)+'\n');
  console.log('Container scroll states: '+cases.length+' snapshots, '+cases.reduce((n,c)=>n+c.targets.reduce((t,p)=>t+p.matches.length,0),0)+' native outcomes captured.');
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
