--!strict
-- Evaluate document metadata at mount and after relevant metadata mutations.
-- Ordinary body edits reuse the mounted cache.
local Node = require(script.Parent.Parent.DOM.Node)
local SourceDocument=require(script.Parent.Parent.DOM.MediaSourceDocument)
local URL = require(script.Parent.Parent.Navigation.URL)
local URLRecord = require(script.Parent.Parent.JavaScript.URLRecord)
local WorkContext=require(script.Parent.Parent.WorkContext)
local Accessors=require(script.Parent.Parent.DOM.DocumentAccessors)

local DocumentInfo = {}
local HTML_NAMESPACE = nil

local function lowerTrim(value: string?): string
	return ((value or ""):match("^%s*(.-)%s*$") or ""):lower()
end

local function resolve(documentURL: string, reference: string): string
	if documentURL:match("^[%a][%w+%.%-]*:")or reference:match("^[%a][%w+%.%-]*:")then
		local ok,address=pcall(URLRecord.resolve,reference,if documentURL:match("^[%a][%w+%.%-]*:")then documentURL else nil,WorkContext.checkpoint)
		return if ok then address else reference
	end
	local result = URL.resolve(documentURL, reference)
	return result.URL or result.Path or reference
end
DocumentInfo.resolveURL=resolve

local function frozenBase(documentURL: string, reference: string): string
	-- URL parsing removes ASCII tabs/newlines and surrounding C0 controls.
	-- The first base still wins when its scheme requires the fallback URL.
	local cleaned = reference:gsub("[\t\n\r]", ""):gsub("^[%z\1-\32]+", ""):gsub("[%z\1-\32]+$", "")
	local baseScheme = documentURL:match("^([%a][%w+%.%-]*):")
	local inputScheme = cleaned:match("^([%a][%w+%.%-]*):")
	-- Local catalog paths deliberately have no network origin. Keep that host
	-- contract while validating absolute addresses with the shared URL parser.
	if not baseScheme and not inputScheme then return resolve(documentURL, cleaned) end
	local ok, address, record = pcall(URLRecord.resolve, cleaned, if baseScheme then documentURL else nil, WorkContext.checkpoint)
	if not ok or record.Scheme == "data" or record.Scheme == "javascript" then return documentURL end
	return address
end

local function isBase(node: any): boolean
	return Accessors.matches(node,"base",Accessors.HTML)
end

local function hrefValue(node: any): string?
	local info=node.AttributeNamespaces and node.AttributeNamespaces.href
	return if info and info.Namespace~=nil and info.Namespace~="" then nil else node.Attributes.href
end

function DocumentInfo.fallbackBase(document: any, documentURL: string?): string
	return document.FallbackBaseURL or documentURL or document.URL or "about:blank"
end

function DocumentInfo.baseURL(document: any, documentURL: string?, scan: boolean?, reset: boolean?): string
	local fallback=DocumentInfo.fallbackBase(document,documentURL)
	local state=document.BaseURLState
	if not state or scan then
		local first=Node.findElement(document,function(node)return isBase(node) and hrefValue(node)~=nil end)
		local href=if first then hrefValue(first) else nil
		if not state or state.First~=first or state.Href~=href or reset then
			state={First=first,Href=href,Frozen=if first then frozenBase(fallback,href)else nil}
			document.BaseURLState=state
		end
	end
	local result=state.Frozen or fallback
	SourceDocument.observe(document,result,documentURL or document.URL)
	return result
end

-- Recompute only when the edited subtree can change the first participating
-- base element. Ordinary metadata, paint and text do not thaw a frozen URL.
function DocumentInfo.baseMutation(document: any, documentURL: string?, record: any)
	local target=record.Target;local root=target
	while root and root~=document do root=root.Parent end
	if root~=document then return end
	local reset=false
	if record.Type=="attributes" then
		if not isBase(target) or record.AttributeName~="href" or record.AttributeNamespace~=nil then return end
		reset=document.BaseURLState~=nil and document.BaseURLState.First==target
	elseif record.Type=="childList" then
		local pending={}
		for _,list in {record.AddedNodes or{},record.RemovedNodes or{}} do for _,node in list do table.insert(pending,node)end end
		local affected=false
		while #pending>0 do
			WorkContext.checkpoint();local node=table.remove(pending)
			if isBase(node) then affected=true;break end
			for _,child in node.Children or{} do table.insert(pending,child)end
		end
		if not affected then return end
	else return end
	DocumentInfo.baseURL(document,documentURL,true,reset)
end

function DocumentInfo.baseHref(document: any, documentURL: string?, source: string): string
	local fallback=DocumentInfo.fallbackBase(document,documentURL)
	return resolve(fallback,source)
end

local function viewport(content: string): {[string]: string}
	local result = {}
	for entry in (content .. ","):gmatch("(.-),") do
		local name, value = entry:match("^%s*([^=%s]+)%s*=%s*(.-)%s*$")
		if name and value and value ~= "" then result[name:lower()] = value end
	end
	return result
end

function DocumentInfo.collect(document: any, documentURL: string?, diagnostic: ((string) -> ())?): any
	documentURL = if documentURL and documentURL ~= "" then documentURL else "/"
	local info: any = {
		Title = "",
		DocumentURL = documentURL,
		BaseURL = DocumentInfo.baseURL(document,documentURL,true),
		DefaultTarget = "",
		Charset = (document.CharacterEncoding or 'UTF-8'):lower(),
		ContentLanguage = document.ContentLanguage or '',
		Metadata = {},
		MetaByName = {},
		HTTPPragmas = {},
		Links = {},
		Viewport = {},
	}
	local titleFound,baseTargetFound = false,false
	local root=Accessors.root(document)
	local pending = { document }
	while #pending > 0 do
		WorkContext.checkpoint()
		local node = table.remove(pending)
		if not titleFound and Accessors.titleCandidate(root,node)then
			titleFound=true;info.Title=Accessors.normalizedTitle(node)
		end
		if node.Kind == "Element" and (node.NamespaceURI == HTML_NAMESPACE or node.NamespaceURI == "http://www.w3.org/1999/xhtml") then
			local attributes = node.Attributes
			local name=node.LocalName or node.Name
			if name == "base" then
				if not baseTargetFound and attributes.target ~= nil then
					baseTargetFound = true
					info.DefaultTarget = if attributes.target:find("[\t\n\r<]") then "_blank" else attributes.target
				end
			elseif name == "meta" then
				local entry = {
					Name = lowerTrim(attributes.name),
					HTTPEquiv = lowerTrim(attributes["http-equiv"]),
					Content = attributes.content or "",
					Charset = lowerTrim(attributes.charset),
					Media = attributes.media or "",
					Node = node,
				}
				table.insert(info.Metadata, entry)
				if entry.Charset ~= "" and not document.CharacterEncoding then
					if entry.Charset == "utf-8" or entry.Charset == "utf8" then info.Charset = "utf-8"
					elseif diagnostic then diagnostic("Unsupported meta charset for an already decoded Luau string: " .. entry.Charset) end
				end
				if entry.Name ~= "" and info.MetaByName[entry.Name] == nil then info.MetaByName[entry.Name] = entry.Content end
				if entry.HTTPEquiv ~= "" and info.HTTPPragmas[entry.HTTPEquiv] == nil then info.HTTPPragmas[entry.HTTPEquiv] = entry.Content end
				if entry.Name == "viewport" and next(info.Viewport) == nil then info.Viewport = viewport(entry.Content)
				elseif entry.Name == "theme-color" and info.ThemeColor == nil then info.ThemeColor = entry.Content
				elseif entry.Name == "referrer" and info.ReferrerPolicy == nil then info.ReferrerPolicy = lowerTrim(entry.Content) end
			elseif name == "link" then
				local href = attributes.href or ""
				table.insert(info.Links, {
					Rel = lowerTrim(attributes.rel),
					Href = href,
					Media = attributes.media or "",
					Type = lowerTrim(attributes.type),
					Disabled = attributes.disabled ~= nil,
					Node = node,
				})
			end
		end
		for index = #node.Children, 1, -1 do table.insert(pending, node.Children[index]) end
	end
	-- The first base href applies to the whole document, including link elements
	-- that occurred before it in source order.
	for _, link in info.Links do link.URL = resolve(info.BaseURL, link.Href) end
	return info
end

return DocumentInfo
