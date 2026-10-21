--!strict
return function(Parser, DOM, State, Model, Events, Popup, loadRenderTree, loadWordLayout, loadBlockLayout)
	local source='<form id="f"><select id="s" name="choice"><option value="plain">Ohne Gruppe<optgroup label="Verfügbar"><option value="a">Alpha<option value="b" selected>Beta<optgroup label="Gesperrt" disabled><option value="c">Bravo<option value="d" disabled>Delta<optgroup label="Leere Gruppe"></optgroup><option value="end">Ende</select></form>'
	local doc=Parser.parse(source)
	assert(#doc.Diagnostics == 0,'Optional option and optgroup end tags must preserve sibling groups')
	local c=State.create(DOM.findById(doc,'s'))
	assert(#c.Options == 6 and #c.SelectRows == 9 and c.SelectedIndex == 3 and c.Value == 'b')
	assert(c.Options[4].Disabled and c.Options[5].Disabled and not c.Options[6].Disabled)
	assert(not c.Options[1].Grouped and c.Options[2].Grouped and not c.Options[6].Grouped)
	assert(c.SelectRows[2].IsGroup and c.SelectRows[2].Caption == 'Verfügbar')
	assert(c.SelectRows[8].IsGroup and c.SelectRows[8].Caption == 'Leere Gruppe')
	local function signal()
		return {Connect=function(_,fn) return {Disconnect=function() end,Callback=fn} end}
	end
	local objects={}
	local function axis(v,i,size)
		if not v then return 0 end
		return v[i]+(v[if i == 1 then 'XScale' else 'YScale'] or 0)*size
	end
	local factory={}
	function factory.create(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton' and class ~= 'TextBox')
		local g=table.clone(props); g.Parent=parent; g.Active=false; g.Visible=true
		local p=if parent then parent.AbsolutePosition else Vector2.new(0,0)
		local s=if parent then parent.AbsoluteSize else Vector2.new(0,0)
		g.AbsolutePosition=Vector2.new(p.X+axis(props.Position,1,s.X),p.Y+axis(props.Position,2,s.Y))
		g.AbsoluteSize=Vector2.new(axis(props.Size,1,s.X),axis(props.Size,2,s.Y))
		function g:Destroy() self.Destroyed=true end
		function g:GetPropertyChangedSignal() return signal() end
		table.insert(objects,g); return g
	end
	factory.modifier=function(_,_,props) return table.clone(props) end
	local parent=factory.create('Frame',nil,{Size=UDim2.fromOffset(400,500)})
	local root=factory.create('ScrollingFrame',parent,{Size=UDim2.fromOffset(400,500)})
	local tree=loadRenderTree(factory).build(doc,root,error,function(_,weight) return if weight == 700 then 'bold' else 'regular' end)
	local measured=0
	local overrides={['Layout/TextMeasure']={measure=function(text,face,size)
		measured+=1
		return {X=#text*(if face == 'bold' then 9 else 5),Y=size}
	end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	blocks.arrange(tree,400,0,0,function() return true end)
	c=tree.Controls[1]
	assert(c.Item.GroupFontFace == 'bold')
	assert(c.Item.IntrinsicWidth == #'Leere Gruppe'*9+18,'Intrinsic width includes bold group headings')
	local initialWidth=c.Item.IntrinsicWidth
	local events=Events.new(error)
	local changes=0
	events:On(nil,'change',function() changes+=1 end)
	local model=Model.new(doc,{c},events,function(_,layout) assert(not layout) end)
	local page={Alive=true,Root=root}
	local popup=Popup.new(page,function(control,index) model:Select(control,index,true) end,factory,function() return 0 end)
	c.Item.BoxGui.AbsolutePosition=Vector2.new(20,20); c.Item.BoxGui.AbsoluteSize=Vector2.new(initialWidth,21)
	local function live(name)
		for i=#objects,1,-1 do
			local g=objects[i]
			if g.Name == name then
				local p=g; while p and not p.Destroyed do p=p.Parent end
				if not p then return g end
			end
		end
	end
	local function click(name)
		local g=assert(live(name))
		local event={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(g.AbsolutePosition.X+1,g.AbsolutePosition.Y+1)}
		popup:Begin(event,{g}); popup:Finish(event,{g})
	end
	popup:Open(c)
	assert(live('GroupText_2').FontFace == 'bold' and live('GroupText_2').Text == 'Verfügbar')
	assert(live('GroupText_5').TextColor3 == Color3.fromRGB(153,153,153))
	assert(live('OptionText_2').Position[1] == 15 and live('OptionText_1').Position[1] == 3)
	assert(live('Option_2').Position[2] == 40 and live('Option_6').Position[2] == 160)
	assert(live('Option_2').Size.XScale == 1 and live('Option_2').Size[1] == 0,'Highlight spans the full indented row')
	assert(live('Option_3').BackgroundTransparency == 0 and live('Option_3').BackgroundColor3 == Color3.fromRGB(0,117,255),
		'Standard select highlights use the native blue selection color')
	assert(live('Options').CanvasSize[2] == 180 and live('SelectPopup').Size[2] == 162)
	click('Group_2'); assert(popup.Control == c and c.Value == 'b' and changes == 0,'Group captions are not selectable')
	click('Option_4'); assert(popup.Control == c and c.Value == 'b' and changes == 0,'Disabled groups cannot be picked')
	popup:MoveSelection(c,1)
	assert(popup.Highlight == 6 and c.Value == 'b','Arrows skip disabled groups and headings')
	assert(live('Options').CanvasPosition.Y == 20,'Reveal uses visual rows including all headings')
	popup:MoveSelection(c,-1); assert(popup.Highlight == 3)
	popup:Type(c,'B'); assert(popup.Highlight == 3,'Typeahead skips the disabled Bravo option')
	popup:ResetSearch(); popup:Type(c,'V'); assert(popup.Highlight == 3,'Group labels are excluded from typeahead')
	popup:ResetSearch(); popup:Type(c,'A'); popup:Commit()
	assert(c.Value == 'a' and c.Caption == 'Alpha' and changes == 1 and not live('SelectPopup'))
	assert(model:Data(c.Form)[1].Value == 'a','Only option values are submitted')
	local before=measured
	blocks.arrange(tree,400,0,0,function() return true end)
	assert(c.Item.IntrinsicWidth == initialWidth and measured == before,'Grouped selects keep their measured width after selection')
	model:Reset(c.Form); assert(c.Value == 'b' and c.SelectedIndex == 3 and changes == 1)
	model:SetValue(c,'c'); assert(c.Value == 'c' and #model:Data(c.Form) == 0,'Programmatically selected disabled options are excluded from form data')
	popup:Open(c); popup:Close(); assert(not live('Group_2'))
	local empty=State.create(DOM.findById(Parser.parse('<select id="s"><optgroup label="Leer"></optgroup></select>'),'s'))
	empty.Item=c.Item; popup:Open(empty)
	assert(live('Group_1') and popup.Highlight == 0)
	popup:Commit(); assert(empty.Value == '' and empty.SelectedIndex == 0)
	local groupedDoc=Parser.parse('<form><select id="s" name="choice" required style="display:block"><optgroup label="X"><option value="" selected>Long grouped option</option></optgroup></select></form>')
	local groupedTree=loadRenderTree(factory).build(groupedDoc,root,error,function(_,weight) return if weight == 700 then 'bold' else 'regular' end)
	blocks.arrange(groupedTree,400,0,0,function() return true end)
	local grouped=groupedTree.Controls[1]
	assert(grouped.Item.GroupFontFace == 'bold' and grouped.Item.IntrinsicWidth == #'Long grouped option'*5+12+18,
		'Block selects include the option indent in their intrinsic width too')
	local submitted=0
	local groupedEvents=Events.new(error); groupedEvents:On(nil,'submit',function() submitted+=1 end)
	local groupedModel=Model.new(groupedDoc,{grouped},groupedEvents,function() end)
	groupedModel:Submit(grouped.Form)
	assert(submitted == 1 and groupedModel:Data(grouped.Form)[1].Value == '',
		'A first option inside a group is not the required-select placeholder')
	popup:Open(c)
	local host,scroll=live('SelectPopup'),live('Options')
	local row,label=live('Option_2'),live('OptionText_2');local option=c.Options[2]
	local first=c.Options[1];c.Options[1],c.Options[2]=option,first
	option.OptionIndex,first.OptionIndex=1,2
	option.Caption='Changed caption';c.SelectRows={option,first}
	c.SelectedIndex=1;popup:Refresh()
	assert(live('SelectPopup')==host and live('Options')==scroll and not row.Destroyed and not label.Destroyed,
		'Popup mutations preserve their native host, scroll and retained option rows')
	assert(label.Text=='Changed caption' and row.Position[2]==0 and popup:Hit({row},Vector2.new(host.AbsolutePosition.X+2,host.AbsolutePosition.Y+2))==1,
		'Popup captions and hit indices track reordered DOM options')
	c.Options={first};first.OptionIndex=1;c.SelectRows=c.Options;c.SelectedIndex=1;popup:Refresh()
	assert(row.Destroyed and popup.Control==c,'Only removed popup rows are destroyed')
	popup:Close()
	print('Optgroups: parsing, headings, disabled groups, indentation, bold widths, mouse, keyboard, reveal, values, reset and cleanup passed')
end
