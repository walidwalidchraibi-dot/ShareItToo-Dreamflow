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
            title: const SizedBox(width: double.infinity, child: Text('Benachrichtigungseinstellungen', textAlign: TextAlign.center)),
            centerTitle: true,
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
            actions: [
              IconButton(
                tooltip: 'Zurücksetzen',
                icon: const Icon(Icons.refresh, color: Colors.white),
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
                  padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
                  children: [
                    _InfoCard(
                      title: 'Feed steuern (MVP)',
                      subtitle: 'Hier bestimmst du, welche Ereignisse im In-App-Feed „Benachrichtigungen“ angezeigt werden. Push/E-Mail kommt später.',
                      icon: Icons.tune,
                      accent: accent,
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Kategorien',
                      child: Column(
                        children: [
                          _ToggleRow(
                            title: 'Wichtig',
                            subtitle: 'Sicherheits- und kritische Hinweise',
                            icon: Icons.error_outline,
                            value: _prefs.showImportant,
                            onChanged: (v) => _save(_prefs.copyWith(showImportant: v)),
                            accent: accent,
                          ),
                          const _Divider(),
                          _ToggleRow(
                            title: 'Buchungen / Anmietungen',
                            subtitle: 'Anfragen, Annahmen, Statusänderungen',
                            icon: Icons.calendar_month_outlined,
                            value: _prefs.showBookings,
                            onChanged: (v) => _save(_prefs.copyWith(showBookings: v)),
                            accent: accent,
                          ),
                          const _Divider(),
                          _ToggleRow(
                            title: 'Nachrichten',
                            subtitle: 'Neue Chats und neue Nachrichten',
                            icon: Icons.chat_bubble_outline,
                            value: _prefs.showMessages,
                            onChanged: (v) => _save(_prefs.copyWith(showMessages: v)),
                            accent: accent,
                          ),
                          const _Divider(),
                          _ToggleRow(
                            title: 'Bewertungen',
                            subtitle: 'Neue Bewertungen & Review-Reminders',
                            icon: Icons.star_outline,
                            value: _prefs.showReviews,
                            onChanged: (v) => _save(_prefs.copyWith(showReviews: v)),
                            accent: accent,
                          ),
                          const _Divider(),
                          _ToggleRow(
                            title: 'Zahlungsstatus',
                            subtitle: 'Zahlung offen, bestätigt, fehlgeschlagen',
                            icon: Icons.payments_outlined,
                            value: _prefs.showPayments,
                            onChanged: (v) => _save(_prefs.copyWith(showPayments: v)),
                            accent: accent,
                          ),
                          const _Divider(),
                          _ToggleRow(
                            title: 'Sicherheit',
                            subtitle: 'Verdächtige Aktivitäten, Verifizierung',
                            icon: Icons.shield_outlined,
                            value: _prefs.showSecurity,
                            onChanged: (v) => _save(_prefs.copyWith(showSecurity: v)),
                            accent: accent,
                          ),
                          const _Divider(),
                          _ToggleRow(
                            title: 'System',
                            subtitle: 'Plattform-Infos & Produkt-Updates',
                            icon: Icons.info_outline,
                            value: _prefs.showSystem,
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
                          _ToggleRow(
                            title: 'Nach Kategorien gruppieren',
                            subtitle: 'Wichtig / Buchungen / Nachrichten … als Sektionen',
                            icon: Icons.view_agenda_outlined,
                            value: _prefs.groupByCategory,
                            onChanged: (v) => _save(_prefs.copyWith(groupByCategory: v)),
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Hinweis',
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Diese Einstellungen wirken sofort auf den In‑App‑Feed. Sobald später Push‑Benachrichtigungen dazukommen, erweitern wir diese Seite um Push/E‑Mail‑Schalter.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.86)),
                        ),
                      ),
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
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;
  const _ToggleRow({required this.title, required this.subtitle, required this.icon, required this.value, required this.onChanged, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = value;

    final titleColor = isActive ? accent : theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final subtitleColor = isActive ? Colors.white.withValues(alpha: 0.78) : theme.colorScheme.onSurface.withValues(alpha: 0.42);

    final badgeBorder = isActive ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.07);
    final badgeGradient = isActive
        ? [accent.withValues(alpha: 0.42), accent.withValues(alpha: 0.12)]
        : [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.03)];
    final badgeIconColor = isActive ? Colors.white : Colors.white.withValues(alpha: 0.62);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: badgeGradient,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: badgeBorder),
            ),
            child: Icon(icon, color: badgeIconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800, color: titleColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: subtitleColor)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              return Colors.white.withValues(alpha: 0.92);
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return accent.withValues(alpha: 0.55);
              return Colors.white.withValues(alpha: 0.18);
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

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  const _InfoCard({required this.title, required this.subtitle, required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [accent.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.06)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent.withValues(alpha: 0.95), accent.withValues(alpha: 0.35)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
