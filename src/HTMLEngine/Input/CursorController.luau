--!strict
local HitTest=require(script.Parent.HitTest)
local Lease=require(script.Parent.CursorLease)
local Cursor=require(script.Parent.Parent.CSS.Cursor)
local Textarea=require(script.Parent.Parent.Controls.TextareaView)
local NumberView=require(script.Parent.Parent.Controls.NumberView)
local ImageMap=require(script.Parent.ImageMap)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local Controller={}

function Controller.start(page: any,tree: any,input: any,playerGui: any): any
	local lease=Lease.new(input)
	local connections,controls={},{ }
	for _,c in tree.Controls or {} do controls[c.Node]=c end
	local alive,mouse,position,drag=true,input.MouseEnabled ~= false,nil,nil
	local self={}
	local function connect(signal: any,fn: any) if signal then table.insert(connections,signal:Connect(fn)) end end
	local function resizeKind(c: any): string
		local mode=(c.LayoutStyle or c.Item.Style).Resize
		return if mode == "horizontal" then "ew-resize" elseif mode == "vertical" then "ns-resize" else "nwse-resize"
	end
	function self:Refresh(at: any?)
		if not alive then return end
		if at then position=at elseif input.GetMouseLocation then position=input:GetMouseLocation();if tree.MousePosition then position=tree.MousePosition(position) end end
		if not page.Alive or not mouse or not position then lease:Set(nil); return end
		if drag then lease:Set(drag); return end
		local objects=playerGui:GetGuiObjectsAtPosition(position.X,position.Y)
		local popup=if self.Popup then self.Popup(objects,position) else nil
		if popup then if tree.SVGCursor then tree.SVGCursor(nil,position) end;lease:Set(Cursor.resolve(popup.Item.Style.Cursor,"default")); return end
		local node,gui=HitTest.pick(objects,tree.HitNodes,page.Root,position,tree.HitStyles)
		local image=node
		node=ImageMap.hit(tree.ImageMapItems,node,position)
		if node~=image and ElementNames.html(node,'area')and tree.ImageMapCursor then
			lease:Set(Cursor.resolve(tree:ImageMapCursor(node,image),if node.Attributes.href~=nil then'pointer'else'default'));return
		end
		local svgCursor=if tree.SVGCursor then tree.SVGCursor(node,position) else nil
		if not node then
			local htmlSurface=false
			for _,object in objects do
				if object.GetAttribute and object:GetAttribute("HTMLCursorSurface") then htmlSurface=true;break end
			end
			lease:Set(if htmlSurface then "default" else nil)
			return
		end
  if svgCursor then lease:Set(Cursor.resolve(Cursor.parse(svgCursor),"default"));return end
		local automatic="default"
		local c=controls[node]
		local ancestor=node
		while ancestor and not c do c=controls[ancestor]; ancestor=ancestor.Parent end
		if c then
			if node == c.Node and Textarea.hit(c,position) then lease:Set(resizeKind(c)); return end
			if c.Item.Editor and not c.Disabled and not (c.Type == "number" and NumberView.direction(c,position)) then automatic="text" end
		else
			local style=tree.NodeStyles and tree.NodeStyles[node]
			if gui and gui:IsA("TextLabel") and (not style or style.UserSelect~="none") then automatic="text" end
			ancestor=node
			while ancestor do
				if (ancestor.Name == "a" or ancestor.Name == "area") and ancestor.Attributes.href ~= nil then automatic="pointer"; break end
				ancestor=ancestor.Parent
			end
		end
		local style=(tree.NodeStyles or {})[node] or (if c then c.Item.Style else nil)
		-- Inert image hit processing can retarget to a non-inert ancestor.
		-- Its own cursor must not be overwritten by the rejected image GUI.
		local visual=if node==image then gui else nil
		while visual do
			if tree.HitStyles and tree.HitStyles[visual] then style=tree.HitStyles[visual]; break end
			if visual == page.Root then break end
			visual=visual.Parent
		end
		if not c and style and style.AutoCursor then automatic=style.AutoCursor end
		lease:Set(Cursor.resolve(if style then style.Cursor else nil,automatic))
	end
	function self:Capture(c: any,event: any)
		if event.UserInputType == Enum.UserInputType.MouseButton1 then drag=resizeKind(c); self:Refresh(event.Position) end
	end
	function self:Release() drag=nil; self:Refresh() end
	function self:Destroy()
		if not alive then return end
		alive=false
		for _,connection in connections do connection:Disconnect() end
		lease:Destroy()
	end
	connect(input.InputChanged,function(event)
		if event.UserInputType == Enum.UserInputType.MouseMovement then mouse=true; self:Refresh(event.Position) end
	end)
	connect(input.InputBegan,function(event)
		if event.UserInputType == Enum.UserInputType.Touch then mouse=false; drag=nil; lease:Set(nil) end
		if event.UserInputType == Enum.UserInputType.MouseButton1 then mouse=true; self:Refresh(event.Position) end
	end)
	connect(input.WindowFocusReleased,function() mouse=false; drag=nil; lease:Set(nil) end)
	connect(input.WindowFocused,function() mouse=input.MouseEnabled ~= false; self:Refresh() end)
	local function watch(gui: any)
		if not gui or not gui.GetPropertyChangedSignal then return end
		for _,key in {"AbsolutePosition","AbsoluteSize","Visible"} do connect(gui:GetPropertyChangedSignal(key),function() self:Refresh() end) end
		if gui:IsA("ScrollingFrame") then connect(gui:GetPropertyChangedSignal("CanvasPosition"),function() self:Refresh() end) end
	end
	watch(page.Root)
	local ancestor=page.Root.Parent
	while ancestor do
		if ancestor.GetPropertyChangedSignal then
			if ancestor:IsA("LayerCollector") then connect(ancestor:GetPropertyChangedSignal("Enabled"),function() self:Refresh() end)
			elseif ancestor:IsA("GuiObject") then connect(ancestor:GetPropertyChangedSignal("Visible"),function() self:Refresh() end) end
		end
		ancestor=ancestor.Parent
	end
	local function visit(box: any)
		if box.ScrollGui then watch(box.ScrollGui) end
		for _,child in box.AllChildren or box.Children or {} do visit(child) end
	end
	visit(tree)
	if page.Root.GetAttributeChangedSignal then
		connect(page.Root:GetAttributeChangedSignal("Status"),function() if page.Root:GetAttribute("Status") == "ready" then self:Refresh() end end)
	end
	page:AddCleanup(function() self:Destroy() end)
	self:Refresh()
	return self
end
return Controller
