--!strict
-- Parse and build the actual authored illustrations with the engine SVG graph.
-- This checks scene construction; it does not substitute for native pixel QA.
return function(SVG: any, assets: any)
	assert(#assets >= 10, "All ten authored illustrations must be included")
	local names, shapeTotal, paintedTotal = {}, 0, 0
	local function diagnostics(problems: any): string
		local result = {}
		for _, problem in problems do
			table.insert(result, tostring(problem.Code) .. ": " .. tostring(problem.Value or problem.Message or problem.Attribute or ""))
		end
		return table.concat(result, "; ")
	end
	for _, asset in assets do
		assert(type(asset.Name) == "string" and type(asset.SVG) == "string", "An illustration needs its source path and exact SVG")
		assert(not names[asset.Name], "Duplicate illustration " .. asset.Name)
		names[asset.Name] = true
		local document = SVG.Parser.parse(asset.SVG)
		assert(document.Valid, asset.Name .. ": " .. diagnostics(document.Diagnostics))
		assert(#document.Diagnostics == 0, asset.Name .. ": " .. diagnostics(document.Diagnostics))
		local root = assert(document.Root, asset.Name .. " has no SVG root")
		local width, height = tonumber(root.Attributes.width), tonumber(root.Attributes.height)
		assert(width and height and width > 0 and height > 0, asset.Name .. " needs positive intrinsic dimensions")
		local data = SVG.SceneBuilder(SVG.Parser, SVG.Viewport, {
			Width = width, Height = height,
			Cases = {{Name = asset.Name, Document = document}},
		}, {}, SVG.Length, SVG.Geometry, SVG.Paint, SVG.Transform,
			SVG.TransformBounds, SVG.Rendering, SVG.Document, SVG.Gradient, SVG.Resources, SVG.Text)
		assert(#data.Diagnostics == 0, asset.Name .. ": " .. diagnostics(data.Diagnostics))
		assert(#data.Scenes == 1, asset.Name .. " must produce one scene")
		local scene = data.Scenes[1]
		assert(scene.Width == width and scene.Height == height, asset.Name .. " lost intrinsic dimensions")
		assert(#scene.Shapes > 0, asset.Name .. " produced no scene shapes")
		local painted = 0
		for _, shape in scene.Shapes do
			local geometry = shape.Geometry
			if not shape.Hidden and (shape.Opacity == nil or shape.Opacity > 0)
				and not (geometry and geometry.Empty)
				and (shape.Fill ~= nil or (shape.Stroke ~= nil and shape.StrokeWidth > 0)) then
				painted += 1
			end
		end
		assert(painted > 0, asset.Name .. " produced no visible paint-bearing geometry")
		shapeTotal += #scene.Shapes
		paintedTotal += painted
	end
	print("NightwebIllustrations: " .. #assets .. " actual SVG sources, " .. shapeTotal
		.. " scene shapes, " .. paintedTotal .. " paint-bearing shapes and zero SVG diagnostics passed")
end
