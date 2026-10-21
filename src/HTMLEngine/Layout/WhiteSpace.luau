--!strict
-- Independent CSS Text whitespace/wrapping axes, including legacy shorthands.
local WhiteSpace={}
local COLLAPSE={collapse=true,discard=true,preserve=true,['preserve-breaks']=true,['preserve-spaces']=true,['break-spaces']=true}
local LEGACY={normal={'collapse','wrap'},nowrap={'collapse','nowrap'},pre={'preserve','nowrap'},['pre-wrap']={'preserve','wrap'},['pre-line']={'preserve-breaks','wrap'}}
function WhiteSpace.serialize(collapse: string,wrap: string): string
	if collapse=='collapse'then return if wrap=='nowrap'then 'nowrap'else 'normal'end
	if collapse=='preserve'then return if wrap=='nowrap'then 'pre'else 'pre-wrap'end
	if collapse=='preserve-breaks'and wrap=='wrap'then return 'pre-line'end
	return collapse..(if wrap=='nowrap'then ' nowrap'else '')
end
function WhiteSpace.parse(value: string): (string?,string?)
	local legacy=LEGACY[value];if legacy then return legacy[1],legacy[2]end
	local collapse,wrap,count=nil,nil,0
	for token in value:gmatch('%S+')do
		count+=1
		if COLLAPSE[token]then if collapse then return nil,nil end;collapse=token
		elseif token=='wrap'or token=='nowrap'then if wrap then return nil,nil end;wrap=token
		else return nil,nil end
	end
	if count==0 then return nil,nil end
	return collapse or 'collapse',wrap or 'wrap'
end
function WhiteSpace.collapse(style: any): string
	if style.WhiteSpaceCollapse then return style.WhiteSpaceCollapse end
	local collapse=WhiteSpace.parse(style.WhiteSpace or 'normal');return collapse or 'collapse'
end
function WhiteSpace.wraps(style: any): boolean
	if style.TextWrapMode then return style.TextWrapMode~='nowrap'end
	local _,wrap=WhiteSpace.parse(style.WhiteSpace or 'normal');return wrap~='nowrap'
end
function WhiteSpace.hanging(style: any): boolean
	return WhiteSpace.collapse(style)=='preserve'and WhiteSpace.wraps(style)
end
function WhiteSpace.expandable(style: any): boolean
	local collapse=WhiteSpace.collapse(style)
	return collapse=='preserve'or collapse=='preserve-spaces'or collapse=='break-spaces'
end
return table.freeze(WhiteSpace)
