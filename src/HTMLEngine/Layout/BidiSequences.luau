--!strict
-- UAX9 BD13/X10 isolating run sequences retain original codepoint indices.
local Explicit=require(script.Parent.BidiExplicit)
local Work=require(script.Parent.Parent.WorkContext)
local Sequences={}
function Sequences.build(original: any,types: any,levels: any,base: number,closing: any,opening: any): any
	local runs,runOf,previous,nextChar={},{},{},{}
	local before=nil
	for index,kind in original do
		Work.checkpoint();previous[index]=before
		if Explicit.Removed[kind]then continue end
		if before then nextChar[before]=index end;before=index
		local run=runs[#runs]
		if not run or levels[run[1]]~=levels[index]then run={};table.insert(runs,run)end
		table.insert(run,index);runOf[index]=#runs
	end
	local sequences={}
	for _,run in runs do
		local first=run[1]
		if original[first]=='PDI'and opening[first]then continue end
		local indices={};local current=run
		while current do
			for _,index in current do Work.checkpoint();table.insert(indices,index)end
			local last=indices[#indices]
			current=if Explicit.Isolate[original[last]]and closing[last]<=#original then runs[runOf[closing[last]]]else nil
		end
		local last=indices[#indices];local level=levels[first]
		local previousLevel=if previous[first]then levels[previous[first]]else base
		local nextLevel=if Explicit.Isolate[types[last]]then base elseif nextChar[last]then levels[nextChar[last]]else base
		local seqTypes={};for _,index in indices do Work.checkpoint();table.insert(seqTypes,types[index])end
		table.insert(sequences,{Indices=indices,Types=seqTypes,Level=level,SOS=if math.max(level,previousLevel)%2==0 then 'L'else 'R',EOS=if math.max(level,nextLevel)%2==0 then 'L'else 'R'})
	end
	return sequences
end
return Sequences
