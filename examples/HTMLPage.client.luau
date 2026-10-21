--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local engineSource = ReplicatedStorage:FindFirstChild("HTMLEngine")
local demoExamples = engineSource and engineSource:FindFirstChild("Examples")
local demoConfig = demoExamples and demoExamples:FindFirstChild("Config")
local demoSettings=if demoConfig then require(demoConfig)else{}
if demoSettings.ActiveDemo and demoSettings.ActiveDemo ~= "HTMLPage" then return end

-- Set Website to a module name when adding a page; empty opens the home page.
local WEBSITE = script:GetAttribute("Website") or ""
-- Prefer the combined browser when both optional modules are available.
-- Setting this to false always selects the engine's own window host.
local browserEnabled=script:GetAttribute("BrowserEnabled")~=false

-- Exact paths relative to Workspace; change these to your own scene.
-- Example: {"Building", "SecurityRoom", "Camera"}. No recursive name search.
local CAMERA_PATH = {"Camera"}
local CAMERA_SCENE_PATH = {} -- Empty = Workspace; a smaller model reduces work.
local function workspaceObject(path: {string}): Instance?
	local object: Instance? = workspace
	for _,name in path do object=object and object:FindFirstChild(name);if not object then break end end
	return object
end

local screen = Instance.new("ScreenGui")
screen.Name = "HTMLPageDemo"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 20
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local target = Instance.new("Frame")
target.Name = "PageTarget"
target.Active = false
target.Selectable = false
target.BackgroundTransparency = 0
target.BackgroundColor3 = Color3.new(1, 1, 1)
target.Position = UDim2.fromOffset(24, 64)
target.Size = UDim2.new(1, -48, 1, -88)
target.Parent = screen

-- The viewport stays blank during loading. This label is only for errors.
local startup = Instance.new("TextLabel")
startup.Name = "StartupStatus"
startup.Active = false
startup.Selectable = false
startup.AutoLocalize = false
startup.TextWrapped = true
startup.TextSize = 18
startup.TextColor3 = Color3.fromRGB(30, 45, 65)
startup.BackgroundTransparency = 1
startup.BorderSizePixel = 0
startup.AnchorPoint = Vector2.new(0.5, 0.5)
startup.Position = UDim2.fromScale(0.5, 0.5)
startup.Size = UDim2.new(1, -48, 0, 100)
startup.ZIndex = 10
startup.Text = ""
startup.Visible = false
startup.Parent = target
print("HTMLPageDemo gestartet: " .. (if WEBSITE=="" then "Startseite" else WEBSITE))

local function showError(message: any)
	startup.Visible = true
	startup.TextColor3 = Color3.fromRGB(130, 35, 35)
	startup.Text = "The application could not start.\n" .. tostring(message)
	warn("HTMLPageDemo: " .. tostring(message))
end

-- Wait once for initial place replication, not for optional packages which may
-- intentionally be absent. Closing the GUI while loading cancels this launch.
if not game:IsLoaded() then game.Loaded:Wait() end
if not screen.Parent then return end
local engineModule = ReplicatedStorage:WaitForChild("HTMLEngine", 10)
if not screen.Parent then return end
if not engineModule then
	showError("HTMLEngine fehlt in ReplicatedStorage. Rojo neu verbinden und Stop → Play ausführen.")
	return
end
-- Give the first client frame back before starting native module compilation.
task.wait()
if not screen.Parent then return end
local engineStarted=os.clock()
local loaded, Engine = pcall(require, engineModule)
if not screen.Parent then return end
if not loaded then showError(Engine); return end
print(string.format('HTMLPageDemo: Engine geladen (%.1f ms)',(os.clock()-engineStarted)*1000))
if type(Engine.mountHTML) ~= "function" or not Engine.Websites then
	showError("Veraltete Engine: Websites-Katalog fehlt. Stop, Rojo synchronisieren, dann Play.")
	return
end
local sourcesStarted=os.clock()
local websiteLoaded, website = true, {Name="Leere Seite",HTML="<!doctype html><html><head><title>Leere Seite</title></head><body></body></html>",Options={}}
if WEBSITE~="" then websiteLoaded,website=pcall(Engine.Websites.get,WEBSITE)end
if not screen.Parent then return end
if not websiteLoaded then showError(website); return end
print(string.format('HTMLPageDemo: Seitenquellen geladen (%.1f ms)',(os.clock()-sourcesStarted)*1000))
local currentWebsite = WEBSITE
local function websiteURL(name: string): string
	return if name=="" then "about:blank" else Engine.Websites.url(name)
end
local webLockStore=if type(Engine.createWebLockStore)=='function'then Engine.createWebLockStore()else nil
local mediaCaptureHost=Engine.createMediaCaptureHost({
	Camera=function()return workspaceObject(CAMERA_PATH)end,
	Scene=function()return workspaceObject(CAMERA_SCENE_PATH)end,
	Width=640,Height=360,FrameRate=30,MaxParts=1500,
})
screen.Destroying:Connect(function()mediaCaptureHost:Destroy()end)
local MemoryStorage=require(engineModule.Storage.Memory)
local storageHost=MemoryStorage.new()
screen.Destroying:Connect(function()
	storageHost:Destroy()
end)
local options = table.clone(website.Options or {})
options.DocumentURL = websiteURL(currentWebsite)
options.StorageHost=storageHost
options.JavaScriptServices=table.clone(options.JavaScriptServices or{})
options.JavaScriptServices.MediaCaptureHost=mediaCaptureHost
options.JavaScriptServices.WebLockStore=webLockStore
if website.CSS ~= nil then options.CSS = website.CSS end
if website.Stylesheets ~= nil then options.Stylesheets = website.Stylesheets end
-- Only this LocalScript connects the independent modules. Initial replication
-- is complete: absent optional packages select the internal host immediately.
local browserModule=if browserEnabled then ReplicatedStorage:FindFirstChild("Browser")else nil
local windowModule=if browserModule then ReplicatedStorage:FindFirstChild("WindowManager")else nil
if not screen.Parent then return end
if browserModule and windowModule then
	local windows,host,destroying
	local connected,message=pcall(function()
		assert(browserModule:IsA("ModuleScript"),"Browser must be a ModuleScript in ReplicatedStorage.")
		assert(windowModule:IsA("ModuleScript"),"WindowManager must be a ModuleScript in ReplicatedStorage.")
		local integration=browserModule:FindFirstChild("Integration")
		assert(integration,"Browser.Integration is missing. Reconnect Rojo, then restart Play.")
		local bindingModule=integration:FindFirstChild("HTMLBinding")
		local hostModule=integration:FindFirstChild("WindowHost")
		assert(bindingModule and bindingModule:IsA("ModuleScript"),"Browser.Integration.HTMLBinding is missing. Reconnect Rojo, then restart Play.")
		assert(hostModule and hostModule:IsA("ModuleScript"),"Browser.Integration.WindowHost is missing. Reconnect Rojo, then restart Play.")
		local Browser=require(browserModule)
		local Binding=require(bindingModule)
		local WindowManager=require(windowModule)
		local WindowHost=require(hostModule)
		windows=WindowManager.new(screen)
		host=WindowHost.new(windows,Browser,Binding,Engine,{
			PersistenceEnabled=false,
			PersistSession=false,
			HomeWebsite=if WEBSITE~="" then WEBSITE else nil,
			DesktopHeaderInset=200, -- Leave room for Roblox's desktop controls above the page.
			ShowPopupNavigation=false, -- Hide only Back/Forward/Reload; keep the address bar.
			StorageHost=storageHost,
			MediaCaptureHost=mediaCaptureHost,
			WebLockStore=webLockStore,
			Diagnostic=function(detail)warn("HTMLPageDemo: "..tostring(detail))end,
			PageMounted=function(tab,loadedPage,milliseconds)
				print(string.format("HTMLPageDemo: Dokument %d aufgebaut (%.1f ms): %s",tab.ID,milliseconds,loadedPage.Title or tab.URL))
				for _,diagnostic in loadedPage.Document.Diagnostics do warn(diagnostic.Code..": "..diagnostic.Message)end
			end,
			PageReady=function(tab,loadedPage)print("HTMLPageDemo: Dokument "..tab.ID.." bereit: "..(loadedPage.Title or tab.URL))end,
		})
		destroying=screen.Destroying:Connect(function()
			destroying:Disconnect();host:Destroy();windows:Destroy()
		end)
		host:Open(if WEBSITE=="" then 'wayline://home'else websiteURL(WEBSITE),{Title='Wayline',Position=Vector2.new(24,64),Size=Vector2.new(math.max(480,screen.AbsoluteSize.X-48),math.max(392,screen.AbsoluteSize.Y-88))})
		print("HTMLPageDemo: Wayline and HTML connected")
	end)
	if not connected then
		if destroying then destroying:Disconnect()end
		if host then host:Destroy()end;if windows then windows:Destroy()end
		showError(message);return
	end
	target:Destroy()
	return
end
local fallbackReason=if not browserEnabled then "Browser deaktiviert"elseif not browserModule then "Browser fehlt"else "WindowManager fehlt"
print("HTMLPageDemo: HTML-Fenster-Fallback ("..fallbackReason..")")
-- The built-in host owns navigation and atomic document replacement in both
-- windowed and explicitly embedded mode, keeping popup families together.
options.Navigate=nil
if options.FallbackWindow~=false then
	target.BackgroundTransparency=1
end
local mountStarted=os.clock()
local mounted, page = pcall(Engine.mountHTML, target, website.HTML, options)
if not mounted then showError(page); return end
local cold=page.ColdLoadStats
if cold and cold.Modules>0 then
	print(string.format('HTMLPageDemo: Kalte Module: %d | mit Pausen: %.1f ms | require-Aufrufe: %.1f ms | längster Aufruf: %s (%.1f ms)',cold.Modules,cold.WallMS,cold.ModuleMS,cold.SlowestModule,cold.SlowestMS))
end
print(string.format('HTMLPageDemo: Dokument aufgebaut (%.1f ms einschließlich Ladepausen)',(os.clock()-mountStarted)*1000))
local build=page.BuildStats
if build then
	print(string.format('HTMLPageDemo: Aufbauphasen mit Wartezeit | HTML: %.1f ms | Metadaten: %.1f ms | CSS/GUI: %.1f ms | JavaScript: %.1f ms',build.ParseMS,build.MetadataMS,build.TreeMS,build.ScriptsMS))
end
page.Root:SetAttribute("Website", currentWebsite)
page.Root:SetAttribute("Location", websiteURL(currentWebsite))
print("HTMLPageDemo: Website geladen: " .. (website.Name or WEBSITE))
-- Optional demo controls must never block the page when Studio has an older Rojo tree.
task.spawn(function()
	local initialPage = page
	if initialPage.FallbackWindow then return end
	local examples = engineModule:FindFirstChild("Examples")
	local resizeModule = examples and examples:WaitForChild("ResizableTestWindow", 4)
	if not initialPage.Root.Parent then return end
	if not resizeModule then
		warn("Eckgriffe fehlen: Rojo in Studio neu verbinden und Stop → Play ausführen.")
		return
	end
	local ok, removeResize = pcall(function() return require(resizeModule)(target) end)
	if not ok then warn("Eckgriffe konnten nicht starten: " .. tostring(removeResize)); return end
	local destroying
	destroying = screen.Destroying:Connect(function() destroying:Disconnect(); removeResize() end)
end)
for _, diagnostic in page.Document.Diagnostics do
	warn(diagnostic.Code .. ": " .. diagnostic.Message)
end
local reportedReady = false
local lastReportedLayout = nil
local function updateStatus()
	local state = page.Root:GetAttribute("Status")
	if state == "error" then showError(page.Root:GetAttribute("Error"))
	elseif state == "ready" then
		startup.Visible = false
		if page.Root:GetAttribute("Presented") == false then return end
		-- Deferred callbacks for layout and ready may both observe the final ready state.
		-- Each completed pass owns a fresh stats table, including identical later results.
		local stats = page.LastLayoutStats
		if reportedReady and stats == lastReportedLayout then return end
		lastReportedLayout = stats
		if not reportedReady then
			reportedReady = true
			print("HTMLPageDemo: Seite bereit")
		else
			if stats and stats.Mode == "partial" then
				print(string.format("HTMLPageDemo: Teil-Layout (%d Layout-Aufrufe, %d Cache-Treffer)", stats.Recomputed, stats.Reused))
			else print("HTMLPageDemo: Seitenlayout vollständig neu berechnet") end
		end
	else
		startup.Visible = false
	end
end
local status = page.Root:GetAttributeChangedSignal("Status"):Connect(updateStatus)
local presented = page.Root:GetAttributeChangedSignal("Presented"):Connect(updateStatus)
page:AddCleanup(function() status:Disconnect(); presented:Disconnect() end)
updateStatus()
-- One report per completed SVG queue batch, not per mouse movement.
local svgPrevious = {Builds=0,Rasters=0,CacheHits=0,Uploads=0,HitBuilds=0,Cancelled=0,BuildMS=0,BuildActiveMS=0,BuildWaitMS=0,RasterMS=0,RasterActiveMS=0,RasterWaitMS=0,LayerHits=0,LayerBuilds=0,PartialRenders=0,RepaintPixels=0,WarmQueued=0,WarmCompleted=0,WarmPreempted=0,WarmCancelled=0}
local function reportSVG()
    local stats=page.SVGStats
    if not stats then return end
    local uploadChanged=stats.Uploads~=svgPrevious.Uploads
    local warmChanged=(stats.WarmCompleted or 0)~=svgPrevious.WarmCompleted or (stats.WarmCancelled or 0)~=svgPrevious.WarmCancelled
    if not uploadChanged and not warmChanged then return end
    if not uploadChanged then
        local queued,done,cancelled=stats.WarmQueued or 0,stats.WarmCompleted or 0,stats.WarmCancelled or 0
        print(string.format("SVG: Hover vorbereitet | Fertig: %d/%d | Wartend: %d | Wegen Anzeige unterbrochen: %d | Abgebrochen: %d | Pixel-Cache: %.1f MB",
            done,queued,math.max(0,queued-done-cancelled),stats.WarmPreempted or 0,cancelled,(stats.CacheBytes or 0)/(1024*1024)))
        for key in svgPrevious do svgPrevious[key]=stats[key] or 0 end
        return
    end
    local builds=stats.Builds-svgPrevious.Builds
    local rasters=stats.Rasters-svgPrevious.Rasters
    local hits=stats.HitBuilds-svgPrevious.HitBuilds
    local cached=stats.CacheHits-svgPrevious.CacheHits
    local cancelled=stats.Cancelled-svgPrevious.Cancelled
    local partials=(stats.PartialRenders or 0)-svgPrevious.PartialRenders
    local mode=if partials>0 and partials==rasters then "Teilbereich neu gerastert" elseif builds>0 then "Szenen-Neuaufbau" elseif rasters>0 then "Pixel-Neuberechnung" else "Cache wiederverwendet"
    print(string.format("SVG: %s | Szenen: %d | Raster: %d | Cache: %d | Hitbox-Aufbau: %d | Uploads: %d | Abgebrochen: %d | %dx%d px | Aufbau inkl. Wartezeit: %.1f ms (ohne Ladepausen: %.1f ms, Warten: %.1f ms) | Raster inkl. Wartezeit: %.1f ms (Arbeit: %.1f ms, Warten: %.1f ms) | Ebenen: %d wiederverwendet, %d erstellt | Neu gerasterte Fläche: %d px",
        mode,builds,rasters,cached,hits,stats.Uploads-svgPrevious.Uploads,cancelled,
        stats.LastWidth,stats.LastHeight,stats.BuildMS-svgPrevious.BuildMS,
        (stats.BuildActiveMS or 0)-svgPrevious.BuildActiveMS,(stats.BuildWaitMS or 0)-svgPrevious.BuildWaitMS,stats.RasterMS-svgPrevious.RasterMS,
        (stats.RasterActiveMS or 0)-svgPrevious.RasterActiveMS,(stats.RasterWaitMS or 0)-svgPrevious.RasterWaitMS,
        (stats.LayerHits or 0)-svgPrevious.LayerHits,(stats.LayerBuilds or 0)-svgPrevious.LayerBuilds,
        (stats.RepaintPixels or 0)-svgPrevious.RepaintPixels))
    for key in svgPrevious do svgPrevious[key]=stats[key] or 0 end
end
local svgStatus=page.Root:GetAttributeChangedSignal("SVGUploads"):Connect(reportSVG)
local svgWarmStatus=page.Root:GetAttributeChangedSignal("SVGPrewarmDone"):Connect(reportSVG)
local svgWarmCancelled=page.Root:GetAttributeChangedSignal("SVGPrewarmCancelled"):Connect(reportSVG)
page:AddCleanup(function() svgStatus:Disconnect();svgWarmStatus:Disconnect();svgWarmCancelled:Disconnect() end)
reportSVG()
-- Zum Entfernen später: page:Destroy()
