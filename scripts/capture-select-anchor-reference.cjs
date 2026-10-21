const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const folder=path.resolve(__dirname,'../build/select-anchor-reference');fs.mkdirSync(folder,{recursive:true});
const base='html,body{margin:0;padding:0}select{appearance:base-select;position:absolute;left:100px;top:150px;width:200px;font:16px/24px Arial}select::picker(select){appearance:base-select;scrollbar-width:none;position-area:none;position-try-fallbacks:none;inset:auto}';
const options='<select id=s><option id=a>Alpha</option><option id=b>Beta</option></select>';
const anchor=(id,left,width=140,name='--target')=>`<div id=${id} style="anchor-name:${name};position:absolute;left:${left}px;top:50px;width:${width}px;height:30px"></div>`;
const cases=[
 {name:'Implicit originating element supplies coordinates and size',markup:options,css:'select::picker(select){position-anchor:auto;left:calc(anchor(left) + 7px);top:calc(anchor(bottom) + 5px);width:anchor-size(width)}',steps:[{}, {styles:{s:'left:140px;top:100px;width:260px'}}]},
 {name:'None removes implicit anchor and its minimum width',markup:options,css:'select::picker(select){position-anchor:none;left:20px;top:25px;width:180px}',steps:[{}, {picker:'position-anchor:none;left:35px;top:45px;width:120px'}]},
 {name:'Explicit named anchor below top layer wins even later in tree order',markup:options+anchor('other',450),css:'select::picker(select){position-anchor:--target;left:anchor(left);top:anchor(bottom);width:anchor-size(width)}',steps:[{}, {styles:{other:'anchor-name:--target;position:absolute;left:370px;top:70px;width:170px;height:40px'}}]},
 {name:'Missing default uses anchor function fallback and zero UA minimum',markup:options,css:'select::picker(select){position-anchor:--missing;left:anchor(left,50px);top:anchor(bottom,60px);width:180px}',steps:[{}, {picker:'position-anchor:--missing;left:anchor(left,25%);top:anchor(bottom,10%);width:20%'}]},
 {name:'Named scope selects component anchor and changes dynamically',markup:'<section id=scope style="anchor-scope:all">'+anchor('local',300,120)+options+'</section>'+anchor('outside',500,90),css:'select::picker(select){position-anchor:--target;left:anchor(left,13px);top:anchor(bottom,17px);width:anchor-size(width,110px)}',steps:[{}, {styles:{scope:'anchor-scope:none'}}, {styles:{scope:'anchor-scope:--target'}}, {styles:{scope:'anchor-scope:all'}}]},
 {name:'Self scope includes its originating select anchor',markup:'<select id=s style="anchor-name:--self;anchor-scope:--self"><option id=a>Alpha</option><option id=b>Beta</option></select>'+anchor('outside',500,90,'--self'),css:'select::picker(select){position-anchor:--self;left:anchor(left);top:anchor(bottom);width:anchor-size(width)}',steps:[{}, {styles:{s:'anchor-name:--self;anchor-scope:none;left:100px;top:150px;width:200px'}}, {styles:{s:'anchor-name:--self;anchor-scope:--self;left:100px;top:150px;width:200px'}}]},
 {name:'Two named anchor expressions share actual viewport geometry',markup:anchor('one',260,100,'--one')+options+anchor('two',410,80,'--two'),css:'select::picker(select){position-anchor:none;min-width:0;left:calc(anchor(--one right) + 7px);top:calc(anchor(--two bottom) + 5px);width:calc(anchor-size(--one width) + anchor-size(--two width))}',steps:[{}, {styles:{two:'anchor-name:--two;position:absolute;left:420px;top:90px;width:50px;height:40px'}}]},
 {name:'Named position try fits after explicit anchor overflow',markup:anchor('edge',740,40)+options,css:'select::picker(select){position-anchor:--target;left:anchor(right);top:anchor(bottom);width:120px;min-width:0;position-try-fallbacks:--left}@position-try --left{left:auto;right:anchor(left);top:anchor(top);bottom:auto}',steps:[{}, {styles:{edge:'anchor-name:--target;position:absolute;left:580px;top:50px;width:40px;height:30px'}}, {styles:{edge:'anchor-name:--target;position:absolute;left:740px;top:50px;width:40px;height:30px'}}]},
 {name:'Viewport percentages and auto margins retain CSS overconstraint',markup:options,css:'select::picker(select){position-anchor:none;left:10%;right:20%;top:5%;width:180px;min-width:0;margin:0 auto}',steps:[{}, {viewport:{width:650,height:480}}, {viewport:{width:800,height:600}}]},
 {name:'Author positioned picker is independent of visible anchor free space',markup:options.replace('id=s','id=s style="top:-10px;height:620px"'),css:'select::picker(select){position-anchor:none;left:40px;top:30px;width:160px;min-width:0}',steps:[{}, {styles:{s:'left:100px;top:900px;width:200px;height:34px'}}, {styles:{s:'left:100px;top:-1000px;width:200px;height:34px'}}]},
];
async function capture(){const browser=await openBrowser(folder);const fixture={captured:'2026-10-10',standard:'https://drafts.csswg.org/css-anchor-position/',cases};
 try{fixture.browser=await browser.evaluate('navigator.userAgent');for(const c of cases){
  c.html='<!doctype html><style id=reference>'+base+c.css+'</style>'+c.markup;await browser.send('Emulation.setDeviceMetricsOverride',{width:800,height:600,deviceScaleFactor:1,mobile:false});await browser.load(c.html);c.expected=[];
  for(const step of c.steps){
   if(step.viewport)await browser.send('Emulation.setDeviceMetricsOverride',{...step.viewport,deviceScaleFactor:1,mobile:false});
   await browser.evaluate(`(()=>{const step=${JSON.stringify(step)};for(const[id,css]of Object.entries(step.styles||{}))document.getElementById(id).style.cssText=css;if(step.picker!==undefined){let sheet=document.getElementById('pickerChanges');if(!sheet){sheet=document.createElement('style');sheet.id='pickerChanges';document.head.append(sheet)}sheet.textContent='select::picker(select){'+step.picker+'}'}})()`);
   const stayedOpen=await browser.evaluate("s.matches(':open')");
   if(!stayedOpen){const shown=await browser.send('Runtime.evaluate',{expression:'s.showPicker()',userGesture:true});if(shown.exceptionDetails)throw new Error(shown.exceptionDetails.text);}
   await browser.evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
   c.expected.push(await browser.evaluate(`(()=>{const p=getComputedStyle(s,'::picker(select)'),r=a.getBoundingClientRect();const boxes={};for(const e of document.querySelectorAll('[id]:not(style)')){const r=e.getBoundingClientRect();boxes[e.id]=[r.x,r.y,r.width,r.height]}return {open:s.matches(':open'),width:parseFloat(p.width),height:parseFloat(p.height),x:r.x-1,y:r.y-1,boxes,viewport:[innerWidth,innerHeight],positionAnchor:p.positionAnchor,positionArea:p.positionArea}})()`));
   c.expected.at(-1).stayedOpen=stayedOpen;
   if(c.name==='Self scope includes its originating select anchor'&&c.expected.length===2){
    const value=c.expected.at(-1);value.normative={x:100,y:184,width:200,boxes:{...value.boxes,a:[101,185,198,24],b:[101,209,198,24]}};
    value.deviation='The current draft chooses the nearest acceptable ancestor before the last anchor in tree order. The originating select is the picker pseudo-element ancestor; Chromium instead chooses the later outside element when the self scope is removed.';
   }
   if(!c.expected.at(-1).open)throw new Error(c.name+': picker did not remain open');
  }
 }}finally{await browser.close()}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/select-anchor-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Select anchors: '+cases.reduce((n,c)=>n+c.steps.length,0)+' native placement states captured.');
}
capture().catch(error=>{console.error(error);process.exitCode=1});
