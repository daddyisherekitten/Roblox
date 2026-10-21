--!strict
-- Owned geometry can copy dimension data; live resources/VM/native objects are
-- not traversed or admitted as measurement cache owners merely through Items.
return function(Measurement,Node)
 local checks=0;local function check(v,label)checks+=1;assert(v,label)end
 local face={Family='owner-font',Weight=400,Style='normal'}
 local function word(text)return{Kind='Word',Text=text,Style={Font='owner-font',TabularNums=false},FontFace=face,TextSize=12,MeasuredText=text,MeasuredSize=12,Glyphs={{Width=12,Height=12}}}end
 local owned,foreign=word('owned'),word('foreign');local fakeArray={Kind='array',Items={'string',37,foreign}};local fakeImage={Kind='foreign',ImageItem=word('foreign image')};local fakeMarker={Kind='foreign',Marker={Text='x',Width=10,Height=10,Size=12}}
 local vm={Kind='runtime',Items={'author array'},State=0};local reads=0;local trap=setmetatable({},{__index=function()reads+=1;error('Live owner read during pure measurement')end})
 local node=Node.element('img',{src='image.png'});node.ImageResourceState={Page={JavaScriptRuntime=vm},State=0}
 local item={Kind='Image',Style={},Node=node,AudioSession={Alive=true,CurrentHostLease={Page={JavaScriptRuntime=vm}},Trap=trap},VideoSelection={Specified=true,Owner={VM=vm},Trap=trap},ChildPage={Alive=true,JavaScriptRuntime=vm,Trap=trap},ImageResourceState=node.ImageResourceState,IntrinsicWidth=20,IntrinsicHeight=10}
 item.VideoSelection.Item=item
 local image={Kind='Image',Style={},IntrinsicWidth=8,IntrinsicHeight=4}
 local root={Kind='Block',Style={},Children={{Kind='Words',Style={},Items={owned,item}},{Kind='BlockImage',Style={},ImageItem=image,Children={}}},ForeignArray=fakeArray,ForeignImage=fakeImage,ForeignMarker=fakeMarker}
 for _,field in {'MotionRuntime','JavaScriptRuntime','CanvasRuntime','IFrameRuntime','NativeImageResources','NativeMediaResources','ResourceLoadHost','ImageMapIndex'}do root[field]={Items={'not geometry'},VM=vm,Trap=trap}end
 local context=Measurement.new(root,function()return true end)
 check(not context.Aborted and reads==0,'Pure graph construction never reads traps inside live resource owners')
 check(context.Copies[vm]==nil and context.Copies[trap]==nil and context.Copies[item.AudioSession]==nil and context.Copies[item.VideoSelection]==nil and context.Copies[item.ChildPage]==nil and context.Copies[node.ImageResourceState]==nil,'No live VM, audio/video lease, iframe child or IMG resource record enters copied measurement graph')
 local probe=context.Root.Children[1].Items[2]
 check(probe.AudioSession==item.AudioSession and probe.VideoSelection==item.VideoSelection and probe.ChildPage==item.ChildPage and probe.ImageResourceState==item.ImageResourceState and probe.Node==node,'Opaque read-only owner/DOM references preserve their exact identity')
 for _,field in {'MotionRuntime','JavaScriptRuntime','CanvasRuntime','IFrameRuntime','NativeImageResources','NativeMediaResources','ResourceLoadHost','ImageMapIndex'}do check(context.Root[field]==nil,'Nongeometry runtime omitted '..field)end
 check(#context.Items==3 and #context.Markers==0,'Only owned Words items and BlockImage image enter publication registries')
 local registrations={};for _,pair in context.Items do registrations[pair.Original]=true end
 check(registrations[owned]and registrations[item]and registrations[image]and not registrations[foreign]and not registrations[fakeImage.ImageItem],'Foreign array/image records are never geometry-cache owners')
 local ownedProbe=context.Root.Children[1].Items[1];ownedProbe.MeasuredText='new measurement';ownedProbe.MeasuredSize=18;ownedProbe.TextSize=18;ownedProbe.Glyphs[1].Width=18;ownedProbe.Glyphs[1].Height=18
 context.Root.Children[2].ImageItem.IntrinsicWidth=16
 context.Root.ForeignArray.Items[3].MeasuredSize=99;context.Root.ForeignImage.ImageItem.IntrinsicWidth=99;context.Root.ForeignMarker.Marker.Width=99
 context:KeepMeasurements()
 check(owned.MeasuredSize==18 and owned.NativeGlyphBounds.Bounds[1].Width==18 and owned.Glyphs[1].Width==12,'Actual owned new glyph cache publishes without changing retained glyph paint')
 check(image.IntrinsicWidth==16,'Actual BlockImage intrinsic measurement publishes')
 check(foreign.MeasuredSize==12 and fakeImage.ImageItem.IntrinsicWidth==nil and fakeMarker.Marker.Width==10 and fakeMarker.Marker.NativeMarkerBounds==nil,'Foreign Items, ImageItem and Marker containers do not publish into live objects')
 check(reads==0 and vm.State==0 and node.ImageResourceState.State==0 and item.AudioSession.Alive and item.ChildPage.Alive and item.VideoSelection.Item==item,'Cache publication does not read or change live VM/resource ownership')
 local actualMarker={Text='x',Width=10,Height=10,Size=12};local markers=Measurement.new({Kind='Block',Style={},Marker=actualMarker,Children={}},function()return true end);check(#markers.Markers==1 and markers.Root.Marker.MeasureOnly,'Actual block marker remains in the pure marker registry');markers:KeepMeasurements();check(actualMarker.NativeMarkerBounds.Width==10,'Actual measured block marker cache still publishes')
 local blockImageMarker={Text='image marker',Width=14,Height=12,Size=12}
 local imageMarkers=Measurement.new({Kind='BlockImage',Style={},ImageItem={Kind='Image',Style={},IntrinsicWidth=8,IntrinsicHeight=4},Marker=blockImageMarker,Children={}},function()return true end)
 check(#imageMarkers.Markers==1 and imageMarkers.Root.Marker.MeasureOnly,'Actual BlockImage promotion/list-item marker remains an owned pure marker')
 imageMarkers:KeepMeasurements();check(blockImageMarker.NativeMarkerBounds.Text=='image marker'and blockImageMarker.NativeMarkerBounds.Width==14,'Actual BlockImage marker/font cache still publishes')
 -- Native Instances throw on unknown properties; ordinary table hosts used to
 -- conceal a LayoutParent lookup in the graph's second linking pass.
 local unsafeNativeReads=0
 local function native(class)
  return setmetatable({ClassName=class,Name='retained',Position=UDim2.fromOffset(3,7),Size=UDim2.fromOffset(20,12),Visible=true,
   IsA=function(_,kind)return kind==class or kind=='GuiObject'end,Destroy=function()error('Live native destruction during measurement')end},
   {__index=function(_,key)if key=='Family'or key=='Kind'then return nil end;if key=='LayoutParent'then unsafeNativeReads+=1 end;error('Invalid native member '..tostring(key))end})
 end
 local textLabel,frame,imageLabel=native('TextLabel'),native('Frame'),native('ImageLabel')
 local textItem=word('retained');textItem.Glyphs[1].Gui=textLabel
 local nativeRoot={Kind='Block',Style={},Gui=frame,Children={}}
 local nativeWords={Kind='Words',Style={},Items={textItem},LayoutParent=nativeRoot};table.insert(nativeRoot.Children,nativeWords)
 local nativeImage={Kind='BlockImage',Style={},Gui=imageLabel,ImageItem={Kind='Image',Style={},IntrinsicWidth=20,IntrinsicHeight=12},LayoutParent=nativeRoot,Children={}}
 table.insert(nativeRoot.Children,nativeImage)
 local nativeContext=Measurement.new(nativeRoot,function()return true end)
 check(unsafeNativeReads==0,'No synthetic LayoutParent access on native GUI surfaces')
 check(nativeContext.Root.Children[1].LayoutParent==nativeContext.Root and nativeContext.Root.Children[2].LayoutParent==nativeContext.Root,'Actual layout boxes retain their copied parent links')
 for _,surface in {textLabel,frame,imageLabel}do
  local copied=nativeContext.Copies[surface];check(copied~=nil and copied~=surface,'Each native surface has an inert value record')
  check(copied.LayoutParent==nil and copied.Position==surface.Position and copied.Size==surface.Size,'GUI geometry copies without synthetic parents or live writes')
 end
 nativeContext:KeepMeasurements();check(unsafeNativeReads==0 and textItem.Glyphs[1].Gui==textLabel,'Cache publication retains the actual label and never reads its synthetic parent')
 local external={Kind='Block',Style={}};local child={Kind='Block',Style={},Children={},LayoutParent=external}
 local detached=Measurement.new(child,function()return true end);check(detached.Root.LayoutParent==external,'A real layout parent outside the copied subtree retains its original geometry reference')
 print('MEASUREMENT_OWNER_SUMMARY','assertions='..checks,'ownedItems='..#context.Items,'foreignItems=0','liveOwnerReads='..reads,'invalidNativeParentReads='..unsafeNativeReads)
end
