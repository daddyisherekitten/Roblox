--!strict
return function(Parser,Node,Style,Stylesheet,CounterStyles,loadRenderTree)
 local renderer=loadRenderTree({create=function(_,parent,properties)local gui=table.clone(properties);gui.Parent=parent;return gui end})
 local function render(html,css)
  local document=Parser.parse(html);local warnings={};local tree=renderer.build(document,{},function(message)table.insert(warnings,message)end,nil,nil,nil,nil,css)
  return tree,document,warnings
 end
 local function style(tree,document,id)return assert(tree.NodeStyles[Node.findById(document,id)],id)end
 local tree,document,warnings=render('<div id="normal">normal</div><div id="important">important</div><div id="nested">nested</div>',[=[
 @layer reset,theme; @layer theme { #normal { color: red; } #important { color: red!important; } }
 @layer reset { #normal { color: blue; } #important { color: blue!important; } }
 #normal { color: green; } #important { color: green!important; }
 @layer theme.child { #nested { color: red; } } @layer theme { #nested { color: blue; } }
 ]=])
 assert(#warnings==0,table.concat(warnings,' | '))
 assert(style(tree,document,'normal').Color==Color3.fromRGB(0,128,0),'Unlayered normal rules must outrank named layers')
 assert(style(tree,document,'important').Color==Color3.fromRGB(0,0,255),'Important rules must reverse explicit and implicit layer order')
 assert(style(tree,document,'nested').Color==Color3.fromRGB(0,0,255),'Parent implicit sublayer must follow its named children')
 tree,document,warnings=render('<p id="specific" class="probe">specific</p><p id="anon">anonymous</p>',[=[
 @layer a,b; @layer a {#specific{color:red}} @layer b {.probe{color:blue}}
 @layer { #anon{color:red} } @layer { #anon{color:blue} }
 ]=])
 assert(#warnings==0 and style(tree,document,'specific').Color==Color3.fromRGB(0,0,255)and style(tree,document,'anon').Color==Color3.fromRGB(0,0,255),'Layer precedence must precede specificity and anonymous layers remain distinct')
 tree,document,warnings=render('<div class="outer"><div class="inner"><p id="near">Near</p><div class="stop"><p id="excluded">Excluded</p></div></div><p id="outer">Outer</p></div><p id="outside">Outside</p>',[=[
 p{color:black} @scope (.inner) to (.stop){p{color:blue}} @scope (.outer) to (.stop){p{color:red}}
 ]=])
 assert(#warnings==0,table.concat(warnings,' | '))
 assert(style(tree,document,'near').Color==Color3.fromRGB(0,0,255),'Nearer scope must outrank later equal specificity')
 assert(style(tree,document,'outer').Color==Color3.fromRGB(255,0,0)and style(tree,document,'excluded').Color==Color3.fromRGB(0,0,0)and style(tree,document,'outside').Color==Color3.fromRGB(0,0,0),'Scope upper/lower bounds must exclude the full limit subtree')
 tree,document,warnings=render('<div class="outer"><p id="comment-scope" class="a2 b3"></p><div class="stop"><p id="comment-limit"></p></div></div>',[=[
 p{color:black}.a2/**/.b3{background:blue}@scope(.outer)to/**//**/(.stop){p{color:red}}
 ]=])
 assert(#warnings==0 and style(tree,document,'comment-scope').Color==Color3.fromRGB(255,0,0)and style(tree,document,'comment-scope').Background==Color3.fromRGB(0,0,255)and style(tree,document,'comment-limit').Color==Color3.fromRGB(0,0,0),'Comment token boundaries must keep to an identifier and adjacent classes a compound: '..table.concat(warnings,' | ')..' / '..tostring(style(tree,document,'comment-scope').Color)..' / '..tostring(style(tree,document,'comment-scope').Background)..' / '..tostring(style(tree,document,'comment-limit').Color))
 tree,document,warnings=render('<div class="outer"><p id="invalid-scope"></p></div>','p{color:black}@scope(.outer)to(.stop){p{color:red}}')
 assert(#warnings==1 and style(tree,document,'invalid-scope').Color==Color3.fromRGB(0,0,0),'A to() function token is not the scope to keyword')
 tree,document,warnings=render('<p id="split" class="a">split</p>','p{width:13px;color:blue}.a/**/p{background:red}#split{width:10/**/px;color:r/**/ed}')
 assert(#warnings>=1 and style(tree,document,'split').Width.Value==13 and style(tree,document,'split').Color==Color3.fromRGB(0,0,255)and style(tree,document,'split').Background==nil,'Deleting comments must not merge dimensions/colors or manufacture a descendant selector')
 tree,document,warnings=render('<section id="implicit"><style>@scope { :scope { padding:3px } > p {color:green} }</style><p id="direct">Direct</p><div><p id="deep">Deep</p></div></section><p id="plain">Plain</p>',nil)
 assert(#warnings==0 and style(tree,document,'implicit').Padding[1]==3 and style(tree,document,'direct').Color==Color3.fromRGB(0,128,0)and style(tree,document,'deep').Color~=Color3.fromRGB(0,128,0),'Implicit owner scope and relative direct child selector failed')
 tree,document,warnings=render('<div class="outer"><section class="inner"><p id="nested-scope">Nested scope</p></section></div><section class="inner"><p id="unscoped">Outside</p></section>',[=[
 @scope (.outer) { @scope (:scope > .inner) { & > p {color:blue} } }
 ]=])
 assert(#warnings==0 and style(tree,document,'nested-scope').Color==Color3.fromRGB(0,0,255)and style(tree,document,'unscoped').Color~=Color3.fromRGB(0,0,255),'Nested scope roots must be relative to the outer scope')
 tree,document,warnings=render('<p id="conditional">Condition</p>',[=[
 @media (min-width:700px){@layer layout{}} @layer theme,layout; @layer theme {p{color:blue}} @layer layout{p{color:red}}
 ]=])
 tree:SetMediaEnvironment(800,600);assert(style(tree,document,'conditional').Color==Color3.fromRGB(0,0,255),'Active conditional first occurrence must establish layer ordering')
 tree:SetMediaEnvironment(500,600);assert(style(tree,document,'conditional').Color==Color3.fromRGB(255,0,0),'Inactive condition must not create a layer order entry')
 tree,document,warnings=render('<p id="invalid-layer">Invalid layer</p>','@layer a,initial;@layer b,a;@layer a{p{color:red}}@layer b{p{color:blue}}')
 assert(#warnings==1 and style(tree,document,'invalid-layer').Color==Color3.fromRGB(255,0,0),'Invalid layer statements must not partially establish names or precedence')
 tree,document,warnings=render('<div id="parent" style="--distance:40px;--tone:red;--ordinary:7px"><p id="defaults"></p><p id="local" style="font-size:20px;--distance:2em;--tone:blue;--ratio:.5"></p><p id="invalid" style="--distance:banana;--tone:3px"></p><p id="cycle" style="--distance:var(--other);--other:var(--distance)"></p><p id="explicit" style="--distance:inherit"></p></div>',[=[
 @property --distance {syntax:"<length>";inherits:false;initial-value:12px}
 @property --tone {syntax:"<color>";inherits:true;initial-value:green}
 @property --ratio {syntax:"<number>";inherits:false;initial-value:1}
 p{width:var(--distance);color:var(--tone);opacity:var(--ratio)}
 ]=])
 assert(#warnings==0,table.concat(warnings,' | '))
 assert(style(tree,document,'defaults').Width.Value==12 and style(tree,document,'defaults').Color==Color3.fromRGB(255,0,0),'Typed initials/noninherit/inherit were not applied')
 assert(style(tree,document,'local').Width.Value==40 and style(tree,document,'local').Color==Color3.fromRGB(0,0,255)and style(tree,document,'local').Opacity==.5,'Typed relative lengths must compute at final font size before substitution')
 assert(style(tree,document,'invalid').Width.Value==12 and style(tree,document,'cycle').Width.Value==12 and style(tree,document,'explicit').Width.Value==40,'Typed invalid/cyclic defaults and explicit inherit failed')
 assert(style(tree,document,'defaults').Custom['--ordinary']=='7px','Unregistered properties must keep ordinary inherited behavior')
 tree,document,warnings=render('<p id="typed-math" style="--percent:calc(20% + 15%);--word:&quot;two&quot; &quot;strings&quot;;--last:wrong"></p>',[=[
 @property --percent{syntax:"<percentage>";inherits:false;initial-value:10%}
 @property --word{syntax:"<string>";inherits:false;initial-value:"valid"}
 @property --last{syntax:"<length>";syntax:"<not-supported>";inherits:false;inherits:wrong;initial-value:7px}
 p{width:var(--percent);height:var(--last)}
 ]=])
 local typed=style(tree,document,'typed-math');assert(#warnings==0 and typed.Width.Percent and typed.Width.Value==35 and typed.Height.Value==7 and typed.Custom['--word']=='"valid"','Typed percentage math, whole-string grammar and last valid descriptors must be computed before substitution')
 local registry={};local function add(name,body)local result,message=CounterStyles.parse(name,body);assert(result,message);registry[name]=result end
 add('binary','system:numeric;symbols:"0" "1";pad:4 "0";negative:"(" ")";prefix:"#";suffix:") ";range:-3 3;fallback:decimal')
 assert(CounterStyles.format(registry,2,'binary')=='0010'and CounterStyles.format(registry,-2,'binary')=='(10)','Numeric symbols/pad/negative formatting failed')
 assert(CounterStyles.format(registry,12,'binary',true)=='#12) ','Marker fallback must keep the selected style prefix and suffix')
 add('cycle','system:cyclic;symbols:"a" "b" "c"');assert(CounterStyles.format(registry,-1,'cycle')=='b','Cyclic negative values must use signed modular indexing')
 add('fixed','system:fixed -1;symbols:"a" "b" "c"');assert(CounterStyles.format(registry,0,'fixed')=='b'and CounterStyles.format(registry,5,'fixed')=='5','Fixed ranges and fallback failed')
 add('symbolic','system:symbolic;symbols:"*" "†" "‡"');assert(CounterStyles.format(registry,4,'symbolic')=='**','Symbolic repetitions failed')
 add('alphabet','system:alphabetic;symbols:"a" "b"');assert(CounterStyles.format(registry,3,'alphabet')=='aa','Alphabetic positional algorithm failed')
 add('additive','system:additive;additive-symbols:2 "b",1 "a",0 "z"');assert(CounterStyles.format(registry,4,'additive')=='bb'and CounterStyles.format(registry,0,'additive')=='z','Additive zero and weighted decomposition failed')
 add('extension','system:extends binary;suffix:"!"');assert(CounterStyles.format(registry,2,'extension',true)=='#0010!','Extended style descriptor inheritance failed')
 add('loop-a','system:extends loop-b');add('loop-b','system:extends loop-a;pad:4 "0"');assert(CounterStyles.format(registry,2,'loop-a')=='2','Extends cycles must each independently extend decimal')
 assert(not CounterStyles.parse('invalid','system:additive;additive-symbols:1 "a",2 "b"'),'Unsorted additive descriptor must invalidate an undefined style')
 assert(not CounterStyles.parse('image','system:cyclic;symbols:url(icon.svg)'),'Image symbols must be diagnosed rather than accepted as text')
 local anonymous=assert(CounterStyles.value('symbols(numeric "0" "1")'))
 assert(CounterStyles.format(nil,5,anonymous,true)=='101 ','Anonymous numeric symbols must have the symbols() space suffix')
 assert(CounterStyles.format(nil,-5,assert(CounterStyles.value('"→ "',true)),true)=='→ ','Literal marker strings must not depend on ordinal or add punctuation')
 assert(not CounterStyles.value('symbols(alphabetic "a")')and not CounterStyles.value('symbols(cyclic a b)')and not CounterStyles.value('symbols(cyclic "a\nb")'),'Anonymous symbols grammar and string line breaks must be validated')
 tree,document,warnings=render('<ol><li id="case"></li><li id="anonymous"></li><li id="literal"></li></ol>',[=[
 @counter-style MixedCase {system:cyclic;symbols:"X";suffix:" "}
 #case{list-style-type:MixedCase} #anonymous{list-style-type:symbols(cyclic "a" "b")} #literal{list-style:inside "✓ "}
 ]=])
 assert(#warnings==0 and style(tree,document,'case').ListStyleType=='MixedCase'and type(style(tree,document,'anonymous').ListStyleType)=='table'and style(tree,document,'literal').ListStyleType.System=='literal','Custom names and anonymous/literal marker declarations must reach the renderer unchanged')
 local startingDocument=Parser.parse('<p id="start">Starting</p><p id="after">After</p><p id="conditional">Conditional</p>')
 local startingRules=Stylesheet.collect(startingDocument,error,[=[
 #start{opacity:1;@starting-style{opacity:0}}
 #after{@starting-style{opacity:0}opacity:.7}
 #conditional{opacity:1}@media(min-width:700px){@starting-style{#conditional{opacity:.2}}}
 ]=])
 local function pose(id,starting)return Style.resolve(Node.findById(startingDocument,id),{FontSize=16},error,false,Stylesheet.match(startingRules,Node.findById(startingDocument,id),nil,nil,starting))end
 Stylesheet.setMediaEnvironment(startingRules,{Width=800,Height=600})
 assert(pose('start',false).Opacity==1 and pose('start',true).Opacity==0 and pose('after',true).Opacity==.7,'Starting style must be excluded from ordinary cascade and preserve nested declaration source order')
 assert(pose('conditional',true).Opacity==.2,'Starting style must retain media conditions')
 Stylesheet.setMediaEnvironment(startingRules,{Width=500,Height=600});assert(pose('conditional',true).Opacity==1,'Inactive starting rules must not contribute')
 print('CSS rule families: normal/important/nested/conditional layers, scope roots/limits/proximity, typed registration/defaults/cycles and custom counter systems passed')
end
