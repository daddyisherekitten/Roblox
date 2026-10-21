--!strict
local Syntax=require(script.Parent.Syntax)
local Length=require(script.Parent.LengthExpression)
local Timeline={}
local axes={block=true,inline=true,x=true,y=true}
local names={cover=true,contain=true,entry=true,exit=true,['entry-crossing']=true,['exit-crossing']=true}
local function trim(v)return v:match('^%s*(.-)%s*$')or ''end
local function tokens(v)local list={};local cursor=1;while cursor<=#v do local p,after=Syntax.scan(v,cursor,' \t\r\n');cursor=after;p=trim(p);if p~=''then table.insert(list,p)end end;return list end
function Timeline.parse(value,context)
	value=trim(value)
	if value=='auto'or value=='none'then return {Kind=value}end
	if value:match('^%-%-[%a_][%w_%-]*$')then return {Kind='named',Name=value}end
	local kind,body=value:match('^(%a+)%((.*)%)$');if kind~='scroll'and kind~='view'then return nil end
	local result={Kind=kind,Axis='block',Scroller='nearest'};local seenAxis,seenScroller=false,false;local insets={}
	for _,token in tokens(body)do
		if axes[token]then if seenAxis then return nil end;result.Axis=token;seenAxis=true
		elseif kind=='scroll'and(token=='nearest'or token=='root'or token=='self')then if seenScroller then return nil end;result.Scroller=token;seenScroller=true
		elseif kind=='view'then local v=if token=='auto'then {Auto=true}else Length.parse(token,context or {FontSize=16});if not v or #insets==2 then return nil end;table.insert(insets,v)
		else return nil end
	end
	result.Insets=if #insets>0 then {insets[1],insets[2]or insets[1]}else nil;return result
end
local function endpoint(parts,cursor,default)
	local part=parts[cursor];if not part then return nil,cursor end
	if part=='normal'then return {Name='normal',Offset={Value=default,Percent=true}},cursor+1 end
	local name=if names[part]then part else 'normal';if names[part]then cursor+=1 end
	local raw=parts[cursor];local offset=raw and Length.parse(raw,{FontSize=16})
	if offset then cursor+=1 elseif name~='normal'then offset={Value=default,Percent=true}else return nil,cursor end
	return {Name=name,Offset=offset},cursor
end
function Timeline.ranges(value)
	local result={};local cursor=1
	while cursor<=#value do local part,after,delimiter=Syntax.scan(value,cursor,',');cursor=after;local p=tokens(part);local first,index=endpoint(p,1,0);if not first then return nil end
		local last;last,index=endpoint(p,index,100)
		if not last then last=if first.Name=='normal'then {Name='normal',Offset={Value=100,Percent=true}}else {Name=first.Name,Offset={Value=100,Percent=true}}end
		if index<=#p then return nil end;table.insert(result,{Start=first,Finish=last});if #result>16 or delimiter~=''and cursor>#value then return nil end
	end;return if #result>0 then result else nil
end
function Timeline.endpoints(value,finish)
	local result={};local cursor=1
	while cursor<=#value do local part,after,delimiter=Syntax.scan(value,cursor,',');cursor=after;local p=tokens(part);local point,index=endpoint(p,1,if finish then 100 else 0);if not point or index<=#p then return nil end;table.insert(result,point);if #result>16 or delimiter~=''and cursor>#value then return nil end end
	return if #result>0 then result else nil
end
function Timeline.bounds(name,start,size,port,insetStart,insetEnd)
	local a,b=start-port+insetEnd,start+size-insetStart
	local innerStart,innerEnd=math.min(start-insetStart,start+size-port+insetEnd),math.max(start-insetStart,start+size-port+insetEnd)
	if name=='entry'then return a,innerStart elseif name=='exit'then return innerEnd,b elseif name=='contain'then return innerStart,innerEnd elseif name=='entry-crossing'then return a,start-insetStart elseif name=='exit-crossing'then return start+size-port+insetEnd,b end
	return a,b
end
return Timeline
