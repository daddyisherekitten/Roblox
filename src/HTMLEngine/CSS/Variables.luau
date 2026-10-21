--!strict
local Syntax=require(script.Parent.Syntax)
local RegisteredProperties=require(script.Parent.RegisteredProperties)
local Variables={}
local function trim(s: string): string return s:match('^%s*(.-)%s*$') :: string end
local function substitute(text: string,lookup: any,depth: number,work: any): string?
	if depth>64 then return nil end
	local output,index,bytes={},1,0
	while index<=#text do
		work.Count+=1;if work.Count>262144 then return nil end
		local at,bodyStart=Syntax.findFunction(text,index,'var')
		if at then
			table.insert(output,text:sub(index,at-1));bytes+=at-index
			local body,after,stop=Syntax.scan(text,bodyStart,')');if stop~=')' then return nil end
			local name,nextIndex,comma=Syntax.scan(body,1,',');name=trim(name)
			local decoded,ending=Syntax.identifier(name);if not decoded or ending<=#name or decoded:sub(1,2)~='--'or #decoded<=2 then return nil end;name=decoded
			local replacement=lookup(name)
			if replacement==nil and comma==',' then replacement=substitute(body:sub(nextIndex),lookup,depth+1,work) end
			if replacement==nil then return nil end
			table.insert(output,replacement);bytes+=#replacement;index=after
		else table.insert(output,text:sub(index));bytes+=#text-index+1;index=#text+1 end
		if bytes>65536 then return nil end
	end
	local result=table.concat(output);if #result>65536 then return nil end;return result
end
function Variables.substitute(text: string,values: any): string?
	return substitute(text,function(name) return values[name] end,0,{Count=0})
end
function Variables.valid(text: string,depth: number?): boolean
	depth=depth or 0;if depth>64 then return false end;local cursor=1
	while cursor<=#text do
		local at,bodyStart=Syntax.findFunction(text,cursor,'var');if not at then return true end
		local body,after,closing=Syntax.scan(text,bodyStart,')');if closing~=')'then return false end
		local name,start,comma=Syntax.scan(body,1,',');name=trim(name)
		local decoded,ending=Syntax.identifier(name)
		if not decoded or ending<=#name or decoded:sub(1,2)~='--'or #decoded<=2 then return false end
		if comma==','and not Variables.valid(body:sub(start),depth+1)then return false end;cursor=after
	end
	return true
end
function Variables.compute(raw: any,parent: any?,registry: any?,context: any?): any
	parent=parent or {};local localValues,result={},table.clone(parent)
	local function initial(name)local registration=registry and registry[name];return registration and RegisteredProperties.compute(registration,registration.Initial,context)end
	local function default(name)local registration=registry and registry[name];return if registration and registration.Inherits then parent[name]or initial(name)else initial(name)end
	for name in registry or{}do result[name]=default(name)end
	for name,value in raw do
		value=trim(value)
		local keyword=value:lower()
		if keyword=='initial'then result[name]=initial(name)
		elseif keyword=='revert'or keyword=='revert-layer'then result[name]=if registry and registry[name]then default(name)else nil
		elseif keyword=='inherit'then result[name]=parent[name]or initial(name)
		elseif keyword=='unset'then result[name]=if registry and registry[name]then default(name)else parent[name]
		else localValues[name]=value;result[name]=nil end
	end
	local edges={}
	local function dependencies(text: string,list: any,depth: number)
		if depth>64 then return end
		local index=1
		while index<=#text do
			local at,bodyStart=Syntax.findFunction(text,index,'var');if not at then return end
				local body,after,stop=Syntax.scan(text,bodyStart,')');if stop~=')' then return end
				local name,afterName,comma=Syntax.scan(body,1,',');local decoded=Syntax.identifier(trim(name));list[decoded or trim(name)]=true
				if comma==',' then dependencies(body:sub(afterName),list,depth+1) end
				index=after
		end
	end
	for name,value in localValues do edges[name]={};dependencies(value,edges[name],0) end
	if context and context.FontSizeDependencies then
		edges['$font-size']={};dependencies(context.FontSizeDependencies,edges['$font-size'],0)
		for name,value in localValues do
			local registration=registry and registry[name]
			if registration and registration.Syntax:find('<length',1,true)and value:lower():match('[%d%.]em%f[%W]')then edges[name]['$font-size']=true end
		end
	end
	local visited,active,stack,cyclic={},{},{},{}
	local function cycle(name: string)
		if active[name] then for i=active[name],#stack do cyclic[stack[i]]=true end;return end
		if visited[name] or not edges[name] then return end
		if #stack>=256 then
			-- Excessive dependency chains are invalid CSS, never a page-ending error.
			cyclic[name]=true
			for _,dependency in stack do cyclic[dependency]=true end
			return
		end
		visited[name]=true;table.insert(stack,name);active[name]=#stack
		for dependency in edges[name] do cycle(dependency) end
		active[name]=nil;table.remove(stack)
	end
	for name in localValues do cycle(name) end
	local done={};local work={Count=0};local resolving=0;local resolve
	resolve=function(name: string): string?
		if done[name] or not localValues[name] then return result[name] end
		if resolving>=256 then return nil end
		done[name]=true
		resolving+=1
		if not cyclic[name] then result[name]=substitute(localValues[name],resolve,0,work) end
		local registration=registry and registry[name]
		if registration then result[name]=RegisteredProperties.compute(registration,result[name],context)or default(name)end
		resolving-=1
		return result[name]
	end
	for name in localValues do resolve(name) end
	return result
end
return Variables
