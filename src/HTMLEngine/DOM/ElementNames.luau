--!strict
-- Names shared by custom-element registration and imperative/declarative roots.
local Names={HTML="http://www.w3.org/1999/xhtml",SVG="http://www.w3.org/2000/svg",MathML="http://www.w3.org/1998/Math/MathML"}
-- Source Name is the qualified name. Element semantics use the expanded name;
-- a literal colon in a local name is never an implicit namespace prefix.
-- Parsed HTML stores its namespace compactly as nil, while explicit no-namespace
-- DOM/XML elements store "" and must not acquire HTML behavior.
function Names.matches(node: any,name: string,namespace: string): boolean
	return node~=nil and node.Kind=="Element"and(node.NamespaceURI or Names.HTML)==namespace and(node.LocalName or node.Name)==name
end
function Names.htmlName(node: any): string?
	return if node~=nil and node.Kind=="Element"and(node.NamespaceURI or Names.HTML)==Names.HTML then node.LocalName or node.Name else nil
end
function Names.html(node: any,name: string?): boolean
	local localName=Names.htmlName(node)
	return localName~=nil and(name==nil or localName==name)
end
function Names.script(node: any): boolean
	return Names.html(node,"script")or Names.matches(node,"script",Names.SVG)
end
function Names.style(node: any): boolean
	return Names.html(node,"style")or Names.matches(node,"style",Names.SVG)
end
local reserved={['annotation-xml']=true,['color-profile']=true,['font-face']=true,['font-face-src']=true,
	['font-face-uri']=true,['font-face-format']=true,['font-face-name']=true,['missing-glyph']=true}
local hosts={article=true,aside=true,blockquote=true,body=true,div=true,footer=true,
	h1=true,h2=true,h3=true,h4=true,h5=true,h6=true,header=true,main=true,nav=true,p=true,section=true,span=true}
function Names.custom(name: string): boolean
	return name:match('^[a-z]')~=nil and name:find('-',1,true)~=nil and not reserved[name]
		and name:find('[%z\t\n\f\r />A-Z]')==nil
end
function Names.shadow(name: string): boolean return hosts[name]==true or Names.custom(name)end
return Names
