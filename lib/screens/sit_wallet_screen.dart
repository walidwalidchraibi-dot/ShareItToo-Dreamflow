import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:lendify/models/sit_credit_transaction.dart';
import 'package:lendify/services/sit_credit_service.dart';

class SitWalletScreen extends StatefulWidget {
  const SitWalletScreen({super.key});

  @override
  State<SitWalletScreen> createState() => _SitWalletScreenState();
}

class _SitWalletScreenState extends State<SitWalletScreen> {
  bool _loading = true;
  bool _enabled = false;
  double _balance = 0;
  List<SitCreditTransaction> _tx = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SitCreditService.getStatus(),
        SitCreditService.getTransactions(),
      ]);
      if (!mounted) return;
      final status = results[0] as SitCreditStatus;
      final tx = results[1] as List<SitCreditTransaction>;
      setState(() {
        _enabled = status.enabled;
        _balance = status.balance;
        _tx = tx;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[SitWalletScreen] load failed: $e');
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _balance = 0;
        _tx = const [];
        _loading = false;
      });
    }
  }

  String _formatCurrency(double value) {
    final v = value.isFinite ? value : 0.0;
    return '${v.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  IconData _iconFor(SitCreditTransactionType type) {
    switch (type) {
      case SitCreditTransactionType.deposit:
        return Icons.south_west;
      case SitCreditTransactionType.spend:
        return Icons.north_east;
      case SitCreditTransactionType.payout:
        return Icons.account_balance_outlined;
    }
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

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
          title: Text('SIT Guthaben', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(
                      'Dein Guthaben ist für Buchungen sofort verfügbar und kann später auch auf ein Bankkonto ausgezahlt werden.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    _WalletBalanceCard(balanceText: _formatCurrency(_balance), enabled: _enabled),
                    const SizedBox(height: 10),
                    _SectionCard(
                      icon: Icons.swap_horiz,
                      title: 'Aktionen',
                      child: Column(children: [
                        _ActionRow(
                          icon: Icons.add_circle_outline,
                          title: 'Einzahlungen',
                          subtitle: 'Später verfügbar (MVP)',
                          onTap: null,
                        ),
                        const SizedBox(height: 8),
                        _ActionRow(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Ausgaben',
                          subtitle: 'Transaktionen aus Buchungen',
                          onTap: null,
                        ),
                        const SizedBox(height: 8),
                        _ActionRow(
                          icon: Icons.account_balance_outlined,
                          title: 'Auszahlungen',
                          subtitle: 'Auf Bankkonto auszahlen (später)',
                          onTap: null,
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Text('Transaktionshistorie', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (_tx.isEmpty)
                      _SectionCard(
                        icon: Icons.receipt_long,
                        title: 'Keine Transaktionen',
                        child: Text('Sobald du Einnahmen oder Ausgaben hast, erscheinen sie hier.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                      )
                    else
                      for (final t in _tx) ...[
                        _TransactionCard(
                          icon: _iconFor(t.type),
                          title: t.title,
                          subtitle: t.subtitle,
                          amountText: (t.amount >= 0 ? '+${_formatCurrency(t.amount)}' : _formatCurrency(t.amount)),
                          amountColor: t.amount >= 0 ? theme.colorScheme.tertiary : theme.colorScheme.error,
                          timeText: _timeLabel(t.createdAt),
                          accent: primary,
                        ),
                        const SizedBox(height: 8),
                      ],
                  ]),
                ),
        ),
      ),
    ]);
  }
}

class _WalletBalanceCard extends StatelessWidget {
  final String balanceText;
  final bool enabled;
  const _WalletBalanceCard({required this.balanceText, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withValues(alpha: 0.35)),
          ),
          child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Aktuelles Guthaben', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(balanceText, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (enabled ? theme.colorScheme.tertiary : Colors.white).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: (enabled ? theme.colorScheme.tertiary : Colors.white).withValues(alpha: 0.25)),
          ),
          child: Text(
            enabled ? 'Aktiv' : 'Inaktiv',
            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SectionCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _ActionRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70)),
            ]),
          ),
          Icon(Icons.chevron_right, color: onTap == null ? Colors.white24 : primary),
        ]),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String amountText;
  final Color amountColor;
  final String timeText;
  final Color accent;
  const _TransactionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amountText,
    required this.amountColor,
    required this.timeText,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            if ((subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70)),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(amountText, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: amountColor)),
          const SizedBox(height: 2),
          Text(timeText, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54)),
        ]),
      ]),
    );
  }
}
