--!strict
-- Reuse the engine's XML scanner instead of passing XML through HTML repairs.
local Scanner=require(script.Parent.Parent.SVG.XML)
local Node=require(script.Parent.Parent.DOM.Node)
local Template=require(script.Parent.Parent.DOM.TemplateDocument)
local Names=require(script.Parent.DOMNames)
local XML={}
function XML.parse(source: string,contentType: string,context: any?): any
	assert(#source<=1024*1024,"XML byte budget exceeded")
	local document=Node.document();document.IsHTML=false;document.ContentType=contentType;document.Mode="no-quirks";document.DetachedDocument=true;document.URL="about:blank"
	local scanner=Scanner.new(source:gsub("\r\n","\n"):gsub("\r","\n"),1024)
	local mappings={xml=Names.XML,xmlns=Names.XMLNS}
	local root=document
	if context then
		root=Node.documentFragment();root.OwnerDocument=context.OwnerDocument
		local ancestry,pointer={},context
		while pointer and pointer.Kind~='Document'do table.insert(ancestry,pointer);pointer=pointer.Parent end
		for index=#ancestry,1,-1 do local node=ancestry[index]
			if node.Kind=='Element'then
				for name,value in node.Attributes do
					if name=='xmlns'then mappings['']=value elseif name:sub(1,6)=='xmlns:'then mappings[name:sub(7)]=value end
				end
				if node.NamespaceURI and node.NamespaceURI~=''then mappings[node.Prefix or'']=node.NamespaceURI end
			end
		end
	end
	local stack={{Node=root,Namespaces=mappings}};local count=0
	local function fail(message)error(message,0)end
	local function add(node)
		count+=1;assert(count<=8192,"XML node budget exceeded")
		local parent=stack[#stack].Node;local target=if Template.matches(parent)then parent.Content else parent
		local owner=if target.Kind=='Document'then target else target.OwnerDocument or document
		node.OwnerDocument=owner
		if Template.matches(node)then Template.contents(node,owner);count+=1;assert(count<=8192,'XML node budget exceeded')end
		Node.append(target,node)
	end
	while true do
		local token=scanner:next();if not token then break end
		if token.Kind=="Start"then
			local mappings=table.clone(stack[#stack].Namespaces)
			for _,attribute in token.Attributes do
				if attribute.Name=="xmlns"then mappings[""]=attribute.Value
				else local prefix=attribute.Name:match("^xmlns:(.+)$");if prefix then
					if prefix=="xmlns"or attribute.Value==Names.XMLNS or(prefix=="xml"and attribute.Value~=Names.XML)or(prefix~="xml"and attribute.Value==Names.XML)or attribute.Value==""then fail("Invalid namespace declaration")end
					mappings[prefix]=attribute.Value
				end end
			end
			local prefix,localName=Scanner.name(token.Name,token.Position);local namespace=mappings[prefix]
			if prefix~=""and not namespace then fail("Unbound namespace prefix")end
			local node=Node.element(token.Name,{});node.NamespaceURI=namespace or"";node.LocalName=localName;node.Prefix=if prefix~=""then prefix else nil;node.AttributeNamespaces={};node.AttributeOrder={}
			local expanded={}
			for _,attribute in token.Attributes do
				local p,l=Scanner.name(attribute.Name,attribute.Position);local uri=if attribute.Name=="xmlns"or p=="xmlns"then Names.XMLNS elseif p~=""then mappings[p]else nil
				if p~=""and not uri then fail("Unbound attribute namespace prefix")end
				local key=(uri or"").."\0"..l;if expanded[key]then fail("Duplicate expanded attribute name")end;expanded[key]=true
				node.Attributes[attribute.Name]=attribute.Value;node.AttributeNamespaces[attribute.Name]={Namespace=uri,LocalName=l,Prefix=if p~=""then p else nil};table.insert(node.AttributeOrder,attribute.Name)
			end
			if not context and #stack==1 and Node.findElement(document,function()return true end)then fail("Multiple document elements")end
			add(node);if not token.SelfClosing then assert(#stack<256,"XML depth budget exceeded");table.insert(stack,{Node=node,Namespaces=mappings})end
		elseif token.Kind=="End"then if #stack==1 or stack[#stack].Node.Name~=token.Name then fail("Mismatched XML end tag")end;table.remove(stack)
		elseif token.Kind=="Text"then if #stack==1 and not context then if token.Text:find("[^\t\n\r ]")then fail("Text outside the document element")end elseif token.Text~=""then add(Node.text(token.Text))end
		elseif token.Kind=="CDATA"then if #stack==1 and not context then fail("CDATA outside the document element")end;add(Node.cdata(token.Text))
		elseif token.Kind=="Comment"then add(Node.comment(token.Text))
		elseif token.Kind=="PI"then
			local target,data=token.Text:match("^([^\t\n\r ]+)[\t\n\r ]*(.*)$");if not target then fail("Invalid processing instruction")end
			if target:lower()=="xml"then if target~="xml"or token.Position~=1 then fail("Misplaced XML declaration")end else Scanner.name(target,token.Position);add(Node.processingInstruction(target,data))end
		end
	end
	if #stack~=1 or(not context and not Node.findElement(document,function()return true end))then fail("XML document needs a closed document element")end
	return root
end
function XML.fragment(source: string,context: any): any return XML.parse(source,'application/xml',context)end
return XML
