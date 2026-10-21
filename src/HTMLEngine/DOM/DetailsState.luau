--!strict
local Names=require(script.Parent.ElementNames)
-- HTML details grouping is a DOM-tree operation, independent of rendering.
local WorkContext=require(script.Parent.Parent.WorkContext)
local Details={}
function Details.isDetails(node: any): boolean
	return Names.html(node,"details")
end
local function root(node: any): any
	while node.Parent do node=node.Parent end
	return node
end
local function walk(node: any,visit: any,step: any?,shadow: boolean?)
	local pending={node}
	while #pending>0 do
		if step then step() else WorkContext.checkpoint() end
		local current=table.remove(pending)
		if visit(current)==false then return end
		if shadow and current.InternalShadowRoot then table.insert(pending,current.InternalShadowRoot)end
		if shadow and current.Content then table.insert(pending,current.Content)end
		for index=#current.Children,1,-1 do table.insert(pending,current.Children[index])end
	end
end
function Details.exclusive(node: any,closeOthers: boolean,change: any,step: any?)
	if not Details.isDetails(node) or node.Attributes.open==nil then return end
	local name=node.Attributes.name
	if name==nil or name=="" then return end
	walk(root(node),function(other)
		if other~=node and Details.isDetails(other) and other.Attributes.name==name and other.Attributes.open~=nil then
			change(if closeOthers then other else node,"open",nil)
			return false
		end
		return true
	end,step)
end
-- Parser attributes precede insertion. Retain their coalesced event states
-- until a document realm installs its task source.
function Details.parserInserted(node: any,step: any?)
	if not Details.isDetails(node) or node.Attributes.open==nil then return end
	node.ParsedDetailsToggle={Old="closed",New="open"}
	Details.exclusive(node,false,function(other,key,value)
		other.Attributes[key]=value
		local order=other.AttributeOrder;local index=order and table.find(order,key)
		if index then table.remove(order,index)end
		other.ParsedDetailsToggle.New="closed"
	end,step)
end
function Details.new(options: any): any
	local controller={Alive=true};local pending,jobs={},{}
	local function queue(node,old,new)
		if not options.QueueTask then return end
		local previous=pending[node]
		if previous then old=previous.Old;previous.Cancelled=true;options.CancelTask(previous.Handle);jobs[previous]=nil end
		local record={Old=old,New=new};pending[node]=record
		jobs[record]=true
		record.Handle=options.QueueTask(function()
			if not controller.Alive or record.Cancelled then return end
			jobs[record]=nil
			options.Fire(node,record.Old,record.New)
			-- HTML clears the tracker after dispatch. A reentrant toggle task
			-- survives independently, even when its tracker is cleared here.
			pending[node]=nil
		end)
	end
	function controller:AttributeChanged(node,key,value,oldValue,namespace)
		if not self.Alive or namespace~=nil or not Details.isDetails(node)then return end
		if key=="name" then Details.exclusive(node,false,options.Attribute,options.Step)
		elseif key=="open" and (value==nil)~=(oldValue==nil)then
			queue(node,if oldValue==nil then "closed"else "open",if value==nil then "closed"else "open")
			if value~=nil then Details.exclusive(node,true,options.Attribute,options.Step)end
		end
	end
	function controller:Inserted(additions)
		for _,addition in additions do walk(addition,function(node)
			local parsed=node.ParsedDetailsToggle
			if parsed and options.QueueTask then node.ParsedDetailsToggle=nil;queue(node,parsed.Old,parsed.New)end
			Details.exclusive(node,false,options.Attribute,options.Step)
			return true
		end,options.Step,true)end
	end
	function controller:Start(document,scheduler)
		for key,value in scheduler do options[key]=value end
		walk(document,function(node)
			local record=node.ParsedDetailsToggle
			if record then node.ParsedDetailsToggle=nil;queue(node,record.Old,record.New)end
			return true
		end,options.Step,true)
	end
	function controller:Destroy()
		if not self.Alive then return end;self.Alive=false
		for record in jobs do options.CancelTask(record.Handle)end
		table.clear(pending);table.clear(jobs);table.clear(options)
	end
	return controller
end
return Details
