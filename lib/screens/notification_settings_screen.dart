import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lendify/services/notification_preferences_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _loading = true;
  NotificationPreferences _prefs = NotificationPreferences.defaults();

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await NotificationPreferencesService.get();
      if (!mounted) return;
      setState(() => _prefs = prefs);
    } catch (e) {
      debugPrint('[NotificationSettingsScreen] load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(NotificationPreferences next) async {
    setState(() => _prefs = next);
    await NotificationPreferencesService.set(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.86));
    final captionStyle = theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.70), height: 1.35);
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
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
            title: const SizedBox.shrink(),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              color: Colors.white.withValues(alpha: 0.92),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              IconButton(
                tooltip: 'Zurücksetzen',
                icon: Icon(Icons.refresh_rounded, size: 20, color: Colors.white.withValues(alpha: 0.82)),
                onPressed: () async {
                  await NotificationPreferencesService.reset();
                  if (!mounted) return;
                  await _load();
                },
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, topInset + kToolbarHeight - 2, 16, 20),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Benachrichtigungseinstellungen', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text('Bestimme, welche Ereignisse in deinem Benachrichtigungs‑Feed angezeigt werden.', style: bodyStyle),
                          const SizedBox(height: 8),
                          Text('Wichtig/Sicherheit bleiben immer sichtbar. Buchungen filtern Anfragen, Annahmen sowie Übergabe- und Rückgabe-Updates. Nachrichten filtern normale Chats, Support-Fälle nur Support-Updates, Zahlungen Zahlungs-/Erstattungsinfos, Bewertungen Review-Updates und System Produkt-/Wartungshinweise.', style: captionStyle),
                        ],
                      ),
                    ),
                    _Section(
                      title: 'Feed steuern',
                      description: 'Wähle, welche Kategorien im Benachrichtigungsfeed angezeigt werden.',
                      child: Column(
                        children: [
                          _SettingToggleTile(
                            icon: Icons.error_outline,
                            title: 'Wichtig',
                            description: 'Zeigt dringende Hinweise und wichtige Ereignisse.',
                            value: true,
                            enabled: false,
                            onChanged: null,
                            accent: accent,
                          ),
                          const _Divider(),
                          _SettingToggleTile(
                            icon: Icons.calendar_month_outlined,
                            title: 'Buchungen',
                            description: 'Anfragen, Annahmen, Stornierungen und Statusänderungen.',
                            value: _prefs.showBookings,
                            enabled: true,
                            onChanged: (v) => _save(_prefs.copyWith(showBookings: v)),
                            accent: accent,
                          ),
                          const _Divider(),
                          _SettingToggleTile(
                            icon: Icons.swap_horiz_rounded,
                            title: 'Übergabe & Rückgabe',
                            description: 'Erinnerungen, Zeitbestätigungen, QR-Code und Rückgabehinweise.',
                            value: _prefs.showBookings,
                            enabled: true,
                            onChanged: (v) => _save(_prefs.copyWith(showBookings: v)),
                            accent: accent,
                          ),
                          const _Divider(),
                          _SettingToggleTile(
                            icon: Icons.chat_bubble_outline,
                            title: 'Nachrichten',
                            description: 'Neue Chat-Nachrichten und Antworten.',
                            value: _prefs.showMessages,
                            enabled: true,
                            onChanged: (v) => _save(_prefs.copyWith(showMessages: v)),
                            accent: accent,
                          ),
                          const _Divider(),
                          _SettingToggleTile(
                            icon: Icons.support_agent_outlined,
                            title: 'Support-Fälle',
                            description: 'Updates zu gemeldeten Problemen und Support-Anfragen.',
                            value: _prefs.showSupport,
                            enabled: true,
                            onChanged: (v) => _save(_prefs.copyWith(showSupport: v)),
                            accent: accent,
                          ),
                          const _Divider(),
                          _SettingToggleTile(
                            icon: Icons.payments_outlined,
                            title: 'Zahlungen',
                            description: 'Zahlungen, Rückerstattungen, Auszahlungen und Gebühren.',
                            value: _prefs.showPayments,
                            enabled: true,
                            onChanged: (v) => _save(_prefs.copyWith(showPayments: v)),
                            accent: accent,
                          ),
                          const _Divider(),
                          _SettingToggleTile(
                            icon: Icons.star_outline,
                            title: 'Bewertungen',
                            description: 'Neue Bewertungen und Erinnerungen zur Bewertung.',
                            value: _prefs.showReviews,
                            enabled: true,
                            onChanged: (v) => _save(_prefs.copyWith(showReviews: v)),
                            accent: accent,
                          ),
                          const _Divider(),
                          _SettingToggleTile(
                            icon: Icons.verified_user_outlined,
                            title: 'Sicherheit & Verifizierung',
                            description: 'Verifizierung, Sicherheitschecks und wichtige Schutz-Hinweise.',
                            value: true,
                            enabled: false,
                            onChanged: null,
                            accent: accent,
                          ),
                          const _Divider(),
                          _SettingToggleTile(
                            icon: Icons.info_outline,
                            title: 'System',
                            description: 'Plattform-Updates und Wartungshinweise.',
                            value: _prefs.showSystem,
                            enabled: true,
                            onChanged: (v) => _save(_prefs.copyWith(showSystem: v)),
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Darstellung',
                      child: Column(
                        children: [
                          _SimpleToggleRow(
                            icon: Icons.view_agenda_outlined,
                            title: 'Nach Kategorien gruppieren',
                            subtitle: 'Sortiert Benachrichtigungen nach Themen.',
                            value: _prefs.groupByCategory,
                            onChanged: (v) => _save(_prefs.copyWith(groupByCategory: v)),
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Sortierung',
                      child: Column(
                        children: [
                          _SimpleToggleRow(
                            icon: Icons.low_priority,
                            title: 'Ungelesene zuerst anzeigen',
                            subtitle: 'Zeigt neue Benachrichtigungen zuerst.',
                            value: _prefs.unreadFirst,
                            onChanged: (v) => _save(_prefs.copyWith(unreadFirst: v)),
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _HintCard(
                      title: 'Hinweis',
                      lines: const [
                        'Diese Einstellungen gelten für den In-App-Benachrichtigungsfeed. Push- und E-Mail-Benachrichtigungen folgen später.',
                      ],
                      accent: accent,
                      titleStyle: titleStyle,
                      captionStyle: captionStyle,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  const _Section({required this.title, this.description, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(description!, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.80))),
                ],
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SettingToggleTile extends StatelessWidget {
  const _SettingToggleTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = value;
    final locked = !enabled;

    final titleColor = active ? Colors.white : Colors.white.withValues(alpha: 0.70);
    final bodyColor = Colors.white.withValues(alpha: active ? 0.78 : 0.56);

    final badgeBorder = active ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.10);
    final badgeGradient = active
        ? [accent.withValues(alpha: 0.42), accent.withValues(alpha: 0.12)]
        : [Colors.white.withValues(alpha: 0.11), Colors.white.withValues(alpha: 0.04)];
    final badgeIconColor = active ? Colors.white : Colors.white.withValues(alpha: 0.68);

    final switchInactiveTrack = Colors.white.withValues(alpha: 0.12);
    final switchInactiveThumb = Colors.white.withValues(alpha: 0.86);
    final switchOutline = Colors.white.withValues(alpha: 0.14);

    return Opacity(
      opacity: locked ? 0.82 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: badgeGradient),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: badgeBorder),
              ),
              child: Stack(children: [
                Positioned.fill(child: Icon(icon, color: badgeIconColor, size: 19)),
                if (locked)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(6)),
                      child: Icon(Icons.lock_outline, size: 12, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    softWrap: true,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: titleColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    softWrap: true,
                    style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor, height: 1.30),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Switch.adaptive(
                value: value,
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white;
                  return switchInactiveThumb;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return accent.withValues(alpha: 0.55);
                  return switchInactiveTrack;
                }),
                trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.transparent;
                  return switchOutline;
                }),
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleToggleRow extends StatelessWidget {
  const _SimpleToggleRow({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged, required this.accent});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final switchInactiveTrack = Colors.white.withValues(alpha: 0.12);
    final switchInactiveThumb = Colors.white.withValues(alpha: 0.86);
    final switchOutline = Colors.white.withValues(alpha: 0.14);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent.withValues(alpha: 0.34), accent.withValues(alpha: 0.10)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, softWrap: true, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle, softWrap: true, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.78), height: 1.30)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              return switchInactiveThumb;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return accent.withValues(alpha: 0.55);
              return switchInactiveTrack;
            }),
            trackOutlineColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.transparent;
              return switchOutline;
            }),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.10));
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.title, required this.lines, required this.accent, required this.titleStyle, required this.captionStyle});
  final String title;
  final List<String> lines;
  final Color accent;
  final TextStyle? titleStyle;
  final TextStyle? captionStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [accent.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0.06)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent.withValues(alpha: 0.90), accent.withValues(alpha: 0.28)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.info_outline, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                const SizedBox(height: 6),
                for (final line in lines) ...[
                  Text(line, style: captionStyle),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
