--!strict
local Engine = require(script.Parent.Parent.Parent)
local Factory = Engine.GuiFactory
local PageSession = Engine.PageSession
local ClickRouter = require(script.Parent.ClickRouter)
local FontLabRow = require(script.Parent.FontLabRow)
local Config = require(script.Parent.FontTestConfig)
local FontProfiles = Engine.FontProfiles
local FontReport = require(script.Parent.FontReport)
local FontLab = {}

function FontLab.mount(target: GuiObject)
	local profile = Config.TestProfile or FontProfiles.get(Config.Font)
	assert(profile, "Please create a FontProfiles entry for " .. tostring(Config.Font))
	-- 1 is a neutral measurement starting point, not a confirmed multiplier.
	local scale = Config.TestSizeMultiplier or profile.SizeMultiplier or 1
	local usesProfileScale = Config.TestSizeMultiplier == nil and profile.SizeMultiplier ~= nil
	local root = Factory.create("ScrollingFrame", target, {
		Name = "WebsiteScrollingFrame",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(17, 24, 36),
		ScrollingDirection = Enum.ScrollingDirection.XY,
	}) :: ScrollingFrame
	local session = PageSession.new(root)
	local router = ClickRouter.new(root)
	session:AddCleanup(function() router:Destroy() end)
	local function text(name: string, content: string, y: number, height: number, size: number)
		Factory.create("TextLabel", root, {
			Name = name, Text = content, TextSize = size,
			Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(860, height),
			TextWrapped = true,
		})
	end
	local status = string.format("%s %g", if usesProfileScale then "Profilfaktor" else "Testfaktor", scale)
	text("Title", "Schriftlabor · " .. profile.Name .. " · " .. status, 16, 36, 28)
	text("Instructions", "Alle vier Linien auf die sichtbare Pixelkante setzen: Rosa=H oben, Grün=x oben, Gelb=H unten, Lila=p unten.", 60, 50, 18)
	text("Scope", "Die Linie jeweils auf die erste sichtbare Pixelreihe legen. Danach Werte ausgeben und die vollständige FONT_REPORT-Zeile kopieren.", 118, 48, 18)
	local rows = {} :: { GuiObject }
	for index, size in Config.Sizes do
		local preset = if Config.UseGuidePreset == false then nil else FontProfiles.guides(profile, size * scale)
		local source = if preset then "fitted" else "unmeasured"
		local row = FontLabRow.create(session, router, {
			Name = profile.Name, Font = if Config.TestProfile then Font.new(profile.Family, Enum.FontWeight.Regular, Enum.FontStyle.Normal) else FontProfiles.face(Config.Font),
			Size = math.ceil(size * scale), HtmlSize = size,
			GuidePreset = preset, GuideSource = source,
		}, index)
		table.insert(rows, row)
	end
	local footerY = 176 + #rows * 254
	local printButton = Factory.create("TextLabel", root, {
		Name = "PrintFontReport", Text = "Werte ausgeben",
		Position = UDim2.fromOffset(16, footerY), Size = UDim2.fromOffset(220, 40),
		BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(48, 65, 87),
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
	}) :: TextLabel
	router:Register(printButton, function()
		FontReport.print(rows, Config.Font, scale, usesProfileScale)
		printButton.Text = "Ausgegeben · erneut drucken"
	end)
	text("PrintHint", "Studio: Ausgabe / Output öffnen. Dort die vollständige FONT_REPORT-Zeile kopieren.", footerY + 50, 28, 18)
	root.CanvasSize = UDim2.fromOffset(896, footerY + 90)
	return session
end

return FontLab
