--!strict
-- Demo shell only: not part of the reusable engine.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local engineModule = ReplicatedStorage:WaitForChild("HTMLEngine", 5)
if not engineModule then return end
local examples = engineModule:WaitForChild("Examples", 5)
if not examples then return end
local demoConfig = examples:FindFirstChild("Config")
if demoConfig and require(demoConfig).ActiveDemo ~= "FontLab" then return end
-- This demo may remain in Studio after switching Rojo projects.
-- Never wait forever for the optional lab in the HTML-only project.
local labFolder = examples:WaitForChild("FontLab", 5)
if not labFolder then return end
local labModule = labFolder:WaitForChild("FontLab", 5)
if not labModule or not engineModule then return end
local FontLab = require(labModule)

local screen = Instance.new("ScreenGui")
screen.Name = "FontLabDemo"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local target = Instance.new("Frame")
target.Name = "EngineTarget"
target.Active = false
target.Selectable = false
target.BackgroundTransparency = 1
target.Position = UDim2.new(0, 24, 0, 64)
target.Size = UDim2.new(1, -48, 1, -88)
target.Parent = screen
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local page = FontLab.mount(target)
local tests = engineModule:FindFirstChild("Tests")
local smoke = if tests then tests:FindFirstChild("Smoke") else nil
if smoke then require(smoke)(page) end
