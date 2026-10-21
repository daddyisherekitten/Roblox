--!nonstrict
-- Upload assets/browser-icons/browser-icons.png once, then set its image ID here.
-- A mount can override this with IconAtlasImage. Empty leaves the icon blank.
local IconAssets={}
IconAssets.Image='rbxassetid://72168208218331'
IconAssets.RectSize=Vector2.new(48,48)
IconAssets.Offsets=table.freeze({
	['back']=Vector2.new(8,8),
	['forward']=Vector2.new(72,8),
	['up']=Vector2.new(136,8),
	['down']=Vector2.new(200,8),
	['plus']=Vector2.new(264,8),
	['close']=Vector2.new(328,8),
	['search']=Vector2.new(392,8),
	['site-controls']=Vector2.new(456,8),
	['home']=Vector2.new(8,72),
	['reload']=Vector2.new(72,72),
	['bookmark']=Vector2.new(136,72),
	['folder']=Vector2.new(200,72),
	['menu']=Vector2.new(264,72),
	['overflow']=Vector2.new(328,72),
	['vertical-menu']=Vector2.new(392,72),
	['overflow-forward']=Vector2.new(456,72),
	['settings']=Vector2.new(8,136),
	['history']=Vector2.new(72,136),
	['edit']=Vector2.new(136,136),
	['delete']=Vector2.new(200,136),
	['move']=Vector2.new(264,136),
	['check']=Vector2.new(328,136),
	['external']=Vector2.new(392,136),
	['warning']=Vector2.new(456,136),
	['logo']=Vector2.new(8,200),
	['guide']=Vector2.new(72,200),
})
local function imageURI(value)
	if type(value)=='number' then
		if value~=value or value<=0 or value==math.huge or value%1~=0 then return nil end
		value=string.format('%.0f',value)
	end
	if type(value)~='string' then return nil end
	local id=value:match('^rbxassetid://(%d+)$')or value:match('^(%d+)$')
	return if id and id:find('[1-9]')then 'rbxassetid://'..id else nil
end
function IconAssets.Resolve(name,override)
	local direct=imageURI(name)
	if direct then return {Image=direct,Offset=Vector2.zero,Size=Vector2.zero,Tint=false}end
	local image=imageURI(if override~=nil then override else IconAssets.Image)
	if not image then return nil end
	return {Image=image,Offset=IconAssets.Offsets[name]or IconAssets.Offsets.guide,Size=IconAssets.RectSize,Tint=true}
end
return IconAssets
