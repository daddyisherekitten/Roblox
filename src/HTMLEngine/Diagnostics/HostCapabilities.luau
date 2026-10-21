--!strict
-- Explicit, read-only capability discovery. Member presence is distinct from
-- permission, transport success and persistent durability. Never writes stores,
-- performs a request or subscribes to permanent render/input connections.
local HostCapabilities={}
function HostCapabilities.capture(services: any?): any
 local environment=services or {}
 local result={Schema='html-engine-host-capabilities/v1',Observed={},Limits={},RequestsPerformed=0,StoresWritten=0}
 local function service(name)
  if environment[name]then return environment[name]end
  if not game then return nil end
  local ok,value=pcall(game.GetService,game,name);return if ok then value else nil
 end
 local function member(name,owner,key)
  local ok,value=pcall(function()return owner and owner[key]end)
  result.Observed[name]={Available=ok and value~=nil,PermissionVerified=false}
 end
 local run=service('RunService')
 if run then
  local ok,studio=pcall(run.IsStudio,run);if ok then result.Studio=studio end
  local active,client=pcall(run.IsClient,run);if active then result.Client=client end
 end
 local getVersion=environment.Version or version
 if getVersion then local ok,value=pcall(getVersion);if ok then result.Version=value end end
 local http,store,assets,text=service('HttpService'),service('DataStoreService'),service('AssetService'),service('TextService')
 member('httpRequest',http,'RequestAsync');member('streamClient',http,'CreateWebStreamClient')
 member('dataStore',store,'GetDataStore');member('editableImage',assets,'CreateEditableImage')
 member('fontMetrics',text,'GetTextBoundsAsync');member('fontPreload',service('ContentProvider'),'PreloadAsync')
 member('buffer',environment.Buffer or buffer,'create')
 local create=environment.NewInstance or(if Instance then Instance.new else nil)
 if create then
  local ok,box=pcall(create,'TextBox')
  if ok then
   member('textValue',box,'Text');member('textCursor',box,'CursorPosition');member('textSelection',box,'SelectionStart')
   member('textDirection',box,'TextDirection');box:Destroy()
  end
 end
 result.Limits={Persistence='Not verified by a read-only capability snapshot',
  Composition='TextBox text/cursor changes do not identify OS composition start/update/end',
  FilePicker='No native OS file-picker adapter is installed',
  GPU='EditableImage availability does not establish arbitrary browser shader execution',
  SharedMemory='buffer availability does not establish shared ownership across Actors',
  GC='Weak table collection does not establish ECMAScript finalizer scheduling'}
 return result
end
return HostCapabilities
