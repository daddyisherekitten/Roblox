--!strict
-- Same-interface Web-IDL brands survive borrowed methods across live realms.
-- Wrapper-like author properties cannot authenticate a receiver.
return function(Parser: any,Runtime: any,Events: any)
 local eventsA,eventsB=Events.new(error),Events.new(error)
 local output,diagnostics={},{}
 local function options(events)
  return {Events=events,URL='https://example.test/selection-realms',
   Console=function(_,message)table.insert(output,message)end,
   Diagnostic=function(message)table.insert(diagnostics,message)end}
 end
 local first=Runtime.new(Parser.parseDocument('<!doctype html><html><body><p>local</p></body></html>'),options(eventsA))
 local second=Runtime.new(Parser.parseDocument('<!doctype html><html><body><p>abcdef</p></body></html>'),options(eventsB))
 second:Run([=[
var foreignText=document.querySelector('p').firstChild;
var foreignSelection=getSelection();
var host=document.createElement('div');document.body.appendChild(host);
var shadow=host.attachShadow({mode:'open'});shadow.innerHTML='<p>shadow text</p>';
var shadowText=shadow.querySelector('p').firstChild;
var shadowSelection=shadow.getSelection();
]=])
 first.VM:Install(function()
  for _,name in {'foreignText','foreignSelection','shadowText','shadowSelection'}do
   first.VM.GlobalEnvironment:Write(name,second.VM.GlobalEnvironment:Read(name),true)
  end
 end)
 first:Run([=[
const count=Object.getOwnPropertyDescriptor(Selection.prototype,'rangeCount').get;
const anchor=Object.getOwnPropertyDescriptor(Selection.prototype,'anchorOffset').get;
const collapse=Selection.prototype.collapse;
console.log(count.call(foreignSelection));
collapse.call(foreignSelection,foreignText,1);
Selection.prototype.extend.call(foreignSelection,foreignText,4);
console.log(count.call(foreignSelection),anchor.call(foreignSelection),Selection.prototype.toString.call(foreignSelection));
console.log(getSelection().rangeCount);
console.log(Object.getPrototypeOf(foreignSelection)===Selection.prototype);
// Changing the receiver's public method cannot replace a borrowed algorithm.
foreignSelection.collapse=()=>{throw Error('public override')};
collapse.call(foreignSelection,foreignText,2);console.log(anchor.call(foreignSelection));
collapse.call(shadowSelection,shadowText,1);
Selection.prototype.extend.call(shadowSelection,shadowText,6);
console.log(count.call(shadowSelection),Selection.prototype.toString.call(shadowSelection));
for(const fake of [{},{SelectionState:true},{SelectionOwner:foreignSelection.SelectionOwner}]){
 try{count.call(fake);console.log('accepted')}catch(error){console.log(error.name)}
}
]=])
 local expected={'0','1 1 bcd','0','false','2','1 hadow','TypeError','TypeError','TypeError'}
 assert(#diagnostics==0,table.concat(diagnostics,'\n'));assert(#output==#expected,'Cross-realm Selection record count')
 for i,value in expected do assert(output[i]==value,'Cross-realm Selection '..i..': '..tostring(output[i])..' ~= '..value)end
 local target=second.Selection.Value
 local collapse=first.VM.ObjectModel.Own(first.VM.Prototypes.Selection or first.VM.ObjectModel.GetPrototype(first.Selection.Value),'collapse').Value
 second:Destroy();eventsB:Destroy()
 assert(not pcall(function()first.VM:Call(collapse,{target},target)end),'Disposed foreign selections lose their authenticated live brand')
 first:Destroy();eventsA:Destroy()
 print('Selection realms: borrowed methods/getters, original implementation, ShadowRoot views, forgery rejection and disposal passed')
end
