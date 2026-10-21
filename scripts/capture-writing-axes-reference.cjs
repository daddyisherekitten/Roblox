// Physical longhands and actual native scroll alignment across all five modes.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
(async()=>{
 const browser=await openBrowser(path.resolve(__dirname,'../build/writing-axes-reference'));
 try{
  await browser.load('<!doctype html><meta charset="utf-8"><div id="sample"></div><div id="port"><div id="content"><div id="target"></div></div></div>');
  const data=await browser.evaluate(String.raw`(async()=>{
   const modes=['horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'],logical=[],inherited=[],scroll=[];
   const sample=document.getElementById('sample'),port=document.getElementById('port'),content=document.getElementById('content'),target=document.getElementById('target');
   const sides=['top','right','bottom','left'],names=['block-start','block-end','inline-start','inline-end'];
   for(const writingMode of modes)for(const direction of ['ltr','rtl'])for(const orientation of ['mixed','upright','sideways']){
    let css='position:absolute;width:100px;height:80px;border:0 solid;writing-mode:'+writingMode+';direction:'+direction+';text-orientation:'+orientation+';';
    for(const [prefix,base,suffix]of [['margin',10,''],['padding',20,''],['border',30,'-width'],['inset',50,''],['scroll-padding',60,''],['scroll-margin',70,'']])
     names.forEach((name,index)=>css+=prefix+'-'+name+suffix+':'+(base+index+1)+'px;');
    ['start-start','start-end','end-start','end-end'].forEach((name,index)=>css+='border-'+name+'-radius:'+(41+index)+'px;');
    sample.style.cssText=css;const computed=getComputedStyle(sample),values={};
    for(const family of ['margin','padding','border','inset','scroll-padding','scroll-margin'])
     values[family]=sides.map(side=>parseFloat(computed.getPropertyValue(family==='inset'?side:family+'-'+side+(family==='border'?'-width':''))));
    values.radius=['top-left','top-right','bottom-right','bottom-left'].map(corner=>parseFloat(computed.getPropertyValue('border-'+corner+'-radius')));
    logical.push({writingMode,direction,orientation,css,values});
    for(const align of ['start','end','center']){
     port.style.cssText='position:absolute;left:0;top:0;width:100px;height:80px;overflow:scroll;scrollbar-width:none;scroll-padding:4px 6px 8px 10px;writing-mode:'+writingMode+';direction:'+direction+';text-orientation:'+orientation+';';
     content.style.cssText='position:relative;width:600px;height:500px';
     target.style.cssText='position:absolute;left:240px;top:200px;width:40px;height:30px;scroll-margin:3px 5px 7px 9px';
     target.scrollIntoView({block:align,inline:align,behavior:'instant'});
     await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
     const p=port.getBoundingClientRect(),t=target.getBoundingClientRect();
     scroll.push({writingMode,direction,orientation,align,width:port.clientWidth,height:port.clientHeight,x:240-(t.left-p.left),y:200-(t.top-p.top),rawLeft:port.scrollLeft,rawTop:port.scrollTop});
    }
   }
   const parent=document.createElement('div');document.body.appendChild(parent);parent.appendChild(sample);
   for(const parentMode of modes)for(const parentDirection of ['ltr','rtl'])for(const writingMode of modes)for(const direction of ['ltr','rtl']){
    const parentCSS='position:relative;margin:11px 12px 13px 14px;padding:21px 22px 23px 24px;border:0 solid;border-width:31px 32px 33px 34px;top:51px;right:52px;bottom:53px;left:54px;border-radius:41px 42px 43px 44px;scroll-padding:61px 62px 63px 64px;scroll-margin:71px 72px 73px 74px;writing-mode:'+parentMode+';direction:'+parentDirection;
    let css='position:absolute;width:100px;height:80px;border:0 solid;writing-mode:'+writingMode+';direction:'+direction+';';
    for(const [prefix,suffix]of [['margin',''],['padding',''],['border','-width'],['inset',''],['scroll-padding',''],['scroll-margin','']])names.forEach(name=>css+=prefix+'-'+name+suffix+':inherit;');
    ['start-start','start-end','end-start','end-end'].forEach(name=>css+='border-'+name+'-radius:inherit;');
    parent.style.cssText=parentCSS;sample.style.cssText=css;const computed=getComputedStyle(sample),values={};
    for(const family of ['margin','padding','border','inset','scroll-padding','scroll-margin'])values[family]=sides.map(side=>parseFloat(computed.getPropertyValue(family==='inset'?side:family+'-'+side+(family==='border'?'-width':''))));
    values.radius=['top-left','top-right','bottom-right','bottom-left'].map(corner=>parseFloat(computed.getPropertyValue('border-'+corner+'-radius')));
    const parentComputed=getComputedStyle(parent),normativeCSS=css.replace(/([\w-]+):inherit;/g,(_,name)=>name+':'+parentComputed.getPropertyValue(name)+';');
    // Logical1 §4 inherits the parent's namesake logical property. Installed
    // Chrome still copies physical sides; retain it rather than hide the delta.
    sample.style.cssText=normativeCSS;const projected=getComputedStyle(sample),normativeValues={};
    for(const family of ['margin','padding','border','inset','scroll-padding','scroll-margin'])normativeValues[family]=sides.map(side=>parseFloat(projected.getPropertyValue(family==='inset'?side:family+'-'+side+(family==='border'?'-width':''))));
    normativeValues.radius=['top-left','top-right','bottom-right','bottom-left'].map(corner=>parseFloat(projected.getPropertyValue('border-'+corner+'-radius')));
    inherited.push({parentMode,parentDirection,parentCSS,writingMode,direction,css,normativeCSS,values:normativeValues,nativeValues:values,difference:JSON.stringify(values)!==JSON.stringify(normativeValues)?'Installed Chrome inherits physical counterparts; Logical1 §4 requires the parent namesake logical property. Expected values are actual native literal-value projections of parent computed logical values.':null});
   }
   return {userAgent:navigator.userAgent,logical,inherited,scroll,evidence:'Unmodified computed physical longhands and scrollIntoView alignment. x/y use physical canvas offsets derived from actual target rectangles; raw negative RTL browser scroll values are also retained.'};
  })()`);
  fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/writing-axes-browser.json'),JSON.stringify(data,null,2)+'\n');
  console.log('Writing axes:',data.logical.length,'native physical longhand mappings;',data.inherited.length,'parent/child inheritance pairs;',data.scroll.length,'actual native scroll alignments');
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});
