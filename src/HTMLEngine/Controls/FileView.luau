--!strict
-- Appearance only. This control never invents access to the player's filesystem.
local File={}
function File.create(item: any,factory: any)
	item.FileButton=factory.create("Frame",item.BoxGui,{Name="ChooseFile",BackgroundTransparency=0,BackgroundColor3=Color3.fromRGB(239,239,239)})
	factory.modifier("UICorner",item.FileButton,{CornerRadius=UDim.new(0,2)})
	factory.modifier("UIStroke",item.FileButton,{Thickness=1,Color=Color3.fromRGB(118,118,118),ApplyStrokeMode=Enum.ApplyStrokeMode.Border,BorderStrokePosition=Enum.BorderStrokePosition.Inner})
	item.FileCaption=factory.create("TextLabel",item.FileButton,{Name="ChooseFileCaption",Text="Datei auswählen",TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center})
	item.FileName=factory.create("TextLabel",item.BoxGui,{Name="FileName",Text="Keine Datei ausgewählt",TextYAlignment=Enum.TextYAlignment.Center})
end
function File.paint(item: any)
	local c,s=item.Control,item.Style;local color=if c.Disabled then Color3.fromRGB(153,153,153) else s.Color
	item.FileCaption.Text=if c.Multiple then "Dateien auswählen" else "Datei auswählen"
	item.FileName.Text=if #(c.Files or {})==0 then (if c.Multiple then "Keine Dateien ausgewählt" else "Keine Datei ausgewählt") else c.FileCaption or ""
	for _,label in {item.FileCaption,item.FileName} do label.FontFace=item.FontFace;label.TextSize=item.TextSize or s.FontSize;label.TextColor3=color end
	item.FileButton.BackgroundColor3=if c.Pressed then Color3.fromRGB(220,220,220) elseif c.Hovered then Color3.fromRGB(229,229,229) else Color3.fromRGB(239,239,239)
end
function File.arrange(item: any,left: number,top: number)
	File.paint(item)
	local width=(item.FileButtonWidth or 100)+12;local height=math.min(item.ContentHeight,(item.TextSize or 14)+6)
	item.FileButton.Position=UDim2.fromOffset(left,top);item.FileButton.Size=UDim2.fromOffset(width,height)
	item.FileCaption.Size=UDim2.fromScale(1,1);item.FileName.Position=UDim2.fromOffset(left+width+5,top);item.FileName.Size=UDim2.fromOffset(math.max(0,item.ContentWidth-width-5),height)
end
return File
