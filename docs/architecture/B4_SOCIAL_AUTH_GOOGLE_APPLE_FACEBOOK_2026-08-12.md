# B4 – Social Login mit Google, Apple und Facebook

Status: Code und lokale Prüfungen fertig; Anbieter in den externen Konsolen
noch nicht aktiviert.

## Verifizierter externer Stand am 14. August 2026

- Firebase Authentication ist im Projekt `shareittoo-staging` initialisiert.
  Noch kein Anbieter ist gespeichert oder für Nutzer freigeschaltet.
- Das SIT-Geschäftskonto besitzt Projektzugriff und ist zusätzlich zum
  bisherigen privaten Eigentümerkonto als Projekteigentümer eingetragen. Das
  private Konto bleibt als Rückfallzugang bestehen.
- Der Google-Anbieter ist vorbereitet, aber nicht gespeichert: Die Konsole
  verlangt eine erneute Anmeldung des SIT-Geschäftskontos, bevor dessen
  Adresse als öffentliche OAuth-Supportadresse verwendet werden kann. Die
  private Adresse wurde ausdrücklich nicht ersatzweise gespeichert.
- SHA-1 und SHA-256 des kanonischen Android-Upload-Zertifikats sind im
  Firebase-Android-App-Eintrag gespeichert und in der Konsole rückgelesen.
  Die Android-Konfigurationsdatei wird erst nach Aktivierung des Google-
  Anbieters einmalig neu geladen, damit sie den endgültigen OAuth-Stand
  enthält.
- Die vorhandene Apple-Firebase-Datei passt zu Projekt und Bundle-ID, enthält
  aber vor der Google-Aktivierung noch keinen iOS-OAuth-Client, keine
  umgekehrte Client-ID und kein aktiviertes Google Sign-In. Der
  Release-Validator lehnt sie deshalb weiterhin geschlossen ab.
- Auf dem Build-Mac sind nur die Apple Command Line Tools vorhanden.
  Vollständiges Xcode, `xcodebuild` und CocoaPods fehlen; ein iOS-Archiv wurde
  folgerichtig nicht versucht.
- Es wurden keine OAuth-Schlüssel, Provider-Secrets oder Nutzertokens gelesen,
  gespeichert oder in das Repository übernommen. `FIREBASE_AUTH_ENABLED`
  bleibt unverändert aus.

## Architektur

- Firebase Authentication führt den jeweiligen Anbieter-Dialog aus und stellt
  ein kurzlebiges Firebase-ID-Token aus.
- Die App sendet ausschließlich dieses Firebase-ID-Token an
  `POST /v1/auth/social`. Provider-Zugriffstoken werden weder im SIT-Backend
  gespeichert noch protokolliert.
- Das Backend prüft Signatur, Zielprojekt und Widerruf über das Firebase Admin
  SDK. Es akzeptiert ausschließlich `google.com`, `apple.com` und
  `facebook.com`.
- Erst danach verknüpft das Backend die externe Identität mit genau einem
  SIT-Konto und stellt die normale kurzlebige SIT-Sitzung mit rotierendem
  Refresh-Token aus. Kontostatus, Moderation und Berechtigungen bleiben
  ausschließlich im SIT-Backend maßgeblich.
- Die Kontoverknüpfung verwendet die unveränderliche native Anbieter-ID;
  zusätzlich wird die Firebase-Nutzer-ID für Export, Widerruf und die spätere
  vollständige Kontolöschung festgehalten. Anbieter-Tokens werden weiterhin
  nicht gespeichert.
- Nach erfolgreicher Übergabe an das SIT-Backend meldet die App Firebase sowie
  das Google- beziehungsweise Facebook-SDK wieder ab. Auf dem Gerät verbleibt
  nur die normale SIT-Sitzung.

## Sichere Kontoverknüpfung

- Google und Apple dürfen nur mit einer vom Anbieter bestätigten E-Mail ein
  bestehendes SIT-Konto automatisch verknüpfen.
- Facebook-E-Mails gelten laut Firebase nicht automatisch als bestätigt. Ein
  neues Facebook-Konto erhält deshalb einmal eine SIT-Bestätigungs-E-Mail.
- Eine unbestätigte Facebook-E-Mail darf niemals ein vorhandenes SIT-Konto
  übernehmen; dafür ist zuerst die bestehende SIT-Anmeldung erforderlich.
- Neue Nutzer müssen Mindestalter, AGB und Datenschutz bestätigen – unabhängig
  vom gewählten Anbieter.
- Gleichzeitige Anmeldeversuche werden je Provider-Identität serialisiert;
  Datenbank-Eindeutigkeitsregeln verhindern Doppelverknüpfungen.

## Noch erforderliche externe Einrichtung

1. In Firebase Authentication Google, Apple und Facebook aktivieren.
2. Android-SHA-1 und SHA-256 des echten Upload-Zertifikats sind in Firebase
   registriert. Nach Aktivierung des Google-Anbieters die Android-
   Konfigurationsdatei neu laden und validieren. Die kanonischen
   Fingerabdrücke sind SHA-1
   `6A:79:73:86:14:85:F7:33:0D:57:25:FF:D6:AA:A9:06:6D:78:97:14` und SHA-256
   `09:8F:48:5E:57:16:15:58:E9:11:FC:3C:74:28:45:92:55:84:DB:31:C4:74:CD:BA:08:DD:A0:2F:EB:01:29:A4`.
3. Apple Developer: „Sign in with Apple“ für `com.shareittoo.app` aktivieren,
   Firebase-Apple-Provider verbinden und die iOS-Konfiguration aktualisieren.
4. Meta Developer App anlegen; echte öffentliche App-ID und Client-Token nur
   über die Release-Konfiguration liefern, App Secret ausschließlich in
   Firebase/Meta verwalten.
5. Erst danach `FIREBASE_AUTH_ENABLED=true` im Backend setzen und die drei
   Wege auf Staging-Geräten prüfen.

Bis diese Schritte vollständig sind, scheitern die Anbieterwege sichtbar und
geschlossen; E-Mail-Anmeldung bleibt verfügbar.
