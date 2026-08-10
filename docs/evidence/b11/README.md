# B11 – Bereinigte Geräte- und Store-Evidenz

Dieser Ordner enthält ausschließlich bereinigte Nachweise für den späteren
B11-Go/No-Go. Jeder verwendete Dateipfad wird in
`store/device-validation.json` referenziert. Für bestandene Gerätezellen,
Releaseprüfungen und Freigaben genügt kein beliebiger Dateitext: Der strenge
Validator verlangt einen inhaltlich geprüften JSON-Nachweis, der exakt an
Kandidat, Zell- beziehungsweise Prüfungs-ID und Zeitpunkt gebunden ist.

Zulässig sind insbesondere:

- Commit, Version, Buildnummer und SHA-256-Artefakthashes;
- Gerätemodell und Betriebssystem ohne Seriennummer, Werbe-ID oder andere
  persönliche Gerätekennung;
- bereinigte Testprotokolle, Store-Warnungen, Health-/Releasezuordnung und
  Go/No-Go-Entscheidungen;
- Screenshots nur nach Prüfung auf Namen, E-Mail, Adressen, Nachrichten,
  Zahlungsdetails und Gerätekennungen.

Nicht zulässig sind Passwörter, Review-Zugangsdaten, Tokens, API-Schlüssel,
Service-Accounts, private Schlüssel, Seriennummern, Android-/Werbe-IDs, IMEI,
IDFA, UDID, vollständige Logdateien mit Nutzerdaten oder unbereinigte
Bildschirmaufnahmen. Zugangsdaten bleiben ausschließlich in den geschützten
Feldern der Stores. Entsprechende Schlüssel werden rekursiv abgelehnt.

Ein bestandener Zellennachweis verwendet `kind=device-matrix-cell`; ein neuer
plattformweiter Nachweis `kind=release-check`; eine technische oder
produktseitige Freigabe `kind=approval`. Alle müssen `schemaVersion=1`, den
unveränderten Kandidaten und ausdrücklich sichere `boundaries` enthalten.

Der vorbereitete Android-Geräteprüfer
`tool/prepare_android_device_test.mjs` gibt nur ein bereinigtes Diagnoseobjekt
ohne ADB-Seriennummer aus. Eine direkte APK-Installation darf als technischer
Smoke-Test dokumentiert werden, jedoch niemals als Play-Internal-Installation
oder bestandene Gerätematrix.

`tool/diagnose_android_app_links.mjs` prüft zusätzlich vier eng begrenzte,
anonyme Linkfälle auf dem bereits verifizierten Android-Kandidaten: eine nicht
vorhandene Anzeige über Staging-HTTPS, den Gast-Chat über das eigene Schema,
eine verworfene unsichere Kennung und die Nichtzuordnung einer fremden Domain.
Der Nachweis schließt weder Store-Installation noch angemeldete Deep Links,
Rollen-/Netzmatrix, Push oder eine Buchung. Das Werkzeug verwendet keinen
Sperrcode und bricht bei einem gesperrten Gerät ab.

`tool/diagnose_android_authenticated_session.mjs` prüft auf dem exakt
gebundenen Android-Kandidaten, ob ein bereits vom Nutzer selbst angemeldetes
Staging-Konto die geschützten Profilaktionen erreicht und ob diese Sitzung
einen vollständigen App-Neustart übersteht. Der bereinigte Nachweis enthält
weder Name noch E-Mail oder Zugangsdaten. Er schließt ausdrücklich weder die
synthetische Vermieter-/Mieter-Matrix und Buchung noch Store-Installation,
angemeldete Deep Links, Push oder die manuelle TalkBack-Prüfung.

`tool/run_staging_synthetic_booking.mjs` nutzt ausschließlich den festen
Staging-Endpunkt und den privaten lokalen Rollentresor. Der Helfer erzeugt ein
isoliertes Inserat, eine Anfrage und die kontrollierten Zustände `requested`,
`accepted`, `active` und `completed`. Der reale Android-Lauf bestätigte die
Anfrage beim Vermieter und denselben Vorgang beim Mieter unter „Kommend“,
„Laufend“ und „Abgeschlossen“. Kein Zahlungsendpunkt wurde aufgerufen;
Zahlungsmodus `memory` und `stripeLivemode=false` bleiben erzwungen. Dieser
WLAN-Direktlauf ist keine Store-Installation und kein Hotspot-, TalkBack-,
Push-, iOS- oder vollständiger Matrixnachweis.

`tool/diagnose_android_authenticated_links.mjs` bindet den privaten
synthetischen Rollentresor ausschließlich zur Laufzeit ein und prüft auf dem
exakten installierten Kandidaten drei angemeldete Ziele: das Staging-Inserat,
die abgeschlossene Buchung und den zugehörigen Buchungs-Chat. Der ausgegebene
Nachweis enthält weder Kontodaten noch Inserat-, Buchungs-, Thread- oder
Gerätekennungen. Er sendet keine Nachricht und ruft keinen Zahlungsendpunkt
auf. Store-Installation, Hotspot, vollständige Gerätematrix, echte
Push-Zustellung, TalkBack und iOS/TestFlight bleiben offen.

<!-- SIT_CURRENT_RELEASE_SNAPSHOT_BEGIN -->
### Aktueller maschinengebundener B11-Kandidat

| Merkmal | Verbindlicher Wert |
|---|---|
| App-Identität | `com.shareittoo.app` (Android und iOS) |
| Version und Build | `1.0.0 (2026081026)` |
| App-Commit | `a3780a9d0fe00ed3890fd54f84150b41771a2d3d` |
| Kanal und API | `internal`, `https://staging.shareittoo.com/api/v1` |
| Firebase und Zahlung | vollständig: `true`; `memory`; `stripeLivemode=false` |
| Android-AAB SHA-256 | `55ea83436251ca657cad7604ac6353d9a65f79e80938a049c111708ae158650d` |
| Android-APK SHA-256 | `b1d3ba3e150047353c26b63a59cf76a786fdee4cd609f8816cdce916796844fe` |
| Uploadzertifikat SHA-256 | `098f485e57161558e911fc3c742845925584db31c474cdba08dda02feb0129a4` |
| Direkte Android-Diagnose | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-direct-smoke-2026081026-20260810T134810Z.json` |
| Direkte Android-App-Link-Diagnose | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-app-link-diagnostic-2026081026-20260810T140225Z.json` |
| Angemeldete Android-Sitzungsdiagnose | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-authenticated-session-2026081026-20260810T135037Z.json` |
| Synthetische Android-Rollenbuchung | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-synthetic-role-booking-2026081026-20260810T141301Z.json` |
| Authentifizierte Android-Deep-Links | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-authenticated-deep-links-2026081026-20260810T135137Z.json` |
| Kandidatenbeleg | `docs/evidence/b11/android-candidate-2026081026.json` |
| Staging-Servercommit | `ec570acfddc218cec6d2bfba43d4feb33bda4cfc` |
| Ehrlicher Freigabestand | `testing/hold`; Gerätezellen 0/4; Releaseprüfungen 3/7 |

Dieser Block wird aus den verbindlichen JSON-Nachweisen geprüft. Die direkten APK-, App-Link-, Sitzungs-, Rollenbuchungs- und authentifizierten Deep-Link-Diagnosen sind keine Store-Installation. Der synthetische WLAN-Nachweis schließt weder Hotspot und die vollständige Rollen-/Netzmatrix noch TalkBack, echte Push-Zustellung, iOS/TestFlight, Produktion, Echtgeld oder eine gesendete Chatnachricht.
<!-- SIT_CURRENT_RELEASE_SNAPSHOT_END -->

Der zusätzliche exakte Logout-/Push-Lebenszyklusnachweis für Build
`2026081026` liegt unter
`android-logout-push-lifecycle-2026081026-20260810T140200Z.json`. Er belegt
Vordergrund-, Hintergrund- und bei zuvor beendetem Prozess ausgelöste
Staging-Pushs, das vergrößerte adaptive Symbol, die Anmeldesperre nach einem
Kaltstart und die ausbleibende Zustellung nach dem Logout. Store-Installation,
Hotspot, TalkBack, iOS und die vollständige Gerätematrix bleiben offen.

Die folgenden Direkt-Smoke-Nachweise bleiben als chronologische Historie
erhalten; nur der obige Snapshot und die Referenzen im Manifest bezeichnen den
aktuellen Kandidaten.

Der erste reale Direkt-Smoke-Test des unveränderten Builds `2026080903` bleibt
in `android-direct-smoke-2026080903-20260809T202357Z.json` als historische
Evidenz erhalten. Nach der Korrektur der Registrierungsweiterleitung wurde der
neue Kandidat `2026080904` auf einem physischen Pixel 7 Pro installiert und
erstmals gestartet; der aktuelle Beleg liegt in
`android-direct-smoke-2026080904-20260809T213814Z.json`.

Beide Nachweise belegen ausschließlich Kandidatenprüfung, Installation,
zurückgelesene Version und Buildnummer sowie den Erststart. Alle Funktions-,
Push-, Netzwerk-, Accessibility- und Play-Internal-Gates bleiben ausdrücklich
offen. `store/device-validation.json` referenziert nur den aktuellen Beleg
unter `candidate.android.directDiagnostic`; der Validator prüft ihn
inhaltlich gegen denselben Kandidaten und dieselben offenen Grenzen.
