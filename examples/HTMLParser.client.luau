--!strict
-- Separate parser demo, intentionally no rendering or font lab.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local engineModule = ReplicatedStorage:WaitForChild("HTMLEngine")
local Engine = require(engineModule)
local runTests = require(engineModule:WaitForChild("Tests"):WaitForChild("HTML"))
runTests({ parse = Engine.parseHTML }, Engine.DOM)

local html = [[
<div id="page" class="card">
  <h1>Meine erste HTML-Seite</h1>
  <p>Hallo <span>Roblox</span> &amp; HTML!</p>
  <img src="rbxassetid://123" alt="Beispiel">
  <input type="checkbox" checked>
</div>
]]
local document = Engine.parseHTML(html)
local page = Engine.DOM.findById(document, "page")
print("HTML demo: nodes =", document.NodeCount)
print("Text content:", Engine.DOM.textContent(page))
for _, diagnostic in document.Diagnostics do
	warn(diagnostic.Code, diagnostic.Message, "at byte", diagnostic.Position)
end
print("Parser demo complete. HTML is data only; CSS and GUI rendering are the next steps.")
