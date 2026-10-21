--!nonstrict
local Factory=require(script.Parent.Parent.GuiFactory)
local View={}
View.TitleHeight=32
local rgb=Color3.fromRGB
View.Colors={Text=rgb(46,46,48),Chrome=rgb(239,239,241),Inactive=rgb(247,247,248),White=rgb(255,255,255),Border=rgb(193,193,197)}
function View.new(services)
	local create=services.Create or (services.Factory and services.Factory.create)or Factory.create
	local modifier=services.Modifier or (services.Factory and services.Factory.modifier)or Factory.modifier
	local self={}
	function self:Make(class,parent,props)
		props.Active=false;props.Selectable=false;props.BorderSizePixel=0
		if props.BackgroundTransparency==nil then props.BackgroundTransparency=1 end
		return create(class,parent,props)
	end
	function self:Round(object,radius)modifier('UICorner',object,{CornerRadius=UDim.new(0,radius)})end
	function self:Stroke(object,color)modifier('UIStroke',object,{Color=color or View.Colors.Border,Thickness=1})end
	function self:Label(parent,text,props)
		props=props or {};props.Text=text;props.TextSize=props.TextSize or 14;props.TextColor3=props.TextColor3 or View.Colors.Text
		props.TextXAlignment=props.TextXAlignment or Enum.TextXAlignment.Center;props.TextYAlignment=props.TextYAlignment or Enum.TextYAlignment.Center
		return self:Make('TextLabel',parent,props)
	end
	function self:Button(parent,name,text,initialVisible)
		local button=self:Make('Frame',parent,{Name=name,Visible=initialVisible~=false,Size=UDim2.fromOffset(82,28),BackgroundTransparency=0,BackgroundColor3=rgb(234,234,237)})
		self:Round(button,5);self:Stroke(button);self:Label(button,text,{Size=UDim2.fromScale(1,1)})
		return button
	end
	return self
end
function View.Window(gui,parent,title)
	local root=gui:Make('Frame',parent,{Name='HTMLWindow',Visible=false,ClipsDescendants=true,BackgroundTransparency=0,BackgroundColor3=View.Colors.White})
	gui:Round(root,8);gui:Stroke(root)
	local bar=gui:Make('Frame',root,{Name='Titlebar',Size=UDim2.new(1,0,0,View.TitleHeight),BackgroundTransparency=0,BackgroundColor3=View.Colors.Chrome})
	bar:SetAttribute('HTMLInputBlocker',true)
	gui:Make('Frame',bar,{Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1),BackgroundTransparency=0,BackgroundColor3=View.Colors.Border})
	local label=gui:Label(bar,title,{Name='Title',Position=UDim2.fromOffset(88,0),Size=UDim2.new(1,-176,1,0),TextTruncate=Enum.TextTruncate.AtEnd})
	local buttons={}
	for index,name in {'Close','Minimize','Maximize'}do
		local button=gui:Make('Frame',bar,{Name=name,Position=UDim2.fromOffset(12+(index-1)*20,10),Size=UDim2.fromOffset(12,12),BackgroundTransparency=0})
		gui:Round(button,6);buttons[name]=button
		local mark=gui:Make('Frame',button,{Name='Mark',Size=UDim2.fromScale(1,1)})
		local function line(x,y,w,h,rotation)
			gui:Make('Frame',mark,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Rotation=rotation or 0,BackgroundTransparency=0,BackgroundColor3=rgb(75,50,45)})
		end
		if name=='Close'then line(6,6,7,1,45);line(6,6,7,1,-45)
		elseif name=='Minimize'then line(6,6,7,1)
		else line(6,6,7,1);line(6,6,1,7)end
		mark.Visible=false
	end
	local content=gui:Make('Frame',root,{Name='Content',Position=UDim2.fromOffset(0,View.TitleHeight),Size=UDim2.new(1,0,1,-View.TitleHeight),ClipsDescendants=true})
	return {Root=root,Content=content,Titlebar=bar,TitleLabel=label,CloseButton=buttons.Close,MinimizeButton=buttons.Minimize,MaximizeButton=buttons.Maximize}
end
function View.Paint(window,focused,hover,pressed)
	window.Titlebar.BackgroundColor3=if focused then View.Colors.Chrome else View.Colors.Inactive
	window.TitleLabel.TextTransparency=if focused then 0 else .35
	for _,entry in {{window.CloseButton,Color3.fromRGB(255,95,87),'close'},{window.MinimizeButton,Color3.fromRGB(254,188,46),'minimize'},{window.MaximizeButton,Color3.fromRGB(40,200,64),'maximize'}}do
		local button,color,kind=table.unpack(entry)
		button.BackgroundColor3=if pressed==kind then color:Lerp(Color3.new(0,0,0),.2)elseif focused or hover==kind then color else Color3.fromRGB(207,207,211)
		button:FindFirstChild('Mark').Visible=hover==kind
	end
end
function View.Contains(object,point)
	if not object or object.Parent==nil then return false end
	local node=object
	while node do
		if node:IsA('GuiObject')and node.Visible==false then return false end
		if node:IsA('GuiObject')and node.ClipsDescendants then
			local p,s=node.AbsolutePosition,node.AbsoluteSize
			if point.X<p.X or point.Y<p.Y or point.X>=p.X+s.X or point.Y>=p.Y+s.Y then return false end
		end
		if node:IsA('LayerCollector')and node.Enabled==false then return false end
		node=node.Parent
	end
	local p,s=object.AbsolutePosition,object.AbsoluteSize
	return point.X>=p.X and point.Y>=p.Y and point.X<p.X+s.X and point.Y<p.Y+s.Y
end
return View
