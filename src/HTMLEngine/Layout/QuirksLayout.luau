--!strict
-- Legacy height lookup is separate from the ordinary containing height:
-- The browser profile also uses it for percentage min-/max-height; it never
-- turns an automatic ancestor into a definite flex/grid containing height.
local Mode=require(script.Parent.Parent.DOM.DocumentMode)
local Quirks={}
local excluded={row=true,group=true,cell=true,caption=true,['table-row']=true,['table-row-group']=true,['table-header-group']=true,
	['table-footer-group']=true,['table-cell']=true,['table-caption']=true}
local function html(node: any,name: string): boolean
	return node~=nil and node.Name==name and (node.NamespaceURI==nil or node.NamespaceURI=='http://www.w3.org/1999/xhtml')
end
local function root(box: any): boolean
	local node=box.Node
	return html(node,'html')and node.Parent~=nil and node.Parent.Kind=='Document'
end
Quirks.isRoot=root
local function body(box: any): boolean
	local node=box.Node
	if not html(node,'body')or not html(node.Parent,'html')or not node.Parent.Parent or node.Parent.Parent.Kind~='Document'then return false end
	for _,child in node.Parent.Children do if html(child,'body')then return child==node end end
	return false
end
function Quirks.bind(box: any,viewportHeight: number)
	local document=Mode.document(box.Node)
	box.QuirksMode=document~=nil and document.Mode=='quirks'
	box.LegacyLineHeight=document~=nil and(document.Mode=='quirks'or document.Mode=='limited-quirks')
	if not box.LayoutParent then box.QuirksHeightBasis=if box.QuirksMode then viewportHeight else nil end
end
function Quirks.heightBasis(box: any,ordinary: number?): number?
	local style=box.Style
	if ordinary~=nil or not box.QuirksMode or style.Position=='absolute'or style.Position=='fixed'or excluded[style.TableRole or style.Display]then return ordinary end
	return box.QuirksHeightBasis
end
function Quirks.heightBorderBox(box: any): boolean
	return box.Style.BoxSizing=='border-box'or box.QuirksMode==true and box.Style.TableRole=='cell'
end
-- Returns the legacy basis passed through an automatic block container and
-- the implicit border-box minimum of the actual HTML root/body.
function Quirks.context(box: any,fixed: number?,edges: number,minHeight: number,maxHeight: number): (number?,number?)
	if not box.QuirksMode then return nil,nil end
	local s=box.Style
	if box.Node.Kind=='Document'then box.QuirksContentBasis=box.GridViewport[2];return box.GridViewport[2],nil end
	local basis=fixed
	local minimum
	if root(box)and (not s.Height or s.Height.Intrinsic)and s.WritingMode=='horizontal-tb'then
		minimum=math.max(0,(box.QuirksHeightBasis or 0)-box.LayoutMargin[1]-box.LayoutMargin[3])
		basis=math.max(minHeight,math.min(maxHeight,math.max(0,minimum-edges)))
		minimum=basis+edges
	elseif body(box)and not s.Height and s.WritingMode=='horizontal-tb'and s.Position~='absolute'and s.Position~='fixed'
		and s.Float=='none'and s.Display~='inline'and s.Display~='inline-block'and s.Display~='inline-flex'and s.Display~='inline-grid'and s.ColumnSpan~='all'then
		local parentHeight=box.QuirksHeightBasis
		minimum=if parentHeight then math.max(0,parentHeight-box.LayoutMargin[1]-box.LayoutMargin[3])else nil
		-- Collapsed child margins affect the body's fill but not the percentage
		-- lookup through it. Its own declared margins and edges do affect it.
		basis=if parentHeight then math.max(minHeight,math.min(maxHeight,math.max(0,parentHeight-s.Margin[1]-s.Margin[3]-edges)))else nil
		if minimum then minimum=math.max(minHeight,math.min(maxHeight,math.max(0,minimum-edges)))+edges end
	elseif fixed==nil and s.Position~='absolute'and s.Position~='fixed'and not excluded[s.TableRole or s.Display]
		and (s.Display=='block'or s.Display=='flow-root'or s.Display=='inline-block'or s.TableRole=='table')then
		basis=box.QuirksHeightBasis
	end
	box.QuirksContentBasis=basis
	return basis,minimum
end
function Quirks.children(box: any,ordinary: number?,legacy: number?)
	for _,child in box.Children do
		child.HeightBasis=if box.Node.Kind=='Document'and root(child)then box.GridViewport[2]else ordinary
		child.QuirksMode,child.QuirksHeightBasis=box.QuirksMode,legacy
		child.LegacyLineHeight=box.LegacyLineHeight
	end
end
return Quirks
