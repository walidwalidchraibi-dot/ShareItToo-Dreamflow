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
| Version und Build | `1.0.0 (2026081202)` |
| App-Commit | `72dd8f13b5d3be0e82392a8b28c31292bdc23b53` |
| Kanal und API | `internal`, `https://staging.shareittoo.com/api/v1` |
| Firebase und Zahlung | vollständig: `true`; `memory`; `stripeLivemode=false` |
| Android-AAB SHA-256 | `aaee3f1193e1a16ed29fa686af8017c3f0f244676f6a75b3fae2036efbe6ffc6` |
| Android-APK SHA-256 | `4445ff773ae728ef0959b4063e9f687ab86777ca9847d2a3605766de55afafec` |
| Uploadzertifikat SHA-256 | `098f485e57161558e911fc3c742845925584db31c474cdba08dda02feb0129a4` |
| Direkte Android-Diagnose | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-direct-smoke-2026081202-20260812T202447Z.json` |
| Direkte Android-App-Link-Diagnose | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-app-link-diagnostic-2026081202-20260812T202729Z.json` |
| Angemeldete Android-Sitzungsdiagnose | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-authenticated-session-2026081202-20260812T202858Z.json` |
| Synthetische Android-Rollenbuchung | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-synthetic-role-booking-2026081202-20260812T202947Z.json` |
| Authentifizierte Android-Deep-Links | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-authenticated-deep-links-2026081202-20260812T203105Z.json` |
| Kontrollierte Android-FCM-Diagnose | `passed` in Vordergrund, Hintergrund und bei beendetem Prozess; `docs/evidence/b11/android-controlled-fcm-2026081202-20260812T203436Z.json` |
| Android-Abmeldung und Push-Unterdrückung | `passed`; `docs/evidence/b11/android-logout-lifecycle-2026081202-20260812T203621Z.json` |
| Android-Offline-/Realtime-Wiederherstellung | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-offline-realtime-2026081202-20260812T203820Z.json` |
| Crashlytics-Releasezuordnung | `testing`; `docs/evidence/b11/android-crash-release-mapping-2026081202.json` |
| Play-Live-Vorprüfung | `ready-awaiting-explicit-internal-upload-approval`; Signierung stimmt, interner Kanal inaktiv mit 0 Bundles, geschlossener Test 0/12; `docs/evidence/b11/google-play-pre-upload-live-readiness-20260813.json` |
| Kandidatenbeleg | `docs/evidence/b11/android-candidate-2026081202.json` |
| Staging-Servercommit | `72dd8f13b5d3be0e82392a8b28c31292bdc23b53` |
| Ehrlicher Freigabestand | `testing/hold`; Gerätezellen 0/4; Releaseprüfungen 4/7 |

Dieser Block wird aus den verbindlichen JSON-Nachweisen geprüft. Die direkten APK-, App-Link-, Sitzungs-, Rollenbuchungs-, Deep-Link-, FCM-, Abmelde- und Offline-/Realtime-Diagnosen sind keine Store-Installation. Die kontrollierten synthetischen WLAN-Nachweise schließen weder Hotspot und die vollständige Rollen-/Netzmatrix noch TalkBack, iOS/TestFlight, Produktion oder Echtgeld.
<!-- SIT_CURRENT_RELEASE_SNAPSHOT_END -->

Der historische Crash-/Symbolnachweis
`android-crash-release-mapping-2026081029.json` bindet die im AAB eingebettete
R8-Zuordnung und alle nativen Android-Symbole per SHA-256 an Build 2026081029.
`android-crash-release-check-2026081029.json` belegt zusätzlich das bereinigte
kontrollierte Diagnoseereignis und seine sichtbare Zuordnung zur exakten
Version und Buildnummer in der Firebase-Konsole. Deshalb steht die
Releaseprüfung `crashReleaseMapping` für diesen früheren Build nachweislich auf
`passed`. Für den aktuellen Build `2026081202` sind die im exakten AAB
eingebettete R8-Zuordnung, die Mapping-ID und alle drei nativen Symbolgruppen
hashgebunden; die Originalzuordnung wurde erfolgreich zu Crashlytics geladen.
Die nativen Symbole sind vollständig paketiert und stimmen bytegenau mit dem
AAB überein. Aus den ungekürzten Bibliotheken wurden 22 gültige Breakpad-
Module erzeugt und erfolgreich zu Crashlytics übertragen; der lokale
Upload-Zwischenspeicher war anschließend vollständig geleert. Der
kontrollierte Diagnoseweg war in diesem exakten Kandidaten absichtlich nicht
einkompiliert. Deshalb wurde kein abweichender Binärstand unter derselben
Buildidentität verwendet. Der bereinigte Laufzeitbefund und seine sichtbare
Zuordnung in der Firebase-Konsole bleiben kandidatenspezifisch offen, daher
steht die Releaseprüfung weiterhin ehrlich auf `testing`.

Der aktuelle Abmelde-/Push-Unterdrückungsnachweis liegt unter
`android-logout-lifecycle-2026081113-20260811T182238Z.json`. Er belegt den
persistenten Gastzustand nach Kaltstart, den erneut geschützten privaten
Chat-Link und die ausbleibende Gerätebenachrichtigung nach einer kontrollierten
Testnachricht auf dem exakten Kandidaten. Das synthetische Testkonto wurde
danach privat wieder angemeldet, damit weitere Prüfungen ohne manuellen
Anmeldestopp fortgesetzt werden können. Store-Installation, Hotspot, TalkBack,
iOS und die vollständige Gerätematrix bleiben offen.

Die negative Routendiagnose
`public-store-route-diagnostic-20260810T214657Z.json` hält einen separaten
B12-Blocker fest: Die drei Backend-Seiten verhalten sich auf Staging korrekt,
die öffentlichen Pfade liefern jedoch nur die App-Hülle ohne Seiten- und
Compliance-Marker. Der Befund schließt kein Gate und hat weder Produktion noch
Staging verändert.

Die lesende Crashlytics-Triage
`crashlytics-open-issues-triage-20260810T221142Z.json` ordnet beide offenen
Fatal-Gruppen ausschließlich älteren Builds bis `2026081026` beziehungsweise
`2026081019` zu; Build `2026081029` wurde in diesen Gruppen nicht beobachtet.
Die vorbereitete Korrektur fängt den Echtzeit-Verbindungsaufbau ab, klassifiziert
Verbindungsfehler defensiv als nicht fatal und entfernt den alten Widget-Kontext
aus der Abmelde-Navigation. Zu diesem Zeitpunkt bestand sie 200 Flutter-Tests
sowie Web- und Android-Debug-Build; ein neuer exakter Kandidaten-Build mit
erneuter Geräteprüfung war noch nötig.

Die erneute lesende Prüfung
`crashlytics-open-issues-recheck-20260811T003517Z.json` bindet denselben Befund
an den inzwischen auf dem physischen Android-Gerät installierten Kandidaten
`2026081101`. Dieser Kandidat erscheint in keiner der beiden historischen
Fatal-Gruppen; seine Offline-/Wiederverbindungsdiagnose ist bestanden. Die
Gruppen bleiben dennoch offen, bis Abmeldung und Kaltstart mit einer
synthetischen angemeldeten Sitzung auf genau diesem Kandidaten wiederholt sind.
Firebase-Status, Produktion und Store-Einreichung wurden nicht verändert.

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
