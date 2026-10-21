--!strict
return function(Animation,Timing,Value,Session,Document,Parser,Viewport,Viewports,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Gradient,Resources,Sources,Text)
 local function near(a,b,label) assert(math.abs(a-b)<.03,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b)) end
 near(Timing.clock('1:02.5'),62.5);near(Timing.clock('00:01:02'),62);near(Timing.clock('250ms'),.25);near(Timing.clock('-.5s'),-.5)
 local p,i=Timing.phase({dur='.4s',repeatCount='2.5',fill='freeze'},1,0);near(p,.5);assert(i==2)
 assert(Timing.phase({dur='1s'},1,0)==nil);near(Timing.phase({dur='1s',fill='freeze'},1,0),1)
 near(Timing.ease('ease-in-out',.5),.5)
 assert(Value.mix('d','M1e2 20L200 30','M2e2 40L300 50',.5,{})=='M150 30L250 40','Exponent tokens retain order')
 local all={Scenes={},Diagnostics={}}
 local function make(source)
  source=table.clone(source);source.Document=Parser.parse(source.SVG);source.Runtime=true
  local s=Session.new(source.Document,function(_,states,animated)
   local data=Viewports(Parser,Viewport,{Cases={source},States=states,Animated=animated},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
   assert(#data.Diagnostics==0,source.Name..': '..tostring(data.Diagnostics[1] and data.Diagnostics[1].Code)..' '..tostring(data.Diagnostics[1] and data.Diagnostics[1].Value))
   return data.Scenes[1]
  end)
  s.Animation=Animation.new(source.Document)
  return s
 end
 local function seek(s,t) s:SetTime(t);s:Flush();assert(#s.Animation.Diagnostics==0,tostring(s.Animation.Diagnostics[1] and s.Animation.Diagnostics[1].Code)..' '..tostring(s.Animation.Diagnostics[1] and s.Animation.Diagnostics[1].Value));return s.Animated end
 local s=make(Sources.Cases[1]);local node=s:Node('moving');local initial=node.Attributes.x
 for _,t in {0,.25,.5,.75,1} do local a=seek(s,t);near(tonumber(a[node].x),40+300*t);near(s:GetBBox(node).X,40+300*t);near(tonumber(a[s:Node('growing')].r),12+33*t) end
 assert(node.Attributes.x==initial,'Animated value never mutates base DOM');local builds=s.Stats.Builds;seek(s,2);assert(s.Stats.Builds==builds,'Frozen animation does not rebuild')
 seek(s,.25);near(s:GetBBox(node).X,115,'Backward seek');s:Destroy()
 s=make(Sources.Cases[3]);local a=seek(s,.25);local positions={};for _,values in a do if values.cx then table.insert(positions,tonumber(values.cx)) end end;table.sort(positions);near(positions[1],40);near(positions[2],140);near(positions[3],140);s:Destroy()
 s=make(Sources.Cases[4]);a=seek(s,1);local values={};for _,v in a do if v.cx then table.insert(values,tonumber(v.cx)) end end;table.sort(values);near(values[1],90);near(values[2],370);s:Destroy()
 s=make(Sources.Cases[5]);seek(s,0);local before=s:GetCTM(s:Node('traveler'));near(before.TX,40);near(before.TY,160)
 seek(s,.5);local center=s:GetCTM(s:Node('traveler'));near(center.TX,240);near(center.TY,160)
 s:SetAttribute(s:Node('track'),'d','M40 40H440');seek(s,.5);center=s:GetCTM(s:Node('traveler'));near(center.TX,240);near(center.TY,40,'Motion path mutation invalidates length lookup');s:Destroy()
 s=make(Sources.Cases[7]);seek(s,0);s:Activate(s:Node('go'));seek(s,.25)
 a=s.Animated;local blue,green
 for target,v in a do if target.Attributes.cy=='90' then blue=tonumber(v.cx) elseif target.Attributes.cy=='180' then green=tonumber(v.cx) end end
 near(blue,230);assert(green==nil,'Syncbase waits until source ends')
 seek(s,.8);for target,v in s.Animated do if target.Attributes.cy=='180' then green=tonumber(v.cx) end end;near(green,230,'Event syncbase starts .1s after end');s:Destroy()
 s=make(Sources.Cases[8]);seek(s,0);seek(s,.5);center=s:GetCTM(s:Node('css'));near(center.TX,150,'CSS keyframes transform');near(tonumber(s.Animated[s:Node('css')].opacity),.675)
 s.Animation.TransitionTime=0;s.States.hover=s:Node('fade');s.Dirty=true;seek(s,.5)
 s.Animation.TransitionTime=.4;seek(s,.5);assert(not s.Animated[s:Node('fade')] or not s.Animated[s:Node('fade')].opacity,'Completed CSS transition uses target cascade')
 near(tonumber(s.Scene.Nodes[s:Node('fade')].Node.Attributes.opacity),.2);s:Destroy()
 local custom={Name='animation-additive',SVG='<svg xmlns="http://www.w3.org/2000/svg"><rect id="a" width="20" height="20" x="10"><animate attributeName="x" by="100" dur="1s" fill="freeze"/><animateTransform attributeName="transform" type="translate" from="0 0" to="0 100" dur="1s" additive="sum" fill="freeze"/></rect></svg>'}
 s=make(custom);a=seek(s,.5);near(tonumber(a[s:Node('a')].x),60);near(s:GetCTM(s:Node('a')).TY,50);s:Destroy()
 s=make({Name='css-missing-endpoints',SVG='<svg xmlns="http://www.w3.org/2000/svg"><style>@keyframes midpoint{50%{x:80}}rect{animation-name:midpoint;animation-duration:1s;animation-timing-function:linear;animation-fill-mode:forwards}</style><rect id="mid" x="20" width="10" height="10"/></svg>'})
 node=s:Node('mid');near(tonumber(seek(s,.25)[node].x),50,'Missing initial keyframe uses underlying value')
 near(tonumber(seek(s,.75)[node].x),50,'Missing final keyframe uses underlying value')
 s:SetAttribute(node,'x','40');near(tonumber(seek(s,.75)[node].x),60,'Compiled keyframe offsets retain live underlying endpoints');s:Destroy()
 local malformed=Parser.parse('<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"><animate attributeName="x" values="0;100" keyTimes="0;nope" dur="1s"/></rect></svg>')
 local invalid=Animation.new(malformed);invalid:Sample(.5,{});assert(invalid.Diagnostics[1].Code=='invalid-animation-key-times')
 local values=Parser.parse('<svg xmlns="http://www.w3.org/2000/svg"><rect><animate id="a" attributeName="x" from="0" to="100" begin="indefinite" dur="1s"/></rect></svg>')
 local api=Animation.new(values);for i=1,300 do api:BeginElement(values.Ids.a,i);api:EndElement(values.Ids.a,i+.5) end
 assert(#api.Items[1].Starts==256 and #api.Items[1].Ends==256,'Instance histories stay bounded')
 s=make({Name='animation-event-history',SVG='<svg xmlns="http://www.w3.org/2000/svg"><rect id="target" width="100" height="100"><animate id="trigger" attributeName="x" from="0" to="100" begin="target.click" dur="1s"/></rect></svg>'})
 node=s:Node('target');api=s.Animation;api:Event(node,'click',0)
 for i=1,400 do api:Event(node,'pointermove',i/1000) end
 assert(#api.Events==1 and api.Events[1].Kind=='click','Unreferenced pointer traffic must retain the animation start event')
 near(tonumber(seek(s,.5)[node].x),50,'Retained click event keeps timing after unrelated pointer traffic')
 s:SetAttribute(s:Node('trigger'),'begin','target.pointermove');assert(api:HasEvent('pointermove'),'Mutation recompiles event interests')
 s:Pointer('move',60,20);local count=#api.Events;s:Pointer('move',61,20)
 assert(#api.Events==count+1 and api.Events[#api.Events].Kind=='pointermove','Referenced pointermove fires even without a script listener or hover change')
 s:SetAttribute(s:Node('trigger'),'end','target.pointerup');assert(api:HasEvent('pointerup'),'End timing mutations update event interests')
 api:BeginElement(s:Node('trigger'),.6);assert(api.Items[1].Starts[#api.Items[1].Starts]==.6,'Manual begin is independent of event filtering');s:Destroy()
 for _,source in Sources.Cases do
  s=make(source);seek(s,.5);table.insert(all.Scenes,s.Scene)
  for _,t in {0,.25,.5,.75,1,1.25} do seek(s,t) end
  s:Destroy()
 end
 print('SVG S39/S40: clocks, repeat boundaries, seek/freeze, interpolation, additive values, transforms, motion cache, event/syncbase starts, CSS keyframes/transitions and base DOM preservation passed')
 return all
end
