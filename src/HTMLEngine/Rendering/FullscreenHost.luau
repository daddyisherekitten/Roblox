--!strict
-- Optional native fullscreen presentation; no Browser/WindowManager import.
local BoxTransform=require(script.Parent.BoxTransform)
local TopLayerLayout=require(script.Parent.TopLayerLayout)
local Fullscreen={}
function Fullscreen.new(page,tree,factory,windowHost,allowed)
	local self={Allowed=allowed~=false,Node=nil,Layer=nil,Connections={}}
	local function dirty(node)
		TopLayerLayout.syncState(tree,'fullscreen',if node then {[node]=true}else {})
		if page.TopLayerChanged then page:TopLayerChanged('fullscreen',node)end
	end
	function self:Enter(node)
		if not page.Alive then return false end
		self.Node=node
		local target=page.Root.Parent;self.Target=target;self.TargetState={Parent=target.Parent,Position=target.Position,Size=target.Size}
		self.Scrollbar=page.Root.ScrollBarThickness;self.Scroll=page.Root.CanvasPosition;page.Root.ScrollBarThickness=0
		if windowHost and windowHost.SetFullscreen then windowHost.SetFullscreen(true)
		else
			local screen=target.Parent;while screen and not screen:IsA('LayerCollector')do screen=screen.Parent end
			if screen then target.Parent=screen;target.Position=UDim2.fromOffset(0,0);target.Size=UDim2.new(1,0,1,0);self.Standalone=true end
		end
		dirty(node)
		if page.FlushScriptLayout then page:FlushScriptLayout()end
		local box=tree.NodeBoxes[node];if not box then return false end
		self.Box=box;self.Surface=BoxTransform.target(box);self.Home=self.Surface.Parent
		self.Layer=factory.create('Frame',target,{Name='HTMLFullscreen',Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0,BorderSizePixel=0,Active=false,Selectable=false,ZIndex=2000})
		self.Layer:SetAttribute('HTMLPageOverlay',true);self.Layer:SetAttribute('HTMLInputBlocker',true)
		self.Surface.Parent=self.Layer;TopLayerLayout.flags(tree,box,true,true,false)
		box.TopLayerPaintX,box.TopLayerPaintY=0,0;self.Surface.Position=UDim2.fromOffset(0,0)
		self.Surface.Visible=true;dirty(node)
		return true
	end
	function self:Refresh()
		if not self.Node or not self.Layer then return end
		local box=tree.NodeBoxes[self.Node];if not box then return end
		if box~=self.Box then self.Box=box;self.Surface=BoxTransform.target(box);self.Home=self.Surface.Parent;self.Surface.Parent=self.Layer end
		TopLayerLayout.flags(tree,box,true,true,false);self.Surface.Position=UDim2.fromOffset(0,0)
	end
	function self:Exit()
		local node=self.Node;self.Node=nil
		if self.Surface and self.Surface.Parent and self.Home and self.Home.Parent then self.Surface.Parent=self.Home end
		if self.Box then TopLayerLayout.flags(tree,self.Box,false,false,false);self.Box.TopLayerPaintX,self.Box.TopLayerPaintY=nil,nil end
		if self.Layer then self.Layer:Destroy();self.Layer=nil end
		self.Box,self.Surface,self.Home=nil,nil,nil
		if self.Target and self.Target.Parent then
			if self.Standalone then self.Target.Parent=self.TargetState.Parent;self.Target.Position=self.TargetState.Position;self.Target.Size=self.TargetState.Size end
			if windowHost and windowHost.SetFullscreen then windowHost.SetFullscreen(false)end
		end
		self.Standalone=nil;self.Target,self.TargetState=nil,nil
		if self.Scrollbar~=nil and page.Alive then page.Root.ScrollBarThickness=self.Scrollbar;page.Root.CanvasPosition=self.Scroll;self.Scrollbar=nil end
		if node and page.Alive then dirty(nil)end
	end
	function self:SubscribeExit(callback)
		if windowHost and windowHost.SubscribeFullscreenExit then table.insert(self.Connections,windowHost.SubscribeFullscreenExit(callback))end
	end
	function self:Destroy()
		for _,connection in self.Connections do connection:Disconnect()end;table.clear(self.Connections)
		self:Exit()
	end
	page.FullscreenPresentation=self
	return self
end
return Fullscreen
