import 'package:flutter/material.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/user_avatar.dart';
import 'package:provider/provider.dart';

class ProfileHeaderCard extends StatelessWidget {
  final User user;
  final int listingsCount;
  /// Number of completed bookings (as renter). If null, we fall back to a demo estimate.
  final int? completedBookingsCount;
  final VoidCallback? onPrimaryTap;
  const ProfileHeaderCard({super.key, required this.user, required this.listingsCount, this.completedBookingsCount, this.onPrimaryTap});

  bool get _isGuestUser => (user.role == 'guest') || (user.id == 'guest-user');

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final isGuest = _isGuestUser;
    final avatarUrl = isGuest ? null : (user.photoURL ?? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPrimaryTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        padding: const EdgeInsets.all(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 104,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(children: [
                      SitUserAvatar(
                        url: avatarUrl,
                        radius: 36,
                        borderColor: Colors.white.withValues(alpha: 0.12),
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
              const SizedBox(width: 8),
              VerticalDivider(width: 1, thickness: 1, color: Colors.white54.withValues(alpha: 0.15)),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetricLine(label: l10n.t('Bewertung'), value: isGuest ? '—' : _ratingText(context, user)),
                      const SizedBox(height: 8),
                      _MetricLine(label: l10n.t('Buchungen'), value: isGuest ? '—' : (completedBookingsCount ?? _estimatedBookings(user)).toString()),
                      const SizedBox(height: 8),
                      _MetricLine(label: l10n.t('Dabei seit'), value: isGuest ? '—' : _joinedMonthYear(user.createdAt)),
                      const SizedBox(height: 8),
                      _MetricLine(label: l10n.t('Anzeigen'), value: isGuest ? '—' : listingsCount.toString()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ratingText(BuildContext context, User user) {
    final l10n = context.read<LocalizationController>();
    final c = user.reviewCount;
    if (c <= 0) return l10n.t('Keine Bewertung');
    final label = c == 1 ? l10n.t('Bewertung') : l10n.t('Bewertungen');
    return '${user.avgRating.toStringAsFixed(1)} ★ ($c $label)';
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
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.labelSmall?.copyWith(color: Colors.white70);
    final valueStyle = textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700);
    // Keep the value close to the label by using a fixed label column.
    // This avoids pushing values to the far right edge.
    return Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
      SizedBox(
        width: 74,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          value,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: valueStyle,
        ),
      ),
    ]);
  }
}
