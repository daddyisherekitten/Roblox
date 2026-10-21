--!strict
-- Rendering-phase resize observations and task-delivered intersections. Only
-- registered targets and their ancestor chains are measured; no DOM-wide scan.
local Borders=require(script.Parent.Parent.Layout.BorderGeometry)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local LayoutObservers={}
function LayoutObservers.install(vm: any,globals: any,options: any): any
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local geometry=assert(options.Geometry,"Layout observers require geometry")
	local api={Alive=true};local processing,requested,intersectionTask=false,false,false
	local requestGeneration,requestDue=0,math.huge
	local resize,intersections,resizeEntries,intersectionEntries,sizes={},{},{},{},{}
	for _,map in {resize,intersections,resizeEntries,intersectionEntries,sizes}do setmetatable(map,{__mode="kv"})end
	local resizeOrder,intersectionOrder=setmetatable({},{__mode="v"}),setmetatable({},{__mode="v"})
	local resizeCount,intersectionCount,observerCount,targetCount=0,0,0,0
	local retained,pending={},{}
	local resizeProto,intersectionProto,resizeEntryProto,intersectionEntryProto,sizeProto=vm.Object({}),vm.Object({}),vm.Object({}),vm.Object({}),vm.Object({})
	local function check()assert(api.Alive and vm.Alive,"Layout observers disposed")end
	local function fail(name,message)VM.throw(VM.error(name,message))end
	local function native(name,arity,action)
		local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return action(args,receiver)end}
		vm.DefineProperty(value,"name",vm.Object({value=name,configurable=true},VM.Null));vm.DefineProperty(value,"length",vm.Object({value=arity,configurable=true},VM.Null));return value
	end
	local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,VM.Null))end
	local function method(proto,key,arity,action)define(proto,key,{value=native(key,arity,action),writable=true,enumerable=true,configurable=true})end
	local function accessor(proto,key,map)
		define(proto,key,{get=native("get "..key,0,function(_,receiver)local state=map[receiver];if not state then fail("TypeError","Illegal observer receiver")end;return state[key]end),enumerable=true,configurable=true})
	end
	local function state(map,receiver)local result=map[receiver];if not result then fail("TypeError","Illegal observer receiver")end;return result end
	local function dictionary(value)
		if value==nil or value==U or value==N then return nil end
		if (type(value)~="table"and type(value)~="function")or(type(value)=="table"and value.Kind=="symbol")then fail("TypeError","Observer options must be a dictionary")end;return value
	end
	local function field(dict,key,fallback)local value=if dict then vm.Get(dict,key)else U;return if value==U then fallback else value end
	local function number(value)local result=VM.number(vm.ToPrimitive(value,"number"));if result~=result or math.abs(result)==math.huge then fail("TypeError","Expected a finite number")end;return result end
	local function text(value)
		value=vm.ToPrimitive(value,"string");if type(value)=="table"and value.Kind=="symbol"then fail("TypeError","Cannot convert Symbol to string")end
		local result=VM.string(value);if #result>65536 then fail("RangeError","Observer string budget exceeded")end;return result
	end
	local function required(args,count,name)if #args<count then fail("TypeError",name.." requires "..count.." arguments")end end
	local function node(value,documentAllowed)
		local result=options.Unwrap(value)
		if not result or(result.Kind~="Element"and not(documentAllowed and result.Kind=="Document"))then fail("TypeError","Expected an Element from this document")end;return result
	end
	local function rect(data)return geometry:Rect(data.X or 0,data.Y or 0,data.Width or 0,data.Height or 0,true)end
	local function empty()return {X=0,Y=0,Width=0,Height=0}end
	local function bounding(list)
		if #list==0 then return empty()end
		local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge;local any=false
		for _,r in list do if r.Width==0 or r.Height==0 then continue end;any=true;left=math.min(left,r.X);top=math.min(top,r.Y);right=math.max(right,r.X+r.Width);bottom=math.max(bottom,r.Y+r.Height)end
		return if any then {X=left,Y=top,Width=right-left,Height=bottom-top}else table.clone(list[1])
	end
	local function frozen(items)
		local value=vm.Array(items)
		for i,item in items do define(value,tostring(i-1),{value=item,writable=false,enumerable=true,configurable=false})end
		define(value,"length",{writable=false});vm.PreventExtensions(value);return value
	end
	local function request(delay)
		if not api.Alive then return end
		delay=delay or 0;local due=((options.Now and options.Now())or os.clock()*1000)+delay
		if requested and due>=requestDue then return end;requested=true;requestDue=due;requestGeneration+=1;local generation=requestGeneration
		local publish=function()
			if not api.Alive or generation~=requestGeneration then return end
			if options.RequestLayout then options.RequestLayout(0)
			else options.QueueTask(function()if api.Alive and generation==requestGeneration then api:AfterLayout()end end)end
		end
		if delay>0 and options.Schedule then options.Schedule(publish,delay)else publish()end
	end
	local function invoke(entry,records)
		local ok,failure=pcall(function()
			if options.Call then options.Call(entry.Callback,{vm.Array(records),entry.Value},entry.Value)else vm:Call(entry.Callback,{vm.Array(records),entry.Value},entry.Value)end
		end)
		if not ok and api.Alive and options.Report then options.Report(VM.exceptionValue(failure))end
	end
	local function view()return (options.GetViewport and options.GetViewport())or {}end
	local function tree()return options.GetTree and options.GetTree()end
	local function boxAndStyle(target)
		local t=tree();local box=t and t.NodeBoxes and t.NodeBoxes[target]
		if not box and options.GetBox then box=options.GetBox(target)end
		return box,(t and t.NodeStyles and t.NodeStyles[target])or(box and box.Style)or {}
	end
	local function depth(target)
		local count=0;while target and target.Kind~="Document"do count+=1;if count>256 then fail("RangeError","Observer ancestor budget exceeded")end;target=target.Parent end;return count
	end
	local function connected(target)
		local count=0;while target and target.Kind~="Document"do count+=1;if count>256 then fail("RangeError","Observer ancestor budget exceeded")end;target=target.Parent end;return target~=nil
	end
	local function contains(root,target)
		local count=0;target=target.Parent;while target do count+=1;if count>256 then fail("RangeError","Observer ancestor budget exceeded")end;if target==root then return true end;target=target.Parent end;return false
	end
	local REPLACED={img=true,input=true,textarea=true,select=true,button=true,canvas=true,video=true,audio=true,iframe=true,object=true,embed=true,svg=true}
	local function resizeBoxes(target)
		if options.GetResizeBoxes then local provided=options.GetResizeBoxes(target);if provided then return provided end end
		local box,s=boxAndStyle(target);local visible=connected(target)and #geometry:ClientRects(target)>0
		local padding=s.Padding or {0,0,0,0};local bt,br,bb,bl=Borders.sizes(s)
		local width=if visible and box then box.OuterWidth or box.Width or 0 else 0
		local height=if visible and box then box.OuterHeight or box.Height or 0 else 0
		local contentWidth=if visible and box then box.ContentWidth or math.max(0,width-bl-br-padding[2]-padding[4]-(box.ScrollY or 0))else 0
		local contentHeight=if visible and box then box.ContentHeight or math.max(0,height-bt-bb-padding[1]-padding[3]-(box.ScrollX or 0))else 0
		local replaced=REPLACED[ElementNames.htmlName(target)] or ElementNames.matches(target,"svg",ElementNames.SVG)
		if s.Display=="inline"and not replaced then width,height,contentWidth,contentHeight=0,0,0,0 end
		local vertical=s.WritingMode=="vertical-rl"or s.WritingMode=="vertical-lr"
		local density=view().DevicePixelRatio or 1
		local function size(w,h)return {InlineSize=if vertical then h else w,BlockSize=if vertical then w else h}end
		return {ContentRect={X=if visible then padding[4]else 0,Y=if visible then padding[1]else 0,Width=contentWidth,Height=contentHeight},
			Content=size(contentWidth,contentHeight),Border=size(width,height),Device=size(math.floor(contentWidth*density+.5),math.floor(contentHeight*density+.5))}
	end
	local function matchingSize(boxes,box)return if box=="border-box"then boxes.Border elseif box=="device-pixel-content-box"then boxes.Device else boxes.Content end
	local function sizeValue(data)
		local value=vm.Object({},sizeProto);local data={inlineSize=data.InlineSize,blockSize=data.BlockSize};value.ObserverState=data;sizes[value]=data;return value
	end
	local function resizeRecord(target,boxes)
		local value=vm.Object({},resizeEntryProto);local data={target=options.Wrap(target),contentRect=rect(boxes.ContentRect),
			contentBoxSize=frozen({sizeValue(boxes.Content)}),borderBoxSize=frozen({sizeValue(boxes.Border)}),devicePixelContentBoxSize=frozen({sizeValue(boxes.Device)})}
		value.ObserverState=data;resizeEntries[value]=data;return value
	end
	local BOXES={["content-box"]=true,["border-box"]=true,["device-pixel-content-box"]=true}
	method(resizeProto,"observe",1,function(args,receiver)
		required(args,1,"observe");local entry=state(resize,receiver);local target=node(args[1]);local d=dictionary(args[2]);local box=text(field(d,"box","content-box"))
		if not BOXES[box]then fail("TypeError","Invalid ResizeObserver box")end
		for i,observation in entry.Targets do if observation.Target==target then
			if observation.Box==box then return U end;table.remove(entry.Targets,i);targetCount-=1;break
		end end
		if targetCount>=4096 then fail("RangeError","Layout observer target budget exceeded")end;targetCount+=1
		table.insert(entry.Targets,{Target=target,Box=box,Last={InlineSize=-1,BlockSize=-1}});retained[receiver]=true;request();return U
	end)
	method(resizeProto,"unobserve",1,function(args,receiver)
		required(args,1,"unobserve");local entry=state(resize,receiver);local target=node(args[1]);for i,observation in entry.Targets do if observation.Target==target then table.remove(entry.Targets,i);targetCount-=1;break end end
		if #entry.Targets==0 then retained[receiver]=nil end;return U
	end)
	method(resizeProto,"disconnect",0,function(_,receiver)local entry=state(resize,receiver);targetCount-=#entry.Targets;entry.Targets={};entry.Active={};retained[receiver]=nil;return U end)
	local function gather(minDepth)
		local active,skipped=false,false
		for index=1,resizeCount do local value=resizeOrder[index];local entry=value and resize[value];if entry then entry.Active={}
			for _,observation in entry.Targets do
				local current=matchingSize(resizeBoxes(observation.Target),observation.Box)
				if current.InlineSize~=observation.Last.InlineSize or current.BlockSize~=observation.Last.BlockSize then
					if depth(observation.Target)>minDepth then table.insert(entry.Active,observation);active=true else skipped=true end
				end
			end
		end end;return active,skipped
	end
	local function broadcast()
		local shallowest=math.huge;local count=resizeCount
		for index=1,count do if not api.Alive then break end;local value=resizeOrder[index];local entry=value and resize[value]
			if entry and #entry.Active>0 then
				local records={};for _,observation in entry.Active do
					local boxes=resizeBoxes(observation.Target);table.insert(records,resizeRecord(observation.Target,boxes));observation.Last=table.clone(matchingSize(boxes,observation.Box));shallowest=math.min(shallowest,depth(observation.Target))
				end;entry.Active={};invoke(entry,records)
			end
		end;return shallowest
	end
	local function margin(value)
		local raw=text(value);if #raw>4096 then fail("RangeError","Observer margin budget exceeded")end
		local parts={};for token in raw:gmatch("[^ \t\r\n\f]+")do
			local numeric,unit=token:lower():match("^(.-)([a-z%%]+)$");local amount=numeric and tonumber(numeric)
			if not amount or amount~=amount or math.abs(amount)==math.huge or not numeric:match("^[-+]?%d*%.?%d+[eE]?[-+]?%d*$")or(unit~="px"and unit~="%")then fail("SyntaxError","Observer margins require px or % lengths")end
			if #parts==4 then fail("SyntaxError","Observer margin requires one to four lengths")end
			-- Chromium stores pixel root/scroll margins as integral CSS pixels.
			if unit=="px"then amount=if amount<0 then math.ceil(amount)else math.floor(amount)end
			table.insert(parts,{Value=amount,Unit=unit})
		end
		if #parts==0 then fail("SyntaxError","Observer margin requires one to four lengths")end
		local result={parts[1],parts[2]or parts[1],parts[3]or parts[1],parts[4]or parts[2]or parts[1]};local strings={}
		for _,part in result do table.insert(strings,tostring(if part.Value==0 then 0 else part.Value)..part.Unit)end;return result,table.concat(strings," ")
	end
	local function expand(r,margin)
		local values={};for i,part in margin do values[i]=if part.Unit=="%"then part.Value*r.Width/100 else part.Value end
		return {X=r.X-values[4],Y=r.Y-values[1],Width=r.Width+values[4]+values[2],Height=r.Height+values[1]+values[3]}
	end
	local function intersect(a,b,clipX,clipY)
		local left=if clipX~=false then math.max(a.X,b.X)else a.X;local top=if clipY~=false then math.max(a.Y,b.Y)else a.Y
		local right=if clipX~=false then math.min(a.X+a.Width,b.X+b.Width)else a.X+a.Width;local bottom=if clipY~=false then math.min(a.Y+a.Height,b.Y+b.Height)else a.Y+a.Height
		if right<left or bottom<top then return empty(),false end;return {X=left,Y=top,Width=right-left,Height=bottom-top},true
	end
	local function clipInfo(target)
		local _,s=boxAndStyle(target);local x=s.OverflowX or s.Overflow or "visible";local y=s.OverflowY or s.Overflow or "visible"
		local paint=s.Contain and s.Contain.Paint;return x~="visible"or paint or s.ClipPath~=nil,y~="visible"or paint or s.ClipPath~=nil,x~="visible"and x~="clip"or y~="visible"and y~="clip"
	end
	local function paddingRect(target)
		local r=bounding(geometry:ClientRects(target));local m=geometry:Metrics(target)
		return {X=r.X+(m.clientLeft or 0),Y=r.Y+(m.clientTop or 0),Width=m.clientWidth or 0,Height=m.clientHeight or 0}
	end
	local function rootRect(entry)
		local root=entry.Root;local r;local scrolling=true
		if not root or root.Kind=="Document"then local viewport=view();r={X=0,Y=0,Width=viewport.ClientWidth or viewport.Width or 0,Height=viewport.ClientHeight or viewport.Height or 0}
		else local x,y; x,y,scrolling=clipInfo(root);r=if x or y then paddingRect(root)else bounding(geometry:ClientRects(root))end
		if scrolling then r=expand(r,entry.ScrollMargin)end;return expand(r,entry.RootMargin)
	end
	local function intersectionData(entry,target)
		local root=entry.Root;local bounds=rootRect(entry);local targetRect,intersection=empty(),empty();local intersecting=false
		if connected(target)and(not root or root.Kind=="Document"or contains(root,target))and(not root or connected(root))then
			local list=geometry:ClientRects(target);targetRect=bounding(list)
			if #list>0 then
				intersection=table.clone(targetRect);intersecting=true
				local provided=options.GetIntersectionClips and options.GetIntersectionClips(target,root)
				if provided then
					if provided.Allowed==false then intersecting=false;intersection=empty()else
						for _,clip in provided do local r=if clip.Scroll then expand(clip.Rect,entry.ScrollMargin)else clip.Rect;local touched;intersection,touched=intersect(intersection,r,clip.X,clip.Y);intersecting=intersecting and touched end
					end
				else
					-- Ordinary ancestor overflow/paint clips are exact for untransformed
					-- rectangles. Native clip-paths and transformed padding require the
					-- adapter's containing-block clip-chain hook for exact geometry.
					local ancestor=target.Parent;local level=0
					while ancestor and ancestor~=root and ancestor.Kind~="Document"do
						level+=1;if level>256 then fail("RangeError","Observer clip budget exceeded")end
						local x,y,scrolling=clipInfo(ancestor)
						if x or y then local r=paddingRect(ancestor);if scrolling then r=expand(r,entry.ScrollMargin)end;local touched;intersection,touched=intersect(intersection,r,x,y);intersecting=intersecting and touched end
						ancestor=ancestor.Parent
					end
				end
				local touched;intersection,touched=intersect(intersection,bounds);intersecting=intersecting and touched
				if not intersecting then intersection=empty()end
			end
		end
		local area=targetRect.Width*targetRect.Height;local ratio=if area~=0 then math.clamp(intersection.Width*intersection.Height/area,0,1)elseif intersecting then 1 else 0
		local visible=entry.trackVisibility and options.GetVisibility and options.GetVisibility(target,root)==true or false
		return bounds,targetRect,intersection,intersecting,ratio,visible
	end
	local function intersectionRecord(data)
		local value=vm.Object({},intersectionEntryProto);value.ObserverState=data;intersectionEntries[value]=data;return value
	end
	local function deliverIntersections()
		if not api.Alive then return end;intersectionTask=false;local count=intersectionCount
		for index=1,count do if not api.Alive then break end;local value=intersectionOrder[index];local entry=value and intersections[value]
			if entry and #entry.Queue>0 then local records=entry.Queue;entry.Queue={};pending[value]=nil;invoke(entry,records)end
		end
	end
	local function queueIntersection(entry,record)
		if #entry.Queue>=16384 then fail("RangeError","IntersectionObserver record budget exceeded")end
		table.insert(entry.Queue,record);pending[entry.Value]=true
		if not intersectionTask then intersectionTask=true;options.QueueTask(deliverIntersections)end
	end
	local function updateIntersections(time)
		for index=1,intersectionCount do local value=intersectionOrder[index];local entry=value and intersections[value]
			if entry then for _,observation in entry.Targets do
				if observation.LastTime and time-observation.LastTime<entry.delay then request(entry.delay-(time-observation.LastTime));continue end
				observation.LastTime=time
				local bounds,targetRect,intersection,intersecting,ratio,visible=intersectionData(entry,observation.Target)
				local thresholdIndex=#entry.Thresholds;for i,threshold in entry.Thresholds do if threshold>ratio then thresholdIndex=i-1;break end end
				if thresholdIndex~=observation.LastThreshold or intersecting~=observation.LastIntersecting or visible~=observation.LastVisible then
					queueIntersection(entry,intersectionRecord({time=time,target=options.Wrap(observation.Target),rootBounds=rect(bounds),boundingClientRect=rect(targetRect),intersectionRect=rect(intersection),isIntersecting=intersecting,intersectionRatio=ratio,isVisible=visible}))
				end
				observation.LastThreshold,observation.LastIntersecting,observation.LastVisible=thresholdIndex,intersecting,visible
			end end
		end
	end
	method(intersectionProto,"observe",1,function(args,receiver)
		required(args,1,"observe");local entry=state(intersections,receiver);local target=node(args[1]);for _,observation in entry.Targets do if observation.Target==target then return U end end
		if targetCount>=4096 then fail("RangeError","Layout observer target budget exceeded")end;targetCount+=1
		table.insert(entry.Targets,{Target=target,LastThreshold=-1,LastIntersecting=false,LastVisible=false});retained[receiver]=true;request();return U
	end)
	method(intersectionProto,"unobserve",1,function(args,receiver)
		required(args,1,"unobserve");local entry=state(intersections,receiver);local target=node(args[1]);for i,observation in entry.Targets do if observation.Target==target then table.remove(entry.Targets,i);targetCount-=1;break end end
		if #entry.Targets==0 then retained[receiver]=nil end;return U
	end)
	method(intersectionProto,"disconnect",0,function(_,receiver)local entry=state(intersections,receiver);targetCount-=#entry.Targets;entry.Targets={};retained[receiver]=nil;return U end)
	method(intersectionProto,"takeRecords",0,function(_,receiver)local entry=state(intersections,receiver);local records=entry.Queue;entry.Queue={};pending[receiver]=nil;return vm.Array(records)end)
	local function constructor(name,arity,proto,create)
		local value=native(name,arity,function()fail("TypeError",name.." requires new")end);value.Construct=function(args)check();return create(args)end
		define(value,"prototype",{value=proto});define(proto,"constructor",{value=value,writable=true,configurable=true});globals[name]=value;vm.Global.Bindings[name]={Value=value};return value
	end
	local function allocate()if observerCount>=1024 then fail("RangeError","Layout observer allocation budget exceeded")end;observerCount+=1 end
	constructor("ResizeObserver",1,resizeProto,function(args)
		if not VM.callable(args[1])then fail("TypeError","ResizeObserver callback must be callable")end;allocate()
		local value=vm.Object({},resizeProto);local entry={Value=value,Callback=args[1],Targets={},Active={}};value.ObserverState=entry;resize[value]=entry;resizeCount+=1;resizeOrder[resizeCount]=value;return value
	end)
	constructor("IntersectionObserver",1,intersectionProto,function(args)
		if not VM.callable(args[1])then fail("TypeError","IntersectionObserver callback must be callable")end;local d=dictionary(args[2]);local init={}
		-- Dictionary members are read in Web IDL's lexical order, before algorithm validation.
		local rawDelay=field(d,"delay",0);local delay=VM.number(vm.ToPrimitive(rawDelay,"number"));delay=if delay~=delay or math.abs(delay)==math.huge or delay==0 then 0 else (if delay<0 then math.ceil(delay)else math.floor(delay))%4294967296
		if delay>=2147483648 then delay-=4294967296 end
		local rawRoot=field(d,"root",N);init.Root=if rawRoot==N then nil else node(rawRoot,true);init.root=if init.Root then options.Wrap(init.Root)else N
		local rootMargin=text(field(d,"rootMargin","0px"));local scrollMargin=text(field(d,"scrollMargin","0px"))
		local thresholds={};local supplied=field(d,"threshold",0)
		if type(supplied)=="table"and supplied~=N and supplied~=U and supplied.Kind~="symbol"then
			local nextValue,close=vm.Iterator(supplied);local ok,failure=pcall(function()while true do local exists,item=nextValue();if not exists then break end;if #thresholds>=4096 then fail("RangeError","IntersectionObserver threshold budget exceeded")end;table.insert(thresholds,number(item))end end)
			if not ok then if close then pcall(close)end;error(failure,0)end
		else table.insert(thresholds,number(supplied))end
		init.trackVisibility=VM.truth(field(d,"trackVisibility",false))
		init.RootMargin,init.rootMargin=margin(rootMargin);init.ScrollMargin,init.scrollMargin=margin(scrollMargin)
		for _,threshold in thresholds do if threshold<0 or threshold>1 then fail("RangeError","IntersectionObserver thresholds must be between zero and one")end end
		table.sort(thresholds);if #thresholds==0 then table.insert(thresholds,0)end
		init.Thresholds=thresholds;init.thresholds=frozen(thresholds);init.delay=if init.trackVisibility then math.max(100,delay)else delay
		allocate();local value=vm.Object({},intersectionProto);init.Value,init.Callback,init.Targets,init.Queue=value,args[1],{},{};value.ObserverState=init;intersections[value]=init;intersectionCount+=1;intersectionOrder[intersectionCount]=value;return value
	end)
	constructor("ResizeObserverEntry",0,resizeEntryProto,function()fail("TypeError","Illegal ResizeObserverEntry constructor")end)
	constructor("ResizeObserverSize",0,sizeProto,function()fail("TypeError","Illegal ResizeObserverSize constructor")end)
	local function rectInit(value)
		local d=dictionary(value);local r={};for _,key in {"height","width","x","y"}do r[key]=VM.number(vm.ToPrimitive(field(d,key,0),"number"))end;return geometry:Rect(r.x,r.y,r.width,r.height,true)
	end
	constructor("IntersectionObserverEntry",1,intersectionEntryProto,function(args)
		required(args,1,"IntersectionObserverEntry");local d=dictionary(args[1]);local raw={}
		for _,key in {"boundingClientRect","intersectionRatio","intersectionRect","isIntersecting","isVisible","rootBounds","target","time"}do
			local value=field(d,key,U);if value==U and key~="isVisible"then fail("TypeError","IntersectionObserverEntry requires "..key)end;raw[key]=value
		end
		return intersectionRecord({boundingClientRect=rectInit(raw.boundingClientRect),intersectionRatio=number(raw.intersectionRatio),intersectionRect=rectInit(raw.intersectionRect),isIntersecting=VM.truth(raw.isIntersecting),isVisible=VM.truth(raw.isVisible),rootBounds=if raw.rootBounds==N then N else rectInit(raw.rootBounds),target=options.Wrap(node(raw.target)),time=number(raw.time)})
	end)
	for _,key in {"target","contentRect","contentBoxSize","borderBoxSize","devicePixelContentBoxSize"}do accessor(resizeEntryProto,key,resizeEntries)end
	for _,key in {"inlineSize","blockSize"}do accessor(sizeProto,key,sizes)end
	for _,key in {"root","rootMargin","scrollMargin","thresholds","delay","trackVisibility"}do accessor(intersectionProto,key,intersections)end
	for _,key in {"time","target","rootBounds","boundingClientRect","intersectionRect","isIntersecting","intersectionRatio","isVisible"}do accessor(intersectionEntryProto,key,intersectionEntries)end
	for _,pair in {{resizeProto,"ResizeObserver"},{intersectionProto,"IntersectionObserver"},{resizeEntryProto,"ResizeObserverEntry"},{intersectionEntryProto,"IntersectionObserverEntry"},{sizeProto,"ResizeObserverSize"}}do if vm.SymbolToStringTag then define(pair[1],vm.SymbolToStringTag,{value=pair[2],configurable=true})end end
	function api:AfterLayout(time)
		check();if processing then return end;processing=true;requested=false;requestDue=math.huge;requestGeneration+=1
		local ok,failure=pcall(function()
			geometry:Flush();local minDepth=0;local active,skipped=gather(minDepth);local rounds=0
			while active and api.Alive do rounds+=1;if rounds>256 then fail("RangeError","ResizeObserver delivery budget exceeded")end
				minDepth=broadcast();if not api.Alive then return end;geometry:Flush();active,skipped=gather(minDepth)
			end
			if skipped and api.Alive then
				local message="ResizeObserver loop completed with undelivered notifications."
				if options.ReportResizeLoopError then options.ReportResizeLoopError(message)elseif options.Report then options.Report(VM.error("Error",message))end;request()
			end
			if api.Alive then updateIntersections(time or (options.Now and options.Now())or os.clock()*1000)end
		end);processing=false
		if not ok then error(failure,0)end
	end
	function api:ScrollChanged()check();request()end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false
		for _,map in {resize,intersections}do for _,entry in map do entry.Callback=nil;entry.Targets={};entry.Active={};entry.Queue={}end end
		for _,map in {resize,intersections,resizeEntries,intersectionEntries,sizes,resizeOrder,intersectionOrder,retained,pending}do table.clear(map)end
	end
	return api
end
return LayoutObservers
