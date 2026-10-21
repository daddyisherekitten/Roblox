# Links und Website-Adressen

## Interne Seiten

Jede Seite besitzt eine vollständige browserfähige Adresse. Zum Beispiel:

```lua
URL = "http://localhost:8000/main/index.html"
```

Im HTML stehen normale relative URLs:

```html
<a href="../css-background-position/index.html">Background positions</a>
<a href="../css-background-position/index.html#top">Background test top</a>
<a href="#top">Back to top</a>
```

Sie funktionieren unverändert im lokalen Browser und in Roblox. Der Roblox-
Modulname `CSSBackgroundPosition` gehört nur zur Startkonfiguration und wird nicht
als `href` verwendet.

Unterstützte URL-Formen:

- relative Pfade wie `../css-background-position/index.html`
- absolute lokale Pfade wie `/css-background-position/index.html`
- Ordneradressen wie `/css-background-position/` als Alias für `index.html`
- Query-Strings wie `?mode=compact`
- Fragmente wie `#base-target`, einschließlich `%xx`-Dekodierung
- externe Schemas wie `https:`, `mailto:` und `tel:` über `options.Navigate`

Während der Entwicklung ist die Origin `http://localhost:8000`. Eine spätere
öffentliche Domain kann als viertes Generatorargument gesetzt werden:

```powershell
python scripts/sync-website.py main Main "HTML Engine Test Pages" https://example.com
```

## Verhalten von `<a>`

Ein `<a>` mit `href` erhält Linkfarbe, Unterstreichung und Pointer-Cursor,
sofern CSS das nicht überschreibt. Es kann mit Maus oder Touch geklickt, mit Tab
fokussiert und mit Enter aktiviert werden. Ein Anker ohne `href` bleibt ein
normaler Platzhalter.

Vor der Standardnavigation wird ein `click`-Ereignis ausgelöst und kann
abgebrochen werden:

```lua
page:On("css-background-position-link", "click", function(event)
    event:PreventDefault()
end)
```

`href`, `target`, `download`, `rel`, `hreflang`, `type`, `referrerpolicy` und
`ping` werden an den Navigations-Callback weitergegeben. `_blank` erzeugt in
Roblox keinen zweiten Tab. Downloads und `ping` werden nicht ausgeführt.

## Fragmente und fehlende Seiten

`#id` scrollt den Seiten-`ScrollingFrame` zum Element. Historische
`<a name="ziel">`-Ziele werden ebenfalls erkannt. Bei einem Seitenwechsel wird
erst die neue Seite aufgebaut und danach zum Fragment gescrollt.

Eine lokale Adresse ohne registrierte Website öffnet die Seite `NotFound` und
setzt `HTTPStatus` auf 404. Externe Ziele öffnet die Engine nicht selbst; darüber
entscheidet die Anwendung im `Navigate`-Callback.

Noch fehlen Navigationsverlauf, separate Tabs/Fenster, Downloads, Link-Audits,
Referrer-Übertragung sowie `area`/Image-Maps und `:visited`-Historie.
