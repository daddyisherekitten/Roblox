--!nonstrict
-- All native Wayline UI passes through this factory, including icon artwork.
local Gui={}
function Gui.new(theme,services)
	services=services or {}
	local self={Theme=theme,OnCreate=services.OnCreate,IconAtlasImage=services.IconAtlasImage}
	function self:Make(class,parent,props,bindings)
		local object=if services.Create then services.Create(class,nil) else Instance.new(class)
		if object:IsA('GuiObject') then
			object.BorderSizePixel=0;object.BackgroundTransparency=1;object.Active=false;object.Selectable=false
			if parent and parent:IsA('GuiObject') then object.ZIndex=parent.ZIndex end
		end
		if object:IsA('TextLabel') or object:IsA('TextBox') or object:IsA('TextButton') then
			object.AutoLocalize=false;object.Font=theme.Tokens.Font;object.TextSize=theme.Tokens.TextBody
			object.TextColor3=theme.Tokens.Text;object.Text='';object.TextWrapped=false
			object.TextXAlignment=Enum.TextXAlignment.Left;object.TextYAlignment=Enum.TextYAlignment.Center
		end
		for key,value in props or {} do if key~='Active' and key~='Selectable' then object[key]=value end end
		if object:IsA('GuiObject') then object.Active=false;object.Selectable=false end
		if bindings then for property,key in bindings do theme:Bind(object,property,key) end end
		if self.OnCreate then self.OnCreate(object) end
		object.Parent=parent
		return object
	end
	function self:Corner(parent,radius)return self:Make('UICorner',parent,{CornerRadius=UDim.new(0,radius or theme.Tokens.Radius8)})end
	function self:Stroke(parent,token,thickness)
		return self:Make('UIStroke',parent,{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=thickness or theme.Tokens.BorderWidth},{Color=token or 'Border'})
	end
	function self:Text(parent,props,bindings)return self:Make('TextLabel',parent,props,bindings or {TextColor3='Text'})end
	return self
end
return Gui
