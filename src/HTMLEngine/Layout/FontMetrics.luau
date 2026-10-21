--!strict
--!optimize 2
local Profiles = require(script.Parent.FontProfiles)
local FontMetrics = {}

function FontMetrics.resolve(style: any, nativeSizeOffset: number?): any
	if style.FontSize==0 then return {TextSize=0,Baseline=0,Top=0,XHeight=0,Bottom=0,Calibrated=true}end
	local profile = Profiles.get(style.Font)
	local requested = style.FontSize * (if profile then profile.SizeMultiplier or 1 else 1)
	if nativeSizeOffset then requested = math.max(1, requested + nativeSizeOffset) end
	local size = math.ceil(requested)
	-- Preserve the input convention of older guide fits; guides round themselves.
	local guides = if profile then Profiles.guides(profile, requested) else nil
	return {
		TextSize = size,
		Baseline = if guides then guides.Baseline else math.round(size * 0.8),
		Top = if guides then guides.Top else math.round(size * 0.13),
		XHeight = if guides then guides.XHeight else math.round(size * 0.3),
		Bottom = if guides then guides.Bottom else size,
		-- Bold/Italic use the family's regular size/guide fit as an estimate.
		-- WordLayout measures actual bounds with the requested weight and style.
		Calibrated = guides ~= nil and (not profile or profile.SizeMultiplierKnown ~= false) and (style.FontWeight or 400) == 400 and (style.FontStyle or "normal") == "normal",
	}
end

function FontMetrics.extents(style: any, metrics: any, measuredHeight: number?): any
	local height = math.max(metrics.TextSize, measuredHeight or 0)
	local specified = style.LineHeight
	if specified and specified.Kind == "number" then height = style.FontSize * specified.Value
	elseif specified and specified.Kind == "px" then height = specified.Value end
	-- Roblox exposes no font ascent/descent. TextSize approximates the logical
	-- font box; measured bounds only size labels and supply the normal line-height.
	-- H/x/p guide edges are visible glyph edges, not full font ascent/descent.
	local leading = (height - metrics.TextSize) / 2
	return {
		Ascent = metrics.Baseline + leading,
		Descent = metrics.TextSize - metrics.Baseline + leading,
	}
end

return FontMetrics
