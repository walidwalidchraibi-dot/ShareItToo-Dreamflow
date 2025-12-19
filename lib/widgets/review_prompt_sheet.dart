import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lendify/models/multi_criteria_review.dart';
import 'package:lendify/services/data_service.dart';

class ReviewPromptSheet extends StatefulWidget {
  final String requestId;
  final String itemId;
  final String reviewerId;
  final String reviewedUserId;
  // 'renter_to_owner' or 'owner_to_renter'
  final String direction;
  const ReviewPromptSheet({super.key, required this.requestId, required this.itemId, required this.reviewerId, required this.reviewedUserId, required this.direction});

  static Future<bool?> show(BuildContext context, {
    required String requestId,
    required String itemId,
    required String reviewerId,
    required String reviewedUserId,
    required String direction,
  }) async {
    // Guard: do not allow double rating
    final already = await DataService.hasSubmittedReview(requestId: requestId, reviewerId: reviewerId);
    if (already) {
      return false;
    }
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.86),
      builder: (_) => ReviewPromptSheet(
        requestId: requestId,
        itemId: itemId,
        reviewerId: reviewerId,
        reviewedUserId: reviewedUserId,
        direction: direction,
      ),
    );
  }

  @override
  State<ReviewPromptSheet> createState() => _ReviewPromptSheetState();
}

class _ReviewPromptSheetState extends State<ReviewPromptSheet> {
  late List<_CriterionState> _criteria;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _criteria = _buildCriteriaFor(widget.direction);
  }

  List<_CriterionState> _buildCriteriaFor(String direction) {
    if (direction == 'renter_to_owner') {
      return [
        _CriterionState(key: 'communication', label: 'Kommunikation'),
        _CriterionState(key: 'condition_dropoff', label: 'Zustand des Artikels bei Abgabe'),
        _CriterionState(key: 'description_accuracy', label: 'Beschreibungstreue'),
        _CriterionState(key: 'reliability', label: 'Zuverlässigkeit'),
        _CriterionState(key: 'value_for_money', label: 'Preis-Leistung'),
        _CriterionState(key: 'process', label: 'Abgabe & Rückgabe-Prozess'),
      ];
    }
    return [
      _CriterionState(key: 'communication', label: 'Kommunikation'),
      _CriterionState(key: 'reliability', label: 'Zuverlässigkeit'),
      _CriterionState(key: 'condition_return', label: 'Zustand des Artikels bei Rückgabe'),
      _CriterionState(key: 'process', label: 'Abgabe & Rückgabe-Prozess'),
    ];
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final list = _criteria
          .map((c) => ReviewCriterion(key: c.key, stars: c.stars.clamp(1, 5), note: c.note.text.trim().isEmpty ? null : c.note.text.trim()))
          .toList();
      await DataService.addMultiReview(
        requestId: widget.requestId,
        itemId: widget.itemId,
        reviewerId: widget.reviewerId,
        reviewedUserId: widget.reviewedUserId,
        direction: widget.direction,
        criteria: list,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[reviews] submit failed: $e');
      if (!mounted) return;
      Navigator.of(context).pop(false);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.direction == 'renter_to_owner' ? 'Vermieter bewerten' : 'Mieter bewerten';
    final bg = Colors.black.withValues(alpha: 0.45);
    final border = Colors.white.withValues(alpha: 0.12);
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(color: bg, border: Border.all(color: border)),
              padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12 + MediaQuery.of(context).viewInsets.bottom),
              constraints: const BoxConstraints(maxWidth: 720),
              child: SafeArea(
                top: false,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Icon(Icons.star_rate_rounded, color: Color(0xFFFB923C)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
                    IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white70)),
                  ]),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(children: [
                        for (final c in _criteria) _CriterionTile(data: c),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
                        child: const Text('Später'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: const Icon(Icons.send_rounded),
                        label: Text(_submitting ? 'Sende…' : 'Bewertung senden'),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CriterionState {
  final String key;
  final String label;
  int stars;
  final TextEditingController note;
  _CriterionState({required this.key, required this.label, this.stars = 5}) : note = TextEditingController();
}

class _CriterionTile extends StatefulWidget {
  final _CriterionState data;
  const _CriterionTile({required this.data});
  @override
  State<_CriterionTile> createState() => _CriterionTileState();
}

class _CriterionTileState extends State<_CriterionTile> {
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(d.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Row(children: [
          for (int i = 1; i <= 5; i++)
            IconButton(
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => d.stars = i),
              icon: Icon(i <= d.stars ? Icons.star : Icons.star_border, color: const Color(0xFFFB923C)),
            ),
        ]),
        const SizedBox(height: 4),
        TextField(
          controller: d.note,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Kommentar (optional)',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ]),
    );
  }
}
