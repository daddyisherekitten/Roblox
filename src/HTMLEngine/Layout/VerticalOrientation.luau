--!strict
-- UAX50 orientation is determined for a complete grapheme, never for an
-- independently rotated combining mark. Heavy data is loaded only on demand.
local Work=require(script.Parent.Parent.WorkContext)
local Orientation={}
local data
local function resources(): any
 if not data then data=require(script.Parent.VerticalOrientationData)end
 return data
end
function Orientation.class(code: number): string
 local ranges=resources().Ranges;local low,high=1,#ranges
 while low<=high do
  local middle=math.floor((low+high)/2);local range=ranges[middle]
  if code<range[1]then high=middle-1 elseif code>range[2]then low=middle+1 else return range[3]end
 end
 return 'R'
end
function Orientation.cluster(text: string): string
 local first=true;local result='R';local enclosing=resources().Enclosing
 for _,code in utf8.codes(text)do
  if enclosing[code]then return 'U'end
  if first then result=Orientation.class(code);first=false end
 end
 return result
end
function Orientation.parts(text: string): any
 local result={}
 for first,last in utf8.graphemes(text)do
  Work.checkpoint();local kind=Orientation.cluster(text:sub(first,last))
  -- CSS Writing Modes4 5.1.2 requires U/Tu/Tr upright. The adapter keeps
  -- alternate-form requirements explicit; a horizontal glyph is a fallback,
  -- not a claim that native vertical font substitutions have been delivered.
  local mode=if kind=='R'then 'sideways'else 'upright'
  local previous=result[#result]
  if previous and previous.Mode==mode then
   previous.Last=last;previous.Alternate=previous.Alternate or kind=='Tu'or kind=='Tr'
  else table.insert(result,{First=first,Last=last,Mode=mode,Alternate=kind=='Tu'or kind=='Tr'})end
 end
 return result
end
function Orientation.mixed(style: any): boolean
 return style and(style.WritingMode=='vertical-rl'or style.WritingMode=='vertical-lr')and style.TextOrientation=='mixed'
end
return Orientation
