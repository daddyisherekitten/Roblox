const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/container-query-reference');fs.mkdirSync(folder,{recursive:true});
const queries=[
 '(width)','(height)','(width:480px)','(height:200px)','(inline-size:480px)','(block-size:200px)',
 '(inline-size:200px)','(block-size:480px)','(min-inline-size:480px)','(max-block-size:200px)',
 '(100px < inline-size <= 480px)','(480px >= inline-size > 100px)','(width>400px) and (height>100px)',
 '(aspect-ratio:12/5)','(orientation:landscape)','(orientation:portrait)','(width:24em)','(width:30em)',
 '(width:30rem)','(inline-size:10em)','(block-size:24em)','(inline-size:calc(10em + 280px))',
 'karte (width>0px)','KARTE (width>0px)','missing (width>0px)','--karte (width>0px)',
 'k\\61 rte (width>0px)','käste (width>0px)','k\\e4 ste (width>0px)',
 'not (unknown)','(unknown) or (width>0px)','(unknown) and (width<0px)',
 'not ((unknown) and (width<0px))','not ((width>0px) and (height>0px))','not (width>0px) and (height>0px)',
 '(width:var(--size))','(width:var(--missing,480px))','not (width:var(--missing))','(width:var(--ink))',
 '(height:var(--height))','(inline-size:var(--size))','(block-size:var(--height))',
 '(width:calc(var(--size) + 0px))','(var(--minimum) < width <= var(--size))',
 '(aspect-ratio:var(--ratio))','(orientation:var(--orientation))','(width:50vw)',
 'karte/**/(width>0px)','/*prefix*/karte (width>0px)',
];
const scenes=[];
for(const type of ['size','inline-size','normal'])for(const writingMode of ['horizontal-tb','vertical-rl'])for(const fontSize of [16,20])scenes.push({type,writingMode,fontSize});
function variableExpectation(source,scene){
 const vertical=scene.writingMode!=='horizontal-tb',size=scene.type==='size',inline=scene.type==='inline-size';
 const width=size||inline&&!vertical,height=size||inline&&vertical;
 if(['(width:var(--size))','(width:var(--missing,480px))','(width:calc(var(--size) + 0px))','(var(--minimum) < width <= var(--size))'].includes(source))return width;
 if(source==='(height:var(--height))')return height;
 if(source==='(inline-size:var(--size))')return (size||inline)&&!vertical;
 if(source==='(block-size:var(--height))')return size&&!vertical;
 if(['(aspect-ratio:var(--ratio))','(orientation:var(--orientation))'].includes(source))return size;
 return false;
}
(async()=>{
 const browser=await openBrowser(folder),cases=[];
 try{
  const userAgent=await browser.evaluate('navigator.userAgent');
  for(const scene of scenes){
   const css=`html{font-size:16px}#container{--size:480px;--height:200px;--minimum:100px;--ratio:12/5;--orientation:landscape;--ink:red;container-type:${scene.type};container-name:karte --karte käste;width:480px;height:200px;font-size:${scene.fontSize}px;writing-mode:${scene.writingMode};padding:5px;border:2px solid;box-sizing:content-box}`;
   const children=queries.map((q,i)=>`<span id="probe${i}"></span>`).join('');
   const rules=queries.map((q,i)=>`@container ${q}{#probe${i}{--match:yes}}`).join('\n');
   await browser.load('<!doctype html><style>'+css+rules+'</style><div id="container">'+children+'</div>');
   const expected=await browser.evaluate(`(()=>{const c=document.getElementById('container'),s=getComputedStyle(c);return {viewportWidth:innerWidth,viewportHeight:innerHeight,custom:Object.fromEntries(['--size','--height','--minimum','--ratio','--orientation','--ink'].map(n=>[n,s.getPropertyValue(n)])),fontSize:parseFloat(s.fontSize),width:parseFloat(s.width),height:parseFloat(s.height),names:s.containerName.split(' '),writingMode:s.writingMode,type:s.containerType,matches:${JSON.stringify(queries)}.map((source,i)=>({source,matches:getComputedStyle(document.getElementById('probe'+i)).getPropertyValue('--match').trim()==='yes'}))}})()`);
   for(const query of expected.matches)if(query.source.includes('var(')){
    const normativeMatches=variableExpectation(query.source,scene);
    if(normativeMatches!==query.matches)Object.assign(query,{normativeMatches,deviation:'CSS Conditional 5 resolves var() against the selected container. Chromium does not implement size-query variable substitution in this snapshot.'});
   }
   cases.push({...scene,...expected});
  }
  fs.writeFileSync(path.join(root,'tests/fixtures/container-query-browser.json'),JSON.stringify({browser:userAgent,captured:'2026-10-09',source:'https://drafts.csswg.org/css-conditional-5/',cases},null,2)+'\n');
  console.log('Container queries: '+cases.length+' scenes, '+cases.reduce((n,c)=>n+c.matches.length,0)+' native outcomes captured.');
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
