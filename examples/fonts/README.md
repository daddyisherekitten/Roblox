# Source Sans Pro für den lokalen Vergleich

`SourceSansPro-Regular.ttf` ist unverändert aus der lokalen Roblox-Installation kopiert:
`version-9fe94fb0e9d84c25/content/fonts/SourceSansPro-Regular.ttf`.
Das dortige Familienmanifest `SourceSansPro.json` verwendet diese Datei für Regular (400).
Die SIL-OFL-Lizenz liegt unter `SourceSansPro-LICENSE.txt` bei.
Die Browser-Testseite lädt diese Datei über `@font-face` und meldet Ladefehler ausdrücklich.
Andere Roblox-Clientversionen können eine andere Fontversion enthalten.

## SVG-Text S25/S26

Zusätzlich unverändert übernommen: `SourceSansPro-Bold.ttf`, `SourceSansPro-It.ttf`
und `SourceSansPro-BoldIt.ttf` aus der lokalen Roblox-Installation
`version-93202a13414c4131/StudioFonts`. Alle drei deklarieren dieselbe Adobe/SIL-OFL-
Lizenz; die vorhandene Lizenzdatei gilt auch für diese Schnitte. Regular bleibt
unverändert. Die Schnitte stammen nicht alle aus derselben Fontversion; pro Schnitt
benutzen Browser und Roblox aber exakt dieselbe Datei.

| Datei | SHA256 |
|---|---|
| SourceSansPro-Regular.ttf | c9868de61ff2bab0b5a3a6d01c4b76f299459f08c6ae2f2c0383b4f9f6bedbf3 |
| SourceSansPro-Bold.ttf | d3f20633924bbbb5a475e7d3b84a5cb9c8d172ed5c97a04687910e37a206f989 |
| SourceSansPro-It.ttf | e77f54aa69152a116a529835c2925f5291305588c2b1e98e3d0d26efc9abb177 |
| SourceSansPro-BoldIt.ttf | a0af84176908b519f0f069aadc410ac1468bfb96389c799254539b8ed8d6bdc3 |

`scripts/export-svg-font.py` (fontTools 4.65.0, lokal unter build/python-svg-fonts)
erzeugt die allgemeinen Glyphenkonturen/Fontmetriken unter `SVG/TextFont`.
Der Runtime-Renderer benötigt weder Python noch Zugriff auf installierte Fonts.
