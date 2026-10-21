--!strict
local Node=require(script.Parent.Parent.DOM.Node)
local Template=require(script.Parent.Parent.DOM.TemplateDocument)
local VM=require(script.Parent.VM)
local Names=require(script.Parent.DOMNames)
local Streams=require(script.Parent.DocumentStreams)
local NamedProperties=require(script.Parent.DOMNamedProperties)
local DocumentCollections=require(script.Parent.DocumentCollections)
local DocumentInfo=require(script.Parent.Parent.HTML.DocumentInfo)
local Accessors=require(script.Parent.Parent.DOM.DocumentAccessors)
local SVG=Accessors.SVG
local Documents={}
function Documents.new(ctx: any): any
	-- Luau weak keys are not ephemerons: a factory closes over its document.
	-- Held factories keep their owner; unused factory/document cycles may collect.
	local api={};local implementations=setmetatable({},{__mode="kv"})
	local streams=Streams.new(ctx)
	local collections=DocumentCollections.new(ctx)
	local named=NamedProperties.new({Wrap=ctx.Wrap,Collection=ctx.Collection,Step=ctx.Step,FrameWindow=ctx.FrameWindow})
	api.NamedProperties=named
	function api:Mutation(record)collections:Mutation(record)end
	function api:NamedGet(node,key)return named:Get(node,'Document',key)end
	function api:NamedKeys(node)return if node.Kind=='Document'then named:Keys(node,'Document')else nil end
	local function fail(name,message)ctx.Error(name,message)end
	local function text(value)return ctx.String(if value==nil then VM.Undefined else value)end
	local function owned(node,document)return ctx.Allocate(node,document)end
	local function element(document,name,namespace)
		local raw=Node.element(name,{});raw.NamespaceURI=namespace;return owned(raw,document)
	end
	local function direct(document,raw)Node.append(document,raw);return raw end
	local function detached(html,contentType)
		local doc=owned(Node.document());doc.IsHTML=html;doc.ContentType=contentType;doc.Mode="no-quirks";doc.URL="about:blank";doc.DetachedDocument=true;return doc
	end
	local function factory(document)
		local made={DOMCollectionKind="DOMImplementation",GetPrototype=function()return ctx.Prototype("DOMImplementation")end,Get=function(key)
			if key=="hasFeature"then return function()return true end end
			if key=="createDocumentType"then return function(args)
				ctx.RequireArgs(args,3);local name=text(args[1]);if not Names.valid(name)then fail("InvalidCharacterError","Invalid doctype name")end
				return ctx.Wrap(owned(Node.documentType(name,text(args[2]),text(args[3])),document))
			end end
			if key=="createDocument"then return function(args)
				ctx.RequireArgs(args,2);local namespace=if args[1]==VM.Null or args[1]==VM.Undefined then nil else text(args[1]);local name=if args[2]==VM.Null then""else text(args[2]);local root
				local uri,localName,prefix;if name~=""then uri,localName,prefix=Names.extract(namespace,name,fail)end
				local doc=detached(false,if uri==Names.HTML then"application/xhtml+xml"elseif uri=="http://www.w3.org/2000/svg"then"image/svg+xml"else"application/xml")
				local doctype=args[3];if doctype~=nil and doctype~=VM.Null and doctype~=VM.Undefined then
					local raw=ctx.Unwrap(doctype);if raw.Kind~="DocumentType"then fail("TypeError","Expected a DocumentType")end;ctx.Mutate(doc,{raw})
				end
				if name~=""then root=element(doc,name,uri or "");root.LocalName,root.Prefix=localName,prefix
					if Template.matches(root)then owned(Template.contents(root,doc),Template.owner(doc))end;direct(doc,root)end
				return ctx.Wrap(doc)
			end end
			if key=="createHTMLDocument"then return function(args)
				local title=if args[1]~=nil and args[1]~=VM.Undefined then text(args[1])else nil
				local doc=detached(true,"text/html");direct(doc,owned(Node.documentType("html","",""),doc))
				local html=direct(doc,element(doc,"html"));local head=element(doc,"head");Node.append(html,head);Node.append(html,element(doc,"body"))
				if title~=nil then local titleNode=element(doc,"title");Node.append(head,titleNode);Node.append(titleNode,owned(Node.text(title),doc))end
				return ctx.Wrap(doc)
			end end
			return VM.Undefined
		end};return made
	end
	function api:Get(node,key)
		if node.Kind=="DocumentType"then
			if key=="name"then return true,node.Name elseif key=="publicId"then return true,node.PublicId or""elseif key=="systemId"then return true,node.SystemId or""end;return false
		elseif node.Kind=="ProcessingInstruction"and key=="target"then return true,node.Target end
		if node.Kind~="Document"then return false end
		local listHandled,list=collections:Get(node,key);if listHandled then return true,list end
		local streamHandled,streamMethod=streams:Get(node,key);if streamHandled then return true,streamMethod end
		if key=="implementation"then
			local implementation=implementations[node]
			if not implementation then implementation=factory(node);implementations[node]=implementation end
			return true,implementation
		end
		if key=="compatMode"then return true,if node.Mode=="quirks"then"BackCompat"else"CSS1Compat"end
		if key=="contentType"then return true,node.ContentType or"text/html"end
		if key=="characterSet"or key=="charset"or key=="inputEncoding"then return true,node.CharacterEncoding or 'UTF-8'end
		if node.DetachedDocument and key=="baseURI"then return true,DocumentInfo.baseURL(node,node.URL,true)end
		if node.DetachedDocument and(key=="URL"or key=="documentURI")then return true,node.URL or"about:blank"end
		if key=="defaultView"and node.DetachedDocument then return true,VM.Null end
		if key=="location"and node.DetachedDocument then return true,VM.Null end
		if key=="doctype"or key=="documentElement"then
			for _,child in node.Children do if child.Kind==(if key=="doctype"then"DocumentType"else"Element")then return true,ctx.Wrap(child)end end;return true,VM.Null
		end
		if key=="head"or key=="body"then
			local target=if key=="head"then Accessors.head(node,ctx.Step)else Accessors.body(node,ctx.Step)
			return true,if target then ctx.Wrap(target)else VM.Null
		end
		if key=="title"then
			return true,Accessors.titleText(node,ctx.Step)
		end
		if key=="createCDATASection"then return true,function(args)
			ctx.RequireArgs(args,1);if node.IsHTML~=false then fail("NotSupportedError","HTML documents cannot create CDATA sections")end
			local value=text(args[1]);if value:find("]]>",1,true)then fail("InvalidCharacterError","CDATA cannot contain ]]>")end
			return ctx.Wrap(owned(Node.cdata(value),node))
		end end
		if key=="createProcessingInstruction"then return true,function(args)
			ctx.RequireArgs(args,2);local target,value=text(args[1]),text(args[2]);if not Names.valid(target)or value:find("?>",1,true)then fail("InvalidCharacterError","Invalid processing instruction")end
			return ctx.Wrap(owned(Node.processingInstruction(target,value),node))
		end end
		if key=="createElementNS"then return true,function(args)
			ctx.RequireArgs(args,2);local namespace=if args[1]==VM.Null or args[1]==VM.Undefined then nil else text(args[1]);local name=text(args[2]);local uri,localName,prefix=Names.extract(namespace,name,fail)
			local raw=element(node,name,uri or"");raw.LocalName,raw.Prefix=localName,prefix
			if Template.matches(raw)then owned(Template.contents(raw,node),Template.owner(node))end
			if ctx.Created and uri==Names.HTML then ctx.Created(raw,args[3])end
			return ctx.Wrap(raw)
		end end
		return false
	end
	function api:Set(node,key,value)
		if node.Kind~="Document"then return false end
		if key=="body"then
			if value==VM.Null or value==VM.Undefined then fail("HierarchyRequestError","Document body must be body or frameset")end
			local raw=ctx.Unwrap(value)
			if raw.Kind~="Element"or(raw.NamespaceURI or Names.HTML)~=Names.HTML then fail("TypeError","Document body requires an HTMLElement")end
			if not Accessors.matches(raw,"body",Names.HTML)and not Accessors.matches(raw,"frameset",Names.HTML)then fail("HierarchyRequestError","Document body must be body or frameset")end
			local current=Accessors.body(node,ctx.Step);if current==raw then return true end
			if current then ctx.Mutate(current.Parent,{raw},current,{current},current)
			else local root=Accessors.root(node);if not root then fail("HierarchyRequestError","Document has no root element")end;ctx.Mutate(root,{raw})end
			return true
		elseif key=="title"then
			local title=text(value);local root=Accessors.root(node);local target
			if Accessors.matches(root,"svg",SVG)then
				target=Accessors.child(root,"title",SVG,ctx.Step)
				if not target then target=element(node,"title",SVG);ctx.Mutate(root,{target},root.Children[1])end
			elseif root and(root.NamespaceURI or Names.HTML)==Names.HTML then
				target=Accessors.title(node,ctx.Step)
				if not target then local head=Accessors.head(node,ctx.Step);if not head then return true end;target=element(node,"title");ctx.Mutate(head,{target})end
			else return true end
			ctx.Wrap(target).Set("textContent",title);return true
		end
		return false
	end
	function api:Destroy()streams:Destroy();named:Destroy();collections:Destroy();table.clear(implementations)end
	return api
end
return Documents
