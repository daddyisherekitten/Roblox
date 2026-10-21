--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- Dialog and popover algorithms share a realm-owned top-layer order. Native
-- buttons, forms and pointer dismissal enter the same algorithms as scripts.
local VM=require(script.Parent.VM)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local API={}
function API.install(vm,globals,options)
	local U,N=VM.Undefined,VM.Null
	local host={Alive=true};local adapter=options.Adapter
	local states=setmetatable({},{__mode="kv"})
	local methods={};local sequence=0;local actionDepth=0;local pointerDown
	local document=options.Document
	local function connected(node)return ShadowTree.Connected(node,document)end
	local function contains(node,parent)return ShadowTree.InclusiveDescendant(node,parent)end
	local function fail(name,message)VM.throw(if name=="TypeError"then VM.error(name,message)else options.Events:DOMException(message,name))end
	local function text(value)
		value=vm.ToPrimitive(value,"string")
		if type(value)=="table"and value.Kind=="symbol"then fail("TypeError","Cannot convert Symbol to DOMString")end
		return VM.string(value)
	end
	local function html(node)return ElementNames.html(node)end
	local function state(node)
		local s=states[node]
		if not s then
			s={Node=node,Modal=false,ReturnValue="",PopoverOpen=false,Order=0,DialogOrder=0,Busy=false}
			states[node]=s;node.JavaScriptTopLayerState=s
		end
		return s
	end
	local function attributeMode(value)
		if value==nil then return nil end
		value=value:lower();return if value==""or value=="auto"then "auto"elseif value=="hint"then "hint"else "manual"
	end
	local function mode(node)return attributeMode(node.Attributes.popover)end
	local function receiver(value,dialog)
		local node=if type(value)=="table"then value.DOMNode else nil
		if not html(node)or(dialog and not ElementNames.html(node,"dialog"))or options.Wrap(node)~=value then fail("TypeError","Incompatible top-layer receiver")end
		if not host.Alive then fail("InvalidStateError","This document has been disposed")end
		return node
	end
	local function target(node)return if options.TargetFor then options.TargetFor(node)else options.Wrap(node)end
	local function fire(node,name,old,new,source,cancelable)
		local init={cancelable=cancelable==true,oldState=old or "",newState=new or "",source=if source then options.Wrap(source)else N}
		return options.Events:Dispatch(target(node),options.Events:NewEvent(name,init,if old then "ToggleEvent"else "Event"),true)
	end
	local function queue(node,callback)
		return options.QueueTask(function()if host.Alive then callback()end end)
	end
	local function toggleTask(node,old,new,source)
		local s=state(node);local pending=s.ToggleTask
		if pending then
			old=pending.Old
			if options.CancelTask then options.CancelTask(pending.Handle)
			else pending.New,pending.Source=new,source;return end
		end
		local task={Old=old,New=new,Source=source};s.ToggleTask=task
		task.Handle=queue(node,function()
			if s.ToggleTask~=task then return end
			s.ToggleTask=nil;fire(node,"toggle",task.Old,task.New,task.Source,false)
		end)
	end
	local function ensure(node)if adapter and adapter.Ensure and connected(node)then adapter:Ensure(node)end end
	local function changed(kind,node)
		if adapter and adapter.Changed then adapter:Changed(kind,node)end
	end
	local function updateDialog(node)
		local s=state(node)
		if adapter and adapter.UpdateDialog then adapter:UpdateDialog(node,{Open=node.Attributes.open~=nil,Modal=s.Modal,ReturnValue=s.ReturnValue,Order=s.DialogOrder})end
		changed("dialog",node)
	end
	local function updatePopover(node)
		local s=state(node)
		if adapter and adapter.UpdatePopover then adapter:UpdatePopover(node,{Open=s.PopoverOpen,Mode=s.OpenMode or mode(node),Order=s.Order,Source=s.Source})end
		changed("popover",node)
	end
	local function setAttribute(node,key,value)
		local wrapped=options.Wrap(node)
		if value==nil then vm:Call(vm.Get(wrapped,"removeAttribute"),{key},wrapped)
		else vm:Call(vm.Get(wrapped,"setAttribute"),{key,value},wrapped)end
	end
	local function active()return if adapter and adapter.GetActiveElement then adapter:GetActiveElement()else nil end
	local function focus(node,kind)if (node==nil or connected(node))and adapter and adapter.Focus then adapter:Focus(node,kind)end end
	local function closedBy(node)
		local value=(node.Attributes.closedby or ""):lower()
		if value=="any"or value=="closerequest"or value=="none"then return value end
		return if state(node).Modal then "closerequest"else "none"
	end
	local function openList(popover)
		local list={}
		for node,s in states do
			if connected(node)and(if popover then s.PopoverOpen else ElementNames.html(node,"dialog")and node.Attributes.open~=nil)then table.insert(list,s)end
		end
		table.sort(list,function(a,b)return(if popover then a.Order else a.DialogOrder)<(if popover then b.Order else b.DialogOrder)end)
		return list
	end
	local hidePopover,showPopover,closeDialog
	local function popoverValid(node,expected)
		if mode(node)==nil then fail("NotSupportedError","The element has no popover attribute")end
		local s=state(node)
		if s.PopoverOpen~=expected then return false end
		if not connected(node)or s.Modal then fail("InvalidStateError","The popover must be connected and nonmodal")end
		return true
	end
	local function popoverAncestor(node,source)
		local found
		for _,s in openList(true)do
			if s.OpenMode~="manual"and(contains(node,s.Node)or contains(source,s.Node))then found=s end
		end
		return found
	end
	local function hideAbove(ancestor,kind,restore)
		local list=openList(true)
		for i=#list,1,-1 do
			local s=list[i]
			if s.OpenMode==kind and(not ancestor or s.Order>ancestor.Order)then hidePopover(s.Node,nil,restore)end
		end
	end
	hidePopover=function(node,source,restore)
		if not popoverValid(node,true)then return end
		local s=state(node);if s.Busy then return end
		s.Busy=true
		-- Hiding an ancestor closes the descendants above it, while manual
		-- popovers are independent and never participate in dismissal stacks.
		if s.OpenMode~="manual"then
			if s.OpenMode=="auto"then hideAbove(s,"hint",restore)end
			hideAbove(s,s.OpenMode,restore)
		end
		fire(node,"beforetoggle","open","closed",source,false)
		if mode(node)==nil or not connected(node)or not s.PopoverOpen then s.Busy=false;return end
		s.PopoverOpen=false;s.Source=nil;s.OpenMode=nil;s.Busy=false
		updatePopover(node);toggleTask(node,"open","closed",source)
		local previous=s.Previous;s.Previous=nil
		if contains(active(),node)then focus(if restore~=false then previous else nil,"restore")end
	end
	showPopover=function(node,source)
		if not popoverValid(node,false)then return end
		local s=state(node);if s.Busy then return end
		s.Busy=true
		local ok=fire(node,"beforetoggle","closed","open",source,true)
		s.Busy=false
		if not ok then return end
		if not popoverValid(node,false)then return end
		local original=mode(node);local effective=original;local ancestor=popoverAncestor(node,source)
		if original~="manual"then
			if ancestor and ancestor.OpenMode=="hint"then effective="hint"end
			hideAbove(ancestor,"hint",false)
			if effective=="auto"then hideAbove(ancestor,"auto",false)end
			if mode(node)~=original then fail("InvalidStateError","The popover type changed while showing")end
			if not popoverValid(node,false)then return end
		end
		ensure(node)
		sequence+=1;s.Order=sequence;s.PopoverOpen=true;s.OpenMode=effective;s.Source=source
		-- The first auto/hint popover owns focus restoration for its stack.
		local ownsFocus=true
		for _,other in openList(true)do if other~=s and other.OpenMode~="manual"then ownsFocus=false;break end end
		s.Previous=if ownsFocus and original~="manual"then active()else nil
		updatePopover(node);focus(node,if ElementNames.html(node,"dialog")then "dialog"else "popover")
		toggleTask(node,"closed","open",source)
	end
	local function showDialog(node,modal,source)
		local s=state(node)
		if node.Attributes.open~=nil then
			if s.Modal==modal then return end
			fail("InvalidStateError","The dialog is already open in another mode")
		end
		if modal and(not connected(node)or s.PopoverOpen)then fail("InvalidStateError","A modal dialog must be connected and not showing as a popover")end
		if s.Busy then return end
		s.Busy=true;local allowed=fire(node,"beforetoggle","closed","open",source,true);s.Busy=false
		if not allowed or node.Attributes.open~=nil or(modal and(not connected(node)or s.PopoverOpen))then return end
		local previous=active()
		setAttribute(node,"open","");s.Modal=modal
		sequence+=1;s.DialogOrder=sequence;s.Previous=previous
		ensure(node);updateDialog(node)
		local ancestor=popoverAncestor(node,nil)
		hideAbove(ancestor,"hint",false);hideAbove(ancestor,"auto",false)
		focus(node,"dialog");toggleTask(node,"closed","open",source)
	end
	closeDialog=function(node,value,source)
		local s=state(node)
		if node.Attributes.open==nil or s.Busy then return end
		s.Busy=true;fire(node,"beforetoggle","open","closed",source,false);s.Busy=false
		if node.Attributes.open==nil then return end
		local wasModal=s.Modal
		local restore=wasModal or contains(active(),node)
		setAttribute(node,"open",nil);s.Modal=false
		if value~=nil then s.ReturnValue=value end
		ensure(node);updateDialog(node);toggleTask(node,"open","closed",source)
		local previous=s.Previous;s.Previous=nil
		if restore then focus(previous,"restore")end
		queue(node,function()fire(node,"close",nil,nil,nil,false)end)
	end
	local function requestClose(node,value,source)
		if node.Attributes.open==nil or not connected(node)then return end
		if fire(node,"cancel",nil,nil,nil,true)then closeDialog(node,value,source)end
	end
	local function native(name,fn)
		local value={Kind="native-function",Call=function(args,object)return fn(args,receiver(object,name=="show"or name=="showModal"or name=="close"or name=="requestClose"))end,Values={},Prototype=vm.Prototypes.Function}
		vm.DefineProperty(value,"name",vm.Object({value=name,configurable=true},N));vm.DefineProperty(value,"length",vm.Object({value=0,configurable=true},N))
		methods[name]=value
	end
	local function dictionary(value)
		if value==nil or value==U or value==N then return nil end
		if(type(value)~="table"and type(value)~="function")or(type(value)=="table"and(value.Kind=="symbol"or value.Kind=="bigint"))then fail("TypeError","Expected a popover options dictionary")end
		return value
	end
	local function sourceOption(value)
		local object=dictionary(value);if not object then return nil end
		local source=vm.Get(object,"source");if source==U or source==N then return nil end
		local node=if type(source)=="table"then source.DOMNode else nil
		if not node or node.Kind~="Element"or options.Wrap(node)~=source then fail("TypeError","Popover source must be an Element or null")end
		return node
	end
	native("show",function(_,node)showDialog(node,false,nil);return U end)
	native("showModal",function(_,node)showDialog(node,true,nil);return U end)
	for _,name in {"close","requestClose"}do native(name,function(args,node)
		local value=if args[1]==nil or args[1]==U then nil else text(args[1])
		if name=="close"then closeDialog(node,value,nil)else requestClose(node,value,nil)end;return U
	end)end
	native("showPopover",function(args,node)local source=sourceOption(args[1]);showPopover(node,source);return U end)
	native("hidePopover",function(_,node)hidePopover(node,nil,true);return U end)
	native("togglePopover",function(args,node)
		local force,source
		if type(args[1])=="boolean"then force=args[1]
		else local object=dictionary(args[1]);if object then local value=vm.Get(object,"force");if value~=U then force=VM.truth(value)end end;source=sourceOption(args[1])end
		local s=state(node)
		if s.PopoverOpen and force~=true then hidePopover(node,nil,true)
		elseif force~=false then showPopover(node,source)
		else popoverValid(node,s.PopoverOpen)end
		return s.PopoverOpen
	end)
	function host:ElementGet(node,key)
		if not html(node)then return nil end
		if key=="popover"then return mode(node)or N end
		if key=="showPopover"or key=="hidePopover"or key=="togglePopover"then return methods[key]end
		if ElementNames.html(node,"dialog")then
			if key=="open"then return node.Attributes.open~=nil end
			if key=="returnValue"then return state(node).ReturnValue end
			if key=="closedBy"then return closedBy(node)end
			if methods[key]then return methods[key]end
		end
		return nil
	end
	function host:ElementSet(node,key,value)
		if not html(node)then return false end
		if key=="popover"then setAttribute(node,"popover",if value==N then nil else text(value));return true end
		if ElementNames.html(node,"dialog")then
			if key=="open"then setAttribute(node,"open",if VM.truth(value)then ""else nil);return true end
			if key=="returnValue"then state(node).ReturnValue=text(value);updateDialog(node);return true end
			if key=="closedBy"then setAttribute(node,"closedby",text(value));return true end
		end
		return false
	end
	function host:AttributeChanged(node,key,value,old)
		if not html(node)then return end
		local s=states[node]
		if ElementNames.html(node,"dialog")and key=="open"then
			s=s or state(node)
			if value==nil then s.Modal=false;if contains(active(),node)then focus(nil,"restore")end
			else if old==nil then sequence+=1;s.DialogOrder=sequence end end
			updateDialog(node)
		elseif key=="popover"and s then
			if s.PopoverOpen and attributeMode(value)~=attributeMode(old)then
				-- Attribute changes synchronously hide the old popover state,
				-- including when its attribute has already been removed.
				-- Attribute removal from a closing beforetoggle callback is a
				-- nested hide. It cleans up without firing that callback twice.
				if not s.Busy then fire(node,"beforetoggle","open","closed",nil,false)end
				s.PopoverOpen=false;s.OpenMode=nil;s.Source=nil;updatePopover(node);toggleTask(node,"open","closed",nil)
			end
		end
	end
	function host:NotifyMutation(record)
		if record.Type~="childList"then return end
		for node,s in states do if not connected(node)then
			if s.PopoverOpen then s.PopoverOpen=false;s.OpenMode=nil;s.Source=nil;updatePopover(node)end
			if s.Modal then s.Modal=false;updateDialog(node)end
		end end
	end
	function host:NativeAction(kind,node,value,source)
		if not self.Alive or not html(node)then return false end
		-- Native controls suppress invalid commands instead of reporting script
		-- exceptions; public JS methods still throw their WebIDL exceptions.
		if actionDepth>=32 then return false end
		actionDepth+=1
		local ok,result=pcall(function()
			if kind=="show-modal"or kind=="show"then if not ElementNames.html(node,"dialog")then return false end;showDialog(node,kind=="show-modal",source)
			elseif kind=="close"or kind=="request-close"then if not ElementNames.html(node,"dialog")then return false end;if kind=="close"then closeDialog(node,value,source)else requestClose(node,value,source)end
			elseif kind=="show-popover"then showPopover(node,source)
			elseif kind=="hide-popover"then hidePopover(node,source,true)
			elseif kind=="toggle-popover"then if state(node).PopoverOpen then hidePopover(node,source,true)else showPopover(node,source)end
			else return false end
			return true
		end)
		actionDepth-=1;return ok and result==true
	end
	function host:Escape()
		local latest,kind
		for _,s in openList(true)do if s.OpenMode~="manual"and(not latest or s.Order>latest.Order)then latest=s;kind="popover"end end
		for _,s in openList(false)do if closedBy(s.Node)~="none"and(not latest or s.DialogOrder>(if kind=="popover"then latest.Order else latest.DialogOrder))then latest=s;kind="dialog"end end
		if not latest then return false end
		if kind=="popover"then hidePopover(latest.Node,nil,true)else requestClose(latest.Node,nil,nil)end
		return true
	end
	local function clickedDialog(position,node)
		while node do
			if ElementNames.html(node,"dialog")and node.Attributes.open~=nil then
				if state(node).Modal and adapter and adapter.ContainsPoint and not adapter:ContainsPoint(node,position)then return nil end
				return node
			end;node=node.Parent
		end;return nil
	end
	local function clickedPopover(position,node)
		local ancestor=popoverAncestor(node,nil)
		if ancestor then return ancestor.Node end
		for _,s in openList(true)do
			if s.OpenMode~="manual"and(adapter and adapter.ContainsPoint and adapter:ContainsPoint(s.Node,position))then return s.Node end
			if node and node.Attributes and node.Attributes.popovertarget and node.Attributes.popovertarget~=""and node.Attributes.popovertarget==s.Node.Attributes.id then return s.Node end
		end;return nil
	end
	function host:PointerDown(position,node)
		pointerDown={Dialog=clickedDialog(position,node),Popover=clickedPopover(position,node)}
	end
	function host:PointerUp(position,node)
		local down=pointerDown;pointerDown=nil;if not down then return false end
		local popover=clickedPopover(position,node)
		if popover==down.Popover then local s=popover and states[popover];hideAbove(s,"hint",true);hideAbove(s,"auto",true)end
		local dialog=clickedDialog(position,node)
		if dialog==down.Dialog then local list=openList(false);local top=list[#list]
			if top and top.Node~=dialog and closedBy(top.Node)=="any"then requestClose(top.Node,nil,nil);return true end
		end
		return false
	end
	function host:Snapshot(node)local s=state(node);return {Open=node.Attributes.open~=nil,Modal=s.Modal,ReturnValue=s.ReturnValue,PopoverOpen=s.PopoverOpen,Order=s.Order,DialogOrder=s.DialogOrder,Mode=s.OpenMode or mode(node)}end
	function host:Destroy()
		if not self.Alive then return end;self.Alive=false;pointerDown=nil
		for node,s in states do if node.JavaScriptTopLayerState==s then node.JavaScriptTopLayerState=nil end;s.ToggleTask=nil;s.Previous=nil end
		table.clear(states);table.clear(methods);adapter=nil;table.clear(options)
	end
	-- Parser-open dialogs already have close watchers, although they do not
	-- focus automatically and direct open-attribute changes fire no toggle.
	local pending={document}
	while #pending>0 do local node=table.remove(pending);if ElementNames.html(node,"dialog")and node.Attributes.open~=nil then sequence+=1;state(node).DialogOrder=sequence end;for _,child in node.Children or {}do table.insert(pending,child)end end
	return host
end
return API
