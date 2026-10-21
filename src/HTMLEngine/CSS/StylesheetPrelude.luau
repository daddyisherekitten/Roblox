--!strict
-- Shared grammar for CSS URL/string preludes. Resolution belongs to the caller.
local Syntax=require(script.Parent.Syntax)
local Layers=require(script.Parent.CascadeLayers)
local Prelude={}
local function trim(s)return s:match('^%s*(.-)%s*$')or ''end
function Prelude.url(source: string): (string?,string)
	source=trim(source)
	local quote=source:sub(1,1)
	if quote=='"'or quote=="'"then
		local index=2
		while index<=#source do
			local char=source:sub(index,index)
			if char==quote then return Syntax.string(source:sub(1,index)),trim(source:sub(index+1))end
			if char=='\\'then
				if source:sub(index+1,index+1)=='\r'and source:sub(index+2,index+2)=='\n'then index+=3
				else local _,nextIndex=Syntax.escape(source,index);index=nextIndex end
			else index+=1 end
		end
		return nil,''
	end
	local name,start=Syntax.identifier(source)
	if not name or name:lower()~='url'or source:sub(start,start)~='('then return nil,''end
	local body,after,closing=Syntax.scan(source,start+1,')',true)
	if closing~=')'then return nil,''end
	body=trim(body)
	if body:sub(1,1)=='"'or body:sub(1,1)=="'"then local url,rest=Prelude.url(body);return if rest==''then url else nil,trim(source:sub(after))end
	-- Whitespace, quotes and unescaped parentheses invalidate an unquoted URL.
	local index=1
	while index<=#body do local char=body:sub(index,index);if char=='\\'then local value,nextIndex=Syntax.escape(body,index);if not value then return nil,''end;index=nextIndex elseif char:match('[%s"\'()]')or (body:byte(index)or 0)<32 or body:byte(index)==127 then return nil,''else index+=1 end end
	return Syntax.unescape(body),trim(source:sub(after))
end
function Prelude.namespace(source: string): (string?,string?)
	local url,rest=Prelude.url(source)
	if url and rest==''then return '',url end
	local prefix,after=Syntax.identifier(trim(source))
	if not prefix then return nil,nil end
	url,rest=Prelude.url(trim(source):sub(after))
	return if url and rest==''then prefix else nil,url
end
-- Shared @import prelude; the caller evaluates supports/media and loads URLs.
function Prelude.import(source: string): any?
	local href,tail=Prelude.url(source);if not href then return nil end
	local result={Href=href,Media='',Layer=nil,Supports=nil}
	local name,after=Syntax.identifier(tail)
	if name and name:lower()=='layer'then
		if tail:sub(after,after)=='('then
			local layer,following,closing=Syntax.scan(tail,after+1,')')
			layer=trim(layer);if closing==')'and Layers.valid(layer)then
				result.Layer=Layers.name(layer);tail=trim(tail:sub(following))
			end -- Otherwise the function can be a general-enclosed media condition.
		else result.Layer='';tail=trim(tail:sub(after))end
	end
	name,after=Syntax.identifier(tail)
	if name and name:lower()=='supports'and tail:sub(after,after)=='('then
		local test,following,closing=Syntax.scan(tail,after+1,')')
		test=trim(test);if closing~=')'or test==''then return nil end
		result.Supports=test;tail=trim(tail:sub(following))
	end
	result.Media=tail;return result
end
return Prelude
