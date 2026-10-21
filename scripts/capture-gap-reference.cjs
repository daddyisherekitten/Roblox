const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const folder=path.resolve(__dirname,'../build/gap-reference');fs.mkdirSync(folder,{recursive:true});
const cases=[];
function add(name,css,steps,child='width:40px;height:20px;flex:none',extra=''){
  cases.push({name,html:'<!doctype html><style>body{margin:0}#gapBox{font:16px/20px Arial;align-items:flex-start;align-content:start;'+css+'}#gapBox>div{'+child+'}'+extra+'</style><div id=gapBox><div id=gapA></div><div id=gapB></div></div>',steps:steps.map(style=>({style,width:800}))});
}
add('Flex row definite axes and side overrides','display:flex;width:200px;height:100px',['gap:10% 20%','gap:calc(10% + 5px) calc(20% - 3px)','gap:10%;column-gap:5%','gap:10%;row-gap:normal','gap:calc(10% - 80px)','gap:calc(-2px)','gap:calc(-10%)']);
add('Flex column indefinite and definite block gap','display:flex;flex-direction:column;width:200px',['gap:10%','gap:calc(10% + 5px)','gap:10%;height:100px','gap:calc(10% + 5px);height:100px','gap:clamp(2px, 10%, 8px);height:100px']);
add('Flex cyclic intrinsic inline sizing','display:inline-flex',['gap:10%','gap:calc(10% + 5px)','gap:min(10%, 4px)','gap:0']);
add('Flex wrapped lines resolve each gap against its corresponding axis','display:flex;flex-wrap:wrap;width:100px',['gap:10% 20%','gap:calc(10% + 5px) 20%','gap:10% 20%;height:100px','gap:normal 20%;height:100px'],'width:60px;height:20px;flex:none');
add('Grid cyclic block gap affects placement without growing the container','display:grid;width:200px;grid-template-rows:20px 20px',['gap:10%','gap:calc(10% + 5px)','gap:10%;height:100px','gap:10%;min-height:100px','gap:10%;row-gap:normal']);
add('Grid cyclic intrinsic inline and block sizing','display:inline-grid;grid-template-columns:40px 40px;grid-template-rows:20px 20px',['gap:10%','gap:calc(10% + 5px)','gap:clamp(2px, 10%, 8px)','gap:0']);
add('Grid definite fractions subtract percentage and math gutters','display:grid;width:200px;height:100px;grid-template-columns:1fr 1fr;grid-template-rows:20px',['gap:10%','gap:calc(10% + 5px)','gap:3px;gap:-10%','gap:3px;gap:10% garbage'],'height:20px');
add('Multicol percentage and math column gaps track content width','columns:2;column-fill:balance;width:200px',['column-gap:10%','column-gap:calc(10% + 5px)','column-gap:calc(10% - 80px)','column-gap:normal'],'height:20px','#gapA{break-after:column}');
add('Responsive flex percentage gap reuses physical rows','display:flex;width:50%',['gap:10%','gap:calc(10% + 5px)','gap:10%']);
cases.at(-1).steps[1].width=600;cases.at(-1).steps[2].width=400;
add('Responsive grid and columns percentage gaps','display:grid;width:50%;grid-template-columns:1fr 1fr',['gap:10%','gap:10%','display:block;columns:2;column-gap:10%'],'height:20px','#gapA{break-after:column}');
cases.at(-1).steps[1].width=600;cases.at(-1).steps[2].width=400;
for(const mode of ['vertical-rl','vertical-lr']){
  add('Vertical flex axis mapping '+mode,'display:flex;writing-mode:'+mode+';width:200px;height:100px',['gap:10%','gap:calc(10% + 5px)']);
  cases.at(-1).pending='Broader vertical flex axis mapping is not yet implemented; retained native geometry is evidence, not a passing profile.';
}
const source='<!doctype html><meta charset=utf-8><div id=fixtureHost></div>';
async function capture(){
  const browser=await openBrowser(folder);const fixture={captured:'2026-10-09',standard:'https://www.w3.org/TR/css-align-3/#gap-percent',cases};
  try{await browser.load(source);fixture.browser=await browser.evaluate('navigator.userAgent');
    for(const c of cases){c.expected=[];
      await browser.load(c.html);
      for(const step of c.steps){
        await browser.send('Emulation.setDeviceMetricsOverride',{width:step.width,height:600,deviceScaleFactor:1,mobile:false});
        c.expected.push(await browser.evaluate(`(()=>{const box=document.getElementById('gapBox');box.style.cssText=${JSON.stringify(step.style)};const r=box.getBoundingClientRect(),result=[r.width,r.height];for(const node of box.children){const p=node.getBoundingClientRect();result.push(p.x-r.x,p.y-r.y,p.width,p.height)}return result})()`));
      }
    }
  }finally{await browser.close()}
  fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/gap-browser.json'),JSON.stringify(fixture,null,2)+'\n');
  console.log('Gap geometry: '+cases.length+' native cases, '+cases.reduce((n,c)=>n+c.steps.length,0)+' retained style/resize states captured.');
}
capture().catch(error=>{console.error(error);process.exitCode=1});
