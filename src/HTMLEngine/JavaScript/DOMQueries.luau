--!strict
-- Live legacy queries traverse the light tree only. Arguments are converted by
-- the DOM binding once; views retain strings and their root, never coercion objects.
local DocumentMode=require(script.Parent.Parent.DOM.DocumentMode)
local Queries={}
Queries.HTML="http://www.w3.org/1999/xhtml"
local function namespace(node: any): any
	-- Parser/native HTML data uses nil for the implicit HTML namespace.
	return if node.NamespaceURI==nil then Queries.HTML elseif node.NamespaceURI=="" then nil else node.NamespaceURI
end
Queries.namespace=namespace

function Queries.entries(root: any,method: string,first: any,second: any,document: any,step: any,revision: any?): any
	local tokens,required={},{}
	local function charge()if step then step()end end
	local function lower(value: string): string return (value:gsub("[A-Z]",string.lower))end
	if method=="getElementsByClassName"then
		for token in first:gmatch("[^\t\n\f\r ]+")do charge();if not required[token]then required[token]=true;table.insert(tokens,token)end end
		if #tokens==0 then return function()return {}end end
	elseif method=="getElementsByTagNameNS"and first==""then first=nil end
	local lowered=if method=="getElementsByTagName"then lower(first)else nil
	local quirks=false
	local function matches(node: any): boolean
		if method=="getElementsByName"then return namespace(node)==Queries.HTML and node.Attributes.name==first end
		if method=="getElementsByTagName"then return first=="*"or node.Name==(if namespace(node)==Queries.HTML and document.IsHTML~=false then lowered else first)end
		if method=="getElementsByTagNameNS"then
			return (first=="*"or namespace(node)==first)and(second=="*"or(node.LocalName or node.Name)==second)
		end
		if #tokens==0 then return false end
		local present={}
		for token in(node.Attributes.class or ""):gmatch("[^\t\n\f\r ]+")do charge();present[if quirks then lower(token)else token]=true end
		for _,token in tokens do charge();if not present[if quirks then lower(token)else token]then return false end end
		return true
	end
	local cachedVersion,cachedOwner,cachedDocument,cached=nil,nil,nil,nil
	return function()
		local version,revisionOwner=nil,nil
		if revision then version,revisionOwner=revision()end
		local owner=DocumentMode.document(root)or document
		if revision and cachedVersion==version and cachedOwner==revisionOwner and cachedDocument==owner and cached then return cached end
		quirks=owner.Mode=='quirks'
		local result,pending={},{}
		for index=#root.Children,1,-1 do table.insert(pending,root.Children[index])end
		while #pending>0 do
			charge();local node=table.remove(pending)
			if node.Kind=="Element"and matches(node)then table.insert(result,node)end
			for index=#node.Children,1,-1 do table.insert(pending,node.Children[index])end
		end
		cachedVersion,cachedOwner,cachedDocument,cached=version,revisionOwner,owner,result
		return result
	end
end
return Queries
