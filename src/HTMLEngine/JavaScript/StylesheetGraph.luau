--!strict
-- One import graph per owner. Network completions cannot publish into a newer
-- graph; request/depth/decoded-byte budgets also bound hostile import trees.
local Imports=require(script.Parent.Parent.CSS.ImportRules)
local Sheet=require(script.Parent.Parent.CSS.Stylesheet)
local URL=require(script.Parent.Parent.Navigation.URL)
local Work=require(script.Parent.Parent.WorkContext)
local Graph={}
function Graph.start(owner:any,options:any):()->()
	local alive,pending,bytes,count=true,0,0,0;local cancellations,parents,requests={}, {}, {};local failed,ready=false,false
	local function valid()return alive and options.Valid()end
	local function currentURL(source,base)return URL.resolve(base or 'about:blank',source).URL or source end
	local function completed()
		if valid()and pending==0 and not ready then ready=true;options.Ready(not failed)end
	end
	local function publish(record)
		local at=record
		while at and valid()and at.GraphFetched and at.GraphRemaining==0 and not at.GraphPublished do
			at.Source=at.GraphSource;at.GraphPublished=true;at.CancelImport=nil
			local parent=parents[at];parents[at]=nil
			if parent then parent.GraphRemaining-=1 end;at=parent
		end
	end
	local function cancelBranch(record)
		if not valid()or record.GraphCancelled then return end
		local parent=parents[record];parents[record]=nil
		if parent then parent.GraphRemaining-=1 end
		local pendingNodes={record}
		while #pendingNodes>0 do
			Work.checkpoint();local node=table.remove(pendingNodes);node.GraphCancelled=true;node.CancelImport=nil;parents[node]=nil
			if node.GraphPending then node.GraphPending=false;pending-=1 end
			local cancel=requests[node];if cancel then requests[node]=nil;cancellations[cancel]=nil;pcall(cancel)end
			for _,child in node.Imports do table.insert(pendingNodes,child)end
		end
		if parent then publish(parent)end
		options.Changed();completed()
	end
	local request,consume
	consume=function(record,ok,value,ancestors,depth)
		if not valid()or record.GraphCancelled then return end
		local source=if type(value)=='table'then value.Source else value
		local rawMIME=if type(value)=='table'then value.MIME else nil
		local mime=if type(rawMIME)=='string'then rawMIME:lower():match('^%s*([^; ]+)')else nil
		ok=ok and type(source)=='string'and #source<=1048576 and(rawMIME==nil or mime=='text/css')
		if ok then bytes+=#source;ok=bytes<=1048576 end
		record.Failed=not ok
		-- Associate each sheet when its own critical subtree has settled. Inline
		-- owner CSS is separately available through the DOM source immediately.
		record.GraphSource=if ok then source elseif record==owner and not options.Imported then nil else ''
		record.GraphFetched=true
		if record==owner and not options.Imported then record.Source=record.GraphSource end
		record.OriginClean=type(value)~='table'or value.OriginClean~=false
		record.ResponseURL=if type(value)=='table'and type(value.URL)=='string'then currentURL(value.URL,record.URL)else record.URL
		record.Imports={};failed=failed or not ok
		if ok then
			local chain=table.clone(ancestors);chain[record.URL]=true;chain[record.ResponseURL]=true
			local children={}
			for _,imported in Imports.read(source)do
				Work.checkpoint();if not valid()then return end
				local target=currentURL(imported.Href,record.ResponseURL)
				local child={URL=target,Href=imported.Href,Layer=imported.Layer,Supports=imported.Supports,Media=imported.Media,Imports={},ParentResource=record}
				table.insert(record.Imports,child)
				if imported.Supports and not Sheet.supports(if imported.Supports:find(':',1,true)then '('..imported.Supports..')'else imported.Supports)then child.Blocked=true
				elseif chain[target]then child.Cyclic=true
				elseif depth>=32 or count>=4096 then child.Source='';child.Failed=true;failed=true
				else parents[child]=record;record.GraphRemaining+=1;table.insert(children,child)end
			end
			-- Reserve all direct dependencies before a packaged synchronous child
			-- can publish. Otherwise the first child could associate its parent
			-- while later sibling imports have not even been discovered yet.
			for _,child in children do Work.checkpoint();if not valid()then return end;request(child,chain,depth+1)end
		end
		publish(record)
		if not valid()then return end;options.Changed();record.GraphPending=false;pending-=1;completed()
	end
	request=function(record,ancestors,depth)
		if not valid()then return end
		if count>=4096 then record.GraphFetched=true;record.GraphRemaining=0;record.GraphSource='';record.Failed=true;failed=true;publish(record);return end
		pending+=1;count+=1;record.GraphRemaining=0;record.GraphFetched=false;record.GraphPublished=false;record.GraphPending=true;record.GraphCancelled=false;record.CancelImport=function()cancelBranch(record)end;requests[record]=false;local called=false;local cancellation
		local function complete(ok,value)
			if called or not valid()or record.GraphCancelled then return end;called=true
			if cancellation then cancellations[cancellation]=nil end;requests[record]=false
			options.QueueTask(function()if valid()then consume(record,ok,value,ancestors,depth)end end)
		end
		local mapped=options.Sources and(options.Sources[record.URL]or options.Sources[record.Href or owner.Raw]or options.Sources[URL.resolve(record.URL,'').Path])
		if record==owner and options.Inline~=nil then consume(record,true,options.Inline,ancestors,depth)
		elseif mapped~=nil then consume(record,true,mapped,ancestors,depth)
		elseif options.Load then
			local ok,result=pcall(options.Load,record.URL,complete,{Type='css',Node=owner.Node,Import=record~=owner})
			if not ok then complete(false,result)
			elseif not called and type(result)=='function'then cancellation=result;cancellations[result]=true;requests[record]=result end
		else complete(false,'No stylesheet resource adapter')end
	end
	request(owner,options.Ancestors or {},0)
	return function()
		if not alive then return end;alive=false
		for record in requests do record.CancelImport=nil end
		for cancellation in cancellations do pcall(cancellation)end;table.clear(cancellations);table.clear(parents);table.clear(requests);table.clear(options)
	end
end
return Graph
