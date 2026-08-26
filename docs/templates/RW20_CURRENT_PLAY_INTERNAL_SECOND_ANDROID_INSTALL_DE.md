# RW20 aktueller Play-Internal-Test auf dem zweiten Android-Handy

Status: **VORBEREITUNG — KEINE EINLADUNG — KEIN PLAY-UPLOAD**

Diese Anleitung gilt nur fuer den spaeter owner-freigegebenen Kandidaten
`1.0.0 (2026082601)` auf `com.shareittoo.app`. Vor der Installation muessen
der private BUILD_READY-Handover, der dort genannte Quell-Commit und der
AAB-SHA-256 mit dem spaeteren Play-Release uebereinstimmen.

## Google-Konto und privater Opt-in

1. Walid bestaetigt ausserhalb von Git und Chat das Google-Konto, das auf dem
   zweiten Android-Handy im Play Store aktiv ist. Die Adresse wird nicht in
   Repository, Evidence oder Screenshots geschrieben.
2. Das Konto wird erst nach `PLAY_UPLOAD_APPROVED` und dem separaten
   Internal-Release-Gate durch den Owner in die private Testerliste aufgenommen.
3. Der private Opt-in-Link bleibt ausserhalb von Git und oeffentlichen Kanaelen.
4. Link mit genau diesem Google-Konto oeffnen, dem internen Test beitreten und
   nur die Play-Store-Seite fuer `com.shareittoo.app` verwenden.
5. Vor Start in den App-Informationen beziehungsweise in der owner-gelieferten
   Buildanzeige `1.0.0 (2026082601)` bestaetigen. Eine andere Buildnummer ist
   ein Stop.

## Clean Install oder Update

- Clean Install: nur wenn `com.shareittoo.app` auf dem zweiten Handy noch nie
  installiert war. Installation ausschliesslich aus Google Play.
- Update: wenn der alte interne Build `2026081509` installiert ist, nicht
  deinstallieren und keine App-Daten loeschen. Das Play-Update muss Daten,
  Paket-ID und Signaturbeziehung erhalten.
- Kein Sideload, kein APK aus Downloads und kein Downgrade fuer diesen Test.

## Sichere Testdaten

- Nur owner-bereitgestellte synthetische Staging-Konten und Testobjekte nutzen.
- Keine echten Namen, Adressen, Telefonnummern, Zahlungen, Vertraege, Ausweise,
  Gesichter oder privaten Fotos eingeben.
- Kein neues oeffentliches Konto anlegen und keine reale Vermietung starten.
- Ergebnisse nur mit einem anonymen Run-Code melden; Google-Adresse und
  Opt-in-Link bleiben privat.

## Sofort stoppen

Stop bei falscher Version, anderer Paket-ID, unerwartetem oeffentlichen Track,
Produktionsdaten, realer Zahlung, externer Provideraktivitaet, Daten eines
anderen Kontos, Signatur-/Installationsfehler oder nicht erklaerbarer
Play-Warnung. Nicht deinstallieren oder Daten loeschen, solange die Ursache und
die benoetigte minimale Evidence nicht geklaert sind.
