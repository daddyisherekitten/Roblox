--!strict
-- Count native-style property assignments on retained grid/table surfaces.
return function(Parser,Node,loadRenderTree,loadWordLayout,loadBlockLayout,UDim2)
	local originalOffset=UDim2.fromOffset
	local valueType={__eq=function(a,b)return a[1]==b[1]and a[2]==b[2]end}
	UDim2.fromOffset=function(x,y)return setmetatable({x,y},valueType)end
	local ok,message=pcall(function()
		local allocated,writes=0,{}
		local function create(class,parent,properties)
			allocated+=1
			local values=table.clone(properties);values.Parent,values.ClassName=parent,class
			local gui
			gui=setmetatable({}, {__index=values,__newindex=function(_,key,value)
				local counts=writes[gui]or{};writes[gui]=counts;counts[key]=(counts[key]or 0)+1;values[key]=value
			end})
			values.Destroy=function()values.Parent=nil end
			values.IsA=function(_,kind)return kind==class or kind=='GuiObject'end
			return gui
		end
		local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*5,Y=size}end}}
		overrides['Layout/WordLayout']=loadWordLayout(overrides)
		local layout,renderer=loadBlockLayout(overrides),loadRenderTree({create=create,modifier=create})
		local document=Parser.parse('<div id="grid" style="display:grid;grid-template-columns:1fr 1fr;gap:10px"><div id="first" style="height:20px"></div><div id="second" style="height:30px"></div></div><table id="table" style="width:100%"><tbody id="group"><tr id="row1"><td style="height:10px"></td><td></td></tr><tr id="row2"><td style="height:20px"></td><td></td></tr></tbody></table>')
		local tree=renderer.build(document,{},error)
		local function box(id)return assert(tree.NodeBoxes[Node.findById(document,id)],id)end
		local first,second,group,row1,row2=box('first'),box('second'),box('group'),box('row1'),box('row2')
		local kept={first.Gui,second.Gui,group.Gui,row1.Gui,row2.Gui}
		local function arrange(width)layout.arrange(tree,width,0,0,function()return true end)end
		arrange(300)
		local before=allocated
		table.clear(writes);arrange(300)
		local function count(gui,key)return writes[gui]and writes[gui][key]or 0 end
		local gridWrites=count(first.Gui,'Position')+count(first.Gui,'ZIndex')+count(second.Gui,'Position')+count(second.Gui,'ZIndex')
		local tableWrites=0
		for _,box in {group,row1,row2}do tableWrites+=count(box.Gui,'Position')+count(box.Gui,'Size')end
		print('Layout paint writes: unchanged 2 grid children Position/ZIndex='..gridWrites..'; unchanged table group/2 rows Position/Size='..tableWrites)
		assert(gridWrites==0 and tableWrites==0,'Repeated equal geometry must not cross the GUI property boundary')
		assert(allocated==before,'Warm arrangement must retain all native surfaces')
		local oldX=second.LayoutX
		table.clear(writes);arrange(500)
		assert(second.LayoutX>oldX and count(second.Gui,'Position')>0 and count(group.Gui,'Size')>0,'Changed grid position and table width must still publish')
		first.Style.Order=2;second.Style.Order=1
		table.clear(writes);arrange(500)
		assert(first.Gui.ZIndex==2 and second.Gui.ZIndex==1 and count(first.Gui,'ZIndex')>0 and count(second.Gui,'ZIndex')>0,'Changed order must still publish its paint order')
		for index,box in {first,second,group,row1,row2}do assert(box.Gui==kept[index],'GUI identity changed')end
	end)
	UDim2.fromOffset=originalOffset
	assert(ok,message)
	print('Layout paint writes: actual layout, native-value equality, changed geometry/order and retained identity passed')
end
