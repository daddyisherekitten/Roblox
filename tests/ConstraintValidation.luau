--!strict
return function(Parser,Runtime,Events,fixture)
	for _,case in fixture.cases do
		local document=Parser.parseDocument(case.html);local actual,diagnostics={},{};local events=Events.new(error)
		local runtime=Runtime.new(document,{Events=events,ControlAdapter={Events=events},Console=function(_,value)table.insert(actual,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end})
		local ok,message=runtime:Run("function record(...values){console.log(values.map(String).join('|'));}"..case.code)
		assert(ok,case.name..': '..tostring(message));local expected=case.standardExpected or case.expected
		assert(#actual==#expected,case.name..': record count')
		for i,value in expected do assert(actual[i]==value,case.name..' record '..i..': '..actual[i]..' ~= '..value)end
		assert(#diagnostics==0,case.name..': unexpected diagnostics');runtime:Destroy();events:Destroy()
	end
	local document=Parser.parseDocument('<form id="native"><input id="pattern" required pattern="[A-Z]{2}" value="ab"></form>')
	local events=Events.new(error);local diagnostics={}
	local runtime=Runtime.new(document,{Events=events,ControlAdapter={Events=events},MaxSteps=1000,Diagnostic=function(value)table.insert(diagnostics,value)end})
	local form=document.Children[1].Children[2].Children[1];local input=form.Children[1]
	-- A completed author task may have used the entire instruction allowance.
	-- Every independent native read/submission must open its own serialized entry.
	for _=1,3 do
		runtime.VM.Steps=1000
		local flags,message=runtime.DOM.Controls:Validity(input)
		assert(flags.patternMismatch and not flags.valid and message~='', 'Native validity preserves flags and message with a fresh budget')
		runtime.VM.Steps=1000;assert(runtime:ReportFormValidity(form)==false,'Native form validation starts a fresh budget')
	end
	local ok,message=pcall(function()runtime.VM:ExecuteHost(function()
		runtime.VM.Steps=1000;runtime.DOM.Controls:Validity(input)
	end)end)
	assert(not ok and tostring(message):find('instruction budget exceeded',1,true),'Nested validity must share the author instruction budget')
	assert(#diagnostics==0,'Native validation must not consume a previous task budget')
	runtime:Destroy();events:Destroy()
	print('Constraint validation: '..#fixture.cases..' native eligibility/flags/CSS/custom/attribute sequences passed')
end
