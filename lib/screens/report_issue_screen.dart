import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/widgets/app_popup.dart';

class ReportIssueScreen extends StatefulWidget {
  final String requestId;
  final String? itemTitle;
  const ReportIssueScreen({super.key, required this.requestId, this.itemTitle});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  String? _selectedCode; // e.g., 'damage', 'delay', 'no_show', 'wrong_item', 'behavior', 'other'
  final TextEditingController _detailsCtrl = TextEditingController();

  final List<_IssueType> _types = const [
    _IssueType(code: 'damage', label: 'Schaden melden', icon: Icons.build_outlined),
    _IssueType(code: 'delay', label: 'Verspätete Rückgabe', icon: Icons.pending_actions_outlined),
    _IssueType(code: 'no_show', label: 'Nicht erschienen', icon: Icons.event_busy_outlined),
    _IssueType(code: 'wrong_item', label: 'Falscher Artikel', icon: Icons.swap_horiz_outlined),
    _IssueType(code: 'behavior', label: 'Unsicheres Verhalten', icon: Icons.report_gmailerrorred_outlined),
    _IssueType(code: 'other', label: 'Sonstiges', icon: Icons.more_horiz),
  ];

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedCode == null) {
      AppPopup.toast(context, icon: Icons.info_outline, title: 'Bitte ein Problem wählen');
      return;
    }
    final note = _detailsCtrl.text.trim();
    try {
      await DataService.addTimelineEvent(
        requestId: widget.requestId,
        type: 'issue:$_selectedCode',
        note: note.isEmpty ? 'Keine Details' : note,
      );
      await DataService.addNotification(
        title: 'Problem gemeldet',
        body: 'Deine Meldung für "${widget.itemTitle ?? 'Buchung'}" wurde gespeichert.',
      );
      debugPrint('[issue] reported ${_selectedCode} for request ${widget.requestId}: $note');
      if (!mounted) return;
      AppPopup.toast(context, icon: Icons.check_circle_outline, title: 'Danke, wir haben es notiert');
      Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('[issue] submit failed: $e');
      if (!mounted) return;
      AppPopup.toast(context, icon: Icons.error_outline, title: 'Meldung fehlgeschlagen');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Problem melden'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.itemTitle != null) ...[
            Text(
              widget.itemTitle!,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
          ],
          Text('Wähle ein Problem', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _types)
                _IssueChip(
                  selected: _selectedCode == t.code,
                  icon: t.icon,
                  label: t.label,
                  onTap: () => setState(() => _selectedCode = t.code),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selectedCode == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    key: ValueKey(_selectedCode),
                    children: [
                      Text('Beschreibung (optional)', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: TextField(
                          controller: _detailsCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Füge Details hinzu…',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.send),
                          label: const Text('Meldung senden'),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _IssueType {
  final String code; final String label; final IconData icon;
  const _IssueType({required this.code, required this.label, required this.icon});
}

class _IssueChip extends StatelessWidget {
  final bool selected; final IconData icon; final String label; final VoidCallback onTap;
  const _IssueChip({required this.selected, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = selected ? primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05);
    final border = selected ? primary.withValues(alpha: 0.4) : Colors.white12;
    final fg = selected ? primary : Colors.white70;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
