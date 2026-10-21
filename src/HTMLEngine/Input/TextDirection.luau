--!strict
-- Resolved UAX9 pieces own their parity. Unprepared legacy labels retain only
-- a homogeneous-direction fallback; this is not a glyph-cluster caret map.
local BidiClass=require(script.Parent.Parent.Layout.BidiClass)
local TextDirection={}
function TextDirection.of(item: any): string
 if item.BidiDirection then return item.BidiDirection end
 if item.SelectionDirectionText==item.Text then return item.SelectionDirection or 'ltr'end
 local first,mixed,numbers=nil,false,false
 for _,code in utf8.codes(item.Text or '')do
  local class=BidiClass.get(code)
  local direction=if class=='R'or class=='AL'then 'rtl'elseif class=='L'then 'ltr'else nil
  if direction then if first and first~=direction then mixed=true end;first=first or direction end
  if class=='EN'or class=='AN'then numbers=true end
 end
 local direction=if not mixed and not(first=='rtl'and numbers)then first or 'ltr'else 'ltr'
 item.SelectionDirectionText,item.SelectionDirection,item.SelectionMixedBidi=item.Text,direction,mixed or first=='rtl'and numbers
 return direction
end
return TextDirection
