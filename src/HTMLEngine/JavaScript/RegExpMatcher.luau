--!strict
-- Ordered backtracking with an explicit work stack; repetition does not grow
-- the Luau call stack. Lookaround recursion and total work are separately bounded.
local Unicode=require(script.Parent.RegExpUnicode)
local Matcher={}
local foldReverse,upperReverse={},{}
for from,to in Unicode.Fold do foldReverse[to]=foldReverse[to]or {};table.insert(foldReverse[to],from)end
for from,to in Unicode.Upper do if from<128 or to>=128 then upperReverse[to]=upperReverse[to]or {};table.insert(upperReverse[to],from)end end
local function contains(ranges,cp)
 local low,high=1,#ranges/2
 while low<=high do local middle=math.floor((low+high)/2);local a,b=ranges[middle*2-1],ranges[middle*2];if cp<a then high=middle-1 elseif cp>b then low=middle+1 else return true end end;return false
end
local function canonical(cp,flags)
 if not flags.i then return cp end
 if flags.u or flags.v then return Unicode.Fold[cp]or cp end
 local upper=Unicode.Upper[cp]or cp;return if cp>=128 and upper<128 then cp else upper
end
local function folded(test,cp,flags)
 if not flags.i then return test(cp)end
 local c=canonical(cp,flags);if test(c)or test(cp)then return true end
 for _,v in (if flags.u or flags.v then foldReverse[c]else upperReverse[c])or {}do if test(v)then return true end end;return false
end
local function space(cp)return cp==32 or(cp>=9 and cp<=13)or cp==0xa0 or cp==0x1680 or(cp>=0x2000 and cp<=0x200a)or cp==0x2028 or cp==0x2029 or cp==0x202f or cp==0x205f or cp==0x3000 or cp==0xfeff end
local function word(cp,flags)if not cp then return false end;cp=canonical(cp,flags);return(cp>=48 and cp<=57)or(cp>=65 and cp<=90)or(cp>=97 and cp<=122)or cp==95 end
local function line(cp)return cp==10 or cp==13 or cp==0x2028 or cp==0x2029 end
local function stringKey(chars,flags)local parts={};for _,cp in chars do table.insert(parts,tostring(canonical(cp,flags)))end;return table.concat(parts,",")end
local function stringCache(set,flags,tick)
 local key=if flags.i then "Folded"else "Exact";set.Cache=set.Cache or {};local cache=set.Cache[key];if cache then return cache end
 cache={Members={},Forward={},Backward={},Empty={}}
 for _,chars in set.Strings do
  if tick then tick()end;cache.Members[stringKey(chars,flags)]=true
  if #chars==0 then table.insert(cache.Empty,chars)else
   local first,last=canonical(chars[1],flags),canonical(chars[#chars],flags)
   cache.Forward[first]=cache.Forward[first]or {};table.insert(cache.Forward[first],chars)
   cache.Backward[last]=cache.Backward[last]or {};table.insert(cache.Backward[last],chars)
  end
 end;set.Cache[key]=cache;return cache
end
local member
member=function(set,chars,flags)
 local t=set.Type;local cp=chars[1]
 if t=="union"then for _,term in set.Terms do if member(term,chars,flags)then return true end end;return false
 elseif t=="intersect"then for _,term in set.Terms do if not member(term,chars,flags)then return false end end;return true
 elseif t=="subtract"then if not member(set.Terms[1],chars,flags)then return false end;for i=2,#set.Terms do if member(set.Terms[i],chars,flags)then return false end end;return true
 elseif t=="negate"then return #chars==1 and not member(set.Child,chars,flags)
 elseif t=="strings"then return stringCache(set,flags).Members[stringKey(chars,flags)]==true
 elseif #chars~=1 then return false
 elseif t=="char"then return canonical(cp,flags)==canonical(set.Code,flags)
 elseif t=="range"then return folded(function(c)return c>=set.First and c<=set.Last end,cp,flags)
 elseif t=="property"then
  if set.Negate and not flags.v then return folded(function(c)return not contains(set.Ranges,c)end,cp,flags)end
  local found=folded(function(c)return contains(set.Ranges,c)end,cp,flags);return if set.Negate then not found else found
 elseif t=="builtin"then
  local n=set.Name;local found=if n=="d"or n=="D"then cp>=48 and cp<=57 elseif n=="s"or n=="S"then space(cp)else word(cp,flags)
  return if n=="D"or n=="S"or n=="W"then not found else found
 end;return false
end
function Matcher.next(units,pos,unicode,direction)
 if direction==1 then local cp=units[pos+1];if not cp then return nil,pos end
  local low=units[pos+2];if unicode and cp>=0xd800 and cp<=0xdbff and low and low>=0xdc00 and low<=0xdfff then return 0x10000+(cp-0xd800)*1024+low-0xdc00,pos+2 end;return cp,pos+1
 end
 local cp=units[pos];if not cp then return nil,pos end;local high=units[pos-1]
 if unicode and cp>=0xdc00 and cp<=0xdfff and high and high>=0xd800 and high<=0xdbff then return 0x10000+(high-0xd800)*1024+cp-0xdc00,pos-2 end;return cp,pos-1
end
function Matcher.match(compiled,units,start,step,fail,maxWork)
 local work=0;local run
 local function tick()work+=1;step();if work>(maxWork or 200000)then fail("RegExp backtracking work budget exceeded")end end
 local function todo(node,nextValue)return {Node=node,Next=nextValue}end
 run=function(root,startPos,captures,direction,depth)
  if depth>64 then fail("RegExp lookaround nesting budget exceeded")end
  local stack={{Todo=todo(root,nil),Position=startPos,Captures=captures}}
  while #stack>0 do
   local state=table.remove(stack);local pending,pos,caps=state.Todo,state.Position,state.Captures
   while true do
    tick();if #stack>16384 then fail("RegExp backtracking stack budget exceeded")end;if not pending then return {Position=pos,Captures=caps}end
    local node,rest=pending.Node,pending.Next;local t=node.Type;local flags=node.Flags or compiled.Flags;local unicode=flags.u or flags.v
    if t=="sequence"then pending=rest;if direction==1 then for i=#node.Terms,1,-1 do pending=todo(node.Terms[i],pending)end else for i=1,#node.Terms do pending=todo(node.Terms[i],pending)end end
    elseif t=="alternation"then
     for i=#node.Terms,2,-1 do table.insert(stack,{Todo=todo(node.Terms[i],rest),Position=pos,Captures=caps})end;pending=todo(node.Terms[1],rest)
    elseif t=="group"then pending=todo(node.Child,rest)
    elseif t=="capture"then pending=todo(node.Child,todo({Type="captureEnd",Index=node.Index,Start=pos},rest))
    elseif t=="captureEnd"then caps=table.clone(caps);caps[node.Index]={math.min(node.Start,pos),math.max(node.Start,pos)};pending=rest
    elseif t=="repeat"or t=="repeatState"then
     local original=if t=="repeat"then node else node.Original;local count=if t=="repeat"then 0 else node.Count
     local childCaps=table.clone(caps);for index=original.FirstCapture,original.LastCapture do childCaps[index]=nil end
     local childTodo=todo(original.Child,todo({Type="repeatAfter",Original=original,Count=count,Start=pos},rest))
     if count>=original.Max then pending=rest
     elseif count<original.Min then pending=childTodo;caps=childCaps
     elseif original.Greedy then table.insert(stack,{Todo=rest,Position=pos,Captures=caps});pending=childTodo;caps=childCaps
     else table.insert(stack,{Todo=childTodo,Position=pos,Captures=childCaps});pending=rest end
    elseif t=="repeatAfter"then if pos==node.Start and node.Count>=node.Original.Min then break end;pending=todo({Type="repeatState",Original=node.Original,Count=node.Count+1},rest)
    elseif t=="lookahead"or t=="lookbehind"then
     local result=run(node.Child,pos,caps,if t=="lookahead"then 1 else -1,depth+1)
     if(node.Negate and result)or(not node.Negate and not result)then break end
     if result then caps=result.Captures end;pending=rest
    elseif t=="start"then if pos~=0 and not(flags.m and line(units[pos]))then break end;pending=rest
    elseif t=="end"then if pos~=#units and not(flags.m and line(units[pos+1]))then break end;pending=rest
    elseif t=="boundary"then local before=Matcher.next(units,pos,unicode,-1);local after=Matcher.next(units,pos,unicode,1);local boundary=word(before,flags)~=word(after,flags);if boundary==node.Negate then break end;pending=rest
    elseif t=="backref"then
     local span=if node.Index then caps[node.Index]else nil;local valid=true
     if node.Indices then for _,id in node.Indices do if caps[id]then span=caps[id];break end end end
     if span then local cursor=if direction==1 then span[1]else span[2];local target=if direction==1 then span[2]else span[1]
      while cursor~=target do tick();local expected,nextCursor=Matcher.next(units,cursor,unicode,direction);local actual,nextPos=Matcher.next(units,pos,unicode,direction);if not actual or canonical(expected,flags)~=canonical(actual,flags)then valid=false;break end;cursor,pos=nextCursor,nextPos end
     end;if not valid then break end;pending=rest
    elseif t=="literal"or t=="dot"then
     local cp,nextPos=Matcher.next(units,pos,unicode,direction);if not cp then break end
     if(t=="literal"and canonical(cp,flags)~=canonical(node.Code,flags))or(t=="dot"and not flags.s and line(cp))then break end;pos,pending=nextPos,rest
    elseif t=="class"then
     local cp,nextPos=Matcher.next(units,pos,unicode,direction)
     local candidates={};local function collect(set)
      if set.Type=="strings"then
       local cache=stringCache(set,flags,tick);local group=if direction==1 then cache.Forward else cache.Backward
       for _,chars in cache.Empty do table.insert(candidates,chars)end
       if cp then for _,chars in group[canonical(cp,flags)]or {}do table.insert(candidates,chars)end end
      elseif set.Terms then for _,term in set.Terms do collect(term)end end
     end;collect(node.Set)
     if cp then table.insert(candidates,{cp})end
     table.sort(candidates,function(a,b)return #a>#b end)
     local endings={};local seen={}
     for _,chars in candidates do
      local cursor=pos;local actual={};local equal=true
      for index=1,#chars do local expected=chars[if direction==1 then index else #chars-index+1];local value,nextCursor=Matcher.next(units,cursor,unicode,direction);if not value or canonical(value,flags)~=canonical(expected,flags)then equal=false;break end;cursor=nextCursor;if direction==1 then table.insert(actual,value)else table.insert(actual,1,value)end end
      if equal and not seen[cursor]and member(node.Set,actual,flags)then seen[cursor]=true;table.insert(endings,cursor)end
     end
     if #endings==0 then break end;for i=#endings,2,-1 do table.insert(stack,{Todo=rest,Position=endings[i],Captures=caps})end;pos,pending=endings[1],rest
    else fail("Unknown RegExp matcher node")end
   end
  end
  return nil
 end
 return run(compiled.Tree,start,{},1,0)
end
return Matcher
