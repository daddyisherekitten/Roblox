# Kleine HTML-/CSS-Ergänzungen

- row-gap/column-gap: einzelne Gap-Achsen in 0/px/normal; normal entspricht bei
  Flex 0. gap setzt beide Achsen zurück, Longhands nur eine. Keine Prozentwerte.
- inset: 1–4 Werte für top/right/bottom/left, auto/0/signierte px/%. Kurzform,
  Longhands, Stylesheets und !important folgen derselben Cascade. auto bleibt
  beim Verteilen der Werte erhalten; ungültige Deklarationen ersetzen nichts.
- font-size:larger: Elternschrift ×1.2, auf die bisherige Enginegrenze100px
  begrenzt. Wie smaller eine relative Näherung; Browser-Schlüsselworttabellen
  und Schriftgrößen außerhalb des bisherigen Bereichs können abweichen.
- text-align:start/end: in der unterstützten LTR-Schreibrichtung links/rechts;
  vererbt und mit Zeilenumbruch/text-align-last kombinierbar. Kein RTL.
- border-width:thin/medium/thick: 1/3/5px, ebenfalls im border-Shorthand.
  Nur Rahmenbreiten: padding, tab-size und border-radius akzeptieren die Wörter
  weiterhin nicht. Einzelne Rahmenkanten sind nicht neu implementiert.
- Alle 148 CSS-Farbnamen einschließlich gray/grey und aqua/cyan. Die statische
  Tabelle in CSS/NamedColors stammt aus der W3C-Tabelle. Keine Netzwerkanfrage
  zur Laufzeit; Color3-Werte werden einmal beim Laden von CSS/Color erzeugt.
- ins: unterstrichener Inline-Text wie u.
- kbd/samp: Inline-Monospace über Roboto Mono wie code.
- var/cite/dfn: kursive Inline-Texte wie i. Autoren-CSS kann Defaults ersetzen.
  Keine neuen Interaktionen, Navigation, Ausführung oder Tooltips.

Beispiel10 kombiniert die neuen Tags, größere Schrift, beide Textausrichtungen,
Farbnamen, beide Gap-Achsen und drei Rahmenstärken in drei kleinen Karten.
Das bestehende Badge in Beispiel9 verwendet nun inset. Das vollständige HTML
ist im Browser und Seitenskript identisch. Auf Nutzerwunsch verwendet die Demo
nur Roboto, sans-serif und Roboto Mono, monospace, ohne Google-Fonts-Links.
Der Browser benötigt diese Schriften lokal; sonst greift die Ersatzschrift.

## Codeprüfung

Geprüft wurden die geänderten Element-/CSS-Kataloge, Parsing/Cascade,
Farbauflösung, die Einbindung in RenderTree, Wort-/Fontlayout sowie Flex- und
Positionslayout. Die neuen Funktionen verwenden vorhandene Darstellungswege.
Katalogangaben zu div/Flex, start/end, Rahmenkeywords und Dekorationsalpha wurden
berichtigt. Die frühere Inset-Zahlengrammatik akzeptierte -+2px; sie lehnt doppelte
Vorzeichen jetzt ab. Regressionen decken den Fall sowie auto-Platzhalter,
Kurzform-Resets und !important ab. Namenstabelle separat von der Farblogik;
keine Änderung der Fontkalibrierungen. Keine vollständige native Sichtprüfung.

tests/SimpleFeatures prüft neben Parsing/Defaults die tatsächliche Flexposition,
Badgeposition bei Resize, Textausrichtung, Inline-Tags, Autorenüberschreibungen,
alle Farbnamen und die Wiederverwendung von Labels/Textmaßen. Bestehende
Ablehnungstests für nun unterstützte Werte wurden aktualisiert; frühere
Regressionen bleiben erhalten. Der Projektaudit prüft zusätzlich sämtliche
Luau-Dateien, JS-/HTML-Syntax und lokale Ressourcenverweise.

Grundlagen: [CSS-Farben](https://www.w3.org/TR/css-color-4/#named-colors),
[Gap](https://www.w3.org/TR/css-align-3/#gaps),
[Rahmenbreiten](https://www.w3.org/TR/css-backgrounds-3/#border-width) und
[HTML-Darstellungsdefaults](https://html.spec.whatwg.org/multipage/rendering.html#phrasing-content-3).
