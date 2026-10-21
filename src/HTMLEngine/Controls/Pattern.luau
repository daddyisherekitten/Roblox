--!strict
-- Intrinsic HTML UnicodeSets patterns also work with page scripts disabled.
local Strings=require(script.Parent.Parent.JavaScript.Strings)
local Syntax=require(script.Parent.Parent.JavaScript.RegExpSyntax)
local Matcher=require(script.Parent.Parent.JavaScript.RegExpMatcher)
local Work=require(script.Parent.Parent.WorkContext)
local Pattern={}
function Pattern.new(step:any?,fail:any?):any
	step=step or Work.checkpoint
	fail=fail or function(message)error('RangeError: '..message,0)end
	local patterns,order={},{}
	local api={Alive=true}
	function api:Mismatch(source:string,input:string,multiple:boolean?):boolean
		assert(self.Alive,'HTML pattern adapter disposed')
		if Strings.length(source)>8192 then fail('HTML pattern length budget exceeded')end
		local compiled=patterns[source]
		if compiled==nil then
			local invalid={}
			local function syntaxError(message)
				if string.find(message,'budget',1,true)then fail(message)end
				error(invalid,0)
			end
			local ok,result=pcall(function()
				Syntax.compile(source,'v',step,syntaxError)
				return Syntax.compile('^(?:'..source..')$','v',step,syntaxError)
			end)
			if not ok and result~=invalid then error(result,0)end
			compiled=if ok then result else false
			if #order==64 then patterns[table.remove(order,1)]=nil end
			patterns[source]=compiled;table.insert(order,source)
		end
		if not compiled then return false end
		local function mismatch(value)
			local units=Strings.units(value);if #units>65536 then fail('HTML pattern input length budget exceeded')end
			return Matcher.match(compiled,units,0,step,fail)==nil
		end
		if multiple then for _,value in string.split(input,',')do if mismatch(value)then return true end end;return false end
		return mismatch(input)
	end
	function api:Destroy()self.Alive=false;table.clear(patterns);table.clear(order)end
	return api
end
local native=Pattern.new()
function Pattern.mismatch(node:any,value:string):boolean
	return native:Mismatch(node.Attributes.pattern,value,(node.Attributes.type or ''):lower()=='email'and node.Attributes.multiple~=nil)
end
return Pattern
