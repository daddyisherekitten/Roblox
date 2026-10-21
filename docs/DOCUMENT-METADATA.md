# Dokumentkopf und Metadaten

Beim Mount wertet die Engine den Dokumentkopf einmal aus. Die gemeinsame
Auswertung liegt in `HTML/DocumentInfo.luau` und liefert:

- den Text des ersten HTML-`title` mit zusammengefasstem ASCII-Leerraum,
- die Dokumentadresse aus `options.DocumentURL`,
- `href` und `target` der jeweils ersten passenden `base`-Angabe,
- alle `meta`-Datensätze,
- strukturierte Werte für `viewport`, `theme-color` und `referrer`,
- alle `link`-Datensätze mit gegen die Basis-URL aufgelöster Adresse.

`HTMLPageDemo` übergibt die URL des ausgewählten Website-Moduls automatisch als
`DocumentURL`. Bei direkter Nutzung der Engine kann sie so gesetzt werden:

```lua
local page = Engine.mountHTML(target, html, {
	DocumentURL = "http://localhost:8000/site/index.html",
	Stylesheets = {
		["http://localhost:8000/assets/site.css"] = css,
	},
})
```

Die Ergebnisse sind über `page.Title`, `page.DocumentURL`, `page.BaseURL`,
`page.DefaultTarget`, `page.Metadata` und `page.DocumentInfo` verfügbar. Das
Root-GUI spiegelt die wichtigsten Zeichenketten als Attribute `Title`,
`DocumentURL`, `BaseURL`, `DefaultTarget`, `Charset`, optional `ThemeColor` und
optional `ReferrerPolicy`.

Relative Hyperlinks und lokale Stylesheet-Links verwenden dieselbe Basis-URL.
Ein `base target` wird für Links ohne eigenes `target` übernommen. Bei lokalen
Stylesheets werden ein exakter `href`, die aufgelöste vollständige URL und der
aufgelöste Pfad als Schlüssel akzeptiert. `disabled`, `type` sowie die einfachen
Medienwerte leer, `all` und `screen` werden berücksichtigt.

## Offene Grenzen

- Die Auswertung findet einmal beim Mount statt; spätere DOM-Änderungen
  aktualisieren Titel, Basis-URL oder Metadaten noch nicht.
- Der HTML-Parser erzeugt `html`, `head` und `body` noch nicht implizit.
- `meta`-Pragmas werden gesammelt, aber bis auf die strukturierten Werte nicht
  ausgeführt. Der HTML-String ist beim Aufruf bereits von Luau decodiert, daher
  kann ein `meta charset` die Byte-Decodierung nicht nachträglich ändern.
- Stylesheets stammen weiterhin aus `options.Stylesheets`; es gibt keine
  automatische HTTP-Abfrage.
- Andere `link`-Beziehungen wie Icon, Manifest, Preload und Canonical werden als
  Metadaten gespeichert, aber noch nicht ausgeführt.
- `script` bleibt parser-only und wird nicht als JavaScript ausgeführt.

