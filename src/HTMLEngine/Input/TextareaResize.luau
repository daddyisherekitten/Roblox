--!strict
local View=require(script.Parent.Parent.Controls.TextareaView)
local Geometry=require(script.Parent.Parent.Layout.BorderGeometry)
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local Resize={}
function Resize.new(alive: any,changed: any,styleChanged: any?): any
	local active,pointer,start,width,height,scaleX,scaleY
	local resized=false
	local resize={}
	local function matches(event: any): boolean
		return event == pointer or (pointer and pointer.UserInputType == Enum.UserInputType.MouseButton1 and event.UserInputType == Enum.UserInputType.MouseButton1)
	end
	local function update(position: any)
		if not active or not alive() then return end
		if not resized and position.X == start.X and position.Y == start.Y then return end
		local item=active.Item
		local s=active.LayoutStyle or item.Style
		local top,right,bottom,left=Geometry.sizes(item.Style)
		local horizontal=left+right+s.Padding[2]+s.Padding[4]
		local vertical=top+bottom+s.Padding[1]+s.Padding[3]
		local dimensions={}
		for _,axis in {{"Width",width+(position.X-start.X)*scaleX,horizontal,s.Resize ~= "vertical"},
			{"Height",height+(position.Y-start.Y)*scaleY,vertical,s.Resize ~= "horizontal"}} do
			if not axis[4] or s.Resize == "none" then continue end
			local value=math.clamp(math.round(axis[2]),axis[3]+12,100000)
			if s.BoxSizing ~= "border-box" then value-=axis[3] end
			local old=s[axis[1]]
			if not old or old.Percent or old.Value ~= value then
				s[axis[1]]={Value=value,Percent=false,UsesViewport=false};dimensions[string.lower(axis[1])]=value
			end
		end
		if next(dimensions) then
			-- Native browser resizing writes inline dimensions. Persist them in
			-- the DOM so subsequent focus/style cascades cannot restore old sizes.
			local declarations={}
			for _,entry in Syntax.declarations(active.Node.Attributes.style or "") do
				local name=entry.Text:match("^%s*([%w%-]+)%s*:")
				if not name or dimensions[string.lower(name)]==nil then
					table.insert(declarations,entry.Text..(if entry.Important then " !important" else ""))
				end
			end
			for _,name in {"width","height"} do
				if dimensions[name]~=nil then table.insert(declarations,name..":"..tostring(dimensions[name]).."px") end
			end
			local css=table.concat(declarations,";")
			if styleChanged then styleChanged(active.Node,css) else active.Node.Attributes.style=css end
			resized=true;changed(item)
		end
	end
	function resize:Begin(c: any,event: any): boolean
		if active then return true end
		if not alive() or not View.hit(c,event.Position) then return false end
		active,pointer,start=c,event,event.Position
		resized=false
		width,height=c.Item.BoxWidth,c.Item.BoxHeight
		scaleX,scaleY=width/c.Item.BoxGui.AbsoluteSize.X,height/c.Item.BoxGui.AbsoluteSize.Y
		return true
	end
	function resize:Move(event: any): boolean
		if not active then return false end
		if event == pointer or (pointer.UserInputType == Enum.UserInputType.MouseButton1 and event.UserInputType == Enum.UserInputType.MouseMovement) then update(event.Position) end
		return true
	end
	function resize:Finish(event: any): boolean
		if not active then return false end
		if matches(event) then update(event.Position); self:Cancel() end
		return true
	end
	function resize:Cancel() active,pointer,start=nil,nil,nil end
	function resize:IsActive(): boolean return active ~= nil end
	return resize
end
return Resize
