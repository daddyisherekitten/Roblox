--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- DOM selections count UTF-16 units. Roblox TextBox positions count UTF-8 bytes.
-- Keep the exact DOM extent, including a boundary inside a surrogate pair; the
-- native editor can only display the nearest complete Unicode boundary.
local Strings=require(script.Parent.Parent.JavaScript.Strings)
local Selection={}
local TYPES={text=true,search=true,url=true,tel=true,password=true}
local KNOWN={text=true,search=true,url=true,tel=true,password=true,email=true,date=true,month=true,week=true,time=true,
	["datetime-local"]=true,number=true,range=true,color=true,checkbox=true,radio=true,file=true,submit=true,image=true,reset=true,button=true,hidden=true}
function Selection.applies(node: any): boolean
	if ElementNames.htmlName(node)=="textarea" then return true end
	if ElementNames.htmlName(node)~="input" then return false end
	local kind=(node.Attributes.type or "text"):lower()
	return TYPES[if KNOWN[kind]then kind else "text"]==true
end
-- select() also applies to the text UI of email/number, although their IDL
-- selection getters/range setters are deliberately unavailable.
function Selection.selectable(node: any): boolean
	if Selection.applies(node)then return true end
	local kind=if ElementNames.htmlName(node)=="input"then (node.Attributes.type or "text"):lower()else ""
	return kind=="email"or kind=="number"
end
local function relevant(c: any): string
	return if c.Type=="number"then c.EditText or c.Value or ""else c.Value or ""
end
function Selection.ensure(c: any)
	if c.SelectionStart==nil then c.SelectionStart,c.SelectionEnd,c.SelectionDirection=0,0,"none";c.SelectionValue=relevant(c)end
end
function Selection.nativeText(text: string): string
	if not text:find("\237",1,true)then return text end
	local parts={}
	for code in Strings.codes(text)do table.insert(parts,utf8.char(if code>=0xd800 and code<=0xdfff then 0xfffd else code))end
	return table.concat(parts)
end
local function changed(c: any,previousStart: number,previousEnd: number,previousDirection: string,selectEvent: boolean)
	if (previousStart~=c.SelectionStart or previousEnd~=c.SelectionEnd or previousDirection~=c.SelectionDirection) and c.SelectionChanged then
		c.SelectionChanged(c,selectEvent)
	end
end
function Selection.set(c: any,start: number,finish: number,direction: string?,selectEvent: boolean?): boolean
	Selection.ensure(c)
	local value=relevant(c);local length=Strings.length(value)
	start,finish=math.min(start,length),math.min(finish,length)
	if finish<=start then start=finish end
	direction=if direction=="forward" or direction=="backward" then direction else "none"
	local previousStart,previousEnd,previousDirection=c.SelectionStart,c.SelectionEnd,c.SelectionDirection
	c.SelectionStart,c.SelectionEnd,c.SelectionDirection,c.SelectionValue=start,finish,direction,value
	local different=previousStart~=start or previousEnd~=finish or previousDirection~=direction
	changed(c,previousStart,previousEnd,previousDirection,selectEvent~=false)
	return different
end
function Selection.valueChanged(c: any,moveToEnd: boolean?)
	if not Selection.selectable(c.Node) then return end
	Selection.ensure(c)
	local oldValue=c.SelectionValue
	local value=relevant(c)
	if oldValue==value then return end
	local length=Strings.length(value)
	local start,finish,direction=c.SelectionStart,c.SelectionEnd,c.SelectionDirection
	if moveToEnd then start,finish,direction=length,length,"none"
	else start,finish=math.min(start,length),math.min(finish,length) end
	Selection.set(c,start,finish,direction,false)
end
-- Native byte positions are one-based, with #text+1 representing its end.
function Selection.toByte(text: string,offset: number): number
	local units,byte=0,1
	for code in Strings.codes(text)do
		local size=if code>0xffff then 2 else 1
		if units+size>offset then return byte end
		units+=size;byte+=if code<0x80 then 1 elseif code<0x800 then 2 elseif code<0x10000 then 3 else 4
	end
	return #text+1
end
function Selection.fromByte(text: string,position: number): number
	local units,byte=0,1
	for code in Strings.codes(text)do
		local size=if code<0x80 then 1 elseif code<0x800 then 2 elseif code<0x10000 then 3 else 4
		if byte+size>position then return units end
		byte+=size;units+=if code>0xffff then 2 else 1
	end
	return units
end
function Selection.paint(c: any)
	local editor=c.Item and c.Item.Editor
	if not editor or not c.Focused or not Selection.selectable(c.Node)then return end
	Selection.ensure(c)
	local value=relevant(c)
	local start,finish=Selection.toByte(value,c.SelectionStart),Selection.toByte(value,c.SelectionEnd)
	local cursor,anchor=if c.SelectionDirection=="backward"then start else finish,if c.SelectionDirection=="backward"then finish else start
	if c.SelectionStart==c.SelectionEnd then anchor=-1 end
	-- Read signals must not interpret the intermediate half of a two-property write.
	c.SelectionWriting=true
	if editor.CursorPosition~=cursor then editor.CursorPosition=cursor end
	if editor.SelectionStart~=anchor then editor.SelectionStart=anchor end
	c.SelectionWriting=false
	c.SelectionNativeCursor,c.SelectionNativeAnchor=cursor,anchor
end
function Selection.read(c: any): boolean
	local editor=c.Item and c.Item.Editor
	if not editor or c.SelectionWriting or not Selection.selectable(c.Node)then return false end
	local cursor,anchor=editor.CursorPosition or -1,editor.SelectionStart or -1
	if cursor<1 then return false end -- Losing native focus never clears the DOM selection.
	local value=relevant(c)
	if c.SelectionNativeCursor==cursor and c.SelectionNativeAnchor==anchor and c.SelectionValue==value then return false end
	local at=Selection.fromByte(value,cursor)
	local other=if anchor>=1 then Selection.fromByte(value,anchor)else at
	local direction=if at<other then "backward"elseif at>other then "forward"else "none"
	c.SelectionNativeCursor,c.SelectionNativeAnchor=cursor,anchor
	return Selection.set(c,math.min(at,other),math.max(at,other),direction,true)
end
return Selection
