import 'package:flutter/material.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:provider/provider.dart';

class ProfileHeaderCard extends StatelessWidget {
  final User user;
  final int listingsCount;
  const ProfileHeaderCard({super.key, required this.user, required this.listingsCount});

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.all(16),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 140,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: NetworkImage(
                      user.photoURL ?? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        user.isVerified ? Icons.verified : Icons.verified_outlined,
                        size: 16,
                        color: user.isVerified ? const Color(0xFF22C55E) : Colors.black45,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  user.isVerified ? l10n.t('Verifiziert') : l10n.t('Nicht verifiziert'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          VerticalDivider(width: 1, thickness: 1, color: Colors.white54.withValues(alpha: 0.15)),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetricLine(label: l10n.t('Bewertung'), value: '${user.avgRating.toStringAsFixed(1)} ★'),
                  const SizedBox(height: 8),
                  _MetricLine(label: l10n.t('Buchungen'), value: _estimatedBookings(user).toString()),
                  const SizedBox(height: 8),
                  _MetricLine(label: l10n.t('Dabei seit'), value: _joinedMonthYear(user.createdAt)),
                  const SizedBox(height: 8),
                  _MetricLine(label: l10n.t('Anzeigen'), value: listingsCount.toString()),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  static String _joinedMonthYear(DateTime createdAt) {
    const monthsDe = ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'];
    final m = monthsDe[createdAt.month - 1];
    return '$m ${createdAt.year}';
  }

  static int _estimatedBookings(User u) {
    final est = (u.reviewCount * 1.3).clamp(0, 9999).toInt();
    return est;
  }
}

class _MetricLine extends StatelessWidget {
  final String label; final String value;
  const _MetricLine({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70))),
      const SizedBox(width: 8),
      Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
    ]);
  }
}
