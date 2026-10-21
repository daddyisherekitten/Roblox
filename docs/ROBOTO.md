# Roboto in der HTML-Engine

Unterstützt werden die vier normalen Schriftfamilien (Regular): Roboto, Roboto Condensed, Roboto Mono und Roboto Slab.
Jede hat ein eigenes kleines Profil unter `src/HTMLEngine/Layout/FontProfiles`.
Roboto normal verwendet Faktor 1,13 mit Aufrunden. Der Nutzer hat die Größe bei HTML 10–50 px visuell bestätigt.
Roboto normal hat eigene Linienformeln aus fünf manuellen Messpunkten mit aufgerundeter TextSize (maximal 1 px Abweichung zu diesen Messpunkten). Sie berücksichtigen das Aufrunden; Zwischenwerte bleiben Näherungen. Daten: `measurements/roboto-guide-fit.json`.
Roboto Mono verwendet den vom Nutzer bestätigten Faktor 1,24 mit Aufrunden. Eigene Linienformeln aus dem neutralen FONT_REPORT beziehen sich auf tatsächliche Roblox-Textgrößen 10–50 und treffen gerundet alle fünf Messpunkte. Zwischenwerte sind Näherungen, größere TextSize-Werte extrapoliert. Rohdaten: `measurements/roboto-mono-height-comparison.md` und `measurements/roboto-mono-guide-fit.json`.
Condensed und Slab starten weiterhin mit Faktor 1; ihre Linien sind noch ungemessen.
Ubuntu und Arial behalten ihre bisherigen Einstellungen. Die Profile werden erst bei Verwendung geladen.

```html
<p style="font-family: Roboto; font-size: 50px">Roboto Beispiel</p>
<p style="font-family: 'Roboto Condensed'; font-size: 50px">Condensed Beispiel</p>
<p style="font-family: 'Roboto Mono'; font-size: 50px">Mono Beispiel</p>
<p style="font-family: 'Roboto Slab'; font-size: 50px">Slab Beispiel</p>
```

## Größen und Linien messen

1. Im Standardprojekt wählt `examples/StudioDemoConfig.luau` aktuell wieder `HTMLPage`. Für neue Messungen dort `FontLab` einstellen; der bestehende Rojo-Server kann weiterlaufen. Alternativ `rojo serve fontlab.project.json` verwenden.
2. In `examples/FontLab/FontTestConfig.luau` bei `Font` genau einen Namen aus der Tabelle eintragen. Aktuell ist dort `"Roboto Mono"` gewählt, mit bestätigtem Profilfaktor 1,24 und berechneten Startlinien.
3. Nach einem Wechsel Studio mit **Stop → Play** neu starten und die passende HTML-Datei in Chrome bei 100 % Zoom öffnen.
4. Die H-Höhen bei 10, 20, 30, 40 und 50 px auf beiden Seiten messen und mit dem Schriftnamen melden.
5. Erst den individuellen Faktor berechnen und prüfen. Danach die vier Linien einstellen und **Werte ausgeben** drücken. Den vollständigen `FONT_REPORT` kopieren.

| Font in der Konfiguration | Chrome-Datei | Roblox-Familie |
| --- | --- | --- |
| `"Roboto"` | `examples/roboto-comparison.html` | `rbxasset://fonts/families/Roboto.json` |
| `"Roboto Condensed"` | `examples/roboto-condensed-comparison.html` | `rbxasset://fonts/families/RobotoCondensed.json` |
| `"Roboto Mono"` | `examples/roboto-mono-comparison.html` | `rbxasset://fonts/families/RobotoMono.json` |
| `"Roboto Slab"` | `examples/roboto-slab-comparison.html` | `rbxassetid://12187368625` |

Der Mono-Vergleich lädt Roboto Mono Regular wie die HTML-Demo über Google Fonts. Die anderen Browserdateien nutzen die vorhandenen lokalen Schriftdateien des Katalogs 098–101. Den Ordner `fonts` daneben behalten.
Roboto Slab verwendet ein Schriftasset; bei einem Ladefehler zeigt der Test eine Fehlermeldung und blendet die Messschrift aus.
Die Tests bleiben außerhalb der Engine, und alle GUI-Elemente bleiben `Active = false`.
