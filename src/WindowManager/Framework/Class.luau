--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Class — OOP ohne Boilerplate.

	.new(name) legt eine Klasse an. Deren .new(...) erzeugt eine Instanz und
	ruft dabei automatisch :init(...) auf — der Konstruktor muss also nie
	von Hand aufgerufen werden.

		local Window = Class.new("Window")

		function Window:init(title)
			self.title = title
		end

		function Window:setTitle(title)
			self.title = title
		end

		local w = Window.new("Editor")   -- ruft w:init("Editor")
		print(w.title, tostring(w))      --> Editor  Window

	.extend(name, parent) erbt Methoden. Hat die Kindklasse kein eigenes
	:init, wird das der Elternklasse benutzt.

		local Dialog = Class.extend("Dialog", Window)

		function Dialog:init(title, message)
			Window.init(self, title)      -- Elternkonstruktor von Hand
			self.message = message
		end

	API: .new(name) · .extend(name, parent) · .isInstanceOf(obj, class)
	     .classNameOf(obj) · .parentOf(class)
--]]

local Class = {}

--[[
	Baut den gemeinsamen Teil von .new und .extend.

	Eine Klasse ist ihre eigene Metatable: cls.__index = cls. Instanzen
	zeigen per setmetatable auf die Klasse, Methodenaufrufe landen also
	direkt dort — ohne Zwischentabelle und ohne Kopieren.

	tostring(instanz) liefert den Klassennamen. Das ist reine Debug-Hilfe,
	aber eine, die sich auszahlt: ohne sie zeigt print() nur
	"table: 0x55f3a1" und man weiss beim Suchen nicht, was man in der Hand
	hält.
--]]
local function makeClass(className, parent)
	local cls = {}

	cls.__index = cls
	cls.className = className
	cls.parent = parent

	cls.__tostring = function()
		return className
	end

	--[[
		rawget, nicht cls.init: bei einer Kindklasse würde cls.init über die
		Metatable schon beim Elternteil fündig. Wir wollen hier aber wissen,
		ob die Klasse SELBST ein :init hat — nur dann darf sie das der
		Elternklasse verdrängen.
	--]]
	cls.new = function(...)
		local instance = setmetatable({}, cls)

		local init = rawget(cls, "init") or (parent and parent.init)
		if init then
			init(instance, ...)
		end

		return instance
	end

	if parent then
		setmetatable(cls, { __index = parent })
	end

	return cls
end

function Class.new(className)
	assert(type(className) == "string" and #className > 0, "Class.new: className fehlt")
	return makeClass(className, nil)
end

function Class.extend(className, parent)
	assert(type(className) == "string" and #className > 0, "Class.extend: className fehlt")
	assert(
		type(parent) == "table" and type(parent.className) == "string",
		"Class.extend: parent ist keine Klasse"
	)
	return makeClass(className, parent)
end

--[[
	Läuft die Vererbungskette hoch. Eine Dialog-Instanz ist damit auch eine
	Window-Instanz — genau das erwartet man von isInstanceOf.
--]]
function Class.isInstanceOf(obj, targetClass)
	if type(obj) ~= "table" then
		return false
	end

	local cls = getmetatable(obj)
	while type(cls) == "table" do
		if cls == targetClass then
			return true
		end
		cls = cls.parent
	end

	return false
end

function Class.classNameOf(obj)
	if type(obj) ~= "table" then
		return nil
	end

	local mt = getmetatable(obj)
	if type(mt) == "table" and type(mt.className) == "string" then
		return mt.className
	end

	return nil
end

-- Elternklasse einer Klasse (nicht einer Instanz). Für Diagnose und Tests.
function Class.parentOf(cls)
	if type(cls) ~= "table" then
		return nil
	end
	return cls.parent
end

return Class
