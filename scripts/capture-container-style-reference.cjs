const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/container-style-reference');fs.mkdirSync(folder,{recursive:true});
const queries=[
 'style(--theme)','style(--missing)','style(--theme: dark)','style(--theme: light)','style(--Theme: Dark)',
 'style(--Theme: dark)','style(--th\\65 me: dark)','style(--empty)','style(--empty:)','style(--theme: initial)',
 'style(--missing: initial)','style(--theme: inherit)','style(--theme: unset)','style(--theme: revert)',
 'not style(--theme: revert)','style(--theme: var(--alias))','style(--theme: var(--missing, dark))',
 'style(--missing: var(--missing))','style(--theme: dark !important)',
 'style((--theme: dark) and (--Theme: Dark))','style((--theme: dark) or (--missing))',
 'style(not (--theme: dark))','not style(--theme: dark)','(style(--theme: dark))',
 'card style(--theme: dark)','CARD style(--theme: dark)','--card style(--theme: dark)',
 '(width:480px) and style(--theme: dark)','style(--theme: dark) or (width:0px)',
 'style(--tokens: a b)','style(--tokens: a/**/b)','style(--punct: a , b)','style(--punct: a,b)',
 'style(--quoted: "hi")',"style(--quoted: 'hi')",'style(--decimal: 1.0)','style(--decimal: 1)',
 'style(--count)','style(--count: 2)','style(--count: calc(1 + 1))','style(--length: 1em)',
 'style(--length: 20px)','style(--length: calc(10px + 10px))','style(--ink: red)',
 'style(--ink: rgb(255 0 0))','style(--initial-count)','style(--initial-count: 2)',
 'style(--count > 1)','style(1 < --count <= 3)','style(--length >= 20px)','style(--decimal = 1)',
 'style(--length > 0)','style(--duration: 1000ms)','style(--duration = 1s)',
 'style(--angle = 180deg)','style(--frequency = 1000Hz)','style(--resolution = 96dpi)',
 'style(unknown())','not style(unknown())','style((--theme: dark) and (--missing) or (--empty))',
];
const registration='@property --count{syntax:"<number>";inherits:true;initial-value:1}@property --length{syntax:"<length>";inherits:true;initial-value:0px}@property --ink{syntax:"<color>";inherits:true;initial-value:black}@property --initial-count{syntax:"<number>";inherits:true;initial-value:2}';
const values='--theme:dark;--Theme:Dark;--empty:;--alias:dark;--tokens:a b;--punct:a,b;--quoted:"hi";--decimal:1.0;--count:2;--length:20px;--ink:red;--duration:1s;--angle:.5turn;--frequency:1kHz;--resolution:1dppx';
const scenes=[];for(const type of ['normal','inline-size','size'])for(const fontSize of [16,20])scenes.push({type,fontSize});
(async()=>{
 const browser=await openBrowser(folder),cases=[];
 try{
  const userAgent=await browser.evaluate('navigator.userAgent');
  for(const scene of scenes){
   const css=registration+`html{font-size:16px}#outer{--theme:light}#container{${values};container-type:${scene.type};container-name:card --card;width:480px;height:200px;font-size:${scene.fontSize}px}`;
   const children=queries.map((q,i)=>`<span id="probe${i}"></span>`).join('');
   const rules=queries.map((q,i)=>`@container ${q}{#probe${i}{--match:yes}}`).join('\n');
   await browser.load('<!doctype html><style>'+css+rules+'</style><div id="outer"><div id="container">'+children+'</div></div>');
   const actual=await browser.evaluate(`(()=>{const s=getComputedStyle(document.getElementById('container'));return {custom:Object.fromEntries(${JSON.stringify([...new Set(values.match(/--[\w-]+(?=:)/g).concat('--initial-count'))])}.map(n=>[n,s.getPropertyValue(n)])),matches:${JSON.stringify(queries)}.map((source,i)=>({source,matches:getComputedStyle(document.getElementById('probe'+i)).getPropertyValue('--match').trim()==='yes'}))}})()`);
   for(const query of actual.matches)if(query.source==='style(--frequency = 1000Hz)')Object.assign(query,{normativeMatches:true,deviation:'CSS Conditional 5 style ranges include frequency; 1kHz equals 1000Hz. Native Chromium does not match this frequency query.'});
   cases.push({...scene,...actual});
  }
  fs.writeFileSync(path.join(root,'tests/fixtures/container-style-browser.json'),JSON.stringify({browser:userAgent,captured:'2026-10-09',source:'https://drafts.csswg.org/css-conditional-5/',registration,values,cases},null,2)+'\n');
  console.log('Container styles: '+cases.length+' scenes, '+cases.reduce((n,c)=>n+c.matches.length,0)+' native outcomes captured.');
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
