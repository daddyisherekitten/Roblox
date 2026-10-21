--!strict
local Edit=require(script.Parent.TemporalEdit)
local View={}
function View.create(item: any,factory: any)
	item.TemporalLabels={}
	item.TemporalIcon=factory.create("Frame",item.BoxGui,{Name="PickerIndicator",Size=UDim2.fromOffset(16,16)})
	local icon=item.TemporalIcon;local color=Color3.fromRGB(35,35,35)
	if item.Control.Type=="time" then
		local ring=factory.create("Frame",icon,{Name="Clock",Position=UDim2.fromOffset(1,1),Size=UDim2.fromOffset(13,13)})
		factory.modifier("UICorner",ring,{CornerRadius=UDim.new(.5,0)})
		factory.modifier("UIStroke",ring,{Thickness=1.3,Color=color,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
		factory.create("Frame",icon,{Name="Hour",Position=UDim2.fromOffset(7,4),Size=UDim2.fromOffset(1,4),BackgroundTransparency=0,BackgroundColor3=color})
		factory.create("Frame",icon,{Name="Minute",Position=UDim2.fromOffset(7,7),Size=UDim2.fromOffset(4,1),BackgroundTransparency=0,BackgroundColor3=color})
	else
		local calendar=factory.create("Frame",icon,{Name="Calendar",Position=UDim2.fromOffset(2,3),Size=UDim2.fromOffset(12,11)})
		factory.modifier("UICorner",calendar,{CornerRadius=UDim.new(0,1)})
		factory.modifier("UIStroke",calendar,{Thickness=1.3,Color=color,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
		factory.create("Frame",calendar,{Name="Header",Position=UDim2.fromOffset(0,2),Size=UDim2.fromOffset(12,2),BackgroundTransparency=0,BackgroundColor3=color})
		for _,x in {3,9} do factory.create("Frame",icon,{Name="Binding",Position=UDim2.fromOffset(x,1),Size=UDim2.fromOffset(1,4),BackgroundTransparency=0,BackgroundColor3=color}) end
		for _,p in {{3,6},{6,6},{3,9},{6,9}} do factory.create("Frame",calendar,{Name="Day",Position=UDim2.fromOffset(p[1],p[2]),Size=UDim2.fromOffset(2,1),BackgroundTransparency=0,BackgroundColor3=color}) end
	end
	item.TemporalFactory=factory
end
function View.paint(item: any)
	local c,s=item.Control,item.Style;local fields=Edit.fields(c);local parts=Edit.parts(c);local labels=item.TemporalLabels
	local x=0;local size=item.TextSize or s.FontSize
	for index,field in fields do
		local entry=labels[index]
		if not entry then
			entry={}
			entry.Prefix=item.TemporalFactory.create("TextLabel",item.BoxGui,{Name="DateSeparator",TextYAlignment=Enum.TextYAlignment.Center})
			entry.Label=item.TemporalFactory.create("TextLabel",item.BoxGui,{Name="DateSegment_"..field.Key,TextYAlignment=Enum.TextYAlignment.Center})
			entry.Suffix=item.TemporalFactory.create("TextLabel",item.BoxGui,{Name="DateSeparator",TextYAlignment=Enum.TextYAlignment.Center})
			labels[index]=entry
		end
		local value=parts[field.Key];local caption=if value~=nil then string.format("%0"..field.Digits.."d",value) else field.Placeholder
		if c.Type=="month" and field.Key=="month" and value and Edit.Months[value] then caption=Edit.Months[value] end
		for _,pair in {{entry.Prefix,field.Prefix or ""},{entry.Label,caption},{entry.Suffix,field.Suffix or ""}} do
			local gui,text=pair[1],pair[2];local width=#text*size*.56
			local cache=entry[if gui==entry.Label then "ValueMetrics" elseif gui==entry.Prefix then "PrefixMetrics" else "SuffixMetrics"]
			if cache and cache.Text==text and cache.Face==item.FontFace and cache.Size==size then width=cache.Width
			elseif item.MeasureText and text~="" then
				local measured=item.MeasureText(text,item.FontFace,size,0);if measured then width=measured.X end
				entry[if gui==entry.Label then "ValueMetrics" elseif gui==entry.Prefix then "PrefixMetrics" else "SuffixMetrics"]={Text=text,Face=item.FontFace,Size=size,Width=width}
			end
			gui.Text=text;gui.FontFace=item.FontFace;gui.TextSize=size;gui.TextColor3=if c.Disabled then Color3.fromRGB(153,153,153) else s.Color
			gui.Position=UDim2.fromOffset((item.TemporalLeft or 3)+x,item.TemporalTop or 1);gui.Size=UDim2.fromOffset(width,item.TemporalHeight or size+2)
			gui.Visible=s.Visibility~="hidden";gui.BackgroundColor3=Color3.fromRGB(0,117,255)
			local selected=gui==entry.Label and c.Focused and (c.TemporalSegment or 1)==index and not c.ReadOnly
			gui.BackgroundTransparency=if selected then 0 else 1;if selected then gui.TextColor3=Color3.new(1,1,1) end
			if gui==entry.Label then entry.Left,entry.Right=x,x+width end
			x+=width
		end
	end
	for index=#fields+1,#labels do for _,gui in {labels[index].Prefix,labels[index].Label,labels[index].Suffix} do gui.Visible=false end end
	item.TemporalIcon.Visible=not c.Disabled and not c.ReadOnly and s.Appearance~="none" and s.Visibility~="hidden"
end
function View.arrange(item: any,left: number,top: number,height: number)
	item.TemporalLeft,item.TemporalTop,item.TemporalHeight=left,top,height
	item.TemporalIcon.Position=UDim2.fromOffset(math.max(left,(item.BoxWidth or 0)-21),math.max(0,((item.BoxHeight or 0)-16)/2))
	View.paint(item)
end
return View
