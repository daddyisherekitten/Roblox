--!strict
return function(Parser: any, Style: any, loadRenderTree: any, loadWordLayout: any)
 local fixtureElement=require('DOM/Node').element
	local parent = {Font = "Inter", FontSize = 20, Color = Color3.new(0, 0, 0)}
	local function resolve(css, inherited, warn)
		return Style.resolve(fixtureElement("span",{style = css}), inherited or parent, warn or function(message) error(message) end, true)
	end
	assert(resolve("").WordSpacing == 0)
	for value, expected in {normal = 0, ["0"] = 0, ["0px"] = 0, ["6px"] = 6, ["-2.5px"] = -2.5, ["+.5px"] = 0.5} do
		local style = resolve("word-spacing: " .. value)
		assert(style.WordSpacing == expected and resolve("", style).WordSpacing == expected)
	end
	assert(resolve("word-spacing: normal", resolve("word-spacing: 6px")).WordSpacing == 0)
	for _, value in {"auto", "10%", "2", "--1px", "-+2px", "1.2.3px", "100001px"} do
		local warnings = 0
		assert(resolve("word-spacing: 3px; word-spacing: " .. value, nil, function() warnings += 1 end).WordSpacing == 3 and warnings == 1)
	end
	local renderer = loadRenderTree({create = function(_, _, properties) return table.clone(properties) end})
	local requests = 0
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			requests += 1
			return {X = if text == " " then 5 else 20, Y = size}
		end},
	})
	local function build(html, warn)
		return renderer.build(Parser.parse(html), {}, warn or function(message) error(message) end).Children[1].Children[1]
	end
	local function run(css, text) return build('<p style="' .. css .. '">' .. text .. '</p>') end
	local function arrange(words, width) return layout.arrange(words, width or 100, 0, 0, function() return true end) end
	local words = run("font-family: Inter; font-size: 20px; word-spacing: 6px", "  AA   BB\n CC  ")
	local before = requests
	arrange(words)
	assert(#words.Items == 3 and requests == before + 5, "Collapsed spaces add no new measurement calls")
	assert(words.Items[1].X == 0 and words.Items[2].X == 31 and words.Items[3].X == 62)
	assert(words.Items[2].SpaceWidth == 11 and words.Items[2].MeasuredSpaceWidth == 5, "CSS pixels add to the native cached width without a font correction")
	local count = requests
	arrange(words, 61)
	assert(words.Items[3].X == 0 and words.Items[3].LineIndex == 2 and requests == count)
	arrange(words, 100)
	assert(words.Items[3].X == 62 and requests == count, "Reflow cannot accumulate spacing")
	words.Style.WordSpacing = 2
	arrange(words)
	assert(words.Items[2].X == 27 and requests == count, "Spacing-only changes reuse native word and space bounds")
	local breaks = run("word-spacing: 6px", "AA<br>BB CC<br>")
	arrange(breaks)
	assert(breaks.Items[3].X == 0 and breaks.Items[4].X == 31)
	local small = run("word-spacing: -2px", "AA BB")
	arrange(small)
	assert(small.Items[2].SpaceWidth == 3 and small.Items[2].X == 23)
	local overlap = run("word-spacing: -40px", "AA BB CC")
	local _, extent = arrange(overlap)
	assert(overlap.Items[2].X == -15 and overlap.Items[3].X == -30 and extent == 20, "Keep the widest earlier word in horizontal extent when later words move backwards")
	for align, first in {left = 0, center = 22.5, right = 45} do
		local aligned = run("word-spacing: 10px; text-align: " .. align, "AA BB")
		arrange(aligned)
		assert(aligned.Items[1].X == first and aligned.Items[2].X == first + 35)
	end
	local justified = run("word-spacing: 10px; text-align: justify; text-indent: 10px", "AA BB CC DD")
	arrange(justified, 80)
	assert(justified.Items[1].X == 10 and justified.Items[2].X == 60 and justified.Items[3].X == 0 and justified.Items[4].X == 35)
	local styled = build([[<p>AA<span style="word-spacing: 10px"> BB </span>CC</p>]])
	arrange(styled)
	assert(styled.Items[2].SpaceWidth == 15 and styled.Items[3].SpaceWidth == 15, "Whitespace carries its own inline style")
	local collapsed = build([[<p>AA <span style="word-spacing: 10px"> BB </span> CC</p>]])
	arrange(collapsed)
	assert(collapsed.Items[2].SpaceWidth == 5 and collapsed.Items[3].SpaceWidth == 15, "The first surviving collapsed space owns the style")
	local adjacent = build([[<p>AA<span style="word-spacing: 10px">BB</span></p>]])
	arrange(adjacent)
	assert(#adjacent.Items == 1 and adjacent.Items[1].Text == "AABB", "No invented word separator at markup boundaries")
	local cascaded = build([[<style>p {word-spacing: 8px !important}</style><p style="word-spacing: 3px">AA BB</p>]])
	arrange(cascaded)
	assert(cascaded.Items[2].SpaceWidth == 13)
	local decorated = run("word-spacing: 6px; text-decoration: underline", "AA BB")
	arrange(decorated)
	local line = decorated.Items[2].DecorationFrames[1]
	assert(line.Position[1] == -11 and line.Size[1] == 31, "Underline covers the enlarged word gap")
	local warnings = 0
	local nbsp = build([[<p style="word-spacing: 6px">AA&nbsp;BB CC</p>]], function(message)
		assert(message:find("non-breaking word group", 1, true)); warnings += 1
	end)
	arrange(nbsp, 1)
	assert(warnings == 1 and #nbsp.Items == 2 and nbsp.Items[1].Text == "AA BB", "Unsupported internal NBSP spacing stays unbreakable with an explicit diagnostic")
	assert(nbsp.Items[2].SpaceWidth == 11)
	print("Word spacing: normal/signed px, inheritance, cascade, collapsed-space ownership, wrapping, alignment, indent, underline, negative overlap, unchanged measurement counts and NBSP diagnostics passed")
end
