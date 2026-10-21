--!strict
return function(Parser: any, DOM: any, Style: any, Stylesheet: any, loadFontProfiles: any, loadRenderTree: any, loadWordLayout: any, loadFontPreload: any)
	local compile, parses = Style.compile, 0
	Style.compile = function(source)
		if source ~= "" then parses += 1 end
		return compile(source)
	end
	local document = Parser.parse([[<style>p, .row {padding: 3px; line-height: 150%; color: red !important; width: 10px} #a {color: green; width: auto} p {color: blue; font-size: 20px}</style><p id="a" class="row">A</p><p id="b">B</p>]])
	local rules = Stylesheet.collect(document, function(message) error(message) end)
	assert(parses == 3, "Compile each rule body once, including comma groups")
	local parent = { FontSize = 16, Font = "Inter", Color = Color3.new(0, 0, 0) }
	local function resolve(id)
		local node = DOM.findById(document, id)
		return Style.resolve(node, parent, function(message) error(message) end, false, Stylesheet.match(rules, node))
	end
	local first = resolve("a")
	assert(first.Width == nil and first.Color == Color3.fromRGB(255, 0, 0) and first.LineHeight.Value == 30)
	first.Padding[1] = 99; first.LineHeight.Value = 99
	for _ = 1, 100 do assert(resolve("b").Padding[1] == 3 and resolve("b").LineHeight.Value == 30) end
	assert(parses == 3, "Applying matches must not parse the CSS again")
	local a = DOM.findById(document, "a")
	a.Attributes.style = "color: green !important"
	assert(resolve("a").Color == Color3.fromRGB(0, 128, 0), "Inline important retains priority")
	Style.compile = compile
	local badRules = Stylesheet.collect(Parser.parse("<style>.unused {unknown: invalid}</style>"), function() error("Unmatched declaration warning") end)
	assert(#Stylesheet.match(badRules, a).Normal == 0)
	local empty = Stylesheet.match({}, a)
	assert(empty == Stylesheet.match(badRules, a), "Unmatched nodes reuse the immutable empty declaration groups")
	assert(not pcall(function() table.insert(empty.Normal, {}) end), "An empty result cannot contaminate later styles")

	local constructed = 0
	local enums = { Font = { Arial = {}, Ubuntu = {}, SourceSans = {} }, FontWeight = { Regular = 400, Bold = 700 }, FontStyle = { Normal = "normal", Italic = "italic" } }
	local profiles = loadFontProfiles({
		fromEnum = function(font) return { Family = font, Weight = 400, Style = "normal" } end,
		new = function(family, weight, style)
			constructed += 1
			return { Family = family, Weight = weight, Style = style }
		end,
	}, enums, function(value) return if type(value) == "table" then "EnumItem" else type(value) end)
	local resolver = profiles.newResolver()
	local normal = resolver("Inter", 400, "normal")
	for _ = 1, 100 do assert(resolver("Inter") == normal) end
	assert(constructed == 1)
	assert(resolver("Inter", 700, "italic") ~= normal and constructed == 2)
	assert(profiles.newResolver()("Inter") ~= normal, "Separate pages own separate caches")
	local public = profiles.face("Inter"); public.Weight = 700
	assert(resolver("Inter").Weight == 400, "Public Font values cannot mutate the private page cache")
	local renderer = loadRenderTree({ create = function(_, _, properties) return table.clone(properties) end })
	local tree = renderer.build(Parser.parse([[<p style="font-family: Inter">A <i>B</i> C <i>D</i><span style="display:none; font-family: Ubuntu">hidden</span></p>]]), {}, function(message) error(message) end, resolver)
	assert(#tree.FontPreloadTargets == 2, "Only used, distinct font variants are preloaded")
	local run = tree.Children[1].Children[1]
	assert(run.ResolveFont == resolver and run.Items[1].Gui.FontFace == normal and run.Items[2].Gui.FontFace.Style == "italic", "Correct fonts must be assigned before measurement")
	local before, measurements = constructed, 0
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = { face = function() error("Bypassed page font resolver") end },
		["Layout/TextMeasure"] = { measure = function(text, face, size)
			measurements += 1
			assert(face == resolver("Inter", 400, face.Style))
			return { X = if text == " " then 3 else 10, Y = size }
		end },
	})
	layout.arrange(run, 100, 0, 0, function() return true end)
	layout.arrange(run, 20, 0, 0, function() return true end)
	assert(constructed == before and measurements == 7, "Fonts are reused; each word and space keeps its own measurement")

	local queue, requests, warnings, alive = {}, 0, {}, true
	local action = nil
	local loader = loadFontPreload({ GetService = function(_, name)
		assert(name == "ContentProvider")
		return { PreloadAsync = function(_, targets, callback)
			requests += 1
			assert(#targets > 0)
			if action then action(callback) else callback("font", "Success") end
		end }
	end }, { defer = function(callback) table.insert(queue, callback) end }, { AssetFetchStatus = { Success = "Success" } })
	local function start(targets)
		loader.start(targets, function() return alive end, function(message) table.insert(warnings, message) end)
	end
	start({})
	assert(#queue == 0)
	start(tree.FontPreloadTargets)
	assert(requests == 0 and #queue == 1, "Preload scheduling must not block mount")
	table.remove(queue, 1)()
	assert(requests == 1 and #warnings == 0 and #tree.FontPreloadTargets == 0)
	local cancelled = { {} }; start(cancelled); alive = false
	table.remove(queue, 1)()
	assert(requests == 1 and #cancelled == 0, "Skip deferred requests after page destruction")
	alive = true
	action = function(callback) callback("font", "Failure") end
	start({ {} }); table.remove(queue, 1)()
	assert(#warnings == 1)
	action = function() error("network failure") end
	start({ {} }); table.remove(queue, 1)()
	assert(#warnings == 2)
	action = function() alive = false; error("late failure") end
	start({ {} }); table.remove(queue, 1)()
	assert(#warnings == 2, "No late diagnostics after destruction")
	print("Page loading: CSS parsed once, independent computed styles, page-local fonts, early font assignment, individual measurements and preload lifecycle passed")
end
