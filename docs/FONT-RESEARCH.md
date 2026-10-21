# Roblox-Schriften: Recherche und Vergleichstest

Stand: 8. September 2026. 40 mitgelieferte Fontfamilien plus 91 im Creator Store; fünf Überschneidungen ergeben 126 unterschiedliche Familiennamen.
Die 91 Familienmanifeste aus dem Store wurden einzeln abgerufen. Zusätzlich wurden die lokalen Manifeste aus Roblox-Version `version-9fe94fb0e9d84c25` gelesen.
Alle 126 zugeordneten Testdateien enthalten die Zeichen `HxpgIl1O0`. Die sichtbare Übereinstimmung ist noch nicht bewertet. Der aktuelle Test ist eine einfache scrollbare Liste.
LegacyArial/LegacyArimo sind Varianten derselben Arimo-Dateien; NotoSansCJKFallback ist eine interne Ersatzschrift. Diese drei Manifeste zählen nicht als zusätzliche Testfamilien.

## Was bedeutet das für Arial?

Roblox hat Arial am 28. Mai 2024 durch Arimo ersetzt. Auch `LegacyArial.json` verweist in der geprüften Installation auf Arimo.
Der bisherige Projektname „Arial“ bezeichnet deshalb die Zuordnung HTML-Arial → Roblox-Arimo.
Unser Faktor 1,13 ist eine bisherige Größenanpassung für diese Zuordnung; er kann unterschiedliche Buchstabenformen nicht angleichen.
Quelle: [Roblox-Ankündigung zur Arial-Ablösung](https://devforum.roblox.com/t/introducing-builder-font-deprecating-gotham-and-arial/2868222/372).

## Verbindliches Messverfahren für neue Fonts

Neue Fontprofile werden immer gegen die tatsächlich an `TextLabel.TextSize` übergebene Ganzzahl
vermessen. Wenn die Engine `ceil(CSS-Größe × Größenfaktor)` verwendet, muss dieselbe Rundung im
Profil als `GuideSizeRounding = "ceil"` stehen und jeder `FONT_REPORT` muss sowohl `htmlSize` als
auch `robloxTextSize` enthalten. Eine Kurve gegen die ungerundete Zwischengröße ist nicht zulässig.

Die erste Messrunde enthält mindestens die CSS-Größen
`10, 13.333333, 16, 20, 30, 40, 50, 60, 70, 80`.
`13.333333` prüft native Formfelder, `16` normalen Webtext und Links. Für jede Größe werden
H-Oberkante, x-Oberkante, Basis/H-Unterkante und p-Unterkante gemessen. Danach werden alle
Engine-Tests und die Browser-Vergleichsseite geprüft.

Ein linear angepasstes Profil darf nur als Näherung bezeichnet werden; selbst viele Stützpunkte
garantieren wegen Rasterung und Font-Hinting keine exakten Zwischenwerte. Für eine 100-%-Aussage
über einen vereinbarten Größenbereich muss nach Bestimmung des Größenfaktors jede ganzzahlige
Roblox-`TextSize` in diesem Bereich gemessen und als exakter Tabellenwert gespeichert werden.
Vor dieser exakten Messrunde wird aus dem bestätigten Faktor die vollständige benötigte Größenliste
erstellt. Größen außerhalb des geprüften Bereichs bleiben ausdrücklich extrapoliert.

Echte Arial, Helvetica und Liberation Sans fehlen im abgerufenen Font-Katalog.
Roblox erlaubt aktuell keinen eigenen Fontimport; zusätzliche nutzbare Familien kommen aus dem Creator Store.
Quelle: [Roblox-Dokumentation zu Font-Assets](https://create.roblox.com/docs/projects/assets).

Für den neuen Vergleich wird jede Roblox-Schrift mit derselben Fontdatei in HTML verglichen. HTML lädt sie über `@font-face` bzw. die FontFace-API.
So werden Namensverwechslungen und abweichende Fontversionen vermieden. Beispielsweise enthält der Roblox-Inter-Eintrag Version 3.019;
eine aktuelle Inter-Datei aus einer anderen Quelle wäre nicht automatisch identisch. Größe, Darstellung der Pixelkanten und Linienpositionen bleiben zu prüfen.

## Neuen Test starten

```powershell
rojo serve fontcomparison.project.json
```

Im Studio mit diesem Rojo-Projekt verbinden, dann **Stop → Play**. Die Startdatei ist `examples/FontComparison.client.luau`.
Alternativ `build/FontComparison.rbxlx` in Studio öffnen und Play drücken.
Beim Wechsel keine alten Demo-LocalScripts zusätzlich laufen lassen: Der neue Test benötigt nur `FontComparisonDemo`.

In Chrome `examples/all-fonts-comparison.html` öffnen; die Datei `font-comparison-catalog.js` und den Ordner `fonts` daneben behalten.
Mit **Strg + 0** auf 100 % Zoom stellen. Jeweils dieselbe nummerierte Schrift vergleichen.

- Beide Seiten starten bei **50 px**, Gewicht 400 / normal, Faktor **1,00**. Dieser Faktor ist unkalibriert.
- Testtext: `HxpgIl1O0`. Ein Wort, damit der Test keine Wortabstandsberechnung benötigt.
- Schriftname und Beispieltext stehen schlicht untereinander auf weißem Hintergrund, ohne Hilfslinien, Knöpfe oder Dekoration.
- Ladefehler bleiben sichtbar; ein Muster erscheint erst nach erfolgreichem Laden/Messen.
- Roblox und HTML begrenzen paralleles Laden auf zwei Vorgänge. Alle Testzeilen werden aufgebaut; Scrollen startet keine Messungen.

Die Fontdateien belegen zusammen etwa 93 MB, vor allem wegen der großen asiatischen Zeichensätze. Sie liegen ausschließlich bei den Beispielen.
Der Test samt Katalog wird nicht in das reine Engine-Modell eingebaut.
Die Dateien dienen hier dem lokalen Vergleich für die Roblox-Entwicklung. Die einzelnen Font-Lizenzen sind in den Metadaten dokumentiert;
insbesondere Builder ist nicht als allgemein frei verwendbarer Website-Font lizenziert.
Quelle: [Builder-Lizenz](https://create.roblox.com/docs/resources/builder-font-license).

## Kandidaten für normale Webseiten

### Laufende Messrunde: neun weitere Familien

Reihenfolge: Lato (057), Lora (061), Merriweather (065), Montserrat (069),
Noto Sans (075), Nunito Sans (082), Playfair Display (089), Poppins (090),
Work Sans (124). Nach jedem Bericht wird die nächste Familie im FontLab
und auf ihrer lokalen Browser-Vergleichsseite eingestellt.

Lato: zehn native Regular-Messungen gespeichert in
`measurements/lato-guide-fit.json`; Größe 13.333333 CSS-px entspricht in
diesem neutralen Messlauf TextSize 14. Größenkorrektur als Näherung aus dem
Nutzervergleich: 57 Browser-Pixel / 49 Roblox-Pixel = 57/49.
Die genaue Bezugsgröße und vollständige Browser-Linienwerte wurden nicht
mitgeliefert; der Faktor ist keine Bestätigung pixelgenauer Parität über alle
Größen. Die Engine nutzt originale Guidewerte an den zehn gemessenen nativen
Größen und einen linearen Fit dazwischen; größere Größen sind extrapoliert.
Bold/Italic sind nicht separat vermessen. Lora: vier native Messgrößen (20, 40, 60, 80) und Kontrolle bei 16 gespeichert in `measurements/lora-guide-fit.json`. Alle fünf Linienmessungen bleiben exakt erhalten. Größenfaktor 56/45 aus dem gemeldeten Pixelvergleich als Näherung; vollständige Browserlinien fehlen.

Die weitere Messrunde nutzt auf Wunsch vier große Größen und die kleine Kontrollgröße. Merriweather: fünf native Linienmessungen in `measurements/merriweather-guide-fit.json`, Größenfaktor 60/48 als Näherung aus dem Pixelvergleich. Montserrat: fünf native Linienmessungen in `measurements/montserrat-guide-fit.json`, Größenfaktor 56/46 als Näherung. Noto Sans: fünf native Linienmessungen in `measurements/noto-sans-guide-fit.json`, Größenfaktor 58/43 als Näherung. Nunito Sans: fünf native Linienmessungen in `measurements/nunito-sans-guide-fit.json`, Größenfaktor 57/41 als Näherung. Playfair Display: fünf native Linienmessungen in `measurements/playfair-display-guide-fit.json`, Größenfaktor 57/42 als Näherung. Poppins: fünf native Linienmessungen in `measurements/poppins-guide-fit.json`, Größenfaktor 56/40 als Näherung. Work Sans: fünf native Linienmessungen in `measurements/work-sans-guide-fit.json`, Größenfaktor 53/45 als Näherung. Alle neun Familien sind registriert. Die gemessenen Regular-Linien gelten für native Textgrößen; Größenkorrekturen werden vor der Linienberechnung angewandt. Bold/Italic und vollständige Browserlinien bleiben separat zu vermessen. Das FontLab bleibt für Work Sans (124) bei neutralem Faktor 1,00.

Für die erste Auswahl würde ich Arimo, Inter, Open Sans, Noto Sans, Roboto, Source Sans Pro und Lato ansehen.
Das ist eine praktische Vorauswahl; keine dieser anderen Familien ist damit als pixelgenauer Arial-Ersatz bestätigt.
Inter ist vom Designer ausdrücklich auch für Benutzeroberflächen vorgesehen: [Inter-Projekt](https://rsms.me/inter/).
Die vollständige Auswahl folgt unten, einschließlich Zier-, Handschrift- und Pixelschriften.

## Vollständiger Katalog

„Schnitte“ zählt die im verwendeten Roblox-Familienmanifest eingetragenen Kombinationen aus Gewicht und Stil.
Der Test wählt daraus immer Gewicht 400 / normal. Die Versionsspalte stammt aus der tatsächlich mitgelieferten Testdatei, nicht nur aus der Storebeschreibung.
Ein Store-Link nennt die Asset-ID; bei ausschließlich mitgelieferten Familien steht der Dateiname des Familienmanifests.

| Nr. | Schrift | Roblox-Familie / Store-ID | Schnitte | Datei-Version |
| --- | --- | --- | ---: | --- |

| 001 | Accanthis ADF Std | `AccanthisADFStd.json` | 1 | Version 1.008;FFEdit |
| 002 | Akronim | [12187368317](https://create.roblox.com/store/asset/12187368317) | 1 | Version 1.002 |
| 003 | Amatic SC | `AmaticSC.json` | 2 | Version 2.505 |
| 004 | Antonio | [122516982241677](https://create.roblox.com/store/asset/122516982241677) | 7 | Version 1.002 |
| 005 | Are You Serious | [12187363616](https://create.roblox.com/store/asset/12187363616) | 1 | Version 1.100 |
| 006 | Arimo | [16658254058](https://create.roblox.com/store/asset/16658254058) | 8 | Version 1.33 |
| 007 | Audiowide | [12187360881](https://create.roblox.com/store/asset/12187360881) | 1 | Version 1.003 |
| 008 | Balthazar | `Balthazar.json` | 1 | Version 1.000 |
| 009 | Bangers | `Bangers.json` | 1 | Version 2.000 |
| 010 | Barlow | [12187372847](https://create.roblox.com/store/asset/12187372847) | 18 | Version 1.408 |
| 011 | Barrio | [12187371991](https://create.roblox.com/store/asset/12187371991) | 1 | Version 1.005 |
| 012 | Blaka | [12187365104](https://create.roblox.com/store/asset/12187365104) | 1 | Version 1.001; ttfautohint (v1.8.4.7-5d5b) |
| 013 | Builder Extended | [16658237174](https://create.roblox.com/store/asset/16658237174) | 5 | Version 2.000;Glyphs 3.4.1 (3436) |
| 014 | Builder Mono | [16658246179](https://create.roblox.com/store/asset/16658246179) | 3 | Version 1.002;hotconv 1.0.109;makeotfexe 2.5.65596 |
| 015 | Builder Sans | [16658221428](https://create.roblox.com/store/asset/16658221428) | 7 | Version 2.000;Glyphs 3.4.1 (3436) |
| 016 | Bungee Inline | [12187370000](https://create.roblox.com/store/asset/12187370000) | 1 | Version 1.001;PS 1.0;hotconv 1.0.72;makeotf.lib2.5.5900 |
| 017 | Bungee Shade | [12187367666](https://create.roblox.com/store/asset/12187367666) | 1 | Version 1.001;PS 1.0;hotconv 1.0.72;makeotf.lib2.5.5900 |
| 018 | Caesar Dressing | [12187368843](https://create.roblox.com/store/asset/12187368843) | 1 | Version 1.000 |
| 019 | Cairo | [12187377099](https://create.roblox.com/store/asset/12187377099) | 8 | Version 3.120 |
| 020 | Caveat | [12187369802](https://create.roblox.com/store/asset/12187369802) | 4 | Version 2.000 |
| 021 | Codystar | [12187363887](https://create.roblox.com/store/asset/12187363887) | 2 | Version 1.000 |
| 022 | Comic Neue | [127896232205472](https://create.roblox.com/store/asset/127896232205472) | 6 | Version 2.003 |
| 023 | Comic Neue Angular | `ComicNeueAngular.json` | 1 | Version 2.003 |
| 024 | Creepster | `Creepster.json` | 1 | Version 1.002 |
| 025 | Damion | [12187607722](https://create.roblox.com/store/asset/12187607722) | 1 | Version 1.000 |
| 026 | Dancing Script | [8764312106](https://create.roblox.com/store/asset/8764312106) | 4 | Version 2.001 |
| 027 | Denk One | `DenkOne.json` | 1 | Version 1.002 |
| 028 | DotGothic16 | [115505072169205](https://create.roblox.com/store/asset/115505072169205) | 1 | Version 1.100 |
| 029 | Eater | [12187372382](https://create.roblox.com/store/asset/12187372382) | 1 | Version 001.002  |
| 030 | Faster One | [12187370928](https://create.roblox.com/store/asset/12187370928) | 1 | Version 1.002 |
| 031 | Finger Paint | [12187375716](https://create.roblox.com/store/asset/12187375716) | 1 | Version 1.002 |
| 032 | Fira Sans | [12187374954](https://create.roblox.com/store/asset/12187374954) | 18 | Version 4.203 |
| 033 | Fondamento | `Fondamento.json` | 2 | Version 1.000 |
| 034 | Fredoka One | `FredokaOne.json` | 1 | Version 1.001 |
| 035 | Frijole | [12187375194](https://create.roblox.com/store/asset/12187375194) | 1 | Version 1.000 |
| 036 | Fuzzy Bubbles | [11322590111](https://create.roblox.com/store/asset/11322590111) | 2 | Version 1.010; ttfautohint (v1.8.3) |
| 037 | Goldman | [115884882777577](https://create.roblox.com/store/asset/115884882777577) | 2 | Version 1.000; ttfautohint (v1.8.3) |
| 038 | Great Vibes | [12187375958](https://create.roblox.com/store/asset/12187375958) | 1 | Version 1.010; ttfautohint (v1.8.3) |
| 039 | Grenze Gotisch | `GrenzeGotisch.json` | 9 | Version 1.001 |
| 040 | Guru | `Guru.json` | 1 | Version 3.42 January 18, 2016 |
| 041 | Highway Gothic | `HighwayGothic.json` | 1 | 1.0055 |
| 042 | Hind | [12187361116](https://create.roblox.com/store/asset/12187361116) | 5 | Version 2.001;PS 1.0;hotconv 1.0.79;makeotf.lib2.5.61930; ttfautohint (v1.5.33-1714) -l 8 -r 50 -G 200 -x 13 -D latn -f deva -w G -W -c -X "" |
| 043 | Hind Siliguri | [12187361378](https://create.roblox.com/store/asset/12187361378) | 5 | Version 1.001;PS 1.0;hotconv 1.0.86;makeotf.lib2.5.63406; ttfautohint (v1.5.33-1714) -l 8 -r 50 -G 200 -x 13 -D latn -f beng -w G -W -c -X "" |
| 044 | IBM Plex Sans JP | [12187364147](https://create.roblox.com/store/asset/12187364147) | 7 | Version 1.001 |
| 045 | Inconsolata | `Inconsolata.json` | 8 | Version 1.016 |
| 046 | Indie Flower | `IndieFlower.json` | 1 | Version 1.001 2010 |
| 047 | Inter | [12187365364](https://create.roblox.com/store/asset/12187365364) | 9 | Version 3.019;git-0a5106e0b |
| 048 | Irish Grover | [12187376910](https://create.roblox.com/store/asset/12187376910) | 1 | Version 1.001 |
| 049 | Italianno | [12187374273](https://create.roblox.com/store/asset/12187374273) | 1 | Version 1.100; ttfautohint (v1.8.3) |
| 050 | Jolly Lodger | [77368255811694](https://create.roblox.com/store/asset/77368255811694) | 1 | Version 1.000 |
| 051 | Josefin Sans | `JosefinSans.json` | 14 | Version 2.000 |
| 052 | Jura | `Jura.json` | 5 | Version 5.104 |
| 053 | Kalam | `Kalam.json` | 3 | Version 2.001;PS 1.0;hotconv 1.0.79;makeotf.lib2.5.61930; ttfautohint (v1.3) |
| 054 | Kanit | [12187373592](https://create.roblox.com/store/asset/12187373592) | 18 | Version 2.000; ttfautohint (v1.8.3) |
| 055 | Kings | [12187371622](https://create.roblox.com/store/asset/12187371622) | 1 | Version 1.010; ttfautohint (v1.8.3) |
| 056 | La Belle Aurore | [12187607116](https://create.roblox.com/store/asset/12187607116) | 1 | Version 1.001 2001 |
| 057 | Lato | [11598289817](https://create.roblox.com/store/asset/11598289817) | 10 | Version 1.104; Western+Polish opensource |
| 058 | Libre Baskerville | [12187365769](https://create.roblox.com/store/asset/12187365769) | 3 | Version 1.000; ttfautohint (v0.93) -l 8 -r 50 -G 200 -x 14 -w "G" |
| 059 | Lobster | [8836875837](https://create.roblox.com/store/asset/8836875837) | 1 | Version 2.100 |
| 060 | Londrina Solid | [113086061264643](https://create.roblox.com/store/asset/113086061264643) | 4 | Version 1.002 |
| 061 | Lora | [12187366657](https://create.roblox.com/store/asset/12187366657) | 8 | Version 3.004 |
| 062 | Luckiest Guy | `LuckiestGuy.json` | 1 | Version 1.001 |
| 063 | M PLUS Rounded 1c | [12188570269](https://create.roblox.com/store/asset/12188570269) | 7 | Version 1.059.20150529 |
| 064 | Marhey | [12187364648](https://create.roblox.com/store/asset/12187364648) | 5 | Version 1.000 |
| 065 | Merriweather | `Merriweather.json` | 8 | Version 2.002 |
| 066 | Michroma | `Michroma.json` | 1 | Version 1.100; ttfautohint (v1.8.4.7-5d5b);gftools[0.9.29] |
| 067 | Monofett | [12187606783](https://create.roblox.com/store/asset/12187606783) | 1 | Version 1.000 |
| 068 | Monoton | [12187374098](https://create.roblox.com/store/asset/12187374098) | 1 | Version 1.000 |
| 069 | Montserrat | [11702779517](https://create.roblox.com/store/asset/11702779517) | 18 | Version 8.000 |
| 070 | Mukta | [12187365559](https://create.roblox.com/store/asset/12187365559) | 7 | Version 2.538;PS 1.001;hotconv 16.6.51;makeotf.lib2.5.65220; ttfautohint (v1.6) |
| 071 | Mulish | [12187372629](https://create.roblox.com/store/asset/12187372629) | 16 | Version 3.603 |
| 072 | NanumGothic | [12187361718](https://create.roblox.com/store/asset/12187361718) | 3 | Version 3.020;PS 1;hotconv 1.0.57;makeotf.lib2.0.21895 |
| 073 | Nosifer | [12187377325](https://create.roblox.com/store/asset/12187377325) | 1 | Version 001.002  |
| 074 | Nothing You Could Do | [12187367901](https://create.roblox.com/store/asset/12187367901) | 1 | Version 1.005 |
| 075 | Noto Sans | [12187370747](https://create.roblox.com/store/asset/12187370747) | 18 | Version 2.007 |
| 076 | Noto Sans HK | [12187362892](https://create.roblox.com/store/asset/12187362892) | 6 | Version 2.002;hotconv 1.0.116;makeotfexe 2.5.65601 |
| 077 | Noto Serif HK | [12187366846](https://create.roblox.com/store/asset/12187366846) | 8 | Version 2.001;hotconv 1.1.0;makeotfexe 2.6.0 |
| 078 | Noto Serif JP | [12187369639](https://create.roblox.com/store/asset/12187369639) | 7 | Version 1.001;PS 1.001;hotconv 16.6.54;makeotf.lib2.5.65590 |
| 079 | Noto Serif SC | [12187376739](https://create.roblox.com/store/asset/12187376739) | 7 | Version 1.001;PS 1.001;hotconv 16.6.54;makeotf.lib2.5.65590 |
| 080 | Noto Serif TC | [12187368093](https://create.roblox.com/store/asset/12187368093) | 7 | Version 1.001;PS 1.001;hotconv 16.6.54;makeotf.lib2.5.65590 |
| 081 | Nunito | `Nunito.json` | 14 | Version 3.504 |
| 082 | Nunito Sans | [12187363368](https://create.roblox.com/store/asset/12187363368) | 14 | Version 3.006; ttfautohint (v1.8.3) |
| 083 | Open Sans | [11598121416](https://create.roblox.com/store/asset/11598121416) | 12 | Version 3.000 |
| 084 | Oswald | `Oswald.json` | 6 | Version 4.100; ttfautohint (v1.8.1.43-b0c9) |
| 085 | Pacifico | [12187367362](https://create.roblox.com/store/asset/12187367362) | 1 | Version 3.001 |
| 086 | Parisienne | [12187361943](https://create.roblox.com/store/asset/12187361943) | 1 | Version 1.000 |
| 087 | Patrick Hand | `PatrickHand.json` | 1 | Version 1.003;PS 001.003;hotconv 1.0.70;makeotf.lib2.5.58329; ttfautohint (v0.94.20-1c74) -l 8 -r 50 -G 200 -x 14 -w "gGD" -c -f |
| 088 | Permanent Marker | `PermanentMarker.json` | 1 | Version 1.001 |
| 089 | Playfair Display | [12187374765](https://create.roblox.com/store/asset/12187374765) | 12 | Version 1.203 |
| 090 | Poppins | [11702779409](https://create.roblox.com/store/asset/11702779409) | 18 | 4.004 |
| 091 | Press Start 2P | `PressStart2P.json` | 1 | Version 2.14 |
| 092 | Prompt | [12187607287](https://create.roblox.com/store/asset/12187607287) | 18 | Version 1.001 |
| 093 | PT Sans | [12187606934](https://create.roblox.com/store/asset/12187606934) | 4 | Version 2.003W OFL |
| 094 | PT Serif | [12187606624](https://create.roblox.com/store/asset/12187606624) | 4 | Version 1.000W OFL |
| 095 | Quicksand | [12187371324](https://create.roblox.com/store/asset/12187371324) | 5 | Version 3.006 |
| 096 | Rajdhani | [12187375422](https://create.roblox.com/store/asset/12187375422) | 5 | Version 1.201;PS 1.0;hotconv 1.0.78;makeotf.lib2.5.61930; ttfautohint (v1.1) -l 7 -r 28 -G 50 -x 13 -D latn -f deva -w G |
| 097 | Raleway | [11702779240](https://create.roblox.com/store/asset/11702779240) | 18 | Version 4.026 |
| 098 | Roboto | `Roboto.json` | 12 | Version 2.137; 2017 |
| 099 | Roboto Condensed | `RobotoCondensed.json` | 6 | Version 2.137; 2017 |
| 100 | Roboto Mono | `RobotoMono.json` | 14 | Version 3.000 |
| 101 | Roboto Slab | [12187368625](https://create.roblox.com/store/asset/12187368625) | 9 | Version 2.001 |
| 102 | Roman Antique | `RomanAntique.json` | 1 | 1.0 |
| 103 | Rubik | [12187365977](https://create.roblox.com/store/asset/12187365977) | 14 | Version 2.104 |
| 104 | Rubik Burned | [12187363148](https://create.roblox.com/store/asset/12187363148) | 1 | Version 2.200 |
| 105 | Rubik Iso | [12187362120](https://create.roblox.com/store/asset/12187362120) | 1 | Version 2.200 |
| 106 | Rubik Marker Hatch | [12187367066](https://create.roblox.com/store/asset/12187367066) | 1 | Version 2.200 |
| 107 | Rubik Maze | [12187366475](https://create.roblox.com/store/asset/12187366475) | 1 | Version 2.200 |
| 108 | Rubik Wet Paint | [12187369046](https://create.roblox.com/store/asset/12187369046) | 1 | Version 2.200 |
| 109 | Rye | [12187372175](https://create.roblox.com/store/asset/12187372175) | 1 | Version 1.001 |
| 110 | Sarpanch | `Sarpanch.json` | 6 | Version 2.004;PS 1.0;hotconv 1.0.78;makeotf.lib2.5.61930; ttfautohint (v1.1) -l 8 -r 50 -G 200 -x 14 -D latn -f deva -w gGD -W -c |
| 111 | Sedgwick Ave Display | [12187376357](https://create.roblox.com/store/asset/12187376357) | 1 | Version 1.000 |
| 112 | Shadows Into Light | [12187607493](https://create.roblox.com/store/asset/12187607493) | 1 | Version 001.000 |
| 113 | Silkscreen | [12187371840](https://create.roblox.com/store/asset/12187371840) | 2 | Version 1.001; ttfautohint (v1.8.4.7-5d5b) |
| 114 | Sono | [12187374537](https://create.roblox.com/store/asset/12187374537) | 7 | Version 2.112 |
| 115 | Sono Monospace | [12187362578](https://create.roblox.com/store/asset/12187362578) | 7 | Version 2.112 |
| 116 | Source Sans Pro | `SourceSansPro.json` | 12 | Version 2.021;PS 2.000;hotconv 1.0.86;makeotf.lib2.5.63406 |
| 117 | Special Elite | `SpecialElite.json` | 1 | Version 1.001 |
| 118 | Tajawal | [12187377588](https://create.roblox.com/store/asset/12187377588) | 7 | Version 1.700 |
| 119 | Tangerine | [12187376545](https://create.roblox.com/store/asset/12187376545) | 2 | Version 1.3 |
| 120 | Teko | [12187376174](https://create.roblox.com/store/asset/12187376174) | 5 | Version 1.106;PS 1.0;hotconv 1.0.78;makeotf.lib2.5.61930; ttfautohint (v1.1) -l 7 -r 28 -G 50 -x 13 -D latn -f deva -w G |
| 121 | Titillium Web | `TitilliumWeb.json` | 11 | Version 1.002;PS 57.000;hotconv 1.0.70;makeotf.lib2.5.55311 |
| 122 | Ubuntu | `Ubuntu.json` | 8 | 0.83 |
| 123 | Unica One | [12187364842](https://create.roblox.com/store/asset/12187364842) | 1 | Version 1.001 |
| 124 | Work Sans | [12187373327](https://create.roblox.com/store/asset/12187373327) | 18 | Version 2.012 |
| 125 | Yellowtail | [12187373881](https://create.roblox.com/store/asset/12187373881) | 1 | Version 001.002  |
| 126 | Zekton | `Zekton.json` | 1 | Version 5.000 |

## Daten und Quellen

- [Creator Store: Fonts](https://create.roblox.com/store/category/2d/fonts)
- [Abgerufene Store-Suche, Assettyp 73](https://apis.roblox.com/toolbox-service/v1/marketplace/73?limit=100)
- Familiendaten: `https://assetdelivery.roblox.com/v1/asset/?id=FAMILIEN_ID`; die jeweiligen IDs stehen oben.
- Lokale Quellen: `content/fonts/families/*.json` und die zugeordneten Dateien in der genannten Roblox-Installation.
- `measurements/roblox-font-catalog-2026-09-08.json`: vollständiger Snapshot mit Familienpfaden, Schnitten, Face-IDs, Versions- und Lizenzangaben sowie SHA-256 jeder Testdatei.
- `examples/FontComparison/Catalog.luau` und `examples/font-comparison-catalog.js`: daraus erzeugte Testlisten in identischer Reihenfolge.

Prüfung: 126 Dateihashes, Katalogzuordnung, Gewicht/Stil und Testzeichen geprüft; JavaScript-Syntax und Luau-Kompilierung erfolgreich; Rojo-Testwelt gebaut.
Die Browser-Sicherheitsrichtlinie blockierte das automatische Öffnen der lokalen HTML-Datei. Browserdarstellung und Studio-Verhalten müssen deshalb noch visuell geprüft werden.

