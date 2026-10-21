--!strict
-- One grammar and axis map for author areas, CSSOM and position-try regions.
local Components=require(script.Parent.MediaSyntax)
local WritingMode=require(script.Parent.WritingMode)
local Area={}
local function token(value)
	if value=='center'or value=='span-all'then return {Text=value,Family='any',Axis=nil,Track=value}end
	local text=value;local span=value:sub(1,5)=='span-';if span then value=value:sub(6)end
	local self=value:sub(1,5)=='self-';if self then value=value:sub(6)end
	local axis,family,side
	if value=='left'or value=='right'then if self then return nil end;axis,family,side='x','physical',if value=='left'then 'start'else 'end'
	elseif value=='top'or value=='bottom'then if self then return nil end;axis,family,side='y','physical',if value=='top'then 'start'else 'end'
	else
		axis,side=value:match('^(x)%-([a-z]+)$');if not axis then axis,side=value:match('^(y)%-([a-z]+)$')end
		if axis then family='physical'
		else axis,side=value:match('^(block)%-([a-z]+)$');if not axis then axis,side=value:match('^(inline)%-([a-z]+)$')end
			if not axis then side=value end;family=if self then 'self'else 'logical'
		end
		if side~='start'and side~='end'then return nil end
	end
	return {Text=text,Family=family,Axis=axis,Short=axis==nil,Track=(if span then 'span-'else '')..side,Self=self,
		Physical=value=='top'or value=='bottom'or value=='left'or value=='right'}
end
local function pair(value)
	local items=Components.parse(value);if not items or #items<1 or #items>2 then return nil end
	if #items==1 and items[1].Kind=='ident'and items[1].Value=='none'then return {None=true}end
	local a,b
	for index,item in items do if item.Kind~='ident'then return nil end;local parsed=token(item.Value);if not parsed then return nil end;if index==1 then a=parsed else b=parsed end end
	if not b then b=if a.Axis then token('span-all')else table.clone(a)end
	local family=if a.Family~='any'then a.Family else b.Family
	if a.Family~='any'and b.Family~='any'and a.Family~=b.Family then return nil end
	if a.Family~='any'and b.Family~='any'and a.Short~=b.Short then return nil end
	local first,second=if family=='physical'then 'x'else 'block',if family=='physical'then 'y'else 'inline'
	if a.Axis and b.Axis and a.Axis==b.Axis then return nil end
	if not a.Axis then a.Axis=if b.Axis then(if b.Axis==first then second else first)else first end
	if not b.Axis then b.Axis=if a.Axis==first then second else first end
	if a.Axis~=first then a,b=b,a end
	return {A=a,B=b,Family=family}
end
local function serialize(p,computed)
	if p.None then return 'none'end
	local a,b=p.A,p.B
	local function text(t,short)
		if not short or p.Family=='physical'or t.Family=='any'then return t.Text end
		return (if t.Track:sub(1,5)=='span-'then 'span-'else '')..(if p.Family=='self'then 'self-'else '')..(if t.Track:sub(1,5)=='span-'then t.Track:sub(6)else t.Track)
	end
	if a.Track==b.Track and a.Family=='any'and b.Family=='any'then return a.Text end
	if a.Track=='span-all'or b.Track=='span-all'then
		local t=if a.Track=='span-all'then b else a
		if t.Text~='center'and t.Text~='span-all'and(token(t.Text).Axis or computed)then
			if computed and p.Family~='physical'and not token(t.Text).Axis then
				return (if t.Track:sub(1,5)=='span-'then 'span-'else '')..(if p.Family=='self'then 'self-'else '')..t.Axis..'-'..(if t.Track:sub(1,5)=='span-'then t.Track:sub(6)else t.Track)
			end
			return t.Text
		end
	end
	return text(a,computed)..' '..text(b,computed)
end
function Area.parse(value)local p=pair(value);return if p then serialize(p,false)else nil end
function Area.serialize(value,computed)local p=pair(value);return if p then serialize(p,computed)else nil end
local vertical=WritingMode.vertical
function Area.reverse(style,axis)
	return if axis=='x'then(if vertical(style)then WritingMode.blockReverse(style)else WritingMode.inlineReverse(style))else vertical(style)and WritingMode.inlineReverse(style)
end
function Area.tracks(value,containingStyle,selfStyle)
	local p=pair(value);if not p or p.None then return nil end
	local result={}
	for _,t in {p.A,p.B}do
		local source=if p.Family=='self'or t.Self then selfStyle else containingStyle
		local axis=t.Axis
		if axis=='block'then axis=if vertical(source)then 'x'else 'y'elseif axis=='inline'then axis=if vertical(source)then 'y'else 'x'end
		local track=t.Track
		if track~='center'and track~='span-all'and not t.Physical and Area.reverse(source,axis)then
			track=({start='end',['end']='start',['span-start']='span-end',['span-end']='span-start'})[track]
		end
		result[axis]=track
	end
	return result
end
local intervals={start={1,2},center={2,3},['end']={3,4},['span-start']={1,3},['span-end']={2,4},['span-all']={1,4}}
function Area.region(value,containing,selfStyle,anchor,offsetX,offsetY)
	if not anchor then return nil end
	local tracks=Area.tracks(value,containing.Style or{},selfStyle);if not tracks then return nil end
	local ax,ay=anchor.X-(offsetX or 0),anchor.Y-(offsetY or 0)
	local xs={math.min(containing.X,ax),ax,ax+anchor.Width,math.max(containing.X+containing.Width,ax+anchor.Width)}
	local ys={math.min(containing.Y,ay),ay,ay+anchor.Height,math.max(containing.Y+containing.Height,ay+anchor.Height)}
	local x,y=intervals[tracks.x],intervals[tracks.y]
	local result=table.clone(containing);result.X,result.Y=xs[x[1]],ys[y[1]];result.Width,result.Height=xs[x[2]]-result.X,ys[y[2]]-result.Y
	result.AreaTracks=tracks;result.AnchorCenterX,result.AnchorCenterY=ax+anchor.Width/2,ay+anchor.Height/2
	return result
end
function Area.flip(value,containingStyle,selfStyle,map)
	local tracks=Area.tracks(value,containingStyle,selfStyle);if not tracks then return value end
	local result={};local startSide={x='left',y='top'};local endSide={x='right',y='bottom'}
	for axis,track in tracks do
		local source=startSide[axis];local target=map[source];local output=if target=='left'or target=='right'then 'x'else 'y'
		if target==endSide[output]then track=({start='end',['end']='start',['span-start']='span-end',['span-end']='span-start'})[track]or track end
		local side=if track=='start'or track=='span-start'then startSide[output]else endSide[output]
		result[output]=if track=='center'or track=='span-all'then track else(if track:sub(1,5)=='span-'then 'span-'else '')..side
	end
	return Area.parse(result.x..' '..result.y)
end
return Area
