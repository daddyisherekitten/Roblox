--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- Internals are attached to the retained DOM node, not its native control or
-- render box. FormData values are snapshotted at setFormValue, as in HTML.
local Node = require(script.Parent.Parent.DOM.Node)
local ShadowTree = require(script.Parent.Parent.DOM.ShadowTree)
local FormOwner = require(script.Parent.Parent.DOM.FormOwner)
local State = require(script.Parent.Parent.Controls.State)
local Strings = require(script.Parent.Strings)
local ElementInternals = {}
local FLAGS = {"valueMissing","typeMismatch","patternMismatch","tooLong","tooShort","rangeUnderflow","rangeOverflow","stepMismatch","badInput","customError"}
local ARIA = {"role","ariaAtomic","ariaAutoComplete","ariaBrailleLabel","ariaBrailleRoleDescription","ariaBusy","ariaChecked","ariaColCount","ariaColIndex","ariaColIndexText","ariaColSpan","ariaCurrent","ariaDescription","ariaDisabled","ariaExpanded","ariaHasPopup","ariaHidden","ariaInvalid","ariaKeyShortcuts","ariaLabel","ariaLevel","ariaLive","ariaModal","ariaMultiLine","ariaMultiSelectable","ariaOrientation","ariaPlaceholder","ariaPosInSet","ariaPressed","ariaReadOnly","ariaRelevant","ariaRequired","ariaRoleDescription","ariaRowCount","ariaRowIndex","ariaRowIndexText","ariaRowSpan","ariaSelected","ariaSetSize","ariaSort","ariaValueMax","ariaValueMin","ariaValueNow","ariaValueText","ariaVirtualContent"}
local RELATIONS = {ariaActiveDescendantElement=false,ariaControlsElements=true,ariaDescribedByElements=true,ariaDetailsElements=true,ariaErrorMessageElements=true,ariaFlowToElements=true,ariaLabelledByElements=true,ariaOwnsElements=true}
function ElementInternals.install(vm: any, globals: any, ctx: any): any
	local VM,U,N=vm.Model,vm.Model.Undefined,vm.Model.Null
	local api={Alive=true};local records,tracked,sets,validityRecords={},{},{},{}
	local formDataConstructor=globals.FormData
	local formDataAppend=vm.Get(vm.Get(formDataConstructor,"prototype"),"append")
	local freeze=vm.Get(globals.Object,"freeze")
	local proto,stateProto,validityProto=vm.Object({}),vm.Object({}),vm.Object({})
	local function check()assert(api.Alive and vm.Alive,"ElementInternals disposed")end
	local function fail(name,message)ctx.DOMError(name,message)end
	local function native(name,length,fn)return {Kind="native-function",Values={name=name,length=length},Prototype=vm.Prototypes.Function,Call=function(args,self)check();return fn(args,self)end}end
	local function define(target,key,value)vm.DefineProperty(target,key,vm.Object({value=value,writable=true,enumerable=true,configurable=true},N))end
	local function accessor(target,key,get,set)vm.DefineProperty(target,key,vm.Object({get=native("get "..key,0,get),set=if set then native("set "..key,1,set)else U,enumerable=true,configurable=true},N))end
	local function global(name,value)globals[name]=value;vm.Global.Bindings[name]={Value=value}end
	local function interface(name,prototype)
		local constructor=native(name,0,function()fail("TypeError","Illegal "..name.." constructor")end)
		constructor.Construct=function()fail("TypeError","Illegal "..name.." constructor")end
		vm.DefineProperty(constructor,"prototype",vm.Object({value=prototype},N));define(prototype,"constructor",constructor)
		if vm.SymbolToStringTag then vm.DefineProperty(prototype,vm.SymbolToStringTag,vm.Object({value=name,configurable=true},N))end
		global(name,constructor)
	end
	interface("ElementInternals",proto);interface("CustomStateSet",stateProto)
	-- Share the native ValidityState prototype once the form interface installer
	-- supplies it; its own accessors still dispatch through the record brand.
	if globals.ValidityState and globals.ValidityState~=U then validityProto=vm.Get(globals.ValidityState,"prototype")else interface("ValidityState",validityProto)end
	local function record(value)local entry=records[value];if not entry then fail("TypeError","Illegal ElementInternals receiver")end;return entry end
	local function face(node)local definition=node.CustomElementDefinition;return definition and definition.FormAssociated==true and definition.Name==definition.LocalName and node.CustomElementState~="failed"end
	local function formRecord(value)local entry=record(value);if not face(entry.Node)then fail("NotSupportedError","The custom element is not form-associated")end;return entry end
	local function root(node)while node.Parent do node=node.Parent end;return node end
	local function ancestor(node,name)local current=node.Parent;while current do if ElementNames.htmlName(current)==name then return current end;current=current.Parent end;return nil end
	function api:IsFormAssociated(node)return face(node)==true end
	function api:Owner(node)
		if not face(node)then return nil end
		return FormOwner.resolve(node)
	end
	function api:WillValidate(node)return face(node)==true and not State.disabled(node)and node.Attributes.readonly==nil and not ancestor(node,"datalist")end
	function api:Validity(node)
		local data=node.ElementInternalsData;local flags={valid=true}
		for _,key in FLAGS do flags[key]=data~=nil and data.Flags[key]==true;flags.valid=flags.valid and not flags[key]end
		return flags,if self:WillValidate(node)and not flags.valid then data.Message else ""
	end
	for _,key in FLAGS do accessor(validityProto,key,function(_,self)local data=validityRecords[self];if not data then fail("TypeError","Illegal ValidityState receiver")end;local flags=api:Validity(data.Node);return flags[key]end)end
	accessor(validityProto,"valid",function(_,self)local data=validityRecords[self];if not data then fail("TypeError","Illegal ValidityState receiver")end;local flags=api:Validity(data.Node);return flags.valid end)
	local function hostFor(node)return (ctx.HostFor and ctx.HostFor(node))or ctx.Host end
	local function notify(node)local host=hostFor(node);if host and host.Changed then host.Changed(node,"state","internals")end end
	function api:Check(node,report)
		if not self:WillValidate(node)then return true end
		local flags,message=self:Validity(node);if flags.valid then return true end
		local host=hostFor(node);local events=(host and host.EventHost)or ctx.Events;local targetFor=(host and host.EventTargetFor)or ctx.TargetFor
		local event=events:NewEvent("invalid",{cancelable=true});events:Dispatch(targetFor(node),event,true)
		if report and not VM.truth(vm.Get(event,"defaultPrevented"))then
			local adapter=host and host.ControlAdapter;local fn=(if host==ctx.Host then ctx.ReportValidity else nil)or(adapter and adapter.ReportValidity)
			if fn then fn((node.ElementInternalsData and node.ElementInternalsData.Anchor)or node,message)end
		end
		return false
	end
	local function snapshot(value)
		if value==N or value==U then return N end
		local network=ctx.Network
		if network and network.FormData:IsFormData(value)then
			return {Entries=network.FormData:SnapshotEntries(value)}
		end
		local blob=network and network:DescribeBlob(value)
		if blob and blob.Name~=nil then return value end
		local text=ctx.ReflectedString(value);local codes={};for cp in Strings.codes(text)do table.insert(codes,utf8.char(if cp>=0xd800 and cp<=0xdfff then 0xfffd else cp))end;return table.concat(codes)
	end
	local function restoreValue(value)
		if type(value)~="table"or not value.Entries then return value end
		local data=vm:Construct(formDataConstructor,{})
		for _,entry in value.Entries do vm.Step();vm:Call(formDataAppend,{entry.name,entry.value},data)end
		return data
	end
	function api:Submission(node)
		local data=node.ElementInternalsData;local value=data and data.Value
		if not value or value==N then return {}end
		if type(value)=="table"and value.Entries then local result={};for _,entry in value.Entries do table.insert(result,{name=entry.name,value=entry.value})end;return result end
		local name=node.Attributes.name or "";return if name==""then {}else{{name=name,value=value}}
	end
	function api:RefreshNode(node)
		if not face(node)then return end;tracked[node]=true
		local owner,disabled=self:Owner(node),State.disabled(node)
		if owner~=node.CustomElementFormOwner then node.CustomElementFormOwner=owner;ctx.Reaction(node,"formAssociatedCallback",{ctx.Wrap(owner)})end
		if disabled~=(node.CustomElementDisabled==true)then node.CustomElementDisabled=disabled;ctx.Reaction(node,"formDisabledCallback",{disabled});notify(node)end
	end
	function api:Refresh()for node in tracked do vm.Step();self:RefreshNode(node)end end
	function api:Reset(node)if face(node)then ctx.Reaction(node,"formResetCallback",{});ctx.Drain()end end
	function api:CaptureState(tree)
		local result={};for node in tracked do if not tree or ShadowTree.InclusiveDescendant(node,tree)then local data=node.ElementInternalsData;if data then table.insert(result,{Node=node,State=data.State})end end end;return result
	end
	function api:RestoreState(values,mode)
		check();if mode~=nil and mode~="restore"and mode~="autocomplete"then fail("TypeError","Invalid custom-element restoration mode")end
		for _,entry in values do if tracked[entry.Node]and face(entry.Node)then ctx.Reaction(entry.Node,"formStateRestoreCallback",{restoreValue(entry.State),mode or "restore"})end end
		ctx.Drain()
	end
	define(proto,"setFormValue",native("setFormValue",1,function(args,self)
		local data=formRecord(self);if #args<1 then fail("TypeError","setFormValue requires a value")end
		-- Convert both unions before committing either field.
		local value=snapshot(args[1]);local state=if #args>=2 then snapshot(args[2])else value
		data.Value,data.State=value,state;return U
	end))
	define(proto,"setValidity",native("setValidity",0,function(args,self)
		local data=formRecord(self);local init=if args[1]==nil then U else args[1]
		if init~=U and init~=N and not vm.ObjectModel.IsObject(init)then fail("TypeError","Validity flags require a dictionary")end
		local nextFlags,invalid={},false;for _,key in FLAGS do nextFlags[key]=init~=U and init~=N and VM.truth(vm.Get(init,key));invalid=invalid or nextFlags[key]end
		local message=if #args>=2 then ctx.ReflectedString(args[2])else ""
		if invalid and message==""then fail("TypeError","Invalid constraints require a nonempty message")end
		message=message:gsub("\r\n","\n"):gsub("\r","\n")
		-- Chromium 154 checks the anchor before committing constraints. Keep
		-- this captured browser behavior atomic; the October 2026 HTML text
		-- currently orders this check later (recorded in the component profile).
		local anchor=data.Node
		if #args>=3 and args[3]~=U then anchor=ctx.Unwrap(args[3]);if anchor.Kind~="Element"or(anchor.NamespaceURI and anchor.NamespaceURI~="http://www.w3.org/1999/xhtml")then fail("TypeError","Validation anchor must be an HTMLElement")end;if not ShadowTree.InclusiveDescendant(anchor,data.Node)then fail("NotFoundError","Validation anchor is outside the custom element")end end
		local nextMessage=if invalid then message else "";local changed=nextMessage~=data.Message
		for _,key in FLAGS do changed=changed or nextFlags[key]~=(data.Flags[key]==true)end
		data.Flags,data.Message=nextFlags,nextMessage;if changed then notify(data.Node)end
		data.Anchor=anchor;return U
	end))
	for _,key in {"checkValidity","reportValidity"}do define(proto,key,native(key,0,function(_,self)return api:Check(formRecord(self).Node,key=="reportValidity")end))end
	accessor(proto,"form",function(_,self)return ctx.Wrap(api:Owner(formRecord(self).Node))end)
	accessor(proto,"willValidate",function(_,self)return api:WillValidate(formRecord(self).Node)end)
	accessor(proto,"validationMessage",function(_,self)local _,message=api:Validity(formRecord(self).Node);return message end)
	accessor(proto,"validity",function(_,self)
		local data=formRecord(self)
		if not data.Validity then
			data.Validity=vm.Object({},validityProto);validityRecords[data.Validity]=data
		end
		return data.Validity
	end)
	accessor(proto,"shadowRoot",function(_,self)return ctx.Wrap(record(self).Node.InternalShadowRoot)end)
	accessor(proto,"labels",function(_,self)
		local data=formRecord(self)
		if not data.Labels then
			local function nodes()
				local result,pending={}, {root(data.Node)}
				while #pending>0 do local node=table.remove(pending);vm.Step();if ElementNames.htmlName(node)=="label"then
					local explicit=node.Attributes["for"];local candidate
					if explicit~=nil then candidate=Node.findById(root(node),explicit)else
						local stack=table.clone(node.Children);while #stack>0 do local child=table.remove(stack,1);if child.Kind=="Element"and(child.CustomElementDefinition and child.CustomElementDefinition.FormAssociated or table.find({"button","input","meter","output","progress","select","textarea"},ElementNames.htmlName(child)))and not(ElementNames.htmlName(child)=="input"and child.Attributes.type=="hidden")then candidate=child;break end;for i=#child.Children,1,-1 do table.insert(stack,1,child.Children[i])end end
					end
					if candidate==data.Node then table.insert(result,node)end
				end;for i=#node.Children,1,-1 do table.insert(pending,node.Children[i])end end;return result
			end
			data.Labels=ctx.CollectionView(nodes,false)
		end
		return data.Labels
	end)
	for _,key in ARIA do accessor(proto,key,function(_,self)return record(self).ARIA[key]or N end,function(args,self)local data=record(self);data.ARIA[key]=if args[1]==N or args[1]==U then nil else ctx.ReflectedString(args[1]);return U end)end
	for key,multiple in RELATIONS do accessor(proto,key,function(_,self)return record(self).Relations[key]or N end,function(args,self)
		local data=record(self);local value=args[1]
		if value==N or value==U then data.Relations[key]=nil;return U end
		if multiple then local nodes={};local iterator=vm.Iterator(value);while true do local more,child=iterator();if not more then break end;vm.Step();local node=ctx.Unwrap(child);if node.Kind~="Element"then fail("TypeError","ARIA relationship needs an Element")end;table.insert(nodes,child)end;value=vm.Array(nodes);vm:Call(freeze,{value})
		else if ctx.Unwrap(value).Kind~="Element"then fail("TypeError","ARIA relationship needs an Element")end end
		data.Relations[key]=value;return U
	end)end
	local function stateRecord(value)local data=sets[value];if not data then fail("TypeError","Illegal CustomStateSet receiver")end;return data end
	accessor(stateProto,"size",function(_,self)return stateRecord(self).StateCount end)
	define(stateProto,"add",native("add",1,function(args,self)local data=stateRecord(self);if #args<1 then fail("TypeError","add requires a state")end;local name=ctx.ReflectedString(args[1]);if not data.States[name]then if data.StateCount>=1024 or #data.StateEntries>=16384 then fail("RangeError","Custom state budget exceeded")end;data.States[name]=true;local entry={Name=name,Active=true};data.StateIndex[name]=entry;table.insert(data.StateEntries,entry);data.StateCount+=1;notify(data.Node)end;return U end))
	define(stateProto,"has",native("has",1,function(args,self)local data=stateRecord(self);if #args<1 then fail("TypeError","has requires a state")end;return data.States[ctx.ReflectedString(args[1])]==true end))
	define(stateProto,"delete",native("delete",1,function(args,self)local data=stateRecord(self);if #args<1 then fail("TypeError","delete requires a state")end;local name=ctx.ReflectedString(args[1]);if not data.States[name]then return false end;data.States[name]=nil;data.StateIndex[name].Active=false;data.StateIndex[name]=nil;data.StateCount-=1;notify(data.Node);return true end))
	define(stateProto,"clear",native("clear",0,function(_,self)local data=stateRecord(self);if data.StateCount>0 then for _,entry in data.StateEntries do entry.Active=false end;table.clear(data.States);table.clear(data.StateIndex);data.StateCount=0;notify(data.Node)end;return U end))
	for _,key in {"values","entries"}do define(stateProto,key,native(key,0,function(_,self)
		local data=stateRecord(self);local index=0;local iterator=vm.Object({},vm.Prototypes.Iterator);iterator.Kind="iterator"
		-- The captured Chromium CustomStateSet iterator remains live even after
		-- a done result; it can observe a subsequent add (unlike a JS Set).
		define(iterator,"next",native("next",0,function()while index<#data.StateEntries do index+=1;local entry=data.StateEntries[index];if entry.Active then local name=entry.Name;return vm.Object({done=false,value=if key=="entries"then vm.Array({name,name})else name})end end;return vm.Object({done=true,value=U})end));return iterator
	end))end
	define(stateProto,"keys",vm.Get(stateProto,"values"))
	vm.DefineProperty(stateProto,vm.SymbolIterator,vm.Object({value=vm.Get(stateProto,"values"),writable=true,configurable=true},N))
	define(stateProto,"forEach",native("forEach",1,function(args,self)local data=stateRecord(self);if not VM.callable(args[1])then fail("TypeError","forEach requires a callback")end;local index=0;while index<#data.StateEntries do index+=1;vm.Step();local entry=data.StateEntries[index];if entry.Active then vm:Call(args[1],{entry.Name,entry.Name,self},args[2]or U)end end;return U end))
	accessor(proto,"states",function(_,self)return record(self).StateSet end)
	function api:Attach(node)
		check();local definition=node.CustomElementDefinition
		if node.IsValue~=nil or not definition or definition.Name~=ElementNames.htmlName(node) or definition.DisableInternals or node.ElementInternalsData or(node.CustomElementState~="custom"and node.CustomElementState~="precustomized")then fail("NotSupportedError","Element internals cannot be attached to this element")end
		local value=vm.Object({},proto);local data={Node=node,Value=N,State=N,Flags={},Message="",Anchor=node,ARIA={},Relations={},States={},StateIndex={},StateEntries={},StateCount=0}
		data.StateSet=vm.Object({},stateProto);sets[data.StateSet]=data;records[value]=data;node.ElementInternalsData=data;node.CustomStates=data.States
		return value
	end
	function api:Get(node,key)
		if node.Kind=="Element"and key=="attachInternals"then return true,function()return self:Attach(node)end end
		return false,nil
	end
	function api:Destroy()
		self.Alive=false;for _,data in records do if data.Node.ElementInternalsData==data then data.Node.ElementInternalsData=nil;data.Node.CustomStates=nil end;table.clear(data)end;table.clear(records);table.clear(tracked);table.clear(sets);table.clear(validityRecords);table.clear(ctx)
	end
	return api
end
return ElementInternals
