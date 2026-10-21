--!strict
return function(Scroll: any)
	local function signal(): any
		local listeners={}
		return {
			Connect=function(_,fn)
				local c={Connected=true,Callback=fn,Disconnect=function(self)self.Connected=false end}
				table.insert(listeners,c);return c
			end,
			Fire=function()for _,c in listeners do if c.Connected then c.Callback() end end end,
		}
	end
	local completed=signal()
	local played,cancelled=0,0
	local tween={Completed=completed,Play=function()played+=1 end,Cancel=function()cancelled+=1;completed.Fire()end}
	local writes=0
	local gui={CanvasPosition=Vector2.new(0,0),CanvasSize={300,300}}
	local box={ScrollGui=gui,Style={ScrollBehavior="smooth"},ScrollMarkerTargets={Vector2.new(100,100)},
		ScrollMarkerViewWidth=100,ScrollMarkerViewHeight=100,TweenService={Create=function()return tween end}}
	local originalRefresh=Scroll.refreshMarkers
	Scroll.refreshMarkers=function()writes+=1 end
	assert(Scroll.scrollToMarker(box,1) and box.ScrollMarkerNavigating and played==1)
	local connection=box.ScrollMarkerTweenConnection
	local canvas=signal();box.ScrollMarkerScrollConnection=canvas:Connect(function()error("Scroll event survived destruction")end)
	local marker=signal();box.ScrollMarkerConnections={marker:Connect(function()error("Marker event survived destruction")end)}
	local hidden={ScrollSnapTween={Cancel=function()cancelled+=1 end}}
	local root={Children={},AllChildren={box,hidden}}
	Scroll.destroyTree(root)
	assert(cancelled==2 and not connection.Connected and not box.ScrollMarkerTween and not hidden.ScrollSnapTween)
	assert(not box.ScrollMarkerNavigating and not box.ScrollMarkerTargets and not box.ScrollMarkerConnections)
	completed.Fire();canvas.Fire();marker.Fire()
	assert(writes==0,"Tween completion must not refresh destroyed markers, including synchronous Cancel completion")
	assert(not Scroll.scrollToMarker(box,1) and not Scroll.snap(box,true) and not Scroll.snapTree(root))
	Scroll.destroyTree(root)
	assert(cancelled==2,"Repeated cleanup must be harmless and include hidden AllChildren")
	Scroll.refreshMarkers=originalRefresh
	for _,axis in {"Inline","Block"} do
		local port={OuterWidth=100,OuterHeight=100,Style={ScrollSnapType={Axis="both",Strictness="mandatory"}},
			ScrollGui={CanvasPosition=Vector2.new(20,70),CanvasSize={500,500}},Children={
				{LayoutX=100,LayoutY=150,OuterWidth=20,OuterHeight=20,
					Style={ScrollSnapAlign={Inline=if axis=="Inline" then "start" else "none",Block=if axis=="Block" then "start" else "none"}}},
			}}
		assert(Scroll.snap(port,true))
		assert(port.ScrollGui.CanvasPosition.X==(if axis=="Inline" then 100 else 20))
		assert(port.ScrollGui.CanvasPosition.Y==(if axis=="Block" then 150 else 70),"The none axis must retain its scroll offset")
	end
	print("Scroll audit: live tween cancellation, disconnected callbacks, hidden subtree/idempotent cleanup and per-axis none passed")
 do
 local original=Vector2.new
 local comparisons={__eq=function(a,b)return a.X==b.X and a.Y==b.Y end}
 Vector2.new=function(x,y)return setmetatable({X=x,Y=y},comparisons)end
 local creates,plays,cancels,writes=0,0,0,0
 local ok,message=pcall(function()
  local values={CanvasPosition=Vector2.new(100,150),CanvasSize={500,500}}
  local gui=setmetatable({},{__index=values,__newindex=function(_,key,value)writes+=1;values[key]=value end})
  local port={OuterWidth=100,OuterHeight=100,Style={ScrollSnapType={Axis="both",Strictness="mandatory"}},
   ScrollGui=gui,Children={{LayoutX=100,LayoutY=150,OuterWidth=20,OuterHeight=20,
    Style={ScrollSnapAlign={Inline="start",Block="start"}}}},
   TweenService={Create=function(_,_,_,goal)
    creates+=1;assert(goal.CanvasPosition.X==100 and goal.CanvasPosition.Y==150)
    return {Play=function()plays+=1 end,Cancel=function()cancels+=1 end}
   end}}
  local tweened=Scroll.snap(port,false);local immediate=Scroll.snap(port,true)
  print("Snap unchanged operations",creates,plays,cancels,writes,"return",tweened,immediate)
  assert(not tweened and not immediate and creates==0 and plays==0 and cancels==0 and writes==0,
   "An already reached snap target must not create/play/cancel a tween or write CanvasPosition")
  port.ScrollSnapTween={Cancel=function()cancels+=1 end}
  assert(not Scroll.snap(port,false)and cancels==1 and port.ScrollSnapTween==nil and creates==0 and writes==0,
   "A reached target stops an older competing tween without creating or writing")
  values.CanvasPosition=Vector2.new(20,70)
  assert(Scroll.snap(port,false) and creates==1 and plays==1 and cancels==1 and writes==0,
   "A changed target must still play its tween")
  assert(Scroll.snap(port,true) and cancels==2 and writes==1 and values.CanvasPosition.X==100 and values.CanvasPosition.Y==150,
   "A changed immediate target must still publish the scroll position")
  assert(not Scroll.snap(port,true) and writes==1,"Repeated immediate snap is a no-op")
  local motionPosition=Vector2.new(100,150);local motionCreates,motionCancels,motionWrites=0,0,0;local movingTween
  local motionGui=setmetatable({CanvasSize={500,500}},{__index=function(_,key)if key=='CanvasPosition'then return motionPosition end end,
   __newindex=function(_,key,value)assert(key=='CanvasPosition');motionWrites+=1;motionPosition=value end})
  local moving={OuterWidth=100,OuterHeight=100,Style=port.Style,ScrollGui=motionGui,Children={{LayoutX=200,LayoutY=250,OuterWidth=20,OuterHeight=20,Style=port.Children[1].Style}}}
  moving.TweenService={Create=function(_,_,_,goal)
   motionCreates+=1;local stopped=false
   movingTween={Play=function()end,Cancel=function()stopped=true;motionCancels+=1 end,
    Advance=function()if not stopped then motionGui.CanvasPosition=goal.CanvasPosition end end}
   return movingTween
  end}
  assert(Scroll.snap(moving,false)and motionCreates==1)
  moving.Children[1].LayoutX,moving.Children[1].LayoutY=100,150
  assert(not Scroll.snap(moving,false)and motionCancels==1 and motionCreates==1 and not moving.ScrollSnapTween,
   "A new reached layout target cancels a genuinely active tween to another destination")
  movingTween.Advance()
  assert(motionWrites==0 and motionPosition.X==100 and motionPosition.Y==150,"A stale competing tween cannot move the scrollport away later")
  for _,mode in {'destroy','replace-gui','new-tween'}do
   values.CanvasPosition=Vector2.new(20,70)
   port.ScrollDestroyed=nil;port.ScrollGui=gui
   local beforeCreates,beforeWrites=creates,writes;local successor
   port.ScrollSnapTween={Cancel=function()
    assert(port.ScrollSnapTween==nil,'Cancel callbacks cannot observe a stale tween owner')
    if mode=='destroy'then Scroll.destroyTree(port)
    elseif mode=='replace-gui'then port.ScrollGui={CanvasPosition=Vector2.new(1,2)}
    else assert(Scroll.snap(port,false));successor=port.ScrollSnapTween end
   end}
   assert(not Scroll.snap(port,false),'The caller stops after cancellation transfers or destroys its owner')
   assert(writes==beforeWrites and creates==beforeCreates+(if mode=='new-tween'then 1 else 0),'No stale work follows a reentrant cancellation')
   if mode=='new-tween'then assert(successor and port.ScrollSnapTween==successor,'A new reentrant tween keeps ownership')end
   port.ScrollSnapTween=nil
  end
 end)
 Vector2.new=original
 assert(ok,message)
 print("Scroll snap: no-op operations, competing targets, changed publication and reentrant cancellation passed")
 end
end
