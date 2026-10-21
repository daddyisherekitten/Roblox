--!strict
local Trim={}
local function eligible(child)
 return child and child.Kind~='Words' and child.Style.Float=='none' and child.Style.Display~='inline' and child.Style.Position~='absolute' and child.Style.Position~='fixed'
end
function Trim.edge(box,side)
 if not eligible(box) then return end
 box.TrimmedMargins=box.TrimmedMargins or {};box.TrimmedMargins[side]=true
 box.LayoutMargin=table.clone(box.LayoutMargin or box.Style.Margin);box.LayoutMargin[side]=0
 if side==1 and box.CollapseTop or side==3 and box.CollapseBottom then
  local flow=box.FlowChildren or box.Children
  Trim.edge(flow[if side==1 then 1 else #flow],side)
 end
end
function Trim.apply(box)
 local s=box.Style;local trim=s.MarginTrim or {}
 if s.Display~='block' and not s.ColumnCount and not s.ColumnWidth and not s.ColumnHeight then return end
 local flow=box.FlowChildren or box.Children;local first,last=flow[1],flow[#flow]
 if trim.Start then Trim.edge(first,1)end
 if trim.End then Trim.edge(last,3)end
end
function Trim.restore(box)
 if not box.TrimmedMargins then return end
 box.LayoutMargin=table.clone(box.LayoutMargin or box.Style.Margin)
 for side in box.TrimmedMargins do box.LayoutMargin[side]=0 end
end
return Trim
