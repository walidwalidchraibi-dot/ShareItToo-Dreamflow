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
- Ersatz-Build: `2026081202` (Build und erneute Binärprüfung noch ausstehend)
- App-Commit: `c6ec80002cf664f513afc768c1b643ac0d1d19fb`
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
Premiumstufen sind auch im geplanten Ersatzkandidaten 2026081202 nicht enthalten.

Falls die Kontoregistrierung allgemein nach geplanten Einnahmequellen fragt,
ist eine mögliche spätere Provision auf die Miete physischer Gegenstände als
anderer Geschäftsumsatz plausibel. Sie macht die konkrete Miete aber nicht zu
einem In-App-Kauf im Sinne digitaler Play-Produkte. „Ads“, „Subscriptions“ und
digitale „In-App purchases“ dürfen für den aktuellen Kandidaten nicht als
vorhandene App-Funktionen übernommen werden: Der signierte Build enthält weder
Werbe-SDK noch digitale Abonnements oder digitale Kaufprodukte. Erst ein
späterer, tatsächlich implementierter Build würde diese Antworten ändern.

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
| Telefon-Screenshots | vier bereinigte, lokal validierte Aufnahmen des unmittelbar vorherigen UI-Stands vorhanden; vor Upload nochmals gegen Kandidat 2026081201 prüfen |

Support-, Datenschutz- und Lösch-URL erst speichern beziehungsweise zur
Prüfung senden, wenn die sichtbaren öffentlichen Seiten inhaltlich freigegeben
und ohne Login mobil erreichbar sind. Ein HTTP-200 mit der normalen App-Shell
gilt nicht als Nachweis.

## 5. App-Inhalte – vorbereitete Antworten

### 5.1 Werbung

- Antwort für Kandidat 2026081201: **Nein, die App enthält keine Werbung.**
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

### 5.6 Finanzfunktionen

Auch Apps ohne Finanzfunktion müssen das sichtbare Google-Play-Formular
beantworten. Der aktuelle Kandidat bietet weder Banking, Kredite,
Geldtransfer, Wallet, Krypto, Anlage, Versicherung noch „Buy now, pay later“.
Die reine Vermittlung und spätere Bezahlung einer Miete physischer Gegenstände
ist nach dem derzeit belegten Funktionsumfang keine solche Finanzfunktion.
Arbeitsantwort deshalb: **„Meine App bietet keine Finanzfunktionen.“** Vor dem
Speichern jede dann sichtbare Definition erneut gegen den tatsächlichen Build
prüfen; eine spätere Wallet-, Kredit-, Versicherungs- oder eigene
Zahlungsfunktion würde eine neue Bewertung erzwingen.

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

Der Release-APK von Kandidat 2026081201 wurde geprüft, anschließend aber wegen
eines eingebetteten, nicht an eine Anwendung gebundenen Google-Schlüssels
gesperrt und nicht hochgeladen. Ersatzkandidat 2026081202 darf erst nach neuer
Binärprüfung verwendet werden. Er soll nur die erwarteten Funktions-,
Netzwerk- und Firebase-Berechtigungen für Kamera, Bilder, groben/präzisen
Standort, Benachrichtigungen, Internet/Netzstatus, Wake Lock und FCM. Nicht
enthalten sind unter anderem SMS-/Anruflisten-/Kontakte-, Mikrofon-,
Accessibility-Service-, Vollspeicher-, Paketinstallations-,
Alle-Pakete-Abfrage- oder Overlay-Berechtigungen. Der bereinigte,
artefaktgebundene Nachweis liegt in
`docs/evidence/b11/android-release-permissions-2026081201.json`; dieser alte
Nachweis darf nicht als Freigabe des Ersatzkandidaten verwendet werden.

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
   Uploadzertifikat in `assetlinks.json` vorbereiten – am 12.08.2026 erledigt;
6. vor jeder öffentlichen Route, DNS-/Serveränderung oder Einreichung erneut
   Backup, Inhaltsprüfung, kontrollierten Reload und Rollback planen.

## 8. Internal Testing – Freigabereihenfolge

1. persönliche Konto-Verifizierung abschließen;
2. App-Datensatz mit den Angaben aus Abschnitt 3 anlegen;
3. Store-Haupteintrag und App-Inhalte zunächst als Entwurf ausfüllen;
4. ausschließlich den nach neuer Prüfung gebundenen AAB-Ersatzkandidaten 2026081202 hochladen;
5. Uploadwarnungen, App-Signing-Fingerprint und Artefaktidentität prüfen;
6. geschützte Review-Zugangsdaten eintragen;
7. nur Internal Testing vorbereiten – keine Production-, Open- oder Closed-
   Veröffentlichung;
8. aus Play installieren und dieselbe Kandidaten-/Gerätematrix wiederholen;
9. erst danach über Closed Testing und die für neue persönliche Konten
   angezeigte Testeranforderung entscheiden.

Für dieses neu erstellte persönliche Konto gilt nach der aktuell
veröffentlichten Google-Play-Regel: Vor einem Antrag auf Produktionszugang
müssen mindestens zwölf Tester während mindestens 14 aufeinanderfolgenden
Tagen durchgehend im geschlossenen Test angemeldet sein. Internal Testing hat
keine Tester-Mindestzahl und kann sofort für die technische Store-Installation
verwendet werden, startet diese 14-Tage-Frist aber nicht. Deshalb bleibt der
separate Launch-Gate `googlePlayClosedTestingRequirement` auch nach der
Identitätsprüfung offen, bis ein eigener bereinigter Closed-Test-Nachweis
vorliegt.

Die qualifizierende Uhr startet erst bei einer bestätigten aggregierten
Console-Beobachtung von mindestens zwölf gleichzeitig durchgehend angemeldeten
Testern. Ein Bestand von elf oder weniger wird nicht als Beginn gespeichert.
Der sichere Vorschau-Lauf lautet:

```text
node tool/prepare_google_play_closed_testing_observation.mjs \
  --observed-at <UTC-CONSOLE-ZEITPUNKT> \
  --continuous-testers <ANZAHL>
```

Ohne `--confirm-console-observation` ändert das Werkzeug keine Datei. Erst nach
manueller Prüfung der aggregierten Console-Werte darf derselbe Lauf mit dieser
Bestätigung den bereinigten Nachweis und den readiness-Stand schreiben.
Testerlisten, E-Mail-Adressen, Konto-IDs, Roh-Screenshots und Zugangsdaten sind
ausdrücklich verboten.

### 8.1 Antrag auf Produktionszugang – vorbereitete Wahrheitsgrenze

Google fragt nach erfülltem Closed Test in drei Bereichen: Durchführung des
geschlossenen Tests, App und Produktionsreife. Der maschinenlesbare Entwurf
liegt in `store/google-play/production-access-application.json`.

Bereits belegbar vorbereitet sind nur:

- Zielgruppe: Erwachsene ab 18 Jahren, die physische Gegenstände lokal mieten
  oder anbieten möchten;
- Nutzen: lokale Suche, Inserate, Verfügbarkeit, Buchung, Chat sowie geführte
  Übergabe und Rückgabe in einem gemeinsamen Ablauf.

Erst nach dem realen Test dürfen ergänzt werden:

- die tatsächlich in der Console gewählte Schwierigkeit der Testergewinnung;
- reale, aggregierte Nutzung der Funktionen und Abweichungen vom erwarteten
  Produktivverhalten;
- tatsächliche Feedbackkanäle und zusammengefasste Feedbackthemen;
- die vom Eigentümer gewählte Console-Spanne der erwarteten Installationen im
  ersten Jahr;
- wirklich umgesetzte Änderungen aus dem Test;
- die belegte Entscheidung, warum der Kandidat produktionsreif ist.

Bis diese Antworten belegt sind, bleibt der Entwurf
`draft-before-closed-test`. Weder das Werkzeug noch der Entwurf senden einen
Antrag ab.

## 9. Harte Stop-Regeln

Kein „Send for review“, Rollout oder öffentliche Freigabe, solange mindestens
einer dieser Punkte offen ist:

- Identitäts-, Geräte- oder Telefonnummernprüfung;
- geschlossener Play-Test mit mindestens zwölf dauerhaft angemeldeten Testern
  über mindestens 14 aufeinanderfolgende Tage und anschließender
  Produktionszugangsprüfung;
- öffentliche Datenschutz-, Support- oder Löschseite;
- Anbieter-/Copyright- und Nutzerinhaltsregeln;
- finale Data-Safety-/Auftragsverarbeiter-Entscheidung;
- geschützte Review-Felder oder frischer Store-Login;
- Store-Screenshots und Privatdatenprüfung;
- Play-App-Signing-/Asset-Link-Nachweis;
- Store-Installation, Hotspot/TalkBack oder übrige B11-Matrix;
- Crashlytics-Zuordnung für exakt den hochgeladenen Kandidaten;
- technisches und produktseitiges Go.

## 10. Maschinengeprüfte Upload-Übergabe

Die Datei `store/google-play/internal-upload-handoff.json` sperrt Build
`2026081201` und bindet die nächste mögliche Play-Aktion an Ersatz-Build
`2026081202`. Dessen AAB-Hash, Upload-Zertifikat und privater Archivname müssen
nach dem Neubau erst eingetragen und erneut geprüft werden. Das Prüfwerkzeug
`tool/validate_google_play_internal_handoff.mjs` bricht ab, wenn sich Datei,
Hash, Kandidatenidentität oder Dateirechte unterscheiden.

Identitäts-, Geräte- und Telefonnummernprüfung sind abgeschlossen, der
App-Datensatz ist erstellt und die drei rechtlichen Erklärungen wurden mit
ausdrücklicher Zustimmung bestätigt. Play App Signing ist aktiv; sein
bereinigter Zertifikat-Fingerprint wurde zusätzlich zum Uploadzertifikat in
der lokalen `assetlinks.json`-Vorbereitung hinterlegt. `submissionAllowed`
bleibt dennoch `false`: Vor dem AAB-Upload wird das Artefakt unmittelbar erneut
geprüft, anschließend darf ausschließlich ein Entwurf im Track „Internal
testing“ entstehen. Alle öffentlichen, Review-, Open- und Closed-Aktionen
bleiben harte Stopps.

## 11. Quellen

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
