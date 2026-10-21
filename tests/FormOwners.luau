--!strict
return function(Parser,Runtime,Events,Node,State,Model,fixture)
	for _,case in fixture.cases do
		local document=Parser.parseDocument(case.html);local events=Events.new(error)
		local runtime=Runtime.new(document,{Events=events,ControlAdapter={},Schedule=function()end})
		local ok,message=runtime:Run('globalThis.formOwnerResult='..case.action)
		assert(ok,case.name..': '..tostring(message))
		local actual=runtime.Window.Get('formOwnerResult')
		assert(actual==(case.specExpected or case.expected),case.name..'\nexpected '..(case.specExpected or case.expected)..'\nactual '..tostring(actual))
		assert(#runtime.Diagnostics==0,case.name..': '..table.concat(runtime.Diagnostics,' | '))
		runtime:Destroy();events:Destroy()
	end
	local doc=Parser.parseDocument('<!doctype html><table><form id=f><input id=e name=value value=first></table>')
	local input=Node.findById(doc,'e');local form=Node.findById(doc,'f');local control=State.create(input)
	assert(control.Form==form and input.Parent~=form,'Native controls share nonancestor parser form ownership')
	local events=Events.new(error);local model=Model.new(doc,{control},events,function()end)
	assert(model:Data(form)[1].Value=='first','Parsed nonancestor form owner controls participate in submission')
	model:SetValue(control,'changed');model:Reset(form)
	assert(control.Value=='first','Parsed nonancestor form owner controls participate in reset')
	model:Destroy();events:Destroy()
	print('Form owners: '..#fixture.cases..' native parser/mutation cases and shared control-model reset/submission passed')
end
