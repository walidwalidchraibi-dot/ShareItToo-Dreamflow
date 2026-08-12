# B11 – Google-Play-Console-Eingabeblatt

Stand: 12. August 2026
Status: interner, geheimnisfreier Arbeitsentwurf; keine Einreichung freigegeben

## 1. Zweck und feste Grenze

Dieses Blatt ordnet die bereits belegten ShareItToo-Fakten den erwarteten
Google-Play-Feldern zu. Es dient nach Abschluss der persönlichen
Kontoverifizierung als Eingabe- und Gegenprüfliste. Es ersetzt weder die
sichtbaren Console-Fragen noch Rechts-/Datenschutzentscheidungen und darf
keinen Upload oder Review-Versand auslösen.

Verbindlicher Kandidat:

- App: `ShareItToo`
- Paket: `com.shareittoo.app`
- Version: `1.0.0`
- Build: `2026081116`
- App-Commit: `03a76e23b0db656b48fc1729b3cd20e6260f2133`
- Kanal: ausschließlich Internal Testing
- Umgebung: ausschließlich Staging
- Zahlung: `paymentMode=memory`, `stripeLivemode=false`
- Freigabezustand: `testing/hold`, keine Store-Einreichung erlaubt

## 2. Persönliches Entwicklerkonto – vor App-Erstellung

Bereits erledigt:

- persönliches Google-Play-Entwicklerkonto `ShareItToo` erstellt;
- erforderliche Konto-Verträge bewusst angenommen;
- einmalige Registrierungsgebühr bezahlt.

Offen und nur durch Walid abschließbar:

1. Identität mit amtlichem Lichtbildausweis und gegebenenfalls gültigem
   Adressnachweis verifizieren;
2. geforderten Zugriff auf ein echtes Android-Gerät bestätigen;
3. Kontakttelefonnummer per Einmalcode bestätigen;
4. sichtbare Personen-/Adressdaten vor Bestätigung gegen die echten Dokumente
   prüfen.

Keine Ausweisbilder, Telefonnummern, Einmalcodes, E-Mail-Adressen,
Zahlungsdaten oder Google-Konto-IDs in Git, Drive, Telegram oder Evidenz
übernehmen.

## 3. „App erstellen“ – vorbereitete Eingaben

| Console-Feld | Arbeitswert | Grenze |
|---|---|---|
| Standardsprache | Deutsch – Deutschland (`de-DE`) | vor Speichern sichtbare Auswahl prüfen |
| App-Name | `ShareItToo` | 10 von 30 Zeichen |
| App oder Spiel | App | kein Spiel |
| Kostenlos oder kostenpflichtig | kostenlos | nach Veröffentlichung nicht ohne Folgen auf bezahlt umstellbar |
| Nutzerkontakt | im geschützten Console-Feld die betriebliche ShareItToo-Adresse | niemals in Repository/Evidenz kopieren |
| Entwicklerprogramm-Richtlinien | nur nach sichtbarer Prüfung bestätigen | Kontoinhaberentscheidung |
| US-Exportrecht | nur nach sichtbarer Prüfung bestätigen | Kontoinhaberentscheidung |
| Play App Signing | für den neuen App-Datensatz vorgesehen | Terms vor Annahme sichtbar prüfen |

Die App vermittelt die zeitweise Nutzung physischer Gegenstände außerhalb der
App. Für diese Mietzahlungen wird kein Google Play Billing eingerichtet.
Digitale Abonnements, Credits, Funktionsfreischaltungen oder werbefreie
Premiumstufen sind im Kandidaten 2026081116 nicht enthalten.

## 4. Store-Haupteintrag

Vorbereitete Dateien:

- Titel: `store/google-play/de-DE/title.txt`
- Kurzbeschreibung: `store/google-play/de-DE/short_description.txt`
- vollständige Beschreibung: `store/google-play/de-DE/full_description.txt`
- interne Release-Notiz: `store/google-play/de-DE/internal_release_notes.txt`
- Alternativtexte: `store/google-play/de-DE/screenshot_alt_texts.json`
- App-Icon: `store/assets/google-play/icon-512.png`
- Feature-Grafik: `store/assets/google-play/feature-graphic-1024x500.png`

Arbeitswerte:

| Feld | Wert/Status |
|---|---|
| App-Kategorie | Shopping |
| Tags | erst aus den tatsächlich angebotenen Console-Tags auswählen |
| Website | `https://shareittoo.com/` – technisch verifiziert |
| Support-URL | `https://shareittoo.com/support` – noch nicht veröffentlichungsfähig |
| Datenschutz-URL | `https://shareittoo.com/privacy` – noch nicht veröffentlichungsfähig |
| öffentliche Kontolöschung | `https://shareittoo.com/account-deletion` – noch nicht veröffentlichungsfähig |
| Telefon-Screenshots | noch leer; nur bereinigte Aufnahmen von Kandidat 2026081116 zulässig |

Support-, Datenschutz- und Lösch-URL erst speichern beziehungsweise zur
Prüfung senden, wenn die sichtbaren öffentlichen Seiten inhaltlich freigegeben
und ohne Login mobil erreichbar sind. Ein HTTP-200 mit der normalen App-Shell
gilt nicht als Nachweis.

## 5. App-Inhalte – vorbereitete Antworten

### 5.1 Werbung

- Antwort für Kandidat 2026081116: **Nein, die App enthält keine Werbung.**
- Beleg: kein Werbe-SDK, kein Firebase Analytics, kein Advertising Tracking.
- Eine im Entwicklerprofil genannte mögliche spätere Werbefinanzierung ändert
  die Antwort für diesen konkreten App-Build nicht.
- Vor jedem späteren Build Abhängigkeiten und Binärscan erneut prüfen.

### 5.2 App-Zugriff / Sign-in details

- Teile der App sind auf angemeldete Nutzer beschränkt: **Ja**.
- Zwei synthetische Rollen stehen bereit: Vermieter und Mieter.
- Passwort-Login ohne OTP ist technisch bestanden.
- Aktives Inserat, akzeptierte Testbuchung, gemeinsamer Chat, Melden/Blockieren,
  Datenexport und Löschung eines entbehrlichen Testkontos sind bestanden.
- Zugangsdaten ausschließlich in den geschützten Play-Console-Feldern
  eintragen; niemals in Freitext, Git, Drive, Telegram oder Screenshots.
- Die geschützten Console-Felder sowie Login aus frischer Store-Installation
  und Zweitnetz bleiben offen.

Englischer Review-Text ist im Abschnitt „App-Zugriff für Google Review“ von
`docs/operations/B11_STORE_SUBMISSION_PACKET_2026-08-09.md` vorbereitet.

### 5.3 Zielgruppe und Kinder

- Zielgruppe: ausschließlich Erwachsene/18+.
- Für Kinder entwickelt: **Nein**.
- Keine Altersgruppe unter 18 auswählen.
- Die sichtbare Altersfrage der Registrierung ist eine Mindestalter-
  Bestätigung; AGB, Datenschutz und Mindestalter bleiben getrennte,
  standardmäßig nicht gesetzte Bestätigungen.

### 5.4 Nutzerinhalte und Kommunikation

- Nutzerinhalte: **Ja** – Inserate, Bilder, Dateien, Chats, Bewertungen und
  Meldungen.
- Direkte Kommunikation: **Ja** – private Buchungs-Chats.
- Melden und Blockieren sind im Kandidaten vorhanden und technisch geprüft.
- Community-/Nutzerinhaltsregeln und endgültige Moderations-/Rechtsfreigabe
  bleiben offen; kein Review-Versand vor Veröffentlichung der Regeln.

### 5.5 Weitere Inhaltsangaben

| Bereich | Arbeitsantwort |
|---|---|
| Nachrichten-/Magazin-App | nein |
| staatliche App | nein |
| Gesundheits-/Medizin-App | nein |
| VPN-App | nein |
| Glücksspiel oder Echtgeldspiel | nein |
| Bank, Kredit, Anlage, Krypto oder anderes Finanzprodukt | nein |
| Kauf/Miete physischer Gegenstände | ja |
| In-App-Purchases digitaler Güter im aktuellen Kandidaten | nein |

Den IARC-Inhaltsfragebogen nicht pauschal vorwegnehmen. Jede sichtbare Frage
gegen die tatsächlichen Inserat-, Chat- und Nutzerinhaltsfunktionen beantworten
und die erzeugte Einstufung vor dem Speichern prüfen.

## 6. Data Safety – technischer Entwurf

Globale Arbeitsantworten:

| Frage | Arbeitsantwort/Status |
|---|---|
| Sammelt oder überträgt die App Nutzerdaten? | ja |
| Daten bei Übertragung verschlüsselt? | ja, HTTPS/TLS; finalen Upload erneut prüfen |
| Nutzer kann Löschung beantragen? | technisch ja; öffentliche Produktionsseite noch offen |
| Datenverkauf oder Werbetracking? | nein |
| „Data shared“ | offen, bis Service-Provider-/Auftragsverarbeiter-Einordnung je Empfänger bestätigt ist |
| Alle Daten optional? | nein; Konto-/Sicherheitsdaten sind erforderlich, viele Featuredaten optional |

Konservativ vorbereitete Datentypen sind in
`store/privacy-disclosures.json` und
`docs/operations/B11_STORE_PRIVACY_DISCLOSURE_MATRIX_2026-08-09.md`
einzeln belegt. Dazu gehören insbesondere:

- Name, E-Mail, optionale Telefonnummer und Adresse;
- User-ID;
- grober und optional präziser Standort;
- Fotos, Dateien, Nachrichten und sonstige Nutzerinhalte;
- Buchungs-/Kaufhistorie und sonstige Finanzinformationen;
- Push-/Installationskennungen;
- Crashdaten und sonstige Diagnostik.

Vollständige Karten- oder Bankdaten werden im Kandidaten nicht von
ShareItToo erhoben. Stripe-Liveverarbeitung ist deaktiviert. „Shared“ darf
erst final beantwortet werden, wenn die konkrete Service-Provider-Einordnung
für Hosting, Mail, Firebase/Google Maps und den späteren Zahlungsdienst
bestätigt ist. Das Data-Safety-Formular noch nicht absenden.

## 7. Berechtigungen und SDK-Prüfung nach AAB-Upload

Der zusammengeführte Release-APK von exakt Kandidat 2026081116 wurde bereits
vor dem Store-Upload geprüft. Er enthält nur die erwarteten Funktions-,
Netzwerk- und Firebase-Berechtigungen für Kamera, Bilder, groben/präzisen
Standort, Benachrichtigungen, Internet/Netzstatus, Wake Lock und FCM. Nicht
enthalten sind unter anderem SMS-/Anruflisten-/Kontakte-, Mikrofon-,
Accessibility-Service-, Vollspeicher-, Paketinstallations-,
Alle-Pakete-Abfrage- oder Overlay-Berechtigungen. Der bereinigte,
artefaktgebundene Nachweis liegt in
`docs/evidence/b11/android-release-permissions-2026081116.json`.

Diese Vorprüfung nimmt keine Console-Antwort vorweg. Google kann erst nach dem
AAB-Upload zusätzliche SDK- oder Berechtigungswarnungen anzeigen; diese bleiben
bis zur sichtbaren Prüfung offen.

Nach dem ersten Internal-AAB-Upload:

1. Play-Console-Warnungen und SDK-Index-Hinweise vollständig lesen;
2. nur tatsächlich vom Bundle ausgelöste Berechtigungsformulare bearbeiten;
3. Kamera, Foto-/Dateizugriff, Standort und Benachrichtigungen als
   funktionsbezogene, nutzerinitiierte Flows erklären;
4. keine SMS-, Anruflisten-, Accessibility-Service- oder anderen nicht
   implementierten Sonderberechtigungen beanspruchen;
5. Play-App-Signing-Zertifikat bereinigt erfassen und zusätzlich zum
   Uploadzertifikat in `assetlinks.json` vorbereiten;
6. vor jeder öffentlichen Route, DNS-/Serveränderung oder Einreichung erneut
   Backup, Inhaltsprüfung, kontrollierten Reload und Rollback planen.

## 8. Internal Testing – Freigabereihenfolge

1. persönliche Konto-Verifizierung abschließen;
2. App-Datensatz mit den Angaben aus Abschnitt 3 anlegen;
3. Store-Haupteintrag und App-Inhalte zunächst als Entwurf ausfüllen;
4. exakt den gebundenen AAB-Kandidaten 2026081116 hochladen;
5. Uploadwarnungen, App-Signing-Fingerprint und Artefaktidentität prüfen;
6. geschützte Review-Zugangsdaten eintragen;
7. nur Internal Testing vorbereiten – keine Production-, Open- oder Closed-
   Veröffentlichung;
8. aus Play installieren und dieselbe Kandidaten-/Gerätematrix wiederholen;
9. erst danach über Closed Testing und die für neue persönliche Konten
   angezeigte Testeranforderung entscheiden.

## 9. Harte Stop-Regeln

Kein „Send for review“, Rollout oder öffentliche Freigabe, solange mindestens
einer dieser Punkte offen ist:

- Identitäts-, Geräte- oder Telefonnummernprüfung;
- öffentliche Datenschutz-, Support- oder Löschseite;
- Anbieter-/Copyright- und Nutzerinhaltsregeln;
- finale Data-Safety-/Auftragsverarbeiter-Entscheidung;
- geschützte Review-Felder oder frischer Store-Login;
- Store-Screenshots und Privatdatenprüfung;
- Play-App-Signing-/Asset-Link-Nachweis;
- Store-Installation, Hotspot/TalkBack oder übrige B11-Matrix;
- Crashlytics-Zuordnung für exakt den hochgeladenen Kandidaten;
- technisches und produktseitiges Go.

## 10. Quellen

- Google Play: App erstellen und einrichten –
  <https://support.google.com/googleplay/android-developer/answer/9859152?hl=en-EN>
- Google Play: App für Review vorbereiten –
  <https://support.google.com/googleplay/android-developer/answer/9859455?hl=en-EN>
- Google Play: Data Safety –
  <https://support.google.com/googleplay/android-developer/answer/10787469?hl=en>
- Google Play: Zahlungen und Miete physischer Güter –
  <https://support.google.com/googleplay/android-developer/answer/9858738?hl=en>
- Google Play: Entwicklerkonto-Angaben –
  <https://support.google.com/googleplay/android-developer/answer/13628312?hl=en>
