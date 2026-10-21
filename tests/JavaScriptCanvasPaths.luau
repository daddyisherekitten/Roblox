--!strict
return function(Parser,Runtime,fixtures)
	for _,fixture in fixtures do
		local output={};local realm=Runtime.new(Parser.parseDocument('<!doctype html><canvas id="canvas" width="64" height="64"></canvas>'),{Schedule=function()end,Console=function(_,text)table.insert(output,text)end})
		local ok,message=realm:Run("const c=document.getElementById('canvas'),ctx=c.getContext('2d');"..fixture.source)
		assert(ok,fixture.name..": "..tostring(message));assert(table.concat(output,"|")==fixture.expected,fixture.name..": "..table.concat(output,"|"))
		realm:Destroy()
	end
	print("Canvas Path2D: "..#fixtures.." browser reference traces passed")
end
