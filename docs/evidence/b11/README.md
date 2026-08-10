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

<!-- SIT_CURRENT_RELEASE_SNAPSHOT_BEGIN -->
### Aktueller maschinengebundener B11-Kandidat

| Merkmal | Verbindlicher Wert |
|---|---|
| App-Identität | `com.shareittoo.app` (Android und iOS) |
| Version und Build | `1.0.0 (2026081018)` |
| App-Commit | `555946e64e583e5b6ee3321de2c1f74f35fbf238` |
| Kanal und API | `internal`, `https://staging.shareittoo.com/api/v1` |
| Firebase und Zahlung | vollständig: `true`; `memory`; `stripeLivemode=false` |
| Android-AAB SHA-256 | `1a35e64413c840c59660e6ffa7416e16fe38398190b0968d89a4d63b0d2a04d4` |
| Android-APK SHA-256 | `51121b9866dac109eaa42c78950d90d33b3d4ef9f9ec7301ddfe62fbe6120619` |
| Uploadzertifikat SHA-256 | `098f485e57161558e911fc3c742845925584db31c474cdba08dda02feb0129a4` |
| Direkte Android-Diagnose | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-direct-smoke-2026081018-20260810T043849Z.json` |
| Direkte Android-App-Link-Diagnose | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-app-link-diagnostic-2026081018-20260810T055418Z.json` |
| Kandidatenbeleg | `docs/evidence/b11/android-candidate-2026081018.json` |
| Staging-Servercommit | `9a1371e02d8e7d63d3dee30ca169c6c7f37fa966` |
| Ehrlicher Freigabestand | `testing/hold`; Gerätezellen 0/4; Releaseprüfungen 3/7 |

Dieser Block wird aus den verbindlichen JSON-Nachweisen geprüft. Die direkten APK- und App-Link-Diagnosen sind keine Store-Installation und schließen weder die Rollen-/Netzmatrix noch angemeldete Deep Links, TalkBack, Push, iOS/TestFlight, Produktion oder Echtgeld.
<!-- SIT_CURRENT_RELEASE_SNAPSHOT_END -->

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
