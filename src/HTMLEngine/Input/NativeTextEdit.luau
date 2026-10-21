--!strict
-- A TextBox reports its resulting text, not OS composition/paste operations.
-- Preserve Unicode boundaries and expose only the edit information observed.
local NativeTextEdit={}
function NativeTextEdit.describe(before,after,hint)
	local old,new={},{}
	for _,code in utf8.codes(before)do table.insert(old,code)end
	for _,code in utf8.codes(after)do table.insert(new,code)end
	local prefix=0;while prefix<#old and prefix<#new and old[prefix+1]==new[prefix+1]do prefix+=1 end
	local suffix=0;while suffix<#old-prefix and suffix<#new-prefix and old[#old-suffix]==new[#new-suffix]do suffix+=1 end
	local inserted={};for i=prefix+1,#new-suffix do table.insert(inserted,utf8.char(new[i]))end
	local data=table.concat(inserted)
	local inputType=hint or(if #inserted>0 then "insertText"else "")
	return {data=if #inserted>0 and inputType~="insertLineBreak"then data else nil,inputType=inputType,isComposing=false,isTrusted=true,composed=true}
end
return NativeTextEdit
