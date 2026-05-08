import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:lendify/services/messages_settings_service.dart';

class TranslationLanguageDialog extends StatefulWidget {
  final String title;
  final String initialCode;
  final List<TranslationLanguageOption> options;
  final List<Widget> actionTiles;
  final bool showTranslationToggle;
  final bool translationEnabled;
  final bool showOriginalToggle;
  final bool showOriginalEnabled;
  final bool showLanguagesOnlyWhenTranslationOn;
  final ValueChanged<bool>? onTranslationToggle;
  final ValueChanged<bool>? onShowOriginalToggle;

  const TranslationLanguageDialog({
    super.key,
    required this.title,
    required this.initialCode,
    required this.options,
    this.actionTiles = const [],
    this.showTranslationToggle = false,
    this.translationEnabled = true,
    this.showOriginalToggle = false,
    this.showOriginalEnabled = false,
    this.showLanguagesOnlyWhenTranslationOn = false,
    this.onTranslationToggle,
    this.onShowOriginalToggle,
  });

  @override
  State<TranslationLanguageDialog> createState() => _TranslationLanguageDialogState();
}

class _TranslationLanguageDialogState extends State<TranslationLanguageDialog> {
  late String _selected;
  late bool _translationOn;
  late bool _showOriginal;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCode.trim().toLowerCase();
    final match = widget.options.firstWhere(
      (opt) => initial == opt.code.toLowerCase() || initial.startsWith('${opt.code.toLowerCase()}-'),
      orElse: () => widget.options.first,
    );
    _selected = match.code;
    _translationOn = widget.translationEnabled;
    _showOriginal = widget.showOriginalEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedOptions = [...widget.options]
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withValues(alpha: 0.0)),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.32), blurRadius: 22, spreadRadius: 4)],
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.translate_outlined, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                              onPressed: () => Navigator.of(context).maybePop(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ]),
                          if (widget.actionTiles.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ..._withSpacing(widget.actionTiles),
                            const SizedBox(height: 10),
                            Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1, height: 1),
                            const SizedBox(height: 10),
                          ],
                          if (widget.showTranslationToggle || widget.showOriginalToggle) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Column(children: [
                                if (widget.showTranslationToggle)
                                  _SwitchRow(
                                    title: 'Übersetzung aktivieren',
                                    subtitle: 'Schaltet die automatische Übersetzung für diesen Chat.',
                                    value: _translationOn,
                                    onChanged: (v) {
                                      setState(() {
                                        _translationOn = v;
                                        if (!v) _showOriginal = false;
                                      });
                                      widget.onTranslationToggle?.call(v);
                                    },
                                  ),
                                if (widget.showOriginalToggle)
                                  _SwitchRow(
                                    title: 'Originale Nachricht anzeigen',
                                    subtitle: 'Zeigt den unveränderten Text.',
                                    value: _showOriginal,
                                    onChanged: _translationOn
                                        ? (v) {
                                            setState(() => _showOriginal = v);
                                            widget.onShowOriginalToggle?.call(v);
                                          }
                                        : null,
                                  ),
                              ]),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (!widget.showLanguagesOnlyWhenTranslationOn || _translationOn)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 320),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: sortedOptions.map((opt) {
                                      final active = _selected.toLowerCase() == opt.code.toLowerCase();
                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () => Navigator.of(context).maybePop(_translationOn ? opt.code : null),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            child: Row(children: [
                                              Icon(active ? Icons.radio_button_checked : Icons.radio_button_off, color: active ? theme.colorScheme.primary : Colors.white54, size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(child: Text(opt.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
                                              if (active)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text('Aktiv', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 11)),
                                                ),
                                            ]),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _withSpacing(List<Widget> children) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i != children.length - 1) spaced.add(const SizedBox(height: 8));
    }
    return spaced;
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: enabled ? 0.72 : 0.45), fontSize: 12)),
          ]),
        ),
        Switch.adaptive(value: value, onChanged: onChanged, activeColor: theme.colorScheme.primary),
      ]),
    );
  }
}