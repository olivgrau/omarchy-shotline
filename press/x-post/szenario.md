# Szenario und Story

Fiktiv, aber so gebaut, dass jeder Entwickler es wiedererkennt. Alle Namen,
Firmen und Daten sind erfunden. Die App im Material ist eine eigens gebaute
Attrappe (`demo-app/pedalio.html`), damit in den Screenshots keine echten
Kundendaten auftauchen.

## Die Situation

**Pedalio** ist ein fiktiver Fahrradverleih mit 40 Rädern an vier Stationen.
Das Ops-Team arbeitet den ganzen Tag im Buchungs-Dashboard. Freitag, 16:40,
kurz vor Feierabend, schreibt Mia aus dem Ops-Team:

> "Die Buchungsliste stimmt hinten und vorne nicht. Kannst du da mal draufgucken?"

Du klickst dich zehn Minuten durch die App und findest vier Probleme:

1. **Der Filter lügt.** Oben steht "Status: Paid", in der Liste stehen trotzdem
   Pending- und Cancelled-Buchungen. Die Summe zählt nur die bezahlten. Liste
   und Summe widersprechen sich.
2. **Die Daten sind im US-Format.** `03/04/2026` heißt in der Detailansicht
   mal der 3. April, mal der 4. März. Das Enddatum liegt vor dem Startdatum,
   die Dauer zeigt `-7 h`.
3. **Speichern schlägt fehl.** `PATCH /api/rentals/0413` gibt 500 zurück,
   `ValidationError: startDate must be ISO-8601`.
4. **Auf schmalen Schirmen fehlt die Summe.** Die Tabelle scrollt seitwärts,
   die Spalte "Amount" liegt außerhalb, nichts weist darauf hin.

## Das eigentliche Problem

Die Bugs zu finden hat zehn Minuten gedauert. Sie aufzuschreiben dauert länger.

> "In der Detailansicht, im Feld rechts oben neben dem Kundennamen, steht das
> Datum im amerikanischen Format, und weiter unten steht deshalb eine negative
> Dauer, das hängt vermutlich zusammen …"

Drei Sätze, die ein Screenshot in einer Sekunde erledigt. Und je länger der
Text wird, desto mehr rät der Agent.

## Was Shotline daraus macht

Vier mal `SUPER + SHIFT + K`. Ausschnitt ziehen, Größe steht im Rahmen,
Kommentar tippen, weiter. Beim Datum einmal den Stift: zwei rote Rahmen,
zwei Worte dran. Dann `SUPER + SHIFT + L`.

Im Agent-Verzeichnis liegen danach:

```
shotline-2026-08-31-pedalio-rentals/
  01-filter-says-status-paid-but-pending-and.png
  02-dates-render-as-mm-dd-yyyy-end-date-is-b.png
  03-saving-a-pending-rental-fails-patch-api.png
  04-on-narrow-screens-the-amount-column-is-p.png
  session.html    zum Ansehen
  session.md      für den Agenten
```

Und in der Zwischenablage steht der fertige Satz, den du dem Agenten gibst.
Aus zehn Minuten Tippen werden zwanzig Sekunden Klicken.

## Die Pointe für den Post

Nicht "ich habe ein Screenshot-Tool gebaut", sondern:
**Der Agent braucht keinen besseren Prompt, er braucht deinen Bildschirm.**
