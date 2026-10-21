# Pseudo computed content

`getComputedStyle(element, '::before' | '::after' | '::marker').content` returns the supported content value in CSSOM form. The legacy `:before` and `:after` aliases and ASCII case variants are accepted. Unsupported pseudo names return an empty declaration view.

Default and explicit `normal` become `none` on `::before` and `::after`; they remain `normal` on an ordinary element and `::marker`. Explicit `none` stays `none`. Adjacent strings and `attr()` substitutions combine into one quoted string, and live attribute changes are reflected on the next read. CSSOM serialization escapes quotation marks, backslashes, ASCII controls and DEL; NUL becomes U+FFFD. This serialization does not add CSS escape parsing to author content strings.

`counter()` and `counters()` remain symbolic functions in the computed value. They do not return the digits already painted by the renderer. Default `decimal` arguments are omitted; counter separators are quoted strings. Quote keywords likewise remain keywords. Native rendered digits are checked separately from serialization.

There is one documented Chromium difference. Explicit `content: inherit` follows CSS Cascade and inherits the originating element's content in this engine. The captured Chromium build suppresses that pseudo content; this also appears in WebKit's issue tracker. The fixture stores the actual native output and the standards/WPT expectation separately. We retain explicit inheritance rather than reproducing that browser defect.

References:

- [CSS Generated Content: content computation](https://www.w3.org/TR/css-content-3/#content-property)
- [CSSOM string serialization](https://drafts.csswg.org/cssom/#serialize-a-string)
- [CSS Cascade: inherit](https://www.w3.org/TR/css-cascade-5/#inherit)
- [WPT explicit generated-content inheritance](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/generated-content/content-inherit-001.xht)
- [WebKit issue18587](https://bugs.webkit.org/show_bug.cgi?id=18587)

Validation uses `tests/fixtures/pseudo-content-native.json`, captured from the actual browser, and `tests/JavaScriptPseudoContent.luau`, which runs the same sources through mounted retained rendering. Thirteen cases agree with the native reference; the explicit-inheritance case checks the documented standard behavior. No FPS benchmarks are performed.
