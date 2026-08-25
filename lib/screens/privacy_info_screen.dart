import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lendify/services/backend_repository.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/local_safety_privacy_service.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:share_plus/share_plus.dart';

class PrivacyInfoScreen extends StatefulWidget {
  const PrivacyInfoScreen({super.key});

  @override
  State<PrivacyInfoScreen> createState() => _PrivacyInfoScreenState();
}

class _PrivacyInfoScreenState extends State<PrivacyInfoScreen> {
  bool _exporting = false;

  Future<String?> _requestCurrentPassword() async {
    final passwordController = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Datenexport bestätigen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gib aus Sicherheitsgründen dein aktuelles Passwort ein. Der Export wird ausschließlich für dein angemeldetes Konto erstellt.',
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('privacy-data-export-password'),
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Aktuelles Passwort',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    Navigator.of(dialogContext).pop(value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              key: const ValueKey('privacy-data-export-confirm'),
              onPressed: () {
                final password = passwordController.text;
                if (password.isNotEmpty) {
                  Navigator.of(dialogContext).pop(password);
                }
              },
              child: const Text('Export erstellen'),
            ),
          ],
        ),
      );
    } finally {
      passwordController.dispose();
    }
  }

  Future<void> _exportData() async {
    if (_exporting) return;
    final currentPassword = await _requestCurrentPassword();
    if (!mounted || currentPassword == null) return;
    setState(() => _exporting = true);
    try {
      final export = Map<String, dynamic>.from(
        await BackendRepository.exportAccountData(
          currentPassword: currentPassword,
        ),
      );
      export['localDevice'] = <String, dynamic>{
        'savedItems': await DataService.exportSavedItemsForPrivacy(),
        'ownedListings': await DataService.exportOwnedListingsForPrivacy(),
        'operationalRecords':
            await DataService.exportOperationalRecordsForPrivacy(),
        'safetyPrivacy':
            await LocalSafetyPrivacyService.exportCurrentPrincipal(),
      };
      final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(export)),
      );
      const filename = 'shareittoo-data-export.json';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, name: filename, mimeType: 'application/json'),
          ],
          fileNameOverrides: const [filename],
          subject: 'Dein ShareItToo-Datenexport',
          downloadFallbackEnabled: true,
        ),
      );
      if (!mounted) return;
      AppPopup.success(
        context,
        title: 'Datenexport erstellt',
        message: 'Dein Datenexport wurde sicher erstellt.',
      );
    } catch (_) {
      if (!mounted) return;
      AppPopup.error(
        context,
        title: 'Datenexport fehlgeschlagen',
        message:
            'Der Datenexport konnte gerade nicht erstellt werden. Bitte versuche es erneut.',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final sections = <_PrivacySectionData>[
      const _PrivacySectionData(
        icon: Icons.public,
        title: 'Öffentliche Informationen',
        description:
            'Diese Informationen können andere Nutzer auf deinem Profil sehen:',
        bullets: [
          'Profilbild',
          'Vorname',
          'Stadt / Standort (keine genaue Adresse)',
          'Profilbeschreibung',
          'Sprachen',
          'Interessen',
          'Bewertungen und Rezensionen',
          'Anzahl Buchungen und Vermietungen',
          'Mitglied seit',
        ],
        note:
            'Diese Informationen helfen dabei, Vertrauen zwischen Mietern und Vermietern aufzubauen.',
      ),
      const _PrivacySectionData(
        icon: Icons.lock_outline,
        title: 'Private Informationen',
        description: 'Die folgenden Daten sind niemals öffentlich sichtbar:',
        bullets: [
          'E‑Mail-Adresse',
          'Telefonnummer',
          'vollständige Adresse',
          'genaue Standortkoordinaten',
          'Buchungsbeträge und Buchungsstatus',
        ],
        extraTitle: 'Diese Informationen werden ausschließlich verwendet für:',
        extraBullets: [
          'Buchungen',
          'Kommunikation während aktiver Buchungen',
          'Berechnung und Darstellung von Buchungsbeträgen',
          'Sicherheitsprozesse',
        ],
        note:
            'Der aktuelle Store-Kandidat erhebt weder Ausweisdokumente noch Karten- oder Bankdaten. ShareItToo gibt persönliche Daten nicht öffentlich weiter.',
      ),
      const _PrivacySectionData(
        icon: Icons.forum_outlined,
        title: 'Chat & Kommunikation',
        description:
            'Der Chat zwischen Mietern und Vermietern wird erst freigeschaltet, wenn eine Buchungsanfrage angenommen wurde.',
        bullets: [
          'persönliche Kontaktdaten zu früh ausgetauscht werden',
          'Kommunikation außerhalb der Plattform stattfindet',
        ],
        extraTitle:
            'Während einer aktiven Buchung dient der Chat dazu, Übergabe und Rückgabe zu koordinieren.',
      ),
      const _PrivacySectionData(
        icon: Icons.location_on_outlined,
        title: 'Adresse & Standort',
        description:
            'Deine vollständige Adresse und genaue Standortkoordinaten werden nicht öffentlich angezeigt.',
        extraTitle: 'Die Adresse wird ausschließlich verwendet für:',
        extraBullets: [
          'Übergaben',
          'Rückgaben',
        ],
        ruleTitle: 'Regel',
        ruleText:
            'Die genaue Adresse wird erst nach einer bestätigten Anfrage und nur nach der festgelegten Zeit- und Statusregel für Übergabe oder Rückgabe sichtbar.',
        note:
            'Andere Nutzer sehen öffentlich nur deine Stadt oder ungefähre Region. Einen präzisen aktuellen Gerätestandort fragt die App nur einmalig ab, wenn du „Standort prüfen“ selbst startest; eine dauerhafte Hintergrund- oder Live‑Ortung findet nicht statt.',
      ),
      const _PrivacySectionData(
        icon: Icons.photo_camera_outlined,
        title: 'Übergabe & Rückgabe',
        description:
            'Bei jeder Übergabe und Rückgabe ist eine Foto‑Dokumentation verpflichtend.',
        bullets: [
          'Übergabe: mindestens 4 Fotos durch den Vermieter',
          'Rückgabe: mindestens 4 Fotos durch den Mieter',
          'Bestätigung durch die Gegenpartei oder mindestens 1 eigenes Abweichungsfoto',
        ],
        note:
            'Die Fotos sind privat, nur für Buchungsbeteiligte und erforderliche Support-/Prüffälle zugänglich und werden nicht an eine KI übermittelt.',
      ),
      const _PrivacySectionData(
        icon: Icons.verified_user_outlined,
        title: 'Sicherheit & Verifizierung',
        description:
            'Um Vertrauen auf der Plattform zu stärken, können folgende Verifizierungen durchgeführt werden:',
        bullets: [
          'E‑Mail‑Bestätigung',
          'freiwillige Anmeldung über einen freigegebenen externen Anbieter',
          'Telefonnummer als optionale Kontaktangabe',
        ],
        extraTitle: 'Diese Maßnahmen helfen dabei:',
        extraBullets: [
          'Betrug zu verhindern',
          'sichere Buchungen zu gewährleisten',
          'Vertrauen zwischen Nutzern aufzubauen',
        ],
        note:
            'Der aktuelle Store-Kandidat bietet keine Ausweisprüfung und keinen Upload von Identitätsdokumenten an. Die SMS-Verifizierung der Telefonnummer bleibt bis zu einem gesondert geprüften Nachfolger deaktiviert.',
      ),
      const _PrivacySectionData(
        icon: Icons.storage_outlined,
        title: 'Speicherung & Nutzung von Daten',
        description: 'Deine Daten werden ausschließlich verwendet, um:',
        bullets: [
          'Buchungen abzuwickeln',
          'Kommunikation zwischen Nutzern zu ermöglichen',
          'deine lokal unter „Gemerkt“ gespeicherten Artikel und Merklisten bereitzustellen',
          'deine vorbereiteten Mietzeiträume und Projektcontainer im Mietkorb lokal oder nach Anmeldung kontogebunden bereitzustellen',
          'Buchungsbeträge und Gebühren transparent darzustellen',
          'die Sicherheit der Plattform zu gewährleisten',
          'die Nutzung der Plattform zu verbessern',
        ],
        note:
            'ShareItToo verkauft oder vermietet keine personenbezogenen Daten an Dritte.',
      ),
      const _PrivacySectionData(
        icon: Icons.hub_outlined,
        title: 'Technische Dienste',
        description:
            'Einige App-Funktionen werden durch technische Dienstleister unterstützt:',
        bullets: [
          'Google Maps Platform für Adressvorschläge sowie Standort- und Entfernungsfunktionen',
          'Firebase Cloud Messaging für Push‑Benachrichtigungen und technische Installationskennungen',
          'Firebase Crashlytics für Absturz-, Geräte-, Diagnose- und App-Sitzungsdaten',
          'Firebase Authentication für eine freiwillige Anmeldung mit einem von ShareItToo freigegebenen Anbieter und die dafür erforderlichen Identitätsdaten',
        ],
        note:
            'Push und freiwillige Crashdiagnose sind standardmäßig aus und werden nur über die getrennten Gerätedienst-Schalter aktiviert. Dort kannst du sie jederzeit wieder ausschalten. Bei Kontolöschung wird eine verknüpfte Firebase-Authentifizierungsidentität dauerhaft zur Anbieterlöschung vorgemerkt und bei Fehlern erneut angefragt. Firebase nennt für FCM-Installationsdaten sowie sonstige Authentifizierungsdaten nach der jeweiligen Löschanforderung bis zu 180 Tage und für Crashdaten mit zugehörigen Kennungen 90 Tage Aufbewahrung, bevor die Entfernung beginnt. Die Verarbeitung kann weltweit an Google-Standorten erfolgen. Werbe-IDs, Werbeprofile, Werbetracking und Analyse zu Werbezwecken sind nicht aktiviert.',
      ),
      const _PrivacySectionData(
        icon: Icons.file_download_outlined,
        title: 'Datenexport',
        description:
            'Du kannst jederzeit eine maschinenlesbare Kopie deiner gespeicherten Daten erstellen:',
        bullets: [
          'Kontodaten und Zustimmungen',
          'eigene Angebote, Buchungen und Kommunikation',
          'lokal auf diesem Gerät gespeicherte Merklisten und Artikelzuordnungen',
          'kontogebundene sowie noch nicht synchronisierte lokale Mietkorb- und Projektdaten',
          'Benachrichtigungen, Bewertungen und Zahlungsstatus',
        ],
        note:
            'Passwörter, Sitzungsschlüssel und interne Sicherheitsgeheimnisse sind niemals enthalten.',
        badgeText: 'Verfügbar',
        actionLabel: 'Meine Daten exportieren',
      ),
      const _PrivacySectionData(
        icon: Icons.person_remove_outlined,
        title: 'Konto löschen',
        description:
            'Du kannst dein Konto jederzeit in den Kontoeinstellungen löschen.',
        extraTitle: 'Beim Löschen eines Kontos werden:',
        extraBullets: [
          'persönliche Daten entfernt oder anonymisiert',
          'lokal auf diesem Gerät gespeicherte Daten unter „Gemerkt“ entfernt',
          'lokale und kontogebundene Mietkorb- und Projektcontainer entfernt',
          'verknüpfte Firebase-Anmeldeidentitäten zur Anbieterlöschung vorgemerkt und bei vorübergehenden Fehlern erneut angefragt',
          'Buchungsdaten gemäß gesetzlichen Anforderungen gespeichert',
        ],
        note: 'Dieser Prozess entspricht den geltenden Datenschutzrichtlinien.',
      ),
    ];

    return Stack(children: [
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(color: Colors.black.withValues(alpha: 0.35)),
        ),
      ),
      Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text('Datenschutz-Infos'),
          centerTitle: true,
          leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _HeaderCard(
              title: 'Datenschutz-Infos',
              description:
                  'Bei ShareItToo hat der Schutz deiner persönlichen Daten höchste Priorität.\nHier erfährst du, welche Informationen sichtbar sind, welche privat bleiben und wie deine Daten auf der Plattform verwendet werden.',
            ),
            const SizedBox(height: 14),
            ...List.generate(
              sections.length,
              (i) => _AnimatedSection(
                index: i,
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: i == sections.length - 1 ? 0 : 12),
                  child: _PrivacyInfoCard(
                    data: sections[i],
                    onAction:
                        sections[i].actionLabel == null ? null : _exportData,
                    actionBusy: sections[i].actionLabel != null && _exporting,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline,
                    color: BrandColors.primary.withValues(alpha: 0.95)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Wichtig: Diese Seite erklärt die Datenschutz‑Logik innerhalb der ShareItToo‑App in verständlicher Form. Die finale rechtliche Datenschutzerklärung und die Einordnung der technischen Empfänger müssen vor einer Store-Veröffentlichung noch geprüft und freigegeben werden.',
                    style: textTheme.bodySmall?.copyWith(
                        color: onSurface.withValues(alpha: 0.85), height: 1.5),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String description;
  const _HeaderCard({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BrandColors.primary.withValues(alpha: 0.18),
            Colors.black.withValues(alpha: 0.18),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(description,
            style: t.bodyMedium?.copyWith(
                color: onSurface.withValues(alpha: 0.88), height: 1.55)),
      ]),
    );
  }
}

class _AnimatedSection extends StatelessWidget {
  final int index;
  final Widget child;
  const _AnimatedSection({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: 45 * index);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, v, c) {
        final eased = Curves.easeOut.transform(v);
        return FutureBuilder<void>(
          future: Future<void>.delayed(delay),
          builder: (context, snap) {
            final visible = snap.connectionState == ConnectionState.done;
            final a = visible ? eased : 0.0;
            return Opacity(
              opacity: a,
              child: Transform.translate(
                  offset: Offset(0, (1 - a) * 10), child: c),
            );
          },
        );
      },
    );
  }
}

class _PrivacySectionData {
  final IconData icon;
  final String title;
  final String description;
  final List<String>? bullets;
  final String? extraTitle;
  final List<String>? extraBullets;
  final String? ruleTitle;
  final String? ruleText;
  final String? note;
  final String? badgeText;
  final String? actionLabel;

  const _PrivacySectionData({
    required this.icon,
    required this.title,
    required this.description,
    this.bullets,
    this.extraTitle,
    this.extraBullets,
    this.ruleTitle,
    this.ruleText,
    this.note,
    this.badgeText,
    this.actionLabel,
  });
}

class _PrivacyInfoCard extends StatelessWidget {
  final _PrivacySectionData data;
  final VoidCallback? onAction;
  final bool actionBusy;
  const _PrivacyInfoCard({
    required this.data,
    this.onAction,
    this.actionBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  BrandColors.primary.withValues(alpha: 0.30),
                  BrandColors.primary.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Icon(data.icon, color: BrandColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(data.title,
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700))),
                if (data.badgeText != null) _Badge(text: data.badgeText!),
              ]),
              const SizedBox(height: 6),
              Text(data.description,
                  style: t.bodyMedium?.copyWith(
                      color: onSurface.withValues(alpha: 0.88), height: 1.55)),
            ]),
          ),
        ]),
        if (data.bullets != null && data.bullets!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _BulletList(items: data.bullets!),
        ],
        if (data.actionLabel != null) ...[
          const SizedBox(height: 14),
          Semantics(
            key: const ValueKey('privacy-data-export-button'),
            button: true,
            enabled: !actionBusy,
            label: actionBusy ? 'Datenexport wird erstellt' : data.actionLabel,
            child: FilledButton.icon(
              onPressed: actionBusy ? null : onAction,
              icon: actionBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(
                  actionBusy ? 'Export wird erstellt …' : data.actionLabel!),
            ),
          ),
        ],
        if (data.extraTitle != null) ...[
          const SizedBox(height: 12),
          Text(data.extraTitle!,
              style: t.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onSurface.withValues(alpha: 0.92))),
        ],
        if (data.extraBullets != null && data.extraBullets!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _BulletList(items: data.extraBullets!),
        ],
        if (data.ruleTitle != null && data.ruleText != null) ...[
          const SizedBox(height: 12),
          _RuleCard(title: data.ruleTitle!, text: data.ruleText!),
        ],
        if (data.note != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lightbulb_outline,
                  color: BrandColors.logoAccent.withValues(alpha: 0.95),
                  size: 18),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(data.note!,
                      style: t.bodySmall?.copyWith(
                          color: onSurface.withValues(alpha: 0.86),
                          height: 1.55))),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: BrandColors.primary.withValues(alpha: 0.14),
        border: Border.all(color: BrandColors.primary.withValues(alpha: 0.35)),
      ),
      child: Text(text,
          style: t.labelSmall?.copyWith(
              color: BrandColors.primary, fontWeight: FontWeight.w800)),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final String title;
  final String text;
  const _RuleCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BrandColors.logoAccent.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: t.labelSmall?.copyWith(
                letterSpacing: 0.2, color: onSurface.withValues(alpha: 0.9))),
        const SizedBox(height: 6),
        Text(text,
            style: t.bodySmall?.copyWith(
                color: onSurface.withValues(alpha: 0.9), height: 1.55)),
      ]),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  const _BulletList({required this.items});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items
          .map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: onSurface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(s,
                        style: t.bodyMedium?.copyWith(
                            color: onSurface.withValues(alpha: 0.88),
                            height: 1.55))),
              ]),
            ),
          )
          .toList(),
    );
  }
}
