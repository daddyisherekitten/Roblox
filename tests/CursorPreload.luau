--!strict
return function(load, icons)
	for _, fail in {false, true} do
		local queue, created, warnings = {}, {}, {}
		local calls = 0
		local loader
		loader = load({GetService = function(_, name)
			assert(name == "ContentProvider")
			return {PreloadAsync = function(_, targets)
				calls += 1
				loader.start()
				local seen = {}
				for _, image in targets do
					assert(not image.Destroyed and image.Parent == nil)
					assert(not seen[image.Image], "Aliases must share one download")
					seen[image.Image] = true
				end
				for _, id in icons do assert(seen[id], "Every catalog image must be preloaded") end
				if fail then error("network failure") end
			end}
		end}, {spawn = function(fn) table.insert(queue, fn) end}, {new = function(class)
			assert(class == "ImageLabel")
			local image = {}
			function image:Destroy() assert(not self.Destroyed); self.Destroyed = true end
			table.insert(created, image)
			return image
		end}, function(message) table.insert(warnings, message) end)
		assert(#queue == 0, "Requiring the module must not start downloads")
		loader.start(); loader.start()
		assert(calls == 0 and #queue == 1, "Mount must not wait for downloads; concurrent mounts share work")
		table.remove(queue, 1)()
		loader.start()
		assert(calls == 1 and #queue == 0, "No repeated preload on subsequent mounts, including failures")
		assert(#created > 0)
		for _, image in created do assert(image.Destroyed, "Temporary images must be freed on success and failure") end
		assert(#warnings == (if fail then 1 else 0))
	end
	print("Cursor preload: complete deduplicated catalog, background scheduling, shared requests and success/failure cleanup passed")
end
