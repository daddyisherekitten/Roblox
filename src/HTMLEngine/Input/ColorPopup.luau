--!strict
-- The browser color well uses native GUI gradients; dragging never rebuilds layout.
local ColorValue=require(script.Parent.Parent.Controls.ColorValue)
local Popup={}
local WIDTH,HEIGHT=234,251
local WHITE,BLACK=Color3.new(1,1,1),Color3.new(0,0,0)
local function rgb(value)
	value=ColorValue.normalize(value)
	return tonumber(value:sub(2,3),16),tonumber(value:sub(4,5),16),tonumber(value:sub(6,7),16)
end
local function hsv(r,g,b,previousHue)
	r,g,b=r/255,g/255,b/255
	local high,low=math.max(r,g,b),math.min(r,g,b);local delta=high-low;local h=previousHue or 0
	if delta>0 then h=(if high==r then (g-b)/delta%6 elseif high==g then (b-r)/delta+2 else (r-g)/delta+4)/6 end
	return h,if high==0 then 0 else delta/high,high
end
local function channels(h,s,v)
	local i=math.floor(h*6);local f=h*6-i;local p,q,t=v*(1-s),v*(1-f*s),v*(1-(1-f)*s)
	local r,g,b
	if i%6==0 then r,g,b=v,t,p elseif i%6==1 then r,g,b=q,v,p elseif i%6==2 then r,g,b=p,v,t
	elseif i%6==3 then r,g,b=p,q,v elseif i%6==4 then r,g,b=t,p,v else r,g,b=v,p,q end
	return math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5)
end
local function hex(r,g,b)return string.format('#%02x%02x%02x',r,g,b)end
local function inside(gui,p)
	local a,s=gui.AbsolutePosition,gui.AbsoluteSize
	return p.X>=a.X and p.X<a.X+s.X and p.Y>=a.Y and p.Y<a.Y+s.Y
end
function Popup.new(page:any,choose:any,commit:any,factory:any?):any
	local self={Control=nil};local host,plane,hue,preview,spot,hueSpot,formatButton
	local fields,labels,strokes,connections={},{},{},{};local h,s,v=0,0,0
	local current,opening,edited,writing=nil,nil,false,false;local mode='RGB';local drag,down,keyboard
	local function active()return page.Alive and self.Control and not self.Control.Disabled and self.Control.Type=='color' end
	local function watch(signal,fn)table.insert(connections,signal:Connect(fn))end
	local function focusedField()
		for index,field in fields do if field.Visible and field:IsFocused()then return index end end
		return nil
	end
	function self:OwnsEditor(editor:any):boolean return editor~=nil and table.find(fields,editor)~=nil end
	function self:Close(notify:boolean?)
		local c=self.Control;local changed=edited and c and c.Value~=opening
		self.Control=nil;drag=nil;down=nil;keyboard=nil;edited=false
		for _,connection in connections do connection:Disconnect()end;table.clear(connections)
		for _,field in fields do if field:IsFocused()then field:ReleaseFocus()end end
		table.clear(fields);table.clear(labels);table.clear(strokes)
		if host then host:Destroy();host=nil end
		if c and page.SetControlPickerOpen then page:SetControlPickerOpen(c,false)end
		if changed and notify~=false and page.Alive and not c.Disabled and c.Type=='color' then commit(c)end
	end
	local function label(name,text,x,y,w,ht,class)
		return factory.create(class or 'TextLabel',host,{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,ht),ZIndex=1000003,
			FontFace=Font.fromEnum(Enum.Font.Arial),TextSize=14,TextColor3=BLACK,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center})
	end
	local function circle(parent,name,size,color,strokeColor,thickness)
		local gui=factory.create('Frame',parent,{Name=name,Size=UDim2.fromOffset(size,size),AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=0,BackgroundColor3=color,ZIndex=1000004})
		factory.modifier('UICorner',gui,{CornerRadius=UDim.new(.5,0)})
		factory.modifier('UIStroke',gui,{Thickness=thickness or 1,Color=strokeColor or BLACK,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
		return gui
	end
	local function paint(force)
		if not host then return end
		local r,g,b=rgb(current);local hr,hg,hb=channels(h,1,1)
		plane.BackgroundColor3=Color3.fromRGB(hr,hg,hb);preview.BackgroundColor3=Color3.fromRGB(r,g,b)
		spot.Position=UDim2.new(s,0,1-v,0);spot.BackgroundColor3=preview.BackgroundColor3
		hueSpot.Position=UDim2.new(1-h,0,.5,0);hueSpot.BackgroundColor3=plane.BackgroundColor3
		local names,values={'R','G','B'},{tostring(r),tostring(g),tostring(b)}
		if mode=='HSL' then
			local light=v*(1-s/2);local saturation=if light==0 or light==1 then 0 else (v-light)/math.min(light,1-light)
			names={'H','S','L'};values={tostring(math.floor(h*360+.5)),tostring(math.floor(saturation*100+.5)),tostring(math.floor(light*100+.5))}
		elseif mode=='HEX' then names={'HEX','',''};values={current:upper(),'',''}end
		writing=true
		for i,field in fields do
			field.Visible=mode~='HEX' or i==1;labels[i].Visible=field.Visible
			field.Position=UDim2.fromOffset(if mode=='HEX' then 24 else 24+(i-1)*60,184)
			field.Size=UDim2.fromOffset(if mode=='HEX' then 170 else 52,32)
			if force or not field:IsFocused()then field.Text=values[i]end
			labels[i].Text=names[i];labels[i].Position=UDim2.fromOffset(if mode=='HEX' then 24 else 24+(i-1)*60,221)
			labels[i].Size=UDim2.fromOffset(if mode=='HEX' then 170 else 52,24)
		end
		writing=false
	end
	local function publish(value,keepHSV)
		if not active()then return end
		value=ColorValue.normalize(value)
		if not keepHSV then local r,g,b=rgb(value);h,s,v=hsv(r,g,b,h)end
		local changed=value~=current;current=value;paint(false)
		if changed then edited=true;choose(self.Control,value)end
	end
	function self:Refresh()
		if not active()then self:Close(false);return end
		if self.Control.Value~=current then
			-- Script/reset writes are not user commits, including inside an input handler.
			current=ColorValue.normalize(self.Control.Value);opening=current;edited=false
			local r,g,b=rgb(current);h,s,v=hsv(r,g,b,h);paint(true)
		end
	end
	local function readField(index)
		if writing or not active()then return end
		if mode=='HEX' then
			local text=fields[1].Text;if text:match('^%x%x%x%x%x%x$')then text='#'..text end
			if text:match('^#%x%x%x%x%x%x$')then publish(text,false)end
			return
		end
		local value=tonumber(fields[index].Text)
		if not value or value~=value or math.abs(value)==math.huge then return end
		value=math.clamp(math.floor(value+.5),0,if mode=='RGB' then 255 elseif index==1 then 360 else 100)
		if mode=='RGB' then local values={rgb(current)};values[index]=value;publish(hex(table.unpack(values)),false)
		else
			local light=v*(1-s/2);local sat=if light==0 or light==1 then 0 else (v-light)/math.min(light,1-light)
			local values={h*360,sat*100,light*100};values[index]=value
			local hueValue,sl,ll=values[1]/360,values[2]/100,values[3]/100
			local vv=ll+sl*math.min(ll,1-ll);h,s,v=hueValue,if vv==0 then 0 else 2*(1-ll/vv),vv
			publish(hex(channels(h,s,v)),true)
		end
	end
	local function focusEntry(index)
		local previous=focusedField();if previous then fields[previous]:ReleaseFocus()end
		keyboard=index
		for i,stroke in strokes do
			stroke.Color=if i==index then Color3.fromRGB(0,117,255)else Color3.fromRGB(200,200,200)
			if i<=2 then stroke.Enabled=i==index end
		end
		if index>=3 and index<=5 then fields[index-2]:CaptureFocus()end
	end
	function self:Open(c:any):boolean
		self:Close();if not page.Alive or c.Disabled or c.Type~='color' or not c.Item or not page.Root.Parent then return false end
		factory=factory or require(script.Parent.Parent.Rendering.GuiFactory)
		self.Control=c;current=ColorValue.normalize(c.Value);opening=current;mode='RGB';edited=false
		local r,g,b=rgb(current);h,s,v=hsv(r,g,b,0)
		local root=page.Root;local parent=root.Parent;local rp,rs=root.AbsolutePosition,root.AbsoluteSize;local bp,bs=c.Item.BoxGui.AbsolutePosition,c.Item.BoxGui.AbsoluteSize
		local scale=math.min(1,math.max(1,rs.X)/WIDTH,math.max(1,rs.Y)/HEIGHT);local w,ht=WIDTH*scale,HEIGHT*scale
		local x=math.clamp(bp.X,rp.X,math.max(rp.X,rp.X+rs.X-w));local below=rp.Y+rs.Y-bp.Y-bs.Y
		local y=if below>=ht or below>=bp.Y-rp.Y then bp.Y+bs.Y else bp.Y-ht;y=math.clamp(y,rp.Y,math.max(rp.Y,rp.Y+rs.Y-ht))
		host=factory.create('Frame',parent,{Name='ColorPicker',Visible=false,Position=UDim2.fromOffset(x-parent.AbsolutePosition.X,y-parent.AbsolutePosition.Y),Size=UDim2.fromOffset(WIDTH,HEIGHT),BackgroundColor3=WHITE,BackgroundTransparency=0,ZIndex=1000000})
		if scale<1 then factory.modifier('UIScale',host,{Scale=scale})end
		factory.modifier('UIStroke',host,{Thickness=1,Color=Color3.fromRGB(190,190,190),ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
		plane=factory.create('Frame',host,{Name='ColorPlane',Size=UDim2.fromOffset(WIDTH,139),BackgroundTransparency=0,ZIndex=1000001})
		local white=factory.create('Frame',plane,{Size=UDim2.new(1,0,1,0),BackgroundColor3=WHITE,BackgroundTransparency=0,ZIndex=1000001})
		factory.modifier('UIGradient',white,{Transparency=NumberSequence.new(0,1)})
		local black=factory.create('Frame',plane,{Size=UDim2.new(1,0,1,0),BackgroundColor3=BLACK,BackgroundTransparency=0,ZIndex=1000002})
		factory.modifier('UIGradient',black,{Rotation=90,Transparency=NumberSequence.new(1,0)})
		spot=circle(plane,'ColorPlaneThumb',13,WHITE)
		local innerRing=circle(spot,'ColorPlaneThumbInnerRing',11,WHITE,WHITE)
		innerRing.Position=UDim2.new(.5,0,.5,0);innerRing.BackgroundTransparency=1;innerRing.ZIndex=spot.ZIndex+1
		-- Screen pixel access is unavailable. Keep the recognizable icon visibly disabled.
		local pipette=label('ColorEyedropperUnavailable','',8,149,28,28)
		for _,part in {{13,5,3,18},{9,3,11,4},{13,22,2,3}}do
			factory.create('Frame',pipette,{Position=UDim2.fromOffset(part[1],part[2]),Size=UDim2.fromOffset(part[3],part[4]),Rotation=40,BackgroundTransparency=0,BackgroundColor3=Color3.fromRGB(145,145,145),ZIndex=1000003})
		end
		preview=circle(host,'ColorPreview',31,WHITE,Color3.fromRGB(165,186,194));preview.Position=UDim2.fromOffset(58,162)
		hue=factory.create('Frame',host,{Name='ColorHue',Position=UDim2.fromOffset(88,155),Size=UDim2.fromOffset(130,12),BackgroundColor3=WHITE,BackgroundTransparency=0,ZIndex=1000002})
		local spectrum={};for i=0,6 do local cr,cg,cb=channels(1-i/6,1,1);table.insert(spectrum,ColorSequenceKeypoint.new(i/6,Color3.fromRGB(cr,cg,cb)))end
		factory.modifier('UIGradient',hue,{Color=ColorSequence.new(spectrum)})
		hueSpot=circle(hue,'ColorHueThumb',14,WHITE,WHITE,2)
		for i=1,3 do
			local field=label('ColorChannel'..i,'',24+(i-1)*60,184,52,32,'TextBox');field.BackgroundColor3=WHITE;field.BackgroundTransparency=0;field.ClearTextOnFocus=false
			fields[i]=field;labels[i]=label('ColorChannelLabel'..i,'',24+(i-1)*60,221,52,24)
			strokes[i+2]=factory.modifier('UIStroke',field,{Thickness=1,Color=Color3.fromRGB(200,200,200),ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
			watch(field:GetPropertyChangedSignal('Text'),function()readField(i)end)
			watch(field.Focused,function()if field:IsFocused()then keyboard=i+2 end end)
			watch(field.FocusLost,function()if not writing and self.Control and not field:IsFocused()then readField(i);paint(true)end end)
		end
		formatButton=label('ColorFormat','',192,225,28,20)
		for _,part in {{11,7,-45},{14,7,45},{11,12,45},{14,12,-45}}do
			factory.create('Frame',formatButton,{Position=UDim2.fromOffset(part[1],part[2]),Size=UDim2.fromOffset(4,1),Rotation=part[3],BackgroundTransparency=0,BackgroundColor3=BLACK,ZIndex=1000003})
		end
		strokes[1]=factory.modifier('UIStroke',plane,{Thickness=1,Color=Color3.fromRGB(200,200,200),ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Enabled=false})
		strokes[2]=factory.modifier('UIStroke',hue,{Thickness=1,Color=Color3.fromRGB(200,200,200),ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Enabled=false})
		paint(true);host.Visible=true
		for _,entry in {{c.Item.BoxGui,'AbsolutePosition'},{c.Item.BoxGui,'AbsoluteSize'},{root,'AbsolutePosition'},{root,'AbsoluteSize'}}do watch(entry[1]:GetPropertyChangedSignal(entry[2]),function()self:Close()end)end
		if page.SetControlPickerOpen then page:SetControlPickerOpen(c,true)end
		return self.Control==c
	end
	function self:Hit(position:any):any
		if not host or not inside(host,position)then return nil end
		if inside(plane,position)then return 1 elseif inside(hue,position)then return 2 end
		for i,field in fields do if field.Visible and inside(field,position)then return i+2 end end
		if inside(formatButton,position)then return 6 end
		return false
	end
	local function move(position)
		local target=if drag.Entry==1 then plane else hue;local p,size=target.AbsolutePosition,target.AbsoluteSize
		local x=math.clamp((position.X-p.X)/math.max(1,size.X),0,1)
		if drag.Entry==1 then s=x;v=1-math.clamp((position.Y-p.Y)/math.max(1,size.Y),0,1)else h=1-x end
		publish(hex(channels(h,s,v)),true)
	end
	local function samePointer(event)
		return drag and (drag.Event==event or drag.Event.UserInputType==Enum.UserInputType.MouseButton1 and (event.UserInputType==Enum.UserInputType.MouseMovement or event.UserInputType==Enum.UserInputType.MouseButton1))
	end
	function self:Begin(event:any):boolean
		if not active()then return false end
		if drag then return true end
		local hit=self:Hit(event.Position);if hit==nil then self:Close();return false end
		down=hit;if hit then focusEntry(hit)end
		if hit==1 or hit==2 then drag={Event=event,Entry=hit};move(event.Position)end
		return true
	end
	function self:Move(event:any):boolean
		if not active()then self:Close(false);return false end
		if samePointer(event)then move(event.Position);return true end
		if drag then return true end
		return self:Hit(event.Position)~=nil
	end
	local function cycle()
		mode=if mode=='RGB' then 'HSL' elseif mode=='HSL' then 'HEX' else 'RGB';paint(true)
	end
	function self:Finish(event:any):boolean
		if not active()then self:Close(false);return false end
		if drag and not samePointer(event)then return true end
		if drag then
			if not Enum.UserInputState or event.UserInputState~=Enum.UserInputState.Cancel then move(event.Position)end
			drag=nil;down=nil;return true
		end
		local hit=self:Hit(event.Position);if down==6 and hit==6 then cycle()end;down=nil
		return hit~=nil
	end
	function self:Tab(reverse:boolean):boolean
		if not active()then return false end
		local order=if mode=='HEX' then {1,2,3,6}else {1,2,3,4,5,6}
		local index=table.find(order,keyboard)or(if reverse then #order+1 else 0);index+=if reverse then -1 else 1
		if index<1 or index>#order then self:Close();return false end
		focusEntry(order[index]);return true
	end
	function self:Key(key:string,reverse:boolean?):boolean
		if not active()then return false end
		if key=='Escape' or key=='Return'then self:Close();return true end
		if key=='Tab'then return self:Tab(reverse==true)end
		if key=='Space' and keyboard==6 then cycle();return true end
		local index=focusedField()
		if index then
			if mode~='HEX' and (key=='Up' or key=='Down')then
				local number=tonumber(fields[index].Text)or 0;fields[index].Text=tostring(number+(if key=='Up'then 1 else -1));readField(index);paint(true);return true
			end
			return false
		end
		local step=if key=='Left' or key=='Down'then -1 elseif key=='Right' or key=='Up'then 1 else nil
		if step then
			if keyboard==2 then h=math.clamp(h-step/360,0,1)
			elseif key=='Left' or key=='Right'then s=math.clamp(s+step/100,0,1)else v=math.clamp(v+step/100,0,1)end
			publish(hex(channels(h,s,v)),true);return true
		end
		return false
	end
	return self
end
return Popup
