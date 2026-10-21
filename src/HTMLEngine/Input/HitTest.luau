--!strict
-- Roblox supplies paint order and clipping; the registry maps visual descendants back to DOM nodes.
local HitTest={}
local ProjectiveHit=require(script.Parent.Parent.Rendering.ProjectiveHit)
local function insideRadii(position: any,gui: any,radii: any): boolean
	local p,size=gui.AbsolutePosition,gui.AbsoluteSize
	local x,y=position.X-p.X,position.Y-p.Y
	for index=1,4 do
		local radius=radii[index]
		local rx,ry=radius and radius[1] or 0,radius and radius[2] or 0
		local top=index<=2
		local localX=if index==1 or index==4 then x else size.X-x
		local localY=if top then y else size.Y-y
		if rx>0 and ry>0 and localX<rx and localY<ry and ((localX-rx)/rx)^2+((localY-ry)/ry)^2>1 then return false end
	end
	return true
end
function HitTest.pick(objects: any, registry: any, root: any, position: any?, styles: any?): any
	for _, object in objects do
		local gui,node,inside,hitStyle,paintOnly=object,nil,false,nil,false
		while gui do
			if gui.GetAttribute and gui:GetAttribute("HTMLPaintOnlyOverlay") then paintOnly=true;break end
			if gui:IsA("GuiObject") then
				if not gui.Visible then node=nil; break end
				local clipStyle=styles and styles[gui]
				if position and gui.ClipsDescendants and clipStyle and clipStyle.ResolvedBorderRadii and not insideRadii(position,gui,clipStyle.ResolvedBorderRadii) then node=nil;break end
				if position and gui.ClipsDescendants then
					local p,size=gui.AbsolutePosition,gui.AbsoluteSize
					if gui:IsA("ScrollingFrame") and gui.AbsoluteWindowSize then size=gui.AbsoluteWindowSize end
					if position.X < p.X or position.Y < p.Y or position.X >= p.X+size.X or position.Y >= p.Y+size.Y then node=nil; break end
				end
			end
			if gui:IsA("LayerCollector") and not gui.Enabled then node=nil; break end
			node=node or registry[gui]
			hitStyle=hitStyle or (styles and styles[gui])
			if gui.GetAttribute and gui:GetAttribute("HTMLPageOverlay") then inside=true; break end
			if gui == root then inside=true; break end
			gui=gui.Parent
		end
		if paintOnly then continue end
		if inside then
			if position and ProjectiveHit.has(object)then
				local hit,source=ProjectiveHit.pick(object,position,registry,styles)
				if hit then return hit,source end
				continue
			end
			if hitStyle and hitStyle.PointerEvents=="none" then continue end
			-- Structural shells have no DOM box to hit, even when the lookup finds
			-- a registered ancestor. Only the shell passes through; its interactive
			-- descendants remain eligible (opacity groups and top-layer hosts).
			if object.GetAttribute and object:GetAttribute("HTMLHitTestPassthrough") then continue end
			if object.GetAttribute and object:GetAttribute("HTMLTableStructure") then continue end
			-- Structural table frames cover the full row/group, including holes
			-- occupied by a rowspan from an earlier sibling. They must not mask it.
			if node and (node.Name == "tr" or node.Name == "thead" or node.Name == "tbody" or node.Name == "tfoot") then continue end
			return node,object
		end
		-- Active outside UI (for example resize grips) owns the gesture.
		if object.Active or (object.GetAttribute and object:GetAttribute("HTMLInputBlocker")) then return nil end
	end
	return nil
end
return HitTest
