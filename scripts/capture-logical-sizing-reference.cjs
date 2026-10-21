const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const folder=path.resolve(__dirname,'../build/logical-sizing-reference');fs.mkdirSync(folder,{recursive:true});
const modes=['horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'];
const names=['width','height','inline-size','block-size','min-width','min-height','min-inline-size','min-block-size','max-width','max-height','max-inline-size','max-block-size'];
const cases=[];
const axisOrder=[];
const base='position:absolute;left:0;top:0;width:140px;height:90px;padding:3px;border:2px solid black;';
function add(name,mode,direction,steps,sheet='',parent=''){
 cases.push({name,html:'<!doctype html><style>body{margin:0}#parent{position:relative;width:400px;height:300px;'+parent+'}#target{'+base+'writing-mode:'+mode+';direction:'+direction+'}'+sheet+'</style><div id=parent><div id=target></div></div>',steps:steps.map(style=>({style,width:800}))});
}
for(const mode of modes)for(const direction of ['ltr','rtl']){
 const label=mode+' '+direction;
 add('Logical/physical declaration order '+label,mode,direction,['inline-size:180px;width:110px;block-size:80px;height:60px','width:110px;inline-size:180px;height:60px;block-size:80px','inline-size:180px!important;width:110px;block-size:80px!important;height:60px']);
 add('Final writing mode independent of declaration position '+label,'horizontal-tb',direction,['inline-size:180px;block-size:80px;writing-mode:'+mode,'writing-mode:'+mode+';inline-size:180px;block-size:80px']);
 add('Logical min/max and minimum precedence '+label,mode,direction,['inline-size:180px;block-size:80px;min-inline-size:190px;max-inline-size:150px;min-block-size:30px;max-block-size:65px','inline-size:180px;block-size:80px;min-inline-size:20px;max-inline-size:150px;min-block-size:30px;max-block-size:65px','width:140px;height:90px;min-width:33px;min-height:27px;max-width:130px;max-height:80px;min-inline-size:70px;max-block-size:65px']);
 add('Percentage/math and invalid after variables '+label,mode,direction,['inline-size:50%;block-size:calc(25% + 10px);min-inline-size:10%;max-block-size:calc(70% - 3px)','--size:175px;inline-size:var(--size);block-size:65px','--size:red;inline-size:170px;inline-size:var(--size);block-size:65px','inline-size:175px;inline-size:-2px;block-size:65px']);
 add('Border-box logical constraints '+label,mode,direction,['box-sizing:border-box;inline-size:180px;block-size:80px','box-sizing:border-box;inline-size:180px;block-size:80px;max-inline-size:160px;min-block-size:95px']);
 add('Same-name logical inheritance '+label,mode,direction,['inline-size:inherit;block-size:inherit;min-inline-size:inherit;min-block-size:inherit;max-inline-size:inherit;max-block-size:inherit'], '', 'writing-mode:'+(mode==='horizontal-tb'?'vertical-rl':'horizontal-tb')+';width:190px;height:170px;min-width:13px;min-height:17px;max-width:230px;max-height:210px;');
 add('Layer rollback retains final mapping '+label,mode,direction,[''], '@layer lower,upper;@layer lower{#target{width:135px;height:75px;writing-mode:horizontal-tb;min-width:11px;min-height:17px;max-width:200px;max-height:170px}}@layer upper{#target{writing-mode:'+mode+';inline-size:180px;inline-size:revert-layer;min-inline-size:revert-layer;max-block-size:revert-layer}}');
 add('Physical layer rollback remaps lower logical declarations '+label,mode,direction,[''], '@layer lower,upper;@layer lower{#target{inline-size:135px;block-size:75px;writing-mode:horizontal-tb;min-inline-size:11px;min-block-size:17px;max-inline-size:200px;max-block-size:170px}}@layer upper{#target{writing-mode:'+mode+';width:revert-layer;height:revert-layer;min-width:revert-layer;max-height:revert-layer}}');
 add('Author-origin rollback and initial '+label,mode,direction,['inline-size:initial;block-size:65px','inline-size:unset;block-size:65px','inline-size:revert;block-size:65px']);
 const declarations='margin-inline-start:13px;padding-block-end:17px;border-inline-end:7px solid black;inset-block-start:19px;border-start-start-radius:23px;scroll-padding-inline-start:29px;scroll-margin-block-end:31px;';
 for(const css of ['writing-mode:horizontal-tb;direction:ltr;'+declarations+'writing-mode:'+mode+';direction:'+direction,'writing-mode:'+mode+';direction:'+direction+';'+declarations,'writing-mode:'+mode+'!important;direction:'+direction+'!important;writing-mode:horizontal-tb;direction:ltr;'+declarations])axisOrder.push({mode,direction,css});
}
add('Retained five-mode switching and viewport resize','horizontal-tb','ltr',modes.map(mode=>'inline-size:180px;block-size:80px;writing-mode:'+mode));
add('Responsive percentage sizes and retained aliases','vertical-rl','ltr',['inline-size:50%;block-size:50%','inline-size:50%;block-size:50%','inline-size:50%;block-size:50%;writing-mode:horizontal-tb']);
cases.at(-1).steps.forEach((step,i)=>step.parentWidth=[400,300,220][i]);
async function capture(){
 const browser=await openBrowser(folder),fixture={captured:'2026-10-10',standards:['https://drafts.csswg.org/css-logical-1/#logical-box-properties','https://drafts.csswg.org/css-logical-1/#dimension-properties'],names,cases,axisOrder};
 try{
  fixture.browser=await browser.evaluate('navigator.userAgent');
  await browser.load('<!doctype html><div id=target style="position:absolute"></div>');
  for(const record of axisOrder)record.values=await browser.evaluate(`(()=>{const t=document.getElementById('target');t.style.cssText='position:absolute;inset:0;'+${JSON.stringify(record.css)};const s=getComputedStyle(t),sides=['top','right','bottom','left'],v={};for(const family of ['margin','padding','border','inset','scroll-padding','scroll-margin'])v[family]=sides.map(side=>parseFloat(s.getPropertyValue(family==='border'?'border-'+side+'-width':family==='inset'?side:family+'-'+side)));v.radius=['top-left','top-right','bottom-right','bottom-left'].map(corner=>parseFloat(s.getPropertyValue('border-'+corner+'-radius')));return v})()`);
  for(const c of cases){c.expected=[];await browser.load(c.html);
   for(const step of c.steps){c.expected.push(await browser.evaluate(`(()=>{const target=document.getElementById('target'),parent=document.getElementById('parent');target.style.cssText=${JSON.stringify(step.style)};${step.parentWidth?'parent.style.width='+JSON.stringify(step.parentWidth+'px')+';':''}const s=getComputedStyle(target),r=target.getBoundingClientRect();return {rect:[r.width,r.height],values:${JSON.stringify(names)}.map(name=>s.getPropertyValue(name))}})()`));}
   if(c.name.startsWith('Same-name logical inheritance')){
    // §4 inherits the namesake parent property. Chromium presently uses the
    // child's physical counterpart instead; raw native evidence stays intact.
    const inherited=await browser.evaluate(`(()=>{const s=getComputedStyle(document.getElementById('parent'));return ${JSON.stringify(names)}.map(name=>s.getPropertyValue(name))})()`);
    const vertical=!c.name.endsWith('horizontal-tb ltr')&&!c.name.endsWith('horizontal-tb rtl');
    const width=inherited[vertical?3:2],height=inherited[vertical?2:3];
    const minW=inherited[vertical?7:6],minH=inherited[vertical?6:7],maxW=inherited[vertical?11:10],maxH=inherited[vertical?10:11];
    c.specExpected=[{rect:[parseFloat(width)+10,parseFloat(height)+10],values:[width,height,inherited[2],inherited[3],minW,minH,inherited[6],inherited[7],maxW,maxH,inherited[10],inherited[11]]}];
    c.difference='CSS Logical §4 namesake inheritance versus Chromium physical inheritance across orthogonal modes.';
   }
  }
 }finally{await browser.close()}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/logical-sizing-browser.json'),JSON.stringify(fixture,null,2)+'\n');
 console.log('Logical sizing: '+cases.length+' native cases and '+cases.reduce((n,c)=>n+c.steps.length,0)+' retained states captured.');
}
capture().catch(error=>{console.error(error);process.exitCode=1});
