--!strict
-- Preserve CR provenance after preprocessing: a later document.write CR must
-- swallow an original LF, but must not swallow a separately normalized CR.
local Work=require(script.Parent.Parent.WorkContext)
local Input={}
function Input.normalize(source: string): (string,string?)
	local first=source:find('\r',1,true);if not first then return source,nil end
	local parts,origins={},{};local position=1;local found=first
	while found do
		Work.checkpoint()
		local span=source:sub(position,found-1)
		table.insert(parts,span);table.insert(parts,'\n')
		table.insert(origins,string.rep('\0',#span));table.insert(origins,'\1')
		position=found+(if source:sub(found+1,found+1)=='\n' then 2 else 1)
		found=source:find('\r',position,true)
	end
	local tail=source:sub(position);table.insert(parts,tail);table.insert(origins,string.rep('\0',#tail))
	return table.concat(parts),table.concat(origins)
end
return Input
