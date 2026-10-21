--!strict
-- CSS Writing Modes4 physical axes. Array side order is top/right/bottom/left.
local Axes={}
function Axes.vertical(style: any): boolean
 local mode=style and style.WritingMode
 return mode=='vertical-rl'or mode=='vertical-lr'or mode=='sideways-rl'or mode=='sideways-lr'
end
function Axes.blockReverse(style: any): boolean
 return style and(style.WritingMode=='vertical-rl'or style.WritingMode=='sideways-rl')or false
end
function Axes.inlineReverse(style: any): boolean
 return (style and style.Direction=='rtl'or false)~=(style and style.WritingMode=='sideways-lr'or false)
end
function Axes.dimension(style: any,axis: string,prefix: string?): string
 local height=(axis=='inline')==Axes.vertical(style)
 return (prefix or '')..(if height then 'Height'else 'Width')
end
function Axes.side(style: any,name: string): number
 if Axes.vertical(style)then
  if name=='block-start'then return if Axes.blockReverse(style)then 2 else 4 end
  if name=='block-end'then return if Axes.blockReverse(style)then 4 else 2 end
  if name=='inline-start'then return if Axes.inlineReverse(style)then 3 else 1 end
  return if Axes.inlineReverse(style)then 1 else 3
 end
 if name=='block-start'then return 1 elseif name=='block-end'then return 3 end
 if name=='inline-start'then return if Axes.inlineReverse(style)then 2 else 4 end
 return if Axes.inlineReverse(style)then 4 else 2
end
function Axes.corner(style: any,name: string): number
 local block,inline=name:match('^(%a+)%-(%a+)$')
 local a,b=Axes.side(style,'block-'..block),Axes.side(style,'inline-'..inline)
 local top=a==1 or b==1;local right=a==2 or b==2
 return if top then(if right then 2 else 1)else(if right then 3 else 4)
end
-- Word flow stores X along the unrotated inline axis, Y along its line stack.
-- Projecting its rectangle does not rotate the physical CSS border sides.
function Axes.rect(style: any,x: number,y: number,width: number,height: number,contentWidth: number,flowWidth: number): (number,number,number,number)
 if not Axes.vertical(style)then return x,y,width,height end
 local block=if Axes.blockReverse(style)then contentWidth-y-height else y
 local inline=if style.WritingMode=='sideways-lr'then flowWidth-x-width else x
 return block,inline,height,width
end
function Axes.flowSides(style: any): (number,number,number,number)
 if not Axes.vertical(style)then return 4,2,1,3 end
 local low,high=if style.WritingMode=='sideways-lr'then 3 else 1,if style.WritingMode=='sideways-lr'then 1 else 3
 return low,high,if Axes.blockReverse(style)then 2 else 4,if Axes.blockReverse(style)then 4 else 2
end
return Axes
