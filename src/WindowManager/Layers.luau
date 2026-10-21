--!strict
-- Window-system coordinates stay inside the supplied host, without desktop layers.
local Layers={};Layers.__index=Layers
function Layers.new(root)
	return setmetatable({Root=root},Layers)
end
function Layers:get(_name)return self.Root end
function Layers:scale()return 1 end
function Layers:toLocal(position,_name)
	local origin=self.Root.AbsolutePosition
	return Vector2.new(position.X-origin.X,position.Y-origin.Y)
end
function Layers:toScreen(position,_name)
	local origin=self.Root.AbsolutePosition
	return Vector2.new(position.X+origin.X,position.Y+origin.Y)
end
function Layers:sizeOf(_name)return self.Root.AbsoluteSize end
return Layers
