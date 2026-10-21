--!strict
return function(NativeSelectionCopy)
	local signals,objects={},{};local focused;local creates,captures,releases=0,0,0
	local function signal()
		local entries={};local api={};table.insert(signals,api)
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
		function api:Count()local count=0;for _,entry in entries do if entry[1].Connected then count+=1 end end;return count end
		return api
	end
	local factory={}
	function factory.create(class,parent,properties)
		local values={ClassName=class,Parent=parent,Visible=true,Enabled=true};for key,value in properties or{}do values[key]=value end
		local changes,attributes={},{};local gui
		gui=setmetatable({},{__index=function(_,key)
			if key=="Visible"and(class=="ScreenGui"or class=="PlayerGui")then error("Non-GuiObject Visible read")end
			return values[key]
		end,__newindex=function(_,key,value)local old=values[key];values[key]=value;if old~=value and changes[key]then changes[key]:Fire()end end})
		function values:IsA(kind)return kind==class or kind=="GuiObject"and(class=="Frame"or class=="ScrollingFrame"or class=="TextBox")or kind=="LayerCollector"and class=="ScreenGui"end
		function values:GetPropertyChangedSignal(key)changes[key]=changes[key]or signal();return changes[key]end
		function values:SetAttribute(key,value)attributes[key]=value end;function values:GetAttribute(key)return attributes[key]end
		values.Focused,values.FocusLost,values.Destroying=signal(),signal(),signal()
		function values:IsFocused()return focused==gui end
		function values:CaptureFocus()
			captures+=1;if focused==gui then return end
			local previous=focused;focused=gui;if previous then previous.FocusLost:Fire(false)end;self.Focused:Fire()
			-- Native focus establishes its own caret before host selection writes.
			gui.CursorPosition=1;gui.SelectionStart=-1
		end
		function values:ReleaseFocus()if focused~=gui then return end;releases+=1;focused=nil;self.FocusLost:Fire(false)end
		function values:Destroy()if self.Destroyed then return end;self.Destroying:Fire();if focused==gui then self:ReleaseFocus()end;self.Destroyed=true;gui.Parent=nil end
		table.insert(objects,gui);if class=="TextBox"and properties.Name=="HTMLSelectionCopy"then creates+=1 end;return gui
	end
	local players=factory.create("PlayerGui",nil,{})
	local screen=factory.create("ScreenGui",players,{})
	local parent=factory.create("Frame",screen,{})
	local root=factory.create("ScrollingFrame",parent,{})
	local input={WindowFocusReleased=signal(),KeyboardEnabled=true}
	function input:GetFocusedTextBox()return focused end
	local page={Alive=true,Root=root,Presented=true,DocumentVisible=true};local tree={PresentationHidden=false}
	local text;local reads=0;local readError=false;local readFocus
	local proxy=NativeSelectionCopy.new(page,tree,{Factory=factory,Input=input},function()
		reads+=1;if readError then error("Disposed source selection")end
		if readFocus then readFocus:CaptureFocus()end;return text
	end)
	assert(creates==0 and not proxy:Arm()and creates==0,"No selection creates no editor")
	text="A😀 é\nאבג"
	assert(proxy:Arm(),"An explicit desktop selection arms native copying")
	local editor=assert(proxy.Editor)
	assert(focused==editor and proxy:IsEditor(editor)and editor.Text==text and editor.CursorPosition==#text+1 and editor.SelectionStart==1,"Full Unicode selection uses native UTF-8 byte boundaries after focus")
	assert(editor.Parent==root and editor.Active==false and editor.Selectable==false and editor.TextEditable==false and editor.ClearTextOnFocus==false and editor.RichText==false and editor.MultiLine==true and editor.ShowNativeInput==false,"Proxy stays read-only and passive")
	local position=editor.Position
	assert((position.X and position.X.Offset or position[1])==-2 and(position.Y and position.Y.Offset or position[2])==-2 and editor.ClipsDescendants,"Native selection is clipped outside the document viewport without positive canvas extent")
	assert(editor.TextTransparency==1 and editor.BackgroundTransparency==1 and editor:GetAttribute("HTMLPaintOnlyOverlay")==true,"Proxy is invisible and excluded from page hits")
	assert(proxy:Arm()and creates==1 and captures==1,"Repeated arming retains the editor and existing focus")
	text="new\ncontents";assert(proxy:Arm()and editor.Text==text and editor.CursorPosition==#text+1 and creates==1 and captures==1,"Changed selection updates without recreating or recapturing")
	proxy:Invalidate()
	assert(focused==editor and proxy.Armed and proxy:IsEditor(editor)and editor.Text==""and editor.CursorPosition==-1 and editor.SelectionStart==-1 and captures==1,"Invalidation erases stale native text while retaining only the existing focus lease")
	assert(proxy:Arm()and focused==editor and editor.Text==text and captures==1,"Ready source maps refill an invalidated mirror without recapturing focus")
	proxy:Release();assert(focused==nil and editor.Text==""and editor.SelectionStart==-1 and not proxy:IsEditor(editor),"Release erases the retained copy buffer")
	proxy:Release();assert(releases==1,"Repeated release is harmless")
	editor:CaptureFocus()
	assert(focused==nil and not proxy.Armed and editor.Text=="","A dialog's stale focus restoration cannot trap typing inside the released invisible proxy")
	local nativeCapture=editor.CaptureFocus
	editor.CaptureFocus=function()error("Native focus rejected")end
	assert(not proxy:Arm()and focused==nil and not proxy.Armed,"Native capture failure leaves no partial copy lease")
	editor.CaptureFocus=nativeCapture;editor:CaptureFocus()
	assert(focused==nil and not proxy.Armed,"Capture failure resets the arming guard before unsolicited focus restoration")
	assert(proxy:Arm()and focused==editor and editor.Text==text,"Legitimate explicit copy arming still succeeds after rejected focus restoration")
	proxy:Release()
	local other=factory.create("TextBox",parent,{Name="AddressOrInput",Text="keep",CursorPosition=3,SelectionStart=1})
	other:CaptureFocus();local count=captures
	assert(not proxy:Arm()and focused==other and other.Text=="keep"and captures==count,"Address, chat and native editors retain focus and text")
	other:ReleaseFocus();assert(proxy:Arm());other:CaptureFocus()
	assert(focused==other and editor.Text==""and not proxy.Armed,"Native focus loss releases only the proxy")
	proxy:Invalidate();assert(focused==other and not proxy.Armed,"Invalidation cannot reacquire a focus lease lost to another editor")
	other:ReleaseFocus()
	local redirect=editor.Focused:Connect(function()other:CaptureFocus()end)
	assert(not proxy:Arm()and focused==other and not proxy.Armed,"Focus redirected by a native Focused callback remains with its new owner")
	redirect:Disconnect();other:ReleaseFocus()
	readError=true;assert(not proxy:Arm()and focused==nil and editor.Text=="","Selection extraction errors leave page input intact");readError=false
	readFocus=other;assert(not proxy:Arm()and focused==other and other.Text=="keep","Focus gained during extraction is never stolen back");readFocus=nil;other:ReleaseFocus()
	for _,gate in {
		{Object=root,Key="Visible",Off=false,On=true},
		{Object=parent,Key="Visible",Off=false,On=true},
		{Object=screen,Key="Enabled",Off=false,On=true},
	}do
		assert(proxy:Arm());gate.Object[gate.Key]=gate.Off
		assert(focused==nil and editor.Text==""and not proxy:Arm(),"Hidden document ancestry immediately releases native focus")
		gate.Object[gate.Key]=gate.On
	end
	for _,gate in {
		{Object=page,Key="Presented",Off=false,On=true},
		{Object=page,Key="DocumentVisible",Off=false,On=true},
		{Object=tree,Key="PresentationHidden",Off=true,On=false},
		{Object=input,Key="KeyboardEnabled",Off=false,On=true},
	}do
		gate.Object[gate.Key]=gate.Off;count=captures
		assert(not proxy:Arm()and captures==count,"Nonpresented/inactive/mobile pages never capture keyboard focus")
		gate.Object[gate.Key]=gate.On
	end
	assert(proxy:Arm());input.WindowFocusReleased:Fire();assert(focused==nil and editor.Text==""and not proxy.Armed,"OS window focus loss drops the proxy")
	assert(proxy:Arm());root.Parent=nil;assert(focused==nil and not proxy.Armed,"Removed root releases focus")
	root.Parent=parent
	local replacement=factory.create("Frame",screen,{Visible=false})
	assert(proxy:Arm());parent.Parent=replacement;assert(focused==nil,"A reparent into hidden ancestry releases focus")
	parent.Parent=screen
	local visibleReplacement=factory.create("Frame",screen,{})
	assert(proxy:Arm());parent.Parent=visibleReplacement
	assert(focused==editor and proxy.Armed,"A visible reparent retains native focus")
	visibleReplacement.Visible=false;assert(focused==nil and not proxy.Armed,"Visible reparent updates ancestor visibility subscriptions")
	parent.Parent=screen
	text="";assert(not proxy:Arm());text=nil;assert(not proxy:Arm());text=string.rep("x",1048577);assert(not proxy:Arm(),"Oversized copy text is rejected without truncation")
	text="retained";assert(proxy:Arm());editor:Destroy()
	assert(proxy.Alive and not proxy.Armed and proxy.Editor==nil and focused==nil,"Externally removing the native surface drops its focus and listeners")
	assert(proxy:Arm()and proxy.Editor~=editor,"The next explicit selection can recreate an externally removed surface")
	editor=proxy.Editor;proxy:Destroy();proxy:Destroy()
	assert(not proxy.Alive and editor.Destroyed and focused==nil and not proxy:Arm(),"Disposal is idempotent and a dead bridge never rearms")
	for _,s in signals do assert(s:Count()==0,"Copy bridge retained a connection after disposal")end
	local second=NativeSelectionCopy.new(page,tree,{Factory=factory,Input=input},function()return "ready"end)
	assert(second:Arm());local secondEditor=second.Editor;root:Destroy()
	assert(not second.Alive and secondEditor.Destroyed and focused==nil,"Destroying the root disposes native copy resources")
	for _,s in signals do assert(s:Count()==0,"Root destruction retained a native-copy callback")end
	print("Native selection copy: passive read-only UTF-8 selection, focus isolation, visibility gates and lifecycle passed; no OS clipboard claim")
end
