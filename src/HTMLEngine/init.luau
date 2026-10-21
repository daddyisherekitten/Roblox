--!strict
-- Engine building blocks only. No demos, tests or input connections on require.
local nativeRequire=require
local importedModules=setmetatable({},{__mode='k'})
local function require(source: any): any
	local value=nativeRequire(source)
	importedModules[source]=true
	return value
end
local Parser = require(script.HTML.Parser)
local Websites = require(script.Websites)
local WorkContext=require(script.WorkContext)
local renderingModulesReady=false
local COLD_IMPORTS_PER_SLICE=4

local function resolveIFrame(baseURL: string, reference: string): any
	if reference == "" or reference == "about:blank" then
		return {Kind = "internal", URL = "about:blank", Website = {HTML = "<!doctype html><html><head><title></title></head><body></body></html>", Options = {}}}
	end
	local destination = Websites.resolveURL(baseURL, reference)
	if destination.Kind == "missing" then destination.Name = "NotFound" end
	if destination.Name then destination.Website = Websites.get(destination.Name) end
	return destination
end

return {
	createWebLockStore = function()
		return require(script.JavaScript.WebLocks).createStore()
	end,
	createMediaCaptureHost = function(options: any?)
		return require(script.Rendering.VirtualCameraHost).new(options)
	end,
	mountHTML = function(target: GuiObject, html: string, options: any?)
		local prepared = table.clone(options or {})
		if prepared.IFrameResolver == nil then prepared.IFrameResolver = resolveIFrame end
		local milliseconds=prepared.RenderWorkBudgetMS
		if type(milliseconds)~='number'or milliseconds~=milliseconds or milliseconds<0 or milliseconds>16 then milliseconds=4 end
		local alive=true
		local destroyed=if target.Destroying then target.Destroying:Connect(function()alive=false end)else nil
		local work=WorkContext.new(math.min(2,milliseconds),{Alive=function()return alive end})
		local cold={Modules=0,ModuleMS=0,SlowestModule='',SlowestMS=0,WallMS=0}
		local function mount()
			-- Parser-only imports still avoid the rendering/input graph. On the
			-- first mount, distribute its individual module imports across frames.
			if work and not renderingModulesReady then
				local began=os.clock()
				local modules=require(script.Rendering.LoadingModules)
				local budget=WorkContext.budget()
				local batch=0
				WorkContext.checkpoint(true)
				for _,path in modules do
					-- Bound both elapsed work and the number of native imports.
					-- An individual native require/compile remains uninterruptible.
					local yields=budget and budget.Yields
					WorkContext.checkpoint(batch>=COLD_IMPORTS_PER_SLICE)
					if not budget or budget.Yields~=yields then batch=0 end
					local module=script
					for name in path:gmatch('[^/]+')do module=module:FindFirstChild(name);assert(module,'Missing rendering module: '..path)end
					if not importedModules[module]then
						local started=os.clock()
						require(module)
						batch+=1
						local elapsed=(os.clock()-started)*1000
						cold.Modules+=1;cold.ModuleMS+=elapsed
						if elapsed>cold.SlowestMS then cold.SlowestModule=path;cold.SlowestMS=elapsed end
					end
				end
				WorkContext.checkpoint(true)
				cold.WallMS=(os.clock()-began)*1000
				renderingModulesReady=true
			end
			WorkContext.checkpoint()
			local HTMLPage=require(script.Rendering.HTMLPage)
			local services=prepared.JavaScriptServices
			local standalone=(not services or services.WindowHost==nil)and not prepared.IsSrcdoc and(prepared.IFrameDepth or 0)==0
			local page
			if standalone then
				local host=require(script.Rendering.StandaloneHost)
				page=host.mount(target,html,prepared,HTMLPage.mount)
			else page=HTMLPage.mount(target,html,prepared)end
			if type(page)=='table'then page.ColdLoadStats=cold end
			return page
		end
		local result=table.pack(pcall(function()return if work then work:Run(mount)else mount()end))
		if destroyed then destroyed:Disconnect()end
		if work then work:Finish()end
		if not result[1]then error(result[2],0)end
		return table.unpack(result,2,result.n)
	end,
	parseHTML = Parser.parse,
	parseDocument = Parser.parseDocument,
	parseDocumentBytes = Parser.parseDocumentBytes,
	DocumentInfo = require(script.HTML.DocumentInfo),
	Elements = require(script.HTML.Elements),
	CSSProperties = require(script.CSS.Properties),
	CursorIcons = require(script.Input.CursorIcons),
	DOM = require(script.DOM.Node),
	GuiFactory = require(script.Rendering.GuiFactory),
	PageSession = require(script.PageSession),
	TextMeasure = require(script.Layout.TextMeasure),
	FontProfiles = require(script.Layout.FontProfiles),
	ImageSources = require(script.Rendering.ImageSources),
	URL = require(script.Navigation.URL),
	Websites = Websites,
}
