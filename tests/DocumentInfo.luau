--!strict
return function(Parser: any, DocumentInfo: any, Links: any)
	local diagnostics = {}
	local document = Parser.parse([[
<!doctype html><html><head>
<title>  Northstar
  Test  </title>
<link rel="stylesheet" href="theme/site.css">
<base href="../assets/" target="preview">
<base href="https://ignored.example/" target="ignored">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="theme-color" content="#123456">
<meta name="referrer" content="no-referrer">
<meta http-equiv="refresh" content="30">
</head><body><svg><title>SVG title</title></svg></body></html>
]])
	local info = DocumentInfo.collect(document, "http://localhost:8000/site/index.html", function(message)
		table.insert(diagnostics, message)
	end)
	assert(#diagnostics == 0)
	assert(info.Title == "Northstar Test", "The first HTML title collapses ASCII whitespace and ignores SVG title")
	assert(info.DocumentURL == "http://localhost:8000/site/index.html")
	assert(info.BaseURL == "http://localhost:8000/assets/" and info.DefaultTarget == "preview", "Only the first base href and target apply")
	assert(#info.Links == 1 and info.Links[1].URL == "http://localhost:8000/assets/theme/site.css", "Base applies even to an earlier link element")
	assert(info.Charset == "utf-8")
	assert(info.Viewport.width == "device-width" and info.Viewport["initial-scale"] == "1")
	assert(info.ThemeColor == "#123456" and info.ReferrerPolicy == "no-referrer")
	assert(info.HTTPPragmas.refresh == "30")
	local anchor = Parser.parse('<a href="pages/help.html">Help</a>').Children[1]
	local link = Links.data(anchor, {BaseURL=info.BaseURL, DefaultTarget=info.DefaultTarget})
	assert(link.Href == "pages/help.html" and link.URL == "http://localhost:8000/assets/pages/help.html" and link.Target == "preview", "Anchors consume document base URL and default target")

	diagnostics = {}
	info = DocumentInfo.collect(Parser.parse('<meta charset="windows-1252"><title>A</title><title>B</title>'), "/index.html", function(message)
		table.insert(diagnostics, message)
	end)
	assert(info.Title == "A" and #diagnostics == 1 and diagnostics[1]:find("windows%-1252"), "First title wins and unsupported post-decode charset is explicit")
	info=DocumentInfo.collect(Parser.parse('<base target=""><base target="later">'),"https://example.test/page")
	assert(info.DefaultTarget=="","An empty first base target still overrides later targets")
	info=DocumentInfo.collect(Parser.parse('<base target="bad&#10;name">'),"https://example.test/page")
	assert(info.DefaultTarget=="_blank","Unsafe base target characters use the browser fallback")
	info=DocumentInfo.collect(Parser.parse('<base target="bad&#13;name">'),"https://example.test/page")
	assert(info.DefaultTarget=="_blank","A carriage return is an ASCII newline for the effective target")
	for _,href in {"data:text/html,ignored", "JavaScript:void(0)", " java&#9;script:void(0)&#13; "} do
		info=DocumentInfo.collect(Parser.parse('<base href="'..href..'"><base href="https://later.example/">'),"https://example.test/page")
		assert(info.BaseURL=="https://example.test/page","A data/javascript first base uses the document fallback and does not let a later base take over: "..href)
	end
	print("Document metadata: title, base URL/target, meta records and resolved link resources passed")
end
