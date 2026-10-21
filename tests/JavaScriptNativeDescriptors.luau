--!strict
-- Internal native property descriptors must not consult Object.prototype.
-- Public ToPropertyDescriptor and FromPropertyDescriptor stay observable.
return function(Parser,Node,Runtime,VM,Events,HostEvents,Geometry)
 local body=[=[
let hits=0;
const poison=Object.create(null);
poison.configurable=true;
poison.get=function(){hits++;throw new Error('private descriptor inherited lookup')};
Object.defineProperty(Object.prototype,'get',poison);
Object.defineProperty(Object.prototype,'set',poison);
const f=function sample(a,b){return a+b};
const bound=f.bind(null,2);
if(bound(3)!==5)throw new Error('bind');
class Box { value=8; get number(){return this.value} set number(v){this.value=v} }
const box=new Box();box.number=9;if(box.number!==9)throw new Error('class');
const abort=new AbortController();abort.signal.onabort=()=>{};abort.abort();
const channel=new MessageChannel();channel.port1.onmessage=()=>{};channel.port1.close();channel.port2.close();
const stream=new ReadableStream({start(c){c.enqueue('ok');c.close()}});
const iterator=stream.values();iterator.next().then(r=>{if(r.value!=='ok')throw new Error('stream')});
const payload=structuredClone({item:12});if(payload.item!==12)throw new Error('clone');
const matrix=new DOMMatrix([1,0,0,1,4,5]);if(matrix.toFloat64Array()[12]!==4)throw new Error('matrix');
const target=document.getElementById('target');
target.getClientRects();
target.onclick=()=>{};
const walker=document.createTreeWalker(document);if(walker.root!==document)throw new Error('traversal');
const observer=new MutationObserver(()=>{});observer.observe(target,{attributes:true});target.setAttribute('data-test','yes');observer.takeRecords();observer.disconnect();
if(hits!==0)throw new Error('private descriptors used inherited hooks');
let rejected=false;try{Object.defineProperty({},'x',{value:1})}catch(e){rejected=true}
if(!rejected||hits!==1)throw new Error('public descriptor stopped observing prototype');
delete Object.prototype.get;delete Object.prototype.set;
const inherited=Object.create({get:function(){return 17},enumerable:true});
const holder={};Object.defineProperty(holder,'answer',inherited);
if(holder.answer!==17)throw new Error('public inherited getter');
const visible=Object.getOwnPropertyDescriptor(holder,'answer');
if(Object.getPrototypeOf(visible)!==Object.prototype)throw new Error('public descriptor prototype changed');
console.log('native-descriptors-pass');
]=]
 local document=Parser.parseDocument('<html><body><div id="target"></div></body></html>')
 local output,diagnostics={},{};local bus=Events.new(error)
 local runtime=Runtime.new(document,{Events=bus,URL='https://example.test/descriptors',ApplyChanges=function()return false end,
  Console=function(_,text)table.insert(output,text)end,Diagnostic=function(text)table.insert(diagnostics,text)end})
 runtime:Run(body)
 runtime:PumpTasks()
 assert(#diagnostics==0,table.concat(diagnostics,'\n'))
 assert(output[1]=='native-descriptors-pass','Native descriptor integration did not complete')
 runtime:Destroy();bus:Destroy()

 -- Installation can also happen after author code has changed its prototypes.
 local globals={};local vm=VM.new(globals,{MaxSteps=100000})
 vm:Run("Object.prototype.get=function(){return 99};Object.prototype.set=function(){};")
 local events=vm:Install(function()return HostEvents.install(vm,globals,{})end)
 local geometry=vm:Install(function()return Geometry.install(vm,globals,{Events=events})end)
 vm:Run("const p=new DOMPoint(3,4);if(p.x!==3||new DOMMatrix().a!==1)throw new Error('late host installation');delete Object.prototype.get;delete Object.prototype.set;")
 geometry:Destroy();events:Destroy();vm:Destroy()
 print('Native descriptors: runtime pollution, late host installation and public descriptor semantics pass')
end
