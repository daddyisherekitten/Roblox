--!strict
return function(Parser,Node,Markup,loadRenderTree,loadWordLayout,loadBlockLayout)
 local renderer=loadRenderTree({create=function(class,parent,props)
  local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent;return gui
 end})
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},
  ['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 local source='<html><head></head><body><p id="before">Before</p><noscript id="fallback"><style>#before{color:red}</style><p id="notice" style="position:fixed;bottom:0">Enable &amp; retry</p><input id="inert-input"><script id="inert-script">missingFunction()</script></noscript><p id="after">After</p></body></html>'
 local enabled=Parser.parseDocument(source,{ScriptingEnabled=true})
 local noscript=assert(Node.findById(enabled,'fallback'))
 assert(enabled.ScriptingEnabled and #enabled.Diagnostics==0 and #noscript.Children==1 and noscript.Children[1].Kind=='Text','Enabled noscript uses raw text without parsing its tags')
 local raw='<style>#before{color:red}</style><p id="notice" style="position:fixed;bottom:0">Enable &amp; retry</p><input id="inert-input"><script id="inert-script">missingFunction()</script>'
 assert(Node.textContent(noscript)==raw and Markup.serialize(noscript,true)==raw,'Raw fallback markup and character references round-trip unchanged')
 assert(not Node.findById(enabled,'notice')and not Node.findById(enabled,'inert-script'),'No fallback controls, scripts or fixed elements enter the active DOM')
 local tree=renderer.build(enabled,{},error)
 layout.arrange(tree,400,0,0,function()return true end)
 assert(not tree.NodeBoxes[noscript]and #tree.Controls==0 and #tree.ViewportPositioned==0,'Enabled fallback allocates no rendered or interactive surfaces')
 assert(tree.NodeStyles[Node.findById(enabled,'before')].Color~=Color3.fromRGB(255,0,0),'Styles inside active noscript cannot affect the document')
 local before,after=tree.NodeBoxes[Node.findById(enabled,'before')],tree.NodeBoxes[Node.findById(enabled,'after')]
 assert(after.LayoutY>=before.LayoutY+before.OuterHeight,'Ordinary content remains in normal flow')
 local disabled=Parser.parseDocument(source,{ScriptingEnabled=false})
 local fallbackTree=renderer.build(disabled,{},error)
 assert(not disabled.ScriptingEnabled and Node.findById(disabled,'notice')and fallbackTree.NodeBoxes[Node.findById(disabled,'fallback')],'Disabled scripting renders the body fallback')
 assert(fallbackTree.NodeStyles[Node.findById(disabled,'before')].Color==Color3.fromRGB(255,0,0),'Disabled fallback styles remain real stylesheet nodes')
 local fragment=Markup.parse(noscript,'<p id="dynamic">New &amp; fallback</p>')
 assert(#fragment.Children==1 and fragment.Children[1].Kind=='Text'and fragment.Children[1].Text=='<p id="dynamic">New &amp; fallback</p>','innerHTML in enabled noscript stays raw text')
 local bodyFragment=Markup.parse(enabled.Body,'<noscript><p id="dynamic">New &amp; fallback</p></noscript>')
 local nested=bodyFragment.Children[1]
 assert(nested.Name=='noscript'and #nested.Children==1 and nested.Children[1].Kind=='Text','Nested noscript in ordinary fragment parsing inherits the scripting flag')
 local disabledFragment=Markup.parse(Node.findById(disabled,'fallback'),'<p id="dynamic">New &amp; fallback</p>')
 assert(disabledFragment.Children[1].Name=='p'and Node.textContent(disabledFragment.Children[1])=='New & fallback','Disabled fragment contexts parse fallback HTML and entities')
 local inert=Parser.parseDocument(source,{DisableDeclarativeShadowRoots=true})
 assert(not inert.ScriptingEnabled and Node.findById(inert,'notice'),'Standalone/inert document parsing keeps its disabled default')
 local head=Parser.parseDocument('<html><head><noscript><style id="fallback-style">p{color:red}</style></noscript></head><body><p>Content</p></body></html>',{ScriptingEnabled=true})
 assert(not Node.findById(head,'fallback-style'),'Enabled head noscript is also raw text')
 local foreign=Parser.parse('<svg><noscript><text id="svg-text">Foreign</text></noscript></svg>',{ScriptingEnabled=true})
 assert(Node.findById(foreign,'svg-text'),'Foreign SVG noscript does not use HTML raw-text rules')
 print('NoScript: page capability, raw parsing/serialization, enabled/disabled fallback, stylesheet/control/fixed isolation, fragment contexts, inert documents and foreign SVG passed')
end
