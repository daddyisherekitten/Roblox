# Dialoge

Die Engine rendert `show-modal` in einer festen Top-Layer-Ebene über dem
Seiteninhalt. Ein nichtmodaler `show`-Dialog bleibt dagegen wie im Browser an
seiner statischen Dokumentposition und scrollt natürlich mit der Seite.
Geschlossene Dialoge bleiben im Dokument, sind aber unsichtbar, nicht
anklickbar und aus Tab-Reihenfolge sowie `autofocus` ausgeschlossen.

Browserkompatible deklarative Schaltflächen öffnen und schließen Dialoge ohne
seitenspezifischen Roblox-Code:

```html
<button type="button" commandfor="confirm" command="show-modal">Open</button>
<dialog id="confirm" closedby="any">
  <form method="dialog">
    <p>Continue?</p>
    <button value="cancel">Cancel</button>
    <button value="confirmed">Confirm</button>
  </form>
</dialog>
```

Unterstützte Befehle sind `show`, `show-modal`, `close` und `request-close`.
`closedby="none"` sperrt Escape, `closedby="closerequest"` erlaubt Escape und
`closedby="any"` zusätzlich einen Klick außerhalb. Ein modales Dialogfenster
blockiert Treffer und Tastaturfokus außerhalb seines Inhalts. Das Absenden
eines Formulars mit `method="dialog"` schließt das Fenster und übernimmt den
`value` des Submitters als Rückgabewert.

Für Roblox-Code stehen `page:ShowDialog(id)`, `page:ShowModal(id)` und
`page:CloseDialog(id, returnValue)` bereit. Die frühere sichtbare Dialogseite
wurde beim Neustart des Testkatalogs entfernt; `tests/Dialog.luau` deckt das
Verhalten weiterhin ab.

Die DOM-Wrapper besitzen inzwischen `show`, `showModal`, `close` und
`requestClose` sowie `open`, `returnValue` und `closedBy`. Dialogereignisse,
Fokuswiederherstellung, gemeinsame Reihenfolge gestapelter Dialoge/Popover,
dynamische DOM-/Attributänderungen und `::backdrop`-CSS sind an den Renderer
angeschlossen. Den geprüften Teilumfang und verbleibende Grenzen beschreibt
[JAVASCRIPT-TOP-LAYER.md](JAVASCRIPT-TOP-LAYER.md); Vergleich 06 zeigt die APIs.
