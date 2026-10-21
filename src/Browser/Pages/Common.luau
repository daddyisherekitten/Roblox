--!nonstrict
local Lifetime = require(script.Parent.Parent.Lifetime)
local Controls = require(script.Parent.Parent.Controls)
local TextService = game:GetService('TextService')

local Common = {}
Common.Palette = {'Slate', 'Ocean', 'Meadow', 'Plum', 'Sand', 'Rose'}
Common.Backgrounds = {
	Slate = {Dark = Color3.fromRGB(48, 49, 52), Light = Color3.fromRGB(255, 255, 255)},
	Ocean = {Dark = Color3.fromRGB(17, 43, 55), Light = Color3.fromRGB(222, 241, 247)},
	Meadow = {Dark = Color3.fromRGB(29, 45, 34), Light = Color3.fromRGB(229, 242, 230)},
	Plum = {Dark = Color3.fromRGB(43, 30, 51), Light = Color3.fromRGB(242, 231, 248)},
	Sand = {Dark = Color3.fromRGB(48, 40, 29), Light = Color3.fromRGB(250, 243, 227)},
	Rose = {Dark = Color3.fromRGB(49, 31, 39), Light = Color3.fromRGB(249, 231, 236)},
}

function Common.controls(ctx, scope)
	return Controls.new(ctx.Gui, ctx.Input, ctx.Theme, scope, ctx.Overlays)
end

function Common.frame(ctx, parent, name, bindings)
	return ctx.Gui:Make('Frame', parent, {Name = name, BackgroundTransparency = 1, BorderSizePixel = 0}, bindings)
end

function Common.place(instance, x, y, width, height)
	instance.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
	instance.Size = UDim2.fromOffset(math.max(0, math.floor(width)), math.max(0, math.floor(height)))
end

function Common.text(controls, parent, text, size, muted)
	return controls:Text(parent, text, {TextSize = size or 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top}, {TextColor3 = muted and 'TextMuted' or 'Text'})
end

function Common.height(text, width, size)
	return math.ceil(TextService:GetTextSize(text, size or 14, Enum.Font.Arial, Vector2.new(math.max(40, width), 100000)).Y) + 3
end

function Common.button(controls, parent, text, icon, callback, tooltip, width)
	return controls:Button(parent, {Text = text, Icon = icon, OnClick = callback, Tooltip = tooltip or text, Width = width or 120, Height = 44})
end

function Common.result(ctx, result, message)
	if result == false or result == nil then
		ctx.Overlays:Notice(message or 'This change could not be completed.')
		return false
	end
	return true
end

function Common.address(ctx, text)
	local result = ctx.Address:Resolve(text)
	if not result or result.Kind == 'error' then return nil, 'Enter a valid address or search phrase.' end
	return result.URL
end

function Common.point(event)
	local value = event and (event.Position or event.Point)
	if value then return Vector2.new(value.X, value.Y) end
	return nil
end

function Common.inside(instance, point)
	if not point or not instance or not instance.Parent then return false end
	local p, s = instance.AbsolutePosition, instance.AbsoluteSize
	return point.X >= p.X and point.Y >= p.Y and point.X < p.X + s.X and point.Y < p.Y + s.Y
end

function Common.page(ctx, title, description, options)
	options = options or {}
	local self = {Context = ctx, State = ctx.State, Alive = true, Width = 400, Layout = function() end}
	self.Scroll = ctx.Controls:Scroll(ctx.Root, {Name = 'PageScroll'})
	self.Scroll.Root.Position = UDim2.fromOffset(0, 0)
	self.Scroll.Root.Size = UDim2.new(1, 0, 1, 0)
	self.Body = Common.frame(ctx, self.Scroll.Body, 'PageBody')
	self.Title = Common.text(ctx.Controls, self.Body, title, 22)
	self.Description = Common.text(ctx.Controls, self.Body, description, 14, true)
	self.Title.Visible = options.Header ~= false
	self.Description.Visible = options.Header ~= false and description ~= ''
	self.Content = Common.frame(ctx, self.Body, 'PageContent')
	function self:Reflow()
		if not self.Alive then return end
		local available = math.max(200, self.Scroll.Root.AbsoluteSize.X)
		local margin = available < 640 and 20 or 24
		self.Width = math.min(options.MaxWidth or 900, math.max(160, available - margin * 2))
		local x = math.max(margin, math.floor((available - self.Width) / 2))
		local titleHeight = self.Title.Visible and Common.height(self.Title.Text, self.Width, 22) or 0
		local descriptionHeight = self.Description.Visible and Common.height(self.Description.Text, self.Width, 14) or 0
		local headerHeight = titleHeight + (descriptionHeight > 0 and descriptionHeight + 8 or 0) + (titleHeight > 0 and 24 or 0)
		Common.place(self.Title, 0, 0, self.Width, titleHeight)
		Common.place(self.Description, 0, titleHeight + 8, self.Width, descriptionHeight)
		self.Content.Position = UDim2.fromOffset(0, headerHeight)
		self.Content.Size = UDim2.fromOffset(self.Width, 1)
		local height = self.Layout(self.Width) or 0
		self.Content.Size = UDim2.fromOffset(self.Width, math.max(0, height))
		local top = options.Top or 24
		Common.place(self.Body, x, top, self.Width, headerHeight + height)
		self.Scroll:SetContentHeight(top + self.Body.Size.Y.Offset + 24)
	end
	ctx.Scope:Add(self.Scroll.Root:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() self:Reflow() end))
	ctx.Scope:Add(function() self.Alive = false end)
	function self:Restore()
		self:Reflow()
		self.Scroll:ScrollTo(tonumber(self.State.Scroll) or 0)
	end
	function self.Capture()
		self.State.Scroll = self.Scroll:GetOffset()
		return self.State
	end
	return self
end

-- A single cleanup closure owns each replaceable list, rather than retaining every old row scope.
function Common.list(ctx, parent, name)
	local scope, root, controls
	local self = {}
	function self:Reset()
		if scope then scope:Destroy() end
		if root then root:Destroy() end
		scope = Lifetime.new()
		root = Common.frame(ctx, parent, name)
		controls = Common.controls(ctx, scope)
		self.Root, self.Controls = root, controls
		return root, controls
	end
	ctx.Scope:Add(function()
		if scope then scope:Destroy() end
		if root then root:Destroy() end
		scope, root, controls = nil, nil, nil
	end)
	self:Reset()
	return self
end

function Common.fieldForm(ctx, title, fields, submit, onSubmit)
	return ctx.Overlays:Form({Title = title, Fields = fields, SubmitText = submit, OnSubmit = onSubmit})
end

function Common.associate(ctx, overlay, remainsAvailable)
	if not overlay or not overlay.Scope then return end
	-- The overlay owns this connection, so repeatedly opening editors retains no listeners.
	overlay.Scope:Add(ctx.Shared.Changed:Connect(function()
		if ctx.Overlays.Current == overlay and not remainsAvailable() then ctx.Overlays:Dismiss() end
	end))
end

-- Long collections create only viewport rows with a small overscan. The complete
-- serializable collection still determines scroll height and item order.
function Common.virtual(ctx, parent, name, page, rowHeight, renderRow)
	local self = {Root = Common.frame(ctx, parent, name), Data = {}, First = nil, Last = nil, Width = 0, Alive = true}
	local content = Common.list(ctx, self.Root, 'VisibleRows')
	function self:Refresh(force)
		if not self.Alive then return end
		local viewport = page.Scroll.Root
		local top = viewport.CanvasPosition.Y - self.Root.Position.Y.Offset - page.Content.Position.Y.Offset - page.Body.Position.Y.Offset
		local first = math.max(1, math.floor(top / rowHeight) - 1)
		local last = math.min(#self.Data, math.ceil((top + viewport.AbsoluteSize.Y) / rowHeight) + 1)
		if last < first then first, last = 1, 0 end
		if not force and first == self.First and last == self.Last and self.Width == self.LastWidth then return end
		self.First, self.Last, self.LastWidth = first, last, self.Width
		if self.OnReset then self.OnReset() end
		local root, controls = content:Reset()
		root.Size = UDim2.fromOffset(self.Width, #self.Data * rowHeight)
		for index = first, last do renderRow(root, controls, self.Data[index], index, self.Width, (index - 1) * rowHeight) end
	end
	function self:SetData(data)
		self.Data = data
		if self.Width > 0 then self:Refresh(true) end
	end
	function self:Place(x, y, width, minimumHeight)
		self.Width = width
		Common.place(self.Root, x, y, width, math.max(minimumHeight or 0, #self.Data * rowHeight))
		self:Refresh()
	end
	ctx.Scope:Add(page.Scroll.Root:GetPropertyChangedSignal('CanvasPosition'):Connect(function() self:Refresh() end))
	ctx.Scope:Add(function() self.Alive = false; self.Data = {} end)
	return self
end

function Common.background(ctx, parent)
	local palette = Common.Backgrounds[ctx.Shared.Home.Background] or Common.Backgrounds.Slate
	local theme = ctx.Shared.Settings.Theme == 'Light' and 'Light' or 'Dark'
	if parent:GetAttribute('WaylineHomePainted') then
		ctx.Theme:Animate(parent, {BackgroundColor3 = palette[theme]}, ctx.Theme.Tokens.DurationTheme)
	else
		parent.BackgroundColor3 = palette[theme]
		parent:SetAttribute('WaylineHomePainted', true)
	end
	parent.BackgroundTransparency = 0
end

function Common.backgroundMenu(ctx, anchor)
	local items = {}
	for _, name in Common.Palette do
		table.insert(items, {Text = name, Icon = ctx.Shared.Home.Background == name and 'check' or nil,
			Action = function() local result, message = ctx.Shared:SetBackground(name); Common.result(ctx, result, message) end})
	end
	ctx.Overlays:Menu(anchor, items)
end

function Common.editGreeting(ctx)
	Common.fieldForm(ctx, 'Home greeting', {{Id = 'Greeting', Label = 'Greeting', Value = ctx.Shared.Home.Greeting,
		Placeholder = 'Your welcome message'}}, 'Save greeting', function(values)
		return ctx.Shared:SetGreeting(values.Greeting)
	end)
end

function Common.connection(ctx, signal, callback)
	if signal and signal.Connect then ctx.Scope:Add(signal:Connect(callback)) end
end

function Common.time(timestamp)
	local ok, text = pcall(function() return os.date('%b %d, %Y at %H:%M', tonumber(timestamp) or 0) end)
	return ok and text or 'Recent visit'
end

return Common
