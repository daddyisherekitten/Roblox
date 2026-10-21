--!strict
-- Active formatting reconstruction and the bounded adoption agency algorithm.
local Context=require(script.Parent.TreeContext)
local Formatting={}
Formatting.Names={a=true,b=true,big=true,code=true,em=true,font=true,i=true,nobr=true,s=true,small=true,strike=true,strong=true,tt=true,u=true}
function Formatting.add(c: any,node: any)
	local identical={}
	for i=#c.Active,1,-1 do
		local candidate=c.Active[i]; if candidate==false then break end
		if candidate.Name~=node.Name or candidate.NamespaceURI~=node.NamespaceURI then continue end
		local equal=true
		for name,value in candidate.Attributes do if node.Attributes[name]~=value then equal=false; break end end
		for name,value in node.Attributes do if candidate.Attributes[name]~=value then equal=false; break end end
		if equal then table.insert(identical,i) end
	end
	if #identical>=3 then table.remove(c.Active,identical[#identical]) end
	table.insert(c.Active,node)
end
function Formatting.ordinaryEnd(c: any,name: string)
	for i=#c.Stack,1,-1 do
		local node=c.Stack[i]
		if node.Name==name and node.NamespaceURI==nil then c:implied(name); for _=#c.Stack,i,-1 do c:pop() end; return end
		if Context.isSpecial(node) then return end
	end
end
function Formatting.finish(c: any,name: string)
	local current=c:current()
	if current and current.Name==name and not table.find(c.Active,current) then c:pop(); return end
	for _=1,8 do
		c:checkpoint()
		local format,activeIndex=c:active(name)
		if not format then Formatting.ordinaryEnd(c,name); return end
		local stackIndex=table.find(c.Stack,format)
		if not stackIndex then table.remove(c.Active,activeIndex); return end
		if not c:inScope(format) then return end
		local furthest,furthestIndex
		for i=stackIndex+1,#c.Stack do if Context.isSpecial(c.Stack[i]) then furthest,furthestIndex=c.Stack[i],i; break end end
		if not furthest then for _=#c.Stack,stackIndex,-1 do c:pop() end; table.remove(c.Active,activeIndex); return end
		local ancestor=c.Stack[stackIndex-1]; local bookmark=activeIndex
		local last=furthest; local index=furthestIndex
		local inner=0
		while true do
			inner+=1; index-=1; local node=c.Stack[index]
			if node==format then break end
			local entry=table.find(c.Active,node)
			if inner>3 and entry then table.remove(c.Active,entry); if entry<bookmark then bookmark-=1 end; entry=nil end
			if not entry then table.remove(c.Stack,index); continue end
			local copy=c:clone(node); c.Active[entry]=copy; c.Stack[index]=copy
			if last==furthest then bookmark=entry+1 end
			c:attach(last,copy); last=copy
		end
		local foster=c.Foster; c.Foster=true
		local parent,before=c:location(ancestor); c.Foster=foster; c:attach(last,parent,before)
		local replacement=c:clone(format)
		local children=table.clone(furthest.Children)
		for _,child in children do c:attach(child,replacement) end
		c:attach(replacement,furthest)
		local old=table.find(c.Active,format); table.remove(c.Active,old); if old<bookmark then bookmark-=1 end
		table.insert(c.Active,bookmark,replacement)
		c:remove(format); table.insert(c.Stack,table.find(c.Stack,furthest)+1,replacement)
	end
end
return Formatting
