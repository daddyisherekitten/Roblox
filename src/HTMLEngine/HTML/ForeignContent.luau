--!strict
local Names=require(script.Parent.SVGNames)
local Foreign={}
local SVG="http://www.w3.org/2000/svg"
local MATH="http://www.w3.org/1998/Math/MathML"
local escape={b=true,big=true,blockquote=true,body=true,br=true,center=true,code=true,dd=true,div=true,dl=true,dt=true,em=true,embed=true,h1=true,h2=true,h3=true,h4=true,h5=true,h6=true,head=true,hr=true,i=true,img=true,li=true,listing=true,menu=true,meta=true,nobr=true,ol=true,p=true,pre=true,ruby=true,s=true,small=true,span=true,strong=true,strike=true,sub=true,sup=true,table=true,tt=true,u=true,ul=true,var=true}
function Foreign.integration(node: any): boolean
	if node.NamespaceURI==SVG then return node.Name=="foreignObject" or node.Name=="desc" or node.Name=="title" end
	if node.NamespaceURI==MATH and node.Name=="annotation-xml" then local e=(node.Attributes.encoding or ""):lower(); return e=="text/html" or e=="application/xhtml+xml" end
	return false
end
local function mathText(node: any): boolean return node.NamespaceURI==MATH and ({mi=true,mo=true,mn=true,ms=true,mtext=true})[node.Name]==true end
function Foreign.insert(c: any,t: any,namespace: string)
	if namespace==SVG then
		t.Name=Names.Tags[t.Name] or t.Name
		for lower,adjusted in Names.Attributes do if t.Attributes[lower] then t.Attributes[adjusted],t.Attributes[lower]=t.Attributes[lower],nil end end
		for i,name in t.AttributeOrder do t.AttributeOrder[i]=Names.Attributes[name] or name end
	elseif t.Attributes.definitionurl then t.Attributes.definitionURL,t.Attributes.definitionurl=t.Attributes.definitionurl,nil
		for i,name in t.AttributeOrder do if name=="definitionurl" then t.AttributeOrder[i]="definitionURL" end end
	end
	local node=c:insert(t,namespace,not t.SelfClosing); c.Tokenizer.Raw=nil
	if namespace==SVG and node.Name=='script'and t.SelfClosing then c.SelfClosedScript=node end
	for name in node.Attributes do
		local prefix,localName=name:match("^(%a+):(.+)$"); local ns=nil
		if prefix=="xlink" and ({actuate=true,arcrole=true,href=true,role=true,show=true,title=true,type=true})[localName] then ns="http://www.w3.org/1999/xlink"
		elseif prefix=="xml" and (localName=="lang" or localName=="space") then ns="http://www.w3.org/XML/1998/namespace"
		elseif name=="xmlns" or name=="xmlns:xlink" then ns="http://www.w3.org/2000/xmlns/"; localName=localName or "xmlns" end
		if ns then node.AttributeNamespaces=node.AttributeNamespaces or {}; node.AttributeNamespaces[name]={Namespace=ns,LocalName=localName,Prefix=prefix} end
	end
end
function Foreign.process(c: any,t: any): boolean?
	local node=c:adjustedCurrent()
	if not node or not node.NamespaceURI or t.Kind=="EOF" then return nil end
	if (Foreign.integration(node) and (t.Kind=="StartTag" or t.Kind=="Text"))
		or (mathText(node) and (t.Kind=="Text" or (t.Kind=="StartTag" and t.Name~="mglyph" and t.Name~="malignmark")))
		or (node.Name=="annotation-xml" and t.Kind=="StartTag" and t.Name=="svg") then return nil end
	if t.Kind=="Text" then local value=t.Text:gsub("%z",utf8.char(0xFFFD)); c:text(value); if t.Text:find("[^%z\t\n\f\r ]") then c.FramesetOK=false end
	elseif (t.Kind=="Comment" or t.Kind=="ProcessingInstruction") then c:comment(t)
	elseif t.Kind=="StartTag" then
		if escape[t.Name] or (t.Name=="font" and (t.Attributes.color or t.Attributes.face or t.Attributes.size)) then
			while c:current().NamespaceURI and not Foreign.integration(c:current()) and not mathText(c:current()) do c:pop() end; return c.HTMLToken(c,t)
		end
		Foreign.insert(c,t,node.NamespaceURI)
	elseif t.Kind=="EndTag" then
		if t.Name=="br" or t.Name=="p" then while c:current().NamespaceURI and not Foreign.integration(c:current()) and not mathText(c:current()) do c:pop() end; return c.HTMLToken(c,t) end
		for i=#c.Stack,1,-1 do
			local candidate=c.Stack[i]
			if not candidate.NamespaceURI then return c.HTMLToken(c,t) end
			if candidate.Name:lower()==t.Name then for _=#c.Stack,i,-1 do c:pop() end; break end
		end
	end
	return true
end
return Foreign
