const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const folder=path.resolve(__dirname,'../build/select-state-reference');fs.mkdirSync(folder,{recursive:true});
const cases=[{
 name:'Base list option UA interaction and author cascade',
 html:'<!doctype html><style>body{color:blue}select{appearance:base-select;width:240px;height:100px;font:16px/24px Arial}</style><select id=stateSelect size=3><optgroup id=stateGroup label=Group><option id=stateA><b id=stateBold>Alpha</b></option><option id=stateB>Beta</option></optgroup></select>',
 targets:['stateSelect','stateGroup','stateA','stateBold','stateB'],steps:[{}, {hover:'stateBold'},{hover:'stateBold',active:'stateBold'},{hover:'stateB',active:null},{hover:null},{hover:'stateA',styles:{stateA:'color:red'}},{styles:{stateA:'color:red;background:green'}},{styles:{stateA:'color:red;background:revert'}},{styles:{stateA:'color:red;background:initial'}},{styles:{stateA:''},attributes:{stateA:{disabled:''}}},{attributes:{stateA:{disabled:null}},hover:null},{attributes:{stateGroup:{disabled:''}}},{attributes:{stateA:{disabled:''}}},{styles:{stateGroup:'color:red'}},{attributes:{stateGroup:{disabled:null}},styles:{stateGroup:''}},{attributes:{stateA:{disabled:null},stateSelect:{disabled:''}}},{attributes:{stateSelect:{disabled:null}}}],
},{
 name:'Base dropdown font-relative UA geometry and pointer states',
 html:'<!doctype html><style>body{color:blue}select{appearance:base-select;font:16px/24px Arial}select::picker(select){appearance:base-select}</style><select id=stateDrop><option>Dropdown</option></select>',
 targets:['stateDrop'],metrics:['stateDrop'],steps:[{}, {hover:'stateDrop'}, {active:'stateDrop'}, {styles:{stateDrop:'font-size:32px;line-height:40px'}}, {styles:{stateDrop:'font-size:32px;line-height:40px;padding-left:3px;border-radius:2px'}},{styles:{stateDrop:'font-size:32px;line-height:40px;padding-left:revert;border-radius:revert'}},{attributes:{stateDrop:{disabled:''}}}, {styles:{stateDrop:'color:red'}},{attributes:{stateDrop:{disabled:null}},styles:{stateDrop:''},hover:null,active:null}],
},{
 name:'Disabled fieldset excludes its first legend and reaches rich group options',
 html:'<!doctype html><style>body{color:blue}select{appearance:base-select;font:16px/24px Arial}</style><fieldset id=stateField disabled><legend><select id=stateLegend size=3><option id=stateLegendOption>Legend</option></select></legend><select id=stateBlocked size=3><optgroup id=stateBlockedGroup label=Group><option id=stateBlockedOption>Blocked</option></optgroup></select></fieldset>',
 targets:['stateLegend','stateLegendOption','stateBlocked','stateBlockedGroup','stateBlockedOption'],steps:[{}, {attributes:{stateField:{disabled:null}}},{attributes:{stateBlocked:{disabled:''}}}, {attributes:{stateBlocked:{disabled:null},stateBlockedGroup:{disabled:''}}},{attributes:{stateBlockedGroup:{disabled:null},stateLegendOption:{disabled:''}}}],
}];
async function capture(){
 const browser=await openBrowser(folder);const fixture={captured:'2026-10-09',standard:'https://html.spec.whatwg.org/multipage/rendering.html#the-select-element-2',cases};
 try{await browser.load('<!doctype html>');fixture.browser=await browser.evaluate('navigator.userAgent');await browser.send('DOM.enable');await browser.send('CSS.enable');
  for(const c of cases){await browser.load(c.html);c.expected=[];let state={};
   for(const step of c.steps){
    await browser.evaluate(`(()=>{const step=${JSON.stringify(step)};for(const [id,style]of Object.entries(step.styles||{}))document.getElementById(id).style.cssText=style;for(const [id,attrs]of Object.entries(step.attributes||{}))for(const [name,value]of Object.entries(attrs))if(value===null)document.getElementById(id).removeAttribute(name);else document.getElementById(id).setAttribute(name,value)})()`);
    for(const name of ['hover','active'])if(Object.hasOwn(step,name))state[name]=step[name];
    const doc=await browser.send('DOM.getDocument');const ids=await browser.evaluate(`(()=>{const map={};for(const [name,id]of Object.entries(${JSON.stringify(state)})){if(!id)continue;let n=document.getElementById(id);while(n){if(n.id)(map[n.id]||=[]).push(name);n=n.parentElement}}return map})()`);
    // Native pointer input exercises hover and its ancestor propagation. CDP's
    // forced hover can leave stale option paint after it has been cleared.
    // Active is forced to avoid selecting an option/opening a native picker.
    for(const id of c.targets){const q=await browser.send('DOM.querySelector',{nodeId:doc.root.nodeId,selector:'#'+id});await browser.send('CSS.forcePseudoState',{nodeId:q.nodeId,forcedPseudoClasses:(ids[id]||[]).filter(name=>name==='active')});}
    const point=state.hover?await browser.evaluate(`(()=>{const r=document.getElementById(${JSON.stringify(state.hover)}).getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}})()`):{x:799,y:599};
    await browser.send('Input.dispatchMouseEvent',{type:'mouseMoved',...point});
    // Read paint after the browser's normal rendering lifecycle.
    await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');
    c.expected.push(await browser.evaluate(`(()=>{const result={},canvas=document.createElement('canvas');canvas.width=canvas.height=1;const ctx=canvas.getContext('2d',{colorType:'float16'});const rgba=raw=>{ctx.clearRect(0,0,1,1);ctx.fillStyle=raw;ctx.fillRect(0,0,1,1);return Array.from(ctx.getImageData(0,0,1,1,{pixelFormat:'rgba-float16'}).data,value=>value*255)};for(const id of ${JSON.stringify(c.targets)}){const n=document.getElementById(id),s=getComputedStyle(n);result[id]={color:rgba(s.color),background:rgba(s.backgroundColor),rawColor:s.color,rawBackground:s.backgroundColor,disabled:n.matches(':disabled'),enabled:n.matches(':enabled')};if(${JSON.stringify(c.metrics||[])}.includes(id))result[id].metrics=[parseFloat(s.borderRadius),parseFloat(s.paddingTop),parseFloat(s.paddingLeft),parseFloat(s.gap),s.boxSizing]}return result})()`));
   }
  }
 }finally{await browser.close()}
 // Keep explicit removals representable in Luau tables, where nil deletes a
 // key. False is the recorded remove sentinel, never a boolean HTML value.
 for(const c of cases)for(const step of c.steps){for(const name of ['hover','active'])if(step[name]===null)step[name]=false;for(const attrs of Object.values(step.attributes||{}))for(const name of Object.keys(attrs))if(attrs[name]===null)attrs[name]=false;}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/select-states-browser.json'),JSON.stringify(fixture,null,2)+'\n');
 console.log('Select UA states: '+cases.reduce((n,c)=>n+c.steps.length,0)+' native states captured with raw CSS colors and normalized paint.');
}
capture().catch(error=>{console.error(error);process.exitCode=1});
