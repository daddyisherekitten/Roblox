--!strict
-- Tree-scoped host context and deliberately exported shadow parts. Matching
-- never rewrites light DOM or expands ordinary selectors through boundaries.
local Syntax=require(script.Parent.Syntax)
local Selectors=require(script.Parent.Selectors)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Shadow={}
local function trim(value)return value:match('^%s*(.-)%s*$')or''end
local function compound(source)
 local parsed=Selectors.compile(source,1);return if parsed and #parsed.Parts==1 then parsed else nil
end
local function origin(source)
 local prefix=trim(source);if prefix==''then return'*'end
 if source:match('%s$')or prefix:match('[>+~]$')then return prefix..' *'end
 return prefix
end
function Shadow.host(source)
 local lower=source:lower();local kind=lower:match('^(:host%-context)%(')or lower:match('^(:host)%(')
 if kind then
  local argument,after,closing=Syntax.scan(source,#kind+2,')');if closing~=')'then return nil end
  local selector=compound(argument);if not selector then return nil end
  local context=kind==':host-context'
  return (if context then'*'else argument)..':scope'..source:sub(after),if context then selector else nil
 end
 if lower:sub(1,5)==':host'and not lower:sub(6,6):match('[%w%-]')then return '*:scope'..source:sub(6),nil end
 return nil
end
function Shadow.context(rule,states)
 if not rule.ShadowContext then return true end
 local ancestor=rule.ShadowHost
 while ancestor do
  if ancestor.Kind=='Element'and Selectors.matches(ancestor,rule.ShadowContext,states)then return true end
  ancestor=ancestor.Parent or(if ancestor.Kind=='ShadowRoot'then ancestor.Host else nil)
 end
 return false
end
function Shadow.part(source,scope)
 local start=source:lower():find('::part(',1,true);if not start then return nil end
 local names,after,closing=Syntax.scan(source,start+7,')');if closing~=')'then return nil end
 local wanted={};for name in names:gmatch('%S+')do if not name:match('^[%a_%-][%w_%-]*$')then return nil end;table.insert(wanted,name)end
 if #wanted==0 then return nil end
 local hostSource=origin(source:sub(1,start-1))
 local host,context
 if scope.Kind=='ShadowRoot'then local prepared,ctx=Shadow.host(hostSource);if prepared then hostSource=prepared;context=ctx end end
 host=Selectors.compile(hostSource);if not host then return nil end
 host.Parts[#host.Parts].QuirksHover=false -- the originating compound has ::part()
 local tail=trim(source:sub(after));if tail~=''and tail:sub(1,1)~=':'then return nil end
 return '*'..tail,{Names=wanted,Host=host,Context=context,Scope=scope,ShadowHost=if context or hostSource:find(':scope',1,true)then scope.Host else nil}
end
function Shadow.slotted(source,scope)
 local start=source:lower():find('::slotted(',1,true);if not start then return nil end
 local argument,after,closing=Syntax.scan(source,start+10,')');if closing~=')'or not compound(argument)then return nil end
 local tail=trim(source:sub(after));if tail~=''and tail:sub(1,2)~='::'then return nil end
 local prefix=origin(source:sub(1,start-1))
 local prepared,context=Shadow.host(prefix);local host=prepared~=nil;prefix=prepared or prefix
 local slot=Selectors.compile(prefix);if not slot then return nil end
 slot.Parts[#slot.Parts].QuirksHover=false -- the compound includes ::slotted()
 return argument..tail,{Selector=slot,Context=context,Host=if host then scope.Host else nil}
end
function Shadow.slotMatches(node,rule,states)
 local slot=node.AssignedSlot;if not slot then return false end
 if rule.SlotContext and not Shadow.context({ShadowHost=rule.SlotHost,ShadowContext=rule.SlotContext},states)then return false end
 return not rule.SlotSelector or Selectors.matches(slot,rule.SlotSelector,states,rule.SlotHost,function(n)local parent=n and n.Parent;return if parent and parent.Kind=='ShadowRoot'and rule.SlotHost then parent.Host else parent end)
end
local function exports(source,names)
 local exposed={};local cursor=1
 while cursor<=#source do
  local mapping,after=Syntax.scan(source,cursor,',');cursor=after;mapping=trim(mapping)
  local inside,outside=mapping:match('^([^:%s]+)%s*:%s*([^:%s]+)$')
  if not inside and mapping~=''and not mapping:find('[:%s]')then inside,outside=mapping,mapping end
  if inside and names[inside]then exposed[outside]=true end
 end
 return exposed
end
function Shadow.partHost(node,part)
 local names={};for name in(node.Attributes.part or''):gmatch('[^ \t\n\r\f]+')do names[name]=true end
 if next(names)==nil then return nil end
 local root=ShadowTree.Root(node)
 while root and root.Kind=='ShadowRoot'do
  local host=root.Host;local outer=ShadowTree.Root(host)
  if outer==part.Scope then
   for _,name in part.Names do if not names[name]then return nil end end
   return host
  end
  names=exports(host.Attributes.exportparts or'',names);if next(names)==nil then return nil end
  root=outer
 end
 return nil
end
function Shadow.partMatches(node,rule,states)
 local part=rule.Part;local host=Shadow.partHost(node,part);if not host then return false end
 if part.Context and not Shadow.context({ShadowHost=part.ShadowHost,ShadowContext=part.Context},states)then return false end
 return Selectors.matches(host,part.Host,states,part.ShadowHost)
end
function Shadow.partScopes(node)
 local scopes={};local root=ShadowTree.Root(node)
 while root and root.Kind=='ShadowRoot'do root=ShadowTree.Root(root.Host);table.insert(scopes,root)end
 return scopes -- nearest outer scope first; normal precedence rises outward.
end
function Shadow.valid(source:string):boolean
 local scope={Kind='ShadowRoot',Host={}}
 if source:lower():find('::part(',1,true)then
  local prepared=Shadow.part(source,scope);return prepared~=nil and Selectors.compile(prepared)~=nil
 elseif source:lower():find('::slotted(',1,true)then
  local prepared=Shadow.slotted(source,scope);return prepared~=nil and Selectors.compile(prepared)~=nil
 end
 local prepared=Shadow.host(source);return prepared~=nil and Selectors.compile(prepared)~=nil
end
return Shadow
