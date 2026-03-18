import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:lendify/models/user.dart';
import 'package:lendify/services/blocked_users_service.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/widgets/user_avatar.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _loading = true;
  List<User> _blocked = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final ids = await BlockedUsersService.getBlockedUserIds();
      final users = <User>[];
      for (final id in ids) {
        final u = await DataService.getUserById(id);
        if (u != null) users.add(u);
      }
      if (!mounted) return;
      users.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      setState(() => _blocked = users);
    } catch (e) {
      debugPrint('[BlockedUsersScreen] _load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmUnblock(User user) async {
    final theme = Theme.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (context) {
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: Text('Nutzer entsperren?', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.of(context).maybePop(false), icon: const Icon(Icons.close, color: Colors.white)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Dieser Nutzer kann dir danach wieder Nachrichten senden und Anfragen stellen.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(false),
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
                          onPressed: () => Navigator.of(context).maybePop(true),
                          style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: const Text('Entsperren'),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    try {
      await BlockedUsersService.unblockUser(user.id);
    } catch (e) {
      debugPrint('[BlockedUsersScreen] unblock failed: $e');
    }
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
        title: const Text('Blockierte Nutzer'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            : _blocked.isEmpty
                ? _BlockedUsersEmptyState(accent: theme.colorScheme.primary)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: _blocked.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final u = _blocked[index];
                      return _BlockedUserCard(user: u, onUnblock: () => _confirmUnblock(u));
                    },
                  ),
      ),
    );
  }
}

class _BlockedUserCard extends StatelessWidget {
  final User user;
  final VoidCallback onUnblock;
  const _BlockedUserCard({required this.user, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratingText = user.reviewCount > 0 ? '${user.avgRating.toStringAsFixed(1)}★ (${user.reviewCount})' : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(children: [
        SitUserAvatar(url: user.photoURL, radius: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.displayName, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              ratingText ?? 'Zuletzt aktiv: kürzlich',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 38,
          child: ElevatedButton(
            onPressed: onUnblock,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Entsperren'),
          ),
        ),
      ]),
    );
  }
}

class _BlockedUsersEmptyState extends StatelessWidget {
  final Color accent;
  const _BlockedUsersEmptyState({required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 40, 18, 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  child: Icon(Icons.verified_user, color: accent.withValues(alpha: 0.95), size: 26),
                ),
              ),
              const SizedBox(height: 14),
              Text('Keine blockierten Nutzer', textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                'Du hast aktuell keine Nutzer blockiert. Du kannst Nutzer jederzeit in einem Chat blockieren.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.5),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
