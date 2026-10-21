--!strict
local VM=require(script.Parent.VM)
local T=require(script.Parent.Parent.Controls.TemporalValue)
local NumberValue=require(script.Parent.Parent.Controls.NumberValue)
local RangeValue=require(script.Parent.Parent.Controls.RangeValue)
local Input={}
local function fail(host,name,message)VM.throw(if host.DOMException and name=="InvalidStateError" then host.DOMException(message,name) else VM.error(name,message))end
local function numeric(c)return T.applies(c.Type) or c.Type=="number" or c.Type=="range" end
function Input.get(c: any,key: string,host: any): (boolean,any)
	if key=="valueAsNumber" then return true,if T.applies(c.Type) then T.number(c.Type,c.Value) or 0/0 elseif c.Type=="number" or c.Type=="range" then tonumber(c.Value) or 0/0 else 0/0 end
	if key=="valueAsDate" then
		if not T.applies(c.Type) or c.Type=="datetime-local" then return true,VM.Null end
		local n=T.number(c.Type,c.Value);if not n then return true,VM.Null end
		if c.Type=="month" then n=T.dayNumber(1970+math.floor(n/12),n%12+1,1)*T.Day end
		local vm=host.GetVM and host.GetVM();if not vm then fail(host,"NotSupportedError","Date values require the JavaScript realm") end
		local object=vm.Object({},vm.Prototypes.Date);object.Kind="date";object.TimeValue=n;return true,object
	end
	if key=="files" then
		if c.Type~="file" then return true,VM.Null end
		if not c.FileList then c.FileList={Get=function(property)
			if property=="length" then return #(c.Files or {}) end
			if property=="item" then return function(args)return (c.Files or {})[(math.floor(VM.number(args[1])) or 0)+1] or VM.Null end end
			local index=tonumber(property);return if index then (c.Files or {})[index+1] or VM.Undefined else VM.Undefined
		end} end
		return true,c.FileList
	end
	return false,nil
end
function Input.set(c: any,key: string,newValue: any,host: any,assign: any): boolean
	if key=="valueAsNumber" then
		local n=VM.number(newValue);if math.abs(n)==math.huge then fail(host,"TypeError","valueAsNumber must be finite or NaN") end
		if not numeric(c) then fail(host,"InvalidStateError","This input type has no numeric value") end
		assign(if n~=n then "" elseif T.applies(c.Type) then T.format(c.Type,n) else tostring(n));return true
	elseif key=="valueAsDate" then
		if not T.applies(c.Type) or c.Type=="datetime-local" then fail(host,"InvalidStateError","This input type has no Date value") end
		if newValue~=VM.Null and (type(newValue)~="table" or newValue.Kind~="date") then fail(host,"TypeError","valueAsDate requires a Date or null") end
		local n=if newValue==VM.Null then 0/0 else newValue.TimeValue
		if c.Type=="month" and n==n then local y,m=T.civil(math.floor(n/T.Day));n=(y-1970)*12+m-1 end
		if c.Type=="time" and n==n then n=n%T.Day end
		assign(if n~=n then "" else T.format(c.Type,n));return true
	end
	return false
end
function Input.step(c: any,args: any,direction: number,host: any,assign: any)
	local r=if T.applies(c.Type) then c.Temporal elseif c.Type=="number" then c.Number elseif c.Type=="range" then c.Range else nil
	if not r or not r.Step then fail(host,"InvalidStateError","This input has no allowed value step") end
	local raw=if args[1]==nil then 1 else VM.number(args[1]);local count=if raw~=raw or math.abs(raw)==math.huge then 0 else (if raw<0 then math.ceil(raw) else math.floor(raw))
	count=count%4294967296;if count>=2147483648 then count-=4294967296 end;count*=direction
	local nextValue
	if T.applies(c.Type) then nextValue=T.step(c,count)
	elseif c.Type=="range" then nextValue=RangeValue.normalize(r,(tonumber(c.Value) or 0)+count*r.Step)
	else nextValue=NumberValue.step(c,count) end
	if nextValue then assign(nextValue) end
end
return Input
