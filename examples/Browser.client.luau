--!strict
-- The standalone example supplies a content Frame; Wayline creates no window frame.
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Browser = require(ReplicatedStorage:WaitForChild('Browser'))

local screen = Instance.new('ScreenGui')
screen.Name = 'WaylineDemo'
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 20
screen.Parent = Players.LocalPlayer:WaitForChild('PlayerGui')

local content = Instance.new('Frame')
content.Name = 'BrowserContentHost'
content.Position = UDim2.fromOffset(16, 16)
content.Size = UDim2.new(1, -32, 1, -32)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.Active = false
content.Selectable = false
content.Parent = screen

local browser = Browser.mount(content,{PersistenceEnabled=false,PersistSession=false})

local destroying: RBXScriptConnection?
destroying = screen.Destroying:Connect(function()
	if destroying then destroying:Disconnect(); destroying = nil end
	browser:Destroy()
end)
