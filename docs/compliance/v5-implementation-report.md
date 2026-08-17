# ShareItToo V5.1 - Umsetzungsbericht

Stand: 17.08.2026, lokaler Checkpoint 16.127

## Verbindliche Grenzen

- Der unveränderte interne Kandidat ist `1.0.0+2026081509`. Spätere
  Quelländerungen sind kein Kandidaten- oder Store-Nachweis.
- Echtgeld, produktive Zahlungen, öffentliche Rechtstexte, Produktion und
  Store-Einreichung bleiben gesperrt.
- Firebase Cloud Messaging und Firebase Crashlytics bleiben Bestandteil des
  Launchumfangs. Sie sind getrennte freiwillige Dienste, im nächsten
  Kandidaten standardmäßig aus; Push aktiviert Crashlytics nicht.
- Werbung, Marketingtracking, allgemeine Analytics und externe generative KI
  bleiben aus, solange sie nicht separat entschieden und geprüft wurden.

## Umgesetzt und technisch geprüft

- V5.1-Nachfolgemapping für die sechs früher offenen V4-Entscheidungen
- serverseitiges, zehn Minuten gültiges und manipulationsgeschütztes Angebot
- Plattformvertrag mit genau zwei ausdrücklichen Erklärungen
- unveränderlicher, authentifizierter HTML-Vertragsbeleg
- V5.1-Widerruf, getrennte Erstattungsobligationen und Stornoregeln
- rollen- und buchungsgebundene Übergabe-/Rückgabefotos mit Gegenbestätigung
- neutrale Rückgabezeitachse bis T0+5 sowie begründete Fallfristen
- exakter, hashgebundener Satz aus sieben deutschen V5.1-Rechtsassets
- unveränderliche Finanzdokumente ausschließlich aus erfolgreich erfassten
  Zahlungs-, Erstattungs- und Auszahlungssnapshots
- getrennte Darstellung von privatem Mietpreis und SIT-Plattformgebühr ohne
  pauschalen 19-%-Umsatzsteuerausweis auf die private Miete
- authentifizierter Belegdownload mit serverseitiger und clientseitiger
  Hashbindung; unbekannte Typen, falsche Summen und unvollständige Snapshots
  werden geschlossen abgelehnt

## Finanzdokument-Boundary

Vor einem tatsächlich erfolgreichen Quellereignis entsteht kein Beleg. Der
Mieter erhält nach erfolgreicher Zahlung eine Buchungs-/Zahlungsübersicht und
gegebenenfalls einen separaten SIT-Gebührenbeleg. Der Vermieter erhält keine
SIT-Gebührenrechnung, sondern erst nach einer tatsächlich ausgeführten
Auszahlung einen Auszahlungsnachweis. Ein Erstattungsbeleg entsteht erst nach
erfolgreicher Erstattung und weist Mietpreis und SIT-Gebühr mit getrennten
Schuldnern aus.

Die Datenbank erzwingt Dokumenttyp, Quellobjekt, Rollen und Summengleichungen.
Dokumente und Downloadereignisse sind append-only. Die Release-App bezieht die
Liste authentifiziert vom Backend, ruft vor PDF-Darstellung den exakten
Serverbeleg ab und vergleicht dessen Hash mit dem unveränderlichen Snapshot.
Nur der ausdrücklich markierte QA-Modus darf lokale Testbelege erzeugen; diese
tragen sichtbar `TESTBELEG` und sind weder Echtgeld- noch Steuerbelege.

Echtbetrieb bleibt zusätzlich geschlossen, bis Betreiber-/Steuerangaben,
SIT-Gebühren-Steuerbehandlung und Live-Ausstellung ausdrücklich freigegeben
sind. Migration 020 wurde nicht auf Staging oder Produktion angewandt; dieser
Checkpoint ist Quell- und Teststand, kein Deployment.

## Rechtsasset-Boundary

Der V5.1-Satz wird aus genau der 54-seitigen Quelle mit SHA-256
`587bfd9e53539e5895c3d9dcb6fc437e0bf7c6e91db144841d0fe986b274b3fc`
reproduzierbar erzeugt. Das Manifest bindet jede Datei an ihren Inhalts-Hash.
Es bleibt `draft-blocked`, kann nicht veröffentlicht und nicht in
`legal_document_snapshots` provisioniert werden.

Die Quelle behauptet auf Seite 38 noch, dass externe Push- und Crashdienste im
Startbetrieb deaktiviert seien. Die spätere Produktentscheidung vom 17.08.2026
behält FCM und Crashlytics bei. Dieser Widerspruch ist im Manifest ausdrücklich
als aktivierungsblockierend festgehalten. Vor einer Freigabe müssen der
Datenschutztext angepasst und Anbieter-, Transfer-, Einwilligungs-,
Aufbewahrungs-, Lösch- und Store-Nachweise geschlossen werden.

## Offene Tatsachen und Gates

- vollständige Betreiber-/Register-/Steuerangaben
- finale öffentliche Widerrufs-URL
- Hosting-, SMTP- und Kartenanbieter samt Regionen
- lizenzierter Marketplace-PSP samt Vertrag, Region und Geldfluss
- Firebase Push-/Crash-Provider-, Transfer- und Vertragsnachweise
- neun Aufbewahrungs-/Löschentscheidungen
- vier reale physische Gerätematrix-Fälle
- neuer signierter Kandidat und vollständige Kandidatenbindung
- unabhängige Rechts-/Produktprüfung, soweit verfügbar

Bis diese Punkte belegt sind, bleibt Go/No-Go auf `HOLD`.

Die neun Aufbewahrungs-/Löschfragen sind in Checkpoint 16.127 nicht mehr ein
undifferenzierter Block: Für jede Entscheidung liegen jetzt Klassifikation,
Empfehlung, Implementierungsstand und belastbare Quellen vor. Zwei Regeln sind
technisch beziehungsweise betrieblich entscheidungsreif (Credential-Purge und
14-Tage-Backuprotation). Die übrigen Regeln bleiben bewusst offen, bis ihre
Betreiber-/Rechtsgrundlage bestätigt ist. Keine kategorieweise Löschung wurde
aktiviert.

## Prüfstand Checkpoint 16.126

- Backend: 198 bestanden, 1 PostgreSQL-Integrationstest ohne lokale
  `TEST_DATABASE_URL` bewusst übersprungen
- Flutter: 275 bestanden, 1 bewusster Skip
- Analyzer: 229 Hinweise, 0 Fehler
- technische Node-/Vertragsprüfungen: 607 bestanden
- Finanzdokument-spezifisch: 7 Backend-, 3 Modell-/Fail-closed- und 4
  Verkabelungstests bestanden
- Rechtsasset-Validator: 6 bestanden
- Datenschutz-, Rechts-, Retention-, Store- und Release-Gates: grün und
  weiterhin fail-closed
- Web-Debug-Build: grün
- Android-Debug-Build: grün

Dieser Bericht beschreibt den Quell- und Prüfstand. Er ist keine Freigabe für
Produktion, Echtgeld, öffentliche Verträge oder Store-Review.

## Prüfstand Checkpoint 16.127

- alle neun Retention-/Löschentscheidungen einzeln vorbereitet, keine als
  beschlossen ausgegeben
- maschinenlesbarer Beleg und lesbare Entscheidungsmatrix gebunden
- FCM-Push und Firebase Crashlytics ausdrücklich erhalten: getrennte
  freiwillige Opt-ins, beide standardmäßig aus, keine Kopplung
- abgelaufene Zugangsdaten: bestehende automatische Bereinigung mit Startlauf,
  Sechs-Stunden-Takt und maximal vorgeschlagenem 24-Stunden-Abschlussfenster
- Backups: bestehende 14-Tage-Rotation als Betreiberentscheidung vorbereitet;
  keine falsche Behauptung kontobezogener Einzellöschung aus alten Backups
- HGB-, AO-, BGB- und BfDI-Quellen gebunden; keine pauschale Rechtsfrist auf
  fachlich unterschiedliche Daten übertragen
- Retention-/Datenschutz-/V5.1-Validatoren grün und weiterhin fail-closed
- vollständige Node-Prüfsuite: 611 bestanden, 0 fehlgeschlagen
- bestehender Kandidat, Staging, Produktion, Store, Echtgeld und öffentliche
  Rechtstexte unverändert
