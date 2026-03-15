import 'dart:ui';

import 'package:flutter/material.dart';

class AccountDeletionDialogAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const AccountDeletionDialogAction({required this.label, required this.onPressed, this.isDestructive = false});
}

/// Glass-style confirmation dialog used for account deletion.
///
/// This keeps destructive flows consistent and more trustworthy than a
/// default AlertDialog.
class AccountDeletionDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget body;
  final AccountDeletionDialogAction leftAction;
  final AccountDeletionDialogAction rightAction;

  const AccountDeletionDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.leftAction,
    required this.rightAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final destructiveColor = t.colorScheme.error;

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(color: Colors.transparent))),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (rightAction.isDestructive ? destructiveColor : t.colorScheme.primary).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Icon(icon, color: rightAction.isDestructive ? destructiveColor : t.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => Navigator.of(context, rootNavigator: true).maybePop(),
                        child: const Center(child: Icon(Icons.close, color: Colors.white70)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  body,
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: leftAction.onPressed,
                        child: Text(leftAction.label),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: rightAction.isDestructive ? destructiveColor : null,
                          foregroundColor: rightAction.isDestructive ? Colors.white : null,
                        ),
                        onPressed: rightAction.onPressed,
                        child: Text(rightAction.label),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
