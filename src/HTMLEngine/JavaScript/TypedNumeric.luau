--!strict
-- Numeric Typed OM expressions keep their units and mutable child values.
-- Conversion is algebraic; it never invents a font/viewport/percentage basis.
local API={}
local Indexed=require(script.Parent.TypedIndexed)
local Parser=require(script.Parent.TypedNumericParser)
function API.install(ctx: any): any
	local vm,VM=ctx.VM,ctx.VM.Model
	local U,N=VM.Undefined,VM.Null
	local values,types=ctx.Values,ctx.UnitTypes
	local mathProto=vm.Object({},ctx.NumericPrototype)
	local arrayProto=vm.Object({});local arrays=setmetatable({},{__mode="kv"})
	local prototypes={};local api={}
	local canonical={length="px",angle="deg",time="s",frequency="hz",resolution="dppx",flex="fr",percent="percent",number="number"}
	local function state(value)
		if type(value)=="number"then return {Kind="unit",Value=ctx.Finite(value),Unit="number"}end
		local s=values[value]
		if not s or (s.Kind~="unit"and s.Kind~="math")then ctx.Fail("Expected a CSSNumericValue or number")end
		return s
	end
	local function numeric(value)return if type(value)=="number"then ctx.Scalar(ctx.Finite(value),"number")else value end
	local function category(unit)
		local kind=types[unit][1]
		return if canonical[kind]then kind else "length"
	end
	local baseTypes={"length","angle","time","frequency","resolution","flex","percent"}
	local function equalTypes(a,b)
		for _,key in baseTypes do if (a[key]or 0)~=(b[key]or 0)then return false end end;return true
	end
	local function applyHint(value,hint)
		local result=table.clone(value)
		if not result.percentHint then result[hint]=(result[hint]or 0)+(result.percent or 0);result.percent=nil;result.percentHint=hint end
		return result
	end
	local function dimensions(s,depth)
		assert(depth<64,"CSS numeric expression depth exceeded")
		if s.Kind=="unit"then local kind=category(s.Unit);return if kind=="number"then {}else {[kind]=1}end
		local result={}
		for index,value in s.Members do
			vm.Step();local current=dimensions(state(value),depth+1)
			if result.percentHint and current.percentHint and result.percentHint~=current.percentHint then ctx.Fail("Incompatible CSS percent hints")end
			local chosen=result.percentHint or current.percentHint
			if chosen then result=applyHint(result,chosen);current=applyHint(current,chosen)end
			if s.Operator=="product"then
				for key,power in current do if key~="percentHint"then result[key]=(result[key]or 0)+power else result.percentHint=power end end
			elseif s.Operator=="invert"then for key,power in current do result[key]=if key=="percentHint"then power else -power end
			elseif index==1 then result=current
			else
				if not equalTypes(result,current)then
					local merged
					if not chosen then for _,kind in baseTypes do
						if kind=="percent"then continue end
						local left,right=applyHint(result,kind),applyHint(current,kind)
						if equalTypes(left,right)then merged=left;break end
					end end
					if not merged then ctx.Fail("Incompatible CSS numeric types")end
					result=merged
				end
			end
		end
		for key,power in result do if power==0 then result[key]=nil end end
		return result
	end
	local function unitTerm(s)
		local info=types[s.Unit];local unit=canonical[info[1]]or s.Unit
		return {Value=s.Value*info[2],Units=if unit=="number"then {}else {[unit]=1}}
	end
	local function unitKey(units)
		local keys={};for unit,power in units do if power~=0 then table.insert(keys,unit..":"..power)end end;table.sort(keys);return table.concat(keys,";")
	end
	local function terms(s,depth)
		assert(depth<64,"CSS numeric expression depth exceeded")
		if s.Kind=="unit"then return {unitTerm(s)}end
		local result
		for _,member in s.Members do
			vm.Step();local current=terms(state(member),depth+1)
			if s.Operator=="negate"then for _,term in current do term.Value=-term.Value end;return current
			elseif s.Operator=="invert"then
				if #current~=1 then ctx.Fail("Cannot invert a CSS sum of different units")end
				local term=current[1];term.Value=1/term.Value;for key,power in term.Units do term.Units[key]=-power end;return current
			elseif not result then result=current
			elseif s.Operator=="sum"then for _,term in current do table.insert(result,term)end
			elseif s.Operator=="product"then
				local product={}
				for _,left in result do for _,right in current do
					vm.Step();assert(#product<256,"CSS numeric term budget exceeded")
					local units=table.clone(left.Units);for key,power in right.Units do units[key]=(units[key]or 0)+power;if units[key]==0 then units[key]=nil end end
					table.insert(product,{Value=left.Value*right.Value,Units=units})
				end end;result=product
			else
				if #result~=1 or #current~=1 or unitKey(result[1].Units)~=unitKey(current[1].Units)then ctx.Fail("CSS comparison needs compatible resolvable units")end
				if s.Operator=="min"then result[1].Value=math.min(result[1].Value,current[1].Value)
				elseif s.Operator=="max"then result[1].Value=math.max(result[1].Value,current[1].Value)end
			end
		end
		if s.Operator=="clamp"then
			local low,mid,high=terms(state(s.Members[1]),depth+1),terms(state(s.Members[2]),depth+1),terms(state(s.Members[3]),depth+1)
			if #low~=1 or #mid~=1 or #high~=1 or unitKey(low[1].Units)~=unitKey(mid[1].Units)or unitKey(mid[1].Units)~=unitKey(high[1].Units)then ctx.Fail("CSS clamp needs compatible resolvable units")end
			return {{Value=math.max(low[1].Value,math.min(mid[1].Value,high[1].Value)),Units=mid[1].Units}}
		end
		local combined,ordered={},{ }
		for _,term in result do
			local key=unitKey(term.Units)
			if combined[key]then combined[key].Value+=term.Value else combined[key]=term;table.insert(ordered,term)end
		end
		return ordered
	end
	function api:Convert(s,unit)
		local result=terms(s,0);local target=unitTerm({Unit=unit,Value=1})
		if #result~=1 or unitKey(result[1].Units)~=unitKey(target.Units)then ctx.Fail("Incompatible CSS unit conversion")end
		return ctx.Finite(result[1].Value/target.Value)
	end
	local function equal(a,b,depth)
		if depth>64 or a.Kind~=b.Kind then return false end
		if a.Kind=="unit"then
			local left,right=unitTerm(a),unitTerm(b)
			return unitKey(left.Units)==unitKey(right.Units)and left.Value==right.Value
		end
		if a.Operator~=b.Operator or #a.Members~=#b.Members then return false end
		for i,value in a.Members do vm.Step();if not equal(state(value),state(b.Members[i]),depth+1)then return false end end
		return true
	end
	function api:Equals(s,args)
		for _,arg in args do if not equal(s,state(arg),0)then return false end end;return true
	end
	local expression
	local function inner(value)
		local s=state(value)
		if s.Kind=="unit"then return ctx.Serialize(s)end
		local body=expression(s)
		return if s.Operator=="sum"or s.Operator=="product"or s.Operator=="invert"or s.Operator=="negate"then "("..body..")"else body
	end
	expression=function(s)
		local parts={}
		if s.Operator=="negate"then
			local child=state(s.Members[1]);if child.Kind=="unit"then return ctx.Serialize({Kind="unit",Unit=child.Unit,Value=-child.Value})end
			return "-"..inner(s.Members[1])
		elseif s.Operator=="invert"then return "1 / "..inner(s.Members[1])end
		for i,value in s.Members do
			local child=state(value)
			if i>1 and s.Operator=="sum"and child.Kind=="math"and child.Operator=="negate"then table.insert(parts," - "..inner(child.Members[1]))
			elseif i>1 and s.Operator=="product"and child.Kind=="math"and child.Operator=="invert"then table.insert(parts," / "..inner(child.Members[1]))
			else table.insert(parts,(if i==1 then ""elseif s.Operator=="sum"then " + "elseif s.Operator=="product"then " * "else ", ")..inner(value))end
		end
		local body=table.concat(parts)
		return if s.Operator=="min"or s.Operator=="max"or s.Operator=="clamp"then s.Operator.."("..body..")"else body
	end
	function api:Serialize(s)
		local body=expression(s)
		return if s.Operator=="min"or s.Operator=="max"or s.Operator=="clamp"then body else "calc("..body..")"
	end
	ctx.Constructor("CSSMathValue",0,mathProto,function()ctx.Fail("Illegal CSSMathValue constructor")end)
	ctx.Accessor(mathProto,"operator",function(self)local s=ctx.Brand(values,self);if s.Kind~="math"then ctx.Fail("Expected CSSMathValue")end;return s.Operator end)
	ctx.Constructor("CSSNumericArray",0,arrayProto,function()ctx.Fail("Illegal CSSNumericArray constructor")end)
	ctx.Accessor(arrayProto,"length",function(self)return #ctx.Brand(arrays,self)end)
	local function array(members)
		local object=vm.Object({},arrayProto);arrays[object]=members;object.TypedNumericMembers=members
		return Indexed.attach(ctx,object,members)
	end
	local function iterator(self,mode)
		local members=ctx.Brand(arrays,self);local i=0;local done=false;local object=vm.Object({})
		ctx.Method(object,"next",0,function()
			if not done then i+=1;done=i>#members end
			return vm.Object({done=done,value=if done then U elseif mode=="keys"then i-1 elseif mode=="entries"then vm.Array({i-1,members[i]})else members[i]})
		end)
		ctx.Define(object,vm.SymbolIterator,{value=ctx.Native("[Symbol.iterator]",0,function(_,receiver)return receiver end)})
		return object
	end
	for _,name in {"entries","keys","values"}do ctx.Method(arrayProto,name,0,function(_,self)return iterator(self,name)end)end
	ctx.Define(arrayProto,vm.SymbolIterator,{value=vm.Get(arrayProto,"values"),writable=true,configurable=true})
	ctx.Method(arrayProto,"forEach",1,function(args,self)ctx.Required(args,1);local members=ctx.Brand(arrays,self);for i,value in members do vm.Step();vm:Call(args[1],{value,i-1,self},args[2]or U)end;return U end)
	local function mathValue(operator,args)
		if #args==0 then VM.throw(vm:Construct(ctx.Globals.DOMException,{"CSS math requires at least one value","SyntaxError"}))end
		assert(#args<=256,"CSS math member budget exceeded")
		local members={};for _,value in args do state(value);table.insert(members,numeric(value))end
		local s={Kind="math",Operator=operator,Members=members};dimensions(s,0)
		return ctx.Wrap(s,prototypes[operator])
	end
	function api:Make(operator,args)return mathValue(operator,args)end
	function api:State(value)return state(value)end
	function api:Type(value)return dimensions(state(value),0)end
	function api:Parse(source)return Parser.parse(ctx,self,source)end
	ctx.Method(ctx.Globals.CSSNumericValue,'parse',1,function(args)ctx.Required(args,1);return api:Parse(ctx.Text(args[1]))end)
	for _,entry in {{"Sum","sum"},{"Product","product"},{"Min","min"},{"Max","max"},{"Negate","negate"},{"Invert","invert"},{"Clamp","clamp"}}do
		local suffix,operator=entry[1],entry[2];local proto=vm.Object({},mathProto);prototypes[operator]=proto
		local arity=if operator=="clamp"then 3 else 1
		ctx.Constructor("CSSMath"..suffix,arity,proto,function(args)
			if operator=="clamp"then ctx.Required(args,3);args={args[1],args[2],args[3]}
			elseif operator=="negate"or operator=="invert"then ctx.Required(args,1);args={args[1]}end
			return mathValue(operator,args)
		end)
		local function own(self)local s=ctx.Brand(values,self);if s.Kind~="math"or s.Operator~=operator then ctx.Fail("Incompatible CSSMath"..suffix.." receiver")end;return s end
		if operator=="negate"or operator=="invert"then ctx.Accessor(proto,"value",function(self)return own(self).Members[1]end)
		elseif operator=="clamp"then
			for i,key in {"lower","value","upper"}do ctx.Accessor(proto,key,function(self)return own(self).Members[i]end)end
		else ctx.Accessor(proto,"values",function(self)local s=own(self);if not s.Array then s.Array=array(s.Members)end;return s.Array end)end
	end
	ctx.Method(ctx.NumericPrototype,"type",0,function(_,self)
		local result=dimensions(state(self),0);local order={}
		for _,key in baseTypes do if result[key]~=nil then table.insert(order,key)end end
		if result.percentHint then table.insert(order,"percentHint")end;return vm.Object(result,nil,order)
	end)
	for _,methodName in {"add","sub","mul","div","min","max"}do
		ctx.Method(ctx.NumericPrototype,methodName,0,function(args,self)
			state(self);local members={self}
			for _,arg in args do state(arg);local value=numeric(arg)
				if methodName=="sub"or methodName=="div"then value=mathValue(if methodName=="sub"then "negate"else "invert",{value})end
				table.insert(members,value)
			end
			local operator=if methodName=="add"or methodName=="sub"then "sum"elseif methodName=="mul"or methodName=="div"then "product"else methodName
			local value=mathValue(operator,members);local first=state(self)
			local same=first.Kind=="unit"
			if operator=="sum"or operator=="min"or operator=="max"then
				for _,arg in args do local s=state(arg);if s.Kind~="unit"or s.Unit~=first.Unit then same=false;break end end
			elseif operator=="product"then for _,arg in args do local s=state(arg);if s.Kind~="unit"or s.Unit~="number"then same=false;break end end end
			return if same then ctx.Scalar(api:Convert(values[value],first.Unit),first.Unit)else value
		end)
	end
	ctx.Method(ctx.NumericPrototype,"toSum",0,function(args,self)
		local result=terms(state(self),0);local members={}
		for _,term in result do
			local unit="number";for key,power in term.Units do if power~=1 or unit~="number"then ctx.Fail("CSS sum contains an unrepresentable unit product")end;unit=key end
			if #args>0 then
				local wanted
				for _,arg in args do local candidate=ctx.ValidUnit(arg);if unitKey(unitTerm({Unit=candidate,Value=1}).Units)==unitKey(term.Units)then wanted=candidate;break end end
				if not wanted then ctx.Fail("Requested CSS sum units cannot represent every term")end
				local target=unitTerm({Unit=wanted,Value=1});term.Value/=target.Value;unit=wanted
			end
			table.insert(members,ctx.Scalar(ctx.Finite(term.Value),unit))
		end
		table.sort(members,function(a,b)return values[a].Unit<values[b].Unit end)
		return mathValue("sum",members)
	end)
	function api:Destroy()for object in arrays do object.TypedNumericMembers=nil end;table.clear(arrays)end
	return api
end
return API
