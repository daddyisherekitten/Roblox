--!strict
-- HTML template contents own one inert document per source document. The
-- association belongs to the document itself; no global cache retains pages.
local WorkContext=require(script.Parent.Parent.WorkContext)
local SourceDocument=require(script.Parent.MediaSourceDocument)
local Template={}
local HTML='http://www.w3.org/1999/xhtml'
function Template.matches(node: any): boolean
	return node.Kind=='Element'and(node.NamespaceURI==nil or node.NamespaceURI==HTML)and(node.LocalName or node.Name)=='template'
end
function Template.owner(document: any): any
	if document.InertTemplateDocument then return document end
	if not document.TemplateContentsDocument then
		local html=document.IsHTML~=false
		document.TemplateContentsDocument={Kind='Document',Children={},Parent=nil,Diagnostics={},
			IsHTML=html,ContentType=if html then'text/html'else'application/xml',
			Mode='no-quirks',URL='about:blank',CharacterEncoding='UTF-8',DetachedDocument=true,
			ScriptingEnabled=false,InertTemplateDocument=true,PlainDocument=not html}
	end
	return document.TemplateContentsDocument
end
function Template.contents(node: any,document: any): any
	local owner=Template.owner(document)
	local content={Kind='DocumentFragment',Children={},Parent=nil,Host=node,OwnerDocument=owner}
	node.Content=content
	return content
end
-- Used for parsed/cloned data trees before they acquire realm wrappers. Public
-- adoption performs its own callbacks but uses the same owner transitions.
function Template.assign(root: any,document: any,allocated: any?,resetSource: boolean?)
	local pending={{Node=root,Document=document}}
	while #pending>0 do
		WorkContext.checkpoint()
		local entry=table.remove(pending);local node,owner=entry.Node,entry.Document
		if node.Kind=='Document'then owner=node else node.OwnerDocument=owner end
		SourceDocument.seed(node,owner,resetSource)
		if allocated then allocated(node,owner)end
		for _,child in node.Children do table.insert(pending,{Node=child,Document=owner})end
		if node.Content then
			local contentOwner=if node.Content.Kind=='ShadowRoot'then owner else Template.owner(owner)
			table.insert(pending,{Node=node.Content,Document=contentOwner})
		end
		if node.InternalShadowRoot then table.insert(pending,{Node=node.InternalShadowRoot,Document=owner})end
		for _,attr in node.AttributeNodes or{}do table.insert(pending,{Node=attr,Document=owner})end
	end
end
return Template
