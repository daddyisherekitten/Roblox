--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- HTML content handlers share the ordered IDL handler slot. The source is
-- compiled lazily in the current node-document realm, not at attribute parsing.
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Attributes={}
local function names(source)
	local result={};for name in source:gmatch('%S+')do result['on'..name]=true end;return result
end
local common=names('abort animationcancel animationend animationiteration animationstart auxclick beforeinput beforematch beforetoggle blur cancel canplay canplaythrough change click close command contextlost contextmenu contextrestored copy cuechange cut dblclick drag dragend dragenter dragleave dragover dragstart drop durationchange emptied ended error focus focusin focusout fullscreenchange fullscreenerror formdata gotpointercapture input invalid keydown keypress keyup load loadeddata loadedmetadata loadstart lostpointercapture mousedown mouseenter mouseleave mousemove mouseout mouseover mouseup paste pause play playing pointercancel pointerdown pointerenter pointerleave pointermove pointerout pointerover pointerrawupdate pointerup progress ratechange reset resize scroll scrollend securitypolicyviolation seeked seeking select selectionchange selectstart slotchange stalled submit suspend timeupdate toggle touchcancel touchend touchmove touchstart transitioncancel transitionend transitionrun transitionstart volumechange waiting webkitanimationend webkitanimationiteration webkitanimationstart webkittransitionend wheel')
local windowOnly=names('afterprint beforeprint beforeunload hashchange languagechange message messageerror offline online pagehide pagereveal pageshow pageswap popstate rejectionhandled storage unhandledrejection unload')
local forwarded=table.clone(windowOnly)
for _,name in {'blur','error','focus','load','resize','scroll'}do forwarded['on'..name]=true end
local windowNames=table.clone(common);for name in windowOnly do windowNames[name]=true end
local documentNames=table.clone(common);documentNames.onreadystatechange=true;documentNames.onvisibilitychange=true
local allNames=table.clone(windowNames);allNames.onreadystatechange=true;allNames.onvisibilitychange=true
Attributes.AllNames=allNames
Attributes.CommonNames=common
Attributes.WindowNames=windowNames
Attributes.DocumentNames=documentNames
function Attributes.names(node)
	if not node then return windowNames elseif node.Kind=='Document'then return documentNames
	elseif (ElementNames.html(node,'body')or ElementNames.html(node,'frameset'))then return windowNames
	elseif node.Kind=='Element'and(ElementNames.html(node)or node.NamespaceURI==ElementNames.SVG or node.NamespaceURI==ElementNames.MathML)then return common end
	return nil
end
local FORM_OWNER={button=true,fieldset=true,input=true,object=true,output=true,select=true,textarea=true}
function Attributes.install(vm,options)
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null
	local api={Alive=true};local seen=setmetatable({},{__mode='k'})
	local syncing=false;local reporting=false
	local function active(node)
		local document=if node and node.Kind=='Document'then node elseif node then node.OwnerDocument or options.Document else options.Document
		return document==options.Document and not document.DetachedDocument and options.ScriptingEnabled~=false
	end
	function api:Target(node,key)
		if node and (ElementNames.html(node,'body')or ElementNames.html(node,'frameset'))and forwarded[key]then
			return if active(node)then options.Window else false
		end
		return nil
	end
	local function errorReport(failure,location)
		local errorValue=VM.exceptionValue(failure)
		if reporting then if options.Report then options.Report(errorValue)end;return end
		reporting=true
		local ok,canceled=pcall(function()
			local event=options.Events:NewEvent('error',{message=vm.Get(errorValue,'message'),filename=location or '',lineno=0,colno=0,error=errorValue,cancelable=true},'ErrorEvent')
			return not options.Events:Dispatch(options.Window,event)
		end)
		reporting=false
		if not ok or not canceled then if options.Report then options.Report(errorValue)end end
	end
	function api:Compile(node,target,key,source)
		local owner=node and options.Bridge.OwnerBridge(node)
		local destination=owner and owner.Host.EventHandlerAttributes
		if destination and destination~=self then return destination:Compile(node,target,key,source)end
		if not active(node)then return N,false end
		local root=node and ShadowTree.Root(node)
		-- Template contents have an inert owner document in browsers. The data
		-- DOM retains a template Host instead; moving out removes this guard.
		if root and root.Kind=='DocumentFragment'and root.Host and ElementNames.html(root.Host,'template')then return N,false end
		local objects={}
		if target~=options.Window and node then
			table.insert(objects,options.Bridge.Wrap(node.OwnerDocument or options.Document))
			if FORM_OWNER[ElementNames.htmlName(node)]then
				local form=options.Bridge.NativeRead(node,'form')
				if form~=nil and form~=N and form~=U then table.insert(objects,form)end
			end
			table.insert(objects,options.Bridge.Wrap(node))
		end
		local location=if options.GetURL then options.GetURL()else options.Document.URL
		local ok,value=pcall(vm.CompileEventHandler,vm,source,key,objects)
		if not ok then return N,true,function()errorReport(value,location)end end
		return value,true
	end
	local function content(node,target,key,value,namespace,explicitNamespace)
		if not explicitNamespace then local info=node.AttributeNamespaces and node.AttributeNamespaces[key];namespace=info and info.Namespace end
		if namespace and namespace~=''then return end
		if value==nil then options.Events:HandlerSet(target,key,N);return end
		local actual=api:Target(node,key)
		if actual==false then return end
		actual=actual or target
		options.Events:HandlerContent(target,key,function()return api:Compile(node,actual,key,value)end)
	end
	function api:Bind(node,target)
		if not self.Alive or not node or node.Kind~='Element'then return end
		local keys=Attributes.names(node);if not keys then return end;local previous=seen[node]
		if not previous then previous={};seen[node]=previous end
		for key,value in node.Attributes do
			if keys[key]and previous[key]~=value then previous[key]=value;content(node,target,key,value)end
		end
		for key in previous do if node.Attributes[key]==nil then previous[key]=nil;content(node,target,key,nil)end end
	end
	function api:AttributeChanged(node,key,value,oldValue,namespace)
		local keys=Attributes.names(node)
		if not self.Alive or node.Kind~='Element'or not keys or not keys[key]or(value==nil and oldValue==nil)then return end
		if namespace and namespace~=''then return end
		local target=options.TargetFor(node)
		seen[node]=seen[node]or {};seen[node][key]=value
		-- Even writing the identical attribute source replaces an IDL callback.
		content(node,target,key,value,namespace,true)
	end
	function api:Inserted(nodes)
		if not self.Alive then return end
		local pending=table.clone(nodes)
		while #pending>0 do
			vm.Step();local node=table.remove(pending)
			if node.Kind=='Element'then
				local keys=Attributes.names(node)
				for key in node.Attributes do if keys and keys[key]then options.TargetFor(node);break end end
			end
			for _,child in node.Children do table.insert(pending,child)end
			if node.InternalShadowRoot then table.insert(pending,node.InternalShadowRoot)end
		end
	end
	function api:SyncBody()
		if syncing or not self.Alive then return end;syncing=true
		local body=options.Document.Body
		if body then self:Bind(body,options.TargetFor(body))end
		syncing=false
	end
	function api:Receive(node,attributes)if attributes then seen[node]=attributes end end
	function api:Adopted(node,destination)
		local handler=destination.Host.EventHandlerAttributes
		if handler then handler:Receive(node,seen[node]);seen[node]=nil end
	end
	function api:Destroy()self.Alive=false;table.clear(seen);table.clear(options)end
	return api
end
return Attributes
