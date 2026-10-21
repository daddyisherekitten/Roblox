--!strict
-- Typed transforms retain their numeric children and share the engine's
-- matrices. Percentage/font lengths need layout and cannot invent toMatrix bases.
local Matrix=require(script.Parent.Parent.CSS.Matrix4)
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local Indexed=require(script.Parent.TypedIndexed)
local Transforms={}
local ELEMENTS={'m11','m12','m13','m14','m21','m22','m23','m24','m31','m32','m33','m34','m41','m42','m43','m44'}
local TWO_D={1,2,5,6,13,14}
function Transforms.install(ctx: any): any
	local vm,VM=ctx.VM,ctx.VM.Model;local U,N=VM.Undefined,VM.Null;local numeric=ctx.Numeric
	local api={};local componentProto=vm.Object({});local listProto=vm.Object({},ctx.StylePrototype);local prototypes={}
	-- WebIDL conversions and Typed OM operations use internal matrix slots,
	-- even when author code replaces public constructors or accessors.
	local matrixCtor=ctx.Globals.DOMMatrix;local keywordCtor=ctx.Globals.CSSKeywordValue;local constructors={}
	local readonlyMatrix=vm.Get(ctx.Globals.DOMMatrixReadOnly,'prototype')
	local matrix2D=vm.ObjectModel.Own(readonlyMatrix,'is2D').Get
	local mutableMatrix=vm.ObjectModel.Own(vm.Get(matrixCtor,'prototype'),'m11').Get
	local matrixGetters={};for i,key in ELEMENTS do matrixGetters[i]=vm.ObjectModel.Own(readonlyMatrix,key).Get end
	local function state(value,kind)
		local s=ctx.Values[value];if not s or s.Kind~=kind then ctx.Fail('Incompatible CSS transform receiver')end;return s
	end
	local function numericValue(value,kind,percent,numberish)
		local candidate=ctx.Values[value]
		if numberish and(not candidate or candidate.Kind~='unit'and candidate.Kind~='math')then value=ctx.Scalar(ctx.Finite(value),'number')end
		local s=ctx.Values[value];if not s or s.Kind~='unit'and s.Kind~='math'then ctx.Fail('Expected CSSNumericValue')end
		local t=numeric:Type(value)
		for _,key in {'length','angle','time','frequency','resolution','flex','percent'}do
			if t[key]and t[key]~=(if key==kind or percent and key=='percent'then 1 else 0)then ctx.Fail('Incompatible CSS transform dimension')end
		end
		local matches=if kind=='number'then not next(t)else t[kind]==1 and not t.percent or percent and t.percent==1 and not t[kind]
		if not matches or t.percentHint and (not percent or t.percentHint~=kind)then ctx.Fail('Incompatible CSS transform dimension')end
		return value
	end
	local function num(value,unit)return numeric:Convert(numeric:State(value),unit)end
	local function serialized(value)return ctx.Serialize(ctx.Values[value])end
	local function matrixBrand(value)
		vm:Call(matrix2D,{},value);return value
	end
	local function matrixValues(value)
		local result={};for i,get in matrixGetters do result[i]=vm:Call(get,{},value)end;return result
	end
	local function matrixObject(values,is2D)
		if is2D then local compact={};for _,i in TWO_D do table.insert(compact,values[i])end;values=compact end
		return vm:Construct(matrixCtor,{vm.Array(values)})
	end
	local function cloneMatrix(value)matrixBrand(value);return matrixObject(matrixValues(value),vm:Call(matrix2D,{},value))end
	local function perspective(value)
		local s=ctx.Values[value]
		if s and(s.Kind=='unit'or s.Kind=='math')then return numericValue(value,'length')end
		local raw=if s and s.Kind=='keyword'then s.Value else ctx.Text(value)
		if raw:lower()~='none'then ctx.Fail('CSSPerspective expects a length or none')end
		return if s and s.Kind=='keyword'then value else vm:Construct(keywordCtor,{raw})
	end
	local function make(operator,fields,is2D)
		return ctx.Wrap({Kind='transform-component',Operator=operator,Fields=fields,Is2D=is2D},prototypes[operator])
	end
	local function serialize(s)
		local op,f=s.Operator,s.Fields;local args={};local name=op
		if op=='matrix'then
			local values=matrixValues(f.matrix);name=if s.Is2D then'matrix'else'matrix3d'
			for _,i in if s.Is2D then TWO_D else{1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16}do table.insert(args,VM.string(values[i]))end
		elseif op=='translate'or op=='scale'then
			name=if s.Is2D then op else op..'3d';for _,key in if s.Is2D then{'x','y'}else{'x','y','z'}do table.insert(args,serialized(f[key]))end
		elseif op=='rotate'then
			if not s.Is2D then name='rotate3d';for _,key in {'x','y','z'}do table.insert(args,serialized(f[key]))end end;table.insert(args,serialized(f.angle))
		elseif op=='skew'then args={serialized(f.ax),serialized(f.ay)}
		elseif op=='skewX'then args={serialized(f.ax)}
		elseif op=='skewY'then args={serialized(f.ay)}
		else args={serialized(f.length)}end
		return name..'('..table.concat(args,', ')..')'
	end
	local function resolved(s)
		local op,f=s.Operator,s.Fields;local m=Matrix.identity()
		if op=='matrix'then m=matrixValues(f.matrix)
		elseif op=='translate'then m=Matrix.translate(num(f.x,'px'),num(f.y,'px'),if s.Is2D then 0 else num(f.z,'px'))
		elseif op=='scale'then m=Matrix.scale(num(f.x,'number'),num(f.y,'number'),if s.Is2D then 1 else num(f.z,'number'))
		elseif op=='rotate'then
			local absolute='rotate'..(if s.Is2D then'('else'3d('..VM.string(num(f.x,'number'))..', '..VM.string(num(f.y,'number'))..', '..VM.string(num(f.z,'number'))..', ')..VM.string(num(f.angle,'deg'))..'deg)'
			m=matrixValues(vm:Construct(matrixCtor,{absolute}))
		elseif op=='skew'or op=='skewX'or op=='skewY'then
			if f.ax then m[5]=math.tan(math.rad(num(f.ax,'deg')))end;if f.ay then m[2]=math.tan(math.rad(num(f.ay,'deg')))end
		elseif op=='perspective'then if ctx.Values[f.length].Kind~='keyword'then m=Matrix.perspective(num(f.length,'px'))end end
		if op=='matrix'and s.Is2D then local plane=Matrix.identity();for _,i in TWO_D do plane[i]=m[i]end;m=plane end
		return m
	end
	ctx.Constructor('CSSTransformComponent',0,componentProto,function()ctx.Fail('Illegal CSSTransformComponent constructor')end)
	ctx.Method(componentProto,'toString',0,function(_,self)return serialize(state(self,'transform-component'))end)
	ctx.Method(componentProto,'toMatrix',0,function(_,self)local s=state(self,'transform-component');return matrixObject(resolved(s),s.Is2D)end)
	ctx.Accessor(componentProto,'is2D',function(self)return state(self,'transform-component').Is2D end,function(self,value)
		local s=state(self,'transform-component');if s.Operator=='skew'or s.Operator=='skewX'or s.Operator=='skewY'or s.Operator=='perspective'then return end;s.Is2D=VM.truth(value)
	end)
	for _,entry in {{'CSSTranslate','translate',2},{'CSSScale','scale',2},{'CSSRotate','rotate',1},{'CSSSkew','skew',2},{'CSSSkewX','skewX',1},{'CSSSkewY','skewY',1},{'CSSPerspective','perspective',1},{'CSSMatrixComponent','matrix',1}}do
		local name,op,arity=entry[1],entry[2],entry[3];local proto=vm.Object({},componentProto);prototypes[op]=proto
		local validators={}
		if op=='translate'then validators={x=function(v)return numericValue(v,'length',true)end,y=function(v)return numericValue(v,'length',true)end,z=function(v)return numericValue(v,'length')end}
		elseif op=='scale'then for _,key in {'x','y','z'}do validators[key]=function(v)return numericValue(v,'number',false,true)end end
		elseif op=='rotate'then for _,key in {'x','y','z'}do validators[key]=function(v)return numericValue(v,'number',false,true)end end;validators.angle=function(v)return numericValue(v,'angle')end
		elseif op=='skew'or op=='skewX'or op=='skewY'then if op~='skewY'then validators.ax=function(v)return numericValue(v,'angle')end end;if op~='skewX'then validators.ay=function(v)return numericValue(v,'angle')end end
		elseif op=='perspective'then validators.length=perspective
		else validators.matrix=function(v)
			vm:Call(mutableMatrix,{},v);return v
		end end
		for key,validate in validators do ctx.Accessor(proto,key,function(self)local s=state(self,'transform-component');if s.Operator~=op then ctx.Fail('Incompatible '..name..' receiver')end;return s.Fields[key]end,function(self,value)local s=state(self,'transform-component');if s.Operator~=op then ctx.Fail('Incompatible '..name..' receiver')end;s.Fields[key]=validate(value)end)end
		constructors[name]=ctx.Constructor(name,arity,proto,function(args)
			ctx.Required(args,arity);local f={};local is2D=true
			if op=='translate'or op=='scale'then
				f.x=validators.x(args[1]);f.y=validators.y(args[2]);is2D=args[3]==nil or args[3]==U;f.z=if is2D then ctx.Scalar(if op=='translate'then 0 else 1,if op=='translate'then'px'else'number')else validators.z(args[3])
			elseif op=='rotate'then
				if #args<4 then if #args~=1 then ctx.Fail('CSSRotate requires one or four arguments')end;f={x=ctx.Scalar(0,'number'),y=ctx.Scalar(0,'number'),z=ctx.Scalar(1,'number'),angle=validators.angle(args[1])}
				else is2D=false;f={x=validators.x(args[1]),y=validators.y(args[2]),z=validators.z(args[3]),angle=validators.angle(args[4])}end
			elseif op=='matrix'then
				f.matrix=cloneMatrix(args[1]);is2D=vm:Call(matrix2D,{},f.matrix);local options=args[2]
				if options~=nil and options~=U and options~=N then if not vm.ObjectModel.IsObject(options)then ctx.Fail('Invalid CSSMatrixComponent options')end;local flag=vm.Get(options,'is2D');if flag~=U then is2D=VM.truth(flag)end end
			elseif op=='perspective'then f.length=perspective(args[1]);is2D=false
			elseif op=='skew'then f.ax=validators.ax(args[1]);f.ay=validators.ay(args[2])
			else local key=if op=='skewX'then'ax'else'ay';f[key]=validators[key](args[1])end
			return make(op,f,is2D)
		end)
	end
	local function list(members)
		if #members==0 then ctx.Fail('CSSTransformValue cannot be empty')end
		local s={Kind='transform',Members=members};local object=ctx.Wrap(s,listProto)
		return Indexed.attach(ctx,object,members,function(i,value)
			state(value,'transform-component');if i>#members then VM.throw(VM.error('RangeError','Transform index exceeds length'))end
			assert(i<256,'CSS transform member budget exceeded');members[i+1]=value;return true
		end)
	end
	ctx.Constructor('CSSTransformValue',1,listProto,function(args)
		ctx.Required(args,1);local nextValue=vm.Iterator(args[1]);local members={}
		while true do vm.Step();local more,value=nextValue();if not more then break end;state(value,'transform-component');assert(#members<256,'CSS transform member budget exceeded');table.insert(members,value)end
		return list(members)
	end)
	ctx.Accessor(listProto,'length',function(self)return #state(self,'transform').Members end)
	ctx.Accessor(listProto,'is2D',function(self)for _,value in state(self,'transform').Members do if not state(value,'transform-component').Is2D then return false end end;return true end)
	ctx.Method(listProto,'toMatrix',0,function(_,self)
		local m=Matrix.identity();local is2D=true;for _,value in state(self,'transform').Members do vm.Step();local s=state(value,'transform-component');m=Matrix.multiply(m,resolved(s));is2D=is2D and s.Is2D end;return matrixObject(m,is2D)
	end)
	for _,mode in {'entries','keys','values'}do ctx.Method(listProto,mode,0,function(_,self)
		local members=state(self,'transform').Members;local i,done=0,false;local iterator=vm.Object({},vm.Prototypes.Iterator)
		ctx.Method(iterator,'next',0,function()if not done then i+=1;done=i>#members end;return vm.Object({done=done,value=if done then U elseif mode=='keys'then i-1 elseif mode=='entries'then vm.Array({i-1,members[i]})else members[i]})end);return iterator
	end)end
	ctx.Define(listProto,vm.SymbolIterator,{value=vm.Get(listProto,'values'),writable=true,configurable=true})
	ctx.Method(listProto,'forEach',1,function(args,self)ctx.Required(args,1);local members=state(self,'transform').Members;local i=1;while i<=#members do vm.Step();vm:Call(args[1],{members[i],i-1,self},args[2]or U);i+=1 end;return U end)
	function api:Serialize(s)
		if s.Kind=='transform-component'then return serialize(s)end
		local parts={};for _,value in s.Members do vm.Step();table.insert(parts,serialize(state(value,'transform-component')))end;return table.concat(parts,' ')
	end
	function api:Parse(source)
		local members={};local cursor=1
		while cursor<=#source do
			vm.Step();local _,last=source:find('^[ \t\n\r\f]*',cursor);cursor=(last or cursor-1)+1;if cursor>#source then break end
			local name,start=Syntax.identifier(source,cursor);if not name or source:sub(start,start)~='('then ctx.Fail('Invalid transform function')end
			local body,finish,closing=Syntax.scan(source,start+1,')');if closing~=''and closing~=')'then ctx.Fail('Invalid transform block')end;cursor=finish;name=name:lower()
			local args={};local at=1
			while at<=#body do local part,after,delimiter=Syntax.scan(body,at,',');part=part:match('^%s*(.-)%s*$');if part==''then ctx.Fail('Empty transform argument')end
				if part:lower()=='none'then table.insert(args,'none')else
					local value=numeric:Parse(part);local s=ctx.Values[value];if s.Kind=='math'and s.Operator=='sum'and #s.Members==1 then value=s.Members[1];s=ctx.Values[value]end
					if s.Kind=='unit'and s.Unit=='number'and s.Value==0 and tonumber(part)==0 then
						if name:sub(1,9)=='translate'or name=='perspective'then value=ctx.Scalar(0,'px')
						elseif name:sub(1,4)=='skew'or name:sub(1,6)=='rotate'and(name~='rotate3d'or #args==3)then value=ctx.Scalar(0,'deg')end
					elseif name:sub(1,5)=='scale'and s.Kind=='unit'and s.Unit=='percent'then value=ctx.Scalar(s.Value/100,'number')end
					table.insert(args,value)
				end
				at=after;if delimiter==''then break end;if at>#body then ctx.Fail('Trailing transform comma')end
			end
			local value
			local function construct(typeName,parameters)return vm:Construct(constructors[typeName],parameters)end
			if name=='matrix'or name=='matrix3d'then
				if #args~=(if name=='matrix'then 6 else 16)then ctx.Fail('Invalid matrix arity')end;local matrixArgs={};for _,arg in args do table.insert(matrixArgs,num(numericValue(arg,'number'),'number'))end
				value=construct('CSSMatrixComponent',{vm:Construct(matrixCtor,{vm.Array(matrixArgs)})})
			elseif name=='translate'or name=='translate3d'then if #args<1 or #args>(if name=='translate'then 2 else 3)or name=='translate3d'and #args~=3 then ctx.Fail('Invalid translate arity')end;value=construct('CSSTranslate',{args[1],args[2]or ctx.Scalar(0,'px'),args[3]})
			elseif name=='translatex'or name=='translatey'or name=='translatez'then if #args~=1 then ctx.Fail('Invalid translate arity')end;local p={ctx.Scalar(0,'px'),ctx.Scalar(0,'px')};p[if name=='translatex'then 1 elseif name=='translatey'then 2 else 3]=args[1];value=construct('CSSTranslate',p)
			elseif name=='scale'or name=='scale3d'then if #args<1 or #args>(if name=='scale'then 2 else 3)or name=='scale3d'and #args~=3 then ctx.Fail('Invalid scale arity')end;value=construct('CSSScale',{args[1],args[2]or args[1],args[3]})
			elseif name=='scalex'or name=='scaley'or name=='scalez'then if #args~=1 then ctx.Fail('Invalid scale arity')end;local p={ctx.Scalar(1,'number'),ctx.Scalar(1,'number')};p[if name=='scalex'then 1 elseif name=='scaley'then 2 else 3]=args[1];value=construct('CSSScale',p)
			elseif name=='rotate'then if #args~=1 then ctx.Fail('Invalid rotation arity')end;value=construct('CSSRotate',args)
			elseif name=='rotate3d'then if #args~=4 then ctx.Fail('Invalid rotation arity')end;value=construct('CSSRotate',args)
			elseif name=='rotatex'or name=='rotatey'or name=='rotatez'then if #args~=1 then ctx.Fail('Invalid rotation arity')end;local p={0,0,0,args[1]};p[if name=='rotatex'then 1 elseif name=='rotatey'then 2 else 3]=1;value=construct('CSSRotate',p)
			elseif name=='skew'then if #args<1 or #args>2 then ctx.Fail('Invalid skew arity')end;value=construct('CSSSkew',{args[1],args[2]or ctx.Scalar(0,'deg')})
			elseif name=='skewx'or name=='skewy'then if #args~=1 then ctx.Fail('Invalid skew arity')end;value=construct(if name=='skewx'then'CSSSkewX'else'CSSSkewY',args)
			elseif name=='perspective'then if #args~=1 then ctx.Fail('Invalid perspective arity')end;value=construct('CSSPerspective',args)
			else ctx.Fail('Unsupported transform function')end
			assert(#members<256,'CSS transform member budget exceeded');table.insert(members,value)
		end
		return list(members)
	end
	return api
end
return Transforms
