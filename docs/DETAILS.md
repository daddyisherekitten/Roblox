# Aufklappbare Bereiche

```html
<details>
  <summary>Weitere Informationen</summary>
  <p>Dieser Inhalt erscheint beim Aufklappen.</p>
</details>
```

`details` ist zunächst geschlossen; mit `open` ist der Inhalt beim Start sichtbar.
Das Attribut ist boolesch: Auch `open="false"` bedeutet geöffnet. Das erste direkte
`summary` ist der aktive Titel und steht visuell vor dem restlichen Inhalt. Weitere
`summary`-Elemente und alleinstehende Summarys sind normale Blöcke. Ohne Titel
erscheint „Details“. Formatierte Titel verwenden das vorhandene Textlayout.

Mausklick, Touch-Tippen und Enter/Leertaste am fokussierten Titel wechseln den
Zustand. Ein abgebrochenes `click`-Event verhindert das Umschalten. Tab/Shift+Tab
berücksichtigen den Titel und überspringen zugeklappte Nachfahren. Die Anzeige
verwendet passive Frames/TextLabels mit zentralem Controller, keine GuiButtons.
Der Dreieckspfeil folgt Schriftgröße und Farbe; der Fokusrahmen verändert keine Maße.
Der Titel zeigt den Fokusrahmen bei Tastaturbedienung, nicht beim Anklicken oder
Antippen zum Auf-/Zuklappen.
Die Pfeilkontur folgt der Nutzerreferenz: bei 18px CSS-Schrift 10×12px sichtbare
Fläche und 19px Vorschub bis zum Titel. Passive horizontale Runs übernehmen die
gemessenen Randtransparenzen; die Unterkante liegt auf der Textgrundlinie.

Rendering/Disclosure verwaltet den Zustand, den anonymen Inhaltscontainer und den
Marker. Geschlossene Inhalte bleiben im Renderbaum als `AllChildren` erhalten,
sind jedoch unsichtbar und nicht Teil der aktuellen `Children` für das Layout.
DirtyLayout registriert auch diese Bereiche und akzeptiert die Details-Box als
gezieltes Änderungsziel. Beim Öffnen/Schließen werden betroffene Layoutbereiche
berechnet; davor liegende unabhängige Teilbäume können wiederverwendet werden.
Vorhandene GUIs, Editorwerte und Zustände verschachtelter Details bleiben erhalten.

Die Original-DOM-Struktur bleibt erhalten; nur das `open`-Attribut wird beim
Umschalten geändert. Anonyme Container und der optionale Ersatztitel gehören nur
zum Renderbaum. Formularwerte aus geschlossenen Details werden weiterhin übertragen;
ein Formular-Reset setzt die Werte zurück und ändert den Aufklappzustand nicht.

`HTMLDetailsElement.open` und `.name` reflektieren die Attribute. Autoren-CSS
wird beim Umschalten neu ausgewertet, einschließlich `[open]`, `:open`,
Nachfahren, Geschwistern und `:has()`-Vorfahren. MutationObserver erhält die
normalen Attributmutationen auch bei nativer Aktivierung.

Seit dem 8. Oktober 2026 erzwingt [DetailsState](../src/HTMLEngine/DOM/DetailsState.luau)
exklusive Gruppen mit gleichen, nichtleeren `name`-Werten im selben DOM-Baum.
Öffnen schließt das andere Gruppenmitglied; Umbenennen und Einfügen schließen
gegebenenfalls das gerade bearbeitete Element. Parserattribute und -einfügungen
folgen diesen Regeln ebenfalls. Shadow-Bäume und getrennte, auch nicht
verbundene Bäume haben getrennte Gruppen. Namen werden exakt verglichen.

`toggle` wird als vertrauenswürdiges, nicht abbrechbares, nicht bubbelndes
`ToggleEvent` in einer eigenen Task ausgeliefert. Mehrere Änderungen vor
Auslieferung behalten den ursprünglichen `oldState` und den letzten `newState`;
auch Rückkehr zum Ausgangszustand kann ein Ereignis liefern. Reentrante
Listener folgen dem Task-Tracker des HTML-Standards. Attributwechsel ohne
Änderung der Anwesenheit von `open` erzeugen kein Toggle. `details` hat im
Standard kein `beforetoggle`-Ereignis. Gruppenänderungen während eines aktiven
Layouts ändern sofort das DOM; die zusammengehörigen GUI-Updates werden erst
am sicheren Layoutende publiziert. Ausstehende Tasks werden beim Abbau beendet.

Weiter offen: automatische Offenlegung für Fokus/Validierung, zusätzliche
Marker-/Summary-Displaykombinationen sowie Animation über diskrete
Inhaltsdarstellung. Standardmarker und native Fokusdarstellung bleiben
angenähert. Das ist keine Einschränkung der nun belegten Gruppierungs- und
Ereignisalgorithmen.

Beispiel 30 in den synchronen Browser-/Studio-Demos. `tests/Details.luau` prüft
Startzustände, Fallback, DOM-Erhaltung, Maus/Touch/Tastatur, Klickabbruch, Tab,
Formulardaten/Reset, Verschachtelung, Editor-Erhaltung und Teil-/Voll-Layout.
`tests/DetailsGroups.luau` ergänzt Parser-/Fragmentgruppen, dynamische Namen,
Einfügen/Verschieben, Detached-/Shadow-/Fremdnamespacefälle, Eventbrand und
Flags, Koaleszierung/Reentranz, Observerreihenfolge und Taskabbau. Die native
Details-Suite prüft zusätzlich beide GUI-Ziele einer Gruppenänderung,
verzögerte Ereignisse und Publikation nach aktivem Layout.
GUI-/Messungs-Mocks ersetzen den visuellen Studio-Vergleich nicht.

Referenz: [HTML details und summary](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-details-element).
