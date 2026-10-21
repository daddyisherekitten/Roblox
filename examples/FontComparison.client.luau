--!strict
-- Start with: rojo serve fontcomparison.project.json
local Players = game:GetService("Players")
local engineModule = game:GetService("ReplicatedStorage"):WaitForChild("HTMLEngine", 5)
if not engineModule then return end
local examples = engineModule:WaitForChild("Examples", 5)
if not examples then return end
local demoConfig = examples:FindFirstChild("Config")
if demoConfig and require(demoConfig).ActiveDemo ~= "FontComparison" then return end
local module = examples:WaitForChild("FontComparison", 5)
if not module then return end
local screen = Instance.new("ScreenGui")
screen.Name = "FontComparisonDemo"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local target = Instance.new("Frame")
target.Name = "ComparisonTarget"
target.Active = false
target.Selectable = false
target.BackgroundTransparency = 1
target.Size = UDim2.fromScale(1, 1)
target.Parent = screen
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local status = Instance.new("TextLabel")
status.Active = false
status.Selectable = false
status.Size = UDim2.fromOffset(864, 60)
status.Text = "Schriftvergleich startet …"
status.Parent = target
local ok, result = pcall(function() return require(module).mount(target) end)
if ok then status:Destroy()
else status.Text = "Schriftvergleich konnte nicht starten: " .. tostring(result); warn(result) end
