--!nonstrict
-- Original scale/fade animation with bounded ownership and interruption.
local TweenService=game:GetService('TweenService')
local Root=script.Parent.Parent
local Theme=require(Root.UI.Theme)
local New=require(Root.UI.New)
local Fade=require(Root.UI.Fade)
local Animate={scale=0.95,tweenInfo=Theme.tween.fast}
function Animate.centeredPosition(position,size,scale)
	return UDim2.new(position.X.Scale,math.round(position.X.Offset+size.X*(1-scale)/2),position.Y.Scale,math.round(position.Y.Offset+size.Y*(1-scale)/2))
end
local function stop(window)
	local state=window._animation;if not state then return end
	window._animation=nil
	if state.Connection then state.Connection:Disconnect()end
	for _,tween in state.Tweens do tween:Cancel()end
	Fade.cancel(state.Fade)
	return state
end
function Animate.prepare(window)
	if window.animate~=false then New('UIScale',{Name='WindowScale',Scale=1,Parent=window.frame})end
	window.cleanup:add(function()stop(window)end)
end
function Animate.finishOpen(window)
	local state=window._animation
	if not state or state.Closing then return end
	stop(window)
	window.frame.Position=state.Target
	local scale=window.frame:FindFirstChild('WindowScale');if scale then scale.Scale=1 end
	Fade.set(state.Fade,0)
	window:setBusy('animation',false)
end
local function play(window,closing,onDone)
	local frame=window.frame;local scale=frame:FindFirstChild('WindowScale')
	local target=if closing then Animate.centeredPosition(frame.Position,window:getSize(),Animate.scale)else frame.Position
	local state={Closing=closing,Target=target,Fade=Fade.capture(frame),Tweens={}}
	window._animation=state
	if not closing then
		window:setBusy('animation',true)
		frame.Position=Animate.centeredPosition(target,window:getSize(),Animate.scale)
		if scale then scale.Scale=Animate.scale end
		Fade.set(state.Fade,1)
	end
	local positionTween=TweenService:Create(frame,Animate.tweenInfo,{Position=target})
	table.insert(state.Tweens,positionTween)
	if scale then table.insert(state.Tweens,TweenService:Create(scale,Animate.tweenInfo,{Scale=if closing then Animate.scale else 1}))end
	state.Connection=positionTween.Completed:Connect(function()
		if window._animation~=state then return end
		if closing then stop(window);onDone()else Animate.finishOpen(window)end
	end)
	Fade.tween(state.Fade,if closing then 1 else 0,Animate.tweenInfo)
	for _,tween in state.Tweens do tween:Play()end
end
function Animate.open(window)if window.animate~=false then play(window,false)end end
function Animate.close(window,onDone)
	Animate.finishOpen(window)
	if window.animate==false then onDone();return end
	play(window,true,onDone)
end
function Animate.cancel(window)stop(window)end
return Animate
