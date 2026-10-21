--!strict
-- Namespace/name validation is shared by document and attribute factories.
local Names={HTML="http://www.w3.org/1999/xhtml",XML="http://www.w3.org/XML/1998/namespace",XMLNS="http://www.w3.org/2000/xmlns/"}
function Names.validElement(value: string): boolean
	if value==""or value:find("[%z\t\n\f\r />]")then return false end
	local first=utf8.codepoint(value,1,1)
	if first>=65 and first<=90 or first>=97 and first<=122 then return true end
	if first~=58 and first~=95 and first<128 then return false end
	for _,code in utf8.codes(value)do if code<128 and code~=58 and code~=95 and code~=45 and code~=46 and not(code>=65 and code<=90)and not(code>=97 and code<=122)and not(code>=48 and code<=57)then return false end end
	return true
end
function Names.validAttribute(value: string): boolean return value~=""and not value:find("[%z\t\n\f\r /=>]")end
function Names.valid(value: string): boolean
	if value==""then return false end
	local first=true
	for _,code in utf8.codes(value)do
		local start=code==58 or code==95 or(code>=65 and code<=90)or(code>=97 and code<=122)or code>=128
		if not start and(first or not(code==45 or code==46 or(code>=48 and code<=57)))then return false end
		if code>=0xd800 and code<=0xdfff then return false end;first=false
	end
	return true
end
function Names.namespace(value: any): any return if value==nil or value==""then nil else value end
function Names.extract(namespace: any,qualified: string,fail: any): (any,string,any)
	if not Names.valid(qualified)then fail("InvalidCharacterError","Invalid qualified name")end
	local prefix,localName=qualified:match("^([^:]+):([^:]+)$")
	if qualified:find(":",1,true)and not prefix then fail("NamespaceError","Invalid namespace-qualified name")end
	localName=localName or qualified;namespace=Names.namespace(namespace)
	if prefix and not namespace then fail("NamespaceError","Prefix requires a namespace")end
	if prefix=="xml"and namespace~=Names.XML then fail("NamespaceError","The xml prefix has a fixed namespace")end
	if (qualified=="xmlns"or prefix=="xmlns")and namespace~=Names.XMLNS then fail("NamespaceError","The xmlns name has a fixed namespace")end
	if namespace==Names.XMLNS and qualified~="xmlns"and prefix~="xmlns"then fail("NamespaceError","XMLNS requires an xmlns name")end
	return namespace,localName,prefix
end
return Names
