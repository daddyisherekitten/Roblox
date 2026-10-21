--!strict
-- Token-preserving custom properties and var() references. These objects do
-- not resolve variables; the existing cascade remains the single resolver.
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local Indexed=require(script.Parent.TypedIndexed)
local Tokens={}
function Tokens.install(ctx: any): any
	local vm,VM=ctx.VM,ctx.VM.Model;local U,N=VM.Undefined,VM.Null
	local unparsedProto=vm.Object({},ctx.StylePrototype);local referenceProto=vm.Object({})
	local references=setmetatable({},{__mode="kv"});local api={}
	local function variable(value)
		local name=ctx.Text(value);local ident,after=Syntax.identifier(name)
		if name:sub(1,2)~="--"or ident~=name or after<=#name then ctx.Fail("Expected a custom property name")end
		return name
	end
	local function unparsed(value)
		local s=ctx.Values[value];if not s or s.Kind~="unparsed"then ctx.Fail("Expected CSSUnparsedValue")end;return s
	end
	local function segment(value)return if references[value]then value else ctx.Text(value)end
	local function make(members)
		local s={Kind="unparsed",Members=members};local object=ctx.Wrap(s,unparsedProto)
		local function assign(i,value)
			if i>#s.Members then VM.throw(VM.error("RangeError","CSSUnparsedValue index exceeds length"))end
			assert(i<4096,"CSS unparsed segment budget exceeded");s.Members[i+1]=segment(value);return true
		end
		return Indexed.attach(ctx,object,members,assign)
	end
	local function reference(name,fallback)
		local s={Variable=variable(name),Fallback=if fallback==nil or fallback==N then N else fallback}
		if s.Fallback~=N then unparsed(s.Fallback)end
		local object=vm.Object({},referenceProto);references[object]=s;object.CSSVariableState=s;return object
	end
	ctx.Constructor("CSSUnparsedValue",1,unparsedProto,function(args)
		ctx.Required(args,1);local iterator=vm.Iterator(args[1]);local members={}
		while true do vm.Step();local more,value=iterator();if not more then break end;assert(#members<4096,"CSS unparsed segment budget exceeded");table.insert(members,segment(value))end
		assert(#members<=4096,"CSS unparsed segment budget exceeded");return make(members)
	end)
	ctx.Constructor("CSSVariableReferenceValue",1,referenceProto,function(args)ctx.Required(args,1);return reference(args[1],args[2])end)
	ctx.Accessor(referenceProto,"variable",function(self)return ctx.Brand(references,self).Variable end,function(self,value)ctx.Brand(references,self).Variable=variable(value)end)
	ctx.Accessor(referenceProto,"fallback",function(self)return ctx.Brand(references,self).Fallback end)
	ctx.Accessor(unparsedProto,"length",function(self)return #unparsed(self).Members end)
	local function iterator(self,mode)
		local i,done=0,false;unparsed(self);local object=vm.Object({})
		ctx.Method(object,"next",0,function()
			local members=unparsed(self).Members
			if not done then i+=1;done=i>#members end
			return vm.Object({done=done,value=if done then U elseif mode=="keys"then i-1 elseif mode=="entries"then vm.Array({i-1,members[i]})else members[i]})
		end)
		ctx.Define(object,vm.SymbolIterator,{value=ctx.Native("[Symbol.iterator]",0,function(_,receiver)return receiver end)})
		return object
	end
	for _,name in {"entries","keys","values"}do ctx.Method(unparsedProto,name,0,function(_,self)return iterator(self,name)end)end
	ctx.Define(unparsedProto,vm.SymbolIterator,{value=vm.Get(unparsedProto,"values"),writable=true,configurable=true})
	ctx.Method(unparsedProto,"forEach",1,function(args,self)ctx.Required(args,1);local i=1;while i<=#unparsed(self).Members do vm.Step();vm:Call(args[1],{unparsed(self).Members[i],i-1,self},args[2]or U);i+=1 end;return U end)
	local function serialize(s,seen,depth)
		if depth>=64 or seen[s]then ctx.Fail("Cyclic CSS variable fallback")end
		seen[s]=true;local parts={};local bytes=0
		for _,member in s.Members do
			vm.Step();local ref=references[member]
			if ref then
				local escaped=vm:Call(vm.Get(ctx.Globals.CSS,"escape"),{ref.Variable},U)
				table.insert(parts,"var("..escaped..(if ref.Fallback==N then ""else ","..serialize(unparsed(ref.Fallback),seen,depth+1))..")")
			else table.insert(parts,member)end
			bytes+=#parts[#parts];assert(bytes<=65536,"CSS unparsed serialization budget exceeded")
		end
		seen[s]=nil;return table.concat(parts)
	end
	function api:Serialize(s)return serialize(s,{},0)end
	local parse
	parse=function(source,depth)
		assert(depth<32 and #source<=65536,"CSS unparsed token budget exceeded")
		local members={};local cursor=1
		while cursor<=#source do
			vm.Step();local at,bodyStart=Syntax.findFunction(source,cursor,'var')
			if not at then table.insert(members,source:sub(cursor));break end
			local body,finish,closing=Syntax.scan(source,bodyStart,")")
			if closing~=")"then ctx.Fail("Unclosed CSS variable reference")end
			local name,start,delimiter=Syntax.scan(body,1,",")
			name=Syntax.unescape(name:match("^%s*(.-)%s*$"))
			if at>cursor then table.insert(members,source:sub(cursor,at-1))end
			table.insert(members,reference(name,if delimiter==","then parse(body:sub(start),depth+1)else N));cursor=finish
			assert(#members<=4096,"CSS unparsed segment budget exceeded")
		end
		assert(#members<=4096,"CSS unparsed segment budget exceeded");return make(members)
	end
	function api:Parse(source)return parse(source,0)end
	function api:ContainsReference(source)
		return Syntax.findFunction(source,1,'var')~=nil
	end
	function api:Destroy()for value in references do value.CSSVariableState=nil end;table.clear(references)end
	return api
end
return Tokens
