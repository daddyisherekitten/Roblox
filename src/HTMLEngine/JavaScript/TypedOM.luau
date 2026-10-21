--!strict
-- Scalar Typed OM values use the existing CSS declaration and dirty-tree path.
-- Relative units remain relative; converting them to px requires CSS context.
local Stylesheet=require(script.Parent.Parent.CSS.Stylesheet)
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local Units=require(script.Parent.Parent.CSS.LengthUnits)
local Numeric=require(script.Parent.TypedNumeric)
local Tokens=require(script.Parent.TypedTokens)
local Transforms=require(script.Parent.TypedTransforms)
local Strings=require(script.Parent.Strings)
local TypedOM={}
function TypedOM.install(vm,globals,host)
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true}
	local values=setmetatable({},{__mode='kv'});local maps=setmetatable({},{__mode='kv'});local nodes=setmetatable({},{__mode='k'})
	local function fail(message)VM.throw(VM.error('TypeError',message))end
	local function check()assert(api.Alive and vm.Alive,'Typed OM disposed')end
	local function text(value)value=vm.ToPrimitive(value,'string');if type(value)=='table'and value.Kind=='symbol'then fail('Cannot convert Symbol to string')end;return Strings.usv(VM.string(value))end
	local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,N))end
	local function native(name,length,fn)return {Kind='native-function',Prototype=vm.Prototypes.Function,Values={name=name,length=length},Call=function(args,self)check();return fn(args,self)end}end
	local function method(proto,name,length,fn)define(proto,name,{value=native(name,length,fn),writable=true,enumerable=true,configurable=true})end
	local function accessor(proto,name,get,set)define(proto,name,{get=native('get '..name,0,function(_,self)return get(self)end),set=if set then native('set '..name,1,function(args,self)set(self,args[1]or U);return U end)else U,enumerable=true,configurable=true})end
	local function required(args,n)if #args<n then fail('Missing Typed OM argument')end end
	local function brand(map,value)local s=map[value];if not s then fail('Incompatible Typed OM receiver')end;return s end
	local function property(raw)local name=text(raw);if name:sub(1,2)~='--'then name=name:lower()end;if not Stylesheet.supports('('..name..':initial)')then fail('Unknown CSS property: '..name)end;return name end
	local styleProto=vm.Object({});local numericProto=vm.Object({},styleProto);local unitProto=vm.Object({},numericProto);local keywordProto=vm.Object({},styleProto)
	local readonlyProto=vm.Object({});local mapProto=vm.Object({},readonlyProto)
	local unitTypes={number={'number',1},percent={'percent',1},deg={'angle',1},grad={'angle',.9},rad={'angle',180/math.pi},turn={'angle',360},s={'time',1},ms={'time',.001},hz={'frequency',1},khz={'frequency',1000},dpi={'resolution',1/96},dpcm={'resolution',2.54/96},dppx={'resolution',1},fr={'flex',1}}
	for unit in ('px cm mm q in pt pc em rem ex rex ch rch cap rcap ic ric lh rlh vw vh vi vb vmin vmax svw svh svi svb svmin svmax lvw lvh lvi lvb lvmin lvmax dvw dvh dvi dvb dvmin dvmax cqw cqh cqi cqb cqmin cqmax'):gmatch('%S+')do unitTypes[unit]={if Units.contextual(unit)or Units.font(unit)then unit else 'length',Units.scale(unit,{FontSize=1})or 1}end
	local function validUnit(raw)local unit=text(raw):lower();if not unitTypes[unit]then fail('Invalid CSS unit: '..unit)end;return unit end
	local function finite(raw)local value=VM.number(vm.ToPrimitive(raw,'number'));if value~=value or math.abs(value)==math.huge then fail('CSS numeric values must be finite')end;return value end
	local function wrap(s,proto)local v=vm.Object({},proto);v.TypedOMState=s;values[v]=s;return v end
	local function scalar(n,unit)return wrap({Kind='unit',Value=n,Unit=unit},unitProto)end
	local numeric,tokens,transforms
	local function serialize(s)
		if s.Kind=='math'then return numeric:Serialize(s)end
		if s.Kind=='unparsed'then return tokens:Serialize(s)end
		if s.Kind=='transform'or s.Kind=='transform-component'then return transforms:Serialize(s)end
		if s.Kind=='unit'then return VM.string(s.Value)..(if s.Unit=='number'then ''elseif s.Unit=='percent'then '%'else s.Unit)end
		return s.Value
	end
	method(styleProto,'toString',0,function(_,self)return serialize(brand(values,self))end)
	local function valueState(self,kind)local s=brand(values,self);if s.Kind~=kind then fail('Incompatible CSS '..kind..' receiver')end;return s end
	accessor(unitProto,'value',function(self)return valueState(self,'unit').Value end,function(self,value)valueState(self,'unit').Value=finite(value)end)
	accessor(unitProto,'unit',function(self)return valueState(self,'unit').Unit end)
	accessor(keywordProto,'value',function(self)return valueState(self,'keyword').Value end,function(self,value)local receiver=valueState(self,'keyword');local s=text(value);if s==''then fail('CSSKeywordValue cannot be empty')end;receiver.Value=s end)
	local function convert(s,unit)
		if s.Kind=='math'then return numeric:Convert(s,unit)end
		if s.Kind~='unit'or unitTypes[s.Unit][1]~=unitTypes[unit][1]then fail('Incompatible CSS unit conversion')end
		return s.Value*unitTypes[s.Unit][2]/unitTypes[unit][2]
	end
	method(numericProto,'to',1,function(args,self)required(args,1);local unit=validUnit(args[1]);return scalar(convert(brand(values,self),unit),unit)end)
	method(numericProto,'equals',0,function(args,self)return numeric:Equals(brand(values,self),args)end)
	local function ctor(name,arity,proto,create)
		local c=native(name,arity,function()fail(name..' requires new')end);c.Construct=function(args,newTarget)check();local value=create(args);local p=vm.Get(newTarget or c,'prototype');if vm.ObjectModel.IsObject(p)then value.Prototype=p end;return value end
		if proto.Prototype and proto.Prototype~=vm.Prototypes.Object then local parent=vm.Get(proto.Prototype,'constructor');if VM.callable(parent)then vm.SetPrototype(c,parent)end end
		define(c,'prototype',{value=proto});define(proto,'constructor',{value=c,writable=true,configurable=true});define(proto,vm.SymbolToStringTag,{value=name,configurable=true});globals[name]=c;vm.Global.Bindings[name]={Value=c};return c
	end
	local styleCtor=ctor('CSSStyleValue',0,styleProto,function()fail('Illegal CSSStyleValue constructor')end)
	ctor('CSSNumericValue',0,numericProto,function()fail('Illegal CSSNumericValue constructor')end)
	ctor('CSSUnitValue',2,unitProto,function(args)required(args,2);return scalar(finite(args[1]),validUnit(args[2]))end)
	ctor('CSSKeywordValue',1,keywordProto,function(args)required(args,1);local s=text(args[1]);if s==''then fail('CSSKeywordValue cannot be empty')end;return wrap({Kind='keyword',Value=s},keywordProto)end)
	ctor('StylePropertyMapReadOnly',0,readonlyProto,function()fail('Illegal StylePropertyMapReadOnly constructor')end)
	ctor('StylePropertyMap',0,mapProto,function()fail('Illegal StylePropertyMap constructor')end)
	numeric=Numeric.install({VM=vm,Globals=globals,Values=values,UnitTypes=unitTypes,NumericPrototype=numericProto,
		Fail=fail,Finite=finite,Scalar=scalar,Serialize=serialize,Wrap=wrap,Brand=brand,ValidUnit=validUnit,
		Constructor=ctor,Accessor=accessor,Method=method,Define=define,Native=native,Required=required,Text=text})
	tokens=Tokens.install({VM=vm,Globals=globals,Values=values,StylePrototype=styleProto,Fail=fail,Text=text,Wrap=wrap,Brand=brand,
		Constructor=ctor,Accessor=accessor,Method=method,Define=define,Native=native,Required=required})
	transforms=Transforms.install({VM=vm,Globals=globals,Values=values,Numeric=numeric,StylePrototype=styleProto,Fail=fail,Text=text,Wrap=wrap,Finite=finite,Scalar=scalar,Serialize=serialize,
		Constructor=ctor,Accessor=accessor,Method=method,Define=define,Native=native,Required=required})
	for unit in unitTypes do method(globals.CSS,unit,1,function(args)required(args,1);return scalar(finite(args[1]),unit)end)end
	for unit,name in {q='Q',hz='Hz',khz='kHz'}do method(globals.CSS,name,1,function(args)required(args,1);return scalar(finite(args[1]),unit)end)end
	local function reify(name,source)
		if name=='transform'and source:lower()~='none'then return transforms:Parse(source)end
		if source:match('^[%+%-]?[%d%.]')or source:lower():match('^calc%s*%(')or source:lower():match('^m[ia][nx]%s*%(')or source:lower():match('^clamp%s*%(')then
			local ok,value=pcall(function()return numeric:Parse(source)end);if ok then return value end
			if type(value)~='table'or vm.Get(VM.exceptionValue(value),'name')~='SyntaxError'then error(value,0)end
		end
		local n,unit=source:match('^([%+%-]?%d*%.?%d+)([%a%%]*)$');local number=tonumber(n)
		if number then unit=if unit==''then 'number'elseif unit=='%'then 'percent'else unit:lower();if unitTypes[unit]then return scalar(number,unit)end end
		local ident,after=Syntax.identifier(source);if ident and after>#source then return wrap({Kind='keyword',Value=ident},keywordProto)end
		return wrap({Kind='opaque',Value=source,Property=name},styleProto)
	end
	local function parse(name,source)
		if #source>65536 or not Stylesheet.supports('('..name..':'..source..')')then fail('Invalid CSS value for '..name)end
		local result={};local cursor=1
		-- Custom properties and non-list shorthand values retain their tokens.
		if name:sub(1,2)=='--'or tokens:ContainsReference(source)then return {tokens:Parse(source)}end
		while cursor<=#source do local part,after,delimiter=Syntax.scan(source,cursor,',');part=part:match('^%s*(.-)%s*$');table.insert(result,reify(name,part));cursor=after;if delimiter==''then break end end
		return result
	end
	method(styleCtor,'parse',2,function(args)required(args,2);return parse(property(args[1]),text(args[2]))[1]end)
	method(styleCtor,'parseAll',2,function(args)required(args,2);return vm.Array(parse(property(args[1]),text(args[2])))end)
	local function declaration(s)return s.Declaration()end
	local function read(s,key)
		local d=declaration(s);local source=vm:Call(vm.Get(d,'getPropertyValue'),{key},d)
		return if source==''then {}else parse(key,source)
	end
	method(readonlyProto,'get',1,function(args,self)required(args,1);return read(brand(maps,self),property(args[1]))[1]or U end)
	method(readonlyProto,'getAll',1,function(args,self)required(args,1);return vm.Array(read(brand(maps,self),property(args[1])))end)
	method(readonlyProto,'has',1,function(args,self)required(args,1);return #read(brand(maps,self),property(args[1]))>0 end)
	local function entries(s)
		local d=declaration(s);local result={}
		for i=0,vm.Get(d,'length')-1 do vm.Step();local name=vm:Call(vm.Get(d,'item'),{i},d);table.insert(result,{name,read(s,name)})end
		table.sort(result,function(a,b)return a[1]<b[1]end);return result
	end
	accessor(readonlyProto,'size',function(self)return #entries(brand(maps,self))end)
	local function iterator(items,mode)
		local index=0;local v=vm.Object({});method(v,'next',0,function()index+=1;local item=items[index];return vm.Object({done=item==nil,value=if not item then U elseif mode=='keys'then item[1]elseif mode=='values'then vm.Array(item[2])else vm.Array({item[1],vm.Array(item[2])})})end)
		define(v,vm.SymbolIterator,{value=native('[Symbol.iterator]',0,function(_,self)return self end),writable=true,configurable=true});return v
	end
	for _,name in {'keys','values','entries'}do method(readonlyProto,name,0,function(_,self)return iterator(entries(brand(maps,self)),name)end)end
	define(readonlyProto,vm.SymbolIterator,{value=vm.Get(readonlyProto,'entries'),writable=true,configurable=true})
	method(readonlyProto,'forEach',1,function(args,self)required(args,1);for _,entry in entries(brand(maps,self))do vm.Step();vm:Call(args[1],{vm.Array(entry[2]),entry[1],self},args[2]or U)end;return U end)
	method(mapProto,'set',1,function(args,self)
		required(args,2);local s=brand(maps,self);local key=property(args[1]);local parts={}
		for i=2,#args do local v=values[args[i]];if v and v.Property and v.Property~=key then fail('CSSStyleValue belongs to a different property')end;table.insert(parts,if v then serialize(v)else text(args[i]))end
		local source=table.concat(parts,', ');parse(key,source);local d=declaration(s);vm:Call(vm.Get(d,'setProperty'),{key,source},d);return U
	end)
	method(mapProto,'delete',1,function(args,self)required(args,1);local d=declaration(brand(maps,self));vm:Call(vm.Get(d,'removeProperty'),{property(args[1])},d);return U end)
	method(mapProto,'clear',0,function(_,self)local d=declaration(brand(maps,self));vm.Set(d,'cssText','',true);return U end)
	local function slot(node)
		node.TypedOMStyleMaps=node.TypedOMStyleMaps or{};local s=node.TypedOMStyleMaps[api]
		if not s then s={};node.TypedOMStyleMaps[api]=s;nodes[node]=true end;return s
	end
	local function styleMap(node,computed)
		local entry=slot(node);local key=if computed then'Computed'else'Inline';if entry[key]then return entry[key]end
		local d=if computed then vm:Call(globals.getComputedStyle,{host.Wrap(node)},U)else nil
		local value=vm.Object({},if computed then readonlyProto else mapProto)
		local s={Declaration=if computed then function()return d end else function()return vm.Get(host.Wrap(node),'style')end}
		value.TypedOMMap=s;maps[value]=s;entry[key]=value;return value
	end
	local function element(self)local node=host.Unwrap(self);if not node or node.Kind~='Element'then fail('Expected Element')end;return node end
	local elementProto=vm.Get(globals.Element,'prototype')
	accessor(elementProto,'attributeStyleMap',function(self)return styleMap(element(self),false)end)
	method(elementProto,'computedStyleMap',0,function(_,self)return styleMap(element(self),true)end)
	function api:ElementGet(node,key)
		if node.Kind~='Element'then return nil end
		if key=='attributeStyleMap'then return styleMap(node,false)end
		if key=='computedStyleMap'then return vm.Get(elementProto,key)end
		return nil
	end
	function api:Destroy()
		self.Alive=false;tokens:Destroy();numeric:Destroy()
		for node in nodes do node.TypedOMStyleMaps[api]=nil;if not next(node.TypedOMStyleMaps)then node.TypedOMStyleMaps=nil end end
		for v in values do v.TypedOMState=nil end;for v,s in maps do s.Declaration=function()error('Typed OM disposed')end;v.TypedOMMap=nil end
		table.clear(values);table.clear(maps);table.clear(nodes)
	end
	return api
end
return TypedOM
