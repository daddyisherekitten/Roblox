--!strict
local Node = require(script.Parent.Parent.DOM.Node)
local ShadowTree = require(script.Parent.Parent.DOM.ShadowTree)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local Markup = require(script.Parent.DOMMarkup)
local ShadowDOM = {}
local HTML = "http://www.w3.org/1999/xhtml"

function ShadowDOM.new(vm: any, ctx: any): any
	local VM, U, N = vm.Model, vm.Model.Undefined, vm.Model.Null
	local api = {Alive=true}
	local signaled, signalOrder, queued = {}, {}, false
	local function fail(name: string, message: string)ctx.DOMError(name,message)end
	local function dictionary(value: any): any
		if value == nil or value == U or value == N then return nil end
		if not vm.ObjectModel.IsObject(value) then fail("TypeError","Expected a dictionary") end
		return value
	end
	local function field(value: any, key: string): any return if value then vm.Get(value,key) else U end
	local function signal(slot: any)
		if signaled[slot] then return end
		signaled[slot] = true
		table.insert(signalOrder,slot)
		if queued then return end; queued = true
		ctx.Enqueue(function()
			if not api.Alive then return end
			queued = false; local pending = signalOrder; signaled = {}; signalOrder = {}
			for _,node in pending do
				if not api.Alive then break end
				ctx.Events:Dispatch(ctx.TargetFor(node),ctx.Events:NewEvent("slotchange",{bubbles=true}),true)
			end
		end)
	end
	local function distribute(root: any)
		return ShadowTree.Distribute(root,signal)
	end
	local function mutateRoot(root: any)
		distribute(root)
		if ShadowTree.Connected(root,ctx.Document) then ctx.Host.Changed(root.Host,"children") end
	end
	function api:Get(node: any, key: any): (boolean, any)
		if key == "getRootNode" then return true,function(args: any)
			local init = dictionary(args[1]); return ctx.Wrap(ShadowTree.Root(node,VM.truth(field(init,"composed"))))
		end end
		if key == "assignedSlot" and (node.Kind == "Element" or node.Kind == "Text") then
			local slot = node.AssignedSlot; local root = slot and ShadowTree.Root(slot)
			return true,ctx.Wrap(if root and root.Mode ~= "closed" then slot else nil)
		end
		if node.Kind == "ShadowRoot" then
			if key == "host" then return true,ctx.Wrap(node.Host) end
			if key == "mode" then return true,node.Mode end
			if key == "delegatesFocus" then return true,node.DelegatesFocus == true end
			if key == "clonable" then return true,node.Clonable == true end
			if key == "serializable" then return true,node.Serializable == true end
			if key == "slotAssignment" then return true,node.SlotAssignment or "named" end
			if key == "innerHTML" then
				local ok,value=pcall(Markup.serialize,node,true);if not ok then
					if ctx.Host.DOMException then VM.throw(ctx.Host.DOMException(tostring(value),"InvalidStateError"))else fail("InvalidStateError",tostring(value))end
				end
				return true,value
			end
			if key == "getElementById" then return true,function(args: any)
				ctx.RequireArgs(args,1); local id = ctx.ReflectedString(args[1]); return ctx.Wrap(if id == "" then nil else Node.findById(node,id))
			end end
			if key == "activeElement" then
				local active = ctx.Host.GetActiveElement or (ctx.Host.ControlAdapter and ctx.Host.ControlAdapter.GetActiveElement)
				local target = active and active()
				return true,ctx.Wrap(if target and ShadowTree.InclusiveDescendant(target,node) then ShadowTree.Retarget(target,node) else nil)
			end
		end
		if node.Kind == "Element" then
			if key == "shadowRoot" then return true,ctx.Wrap(if node.InternalShadowRoot and node.InternalShadowRoot.Mode == "open" then node.InternalShadowRoot else nil) end
			if key == "slot" then return true,node.Attributes.slot or "" end
			if key == "attachShadow" then return true,function(args: any)
				ctx.RequireArgs(args,1); local init = dictionary(args[1]); local mode = ctx.ReflectedString(field(init,"mode"))
				if mode ~= "open" and mode ~= "closed" then fail("TypeError","Invalid ShadowRoot mode") end
				if not ElementNames.html(node) or not ElementNames.shadow(ElementNames.htmlName(node)) then fail("NotSupportedError","This element cannot host a shadow tree") end
				if node.CustomElementDefinition and node.CustomElementDefinition.DisableShadow then fail("NotSupportedError","Shadow trees are disabled for this custom element") end
				local existing = node.InternalShadowRoot
				if existing then
					if not existing.Declarative or existing.Mode ~= mode then fail("NotSupportedError","The element already has a shadow tree") end
					ctx.Mutate(existing,{},nil,table.clone(existing.Children)); existing.Declarative = false; mutateRoot(existing); return ctx.Wrap(existing)
				end
				local slotAssignment = field(init,"slotAssignment")
				if slotAssignment ~= U then slotAssignment = ctx.ReflectedString(slotAssignment); if slotAssignment ~= "named" and slotAssignment ~= "manual" then fail("TypeError","Invalid slotAssignment") end end
				local custom=ctx.CustomElements and ctx.CustomElements()
				local registry=field(init,"customElementRegistry")
				if registry==U and custom then registry=custom:GetRegistry(node.OwnerDocument or ctx.Document)end
				-- Validate before attaching a root, so an invalid registry cannot
				-- leave the host with a half-created shadow tree.
				if custom and registry~=U then custom:ValidateRegistry(registry,node)end
				local root = ctx.Allocate(Node.shadowRoot(mode,node,VM.truth(field(init,"clonable")),VM.truth(field(init,"serializable")),VM.truth(field(init,"delegatesFocus"))))
				root.SlotAssignment = if slotAssignment == U then "named" else slotAssignment
				root.OwnerDocument = node.OwnerDocument or ctx.Document
				if custom and registry~=U then custom:SetRegistry(root,registry)end
				node.InternalShadowRoot = root; node.ShadowRoot = if mode == "open" then root else nil
				mutateRoot(root); return ctx.Wrap(root)
			end end
			if ElementNames.htmlName(node) == "slot" and (not node.NamespaceURI or node.NamespaceURI == HTML) then
				if key == "name" then return true,node.Attributes.name or "" end
				if key == "assignedNodes" or key == "assignedElements" then return true,function(args: any)
					local init = dictionary(args[1]); local values = ShadowTree.Assigned(node,VM.truth(field(init,"flatten")))
					local result = {}; for _, child in values do if key == "assignedNodes" or child.Kind == "Element" then table.insert(result,ctx.Wrap(child)) end end
					return vm.Array(result)
				end end
				if key == "assign" then return true,function(args: any)
					local values, seen = {}, {}
					for _, value in args do local child = ctx.Unwrap(value); if child.Kind ~= "Element" and child.Kind ~= "Text" then fail("TypeError","Slots accept Element or Text nodes") end
						if not seen[child] then seen[child] = true; table.insert(values,child) end
					end
					for _, child in node.ManualAssignedNodes or {} do if child.ManualSlot == node then child.ManualSlot = nil end end
					node.ManualAssignedNodes = values; for _, child in values do child.ManualSlot = node end
					local root = ShadowTree.Root(node); if root.Kind == "ShadowRoot" then mutateRoot(root) end
				end end
			end
		end
		return false,nil
	end
	function api:Set(node: any,key: any,value: any,strict: boolean?): boolean
		if node.Kind == "ShadowRoot" and key == "innerHTML" then
			local fragment = ctx.Parse(node,if value == N then "" else ctx.ReflectedString(value))
			ctx.Mutate(node,{fragment},nil,table.clone(node.Children)); return true
		end
		if node.Kind == "Element" and (key == "slot" or (ElementNames.htmlName(node) == "slot" and key == "name")) then ctx.Attribute(node,key,ctx.ReflectedString(value)); return true end
		if key == "assignedSlot" or (node.Kind == "Element" and key == "shadowRoot") or (node.Kind == "ShadowRoot" and ({host=true,mode=true,delegatesFocus=true,clonable=true,serializable=true,slotAssignment=true,activeElement=true})[key]) then
			if strict ~= false then fail("TypeError","Read-only shadow DOM property") end; return true
		end
		return false
	end
	function api:Mutation(record: any)
		local node, roots = record.Target, {}
		-- Distribution can change when nodes move or a slot/name changes. Text,
		-- class and style mutations already have their own local renderer path.
		-- Promoting those changes to host children discards that distinction.
		if record.Type ~= "childList" and not (record.Type == "attributes" and
			(record.AttributeName == "slot" or (ElementNames.htmlName(node) == "slot" and record.AttributeName == "name"))) then return end
		local root = ShadowTree.Root(node)
		if root.Kind == "ShadowRoot" then roots[root] = true end
		if node.InternalShadowRoot then roots[node.InternalShadowRoot] = true end
		if node.Parent and node.Parent.InternalShadowRoot then roots[node.Parent.InternalShadowRoot] = true end
		for current in roots do
			local changed = distribute(current)
			if record.Type == "childList" and ElementNames.htmlName(node) == "slot" and #(node.AssignedNodes or {}) == 0 then signal(node) end
			if changed and ShadowTree.Connected(current,ctx.Document) then ctx.Host.Changed(current.Host,"children") end
		end
	end
	function api:Destroy()self.Alive = false; table.clear(signaled);table.clear(signalOrder); table.clear(ctx)end
	local pending = {ctx.Document}; while #pending > 0 do
		local node = table.remove(pending); if node.InternalShadowRoot then distribute(node.InternalShadowRoot); table.insert(pending,node.InternalShadowRoot) end
		for _, child in node.Children do table.insert(pending,child) end
	end
	return api
end
return ShadowDOM
