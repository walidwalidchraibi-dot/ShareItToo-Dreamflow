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
    final custom = lists.where((e) => e['system'] != true).toList();
    return AppPopup.showCustom<String>(
      context,
      icon: Icons.favorite,
      title: 'Zu welcher Wunschliste hinzufügen?',
      body: _SelectorContent(
        title: 'Zu welcher Wunschliste hinzufügen?',
        options: [
          // System lists first
          for (final e in system)
            _SheetOption(
              id: (e['id'] ?? '').toString(),
              title: (e['name'] ?? '').toString(),
              subtitle: _subtitleForSystem((e['id'] ?? '').toString()),
              icon: _iconForListId((e['id'] ?? '').toString(), system: true),
              count: itemsBy[(e['id'] ?? '').toString()]?.length ?? 0,
              system: true,
            ),
          // Then custom lists
          for (final e in custom)
            _SheetOption(
              id: (e['id'] ?? '').toString(),
              title: (e['name'] ?? '').toString(),
              subtitle: 'Eigene Liste',
              icon: _iconForListId((e['id'] ?? '').toString(), system: false),
              count: itemsBy[(e['id'] ?? '').toString()]?.length ?? 0,
              system: false,
            ),
        ],
        grid: false,
        onDark: true,
        hideIcons: false,
        allowCreate: true,
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
          icon: _iconForListId((e['id'] ?? '').toString(), system: e['system'] == true),
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
        hideIcons: false,
        allowCreate: true,
        popWith: (id) => Navigator.of(context).pop(id),
      ),
      showCloseIcon: false,
      showLeading: false,
      showAccentLine: false,
    );
  }

  /// Shows the small management popup with two actions for an item already
  /// saved in a wishlist: move to another list or remove from wishlist.
  /// Returns 'move' | 'remove' or null when dismissed.
  static Future<String?> showManageOptions(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    return AppPopup.showCustom<String>(
      context,
      icon: Icons.favorite,
      title: 'Wunschliste',
      body: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionRow(
              icon: Icons.swap_horiz,
              iconColor: cs.primary,
              label: 'In andere Wunschliste verschieben',
              onTap: () => Navigator.of(context).pop('move'),
            ),
            _ActionRow(
              icon: Icons.delete_outline,
              iconColor: cs.error,
              label: 'Aus Wunschliste entfernen',
              onTap: () => Navigator.of(context).pop('remove'),
            ),
          ],
        ),
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
  final bool allowCreate;
  const _SelectorContent({required this.title, required this.options, this.grid = false, this.onDark = false, this.hideIcons = false, this.popWith, this.allowCreate = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (allowCreate)
                _CreateListCard(
                  onDark: onDark,
                  onCreated: (id) => (popWith ?? (s) {})(id),
                ),
              if (grid)
                WishlistFolderGrid(
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
              else
                Column(children: [for (final op in options) _OptionCard(option: op, onSelected: (id) => (popWith ?? (s) {})(id), onDark: onDark, showIcon: !hideIcons)]),
            ],
          ),
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
    final iconBg = cs.primary.withValues(alpha: onDark ? 0.15 : 0.10);
    final iconColor = cs.primary;
    // Systemlisten (Demnächst benötigt, Für später, Wieder mieten) sollen im dunklen Popup weiß sein
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: onDark
          ? (option.system ? Colors.white : cs.primary)
          : cs.primary,
    );
    final subStyle = onDark
        ? Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white60)
        : Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.60));
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
                // Count badge for folders
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

/// Returns a suitable icon for a wishlist id.
IconData _iconForListId(String id, {required bool system}) {
  if (system) {
    // Deutlich unterschiedliche Icons fuer "Demnächst benötigt" und "Für später"
    if (id == DataService.wlSoonId) return Icons.watch_later_outlined; // bald/zeitnah
    if (id == DataService.wlLaterId) return Icons.event_available_outlined; // für später
    if (id == DataService.wlAgainId) return Icons.repeat_outlined;
  }
  // Für vom Nutzer erstellte Wunschlisten ein persönliches Icon anzeigen
  return Icons.person_outline;
}

class _CreateListCard extends StatelessWidget {
  final bool onDark;
  final ValueChanged<String> onCreated;
  const _CreateListCard({required this.onDark, required this.onCreated});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tileBg = onDark ? Colors.white.withValues(alpha: 0.08) : cs.surfaceContainerHighest;
    final tileBorder = onDark ? Colors.white.withValues(alpha: 0.12) : cs.onSurface.withValues(alpha: 0.06);
    final iconBg = cs.primary.withValues(alpha: onDark ? 0.15 : 0.10);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          final controller = TextEditingController();
          final name = await AppPopup.showCustom<String>(
            context,
            icon: Icons.favorite_border,
            title: 'Neue Wunschliste erstellen',
            showCloseIcon: false,
            showLeading: false,
            showAccentLine: false,
            body: _CreateListForm(controller: controller),
          );
          if (name != null && name.trim().isNotEmpty) {
            final id = await DataService.addCustomWishlist(name.trim());
            // Return the new id to the parent selector so it can immediately select it
            onCreated(id);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: tileBg, border: Border.all(color: tileBorder)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle), child: Icon(Icons.add, color: cs.primary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Neue Wunschliste erstellen', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: onDark ? Colors.white : cs.primary)),
                    const SizedBox(height: 4),
                    Text('Eigene Liste', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: onDark ? Colors.white60 : cs.onSurface.withValues(alpha: 0.60))),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateListForm extends StatelessWidget {
  final TextEditingController controller;
  const _CreateListForm({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inputBg = Colors.white.withValues(alpha: 0.08);
    final inputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: cs.primary,
          decoration: InputDecoration(
            hintText: 'Name der Wunschliste',
            hintStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.2)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: BorderSide(color: Colors.white.withValues(alpha: 0.20)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Abbrechen'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(context).maybePop(controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Erstellen'),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Simple two-option action rows used by showManageOptions(), matching the
/// visual language of the wishlist selection popup (glass card, rounded tiles,
/// white text on dark, colored leading icon inside a soft circle).
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.iconColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tileBg = Colors.white.withValues(alpha: 0.08);
    final tileBorder = Colors.white.withValues(alpha: 0.12);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: tileBg, border: Border.all(color: tileBorder)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(icon, color: iconColor)),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ),
    );
  }
}
