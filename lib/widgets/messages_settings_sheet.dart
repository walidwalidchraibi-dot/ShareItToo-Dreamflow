import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:lendify/screens/blocked_users_screen.dart';
import 'package:lendify/screens/report_user_screen.dart';
import 'package:lendify/services/messages_settings_service.dart';

enum MessagesSettingsPresentation { sheet, page }

/// Reusable content for Nachrichten-Einstellungen.
///
/// - [sheet]: used inside a bottom sheet (renders its own close button)
/// - [page]: used inside a full screen (header/back handled by the screen)
class MessagesSettingsView extends StatefulWidget {
  final MessagesSettingsPresentation presentation;
  final VoidCallback? onCancel;
  final VoidCallback? onSaved;

  const MessagesSettingsView({super.key, required this.presentation, this.onCancel, this.onSaved});

  @override
  State<MessagesSettingsView> createState() => _MessagesSettingsViewState();
}

class _MessagesSettingsViewState extends State<MessagesSettingsView> {
  MessagesSettings? _settings;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await MessagesSettingsService.get();
      if (!mounted) return;
      setState(() => _settings = value);
    } catch (e) {
      debugPrint('MessagesSettingsView._load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final value = _settings;
    if (value == null) return;
    setState(() => _saving = true);
    try {
      await MessagesSettingsService.set(value);
      if (!mounted) return;
      widget.onSaved?.call();
      if (widget.presentation == MessagesSettingsPresentation.sheet) {
        Navigator.of(context).maybePop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickWhoCanWrite() async {
    final current = _settings?.whoCanWrite ?? MessagesSettings.defaults().whoCanWrite;
    final picked = await showModalBottomSheet<WhoCanWrite>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        return _SelectorSheet<WhoCanWrite>(
          title: 'Wer kann mir schreiben',
          value: current,
          items: const [WhoCanWrite.everyone, WhoCanWrite.acceptedRequestOnly],
          label: (v) => switch (v) {
            WhoCanWrite.everyone => 'Jeder',
            WhoCanWrite.acceptedRequestOnly => 'Nur nach angenommener Anfrage',
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _settings = (_settings ?? MessagesSettings.defaults()).copyWith(whoCanWrite: picked));
  }

  Future<void> _pickMediaAutoDownload() async {
    final current = _settings?.mediaAutoDownload ?? MessagesSettings.defaults().mediaAutoDownload;
    final picked = await showModalBottomSheet<MediaAutoDownload>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        return _SelectorSheet<MediaAutoDownload>(
          title: 'Medien automatisch herunterladen',
          value: current,
          items: const [MediaAutoDownload.wifi, MediaAutoDownload.always, MediaAutoDownload.never],
          label: (v) => switch (v) {
            MediaAutoDownload.wifi => 'WLAN',
            MediaAutoDownload.always => 'Immer',
            MediaAutoDownload.never => 'Nie',
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _settings = (_settings ?? MessagesSettings.defaults()).copyWith(mediaAutoDownload: picked));
  }

  Future<void> _pickPreferredLanguage() async {
    final current = _settings?.preferredLanguageCode ?? MessagesSettings.defaults().preferredLanguageCode;
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        return _SelectorSheet<String>(
          title: 'Bevorzugte Sprache',
          value: current,
          items: const ['auto', 'de', 'en'],
          label: (v) => switch (v) {
            'auto' => 'Automatisch',
            'de' => 'Deutsch',
            'en' => 'Englisch',
            _ => v,
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _settings = (_settings ?? MessagesSettings.defaults()).copyWith(preferredLanguageCode: picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _settings;

    final header = widget.presentation == MessagesSettingsPresentation.sheet
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
            child: Row(children: [
              Expanded(child: Text('Nachrichten-Einstellungen', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          )
        : const SizedBox(height: 10);

    final footer = SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _saving
                    ? null
                    : () {
                        if (widget.presentation == MessagesSettingsPresentation.sheet) {
                          Navigator.of(context).maybePop();
                        } else {
                          (widget.onCancel ?? () => Navigator.of(context).maybePop()).call();
                        }
                      },
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Abbrechen'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: (_saving || _loading) ? null : _save,
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Änderungen speichern'),
              ),
            ),
          ),
        ]),
      ),
    );

    return Column(children: [
      header,
      const Divider(height: 1, thickness: 1, color: Colors.white24),
      Expanded(
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _SettingsSection(
                    title: 'Benachrichtigungen',
                    child: Column(children: [
                      _SettingsSwitchRow(
                        icon: Icons.notifications_off,
                        title: 'Alle stummschalten',
                        subtitle: 'Deaktiviert alle Chat-Benachrichtigungen in der App',
                        value: s?.muteAll ?? false,
                        onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(muteAll: v)),
                      ),
                      const SizedBox(height: 10),
                      _SettingsSwitchRow(
                        icon: Icons.done_all,
                        title: 'Lesebestätigungen senden',
                        subtitle: 'Andere sehen, ob du eine Nachricht gelesen hast',
                        value: s?.sendReadReceipts ?? true,
                        onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(sendReadReceipts: v)),
                      ),
                      const SizedBox(height: 10),
                      _SettingsSwitchRow(
                        icon: Icons.visibility,
                        title: 'Chat-Vorschau anzeigen',
                        subtitle: 'Letzte Nachricht in der Chat-Liste anzeigen',
                        value: s?.showChatPreview ?? true,
                        onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(showChatPreview: v)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: 'Privatsphäre & Sicherheit',
                    emphasized: true,
                    child: Column(children: [
                      _SettingsSelectorRow(
                        icon: Icons.lock,
                        title: 'Wer kann mir schreiben',
                        valueText: (s?.whoCanWrite ?? WhoCanWrite.acceptedRequestOnly) == WhoCanWrite.acceptedRequestOnly ? 'Nur nach angenommener Anfrage' : 'Jeder',
                        emphasizedValue: (s?.whoCanWrite ?? WhoCanWrite.acceptedRequestOnly) == WhoCanWrite.acceptedRequestOnly,
                        onTap: _pickWhoCanWrite,
                      ),
                      const SizedBox(height: 10),
                      _SettingsActionRow(
                        icon: Icons.block,
                        title: 'Blockierte Nutzer verwalten',
                        subtitle: 'Du bestimmst, wer dir schreiben kann',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
                      ),
                      const SizedBox(height: 10),
                      _SettingsActionRow(
                        icon: Icons.report,
                        title: 'Nutzer melden',
                        subtitle: 'Hilf uns, die Community sicher zu halten',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportUserScreen())),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: 'Übergaben & Sicherheit',
                    emphasized: true,
                    highlightTint: theme.colorScheme.primary.withValues(alpha: 0.10),
                    child: Column(children: [
                      _SettingsSwitchRow(
                        icon: Icons.photo_library,
                        title: 'Übergabefotos automatisch speichern',
                        subtitle: 'Sichert Belege schneller in deiner Galerie',
                        value: s?.autoSaveHandoverPhotos ?? true,
                        onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(autoSaveHandoverPhotos: v)),
                      ),
                      const SizedBox(height: 10),
                      _SettingsSwitchRow(
                        icon: Icons.notifications_active,
                        title: 'Erinnerungen für Übergabe & Rückgabe',
                        subtitle: 'Hilft dir, Termine nicht zu verpassen',
                        value: s?.handoverReminders ?? true,
                        onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(handoverReminders: v)),
                      ),
                      const SizedBox(height: 10),
                      const _SettingsInfoRow(icon: Icons.info_outline, title: 'Mind. 4 Fotos erforderlich', subtitle: 'Für eine saubere Dokumentation bei Übergabe & Rückgabe'),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: 'Chat-Verhalten',
                    child: Column(children: [
                      _SettingsSwitchRow(
                        icon: Icons.archive_outlined,
                        title: 'Chats automatisch archivieren',
                        subtitle: 'Ordnet abgeschlossene Chats automatisch ein',
                        value: s?.autoArchiveChats ?? false,
                        onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(autoArchiveChats: v)),
                      ),
                      const SizedBox(height: 10),
                      _SettingsSwitchRow(
                        icon: Icons.visibility_off,
                        title: 'Chats nach Abschluss ausblenden',
                        subtitle: 'Reduziert die Liste auf aktive Vorgänge',
                        value: s?.hideCompletedChats ?? false,
                        onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(hideCompletedChats: v)),
                      ),
                      const SizedBox(height: 10),
                      _SettingsSelectorRow(
                        icon: Icons.download_for_offline,
                        title: 'Medien automatisch herunterladen',
                        valueText: _mediaLabel(s?.mediaAutoDownload ?? MediaAutoDownload.wifi),
                        onTap: _pickMediaAutoDownload,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: 'Sprache & Kommunikation',
                    child: Column(children: [
                      _SettingsSwitchRow(
                        icon: Icons.translate,
                        title: 'Chat automatisch übersetzen',
                        subtitle: 'Hilft bei internationalen Übergaben',
                        value: s?.autoTranslateChat ?? false,
                        onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(autoTranslateChat: v)),
                      ),
                      const SizedBox(height: 10),
                      _SettingsSelectorRow(
                        icon: Icons.language,
                        title: 'Bevorzugte Sprache',
                        valueText: _languageLabel(s?.preferredLanguageCode ?? 'auto'),
                        onTap: _pickPreferredLanguage,
                      ),
                    ]),
                  ),
                ]),
              ),
      ),
      const Divider(height: 1, thickness: 1, color: Colors.white24),
      footer,
    ]);
  }

  String _mediaLabel(MediaAutoDownload v) => switch (v) {
    MediaAutoDownload.wifi => 'WLAN',
    MediaAutoDownload.always => 'Immer',
    MediaAutoDownload.never => 'Nie',
  };

  String _languageLabel(String code) => switch (code) {
    'auto' => 'Automatisch',
    'de' => 'Deutsch',
    'en' => 'Englisch',
    _ => code,
  };
}

/// Premium bottom-sheet wrapper for Nachrichten-Einstellungen (local-only MVP).
class MessagesSettingsSheet extends StatelessWidget {
  const MessagesSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) => const MessagesSettingsView(presentation: MessagesSettingsPresentation.sheet);
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool emphasized;
  final Color? highlightTint;
  const _SettingsSection({required this.title, required this.child, this.emphasized = false, this.highlightTint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = highlightTint ?? Colors.white.withValues(alpha: emphasized ? 0.08 : 0.06);
    return Container(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: emphasized ? 0.16 : 0.10)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
          if (emphasized) Icon(Icons.shield_moon, color: theme.colorScheme.primary.withValues(alpha: 0.95), size: 18),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsSwitchRow({required this.icon, required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
            child: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.92), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35)),
              ],
            ]),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: theme.colorScheme.primary,
            inactiveThumbColor: Colors.white.withValues(alpha: 0.65),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
          ),
        ]),
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _SettingsActionRow({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
              child: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.92), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35)),
                ],
              ]),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ]),
        ),
      ),
    );
  }
}

class _SettingsSelectorRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String valueText;
  final bool emphasizedValue;
  final VoidCallback onTap;
  const _SettingsSelectorRow({required this.icon, required this.title, required this.valueText, this.emphasizedValue = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
              child: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.92), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800))),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                valueText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: emphasizedValue ? theme.colorScheme.primary : Colors.white70, fontWeight: emphasizedValue ? FontWeight.w900 : FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, color: Colors.white70),
          ]),
        ),
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SettingsInfoRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
          child: Icon(icon, color: theme.colorScheme.primary.withValues(alpha: 0.95), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

class _SelectorSheet<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<T> items;
  final String Function(T value) label;
  const _SelectorSheet({required this.title, required this.value, required this.items, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(children: [
                Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),
            const Divider(height: 1, thickness: 1, color: Colors.white24),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = item == value;
                  return Material(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).maybePop(item),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selected ? theme.colorScheme.primary.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: Row(children: [
                          Expanded(child: Text(label(item), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800))),
                          const SizedBox(width: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected ? theme.colorScheme.primary : Colors.transparent,
                              border: Border.all(color: selected ? theme.colorScheme.primary : Colors.white.withValues(alpha: 0.28), width: 2),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
