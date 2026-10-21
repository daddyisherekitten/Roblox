--!strict
local Node = require(script.Parent.Parent.DOM.Node)
local ShadowTree = require(script.Parent.Parent.DOM.ShadowTree)
local Elements = require(script.Parent.Parent.HTML.Elements)
local ElementInternals = require(script.Parent.ElementInternals)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local AttributeStore=require(script.Parent.Parent.DOM.AttributeStore)
local CustomElements = {}
-- Registry identity survives adoption into another live document. Only host
-- records create this brand; author objects with copied fields cannot forge it.
local registryOwners=setmetatable({},{__mode="kv"})
local INTERFACES = {
	a="HTMLAnchorElement",area="HTMLAreaElement",audio="HTMLAudioElement",base="HTMLBaseElement",body="HTMLBodyElement",br="HTMLBRElement",button="HTMLButtonElement",canvas="HTMLCanvasElement",
	caption="HTMLTableCaptionElement",col="HTMLTableColElement",colgroup="HTMLTableColElement",data="HTMLDataElement",datalist="HTMLDataListElement",details="HTMLDetailsElement",dialog="HTMLDialogElement",div="HTMLDivElement",dl="HTMLDListElement",
	del="HTMLModElement",ins="HTMLModElement",embed="HTMLEmbedElement",fieldset="HTMLFieldSetElement",form="HTMLFormElement",h1="HTMLHeadingElement",h2="HTMLHeadingElement",h3="HTMLHeadingElement",h4="HTMLHeadingElement",h5="HTMLHeadingElement",h6="HTMLHeadingElement",
	head="HTMLHeadElement",hr="HTMLHRElement",html="HTMLHtmlElement",iframe="HTMLIFrameElement",img="HTMLImageElement",input="HTMLInputElement",label="HTMLLabelElement",legend="HTMLLegendElement",li="HTMLLIElement",link="HTMLLinkElement",
	map="HTMLMapElement",menu="HTMLMenuElement",meta="HTMLMetaElement",meter="HTMLMeterElement",object="HTMLObjectElement",ol="HTMLOListElement",optgroup="HTMLOptGroupElement",option="HTMLOptionElement",output="HTMLOutputElement",p="HTMLParagraphElement",
	pre="HTMLPreElement",progress="HTMLProgressElement",q="HTMLQuoteElement",blockquote="HTMLQuoteElement",script="HTMLScriptElement",select="HTMLSelectElement",slot="HTMLSlotElement",source="HTMLSourceElement",span="HTMLSpanElement",style="HTMLStyleElement",
	table="HTMLTableElement",tbody="HTMLTableSectionElement",thead="HTMLTableSectionElement",tfoot="HTMLTableSectionElement",td="HTMLTableCellElement",th="HTMLTableCellElement",template="HTMLTemplateElement",textarea="HTMLTextAreaElement",time="HTMLTimeElement",tr="HTMLTableRowElement",track="HTMLTrackElement",ul="HTMLUListElement",video="HTMLVideoElement",
}
local validName=ElementNames.custom
CustomElements.validName=validName

function CustomElements.install(vm: any, globals: any, ctx: any): any
	local VM, U, N = vm.Model, vm.Model.Undefined, vm.Model.Null
	local api = {Alive=true}
	local registries, activeDefinitions = {}, {}
	local globalRegistry, globalState, internals
	local prototypes, constructors = {}, {}
	local reactions, draining, constructing = {}, false, 0
	local foreignReactions={}
	local foreignInternals=setmetatable({},{__mode="k"})
	local function refreshInternals()
		internals:Refresh()
		for owner in foreignInternals do if owner.Alive then owner.Internals:Refresh();foreignReactions[owner]=true else foreignInternals[owner]=nil end end
	end
	local function registryState(value)
		local own=registries[value];if own then return own end
		local owner=registryOwners[value]
		return if owner and owner.Alive then owner:RegistryState(value)else nil
	end
	function api:RegistryState(value)return if self.Alive then registries[value]else nil end
	local function connected(node)return ShadowTree.Connected(node)end
	local function effectiveGlobal(registry)local state=registryState(registry);return if state and not state.Scoped then registry else nil end
	local function check()assert(api.Alive and vm.Alive,"Custom elements disposed")end
	local function fail(name: string, message: string)ctx.DOMError(name,message)end
	local function native(name: string,length: number,fn: any): any
		return {Kind="native-function",Values={name=name,length=length},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end}
	end
	local function define(target: any,key: any,value: any)
		vm.DefineProperty(target,key,vm.Object({value=value,writable=true,configurable=true},N))
	end
	local function global(name: string,value: any)globals[name]=value;vm.Global.Bindings[name]={Value=value}end
	local function walk(root: any,callback: any)
		local pending={root};while #pending>0 do
			vm.Step();local node=table.remove(pending);callback(node)
			for i=#node.Children,1,-1 do table.insert(pending,node.Children[i])end
			if node.InternalShadowRoot then table.insert(pending,node.InternalShadowRoot)end
		end
	end
	local function registryFor(node: any): any
		if node.CustomElementRegistryInitialized then return node.CustomElementRegistry end
		local root=ShadowTree.Root(node)
		if root.Kind=="ShadowRoot"and not root.CustomElementRegistryInitialized then root.CustomElementRegistry=if root.KeepCustomElementRegistryNull then nil else (root.OwnerDocument or ctx.Document).CustomElementRegistry;root.CustomElementRegistryInitialized=true end
		local registry=if root.Kind=="ShadowRoot"or root.Kind=="Document"then root.CustomElementRegistry elseif node.OwnerDocument then node.OwnerDocument.CustomElementRegistry else globalRegistry
		node.CustomElementRegistry=registry;node.CustomElementRegistryInitialized=true
		return registry
	end
	local function lookup(node: any,registry: any?): any
		local name=ElementNames.htmlName(node);if not name then return nil end
		if not node.CustomElementIsInitialized then node.IsValue=node.IsValue or node.Attributes.is;node.CustomElementIsInitialized=true end
		local state=registryState(registry or registryFor(node));if not state then return nil end
		local definition=state.Definitions[name]or(node.IsValue and state.Definitions[node.IsValue])
		return if definition and definition.LocalName==name then definition else nil
	end
	local function enqueue(node: any,name: string,args: any)
		local definition=node.CustomElementDefinition;local callback=definition and definition.Callbacks[name]
		if definition and definition.API~=api then local owner=definition.API;if owner and owner.Alive then foreignInternals[owner]=true;if callback then foreignReactions[owner]=true;owner.Reaction(node,name,args)end end;return end
		if callback then assert(#reactions<16384,"Custom element reaction budget exceeded");table.insert(reactions,{Node=node,Callback=callback,Args=args})end
	end
	api.Reaction=enqueue
	function api:Drain()
		if draining or constructing>0 or not self.Alive then return end;draining=true
		local index=1
		while index<=#reactions and self.Alive do
			local reaction=reactions[index];index+=1
			if reaction.Node.CustomElementState=="custom"then
				local ok,message=pcall(vm.Call,vm,reaction.Callback,reaction.Args,ctx.Wrap(reaction.Node))
				if not ok and ctx.Report then ctx.Report(message)end
			end
		end
		table.clear(reactions);draining=false
		local pending=foreignReactions;foreignReactions={};for owner in pending do if owner.Alive then owner:Drain()end end
	end
	local function htmlConstructor(interface: string,newTarget: any): any
		if newTarget==constructors[interface]then fail("TypeError","Illegal HTML element constructor")end
		local definition=activeDefinitions[newTarget]or globalState.Constructors[newTarget]
		if not definition then fail("TypeError","Illegal HTML element constructor")end
		local wanted=if definition.Name==definition.LocalName then "HTMLElement"else INTERFACES[definition.LocalName]or"HTMLElement"
		if wanted~=interface then fail("TypeError","Custom element extends an incompatible HTML interface")end
		local top=definition.Stack[#definition.Stack]
		local node
		if top then
			if top.Constructed then fail("TypeError","The element has already been constructed")end
			top.Constructed=true;node=top.Node
		else
			node=ctx.Allocate(Node.element(definition.LocalName,{}));node.IsValue=if definition.LocalName~=definition.Name then definition.Name else nil
			node.CustomElementDefinition=definition;node.CustomElementState="custom";node.CustomElementConnected=false
			node.CustomElementRegistry=definition.Registry;node.CustomElementRegistryInitialized=true
			internals:RefreshNode(node)
		end
		local target=ctx.Wrap(node);local proto=vm.Get(newTarget,"prototype")
		if not vm.ObjectModel.IsObject(proto)then proto=prototypes[interface]end
		vm.SetPrototype(target,proto)
		return target
	end
	local function interface(name: string,parent: any,constructible: boolean?)
		if constructors[name]then return constructors[name]end
		local proto=vm.Object({},parent or vm.Prototypes.Object);prototypes[name]=proto
		local ctor=native(name,0,function()fail("TypeError","HTML constructors require new")end)
		ctor.Construct=function(_,newTarget)
			check();if not constructible then fail("TypeError","Illegal "..name.." constructor")end
			return htmlConstructor(name,newTarget or ctor)
		end
		vm.DefineProperty(ctor,"prototype",vm.Object({value=proto},N));define(proto,"constructor",ctor)
		if vm.SymbolToStringTag then vm.DefineProperty(proto,vm.SymbolToStringTag,vm.Object({value=name,configurable=true},N))end
		constructors[name]=ctor;global(name,ctor);return ctor
	end
	interface("Node",vm.Get(globals.EventTarget,"prototype"))
	interface("Element",prototypes.Node)
	interface("HTMLElement",prototypes.Element,true)
	interface("HTMLMediaElement",prototypes.HTMLElement)
	for _,name in INTERFACES do interface(name,if name=="HTMLAudioElement"or name=="HTMLVideoElement"then prototypes.HTMLMediaElement else prototypes.HTMLElement,true)end
	interface("HTMLUnknownElement",prototypes.HTMLElement)
	interface("Document",prototypes.Node);interface("HTMLDocument",prototypes.Document)
	interface("DocumentFragment",prototypes.Node);interface("ShadowRoot",prototypes.DocumentFragment)
	interface("CharacterData",prototypes.Node);interface("Text",prototypes.CharacterData);interface("Comment",prototypes.CharacterData)
	for key,value in {ELEMENT_NODE=1,TEXT_NODE=3,COMMENT_NODE=8,DOCUMENT_NODE=9,DOCUMENT_FRAGMENT_NODE=11}do define(constructors.Node,key,value);define(prototypes.Node,key,value)end
	local function receiverNode(value: any,kind: string?): any
		local node=ctx.Unwrap(value);if kind and node.Kind~=kind then fail("TypeError","Incompatible DOM interface receiver")end;return node
	end
	local function methods(proto: any,names: string,kind: string?,interfaceName: string?)
		for key in names:gmatch("%S+")do define(proto,key,native(key,0,function(args,self)
			local node=receiverNode(self,kind);local method=ctx.NativeGet(node,key)
			if interfaceName and INTERFACES[ElementNames.htmlName(node)]~=interfaceName then fail("TypeError","Incompatible HTML interface receiver")end
			if not VM.callable(method)then fail("TypeError","Incompatible DOM method receiver")end
			if type(method)=="function"then return method(args,self)else return vm:Call(method,args,self)end
		end))end
	end
	methods(prototypes.Node,"appendChild insertBefore replaceChild removeChild cloneNode contains getRootNode isSameNode isEqualNode compareDocumentPosition normalize hasChildNodes")
	methods(prototypes.Element,"attachShadow matches closest getAttribute hasAttribute hasAttributes getAttributeNames setAttribute removeAttribute toggleAttribute insertAdjacentHTML insertAdjacentText insertAdjacentElement querySelector querySelectorAll append prepend replaceChildren before after replaceWith remove","Element")
	methods(prototypes.HTMLElement,"click focus blur showPopover hidePopover togglePopover attachInternals","Element")
	methods(prototypes.HTMLDialogElement,"show showModal close requestClose","Element","HTMLDialogElement")
	methods(prototypes.HTMLSlotElement,"assignedNodes assignedElements assign","Element","HTMLSlotElement")
	methods(prototypes.DocumentFragment,"querySelector querySelectorAll append prepend replaceChildren")
	methods(prototypes.HTMLTableElement,"createCaption deleteCaption createTHead deleteTHead createTFoot deleteTFoot createTBody insertRow deleteRow","Element","HTMLTableElement")
	methods(prototypes.HTMLTableSectionElement,"insertRow deleteRow","Element","HTMLTableSectionElement")
	methods(prototypes.HTMLTableRowElement,"insertCell deleteCell","Element","HTMLTableRowElement")
	local function properties(interfaceName: string,read: string,write: string?)
		local writable={};for key in(write or ""):gmatch("%S+")do writable[key]=true end
		for key in read:gmatch("%S+")do
			local function brand(self)local node=receiverNode(self,"Element");if INTERFACES[ElementNames.htmlName(node)]~=interfaceName then fail("TypeError","Incompatible HTML interface receiver")end;return node end
			vm.DefineProperty(prototypes[interfaceName],key,vm.Object({
				get=native("get "..key,0,function(_,self)return ctx.NativeGet(brand(self),key)end),
				set=if writable[key]then native("set "..key,1,function(args,self)ctx.NativeSet(brand(self),key,if args[1]~=nil then args[1]else U);return U end)else U,
				enumerable=true,configurable=true},N))
		end
	end
	properties("HTMLTableElement","caption tHead tFoot tBodies rows","caption tHead tFoot")
	properties("HTMLTableSectionElement","rows")
	properties("HTMLTableRowElement","cells rowIndex sectionRowIndex")
	properties("HTMLTableCellElement","cellIndex colSpan rowSpan headers scope abbr","colSpan rowSpan headers scope abbr")
	properties("HTMLTableColElement","span","span")
	properties("HTMLOListElement","start reversed type","start reversed type")
	properties("HTMLLIElement","value type","value type")
	function api:Prototype(node: any): any
		if node.CustomElementDefinition and node.CustomElementState=="custom"then return vm.Get(node.CustomElementDefinition.Constructor,"prototype")end
		if node.Kind=="Element"then
			if node.NamespaceURI and node.NamespaceURI~="http://www.w3.org/1999/xhtml"then return prototypes.Element end
			if node.CustomElementState=="failed"then return prototypes.HTMLUnknownElement end
			local name=node.LocalName or node.Name
			return prototypes[INTERFACES[name]or(if name~="svg"and name~="math"and Elements[name]or validName(name)then"HTMLElement"else"HTMLUnknownElement")]
		end
		if node.Kind=='Document'and node.PlainDocument then return prototypes.Document end
		if node.Kind=="Document"and node.IsHTML==false and globals.XMLDocument then return vm.Get(globals.XMLDocument,"prototype")end
		return prototypes[if node.Kind=="Document"then"HTMLDocument"else node.Kind]or prototypes.Node
	end
	local function upgrade(node: any,definition: any)
		if definition.API~=api then local owner=definition.API;if owner and owner.Alive then foreignInternals[owner]=true;foreignReactions[owner]=true;owner:UpgradeElement(node,definition)end;return end
		if node.CustomElementState and node.CustomElementState~="undefined"and node.CustomElementState~="uncustomized"then return end
		node.CustomElementDefinition=definition;node.CustomElementState="precustomized"
		local isConnected=connected(node)
		local checkpoint=#reactions
		for _,key in ctx.Markup.attributeNames(node)do
			local info=node.AttributeNamespaces and node.AttributeNamespaces[key];local name=info and info.LocalName or key
			if definition.Observed[name]then enqueue(node,"attributeChangedCallback",{name,N,node.Attributes[key],AttributeStore.namespace(node,key)or N})end
		end
		if isConnected then enqueue(node,"connectedCallback",{})end
		local frame={Node=node,Constructed=false};table.insert(definition.Stack,frame)
		local previousDefinition=activeDefinitions[definition.Constructor];activeDefinitions[definition.Constructor]=definition
		constructing+=1
		local ok,value=pcall(function()
			if definition.DisableShadow and node.InternalShadowRoot then fail("NotSupportedError","Shadow trees are disabled for this custom element")end
			return vm:Construct(definition.Constructor,{},definition.Constructor)
		end)
		constructing-=1
		activeDefinitions[definition.Constructor]=previousDefinition
		table.remove(definition.Stack)
		if ok and (value~=ctx.Wrap(node)or not frame.Constructed)then ok=false;value=VM.error("TypeError","Custom constructor must return its element")end
		if not ok then
			node.CustomElementState="failed"
			for i=#reactions,checkpoint+1,-1 do if reactions[i].Node==node then table.remove(reactions,i)end end
			if ctx.Report then ctx.Report(value)end;return
		end
		node.CustomElementState="custom";node.CustomElementConnected=isConnected
		internals:RefreshNode(node)
	end
	function api:UpgradeElement(node,definition)upgrade(node,definition)end
	function api:Created(node: any,synchronous: boolean?)
		local definition=lookup(node)
		if definition then
			upgrade(node,definition)
			if synchronous and definition.Name==definition.LocalName and node.CustomElementState=="custom"and(next(node.Attributes)~=nil or #node.Children>0 or node.Parent~=nil)then
				node.CustomElementState="failed";node.CustomElementDefinition=nil
				if ctx.Report then ctx.Report(VM.error("NotSupportedError","A new custom element constructor cannot add attributes or light children"))end
			end
		end
		self:Drain()
	end
	function api:ParserCreated(node: any,parent: any)
		self:PrepareTree(node,parent)
		local definition=lookup(node);if not definition then return end
		local attributes,order=node.Attributes,node.AttributeOrder
		node.IsValue=node.IsValue or attributes.is
		node.Attributes,node.AttributeOrder={},{}
		local document=node.OwnerDocument or ctx.Document
		document.ThrowOnDynamicMarkupInsertion=(document.ThrowOnDynamicMarkupInsertion or 0)+1
		local ok,message=pcall(function()
			self:Created(node,true)
			node.Attributes,node.AttributeOrder=attributes,order
			-- Attributes exist together before reactions; the parser has not
			-- inserted the element or processed its light children yet.
			for _,name in order or{}do local info=node.AttributeNamespaces and node.AttributeNamespaces[name];self:AttributeChanged(node,info and info.LocalName or name,attributes[name],nil,AttributeStore.namespace(node,name))end
		end)
		node.Attributes,node.AttributeOrder=attributes,order
		document.ThrowOnDynamicMarkupInsertion-=1
		if not ok then error(message,0)end
	end
	function api:UpgradeTree(root: any)
		walk(root,function(node)local definition=lookup(node);if definition then upgrade(node,definition)end end)
	end
	function api:PrepareTree(root: any,context: any)
		local registry=registryFor(context)
		walk(root,function(node)if node.Kind=="Element"and not node.CustomElementRegistryInitialized then self:SetRegistry(node,registry or N)end end)
	end
	function api:Cloned(node: any,source: any)
		node.IsValue=source.IsValue;node.CustomElementIsInitialized=true
		local registry=registryFor(source);local state=registryState(registry)
		if(source.OwnerDocument and source.OwnerDocument.InertTemplateDocument)or(state and not state.Scoped)then registry=effectiveGlobal((node.OwnerDocument or ctx.Document).CustomElementRegistry)end
		self:SetRegistry(node,registry or N)
	end
	function api:CloneFinished(node: any)
		-- DOM cloning uses a nonsynchronous create-element step. Upgrade after
		-- copying attributes and a clonable shadow tree, so the constructor sees
		-- the same existing root and observed-attribute reactions as HTML.
		local root=node.InternalShadowRoot
		if root then local registry=root.CustomElementRegistry;local state=registryState(registry);if state and not state.Scoped then self:SetRegistry(root,effectiveGlobal((node.OwnerDocument or ctx.Document).CustomElementRegistry)or N)end end
		local definition=lookup(node);if definition then upgrade(node,definition)end
	end
	function api:Mutation(record: any)
		if record.Type~="childList"then return end
		if record.Move then
			-- A state-preserving move skips connection reactions. Form ownership
			-- still resets at detachment, as in the captured Chromium profile.
			if #(record.RemovedNodes or {})>0 then refreshInternals()end
			for _,root in record.AddedNodes or {}do self:Moved(root)end
			return
		end
		for _,root in record.RemovedNodes or {}do walk(root,function(node)
			if node.CustomElementState=="custom"and node.CustomElementConnected then node.CustomElementConnected=false;enqueue(node,"disconnectedCallback",{})end
		end)end
		for _,root in record.AddedNodes or {}do
			self:UpgradeTree(root)
			walk(root,function(node)
				if node.CustomElementState=="custom"and connected(node)and not node.CustomElementConnected then node.CustomElementConnected=true;enqueue(node,"connectedCallback",{})end
			end)
		end
		refreshInternals()
	end
	function api:AttributeChanged(node: any,name: string,value: any,oldValue: any,namespace: string?)
		if node.CustomElementState=="custom"and node.CustomElementDefinition.Observed[name]then enqueue(node,"attributeChangedCallback",{name,oldValue or N,value or N,namespace or N})end
		if not namespace and(name=="id"or name=="form"or name=="disabled"or name=="readonly")then refreshInternals()end
		self:Drain()
	end
	local registryPrototype=vm.Object({})
	local function receiver(value: any)local state=registryState(value);if not state then fail("TypeError","Illegal CustomElementRegistry receiver")end;return state end
	local function makeRegistry(scoped: boolean)
		local registry=vm.Object({},registryPrototype);registries[registry]={Definitions={},Waiting={},Defining=false,Scoped=scoped,Documents=setmetatable({[ctx.Document]=true},{__mode="k"}),Constructors={}};registryOwners[registry]=api
		return registry,registries[registry]
	end
	globalRegistry,globalState=makeRegistry(false)
	ctx.Document.CustomElementRegistry=globalRegistry
	local internalContext=table.clone(ctx);internalContext.Reaction=enqueue;internalContext.Drain=function()api:Drain()end
	internals=ElementInternals.install(vm,globals,internalContext);api.Internals=internals
	local function argument(args: any,i: number): any return if args[i]~=nil then args[i]else U end
	local function text(value: any): string return ctx.ReflectedString(value)end
	local function dict(value: any): any if value==N or value==U then return nil end;if not vm.ObjectModel.IsObject(value)then fail("TypeError","Expected options dictionary")end;return value end
	define(registryPrototype,"define",native("define",2,function(args,self)
		local state=receiver(self);local definitions=state.Definitions;if #args<2 then fail("TypeError","define requires name and constructor")end
		local name,ctor=text(args[1]),args[2]
		if not vm.IsConstructor(ctor)then fail("TypeError","Custom element constructor is not constructible")end
		if not validName(name)then fail("SyntaxError","Invalid custom element name")end
		if definitions[name]or state.Constructors[ctor]then fail("NotSupportedError","Custom element name or constructor already defined")end
		local init=dict(argument(args,3));local extends=if init then vm.Get(init,"extends")else U
		local localName=if extends~=U then text(extends)else name
		-- Scoped customized built-ins are accepted by the captured Chromium 154
		-- profile, although the current HTML text rejects this extends option.
		if extends~=U and (validName(localName)or not Elements[localName]or localName=="svg"or localName=="math")then fail("NotSupportedError","Invalid built-in custom element base")end
		if state.Defining then fail("NotSupportedError","A custom element definition is already running")end
		state.Defining=true
		local ok,definition=pcall(function()
			local proto=vm.Get(ctor,"prototype");if not vm.ObjectModel.IsObject(proto)then fail("TypeError","Custom element prototype must be an object")end
			local callbacks={}
			for _,key in {"connectedCallback","disconnectedCallback","connectedMoveCallback","adoptedCallback","attributeChangedCallback"}do
				local callback=vm.Get(proto,key);if callback~=U then if not VM.callable(callback)then fail("TypeError","Lifecycle callback is not callable")end;callbacks[key]=callback end
			end
			local observed={}
			if callbacks.attributeChangedCallback then
				local values=vm.Get(ctor,"observedAttributes");if values~=U then local iterator=vm.Iterator(values);while true do local more,value=iterator();if not more then break end;vm.Step();observed[text(value)]=true end end
			end
			local disableShadow,disableInternals=false,false;local disabled=vm.Get(ctor,"disabledFeatures")
			if disabled~=U then local iterator=vm.Iterator(disabled);while true do local more,value=iterator();if not more then break end;vm.Step();local feature=text(value);if feature=="shadow"then disableShadow=true elseif feature=="internals"then disableInternals=true end end end
			local formAssociated=VM.truth(vm.Get(ctor,"formAssociated"))
			if formAssociated then for _,key in {"formAssociatedCallback","formResetCallback","formDisabledCallback","formStateRestoreCallback"}do local callback=vm.Get(proto,key);if callback~=U then if not VM.callable(callback)then fail("TypeError","Lifecycle callback is not callable")end;callbacks[key]=callback end end end
			return {Name=name,LocalName=localName,Constructor=ctor,Callbacks=callbacks,Observed=observed,Stack={},DisableShadow=disableShadow,DisableInternals=disableInternals,FormAssociated=formAssociated,Registry=self,API=api}
		end)
		state.Defining=false;if not ok then error(definition,0)end
		definitions[name]=definition;state.Constructors[ctor]=definition
		for document in state.Documents do walk(document,function(node)if node.Kind=="Element"and registryFor(node)==self then local found=lookup(node,self);if found then upgrade(node,found)end end end)end;api:Drain()
		local capability=state.Waiting[name];if capability then state.Waiting[name]=nil;capability.Resolve({ctor})end
		return U
	end))
	define(registryPrototype,"get",native("get",1,function(args,self)local state=receiver(self);if #args<1 then fail("TypeError","get requires a name")end;local definition=state.Definitions[text(args[1])];return if definition then definition.Constructor else U end))
	define(registryPrototype,"getName",native("getName",1,function(args,self)local state=receiver(self);if #args<1 or not vm.IsConstructor(args[1])then fail("TypeError","getName requires a constructor")end;local definition=state.Constructors[args[1]];return if definition then definition.Name else N end))
	define(registryPrototype,"whenDefined",native("whenDefined",1,function(args,self)
		local state=receiver(self);local definitions,waiting=state.Definitions,state.Waiting;if #args<1 then fail("TypeError","whenDefined requires a name")end
		local name=text(args[1]);if waiting[name]then return waiting[name].Promise end
		local promise,resolve,reject=ctx.CreatePromise()
		if not validName(name)then reject({ctx.Events:DOMException("Invalid custom element name","SyntaxError")})
		elseif definitions[name]then resolve({definitions[name].Constructor})
		else waiting[name]={Promise=promise,Resolve=resolve,Reject=reject}end
		return promise
	end))
	define(registryPrototype,"upgrade",native("upgrade",1,function(args,self)
		receiver(self);if #args<1 then fail("TypeError","upgrade requires a root")end;walk(ctx.Unwrap(args[1]),function(node)if node.Kind=="Element"and registryFor(node)==self then local definition=lookup(node,self);if definition then upgrade(node,definition)end end end);api:Drain();return U
	end))
	define(registryPrototype,"initialize",native("initialize",1,function(args,self)
		local state=receiver(self);if #args<1 then fail("TypeError","initialize requires a root")end;local root=ctx.Unwrap(args[1]);local document=if root.Kind=="Document"then root else root.OwnerDocument or ctx.Document
		if not state.Scoped and(root.Kind=="Document"or document.CustomElementRegistry~=self)then fail("NotSupportedError","Global registry cannot initialize this root")end
		local stack={root};while #stack>0 do local node=table.remove(stack);vm.Step();if node.Kind=="Document"or node.Kind=="ShadowRoot"or node.Kind=="Element"then if node.CustomElementRegistry==nil then node.CustomElementRegistry=self;node.CustomElementRegistryInitialized=true end end;for i=#node.Children,1,-1 do table.insert(stack,node.Children[i])end end
		state.Documents[document]=true;api:UpgradeTree(root);api:Drain();return U
	end))
	function api:SetRegistry(node,value)
		local state=if value~=N then registryState(value)else nil
		if value~=N and not state then fail("TypeError","Expected a CustomElementRegistry")end
		node.CustomElementRegistry=if value==N then nil else value;node.CustomElementRegistryInitialized=true
		if state then state.Documents[node.OwnerDocument or ctx.Document]=true end
	end
	function api:ValidateRegistry(value,node)
		local state=if value~=N then registryState(value)else nil
		if value~=N and not state then fail("TypeError","Expected a CustomElementRegistry")end
		if state and not state.Scoped and value~=(node.OwnerDocument or ctx.Document).CustomElementRegistry then fail("NotSupportedError","Global registry belongs to another document")end
	end
	function api:GetRegistry(node)return registryFor(node)or N end
	function api:Reassociate(node,document,oldShadowRegistries)
		if node.Kind~="Element"and node.Kind~="ShadowRoot"then return end
		local registry=node.CustomElementRegistry;local state=registryState(registry)
		if state and state.Scoped then state.Documents[document]=true;return end
		if node.Kind=="ShadowRoot"then
			if registry~=nil or not node.KeepCustomElementRegistryNull then self:SetRegistry(node,effectiveGlobal(document.CustomElementRegistry)or N)end
		else
			if registry~=nil or node.Parent==nil or node.Parent.Kind=="DocumentFragment"then registry=document.CustomElementRegistry
			else
				local root=ShadowTree.Root(node.Parent);local previous=oldShadowRegistries and oldShadowRegistries[root]
				-- Chromium's adopted null-registry descendants use the shadow
				-- registry from before adoption, even when their root gains the
				-- destination global registry. Keep this snapshot operation-local.
				registry=if previous then previous.Value elseif root.Kind=="ShadowRoot"then root.CustomElementRegistry else document.CustomElementRegistry
			end
			self:SetRegistry(node,effectiveGlobal(registry)or N)
		end
	end
	function api:Get(node,key)
		if key=="customElementRegistry"and(node.Kind=="Element"or node.Kind=="Document"or node.Kind=="ShadowRoot")then return true,self:GetRegistry(node)end
		local definition=node.CustomElementDefinition;if definition and definition.API~=api and definition.API.Alive then return definition.API:Get(node,key)end
		return internals:Get(node,key)
	end
	function api:Adopted(node,oldDocument,newDocument)
		if node.CustomElementState=="custom"then enqueue(node,"adoptedCallback",{ctx.Wrap(oldDocument),ctx.Wrap(newDocument)});internals:RefreshNode(node)end
	end
	function api:Moved(node)
		walk(node,function(child)if child.CustomElementState=="custom"and connected(child)then if child.CustomElementDefinition.Callbacks.connectedMoveCallback then enqueue(child,"connectedMoveCallback",{})else enqueue(child,"disconnectedCallback",{});enqueue(child,"connectedCallback",{})end end end);refreshInternals()
	end
	global("customElements",globalRegistry)
	local registryConstructor=native("CustomElementRegistry",0,function()fail("TypeError","CustomElementRegistry requires new")end)
	registryConstructor.Construct=function()return makeRegistry(true)end
	vm.DefineProperty(registryConstructor,"prototype",vm.Object({value=registryPrototype},N));define(registryPrototype,"constructor",registryConstructor);global("CustomElementRegistry",registryConstructor)
	if vm.SymbolToStringTag then vm.DefineProperty(registryPrototype,vm.SymbolToStringTag,vm.Object({value="CustomElementRegistry",configurable=true},N))end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false;internals:Destroy();for registry,state in registries do registryOwners[registry]=nil;table.clear(state.Definitions);table.clear(state.Constructors);table.clear(state.Waiting);table.clear(state.Documents)end;table.clear(registries);table.clear(activeDefinitions);table.clear(reactions);table.clear(foreignReactions);table.clear(foreignInternals);table.clear(ctx)
	end
	return api
end
return CustomElements
