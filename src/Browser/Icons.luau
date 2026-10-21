--!nonstrict
-- Shared image atlas with theme tinting; input remains owned by browser controls.
local IconAssets=require(script.Parent.IconAssets)
local Icons={}
local records=setmetatable({},{__mode='k'})
local aliases={star='bookmark',trash='delete',chevron='down',page='guide',add='plus',cross='close',dots='overflow',info='guide',more='vertical-menu'}
function Icons.SetColor(icon,gui,value)
	local record=records[icon];if not record then return end
	if record.Color==value then return end;local initial=record.Color==nil;record.Color=value
	for _,remove in record.Unbinds do remove() end;table.clear(record.Unbinds)
	for _,paint in record.Paint do
		local previous=paint.Object[paint.Property]
		if type(value)=='string' then
			table.insert(record.Unbinds,gui.Theme:Bind(paint.Object,paint.Property,value))
			if not initial then paint.Object[paint.Property]=previous;gui.Theme:Animate(paint.Object,{[paint.Property]=gui.Theme.Tokens[value]}) end
		elseif initial then paint.Object[paint.Property]=value
		else gui.Theme:Animate(paint.Object,{[paint.Property]=value}) end
	end
end
function Icons.draw(gui,parent,name,size,color)
	size=size or gui.Theme.Tokens.IconSize;name=string.lower(tostring(name or 'guide'));name=aliases[name]or name
	local asset=IconAssets.Resolve(name,gui.IconAtlasImage)
	local root=gui:Make('Frame',parent,{Name='Icon_'..name,Size=UDim2.fromOffset(size,size)})
	local record={Paint={},Unbinds={}};records[root]=record
	local function paint(object,property)table.insert(record.Paint,{Object=object,Property=property})end
	local image
	if asset then
		image=gui:Make('ImageLabel',root,{Name='Artwork',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
			Image=asset.Image,ImageRectOffset=asset.Offset,ImageRectSize=asset.Size,ImageColor3=Color3.new(1,1,1),
			ScaleType=if asset.Tint then Enum.ScaleType.Stretch else Enum.ScaleType.Fit,
			-- Keep pending artwork renderable so Roblox can request the texture.
			ResampleMode=Enum.ResamplerMode.Default,Visible=true})
		if asset.Tint then paint(image,'ImageColor3')end
	end
	root:SetAttribute('IconRenderMode',if image then 'image'else 'empty')
	Icons.SetColor(root,gui,color or 'Text')
	root.Destroying:Connect(function()
		for _,remove in record.Unbinds do remove()end;table.clear(record.Unbinds);table.clear(record.Paint);records[root]=nil
	end)
	return root
end
return Icons
