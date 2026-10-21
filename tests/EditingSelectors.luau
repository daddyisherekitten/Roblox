--!strict
return function(Parser,Runtime,Events,fixture)
	local events=Events.new(error)
	local realm=Runtime.new(Parser.parseDocument('<!doctype html><title>Editing selectors</title><body></body>'),
		{Events=events,ControlAdapter={Events=events},Schedule=function()end,MaxSteps=500000})
	assert(realm:Run(fixture.source..'\nconst editingResults=editingSelectorChecks();'),table.concat(realm.Diagnostics,'\n'))
	for index,expected in fixture.records do
		assert(realm:Run('window.editingResult=JSON.stringify(editingResults['..tostring(index-1)..'].value);'),table.concat(realm.Diagnostics,'\n'))
		local normative=fixture.normative[expected.name]
		local target=if normative then normative.json else expected.json
		assert(realm.Window.Get('editingResult')==target,expected.name..'\nexpected '..target..'\nactual '..tostring(realm.Window.Get('editingResult')))
	end
	assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,'\n'))
	realm:Destroy();events:Destroy()
	local deltas=0;for _ in fixture.normative do deltas+=1 end
	print('Editing selectors: '..tostring(#fixture.records-deltas)..' exact native inherited/plaintext/input/namespace/shadow/designMode/reparent records + '..tostring(deltas)..' explicit normative state deltas passed')
end
