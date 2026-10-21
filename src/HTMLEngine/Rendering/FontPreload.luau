--!strict
local FontPreload = {}

-- One existing label per used font variant, rather than the entire page/catalog.
-- Start all requests together; layout can proceed while Roblox loads fonts.
function FontPreload.start(targets: { any }?, alive: () -> boolean, diagnostic: (string) -> (), completed: (() -> ())?, services: any?)
	if not targets or #targets == 0 then if completed and alive()then completed()end;return end
	local taskAPI=if services and services.Task then services.Task else task
	taskAPI.defer(function()
		if not alive() then table.clear(targets); return end
		local failed = false
		local ok, message = pcall(function()
			local provider=if services and services.ContentProvider then services.ContentProvider else game:GetService("ContentProvider")
			provider:PreloadAsync(targets, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then failed = true end
			end)
		end)
		table.clear(targets)
		if not alive() then return end
		-- Preloading is best effort. Actual measurement retains its own error path.
		if not ok then diagnostic("Font preload failed: " .. tostring(message))
		elseif failed then diagnostic("Some page fonts could not be preloaded") end
		if completed then completed()end
	end)
end

return FontPreload
