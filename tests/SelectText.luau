--!strict
return function(Parser,Runtime,Events,fixture)
	for _,case in fixture.cases do
		local document=Parser.parseDocument(case.html);local actual,diagnostics={},{};local events=Events.new(error)
		local runtime=Runtime.new(document,{Events=events,ControlAdapter={Events=events},Console=function(_,value)table.insert(actual,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end})
		local ok,message=runtime:Run("function record(){const a=[];for(let i=0;i<arguments.length;i++)a.push(String(arguments[i]));console.log(a.join('|'));}"..case.code)
		assert(ok,case.name..': '..tostring(message));assert(#actual==#case.expected,case.name..': record count')
		for i,value in case.expected do assert(actual[i]==value,case.name..' record '..i..': '..actual[i]..' ~= '..value)end
		assert(#diagnostics==0,case.name..': unexpected diagnostics');runtime:Destroy();events:Destroy()
	end
	print('Select text: '..#fixture.cases..' native label/text/value/mutation sequences passed')
end
