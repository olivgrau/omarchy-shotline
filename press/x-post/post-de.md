# X-Post — Deutsch

Zwei Varianten: Thread (mehr Reichweite, mehr Aufwand) oder Einzelpost.
Zeichenzahlen stehen pro Tweet dabei, alle unter dem 280-Zeichen-Limit.

---

## Variante A — Thread (6 Posts)

### 1/6 · Video `video/shotline.mp4` anhängen · 250 Zeichen

```
Ich schreibe meinem Coding-Agenten keine 200-Wort-Bugreports mehr.

Jetzt fotografiere ich die App Schritt für Schritt und kommentiere jeden Shot.

4 Bugs → 4 Screenshots → 1 Markdown, das er wirklich lesen kann.

Als Omarchy-Plugin gebaut: Shotline.
```

### 2/6 · ohne Medien · 256 Zeichen

```
Den Bug zu finden war nie das Problem.

Ihn zu beschreiben schon: "in der Detailansicht, rechts oben neben dem
Kundennamen, steht das Datum im US-Format, und weiter unten ist deshalb die
Dauer negativ…"

Drei Sätze für das, was ein Screenshot sofort zeigt.
```

### 3/6 · `screenshots/02-comment-dialog.png` anhängen · 242 Zeichen

```
SUPER+SHIFT+K friert den Bildschirm ein. Ausschnitt ziehen — die Größe steht
währenddessen im Rahmen. Ein Klick nimmt das ganze Fenster.

Das Kommentarfeld kommt sofort, mit der Größe im Text.

Tippen, Enter, zurück zur App. Nächster Schritt.
```

### 4/6 · `screenshots/04-annotation.png` anhängen · 236 Zeichen

```
Du willst auf etwas zeigen?

Sobald ein Shot da ist, erscheint ein Stift in der Bar. Klick, und der
Screenshot öffnet sich mit dem Stift — oder mit Blur, für alles, was nicht
ins Repo gehört.

Speichern, und du bist zurück im Kommentar.
```

### 5/6 · `screenshots/05-session-html-light.png` und `screenshots/07-session-md.png` anhängen · 262 Zeichen

```
SUPER+SHIFT+L schließt die Serie ab.

Zielordner wählen, fertig:
· session.html — für dich, hell und dunkel
· session.md — für den Agenten, relative Bildpfade
· die PNGs daneben

Der Prompt, der dem Agenten sagt was zu tun ist, liegt schon in der
Zwischenablage.
```

### 6/6 · ohne Medien · 219 Zeichen

```
Bash, Python-Standardbibliothek, ein QML-Bar-Widget. Zur Laufzeit braucht es
nur grim, slurp und jq.

149 Tests, alle grün, keiner davon fasst deinen echten Desktop an.

MIT-Lizenz.

github.com/olivgrau/omarchy-shotline
```

---

## Variante B — Einzelpost · Video anhängen · 272 Zeichen

```
Einen Bug zu erklären dauert länger, als ihn zu finden.

Deshalb Shotline: App Schritt für Schritt fotografieren, jeden Shot
kommentieren, das Wichtige markieren.

Heraus kommt eine Markdown-Datei für den Agenten.

Omarchy-Plugin, MIT.
github.com/olivgrau/omarchy-shotline
```

---

## Alt-Texte für die Bilder

Gehören in das Alt-Text-Feld von X. Gut für Reichweite und für alle, die einen
Screenreader nutzen.

| Bild | Alt-Text |
|---|---|
| `01-app-with-bugs.png` | Dunkles Buchungs-Dashboard mit sechs Buchungen. Der Filter sagt "Status: Paid", trotzdem stehen Pending- und Cancelled-Zeilen in der Liste, und die Summe zählt nur die bezahlten. |
| `02-comment-dialog.png` | Dasselbe Dashboard, darüber ein kleines Eingabefeld, das nach einem Kommentar zu Shot 5 fragt und die Größe 1588 mal 962 Pixel anzeigt. |
| `03-bar-widget.png` | Nahaufnahme einer Statusleiste: ein Kamerasymbol mit der Zahl 4 daneben, dahinter ein Stiftsymbol. |
| `04-annotation.png` | Detailzeilen einer Buchung mit zwei roten Rahmen: einer um zwei Daten im US-Format mit der Notiz "US format?", einer um eine Dauer von minus 7 Stunden mit der Notiz "negative". |
| `05-session-html-light.png` | Erzeugte HTML-Seite mit dem Titel "Pedalio rentals", die vier Screenshots samt Kommentaren auflistet. |
| `06-session-html-dark.png` | Dieselbe Seite im Dunkelmodus. |
| `07-session-md.png` | Terminalansicht von session.md: pro Schritt eine Überschrift, der Bildpfad, die Ausschnittgröße, das Fenster und der Kommentar als Zitat. |
| `08-agent-prompt.png` | Terminalausgabe nach dem Abschluss: der Zielpfad und der fertige Prompt, der den Agenten auf session.md verweist. |

---

## Hinweise zum Posten

- **Video zuerst.** Die 30 Sekunden tragen die Idee besser als jedes Einzelbild.
  `video/shotline.gif` ist der Ersatz, wo MP4 unpraktisch ist.
- **Zeitpunkt:** werktags vormittags. Die Omarchy-Leute sind überwiegend in
  Europa und posten früh.
- **Hashtags:** keine im Hauptpost. Wenn doch, dann `#Omarchy #Hyprland #Linux`
  in eine Antwort, damit sie den Einstieg nicht zerreißen.
- **Erwähnen:** der Omarchy-Account, wenn die Community es sehen soll. Nicht
  mehr als einen Account markieren.
