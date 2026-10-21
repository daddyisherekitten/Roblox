--!strict
-- Shared CSS block partitioning and nesting-selector expansion. A declaration
-- run retains its source position; CSSOM can expose later runs independently.
local Syntax=require(script.Parent.Syntax)
local Nesting={}
local trim=Syntax.trim
function Nesting.body(source: string): any
 local result,run,index={},{},1
 local function flush()
  local text=table.concat(run);table.clear(run)
  if text:find('%S')then table.insert(result,{Kind='Declarations',Source=text})end
 end
 while index<=#source do
  local header,after,stop=Syntax.scan(source,index,';{',nil,true);index=after
  if stop=='{'then
   local body,following,closing=Syntax.scan(source,index,'}',true);index=following
   if trim(header):match('^%-%-[%w_%-]+%s*:')then
    -- Braced custom-property values are component values, never child rules.
    local tail,finish,delimiter=Syntax.scan(source,index,';');index=finish
    table.insert(run,header..'{'..body..(if closing=='}'then'}'else'')..tail..delimiter)
   else
    flush();table.insert(result,{Kind='Rule',Header=trim(header),Body=body,Source=header..'{'..body..(if closing=='}'then'}'else'')})
   end
  elseif trim(header):sub(1,1)=='@'then
   flush();table.insert(result,{Kind='Rule',Header=trim(header),Source=header..stop})
  else table.insert(run,header..stop)end
 end
 flush();return result
end
local function resolveOne(source: string,parent: string,explicitOnly: boolean?): (string?,boolean?)
 -- :is() both represents the complete parent list and supplies its maximum
 -- specificity. Expanding each branch separately would get specificity wrong.
 local replacement=':is('..parent..')';local out,index,chunk={},1,1
 local quote: string?=nil;local attribute=0;local found=false
 while index<=#source do
  local char=source:sub(index,index)
  if char=='\\'then index+=2;continue end
  if quote then if char==quote then quote=nil end
  elseif char=='"'or char=="'"then quote=char
  elseif char=='['then attribute+=1
  elseif char==']'then attribute=math.max(0,attribute-1)
  elseif char=='&'and attribute==0 then
   local after=source:sub(index+1,index+1)
   -- CSS nesting is a selector, not Sass-style identifier concatenation.
   if after:match('[%w_%-]')then return nil end
   table.insert(out,source:sub(chunk,index-1));table.insert(out,replacement);chunk=index+1;found=true
  end
  index+=1
 end
 table.insert(out,source:sub(chunk));local expanded=table.concat(out)
 if not explicitOnly then
  if not found then expanded=replacement..' '..expanded
  elseif trim(source):match('^[>+~]')then expanded=replacement..' '..expanded end
 end
 return if #expanded<=4096 then expanded else nil,found
end
function Nesting.resolve(source: string,parent: string,explicitOnly: boolean?): string?
 local out,index={},1
 while index<=#source do
  local entry,after=Syntax.scan(source,index,',',nil,true);index=after
  if trim(entry)==''then return nil end
  local expanded=resolveOne(entry,parent,explicitOnly);if not expanded then return nil end
  table.insert(out,expanded)
 end
 if #out==0 or source:match(',%s*$')then return nil end
 local result=table.concat(out,', ');return if #result<=4096 then result else nil
end
function Nesting.selector(source: string): string?
 local out,index={},1
 while index<=#source do
  local entry,after=Syntax.scan(source,index,',',nil,true);index=after;entry=trim(entry)
  if entry==''then return nil end
  local expanded,explicit=resolveOne(entry,'*');if not expanded then return nil end
  if not explicit or entry:match('^[>+~]')then entry='& '..entry end
  table.insert(out,entry)
 end
 if #out==0 or source:match(',%s*$')then return nil end
 return table.concat(out,', ')
end
local function attributeText(body: string): string
	local name,after,stop=Syntax.scan(body,1,'=')
	if stop~='='then return trim(body)end
	name=trim(name);local operator='=';local last=name:sub(-1)
	if last:match('[~|^$*]')then operator=last..'=';name=trim(name:sub(1,-2))end
	local tail=trim(body:sub(after));local quote=tail:sub(1,1);local value,ending
	if quote=='"'or quote=="'"then value,ending=Syntax.stringToken(tail,1)else value,ending=Syntax.identifier(tail,1)end
	if value==nil then return body end
	local suffix=tail:sub((Syntax.skip(tail,ending)));local flag=Syntax.identifier(suffix,1)
	return name..operator..Syntax.serializeString(value)..(if flag then ' '..flag:lower()else'')
end
function Nesting.format(source: string): string
 local out,index,chunk={},1,1
 local function plain(finish)
  local text=source:sub(chunk,finish):gsub('%s*([>+~])%s*',' %1 '):gsub('%s*,%s*',', '):gsub('%s+',' ')
  table.insert(out,text)
 end
 while index<=#source do
  local char=source:sub(index,index)
  if char=='\\'then index+=2;continue end
  if char==':'then
   local name,ending=Syntax.identifier(source,index+1)
   if name and name:lower()=='heading'and source:sub(ending,ending)=='('then
    local body,after=Syntax.scan(source,ending+1,')',nil,true)
    local levels=Syntax.integerList(body)
    if levels then
     local values={};for _,level in levels do table.insert(values,tostring(level))end
     plain(index-1);table.insert(out,':heading('..table.concat(values,', ')..')')
     index=after;chunk=index;continue
    end
   end
   if name and(name:lower()=='state'or name:lower()=='dir')and source:sub(ending,ending)=='('then
    local body,after=Syntax.scan(source,ending+1,')',nil,true)
    local value,unread=Syntax.identifier(body,(Syntax.skip(body,1)))
    if value and Syntax.skip(body,unread)>#body then
     plain(index-1);table.insert(out,':'..name:lower()..'('..Syntax.serializeIdentifier(value)..')')
     index=after;chunk=index;continue
    end
   end
   if name and source:sub(ending,ending)=='('and({['nth-child']=true,['nth-last-child']=true,['nth-of-type']=true,['nth-last-of-type']=true})[name:lower()]then
    local body,after=Syntax.scan(source,ending+1,')',nil,true)
    local a,b,unread=Syntax.anb(body)
    if a~=nil then
     plain(index-1)
     local formula=if a==0 then tostring(b)elseif a==1 then'n'elseif a==-1 then'-n'else tostring(a)..'n'
     if a~=0 and b~=0 then formula..=(if b>0 then'+'else'')..tostring(b)end
     local remainder=body:sub((Syntax.skip(body,unread)))
     if remainder~=''then local _,offset=Syntax.identifier(remainder,1);formula..=' of '..Nesting.format(remainder:sub((Syntax.skip(remainder,offset))))end
     table.insert(out,':'..name:lower()..'('..formula..')');index=after;chunk=index;continue
    end
   end
  end
  if char=='['or char=='"'or char=="'"then
   plain(index-1)
   if char=='['then local body,after=Syntax.scan(source,index+1,']');table.insert(out,'['..attributeText(body)..']');index=after
   else
    local start=index;index+=1
    while index<=#source do local nextChar=source:sub(index,index);index+=1;if nextChar=='\\'then index+=1 elseif nextChar==char then break end end
    table.insert(out,source:sub(start,index-1))
   end
   chunk=index;continue
  end
  index+=1
 end
 plain(#source);return trim(table.concat(out))
end
return Nesting
