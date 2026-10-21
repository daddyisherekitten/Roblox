--!strict
-- BUILD-ONLY DOM IMG request owner for pages without a JavaScript Runtime.
-- Native visual readiness and optional dimensions remain separate consumers.
local Names=require(script.Parent.Parent.DOM.ElementNames)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Responsive=require(script.Parent.Parent.HTML.ResponsiveSources)
local DocumentInfo=require(script.Parent.Parent.HTML.DocumentInfo)
local URLRecord=require(script.Parent.Parent.JavaScript.URLRecord)
local Strings=require(script.Parent.Parent.JavaScript.Strings)
local Work=require(script.Parent.Parent.WorkContext)
local NativeImageResources={}

local function snapshot(node)
	local a=node.Attributes
	local result={Src=a.src,Srcset=a.srcset,Sizes=a.sizes,Loading=a.loading,Width=a.width,Height=a.height,Parent=node.Parent,Sources={}}
	if Names.html(node.Parent,"picture")then
		for _,child in node.Parent.Children do
			if child==node then break end
			if Names.html(child,"source")then
				local s=child.Attributes
				table.insert(result.Sources,{Node=child,Srcset=s.srcset,Sizes=s.sizes,Media=s.media,Type=s.type,Width=s.width,Height=s.height})
			end
		end
	end
	return result
end
local function same(a,b)
	if not a or a.Src~=b.Src or a.Srcset~=b.Srcset or a.Sizes~=b.Sizes or a.Loading~=b.Loading or a.Width~=b.Width or a.Height~=b.Height or a.Parent~=b.Parent or #a.Sources~=#b.Sources then return false end
	for i,s in a.Sources do
		local t=b.Sources[i]
		if s.Node~=t.Node or s.Srcset~=t.Srcset or s.Sizes~=t.Sizes or s.Media~=t.Media or s.Type~=t.Type or s.Width~=t.Width or s.Height~=t.Height then return false end
	end
	return true
end

function NativeImageResources.new(page,services)
	services=services or{}
	local lease={Alive=true,Page=page,Task=services.Task or task,Started=false,Running=false,Wake=false,
		Records={},Queue={Head=1,Tail=0},Queued={},Discoveries={},Changed=services.Changed,Emit=services.Emit,GetViewport=services.GetViewport,
		LoadImage=services.LoadImage,DeferImage=services.DeferImage,ImageIsRendered=services.ImageIsRendered,ScriptingEnabled=services.ScriptingEnabled~=false}
	page=nil;services=nil
	local api={Alive=true,Pending=0,DiscoveryDepth=0,Stats={Visits=0,Selections=0,Requests=0}}
	local drain,wake,refresh,visit
	local function live()
		return lease.Alive and lease.Page~=nil and lease.Page.Alive and lease.Page.JavaScriptRuntime==nil
	end
	local function current(r,generation)
		return live()and r.Node~=nil and lease.Records[r.Node]==r and r.Generation==generation
	end
	local function notify()
		local owner=lease.Page
		if live()and owner.DocumentResourcesChanged then owner:DocumentResourcesChanged()end
	end
	local function reserve(r)
		if lease.ScriptingEnabled and r.Node and(r.Node.Attributes.loading or''):lower()=='lazy'then return end
		if not r.Pending then r.Pending=true;api.Pending+=1 end
	end
	local function release(r)
		if r.Pending then r.Pending=false;api.Pending-=1 end
	end
	local function cancel(r)
		local fn=r.Cancel;r.Cancel=nil
		if fn then fn()end
	end
	local function has()return lease.Queue.Head<=lease.Queue.Tail end
	local function enqueue(callback)
		if not live()then return end
		local entry={Callback=callback};lease.Queued[entry]=true
		local q=lease.Queue;q.Tail+=1;q[q.Tail]=entry
		wake()
	end
	wake=function()
		if not live()or not lease.Started or lease.Running or lease.Wake then return end
		lease.Wake=true
		local ok,message=pcall(lease.Task.defer,function()
			lease.Wake=false
			if live()then drain()end
		end)
		if not ok then pcall(api.Destroy,api);error(message,0)end
	end
	drain=function()
		if not live()or lease.Running then return end
		lease.Running=true
		local ok,message=pcall(Work.runFor,lease.Page,function()
			if not has()then return end
			Work.checkpoint();if not live()then return end
			local q=lease.Queue;local index=q.Head;local entry=q[index];q[index]=nil;q.Head+=1
			if not has()then q.Head=1;q.Tail=0 end
			lease.Queued[entry]=nil;local callback=entry.Callback;entry.Callback=nil
			if callback then callback()end
		end)
		lease.Running=false
		if not ok then
			if not lease.Alive and Work.isCancelled(message)then return end
			pcall(api.Destroy,api);error(message,0)
		end
		if live()and has()then wake()end
	end
	local function terminal(r,generation,success,data,kind)
		if not current(r,generation)then return end
		r.Cancel=nil
		local w,h=if type(data)=="table"then data.Width else nil,if type(data)=="table"then data.Height else nil
		if kind~=nil then success=success and type(w)=="number"and type(h)=="number"and w>=0 and h>=0 and w<math.huge and h<math.huge end
		r.Status=if kind==nil then"empty"elseif success then"loaded"else"error"
		r.PixelWidth,r.PixelHeight=if success then w or 0 else 0,if success then h or 0 else 0
		r.Width,r.Height=Responsive.intrinsicSize(r.PixelWidth,r.PixelHeight,r.SourceDensity)
		local result=if success then table.clone(data or{})else nil
		if result then result.Width,result.Height=r.Width,r.Height end
		r.Current=r.URL or""
		if lease.Changed then lease.Changed(r.Node,success,result)end
		if not current(r,generation)then return end
		if kind~=nil then
			local event=if success then"load"else"error"
			if lease.Emit then lease.Emit(r.Node,event)
			elseif lease.Page.Events then lease.Page.Events:Emit(r.Node,event,{}, {Bubbles=false,Cancelable=false})end
		end
		if not current(r,generation)then return end
		-- The terminal node task owns the delay through publication/dispatch.
		release(r);notify()
	end
	local function choice(r,generation)
		if not current(r,generation)then return nil end
		local node,owner=r.Node,lease.Page
		local viewport=lease.GetViewport and lease.GetViewport()or{Width=owner.Root.AbsoluteSize.X,Height=owner.Root.AbsoluteSize.Y,Density=1}
		if not current(r,generation)then return end
		if Responsive.allowsAuto(node)and lease.ImageIsRendered then
			local size=lease.ImageIsRendered(node)
			if not current(r,generation)then return end
			if size then Responsive.publishAutoSize(node,size.Width)end
		end
		local raw,density,dimensionSource=Responsive.forImage(node,math.max(1,viewport.Width or 1024),Responsive.deviceDensity(viewport),viewport)
		if not current(r,generation)then return nil end
		return raw,density,dimensionSource
	end
	local function select(r,generation)
		if not current(r,generation)then return end
		api.Stats.Selections+=1
		local raw,density,dimensionSource=choice(r,generation)
		if raw==nil or not current(r,generation)then return end
		local node,owner=r.Node,lease.Page
		r.Raw=raw;r.SourceDensity=density;r.DimensionSource=dimensionSource
		r.AttributeWidth,r.AttributeHeight=dimensionSource.Attributes.width,dimensionSource.Attributes.height;r.URL=""
		if raw==""then
			-- A null source still queues error when src is present or the IMG
			-- uses srcset/picture. Ordinary missing src has no terminal event.
			local empty=node.Attributes.src~=nil or node.Attributes.srcset~=nil or Names.html(node.Parent,"picture")
			enqueue(function()terminal(r,generation,false,nil,if empty then"error"else nil)end);return
		end
		local document=node.OwnerDocument or owner.Document
		local address=if document==owner.Document then owner.DocumentURL else document.URL
		local base=DocumentInfo.baseURL(document,address,true)
		if not current(r,generation)then return end
		local input=Strings.usv(raw)
		local scheme=base and base:match("^[%a][%w+%.%-]*:")
		local ok,url
		if not scheme and not input:match("^[%a][%w+%.%-]*:")then
			url=DocumentInfo.resolveURL(base or"/",input);ok=true
		else ok,url=pcall(URLRecord.resolve,input,if scheme then Strings.usv(base)else nil,Work.checkpoint)end
		if not current(r,generation)then return end
		if not ok then enqueue(function()terminal(r,generation,false,nil,"error")end);return end
		r.URL=url;r.Status="loading"
		local completed=false
		local function complete(success,data)
			if completed or not current(r,generation)then return end;completed=true
			enqueue(function()terminal(r,generation,success,data,"resource")end)
		end
		api.Stats.Requests+=1
		local fn=lease.LoadImage
		local cancellation=if fn then fn(url,complete,{Source=raw,Node=node})else owner.ResourceLoadHost:LoadImage(url,complete,{Source=raw,Node=node})
		if not current(r,generation)then if type(cancellation)=="function"then cancellation()end;return end
		if not completed and type(cancellation)=="function"then r.Cancel=cancellation end
	end
	refresh=function(node,force,viewportChanged)
		if not live()or not Names.html(node,"img")or not ShadowTree.Connected(node,lease.Page.Document)then return end
		local r=lease.Records[node]
		if node.ImageResourceState and node.ImageResourceState~=r then return end
		if r and lease.ScriptingEnabled and(node.Attributes.loading or''):lower()=='lazy'then release(r)end
		local next=snapshot(node)
		if r and (viewportChanged or not force and not same(r.Snapshot,next))then
			local generation=r.Generation
			local raw,density,dimensionSource=choice(r,generation)
			if raw==nil or not current(r,generation)then return end
			-- Frozen environment-change processing compares the selected source
			-- before base resolution. Fixed-density no-ops retain the request.
			if raw==""and viewportChanged then return end
			if raw~=""and r.Raw==raw and r.Status~="deferred"then
				r.Snapshot=next
				local width,height=dimensionSource.Attributes.width,dimensionSource.Attributes.height
				local dimensionChanged=r.DimensionSource~=dimensionSource or r.AttributeWidth~=width or r.AttributeHeight~=height
				r.DimensionSource,r.AttributeWidth,r.AttributeHeight=dimensionSource,width,height
				if r.SourceDensity~=density or dimensionChanged then
					r.SourceDensity=density
					local loaded=r.Status=="loaded"
					if loaded then
						r.Width,r.Height=Responsive.intrinsicSize(r.PixelWidth,r.PixelHeight,density)
					end
					if lease.Changed then lease.Changed(node,loaded,if loaded then{Width=r.Width,Height=r.Height}else nil)end
				end
				return
			end
		end
		if r and not force and same(r.Snapshot,next)then return end
		if not r then
			r={Node=node,Generation=0,Status="empty",Width=0,Height=0,Current="",URL=""}
			lease.Records[node]=r;node.ImageResourceState=r
		end
		r.Generation+=1;local generation=r.Generation;r.Snapshot=next
		-- Replacing an attempt never exposes a temporary zero contribution.
		reserve(r);cancel(r)
		if not current(r,generation)then return end
		if Responsive.allowsAuto(node)and lease.ImageIsRendered then
			local size=lease.ImageIsRendered(node)
			if not current(r,generation)then return end
			if size==false then r.Status='layout-deferred';notify();return end
		end
		if lease.ScriptingEnabled and(node.Attributes.loading or""):lower()=="lazy"then
			r.Status="deferred";release(r);notify()
			if not current(r,generation)then return end
			if not lease.DeferImage then return end
			local resumed=false
			local cancellation=lease.DeferImage(node,function()
				if not current(r,generation)then return end
				resumed=true;r.Cancel=nil;r.Status='loading'
				enqueue(function()select(r,generation)end)
			end)
			if not current(r,generation)then if type(cancellation)=='function'then cancellation()end;return end
			if resumed then return end
			if type(cancellation)=='function'then r.Cancel=cancellation;return end
		end
		r.Status="loading"
		enqueue(function()select(r,generation)end)
	end
	visit=function(root)
		if not live()then return end;api.Stats.Visits+=1
		local pending={root}
		while #pending>0 and live()do
			local node=table.remove(pending)
			if Names.html(node,"img")then refresh(node,false)end
			if not live()then break end
			if not Names.html(node,"template")then
				for i=#(node.Children or{}),1,-1 do table.insert(pending,node.Children[i])end
				if node.InternalShadowRoot then table.insert(pending,node.InternalShadowRoot)end
			end
			Work.checkpoint();if not live()then break end
		end
	end
	local function operation(fn,...)
		local result=table.pack(pcall(fn,...))
		if not result[1]then pcall(api.Destroy,api);error(result[2],0)end
		return table.unpack(result,2,result.n)
	end
	local function discover(fn,...)
		if not live()then return end
		local scan={};lease.Discoveries[scan]=true;api.DiscoveryDepth+=1
		local result=table.pack(pcall(fn,...))
		if lease.Discoveries[scan]then lease.Discoveries[scan]=nil;api.DiscoveryDepth-=1 end
		if not result[1]then pcall(api.Destroy,api);error(result[2],0)end
		if live()then operation(notify)end
		return table.unpack(result,2,result.n)
	end
	-- Discovery is a separate transaction gate, never a fabricated IMG request.
	-- A stopped no-Realm owner must not fall back to a second legacy loader.
	-- The page's visual-item caller already supplies its own DOM nodes.
	function api:Manages(node)return Names.html(node,"img")end
	function api:Owns(node)return live()and lease.Records[node]~=nil end
	function api:Visit(root)discover(visit,root)end
	function api:Refresh(node,force)operation(refresh,node,force==true)end
	function api:Start()if not live()then return end;lease.Started=true;wake()end
	function api:AttributeChanged(node,key,namespace)
		if namespace~=nil and namespace~=""or not live()then return end
		if Names.html(node,"img")and(key=="src"or key=="srcset"or key=="sizes"or key=="loading"or key=="width"or key=="height")then operation(refresh,node,key=="src")
		elseif Names.html(node,"source")and Names.html(node.Parent,"picture")and(key=="srcset"or key=="sizes"or key=="media"or key=="type"or key=="width"or key=="height")then discover(visit,node.Parent)end
	end
	function api:Mutation(change)
		if not live()or change.Type~="childList"then return end
		discover(function()
			if Names.html(change.Target,"picture")then visit(change.Target)end
			for _,node in change.AddedNodes or{}do visit(node)end
		end)
	end
	function api:ViewportChanged()
		if not live()then return end
		local nodes={};for node in lease.Records do table.insert(nodes,node)end
		for _,node in nodes do if node.Attributes.srcset~=nil or Names.html(node.Parent,"picture")then operation(refresh,node,true,true)end end
	end
	function api:AfterLayout()
		if not live()then return end
		local nodes={};for node in lease.Records do if Responsive.allowsAuto(node)then table.insert(nodes,node)end end
		for _,node in nodes do if not live()then return end;operation(refresh,node,true,true)end
	end
	function api:Destroy()
		if not lease.Alive then return end;lease.Alive=false;self.Alive=false
		for entry in lease.Queued do entry.Callback=nil end;table.clear(lease.Queued);table.clear(lease.Queue)
		table.clear(lease.Discoveries);self.DiscoveryDepth=0
		local records=lease.Records;lease.Records={};local owner=lease.Page
		local failed,first=false,nil
		for node,r in records do
			if node.ImageResourceState==r then node.ImageResourceState=nil end
			r.Generation+=1;r.Node=nil;r.Snapshot=nil;r.DimensionSource=nil;release(r)
			local ok,value=pcall(cancel,r);if not ok and not failed then failed=true;first=value end
		end
		table.clear(records);self.Pending=0
		lease.Page=nil;lease.Changed=nil;lease.Emit=nil;lease.GetViewport=nil;lease.LoadImage=nil;lease.DeferImage=nil;lease.ImageIsRendered=nil
		if owner.Alive and owner.DocumentResourcesChanged then local ok,value=pcall(owner.DocumentResourcesChanged,owner);if not ok and not failed then failed=true;first=value end end
		if failed then error(first,0)end
	end
	lease.Page.NativeImageResources=api
	lease.Page:AddCleanup(function()api:Destroy()end)
	-- Page.ScriptInitializationPending guards a yielding initial DOM census.
	discover(visit,lease.Page.Document)
	return api
end
return NativeImageResources
