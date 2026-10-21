--!strict
-- HTML mutation shares the existing tokenizer/tree builder. This adapter keeps
-- template contents inert and supplies ordinary HTML fragment contexts.
local Node = require(script.Parent.Parent.DOM.Node)
local Template=require(script.Parent.Parent.DOM.TemplateDocument)
local XML=require(script.Parent.DOMXML)
local XMLSerialization=require(script.Parent.XMLSerialization)
local Parser = require(script.Parent.Parent.HTML.Parser)
local Store=require(script.Parent.Parent.DOM.AttributeStore)
local Markup = {}
local void = {area=true,base=true,br=true,col=true,embed=true,hr=true,img=true,input=true,link=true,meta=true,param=true,source=true,track=true,wbr=true,
	basefont=true,bgsound=true,frame=true,keygen=true}
local HTML="http://www.w3.org/1999/xhtml"
local function isHTML(node)return node.NamespaceURI==nil or node.NamespaceURI==HTML end
local function serializesVoid(node)return node.Kind=="Element"and isHTML(node)and void[node.LocalName or node.Name]end
local function tagName(node)
	local namespace=node.NamespaceURI
	return if isHTML(node)or namespace=="http://www.w3.org/2000/svg"or namespace=="http://www.w3.org/1998/Math/MathML"then node.LocalName or node.Name else node.Name
end
local raw = {script=true,style=true,xmp=true,iframe=true,noembed=true,noframes=true,plaintext=true}
local function scriptingEnabled(context: any): boolean
	local owner=context.OwnerDocument
	if not owner then
		owner=context
		while owner and owner.Kind~='Document'do owner=owner.Parent or owner.Host end
	end
	return owner~=nil and owner.ScriptingEnabled==true
end
local function rawContext(context: any): boolean
	local name=context.LocalName or context.Name
	return isHTML(context) and (raw[name]==true or (name=='noscript'and scriptingEnabled(context)))
end

Markup.attributeNames=Store.keys

local function escape(value: string, attribute: boolean): string
	value = value:gsub("&", "&amp;"):gsub(utf8.char(160), "&nbsp;")
	return if attribute then (value:gsub('"', "&quot;")) else (value:gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Markup.serialize(root: any, childrenOnly: boolean?): string
	local document=if root.Kind=="Document"then root else root.OwnerDocument
	local html=not document or document.IsHTML~=false
	if not html then return XMLSerialization.serialize(root,childrenOnly,true)end
	if html and childrenOnly and serializesVoid(root)then return ""end
	local parts, size, pending = {}, 0, {}
	local function emit(value: string)
		size += #value
		assert(size <= 1024 * 1024, "Serialized HTML budget exceeded")
		table.insert(parts, value)
	end
	local function pushChildren(node: any)
		local children = if Template.matches(node) and node.Content then node.Content.Children else node.Children
		for index = #children, 1, -1 do table.insert(pending, {Node=children[index], Parent=node}) end
	end
	if childrenOnly then pushChildren(root) else table.insert(pending, {Node=root}) end
	while #pending > 0 do
		local entry = table.remove(pending)
		if entry.Close then emit("</" .. entry.Close .. ">"); continue end
		local node = entry.Node
		if node.Kind == "Text"or node.Kind=="CDATASection"then
			emit(if entry.Parent and rawContext(entry.Parent) then node.Text else escape(node.Text, false))
		elseif node.Kind=="ProcessingInstruction"then emit("<?"..node.Target.." "..node.Text.."?>")
		elseif node.Kind=="DocumentType"then emit("<!DOCTYPE "..node.Name..">")
		elseif node.Kind == "Comment" then emit("<!--" .. node.Text .. "-->")
		elseif node.Kind == "Element" then
			local name=tagName(node)
			emit("<" .. name)
			local keys = Markup.attributeNames(node)
			for _, key in keys do
				local namespace=Store.namespace(node,key);local info=node.AttributeNamespaces and node.AttributeNamespaces[key]
				local name=if namespace=='http://www.w3.org/XML/1998/namespace'then 'xml:'..info.LocalName
					elseif namespace=='http://www.w3.org/2000/xmlns/'then if info.LocalName=='xmlns'then 'xmlns'else 'xmlns:'..info.LocalName
					elseif namespace=='http://www.w3.org/1999/xlink'then 'xlink:'..info.LocalName else Store.name(node,key)
				emit(" "..name..'="'..escape(node.Attributes[key],true)..'"')
			end
			emit(">")
			if not serializesVoid(node) then
				table.insert(pending, {Close=name})
				pushChildren(node)
			end
		else pushChildren(node) end
	end
	return table.concat(parts)
end

function Markup.parse(context: any, source: string): any
	if context.OwnerDocument and context.OwnerDocument.IsHTML==false then return XML.fragment(source,context)end
	local enabled=scriptingEnabled(context)
	local element=if context.Kind=="ShadowRoot" then context.Host else context
	if element.Kind~="Element" then element=Node.element("body",{}); element.OwnerDocument=context.OwnerDocument end
	return Parser.parseFragment(source,element,{MaxNodes=8192,ScriptingEnabled=enabled})
end

return Markup
