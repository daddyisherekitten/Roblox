--!strict
return function(Parser,DOM,State,Gauge,View,Controller,loadRenderTree,loadWordLayout,loadBlockLayout)
	local function state(tag,attributes)
		return State.create(DOM.findById(Parser.parse('<'..tag..' id="g" '..attributes..'>Fallback</'..tag..'>'),'g'))
	end
	local p=state('progress','max="100"')
	assert(p.Value == '0' and p.Gauge.Indeterminate and p.Gauge.Max == 100)
	assert(Gauge.assign(p,0) and not p.Gauge.Indeterminate,'Setting zero must exit indeterminate state')
	assert(not Gauge.assign(p,0),'Unchanged values do not trigger paint')
	for _,case in {{'value="bad" max="bad"','0',1},{'value="2" max="0"','1',1},{'value="-1" max="10"','0',10},{'value="20" max="10"','10',10}} do
		local c=state('progress',case[1]); assert(c.Value == case[2] and c.Gauge.Max == case[3] and not c.Gauge.Indeterminate)
	end
	local m=state('meter','min="10" max="5" low="-1" high="20" optimum="99"')
	assert(m.Value == '10' and m.Gauge.Max == 10 and m.Gauge.Low == 10 and m.Gauge.High == 10 and m.Gauge.Optimum == 10 and m.Gauge.Ratio == 0)
	m=state('meter','min="-10" max="10" low="-5" high="5" optimum="0" value="0"')
	assert(m.Gauge.Ratio == .5 and m.Gauge.Quality == 'optimum')
	Gauge.assign(m,-6); assert(m.Gauge.Quality == 'suboptimal')
	Gauge.assign(m,6); assert(m.Gauge.Quality == 'suboptimal')
	for _,case in {{20,40,'optimum'},{20,41,'suboptimal'},{20,80,'suboptimal'},{20,81,'critical'},
		{90,80,'optimum'},{90,79,'suboptimal'},{90,40,'suboptimal'},{90,39,'critical'},
		{40,40,'optimum'},{80,80,'optimum'}} do
		m=state('meter','min="0" max="100" low="40" high="80" optimum="'..case[1]..'" value="'..case[2]..'"')
		assert(m.Gauge.Quality == case[3])
	end
	assert(state('meter','min="-1e308" max="1e308" value="0"').Gauge.Ratio == .5)
	assert(state('progress','max="5e-324" value="5e-324"').Gauge.Ratio == 1)
	local function signal()
		local callbacks={}; local s={}
		function s:Connect(fn)
			local c={Connected=true}; function c:Disconnect() self.Connected=false end
			table.insert(callbacks,{fn,c}); return c
		end
		function s:Fire(...) for _,e in table.clone(callbacks) do if e[2].Connected then e[1](...) end end end
		return s
	end
	local allocations=0
	local factory={}
	function factory.create(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton' and class ~= 'TextBox')
		allocations+=1
		local gui=table.clone(props); gui.Parent=parent; gui.Visible=true
		gui.AbsolutePosition=Vector2.new(0,0); gui.AbsoluteSize=Vector2.new(400,300)
		function gui:IsA(kind) return kind == class or kind == 'GuiObject' end
		function gui:Destroy() self.Destroyed=true end
		return gui
	end
	factory.modifier=function(_,_,props) return table.clone(props) end
	local doc=Parser.parse('<form id="f"><button id="a">A</button><progress id="p" name="ignored" form="f" disabled required value="60" max="100">Fallback</progress><meter id="m" name="ignored" min="0" max="100" low="40" high="80" optimum="20" value="70">Fallback</meter><progress id="u"></progress><button id="b">B</button></form>')
	local root=factory.create('ScrollingFrame',nil,{})
	local tree=loadRenderTree(factory).build(doc,root,error,function(font) return font end)
	local byId={}; for _,c in tree.Controls do byId[c.Node.Attributes.id]=c end
	local overrides={["Layout/TextMeasure"]={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	blocks.arrange(tree,400,0,0,function() return true end)
	p,m=byId.p,byId.m
	assert(p.DisplayOnly and not p.Disabled and not p.Required and not p.Form)
	assert(not p.Item.Label and not p.Item.Editor and not m.Item.Label and p.Item.GaugeFill.Size.XScale == .6)
	assert(p.Item.IntrinsicWidth == p.Item.Style.FontSize*10 and m.Item.IntrinsicWidth == m.Item.Style.FontSize*5)
	assert(m.Item.GaugeFill.BackgroundColor3 == Color3.fromRGB(255,185,0))
	local snapshot=table.clone(byId.u.Item); snapshot.PaintOwner=byId.u.Item
	local tweens={}
	local tweenService={}
	function tweenService:Create(target,info,goal)
		assert(info[4] == -1 and info[5] and goal.Position.XScale == .7)
		local tween={Target=target}
		function tween:Play() self.Playing=true end
		function tween:Cancel() self.Cancelled=true end
		function tween:Destroy() self.Destroyed=true end
		table.insert(tweens,tween); return tween
	end
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox() return nil end
	function input:IsKeyDown() return false end
	local hits={}
	local page={Document=doc,Root=root,Alive=true}
	function page:AddCleanup(fn) self.Cleanup=fn end
	local cleanup=Controller.start(page,tree,function() error('Gauge values must not request layout') end,error,
		{Input=input,PlayerGui={GetGuiObjectsAtPosition=function() return hits end},TweenService=tweenService})
	assert(#tweens == 1 and tweens[1].Playing)
	byId.u.Item.GaugeFill.Position=UDim2.new(.4,0,0,0)
	View.paint(snapshot)
	assert(byId.u.Item.GaugeFill.Position.XScale == .4 and #tweens == 1,'Cached paint snapshots preserve the live animation')
	local events=0
	page:On('input',function() events+=1 end); page:On('change',function() events+=1 end)
	local count=allocations
	page:SetValue('p',25); assert(page:GetValue('p') == '25' and p.Item.GaugeFill.Size.XScale == .25)
	page:SetValue('m',90); assert(m.Item.GaugeFill.BackgroundColor3 == Color3.fromRGB(216,48,48))
	page:SetValue('m',20); assert(m.Item.GaugeFill.BackgroundColor3 == Color3.fromRGB(16,142,38))
	page:Reset('f'); assert(p.Value == '25' and m.Value == '20' and #page:GetFormData('f') == 0)
	assert(allocations == count and events == 0)
	page:Focus('a'); page:Focus('p'); assert(byId.a.Focused and not p.Focused)
	input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Tab},false)
	assert(byId.b.Focused,'Tab skips passive gauges')
	hits={p.Item.GaugeTrack}
	local click={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(10,10)}
	input.InputBegan:Fire(click,false); input.InputEnded:Fire(click,false)
	assert(p.Value == '25' and not p.Pressed and not p.Focused)
	local beforeResize=allocations -- Focus may have allocated a separate UA outline.
	blocks.arrange(tree,250,0,0,function() return true end)
	assert(#tweens == 1 and allocations == beforeResize,'Resize reuses GUI and running tween')
	page:SetValue('u',0); assert(tweens[1].Cancelled and tweens[1].Destroyed and not byId.u.Gauge.Indeterminate)
	page:SetValue('u',nil); assert(#tweens == 2 and byId.u.Gauge.Indeterminate)
	byId.u.Item.Style.Visibility='hidden'; View.paint(byId.u.Item); assert(tweens[2].Destroyed)
	byId.u.Item.Style.Visibility='visible'; View.paint(byId.u.Item); assert(#tweens == 3)
	cleanup(); assert(tweens[3].Cancelled and tweens[3].Destroyed and not byId.u.Item.GaugeAnimate)
	assert(not pcall(function() page:SetValue('p',80) end) and p.Value == '25','Disposed controls are no longer addressable')
	print('Gauges: bounds, quality regions, passive layout, paint-only values, form exclusion and tween lifecycle passed')
end
