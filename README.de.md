# Shotline

*[English version](README.md)*

Omarchy-Plugin. Nimmt schrittweise Screenshots einer App auf, kommentiert jeden
Schritt sofort und legt die Serie als HTML plus Markdown in einem Agent-Verzeichnis
ab. Zum Schluss liegt ein fertiger Prompt für den KI-Agenten in der Zwischenablage.

## Ablauf

1. `SUPER + SHIFT + K` drücken. Der Bildschirm friert ein, `slurp` zeigt die Größe
   der Auswahl während des Ziehens. Ein Klick wählt ein ganzes Fenster.
   Die Tastensteuerung aus Omarchys Screenshot-Werkzeug gilt auch hier:

   | Taste | Wirkung |
   |---|---|
   | Ziehen | freie Auswahl, Größe wird angezeigt |
   | Klick | Fenster oder Monitor unter dem Zeiger |
   | `Tab` / `Ctrl+Tab` | nächstes / vorheriges Fenster |
   | Pfeiltasten | Fenster in dieser Richtung |
   | `Return` | hervorgehobenes Fenster nehmen |
   | `Ctrl+Return` | ganzen Bildschirm nehmen |
   | `Esc` | abbrechen |

   Diese Tasten stellt Omarchy selbst an slurps Auswahl-Layer bereit; Shotline wertet
   nur das Ergebnis aus. Reagieren sie nicht, fehlen sie systemweit — dann tun sie es
   auch in Omarchys eigenem Screenshot. Ein Neustart der Hyprland-Sitzung stellt sie her.
2. Ein Eingabefeld fragt nach dem Kommentar. Die Größe des Ausschnitts steht im Text.
3. Optional markieren: auf das Stift-Symbol in der Bar klicken oder
   `SUPER + SHIFT + Z` drücken. Der Screenshot öffnet sich in `tensaku` mit dem
   Stift-Werkzeug, `SUPER + SHIFT + I` → *Letzten unkenntlich machen* startet
   stattdessen mit dem Blur-Werkzeug. Enter speichert, danach kommt der
   Kommentar-Dialog zurück.
4. Zurück zur App, nächster Schritt, wieder `SUPER + SHIFT + K`.
5. `SUPER + SHIFT + L` schließt die Serie ab: Titel eingeben, Zielordner aus der
   Merkliste wählen, fertig.

## Bar-Widget

Zwei Symbole. Die Kamera zeigt die laufende Session mit Zähler. Der Stift
erscheint erst, sobald ein Shot zum Markieren da ist.

| | Linksklick | Mittelklick | Rechtsklick |
|---|---|---|---|
| Kamera | nächster Shot | letzten verwerfen | Menü |
| Stift | markieren (Stift) | Menü | unkenntlich machen (Blur) |

Das Menü (`SUPER + SHIFT + I` oder Rechtsklick) zeigt nur, was gerade möglich ist:
nächster Shot, letzten markieren, letzten unkenntlich machen, letzten verwerfen,
Serie abschließen, Serie verwerfen, letztes Ergebnis öffnen.

## Ergebnis

```
<agent-verzeichnis>/shotline-2026-08-28-login-flow/
  01-login-maske.png
  02-fehler-nach-dem-absenden.png
  session.html    zum Ansehen, mit Hell/Dunkel-Umschalter
  session.md      für den KI-Agenten, relative Bildpfade
```

Der Prompt in der Zwischenablage verweist auf `session.md`.

## Installation

```bash
./install.sh
```

Der Installer verlinkt die CLI nach `~/.local/bin`, registriert das Plugin unter
`~/.config/omarchy/plugins/olivgrau.shotline` und trägt einen markierten
Block in `~/.config/hypr/bindings.lua` ein. Andere Tasten:

```bash
SHOT_KEY="SUPER + SHIFT + P" MARK_KEY="SUPER + ALT + P" ./install.sh
```

Belegt werden `SHOT_KEY`, `MARK_KEY`, `UNDO_KEY`, `MENU_KEY` und `FINISH_KEY`.
Der Installer warnt, wenn eine Taste in Hyprland schon vergeben ist.

`./install.sh uninstall` nimmt alles zurück. Aufgenommene Serien bleiben liegen.

## CLI

| Befehl | Wirkung |
|--------|---------|
| `shotline shot [--comment TEXT]` | Ausschnitt wählen, aufnehmen, kommentieren |
| `shotline annotate [--blur] [--index N]` | Shot im Editor markieren, danach Kommentar nachziehen |
| `shotline menu` | Menü mit allen Aktionen |
| `shotline undo` | letzten Shot verwerfen |
| `shotline list` | Shots der laufenden Session zeigen |
| `shotline status [--json]` | Zustand, auch für das Bar-Widget |
| `shotline finish [--target DIR] [--title T] [--open]` | Serie ablegen und Prompt liefern |
| `shotline cancel` | Session verwerfen |
| `shotline prompt` | Prompt der letzten Serie erneut ausgeben |
| `shotline open` | `session.html` der letzten Serie öffnen |

Ohne Befehl nimmt die CLI einen Shot auf. Läuft keine Session, startet sie eine.

## Konfiguration

| Variable | Zweck |
|----------|-------|
| `SHOTLINE_DEFAULT_TARGET` | Zielordner, der in der Auswahl oben steht |
| `SHOTLINE_STATE_DIR` | Arbeitsverzeichnis (Standard: `~/.local/state/shotline`) |
| `SHOTLINE_EDITOR` | Editor zum Markieren (Standard: `tensaku`) |
| `SHOTLINE_QUIET` | auf `1` setzen, um alle Meldungen zu unterdruecken (Skripte, Aufnahmen) |

Widget-Einstellungen (`omarchy bar set`): `hideWhenIdle`, `showCount`, `showPen`, `command`.

## Aufbau

| Pfad | Zweck |
|------|-------|
| `bin/shotline` | CLI: Session, Aufnahme, Dialoge, Abschluss |
| `bin/shotline-render` | Renderer: `session.json` → HTML und Markdown |
| `BarWidget.qml` | Bar-Widget mit Zähler |
| `manifest.json` | Plugin-Manifest, Schema 1 |
| `test/` | Tests |

Die laufende Session liegt in `~/.local/state/shotline/sessions/<id>/`
mit `session.json` und den PNGs. `finish` kopiert erst ins Ziel und räumt danach
auf, damit ein Fehler unterwegs keine Aufnahmen vernichtet.

## Tests

```bash
./test/run-all.sh
```

119 Tests für die CLI, 26 für den Renderer. Der Bash-Test ersetzt `slurp`, `grim`,
`hyprctl`, den Editor und die Dialoge durch Stubs.
Er läuft ohne Wayland-Sitzung und öffnet nie ein Fenster.

## Voraussetzungen

`grim`, `slurp`, `jq`, `python`. Optional: `hyprpicker` (friert den Bildschirm
während der Auswahl ein), `wl-clipboard` (Prompt in die Zwischenablage),
`tensaku` (Markieren und Unkenntlichmachen; liegt Omarchy bei).
