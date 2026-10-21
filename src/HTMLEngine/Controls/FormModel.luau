--!strict
local DOM=require(script.Parent.Parent.DOM.Node)
local FormOwner=require(script.Parent.Parent.DOM.FormOwner)
local State=require(script.Parent.State)
local SelectOptions=require(script.Parent.SelectOptions)
local RangeValue=require(script.Parent.RangeValue)
local NumberValue=require(script.Parent.NumberValue)
local GaugeValue=require(script.Parent.GaugeValue)
local ColorValue=require(script.Parent.ColorValue)
local TextValue=require(script.Parent.TextValue)
local TextSelection=require(script.Parent.TextSelection)
local ValidationMessage=require(script.Parent.ValidationMessage)
local Eligibility=require(script.Parent.ValidationEligibility)
local Validity=require(script.Parent.Validity)
local Temporal=require(script.Parent.TemporalValue)
local Model={}
function Model.new(document: any, controls: any, events: any, changed: any, preserveCurrent: boolean?): any
	local byNode,alive={},true
	local model={Controls=controls, Focused=nil}
	local radioGroups,radioByControl,radioOwners={},{},{}
	local function refreshControls(initial: boolean?)
		table.clear(byNode);table.clear(radioGroups);table.clear(radioByControl);table.clear(radioOwners)
		for _,c in controls do
			byNode[c.Node]=c
			if not c.DisplayOnly and c.Type~="summary" then
				c.Form=FormOwner.resolve(c.Node);c.Disabled=State.disabled(c.Node)
			end
		end
		for _,c in controls do
			if c.Type ~= "radio" then continue end
			local owner=c.Form or c.Node
			if not c.Form then while owner.Parent do owner=owner.Parent end end
			local named=radioOwners[owner]
			if not named then named={};radioOwners[owner]=named end
			local group=if c.Name ~= "" then named[c.Name] else nil
			if not group then
				group={Members={},Form=c.Form}
				table.insert(radioGroups,group)
				if c.Name ~= "" then named[c.Name]=group end
			end
			table.insert(group.Members,c)
			radioByControl[c]=group
			if (initial and c.DefaultChecked) or (not initial and c.Checked) then group.LastDefault=c end
		end
		for _,group in radioGroups do
			if group.LastDefault then
				for _,c in group.Members do c.Checked=c == group.LastDefault end
			end
			group.LastDefault=nil
		end
	end
	refreshControls(preserveCurrent~=true)
	function model:RefreshControls() if alive then refreshControls(false) end end
	function model:RadioPeers(c:any):any
		local group=radioByControl[c]
		return if group then group.Members else {}
	end
	function model:Validity(c:any): (any,string)
		return Validity.read(c.Node,c,function(callback)for _,peer in self:RadioPeers(c)do callback(peer)end end)
	end
	function model:NotifyChanged(c: any,layout: boolean?)
		if alive then changed(c,layout==true) end
	end
	function model:Resolve(target: any): any
		local node=if type(target) == "string" then DOM.findById(document,target) else target
		return byNode[node]
	end
	function model:Emit(c: any,kind: string,data: any?,options: any?): any return events:Emit(c.Node,kind,data,options) end
	function model:Select(c: any,index: number,user: boolean?,additive: boolean?,range: boolean?)
		if not alive or c.Type ~= "select" or (user and (c.Disabled or not c.Options[index] or c.Options[index].Disabled)) then return end
		if c.SelectMultiple then
			local selected=if additive then table.clone(c.SelectedIndices) else {}
			if index>0 then
				if range and c.SelectAnchor then
					for i=math.min(index,c.SelectAnchor),math.max(index,c.SelectAnchor) do
						if c.Options[i] and not c.Options[i].Disabled then selected[i]=true end
					end
				else selected[index]=if additive then not selected[index] else true;c.SelectAnchor=index end
			end
			c.ListActiveIndex=index
			local same=true
			for i=1,#c.Options do if (selected[i]==true)~=(c.SelectedIndices[i]==true) then same=false;break end end
			if same then return end
			SelectOptions.assignMultiple(c,selected);changed(c,false)
			if user then self:Emit(c,"input",{Value=c.Value});if alive then self:Emit(c,"change",{Value=c.Value}) end end
			return
		end
		c.ListActiveIndex=index
		if c.SelectedIndex == index then
			if not user then SelectOptions.assign(c,index);changed(c,false)end
			return
		end
		SelectOptions.assign(c,index); changed(c,false)
		if user then self:Emit(c,"input",{Value=c.Value}); if alive then self:Emit(c,"change",{Value=c.Value}) end end
	end
	function model:SetValue(c: any,value: any,user: boolean?,nativeData: any?)
		if not alive or (user and (c.Disabled or c.ReadOnly)) then return end
		if c.DisplayOnly then
			if not user and GaugeValue.assign(c,value) then changed(c,false) end
			return
		end
		value=tostring(value)
		if c.Type=="file" then
			assert(value=="","InvalidStateError: file inputs can only be cleared")
			c.Files={};c.Value="";changed(c,false);return
		end
		if c.Type == "number" then
			local sanitized=NumberValue.sanitize(value)
			local edit=if user then value else sanitized
			if sanitized == c.Value and edit == c.EditText then return end
			c.Value,c.EditText,c.BadInput=sanitized,edit,edit ~= "" and sanitized == ""
			if user then TextSelection.read(c)end
			TextSelection.valueChanged(c,false)
			changed(c,false)
			if user then self:Emit(c,"input",nativeData or {Value=c.Value}) end
			return
		end
		if c.Type == "color" then value=ColorValue.normalize(value) end
		if c.Type == "select" then
			local index=0
			for i,option in c.Options do if option.Value == value then index=i; break end end
			self:Select(c,index,user); return
		end
		local hadPartial=Temporal.applies(c.Type) and (c.TemporalParts~=nil or c.BadInput==true)
		if Temporal.applies(c.Type) then value=Temporal.sanitize(c.Type,value);c.TemporalParts,c.TemporalDigits,c.BadInput=nil,nil,false
		elseif c.Type == "range" then value=RangeValue.normalize(c.Range,value)
		else
			value=TextValue.sanitize(c.Type,value,c.Multiple)
			if user then value=State.limit(value,c.MaxLength) end
		end
		if TextValue.applies(c.Type) and (value ~= c.Value or not user) then c.UserEdited=user == true end
		if value == c.Value then if hadPartial then changed(c,false) end;return end
		c.Value=value
		if user then TextSelection.read(c)end
		TextSelection.valueChanged(c,false);changed(c,c.Type == "output")
		if user then self:Emit(c,"input",nativeData or {Value=value}) end
	end
	function model:StepNumber(c: any,direction: number): boolean
		if not alive or c.Type ~= "number" or c.Disabled or c.ReadOnly then return false end
		local value=NumberValue.step(c,direction)
		if not value or value == c.Value then return false end
		if self.CommitNumber then self:CommitNumber(c,value) end
		self:SetValue(c,value,true)
		if alive then self:Emit(c,"change",{Value=c.Value}) end
		return true
	end
	function model:SetChecked(c: any,value: boolean,user: boolean?)
		if not alive or (user and c.Disabled) then return end
		if c.Type ~= "checkbox" and c.Type ~= "radio" then return end
		if c.Checked == value then return end
		local unchecked={}
		if value and c.Type == "radio" then
			local group=radioByControl[c]
			for _,other in if group then group.Members else {} do
				if other ~= c and other.Checked then other.Checked=false;table.insert(unchecked,other) end
			end
		end
		c.Checked=value
		-- Observers see the complete new group, including preactivation rollback.
		for _,other in unchecked do changed(other,false)end
		changed(c,false)
		if user then self:Emit(c,"input",{Checked=value}); self:Emit(c,"change",{Checked=value}) end
	end
	function model:Data(form: any,submitter: any?): any
		local result={}
		for _, c in controls do
			if c.DisplayOnly or c.Form ~= form or c.Disabled or (c.Name == "" and c.Type~="image") or c.Type == "output" or c.Type == "button" or c.Type == "reset" then continue end
			if c.Type=="image" then
				if c==submitter then local prefix=if c.Name=="" then "" else c.Name..".";local point=c.ImagePoint or {X=0,Y=0};table.insert(result,{Name=prefix.."x",Value=tostring(point.X)});table.insert(result,{Name=prefix.."y",Value=tostring(point.Y)}) end
				continue
			end
			if c.Type == "submit" and c ~= submitter then continue end
			if c.Type == "select" and c.SelectMultiple then
				for index,option in c.Options do
					if c.SelectedIndices[index] and not option.Disabled then table.insert(result,{Name=c.Name,Value=option.Value}) end
				end
				continue
			end
			if c.Type == "select" and (not c.Options[c.SelectedIndex] or c.Options[c.SelectedIndex].Disabled) then continue end
			local toggle=c.Type == "radio" or c.Type == "checkbox"
			if toggle and not c.Checked then continue end
			table.insert(result,{Name=c.Name,Value=if toggle then c.Node.Attributes.value or "on" else c.Value})
		end
		return result
	end
	function model:Reset(form: any)
		if not alive or events:Emit(form,"reset").DefaultPrevented or not alive then return false end
		local defaults={}
		for _,group in radioGroups do
			if group.Form == form then
				for _,c in group.Members do if c.DefaultChecked then defaults[group]=c end end
			end
		end
		for _, c in controls do
			if not c.DisplayOnly and c.Form == form then
				local group=radioByControl[c]
				c.Value=c.DefaultValue
				c.Checked=if group then defaults[group] == c else c.DefaultChecked
				c.DOMDirtyValue,c.DOMDirtyChecked=false,false
					c.UserEdited=false
					c.UserInvalid=false
				if c.Type == "number" then c.EditText,c.BadInput=c.Value,false end
				if Temporal.applies(c.Type) then c.TemporalParts,c.TemporalDigits,c.BadInput=nil,nil,false end
				if c.Type=="file" then c.Files={};c.Value="" end
				if c.Type == "select" then
					if c.SelectMultiple then SelectOptions.assignMultiple(c,c.DefaultSelectedIndices)
					else SelectOptions.assign(c,c.DefaultSelectedIndex) end
					c.ListActiveIndex=c.SelectedIndex
				end
				TextSelection.valueChanged(c,false);changed(c,c.Type == "output")
			end
		end
		return true
	end
	function model:Submit(form: any,submitter: any?,validated: boolean?)
		if not alive or not form then return end
		local skip=form.Attributes.novalidate~=nil or (submitter and submitter.Node.Attributes.formnovalidate~=nil)
		if not skip and not validated and self.ValidateForm and not self.ValidateForm(form,submitter) then return end
		for _, c in controls do
			if validated or self.ValidateForm then break end
			if form.Attributes.novalidate ~= nil or (submitter and submitter.Node.Attributes.formnovalidate ~= nil) then break end
			if c.Form ~= form or not Eligibility.applies(c.Node,c)then continue end
			local flags,reason=self:Validity(c)
			if not flags.valid then
				c.UserInvalid=true
				changed(c,false)
				local message=ValidationMessage.get(c,reason)
				local event=self:Emit(c,"invalid",{Reason=reason,Message=message},{Bubbles=false,Cancelable=true})
				if alive and not event.DefaultPrevented then
					if self.Focus then self:Focus(c) end
					if alive and self.ShowValidation then self:ShowValidation(c,message) end
				end
				return
			end
		end
		if string.lower(form.Attributes.method or "") == "dialog" and self.CloseDialogFromForm and self:CloseDialogFromForm(form,submitter) then return end
		events:Emit(form,"submit",{Submitter=if submitter then submitter.Node else nil,Entries=self:Data(form,submitter)})
	end
	function model:Activate(c: any,numberDirection: number?,scripted: boolean?,nativeData: any?,clickTarget: any?)
		if not alive or c.Disabled or c.DisplayOnly then return end
		-- HTML checkable inputs preactivate before click handlers run. Cancellation
		-- restores the previous selection and emits neither input nor change.
		local checkable=c.Type=="checkbox" or c.Type=="radio"
		local previous,changedCheck,previousIndeterminate={},false,c.Indeterminate
		if checkable then
			if c.Type=="checkbox" then c.Indeterminate=false end
			previous[c]=c.Checked
			local group=radioByControl[c]
			for _,other in if group then group.Members else {} do previous[other]=other.Checked end
			self:SetChecked(c,if c.Type=="checkbox" then not c.Checked else true)
			changedCheck=previous[c]~=c.Checked
		end
		if not scripted then self.UserActivationUntil=os.clock()+5 end
		local click=events:Emit(clickTarget or c.Node,"click",if scripted then {isTrusted=false}else nativeData)
		if not alive then return end
		if click.DefaultPrevented then
			if c.Type=="radio" then
				local selected
				for other,value in previous do if value then selected=other;break end end
				if selected and (selected==c or radioByControl[c]==radioByControl[selected]) then self:SetChecked(selected,true)
				else self:SetChecked(c,false) end
			else
				for other,value in previous do if other.Checked~=value then other.Checked=value;changed(other,false) end end
			end
			if c.Type=="checkbox" and c.Indeterminate~=previousIndeterminate then c.Indeterminate=previousIndeterminate;changed(c,false) end
			return
		end
		if checkable then
			if changedCheck then self:Emit(c,"input",{Checked=c.Checked});if alive then self:Emit(c,"change",{Checked=c.Checked}) end end
			return
		end
		if c.Type == "number" and numberDirection then self:StepNumber(c,numberDirection)
		elseif c.Type=='color'and self.OpenColor then
			if not scripted or (self.UserActivationUntil or 0)>os.clock()then self:OpenColor(c)end
		elseif Temporal.applies(c.Type) and self.ActivateTemporal then self:ActivateTemporal(c,nativeData,scripted)
		elseif c.Datalist and self.OpenDatalist then self:OpenDatalist(c)
		elseif c.Type == "select" and self.ToggleSelect then self:ToggleSelect(c)
		elseif c.Type == "summary" and self.ToggleDetails then self:ToggleDetails(c)
		elseif self.Command and self:Command(c) then return
		elseif c.Type == "reset" and c.Form then self:Reset(c.Form)
		elseif c.Type == "submit" or c.Type=="image" then
			if c.Type=="image" then
				local box=c.Item and c.Item.BoxGui;local pos=box and box.AbsolutePosition
				c.ImagePoint={X=if not scripted and pos and nativeData and nativeData.screenX then math.max(0,math.floor(nativeData.screenX-pos.X)) else 0,Y=if not scripted and pos and nativeData and nativeData.screenY then math.max(0,math.floor(nativeData.screenY-pos.Y)) else 0}
			end
			self:Submit(c.Form,c)
		end
	end
	function model:Label(node: any): any
		if node.Attributes["for"] then return self:Resolve(node.Attributes["for"]) end
		for _, c in controls do local parent=c.Node.Parent; while parent do if parent == node then return c end; parent=parent.Parent end end
		return nil
	end
	function model:Destroy()
		alive=false
		table.clear(byNode);table.clear(radioByControl);table.clear(radioGroups);table.clear(radioOwners)
	end
	return model
end
return Model
