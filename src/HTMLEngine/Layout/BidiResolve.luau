--!strict
-- UAX9 Unicode17 W1-W7, bracket rule N0, N1-N2 and I1-I2.
local Explicit=require(script.Parent.BidiExplicit)
local Work=require(script.Parent.Parent.WorkContext)
local Resolve={}
local neutrals={B=true,S=true,WS=true,ON=true,LRI=true,RLI=true,FSI=true,PDI=true}
local function strong(kind: string): string?
	return if kind=='L'then 'L'elseif kind=='R'or kind=='EN'or kind=='AN'then 'R'else nil
end
function Resolve.weak(seq: any)
	local types=seq.Types;local previous=seq.SOS
	for index,kind in types do
		Work.checkpoint()
		if kind=='NSM'then types[index]=previous
		else previous=if Explicit.Isolate[kind]or kind=='PDI'then 'ON'else kind end
	end
	local priorStrong=seq.SOS
	for index,kind in types do
		Work.checkpoint()
		if kind=='EN'and priorStrong=='AL'then types[index]='AN'
		elseif kind=='L'or kind=='R'or kind=='AL'then priorStrong=kind end
	end
	for index,kind in types do Work.checkpoint();if kind=='AL'then types[index]='R'end end
	for index=2,#types-1 do
		Work.checkpoint()
		local kind,a,b=types[index],types[index-1],types[index+1]
		if a==b and(kind=='ES'and a=='EN'or kind=='CS'and(a=='EN'or a=='AN'))then types[index]=a end
	end
	local index=1
	while index<=#types do
		Work.checkpoint()
		if types[index]~='ET'then index+=1;continue end
		local ending=index;while types[ending+1]=='ET'do Work.checkpoint();ending+=1 end
		local a,b=if index==1 then seq.SOS else types[index-1],if ending==#types then seq.EOS else types[ending+1]
		if a=='EN'or b=='EN'then for at=index,ending do Work.checkpoint();types[at]='EN'end end
		index=ending+1
	end
	priorStrong=seq.SOS
	for index,kind in types do
		Work.checkpoint()
		if kind=='ES'or kind=='ET'or kind=='CS'then types[index]='ON'
		elseif kind=='EN'and priorStrong=='L'then types[index]='L'
		elseif kind=='L'or kind=='R'then priorStrong=kind end
	end
end
local function canonical(code: number?): number?
	return if code==0x2329 then 0x3008 elseif code==0x232a then 0x3009 else code
end
function Resolve.brackets(seq: any,original: any,codes: any,data: any)
	local stack,pairs={},{};local types,indices=seq.Types,seq.Indices
	for position,index in indices do
		Work.checkpoint();local info=data.Brackets[codes[index]]
		if not info or types[position]~='ON'then continue end
		if info.Open then
			if #stack==63 then break end
			table.insert(stack,{Position=position,Pair=canonical(info.Pair)})
		else
			for at=#stack,1,-1 do
				if stack[at].Pair==canonical(codes[index])then
					table.insert(pairs,{stack[at].Position,position})
					for remove=#stack,at,-1 do stack[remove]=nil end;break
				end
			end
		end
	end
	table.sort(pairs,function(a,b)return a[1]<b[1]end)
	local embed=if seq.Level%2==0 then 'L'else 'R';local prior=seq.SOS;local cursor=1
	for _,pair in pairs do
		Work.checkpoint();local first,last=pair[1],pair[2];local inside=nil
		for at=first+1,last-1 do Work.checkpoint();local direction=strong(types[at]);if direction==embed then inside=embed;break elseif direction then inside=direction end end
		while cursor<first do Work.checkpoint();prior=strong(types[cursor])or prior;cursor+=1 end
		if not inside then continue end
		local direction=if inside==embed or prior~=inside then embed else inside
		types[first],types[last]=direction,direction
		for _,start in {first+1,last+1}do
			local at=start;while indices[at]and original[indices[at]]=='NSM'do Work.checkpoint();types[at]=direction;at+=1 end
		end
	end
end
function Resolve.neutral(seq: any)
	local types=seq.Types;local index=1
	while index<=#types do
		Work.checkpoint()
		if not neutrals[types[index]]then index+=1;continue end
		local ending=index;while neutrals[types[ending+1]]do Work.checkpoint();ending+=1 end
		local a=if index==1 then seq.SOS else strong(types[index-1])
		local b=if ending==#types then seq.EOS else strong(types[ending+1])
		local direction=if a==b then a else if seq.Level%2==0 then 'L'else 'R'
		for at=index,ending do Work.checkpoint();types[at]=direction end;index=ending+1
	end
end
function Resolve.apply(seq: any,types: any,levels: any)
	for position,index in seq.Indices do
		Work.checkpoint();local kind=seq.Types[position];types[index]=kind
		levels[index]=seq.Level+(if seq.Level%2==0 then if kind=='R'then 1 elseif kind=='EN'or kind=='AN'then 2 else 0 else if kind=='R'then 0 else 1)
	end
end
return Resolve
