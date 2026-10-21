return function(Parser,Runtime,VM,Events,source,expected)
	local doc=Parser.parseDocument('<html><head></head><body></body></html>');local diagnostics={}
	local runtime=Runtime.new(doc,{Events=Events.new(error),Diagnostic=function(message)table.insert(diagnostics,message)end})
	runtime:Run(source);assert(#diagnostics==0,table.concat(diagnostics,' | '))
	local log=runtime.VM.Global.Bindings.log.Value
	for index,item in expected do assert(runtime.VM.Get(log,tostring(index-1))==item,'Anchor CSSOM reference '..index..': '..VM.string(runtime.VM.Get(log,tostring(index-1)))..' != '..item)end
	assert(runtime.VM.Get(log,'length')==#expected)
	runtime:Destroy();print('Anchor CSSOM: '..#expected..' native rule, descriptor, mutation and serialization results passed')
end
