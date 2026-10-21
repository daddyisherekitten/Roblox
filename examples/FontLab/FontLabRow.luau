--!strict
local Engine = require(script.Parent.Parent.Parent)
local Factory = Engine.GuiFactory
local TextMeasure = Engine.TextMeasure
local GuideControls = require(script.Parent.GuideControls)
local FontLabRow = {}

function FontLabRow.create(session: any, router: any, config: any, index: number)
	local row = Factory.create("Frame", session.Root, {
		Name = "Sample_" .. index,
		Position = UDim2.fromOffset(16, 176 + (index - 1) * 254),
		Size = UDim2.fromOffset(864, 242), BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(29, 38, 53),
	})
	local function label(name: string, text: string, x: number, y: number, w: number, h: number): TextLabel
		return Factory.create("TextLabel", row, {
			Name = name, Text = text,
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		}) :: TextLabel
	end
	local sourceLabel = if config.GuideSource == "fitted" then "Startlinien: berechnete Näherung" else "Startlinien: unkalibriert"
	local title = label("Title", "", 12, 8, 835, 24)
	row:SetAttribute("GuideSource", config.GuideSource)
	row:SetAttribute("HtmlSize", config.HtmlSize)
	row:SetAttribute("FontName", config.Name)
	local sample = label("MeasuredText", "H x p", 12, 44, 450, 100)
	sample.Visible = false
	row:SetAttribute("MeasurementStatus", "loading")
	sample.FontFace = config.Font
	sample.TextSize = config.Size
	row:SetAttribute("RobloxTextSize", sample.TextSize)
	title.Text = string.format("%s | HTML %g px → Roblox %g | %s", config.Name, config.HtmlSize, sample.TextSize, sourceLabel)
	sample.LineHeight = 1
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = Color3.fromRGB(66, 143, 227)
	outline.Thickness = 1
	outline.Parent = sample
	local report = label("Report", "", 12, 184, 835, 24)
	report.TextSize = 16
	local initialX = if config.GuidePreset then config.GuidePreset.XHeight else math.floor(config.Size / 3)
	row:SetAttribute("InitialXOffset", initialX)
	row:SetAttribute("XAdjustment", 0)
	local offsets = {} :: { [string]: number }
	local function onGuideChanged(key: string, value: number)
		offsets[key] = value
		row:SetAttribute("Manual" .. key .. "Offset", value)
		if key == "XHeight" then row:SetAttribute("XAdjustment", value - initialX) end
		if offsets.Top and offsets.XHeight and offsets.Baseline and offsets.Bottom then
			report.Text = string.format("HTML %g | Roblox %g | H-Abstand=%d px | Oben=%d x=%d Basis=%d Unten=%d",
				config.HtmlSize, sample.TextSize, offsets.Baseline - offsets.Top,
				offsets.Top, offsets.XHeight, offsets.Baseline, offsets.Bottom)
		end
	end
	-- Preserve the prediction as a separate value; manual changes never train the model here.
	local definitions = {
		{ Key = "Top", Label = "Oben · H", Offset = 0, Color = Color3.fromRGB(242, 129, 153) },
		{ Key = "XHeight", Label = "x-Oberkante", Offset = math.floor(config.Size / 3), Color = Color3.fromRGB(119, 223, 171) },
		{ Key = "Baseline", Label = "Basis · H unten", Offset = math.round(config.Size), Color = Color3.fromRGB(255, 192, 84) },
		{ Key = "Bottom", Label = "Unten · p", Offset = math.round(config.Size) + 4, Color = Color3.fromRGB(192, 157, 255) },
	}
	for guideIndex, definition in definitions do
		if config.GuidePreset then
			definition.Offset = config.GuidePreset[definition.Key]
		end
		GuideControls.create(row, router, definition, guideIndex, onGuideChanged)
	end
	Factory.create("Frame", row, {
		Name = "Reference100px", Position = UDim2.fromOffset(12, 158),
		Size = UDim2.fromOffset(100, 2), BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
	})
	local hint = label("Hint", "← 100 px Referenz (keine Schriftmessung)", 124, 150, 340, 30)
	hint.TextSize = 16
	local metrics = label("Metrics", "Individuelle Textmessung läuft …", 12, 212, 835, 22)
	local measured: Vector2? = nil
	local failure: string? = nil
	local function updateMetrics()
		if not session.Alive then return end
		local actual = sample.TextBounds
		local requested = if measured then string.format("%.1f × %.1f", measured.X, measured.Y) else "ausstehend"
		metrics.Text = if failure then "Messfehler: " .. failure else string.format(
			"TextService: %s | TextLabel: %.1f × %.1f | Linien manuell", requested, actual.X, actual.Y)
	end
	local changed = sample:GetPropertyChangedSignal("TextBounds"):Connect(updateMetrics)
	session:AddCleanup(function() changed:Disconnect() end)
	task.spawn(function()
		local bounds, message = TextMeasure.measure(sample.Text, config.Font, sample.TextSize, 0)
		if not session.Alive then return end
		measured, failure = bounds, message
		sample.Visible = bounds ~= nil
		row:SetAttribute("MeasurementStatus", if bounds then "ready" else "error")
		updateMetrics()
	end)
	return row
end

return FontLabRow
