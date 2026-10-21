--!strict
-- DOM Parsing §5.2.1. Prefix fixup is output-only: no DOM/Attr mutation, no
-- process-wide cache. Each invocation owns its namespace scopes and counter.
local Store=require(script.Parent.Parent.DOM.AttributeStore)
local Template=require(script.Parent.Parent.DOM.TemplateDocument)
local Work=require(script.Parent.Parent.WorkContext)
local Strings=require(script.Parent.Strings)
local XML={}
local HTML='http://www.w3.org/1999/xhtml'
local XMLURI='http://www.w3.org/XML/1998/namespace'
local XMLNS='http://www.w3.org/2000/xmlns/'
local void={area=true,base=true,br=true,col=true,embed=true,hr=true,img=true,input=true,link=true,meta=true,param=true,source=true,track=true,wbr=true}
local function namespace(value)return if value==''then nil else value end
local function elementNamespace(node)
 if node.NamespaceURI~=nil then return namespace(node.NamespaceURI)end
 -- Parsed HTML uses nil as its compact HTML-namespace representation. Explicit
 -- null-namespace DOM elements use the empty-string sentinel instead.
 return if not node.OwnerDocument or node.OwnerDocument.IsHTML~=false then HTML else nil
end
local function character(code)
 return code==9 or code==10 or code==13 or(code>=32 and code<=0xd7ff)or(code>=0xe000 and code<=0xfffd)or(code>=0x10000 and code<=0x10ffff)
end
local function checkChars(value)
 for code in Strings.codes(value)do Work.checkpoint();assert(character(code),'XML contains a character outside XML 1.0 Char')end
end
local function nameStart(code)
 return(code>=65 and code<=90)or code==95 or(code>=97 and code<=122)or(code>=0xc0 and code<=0xd6)or(code>=0xd8 and code<=0xf6)
  or(code>=0xf8 and code<=0x2ff)or(code>=0x370 and code<=0x37d)or(code>=0x37f and code<=0x1fff)or(code>=0x200c and code<=0x200d)
  or(code>=0x2070 and code<=0x218f)or(code>=0x2c00 and code<=0x2fef)or(code>=0x3001 and code<=0xd7ff)or(code>=0xf900 and code<=0xfdcf)
  or(code>=0xfdf0 and code<=0xfffd)or(code>=0x10000 and code<=0xeffff)
end
local function checkName(value)
 assert(value~='','Empty XML local name');local first=true
 for code in Strings.codes(value)do Work.checkpoint()
  assert(nameStart(code)or(not first and(code==45 or code==46 or(code>=48 and code<=57)or code==0xb7 or(code>=0x300 and code<=0x36f)or(code>=0x203f and code<=0x2040))),'Invalid XML local name')
  first=false
 end
end
local function escaped(value,attribute,strict)
 value=value or'';if strict then checkChars(value)end
 value=value:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')
 return if attribute then(value:gsub('"','&quot;'):gsub('\t','&#9;'):gsub('\n','&#10;'):gsub('\r','&#13;'))else value
end
-- Snapshot order without normalizing AttributeOrder: failed getters must not
-- change even private source metadata or materialize live Attr wrappers.
local function attributeKeys(node)
 local keys,seen={},{}
 for _,key in node.AttributeOrder or{}do Work.checkpoint();if node.Attributes[key]~=nil and not seen[key]then table.insert(keys,key);seen[key]=true end end
 local remaining={};for key in node.Attributes do Work.checkpoint();if not seen[key]then table.insert(remaining,key)end end
 table.sort(remaining);for _,key in remaining do table.insert(keys,key)end;return keys
end
local function copyMap(source)
 local map={Bindings=table.clone(source.Bindings),Candidates={}}
 for uri,prefixes in source.Candidates do Work.checkpoint();map.Candidates[uri]=table.clone(prefixes)end;return map
end
local function add(map,uri,prefix)
 uri=uri or'';local old=map.Bindings[prefix]
 if old~=nil and old~=uri then
  local list=map.Candidates[old];if list then for index=#list,1,-1 do if list[index]==prefix then table.remove(list,index)end end end
 end
 map.Bindings[prefix]=uri;local candidates=map.Candidates[uri]or{};map.Candidates[uri]=candidates;table.insert(candidates,prefix)
end
local function preferred(map,uri,prefix)
 local candidates=map.Candidates[uri or''];if not candidates then return nil end
 if prefix and table.find(candidates,prefix)then return prefix end;return candidates[#candidates]
end
local function found(map,uri,prefix)return map.Bindings[prefix]==(uri or'')end
local function id(value)
 local quote=if value:find('"',1,true)then"'"else'"';return quote..value..quote
end
local function checkPublicId(value)
 for code in Strings.codes(value)do Work.checkpoint()
  assert(code==32 or code==10 or code==13 or(code>=65 and code<=90)or(code>=97 and code<=122)or(code>=48 and code<=57)
   or(code<128 and(("-'()+,./:=?;!*#@$_%"):find(string.char(code),1,true)~=nil)),'Invalid XML public identifier')
 end
end
function XML.serialize(root: any,childrenOnly: boolean?,requireWellFormed: boolean?): string
 local strict=requireWellFormed==true
 local parts,size,counter,pending={},0,1,{}
 local initial={Bindings={xml=XMLURI},Candidates={[XMLURI]={'xml'}}}
 local function emit(value)
  size+=#value;assert(size<=1024*1024,'Serialized XML budget exceeded');table.insert(parts,value)
 end
 local function generate(map)
  -- DOM-Parsing issue44: never create a second conflicting xmlns:nsN.
  while true do Work.checkpoint();local prefix='ns'..tostring(counter);counter+=1;if map.Bindings[prefix]==nil then return prefix end end
 end
 local function pushChildren(node,default,map)
  local children=if Template.matches(node)and node.Content then node.Content.Children else node.Children
  for index=#children,1,-1 do table.insert(pending,{Node=children[index],Default=default,Map=map})end
 end
 if childrenOnly then pushChildren(root,nil,initial)else table.insert(pending,{Node=root,Map=initial})end
 while #pending>0 do
  Work.checkpoint();local entry=table.remove(pending)
  if entry.Close then emit('</'..entry.Close..'>');continue end
  local node=entry.Node;local kind=node.Kind
  if kind=='Element'then
   local localName=node.LocalName or node.Name;local uri=elementNamespace(node);local prefix=node.Prefix
   if strict then
    checkName(localName);if prefix then checkName(prefix)end
    assert(uri~=XMLNS,'The XMLNS namespace cannot name an element')
   end
   local map=copyMap(entry.Map);local localPrefixes,localDefault={},nil;local keys=attributeKeys(node)
   for _,key in keys do
    if Store.namespace(node,key)==XMLNS then
     local info=node.AttributeNamespaces[key];local value=node.Attributes[key]
     if not info.Prefix then localDefault=value
     elseif value~=XMLURI and not found(map,namespace(value),info.LocalName)then add(map,namespace(value),info.LocalName);localPrefixes[info.LocalName]=value end
    end
   end
   local inherited,ignore,name=entry.Default,false,nil;local usedPrefixes={}
   local declarations={}
   local function declaration(candidate,value)
    table.insert(declarations,' '..(if candidate then'xmlns:'..candidate else'xmlns')..'="'..escaped(value,true,strict)..'"')
   end
   if inherited==uri then
    ignore=localDefault~=nil;name=if uri==XMLURI then'xml:'..localName else localName
   else
    -- DOM-Parsing issue52 + native/WPT: an explicit matching local default
    -- namespace wins over a prefix when the source element has no prefix.
    local candidate=if not prefix and localDefault~=nil and namespace(localDefault)==uri then nil else preferred(map,uri,prefix)
    if prefix=='xmlns'then assert(not strict,'An XML element cannot use the xmlns prefix');candidate=prefix end
    if candidate then
     name=candidate..':'..localName
     usedPrefixes[candidate]=uri or''
     if localDefault~=nil and localDefault~=XMLURI then inherited=namespace(localDefault)end
    elseif prefix then
     if localPrefixes[prefix]~=nil then prefix=generate(map)end
     add(map,uri,prefix);localPrefixes[prefix]=uri or'';name=prefix..':'..localName;declaration(prefix,uri)
     if localDefault~=nil then inherited=namespace(localDefault)end
    elseif localDefault==nil or namespace(localDefault)~=uri then
     ignore=true;name=localName;inherited=uri;declaration(nil,uri)
    else name=localName;inherited=uri end
   end
   emit('<'..name);for _,value in declarations do emit(value)end
   local expanded={}
   for _,key in keys do
    Work.checkpoint();local info=node.AttributeNamespaces and node.AttributeNamespaces[key]
    local attrURI=Store.namespace(node,key);local attrLocal=if info then info.LocalName or key else key
    local attrPrefix=info and info.Prefix;local value=node.Attributes[key]
    if strict then
     local expandedName=(attrURI or'')..'\0'..attrLocal;assert(not expanded[expandedName],'Duplicate expanded XML attribute');expanded[expandedName]=true
    end
    local candidate
    if attrURI then
     candidate=preferred(map,attrURI,attrPrefix)
     if attrURI==XMLNS then
      if value==XMLURI or(not attrPrefix and ignore)or(attrPrefix and localPrefixes[attrLocal]~=value and found(map,namespace(value),attrLocal))then continue end
     if strict then assert(value~=XMLNS,'Cannot declare the XMLNS namespace');assert(value~=''or not attrPrefix,'Cannot undeclare a namespace prefix')end
      if strict and attrPrefix then assert(attrLocal~='xmlns'and(attrLocal~='xml'or value==XMLURI),'Reserved XML namespace prefix declaration')end
      if attrPrefix=='xmlns'then candidate='xmlns'end
     elseif not candidate then
      candidate=if attrPrefix and localPrefixes[attrPrefix]==nil and map.Bindings[attrPrefix]==nil and usedPrefixes[attrPrefix]==nil then attrPrefix else generate(map)
      add(map,attrURI,candidate);localPrefixes[candidate]=attrURI
      emit(' xmlns:'..candidate..'="'..escaped(attrURI,true,strict)..'"')
     end
    end
    if strict then checkName(attrLocal);assert(attrURI~=nil or attrLocal~='xmlns','Unqualified xmlns attribute')end
    if candidate and attrURI~=XMLNS then usedPrefixes[candidate]=attrURI end
    emit(' '..(if candidate then candidate..':'else'')..attrLocal..'="'..escaped(value,true,strict)..'"')
   end
   local children=if Template.matches(node)and node.Content then node.Content.Children else node.Children
   if #children==0 and(uri~=HTML or void[localName])then emit(if uri==HTML then' />'else'/>')
   else emit('>');table.insert(pending,{Close=name});pushChildren(node,inherited,map)end
  elseif kind=='Text'then emit(escaped(node.Text,false,strict))
  elseif kind=='Comment'then
   if strict then checkChars(node.Text);assert(not node.Text:find('--',1,true)and node.Text:sub(-1)~='-','Invalid XML comment')end
   emit('<!--'..node.Text..'-->')
  elseif kind=='CDATASection'then
   -- The current DOM-Parsing algorithm intentionally has no validation step
   -- here, even when require-well-formed is true; preserve that API behavior.
   emit('<![CDATA['..node.Text..']]>')
  elseif kind=='ProcessingInstruction'then
   if strict then assert(not node.Target:find(':',1,true)and node.Target:lower()~='xml','Invalid XML PI target');checkChars(node.Text);assert(not node.Text:find('?>',1,true),'Invalid XML PI data')end
   emit('<?'..node.Target..' '..node.Text..'?>')
  elseif kind=='DocumentType'then
   local public,system=node.PublicId or'',node.SystemId or''
   if strict then
    checkPublicId(public);checkChars(system)
    assert(not(system:find('"',1,true)and system:find("'",1,true)),'Invalid XML system identifier')
   end
   emit('<!DOCTYPE '..node.Name..(if public~=''then' PUBLIC '..id(public)else'')..(if public==''and system~=''then' SYSTEM'else'')..(if system~=''then' '..id(system)else'')..'>')
  elseif kind=='Document'or kind=='DocumentFragment'or kind=='ShadowRoot'then
   if kind=='Document'and strict then local element=false;for _,child in node.Children do if child.Kind=='Element'then element=true;break end end;assert(element,'XML document has no document element')end
   pushChildren(node,entry.Default,entry.Map)
  elseif kind~='Attr'then error('Unsupported node kind for XML serialization')end
 end
 return table.concat(parts)
end
return XML
