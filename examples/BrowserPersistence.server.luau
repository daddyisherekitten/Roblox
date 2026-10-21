--!strict
-- DataStore access stays on the server; the browser client receives bounded records.
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')
-- The server model is already present at startup. Browser persistence belongs
-- to an optional Browser installation; an HTML-only place has no owner to start.
local browser = ReplicatedStorage:FindFirstChild('Browser')
if not browser then return end
assert(browser:IsA('ModuleScript'), 'BrowserPersistenceServer: ReplicatedStorage.Browser must be a ModuleScript.')
local persistence = browser:FindFirstChild('Persistence')
local schemaModule = persistence and persistence:FindFirstChild('Schema')
assert(schemaModule and schemaModule:IsA('ModuleScript'), 'BrowserPersistenceServer: Browser.Persistence.Schema is missing or is not a ModuleScript.')
local serverModule = ServerScriptService:FindFirstChild('BrowserServer')
assert(serverModule and serverModule:IsA('ModuleScript'), 'BrowserPersistenceServer: ServerScriptService.BrowserServer is missing or is not a ModuleScript.')
local Schema = require(schemaModule)
local BrowserServer = require(serverModule)
assert(type(BrowserServer) == 'table' and type(BrowserServer.new) == 'function', 'BrowserPersistenceServer: BrowserServer.new is missing or is not a function.')
BrowserServer.new(Schema, {Name = 'WaylineBrowser_v1', RemoteName = 'WaylinePersistence'})
