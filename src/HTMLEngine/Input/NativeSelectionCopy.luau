--!strict
-- A read-only native selection supplies Roblox's ordinary Ctrl/Cmd+C handling.
-- This module never accesses the OS clipboard or synthesizes keyboard input.
local NativeSelectionCopy={}
local MAX_TEXT_BYTES=1048576

function NativeSelectionCopy.new(page: any,tree: any,services: any?,getText: () -> string?): any
	local input=if services and services.Input then services.Input else game:GetService("UserInputService")
	local factory=services and services.Factory
	local api={Alive=true,Editor=nil,Armed=false,Invalidated=false}
	local connections,surfaceConnections,editorConnections={},{},{}
	local releasing,arming=false,false
	local function connect(list,signal,callback)
		if signal then table.insert(list,signal:Connect(callback))end
	end
	local function disconnect(list)
		for _,connection in list do connection:Disconnect()end;table.clear(list)
	end
	local function visible()
		if not api.Alive or not page.Alive or page.Presented~=true or page.DocumentVisible==false
			or tree.PresentationHidden==true or tree.Alive==false or input.KeyboardEnabled==false then return false end
		local root=page.Root
		if not root or not root.Parent then return false end
		local current=root
		while current do
			if current:IsA("GuiObject")and current.Visible==false
				or current:IsA("LayerCollector")and current.Enabled==false then return false end
			current=current.Parent
		end
		return true
	end
	function api:Release()
		if releasing then return end;releasing=true;self.Armed=false;self.Invalidated=false
		disconnect(surfaceConnections)
		local editor=self.Editor
		if editor then
			-- Do not release whichever other editor the player has just focused.
			pcall(function()if editor:IsFocused()then editor:ReleaseFocus(false)end end)
			pcall(function()editor.Text="";editor.CursorPosition=-1;editor.SelectionStart=-1 end)
		end
		releasing=false
	end
	function api:Invalidate()
		local editor=self.Editor
		if not self.Alive or not self.Armed or not editor or not editor:IsFocused()then self:Release();return end
		-- DOM reconciliation can yield before its rendered source map is ready.
		-- Keep only our existing focus lease, never its now-stale native text.
		local ok=pcall(function()editor.Text="";editor.CursorPosition=-1;editor.SelectionStart=-1 end)
		self.Invalidated=true
		if not ok then self:Release()end
	end
	local watchSurface
	watchSurface=function()
		disconnect(surfaceConnections)
		local function changed()
			if not api.Armed then return end
			if not visible()then api:Release()end
		end
		local function ancestryChanged()
			if not api.Armed then return end
			if not visible()then api:Release()else watchSurface()end
		end
		local current=page.Root
		while current do
			if current:IsA("GuiObject")then connect(surfaceConnections,current:GetPropertyChangedSignal("Visible"),changed)
			elseif current:IsA("LayerCollector")then connect(surfaceConnections,current:GetPropertyChangedSignal("Enabled"),changed)end
			connect(surfaceConnections,current:GetPropertyChangedSignal("Parent"),ancestryChanged)
			current=current.Parent
		end
	end
	local function ensure()
		if api.Editor then return api.Editor end
		factory=factory or require(script.Parent.Parent.Rendering.GuiFactory)
		local editor=factory.create("TextBox",page.Root,{Name="HTMLSelectionCopy",Active=false,Selectable=false,
			Text="",TextEditable=false,ClearTextOnFocus=false,RichText=false,MultiLine=true,TextWrapped=false,
			TextTransparency=1,TextStrokeTransparency=1,BackgroundTransparency=1,ShowNativeInput=false,
			TextSize=1,ClipsDescendants=true,Position=UDim2.fromOffset(-2,-2),Size=UDim2.fromOffset(1,1),ZIndex=0})
		editor:SetAttribute("HTMLPaintOnlyOverlay",true)
		api.Editor=editor
		connect(editorConnections,editor.Focused,function()
			-- Dialogs can retain a prior native editor after our copy buffer was
			-- released. Refuse an unsolicited restore into an empty hidden field.
			if not arming and not api.Armed then api:Release()end
		end)
		connect(editorConnections,editor.FocusLost,function()api:Release()end)
		connect(editorConnections,editor.Destroying,function()
			api.Editor=nil;api.Armed=false;disconnect(surfaceConnections);disconnect(editorConnections)
		end)
		return editor
	end
	function api:Arm(): boolean
		if not visible()then self:Release();return false end
		local focused=input:GetFocusedTextBox()
		if focused and focused~=self.Editor then self:Release();return false end
		local read,text=pcall(getText)
		if not read or type(text)~="string"or #text==0 or #text>MAX_TEXT_BYTES then self:Release();return false end
		-- Extraction may have run script callbacks. Check eligibility once more.
		focused=input:GetFocusedTextBox()
		if not visible()or focused and focused~=self.Editor then self:Release();return false end
		local ok,armed=pcall(function()
			local editor=ensure()
			if editor.Text~=text then editor.Text=text end
			if not editor:IsFocused()then arming=true;editor:CaptureFocus()end
			if not editor:IsFocused()then return false end
			-- Roblox CursorPosition/SelectionStart use UTF-8 byte positions.
			editor.CursorPosition=#text+1;editor.SelectionStart=1
			self.Armed=true;self.Invalidated=false;watchSurface();return true
		end)
		arming=false
		if not ok or not armed then self:Release();return false end
		return true
	end
	function api:IsEditor(editor: any): boolean return self.Alive and self.Armed and editor~=nil and editor==self.Editor end
	function api:Destroy()
		if not self.Alive then return end
		self:Release();self.Alive=false;disconnect(connections);disconnect(editorConnections)
		local editor=self.Editor;self.Editor=nil;if editor then editor:Destroy()end
	end
	connect(connections,input.WindowFocusReleased,function()api:Release()end)
	connect(connections,page.Root and page.Root.Destroying,function()api:Destroy()end)
	return api
end

return NativeSelectionCopy
