import 'package:flutter/material.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/widgets/wishlist_folder.dart';
import 'package:lendify/widgets/app_popup.dart';

class WishlistSelectionSheet {
  /// Shows the first-time add sheet with the three predefined lists only.
  static Future<String?> showAdd(BuildContext context) async {
    final lists = await DataService.getWishlists();
    final itemsBy = await DataService.getItemsByWishlist();
    final system = lists.where((e) => e['system'] == true).toList();
    return AppPopup.showCustom<String>(
      context,
      icon: Icons.favorite,
      title: 'Zu welcher Wunschliste hinzufügen?',
      body: _SelectorContent(
        title: 'Zu welcher Wunschliste hinzufügen?',
        options: [
          for (final e in system)
            _SheetOption(
              id: (e['id'] ?? '').toString(),
              title: (e['name'] ?? '').toString(),
              subtitle: _subtitleForSystem((e['id'] ?? '').toString()),
              icon: Icons.folder,
              count: itemsBy[(e['id'] ?? '').toString()]?.length ?? 0,
              system: true,
            )
        ],
        grid: false,
        onDark: true,
        hideIcons: true,
        popWith: (id) => Navigator.of(context).pop(id),
      ),
      showCloseIcon: false,
      showLeading: false,
      showAccentLine: false,
    );
  }

  /// Shows a move-to sheet across all lists except the current.
  static Future<String?> showMove(BuildContext context, {required String currentListId}) async {
    final lists = await DataService.getWishlists();
    final itemsBy = await DataService.getItemsByWishlist();
    final options = lists.where((e) => (e['id'] ?? '').toString() != currentListId).map((e) => _SheetOption(
          id: (e['id'] ?? '').toString(),
          title: (e['name'] ?? '').toString(),
          subtitle: e['system'] == true ? _subtitleForSystem((e['id'] ?? '').toString()) : 'Eigene Liste',
          icon: Icons.folder,
          count: itemsBy[(e['id'] ?? '').toString()]?.length ?? 0,
          system: e['system'] == true,
        ));
    return AppPopup.showCustom<String>(
      context,
      icon: Icons.drive_file_move_rtl,
      title: 'In andere Wunschliste verschieben',
      body: _SelectorContent(
        title: 'In andere Wunschliste verschieben',
        options: options.toList(),
        grid: false,
        onDark: true,
        hideIcons: true,
        popWith: (id) => Navigator.of(context).pop(id),
      ),
      showCloseIcon: false,
      showLeading: false,
      showAccentLine: false,
    );
  }

  static String _subtitleForSystem(String id) {
    if (id == DataService.wlSoonId) return 'Ich plane, diesen Artikel bald zu mieten';
    if (id == DataService.wlLaterId) return 'Interessant, aber nicht jetzt';
    if (id == DataService.wlAgainId) return 'Diesen Artikel hatte ich schon';
    return '';
  }
}

class _SelectorContent extends StatelessWidget {
  final String title;
  final List<_SheetOption> options;
  final bool grid;
  final bool onDark;
  final bool hideIcons;
  final ValueChanged<String>? popWith; // when embedded inside AppPopup, we cannot use the local Navigator context directly
  const _SelectorContent({required this.title, required this.options, this.grid = false, this.onDark = false, this.hideIcons = false, this.popWith});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: grid
              ? WishlistFolderGrid(
                  options: [
                    for (final op in options)
                      WishlistFolderOption(
                        id: op.id,
                        title: op.title,
                        subtitle: op.subtitle,
                        count: op.count,
                        system: op.system,
                      ),
                  ],
                  onSelected: (id) => (popWith ?? (s) {})(id),
                  onDark: onDark,
                )
              : Column(children: [for (final op in options) _OptionCard(option: op, onSelected: (id) => (popWith ?? (s) {})(id), onDark: onDark, showIcon: !hideIcons)]),
        ),
      ]),
    );
  }
}

class _SheetOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final int count;
  final bool system;
  const _SheetOption({required this.id, required this.title, required this.subtitle, required this.icon, this.count = 0, this.system = false});
}

class _OptionCard extends StatelessWidget {
  final _SheetOption option;
  final ValueChanged<String> onSelected;
  final bool onDark;
  final bool showIcon;
  const _OptionCard({required this.option, required this.onSelected, this.onDark = false, this.showIcon = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tileBg = onDark ? Colors.white.withValues(alpha: 0.08) : cs.surfaceContainerHighest;
    final tileBorder = onDark ? Colors.white.withValues(alpha: 0.12) : cs.onSurface.withValues(alpha: 0.06);
    final iconBg = onDark ? Colors.white.withValues(alpha: 0.10) : cs.primary.withValues(alpha: 0.10);
    final iconColor = onDark ? Colors.white : cs.primary;
    final titleStyle = onDark
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)
        : Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.primary);
    final subStyle = onDark
        ? Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)
        : Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.72));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => onSelected(option.id),
        borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: tileBg, border: Border.all(color: tileBorder)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                if (showIcon) ...[
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle), child: Icon(option.icon, color: iconColor)),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(option.title, style: titleStyle),
                    const SizedBox(height: 4),
                      Text(option.subtitle, style: subStyle),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: (onDark ? Colors.white.withValues(alpha: 0.10) : cs.primary.withValues(alpha: 0.10)), borderRadius: BorderRadius.circular(999)),
                    child: Text(option.count.toString(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: onDark ? Colors.white : cs.primary, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// _FolderGrid and _CountBadge moved to shared widgets (WishlistFolderGrid)
