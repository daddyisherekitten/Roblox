--!strict
-- CSSOM View adapter over the native layout and scrolling frames.
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local ScriptGeometry={}
local INLINE_REPLACED={img=true,canvas=true,audio=true,video=true,iframe=true,object=true,embed=true}
function ScriptGeometry.new(page: any,tree: any,runtime: any,services: any?): any
	local tweens=setmetatable({},{__mode="k"});local adapter={};local alive=true
	function adapter.GetTree()return tree end
	function adapter.GetLayoutFragments(node)
		return if tree.InlineLayoutRects then tree:InlineLayoutRects(node)else {}
	end
	function adapter.GetBox(node)
		local model=page.FormModel;local control=model and model:Resolve(node)
		if control then return control.Item.GeometryBox end
		if not INLINE_REPLACED[ElementNames.htmlName(node)]and not ElementNames.matches(node,"svg",ElementNames.SVG)then return nil end
		local item=tree.MediaByNode and tree.MediaByNode[node]or tree.FindImageItem and tree:FindImageItem(node)
		return item and item.GeometryBox
	end
	function adapter.GetViewport()return page:GeometryViewport()end
	function adapter.HasPending()return runtime:HasPending() or page:HasPendingLayout()end
	function adapter.Flush()page:FlushScriptLayout()end
	local function complete(record)
		if record.Done then return end;record.Done=true
		if record.Connection then record.Connection:Disconnect();record.Connection=nil end
		if tweens[record.Gui]==record then tweens[record.Gui]=nil end
		if record.Resolve and alive and runtime.Alive then record.Resolve({})end
		record.Resolve=nil
	end
	function adapter.Scroll(node,x,y,behavior,relative)
		local box=node and tree.NodeBoxes[node]
		local gui=if node then box and box.ScrollGui else page.Root
		if not gui or not alive then return nil end
		local previous=tweens[gui]
		if previous then complete(previous);previous.Tween:Cancel()end
		local position=Vector2.new(x,y)
		if gui.CanvasPosition==position then return nil end
		if relative and tree.RecordRelativeScroll then tree:RecordRelativeScroll(node,x-gui.CanvasPosition.X,y-gui.CanvasPosition.Y)end
		if behavior~="smooth" then gui.CanvasPosition=position;return nil end
		local tweenService=services and services.TweenService
		if not tweenService and game then tweenService=game:GetService("TweenService")end
		if not tweenService then gui.CanvasPosition=position;return nil end
		local promise,resolve=runtime.Promises:CreateCapability()
		local tween=tweenService:Create(gui,TweenInfo.new(.24,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{CanvasPosition=position})
		local record={Gui=gui,Tween=tween,Resolve=resolve,Done=false};tweens[gui]=record
		record.Connection=tween.Completed:Connect(function()
			if not alive or record.Done then return end
			runtime.EventLoop:QueueTask(function()
				if not alive or record.Done then return end
				complete(record)
				if page.Alive then page.Events:Emit(node or page.Document,"scrollend",nil,{Bubbles=node==nil,Cancelable=false})end
			end)
		end)
		tween:Play();return promise
	end
	function adapter.Destroy()
		if not alive then return end;alive=false
		for _,record in tweens do complete(record);record.Tween:Cancel()end
		table.clear(tweens)
	end
	return adapter
end
return ScriptGeometry
