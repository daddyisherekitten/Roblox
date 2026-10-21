--!strict
-- RFC 4647 extended filtering for :lang(). Compiled ranges contain no DOM.
local Range={}
function Range.compile(value: string): any
	value=value:lower()
	if value==""then return {Unknown=true}end
	if value:sub(1,1)=="-"or value:sub(-1)=="-"or value:find("--",1,true)then return {Invalid=true}end
	local parts={}
	for part in value:gmatch("[^-]+")do
		if part~="*"and (#part>8 or not part:match(if #parts==0 then "^[a-z]+$"else "^[a-z0-9]+$"))then return {Invalid=true}end
		table.insert(parts,part)
	end
	return {Parts=parts}
end
function Range.matches(language: string,range: any): boolean
	if range.Invalid then return false end
	if range.Unknown then return language==""end
	if language==""or language:sub(1,1)=="-"or language:sub(-1)=="-"or language:find("--",1,true)then return false end
	local tag={}
	for part in language:lower():gmatch("[^-]+")do
		if #part>8 or not part:match(if #tag==0 then "^[a-z]+$"else "^[a-z0-9]+$")then return false end
		table.insert(tag,part)
	end
	local parts=range.Parts
	if #tag==0 or (parts[1]~="*"and parts[1]~=tag[1])then return false end
	local i,j=2,2
	while i<=#parts do
		if parts[i]=="*"then i+=1
		elseif j>#tag then return false
		elseif parts[i]==tag[j]then i+=1;j+=1
		elseif #tag[j]==1 then return false -- Extensions/private use form a barrier.
		else j+=1 end
	end
	return true
end
function Range.language(node: any): string
	local document=if node.Kind=='Document'then node else node.OwnerDocument
	while node do
		local attributes=node.Attributes
		if node.Kind=="Element"and attributes then
			for key,metadata in node.AttributeNamespaces or{}do
				if metadata.Namespace=="http://www.w3.org/XML/1998/namespace"and metadata.LocalName=="lang"and attributes[key]~=nil then return attributes[key]end
			end
			local namespace=node.NamespaceURI
			if (not namespace or namespace=="http://www.w3.org/1999/xhtml"or namespace=="http://www.w3.org/2000/svg")and attributes.lang~=nil and not (node.AttributeNamespaces or{}).lang then return attributes.lang end
		end
		if node.Kind=="Document"then return node.ContentLanguage or ""end
		node=if node.Kind=="ShadowRoot"then node.Host else node.Parent
	end
	return if document then document.ContentLanguage or ''else ''
end
return Range
