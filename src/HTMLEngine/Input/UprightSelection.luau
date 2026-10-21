--!strict
-- The source word owns selection; retained upright cells merely provide its
-- physical inline-axis projection. No native measurement or source mutation.
local Upright={}
function Upright.width(item: any,offset: number): number
 if offset<=0 then return 0 end
 if item.VerticalCharacters then local nextGlyph=item.VerticalCharacters[offset+1];return if nextGlyph then nextGlyph.Advance else item.Width end
 return item.Width*math.clamp(offset/math.max(1,#(item.Text or '')),0,1)
end
function Upright.offset(item: any,position: any): number
 local gui=item.Gui;local scale=if item.Width>0 and gui.AbsoluteSize.Y>0 then gui.AbsoluteSize.Y/item.Width else 1
 local advance=math.clamp((position.Y-gui.AbsolutePosition.Y)/scale,0,item.Width)
 local count=if item.VerticalCharacters then #item.VerticalCharacters else #(item.Text or '')
 local low,high=0,count
 while low<high do local middle=math.floor((low+high)/2);if Upright.width(item,middle)<advance then low=middle+1 else high=middle end end
 if low>0 and math.abs(advance-Upright.width(item,low-1))<math.abs(Upright.width(item,low)-advance)then return low-1 end
 return low
end
function Upright.rect(item: any,first: number,last: number): any
 local gui=item.Gui;local scale=if item.Width>0 and gui.AbsoluteSize.Y>0 then gui.AbsoluteSize.Y/item.Width else 1
 local cross=math.max(item.TextSize or 0,item.NativeHeight or item.Height);local scaleX=if item.Height>0 then gui.AbsoluteSize.X/item.Height else 1
 local start,finish=Upright.width(item,first)*scale,Upright.width(item,last)*scale
 return {X=gui.AbsolutePosition.X+(item.Height-cross)/2*scaleX,Y=gui.AbsolutePosition.Y+start,Width=cross*scaleX,Height=finish-start}
end
function Upright.paint(self: any,item: any,first: number,last: number,color: any,create: any)
 local gui=item.Gui;local firstAdvance,lastAdvance=Upright.width(item,first),Upright.width(item,last)
 local overlay=self.Overlays[item]
 if overlay and not overlay.Upright then
  if overlay.Text then self.Tree.TextItemsByGui[overlay.Text]=nil end
  for _,glyph in overlay.Glyphs do self.Tree.TextItemsByGui[glyph]=nil end
  self.Tree.TextItemsByGui[overlay.Frame]=nil;overlay.Frame:Destroy();overlay=nil
 end
 if not overlay then
  local frame=create('Frame',gui,{Name='HTMLSelection',ClipsDescendants=true})
  overlay={Frame=frame,Glyphs={},Upright=true};self.Overlays[item]=overlay;self.Tree.TextItemsByGui[frame]=item
 end
 local frame=overlay.Frame;frame.ZIndex=(gui.ZIndex or 1)+(self.ZOffset or 4096)
 local cross=math.max(item.TextSize or 0,item.NativeHeight or item.Height)
 frame.BackgroundColor3,frame.BackgroundTransparency=color.Background,1-color.Alpha
 frame.Position=UDim2.fromOffset((item.Height-cross)/2,firstAdvance);frame.Size=UDim2.fromOffset(cross,lastAdvance-firstAdvance)
 for index,character in item.VerticalCharacters or {}do
  local source=item.UprightPool[index]
  local copy=overlay.Glyphs[index]
  if not copy then copy=create('TextLabel',frame,{Name='SelectedUpright_'..index});overlay.Glyphs[index]=copy;self.Tree.TextItemsByGui[copy]=item end
  local label=source.TextGui;local cell=character.Cell or item.VerticalAdvance
  for _,key in {'Text','FontFace','OpenTypeFeatures','TextSize','TextDirection','TextXAlignment','TextYAlignment','LineHeight'}do copy[key]=label[key]end
  copy.TextColor3=color.Color;copy.ZIndex=frame.ZIndex+1;copy.Visible=index>first and index<=last
  copy.Position=UDim2.fromOffset((cross-cell)/2,character.Advance-firstAdvance);copy.Size=UDim2.fromOffset(cell,cell)
 end
 for index=#(item.VerticalCharacters or {})+1,#overlay.Glyphs do overlay.Glyphs[index].Visible=false end
 overlay.StyleDirty=nil
end
return Upright
