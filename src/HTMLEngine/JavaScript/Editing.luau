--!strict
-- Native input is a proposal. Edit the live Range, keeping the surrounding
-- inline DOM and all retained nodes/listeners rather than replacing innerHTML.
local Strings=require(script.Parent.Strings)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local EditingHost=require(script.Parent.Parent.DOM.EditingHost)
local Editing={}
local HTML="http://www.w3.org/1999/xhtml"
local BLOCKS={div=true,p=true,li=true,blockquote=true,pre=true,h1=true,h2=true,h3=true,h4=true,h5=true,h6=true}
Editing.state=EditingHost.state
Editing.host=EditingHost.host
Editing.isEditable=EditingHost.isEditable
-- UTF-16 projection with exact boundary mappings. BR and block boundaries
-- contribute line breaks; contenteditable=false islands are protected.
function Editing.project(host: any,step: any?): any
	local parts,segments,positions,units={}, {}, {}, 0
	local function add(text,sn,so,en,eo,locked)
		local length=Strings.length(text)
		if length>0 then table.insert(parts,text);table.insert(segments,{Start=units,Finish=units+length,Text=text,StartNode=sn,StartOffset=so,EndNode=en,EndOffset=eo,Locked=locked})end
		units+=length;assert(units<=65536,"Editable text budget exceeded")
	end
	local frames={{Node=host,Index=1,Locked=false,Started=false}};local count=0
	while #frames>0 do
		if step then step()end;count+=1;assert(count<=32768,"Editable node budget exceeded")
		local frame=frames[#frames];local node=frame.Node
		if not frame.Started then
			frame.Started=true;positions[node]={Start=units,Children={[0]=units}}
			if node.Kind=="Text"or node.Kind=="CDATASection"then add(node.Text,node,0,node,Strings.length(node.Text),frame.Locked);positions[node].Finish=units;table.remove(frames);continue end
			if node.Kind=="Element"and node.Name=="br"then
				local parent=node.Parent;local at=table.find(parent.Children,node)-1;add("\n",parent,at,parent,at+1,frame.Locked)
				positions[node].Finish=units;table.remove(frames);continue
			end
		end
		local child=node.Children and node.Children[frame.Index]
		if not child then positions[node].Finish=units;table.remove(frames);continue end
		local at=frame.Index-1;frame.Index+=1
		local previous=node.Children[at]
		if units>0 and previous and((child.Kind=="Element"and BLOCKS[child.Name])or(previous.Kind=="Element"and BLOCKS[previous.Name]))then
			local last=parts[#parts];if not last or last:sub(-1)~="\n"then add("\n",node,at,node,at,frame.Locked)end
		end
		positions[node].Children[at]=units
		local locked=frame.Locked or(child.Kind=="Element"and Editing.state(child)=="false")
		table.insert(frames,{Node=child,Index=1,Locked=locked,Started=false})
	end
	for node,position in positions do if node.Children then position.Children[#node.Children]=position.Finish end end
	return {Text=table.concat(parts),Length=units,Segments=segments,Positions=positions,Host=host}
end
function Editing.point(projection: any,offset: number,forward: boolean?): (any,number)
	offset=math.clamp(offset,0,projection.Length)
	for _,segment in projection.Segments do
		if offset<segment.Finish or(offset==segment.Finish and not forward)then
			if segment.StartNode==segment.EndNode and(segment.StartNode.Kind=="Text"or segment.StartNode.Kind=="CDATASection")then return segment.StartNode,segment.StartOffset+offset-segment.Start end
			return if offset<=segment.Start then segment.StartNode else segment.EndNode,if offset<=segment.Start then segment.StartOffset else segment.EndOffset
		end
	end
	local last=projection.Segments[#projection.Segments]
	if last then return last.EndNode,last.EndOffset end
	return projection.Host,#projection.Host.Children
end
function Editing.offset(projection: any,node: any,offset: number): number?
	local position=projection.Positions[node];if not position then return nil end
	if node.Kind=="Text"or node.Kind=="CDATASection"then return position.Start+math.clamp(offset,0,position.Finish-position.Start)end
	return position.Children[offset]
end
local function diff(before: string,after: string): (number,number,string)
	local old,new=Strings.units(before),Strings.units(after);local first=0
	while first<#old and first<#new and old[first+1]==new[first+1]do first+=1 end
	local suffix=0;while suffix<#old-first and suffix<#new-first and old[#old-suffix]==new[#new-suffix]do suffix+=1 end
	-- Never split a surrogate pair when a native UTF-8 proposal changes it.
	if first>0 and old[first]>=0xd800 and old[first]<=0xdbff then first-=1 end
	local inserted={};for i=first+1,#new-suffix do table.insert(inserted,new[i])end
	return first,#old-suffix,Strings.fromUnits(inserted)
end
function Editing.install(vm: any,options: any): any
	local VM=vm.Model;local bridge,ranges,selection=options.DOM,options.Ranges,options.Selection
	local context=bridge.RangeContext();local api={Alive=true}
	local function check()assert(api.Alive and vm.Alive,"Content editing disposed")end
	local function rangeCall(range,key,args)return vm:Call(vm.Get(range,key),args or{},range)end
	local function connected(host)return ShadowTree.Connected(host,options.Document)end
	local function emit(host,kind,data,targetRange)
		if options.Emit then return options.Emit(host,kind,data,targetRange)end;return true
	end
	function api:Get(node,key)
		if key=="isContentEditable"and node.Kind=="Element"then return true,Editing.isEditable(node)end
		if key=="designMode"and node.Kind=="Document"then return true,node.DesignMode or"off"end
		return false
	end
	function api:Set(node,key,value)
		if node.Kind=="Document"and key=="designMode"then
			local primitive=vm.ToPrimitive(value,"string");if type(primitive)=="table"and primitive.Kind=="symbol"then VM.throw(VM.error("TypeError","Cannot convert Symbol to DOMString"))end
			local mode=VM.string(primitive):lower()
			if(mode=="on"or mode=="off")and mode~=(node.DesignMode or"off")then node.DesignMode=mode;if options.Changed then options.Changed(node)end end
			return true
		end;return false
	end
	function api:Host(node)return Editing.host(node)end
	function api:Snapshot(host)
		check();local projection=Editing.project(host,vm.Step);local snapshot=selection:Snapshot();projection.Selection=snapshot
		if snapshot then projection.Cursor=Editing.offset(projection,snapshot.FocusNode,snapshot.FocusOffset);projection.Anchor=Editing.offset(projection,snapshot.AnchorNode,snapshot.AnchorOffset)end
		return projection
	end
	function api:Select(host,cursor,anchor)
		check();if not connected(host)or Editing.host(host)~=host then return false end
		local projection=Editing.project(host,vm.Step);local fn,fo=Editing.point(projection,cursor,true);local an,ao=Editing.point(projection,anchor or cursor,true)
		selection:SetRaw(an,ao,fn,fo);return true
	end
	function api:Navigate(host,extend,direction,granularity)
		check();if not connected(host)or Editing.host(host)~=host then return false end
		local before=selection:Snapshot();if not before or Editing.host(before.FocusNode)~=host then return false end
		vm:Call(vm.Get(selection.Value,"modify"),{if extend then "extend"else "move",direction,granularity},selection.Value)
		local after=selection:Snapshot();if not after then return false end
		if Editing.host(after.FocusNode)~=host then
			local projection=Editing.project(host,vm.Step);local offset=Editing.offset(projection,after.FocusNode,after.FocusOffset)
			local forward=direction=="forward"or direction=="right"
			if offset then
				for _,segment in projection.Segments do if segment.Locked and offset>=segment.Start and offset<=segment.Finish then offset=if forward then segment.Finish else segment.Start end end
			else offset=if forward then projection.Length else 0 end
			local node,at=Editing.point(projection,offset,forward)
			if Editing.host(node)~=host then node,at=host,if forward then #host.Children else 0 end
			if extend then selection:SetRaw(before.AnchorNode,before.AnchorOffset,node,at)else selection:SetRaw(node,at,node,at)end
		end;return true
	end
	local function paragraph(host,range)
		local state=ranges.State(range);local block=state.StartNode
		while block and block~=host and not(block.Kind=="Element"and BLOCKS[block.Name])do block=block.Parent end
		block=block or host;local tail=ranges.New(state.StartNode,state.StartOffset,block,#block.Children)
		local fragment=bridge.Unwrap(rangeCall(tail,"extractContents"))
		local nextBlock=if block~=host then context.Clone(block,false)else context.Element("div",HTML)
		if nextBlock.Attributes.id then nextBlock.Attributes.id=nil end
		context.Insert(nextBlock,fragment,nil);if #nextBlock.Children==0 then context.Insert(nextBlock,context.Element("br",HTML),nil)end
		if block==host then context.Insert(host,nextBlock,nil)
		else local parent=block.Parent;context.Insert(parent,nextBlock,parent.Children[table.find(parent.Children,block)+1]);if #block.Children==0 then context.Insert(block,context.Element("br",HTML),nil)end end
		local caret=nextBlock;while caret.Children and caret.Children[1]and caret.Children[1].Kind~="Element"do caret=caret.Children[1]end
		selection:SetRaw(caret,0,caret,0)
	end
	function api:Commit(host,proposed,inputType,cursor,anchor)
		check();if type(proposed)~="string"or #proposed>65536 or not connected(host)then return false end
		local owner,mode=Editing.host(host);if owner~=host then return false end
		local projection=Editing.project(host,vm.Step);if proposed==projection.Text then return self:Select(host,cursor or projection.Length,anchor)end
		local first,last,inserted=diff(projection.Text,proposed)
		for _,segment in projection.Segments do
			if segment.Locked and((first<segment.Finish and last>segment.Start)or(first==last and first>segment.Start and first<segment.Finish))then return false end
		end
		local originalSelection=selection:Snapshot()
		local sn,so=Editing.point(projection,first,true);local en,eo
		if first==last and originalSelection and originalSelection.StartNode==originalSelection.EndNode and originalSelection.StartOffset==originalSelection.EndOffset
			and Editing.offset(projection,originalSelection.StartNode,originalSelection.StartOffset)==first then sn,so=originalSelection.StartNode,originalSelection.StartOffset end
		if first==last then en,eo=sn,so else en,eo=Editing.point(projection,last,false)end
		if Editing.host(sn)~=host or Editing.host(en)~=host then return false end
		local range=ranges.New(sn,so,en,eo)
		inputType=inputType or(if inserted~=""then"insertText"else"deleteContentBackward")
		local event={inputType=inputType,data=if inputType=="insertText"or inputType=="insertReplacementText"then inserted else VM.Null,isComposing=false,composed=true,bubbles=true,cancelable=true}
		local targetRange=ranges.NewStatic(ranges.State(range))
		if not emit(host,"beforeinput",event,targetRange)then return false end
		-- A synchronous handler owns its changes. Do not overwrite a changed
		-- subtree, host state or selection using the previous native snapshot.
		local nextOwner,nextMode=Editing.host(host)
		if not api.Alive or not connected(host)or nextOwner~=host or nextMode~=mode or Editing.project(host,vm.Step).Text~=projection.Text then return false end
		local now=selection:Snapshot()
		if originalSelection and(not now or now.AnchorNode~=originalSelection.AnchorNode or now.AnchorOffset~=originalSelection.AnchorOffset or now.FocusNode~=originalSelection.FocusNode or now.FocusOffset~=originalSelection.FocusOffset)then return false end
		rangeCall(range,"deleteContents");ranges.Collapse(range,true)
		if inserted~=""then
			if inputType=="insertParagraph"and mode~="plaintext-only"and inserted=="\n"then paragraph(host,range)
			elseif inputType=="insertLineBreak"and mode~="plaintext-only"and inserted=="\n"then
				local br=context.Element("br",HTML);rangeCall(range,"insertNode",{bridge.Wrap(br)});local at=table.find(br.Parent.Children,br);selection:SetRaw(br.Parent,at,br.Parent,at)
			else
				local state=ranges.State(range)
				if state.StartNode.Kind=="Text"then
					local node,offset=state.StartNode,state.StartOffset+Strings.length(inserted);context.ReplaceData(node,state.StartOffset,0,inserted);selection:SetRaw(node,offset,node,offset)
				else local text=context.Text(inserted);rangeCall(range,"insertNode",{bridge.Wrap(text)});selection:SetRaw(text,Strings.length(inserted),text,Strings.length(inserted))end
			end
		else local state=ranges.State(range);selection:SetRaw(state.StartNode,state.StartOffset,state.StartNode,state.StartOffset)end
		event.cancelable=false;emit(host,"input",event,nil);return true
	end
	function api:Destroy()self.Alive=false;table.clear(options)end
	return api
end
return Editing
