--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- Linked stylesheet requests belong to DOM owners, not transient render boxes.
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Media=require(script.Parent.Parent.CSS.MediaQueries)
local Graph=require(script.Parent.StylesheetGraph)
local URL=require(script.Parent.Parent.Navigation.URL)
local Sheet=require(script.Parent.Parent.CSS.Stylesheet)
local Work=require(script.Parent.Parent.WorkContext)
local Resources={}
function Resources.install(vm: any,globals: any,options: any): any
	local api={Alive=true,Pending=0};local document=options.Document
	local records=setmetatable({},{__mode='kv'});local active={};local importJobs=setmetatable({},{__mode='kv'})
	local function owner(node)
		return ElementNames.html(node,'link')or ElementNames.style(node)
	end
	local function connected(node)return ShadowTree.Connected(node,document)end
	local function root(node)while node.Parent do node=node.Parent end;return node end
	local function relations(node)
		local sheet,alternate=false,false
		for value in (node.Attributes.rel or ''):lower():gmatch('[^ \t\r\n\f]+')do
			if value=='stylesheet'then sheet=true elseif value=='alternate'then alternate=true end
		end
		return sheet,alternate
	end
	local function notify()if options.LoadStateChanged then options.LoadStateChanged()end end
	local function recount()
		local count=0;for record in active do if connected(record.Node)then count+=1 end end
		api.Pending=count;notify()
	end
	local function queue(fn)options.QueueTask(function()if api.Alive then fn()end end)end
	local function cancel(record)
		record.Generation+=1
		if record.Cancel then pcall(record.Cancel);record.Cancel=nil end
		active[record]=nil
	end
	local function changed(node)
		if options.Changed then options.Changed(node)end
	end
	local function ready(record,generation,ok)
		record.GraphReady=true;local event={Kind=if ok then'load'else'error'};record.QueuedEvent=event
		queue(function()
			if record.Generation~=generation or record.Status~='loading'then
				if event.Detached then options.Emit(record.Node,event.Kind)end;return
			end
			record.Cancel=nil;record.QueuedEvent=nil;record.Status=if ok then'loaded'else'error'
			options.Emit(record.Node,event.Kind);active[record]=nil;recount()
		end)
	end
	local function cancelOwner(node)
		for job in active do if job.Node==node then
			if job.GraphReady and job.QueuedEvent and not connected(node)then job.QueuedEvent.Detached=true end
			cancel(job)
		end end
	end
	local refresh
	refresh=function(node,force)
		if not owner(node)then return end
		local inline=ElementNames.style(node)
		local record=records[node]
		if not record then
			record={Node=node,Generation=0,Status='empty',Key=nil,Source=nil};records[node]=record
			node.StylesheetResourceState=record
			local sheet,alternate=relations(node)
			local env=if options.Environment then options.Environment()else {Width=1024,Height=768}
			record.ParserBlocking=node.StylesheetParserInserted==true and root(node)==document and(inline or sheet and not alternate)
				and(inline or node.Attributes.disabled==nil)and Media.matches(Media.compile(node.Attributes.media or ''),env)
		end
		local sheet,alternate=relations(node);local attrs=node.Attributes
		local enabled=connected(node)and(inline or sheet and attrs.disabled==nil and(not alternate or (attrs.title or '')==''))
		local kind=(attrs.type or ''):lower();if kind~=''and kind~='text/css'then enabled=false end
		local source=attrs.href or '';local url='';local base=if options.GetBaseURL then options.GetBaseURL()else options.URL or 'about:blank'
		if inline then source=Sheet.styleText(node);url=base
		elseif enabled and source~=''then
			local ok,value=pcall(function()return vm.Get(vm:Construct(globals.URL,{source,base}),'href')end)
			if ok then url=value end
		end
		local key=if enabled then url else nil
		if not force and record.Key==key and record.Raw==source then return end
		cancelOwner(node);cancel(record);record.Key,record.Raw,record.URL=key,source,url
		record.Source,record.ResponseURL,record.OriginClean,record.Imports=nil,nil,true,{};record.Status='empty';record.GraphReady=false;changed(node)
		if not enabled or not inline and(source==''or url=='')then recount();return end
		record.Status='loading';active[record]=true;local generation=record.Generation;recount()
		record.Cancel=Graph.start(record,{
			Valid=function()return api.Alive and record.Generation==generation and record.Status=='loading'end,
			Sources=options.Sources,Inline=if inline then source else nil,Load=options.LoadStylesheet,QueueTask=queue,
			Changed=function()changed(node)end,
			Ready=function(ok)ready(record,generation,ok)end,
		})
	end
	local function walk(nodes,force)
		local pending={};for _,node in nodes or {}do table.insert(pending,node)end
		while #pending>0 do
			Work.checkpoint();local node=table.remove(pending)
			refresh(node,force and ElementNames.style(node))
			for _,child in node.Children or {}do table.insert(pending,child)end
			if node.InternalShadowRoot then table.insert(pending,node.InternalShadowRoot)end
		end
	end
	function api:HasBlockingScripts(): boolean
		for record in active do
			if record.Status=='loading'and not record.GraphReady and record.ParserBlocking and root(record.Node)==document then return true end
		end
		return false
	end
	function api:InsertImport(parent,imported,index,node)
		local base=parent.ResponseURL or parent.URL or options.URL or 'about:blank'
		local resource={URL=URL.resolve(base,imported.Href).URL,Href=imported.Href,Layer=imported.Layer,Supports=imported.Supports,Media=imported.Media,Imports={},ParentResource=parent}
		table.insert(parent.Imports,index,resource)
		if imported.Supports and not Sheet.supports(if imported.Supports:find(':',1,true)then '('..imported.Supports..')'else imported.Supports)then resource.Blocked=true;return resource end
		local ancestors,ancestor={},parent
		while ancestor do
			if ancestor.URL then ancestors[ancestor.URL]=true end
			if ancestor.ResponseURL then ancestors[ancestor.ResponseURL]=true end
			ancestor=ancestor.ParentResource
		end
		if ancestors[resource.URL]then resource.Cyclic=true;return resource end
		node=node or parent.Node
		if not node or not connected(node)then return resource end
		local job={Node=node,Generation=0,Status='loading',ParserBlocking=node.StylesheetResourceState and node.StylesheetResourceState.ParserBlocking};active[job]=true;importJobs[resource]=job;recount()
		local generation=job.Generation
		job.Cancel=Graph.start(resource,{Sources=options.Sources,Load=options.LoadStylesheet,Imported=true,Ancestors=ancestors,QueueTask=queue,
			Valid=function()return api.Alive and job.Generation==generation and job.Status=='loading'and connected(node)end,
			Changed=function()changed(node)end,
			Ready=function(ok)ready(job,generation,ok)end,
		})
		return resource
	end
	function api:RemoveImport(parent,resource)
		local index=table.find(parent.Imports,resource);if index then table.remove(parent.Imports,index)end
		if resource.CancelImport then resource.CancelImport()end
		local job=importJobs[resource];if job and active[job]then cancel(job);job.Status='cancelled';recount()end
		importJobs[resource]=nil
	end
	function api:NotifyMutation(record)
		if not self.Alive then return end
		if record.Type=='childList'then walk(record.RemovedNodes,true);walk(record.AddedNodes,true)
		elseif record.Type=='attributes'and not record.AttributeNamespace and owner(record.Target)then
			local name=record.AttributeName
			if name=='href'or name=='rel'or name=='type'or name=='disabled'then refresh(record.Target)end
		end
		local inlineOwner=Sheet.styleMutationOwner(record)
		if inlineOwner then refresh(inlineOwner,true)end
	end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false
		for record in active do cancel(record)end
		for node,record in records do if node.StylesheetResourceState==record then node.StylesheetResourceState=nil end end
		table.clear(records);table.clear(active);table.clear(importJobs);table.clear(options);self.Pending=0
	end
	if options.Scan~=false then walk({document})end;return api
end
return Resources
