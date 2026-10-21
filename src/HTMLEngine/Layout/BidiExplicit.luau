--!strict
-- UAX9 Unicode17 P2/P3 and X1-X9. No DOM, GUI or glyph shaping assumptions.
local Work=require(script.Parent.Parent.WorkContext)
local Explicit={}
Explicit.Isolate={LRI=true,RLI=true,FSI=true}
Explicit.Removed={LRE=true,RLE=true,LRO=true,RLO=true,PDF=true,BN=true}
function Explicit.matches(types: any): (any,any)
	local stack,closing,opening={},{},{}
	for index,kind in types do
		Work.checkpoint()
		if Explicit.Isolate[kind]then table.insert(stack,index)
		elseif kind=='PDI'and #stack>0 then local start=table.remove(stack);closing[start],opening[index]=index,start end
	end
	for _,index in stack do closing[index]=#types+1 end
	return closing,opening
end
function Explicit.base(types: any,closing: any,first: number?,last: number?): number
	local index,limit=first or 1,last or #types
	while index<=limit do
		Work.checkpoint();local kind=types[index]
		if kind=='L'then return 0 elseif kind=='R'or kind=='AL'then return 1 end
		index=if Explicit.Isolate[kind]then closing[index]+1 else index+1
	end
	return 0
end
function Explicit.levels(original: any,base: number,closing: any): (any,any)
	local types,levels=table.clone(original),table.create(#original,base)
	local stack={{Level=base,Override=nil,Isolate=false}}
	local overflowIsolates,overflowEmbeddings,validIsolates=0,0,0
	for index,kind in original do
		Work.checkpoint();local state=stack[#stack]
		if kind=='RLE'or kind=='LRE'or kind=='RLO'or kind=='LRO'or Explicit.Isolate[kind]then
			local isolate=Explicit.Isolate[kind]==true
			local rtl=kind=='RLE'or kind=='RLO'or kind=='RLI'or kind=='FSI'and Explicit.base(original,closing,index+1,closing[index]-1)==1
			if isolate then levels[index]=state.Level;types[index]=state.Override or kind end
			local nextLevel=if rtl then state.Level+1+(state.Level%2)else state.Level+2-state.Level%2
			if nextLevel<=125 and overflowIsolates==0 and overflowEmbeddings==0 then
				if isolate then validIsolates+=1 else levels[index]=nextLevel end
				table.insert(stack,{Level=nextLevel,Override=if kind=='RLO'then 'R'elseif kind=='LRO'then 'L'else nil,Isolate=isolate})
			elseif isolate then overflowIsolates+=1 elseif overflowIsolates==0 then overflowEmbeddings+=1 end
		elseif kind=='PDI'then
			if overflowIsolates>0 then overflowIsolates-=1
			elseif validIsolates>0 then
				overflowEmbeddings=0
				while not stack[#stack].Isolate do table.remove(stack)end
				table.remove(stack);validIsolates-=1
			end
			state=stack[#stack];levels[index]=state.Level;types[index]=state.Override or kind
		elseif kind=='PDF'then
			levels[index]=state.Level
			if overflowIsolates==0 then
				if overflowEmbeddings>0 then overflowEmbeddings-=1 elseif #stack>1 and not state.Isolate then table.remove(stack)end
			end
		elseif kind=='B'then levels[index]=base
		else levels[index]=state.Level;types[index]=state.Override or kind end
	end
	return types,levels
end
return Explicit
