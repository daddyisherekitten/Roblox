--!strict
return function(Parser,Runtime,VM,Events,source,expected)
 local document=Parser.parseDocument('<html><head></head><body></body></html>');local diagnostics={}
 local runtime=Runtime.new(document,{Events=Events.new(error),Diagnostic=function(message)table.insert(diagnostics,message)end})
 runtime:Run(source)
 assert(#diagnostics==0,table.concat(diagnostics,' | '))
 local log=runtime.VM.Global.Bindings.log.Value
 for i,item in expected do assert(runtime.VM.Get(log,tostring(i-1))==item,'CSSOM rules native reference ['..i..']: '..VM.string(runtime.VM.Get(log,tostring(i-1)))..' ~= '..item)end
 assert(runtime.VM.Get(log,'length')==#expected,'CSSOM rules result count differs')
 runtime:Destroy();print('CSSOM rules: '..#expected..' browser reference assertions passed')
end
