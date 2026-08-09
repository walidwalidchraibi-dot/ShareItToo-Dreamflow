# B11 – Maschinenlesbare Geräteabnahme und Go/No-Go

Stand: 9. August 2026  
Status: technisch vorbereitet; reale Store- und Geräteabnahme bleibt offen

## Ziel und Wahrheitsgrenze

Die reale B11-Abnahme war bisher ausschließlich als ausführliches Runbook
beschrieben. `store/device-validation.json` macht daraus zusätzlich einen
versionierten, maschinenlesbaren Nachweis. Er verhindert, dass ein lokaler
Zwischenbuild, ein Simulatorlauf, nur eine Plattform oder ein unvollständiger
Push-/Accessibility-Test versehentlich als B11-Freigabe gilt.

Der aktuelle Zustand bleibt bewusst:

- `state=planned`;
- `goNoGo=no-go`;
- vier von vier Gerätezellen offen;
- sieben von sieben plattformweiten Releaseprüfungen offen;
- Buildnummer und finale Artefakthashes noch nicht gesetzt;
- Firebase deaktiviert, Store-Installation ausstehend und Echtgeld gesperrt.

## Fest an denselben Kandidaten gebundene Angaben

Ein bestandener Nachweis verlangt gleichzeitig:

- Android Application ID und iOS Bundle ID `com.shareittoo.app`;
- Version `1.0.0`, Build `2026080903` oder höher und Übereinstimmung mit
  `pubspec.yaml`;
- vollständigen 40-stelligen Commit;
- ausschließlich den internen Kanal und
  `https://staging.shareittoo.com/api/v1`;
- vollständige Firebase-Konfiguration, aber weiterhin
  `stripeLivemode=false`;
- AAB-, APK-, Signaturzertifikat- und IPA-SHA-256;
- Play-Internal- und TestFlight-Internal-Installation;
- Apple-Teamkennung und bestandenen IPA-/Privacy-Manifest-Scan.

Jede Änderung an Commit, Buildnummer, Signatur, Firebase-Konfiguration oder
API-Ziel macht die betroffene Abnahme ungültig und verlangt einen neuen
Nachweis.

## Verbindliche reale Gerätematrix

Vier Zellen sind nicht austauschbar:

| Zelle | Plattform | Netz | Rolle | Screenreader |
|---|---|---|---|---|
| `android-wifi-owner` | Android | WLAN | Vermieter | TalkBack |
| `android-hotspot-renter` | Android | Hotspot/Mobilfunk | Mieter | TalkBack |
| `ios-wifi-owner` | iOS | WLAN | Vermieter | VoiceOver |
| `ios-hotspot-renter` | iOS | Hotspot/Mobilfunk | Mieter | VoiceOver |

Jede Zelle muss ein physisches Gerät, Modell und Betriebssystem ohne
Seriennummer dokumentieren. Alle folgenden Prüfgruppen müssen bestanden sein:

- Store-Installation und Erststart;
- Anmeldung, Sitzung und Neustart;
- Inserat und Buchungsfluss;
- Chat und Deep Link;
- Push im Vordergrund, Hintergrund und nach beendetem Prozess;
- Übergabe und Rückgabe;
- Melden/Blockieren sowie Kontenfunktionen;
- Offline-Wiederkehr;
- 200-Prozent-Schrift und TalkBack beziehungsweise VoiceOver.

## Plattformweite Releaseprüfungen

Zusätzlich zu den vier Gerätezellen sind sieben Nachweise zwingend:

1. Kandidatenidentität und Signaturen;
2. Firebase, FCM und APNs;
3. finaler Binärdatenschutz und reale Netzwerkbeobachtung;
4. Crashlytics-Releasezuordnung ohne sensible Inhalte;
5. Store-Warnungen, Deep Links und App-Signing;
6. Bereinigung synthetischer Staging-Daten und gesunde Readiness;
7. unveränderte Produktion und gesperrtes Echtgeld.

Technische und produktseitige Freigabe erhalten jeweils einen bereinigten
lokalen Beleg und einen ISO-Zeitpunkt. Review-Passwörter oder andere
Zugangsdaten dürfen weder im Manifest noch in Evidenzdateien stehen.

## Fail-closed-Verknüpfung

Standardprüfung:

```text
node tool/validate_device_evidence.mjs
```

Sie akzeptiert den ehrlichen offenen Planstand und läuft in jeder technischen
Regression sowie im Release-Preflight. Neun Negativ-/Positivtests prüfen
unter anderem vorzeitiges `go`, fehlende Matrixzellen, credential-förmige
Felder, fehlende Evidenzdateien und einen vollständig synthetisch erzeugten
Passzustand.

Strenge Prüfung:

```text
node tool/validate_device_evidence.mjs --require-passed
```

Sie bleibt derzeit erwartungsgemäß rot. `SIT_REQUIRE_STORE_SUBMISSION=1`
erzwingt sie vor jedem späteren Store-Upload zusätzlich zum strengen
Metadaten- und Pflichtseitencheck.

Ein B11-Pass darf die drei zugehörigen Gates in `store/submission.json` nur
gemeinsam schließen:

- `realAndroidAndIosDevices`;
- `finalBinaryPrivacyScan`;
- `closedStoreAndAccessibilityMatrix`.

Sind alle drei geschlossen, ohne dass der Gerätevalidator `state=passed` und
`goNoGo=go` beweist, bricht die Prüfung ab. B12 bleibt bis zu diesem
unveränderten, belegten Gerätebuild gesperrt.

## Evidenzablage und Schutz

Alle referenzierten Dateien liegen unter `docs/evidence/b11/`. Der strenge
Validator akzeptiert keine absoluten Pfade, kein `..`, keine fehlenden oder
leeren Dateien. Die Ablage enthält nur synthetische Konten und bereinigte
Belege ohne Secrets, Review-Zugangsdaten, Roh-Gerätekennungen oder private
Nutzerdaten.

Dieser Baustein verändert weder Staging noch Produktion, Caddy, DNS, Mail,
Cronjobs, Stripe-Live oder Echtgeld. Er erzeugt keinen Store-Kandidaten und
schließt kein reales Gate.
