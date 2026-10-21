const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const folder=path.resolve(__dirname,'../build/select-picker-reference');fs.mkdirSync(folder,{recursive:true});
const common='<!doctype html><style>select{appearance:base-select;width:200px;font:16px/24px Arial}select::picker(select){appearance:base-select;scrollbar-width:none}';
const cases=[{
 name:'Default picker shares normal rich option and group flow',
 html:common+'</style><select id=s><option id=a>Alpha</option><optgroup id=g label=Group><option id=b>Beta</option><option id=c>Gamma</option></optgroup></select>',targets:['a','g','b','c'],steps:[{}, {styles:{s:'width:260px'}}, {styles:{b:'height:40px'}}, {styles:{b:'height:24px'}}],
},{
 name:'Picker box dimensions, padding and borders participate in layout',
 html:common+'select::picker(select){width:300px;padding:10px 12px;border:3px solid red}option img{display:block}</style><select id=s><option id=a>Alpha</option><option id=b><img width=18 height=36></option></select>',targets:['a','b'],steps:[{}, {picker:'width:360px;padding:4px;border:2px solid blue'}, {picker:'width:300px;padding:0;border:1px solid black'}],
},{
 name:'Grid picker places the original option boxes in shared tracks',
 html:common+'select::picker(select){display:grid;width:320px;grid-template-columns:1fr 1fr;gap:8px;padding:6px}</style><select id=s><option id=a>Alpha</option><option id=b>Beta</option><option id=c>Gamma</option><option id=d>Delta</option></select>',targets:['a','b','c','d'],steps:[{}, {picker:'display:grid;width:320px;grid-template-columns:1fr 1fr;gap:12px;padding:10px'}, {picker:'display:block;width:320px;padding:0'}],
},{
 name:'Author option display and spacing are not forced into private rows',
 html:common+'select::picker(select){width:300px}option{display:block;padding:8px 10px;border:2px solid red}</style><select id=s><option id=a>Alpha</option><option id=b>Beta</option></select>',targets:['a','b'],steps:[{}, {styles:{a:'display:flex;height:48px;padding:0;border:0'}}, {styles:{a:'display:none'}}, {styles:{a:''}}],
},{
 name:'Scrollable picker keeps CSS max height and original variable rows',
 html:common+'select::picker(select){width:300px;max-height:72px}option{height:32px}</style><select id=s><option id=a>Alpha</option><option id=b>Beta</option><option id=c>Gamma</option><option id=d>Delta</option></select>',targets:['a','b','c','d'],steps:[{}, {picker:'width:300px;max-height:104px'}, {picker:'width:300px;height:48px;max-height:none'}],
},{
 name:'Picker percentage width resolves against its viewport',
 html:common+'select::picker(select){width:50%;padding:6px}</style><select id=s><option id=a>Alpha</option><option id=b>Beta</option></select>',targets:['a','b'],steps:[{}, {picker:'width:75%;padding:2px'}, {picker:'width:25%;padding:0'}],
}];
async function capture(){const browser=await openBrowser(folder);const fixture={captured:'2026-10-09',standard:'https://html.spec.whatwg.org/multipage/rendering.html#the-select-element-2',cases};
 try{fixture.browser=await browser.evaluate('navigator.userAgent');for(const c of cases){await browser.load(c.html);c.expected=[];
  for(const step of c.steps){await browser.evaluate(`(()=>{const step=${JSON.stringify(step)};for(const [id,css]of Object.entries(step.styles||{}))document.getElementById(id).style.cssText=css;if(step.picker!==undefined){let sheet=document.getElementById('pickerChanges');if(!sheet){sheet=document.createElement('style');sheet.id='pickerChanges';document.head.append(sheet)}sheet.textContent='select::picker(select){scrollbar-width:none;appearance:base-select;'+step.picker+'}'}})()`);
   if(!await browser.evaluate("s.matches(':open')")){const shown=await browser.send('Runtime.evaluate',{expression:'s.showPicker()',userGesture:true});if(shown.exceptionDetails)throw new Error(shown.exceptionDetails.text);}
   await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');
   const expected=await browser.evaluate(`(()=>{const select=document.getElementById('s'),anchor=select.getBoundingClientRect(),p=getComputedStyle(select,'::picker(select)'),result={width:parseFloat(p.width),height:parseFloat(p.height),open:select.matches(':open'),boxes:{}};for(const id of ${JSON.stringify(c.targets)}){const n=document.getElementById(id),r=n.getBoundingClientRect();result.boxes[id]=n.getClientRects().length?[r.x-anchor.x,r.y-anchor.bottom,r.width,r.height]:{hidden:true}}return result})()`);if(!expected.open)throw new Error(c.name+': native picker did not open');c.expected.push(expected);
  }
 }}finally{await browser.close()}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/select-picker-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Select picker: '+cases.reduce((n,c)=>n+c.steps.length,0)+' native CSS geometry states captured.');
}
capture().catch(error=>{console.error(error);process.exitCode=1});
