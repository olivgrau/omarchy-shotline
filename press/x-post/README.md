# X-Post-Paket: Shotline

Alles für einen Post über Shotline auf X. Fertig zum Kopieren, nichts muss
mehr gebaut werden.

## Inhalt

| Pfad | Was |
|------|-----|
| `post-en.md` | Englischer Thread (6 Posts) und Einzelpost, mit Alt-Texten und Hinweisen |
| `post-de.md` | Dieselben Texte auf Deutsch |
| `szenario.md` | Das fiktive Szenario samt Story, aus dem das Material entstand |
| `screenshots/` | Acht Bilder, direkt anhängbar |
| `video/shotline.mp4` | 30 Sekunden, 1280×720, ~560 KB — das Hauptmedium |
| `video/shotline.gif` | Dasselbe als GIF, 640 px, ~1,2 MB |
| `video/build.sh` | Baut Video und GIF aus den Screenshots neu |
| `serie/` | Die echte Shotline-Serie, die im Material zu sehen ist |
| `demo-app/pedalio.html` | Die fiktive App aus den Screenshots |

## Die Bilder

| Datei | Zeigt |
|-------|-------|
| `01-app-with-bugs.png` | Das Dashboard mit dem widersprüchlichen Filter |
| `02-comment-dialog.png` | Das Kommentarfeld über der App, mit Größenangabe |
| `03-bar-widget.png` | Bar-Widget: Kamera mit Zähler, Stift daneben |
| `04-annotation.png` | Markierte Datumszeilen, Stift-Werkzeug |
| `05-session-html-light.png` | Das Ergebnis als HTML, hell |
| `06-session-html-dark.png` | Dasselbe dunkel |
| `07-session-md.png` | `session.md`, wie der Agent es liest |
| `08-agent-prompt.png` | Der Prompt nach `shotline finish` |

## So postest du

1. `post-en.md` oder `post-de.md` öffnen, Variante A (Thread) oder B (Einzelpost) wählen.
2. Ersten Post schreiben, `video/shotline.mp4` anhängen.
3. Alt-Text aus der Tabelle in der jeweiligen Datei zu jedem Bild eintragen.
4. Bei einem Thread: die Antworten direkt hintereinander absetzen, nicht
   über den Tag verteilt.

Alle Textblöcke sind gezählt und liegen unter 280 Zeichen. Die Zahl steht in
jeder Überschrift.

## Wie das Material entstanden ist

Die Screenshots sind echt: aufgenommen mit Shotline selbst, in einer echten
Session über die Attrappe `demo-app/pedalio.html`. Die Attrappe existiert,
damit in den Bildern keine echten Kundendaten oder privaten Fenster
auftauchen.

Zwei Dinge sind nachträglich entstanden und sollten hier stehen:

- Die roten Markierungen in `04-annotation.png` (und im zweiten Bild der Serie)
  sind mit ImageMagick gezeichnet, nicht von Hand im Editor gemalt. Das
  Ergebnis entspricht dem, was `tensaku` erzeugt hätte, aber gemalt hat es
  niemand.
- In `session.md` und `session.html` der Serie wurde die Chromium-Fensterklasse
  gekürzt: dort stand der komplette lokale Dateipfad der Attrappe, weil die
  App als `file://`-Seite lief. Bei einer echten Web-App stünde dort ohnehin
  nur der Fenstername.

`video/build.sh` baut Video und GIF jederzeit neu aus den Screenshots.

## Ein Hinweis für den englischen Post

`02-comment-dialog.png` zeigt den Dialog auf Deutsch („was passiert hier?"),
weil die CLI-Texte deutsch sind. Für einen englischen Thread entweder das Bild
weglassen oder die UI-Texte übersetzen.
