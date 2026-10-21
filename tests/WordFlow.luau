--!strict
return function(TextWords: any, Flow: any)
	local strut = { Ascent = 9, Descent = 3 }
	local items = TextWords.split("Hallo   Roblox!\nNeue Zeile")
	assert(#items == 5 and items[1].Text == "Hallo" and items[2].Text == "Roblox!")
	assert(items[2].SpaceBefore and items[3].Kind == "Break" and not items[4].SpaceBefore)
	for _, item in items do
		if item.Kind == "Word" then
			item.Width, item.SpaceWidth = 20, 5
			item.Ascent, item.Descent, item.Baseline = 9, 3, 9
		end
	end
	local height = Flow.arrange(items, 45, strut)
	assert(height == 24 and items[2].X == 25 and items[4].Y == 12)
	height = Flow.arrange(items, 44, strut)
	assert(height == 48 and items[2].X == 0 and items[2].Y == 12 and items[4].Y == 24)
	local long = { { Kind = "Word", Text = "long", Width = 100, SpaceWidth = 0, Ascent = 9, Descent = 3, Baseline = 9 } }
	local longHeight, extent = Flow.arrange(long, 10, strut)
	assert(longHeight == 12 and extent == 100 and long[1].Y == 0, "Long word must not create a blank first line")
	assert(Flow.arrange({ { Kind = "Break" }, { Kind = "Break" } }, 100, strut) == 24)
	assert(Flow.arrange({}, 100, strut) == 0)
	assert(#TextWords.split("Äpfel & Wörter") == 3)
	print("Word flow: word splitting, spaces, wrapping, breaks and oversized words passed")
end
