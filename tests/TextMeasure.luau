--!strict
return function(loadTextMeasure: any)
	local created, calls = {}, 0
	local failService = false
	local instance = { new = function(className)
		assert(className == "GetTextBoundsParams")
		local fields = { DestroyCalls = 0 }
		local object = setmetatable({}, {
			__index = function(_, key)
				if key == "Destroy" then return function() fields.DestroyCalls += 1 end end
				return fields[key]
			end,
			__newindex = function(_, key, value)
				if key == "Font" and value == "invalid" then error("Invalid font") end
				fields[key] = value
			end,
		})
		table.insert(created, object)
		return object
	end }
	local service = { GetTextBoundsAsync = function(_, params)
		calls += 1
		assert(params.Text == "word" and params.Size == 20 and params.Width == 0 and not params.RichText)
		if failService then error("Measurement failed") end
		return { X = 30, Y = 20 }
	end }
	local measure = loadTextMeasure(instance, { GetService = function(_, name) assert(name == "TextService"); return service end }).measure
	local bounds, message = measure("word", "font", 20, 0)
	assert(bounds.X == 30 and message == nil and created[1].DestroyCalls == 1)
	bounds, message = measure("word", "invalid", 20, 0)
	assert(bounds == nil and message ~= nil and created[2].DestroyCalls == 1 and calls == 1)
	failService = true
	bounds, message = measure("word", "font", 20, 0)
	assert(bounds == nil and message ~= nil and created[3].DestroyCalls == 1 and calls == 2)
	bounds,message=measure("word","font",0,0)
	assert(bounds.X==0 and bounds.Y==0 and message==nil and #created==3 and calls==2,'Zero-sized glyphs allocate no native measurement request')
	assert(not pcall(measure,"word","font",-1,0)and #created==3,'Negative sizes remain invalid')
	print("Text measurement: request objects released after success, property errors and service errors passed")
end
