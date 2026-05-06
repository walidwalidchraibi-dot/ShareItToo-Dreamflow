import 'dart:ui';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _settings;
    final muteAll = s?.muteAll ?? false;

    final header = widget.presentation == MessagesSettingsPresentation.sheet
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
            child: Row(children: [
              Expanded(child: Text('Nachrichten-Einstellungen', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          )
        : const SizedBox(height: 10);

    return Column(children: [
      header,
      const Divider(height: 1, thickness: 1, color: Colors.white24),
      Expanded(
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            : Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 160),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      // 1. Benachrichtigungen
                      _SettingsSection(
                        title: 'Benachrichtigungen',
                        icon: Icons.notifications_outlined,
                        child: Column(children: [
                          _SettingsSwitchRow(
                            icon: Icons.mark_chat_unread_outlined,
                            title: 'Neue Nachrichten',
                            subtitle: 'Benachrichtigt dich bei neuen Chat-Nachrichten.',
                            value: s?.newMessagesNotif ?? true,
                            onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(newMessagesNotif: v)),
                            disabled: muteAll,
                          ),
                          const SizedBox(height: 4),
                          _SettingsSwitchRow(
                            icon: Icons.schedule_outlined,
                            title: 'Übergabe- & Rückgabe-Erinnerungen',
                            subtitle: 'Erinnert dich rechtzeitig an Übergabe und Rückgabe.',
                            value: s?.handoverReturnReminders ?? true,
                            onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(handoverReturnReminders: v)),
                            disabled: muteAll,
                          ),
                          const SizedBox(height: 4),
                          _SettingsSwitchRow(
                            icon: Icons.pending_actions_outlined,
                            title: 'Offene Zeitbestätigungen',
                            subtitle: 'Erinnert dich, wenn eine vorgeschlagene Zeit noch bestätigt werden muss.',
                            value: s?.openTimeConfirmations ?? true,
                            onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(openTimeConfirmations: v)),
                            disabled: muteAll,
                          ),
                          const SizedBox(height: 4),
                          _SettingsSwitchRow(
                            icon: Icons.support_agent_outlined,
                            title: 'Support-Fall Updates',
                            subtitle: 'Benachrichtigt dich, wenn es Neuigkeiten zu einem Support-Fall gibt.',
                            value: s?.supportCaseUpdates ?? true,
                            onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(supportCaseUpdates: v)),
                            disabled: muteAll,
                          ),
                          const SizedBox(height: 4),
                          _SettingsSwitchRow(
                            icon: Icons.notifications_off_outlined,
                            title: 'Alle stummschalten',
                            subtitle: 'Deaktiviert alle Chat-Benachrichtigungen.',
                            value: muteAll,
                            onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(muteAll: v)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),

                      // 2. Privatsphäre & Sicherheit
                      _SettingsSection(
                        title: 'Privatsphäre & Sicherheit',
                        icon: Icons.shield_outlined,
                        emphasized: true,
                        child: Column(children: [
                          _SettingsSwitchRow(
                            icon: Icons.done_all,
                            title: 'Lesebestätigungen senden',
                            subtitle: 'Andere sehen, ob du eine Nachricht gelesen hast.',
                            value: s?.sendReadReceipts ?? true,
                            onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(sendReadReceipts: v)),
                          ),
                          const SizedBox(height: 4),
                          _SettingsSwitchRow(
                            icon: Icons.visibility_outlined,
                            title: 'Chat-Vorschau anzeigen',
                            subtitle: 'Zeigt die letzte Nachricht in der Chat-Liste.',
                            value: s?.showChatPreview ?? true,
                            onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(showChatPreview: v)),
                          ),
                          const SizedBox(height: 4),
                          _SettingsActionRow(
                            icon: Icons.block,
                            title: 'Blockierte Nutzer verwalten',
                            subtitle: 'Du bestimmst, wen du blockiert hast.',
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
                          ),
                          const SizedBox(height: 4),
                          _SettingsActionRow(
                            icon: Icons.report_outlined,
                            title: 'Nutzer oder Chat melden',
                            subtitle: 'Hilf uns, die Community sicher zu halten.',
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportUserScreen())),
                          ),
                          const SizedBox(height: 6),
                          _SettingsInfoRow(
                            icon: Icons.info_outline,
                            text: 'Chats sind nur bei angenommenen und laufenden Buchungen aktiv.',
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),

                      // 3. Übergabe & Belege
                      _SettingsSection(
                        title: 'Übergabe & Belege',
                        icon: Icons.inventory_2_outlined,
                        highlightTint: theme.colorScheme.primary.withValues(alpha: 0.08),
                        child: Column(children: [
                          _SettingsSwitchRow(
                            icon: Icons.photo_library_outlined,
                            title: 'Übergabefotos in Galerie speichern',
                            subtitle: 'Speichert Belege schneller auf deinem Gerät.',
                            value: s?.autoSaveHandoverPhotos ?? true,
                            onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(autoSaveHandoverPhotos: v)),
                          ),
                          const SizedBox(height: 4),
                          _SettingsSwitchRow(
                            icon: Icons.save_outlined,
                            title: 'Belege lokal speichern',
                            subtitle: 'Sichert wichtige Nachweise für Übergabe und Rückgabe.',
                            value: s?.saveReceiptsLocally ?? true,
                            onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(saveReceiptsLocally: v)),
                          ),
                          const SizedBox(height: 6),
                          _SettingsInfoRow(
                            icon: Icons.photo_camera_outlined,
                            text: 'Für Übergabe und Rückgabe sind mindestens 4 Fotos erforderlich.',
                          ),
                          const SizedBox(height: 4),
                          _SettingsSwitchRow(
                            icon: Icons.qr_code_2,
                            title: 'QR-/Code-Hinweise anzeigen',
                            subtitle: 'Zeigt Hinweise, falls QR-Code oder 6-stelliger Code benötigt wird.',
                            value: s?.showQrCodeHints ?? true,
                            onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(showQrCodeHints: v)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),

                      // 4. Chat-Verhalten
                      _SettingsSection(
                        title: 'Chat-Verhalten',
                        icon: Icons.forum_outlined,
                        child: Column(children: [
                          _SettingsSwitchRow(
                            icon: Icons.visibility_off_outlined,
                            title: 'Abgeschlossene Chats ausblenden',
                            subtitle: 'Reduziert die Liste auf aktive Vorgänge.',
                            value: s?.hideCompletedChats ?? false,
                            onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(hideCompletedChats: v)),
                          ),
                          const SizedBox(height: 4),
                          _SettingsSwitchRow(
                            icon: Icons.archive_outlined,
                            title: 'Chats automatisch archivieren',
                            subtitle: 'Ordnet abgeschlossene Chats automatisch ein.',
                            value: s?.autoArchiveChats ?? false,
                            onChanged: (v) => setState(() => _settings = (s ?? MessagesSettings.defaults()).copyWith(autoArchiveChats: v)),
                          ),
                          const SizedBox(height: 6),
                          _SettingsInfoRow(
                            icon: Icons.info_outline,
                            text: 'Abgeschlossene Chats bleiben über Buchungsdetails erreichbar.',
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ]),
                  ),
                  // Floating glassy footer
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _GlassyFooter(
                      saving: _saving,
                      loading: _loading,
                      onCancel: () {
                        if (widget.presentation == MessagesSettingsPresentation.sheet) {
                          Navigator.of(context).maybePop();
                        } else {
                          (widget.onCancel ?? () => Navigator.of(context).maybePop()).call();
                        }
                      },
                      onSave: _save,
                    ),
                  ),
                ],
              ),
      ),
    ]);
  }
}

/// Premium bottom-sheet wrapper for Nachrichten-Einstellungen (local-only MVP).
class MessagesSettingsSheet extends StatelessWidget {
  const MessagesSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) => const MessagesSettingsView(presentation: MessagesSettingsPresentation.sheet);
}

/// Glassy floating footer with Abbrechen/Speichern buttons
class _GlassyFooter extends StatelessWidget {
  final bool saving;
  final bool loading;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  const _GlassyFooter({required this.saving, required this.loading, required this.onCancel, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              padding: const EdgeInsets.all(6),
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: TextButton(
                          onPressed: saving ? null : onCancel,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.06),
                            foregroundColor: Colors.white.withValues(alpha: 0.85),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                          ),
                          child: const Text('Abbrechen', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: TextButton(
                      onPressed: (saving || loading) ? null : onSave,
                      style: TextButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Änderungen speichern', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool emphasized;
  final Color? highlightTint;
  const _SettingsSection({required this.title, required this.icon, required this.child, this.emphasized = false, this.highlightTint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = highlightTint ?? Colors.white.withValues(alpha: emphasized ? 0.06 : 0.04);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: emphasized ? 0.14 : 0.08)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon, color: emphasized ? theme.colorScheme.primary : Colors.white70, size: 15),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.2, fontSize: 12))),
            ]),
            const SizedBox(height: 6),
            child,
          ]),
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool disabled;
  const _SettingsSwitchRow({required this.icon, required this.title, this.subtitle, required this.value, required this.onChanged, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = disabled ? 0.4 : 1.0;
    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.fromLTRB(7, 5, 4, 5),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, color: Colors.white70, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 12)),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54, fontSize: 10, height: 1.25)),
              ],
            ]),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: disabled ? null : onChanged,
              activeColor: theme.colorScheme.primary,
              inactiveThumbColor: Colors.white.withValues(alpha: 0.6),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
            ),
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
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
          child: Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, color: Colors.white70, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 12)),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54, fontSize: 10, height: 1.25)),
                ],
              ]),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
          ]),
        ),
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SettingsInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: theme.colorScheme.primary.withValues(alpha: 0.8), size: 14),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, fontSize: 10, height: 1.35),
            softWrap: true,
          ),
        ),
      ]),
    );
  }
}
