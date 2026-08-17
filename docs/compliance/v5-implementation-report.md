# ShareItToo V5.1 - Umsetzungsbericht

Stand: 17.08.2026, lokaler Checkpoint 16.125

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

## Prüfstand Checkpoint 16.125

- Backend: 191 bestanden, 1 PostgreSQL-Integrationstest ohne lokale
  `TEST_DATABASE_URL` bewusst übersprungen
- Flutter: 272 bestanden, 1 bewusster Skip
- Analyzer: 229 Hinweise, 0 Fehler
- Rechtsasset-Validator: 6 bestanden
- Datenschutz-, Rechts-, Retention-, Store- und Release-Gates: grün und
  weiterhin fail-closed
- Web-Debug-Build: grün
- Android-Debug-Build: grün

Dieser Bericht beschreibt den Quell- und Prüfstand. Er ist keine Freigabe für
Produktion, Echtgeld, öffentliche Verträge oder Store-Review.
