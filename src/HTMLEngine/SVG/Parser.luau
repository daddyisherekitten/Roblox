--!strict
local Node=require(script.Parent.Parent.DOM.Node)
local XML=require(script.Parent.XML)
local Parser={Namespace="http://www.w3.org/2000/svg"}
local XMLURI="http://www.w3.org/XML/1998/namespace"
local XMLNS="http://www.w3.org/2000/xmlns/"
local function namespace(scope: any,prefix: string): string?
	while scope do
		local value=scope.Values[prefix]
		if value~=nil then return value end
		scope=scope.Parent
	end
	return nil
end
local function limit(options: any,key: string,default: number): number
	local n=options[key] or default
	assert(type(n)=="number" and n>0 and n<math.huge and n%1==0,"Invalid "..key)
	return n
end
function Parser.parse(source: string,options: any?): any
	assert(type(source)=="string","SVG must be a string")
	options=options or {}
	assert(options.Inline==nil or type(options.Inline)=="boolean","Inline must be boolean")
	local maxBytes=limit(options,"MaxBytes",1024*1024)
	local maxNodes=limit(options,"MaxNodes",20000)
	local maxDepth=limit(options,"MaxDepth",128)
	local maxDiagnostics=limit(options,"MaxDiagnostics",100)
	local maxAttributes=limit(options,"MaxAttributes",256)
	local document=Node.document(); document.Valid=false; document.Ids={}
	local function diagnostic(code: string,message: string,position: number,severity: string)
		if #document.Diagnostics<maxDiagnostics then table.insert(document.Diagnostics,{Code=code,Message=message,Position=position,Severity=severity})
		else
			document.DiagnosticsTruncated=true
			if severity=="error" then document.Diagnostics[#document.Diagnostics]={Code=code,Message=message,Position=position,Severity=severity} end
		end
	end
	local ok,problem=pcall(function()
		if #source>maxBytes then XML.fail("byte-limit","SVG exceeds MaxBytes",1) end
		source=source:gsub("\r\n","\n"):gsub("\r","\n")
		if source:sub(1,3)=="\239\187\191" then source=source:sub(4) end
		local scanner=XML.new(source,maxAttributes)
		local stack={document}; local nodes=0
		local function append(node: any)
			nodes+=1; if nodes>maxNodes then XML.fail("node-limit","SVG exceeds MaxNodes",scanner.Position) end
			Node.append(stack[#stack],node)
		end
		while true do
			local token=scanner:next(); if not token then break end
			local parent=stack[#stack]
			if token.Kind=="Start" then
				if #stack>maxDepth then XML.fail("depth-limit","SVG exceeds MaxDepth",token.Position) end
				if parent==document and document.Root then XML.fail("multiple-roots","Only one SVG root is allowed",token.Position) end
				-- Persistent namespace scopes avoid copying every inherited binding per node.
				local namespaces={Values={},Parent=parent.Namespaces or {Values={xml=XMLURI,[""]=if options.Inline then Parser.Namespace else ""}}}
				local attrs={}
				for _,a in token.Attributes do
					attrs[a.Name]=a.Value
					local prefix,localName=XML.name(a.Name,a.Position)
					if a.Name=="xmlns" or prefix=="xmlns" then
						local key=if a.Name=="xmlns" then "" else localName
						if key=="xmlns" or a.Value==XMLNS or (key=="xml" and a.Value~=XMLURI) or (key~="xml" and a.Value==XMLURI)
							or (key~="" and a.Value=="") then XML.fail("invalid-namespace","Invalid namespace binding: "..a.Name,a.Position) end
						namespaces.Values[key]=a.Value
					end
				end
				local prefix,name=XML.name(token.Name,token.Position)
				local nodeURI=namespace(namespaces,prefix)
				if prefix=="xmlns" or nodeURI==nil then XML.fail("unbound-prefix","Unknown element prefix: "..prefix,token.Position) end
				local node=Node.element(name,attrs)
				node.QualifiedName,node.NamespaceURI,node.Namespaces=token.Name,nodeURI,namespaces
				node.Position=token.Position; node.ExpandedAttributes={}
				for _,a in token.Attributes do
					local ap,an=XML.name(a.Name,a.Position)
					local uri=if a.Name=="xmlns" or ap=="xmlns" then XMLNS elseif ap=="" then "" else namespace(namespaces,ap)
					if uri==nil then XML.fail("unbound-prefix","Unknown attribute prefix: "..ap,a.Position) end
					local key=uri.."\0"..an
					if node.ExpandedAttributes[key]~=nil then XML.fail("duplicate-expanded-attribute","Attributes share the same namespace/name",a.Position) end
					node.ExpandedAttributes[key]=a.Value
				end
				if parent==document then
					if name~="svg" or node.NamespaceURI~=Parser.Namespace then XML.fail("invalid-root","Expected an svg element in the SVG namespace",token.Position) end
					document.Root=node
				end
				append(node)
				if attrs.id then
					if document.Ids[attrs.id] then diagnostic("duplicate-id","Duplicate ID; first definition retained: "..attrs.id,token.Position,"warning")
					else document.Ids[attrs.id]=node end
				end
				if not token.SelfClosing then table.insert(stack,node) end
			elseif token.Kind=="End" then
				if parent==document or parent.QualifiedName~=token.Name then XML.fail("mismatched-end-tag","Unexpected closing tag: "..token.Name,token.Position) end
				table.remove(stack)
			elseif token.Kind=="Text" or token.Kind=="CDATA" then
				if parent==document then
					if token.Kind=="CDATA" or token.Text:find("[^ \t\n\r]") then XML.fail("outside-root","Text outside SVG root",token.Position) end
				else append(Node.text(token.Text)) end
			elseif token.Kind=="Comment" then append(Node.comment(token.Text))
			elseif token.Kind=="PI" then
				local target=token.Text:match("^([^%s]+)") or ""
				XML.name(target,token.Position)
				if target:lower()=="xml" then
					if token.Position~=1 or target~="xml" then XML.fail("invalid-xml-declaration","XML declaration must be first",token.Position) end
					-- Validate the declaration's ordered pseudo-attributes with the scanner.
					local declaration=XML.new("<xml "..token.Text:sub(5).."/>",4)
					local decl=declaration:next()
					if not decl.SelfClosing or declaration.Position<=#declaration.Source or token.Text:find("&",1,true) then
						XML.fail("invalid-xml-declaration","Invalid XML declaration content",token.Position)
					end
					local a=decl.Attributes
					if not a[1] or a[1].Name~="version" or a[1].Value~="1.0" then XML.fail("unsupported-xml-version","Expected XML 1.0",token.Position) end
					local nextIndex=2
					if a[nextIndex] and a[nextIndex].Name=="encoding" then
						if a[nextIndex].Value:lower()~="utf-8" then XML.fail("unsupported-encoding","Only UTF-8 is supported",token.Position) end
						nextIndex+=1
					end
					if a[nextIndex] and a[nextIndex].Name=="standalone" and (a[nextIndex].Value=="yes" or a[nextIndex].Value=="no") then nextIndex+=1 end
					if a[nextIndex] then XML.fail("invalid-xml-declaration","Unexpected XML declaration attribute",token.Position) end
				else
					append({Kind="ProcessingInstruction",Name=target,Text=token.Text,Children={}})
					diagnostic("inert-processing-instruction","Processing instruction retained without execution",token.Position,"warning")
				end
			end
		end
		if #stack>1 then XML.fail("unclosed-element","Unclosed element: "..stack[#stack].QualifiedName,#source+1) end
		if not document.Root then XML.fail("missing-root","No SVG root found",1) end
		document.Valid=true
	end)
	if not ok then
		if type(problem)~="table" or not problem.Code then error(problem) end
		diagnostic(problem.Code,problem.Message,problem.Position,"error")
		document.Root=nil; document.Ids={}; document.Children={}
	end
	return document
end
return Parser
