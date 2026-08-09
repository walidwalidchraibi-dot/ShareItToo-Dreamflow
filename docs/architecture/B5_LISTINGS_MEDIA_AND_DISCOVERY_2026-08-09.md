# B5 — Inserate, Medien und Auffindbarkeit

Stand: 9. August 2026

Branch: `codex/master-workflow-20260808`

Status: Implementierung lokal vollständig geprüft; PostgreSQL-CI und isolierte
Staging-Abnahme stehen vor der technischen Freigabe noch aus.

## Ergebnisziel

B5 ersetzt den früheren Demo-Katalog durch echte, serverseitig geprüfte
Inserate. Anbieter können ein vollständiges Angebot anlegen, bearbeiten,
pausieren und beenden. Mieter sehen ausschließlich aktive Angebote mit einem
serverseitig verarbeiteten Bild und können nach Text, Kategorie, Zustand,
Preis und Entfernung suchen.

## Verbindliches Inserat

Ein aktives Inserat benötigt:

- Titel und aussagekräftige Beschreibung;
- Kategorie, optional Unterkategorie und Suchbegriffe;
- Zustand aus einer kontrollierten Werteliste;
- positiven Tagespreis, Währung und optional eine Kaution;
- genauen internen Standort mit Stadt, Land und Koordinaten;
- Mindest- und Höchstdauer;
- Übergaberadius und das einheitliche Schutzmodell;
- mindestens ein geprüftes, dem Anbieter gehörendes Inseratbild;
- Status `active`.

Entwürfe und pausierte Inserate dürfen ohne Bild gespeichert werden, sind aber
weder öffentlich sichtbar noch buchbar. `ended` ist der endgültige
Soft-Delete-Status und bewahrt nur die für bestehende Vorgänge benötigte
Referenz.

## Datenmodell und Rollback-Kompatibilität

Migration `004_b5_listing_catalog.up.sql` ergänzt normalisierte Katalogfelder,
Suchindizes, Bildmetadaten und `catalog_version`.

- `catalog_version = 1` kennzeichnet ein nach B5 vollständig geprüftes
  Inserat. Nur diese Version darf veröffentlicht oder gebucht werden.
- `catalog_version = 0` ist eine bewusst isolierte Kompatibilitätsspur. Sie
  erlaubt bei einer kurzfristigen Rückrollung weiterhin Schreibvorgänge der
  vorherigen B4-App, ohne die neuen Regeln zu umgehen.
- Eine B5-Schreibrevision kennzeichnet bewusst validierte Änderungen. Ändert
  die B4-App während einer Rückrollung einen bestehenden B5-Datensatz ohne
  diese Revision, setzt ein Datenbank-Trigger ihn automatisch auf Version 0.
- Nach dem erneuten Vorwärtsrollout bleiben während eines Rollbacks angelegte
  Version-0-Datensätze unsichtbar und unbuchbar. Eine vollständige Bearbeitung
  über B5 validiert und hebt sie auf Version 1.
- Frühere aktive Datensätze ohne serverseitig verarbeitetes Bild werden bei
  der Migration automatisch pausiert.
- Die ehemaligen fünf Server-Demoangebote werden beendet und nie in den
  öffentlichen Katalog übernommen.

Die Migration ist additiv. Eine einmal ausgeführte Datei darf nicht verändert
werden; spätere Korrekturen müssen als neue Vorwärtsmigration erfolgen.

## Bildverarbeitung und Zugriffsschutz

Der Upload-Endpunkt akzeptiert nur dekodierbare JPEG-, PNG- und WebP-Dateien
bis 8 MiB. Für Inseratbilder gelten zusätzlich Mindestmaße und eine Obergrenze
von 40 Megapixeln beziehungsweise 12.000 Pixeln je Seite.

Jedes akzeptierte Bild wird vollständig neu dekodiert und erzeugt:

- ein automatisch gedrehtes, metadatenfreies WebP bis 2.048 Pixel;
- ein quadratisches 480-Pixel-Vorschaubild;
- gespeicherte Abmessungen, Dateigrößen und SHA-256-Prüfsumme;
- den Prüfstatus `passed` erst nach erfolgreicher Verarbeitung.

Die Neucodierung entfernt eingebettete Metadaten und nicht benötigte
Dateiinhalte. Teilweise geschriebene Dateien werden bei jedem Datenbank- oder
Dateifehler wieder entfernt.

Ein ungebundenes Inseratbild ist privat und nur für seinen Eigentümer lesbar.
Nach Veröffentlichung sind Original und Vorschau öffentlich cachebar. Sobald
das Inserat pausiert oder beendet wird, verlangt derselbe undurchsichtige
Medienpfad wieder eine aktive Sitzung des Eigentümers. Fremde Nutzer erhalten
keinen Zugriff. Die zentrale App-Bildkomponente sendet für verwaltete
Backend-Bilder bei einer aktiven Sitzung automatisch den kurzlebigen
Access-Token, sodass Eigentümer ihre privaten Entwürfe weiterhin sehen.

## Eigentum und Lebenszyklus

- Inserat-ID und Eigentümer werden serverseitig gesetzt; Payload-Felder können
  weder Eigentum noch Identität überschreiben.
- Nur der Eigentümer darf ein Inserat aktualisieren, pausieren, reaktivieren
  oder beenden.
- Ein Bild muss demselben Eigentümer gehören, erfolgreich verarbeitet sein
  und darf nicht an ein anderes Inserat gebunden sein.
- Reaktivierung prüft erneut, ob mindestens ein freigegebenes Bild vorhanden
  ist.
- Öffentliche Suche und neue Buchungsanfragen verlangen gleichzeitig
  `catalog_version = 1`, `status = active` und `is_active = true`.
- Ein pausiertes oder beendetes Inserat kann keine neue Buchung erhalten.

## Suche und Datenschutz

Die öffentliche Katalogabfrage unterstützt:

- Textsuche über Titel, Beschreibung, Kategorie, Unterkategorie, Stadt und
  Land;
- mehrere Kategorien und Zustände;
- minimalen und maximalen Preis;
- Umkreisfilter mit serverseitig berechneter Distanz;
- Sortierung nach Neuheit, Preis auf- oder absteigend und Entfernung;
- begrenzte, paginierte Antworten.

Exakte Adresse und genauer Geohash verlassen das Backend nicht. Öffentlich
erscheinen nur Stadt/Land, auf ungefähr einen Kilometer gerundete
Koordinaten und eine entsprechend gerundete Entfernung. Bild-URLs werden
gegen tatsächlich gebundene, freigegebene Upload-Datensätze gefiltert.

## App-Verhalten

- Explore, Such-Overlay und Ergebnislisten laden den echten öffentlichen
  Katalog und reichen Filter an den Server weiter.
- Lade-, Leer- und Fehlerzustände sind getrennt sichtbar; ein Backendfehler
  fällt im produktiven Modus nicht auf Demoangebote zurück.
- Veröffentlichen ist ohne echtes Bild nicht mehr möglich.
- Inseratdetails kennzeichnen den Standort ausdrücklich als ungefähr und
  zeigen das einheitliche Schutzmodell.
- Externe Zufallsbilder und automatisch erzeugte Demo-Buchungen wurden aus
  normalen Laufzeitpfaden entfernt.
- Lokale QA-Fixtures existieren nur hinter dem expliziten Debug-Parameter
  `qa=1`; Release-Builds können ihn nicht aktivieren.

## Automatische Nachweise

Lokaler Endstand vor CI:

- Backend: 35 bestandene Tests, ein ausschließlich mangels lokaler
  PostgreSQL-Installation übersprungener Integrationstest, anschließend
  vollständige Syntaxprüfung;
- App: 154 bestandene Flutter-Tests;
- Analyse: 710 bestehende Hinweise, keine Fehler und damit Verbesserung der
  akzeptierten Altlasten-Baseline von 729;
- erfolgreicher Web-Debug-Build;
- erfolgreiche Android-Debug-APK;
- Quelltextprüfung ohne verbliebene Zufallsbilder oder Demoangebote in den
  Katalog- und Buchungs-Laufzeitpfaden.

Der PostgreSQL-16-Integrationstest in CI prüft zusätzlich:

- vier Migrationen einschließlich idempotenter Wiederholung und Prüfsummen;
- die isolierte B4-Rollbackspur `catalog_version = 0`;
- echtes JPEG-Upload, WebP-Neucodierung, Thumbnail, Hash und Metadaten;
- privaten Zugriff vor Bindung sowie öffentlichen Zugriff nur während des
  aktiven Inseratstatus;
- Erstellen, Suchen, Filtern, Bearbeiten, Pausieren, Reaktivieren und Beenden;
- Ablehnung fremder Änderungen und fremder Bildbindung;
- Nichtbuchbarkeit pausierter Angebote und Standort-Redaktion.

## Noch ausstehende Freigaben

| Gate | Erforderlicher Nachweis | Status |
|---|---|---|
| Lokale Backend-Prüfung | Tests und Syntax | bestanden |
| App-Regression | 154 Tests, Analyse, Web und Android | bestanden |
| PostgreSQL-Migration | PostgreSQL 16 und kompletter Katalog-Lebenszyklus | ausstehend: CI |
| Unveränderliches Image | Commit-markiertes Container-Image | ausstehend: CI |
| Isoliertes Staging | Backup, Migration, reale Upload-/CRUD-/Suchproben | ausstehend |
| Rückrollung | B4-App auf additivem B5-Schema plus Vorwärtswiederherstellung | ausstehend |
| Restore | Pre-B5-Datenbank und Uploads getrennt wiederherstellen | ausstehend |
| Pilotdaten | realer Artikel, Kategorie, Ort, Preis und Übergaberegel | Entscheidung mit Walid nach technischer Freigabe |

B5 gilt erst nach grüner CI sowie erfolgreicher Staging-, Rückroll- und
Restore-Probe als technisch bestanden. Produktion wird dabei nicht verändert.
