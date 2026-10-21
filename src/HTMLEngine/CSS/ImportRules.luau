--!strict
-- Discover only eligible top-level imports; resource and CSSOM owners keep
-- their own instances even when several rules request the same URL.
local Syntax=require(script.Parent.Syntax)
local Prelude=require(script.Parent.StylesheetPrelude)
local Selectors=require(script.Parent.Selectors)
local Layers=require(script.Parent.CascadeLayers)
local Imports={}
local blocks={media=true,supports=true,layer=true,scope=true,container=true,['font-face']=true,keyframes=true,['-webkit-keyframes']=true,property=true,['counter-style']=true,page=true,['font-palette-values']=true,['position-try']=true,['starting-style']=true}
function Imports.closes(header:string):boolean
	local name,prelude=Syntax.atRule(header)
	if not name then return Selectors.compile(header)~=nil end
	if not blocks[name]then return false end
	if name=='layer'then return prelude==''or Layers.valid(prelude)end
	if name=='supports'then return prelude:sub(1,1)=='('or prelude:lower():match('^not%s')~=nil or prelude:lower():match('^selector%(')~=nil end
	return true
end
function Imports.read(source:string):any
	local result,index,closed={},1,false
	while index<=#source do
		local header,after,delimiter=Syntax.scan(source,index,'{;}');index=after
		local name,prelude=Syntax.atRule(header)
		if delimiter=='{'then
			local _,following=Syntax.scan(source,index,'}',true);index=following
			if Imports.closes(header)then closed=true end
		elseif delimiter==';'then
			if name=='import'and not closed then
				local imported=Prelude.import(prelude);if imported then table.insert(result,imported)end
			elseif name=='namespace'then local prefix,uri=Prelude.namespace(prelude);if prefix~=nil and uri~=nil then closed=true end
			end
		end
	end
	return result
end
return Imports
