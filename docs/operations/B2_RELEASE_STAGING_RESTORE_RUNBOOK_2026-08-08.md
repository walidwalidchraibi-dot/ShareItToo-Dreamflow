# B2 Umgebungen, Releaseweg und Betrieb

Stand: 8. August 2026

## Ziel und Gate

Jede ShareItToo-Version muss aus einem sauberen Commit reproduzierbar gebaut,
in einer isolierten Staging-Umgebung geprüft, eindeutig identifiziert,
kontrolliert ausgerollt, beobachtet und auf ein vorheriges Image
zurückgerollt werden können. Backups gelten erst als belastbar, wenn eine
isolierte Wiederherstellung nachweislich erfolgreich war.

B2 ist erst abgeschlossen, wenn alle Nachweise in der Abnahmetabelle auf
`bestanden` stehen. Repository-Artefakte allein beweisen noch kein erfolgreiches
Staging, Restore oder Rollback auf dem VPS.

## Trennung der Umgebungen

| Bereich | Lokal/CI | Staging | Produktion |
|---|---|---|---|
| Compose | Entwickler/CI | `backend/compose.staging.yml` | `backend/compose.prod.yml` |
| Datenbank | Testfixture/temporär | `shareittoo_staging` | `shareittoo` |
| Secrets | lokale Testwerte | `.env.staging`, nie in Git | `.env`, nie in Git |
| Uploads | lokal/temporär | `shareittoo_staging_uploads` | `shareittoo_uploads` |
| Mail | memory/disabled | memory, keine echte Zustellung | Google Workspace SMTP |
| API | Testprozess | zunächst nur `127.0.0.1:18080` | `https://shareittoo.com/api` |

Staging darf niemals Produktionsdaten, Produktions-JWT-Secrets,
Produktionspasswörter oder echte Zahlungsmodi verwenden. Ein späterer
öffentlicher Staging-Hostname wird nur mit HTTPS und Zugangsschutz aktiviert.

## Unveränderliche Release-Kennung

Der Release-Build erhält:

- per Digest festgeschriebene Node- und PostgreSQL-Basisimages;
- ein Image-Tag mit vollständigem 40-stelligem Git-Commit;
- OCI-Labels für Version, Commit, Commit-Zeitpunkt und Quellrepository;
- dieselben Werte im Container als Laufzeitumgebung;
- eine maschinenlesbare Ausgabe unter `/version` und allen Health-Endpunkten.

Dependabot prüft wöchentlich GitHub-Actions, Docker-Basisimages und
Backend-Abhängigkeiten. Aktualisierungen durchlaufen denselben CI- und
Reviewweg; Digests werden nicht unkontrolliert auf schwebende Tags gelockert.

Ein Rollout wird abgebrochen, wenn das Image-Label nicht mit dem angeforderten
Commit übereinstimmt oder der laufende `/version`-Endpunkt nach dem Rollout
nicht exakt denselben Commit meldet.

## CI-Pflichtgate

Der GitHub-Workflow `regression` enthält zwei unabhängige Jobs:

1. Backend: gesperrte pnpm-Abhängigkeiten, alle Node-Tests, Syntaxprüfung aller
   Quell- und Betriebsskripte und Build eines commit-markierten API-Images.
2. Flutter: Analyse gegen den dokumentierten Altlasten-Baselinewert, alle
   Flutter-Tests, Web-Debug-Build und Android-Debug-Build.

Ein fehlerhafter Job verhindert einen grünen Gesamtstatus. Der Branchschutz
für `main` und die verbindliche PR-Freigabe bleiben als P1-Gate offen, bis sie
auf GitHub aktiviert wurden.

## Standardablauf Staging

1. Sauberen, CI-grünen Commit auswählen.
2. Mit `backend/ops/build_release_image.sh` das exakt bezeichnete Image bauen.
3. Separate `.env.staging` aus `.env.staging.example` mit unabhängigen
   Geheimnissen anlegen.
4. `backend/ops/deploy_release.sh staging <FULL_COMMIT>` ausführen.
5. `/version`, `/health/live`, `/health/ready` und `/health` prüfen.
6. Registrierung, Anmeldung, Verifizierung im Memory-Mailmodus, Upload,
   Inserat, Buchungsanfrage und Nachrichten-Smoke-Test ausführen.
7. Containerzustand, Logs, CPU/RAM, Datenbank und Speicher prüfen.
8. Den vorherigen Commit erneut mit demselben Skript ausrollen und Version,
   Health und Kern-Smoke-Test wiederholen.
9. Den freigegebenen Commit erneut ausrollen. Beide Wechsel werden mit den
   JSON-Releasebelegen dokumentiert.

## Standardablauf Produktion

1. Freigegebenen Staging-Commit und grünen CI-Lauf festhalten.
2. Aktuellen Produktions-Commit über `/api/version` und vorheriges Image
   dokumentieren.
3. Hostinger-Snapshotzustand sowie lokalen täglichen Backupzustand prüfen.
4. `CONFIRM_PRODUCTION_DEPLOY` auf den exakten neuen Commit setzen und den
   Produktionsrollout starten. Das Skript erstellt zuerst ein neues Backup.
5. Auf Container-Health warten; danach `/api/version`, `/api/health/ready`,
   `/api/health`, Website und einen nicht mutierenden API-Smoke-Test prüfen.
6. Logs und Ressourcen unmittelbar sowie nach 5, 15 und 30 Minuten prüfen.
7. Bei einem Gate-Fehler keine weiteren Migrationen oder Nutzeraktionen
   auslösen, sondern auf den vorherigen Commit zurückrollen.
8. Nach bestandenem Erstrollout und Restore-Nachweis die Health-Gates
   `REQUIRE_RELEASE_IDENTITY=true` und `REQUIRE_RECENT_RESTORE_CHECK=true`
   aktivieren.

## Backup- und Restore-Nachweis

`backend/ops/verify_restore.sh` arbeitet ausschließlich mit einer temporären
PostgreSQL-Instanz, einem temporären Docker-Volume und einem per `mktemp`
erzeugten Uploadverzeichnis. Es prüft Prüfsummen, Dump-Struktur, tatsächliche
Wiederherstellung, vorhandene Tabellen und die Entpackbarkeit der Uploads.
Alle temporären Ressourcen werden auch bei Fehlern entfernt. Der
Produktionscontainer und sein Datenvolume werden nicht angesprochen.

Der wöchentliche Timer läuft sonntags um 03:30 UTC mit zufälliger Verzögerung.
Vor seiner Aktivierung werden Service und Skript einmal manuell erfolgreich
ausgeführt und das erzeugte JSON-Protokoll gesichert.

## Rollback-Regel

- Es wird ausschließlich auf ein bereits gebautes, commit-markiertes Image
  zurückgerollt.
- Datenbankmigrationen benötigen vorab eine eigene Vorwärts- und
  Rückwärtsstrategie. Ohne sichere Rückwärtsmigration wird die Anwendung
  kompatibel vorwärts repariert und das Backup nur nach Incident-Entscheidung
  wiederhergestellt.
- Ein Restore überschreibt niemals spontan die Produktionsdatenbank. Zuerst
  erfolgt ein isolierter Restore und Datenabgleich.
- Nach Rollback müssen Version, Readiness, Website und Kern-Smoke-Test erneut
  bestehen.

## Abnahmenachweise

| Nachweis | Aktueller Stand | Ergebnis |
|---|---|---|
| Release-Metadaten im Code und Image | implementiert, lokale/CI-Prüfung ausstehend | offen |
| Backend- und Flutter-CI | Workflow erweitert, GitHub-Lauf ausstehend | offen |
| Staging aus sauberem Commit | Compose und Skripte vorbereitet, VPS-Rollout ausstehend | offen |
| Staging Health und Smoke-Test | ausstehend | offen |
| Rollback-Probe Staging | ausstehend | offen |
| Täglicher Backup-Timer aktiv | Dateien vorhanden, VPS-Zustand direkt zu prüfen | offen |
| Isolierter Restore erfolgreich | Skript/Timer vorbereitet, VPS-Lauf ausstehend | offen |
| Produktions-Version meldet Commit | Code vorbereitet, noch nicht ausgerollt | offen |
| Kritische Alarmadresse | Walids Entscheidung ausstehend | offen |

## Maximus-Checkpoint

Nach vollständigem B2-Gate erhält Maximus Ergebnis, Commits/PR/Build,
CI-Nachweise, Staging-/Restore-/Rollback-Protokolle, Produktionsstatus,
Risiken, Rückfallweg und den Eintritt in B3. Keine Secrets oder internen
Zugangsdaten werden übertragen.
