--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- Form DOM state shares the renderer's control records. Adapters perform native
-- painting/focus/activation; attribute writes always pass through DOM validation.
local Node=require(script.Parent.Parent.DOM.Node)
local FormOwner=require(script.Parent.Parent.DOM.FormOwner)
local State=require(script.Parent.Parent.Controls.State)
local Defaults=require(script.Parent.Parent.Controls.Defaults)
local SelectOptions=require(script.Parent.Parent.Controls.SelectOptions)
local SelectTree=require(script.Parent.Parent.HTML.SelectTree)
local TextValue=require(script.Parent.Parent.Controls.TextValue)
local NumberValue=require(script.Parent.Parent.Controls.NumberValue)
local Eligibility=require(script.Parent.Parent.Controls.ValidationEligibility)
local Validity=require(script.Parent.Parent.Controls.Validity)
local Messages=require(script.Parent.Parent.Controls.ValidationMessage)
local VM=require(script.Parent.VM)
local Strings=require(script.Parent.Strings)
local TextSelection=require(script.Parent.Parent.Controls.TextSelection)
local TextSelectionAPI=require(script.Parent.TextControlSelection)
local Temporal=require(script.Parent.Parent.Controls.TemporalValue)
local InputValues=require(script.Parent.InputValues)
local Controls={}
local AttributeValues=require(script.Parent.Parent.HTML.AttributeValues)
local SelectedContent=require(script.Parent.Parent.HTML.SelectedContent)
local Directionality=require(script.Parent.Parent.CSS.Directionality)
local FORM_ASSOCIATED={input=true,textarea=true,select=true,button=true,output=true,fieldset=true,object=true}
local BOOL={disabled="disabled",readOnly="readonly",required="required",multiple="multiple"}
local STRINGS={name="name",placeholder="placeholder",min="min",max="max",step="step",pattern="pattern"}
local function reflects(node,key)
	local name=ElementNames.htmlName(node)
	if key=="disabled" then return name=="input" or name=="textarea" or name=="select" or name=="button" or name=="fieldset" or name=="option" or name=="optgroup"
	elseif key=="readOnly" then return name=="input" or name=="textarea"
	elseif key=="required" then return name=="input" or name=="textarea" or name=="select"
	elseif key=="multiple" then return name=="input" or name=="select"
	elseif key=="name" then return FORM_ASSOCIATED[name] or name=="form"
	elseif key=="placeholder" then return name=="input" or name=="textarea"
	else return name=="input" end
end
local CURRENT_FIELDS={"Value","Checked","EditText","BadInput","UserEdited","UserInvalid","SelectedIndex","SelectedIndices","TemporalParts","TemporalSegment","TemporalDigits","Files","ImagePoint",
	"DOMDirtyValue","DOMDirtyChecked","DOMCustomValidity","Indeterminate","SelectionStart","SelectionEnd","SelectionDirection","SelectionValue"}
local html=ElementNames.html
local function internals(node)
	local definition=node.CustomElementDefinition
	return if definition and definition.FormAssociated and definition.API then definition.API.Internals else nil
end
local function valueMode(kind)return kind~="checkbox" and kind~="radio" and kind~="hidden" and kind~="submit" and kind~="reset" and kind~="button" and kind~="image" and kind~="file" end
local function root(node)while node.Parent do node=node.Parent end;return node end
local function walk(node,callback)
	local pending={node};while #pending>0 do
		local current=table.remove(pending);callback(current)
		for index=#current.Children,1,-1 do table.insert(pending,current.Children[index]) end
	end
end
local function ancestor(node,name)
	local current=node.Parent;while current do if ElementNames.htmlName(current)==name then return current end;current=current.Parent end
	return nil
end
local owner=FormOwner.resolve
local function errorValue(name,message)VM.throw(VM.error(name,message))end
local function signedLong(value)
	local n=VM.number(value);if n~=n or n==math.huge or n==-math.huge then return 0 end
	n=(if n<0 then math.ceil(n) else math.floor(n))%4294967296
	return if n>=2147483648 then n-4294967296 else n
end
function Controls.new(document: any,host: any): any
	local records,options,views,alive={},{},{},true
	local bindings={}
	local bridge={}
	local selection
	local updateSelected
	local mirrorHooks,synchronizing={},{}
	local namedForms=setmetatable({},{__mode='k'})
	local namedRevision=0
	local eventConnection
	local function check()assert(alive,"Document has been disposed")end
	local function notify(node,kind)local changed=host.ControlChanged or host.NotifyChanged;if changed then changed(node,kind) end end
	local function record(node)
		local native=if host.ResolveControl then host.ResolveControl(node) else nil
		local entry=records[node]
		if not entry then
			local c=native or State.create(node)
			if ElementNames.htmlName(node)=="textarea" and not native then c.Value=TextValue.sanitize("textarea",Node.textContent(node));c.DefaultValue=c.Value end
			entry={State=c,Native=native~=nil};records[node]=entry
		elseif native and entry.State~=native then
			-- RenderTree can replace records when a detached node is attached again.
			-- Preserve current state by identity, leaving new layout/configuration intact.
			if selection then selection:Unbind(entry.State)end
			if not native.DOMStateRestored then for _,field in CURRENT_FIELDS do native[field]=entry.State[field] end end
			entry.State=native;entry.Native=true
		elseif not native then entry.Native=false end
		local c=entry.State
		Directionality.bind(node,c)
		if ElementNames.htmlName(node)=='select'and not mirrorHooks[c]then
			local previous=c.UpdateSelectedContent
			local callback=function(force)if alive and updateSelected then updateSelected(node,c,force)end end
			mirrorHooks[c]={Previous=previous,Callback=callback};c.UpdateSelectedContent=callback
		end
		if selection then selection:Bind(node,c)end
		if c.UserEdited then c.DOMDirtyValue=true end
		c.Form=owner(node);c.Disabled=State.disabled(node)
		return c,entry
	end
	local function option(node)
		local entry=options[node]
		if not entry then entry={Selected=node.Attributes.selected~=nil,Dirty=false};options[node]=entry end
		return entry
	end
	local function selected(node)
		local c=record(node)
		for index,item in c.Options or {} do
			option(item.Node).Selected=if c.SelectMultiple then c.SelectedIndices[index]==true else c.SelectedIndex==index
		end
		return c
	end
	updateSelected=function(node,c,force)
		if synchronizing[node]or not bindings.Mirror then return end
		synchronizing[node]=true
		local ok,message=pcall(function()
			local option=c.Options and c.Options[c.SelectedIndex]
			SelectedContent.update(node,option and option.Node,bindings.Mirror.Clone,bindings.Mirror.Replace,force)
		end)
		synchronizing[node]=nil;if not ok then error(message,0)end
	end
	local function applySelection(node,c,indices,force)
		if c.SelectMultiple then SelectOptions.assignMultiple(c,indices)
		else local index=0;for i=1,#c.Options do if indices[i] then index=i;break end end;SelectOptions.assign(c,index,force) end
		c.ListActiveIndex=c.SelectedIndex
		for index,item in c.Options do option(item.Node).Selected=indices[index]==true end
		-- SelectOptions assignments update the same native record used by FormModel.
		notify(node,"selected")
	end
	local function refreshSelect(node,preserve,removedMultiple,resetSelection)
		local c,entry=record(node)
		if preserve and c.Options then
			if entry.SelectionSeen then selected(node)
			else for index,item in c.Options do
				local state=option(item.Node)
				if not state.Dirty then state.Selected=if c.SelectMultiple then c.SelectedIndices[index]==true else c.SelectedIndex==index end
			end end
		end
		entry.SelectionSeen=true
		local items,defaultIndex,rows,content,defaults=SelectOptions.read(node)
		-- An explicitly empty selection survives changes to labels, disabledness,
		-- option text and non-option children. Only an actual option-list change
		-- or a selectedness-reset trigger chooses the first enabled option again.
		local optionsChanged=#(c.Options or {})~=#items
		if not optionsChanged then for index,item in items do
			if c.Options[index].Node~=item.Node then optionsChanged=true;break end
		end end
		c.Options,c.SelectRows,c.SelectedContent=items,rows,content
		c.DefaultSelectedIndex,c.DefaultSelectedIndices=defaultIndex,defaults
		c.SelectMultiple=node.Attributes.multiple~=nil;c.Multiple=c.SelectMultiple
		c.SelectSize=math.clamp(AttributeValues.positive(node.Attributes.size,if c.SelectMultiple then 4 else 1),1,100)
		c.SelectList=c.SelectMultiple or c.SelectSize>1
		local indices,last={},nil
		for index,item in items do
			local state=option(item.Node)
			if not preserve then state.Selected=item.Node.Attributes.selected~=nil;state.Dirty=false end
			-- Removing multiple preserves the first selected option. Ordinary
			-- selectedness resets still retain the last selected option.
			if state.Selected then indices[index]=true;last=if removedMultiple then last or index else index end
		end
		if not c.SelectMultiple then
			indices={};if last then indices[last]=true
			elseif c.SelectSize==1 and (not preserve or optionsChanged or resetSelection) then
				for index,item in items do if not item.Disabled then indices[index]=true;break end end
			end
		end
		applySelection(node,c,indices,preserve~=true)
		c.DefaultValue=if items[defaultIndex] then items[defaultIndex].Value else ""
		return c
	end
	local function radioGroup(node,callback)
		local name=node.Attributes.name or "";if name=="" then return end
		local form=owner(node)
		walk(root(node),function(other)
			if other~=node and ElementNames.htmlName(other)=="input" and Defaults.kind(other)=="radio"
				and (other.Attributes.name or "")==name and owner(other)==form then callback(other) end
		end)
	end
	local function checked(node,value,dirty)
		local c,entry=record(node);if dirty then c.DOMDirtyChecked=true end
		if entry.Native and host.SetControlChecked and (c.Type=="checkbox" or c.Type=="radio") then host.SetControlChecked(node,value)
		else c.Checked=value;notify(node,"checked") end
		c.Checked=value
		if value and Defaults.kind(node)=="radio" then radioGroup(node,function(other)
			local peer=record(other);if peer.Checked then peer.Checked=false;notify(other,"checked") end
		end) end
	end
	local function value(node,text,dirty)
		local c,entry=record(node);if dirty then c.DOMDirtyValue=true end
		if c.Type=="file" then
			if text~="" then errorValue("InvalidStateError","File inputs can only be cleared") end
			c.Files={};c.Value="";notify(node,"value");return
		end
		TextSelection.ensure(c);local previous=c.Value
		if entry.Native and host.SetControlValue then host.SetControlValue(node,text)
		else
			if ElementNames.htmlName(node)=="textarea" then c.Value=TextValue.sanitize("textarea",text)
			elseif c.Type=="number" then c.Value=NumberValue.sanitize(text);c.EditText,c.BadInput=c.Value,false
			elseif Temporal.applies(c.Type) then c.Value=Temporal.sanitize(c.Type,text);c.TemporalParts,c.TemporalDigits,c.BadInput=nil,nil,false
			elseif c.Type=="range" or c.Type=="color" then
				local synthetic=Node.element("input",table.clone(node.Attributes));synthetic.Attributes.value=text
				c.Value=State.create(synthetic).Value
			else c.Value=TextValue.sanitize(c.Type,text,c.Multiple) end
			c.UserEdited=false;notify(node,"value")
		end
		TextSelection.valueChanged(c,false)
		if dirty and previous~=c.Value and TextSelection.selectable(node)then
			local length=Strings.length(c.Value)
			TextSelection.set(c,length,length,"none",false)
		end
		TextSelection.paint(c)
	end
	local function setAttribute(node,name,value)
		assert(bindings.Attribute,"DOMControls must be attached before reflecting attributes")
		bindings.Attribute(node,name,value)
	end
	local function dispatch(node,name,data)
		local eventOptions={Bubbles=name~="invalid",Cancelable=true}
		if host.EventDispatch then return host.EventDispatch(node,name,data,eventOptions) end
		return if host.Events then host.Events:Emit(node,name,data,eventOptions) else {DefaultPrevented=false}
	end
	local function cancelled(event)return event==false or (type(event)=="table" and (event.DefaultPrevented==true or event.defaultPrevented==true))end
	local function candidates(form)
		local result={};walk(root(form),function(node)
			local custom=internals(node)
			if node.Kind=="Element"and(FORM_ASSOCIATED[ElementNames.htmlName(node)]or custom)and(if custom then custom:Owner(node)else owner(node))==form then table.insert(result,node)end
		end);return result
	end
	local function indexedCandidates(form)
		local result={};for _,node in candidates(form)do if ElementNames.htmlName(node)~='input'or Defaults.kind(node)~='image'then table.insert(result,node)end end;return result
	end
	local function willValidate(node)
		local custom=internals(node);if custom then return custom:WillValidate(node)end
		if ElementNames.htmlName(node)~='input'and ElementNames.htmlName(node)~='textarea'and ElementNames.htmlName(node)~='select'and ElementNames.htmlName(node)~='button'then return false end
		return Eligibility.applies(node,record(node))
	end
	local function validity(node)
		local custom=internals(node);if custom then return custom:Validity(node)end
		local c=record(node)
		local values,reason=Validity.read(node,c,function(callback)radioGroup(node,function(peer)callback(record(peer))end)end,host.PatternMismatch)
		local message=if not willValidate(node)or values.valid then ""elseif values.customError then c.DOMCustomValidity else Messages.get(c,reason)
		return values,message
	end
	local function validate(node,report)
		local nodes=if ElementNames.htmlName(node)=="form" then candidates(node) else {node}
		local valid=true
		for _,candidate in nodes do if willValidate(candidate) then
			local custom=internals(candidate);if custom then if not custom:Check(candidate,report)then valid=false end;continue end
			local state,message=validity(candidate)
			if not state.valid then
				valid=false;local event=dispatch(candidate,"invalid",{Message=message})
				if report and not cancelled(event) and host.ReportValidity then host.ReportValidity(candidate,message) end
			end
		end end
		return valid
	end
	function bridge:Attach(wrap,attribute,text,collection,mirror)
		bindings.Wrap,bindings.Attribute,bindings.Text,bindings.Collection=wrap,attribute,text,collection
		bindings.Mirror=mirror
		for node,entry in records do if ElementNames.htmlName(node)=='select'then updateSelected(node,entry.State,false)end end
	end
	function bridge:State(node)check();return record(node)end
	function bridge:Validity(node)
		check();local vm=host.GetVM and host.GetVM()
		if host.NativeRead and not(vm and vm:IsExecutingOnCurrentThread())then
			return host.NativeRead(function()return validity(node)end)
		end
		return validity(node)
	end
	local function formNames(form)
		local function attribute(node,key)
			local info=node.AttributeNamespaces and node.AttributeNamespaces[key]
			return if info and info.Namespace and info.Namespace~=''then nil else node.Attributes[key]
		end
		local state=form.DOMFormNames
		if not state then state={Past={},NamedViews=setmetatable({},{__mode='v'})};form.DOMFormNames=state;namedForms[form]=true end
		if state.Revision~=namedRevision then
			state.Entries=indexedCandidates(form);state.Names={};state.Images={};state.Revision=namedRevision
			for _,candidate in state.Entries do
				for _,key in {attribute(candidate,'id'),attribute(candidate,'name')}do
					if key and key~=''then local entries=state.Names[key];if not entries then entries={};state.Names[key]=entries end;if not table.find(entries,candidate)then table.insert(entries,candidate)end end
				end
			end
			walk(root(form),function(candidate)
				if html(candidate)and ElementNames.htmlName(candidate)=='img'and ancestor(candidate,'form')==form then
					for _,key in {attribute(candidate,'id'),attribute(candidate,'name')}do if key and key~=''then
						local entries=state.Images[key];if not entries then entries={};state.Images[key]=entries end;if not table.find(entries,candidate)then table.insert(entries,candidate)end
					end end
				end
			end)
			for key,past in state.Past do if owner(past)~=form then state.Past[key]=nil end end
		end
		return state
	end
	local function namedCandidates(form,key)
		local state=formNames(form);return state.Names[key]or state.Images[key]or {}
	end
	function bridge:NamedGet(node,key)
		if not html(node)or ElementNames.htmlName(node)~='form'or type(key)~='string'then return false end
		check()
		local state=formNames(node)
		local index=tonumber(key)
		if index and index>=0 and index%1==0 and tostring(index)==key then
			local candidate=state.Entries[index+1];return candidate~=nil,if candidate then bindings.Wrap(candidate)else nil,true
		end
		if key==''then return false end
		local matches=namedCandidates(node,key)
		if #matches==1 then state.Past[key]=matches[1];return true,bindings.Wrap(matches[1])end
		if #matches>1 then
			local function entries()check();return namedCandidates(node,key)end
			local function radioValue()
				for _,candidate in entries()do if ElementNames.htmlName(candidate)=='input'and Defaults.kind(candidate)=='radio'and record(candidate).Checked then return candidate.Attributes.value or 'on'end end
				return ''
			end
			local function assignRadio(text)
				for _,candidate in entries()do if ElementNames.htmlName(candidate)=='input'and Defaults.kind(candidate)=='radio'and(candidate.Attributes.value or 'on')==text then checked(candidate,true,false);break end end
			end
			if not state.NamedViews[key]then state.NamedViews[key]=bindings.Collection(entries,false,{Kind='RadioNodeList',ValueGet=radioValue,ValueSet=assignRadio})end
			return true,state.NamedViews[key]
		end
		local past=state.Past[key]
		if past and owner(past)==node then return true,bindings.Wrap(past)end
		state.Past[key]=nil;return false
	end
	function bridge:NamedKeys(node)
		if not html(node)or ElementNames.htmlName(node)~='form'then return nil end
		check();local keys={};for index in formNames(node).Entries do table.insert(keys,tostring(index-1))end;return keys
	end
	function bridge:RefreshNativeRecords()check();for node in records do record(node)end end
	function bridge:Get(node,key)
		check();if not html(node) then return false end
		local handled,selectionValue=selection:Get(node,key);if handled then return true,selectionValue end
		local name=ElementNames.htmlName(node)
		if views[node] and views[node][key] then return true,views[node][key] end
		local function view(value)if not views[node] then views[node]={} end;views[node][key]=value;return true,value end
		if name=="form" then
			if key=="elements" and bindings.Collection then return view(bindings.Collection(function()return indexedCandidates(node)end,true)) end
			if key=="length" then return true,#indexedCandidates(node) elseif key=="noValidate" then return true,node.Attributes.novalidate~=nil end
		end
		if BOOL[key] and reflects(node,key) then return true,node.Attributes[BOOL[key]]~=nil end
		if STRINGS[key] and reflects(node,key) then return true,node.Attributes[STRINGS[key]] or "" end
		if key=="form" and (FORM_ASSOCIATED[name] or name=="option") then
			local form=if name=="option" then (if ancestor(node,"select") then owner(ancestor(node,"select")) else nil) else owner(node)
			return true,if bindings.Wrap then bindings.Wrap(form) else form or VM.Null
		end
		if name=="option" then
			if key=="defaultSelected" then return true,node.Attributes.selected~=nil
			elseif key=="value" or key=="text" or key=="label" then
				local caption=SelectTree.text(node,false)
				return true,if key=="value" then node.Attributes.value or caption elseif key=="label" then node.Attributes.label or caption else caption
			elseif key=="selected" or key=="index" then
				local select=ancestor(node,"select");local index=0
				if select then local c=selected(select);for i,item in c.Options do if item.Node==node then index=i-1;break end end end
				return true,if key=="index" then index else option(node).Selected
			end
		end
		if name=="input" or name=="textarea" or name=="button" or name=="select" then
			local c=record(node)
			if name=="input" then local handled,result=InputValues.get(c,key,host);if handled then return true,result end end
			if key=="type" then return true,if name=="select" then (if node.Attributes.multiple~=nil then "select-multiple" else "select-one") elseif name=="textarea" then "textarea" else Defaults.kind(node) end
			if key=="value" then
				if name=="button" or (name=="input" and (c.Type=="hidden" or c.Type=="submit" or c.Type=="reset" or c.Type=="button" or c.Type=="image")) then return true,node.Attributes.value or "" end
				if name=="input" and (c.Type=="checkbox" or c.Type=="radio") then return true,node.Attributes.value or "on" end
				return true,c.Value
			elseif name=="input" and key=="checked" then return true,c.Checked==true
			elseif name=="input" and key=="indeterminate" then return true,c.Indeterminate==true
			elseif name=="input" and key=="defaultChecked" then return true,node.Attributes.checked~=nil
			elseif key=="defaultValue" and (name=="input" or name=="textarea") then return true,if name=="textarea" then Node.textContent(node) else node.Attributes.value or ""
			elseif name=="select" and key=="selectedIndex" then return true,(c.SelectedIndex or 0)-1
			elseif name=="select" and (key=="options" or key=="selectedOptions") and bindings.Collection then
				return view(bindings.Collection(function()
					local current=selected(node);local out={};for _,item in current.Options do if key=="options" or option(item.Node).Selected then table.insert(out,item.Node) end end;return out
				end,true))
			elseif key=="willValidate" then return true,willValidate(node)
			elseif key=="validationMessage" then local _,message=validity(node);return true,message
			elseif key=="validity" then
				return view({Get=function(property)check();local flags=validity(node);return if flags[property]~=nil then flags[property] else VM.Undefined end})
			end
		end
		return false
	end
	function bridge:Set(node,key,newValue,strict)
		check();if not html(node) then return false end
		if selection:Set(node,key,newValue)then return true end
		local name=ElementNames.htmlName(node)
		if key=="form" or key=="willValidate" or key=="validity" or key=="validationMessage" or key=="elements" or key=="selectedOptions" or(name=="textarea"and key=="textLength") or (key=="type" and (name=="textarea" or name=="select")) then
			local handled=self:Get(node,key);if handled then if strict~=false then errorValue("TypeError","Read-only DOM property: "..key) end;return true end
		end
		if name=="form" and key=="noValidate" then setAttribute(node,"novalidate",if VM.truth(newValue) then "" else nil);return true end
		if BOOL[key] and reflects(node,key) then setAttribute(node,BOOL[key],if VM.truth(newValue) then "" else nil);return true end
		if STRINGS[key] and reflects(node,key) then setAttribute(node,STRINGS[key],VM.string(newValue));return true end
		if name=="option" then
			if key=="defaultSelected" then setAttribute(node,"selected",if VM.truth(newValue) then "" else nil);return true
			elseif key=="value" or key=="label" then setAttribute(node,key,VM.string(newValue));return true
			elseif key=="text" then assert(bindings.Text,"DOMControls is not attached");bindings.Text(node,VM.string(newValue));return true
			elseif key=="selected" then
				local select=ancestor(node,"select");local c=if select then selected(select) else nil
				local state=option(node);state.Selected=VM.truth(newValue);state.Dirty=true
				if c then
					local indices={};for i,item in c.Options do if option(item.Node).Selected and (c.SelectMultiple or not state.Selected or item.Node==node) then indices[i]=true end end
					if not c.SelectMultiple and next(indices)==nil and c.SelectSize==1 then for i,item in c.Options do if not item.Disabled then indices[i]=true;break end end end
					applySelection(select,c,indices)
				end
				return true
			end
		end
		if name=="input" or name=="textarea" or name=="button" or name=="select" then
			local c=record(node)
			if name=="input" and InputValues.set(c,key,newValue,host,function(text)value(node,text,true)end) then return true end
			if key=="type" and (name=="input" or name=="button") then setAttribute(node,"type",VM.string(newValue));return true end
			if key=="defaultValue" and (name=="input" or name=="textarea") then
				if name=="textarea" then assert(bindings.Text,"DOMControls is not attached");bindings.Text(node,VM.string(newValue)) else setAttribute(node,"value",VM.string(newValue)) end;return true
			elseif name=="input" and key=="defaultChecked" then setAttribute(node,"checked",if VM.truth(newValue) then "" else nil);return true
			elseif name=="input" and key=="checked" then checked(node,VM.truth(newValue),true);return true
			elseif name=="input" and key=="indeterminate" then c.Indeterminate=VM.truth(newValue);notify(node,"checked");return true
			elseif key=="value" then
				local text=if newValue==VM.Null and (name=="input" or name=="textarea") then "" else VM.string(newValue);assert(#text<=65536,"Control value budget exceeded")
				if name=="button" or (name=="input" and (c.Type=="checkbox" or c.Type=="radio" or c.Type=="hidden" or c.Type=="submit" or c.Type=="reset" or c.Type=="button" or c.Type=="image")) then setAttribute(node,"value",text)
				elseif name=="select" then
					local indices={};for i,item in c.Options do if item.Value==text then indices[i]=true;option(item.Node).Dirty=true;break end end;applySelection(node,c,indices)
				else value(node,text,true) end;return true
			elseif name=="select" and key=="selectedIndex" then
				local index=signedLong(newValue)+1;local indices={};if c.Options[index] then indices[index]=true;option(c.Options[index].Node).Dirty=true end;applySelection(node,c,indices);return true
			end
		end
		return false
	end
	function bridge:Method(node,key)
		check();if not html(node) then return nil end
		if ElementNames.htmlName(node)=="input" and (key=="stepUp" or key=="stepDown") then return function(args)InputValues.step(record(node),args,if key=="stepUp" then 1 else -1,host,function(text)value(node,text,true)end)end end
		if ElementNames.htmlName(node)=="input" and key=="showPicker" then return function()
			local c=record(node);if c.Disabled or c.ReadOnly then errorValue("InvalidStateError","The input is not mutable") end
			if host.HasUserActivation and not host.HasUserActivation() then VM.throw(if host.DOMException then host.DOMException("showPicker requires user activation","NotAllowedError") else VM.error("NotAllowedError","showPicker requires user activation")) end
			if host.ShowPicker then host.ShowPicker(node) end
		end end
		if ElementNames.htmlName(node)=='select'and key=='showPicker'then return function()
			local function fail(name,message)VM.throw(if host.DOMException then host.DOMException(message,name)else VM.error(name,message))end
			local c=record(node)
			if c.Disabled then fail('InvalidStateError','The select is not mutable')end
			if host.IsPickerCrossOrigin and host.IsPickerCrossOrigin()then fail('SecurityError','The select document is not same-origin with its top-level document')end
			if not host.HasUserActivation or not host.HasUserActivation()then fail('NotAllowedError','showPicker requires user activation')end
			if host.IsRendered and not host.IsRendered(node)or not host.IsRendered and root(node)~=document then fail('NotSupportedError','The select is not being rendered')end
			if host.ShowPicker then host.ShowPicker(node)end
			return VM.Undefined
		end end
		local selectionMethod=selection:Method(node,key);if selectionMethod then return selectionMethod end
		if key=="focus" and host.FocusControl then return function(args)
			if Defaults.kind(node) then record(node) end;host.FocusControl(node,args[1])
		end
		elseif key=="blur" and host.BlurControl then return function()host.BlurControl(node)end
		elseif key=="click" and host.ActivateControl then return function()
			if Defaults.kind(node) then record(node) end
			if ElementNames.htmlName(node)=="input" and (Defaults.kind(node)=="checkbox" or Defaults.kind(node)=="radio") and not State.disabled(node) then record(node).DOMDirtyChecked=true end
			host.ActivateControl(node)
		end end
		if ElementNames.htmlName(node)=="form" and key=="reset" then return function()
			local committed
			if host.ResetForm then committed=host.ResetForm(node)
			else committed=not cancelled(dispatch(node,"reset")) end
			if committed then for _,child in candidates(node) do
				local custom=internals(child)
				if custom then custom:Reset(child)
				elseif Defaults.kind(child) then
					-- A native FormModel only knows mounted controls. Reset associated
					-- detached/display:none records as well, using the same state paths.
					local c=record(child);c.DOMDirtyValue,c.DOMDirtyChecked,c.UserEdited,c.UserInvalid=false,false,false,false
					if ElementNames.htmlName(child)=="select" then refreshSelect(child,false)
					else
						local fresh=State.create(child)
						value(child,if ElementNames.htmlName(child)=="textarea" then TextValue.sanitize("textarea",Node.textContent(child)) else fresh.DefaultValue,false);checked(child,fresh.DefaultChecked,false)
					end
				end
			end end
		end end
		if ElementNames.htmlName(node)=="form" and key=="requestSubmit" then return function(args)
			local submitter=args[1]
			if submitter==VM.Null or submitter==VM.Undefined then submitter=nil end
			if submitter then
				if type(submitter)~="table" or not submitter.DOMNode or (bindings.Wrap and bindings.Wrap(submitter.DOMNode)~=submitter)then errorValue("TypeError","Expected a submit button from this document") end
				submitter=submitter.DOMNode
				if (ElementNames.htmlName(submitter)~="button" and ElementNames.htmlName(submitter)~="input") or (Defaults.kind(submitter)~="submit" and Defaults.kind(submitter)~="image") then errorValue("TypeError","Expected a submit button") end
				if owner(submitter)~=node then errorValue("NotFoundError","Submitter belongs to another form") end
			end
			if node.Attributes.novalidate~=nil or (submitter and submitter.Attributes.formnovalidate~=nil) or validate(node,false) then
				if host.RequestSubmit then host.RequestSubmit(node,submitter) else dispatch(node,"submit",{Submitter=submitter}) end
			end
		end end
		if key=="checkValidity" or key=="reportValidity" then
			if ElementNames.htmlName(node)=="form" or ElementNames.htmlName(node)=="input" or ElementNames.htmlName(node)=="textarea" or ElementNames.htmlName(node)=="select" or ElementNames.htmlName(node)=="button" then return function()return validate(node,key=="reportValidity")end end
		elseif key=="setCustomValidity" and (ElementNames.htmlName(node)=="input" or ElementNames.htmlName(node)=="textarea" or ElementNames.htmlName(node)=="select" or ElementNames.htmlName(node)=="button") then return function(args)
			if #args<1 then errorValue("TypeError","setCustomValidity needs a message") end
			local message=VM.string(args[1]);assert(#message<=65536,"Custom validity message budget exceeded")
			record(node).DOMCustomValidity=message;notify(node,"state")
		end end
		return nil
	end
	function bridge:AttributeChanged(node,key)
		if key=='id'or key=='name'or key=='form'or key=='type'then namedRevision+=1 end
		check();if not html(node) then return end
		if ElementNames.htmlName(node)=="fieldset" and key=="disabled" then
			for tracked in records do record(tracked);notify(tracked,"state") end
			if host.RefreshControls then host.RefreshControls() end;return
		elseif ElementNames.htmlName(node)=="optgroup" and key=="disabled" then
			local select=ancestor(node,"select");if select then refreshSelect(select,true) end;return
		end
		if key=="id" or key=="form" or key=="name" or key=="type" then
			for tracked in records do record(tracked) end
		end
		if ElementNames.htmlName(node)=="option" then
			local entry=option(node);if key=="selected" and not entry.Dirty then entry.Selected=node.Attributes.selected~=nil end
			local select=ancestor(node,"select");if select then
				-- Preserve option state before rebuilding the renderer's option records.
				local c=record(select);if key=="selected" then local indices={};for i,item in c.Options do if option(item.Node).Selected then indices[i]=true end end;applySelection(select,c,indices) end
				refreshSelect(select,true,nil,key=="selected")
			end;return
		end
		if not Defaults.kind(node) then
			if key=="id" and host.RefreshControls then host.RefreshControls() end;return
		end
		local c=record(node);local previousType=c.Type;local oldSelectable=c.SelectionApplies;local fresh=State.create(node)
		c.SelectionApplies=TextSelection.applies(node)
		for _,field in {"Type","DefaultValue","DefaultChecked","ReadOnly","Required","Name","Multiple","MinLength","MaxLength","Number","Range","Temporal"} do c[field]=fresh[field] end
		if ElementNames.htmlName(node)=="select" and (key=="multiple" or key=="size") then refreshSelect(node,true,key=="multiple" and node.Attributes.multiple==nil,true)
		elseif key=="value" and not c.DOMDirtyValue then value(node,fresh.Value,false)
		elseif key=="checked" and not c.DOMDirtyChecked then checked(node,fresh.Checked,false)
		elseif key=="type" and previousType~=c.Type then
			c.Caption=fresh.Caption
			if ElementNames.htmlName(node)=='input'then c.Datalist,c.Options,c.SelectRows,c.SelectedIndex=fresh.Datalist,fresh.Options,fresh.SelectRows,fresh.SelectedIndex end
			if not oldSelectable and TextSelection.applies(node)then c.SelectionStart,c.SelectionEnd,c.SelectionDirection,c.SelectionValue=0,0,"none",c.Value end
			if c.Type=="file" then c.DOMDirtyValue=false;value(node,"",false)
			elseif ElementNames.htmlName(node)=="input" and valueMode(previousType) and not valueMode(c.Type) and c.Value~="" then setAttribute(node,"value",c.Value)
			elseif ElementNames.htmlName(node)=="input" and not valueMode(previousType) and valueMode(c.Type) then c.DOMDirtyValue=false;value(node,node.Attributes.value or "",false)
			else value(node,c.Value,false) end
			if c.Checked then checked(node,true,false) end
		elseif c.Type=="range" and (key=="min" or key=="max" or key=="step") then value(node,c.Value,false)
		elseif c.Type=="email" and key=="multiple" then value(node,c.Value,false)
		elseif (key=="name" or key=="form") and c.Checked then checked(node,true,false) end
		if key=="required" or key=="readonly" or key=="placeholder" or key=="name" or key=="disabled" or key=="min" or key=="max" or key=="step" or key=="pattern" or key=="minlength" or key=="maxlength" or key=="multiple" or key=="type" then notify(node,"state") end
		if (key=="id" or key=="form" or key=="name" or key=="type") and host.RefreshControls then host.RefreshControls() end
	end
	function bridge:TextChanged(node)
		check();local current=node
		while current do
			if ElementNames.htmlName(current)=="textarea" then
				local c=record(current);c.DefaultValue=TextValue.sanitize("textarea",Node.textContent(current))
				if not c.DOMDirtyValue then value(current,c.DefaultValue,false) end;return
			elseif ElementNames.htmlName(current)=="option" then self:AttributeChanged(current,"text");return end
			current=current.Parent
		end
	end
	function bridge:TreeChanged(node,inserted)
		namedRevision+=1
		check();self:TextChanged(node)
		local current=node;while current do
			if ElementNames.htmlName(current)=='selectedcontent'then break end
			if ElementNames.htmlName(current)=="select" then refreshSelect(current,true);break end;current=current.Parent
		end
		walk(node,function(child)
			if ElementNames.htmlName(child)=="select" then refreshSelect(child,true)
			elseif ElementNames.htmlName(child)=="input" and Defaults.kind(child)=="radio" then record(child) end
		end)
		-- Radio insertion steps run for inserted descendants, in insertion order.
		-- Existing checked siblings must not be re-checked after the new radio.
		local newlyChecked={};for _,subtree in inserted or {}do walk(subtree,function(child)
			if ElementNames.htmlName(child)=="input"and Defaults.kind(child)=="radio"and record(child).Checked then table.insert(newlyChecked,child)end
		end)end
		for _,child in newlyChecked do checked(child,true,false) end
		if host.RefreshControls then host.RefreshControls() end
	end
	function bridge:NotifyUserChange(node,key)
		check();local c=record(node)
		if key=="checked" then c.DOMDirtyChecked=true
		elseif key=="selected" and ElementNames.htmlName(node)=="select" then local state=selected(node);for _,item in state.Options do option(item.Node).Dirty=true end
		else c.DOMDirtyValue=true end
	end
	function bridge:Clone(source,copy)
		check()
		if html(source)and ElementNames.htmlName(source)=="select"then return end
		if html(source)and ElementNames.htmlName(source)=="option"then
			-- Chromium initializes a cloned option from copied content attributes;
			-- current selectedness/dirty state belongs to adoption, not cloning.
			options[copy]={Selected=copy.Attributes.selected~=nil,Dirty=false};return
		end
		if not html(source)or(ElementNames.htmlName(source)~="input"and ElementNames.htmlName(source)~="textarea")then return end
		local old=record(source);local nextState=record(copy)
		nextState.Value,nextState.DOMDirtyValue=old.Value,old.DOMDirtyValue
		if ElementNames.htmlName(source)=="input" then nextState.Checked,nextState.DOMDirtyChecked,nextState.Indeterminate=old.Checked,old.DOMDirtyChecked,old.Indeterminate end
		if nextState.Type=="number" then nextState.EditText,nextState.BadInput=nextState.Value,false end
		-- Native pending state must survive a future RenderTree record creation.
		nextState.UnrenderedValueSet,nextState.UnrenderedCheckedSet=true,true
		if host.SaveControlState then host.SaveControlState(copy,nextState) end
	end
	function bridge:CloneFinished(source,copy)
		check();if html(source)and ElementNames.htmlName(source)=="select"then refreshSelect(copy,false)end
	end
	function bridge:TransferTo(node,destination)
		check()
		if ElementNames.htmlName(node)=="option"and options[node]then destination:ImportOption(node,options[node]);options[node]=nil end
		local entry=records[node];if not entry then return end
		if ElementNames.htmlName(node)=="select"then selected(node)end
		local state=record(node);if host.SaveControlState then host.SaveControlState(node,state)end
		destination:ImportState(node,state)
		if selection then selection:Unbind(entry.State)end;records[node]=nil;views[node]=nil
	end
	function bridge:ImportState(node,state)
		check();local fresh=State.create(node)
		for _,field in CURRENT_FIELDS do fresh[field]=if type(state[field])=="table"then table.clone(state[field])else state[field]end
		fresh.UnrenderedValueSet,fresh.UnrenderedCheckedSet=true,true
		records[node]={State=fresh,Native=false};if host.SaveControlState then host.SaveControlState(node,fresh)end
	end
	function bridge:ImportOption(node,state)check();options[node]={Selected=state.Selected,Dirty=state.Dirty}end
	function bridge:Destroy()
		alive=false;if eventConnection then eventConnection:Disconnect();eventConnection=nil end
		selection:Destroy()
		for node,entry in records do if not entry.Native then Directionality.unbind(node,entry.State)end end
		for c,hook in mirrorHooks do if c.UpdateSelectedContent==hook.Callback then c.UpdateSelectedContent=hook.Previous end end
		table.clear(mirrorHooks);table.clear(synchronizing)
		for node in namedForms do node.DOMFormNames=nil end;table.clear(namedForms)
		table.clear(records);table.clear(options);table.clear(views);table.clear(bindings)
	end
	function bridge:SelectionText(node)return selection:Text(node)end
	selection=TextSelectionAPI.new({Host=host,Record=record,SetValue=value,Alive=function()return alive end,Wrap=function(node)return bindings.Wrap(node)end})
	walk(document,function(node)
		if html(node) and Defaults.kind(node) then record(node) end
	end)
	local initiallyChecked={}
	walk(document,function(node)
		if html(node) and ElementNames.htmlName(node)=="select" then refreshSelect(node,true)
		elseif html(node) and ElementNames.htmlName(node)=="input" and Defaults.kind(node)=="radio" then local c=record(node);if c.Checked then table.insert(initiallyChecked,node) end end
	end)
	for _,node in initiallyChecked do checked(node,true,false) end
	if host.Events and host.Events.BeforeEmit then eventConnection=host.Events:BeforeEmit(function(event)
		local node=event.Target;if not alive or not node or not Defaults.kind(node) then return end
		if event.Type=="input" or event.Type=="change" then
			bridge:NotifyUserChange(node,if ElementNames.htmlName(node)=="select" then "selected" elseif Defaults.kind(node)=="checkbox" or Defaults.kind(node)=="radio" then "checked" else "value")
		elseif event.Type=="click" and ElementNames.htmlName(node)=="input" and (Defaults.kind(node)=="checkbox" or Defaults.kind(node)=="radio") and not State.disabled(node) then record(node).DOMDirtyChecked=true end
	end) end
	return bridge
end
return Controls
