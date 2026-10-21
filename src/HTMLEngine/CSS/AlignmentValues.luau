--!strict
-- Shared keyword grammar; computed CSS remains a canonical keyword string.
local Syntax=require(script.Parent.Syntax)
local Values={}
local selfPositions={center=true,start=true,['end']=true,['self-start']=true,['self-end']=true,['flex-start']=true,['flex-end']=true}
local contentPositions={center=true,start=true,['end']=true,['flex-start']=true,['flex-end']=true}
local function keywords(value: string): any?
 local out,index={},1
 while index<=#value do
  index=Syntax.skip(value,index);if index>#value then break end
  local word,last=Syntax.identifier(value,index);if not word then return nil end
  table.insert(out,word:lower());index=last
  if #out>4 then return nil end
 end
 return out
end
function Values.parse(value: string,field: string,allowed: any): string?
 local words=keywords(value);if not words then return nil end
 if #words==1 then return if allowed[words[1]]then words[1]else nil end
 if #words~=2 or(words[1]~='safe'and words[1]~='unsafe')then return nil end
 local position=words[2];local content=field=='AlignContent'or field=='JustifyContent'
 local accepted=(if content then contentPositions else selfPositions)[position]
 if position=='left'or position=='right'then accepted=field=='JustifyItems'or field=='JustifySelf'or field=='JustifyContent' end
 if position=='normal'then accepted=field=='AlignSelf'or field=='JustifySelf'end
 return if accepted then words[1]..' '..position else nil
end
function Values.split(value: string?): (string,string?)
 if value then local safety,position=value:match('^(safe) (.+)$');if not safety then safety,position=value:match('^(unsafe) (.+)$')end;if safety then return position,safety end end
 return value or 'normal',nil
end
function Values.overflow(mode: string,safety: string?,free: number): string
 -- Frozen Align3 30Jan2026: fallback is flex-start, including reversed axes.
 return if safety=='safe'and free<0 then 'flex-start'else mode
end
function Values.shorthand(value: string,suffix: string,properties: any): any?
 local words=keywords(value);if not words or #words==0 then return nil end
 local first='align-'..suffix;local second='justify-'..suffix
 for boundary=1,#words do
  local a=Values.parse(table.concat(words,' ',1,boundary),properties[first].Field,properties[first].Allowed)
  local rest=if boundary==#words then table.concat(words,' ',1,boundary)else table.concat(words,' ',boundary+1)
  local b=Values.parse(rest,properties[second].Field,properties[second].Allowed)
  if a and b then return {{Name=first,Value=a},{Name=second,Value=b}}end
 end
 return nil
end
return Values
