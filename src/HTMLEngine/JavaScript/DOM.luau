--!strict
-- Stable wrappers over the existing HTML DOM. No Roblox instances escape to JS.
local Node = require(script.Parent.Parent.DOM.Node)
local Template=require(script.Parent.Parent.DOM.TemplateDocument)
local Selectors = require(script.Parent.Parent.CSS.Selectors)
local Style = require(script.Parent.Style)
local VM = require(script.Parent.VM)
local Strings = require(script.Parent.Strings)
local Tree = require(script.Parent.DOMTree)
local Markup = require(script.Parent.DOMMarkup)
local Controls = require(script.Parent.DOMControls)
local Queries = require(script.Parent.DOMQueries)
local Tables = require(script.Parent.DOMTables)
local Lists = require(script.Parent.DOMLists)
local ShadowDOM = require(script.Parent.ShadowDOM)
local ShadowTree = require(script.Parent.Parent.DOM.ShadowTree)
local Names=require(script.Parent.DOMNames)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local Documents=require(script.Parent.DOMDocuments)
local Reflection=require(script.Parent.DOMReflection)
local Attributes=require(script.Parent.DOMAttributes)
local Interfaces=require(script.Parent.DOMInterfaces)
local XML=require(script.Parent.DOMXML)
local XMLSerialization=require(script.Parent.XMLSerialization)
local HTMLParser=require(script.Parent.Parent.HTML.Parser)
local Details=require(script.Parent.Parent.DOM.DetailsState)
local Language=require(script.Parent.Parent.DOM.DocumentLanguage)
local DocumentInfo=require(script.Parent.Parent.HTML.DocumentInfo)
local FormOwner=require(script.Parent.Parent.DOM.FormOwner)
local AttributeStore=require(script.Parent.Parent.DOM.AttributeStore)
local SourceDocument=require(script.Parent.Parent.DOM.MediaSourceDocument)
local DOM = {}
-- Trusted wrappers cannot be forged by an author copying the DOMNode field.
-- A node retains its original realm's wrapper after cross-document adoption.
local canonical=setmetatable({},{__mode="kv"})
-- Luau weak keys are not ephemerons: a strong bridge value reaches its wrapper
-- keys. Weak values avoid retaining an entire disposed document cycle.
local origins=setmetatable({},{__mode="kv"})
local documents=setmetatable({},{__mode="kv"})
local xmlSerializers=setmetatable({},{__mode="k"})
local NODE_CONSTANTS={ELEMENT_NODE=1,TEXT_NODE=3,CDATA_SECTION_NODE=4,PROCESSING_INSTRUCTION_NODE=7,COMMENT_NODE=8,DOCUMENT_NODE=9,DOCUMENT_TYPE_NODE=10,DOCUMENT_FRAGMENT_NODE=11,
	DOCUMENT_POSITION_DISCONNECTED=1,DOCUMENT_POSITION_PRECEDING=2,DOCUMENT_POSITION_FOLLOWING=4,
	DOCUMENT_POSITION_CONTAINS=8,DOCUMENT_POSITION_CONTAINED_BY=16,DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC=32}
local READ_ONLY={parentNode=true,parentElement=true,ownerDocument=true,nodeType=true,nodeName=true,baseURI=true,isConnected=true,
	childNodes=true,children=true,firstChild=true,lastChild=true,nextSibling=true,previousSibling=true,
	nextElementSibling=true,previousElementSibling=true,firstElementChild=true,lastElementChild=true,childElementCount=true,
	tagName=true,localName=true,namespaceURI=true,prefix=true,dataset=true,content=true,attributes=true,areas=true,length=true,wholeText=true,isContentEditable=true,
	readyState=true,visibilityState=true,currentScript=true,defaultView=true,documentElement=true,head=true,activeElement=true,timeline=true,doctype=true,compatMode=true,contentType=true,characterSet=true,charset=true,inputEncoding=true,implementation=true,name=true,publicId=true,systemId=true,target=true}
function DOM.new(document: any, host: any): any
	Template.assign(document,document)
	SourceDocument.observe(document,DocumentInfo.baseURL(document,host.URL,true),host.URL or document.URL)
	-- Nodes own their realm wrappers. The bridge only indexes them weakly:
	-- a strong cache would keep every removed subtree alive for the whole page.
	local wrappers=setmetatable({},{__mode="kv"})
	local readers=setmetatable({},{__mode="kv"})
	local listeners, wrap, createWrapper = {}, nil, nil
	local eventWrappers=setmetatable({},{__mode="kv"})
	local bridge={Alive=true,Host=host};documents[document]=bridge
	if document.TemplateContentsDocument then documents[document.TemplateContentsDocument]=bridge end
	local function ownerBridge(node)
		local doc=if node.Kind=="Document"then node else node.OwnerDocument
		return (doc and documents[doc])or bridge
	end
	local realmVM
	local function symbol(key,name)return realmVM and key==realmVM[name]end
	local function isSymbol(key)return type(key)=="table"and key.Kind=="symbol"end
	local controlBridge
	local traversalBridge
	local rangeBridge
	local shadowBridge, customBridge, tableBridge, listBridge, documentBridge, reflectionBridge, attributeBridge
	local queryRevision=0;local queryOwner={}
	-- The token identifies an invalidation scope without retaining its realm.
	bridge.QueryRevision=function()return queryRevision,queryOwner end
	local attribute
	local disclosures=Details.new({Attribute=function(...)return attribute(...)end,Step=host.Step})
	bridge.Details=disclosures
	local previousMutation=host.Mutation
	host.Mutation=function(record)
		local key=if record.Type=="attributes"then AttributeStore.expanded(record.Target,Names.namespace(record.AttributeNamespace),record.AttributeName)else nil
		local changed=if record.Type=="attributes"then record.OldValue~=(if key then record.Target.Attributes[key]else nil)
			elseif record.Type=="characterData"then record.OldValue~=record.Target.Text
			else #(record.AddedNodes or {})>0 or #(record.RemovedNodes or {})>0
		if changed then queryRevision+=1 end
		if documentBridge then documentBridge:Mutation(record)end
		if record.Type=='childList'and record.Move then
			for _,node in record.AddedNodes or{}do FormOwner.afterMove(node)end
		end
		if changed and documentBridge then documentBridge.NamedProperties:Mutation(record)end
		if record.Type=='childList'and #(record.AddedNodes or{})>0 then
			Language.inserted(record.AddedNodes,function(changedDocument)
				queryRevision+=1
				if changedDocument==document then host.Changed(document,'language')end
			end,host.Step)
		end
		if previousMutation then previousMutation(record)end
		if record.Type=="childList" and #(record.AddedNodes or {})>0 then disclosures:Inserted(record.AddedNodes)end
		if shadowBridge then shadowBridge:Mutation(record)end
		if customBridge then customBridge:Mutation(record)end
	end
	local previousBeforeRemove=host.BeforeRemove
	host.BeforeRemove=function(node,preservingMove)
		FormOwner.beforeRemove(node,preservingMove)
		if not preservingMove then
			if traversalBridge then traversalBridge:BeforeRemove(node)end
			if rangeBridge then rangeBridge:BeforeRemove(node)end
		end
		if previousBeforeRemove then previousBeforeRemove(node,preservingMove)end
	end
	local previousBeforeInsert=host.BeforeInsert
	host.BeforeInsert=function(parent,index,count)
		if rangeBridge then rangeBridge:BeforeInsert(parent,index,count)end
		if previousBeforeInsert then previousBeforeInsert(parent,index,count)end
	end
	local created=0
	local function allocate(node,owner)
		if node.DOMAllocatedBridge~=bridge then created+=1;assert(created<=8192,"Created DOM node budget exceeded");node.DOMAllocatedBridge=bridge end
		if node.Kind ~= "Document" then
			node.OwnerDocument = owner or document
			if node.OwnerDocument.InertTemplateDocument and not documents[node.OwnerDocument]then documents[node.OwnerDocument]=bridge end
		else documents[node]=bridge end
		return node
	end
	local function check() assert(bridge.Alive,"Document has been disposed") end
	local function domError(name,message) VM.throw(VM.error(name,message)) end
	local function serializationError(message)
		VM.throw(if host.DOMException then host.DOMException(message,"InvalidStateError")else VM.error("InvalidStateError",message))
	end
	local function serialized(node,childrenOnly)
		local ok,value=pcall(Markup.serialize,node,childrenOnly)
		if not ok then serializationError(tostring(value))end
		return value
	end
	local function requireArgs(args,count)
		if #args<count then domError("TypeError","Not enough arguments for DOM method") end
	end
	local function uint(value)
		local n=VM.number(value)
		if n~=n or n==math.huge or n==-math.huge or n==0 then return 0 end
		return (if n<0 then math.ceil(n) else math.floor(n))%4294967296
	end
	local function reflectedString(value,wellFormed)
		local primitive=if realmVM then realmVM.ToPrimitive(value,"string")else value
		if type(primitive)=="table"and primitive.Kind=="symbol"then domError("TypeError","Cannot convert Symbol to DOMString")end
		local text=VM.string(primitive)
		if not wellFormed then return text end
		local parts={};for code in Strings.codes(text)do table.insert(parts,utf8.char(if code>=0xd800 and code<=0xdfff then 0xfffd else code))end
		return table.concat(parts)
	end
	local function array(values) return {Kind="array",Items=values,Length=#values,Properties={}} end
	local function plain(values) return {Kind="object",Values=values,Get=function(key)return if values[key]~=nil then values[key] else VM.Undefined end} end
	local function iterator(entries,kind,mapper)
		local index,done=0,false;local result
		local function nextValue()
			check();if done then return false,VM.Undefined end
			local values=entries();index+=1
			if index>#values then done=true;return false,VM.Undefined end
			local value=values[index]
			if mapper and kind~="keys"then value=mapper(value)end
			return true,if kind=="keys" then index-1 elseif kind=="entries" then array({index-1,value}) else value
		end
		local nextMethod=function()local exists,value=nextValue();return plain({done=not exists,value=value})end
		result={Iterator=function()return nextValue end,Get=function(key)
			if key=="next" then return nextMethod end
			if symbol(key,"SymbolIterator")then return function()return result end end
			return VM.Undefined
		end};return result
	end
	local function connected(node)
		return ShadowTree.Connected(node,document)
	end
	attribute=function(node,key,value,namespace,newNamespaceInfo,incomingAttr)
		local destination=ownerBridge(node);if destination~=bridge then return destination.Attribute(node,key,value,namespace,newNamespaceInfo,incomingAttr)end
		check();key=if not newNamespaceInfo and not AttributeStore.namespace(node,key)and not key:find('\0',1,true)and Queries.namespace(node)==Names.HTML and(node.OwnerDocument or document).IsHTML~=false then key:lower()else key
		local actualName=if newNamespaceInfo then newNamespaceInfo.QualifiedName or(if newNamespaceInfo.Prefix then newNamespaceInfo.Prefix..':'..newNamespaceInfo.LocalName else newNamespaceInfo.LocalName)else AttributeStore.name(node,key)
		if not Names.validAttribute(actualName) then domError("InvalidCharacterError","Invalid attribute name") end
		assert(value==nil or #value<=65536,"Attribute budget exceeded")
		local oldValue=node.Attributes[key]
		local namespaceInfo=node.AttributeNamespaces and node.AttributeNamespaces[key]
		local attributeNamespace=if newNamespaceInfo then newNamespaceInfo.Namespace else namespace or(namespaceInfo and namespaceInfo.Namespace)
		local localName=(newNamespaceInfo or namespaceInfo)and(newNamespaceInfo or namespaceInfo).LocalName or key
		if host.ValidateDataAttribute and not attributeNamespace then host.ValidateDataAttribute(node,key,value)end
		if oldValue~=value and host.ValidateAttribute and not attributeNamespace and connected(node) then host.ValidateAttribute(node,key,value) end
		if incomingAttr then
			node.AttributeNodes=node.AttributeNodes or{}
			local previous=node.AttributeNodes[key]
			if previous then previous.Text=oldValue;previous.OwnerElement=nil;previous.StorageKey=nil end
			node.AttributeNodes[key]=incomingAttr
			incomingAttr.OwnerElement=node;incomingAttr.StorageKey=key;incomingAttr.OwnerDocument=node.OwnerDocument
		end
		if oldValue==value then
			if value~=nil then
				SourceDocument.write(node,localName,value,attributeNamespace,node.OwnerDocument or document)
				if not attributeNamespace then FormOwner.attributeChanged(node,key)end
				if newNamespaceInfo then node.AttributeNamespaces=node.AttributeNamespaces or{};node.AttributeNamespaces[key]=newNamespaceInfo end
				if controlBridge and not attributeNamespace then controlBridge:AttributeChanged(node,key)end
				if host.AttributeChanged then host.AttributeChanged(node,localName,value,oldValue,attributeNamespace)end
				if customBridge then customBridge:AttributeChanged(node,localName,value,oldValue,attributeNamespace)end
				if host.Mutation then host.Mutation({Type="attributes",Target=node,AttributeName=(newNamespaceInfo or namespaceInfo)and(newNamespaceInfo or namespaceInfo).LocalName or key,AttributeNamespace=attributeNamespace,OldValue=oldValue})end
			end;return
		end
		if not attributeNamespace then FormOwner.attributeChanged(node,key)end
		if newNamespaceInfo then node.AttributeNamespaces=node.AttributeNamespaces or{};node.AttributeNamespaces[key]=newNamespaceInfo end
		local names=Markup.attributeNames(node)
		if node.Attributes[key]==nil and value~=nil then table.insert(names,key)
		elseif value==nil then local index=table.find(names,key);if index then table.remove(names,index) end end
		node.Attributes[key]=value
		SourceDocument.write(node,localName,value,attributeNamespace,node.OwnerDocument or document)
		if attributeBridge then attributeBridge:Changed(node,key,value)end
		-- Record the first pre-mutation value before custom-element reactions
		-- can write the same attribute again or request current geometry.
		if connected(node) then host.Changed(node,"attribute",key,oldValue,true) end
		if host.Mutation then host.Mutation({Type="attributes",Target=node,AttributeName=(newNamespaceInfo or namespaceInfo)and(newNamespaceInfo or namespaceInfo).LocalName or key,AttributeNamespace=attributeNamespace,OldValue=oldValue})end
		disclosures:AttributeChanged(node,key,value,oldValue,attributeNamespace)
		if controlBridge and not attributeNamespace then controlBridge:AttributeChanged(node,key) end
		if host.AttributeChanged then host.AttributeChanged(node,localName,value,oldValue,attributeNamespace)end
		if customBridge then customBridge:AttributeChanged(node,localName,value,oldValue,attributeNamespace)end
	end
	local function collectionView(entries,elements,settings)
		local kind=if settings then settings.Kind else if elements then 'HTMLCollection'else 'NodeList'
		local view;local cached,properties,propertyOrder={},{ },{}
		local function named(name)
			if name=="" then return nil end
			for _,node in entries() do
				if host.Step then host.Step()end
				if node.Attributes.id==name or(Queries.namespace(node)==Queries.HTML and node.Attributes.name==name)then return node end
			end
			return nil
		end
		local function read(key)
			check()
			if symbol(key,"SymbolIterator")then return function()check();return iterator(entries,"values",wrap)end end
			if symbol(key,"SymbolToStringTag")then return kind end
			if isSymbol(key)then return VM.Undefined end
			if key=="length" then return #entries() end
			if key=='value'and settings and settings.ValueGet then return settings.ValueGet()end
			if key=="item" then return function(args)
				check();requireArgs(args,1);local index=uint(args[1])
				-- Web IDL conversion can run author code that changes this live view.
				return wrap(entries()[index+1])
			end end
			if key=="namedItem" and elements then return function(args)check();requireArgs(args,1);return wrap(named(VM.string(args[1])))end end
			if not elements and (key=="keys" or key=="values" or key=="entries") then return function()check();return iterator(entries,key,wrap)end end
			if key=="forEach" and not elements then return function(args)
				check()
				requireArgs(args,1);if not VM.callable(args[1])then domError("TypeError","forEach callback must be callable")end
				local length=#entries()
				for index=1,length do
					local child=entries()[index]
					if child then (host.CallDirect or host.Call)(args[1],{wrap(child),index-1,view},args[2]) end
				end
			end end
			local index=tonumber(key)
			if index and index>=0 and index%1==0 and tostring(index)==tostring(key) then
				return if entries()[index+1] then wrap(entries()[index+1]) else VM.Undefined
			end
			local entry=if elements then named(VM.string(key)) else nil
			return if entry then wrap(entry) else VM.Undefined
		end
		view={DOMCollectionKind=kind,GetPrototype=function()return if bridge.InterfacePrototypes then bridge.InterfacePrototypes[kind]else VM.Null end,Get=function(key)
			check()
			if properties[key]~=nil then return properties[key]end;if cached[key]then return cached[key]end
			local value=read(key);if type(value)=="function"then cached[key]=value end;return value
		end,Set=function(key,value,strict)
			check();local index=if type(key)=="string"then tonumber(key)else nil
			if key=='value'and settings and settings.ValueSet then settings.ValueSet(reflectedString(value));return end
			if key=="length"or(index and index>=0 and index%1==0 and tostring(index)==key)or(elements and type(key)=="string"and named(key))then
				if strict~=false then domError("TypeError","Read-only collection property: "..VM.string(key))end
			else if properties[key]==nil then table.insert(propertyOrder,key)end;properties[key]=value end
		end,Iterator=function()check();return iterator(entries,"values",wrap).Iterator()end,
		HasOwn=function(key)
			check();if properties[key]~=nil then return true end
			-- Interface members hide named properties; querying length or a method
			-- must not scan every element to discover a same-named attribute.
			if key=="length"or key=="item"or(elements and key=="namedItem")then return false end
			local index=if type(key)=="string"then tonumber(key)else nil
			return(index~=nil and index>=0 and index%1==0 and tostring(index)==key and entries()[index+1]~=nil)or(elements and type(key)=="string"and named(key)~=nil)
		end,
		Keys=function(enumerable)
			check();local keys,seen={},{};for index=1,#entries()do local key=tostring(index-1);table.insert(keys,key);seen[key]=true end
			if elements and not enumerable then for _,node in entries()do
				for _,name in {node.Attributes.id,if Queries.namespace(node)==Queries.HTML then node.Attributes.name else nil}do
					if name and name~=""and not seen[name]and name~="length"and name~="item"and name~="namedItem"then table.insert(keys,name);seen[name]=true end
				end
			end end
			for _,key in propertyOrder do if properties[key]~=nil and not seen[key]then table.insert(keys,key)end end;return keys
		end,
		GetOwnPropertyDescriptor=function(key)
			check();if properties[key]~=nil then return {Value=properties[key],Writable=true,Enumerable=true,Configurable=true}end
			local index=if type(key)=="string"then tonumber(key)else nil
			if index and index>=0 and index%1==0 and tostring(index)==key and entries()[index+1]then return {Value=wrap(entries()[index+1]),Writable=false,Enumerable=true,Configurable=true}end
			if elements and type(key)=="string"and key~="length"and key~="item"and key~="namedItem"then local node=named(key);if node then return {Value=wrap(node),Writable=false,Enumerable=false,Configurable=true}end end
			return nil
		end,
		Delete=function(key)check();if view.HasOwn(key)and properties[key]==nil then return false end;properties[key]=nil;return true end}
		return view
	end
	local function collection(nodes)return collectionView(function()return nodes end,false)end
	local function liveChildren(node,elements)
		return collectionView(function()
			local result={};for _,child in node.Children do if not elements or child.Kind=="Element" then table.insert(result,child) end end;return result
		end,elements)
	end
	local function unwrap(value)
		if not (type(value)=="table" and value.DOMNode and origins[value]and origins[value].Alive) then domError("TypeError","Expected a live DOM node") end
		return value.DOMNode
	end
	local function adopt(root,owner)
		-- Preserve each root's registry for this adoption operation. Null-registry
		-- descendants consult the pre-adoption root even if that root is rebound
		-- to the destination global registry before its children are visited.
		local oldShadowRegistries
		if customBridge and(root.OwnerDocument or document)~=owner then
			oldShadowRegistries={};local scan={root}
			while #scan>0 do local node=table.remove(scan)
				if node.Kind=="ShadowRoot"then oldShadowRegistries[node]={Value=node.CustomElementRegistry}end
				for _,child in node.Children do table.insert(scan,child)end
				if node.Content then table.insert(scan,node.Content)end
				if node.InternalShadowRoot then table.insert(scan,node.InternalShadowRoot)end
			end
		end
		local pending={{Node=root,Document=owner}};while #pending>0 do local entry=table.remove(pending);local node,destination=entry.Node,entry.Document;local old=node.OwnerDocument or document
			if old~=destination then
				local source=ownerBridge(node)
				if source.Controls and controlBridge and source.Controls~=controlBridge then source.Controls:TransferTo(node,controlBridge)end
				node.OwnerDocument=destination
				if customBridge and(node.Kind=="Element"or node.Kind=="ShadowRoot")then customBridge:Reassociate(node,destination,oldShadowRegistries)end
				local definition=node.CustomElementDefinition;if definition and definition.API and definition.API.Adopted then definition.API:Adopted(node,old,destination)end
				if source.Host.Adopted then source.Host.Adopted(node,old,destination,bridge)end
			end
			for _,child in node.Children do table.insert(pending,{Node=child,Document=destination})end
			if node.Content then
				local contentOwner=if node.Content.Kind=='ShadowRoot'then destination else Template.owner(destination)
				if contentOwner.InertTemplateDocument and not documents[contentOwner]then documents[contentOwner]=documents[destination]or bridge end
				table.insert(pending,{Node=node.Content,Document=contentOwner})
			end
			if node.InternalShadowRoot then table.insert(pending,{Node=node.InternalShadowRoot,Document=destination})end
			for _,attr in node.AttributeNodes or{}do table.insert(pending,{Node=attr,Document=destination})end
		end
		if customBridge then customBridge:Drain()end
	end
	local function queryMethod(root,key)
		local length=if key=="getElementsByTagNameNS"then 2 else 1
		local function action(args,receiver)
			check();local target=if receiver==nil then root else unwrap(receiver)
			if target.Kind~=root.Kind then domError("TypeError","Incompatible query method receiver")end
			requireArgs(args,length)
			local first=if key=="getElementsByTagNameNS"and(args[1]==VM.Null or args[1]==VM.Undefined)then nil else VM.string(args[1])
			local second=if length==2 then VM.string(args[2])else nil
			local owner=if target.Kind=="Document"then target else target.OwnerDocument or document
			return collectionView(Queries.entries(target,key,first,second,owner,host.Step,function()return ownerBridge(target).QueryRevision()end),key~="getElementsByName")
		end
		local value={Kind="native-function",Values={name=key,length=length},Call=action,
			Descriptors={name={Value=key,Writable=false,Enumerable=false,Configurable=true},length={Value=length,Writable=false,Enumerable=false,Configurable=true}},
			GetPrototype=function()return if realmVM then realmVM.Prototypes.Function else VM.Null end}
		-- Internal Luau callers historically call DOM methods directly; the JS
		-- model still sees an ordinary nonconstructible native operation function.
		return setmetatable(value,{__call=function(_,args,receiver)return action(args,receiver)end})
	end
	local function mutate(parent,nodes,before,removals,validityReference,preservingMove)
		local destination=ownerBridge(parent);if destination~=bridge then return destination.Mutate(parent,nodes,before,removals,validityReference,preservingMove)end
		check()
		if before and before.Parent~=parent then domError("NotFoundError","Reference node is not a child of this parent") end
		for _,child in nodes do local valid,message=pcall(Node.validateInsert,parent,child,validityReference or before,removals);if not valid then domError("HierarchyRequestError",tostring(message)) end end
		local additions=Tree.flatten(nodes)
		local ok,plan=pcall(Tree.plan,parent,additions,before,removals,validityReference)
		if not ok then domError("HierarchyRequestError",tostring(plan)) end
		plan.Move=preservingMove==true
		Tree.validate(plan,host)
		-- Foreign source hosts must receive their own removal/range/observer steps.
		for _,child in plan.Additions do local source=ownerBridge(child)
			if child.Parent and source~=bridge then source.Remove(child.Parent,child)end
		end
		local owner=if parent.Kind=="Document"then parent else parent.OwnerDocument or document
		for _,child in plan.Additions do adopt(child,owner)end
		Tree.commit(plan,host,connected)
		if customBridge then customBridge:Drain()end
		if controlBridge and plan.Changed then
			for source in plan.OldParents do if source~=parent then controlBridge:TreeChanged(source) end end
			controlBridge:TreeChanged(parent,plan.Additions)
		end
	end
	local function convert(args)
		local nodes={}
		for _,value in args do
			if type(value)=="table" and value.DOMNode then table.insert(nodes,unwrap(value))
			else local text=VM.string(value);assert(#text<=65536,"Text budget exceeded");table.insert(nodes,allocate(Node.text(text))) end
		end
		return nodes
	end
	local function countCreated(root,owner)
		Template.assign(root,owner or document,allocate)
		return root
	end
	local function parse(context,source,inert)
		local ok,parsed=pcall(Markup.parse,context,source)
		if not ok then if context.OwnerDocument and context.OwnerDocument.IsHTML==false then domError('SyntaxError',tostring(parsed))else error(parsed,0)end end
		local parsingContext=if Template.matches(context)then context.Content else context
		local fragment=countCreated(parsed,parsingContext.OwnerDocument or document)
		if inert~=false then
			local pending={fragment};while #pending>0 do local node=table.remove(pending)
				if ElementNames.htmlName(node)=="script" then node.ScriptStarted=true end
				for _,child in node.Children do table.insert(pending,child) end
				if node.Content then table.insert(pending,node.Content) end
			end
		end
		if customBridge then if customBridge.PrepareTree then customBridge:PrepareTree(fragment,parsingContext)end;customBridge:UpgradeTree(fragment)end
		return fragment
	end
	local function clone(source,deep,owner)
		owner=owner or source.OwnerDocument or document
		local copied=Node.cloneNode(source,deep,function(copy,original)
			if copy.Kind=="Document"then owner=copy;copy.DetachedDocument=true end
			allocate(copy,copy.OwnerDocument or owner)
			if copy.Kind=="Element"and customBridge and customBridge.Cloned then customBridge:Cloned(copy,original)end
		end,owner)
		local pending,finished={{Source=source,Copy=copied}},{}
		while #pending>0 do
			local pair=table.remove(pending)
			table.insert(finished,pair)
			if pair.Source.Attributes then pair.Copy.AttributeOrder=table.clone(Markup.attributeNames(pair.Source)) end
			if host.CloneNode then host.CloneNode(pair.Source,pair.Copy) end
			if controlBridge then controlBridge:Clone(pair.Source,pair.Copy) end
			if customBridge and customBridge.CloneFinished and pair.Copy.Kind=="Element"then customBridge:CloneFinished(pair.Copy,pair.Source)end
			for index,child in pair.Copy.Children do table.insert(pending,{Source=pair.Source.Children[index],Copy=child}) end
			if pair.Source.Content and pair.Copy.Content and deep then
				table.insert(pending,{Source=pair.Source.Content,Copy=pair.Copy.Content})
			end
			if pair.Source.InternalShadowRoot and pair.Copy.InternalShadowRoot and pair.Source.InternalShadowRoot.Clonable then
				table.insert(pending,{Source=pair.Source.InternalShadowRoot,Copy=pair.Copy.InternalShadowRoot})
			end
		end
		if controlBridge and controlBridge.CloneFinished then for index=#finished,1,-1 do local pair=finished[index];controlBridge:CloneFinished(pair.Source,pair.Copy)end end
		countCreated(copied,owner)
		if customBridge then customBridge:Drain()end
		return copied
	end
	local function insert(parent,child,before)
		mutate(parent,{child},before)
		return wrap(child)
	end
	local function remove(parent,child)
		local destination=ownerBridge(parent);if destination~=bridge then return destination.Remove(parent,child)end
		check();if child.Parent~=parent then domError("NotFoundError","Node is not a child of this parent") end
		if host.ValidateStructure then host.ValidateStructure(nil,child,parent) end
		local wasConnected=connected(parent)
		Tree.remove(parent,child,host)
		if customBridge then customBridge:Drain()end
		if controlBridge then controlBridge:TreeChanged(parent) end
		if wasConnected then host.Changed(parent,"children") end
		return wrap(child)
	end
	local function compile(source)
		check();local compiled={}
		for _,part in Selectors.list(VM.string(source)) do
			local selector=Selectors.compile(part);if not selector then domError("SyntaxError","Invalid or unsupported selector: " .. VM.string(source)) end;table.insert(compiled,selector)
		end
		if #compiled==0 then domError("SyntaxError","Empty selector") end
		return compiled
	end
	local selectorStates=setmetatable({
		GetFormState=function(node)
			if ElementNames.htmlName(node)~='input'and ElementNames.htmlName(node)~='textarea'and ElementNames.htmlName(node)~='select'and ElementNames.htmlName(node)~='button'then return nil end
			local controls=ownerBridge(node).Controls or controlBridge
			return if controls then controls:State(node)else nil
		end,
		GetValidity=function(node)
			local controls=ownerBridge(node).Controls or controlBridge
			return if controls then controls:Validity(node)else nil
		end,
		GetOptionSelected=function(node)
			local controls=ownerBridge(node).Controls or controlBridge
			if not controls then return node.Attributes.selected~=nil end
			local _,selected=controls:Get(node,'selected');return selected
		end,
	},{__index=function(_,key)return host.States and host.States[key]end})
	local function matches(node,compiled,scope)
		for _,selector in compiled do if Selectors.matches(node,selector,selectorStates,scope) then return true end end
		return false
	end
	local function query(root,source,first)
		local compiled=compile(source)
		local scope=if root.Kind=="Document" then root.DocumentElement or root.Children[1] else root
		local pending,result={},{}
		for i=#root.Children,1,-1 do table.insert(pending,root.Children[i]) end
		while #pending>0 do
			local node=table.remove(pending);if host.Step then host.Step() end
			if node.Kind=="Element" then
				if matches(node,compiled,scope) then
					if first then return wrap(node) end
					table.insert(result,node)
				end
			end
			for i=#node.Children,1,-1 do table.insert(pending,node.Children[i]) end
		end
		return if first then VM.Null else collection(result)
	end
	local function findId(id,root)
		if id=="" then return nil end
		local pending={root or document}
		while #pending>0 do
			if host.Step then host.Step() end
			local node=table.remove(pending)
			if node.Kind=="Element" and node.Attributes.id==id then return node end
			for i=#node.Children,1,-1 do table.insert(pending,node.Children[i]) end
		end
		return nil
	end
	local function classList(node)
		local function tokens()local values={};for token in (node.Attributes.class or ""):gmatch("[^\t\n\f\r ]+") do if not table.find(values,token) then table.insert(values,token) end end;return values end
		local function update(values)if #values==0 and node.Attributes.class==nil then return end;attribute(node,"class",table.concat(values," "))end
		local function valid(args)
			local values={};for _,v in args do
				local token=VM.string(v)
				if token=="" then domError("SyntaxError","Class token must not be empty") end
				if token:find("[\t\n\f\r ]") then domError("InvalidCharacterError","Class token must not contain ASCII whitespace") end
				table.insert(values,token)
			end;return values
		end
		local view;local cached,properties={},{ }
		local function read(key)
			check()
			if symbol(key,"SymbolIterator")then return function()return iterator(tokens,"values")end end
			if symbol(key,"SymbolToStringTag")then return "DOMTokenList"end
			if isSymbol(key)then return VM.Undefined end
			if key=="length" then return #tokens() elseif key=="value" then return node.Attributes.class or "" end
			if key=="item" then return function(args)requireArgs(args,1);return tokens()[uint(args[1])+1] or VM.Null end end
			if key=="toString" then return function()return node.Attributes.class or ""end end
			if key=="keys" or key=="values" or key=="entries" then return function()return iterator(tokens,key)end end
			if key=="forEach" then return function(args)
				requireArgs(args,1);if not VM.callable(args[1])then domError("TypeError","forEach callback must be callable")end
				local length=#tokens();for index=1,length do local value=tokens()[index];if value then (host.CallDirect or host.Call)(args[1],{value,index-1,view},args[2]) end end
			end end
			if key=="supports" then return function()domError("TypeError","classList has no supported-token vocabulary")end end
			if key=="contains" then return function(args)requireArgs(args,1);return table.find(tokens(),valid({args[1]})[1])~=nil end end
			if key=="add" or key=="remove" then return function(args)
				local additions=valid(args);local values=tokens()
				for _,token in additions do local i=table.find(values,token);if key=="add" and not i then table.insert(values,token) elseif key=="remove" and i then table.remove(values,i) end end
				update(values)
			end end
			if key=="toggle" then return function(args)
				requireArgs(args,1)
				local token=valid({args[1]})[1];local values=tokens();local i=table.find(values,token)
				local wanted=if args[2]==nil then i==nil else VM.truth(args[2])
				if wanted and not i then table.insert(values,token);attribute(node,"class",table.concat(values," "))
				elseif not wanted and i then table.remove(values,i);attribute(node,"class",table.concat(values," ")) end
				return wanted
			end end
			if key=="replace" then return function(args)
				requireArgs(args,2)
				local pair=valid({args[1],args[2]});local values=tokens();local old=table.find(values,pair[1]);if not old then return false end
				local existing=table.find(values,pair[2])
				if not existing then values[old]=pair[2]
				elseif existing<old then table.remove(values,old)
				elseif existing>old then values[old]=pair[2];table.remove(values,existing) end
				attribute(node,"class",table.concat(values," "));return true
			end end
			local i=tonumber(key);return if i and i>=0 and i%1==0 and tostring(i)==tostring(key) then tokens()[i+1] or VM.Undefined else VM.Undefined
		end
		view={Get=function(key)check();if properties[key]~=nil then return properties[key]end;if cached[key]then return cached[key]end;local value=read(key);if type(value)=="function"then cached[key]=value end;return value end,
		Set=function(key,value,strict)
			check();local index=if type(key)=="string"then tonumber(key)else nil
			if key=="value"then attribute(node,"class",VM.string(value))
			elseif key=="length"or(index and index>=0 and index%1==0 and tostring(index)==key)then if strict~=false then domError("TypeError","Read-only classList property")end
			else properties[key]=value end
		end,Iterator=function()return iterator(tokens,"values").Iterator()end,
		Keys=function()check();local keys={};for index=1,#tokens()do table.insert(keys,tostring(index-1))end;for key in properties do table.insert(keys,key)end;return keys end,
		HasOwn=function(key)local index=if type(key)=="string"then tonumber(key)else nil;return properties[key]~=nil or(index~=nil and index>=0 and index%1==0 and tostring(index)==key and tokens()[index+1]~=nil)end,
		Delete=function(key)check();properties[key]=nil;return true end}
		return view
	end
	local function dataset(node)
		local symbolProperties={}
		local function attributeName(key)return "data-"..VM.string(key):gsub("[A-Z]",function(letter)return "-"..letter:lower()end)end
		local function stored(key)return if not VM.string(key):find("%-[a-z]")then AttributeStore.qualified(node,attributeName(key))else nil end
		local function present(key)return stored(key)~=nil end
		local function keys()
			check();local values={}
			for _,entry in Markup.attributeNames(node) do local key=AttributeStore.name(node,entry);if key:sub(1,5)=="data-" and not key:sub(6):find("[A-Z]") then
				local name=(key:sub(6):gsub("%-([a-z])",string.upper));if not table.find(values,name)then table.insert(values,name)end
			end end
			return values
		end
		return {Get=function(key)check();if isSymbol(key)then return if symbolProperties[key]~=nil then symbolProperties[key]else(if symbol(key,"SymbolToStringTag")then "DOMStringMap"else VM.Undefined)end;local entry=stored(key);return if entry then node.Attributes[entry]else VM.Undefined end,
		Set=function(key,value)
			check();if isSymbol(key)then symbolProperties[key]=value;return end
			key=VM.string(key);if key:find("%-[a-z]") then domError("SyntaxError","dataset keys cannot contain a hyphen followed by a lowercase letter") end
			attribute(node,attributeName(key),VM.string(value))
		end,Delete=function(key)check();if isSymbol(key)then symbolProperties[key]=nil else local entry=stored(key);if entry then attribute(node,entry,nil)end end;return true end,
		Has=function(key)check();return if isSymbol(key)then symbolProperties[key]~=nil or symbol(key,"SymbolToStringTag")==true else present(key)end,
		HasOwn=function(key)check();return if isSymbol(key)then symbolProperties[key]~=nil else present(key)end,
		Keys=function()local result=keys();for key in symbolProperties do table.insert(result,key)end;return result end}
	end
	local function event(e)
		if host.EventWrapper then return host.EventWrapper(e) end
		if eventWrappers[e] then return eventWrappers[e] end
		local object={Get=function(key)
			check()
			if key=="target" then return if e.Target then wrap(e.Target) else host.Window end
			if key=="currentTarget" then return if e.Phase==0 then VM.Null elseif e.CurrentTarget then wrap(e.CurrentTarget) else host.Window end
			local fields={type="Type",eventPhase="Phase",defaultPrevented="DefaultPrevented",bubbles="Bubbles",cancelable="Cancelable"}
			if fields[key] then return e[fields[key]] end
			if key=="preventDefault" then return function()e:PreventDefault()end end
			if key=="stopPropagation" then return function()e:StopPropagation()end end
			if key=="stopImmediatePropagation" then return function()e:StopImmediatePropagation()end end
			return VM.Undefined
		end}
		eventWrappers[e]=object;return object
	end
	local function eventMethod(node,key)
		if host.EventMethod then local method=host.EventMethod(node,key);if method then return method end end
		if key~="addEventListener" and key~="removeEventListener" then return nil end
		return function(args)
			check();local kind,callback=VM.string(args[1]),args[2]
			if callback==nil or callback==VM.Null or callback==VM.Undefined then return end
			local option=args[3];local capture=option==true;local once,passive=false,false
			if type(option)=="table" and option~=VM.Null and option~=VM.Undefined then
				capture=VM.truth(host.Get(option,"capture"));once=VM.truth(host.Get(option,"once"));passive=VM.truth(host.Get(option,"passive"))
			end
			for i,entry in listeners do
				if entry.Node==node and entry.Kind==kind and entry.Callback==callback and entry.Capture==capture then
					if key=="removeEventListener" then entry.Connection:Disconnect();table.remove(listeners,i) end
					return
				end
			end
			if key=="removeEventListener" then return end
			assert(#listeners<512,"Document event listener budget exceeded")
			local listenerObject=type(callback)=="table" and not VM.callable(callback)
			assert(VM.callable(callback) or listenerObject,"Listener must be a function or listener object")
			local entry={Node=node,Kind=kind,Callback=callback,Capture=capture}
			entry.Connection=host.Events:On(node,kind,function(e)
				if not bridge.Alive then return end
				if once then local index=table.find(listeners,entry);if index then table.remove(listeners,index) end end
				if listenerObject then
					local handler=host.Get(callback,"handleEvent")
					if VM.callable(handler) then host.Call(handler,{event(e)},callback) end
				else host.Call(callback,{event(e)},if node then wrap(node) else host.Window) end
			end,{Capture=capture,Once=once,Passive=passive})
			table.insert(listeners,entry)
		end
	end
	local function setData(node,text,offset,count,inserted,validated)
		local destination=ownerBridge(node);if destination~=bridge then return destination.SetData(node,text,offset,count,inserted,validated)end
		check();assert(#text<=65536,"Text budget exceeded")
		if not validated and node.Kind=="Text" and host.ValidateText and connected(node) then host.ValidateText(node) end
		if rangeBridge then rangeBridge:CharacterData(node,offset or 0,count or Strings.length(node.Text),inserted or Strings.length(text),node.Text~=text)end
		if node.Text==text then if host.Mutation then host.Mutation({Type="characterData",Target=node,OldValue=node.Text})end;return end
		local oldValue=node.Text;node.Text=text
		if host.Mutation then host.Mutation({Type="characterData",Target=node,OldValue=oldValue})end
		if controlBridge then controlBridge:TextChanged(node) end
		if connected(node) then host.Changed(node,"text") end
	end
	local function substring(node,offset,count)
		local start,amount=uint(offset),uint(count);local units=Strings.units(node.Text)
		if start>#units then domError("IndexSizeError","Offset exceeds CharacterData length") end
		local result={};for index=start+1,math.min(start+amount,#units) do table.insert(result,units[index]) end
		return Strings.fromUnits(result)
	end
	local function replaceData(node,offset,count,value)
		local start,amount=uint(offset),uint(count);local text=VM.string(value);local units=Strings.units(node.Text)
		if start>#units then domError("IndexSizeError","Offset exceeds CharacterData length") end
		local finish=math.min(start+amount,#units);local result={};local added=Strings.units(text)
		for index=1,start do table.insert(result,units[index]) end
		for _,unit in added do table.insert(result,unit) end
		for index=finish+1,#units do table.insert(result,units[index]) end
		setData(node,Strings.fromUnits(result),start,finish-start,#added)
	end
	local function splitText(node,offset)
		check();offset=uint(offset);local length=Strings.length(node.Text)
		if offset>length then domError("IndexSizeError","Offset exceeds Text length")end
		local prefix,suffix=substring(node,0,offset),substring(node,offset,length-offset)
		local sibling=allocate(Node.text(suffix));local plan
		if node.Parent then local index=table.find(node.Parent.Children,node);plan=Tree.plan(node.Parent,{sibling},node.Parent.Children[index+1]);Tree.validate(plan,host)end
		if host.ValidateText and connected(node)then host.ValidateText(node)end
		if plan then Tree.commit(plan,host,connected)end
		if rangeBridge then rangeBridge:SplitText(node,sibling,offset)end
		setData(node,prefix,offset,length-offset,0,true)
		return sibling
	end
	local function normalize(root)
		check();local actions,frames={},{ {Node=root,Index=1,Head=nil,Text=""} }
		while #frames>0 do
			local frame=frames[#frames];local child=frame.Node.Children[frame.Index];frame.Index+=1
			if not child then table.remove(frames)
			elseif child.Kind=="Text" then
				if host.Step then host.Step()end
				if frame.Head then
					local oldLength=Strings.length(frame.Text)
					if not frame.HeadAction then
						frame.HeadAction={Kind="text",Node=frame.Head,Text=frame.Text,OldLength=oldLength};table.insert(actions,frame.HeadAction)
					end
					frame.Text..=child.Text;assert(#frame.Text<=65536,"Text budget exceeded")
					frame.HeadAction.Text=frame.Text
					table.insert(actions,{Kind="merge",Node=frame.Head,Merged=child,OldLength=oldLength})
					table.insert(actions,{Kind="remove",Node=child,Parent=frame.Node})
				elseif child.Text=="" then table.insert(actions,{Kind="remove",Node=child,Parent=frame.Node})
				else
					frame.Head,frame.Text=child,child.Text
					frame.HeadAction={Kind="text",Node=child,Text=child.Text,OldLength=Strings.length(child.Text)}
					table.insert(actions,frame.HeadAction)
				end
			else frame.Head=nil;frame.HeadAction=nil;frame.Text="";table.insert(frames,{Node=child,Index=1,Head=nil,Text=""})end
		end
		-- Validation of every descendant precedes the first text or tree write.
		for _,action in actions do
			if action.Kind=="text" then if host.ValidateText and connected(action.Node)then host.ValidateText(action.Node)end
			elseif action.Kind=="remove"and host.ValidateStructure then host.ValidateStructure(nil,action.Node,action.Parent)end
		end
		local dirty={}
		for _,action in actions do
			if action.Kind=="text"then
				if rangeBridge then rangeBridge:CharacterData(action.Node,action.OldLength,0,Strings.length(action.Text)-action.OldLength,action.Node.Text~=action.Text)end
				local oldValue=action.Node.Text;action.Node.Text=action.Text
				if host.Mutation then host.Mutation({Type="characterData",Target=action.Node,OldValue=oldValue})end
				if oldValue~=action.Text and connected(action.Node)then host.Changed(action.Node,"text")end
			elseif action.Kind=="merge"then if rangeBridge then rangeBridge:NormalizeText(action.Node,action.Merged,action.OldLength)end
			else Tree.remove(action.Parent,action.Node,host);if connected(action.Parent)then dirty[action.Parent]=true end end
		end
		for parent in dirty do host.Changed(parent,"children")end
		if controlBridge then controlBridge:TreeChanged(root) end
	end
	local disconnectedOrder,nextOrder=setmetatable({},{__mode="k"}),0
	local function position(node,other)
		if node==other then return 0 end
		local leftRoot,rightRoot=Tree.root(node),Tree.root(other)
		if leftRoot~=rightRoot then
			for _,root in {leftRoot,rightRoot} do if not disconnectedOrder[root] then nextOrder+=1;disconnectedOrder[root]=nextOrder end end
			return 33+(if disconnectedOrder[leftRoot]<disconnectedOrder[rightRoot] then 4 else 2)
		end
		if Tree.contains(node,other) then return 20 end
		if Tree.contains(other,node) then return 10 end
		local left,right={},{}
		local current=node;while current do table.insert(left,1,current);current=current.Parent end
		current=other;while current do table.insert(right,1,current);current=current.Parent end
		local index=1;while left[index]==right[index] do index+=1 end
		local siblings=left[index-1].Children
		return if table.find(siblings,left[index])<table.find(siblings,right[index]) then 4 else 2
	end
	local function adjacent(node,positionValue)
		local positionName=VM.string(positionValue):lower()
		if positionName=="beforebegin" or positionName=="afterend" then
			local parent=node.Parent
			if not parent or parent.Kind=="Document" then return nil,nil,positionName end
			local index=table.find(parent.Children,node)
			return parent,if positionName=="beforebegin" then node else parent.Children[index+1],positionName
		elseif positionName=="afterbegin" then return node,node.Children[1],positionName
		elseif positionName=="beforeend" then return node,nil,positionName end
		domError("SyntaxError","Invalid adjacent insertion position")
	end
	tableBridge=Tables.new({Wrap=function(node)return wrap(node)end,Attribute=attribute,CollectionView=collectionView,
		Allocate=allocate,Check=check,DOMError=domError,RequireArgs=requireArgs,ReflectedString=reflectedString,
		Mutate=mutate,Unwrap=unwrap,ToPrimitive=function(value,hint)return if realmVM then realmVM.ToPrimitive(value,hint)else value end})
	listBridge=Lists.new({Attribute=attribute,ReflectedString=reflectedString,DOMError=domError,
		ToPrimitive=function(value,hint)return if realmVM then realmVM.ToPrimitive(value,hint)else value end})
	local function createdElement(node,options)
		if options~=nil and options~=VM.Null and options~=VM.Undefined then
			if not realmVM.ObjectModel.IsObject(options)then domError("TypeError","createElement options must be a dictionary")end
			local isValue=realmVM.Get(options,"is");if isValue~=VM.Undefined then node.IsValue=reflectedString(isValue)end
			local registry=realmVM.Get(options,"customElementRegistry");if registry~=VM.Undefined and customBridge and customBridge.SetRegistry then customBridge:SetRegistry(node,registry)end
		end
		if customBridge then customBridge:Created(node,true)end
	end
	documentBridge=Documents.new({Allocate=allocate,Wrap=function(node)return wrap(node)end,Unwrap=unwrap,Error=domError,
		Step=host.Step,Collection=collectionView,
		String=reflectedString,RequireArgs=requireArgs,Mutate=mutate,Created=createdElement,
		Controller=function(node)return host.ParserController and host.ParserController(node)end,
		ParserElement=function(node,parent)if customBridge then customBridge:ParserCreated(node,parent)end end,
		ParserShadow=function(root)if host.Changed then host.Changed(root.Host,'children')end end,
		Replace=function(node,children)
			-- document.open performs replace-all as an internal parser operation.
			-- Preserve observers/ranges/removal lifecycles while bypassing only
			-- the author-mutation renderer preflight for html/head/body roots.
			check();local plan=Tree.plan(node,children,nil,table.clone(node.Children))
			Tree.commit(plan,host,connected)
			if customBridge then customBridge:Drain()end
			if controlBridge and plan.Changed then controlBridge:TreeChanged(node,children)end
		end,
		Mutation=function(record)
			check();if host.Mutation then host.Mutation(record)end
			if host.Changed then host.Changed(record.Target,if record.Type=="characterData"then"text"else"children")end
			if host.PostInsert and record.Type=="childList"then host.PostInsert(record.AddedNodes or{})end
		end,
		EraseListeners=function(root)
			local pending={root};local affected={}
			while #pending>0 do
				local node=table.remove(pending);affected[node]=true
				if host.EraseListeners then host.EraseListeners(node)end
				for _,child in node.Children do table.insert(pending,child)end
				if node.InternalShadowRoot then table.insert(pending,node.InternalShadowRoot)end
			end
			for index=#listeners,1,-1 do local entry=listeners[index]
				if affected[entry.Node]or(entry.Node==nil and root==document)then entry.Connection:Disconnect();table.remove(listeners,index)end
			end
			if root==document and host.EraseListeners then host.EraseListeners(nil)end
		end,
		WindowOpen=function(node,args)
			if node.DetachedDocument then domError("InvalidAccessError","Document has no active window")end
			local method=host.Window and host.Window.Get("open")
			if not VM.callable(method)then domError("NotSupportedError","Window.open requires a navigation window host")end
			return host.CallDirect(method,args,host.Window)
		end,
		Prototype=function(name)return if bridge.InterfacePrototypes then bridge.InterfacePrototypes[name]else VM.Null end})
	bridge.NamedProperties=documentBridge.NamedProperties
	attributeBridge=Attributes.new({Document=document,Allocate=allocate,Wrap=function(node)return wrap(node)end,Unwrap=unwrap,Error=domError,
		String=reflectedString,RequireArgs=requireArgs,Attribute=attribute,Uint=uint,Prototype=function(name)return if bridge.InterfacePrototypes then bridge.InterfacePrototypes[name]else VM.Null end})
	reflectionBridge=Reflection.new({Attribute=attribute,String=reflectedString,Error=domError,Long=function(value)
		local primitive=if realmVM then realmVM.ToPrimitive(value,"number")else value
		if type(primitive)=="table"and(primitive.Kind=="symbol"or primitive.Kind=="bigint")then domError("TypeError","Cannot convert DOM value to a number")end
		local n=VM.number(primitive);if n~=n or math.abs(n)==math.huge then return 0 end;n=(if n<0 then math.ceil(n)else math.floor(n))%4294967296;return if n>=2147483648 then n-4294967296 else n
	end,ResolveURL=function(node,source)
		-- Borrowed accessors keep their origin realm, but the current node
		-- document owns URL resolution after adoption.
		local owner=node.OwnerDocument or document;local base=ownerBridge(owner).NativeRead(owner,"baseURI")
		if ElementNames.htmlName(node)=="base" then
			local address=ownerBridge(owner).NativeRead(owner,"URL")
			return DocumentInfo.baseHref(owner,address,source)
		end
		return DocumentInfo.resolveURL(base or"about:blank",source)
	end})
	createWrapper=function(node)
		if not node then return VM.Null end
		if wrappers[node] then return wrappers[node] end
		local object={DOMNode=node};wrappers[node]=object;origins[object]=bridge
		node.DOMWrappers=node.DOMWrappers or {};node.DOMWrappers[bridge]=object
		if customBridge then object.Prototype=customBridge:Prototype(node)end
		local cached,properties,methods,propertyOrder,ownDescriptors={},{},{},{},{}
		local function namedGet(key)
			if controlBridge and controlBridge.NamedGet then local handled,value,indexed=controlBridge:NamedGet(node,key);if handled then return true,value,indexed end end
			return documentBridge:NamedGet(node,key)
		end
		local function read(key)
			check()
			if cached[key] then return cached[key] end
			local attrHandled,attrValue=attributeBridge:Get(node,key);if attrHandled then return attrValue end
			local documentHandled,documentValue=documentBridge:Get(node,key);if documentHandled then return documentValue end
			if key=="baseURI"and node.Kind~="Document"then
				-- The current node document owns the base, even for detached nodes,
				-- attributes and nodes whose original wrapper survives adoption.
				local owner=node.OwnerDocument or document
				return ownerBridge(owner).NativeRead(owner,key)
			end
			if node==document and traversalBridge then local value=traversalBridge.DocumentMethod(key);if value~=nil then return value end end
			if node==document and rangeBridge then local value=rangeBridge.DocumentMethod(key);if value~=nil then return value end end
			if host.EventGet then local value=host.EventGet(node,key);if value~=nil then return value end end
			local method=eventMethod(node,key);if method then cached[key]=method;return method end
			if host.AnimationMethod then local value=host.AnimationMethod(node,key);if value~=nil then return value end end
			if node==document and host.AnimationGet then local value=host.AnimationGet(key);if value~=nil then return value end end
			if host.ElementGet then local value=host.ElementGet(node,key);if value~=nil then return value end end
			if key=="baseURI"then return DocumentInfo.baseURL(node,node.URL or host.URL,true)end
			if customBridge and customBridge.Get then local handled,value=customBridge:Get(node,key);if handled then return value end end
			if shadowBridge then local handled,value=shadowBridge:Get(node,key);if handled then return value end end
			local tableHandled,tableValue=tableBridge:Get(node,key);if tableHandled then return tableValue end
			local listHandled,listValue=listBridge:Get(node,key);if listHandled then return listValue end
			if controlBridge then
				local method=controlBridge:Method(node,key);if method then return method end
				local handled,value=controlBridge:Get(node,key);if handled then return value end
			end
			if key=="nodeType" then return if node.Kind=="Document" then 9 elseif node.Kind=="Text" then 3 elseif node.Kind=="CDATASection"then 4 elseif node.Kind=="ProcessingInstruction"then 7 elseif node.Kind=="Comment" then 8 elseif node.Kind=="DocumentType"then 10 elseif node.Kind=="DocumentFragment" or node.Kind=="ShadowRoot" then 11 else 1 end
			if key=="nodeName" then return if node.Kind=="Document" then "#document" elseif node.Kind=="DocumentFragment" or node.Kind=="ShadowRoot" then "#document-fragment" elseif node.Kind=="Text" then "#text"elseif node.Kind=="CDATASection"then"#cdata-section"elseif node.Kind=="ProcessingInstruction"then node.Target elseif node.Kind=="Comment" then "#comment"elseif node.Kind=="DocumentType"then node.Name else (if Queries.namespace(node)==Names.HTML and(node.OwnerDocument or document).IsHTML~=false then node.Name:upper()else node.Name) end
			if key=="nodeValue" then return if node.Kind=="Text"or node.Kind=="CDATASection"or node.Kind=="ProcessingInstruction" or node.Kind=="Comment" then node.Text else VM.Null end
			if node==document and key=="activeElement" then
				local active=host.GetActiveElement or (host.ControlAdapter and host.ControlAdapter.GetActiveElement)
				local target=if active then active() else nil
				return if target then wrap(ShadowTree.Retarget(target,document)) else query(document,"body",true)
			end
			if NODE_CONSTANTS[key] then return NODE_CONSTANTS[key] end
			if key=="parentNode" then return wrap(node.Parent) end
			if key=="parentElement" then return wrap(if node.Parent and node.Parent.Kind=="Element" then node.Parent else nil) end
			if key=="isConnected" then local root=ShadowTree.Root(node);while root.Kind=="ShadowRoot"do root=ShadowTree.Root(root.Host)end;return root.Kind=="Document"end
			if key=="ownerDocument" then return if node.Kind=="Document" then VM.Null else wrap(node.OwnerDocument or document) end
			if key=="textContent" then return if node.Kind=="Document"or node.Kind=="DocumentType"then VM.Null elseif node.Kind=="Comment"or node.Kind=="ProcessingInstruction"then node.Text else Node.textContent(node) end
			if key=="hasChildNodes" then return function()return #node.Children>0 end end
			if key=="contains" then return function(args)requireArgs(args,1);return args[1]~=VM.Null and args[1]~=VM.Undefined and Tree.contains(node,unwrap(args[1]))end end
			if key=="getRootNode" then return function()return wrap(Tree.root(node))end end
			if key=="isSameNode" then return function(args)requireArgs(args,1);return args[1]==object end end
			if key=="isEqualNode" then return function(args)requireArgs(args,1);return args[1]~=VM.Null and args[1]~=VM.Undefined and Tree.equal(node,unwrap(args[1]))end end
			if key=="compareDocumentPosition" then return function(args)requireArgs(args,1);return position(node,unwrap(args[1]))end end
			if key=="cloneNode" then return function(args)
				if node.Kind=="ShadowRoot"then domError("NotSupportedError","Shadow roots cannot be cloned directly")end
				return wrap(clone(node,args[1]~=nil and VM.truth(args[1])))
			end end
			if key=="normalize" then return function()normalize(node)end end
			if key=="firstChild" then return wrap(node.Children[1]) end
			if key=="lastChild" then return wrap(node.Children[#node.Children]) end
			if key=="childNodes" or key=="children" then cached[key]=liveChildren(node,key=="children");return cached[key] end
			if key=="childElementCount" then local n=0;for _,child in node.Children do if child.Kind=="Element" then n+=1 end end;return n end
			if key=="firstElementChild" or key=="lastElementChild" then
				local result;for _,child in node.Children do if child.Kind=="Element" then result=child;if key=="firstElementChild" then break end end end
				return wrap(result)
			end
			if key=="nextSibling" or key=="previousSibling" then
				local index=if node.Parent then table.find(node.Parent.Children,node) else nil
				return wrap(if index then node.Parent.Children[index+(if key=="nextSibling" then 1 else -1)] else nil)
			end
			if key=="nextElementSibling" or key=="previousElementSibling" then
				local index=if node.Parent then table.find(node.Parent.Children,node) else nil
				if index then
					local direction=if key=="nextElementSibling" then 1 else -1;index+=direction
					while node.Parent.Children[index] do local sibling=node.Parent.Children[index];if sibling.Kind=="Element" then return wrap(sibling) end;index+=direction end
				end;return VM.Null
			end
			if key=="appendChild" then return function(args)return insert(node,unwrap(args[1]),nil)end end
			if key=="insertBefore" then return function(args)return insert(node,unwrap(args[1]),if args[2]==VM.Null or args[2]==VM.Undefined or args[2]==nil then nil else unwrap(args[2]))end end
			if key=="removeChild" then return function(args)return remove(node,unwrap(args[1]))end end
			if key=="replaceChild" then return function(args)
				local child,old=unwrap(args[1]),unwrap(args[2]);if old.Parent~=node then domError("NotFoundError","Node is not a child of this parent") end
				local index=table.find(node.Children,old);mutate(node,{child},node.Children[index+1],{old},old);return wrap(old)
			end end
			if node.Kind=="Document" or node.Kind=="DocumentFragment" or node.Kind=="ShadowRoot" or node.Kind=="Element" then
				if key=="moveBefore"and node.Kind~="Document"then return function(args)
					requireArgs(args,2);local child=unwrap(args[1]);local before=if args[2]==VM.Null or args[2]==VM.Undefined then nil else unwrap(args[2])
					if not child.Parent or (child.Kind~="Element"and child.Kind~="Text")or child.OwnerDocument~=(node.OwnerDocument or document)then domError("HierarchyRequestError","A state-preserving move requires a parent and the same document")end
					local function isConnected(raw)local root=ShadowTree.Root(raw);while root.Kind=="ShadowRoot"do root=ShadowTree.Root(root.Host)end;return root.Kind=="Document"end
					if isConnected(child)~=isConnected(node)then domError("HierarchyRequestError","State-preserving moves cannot change connectedness")end
					if child==before then return VM.Undefined end;mutate(node,{child},before,nil,nil,true);return VM.Undefined
				end end
				if key=="append" or key=="prepend" or key=="replaceChildren" then return function(args)
					local nodes=convert(args);mutate(node,nodes,if key=="prepend" then node.Children[1] else nil,if key=="replaceChildren" then table.clone(node.Children) else nil)
				end end
				if key=="querySelector" or key=="querySelectorAll" then return function(args)requireArgs(args,1);return query(node,args[1],key=="querySelector")end end
				if key=="getElementById" and node.Kind=="DocumentFragment" then return function(args)return wrap(findId(VM.string(args[1]),node))end end
			end
			if node.Kind=="Document" or node.Kind=="Element" then
				if key=="getElementsByClassName"or key=="getElementsByTagName"or key=="getElementsByTagNameNS"or(key=="getElementsByName"and node.Kind=="Document")then
					methods[key]=methods[key]or queryMethod(node,key);return methods[key]
				end
			end
			if node.Kind=="Element" or node.Kind=="Text" or node.Kind=="Comment" then
				if key=="remove" then return function()if node.Parent then remove(node.Parent,node) end end end
				if key=="before" or key=="after" or key=="replaceWith" then return function(args)
					local parent=node.Parent;if not parent then return end
					local index=table.find(parent.Children,node)
					mutate(parent,convert(args),if key=="before" then node else parent.Children[index+1],if key=="replaceWith" then {node} else nil)
				end end
			end
			if node.Kind=="Text"or node.Kind=="CDATASection"or node.Kind=="ProcessingInstruction" or node.Kind=="Comment" then
				if key=="data" then return node.Text elseif key=="length" then return Strings.length(node.Text) end
				if key=="substringData" then return function(args)requireArgs(args,2);return substring(node,args[1],args[2])end end
				if key=="appendData" then return function(args)requireArgs(args,1);local text=VM.string(args[1]);replaceData(node,Strings.length(node.Text),0,text)end end
				if key=="insertData" then return function(args)requireArgs(args,2);replaceData(node,args[1],0,args[2])end end
				if key=="deleteData" then return function(args)requireArgs(args,2);replaceData(node,args[1],args[2],"")end end
				if key=="replaceData" then return function(args)requireArgs(args,3);replaceData(node,args[1],args[2],args[3])end end
				if key=="wholeText" and node.Kind=="Text" then
					local siblings=if node.Parent then node.Parent.Children else {node};local index=table.find(siblings,node);local first,last=index,index
					while siblings[first-1] and siblings[first-1].Kind=="Text" do first-=1 end
					while siblings[last+1] and siblings[last+1].Kind=="Text" do last+=1 end
					local parts={};for i=first,last do table.insert(parts,siblings[i].Text) end;return table.concat(parts)
				end
				if key=="splitText" and node.Kind=="Text" then return function(args)
					requireArgs(args,1)
					return wrap(splitText(node,args[1]))
				end end
			end
			if node.Kind=="Document" then
				if key=="createElement" then return function(args)
					requireArgs(args,1)
					local name=reflectedString(args[1]);if node.IsHTML~=false then name=name:lower()end;if not Names.validElement(name)then domError("InvalidCharacterError","Invalid element name")end
					local createdNode=allocate(Node.element(name,{}),node);if node.IsHTML==false then createdNode.NamespaceURI=""end
					if Template.matches(createdNode)then allocate(Template.contents(createdNode,node),Template.owner(node))end
					createdElement(createdNode,args[2])
					return wrap(createdNode)
				end end
				if key=="createTextNode" then return function(args)requireArgs(args,1);local value=reflectedString(args[1]);assert(#value<=65536,"Text budget exceeded");return wrap(allocate(Node.text(value),node))end end
				if key=="createComment" then return function(args)requireArgs(args,1);local value=reflectedString(args[1]);assert(#value<=65536,"Comment budget exceeded");return wrap(allocate(Node.comment(value),node))end end
				if key=="createDocumentFragment" then return function()return wrap(allocate(Node.documentFragment(),node))end end
				if key=="getElementById" then return function(args)requireArgs(args,1);return wrap(findId(reflectedString(args[1]),node))end end
				if key=="importNode" then return function(args)
					local source=unwrap(args[1]);if source.Kind=="Document" then domError("NotSupportedError","Cannot import a Document") end
					if source.Kind=="ShadowRoot"then domError("NotSupportedError","Cannot import a ShadowRoot")end
					local copy=clone(source,args[2]~=nil and VM.truth(args[2]),node);return wrap(copy)
				end end
				if key=="adoptNode" then return function(args)
					local source=unwrap(args[1]);if source.Kind=="Document" then domError("NotSupportedError","Cannot adopt a Document") end
					if source.Kind=="ShadowRoot"then domError("HierarchyRequestError","Cannot adopt a ShadowRoot")end
					if source.Parent then remove(source.Parent,source) end;adopt(source,node);return args[1]
				end end
				if key=="readyState" then return host.ReadyState end
				if key=="currentScript" then return wrap(host.CurrentScript) end
				if key=="defaultView" then return host.Window end
			elseif node.Kind=="Element" then
				if key=="content" and Template.matches(node) then return wrap(node.Content) end
				if key=="areas"and ElementNames.html(node,"map")then
					-- A retained map can move between live document bridges. Scan its
					-- current light tree without retaining a revision or old entries.
					cached.areas=collectionView(function()
						return Queries.entries(node,"getElementsByTagNameNS",Names.HTML,"area",node.OwnerDocument or document,host.Step)()
					end,true)
					return cached.areas
				end
				local a=node.Attributes
				if (ElementNames.style(node) or ElementNames.htmlName(node)=="link") and (key=="media" or key=="type" or key=="title" or (ElementNames.htmlName(node)=="link" and key=="rel"))then return a[key]or ""end
				if ElementNames.htmlName(node)=="link" and key=="disabled"then return a.disabled~=nil end
				if ElementNames.htmlName(node)=="link" and key=="href"then
					if a.href==nil then return ""end
					local base=if host.ElementGet then host.ElementGet(document,"baseURI")else host.URL
					return if type(base)=="string"and base~=""then DocumentInfo.resolveURL(base,a.href)else a.href
				end
				if key=="tagName" then return if Queries.namespace(node)==Names.HTML and (node.OwnerDocument or document).IsHTML~=false then node.Name:upper()else node.Name elseif key=="localName" then return node.LocalName or node.Name end
				if ElementNames.htmlName(node)=="script" then
					if key=="async" then return node.ScriptAsync~=false or a.async~=nil end
					if key=="defer" or key=="noModule" then return a[if key=="noModule" then "nomodule" else key]~=nil end
					if key=="type" then return a.type or "" end
					if key=="text" then local parts={};for _,child in node.Children do if child.Kind=="Text" then table.insert(parts,child.Text) end end;return table.concat(parts) end
					if key=="src" then local source=a.src;if not source then return "" end;local base=if host.ElementGet then host.ElementGet(document,"baseURI")else host.URL;return DocumentInfo.resolveURL(base or "about:blank",source)end
				end
				if key=="namespaceURI" then return Queries.namespace(node)or VM.Null elseif key=="prefix" then return node.Prefix or VM.Null end
				local handled,reflected=reflectionBridge:Get(node,key);if handled then return reflected end
				if key=="id" then return a.id or "" elseif key=="className" then return a.class or "" elseif key=="hidden" then return a.hidden~=nil end
				if key=="value" and (ElementNames.htmlName(node)=="input" or ElementNames.htmlName(node)=="button" or ElementNames.htmlName(node)=="textarea" or ElementNames.htmlName(node)=="select" or ElementNames.htmlName(node)=="output" or ElementNames.htmlName(node)=="progress" or ElementNames.htmlName(node)=="meter") then return host.GetControl(node,key) end
				if key=="checked" and ElementNames.htmlName(node)=="input" then return host.GetControl(node,key) end
				if key=="style" then cached.style=if host.CreateInlineStyle then host.CreateInlineStyle(node,attribute)else Style.new(node,attribute);return cached.style end
				if key=="classList" then cached.classList=classList(node);return cached.classList end
				if key=="dataset" then cached.dataset=dataset(node);return cached.dataset end
				if key=="innerHTML" then return serialized(node,true) elseif key=="outerHTML" then return serialized(node) end
				if key=="matches" or key=="closest" then return function(args)
					requireArgs(args,1)
					local compiled=compile(args[1]);local current=node
					while current and current.Kind=="Element" do
						if matches(current,compiled,node) then return if key=="matches" then true else wrap(current) end
						if key=="matches" then return false end;current=current.Parent
					end;return VM.Null
				end end
				if key=="getAttribute"or key=="hasAttribute"then return function(args)requireArgs(args,1);local name=VM.string(args[1]);if Queries.namespace(node)==Names.HTML and(node.OwnerDocument or document).IsHTML~=false then name=name:lower()end;local stored=AttributeStore.qualified(node,name);return if key=='hasAttribute'then stored~=nil else if stored then a[stored]else VM.Null end end
				if key=="hasAttributes" then return function()return next(a)~=nil end end
				if key=="getAttributeNames" then return function()local result={};for _,stored in Markup.attributeNames(node)do table.insert(result,AttributeStore.name(node,stored))end;return array(result)end end
				if key=="setAttribute"or key=="removeAttribute"then return function(args)requireArgs(args,if key=='setAttribute'then 2 else 1);local name=VM.string(args[1]);if Queries.namespace(node)==Names.HTML and(node.OwnerDocument or document).IsHTML~=false then name=name:lower()end;if not Names.validAttribute(name)and key=='setAttribute'then domError('InvalidCharacterError','Invalid attribute name')end;local stored=AttributeStore.qualified(node,name);if key=='setAttribute'then attribute(node,stored or name,VM.string(args[2]))elseif stored then attribute(node,stored,nil)end end end
				if key=="toggleAttribute" then return function(args)
					requireArgs(args,1)
					local name=VM.string(args[1]);name=if Queries.namespace(node)==Names.HTML and(node.OwnerDocument or document).IsHTML~=false then name:lower()else name
					if not Names.validAttribute(name) then domError("InvalidCharacterError","Invalid attribute name") end
					local stored=AttributeStore.qualified(node,name);local present=stored~=nil;local wanted=if args[2]==nil then not present else VM.truth(args[2])
					if wanted and not present then attribute(node,name,"") elseif not wanted and present then attribute(node,stored,nil) end;return wanted
				end end
				if key=="insertAdjacentHTML" or key=="insertAdjacentText" or key=="insertAdjacentElement" then return function(args)
					local parent,before=adjacent(node,args[1])
					if not parent then
						if key=="insertAdjacentHTML" then domError("NoModificationAllowedError","Adjacent HTML requires an element parent") end
						return if key=="insertAdjacentElement" then VM.Null else VM.Undefined
					end
					local child
					if key=="insertAdjacentElement" then child=unwrap(args[2]);if child.Kind~="Element" then domError("TypeError","insertAdjacentElement requires an Element") end
					elseif key=="insertAdjacentText" then local text=VM.string(args[2]);assert(#text<=65536,"Text budget exceeded");child=allocate(Node.text(text))
					else child=parse(if parent.Kind=="Element" then parent else Node.element("body",{}),VM.string(args[2])) end
					insert(parent,child,before);return if key=="insertAdjacentElement" then wrap(child) else VM.Undefined
				end end
				if key=="click" then return function()
					if host.Click then host.Click(node)elseif host.Events then host.Events:Emit(node,"click",{isTrusted=false},{Bubbles=true,Cancelable=true,Composed=true})end
				end end
			end
			return VM.Undefined
		end
		readers[node]=read;object.DOMReader=read
		object.Get=function(key)
			check()
			local named,namedValue,indexed=namedGet(key);if indexed and named then return namedValue end
			local own=ownDescriptors[key];if own and own.Accessor then return if own.Get and own.Get~=VM.Undefined then realmVM:Call(own.Get,{},object)else VM.Undefined end
			if properties[key]~=nil then return properties[key] end
			if named then return namedValue end
			if key=='showPicker'and ElementNames.htmlName(node)=='select'and realmVM then
				local operation=realmVM.Get(realmVM.GetPrototype(object),key)
				if VM.callable(operation)then return operation end
			end
			local destination=ownerBridge(node);if destination~=bridge then return destination.NativeRead(node,key)end
			if methods[key] then return methods[key] end
			local value=read(key)
			if type(value)=="function" then
				local method=function(args,receiver)
					check()
					local destination=ownerBridge(node);if(receiver==nil or receiver==object)and destination~=bridge then local current=destination.NativeRead(node,key);if not VM.callable(current)then domError("TypeError","Incompatible DOM method receiver")end;return if type(current)=="function"then current(args,object)else realmVM:Call(current,args,object)end
					-- Direct host calls omit a receiver. JavaScript calls carry this;
					-- a borrowed method must operate on that compatible DOM wrapper.
					if receiver~=nil and receiver~=object then
						unwrap(receiver)
						if tableBridge:Has(node,key)and tableBridge.CompatibleMethod and not tableBridge:CompatibleMethod(node,receiver.DOMNode,key)then domError("TypeError","Incompatible table method receiver")end
						local target=ownerBridge(receiver.DOMNode).NativeRead(receiver.DOMNode,key)
						if type(target)~="function" then domError("TypeError","Incompatible DOM method receiver") end
						return target(args,receiver)
					end
					return value(args,object)
				end
				methods[key]=method;return method
			end
			return value
		end
		object.Set=function(key,value,strict)
			check()
			local named,_,indexed=namedGet(key)
			if named and(indexed or properties[key]==nil)then
				if strict~=false then domError("TypeError","Read-only DOM named property")end;return
			end
			local own=ownDescriptors[key]
			if own then
				if own.Accessor then if own.Set and own.Set~=VM.Undefined then realmVM:Call(own.Set,{value},object)elseif strict~=false then domError("TypeError","Read-only DOM expando")end;return
				elseif not own.Writable then if strict~=false then domError("TypeError","Read-only DOM expando")end;return end
				properties[key]=value;return
			end
			local destination=ownerBridge(node);if destination~=bridge and destination.NativeRead(node,key)~=VM.Undefined then return destination.NativeSet(node,key,value,strict)end
			if documentBridge:Set(node,key,value)then return end
			if attributeBridge:Set(node,key,value)then return end
			if host.EventSet and host.EventSet(node,key,value,strict) then return end
			if host.ElementSet and host.ElementSet(node,key,value,strict) then return end
			if shadowBridge and shadowBridge:Set(node,key,value,strict)then return end
			if tableBridge:Set(node,key,value,strict)then return end
			if listBridge:Set(node,key,value)then return end
			if controlBridge and controlBridge:Set(node,key,value,strict) then return end
			if reflectionBridge:Set(node,key,value)then return end
			if ElementNames.htmlName(node)=="script" and(key=="src" or key=="type" or key=="async" or key=="defer" or key=="noModule") then
				if key=="async" then node.ScriptAsync=false end
				local name=if key=="noModule" then "nomodule" else key
				attribute(node,name,if key=="src" or key=="type" then reflectedString(value) else if VM.truth(value) then "" else nil)
			elseif ElementNames.htmlName(node)=="script" and key=="text" then object.Set("textContent",reflectedString(value),strict)
			elseif key=="nodeValue" or ((node.Kind=="Text"or node.Kind=="CDATASection"or node.Kind=="ProcessingInstruction" or node.Kind=="Comment") and key=="data") then
				if node.Kind=="Text"or node.Kind=="CDATASection"or node.Kind=="ProcessingInstruction" or node.Kind=="Comment" then setData(node,if value==VM.Null then "" else VM.string(value)) end
			elseif key=="textContent" then
				if node.Kind=="Document"or node.Kind=="DocumentType"then return end
				local text=if value==VM.Null then "" else VM.string(value);assert(#text<=65536,"Text budget exceeded")
				if node.Kind=="Text" or node.Kind=="Comment" then setData(node,text);return end
				if host.ValidateText and connected(node) then host.ValidateText(node) end
				local sameText=(#node.Children==0 and text=="") or (#node.Children==1 and node.Children[1].Kind=="Text" and node.Children[1].Text==text)
				local replacements=if text=="" then {} else {allocate(Node.text(text))}
				local structural=false;for _,child in node.Children do if child.Kind=="Element" then structural=true;break end end
				if structural then
					mutate(node,replacements,nil,table.clone(node.Children))
				else
					local removed=table.clone(node.Children)
					for _,child in removed do Tree.remove(node,child,host,true)end
					if #replacements>0 then host.BeforeInsert(node,0,#replacements)end
					for _,child in replacements do Node.append(node,child) end
					if host.Mutation and(#removed>0 or #replacements>0)then host.Mutation({Type="childList",Target=node,AddedNodes=replacements,RemovedNodes=removed})end
				end
				-- Element setters still replace the DOM text node, as in a browser.
				-- Equal plain text does not change selectors or render geometry.
				if controlBridge then controlBridge:TextChanged(node) end
				if connected(node) and not sameText then host.Changed(node,"text") end
			elseif node.Kind=="Element" and key=="innerHTML" then
				local fragment=parse(node,if value==VM.Null then "" else VM.string(value))
				local target=if Template.matches(node) then node.Content else node
				mutate(target,{fragment},nil,table.clone(target.Children))
			elseif node.Kind=="Element" and key=="outerHTML" then
				local parent=node.Parent;if not parent then return end
				if parent.Kind=="Document" then domError("NoModificationAllowedError","Cannot replace the document element using outerHTML") end
				local context=if parent.Kind=="Element" then parent else Node.element("body",{})
				local index=table.find(parent.Children,node);local fragment=parse(context,if value==VM.Null then "" else VM.string(value))
				mutate(parent,{fragment},parent.Children[index+1],{node})
			elseif node.Kind=="Element" and ((key=="value" and (ElementNames.htmlName(node)=="input" or ElementNames.htmlName(node)=="button" or ElementNames.htmlName(node)=="textarea" or ElementNames.htmlName(node)=="select" or ElementNames.htmlName(node)=="output" or ElementNames.htmlName(node)=="progress" or ElementNames.htmlName(node)=="meter")) or (key=="checked" and ElementNames.htmlName(node)=="input")) then host.SetControl(node,key,value)
			elseif node.Kind=="Element" and (key=="id" or key=="className") then attribute(node,if key=="id" then "id" else "class",VM.string(value))
			elseif node.Kind=="Element" and key=="hidden" then attribute(node,"hidden",if VM.truth(value) then "" else nil)
			elseif node.Kind=="Element" and ElementNames.htmlName(node)=="link" and key=="disabled"then attribute(node,"disabled",if VM.truth(value)then""else nil)
			elseif node.Kind=="Element" and (ElementNames.style(node)or ElementNames.htmlName(node)=="link")and(key=="media"or key=="type"or key=="title"or(ElementNames.htmlName(node)=="link"and key=="rel"))then
				attribute(node,key,reflectedString(value))
			elseif node.Kind=="Element" and ElementNames.htmlName(node)=="link"and key=="href"then attribute(node,"href",reflectedString(value,true))
			elseif node.Kind=="Element" and key=="style" then local style=object.Get("style");style.Set("cssText",value)
			elseif node.Kind=="Element" and key=="classList" then attribute(node,"class",VM.string(value))
			elseif (READ_ONLY[key] and (if key=="areas"then ElementNames.html(node,"map")else read(key)~=VM.Undefined)) or NODE_CONSTANTS[key] then
				if strict~=false then domError("TypeError","Read-only DOM property: "..VM.string(key)) end
			else
				-- Custom-element prototype accessors retain their normal JavaScript
				-- receiver. DOM interfaces still own their reflected setters above.
				if properties[key]==nil and realmVM and object.Prototype then
					local proto=object.Prototype
					while proto and proto~=VM.Null do
						local d=realmVM.ObjectModel.Own(proto,key)
						if d then
							if d.Accessor then if d.Set and d.Set~=VM.Undefined then realmVM:Call(d.Set,{value},object)elseif strict~=false then domError("TypeError","Read-only inherited property")end;return end
							if not d.Writable then if strict~=false then domError("TypeError","Read-only inherited property")end;return end
							break
						end
						proto=realmVM.GetPrototype(proto)
					end
				end
				if properties[key]==nil then table.insert(propertyOrder,key)end;properties[key]=value
			end
		end
		object.Keys=function(enumerable)check();local keys=if controlBridge and controlBridge.NamedKeys then controlBridge:NamedKeys(node)or {}else {}
			for _,key in documentBridge:NamedKeys(node)or {}do if properties[key]==nil then table.insert(keys,key)end end
			for _,key in propertyOrder do if properties[key]~=nil and not table.find(keys,key)then
				if not enumerable or not ownDescriptors[key]or ownDescriptors[key].Enumerable then table.insert(keys,key)end
			end end;return keys end
		object.HasOwn=function(key)check();return properties[key]~=nil or namedGet(key)end
		object.Has=function(key)return object.Get(key)~=VM.Undefined end
		object.GetOwnPropertyDescriptor=function(key)
			check()
			local handled,value,indexed=namedGet(key)
			if handled and(indexed or properties[key]==nil)then return {Value=value,Writable=false,Enumerable=indexed==true or node.Kind=='Document',Configurable=true}end
			local d=ownDescriptors[key]
			if d then local copy=table.clone(d);if not copy.Accessor then copy.Value=properties[key]end;return copy end
			if properties[key]~=nil then return {Value=properties[key],Writable=true,Enumerable=true,Configurable=true}end
			return nil
		end
		object.DefineProperty=function(key,descriptor)
			check();local handled,_,indexed=namedGet(key);if handled and(indexed or properties[key]==nil)then return false end
			local d=realmVM.ObjectModel.ToDescriptor(descriptor);local old=object.GetOwnPropertyDescriptor(key)
			if not realmVM.ObjectModel.CompatibleDescriptor(object.Extensible~=false,d,old)then return false end
			local nextDescriptor=if old then table.clone(old)else realmVM.ObjectModel.CompleteDescriptor(d)
			if old and (d.Accessor or d.Value~=nil or d.Writable~=nil) and (d.Accessor==true)~=(old.Accessor==true)then nextDescriptor=realmVM.ObjectModel.CompleteDescriptor({Enumerable=old.Enumerable,Configurable=old.Configurable,Accessor=d.Accessor})end
			for name,item in d do nextDescriptor[name]=item end
			ownDescriptors[key]=nextDescriptor
			if properties[key]==nil and not table.find(propertyOrder,key)then table.insert(propertyOrder,key)end
			properties[key]=if nextDescriptor.Accessor then VM.Undefined else nextDescriptor.Value
			return true
		end
		object.SetPrototype=function(proto)
			if proto==object.Prototype then return true end;if object.Extensible==false then return false end
			local current=proto;while current and current~=VM.Null do if current==object then return false end;current=realmVM.GetPrototype(current)end
			object.Prototype=proto;return true
		end
		object.Delete=function(key)check();if properties[key]==nil and namedGet(key)then return false end;if ownDescriptors[key]and not ownDescriptors[key].Configurable then return false end
			properties[key]=nil;ownDescriptors[key]=nil;local index=table.find(propertyOrder,key);if index then table.remove(propertyOrder,index)end;return true end
		return object
	end
	wrap=function(node)
		if not node then return VM.Null end
		local object=canonical[node]
		if object and origins[object]and origins[object].Alive then return object end
		object=createWrapper(node);canonical[node]=object;return object
	end
	bridge.OwnerBridge=ownerBridge
	bridge.OriginBridge=function(node)local object=canonical[node];return if object then origins[object]else nil end
	bridge.NativeRead=function(node,key)
		check()
		-- SameObject belongs to the original wrapper even after adoption or a
		-- getter borrowed from another realm. Reuse that wrapper's sole cache.
		if key=="areas"and ElementNames.html(node,"map")then
			local origin=bridge.OriginBridge(node)
			if origin and origin~=bridge then return origin.NativeRead(node,key)end
		end
		createWrapper(node);return readers[node](key)
	end
	bridge.NativeSet=function(node,key,value,strict)check();return createWrapper(node).Set(key,value,strict)end
	bridge.Attribute=attribute;bridge.Mutate=mutate;bridge.Remove=remove;bridge.SetData=setData;bridge.Adopt=adopt
	bridge.InstallInterfaces=function(vm,globals)
		check();local installed=Interfaces.install(vm,globals,{Error=domError,Unwrap=unwrap,NativeRead=bridge.NativeRead,NativeSet=bridge.NativeSet,
			CreateElement=function(tag)return bridge.Document.Get("createElement")({tag})end})
		bridge.InterfacePrototypes=installed.CollectionPrototypes
		local states=setmetatable({},{__mode="k"});local prototype=vm.Object({})
		local function native(name,length,fn)return {Kind="native-function",Prototype=vm.Prototypes.Function,Values={name=name,length=length},Call=fn}end
		local constructor=native("DOMParser",0,function()domError("TypeError","DOMParser requires new")end)
		constructor.Construct=function()check();local instance=vm.Object({},prototype);states[instance]=true;return instance end
		vm.DefineProperty(constructor,"prototype",vm.Object({value=prototype},VM.Null))
		vm.DefineProperty(prototype,"constructor",vm.Object({value=constructor,writable=true,configurable=true},VM.Null))
		vm.DefineProperty(prototype,vm.SymbolToStringTag,vm.Object({value="DOMParser",configurable=true},VM.Null))
		vm.DefineProperty(prototype,"parseFromString",vm.Object({value=native("parseFromString",2,function(args,receiver)
			check();if not states[receiver]then domError("TypeError","Illegal DOMParser receiver")end;requireArgs(args,2)
			local source,kind=reflectedString(args[1]),reflectedString(args[2]);local parsed
			if kind=="text/html"then
				parsed=HTMLParser.parseDocument(source,{DisableDeclarativeShadowRoots=true});parsed.DetachedDocument=true;parsed.URL="about:blank"
			elseif kind=="text/xml"or kind=="application/xml"or kind=="application/xhtml+xml"or kind=="image/svg+xml"then
				local ok,value=pcall(XML.parse,source,kind);if ok then parsed=value else
					parsed=Node.document();parsed.IsHTML=false;parsed.ContentType=kind;parsed.DetachedDocument=true;parsed.URL="about:blank"
					local issue=Node.element("parsererror",{});issue.NamespaceURI="http://www.mozilla.org/newlayout/xml/parsererror.xml";Node.append(issue,Node.text(if type(value)=="table"then value.Message or"Invalid XML"else tostring(value)));Node.append(parsed,issue)
				end
			else domError("TypeError","Unsupported DOMParser MIME type")end
			parsed.URL=if host.ElementGet then host.ElementGet(document,"URL")or host.URL or"about:blank"else host.URL or"about:blank"
			countCreated(parsed,parsed);return wrap(parsed)
		end),writable=true,enumerable=true,configurable=true},VM.Null))
		globals.DOMParser=constructor;vm.Global.Bindings.DOMParser={Value=constructor}
		local xmlPrototype=vm.Object({})
		local xmlConstructor=native("XMLSerializer",0,function()domError("TypeError","XMLSerializer requires new")end)
		xmlConstructor.Construct=function()check();local instance=vm.Object({},xmlPrototype);xmlSerializers[instance]=true;return instance end
		vm.DefineProperty(xmlConstructor,"prototype",vm.Object({value=xmlPrototype},VM.Null))
		vm.DefineProperty(xmlPrototype,"constructor",vm.Object({value=xmlConstructor,writable=true,configurable=true},VM.Null))
		vm.DefineProperty(xmlPrototype,vm.SymbolToStringTag,vm.Object({value="XMLSerializer",configurable=true},VM.Null))
		vm.DefineProperty(xmlPrototype,"serializeToString",vm.Object({value=native("serializeToString",1,function(args,receiver)
			check();if not xmlSerializers[receiver]then domError("TypeError","Illegal XMLSerializer receiver")end;requireArgs(args,1)
			local raw=unwrap(args[1]);local ok,value=pcall(XMLSerialization.serialize,raw,false,false)
			if not ok then serializationError(tostring(value))end;return value
		end),writable=true,enumerable=true,configurable=true},VM.Null))
		globals.XMLSerializer=xmlConstructor;vm.Global.Bindings.XMLSerializer={Value=xmlConstructor}
		for node,object in wrappers do if customBridge then object.Prototype=customBridge:Prototype(node)end end
	end
	bridge.Document=wrap(document)
	bridge.Wrap=wrap
	bridge.ParserElement=function(node,parent)if customBridge then customBridge:ParserCreated(node,parent)end end
	bridge.Unwrap=unwrap
	bridge.AttachShadow=function(vm,settings)
		check();assert(not shadowBridge,"Shadow DOM already attached")
		settings=table.clone(settings);settings.Document=document;settings.Host=host;settings.Wrap=wrap;settings.Unwrap=unwrap
		settings.DOMError=domError;settings.RequireArgs=requireArgs;settings.ReflectedString=reflectedString;settings.Allocate=allocate
		settings.Attribute=attribute;settings.Mutate=mutate;settings.Parse=parse
		settings.CustomElements=function()return customBridge end
		shadowBridge=ShadowDOM.new(vm,settings);bridge.Shadow=shadowBridge;return shadowBridge
	end
	bridge.AttachCustomElements=function(custom)
		check();assert(not customBridge,"Custom elements already attached");customBridge=custom;bridge.CustomElements=custom
		for node,object in wrappers do object.Prototype=custom:Prototype(node)end
	end
	bridge.CustomContext=function()return {Document=document,Host=host,HostFor=function(node)return ownerBridge(node).Host end,Wrap=wrap,Unwrap=unwrap,Allocate=allocate,DOMError=domError,
		ReflectedString=reflectedString,Attribute=attribute,Connected=connected,Markup=Markup,CollectionView=collectionView,
		NativeGet=function(node,key)wrap(node);return readers[node](key)end,
		NativeSet=function(node,key,value)
			if tableBridge:Set(node,key,value,true)then return end
			if shadowBridge and shadowBridge:Set(node,key,value,true)then return end
			wrap(node).Set(key,value,true)
		end}end
	bridge.AttachVM=function(vm)check();assert(not realmVM,"DOM already attached to a JavaScript realm");realmVM=vm end
	bridge.AttachTraversal=function(traversal)check();assert(not traversalBridge,"Traversal already attached");traversalBridge=traversal;bridge.Traversal=traversal end
	bridge.AttachRanges=function(ranges)check();assert(not rangeBridge,"Ranges already attached");rangeBridge=ranges;bridge.Ranges=ranges end
	bridge.RangeContext=function()
		check();return {Wrap=wrap,Unwrap=unwrap,Clone=clone,Fragment=function()check();return allocate(Node.documentFragment())end,
			Text=function(text)check();assert(#text<=65536,"Text budget exceeded");return allocate(Node.text(text))end,
			Element=function(name,namespace)check();local raw=allocate(Node.element(name,{}));raw.NamespaceURI=namespace;return raw end,
			Parse=function(context,source)return parse(context,source,false)end,Insert=function(parent,child,before)mutate(parent,{child},before);return child end,
			Remove=function(child)if child.Parent then remove(child.Parent,child)end end,
			Clear=function(parent)mutate(parent,{},nil,table.clone(parent.Children))end,
			ReplaceData=replaceData,SplitText=splitText,SetData=setData,
			ValidateStructure=function(parent,child,oldParent)check();if host.ValidateStructure then host.ValidateStructure(parent,child,oldParent)end end,
			ValidateInsert=function(parent,child,before)
				check();local ok,plan=pcall(function()Node.validateInsert(parent,child,before);return Tree.plan(parent,Tree.flatten({child}),before)end)
				if not ok then domError("HierarchyRequestError",tostring(plan))end;Tree.validate(plan,host)
			end}
	end
	bridge.BeforeRemove=host.BeforeRemove
	bridge.WindowMethod=function(key)return eventMethod(nil,key)end
	bridge.Serialize=function(node,childrenOnly)return serialized(unwrap(node),childrenOnly)end
	bridge.AttachControls=function(controls)
		check();assert(not controlBridge,"Controls are already attached")
		controlBridge=controls;bridge.Controls=controls
		controls:Attach(wrap,attribute,function(node,text)wrap(node).Set("textContent",text)end,collectionView,{
			Clone=function(node)return clone(node,true)end,
			Replace=function(node,children)mutate(node,children,nil,table.clone(node.Children))end,
		})
	end
	if host.Controls or host.ControlAdapter then bridge.AttachControls(host.Controls or Controls.new(document,host.ControlAdapter)) end
	function bridge:Destroy()
		if not self.Alive then return end;self.Alive=false
		documentBridge:Destroy()
		disclosures:Destroy()
		for _,entry in listeners do entry.Connection:Disconnect() end
		for node,object in wrappers do
			node.DOMWrappers[bridge]=nil;if not next(node.DOMWrappers)then node.DOMWrappers=nil end
			object.DOMReader=nil
		end
		table.clear(listeners);table.clear(wrappers);table.clear(readers);table.clear(disconnectedOrder);table.clear(eventWrappers)
		if controlBridge then controlBridge:Destroy() end
		if traversalBridge then traversalBridge:Destroy()end
		if rangeBridge then rangeBridge:Destroy()end
		if shadowBridge then shadowBridge:Destroy()end
	end
	return bridge
end
return DOM
