--!strict
local Syntax=require(script.Parent.Syntax)
local Length=require(script.Parent.LengthExpression)
local ViewBox={}

function ViewBox.parse(value: string,parseLength: (string,boolean?)->any?): any?
 if value=='none' then return nil end
 local kind,body=value:match('^([%a]+)%((.*)%)$')
 if kind~='inset' and kind~='xywh' and kind~='rect' then return nil end
 local parts,index={},1
 while index<=#body do
  local part,nextIndex=Syntax.scan(body,index,' \t\r\n');index=nextIndex
  if part~='' then table.insert(parts,part) end
 end
 if #parts<1 or #parts>4 or (kind~='inset' and #parts~=4) then return nil end
 local values={}
 for i,part in parts do
  local length=if part=='auto' and kind=='rect' then false else parseLength(part,kind~='xywh' or i<=2)
  if length==nil then return nil end
  values[i]=length
 end
 if kind=='inset' then values={values[1],values[2] or values[1],values[3] or values[1],values[4] or values[2] or values[1]} end
 return {Kind=kind,Values=values}
end

function ViewBox.rectangle(view: any?,width: number,height: number): (number,number,number,number)
 if not view then return 0,0,width,height end
 local v=view.Values
 if view.Kind=='xywh' then return Length.resolve(v[1],width),Length.resolve(v[2],height),math.max(0,Length.resolve(v[3],width)),math.max(0,Length.resolve(v[4],height)) end
 local top=if v[1] then Length.resolve(v[1],height) else 0
 local right=if v[2] then Length.resolve(v[2],width) else width
 local bottom=if v[3] then Length.resolve(v[3],height) else height
 local left=if v[4] then Length.resolve(v[4],width) else 0
 if view.Kind=='inset' then
  -- Opposite insets above 100% are reduced proportionally, as for inset().
  if left+right>width then local factor=width/(left+right);left*=factor;right*=factor end
  if top+bottom>height then local factor=height/(top+bottom);top*=factor;bottom*=factor end
  return left,top,math.max(0,width-left-right),math.max(0,height-top-bottom)
 end
 return left,top,math.max(0,right-left),math.max(0,bottom-top)
end
return ViewBox
