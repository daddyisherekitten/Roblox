--!strict
local Captions = {}

function Captions.create(box: any, factory: any, registry: any)
	if #box.TableCaptions == 0 and not box.TableSurface then return end
	local wrapper=box.Gui
	if not box.TableSurface then
		local surface=box.Gui
		wrapper=factory.create("Frame",surface.Parent,{Name="TableWrapper",BackgroundTransparency=1})
		registry[wrapper]=box.Node;surface.Parent=wrapper
		box.Gui,box.TableSurface=wrapper,surface
	end
	for _,caption in box.TableCaptions do
		local gui=if caption.OpacityGroup then caption.OpacityGroup.Gui else caption.Gui
		gui.Parent=wrapper
	end
end

function Captions.measure(box: any, measured: any, available: number, natural: any, alive: any): any
	if measured.Fixed or #box.TableCaptions == 0 then return measured end
	local minimum=0
	for _,caption in box.TableCaptions do
		minimum=math.max(minimum,natural(caption,available,alive,true))
		if not alive() then return nil end
	end
	local s=box.Style
	local edges=(s.BorderSizes and (s.BorderSizes[2]+s.BorderSizes[4]) or 2*(s.BorderSize or 0))+s.Padding[2]+s.Padding[4]
	measured.GridMin,measured.GridMax=measured.Min,measured.Max
	measured.Min=math.max(measured.Min,minimum-edges)
	measured.Max=math.max(measured.Max,measured.Min)
	return measured
end

function Captions.arrange(box: any, width: number, gridHeight: number, arrange: any, alive: any): (number,number,number,number)
	local y,right,bottom=0,width,0
	local top=0
	for _,side in {"top","bottom"} do
		if side == "bottom" then top=y; y+=gridHeight end
		for _,caption in box.TableCaptions do
			if (caption.Style.CaptionSide or "top") ~= side then continue end
			local h,r,b=arrange(caption,width,0,y,alive,true)
			if not alive() then return 0,0,0,0 end
			right,bottom=math.max(right,r),math.max(bottom,y+b)
			y+=h
		end
	end
	box.CaptionTop,box.TableGridHeight=top,gridHeight
	box.TableSurface.Position=UDim2.fromOffset(0,top)
	box.TableSurface.Size=UDim2.fromOffset(width,gridHeight)
	return y,right,math.max(y,bottom),top
end

return Captions
