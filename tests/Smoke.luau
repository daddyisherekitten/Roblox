--!strict
-- Runs once in Studio Play. No text metric claims without visual inspection.
return function(page: any)
	assert(page.Root:IsA("ScrollingFrame"), "Page root must be a ScrollingFrame")
	assert(page.Root.ScrollingEnabled, "Native scrolling must stay enabled")
	assert(page.Root.Active == false, "Root must be inactive")
	local count = 0
	for _, object in page.Root:GetDescendants() do
		if object:IsA("GuiObject") then
			count += 1
			assert(not object.Active, object:GetFullName() .. " has Active = true")
			assert(not object.Selectable, object:GetFullName() .. " uses native selection")
		end
	end
	assert(count > 0, "Lab is empty")

	-- Lifecycle regression: cleanup exactly once, including registrations after
	-- destruction. This fixture does not touch the displayed page.
	local EngineRoot = game:GetService("ReplicatedStorage"):WaitForChild("HTMLEngine")
	require(script.Parent.FontReport)(EngineRoot)
	local profiles = require(EngineRoot.Layout.FontProfiles)
	require(script.Parent.FontProfiles)(profiles)
	for _, name in { "Open Sans", "Inter", "Roboto", "Roboto Condensed", "Roboto Mono", "Roboto Slab" } do
		assert(profiles.face(name).Family == profiles.get(name).Family, "Wrong FontFace for " .. name)
		assert(profiles.face(name, 700).Weight == Enum.FontWeight.Bold)
		assert(profiles.face(name, 700, "italic").Style == Enum.FontStyle.Italic)
	end
	for _, font in { Enum.Font.Arial, Enum.Font.Ubuntu, Enum.Font.SourceSans } do
		assert(profiles.face(font, 700).Family == Font.fromEnum(font).Family)
		assert(profiles.face(font, 700).Weight == Enum.FontWeight.Bold)
		assert(profiles.face(font, 700, "italic").Style == Enum.FontStyle.Italic)
	end
	assert(profiles.get(Enum.Font.Arial).SizeMultiplier == 1.13)
	assert(profiles.get(Enum.Font.SourceSans).SizeMultiplier == nil)
	assert(profiles.get(Enum.Font.Ubuntu).SizeMultiplier == 1.09)
	assert(profiles.guides(profiles.get(Enum.Font.SourceSans), 50) == nil, "Unknown fonts must not inherit Arial guides")
	require(script.Parent.GuideEstimates)(profiles)
	local PageSession = require(EngineRoot.PageSession)
	local Factory = require(EngineRoot.Rendering.GuiFactory)
	local fixture = Factory.create("Frame", nil, { Name = "LifecycleFixture" })
	local session = PageSession.new(fixture)
	local cleaned = 0
	session:AddCleanup(function() cleaned += 1 end)
	session:Destroy()
	session:Destroy()
	assert(not session.Alive and cleaned == 1, "Cleanup must run exactly once")
	session:AddCleanup(function() cleaned += 1 end)
	assert(cleaned == 2, "Late resources must be cleaned immediately")

	print(string.format("FontLab: %d GuiObjects checked; Active=false; native scrolling enabled.", count + 1))
end
