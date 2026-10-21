const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const modes=['horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'];
const cases=[];
for(const mode of modes)for(const dir of ['ltr','rtl'])for(const [name,left,top,picker]of [
 ['center',300,230,'width:260px;height:70px'],
 ['bottom',600,530,'width:260px;height:70px'],
 ['top-left',5,5,'width:260px;height:70px'],
 ['small',300,230,'width:20px;height:10px'],
 ['physical-bounds-reset',600,530,'width:260px;height:70px;min-width:0;min-height:0;max-width:none;max-height:none;position-try-order:normal;position-try-fallbacks:none'],
]){
 const html='<!doctype html><style>html,body{margin:0;padding:0}select{appearance:base-select;position:fixed;left:'+left+'px;top:'+top+'px;width:120px;height:40px;writing-mode:'+mode+';direction:'+dir+'}select::picker(select){appearance:base-select;scrollbar-width:none;'+picker+'}option{font-size:0;display:block;min-width:0;min-height:0;padding:0;width:20px;height:20px}option::checkmark{content:none}</style><select id=s><option id=a></option><option id=b></option></select>';
 cases.push({name:mode+'/'+dir+'/'+name,html,steps:[{}, {left:80,top:60},{viewport:{width:620,height:450}}]});
}
const groupHTML='<!doctype html><style>html,body{margin:0;padding:0}select{appearance:base-select;position:fixed;left:10px;top:420px;width:220px;height:30px}select::picker(select){appearance:base-select}optgroup{color:green;font-size:20px}legend b{color:purple}</style><select id=s><button><selectedcontent></selectedcontent></button><optgroup label=Ignored><legend><b>Places</b><img id=icon width=18 height=28></legend><option>Alpha</option><option>Beta</option></optgroup></select>';
function findPicker(node){
 const attrs=node.attributes||[];
 for(let i=0;i<attrs.length;i+=2)if(attrs[i]==='pseudo'&&attrs[i+1]==='picker(select)')return node.nodeId;
 for(const key of ['children','shadowRoots','pseudoElements'])for(const child of node[key]||[]){const found=findPicker(child);if(found)return found;}
 return null;
}
async function snapshot(browser){
 const root=await browser.send('DOM.getDocument',{depth:-1,pierce:true});
 const nodeId=findPicker(root.root);if(!nodeId)throw new Error('Native UA picker node missing');
 const {model}=await browser.send('DOM.getBoxModel',{nodeId});
 const q=model.border;
 const style=await browser.evaluate("(()=>{const p=getComputedStyle(s,'::picker(select)'),r=s.getBoundingClientRect();return {select:[r.x,r.y,r.width,r.height],area:p.positionArea,tries:p.positionTryFallbacks,order:p.positionTryOrder,minWidth:p.minWidth,minHeight:p.minHeight,maxWidth:p.maxWidth,maxHeight:p.maxHeight,width:p.width,height:p.height,open:s.matches(':open')}})()");
 return {...style,rect:[q[0],q[1],q[2]-q[0],q[7]-q[1]]};
}
async function main(){
 const folder=path.resolve(__dirname,'../build/select-ua-reference');fs.mkdirSync(folder,{recursive:true});
 const browser=await openBrowser(folder);let active='start';const fixture={captured:'2026-10-10',standard:'https://html.spec.whatwg.org/multipage/rendering.html#the-select-element',cases,group:{html:groupHTML,steps:[{}, {imageHeight:80},{imageHeight:12}],expected:[]}};
 try{
  await browser.send('DOM.enable');fixture.browser=await browser.evaluate('navigator.userAgent');
  for(const c of cases){
   c.expected=[];
   // Chromium adds min-block-size:1lh to its picker UA. The HTML Standard
   // does not. Preserve its raw result and a separate real native sequence
   // with exactly this extra minimum disabled, including fallback retention.
   for(const normative of [false,true]){
    await browser.send('Emulation.setDeviceMetricsOverride',{width:800,height:600,deviceScaleFactor:1,mobile:false});
    await browser.load(normative?c.html.replace('</style>','select::picker(select){min-block-size:0}</style>'):c.html);
    for(let i=0;i<c.steps.length;i++){
     active=c.name+'/'+i+(normative?'/normative-minimum':'');const step=c.steps[i];
     if(step.left!==undefined)await browser.evaluate('s.style.left='+JSON.stringify(step.left+'px')+';s.style.top='+JSON.stringify(step.top+'px'));
     if(step.viewport)await browser.send('Emulation.setDeviceMetricsOverride',{...step.viewport,deviceScaleFactor:1,mobile:false});
     if(i===0)await browser.send('Runtime.evaluate',{expression:'s.showPicker()',userGesture:true});
     await browser.evaluate('new Promise(r=>setTimeout(r,35))');const expected=await snapshot(browser);
     if(normative)c.expected[i].normativeControl=expected;else c.expected.push(expected);
    }
   }
  }
  await browser.send('Emulation.setDeviceMetricsOverride',{width:600,height:480,deviceScaleFactor:1,mobile:false});await browser.load(groupHTML);
  await browser.send('Runtime.evaluate',{expression:'s.showPicker()',userGesture:true});
  for(const step of fixture.group.steps){active='group/'+JSON.stringify(step);if(step.imageHeight)await browser.evaluate('icon.height='+step.imageHeight);await browser.evaluate('new Promise(r=>setTimeout(r,35))');fixture.group.expected.push(await snapshot(browser));}
 }catch(error){throw new Error(active+': '+error.message)}finally{await browser.close()}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/select-ua-browser.json'),JSON.stringify(fixture,null,2)+'\n');
 console.log('UA picker: '+cases.reduce((n,c)=>n+c.steps.length,0)+' native pseudo-box states and '+fixture.group.expected.length+' actual legend growth/shrink positions captured.');
}
main().catch(error=>{console.error(error);process.exitCode=1});
