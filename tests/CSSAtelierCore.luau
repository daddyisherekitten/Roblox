-- Semantic cases from the browser reference, including mutation and boundaries.
return function(Syntax,Selectors,Parser,Node,Media,Container,Length,Style,Sheet)
	local document=Parser.parseDocument('<html lang="de-CH"><body><ul><li class="picked café">A</li><li>B</li><li class="picked">C</li><li class="picked">D</li></ul><p dir="auto">123 مرحبا</p><q lang="fr-CA">Q</q><details open></details></body></html>')
	local list=Node.findElement(document,function(n)return n.Name=='ul'end)
	local function match(node,text)return Selectors.matches(node,assert(Selectors.compile(text)))end
	assert(match(list.Children[1],'.caf\\e9')and match(list.Children[1],'.café'))
	assert(match(list.Children[3],'li:nth-child(2n of .picked)'))
	assert(not match(list.Children[2],'li:nth-child(2n of .picked)'))
	assert(match(list.Children[3],'li:nth-last-child(2 of .picked)'))
	local specific=assert(Selectors.compile('li:nth-child(2n of .picked, #important)')).Specificity
	assert(specific[1]==1 and specific[2]==1 and specific[3]==1)
	list.Children[2].Attributes.class='picked'
	assert(match(list.Children[2],'li:nth-child(2n of .picked)')and not match(list.Children[3],'li:nth-child(2n of .picked)'))
	assert(match(list,':lang(de)'))
	assert(match(Node.findElement(document,function(n)return n.Name=='q'end),':lang(en, fr)'))
	assert(match(Node.findElement(document,function(n)return n.Name=='p'end),':dir(rtl)'))
	assert(match(Node.findElement(document,function(n)return n.Name=='details'end),':open'))
	assert(Selectors.compile('.123')==nil and Selectors.compile(':nth-of-type(2 of .picked)')==nil)
	assert(Syntax.unescape('a\\00002e b')=='a.b'and Syntax.unescape('\\0')==utf8.char(0xfffd))
	local token,after=Syntax.scan('a\\;b;c',1,';');assert(token=='a\\;b'and after==6)
	local svg=Node.element('text',{['xlink:href']='#a'});svg.NamespaceURI='http://www.w3.org/2000/svg'
	svg.AttributeNamespaces={['xlink:href']={Namespace='http://www.w3.org/1999/xlink',LocalName='href',Prefix='xlink'}}
	local namespaces={svg=svg.NamespaceURI,xlink='http://www.w3.org/1999/xlink'}
	assert(Selectors.matches(svg,assert(Selectors.compile('svg|text[xlink|href="#a"]',nil,namespaces))))
	assert(not Selectors.matches(svg,assert(Selectors.compile('|text'))))
	local function query(text,env)local parsed=assert(Media.compile(text),text);return Media.matches(parsed,env)end
	assert(query('(500px <= width <= 900px)',{Width=500})and query('(900px >= width > 500px)',{Width=900}))
	assert(not query('(500px < width < 900px)',{Width=500}))
	assert(query('((width > 40rem) or (height > 700px)) and (hover)',{Width=400,Height=800,Hover=true}))
	assert(query('(aspect-ratio >= 4/3)',{Width=800,Height=600}))
	assert(query('(resolution:192dpi)',{Resolution=2})and query('(width)',{Width=1}))
	assert(not query('(width)',{Width=0})and not query('(monochrome)',{}))
	assert(not query('(1px < width > 100px)',{Width=50}))
	assert(not query('(width>2px) or (height>2px) and (hover)',{Width=50,Height=50,Hover=true}))
	assert(Container.matches({assert(Container.compile('karte (width > 420px) and (width < 800px)'))},{Names={'karte'},Width=500,Height=200}))
	assert(not Container.matches({assert(Container.compile('karte (width > 420px)'))},{Names={'other'},Width=500}))
	local context={FontSize=20,RootFontSize=18,XHeight=9,ZeroAdvance=11,ViewportWidth=1000,ViewportHeight=600,SmallViewportWidth=800,DynamicViewportHeight=500,ContainerWidth=400,ContainerHeight=200}
	local function pixels(source,expected)local value=assert(Length.parse(source,context),source);assert(math.abs(Length.resolve(value,200)-expected)<1e-5,source)end
	for _,source in {'1in','2.54cm','25.4mm','101.6q','72pt','6pc'}do pixels(source,96)end
	pixels('3ex',27);pixels('2ch',22);pixels('10cqw',40);pixels('10cqh',20);pixels('10svw',80);pixels('10dvh',50);pixels('10vi',100)
	context.WritingMode='vertical-rl';pixels('10vi',60);pixels('10cqi',20)
	pixels('clamp(20px, calc(2cqw + 1ch), 30px)',20)
	local styled=Style.resolve(Node.element('div',{style='c\\6flor:red;--grö\\73 se:2ex;width:var(--grösse);padding:1ex;min-width:2ex;max-height:20%;margin:auto 2ex;text-indent:2ex;letter-spacing:1ex;word-spacing:1ex'}),{FontSize=20,Font='Arial'},error)
	assert(styled.Color.R==1 and styled.Width.Value==20 and styled.Padding[1]==10 and styled.MinWidth.Value==20 and styled.MaxHeight.Percent and styled.MarginAuto[1]and styled.Margin[2]==20 and styled.TextIndent.Value==20 and styled.LetterSpacing==10 and styled.WordSpacing==10,'Escaped declarations and Unicode variables reach actual length fields')
	assert(Length.usesViewport('calc(2cqw + 3dvh)')and not Length.usesViewport('20ch'))
	local target=Node.element('div',{id='x'});local inherited={FontSize=16,Font='Arial',Color=Color3.new(0,0,0)}
	local rules=Sheet.collect(target,error,'@layer base,theme;@layer base{#x{color:red;padding:1em;background:green}}@layer theme{#x{font-size:32px;color:blue;padding:9px;background:blue}#x{padding:revert-layer;color:revert-layer}}')
	local layered=Style.resolve(target,inherited,error,false,Sheet.match(rules,target));assert(layered.Color.R==1 and layered.Color.B==0 and layered.FontSize==32 and layered.Padding[1]==32,'Rollback chooses lower values at final font basis')
	target.Attributes.style='background:revert-layer!important;color:revert';local inlineRollback=Style.resolve(target,inherited,error,false,Sheet.match(rules,target));assert(inlineRollback.Background.B==1 and inlineRollback.Color==inherited.Color,'Inline layer rollback keeps author layers while origin rollback uses UA/inheritance')
	target.Attributes.style='';local important=Sheet.collect(target,error,'@layer base,theme;@layer base{#x{color:red!important}#x{color:revert-layer!important}}@layer theme{#x{color:blue!important}}')
	assert(Style.resolve(target,inherited,error,false,Sheet.match(important,target)).Color.B==1,'Important layer rollback respects reversed layer priority')
	print('CSS Atelier core: escaped identifiers, filtered sibling mutation/specificity, language/direction, namespaces, range/boolean queries and dimensional axes passed')
end
