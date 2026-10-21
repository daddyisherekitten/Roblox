--!strict
-- CSS Font Loading state belongs to a realm; actual font decoding/preload is
-- provided by an explicit host adapter. An unavailable font never succeeds.
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local Strings=require(script.Parent.Strings)
local FontLoading={}
local defaults={style="normal",weight="normal",stretch="normal",unicodeRange="U+0-10FFFF",variant="normal",featureSettings="normal",variationSettings="normal",display="auto",ascentOverride="normal",descentOverride="normal",lineGapOverride="normal"}
local function trim(value)return value:match("^%s*(.-)%s*$")end
local function family(value)
	value=trim(value);local quote=value:sub(1,1)
	if quote=="'"or quote=='"'then if #value<3 or value:sub(-1)~=quote or value:sub(2,-2):find(quote,1,true)or value:find("[\r\n\f\\]")then return nil end;return value:sub(2,-2)end
	if value==""or value:find("[,;()\\]")then return nil end
	local parts={};for word in value:gmatch("%S+")do if not word:match("^[%a_\128-\255%-][%w_\128-\255%-]*$")then return nil end;table.insert(parts,word)end
	return table.concat(parts," ")
end
local function ranges(value)
	local result={};for token in value:gmatch("[^,]+")do
		token=trim(token):upper();local low,high=token:match("^U%+([0-9A-F]+)%-([0-9A-F]+)$")
		if low then low,high=tonumber(low,16),tonumber(high,16)
		else local single=token:match("^U%+([0-9A-F?]+)$");if not single or #single>6 then return nil end
			if single:find("?",1,true)then if not single:match("^[0-9A-F]*%?+$")then return nil end;low,high=tonumber((single:gsub("?","0")),16),tonumber((single:gsub("?","F")),16)
			else low=tonumber(single,16);high=low end
		end
		if not low or not high or low>high or high>0x10ffff then return nil end;table.insert(result,{low,high})
	end;return if #result>0 then result else nil
end
local function descriptor(key,value)
	local lower=trim(value):lower()
	if key=="style"then return lower=="normal"or lower=="italic"or lower=="oblique"
	elseif key=="weight"then if lower=="normal"or lower=="bold"then return true end;local a,b=lower:match("^(%d+)%s+(%d+)$");a=tonumber(a or lower);b=tonumber(b)or a;return a~=nil and a>=1 and b<=1000 and a<=b
	elseif key=="stretch"then return lower=="normal"or lower=="condensed"or lower=="expanded"or lower=="semi-condensed"or lower=="semi-expanded"or lower=="extra-condensed"or lower=="extra-expanded"or lower=="ultra-condensed"or lower=="ultra-expanded"or(lower:match("^[%d%.]+%%$")~=nil and(tonumber(lower:sub(1,-2))or 0)>0)
	elseif key=="unicodeRange"then return ranges(value)~=nil
	elseif key=="display"then return lower=="auto"or lower=="block"or lower=="swap"or lower=="fallback"or lower=="optional"
	elseif key=="variant"then return lower=="normal"or lower=="small-caps"
	elseif key=="ascentOverride"or key=="descentOverride"or key=="lineGapOverride"then return lower=="normal"or lower:match("^[%d%.]+%%$")~=nil
	elseif key=="featureSettings"or key=="variationSettings"then return lower=="normal"or lower:match('^["\']%w%w%w%w["\']')~=nil end
	return false
end
local function parseFont(value)
	local cursor=1;local sizeFound=false;local weight,style="normal","normal"
	while cursor<=#value do
		local token,nextCursor=Syntax.scan(value,cursor," \t\r\n");cursor=nextCursor;token=trim(token):lower();if token==""then continue end
		local size,line=token:match("^([^/]+)/?(.*)$")
		if size:match("^[%d%.]+[a-z%%]+$")or({['xx-small']=true,['x-small']=true,small=true,medium=true,large=true,['x-large']=true,['xx-large']=true,['xxx-large']=true,smaller=true,larger=true})[size]then
			local numeric,unit=size:match("^([%d%.]+)([a-z%%]+)$")
			if numeric and(not tonumber(numeric)or tonumber(numeric)<0 or not({px=true,pt=true,pc=true,['in']=true,cm=true,mm=true,q=true,em=true,rem=true,ex=true,ch=true,vw=true,vh=true,['%']=true})[unit])then return nil end
			if line~=""and line~="normal"and not line:match("^[%d%.]+[a-z%%]*$")then return nil end
			sizeFound=true;break
		elseif token=="normal"or token=="small-caps"then continue
		elseif token=="italic"or token=="oblique"then style=token
		elseif token=="bold"or token:match("^%d+$")and tonumber(token)>=1 and tonumber(token)<=1000 then weight=token
		elseif token=="condensed"or token=="expanded"then continue else return nil end
	end
	if not sizeFound then return nil end
	local rest=trim(value:sub(cursor));if rest:sub(1,1)=="/"then local _,nextCursor=Syntax.scan(rest,2," \t\r\n");rest=trim(rest:sub(nextCursor))end
	local families={};local index=1;while index<=#rest do local part,nextIndex=Syntax.scan(rest,index,",");index=nextIndex;local name=family(part);if not name then return nil end;table.insert(families,name:lower())end
	return if #families>0 then{Families=families,Weight=weight,Style=style}else nil
end
FontLoading.parseFont=parseFont
function FontLoading.install(vm: any,globals: any,options: any): any
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true}
	local faces=setmetatable({},{__mode="kv"});local members,order,loading,loaded,failed={},{},{},{},{}
	local iterators=setmetatable({},{__mode="k"});local memberCount=0
	local hostPending=0;local status="loaded";local ready,readyResolve;local readyPending=true
	local faceProto=vm.Object({});local setProto=vm.Object({},vm.Get(globals.EventTarget,"prototype"));local set=vm.Object({},setProto)
	local function check()assert(api.Alive and vm.Alive,"Font loading disposed")end
	local function exception(name,message)return if options.Events then options.Events:DOMException(message,name)else VM.error(name,message)end
	local function fail(name,message)VM.throw(exception(name,message))end
	local function text(value)local primitive=vm.ToPrimitive(value,"string");if type(primitive)=="table"and primitive.Kind=="symbol"then fail("TypeError","Cannot convert Symbol to string")end;return VM.string(primitive)end
	local function native(name,length,fn)return {Kind="native-function",Prototype=vm.Prototypes.Function,Values={name=name,length=length},Call=function(args,self)check();return fn(args,self)end}end
	local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,N))end
	local function accessor(proto,key,read,write)define(proto,key,{get=native("get "..key,0,function(_,self)return read(self)end),set=if write then native("set "..key,1,function(args,self)write(self,if args[1]==nil then U else args[1]);return U end)else U,enumerable=true,configurable=true})end
	local function method(proto,key,length,fn)define(proto,key,{value=native(key,length,fn),writable=true,enumerable=true,configurable=true})end
	local function brand(value)local state=faces[value];if not state then fail("TypeError","Illegal FontFace receiver")end;return state end
	local function brandSet(self)if self~=set then fail("TypeError","Illegal FontFaceSet receiver")end end
	local function task(fn)options.QueueTask(function()if api.Alive then fn()end end)end
	local eventProto=vm.Object({},vm.Get(globals.Event,"prototype"));local fontEvents=setmetatable({},{__mode="kv"})
	local freeze=vm.Get(globals.Object,"freeze")
	local function fontEvent(kind,values,init)
		local event=options.Events:NewEvent(kind,init);vm.SetPrototype(event,eventProto)
		local list=vm.Array(table.clone(values or{}));vm:Call(freeze,{list});event.FontLoadFaces=list;fontEvents[event]=list
		return event
	end
	accessor(eventProto,"fontfaces",function(self)local list=fontEvents[self];if not list then fail("TypeError","Illegal FontFaceSetLoadEvent receiver")end;return list end)
	define(eventProto,vm.SymbolToStringTag,{value="FontFaceSetLoadEvent",configurable=true})
	local eventCtor=native("FontFaceSetLoadEvent",1,function()fail("TypeError","FontFaceSetLoadEvent requires new")end)
	eventCtor.Construct=function(args)
		if #args<1 then fail("TypeError","FontFaceSetLoadEvent requires a type")end
		local init=args[2];local values={};local settings={}
		if init~=nil and init~=U and init~=N then
			for _,key in {"bubbles","cancelable","composed"}do settings[key]=VM.truth(vm.Get(init,key))end
			local supplied=vm.Get(init,"fontfaces")
			if supplied~=U then
				local nextValue,close=vm.Iterator(supplied);local ok,message=pcall(function()
					while true do local more,value=nextValue();if not more then break end;brand(value);table.insert(values,value);vm.Step()end
				end)
				if not ok then if close then pcall(close)end;error(message,0)end
			end
		end
		return fontEvent(text(args[1]),values,settings)
	end
	define(eventCtor,"prototype",{value=eventProto});define(eventProto,"constructor",{value=eventCtor,writable=true,configurable=true});globals.FontFaceSetLoadEvent=eventCtor;vm.Global.Bindings.FontFaceSetLoadEvent={Value=eventCtor}
	local function emit(kind,values)
		local included={};for _,face in values or{}do if members[face]then table.insert(included,face)end end
		options.Events:Dispatch(set,fontEvent(kind,included),true)
	end
	local function beginCycle()
		if status=="loading"then return end;status="loading"
		if not readyPending then ready,readyResolve=options.CreatePromise();readyPending=true end
		task(function()emit("loading")end)
	end
	local function finishCycle()
		if not readyPending or next(loading)or hostPending>0 then return end
		if options.IsLayoutPending and options.IsLayoutPending()then return end
		if readyPending then readyPending=false;readyResolve({set})end
		if status~="loading"then return end
		-- Resolve ready when switching to loaded. The separate font event task
		-- follows its promise checkpoint, rather than settling ready in that task.
		status="loaded";local success,bad=table.clone(loaded),table.clone(failed);table.clear(loaded);table.clear(failed)
		task(function()emit("loadingdone",success);if #bad>0 then emit("loadingerror",bad)end end)
	end
	local function addLoading(face)
		if loading[face]then return end;loading[face]=true;beginCycle()
	end
	local function finish(face,ok,value)
		local state=faces[face];if not api.Alive or not state or state.Status~="loading"then return end
		state.Cancel=nil;state.Status=if ok then"loaded"else"error";state.Error=if ok then nil else exception("NetworkError",tostring(value or"Font resource unavailable"))
		local settle=if ok then state.Resolve else state.Reject;settle({if ok then face else state.Error})
		if loading[face]then loading[face]=nil;table.insert(if ok then loaded else failed,face)end
		if ok and members[face]and options.FontChanged then options.FontChanged(state)end
		finishCycle()
	end
	local function loadFace(face)
		local state=brand(face);if state.Status~="unloaded"then return state.Loaded end
		state.Status="loading";if members[face]then addLoading(face)end
		local done=false
		local function complete(ok,result)if done or not api.Alive then return end;done=true;task(function()finish(face,ok,result)end)end
		if not options.LoadFont then complete(false,"No native font resource adapter")
		else local ok,cancel=pcall(options.LoadFont,{Family=state.Family,Source=state.Source,Descriptors=table.clone(state.Descriptors)},complete)
			if not ok then complete(false,cancel)elseif not done and type(cancel)=="function"then state.Cancel=cancel end
		end
		return state.Loaded
	end
	local function create(args)
		if #args<2 then fail("TypeError","FontFace requires family and source")end
		local face=vm.Object({},faceProto);local data=type(args[2])=="table"and args[2].BinaryState
		if data and(data.Detached or data.Buffer and data.Buffer.BinaryState.Detached)then fail("TypeError","Detached font BufferSource")end
		local source=if data then args[2]else text(args[2])
		local loadedPromise,resolve,reject=options.CreatePromise();local state={Face=face,Family=text(args[1]),Source=source,Descriptors=table.clone(defaults),Status="unloaded",Loaded=loadedPromise,Resolve=resolve,Reject=reject}
		face.FontFaceState=state;faces[face]=state
		local valid=family(state.Family)~=nil;local dictionary=args[3]
		if dictionary~=nil and dictionary~=U and dictionary~=N then
			for key in defaults do local value=vm.Get(dictionary,key);if value~=U then value=text(value);state.Descriptors[key]=value;valid=valid and descriptor(key,value)end end
		end
		if type(source)=="string"then
			local cursor=1;local count=0;while cursor<=#source do
				local part,nextCursor=Syntax.scan(source,cursor,",");cursor=nextCursor;part=trim(part);count+=1
				if not part:match("^local%s*%b()%s*$")and not part:match("^url%s*%b()%s*[a-zA-Z%(%)\"'%w%s,%-]*$")then valid=false end
			end;valid=valid and count>0
		end
		if not valid then state.Status="error";state.Error=exception("SyntaxError","Invalid FontFace family, source or descriptor");reject({state.Error})
		elseif type(source)~="string"then loadFace(face)end
		return face
	end
	local constructor=native("FontFace",2,function()fail("TypeError","FontFace requires new")end);constructor.Construct=create
	define(constructor,"prototype",{value=faceProto});define(faceProto,"constructor",{value=constructor,writable=true,configurable=true});define(faceProto,vm.SymbolToStringTag,{value="FontFace",configurable=true});globals.FontFace=constructor;vm.Global.Bindings.FontFace={Value=constructor}
	accessor(faceProto,"family",function(self)return brand(self).Family end,function(self,value)value=text(value);if not family(value)then fail("SyntaxError","Invalid font family")end;brand(self).Family=value end)
	for key in defaults do accessor(faceProto,key,function(self)return brand(self).Descriptors[key]end,function(self,value)value=text(value);if not descriptor(key,value)then fail("SyntaxError","Invalid font descriptor")end;brand(self).Descriptors[key]=value end)end
	accessor(faceProto,"status",function(self)return brand(self).Status end);accessor(faceProto,"loaded",function(self)return brand(self).Loaded end)
	method(faceProto,"load",0,function(_,self)return loadFace(self)end)
	options.Events:WrapTarget(set,{Handlers=true,HandlerNames={onloading=true,onloadingdone=true,onloadingerror=true}})
	ready,readyResolve=options.CreatePromise();finishCycle()
	local function matching(font,sample)
		local parsed=parseFont(text(font));if not parsed then fail("SyntaxError","Invalid CSS font shorthand")end
		sample=if sample==nil or sample==U then" "else text(sample);local result={}
		local wanted=if parsed.Weight=="normal"then 400 elseif parsed.Weight=="bold"then 700 else tonumber(parsed.Weight)
		local function weightScore(state)
			local weight=state.Descriptors.weight;local a,b=weight:match("^(%d+)%s+(%d+)$");a=tonumber(a or weight)or(if weight=="bold"then 700 else 400);b=tonumber(b)or a
			if wanted>=a and wanted<=b then return 0 end
			if wanted<400 then return if b<wanted then wanted-b else 2000+a-wanted
			elseif wanted>500 then return if a>wanted then a-wanted else 2000+wanted-b
			else return if a>wanted and a<=500 then a-wanted elseif b<wanted then 2000+wanted-b else 4000+a-wanted end
		end
		local function styleScore(value)
			if value==parsed.Style then return 0 end
			if parsed.Style=="normal"then return if value=="oblique"then 1 else 2 end
			return if value=="normal"then 2 else 1
		end
		for _,name in parsed.Families do
			local candidates,best={},nil
			for _,face in order do if members[face]then local state=brand(face);local actual=family(state.Family)
				if actual and actual:lower()==name then
					local covered=false;local unicode=ranges(state.Descriptors.unicodeRange)
					for point in Strings.codes(sample)do for _,r in unicode or{}do if point>=r[1]and point<=r[2]then covered=true;break end end;if covered then break end end
					if covered then local score=styleScore(state.Descriptors.style)*10000+weightScore(state)
						if best==nil or score<best then best=score;candidates={face}elseif score==best then table.insert(candidates,face)end
					end
				end
			end end
			for _,face in candidates do if not table.find(result,face)then table.insert(result,face)end end
		end
		return result
	end
	local function compact()
		if #order<memberCount*2+32 or next(iterators)then return end
		local retained={};for _,face in order do if face then table.insert(retained,face);members[face]=#retained end end;order=retained
	end
	local function forget(face)
		local index=members[face];if not index then return false end
		members[face]=nil;order[index]=false;memberCount-=1;loading[face]=nil
		for _,list in {loaded,failed}do local found=table.find(list,face);if found then table.remove(list,found)end end
		return true
	end
	method(setProto,"add",1,function(args,self)brandSet(self);local face=args[1];local state=brand(face);if not members[face]then compact();table.insert(order,face);members[face]=#order;memberCount+=1;if state.Status=="loading"then addLoading(face)end;if state.Status=="loaded"and options.FontChanged then options.FontChanged(state)end end;return set end)
	method(setProto,"delete",1,function(args,self)brandSet(self);local face=args[1];brand(face);local found=forget(face);if found then if options.FontChanged then options.FontChanged()end;finishCycle();compact()end;return found end)
	method(setProto,"clear",0,function(_,self)brandSet(self);for _,face in order do if face then forget(face)end end;if options.FontChanged then options.FontChanged()end;finishCycle();compact();return U end)
	method(setProto,"has",1,function(args,self)brandSet(self);brand(args[1]);return members[args[1]]~=nil end)
	method(setProto,"check",1,function(args,self)brandSet(self);if #args<1 then fail("TypeError","FontFaceSet.check requires a font")end;for _,face in matching(args[1],args[2])do if brand(face).Status~="loaded"then return false end end;return true end)
	method(setProto,"load",1,function(args,self)
		brandSet(self);local promise,resolve,reject=options.CreatePromise();local ok,result=pcall(function()if #args<1 then fail("TypeError","FontFaceSet.load requires a font")end;return matching(args[1],args[2])end)
		if not ok then reject({VM.exceptionValue(result)});return promise end
		local remaining=#result;if remaining==0 then resolve({vm.Array({})});return promise end
		for _,face in result do options.Await(loadFace(face),function()remaining-=1;if remaining==0 then resolve({vm.Array(result)})end end,function(reason)reject({reason})end)end
		return promise
	end)
	local function iterator(kind)
		local index=0;local result=vm.Object({});local done=false
		iterators[result]=true
		result.Values.next=native("next",0,function()
			if done then return vm.Object({done=true,value=U})end
			while index<#order do index+=1;local face=order[index];vm.Step();if face then return vm.Object({done=false,value=if kind=="entries"then vm.Array({face,face})else face})end end
			done=true;iterators[result]=nil;compact();return vm.Object({done=true,value=U})
		end)
		result.Values[vm.SymbolIterator]=native("[Symbol.iterator]",0,function()return result end);return result
	end
	for _,key in {"values","keys","entries"}do method(setProto,key,0,function(_,self)brandSet(self);return iterator(key)end)end
	define(setProto,vm.SymbolIterator,{value=vm.Get(setProto,"values"),writable=true,configurable=true})
	method(setProto,"forEach",1,function(args,self)
		brandSet(self);if not VM.callable(args[1])then fail("TypeError","FontFaceSet.forEach requires a callback")end
		local cursor={};iterators[cursor]=true;local ok,message=pcall(function()local index=1;while index<=#order do local face=order[index];index+=1;if face then vm:Call(args[1],{face,face,set},args[2])end;vm.Step()end end)
		iterators[cursor]=nil;compact();if not ok then error(message,0)end;return U
	end)
	accessor(setProto,"size",function(self)brandSet(self);return memberCount end);accessor(setProto,"status",function(self)brandSet(self);return status end);accessor(setProto,"ready",function(self)brandSet(self);return ready end)
	define(setProto,vm.SymbolToStringTag,{value="FontFaceSet",configurable=true})
	local setCtor=native("FontFaceSet",1,function()fail("TypeError","FontFaceSet is not constructible in this host")end);define(setCtor,"prototype",{value=setProto});define(setProto,"constructor",{value=setCtor,writable=true,configurable=true});globals.FontFaceSet=setCtor;vm.Global.Bindings.FontFaceSet={Value=setCtor}
	api.Set=set
	function api:BeginHostLoad()if not self.Alive then return end;hostPending+=1;beginCycle()end
	function api:EndHostLoad()if not self.Alive then return end;hostPending=math.max(0,hostPending-1);finishCycle()end
	function api:NeedsEnvironmentCheck(): boolean
		-- Resource callbacks release their own dependencies. Only a pending
		-- ready promise whose remaining layout/document gate can now open needs
		-- a boundary task; loaded sets must leave an idle realm idle.
		return self.Alive and readyPending and hostPending==0 and next(loading)==nil
			and not(options.IsLayoutPending and options.IsLayoutPending())
	end
	function api:AfterLayout()if self.Alive then finishCycle()end end
	function api:EnvironmentChanged()if self.Alive then finishCycle()end end
	function api:RegisterFace(descriptorRecord)
		local face=create({descriptorRecord.Family,descriptorRecord.Source,vm.Object(descriptorRecord.Descriptors or{})});vm:Call(vm.Get(set,"add"),{face},set);return face
	end
	function api:Destroy()if not self.Alive then return end;self.Alive=false;for _,state in faces do if state.Cancel then pcall(state.Cancel)end end;table.clear(faces);table.clear(fontEvents);table.clear(iterators);table.clear(members);table.clear(order);table.clear(loading);table.clear(loaded);table.clear(failed)end
	local previous=options.Host.ElementGet;options.Host.ElementGet=function(node,key)if node==options.Document and key=="fonts"then return set end;return if previous then previous(node,key)else nil end
	local previousSet=options.Host.ElementSet;options.Host.ElementSet=function(node,key,value,strict)if node==options.Document and key=="fonts"then if strict~=false then fail("TypeError","document.fonts is read-only")end;return true end;return previousSet and previousSet(node,key,value,strict)==true end
	for _,record in options.FontFaces or{}do api:RegisterFace(record)end
	return api
end
return FontLoading


