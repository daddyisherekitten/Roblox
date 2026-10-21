--!strict
-- Resolve position keywords into physical low/high edges. Layout algorithms
-- retain their own sizing, auto-margin and track/flex-axis projection rules.
local WritingMode=require(script.Parent.Parent.CSS.WritingMode)
local Values=require(script.Parent.Parent.CSS.AlignmentValues)
local Alignment={}
Alignment.split=Values.split
Alignment.overflow=Values.overflow
function Alignment.horizontalContainer(style: any): boolean
 return not WritingMode.vertical(style)
end
function Alignment.startAtEnd(horizontal: boolean,style: any): boolean
 local axis=if horizontal==WritingMode.vertical(style)then 'block'else 'inline'
 local side=WritingMode.side(style,axis..'-start')
 return side==2 or side==3
end
function Alignment.resolve(mode: string?,horizontal: boolean,container: any,subject: any?,flexReverse: boolean?,free: number?): string
 local safety;mode,safety=Values.split(mode)
 if free~=nil then mode=Values.overflow(mode,safety,free)end
 if mode=='left'or mode=='right'then
  if horizontal then return if mode=='right'then 'end'else 'start'end
  -- Physical justify left/right fall back to start on a column flex axis.
  mode='start'
 end
 local atEnd
 if mode=='self-start'or mode=='self-end'then
  atEnd=Alignment.startAtEnd(horizontal,subject or container)~=(mode=='self-end')
 elseif mode=='flex-start'or mode=='flex-end'then
  atEnd=(if flexReverse~=nil then flexReverse else Alignment.startAtEnd(horizontal,container))~=(mode=='flex-end')
 elseif mode==nil or mode=='normal'or mode=='stretch'or mode=='start'or mode=='end'then
  atEnd=Alignment.startAtEnd(horizontal,container)~=(mode=='end')
 else return mode end
 return if atEnd then 'end'else 'start'
end
function Alignment.offset(mode: string,free: number): number
 return if mode=='center'then free/2 elseif mode=='end'then free else 0
end
return Alignment
