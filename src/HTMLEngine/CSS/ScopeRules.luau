--!strict
local Syntax=require(script.Parent.Syntax)
local Selectors=require(script.Parent.Selectors)
local Nesting=require(script.Parent.Nesting)
local Scope={}
local WorkContext=require(script.Parent.Parent.WorkContext)
local trim=Syntax.trim
local function nesting(value)
 -- Scope/nesting references are lexical, including unsupported forgiving
 -- branches. Strings, comments, escaped identifiers and URL tokens are data.
 local index,chunk=1,1;local out;local referenced=false
 local function identifierEnd(at)
  local name,after=Syntax.identifier(value,at)
  if not name then return nil,at end
  if name:lower()=='url'and value:sub(after,after)=='('then
   local first=after+1
   while value:sub(first,first):match('[ \t\n\r\f]')do first+=1 end
   local quote=value:sub(first,first)
   if quote~='"'and quote~="'"then
    -- Unquoted URL/bad-URL tokens stop at the first unescaped close.
    local finish=first
    while finish<=#value do
     WorkContext.checkpoint()
     if value:sub(finish,finish)==')'then return name,finish+1 end
     if value:sub(finish,finish)=='\\'then local _,nextIndex=Syntax.escape(value,finish);finish=nextIndex
     else finish+=1 end
    end
    return name,#value+1
   end
  end
  return name,after
 end
 while index<=#value do
  WorkContext.checkpoint();local char=value:sub(index,index)
  if value:sub(index,index+1)=='/*'then index=(value:find('*/',index+2,true)or #value)+2
  elseif char=='"'or char=="'"then local _,after=Syntax.stringToken(value,index);index=after
  elseif char=='&'then
   referenced=true;out=out or{};table.insert(out,value:sub(chunk,index-1));table.insert(out,':where(:scope)');index+=1;chunk=index
  elseif char==':'then
   local at,spaced=Syntax.skip(value,index+1)
   local name,after=identifierEnd(at)
   if name and not spaced and name:lower()=='scope'then referenced=true end
   index=if name then after else index+1
  elseif char=='#'or char=='@'then
   local _,after=Syntax.identifier(value,index+1,char=='#');index=if after>index+1 then after else index+1
  else
   local number=value:match('^[+-]?%d*%.?%d+',index)
   if number then
    index+=#number
    local exponent=value:match('^[eE][+-]?%d+',index);if exponent then index+=#exponent end
    local _,after=Syntax.identifier(value,index);index=after
    if value:sub(index,index)=='%'then index+=1 end
   else
    local name,after=identifierEnd(index)
    if name then index=after
    elseif char=='\\'then local _,after=Syntax.escape(value,index);index=after
    else index+=1 end
   end
  end
 end
 if out then table.insert(out,value:sub(chunk));return table.concat(out),referenced end
 return value,referenced
end
local function selectorList(source,parentSelector,namespaces,scopedStart)
 local list={}
 for _,part in Selectors.list(source)do
  if part:find('::',1,true)then return nil end
  part=trim(part)
  if parentSelector then part=Nesting.resolve(part,parentSelector);if not part then return nil end end
  local referenced;part,referenced=nesting(part);local relative=part:sub((Syntax.skip(part,1))):match('^[>+~]')~=nil
  if scopedStart and not parentSelector and not referenced then relative=true end
  if relative then part=':where(:scope) '..part end
  local selector=Selectors.compile(part,nil,namespaces,nil,if relative then 'relative'else nil);if not selector then return nil end;table.insert(list,selector)
 end
 return if #list>0 then list else nil
end
function Scope.parse(source,owner,root,parentSelector,namespaces,scopedStart)
 source=trim(source);local start,finish,index,startText,finishText=nil,nil,1,nil,nil
 if source:sub(1,1)=='('then local text,after,close=Syntax.scan(source,2,')');if close~=')'then return nil end;start=selectorList(text,parentSelector,namespaces,scopedStart);if not start then return nil end;startText=trim(text);index=after end
 local remaining=trim(source:sub(index))
 if remaining~=''then local body=remaining:match('^[Tt][Oo][ \t\n\r\f]+(%(.+)$');if not body then return nil end;local text,after,close=Syntax.scan(body,2,')');if close~=')'or trim(body:sub(after))~=''then return nil end;finish=selectorList(text,nil,namespaces);if not finish then return nil end;finishText=trim(text)end
 local implicit=owner and owner.Parent
 if not implicit or implicit.Kind~='Element'then implicit=if root.Kind=='ShadowRoot'then root.Host else root end
 return {Start=start,Finish=finish,StartText=startText,FinishText=finishText,Implicit=implicit}
end
local function parent(node,rule)
 local p=node and node.Parent
 return if p and p.Kind=='ShadowRoot'and rule.ShadowHost then p.Host else p
end
local function matchesAny(node,list,states,scope,rule)
 for _,selector in list do if Selectors.matches(node,selector,states,scope,function(n)return parent(n,rule)end)then return true end end;return false
end
-- Find a complete nesting chain. A nearer inner root may be excluded by the
-- outer donut, so roots must be tried rather than selected independently.
function Scope.match(node,rule,states):(boolean,number?,any?)
 if not rule.Scopes then return true,math.huge,nil end
 local chain=rule.Scopes;local search
 search=function(index,outer)
  local spec=chain[index];local candidate=node;local distance=0
  while candidate and distance<512 do
   local eligible=if spec.Start then candidate.Kind=='Element'and matchesAny(candidate,spec.Start,states,outer,rule)else candidate==spec.Implicit
   if eligible and index==#chain and candidate==node and rule.ScopeRootEligible==false then eligible=false end
   if eligible then
    local inOuter=outer==nil;local at=node;local excluded=false
    while at do
     if at==candidate then break end
     if spec.Finish and at.Kind=='Element'and matchesAny(at,spec.Finish,states,candidate,rule)then excluded=true;break end
     at=parent(at,rule)
    end
    if outer then local ancestor=candidate;while ancestor do if ancestor==outer then inOuter=true;break end;ancestor=parent(ancestor,rule)end end
    if at==candidate and not excluded and inOuter then
     if index==#chain then return true,distance,candidate end
     local ok,proximity,root=search(index+1,candidate);if ok then return ok,proximity,root end
    end
   end
   if candidate==outer then break end;candidate=parent(candidate,rule);distance+=1
  end
  return false,nil,nil
 end
 return search(1,nil)
end
function Scope.selector(source)
 -- Relative styles have an implicit anchor, unlike authored :scope or &.
 local referenced
 source,referenced=nesting(source)
 local relative=source:sub((Syntax.skip(source,1))):match('^[>+~]')~=nil
 if relative then source=':where(:scope) '..source end
 return source,if relative then 'relative'else nil,referenced and not relative
end
return Scope
