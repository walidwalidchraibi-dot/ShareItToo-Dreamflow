import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:lendify/models/user.dart';
import 'package:lendify/services/backend_config.dart';
import 'package:lendify/services/backend_repository.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/qa_runtime_service.dart';
import 'package:lendify/services/user_reports_service.dart';
import 'package:lendify/widgets/user_avatar.dart';
import 'package:lendify/widgets/app_popup.dart';

enum ReportReason {
  inappropriate,
  fraud,
  harassment,
  handover,
  other,
}

class ReportUserScreen extends StatefulWidget {
  final String? reportedUserId;
  final String? reference;

  const ReportUserScreen({super.key, this.reportedUserId, this.reference});

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  bool _loading = true;
  bool _submitting = false;
  bool _uploadingEvidence = false;
  bool _success = false;
  bool _successWasHarassment = false;
  bool _successHasActiveBlock = false;

  User? _reportedUser;
  User? _currentUser;

  ReportReason? _reason;
  bool? _immediateDanger;
  final String _harassmentIdempotencyKey =
      'harassment_${DateTime.now().microsecondsSinceEpoch}';
  final TextEditingController _detailsController = TextEditingController();
  final List<_ReportEvidence> _evidence = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await DataService.getCurrentUser();
      final users = await DataService.getUsers();
      final reportedId = (widget.reportedUserId?.trim().isNotEmpty ?? false)
          ? widget.reportedUserId!.trim()
          : users
              .where((u) => u.id != me?.id)
              .map((u) => u.id)
              .cast<String?>()
              .firstOrNull;
      final reported =
          reportedId == null ? null : await DataService.getUserById(reportedId);

      if (!mounted) return;
      setState(() {
        _currentUser = me;
        _reportedUser = reported;
      });
    } catch (e) {
      debugPrint('[ReportUserScreen] _load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _reasonLabel(ReportReason r) => switch (r) {
        ReportReason.inappropriate => 'Unangemessenes Verhalten',
        ReportReason.fraud => 'Betrug / Täuschung',
        ReportReason.harassment => 'Beleidigung / Belästigung',
        ReportReason.handover => 'Problem bei Übergabe',
        ReportReason.other => 'Sonstiges',
      };

  String _reasonCode(ReportReason r) => switch (r) {
        ReportReason.inappropriate => 'inappropriate_behavior',
        ReportReason.fraud => 'fraud_or_deception',
        ReportReason.harassment => 'harassment',
        ReportReason.handover => 'handover_problem',
        ReportReason.other => 'other',
      };

  IconData _reasonIcon(ReportReason r) => switch (r) {
        ReportReason.inappropriate => Icons.warning_amber,
        ReportReason.fraud => Icons.policy,
        ReportReason.harassment => Icons.do_not_disturb_on,
        ReportReason.handover => Icons.handshake,
        ReportReason.other => Icons.more_horiz,
      };

  Future<void> _addEvidence() async {
    if (_uploadingEvidence || _evidence.length >= 8) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return;
    setState(() => _uploadingEvidence = true);
    try {
      String? uploadId;
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        final upload = await BackendRepository.uploadReportEvidence(
          bytes: await picked.readAsBytes(),
          filename: picked.name,
        );
        uploadId = upload['id']?.toString();
        if ((uploadId ?? '').isEmpty) throw StateError('Missing upload id');
      }
      if (!mounted) return;
      setState(() => _evidence
          .add(_ReportEvidence(name: picked.name, uploadId: uploadId)));
    } catch (e) {
      debugPrint('[ReportUserScreen] evidence upload failed: $e');
      if (mounted) {
        AppPopup.error(
          context,
          title: 'Beweis nicht hochgeladen',
          message: 'Bitte prüfe die Datei und versuche es erneut.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingEvidence = false);
    }
  }

  Future<void> _submit() async {
    final reported = _reportedUser;
    final me = _currentUser;
    final reason = _reason;
    if (reported == null || me == null || reason == null) return;
    if (reason == ReportReason.harassment && _immediateDanger != false) return;

    setState(() => _submitting = true);
    try {
      final evidenceNames = _evidence.map((entry) => entry.name).toList();
      final evidenceUploadIds =
          _evidence.map((entry) => entry.uploadId).whereType<String>().toList();
      var harassmentBlockActive = false;
      if (reason == ReportReason.harassment) {
        harassmentBlockActive =
            await UserReportsService.addHarassmentBlockReport(
          reporterUserId: me.id,
          reportedUserId: reported.id,
          immediateDanger: false,
          idempotencyKey: _harassmentIdempotencyKey,
          details: _detailsController.text.trim(),
          evidenceNames: evidenceNames,
          evidenceUploadIds: evidenceUploadIds,
          reference: widget.reference,
        );
      } else {
        await UserReportsService.addReport(
          reporterUserId: me.id,
          reportedUserId: reported.id,
          reasonCode: _reasonCode(reason),
          details: _detailsController.text.trim(),
          evidenceNames: evidenceNames,
          evidenceUploadIds: evidenceUploadIds,
          reference: widget.reference,
        );
      }
      if (!mounted) return;
      setState(() {
        _success = true;
        _successWasHarassment = reason == ReportReason.harassment;
        _successHasActiveBlock = harassmentBlockActive;
      });
    } catch (e) {
      debugPrint('[ReportUserScreen] submit failed: $e');
      if (!mounted) return;
      AppPopup.error(
        context,
        title: 'Meldung nicht gesendet',
        message: 'Bitte versuche es erneut.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back)),
        title: const Text('Nutzer melden'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator()))
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _success
                    ? _ReportSuccess(
                        protectedByBlock: _successWasHarassment,
                        directContactBlocked: _successHasActiveBlock,
                        onDone: () => Navigator.of(context).maybePop(true))
                    : SingleChildScrollView(
                        key: const ValueKey('form'),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ReportedUserCard(
                                  user: _reportedUser,
                                  reference: widget.reference),
                              const SizedBox(height: 16),
                              _Section(
                                title: 'Grund',
                                child: Column(
                                  children: [
                                    for (final r in ReportReason.values) ...[
                                      _ReasonTile(
                                        icon: _reasonIcon(r),
                                        title: _reasonLabel(r),
                                        selected: _reason == r,
                                        onTap: () => setState(() {
                                          _reason = r;
                                          _immediateDanger = null;
                                        }),
                                      ),
                                      if (r != ReportReason.values.last)
                                        const SizedBox(height: 10),
                                    ],
                                  ],
                                ),
                              ),
                              if (_reason == ReportReason.harassment) ...[
                                const SizedBox(height: 16),
                                _Section(
                                  title: 'Besteht unmittelbare Gefahr?',
                                  child: Column(children: [
                                    RadioGroup<bool>(
                                      groupValue: _immediateDanger,
                                      onChanged: (value) => setState(
                                          () => _immediateDanger = value),
                                      child: const Column(children: [
                                        RadioListTile<bool>(
                                          key: ValueKey('harassment-non-acute'),
                                          value: false,
                                          title: Text(
                                              'Nein, keine unmittelbare Gefahr'),
                                          subtitle: Text(
                                              'Die Person wird blockiert und die Meldung neutral geprüft.'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        RadioListTile<bool>(
                                          key: ValueKey(
                                              'harassment-immediate-danger'),
                                          value: true,
                                          title: Text('Ja oder unsicher'),
                                          subtitle: Text(
                                              'Nutze den unmittelbaren Sicherheitsweg.'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ]),
                                    ),
                                    if (_immediateDanger == true)
                                      Container(
                                        key: const ValueKey(
                                            'immediate-danger-guidance'),
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.red
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.red
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: const Text(
                                          'Beende den Kontakt und bringe dich in Sicherheit. '
                                          'Rufe bei unmittelbarer Gefahr 110 oder 112. '
                                          'SIT ist kein Notfalldienst; sende diesen akuten Fall nicht über dieses Formular.',
                                        ),
                                      ),
                                  ]),
                                ),
                              ],
                              const SizedBox(height: 16),
                              _Section(
                                title: 'Zusätzliche Details (optional)',
                                child: _DetailsField(
                                    controller: _detailsController),
                              ),
                              const SizedBox(height: 16),
                              _Section(
                                title: 'Beweise (optional)',
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Füge Screenshots oder Fotos hinzu, um deine Meldung zu unterstützen.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: Colors.white70,
                                                height: 1.4),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          for (final evidence in _evidence)
                                            _EvidenceChip(
                                              name: evidence.name,
                                              onRemove: () => setState(() =>
                                                  _evidence.remove(evidence)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        height: 46,
                                        child: OutlinedButton.icon(
                                          onPressed: (_uploadingEvidence ||
                                                  _evidence.length >= 8)
                                              ? null
                                              : _addEvidence,
                                          style: OutlinedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16))),
                                          icon: _uploadingEvidence
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2))
                                              : Icon(Icons.add_photo_alternate,
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.92),
                                                  size: 18),
                                          label: Text(_uploadingEvidence
                                              ? 'Wird sicher hochgeladen…'
                                              : 'Beweise hinzufügen'),
                                        ),
                                      ),
                                    ]),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: (_reason == null ||
                                          _submitting ||
                                          _reportedUser == null ||
                                          _currentUser == null ||
                                          (_reason == ReportReason.harassment &&
                                              _immediateDanger != false))
                                      ? null
                                      : _submit,
                                  style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18))),
                                  child: _submitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : Text(_reason == ReportReason.harassment
                                          ? 'Blockieren und melden'
                                          : 'Meldung senden'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Deine Meldung wird vertraulich behandelt und von unserem Team geprüft.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white70, height: 1.4),
                              ),
                            ]),
                      ),
              ),
      ),
    );
  }
}

class _ReportEvidence {
  final String name;
  final String? uploadId;

  const _ReportEvidence({required this.name, this.uploadId});
}

class _ReportedUserCard extends StatelessWidget {
  final User? user;
  final String? reference;
  const _ReportedUserCard({required this.user, this.reference});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = user;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(children: [
        SitUserAvatar(url: u?.photoURL, radius: 22),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u?.displayName ?? 'Unbekannter Nutzer',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              reference?.trim().isNotEmpty == true
                  ? reference!.trim()
                  : 'Meldung zu Chat/Übergabe (optional)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.white70, height: 1.35),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  const _ReasonTile(
      {required this.icon,
      required this.title,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.60)
        : Colors.white.withValues(alpha: 0.10);
    final tint = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.04);

    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border)),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10))),
              child: Icon(icon,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
                  size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w800))),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    selected ? theme.colorScheme.primary : Colors.transparent,
                border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : Colors.white.withValues(alpha: 0.28),
                    width: 2),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DetailsField extends StatelessWidget {
  final TextEditingController controller;
  const _DetailsField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      minLines: 4,
      maxLines: 8,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: 'Beschreibe das Problem (optional)',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.65))),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      ),
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;
  const _EvidenceChip({required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.image_outlined, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRemove,
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.close, size: 16, color: Colors.white70),
          ),
        ),
      ]),
    );
  }
}

class _ReportSuccess extends StatelessWidget {
  final VoidCallback onDone;
  final bool protectedByBlock;
  final bool directContactBlocked;
  const _ReportSuccess({
    required this.onDone,
    required this.protectedByBlock,
    required this.directContactBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Center(
      key: const ValueKey('success'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 40, 18, 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.22)),
                      ),
                      child: Icon(Icons.verified,
                          color: accent.withValues(alpha: 0.95), size: 26),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Meldung gesendet',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    protectedByBlock && directContactBlocked
                        ? 'Die Person ist für direkten Kontakt blockiert. '
                            'Die Meldung bleibt für eine neutrale Prüfung offen; '
                            'damit ist noch kein Verstoß und keine Schuld festgestellt.'
                        : protectedByBlock
                            ? 'Die Meldung bleibt für eine neutrale Prüfung offen. '
                                'Der Kontaktblock ist aktuell nicht aktiv; damit ist '
                                'noch kein Verstoß und keine Schuld festgestellt.'
                            : 'Vielen Dank. Wir prüfen den Fall und kümmern uns darum.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onDone,
                      style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18))),
                      child: const Text('Fertig'),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
