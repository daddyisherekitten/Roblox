const svgFixture=require('./svg-fixtures.cjs');
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
for(const page of ['s43','s44','s43-s44']){
 const html=svgFixture('examples/svg-tests/'+page+'.html');const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
 const frame={style:{},contentWindow:{},src:page+'-content.html'},status={},handlers={};let tick;
 const context=vm.createContext({document:{querySelector:id=>id==='#page'?frame:status},innerHeight:800,performance:{now:()=>0},requestAnimationFrame:fn=>tick=fn,addEventListener:(key,fn)=>handlers[key]=fn});
 vm.runInContext(script,context);assert.equal(frame.style.width,'490px');assert.equal(frame.style.height,'650px');
 handlers.keydown({key:'1'});assert.equal(frame.style.width,'250px');handlers.keydown({key:'3'});assert.equal(frame.style.width,'970px');
 handlers.message({source:{},data:{channel:'svg-integration-key',key:'1'}});assert.equal(frame.style.width,'970px');
 handlers.message({source:frame.contentWindow,data:{channel:'svg-integration-key',key:'c'}});tick(100);assert.notEqual(frame.style.width,'970px');
 handlers.keydown({key:'c'});const width=frame.style.width;tick(200);assert.equal(frame.style.width,width);handlers.keydown({key:'r'});assert.equal(frame.src,page+'-content.html');
 const content=svgFixture('examples/svg-tests/'+page+'-content.html');assert(content.includes('::-webkit-scrollbar{width:10px'));
 const bridge=content.match(/<script>([\s\S]*?)<\/script>/)[1];let keyHandler,messages=0;
 vm.runInNewContext(bridge,{addEventListener:(_,fn)=>keyHandler=fn,parent:{postMessage:data=>{messages++;handlers.message({source:frame.contentWindow,data})}}});
 keyHandler({key:'1',target:{matches:()=>true}});assert.equal(messages,0,'Form entry does not trigger lab shortcuts');keyHandler({key:'1',target:{matches:()=>false}});assert.equal(frame.style.width,'250px');
 console.log(page+': wrapper viewport, continuous resize, reset, message provenance and form-key isolation passed (DOM mocks).');
}
