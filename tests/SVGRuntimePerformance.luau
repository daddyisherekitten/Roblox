--!strict
return function(Events,Hit,Session,Queries,Matrix,Geometry,Parser)
 local bus=Events.new(function(message) error(message) end)
 local root={};local child={Parent=root};local other={Parent=root};local calls=0
 local first=bus:On(child,'pointermove',function() calls+=1 end)
 local second=bus:On(child,'pointermove',function() calls+=1 end)
 first:Disconnect();first:Disconnect()
 assert(bus:Has('pointermove'),'Repeated disconnect must not hide remaining listeners')
 bus:Emit(child,'pointermove');assert(calls==1)
 second:Disconnect();assert(not bus:Has('pointermove'))
 local trace={};local added=false;local removed
 bus:On(root,'x',function()
  table.insert(trace,'capture')
  removed:Disconnect()
  if not added then added=true;bus:On(child,'x',function() table.insert(trace,'new') end) end
 end,true)
 removed=bus:On(child,'x',function() error('Removed listener ran') end)
 bus:On(child,'x',function() table.insert(trace,'target') end)
 for _=1,1000 do bus:On(other,'x',function() error('Unrelated listener ran') end) end
 bus:Emit(child,'x');assert(table.concat(trace,',')=='capture,target','Dispatch snapshots additions and honors removals')
 table.clear(trace);bus:Emit(child,'x');assert(table.concat(trace,',')=='capture,target,new')
 local count=0;local once
 once=bus:On(child,'once',function() count+=1;once:Disconnect();bus:Emit(child,'once') end,{Once=true})
 bus:Emit(child,'once');assert(count==1 and not bus:Has('once'))
 bus:Destroy();assert(not bus:Has('x'))

 local function rectangle(x,y,width,height,node)
  return {Geometry={Kind='rect',X=x,Y=y,Width=width,Height=height,RX=0,RY=0,Closed=true},Transform=Matrix.identity(),Fill={1,0,0,1},SourceNode=node}
 end
 local shapes={};local strokeCalls=0;local originalStroke=Geometry.stroke
 Geometry.stroke=function(...) strokeCalls+=1;return originalStroke(...) end
 for i=1,400 do table.insert(shapes,rectangle((i-1)*15,20,10,10)) end
 local scene={Width=6000,Height=100,Shapes={{Children=shapes}}}
 local snapshot=Hit.prepare(scene)
 Geometry.stroke=originalStroke
 assert(strokeCalls==0,'Unpainted strokes must not be tessellated for visiblePainted hits')
 local contains=Hit.contains;local contourQueries=0
 Hit.contains=function(...) contourQueries+=1;return contains(...) end
 assert(Hit.query(snapshot,5,25)==shapes[1])
 assert(contourQueries==1,'Distant shapes must be rejected before detailed polygon checks')
 assert(Hit.query(snapshot,5,75)==nil and contourQueries==1,'Distant groups must be rejected before child traversal')
 Hit.contains=contains
 local line={Geometry={Kind='line',Points={{20,40},{80,40}},Closed=false},Transform=Matrix.identity(),StrokeWidth=20,LineCap='square',PointerEvents='all'}
 snapshot=Hit.prepare({Width=100,Height=100,Shapes={line}})
 assert(Hit.query(snapshot,12,48)==line,'Bounds must include unpainted square stroke caps')
 line.NonScalingStroke=true;snapshot=Hit.prepare({Width=100,Height=100,Shapes={line}},2)
 assert(Hit.query(snapshot,16,44)==line and Hit.query(snapshot,12,48)==nil,'Non-scaling stroke bounds follow scale')
 assert(Hit.query(nil,10,10)==nil)

 local node={};local geometry={Kind='polyline',Points={{0,0},{30,0},{30,40}},Closed=false}
 local queryScene={Nodes={[node]={Geometry=geometry}}}
 local contours=0;local originalContour=Geometry.contour
 Geometry.contour=function(...) contours+=1;return originalContour(...) end
 assert(Queries.length(queryScene,node)==70)
 for i=1,1000 do
  local point=Queries.point(queryScene,node,50);assert(point.X==30 and point.Y==20)
 end
 assert(contours==1,'Repeated path queries must reuse flattened geometry and metrics')
 local publicPath=Queries.path(queryScene,node);publicPath[1].Points[1][1]=999
 assert(Queries.point(queryScene,node,0).X==0,'Returned paths must not mutate cached metrics')
 queryScene.Nodes[node].Geometry={Kind='polyline',Points={{0,0},{100,0}},Closed=false}
 assert(Queries.length(queryScene,node)==100 and contours==2,'New geometry invalidates path metrics')
 Geometry.contour=originalContour

 local document=Parser.parse('<svg xmlns="http://www.w3.org/2000/svg"><rect id="plain" width="50" height="50"/></svg>')
 local current=document.Ids.plain
 local session=Session.new(document,function()
  return {Width=100,Height=100,Shapes={rectangle(0,0,50,50,current)},Nodes={[current]={Box={X=0,Y=0,Width=50,Height=50}}}}
 end)
 local builds=session.Stats.Builds
 session:Pointer('down',10,10);session:Pointer('cancel',-1,-1);session:Flush()
 assert(session.States.active==nil and session.States.hover==nil and session.Pointers[1]==nil,'Cancel clears logical state even without CSS changes')
 assert(session.Stats.Builds==builds,'State-only cancellation must not rebuild scenes')
 session:Pointer('down',10,10,2,'touch');session:Pointer('up',10,10,2,'touch');session:Flush()
 assert(session.Stats.Builds==builds,'Touch release without visual CSS changes must not rebuild scenes')
 local style={Kind='Element',Name='style',Attributes={},Parent=document.Root,Children={}}
 table.insert(style.Children,{Kind='Text',Text='rect:hover{fill:blue}',Children={},Parent=style});table.insert(document.Root.Children,style)
 session:InvalidateStyles();session:Flush();session:Pointer('move',10,10)
 assert(session.Dirty,'New stylesheet must participate in state invalidation after structural mutation')
 session:Flush();session:Pointer('move',-1,-1);session:Flush()
 local old=current;current=table.clone(old);current.Attributes=table.clone(old.Attributes)
 session.Dirty=true;session:Flush()
 assert(Hit.query(session.Snapshot,10,10).SourceNode==current,'Equivalent replacement geometry must update the event source')
 local samples=0
 session.Animation={Version=0,Sample=function() samples+=1;return {} end}
 for _=1,100 do session:Flush();session:GetBBox(current) end
 assert(samples==1,'Unchanged animation time and state must not resample during repeated queries')
 session:SetTime(1);session:Flush();assert(samples==2)
 session.Animation.TransitionTime=.25;session:Flush();assert(samples==3,'Paused timeline still samples advancing CSS transitions')
 session.Animation.Version+=1;session:Flush();assert(samples==4,'Animation events invalidate the sample')
 session:SetAttribute(current,'fill','blue');session:Flush();assert(samples==5,'Base attribute mutations invalidate the sample')
 session.States.hover=current;session:Flush();assert(samples==6,'CSS state changes invalidate the sample')
 session.States.hover=nil;session:Flush();assert(samples==7,'Cleared CSS state invalidates the sample')
 session:Destroy()
 print('SVG runtime performance: bounded hit queries, listener isolation/lifecycle, cached path metrics, and no-op pointer states passed')
end
