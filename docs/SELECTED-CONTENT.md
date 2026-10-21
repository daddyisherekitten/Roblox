# Selected content

`selectedcontent` wird als Nachfahre des ersten `button` eines einfachen
`select` erkannt. Das Element selbst erzeugt keine zweite Roblox-GUI-Box; sein
Inhalt ist die bereits vorhandene geschlossene Select-Anzeige.

Bei der Auswahl wird zwischen zwei Texten unterschieden:

- Die Popup-Zeile verwendet `option[label]`, sofern dieses Attribut vorhanden
  ist.
- Die geschlossene Anzeige verwendet bei vorhandenem `selectedcontent` den
  normalisierten Textinhalt der `option` und ignoriert deren `label`-Attribut.

Maus, Touch, Tastatur, Präfixsuche, `page:SetValue` und Formular-Reset laufen
über denselben Auswahlzustand und aktualisieren die Anzeige ohne Seiten-Reflow.
Bei `multiple` ist `selectedcontent` wie im Standard deaktiviert.

Die frühere sichtbare Testseite wurde beim Neustart des Website-Katalogs
entfernt. Die Select-Tests prüfen weiterhin, dass eine Option mit dem Popup-Text
`Copper — popup label` im geschlossenen Feld ihren Inhaltswert `Copper sunset`
anzeigt.

Für diesen anpassbaren Select reserviert das Roblox-Popup links eine
Haken-Spalte. Nur die tatsächlich gewählte Option trägt dort das Zeichen `✓`; eine
vorläufig per Tastatur oder Maus hervorgehobene andere Zeile ändert ihn nicht.
Das geschlossene Feld verwendet außerdem ein gefülltes, nach unten gerichtetes
Dreieck wie die Browserreferenz. Die Hervorhebung verwendet das native
`base-select`-Grau `#e5e5e5` mit schwarzem Text. Normale Select-Felder behalten
ihren bisherigen Chevron und ihre blaue Popup-Auswahl. Optionen des
anpassbaren Pickers verwenden außerdem eine mindestens 40px hohe Zeile, damit
der vertikale Abstand der Browserdarstellung entspricht.

Der aktuelle Teilumfang spiegelt Text. Das Klonen und Rendern beliebiger
verschachtelter HTML-Kinder einer Option, dynamische DOM-Mutationen und mehrere
aktive `selectedcontent`-Knoten sind noch nicht vorhanden.
