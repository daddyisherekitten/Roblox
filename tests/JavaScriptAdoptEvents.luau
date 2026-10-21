--!strict
return function(Parser,Runtime,Events)
 local output,diagnostics={},{}
 local function create(url)
  return Runtime.new(Parser.parseDocument('<!doctype html><html><body></body></html>'),{Events=Events.new(error),URL=url,
   Console=function(_,s)table.insert(output,s)end,Diagnostic=function(s)table.insert(diagnostics,s)end})
 end
 local source,destination=create('https://example.test/a'),create('https://example.test/b')
 source:Run([=[
globalThis.moved=document.createElement('button');document.body.appendChild(moved);
moved.textContent='Move';globalThis.oldEvent=new Event('action',{bubbles:true});
moved.addEventListener('action',function(e){console.log('own:'+ (this===moved)+':' +(e.target===moved));});
document.body.addEventListener('action',()=>console.log('old parent'));
]=])
 destination.VM.Global.Bindings.foreign={Value=source.VM.Global.Bindings.moved.Value}
 destination.VM.Global.Bindings.oldEvent={Value=source.VM.Global.Bindings.oldEvent.Value}
 destination:Run([=[
document.body.addEventListener('action',e=>console.log('new parent:'+(e.target===foreign)));
document.body.appendChild(foreign);foreign.dispatchEvent(new Event('action',{bubbles:true}));
foreign.dispatchEvent(oldEvent);
]=])
 assert(#diagnostics==0,table.concat(diagnostics,'\n'))
 assert(table.concat(output,'|')=='own:true:true|new parent:true|own:true:true|new parent:true',table.concat(output,'|'))
 source:Destroy();destination:Destroy()
 print('Live document adoption: original callbacks, original wrapper identity, new event ancestry and cross-realm Event brands passed')
end
