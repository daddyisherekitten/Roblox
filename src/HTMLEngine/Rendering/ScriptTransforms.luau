--!strict
-- CSSOM transforms can repaint an existing surface without walking the page.
-- Keep the normal cascade for selector, inheritance, geometry and CSS motion
-- dependencies; never treat a lack of layout requests as proof of cheap paint.
local Style=require(script.Parent.Parent.CSS.InlineStyle)
local BoxTransform=require(script.Parent.BoxTransform)
local Transform2D=require(script.Parent.Parent.CSS.Transform2D)
local Matrix4=require(script.Parent.Parent.CSS.Matrix4)
local PositionedLayout=require(script.Parent.Parent.Layout.PositionedLayout)
local DocumentMode=require(script.Parent.Parent.DOM.DocumentMode)
local Directionality=require(script.Parent.Parent.CSS.Directionality)
local LanguageRange=require(script.Parent.Parent.CSS.LanguageRange)
local ScriptTransforms={}

local function selectorReads(selector: any,kind: string,name: string): boolean
	for _,part in selector.Parts or {} do
		for _,test in part.Tests do
			if test.Kind==kind and test.Name:lower()==name then return true end
			for _,nested in test.Selectors or {} do if selectorReads(nested,kind,name) then return true end end
			for _,nested in test.Filter or {} do if selectorReads(nested,kind,name) then return true end end
		end
	end
	-- Scope boundaries and shadow selectors also participate in matching; their
	-- tests may be stored outside the target selector's compound parts.
	for _,key in {'ShadowContext','SlotSelector','SlotContext'}do
		local nested=selector[key];if nested and selectorReads(nested,kind,name)then return true end
	end
	if selector.Part then
		for _,key in {'Host','Context'}do
			local nested=selector.Part[key];if nested and selectorReads(nested,kind,name)then return true end
		end
	end
	for _,scope in selector.Scopes or{}do
		for _,list in {scope.Start or{},scope.Finish or{}}do
			for _,nested in list do if selectorReads(nested,kind,name)then return true end end
		end
	end
	return false
end
local function automaticDirection(node: any): boolean
	return next(Directionality.textOwners(node))~=nil
end
-- Determine whether changing an attribute can affect only its own subtree.
-- Relational subjects, sibling filters, scopes and slot-owned subjects retain
-- the general cascade; ordinary descendant and exported part rules stay local.
local function attributeDependency(selector: any,name: string,changedNames: any?): (boolean,boolean)
	local dependent,safe=false,true
	for index,part in selector.Parts or{}do
		local partDependent=false
		for _,test in part.Tests do
			local direct=test.Kind=='attribute'and test.Name:lower()==name
				or (name=='class'and test.Kind=='class'or name=='id'and test.Kind=='id')and(not changedNames or changedNames.Names[if changedNames.Fold then DocumentMode.fold(test.Value)else test.Value])
				or name=='open'and test.Kind=='pseudo'and test.Name=='open'
			partDependent=partDependent or direct
			for _,nested in test.Selectors or{}do
				local reads,localScope=attributeDependency(nested,name,changedNames)
				if reads then partDependent=true;if test.Name=='has'or not localScope then safe=false end end
			end
			for _,nested in test.Filter or{}do
				local reads=attributeDependency(nested,name,changedNames)
				if reads then partDependent=true;safe=false end
			end
		end
		if partDependent then
			dependent=true
			for following=index+1,#selector.Parts do
				local relation=selector.Parts[following].Relation
				if relation=='+'or relation=='~'then safe=false end
			end
		end
	end
	for _,key in {'ShadowContext','SlotSelector','SlotContext'}do
		local nested=selector[key]
		if nested then local reads,localScope=attributeDependency(nested,name,changedNames)
			if reads then dependent=true;if key=='SlotSelector'or not localScope then safe=false end end
		end
	end
	if selector.Part then for _,key in {'Host','Context'}do
		local nested=selector.Part[key]
		if nested then local reads,localScope=attributeDependency(nested,name,changedNames)
			if reads then dependent=true;safe=safe and localScope end
		end
	end end
	for _,scope in selector.Scopes or{}do for _,list in {scope.Start or{},scope.Finish or{}}do
		for _,nested in list do if attributeDependency(nested,name,changedNames)then dependent=true;safe=false end end
	end end
	return dependent,safe
end
local function inheritsTransform(declarations: any): boolean
	for _,entries in {declarations.Normal,declarations.Important} do
		for _,entry in entries do
			-- var() can resolve to inherit, including through a fallback.
			if (entry.Field=="Transform" and entry.Wide=="inherit")
				or entry.VariableProperty=="transform" or entry.VariableProperty=="all" then return true end
		end
	end
	return false
end
local function hasMotion(style: any): boolean
	for _,duration in style.TransitionDuration or {} do if duration>0 then return true end end
	for _,name in style.AnimationName or {} do if name~="none" then return true end end
	return false
end

function ScriptTransforms.new(tree: any,records: any,ruleSets: any,host: any): any
	local selectors,inheritance,emptySelectors,directionSelectors=false,false,false,false
	for _,rules in ruleSets do
		for i=1,#rules do
			local rule=rules[i]
			if selectorReads(rule,'attribute','style') then selectors=true end
			if selectorReads(rule,'pseudo','empty') then emptySelectors=true end
			if selectorReads(rule,'pseudo','dir') then directionSelectors=true end
			if inheritsTransform(rule.Declarations) then inheritance=true end
		end
	end
	local index,inlineInheritance=nil,false
	local attributeScopes={}
	local self={}
	function self:Invalidate()index=nil;table.clear(attributeScopes) end
	local function subtreeAttribute(name: string,changedNames: any?): boolean
		if not changedNames and attributeScopes[name]~=nil then return attributeScopes[name] end
		for _,rules in ruleSets do for i=1,#rules do
			local reads,safe=attributeDependency(rules[i],name,changedNames)
			if reads and not safe then if not changedNames then attributeScopes[name]=false end;return false end
		end end
		if not changedNames then attributeScopes[name]=true end;return true
	end
	local function changedIdentifiers(node: any,change: any,attribute: string): any?
		local old=change.OldAttributes and change.OldAttributes[attribute]
		if old==nil or(attribute~='class'and attribute~='id')then return nil end
		local before,after=old or '',node.Attributes[attribute]or ''
		local fold=DocumentMode.quirks(node)
		if fold then before,after=DocumentMode.fold(before),DocumentMode.fold(after)end
		local changed={}
		local result={Names=changed,Fold=fold}
		if attribute=='id'then if before~=after then changed[before],changed[after]=true,true end;return result end
		local previous,current={},{}
		for name in before:gmatch('[^ \t\n\r\f]+')do previous[name]=true end
		for name in after:gmatch('[^ \t\n\r\f]+')do current[name]=true end
		for name in previous do if not current[name]then changed[name]=true end end
		for name in current do if not previous[name]then changed[name]=true end end
		return result
	end
	function self:Scope(changes: any,allowText: boolean?): any?
		local affected,subtrees={},{}
		for node,change in changes do
			if change.Children then return nil end
			local scopedAttribute=false
			for attribute in change.Attributes or{}do
				if attribute=='style'then continue end
				-- This is cascade invalidation, never the transform-only painter.
				if not allowText or not(attribute=='class'or attribute=='id'or attribute=='open'and node.Name=='details'
					or attribute:match('^aria%-')or attribute:match('^data%-'))or not subtreeAttribute(attribute,changedIdentifiers(node,change,attribute))then return nil end
				scopedAttribute=true;subtrees[node]=true
			end
			local inline=change.Attributes and change.Attributes.style
			if inline and selectors then return nil end
			if change.Text then
				-- A text replacement in the same batch must not turn a local
				-- inline style write into a page-wide recascade. Keep conservative
				-- selector invalidation for emptiness and automatic direction.
				if not allowText or emptySelectors or(directionSelectors and automaticDirection(node))then return nil end
				for auto in Directionality.textOwners(node)do affected[auto]=true;subtrees[auto]=true end
			elseif not inline and not scopedAttribute then return nil end
			local target=if node.Kind=='Text'then node.Parent else node
			if target then affected[target]=true end
		end
		if next(subtrees)then for _,record in records do
			local node=record.Node
			while node do
				if subtrees[node]then affected[record.Node]=true;break end
				node=if node.Kind=='ShadowRoot'then node.Host else node.Parent
			end
		end end
		return affected
	end
	function self:Try(changes: any): boolean
		local affected=self:Scope(changes)
		if not affected or not next(affected) or inheritance or tree.LayoutNeedsRecovery then return false end
		if not index then
			index={};inlineInheritance=false
			for _,record in records do
				index[record.Node]=record
				if inheritsTransform(Style.compile(record.Node.Attributes.style or "")) then inlineInheritance=true end
			end
		end
		if inlineInheritance then return false end
		local updates={}
		for node in affected do
			local record,box=index[node],BoxTransform.node(tree,node)
			if not record or not box or box.Style~=record.Style or not box.OuterWidth or not box.OuterHeight then return false end
			-- Sampled layout fields can equal a newly written author value while
			-- their saved underlying values differ. The full recascade restores
			-- those values before comparing and preserves additive/cancel semantics.
			if box.AnimationAuthorFields or box.AnimationMetricAuthor or box.AnimationColorAuthor or box.AnimationTextShadowAuthor then return false end
			local current=record.Style
			if hasMotion(current) or (tree.MotionRuntime and tree.MotionRuntime.Transitions and tree.MotionRuntime.Transitions[box])
				or box.Scene3DRoot or box.Scene3DContext or current.TransformStyle=="preserve-3d"
				or current.Position=="fixed" or current.Position=="sticky" then return false end
			if inheritsTransform(Style.compile(node.Attributes.style or "")) then return false end
   local computed=Style.resolve(node,record.Inherited,host.Diagnostic,record.Inline,host.Matched(node))
   computed.HyphenationLanguage=if computed.Hyphens=='auto'then LanguageRange.language(node)else ''
   computed.TextTransformLanguage=if computed.TextTransform and computed.TextTransform~='none'then LanguageRange.language(node)else ''
   computed.TableBorderMode=if computed.TableRole=='table'then computed.BorderCollapse else record.Inherited.TableBorderMode
   computed.CollapsedBorder=computed.TableRole~=nil and computed.TableRole~='caption'and computed.TableBorderMode=='collapse'
			if current.AtomicInline and computed.Display=="inline" then computed.Display="inline-block" end
			for field in host.Fields do
				if field~="Transform" and field~="ViewportWidth" and field~="ViewportHeight"
     and not host.Same(current[field],computed[field]) then return false end
			end
			if not Matrix4.native(Transform2D.matrix(Transform2D.operations(computed),box.OuterWidth,box.OuterHeight)) then return false end
			if PositionedLayout.establishesFixedContainingBlock(current)~=PositionedLayout.establishesFixedContainingBlock(computed)
				and host.HasPositionedDescendant(box) then return false end
			table.insert(updates,{Box=box,Current=current,Computed=computed})
		end
		-- Preflight the complete batch before touching any computed style or GUI.
		for _,update in updates do
			local current,computed=update.Current,update.Computed
			if not host.Same(current.Transform,computed.Transform) then
				current.Transform=computed.Transform
				BoxTransform.apply(update.Box,nil,true)
			end
			current.ViewportWidth,current.ViewportHeight=computed.ViewportWidth,computed.ViewportHeight
		end
		return true
	end
	return self
end
return ScriptTransforms
