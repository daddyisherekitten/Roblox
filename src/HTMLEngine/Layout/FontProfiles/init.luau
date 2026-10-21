--!strict
local FontProfiles = {}
local WEIGHTS={'Thin','ExtraLight','Light','Regular','Medium','SemiBold','Bold','ExtraBold','Heavy'}
local function weightStep(weight: number?): number return math.clamp(math.round((weight or 400)/100),1,9) end

function FontProfiles.get(font: Enum.Font | string): any
	if font == Enum.Font.Arial then return require(script.Arial) end
	if font == Enum.Font.SourceSans then return require(script.SourceSans) end
	if font == Enum.Font.Ubuntu then return require(script.Ubuntu) end
	if font == "Roboto" then return require(script.Roboto) end
	if font == "Roboto Condensed" then return require(script.RobotoCondensed) end
	if font == "Roboto Mono" then return require(script.RobotoMono) end
	if font == "PT Serif" then return require(script.PTSerif) end
	if font == "Roboto Slab" then return require(script.RobotoSlab) end
	if font == "Inter" then return require(script.Inter) end
	if font == "Open Sans" then return require(script.OpenSans) end
	if font == "Builder Sans" then return require(script.BuilderSans) end
	if font == "Lato" then return require(script.Lato) end
	if font == "Lora" then return require(script.Lora) end
	if font == "Merriweather" then return require(script.Merriweather) end
	if font == "Montserrat" then return require(script.Montserrat) end
	if font == "Noto Sans" then return require(script.NotoSans) end
	if font == "Nunito Sans" then return require(script.NunitoSans) end
	if font == "Playfair Display" then return require(script.PlayfairDisplay) end
	if font == "Poppins" then return require(script.Poppins) end
	if font == "Work Sans" then return require(script.WorkSans) end
	return nil
end

-- Asset families also work here, including families without an Enum.Font entry.
function FontProfiles.face(font: Enum.Font | string, weight: number?, style: string?): Font
	local fontWeight = Enum.FontWeight[WEIGHTS[weightStep(weight)]]
	local fontStyle = if style == "italic" then Enum.FontStyle.Italic else Enum.FontStyle.Normal
	if typeof(font) ~= "string" then
		local face = Font.fromEnum(font :: Enum.Font)
		if weight == nil and style == nil then return face end
		return Font.new(face.Family, if weight == nil then face.Weight else fontWeight, if style == nil then face.Style else fontStyle)
	end
	local profile = FontProfiles.get(font)
	assert(profile and profile.Family, "Unknown font family: " .. font)
	return Font.new(profile.Family, fontWeight, fontStyle)
end

-- Private to one page. No text measurements are shared or cached here.
-- Public face() keeps returning fresh Font values, so callers cannot mutate a
-- shared cache through the public API. Cache each native weight/style variant.
function FontProfiles.newResolver(): (Enum.Font | string, number?, string?) -> Font
	local families: any = {}
	return function(font: Enum.Font | string, weight: number?, style: string?): Font
		local resolvedWeight = weightStep(weight)*100
		local resolvedStyle = if style == "italic" then "italic" else "normal"
		local key = resolvedStyle .. tostring(resolvedWeight)
		local variants = families[font]
		if not variants then variants = {}; families[font] = variants end
		if not variants[key] then variants[key] = FontProfiles.face(font, resolvedWeight, resolvedStyle) end
		return variants[key]
	end
end

function FontProfiles.guides(profile: any, textSize: number): { [string]: number }?
	if textSize ~= textSize or textSize <= 0 or textSize == math.huge then return nil end
	-- New measurements use rounded TextSize; older fits retain their original input convention.
	if profile.GuideSizeRounding == "ceil" then textSize = math.ceil(textSize) end
	local measured = profile.GuideSamples and profile.GuideSamples[textSize]
	if measured then return table.clone(measured) end
	local result = {} :: { [string]: number }
	for _, key in { "Top", "XHeight", "Baseline", "Bottom" } do
		local coefficients = profile.Guides[key]
		if not coefficients or coefficients.Slope == nil or coefficients.Intercept == nil then return nil end
		result[key] = math.max(0, math.round(coefficients.Slope * textSize + coefficients.Intercept))
	end
	-- Extrapolated tiny sizes must retain the physical order of glyph guides.
	result.XHeight = math.max(result.Top, result.XHeight)
	result.Baseline = math.max(result.XHeight, result.Baseline)
	result.Bottom = math.max(result.Baseline, result.Bottom)
	return result
end

return FontProfiles
