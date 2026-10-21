--!strict
return function(Style: any,FontFeatures: any)
 local fixtureElement=require('DOM/Node').element
	local parent={FontSize=20,Font="Builder Sans",Color=Color3.new(0,0,0)}
	local function resolve(css: string,warnings: any?): any
		return Style.resolve(fixtureElement("span",{style=css}),parent,function(message)
			if warnings then table.insert(warnings,message) else error(message) end
		end,true)
	end
	local shorthand=resolve('font-variant:slashed-zero no-common-ligatures no-contextual;font-feature-settings:"ss03" 1')
	assert(shorthand.FontVariantNumeric and not shorthand.FontVariantLigatures.Liga and not shorthand.FontVariantLigatures.Calt)
	assert(shorthand.OpenTypeFeatures:find("zero 1",1,true) and shorthand.OpenTypeFeatures:find("ss03 1",1,true) and shorthand.OpenTypeFeatures:find("liga 0",1,true) and shorthand.OpenTypeFeatures:find("calt 0",1,true))
	local override=resolve('font-variant-numeric:slashed-zero;font-feature-settings:"zero" 0,"liga" 0')
	assert(override.OpenTypeFeatures:find("zero 0",1,true) and override.OpenTypeFeatures:find("liga 0",1,true) and override.OpenTypeFeatures:find("calt 1",1,true))
	local inherited=Style.resolve(fixtureElement("em",{}),shorthand,function(message) error(message) end,true)
	assert(inherited.OpenTypeFeatures==shorthand.OpenTypeFeatures)
	local warnings={}
	local fallback=resolve('font-feature-settings:"kern" 1;font-variant-numeric:tabular-nums',warnings)
	assert(#warnings==0 and fallback.TabularNums and fallback.OpenTypeFeatures:find("kern 1",1,true))
	local combined=resolve('font-variant-numeric:tabular-nums slashed-zero lining-nums;font-feature-settings:"tnum" 1')
	assert(combined.TabularNums and combined.OpenTypeFeatures:find("zero 1",1,true))
	assert(not combined.OpenTypeFeatures:find("tnum",1,true),"Roblox does not expose the tnum OpenType tag")
	local disabled=resolve('font-variant-numeric:tabular-nums;font-feature-settings:"tnum" 0')
	assert(not disabled.TabularNums)
	assert(FontFeatures.settings('"zero" 1,"ss03" 0')[1].Tag=="zero")
	assert(FontFeatures.settings('"zero" 1,"zero" 0')==nil and FontFeatures.settings('zero 1')==nil)
	assert(FontFeatures.ligatures("common-ligatures no-contextual").Calt==false)
	print("Font features: CSS parsing, shorthand expansion, inheritance, overrides and Roblox OpenType serialization passed")
end
