--!strict
-- The Chromium originals are required; two lone-surrogate poster writes and
-- their three retained continuation states use the frozen USV projection.
return function(Parser,Runtime,Events,fixture)
 local expectedCases={
  ['extra:poster DOMString content scalar getter fallback']=true,
  ["basic:attribute width null"]=true,
  ["basic:attribute width \"\""]=true,
  ["basic:attribute width \"23\""]=true,
  ["basic:attribute width \"23px\""]=true,
  ["basic:attribute width \" 23\""]=true,
  ["basic:attribute width \"-2\""]=true,
  ["basic:attribute width \"+23\""]=true,
  ["basic:attribute width \"3.7\""]=true,
  ["basic:attribute width \"0\""]=true,
  ["basic:attribute width \"2147483647\""]=true,
  ["basic:attribute width \"2147483648\""]=true,
  ["basic:attribute width \"4294967295\""]=true,
  ["basic:attribute width \"4294967296\""]=true,
  ["basic:attribute width \"1e2\""]=true,
  ["basic:attribute width \"023\""]=true,
  ["basic:attribute width \"0x10\""]=true,
  ["basic:attribute width \"\\n5\""]=true,
  ["basic:attribute width \"NaN\""]=true,
  ["basic:attribute height null"]=true,
  ["basic:attribute height \"\""]=true,
  ["basic:attribute height \"23\""]=true,
  ["basic:attribute height \"23px\""]=true,
  ["basic:attribute height \" 23\""]=true,
  ["basic:attribute height \"-2\""]=true,
  ["basic:attribute height \"+23\""]=true,
  ["basic:attribute height \"3.7\""]=true,
  ["basic:attribute height \"0\""]=true,
  ["basic:attribute height \"2147483647\""]=true,
  ["basic:attribute height \"2147483648\""]=true,
  ["basic:attribute height \"4294967295\""]=true,
  ["basic:attribute height \"4294967296\""]=true,
  ["basic:attribute height \"1e2\""]=true,
  ["basic:attribute height \"023\""]=true,
  ["basic:attribute height \"0x10\""]=true,
  ["basic:attribute height \"\\n5\""]=true,
  ["basic:attribute height \"NaN\""]=true,
  ["basic:setter width -1"]=true,
  ["basic:setter width NaN"]=true,
  ["basic:setter width Infinity"]=true,
  ["basic:setter width 2147483648"]=true,
  ["basic:setter width 4294967295"]=true,
  ["basic:setter width 4294967296"]=true,
  ["basic:setter width 4.7"]=true,
  ["basic:setter width true"]=true,
  ["basic:setter width null"]=true,
  ["basic:setter width undefined"]=true,
  ["basic:setter width \"5\""]=true,
  ["basic:setter height -1"]=true,
  ["basic:setter height NaN"]=true,
  ["basic:setter height Infinity"]=true,
  ["basic:setter height 2147483648"]=true,
  ["basic:setter height 4294967295"]=true,
  ["basic:setter height 4294967296"]=true,
  ["basic:setter height 4.7"]=true,
  ["basic:setter height true"]=true,
  ["basic:setter height null"]=true,
  ["basic:setter height undefined"]=true,
  ["basic:setter height \"5\""]=true,
  ["basic:initial"]=true,
  ["basic:relative poster"]=true,
  ["basic:base changes getter"]=true,
  ["basic:empty poster"]=true,
  ["basic:USV poster"]=true,
  ["basic:inline true"]=true,
  ["basic:inline string false"]=true,
  ["basic:inline false"]=true,
  ["deep:six video presentation descriptors"]=true,
  ["deep:poster getter {}"]=true,
  ["deep:poster getter document.getElementById(\"a\")"]=true,
  ["deep:poster getter HTMLVideoElement.prototype"]=true,
  ["deep:poster getter document.createElementNS(\"urn:foreign\",\"video\")"]=true,
  ["deep:poster getter document.createElementNS(\"http://www.w3.org/1999/xhtml\",\"x:video\")"]=true,
  ["deep:width getter {}"]=true,
  ["deep:width getter document.getElementById(\"a\")"]=true,
  ["deep:width getter HTMLVideoElement.prototype"]=true,
  ["deep:width getter document.createElementNS(\"urn:foreign\",\"video\")"]=true,
  ["deep:width getter document.createElementNS(\"http://www.w3.org/1999/xhtml\",\"x:video\")"]=true,
  ["deep:height getter {}"]=true,
  ["deep:height getter document.getElementById(\"a\")"]=true,
  ["deep:height getter HTMLVideoElement.prototype"]=true,
  ["deep:height getter document.createElementNS(\"urn:foreign\",\"video\")"]=true,
  ["deep:height getter document.createElementNS(\"http://www.w3.org/1999/xhtml\",\"x:video\")"]=true,
  ["deep:playsInline getter {}"]=true,
  ["deep:playsInline getter document.getElementById(\"a\")"]=true,
  ["deep:playsInline getter HTMLVideoElement.prototype"]=true,
  ["deep:playsInline getter document.createElementNS(\"urn:foreign\",\"video\")"]=true,
  ["deep:playsInline getter document.createElementNS(\"http://www.w3.org/1999/xhtml\",\"x:video\")"]=true,
  ["deep:videoWidth getter {}"]=true,
  ["deep:videoWidth getter document.getElementById(\"a\")"]=true,
  ["deep:videoWidth getter HTMLVideoElement.prototype"]=true,
  ["deep:videoWidth getter document.createElementNS(\"urn:foreign\",\"video\")"]=true,
  ["deep:videoWidth getter document.createElementNS(\"http://www.w3.org/1999/xhtml\",\"x:video\")"]=true,
  ["deep:videoHeight getter {}"]=true,
  ["deep:videoHeight getter document.getElementById(\"a\")"]=true,
  ["deep:videoHeight getter HTMLVideoElement.prototype"]=true,
  ["deep:videoHeight getter document.createElementNS(\"urn:foreign\",\"video\")"]=true,
  ["deep:videoHeight getter document.createElementNS(\"http://www.w3.org/1999/xhtml\",\"x:video\")"]=true,
  ["deep:poster setter brand before conversion"]=true,
  ["deep:width setter brand before conversion"]=true,
  ["deep:height setter brand before conversion"]=true,
  ["deep:playsInline setter brand before conversion"]=true,
  ["deep:videoWidth readonly assignments"]=true,
  ["deep:videoHeight readonly assignments"]=true,
  ["deep:poster = null"]=true,
  ["deep:poster = undefined"]=true,
  ["deep:poster = Symbol(\"s\")"]=true,
  ["deep:poster = ({toString(){return \"cover.png\"}})"]=true,
  ["deep:poster = ({toString(){throw new RangeError(\"marker\")}})"]=true,
  ["deep:poster = \"A\\uD800B\""]=true,
  ["deep:poster = \"A\\uD83D\\uDE00B\""]=true,
  ["deep:width = Symbol(\"s\")"]=true,
  ["deep:width = 1n"]=true,
  ["deep:width = ({valueOf(){return 19.8}})"]=true,
  ["deep:width = ({valueOf(){throw new RangeError(\"marker\")}})"]=true,
  ["deep:width = -4294967295"]=true,
  ["deep:width = 4294967297"]=true,
  ["deep:height = -4294967295"]=true,
  ["deep:height = 4294967297"]=true,
  ["deep:playsInline = false"]=true,
  ["deep:playsInline = 0"]=true,
  ["deep:playsInline = \"false\""]=true,
  ["deep:playsInline = []"]=true,
  ["deep:playsInline = Symbol(\"s\")"]=true,
  ["deep:relative current owner"]=true,
  ["deep:base-only changes getter"]=true,
  ["deep:adopt changes getter"]=true,
  ["deep:new owner base changes getter"]=true,
  ["deep:remove poster getter empty"]=true,
  ["deep:empty poster getter ownerbase"]=true,
 }
 local seen,rows,deltas={},0,0
 assert(#fixture.raw.basic.reflection==66 and #fixture.raw.basic.geometry==18,'Original basic native inventory')
 assert(#fixture.raw.deep.descriptors==6 and #fixture.raw.deep.brands==36 and #fixture.raw.deep.coercions==20 and #fixture.raw.deep.ownerBase==6 and #fixture.raw.deep.intrinsics==20,'Original deep native inventory')
 assert(#fixture.raw.dimensions.rawDimensions==24 and #fixture.raw.dimensions.cascade==14,'Original dimension native inventory')
 assert(fixture.target.sha=='49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f','Frozen HTML pin')
 local runtime,events,group
 local function destroy()if runtime then runtime:Destroy();events:Destroy();assert(not runtime.Alive and not runtime.EventLoop.Alive,'DOM realm cleanup');runtime=nil end end
 for _,case in fixture.domCases do
  local name=case.group..':'..case.name;assert(expectedCases[name]and not seen[name],'Unexpected or duplicated video case '..name);seen[name]=true
  if case.group~=group then
   destroy();group=case.group;events=Events.new(error)
   local base=if group=='basic'then 'https://video.test/one/'else 'https://video.test/a/'
   local html='<!doctype html>'..(if group=='extra'then ''else '<base href="'..base..'">')..'<video id="v"></video><audio id="a"></audio>'
   runtime=Runtime.new(Parser.parseDocument(html),{URL=if group=='extra'then 'about:blank'else 'https://video.test/root/index.html',Events=events,Schedule=function()end,ControlAdapter={}})
   assert(runtime:Run('var v=document.getElementById("v");var keys=["poster","width","height","playsInline","videoWidth","videoHeight"]'))
  end
  local ok,message=runtime:Run('window.videoPresentationResult=JSON.stringify('..case.action..')');assert(ok,name..': '..tostring(message))
  local actual=runtime.Window.Get('videoPresentationResult');local expected=case.targetExpected or case.expected
  if actual~=expected then print('Video expected',expected);print('Video actual',actual)end
  assert(actual==expected,name);assert(#runtime.Diagnostics==0,name..': '..table.concat(runtime.Diagnostics,' | '));rows+=1
  if case.normDelta then assert((case.normDelta=='poster-usv-lone-surrogate'or name=='extra:poster DOMString content scalar getter fallback'and case.normDelta=='poster-usv-scalar-getter')and case.expected~=case.targetExpected,'Exactly named USV projection');deltas+=1 end
 end
 for name in expectedCases do assert(seen[name],'Missing required video case '..name)end
 assert(rows==130 and deltas==6,'Complete video DOM raw/projection inventory');destroy()
 print('VideoPresentationDOM: '..rows..' named native cases, '..deltas..' explicit frozen USV projections passed')
end
