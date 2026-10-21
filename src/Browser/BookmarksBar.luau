--!strict
local Bar={};Bar.__index=Bar
local TextService=game:GetService('TextService')
function Bar.new(browser,parent,gui,scope)
	local self=setmetatable({Browser=browser,Rows={},Scope=scope},Bar)
	self.Root=gui:Make('Frame',parent,{Name='BookmarksBar',Size=UDim2.new(1,0,0,30),BackgroundTransparency=0},{BackgroundColor3='Toolbar'})
	self.More=browser:ControlsFor(scope):Button(self.Root,{Name='MoreBookmarks',Icon='overflow-forward',IconSize=16,Variant='Toolbar',Tooltip='More bookmarks',Width=26,Height=26,OnClick=function()self:Overflow()end})
	return self
end
function Bar:Open(item,anchor)
	if item.Kind=='bookmark'then self.Browser:Navigate(item.Address);return end
	local entries={{Text='Open folder',Icon='folder',Action=function()self.Browser:Navigate('wayline://bookmarks?folder='..item.ID)end}}
	for _,child in self.Browser.Shared:GetChildren(item.ID)do
		local entry=child;table.insert(entries,{Text=entry.Title,Icon=if entry.Kind=='folder'then 'folder'else 'page',Action=function()self:Open(entry,anchor)end})
	end
	self.Browser.Overlays:Menu(anchor,entries)
end
function Bar:Overflow()
	local entries={{Text='Manage bookmarks',Icon='bookmark',Action=function()self.Browser:Navigate('wayline://bookmarks')end}}
	for _,item in self.Browser.Shared:GetChildren('root')do
		local entry=item;table.insert(entries,{Text=entry.Title,Icon=if entry.Kind=='folder'then 'folder'else 'page',Detail=entry.Address,Action=function()self:Open(entry,self.More.Root)end})
	end
	self.Browser.Overlays:Menu(self.More.Root,entries)
end
function Bar:Sync()
	local items=self.Browser.Shared:GetChildren('root');local present={};local x=6
	local height=if self.Browser.View.Touch then 36 else self.Browser.Theme.Tokens.ChromeBookmarkButtonHeight
	local y=math.floor((self.Root.AbsoluteSize.Y-height)/2)
	local available=math.max(0,self.Root.AbsoluteSize.X-height-12);local overflow=false
	for _,item in items do
		if not self.Root.Visible then break end
		local record=self.Rows[item.ID];local font=self.Browser.Theme.Tokens.Font
		-- A bookmark keeps its own text measurement until its title/font changes.
		local textWidth=if record and record.MeasuredTitle==item.Title and record.MeasuredFont==font then record.TextWidth
			else TextService:GetTextSize(item.Title,12,font,Vector2.new(10000,30)).X
		local width=math.clamp(math.ceil(textWidth)+34,60,180)
		if x+width>available then overflow=true;break end
		present[item.ID]=true
		if not record then
			local rowScope=self.Scope:Child();record={Scope=rowScope};self.Rows[item.ID]=record
			local id=item.ID
			record.Button=self.Browser:ControlsFor(rowScope):Button(self.Root,{Name='Bookmark_'..id,Text=item.Title,Icon=if item.Kind=='folder'then 'folder'else 'page',IconSize=16,TextSize=12,Variant='Toolbar',Radius=4,Width=160,Height=height,
				Tooltip=item.Address or item.Title,OnClick=function()local current=self.Browser.Shared.Bookmarks[id];if current then self:Open(current,record.Button.Root)end end})
		end
		record.MeasuredTitle=item.Title;record.MeasuredFont=font;record.TextWidth=textWidth
		record.Button:SetText(item.Title);record.Button.Entry.Tooltip=item.Address or item.Title;record.Button.Root.Size=UDim2.fromOffset(width,height)
		record.Button.Label.Position=UDim2.fromOffset(26,0);record.Button.Label.Size=UDim2.new(1,-32,1,0)
		if record.Button.Icon then record.Button.Icon.Position=UDim2.new(0,12,.5,0)end
		record.Button.Root.Visible=true;record.Button.Root.Position=UDim2.fromOffset(x,y);x+=width+2
	end
	for id,record in self.Rows do if not present[id]then record.Scope:Destroy();record.Button.Root:Destroy();self.Rows[id]=nil end end
	self.More.Root.Position=UDim2.new(1,-height-6,0,y);self.More.Root.Size=UDim2.fromOffset(height,height);self.More.Root.Visible=overflow
end
function Bar:Destroy()for _,record in self.Rows do record.Scope:Destroy()end;table.clear(self.Rows)end
return Bar
