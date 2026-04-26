import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:image_picker/image_picker.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/message.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/handover_code.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/brand_logo_icon.dart';
import 'package:lendify/widgets/modern_datetime_stepper_sheet.dart';
import 'package:lendify/widgets/return_handover_stepper_sheet.dart';
import 'package:lendify/widgets/user_avatar.dart';

/// Chat detail screen (Communication Hub).
///
/// - Fully data-driven: thread, users, item, and booking state are loaded from local storage.
/// - Shows a sticky action bar based on booking state.
/// - Renders system messages + inline handover/return cards.
class MessageThreadScreen extends StatefulWidget {
  /// Preferred identifier. If null, we try to resolve via [requestId].
  final String? threadId;

  /// Optional deep-link when opened from booking context.
  final String? requestId;

  /// Legacy/override (kept for backward compatibility). The UI will prefer live user/thread data.
  final String? participantName;
  final String? avatarUrl;
  final String? itemTitle;

  const MessageThreadScreen({
    super.key,
    this.threadId,
    this.requestId,
    this.participantName,
    this.avatarUrl,
    this.itemTitle,
  });

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

enum _ChatState { requestOpen, confirmed, running, returnPlanned, completed, support }

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _listController = ScrollController();

  bool _isLoading = true;
  User? _currentUser;
  MessageThread? _thread;
  User? _otherUser;
  Item? _item;
  RentalRequest? _request;
  Map<String, dynamic> _handoverReturnState = const {};

  bool _isAtBottom = true;
  bool _showJumpToBottom = false;
  double _lastViewInsetBottom = 0;

  // Keep these sizes centralized to make the composer compact without breaking touch targets.
  static const double _composerIconSize = 20;
  static const double _composerButtonSize = 38;
  static const double _composerSendButtonSize = 44;
  static const double _composerCornerRadius = 14;
  static const double _composerFieldRadius = 18;

  @override
  void initState() {
    super.initState();
    _load();
    _listController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final me = await DataService.getCurrentUser();
      if (me == null) {
        if (!mounted) return;
        setState(() {
          _currentUser = null;
          _isLoading = false;
        });
        return;
      }

      MessageThread? thread;
      if ((widget.threadId ?? '').trim().isNotEmpty) {
        thread = await DataService.getMessageThreadById(widget.threadId!.trim());
      }
      if (thread == null && (widget.requestId ?? '').trim().isNotEmpty) {
        thread = await DataService.createOrGetThreadForRequest(widget.requestId!.trim());
      }

      RentalRequest? request;
      if (thread != null) {
        request = await DataService.getRentalRequestById(thread.requestId);
      } else if ((widget.requestId ?? '').trim().isNotEmpty) {
        request = await DataService.getRentalRequestById(widget.requestId!.trim());
      }

      Item? item;
      if (thread != null) {
        item = await DataService.getItemById(thread.itemId);
      } else if (request != null) {
        item = await DataService.getItemById(request.itemId);
      }

      User? other;
      if (thread != null) {
        final otherId = thread.user1Id == me.id ? thread.user2Id : thread.user1Id;
        other = await DataService.getUserById(otherId);
      }

      Map<String, dynamic> hr = const {};
      final reqId = request?.id ?? thread?.requestId;
      if (reqId != null && reqId.isNotEmpty) {
        hr = await DataService.getHandoverReturnState(reqId);
      }

      if (!mounted) return;
      setState(() {
        _currentUser = me;
        _thread = thread;
        _request = request;
        _item = item;
        _otherUser = other;
        _handoverReturnState = hr;
        _isLoading = false;
      });

      // Mark as read + initial scroll.
      if (thread != null) {
        await DataService.markThreadMessagesAsRead(threadId: thread.id, userId: me.id);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      debugPrint('[MessageThreadScreen] _load failed: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  _ChatState _deriveChatState() {
    final t = _thread;
    final r = _request;
    final isSupport = ((t?.threadType ?? '').toLowerCase() == 'support') || (t?.user1Id == 'support') || (t?.user2Id == 'support');
    if (isSupport) return _ChatState.support;

    final raw = (r?.status ?? t?.bookingStatus ?? '').toLowerCase().trim();
    final returnActive = _handoverReturnState['returnActive'] == true;
    switch (raw) {
      case 'pending':
        return _ChatState.requestOpen;
      case 'accepted':
        return _ChatState.confirmed;
      case 'running':
        return returnActive ? _ChatState.returnPlanned : _ChatState.running;
      case 'completed':
      case 'declined':
      case 'cancelled':
        return _ChatState.completed;
      default:
        // For demo threads without a backing request.
        if (returnActive) return _ChatState.returnPlanned;
        return _ChatState.confirmed;
    }
  }

  ({String label, Color bg, Color fg}) _statusBadge(_ChatState st) {
    final cs = Theme.of(context).colorScheme;
    switch (st) {
      case _ChatState.requestOpen:
        return (label: 'Anfrage offen', bg: BrandColors.logoAccent.withValues(alpha: 0.18), fg: Colors.white);
      case _ChatState.confirmed:
        return (label: 'Bestätigt', bg: cs.primary.withValues(alpha: 0.22), fg: Colors.white);
      case _ChatState.running:
        return (label: 'Laufend', bg: BrandColors.success.withValues(alpha: 0.22), fg: Colors.white);
      case _ChatState.returnPlanned:
        return (label: 'Rückgabe geplant', bg: BrandColors.primary.withValues(alpha: 0.18), fg: Colors.white);
      case _ChatState.completed:
        return (label: 'Abgeschlossen', bg: Colors.white.withValues(alpha: 0.10), fg: Colors.white);
      case _ChatState.support:
        return (label: 'Support', bg: cs.primary.withValues(alpha: 0.22), fg: Colors.white);
    }
  }

  String _displayName() => _otherUser?.displayName ?? (widget.participantName?.trim().isNotEmpty == true ? widget.participantName!.trim() : 'Chat');

  String _itemTitle() {
    final t = _thread;
    final i = _item;
    if (i != null) return i.title;
    if (t != null && t.itemTitle.trim().isNotEmpty) return t.itemTitle.trim();
    if (widget.itemTitle?.trim().isNotEmpty == true) return widget.itemTitle!.trim();
    return '';
  }

  String? _avatarUrl() {
    final u = _otherUser;
    final url = u?.photoURL ?? widget.avatarUrl;
    if (url == null) return null;
    final v = url.trim();
    return v.isEmpty ? null : v;
  }

  bool _viewerIsOwner() {
    final me = _currentUser;
    final r = _request;
    if (me == null || r == null) return false;
    return r.ownerId == me.id;
  }

  bool _canStartHandover(RentalRequest? request) {
    if (request == null) return false;
    final status = request.status.toLowerCase().trim();
    final handoverActive = _handoverReturnState['handoverActive'] == true;
    return status == 'accepted' && !handoverActive;
  }

  bool _canStartReturn(RentalRequest? request) {
    if (request == null) return false;
    final status = request.status.toLowerCase().trim();
    final returnActive = _handoverReturnState['returnActive'] == true;
    return status == 'running' && !returnActive;
  }

  Future<void> _applyPrimaryAction() async {
    final st = _deriveChatState();
    final me = _currentUser;
    final t = _thread;
    final r = _request;
    if (me == null || t == null) return;

    try {
      switch (st) {
        case _ChatState.requestOpen:
          if (r == null) {
            await _acceptRequestWithThreadSideEffects(threadId: t.id);
          } else {
            if (!_viewerIsOwner()) return;
            await _acceptRequestWithThreadSideEffects(
              threadId: t.id,
              requestId: r.id,
            );
          }
          break;
        case _ChatState.confirmed:
          if (!_canStartHandover(r)) {
            if (mounted) {
              AppPopup.toast(context, icon: Icons.info_outline, title: 'Übergabe ist gerade nicht verfügbar');
            }
            return;
          }
          final handoverRequest = r!;
          await _startHandoverWithThreadSideEffects(
            threadId: t.id,
            requestId: handoverRequest.id,
          );
          break;
        case _ChatState.running:
        case _ChatState.returnPlanned:
          if (!_canStartReturn(r)) {
            if (mounted) {
              AppPopup.toast(context, icon: Icons.info_outline, title: 'Rückgabe ist gerade nicht verfügbar');
            }
            return;
          }
          final returnRequest = r!;
          await _startReturnWithThreadSideEffects(
            threadId: t.id,
            requestId: returnRequest.id,
          );
          break;
        case _ChatState.completed:
          // Bewertung abgeben (demo flow)
          await AppPopup.toast(context, icon: Icons.star_outline, title: 'Bewertung (Demo)', message: 'Bewertungs-Flow ist als nächster Schritt vorgesehen.');
          break;
        case _ChatState.support:
          return;
      }
    } catch (e) {
      debugPrint('[MessageThreadScreen] _applyPrimaryAction failed: $e');
      if (mounted) {
        AppPopup.toast(context, icon: Icons.error_outline, title: 'Aktion fehlgeschlagen');
      }
    } finally {
      await _load();
    }
  }

  Future<void> _applySecondaryAction() async {
    final st = _deriveChatState();
    final me = _currentUser;
    final t = _thread;
    final r = _request;
    if (me == null || t == null) return;
    if (st != _ChatState.requestOpen) return;
    if (r != null && !_viewerIsOwner()) return;

    try {
      if (r == null) {
        await _declineRequestWithThreadSideEffects(threadId: t.id);
      } else {
        await _declineRequestWithThreadSideEffects(
          threadId: t.id,
          requestId: r.id,
        );
      }
    } catch (e) {
      debugPrint('[MessageThreadScreen] _applySecondaryAction failed: $e');
    } finally {
      await _load();
    }
  }

  Future<void> _startReturnWithThreadSideEffects({
    required String threadId,
    required String requestId,
  }) async {
    await DataService.setReturnActive(requestId, active: true);
    await DataService.addSystemMessageToThread(threadId: threadId, text: 'Rückgabe gestartet');
  }

  Future<void> _startHandoverWithThreadSideEffects({
    required String threadId,
    required String requestId,
  }) async {
    await DataService.setHandoverActive(requestId, active: true);
    await DataService.addSystemMessageToThread(threadId: threadId, text: 'Übergabe gestartet');
  }

  Future<void> _acceptRequestWithThreadSideEffects({
    required String threadId,
    String? requestId,
  }) async {
    if (requestId != null) {
      await DataService.updateRentalRequestStatus(requestId: requestId, status: 'accepted');
    }
    await DataService.updateMessageThreadBookingStatus(threadId: threadId, status: 'accepted');
    await DataService.addSystemMessageToThread(threadId: threadId, text: 'Anfrage angenommen');
  }

  Future<void> _declineRequestWithThreadSideEffects({
    required String threadId,
    String? requestId,
  }) async {
    if (requestId != null) {
      await DataService.updateRentalRequestStatus(requestId: requestId, status: 'declined');
    }
    await DataService.updateMessageThreadBookingStatus(threadId: threadId, status: 'declined');
    await DataService.addSystemMessageToThread(threadId: threadId, text: 'Anfrage abgelehnt');
  }

  ({String primary, String? secondary}) _actionLabels(_ChatState st) {
    switch (st) {
      case _ChatState.requestOpen:
        return (primary: 'Annehmen', secondary: 'Ablehnen');
      case _ChatState.confirmed:
        return (primary: 'Übergabe starten', secondary: null);
      case _ChatState.running:
      case _ChatState.returnPlanned:
        return (primary: 'Rückgabe starten', secondary: null);
      case _ChatState.completed:
        return (primary: 'Bewertung abgeben', secondary: null);
      case _ChatState.support:
        return (primary: '', secondary: null);
    }
  }

  bool _shouldShowActions(_ChatState st) {
    if (st == _ChatState.support) return false;
    if (st == _ChatState.requestOpen && !_viewerIsOwner()) return false;
    return true;
  }

  Future<void> _sendText() async {
    final me = _currentUser;
    final t = _thread;
    final text = _controller.text.trim();
    if (me == null || t == null || text.isEmpty) return;
    _controller.clear();
    try {
      await DataService.addMessageToThread(threadId: t.id, senderId: me.id, text: text);
      await _load();
      _scrollToBottom(animate: true);
    } catch (e) {
      debugPrint('[MessageThreadScreen] _sendText failed: $e');
      if (mounted) AppPopup.toast(context, icon: Icons.error_outline, title: 'Fehler beim Senden');
    }
  }

  Future<void> _pickCamera() async {
    final t = _thread;
    if (t == null) return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 82);
      if (file == null) return;
      await DataService.addSystemMessageToThread(threadId: t.id, text: 'Foto hinzugefügt');
      // Update inline progress when a handover/return is active.
      final reqId = _request?.id;
      if (reqId != null && reqId.isNotEmpty) {
        final handoverActive = _handoverReturnState['handoverActive'] == true;
        final returnActive = _handoverReturnState['returnActive'] == true;
        if (handoverActive) await DataService.incrementHandoverPhotos(reqId);
        if (returnActive) await DataService.incrementReturnPhotos(reqId);
      }
      await _load();
      _scrollToBottom(animate: true);
    } catch (e) {
      debugPrint('[MessageThreadScreen] _pickCamera failed: $e');
      if (mounted) AppPopup.toast(context, icon: Icons.error_outline, title: 'Kamera nicht verfügbar');
    }
  }

  Future<void> _pickFile() async {
    final t = _thread;
    if (t == null) return;
    try {
      final result = await FilePicker.platform.pickFiles(withData: false);
      if (result == null || result.files.isEmpty) return;
      final name = result.files.first.name;
      await DataService.addSystemMessageToThread(threadId: t.id, text: 'Anhang hinzugefügt: $name');
      await _load();
      _scrollToBottom(animate: true);
    } catch (e) {
      debugPrint('[MessageThreadScreen] _pickFile failed: $e');
      if (mounted) AppPopup.toast(context, icon: Icons.error_outline, title: 'Anhang nicht verfügbar');
    }
  }

  Future<void> _addPhotosInline() async {
    final r = _request;
    if (r == null) return;

    // If the full stepper is available (handover/return flow), prefer it.
    try {
      final item = _item;
      final other = _otherUser;
      final me = _currentUser;
      if (item != null && other != null && me != null) {
        final mode = (_handoverReturnState['handoverActive'] == true)
            ? ReturnFlowMode.pickupFlow
            : ReturnFlowMode.returnFlow;
        final bookingSeed = _computeBookingSeed(item, r);
        final segment = mode == ReturnFlowMode.returnFlow ? HandoverCodeService.segmentReturn : HandoverCodeService.segmentPickup;
        final presenterRole = mode == ReturnFlowMode.returnFlow ? HandoverCodeService.presenterRenter : HandoverCodeService.presenterOwner;
        final confirmationCode = HandoverCodeService.codeForTitleAndStart(
          title: item.title,
          start: r.start,
          bookingId: bookingSeed,
          segment: segment,
          presenterRole: presenterRole,
        );
        final ok = await ReturnHandoverStepperSheet.push(
          context,
          item: item,
          request: r,
          renterName: (_viewerIsOwner() ? other.displayName : me.displayName),
          ownerName: (_viewerIsOwner() ? me.displayName : other.displayName),
          handoverCode: confirmationCode,
          viewerIsOwner: _viewerIsOwner(),
          mode: mode,
        );
        if (ok?.confirmed == true) {
          // Treat as completing 4/4 photos in the active segment.
          if (_handoverReturnState['handoverActive'] == true) {
            for (int i = 0; i < 4; i++) {
              await DataService.incrementHandoverPhotos(r.id);
            }
            if (ok?.galleryUsed == true) {
              await DataService.markHandoverGalleryUsed(r.id);
            }
          }
          if (_handoverReturnState['returnActive'] == true) {
            for (int i = 0; i < 4; i++) {
              await DataService.incrementReturnPhotos(r.id);
            }
            if (ok?.galleryUsed == true) {
              await DataService.markReturnGalleryUsed(r.id);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[MessageThreadScreen] ReturnHandoverStepperSheet failed: $e');
    } finally {
      await _load();
    }
  }

  bool _showAddressHint() {
    final r = _request;
    if (r == null) return false;
    // If there's no address snapshot yet, warn about time-based address release.
    final hasAddress = (r.deliveryAddressLine ?? '').trim().isNotEmpty || (r.deliveryCity ?? '').trim().isNotEmpty;
    if (hasAddress) return false;

    // Only relevant for non-terminal booking states.
    final st = _deriveChatState();
    if (st == _ChatState.completed || st == _ChatState.support) return false;

    // Release window example: 6h before handover.
    final revealAt = r.start.subtract(const Duration(hours: 6));
    return DateTime.now().isBefore(revealAt);
  }

  String _addressHintText() {
    final r = _request;
    if (r == null) return '';
    final revealAt = r.start.subtract(const Duration(hours: 6));
    final minutes = revealAt.difference(DateTime.now()).inMinutes;
    if (minutes <= 0) return 'Hinweis: Die Adresse wird in Kürze freigegeben.';
    final hours = (minutes / 60).ceil();
    return 'Hinweis zur Adressfreigabe: Die genaue Adresse wird automatisch ca. $hours h vor der Übergabe angezeigt.';
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    if (insets != _lastViewInsetBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final opened = insets > 0 && _lastViewInsetBottom == 0;
        _lastViewInsetBottom = insets;
        if (opened && _isAtBottom) _scrollToBottom(animate: true);
      });
    }

    final st = _deriveChatState();
    final isSupport = st == _ChatState.support;
    final badge = _statusBadge(st);
    final actionLabels = _actionLabels(st);
    final messages = _thread?.messages ?? const <Message>[];
    final showActions = _shouldShowActions(st);
    final showAddressHint = _showAddressHint();

    final handoverActive = _handoverReturnState['handoverActive'] == true;
    final returnActive = _handoverReturnState['returnActive'] == true;
    final showInlineFlowCard = (handoverActive || returnActive) && (_request != null);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _ThreadHeader(
        isSupport: isSupport,
        avatarUrl: _avatarUrl(),
        title: isSupport ? 'SIT Support' : _displayName(),
        subtitle: isSupport ? 'Hilfe & Sicherheit' : _itemTitle(),
        verified: isSupport ? true : (_otherUser?.isVerified ?? false),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                if (!isSupport) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: _BookingInfoCard(
                      itemTitle: _itemTitle(),
                      request: _request,
                      statusLabel: badge.label,
                      statusBg: badge.bg,
                      statusFg: badge.fg,
                      showAddressPrivacyNote: showAddressHint,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: const _TrustBanner(),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (messages.isEmpty && !showAddressHint && !showInlineFlowCard)
                          ? const Center(child: Text('Noch keine Nachrichten', style: TextStyle(color: Colors.white70)))
                          : NotificationListener<UserScrollNotification>(
                              onNotification: (n) {
                                if (n.direction == ScrollDirection.forward && _inputFocus.hasFocus) {
                                  FocusScope.of(context).unfocus();
                                }
                                return false;
                              },
                              child: ListView.builder(
                                controller: _listController,
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                                itemCount: _tipCardsCount(st: st) + messages.length + (showAddressHint ? 1 : 0) + (showInlineFlowCard ? 1 : 0),
                                itemBuilder: (context, index) {
                                  int i = index;

                                  final tipCount = _tipCardsCount(st: st);
                                  if (i < tipCount) {
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: i == tipCount - 1 ? 10 : 8),
                                      child: _InlineSystemCard(icon: _tipIcon(i), text: _tipText(i, st: st)),
                                    );
                                  }
                                  i -= tipCount;

                                  if (showAddressHint) {
                                    if (i == 0) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _InlineSystemCard(icon: Icons.lock_outline, text: _addressHintText()),
                                      );
                                    }
                                    i -= 1;
                                  }

                                  if (i < messages.length) {
                                    final m = messages[i];
                                    final isMe = m.senderId == _currentUser?.id;
                                    final isSystem = m.senderId == 'system';
                                    return _AnimatedMessageEntry(
                                      key: ValueKey('msg_${m.id}'),
                                      child: isSystem
                                          ? _SystemMessage(text: m.text)
                                          : _AvatarMessageRow(
                                              isMe: isMe,
                                              avatarUrl: isMe ? _currentUser?.photoURL : _avatarUrl(),
                                              child: _ChatBubble(
                                                text: m.text,
                                                me: isMe,
                                                time: _formatTime(m.timestamp),
                                              ),
                                            ),
                                    );
                                  }
                                  i -= messages.length;
                                  if (showInlineFlowCard && i == 0) {
                                    final maxPhotos = 4;
                                    final photoCount = handoverActive
                                        ? ((_handoverReturnState['handoverPhotos'] as int?) ?? 0)
                                        : ((_handoverReturnState['returnPhotos'] as int?) ?? 0);
                                    final statusText = handoverActive ? 'Übergabe läuft' : 'Rückgabe läuft';
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: _FlowProgressCard(
                                        title: statusText,
                                        progressLabel: 'Fotos ${photoCount.clamp(0, maxPhotos)}/$maxPhotos',
                                        progress: (photoCount / maxPhotos).clamp(0.0, 1.0),
                                        onAddPhotos: _addPhotosInline,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                ),
                _TransactionComposer(
                  showActions: showActions,
                  primaryLabel: showActions ? actionLabels.primary : null,
                  secondaryLabel: showActions ? actionLabels.secondary : null,
                  onPrimary: showActions ? _applyPrimaryAction : null,
                  onSecondary: (showActions && actionLabels.secondary != null) ? _applySecondaryAction : null,
                  explanationText: _actionExplanation(st),
                  onShareLocation: _shareLocation,
                  onSendPhoto: _pickCamera,
                  onChangeTime: _changeTime,
                  controller: _controller,
                  focusNode: _inputFocus,
                  onSend: _sendText,
                  iconSize: _composerIconSize,
                  buttonSize: _composerButtonSize,
                  sendButtonSize: _composerSendButtonSize,
                  cornerRadius: _composerCornerRadius,
                  fieldRadius: _composerFieldRadius,
                ),
              ],
            ),
            if (_showJumpToBottom)
              Positioned(
                right: 16,
                bottom: (MediaQuery.of(context).viewInsets.bottom > 0 ? MediaQuery.of(context).viewInsets.bottom : 0) + 72,
                child: FloatingActionButton.small(
                  onPressed: () => _scrollToBottom(animate: true),
                  child: const Icon(Icons.arrow_downward),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onScroll() {
    if (!_listController.hasClients) return;
    final pos = _listController.position;
    final atBottomNow = pos.pixels >= (pos.maxScrollExtent - 8);
    if (atBottomNow != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottomNow;
        _showJumpToBottom = !atBottomNow;
      });
    }
  }

  void _scrollToBottom({bool animate = false}) {
    if (!_listController.hasClients) return;
    final max = _listController.position.maxScrollExtent;
    if (animate) {
      _listController.animateTo(max, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    } else {
      _listController.jumpTo(max);
    }
  }

  String _formatTime(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  int _tipCardsCount({required _ChatState st}) => st == _ChatState.support ? 0 : 3;

  IconData _tipIcon(int index) {
    if (_deriveChatState() == _ChatState.support) return Icons.support_agent_rounded;
    switch (index) {
      case 0:
        return Icons.verified_user_outlined;
      case 1:
        return Icons.schedule_rounded;
      default:
        return Icons.lock_outline;
    }
  }

  String _tipText(int index, {required _ChatState st}) {
    if (st == _ChatState.support) return '';
    switch (index) {
      case 0:
        return 'Tipp: Nutze den Chat für alle Absprachen — so sind Details zur Buchung dokumentiert.';
      case 1:
        return 'Tipp: Sei pünktlich. Bei Verspätung kurz Bescheid geben und neue Uhrzeit bestätigen.';
      default:
        return 'Tipp: Aus Sicherheitsgründen wird die genaue Adresse ggf. erst kurz vor der Übergabe sichtbar.';
    }
  }

  String _actionExplanation(_ChatState st) {
    switch (st) {
      case _ChatState.requestOpen:
        return 'Bestätige die Anfrage, um die Buchung zu starten. Ablehnen ist jederzeit möglich.';
      case _ChatState.confirmed:
        return 'Starte die Übergabe erst, wenn ihr euch trefft und alles geprüft ist.';
      case _ChatState.running:
      case _ChatState.returnPlanned:
        return 'Starte die Rückgabe, wenn der Artikel zurückgegeben wird (Fotos helfen bei Streitfällen).';
      case _ChatState.completed:
        return 'Teile eine kurze Bewertung — das stärkt Vertrauen in der Community.';
      case _ChatState.support:
        return '';
    }
  }

  String _deriveResponseTimeLabel({required List<Message> messages, required String? otherUserId}) {
    try {
      if (otherUserId == null || messages.isEmpty) return 'Antwortzeit: < 1h';
      final others = messages.where((m) => m.senderId == otherUserId).toList();
      if (others.isEmpty) return 'Antwortzeit: < 1h';
      others.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final last = others.last.timestamp;
      final mins = DateTime.now().difference(last).inMinutes;
      if (mins < 10) return 'Antwortzeit: aktiv';
      if (mins < 60) return 'Antwortzeit: ~${mins} min';
      final h = (mins / 60).round();
      return 'Antwortzeit: ~${h} h';
    } catch (_) {
      return 'Antwortzeit: < 1h';
    }
  }

  Future<void> _shareLocation() async {
    final t = _thread;
    final me = _currentUser;
    if (t == null || me == null) return;
    try {
      await DataService.addSystemMessageToThread(threadId: t.id, text: '${me.displayName} hat den Standort geteilt (Demo).');
      await _load();
      _scrollToBottom(animate: true);
    } catch (e) {
      debugPrint('[MessageThreadScreen] _shareLocation failed: $e');
    }
  }

  Future<void> _changeTime() async {
    final r = _request;
    final t = _thread;
    if (t == null) return;
    final range = await ModernDateTimeStepperSheet.show(context, initialStart: r?.start, initialEnd: r?.end);
    if (range == null) return;
    try {
      await DataService.addSystemMessageToThread(
        threadId: t.id,
        text: 'Zeitvorschlag: ${_formatDate(range.start)} – ${_formatDate(range.end)}',
      );
      await _load();
      _scrollToBottom(animate: true);
    } catch (e) {
      debugPrint('[MessageThreadScreen] _changeTime failed: $e');
    }
  }


  String _computeBookingSeed(Item item, RentalRequest req) {
    final seed = ((item.id.hashCode) ^ (req.id.hashCode) ^ (item.title.hashCode)).abs();
    final s = seed.toString().padLeft(8, '0');
    return 'BKG-${s.substring(0, 4)}-${s.substring(4, 8)}';
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $hh:$mm';
  }
}

class _ThreadHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool isSupport;
  final String? avatarUrl;
  final String title;
  final String subtitle;
  final bool verified;

  const _ThreadHeader({
    required this.isSupport,
    required this.avatarUrl,
    required this.title,
    required this.subtitle,
    required this.verified,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(true),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      titleSpacing: 8,
      title: Row(
        children: [
          _HeaderAvatar(isSupport: isSupport, avatarUrl: avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.verified_rounded, size: 16, color: BrandColors.success),
                    ],
                  ],
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.72), fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final bool isSupport;
  final String? avatarUrl;

  const _HeaderAvatar({required this.isSupport, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    if (!isSupport) {
      return SitUserAvatar(
        url: avatarUrl,
        radius: 16,
        borderColor: Colors.white.withValues(alpha: 0.16),
        placeholderIcon: Icons.person_outline,
      );
    }

    // Support: always show SIT symbol inside the avatar circle.
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.6),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: const Center(
        child: BrandLogoIcon(
          assetPath: 'assets/images/icononly_transparent_nobuffer.png',
          fallback: Icons.support_agent_rounded,
          fallbackColor: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 14),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontWeight: FontWeight.w800, fontSize: 11)),
        ],
      ),
    );
  }
}

class _BookingInfoCard extends StatelessWidget {
  final String itemTitle;
  final RentalRequest? request;
  final String statusLabel;
  final Color statusBg;
  final Color statusFg;
  final bool showAddressPrivacyNote;

  const _BookingInfoCard({
    required this.itemTitle,
    required this.request,
    required this.statusLabel,
    required this.statusBg,
    required this.statusFg,
    required this.showAddressPrivacyNote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    final dateText = (r == null)
        ? 'Zeit: nicht verfügbar'
        : '${_fmtDay(r.start)} · ${_fmtTime(r.start)} – ${_fmtTime(r.end)}';
    final locationLine = (r == null)
        ? 'Ort: Wird im Chat geklärt'
        : 'Ort: ${(r.deliveryCity ?? '').trim().isNotEmpty ? r.deliveryCity!.trim() : 'Wird im Chat geklärt'}';
    final privacyNote = showAddressPrivacyNote ? 'Genaue Adresse wird automatisch später freigegeben.' : 'Adressdaten sind geschützt.';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, color: Colors.white.withValues(alpha: 0.9), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      itemTitle.isEmpty ? 'Buchung' : itemTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _StatusBadge(label: statusLabel, bg: statusBg, fg: statusFg),
                ],
              ),
              const SizedBox(height: 10),
              _InfoRow(icon: Icons.event_outlined, text: dateText),
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.place_outlined, text: locationLine),
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.privacy_tip_outlined, text: privacyNote),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDay(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d.$m.${dt.year}';
  }

  String _fmtTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.78), size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.86), fontWeight: FontWeight.w700, height: 1.35))),
      ],
    );
  }
}

class _TrustBanner extends StatelessWidget {
  const _TrustBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.9), size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Zahlungsschutz aktiv: Zahlungen & Streitfälle werden über SIT abgesichert.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _StatusBadge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  const _ActionBar({required this.primaryLabel, required this.secondaryLabel, required this.onPrimary, required this.onSecondary});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              if (secondaryLabel != null) ...[
                Expanded(
                  child: _PressScale(
                    onTap: onSecondary,
                    child: _SITButton.secondary(label: secondaryLabel!, icon: Icons.close_rounded),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: secondaryLabel != null ? 2 : 1,
                child: _PressScale(
                  onTap: onPrimary,
                  child: _SITButton.primary(label: primaryLabel, icon: Icons.bolt_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SITButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  const _SITButton._({required this.label, required this.icon, required this.primary});

  factory _SITButton.primary({required String label, required IconData icon}) => _SITButton._(label: label, icon: icon, primary: true);
  factory _SITButton.secondary({required String label, required IconData icon}) => _SITButton._(label: label, icon: icon, primary: false);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = primary ? cs.primary : Colors.white.withValues(alpha: 0.08);
    final border = primary ? cs.primary.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.14);
    final fg = Colors.white;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _AnimatedMessageEntry extends StatelessWidget {
  final Widget child;
  const _AnimatedMessageEntry({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, v, _) {
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, (1 - v) * 8), child: child),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool me;
  final String time;
  const _ChatBubble({required this.text, required this.me, required this.time});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = me ? cs.primary.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.08);
    final border = Colors.white.withValues(alpha: me ? 0.10 : 0.12);
    final maxWidth = MediaQuery.of(context).size.width * 0.75;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 9),
          constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 64),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: const TextStyle(color: Colors.white, height: 1.35)),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(time, style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarMessageRow extends StatelessWidget {
  final bool isMe;
  final String? avatarUrl;
  final Widget child;
  const _AvatarMessageRow({required this.isMe, required this.avatarUrl, required this.child});

  @override
  Widget build(BuildContext context) {
    final avatar = SitUserAvatar(
      url: avatarUrl,
      radius: 12,
      borderColor: Colors.white.withValues(alpha: 0.12),
      placeholderIcon: Icons.person_outline,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            avatar,
            const SizedBox(width: 8),
          ],
          Flexible(child: child),
          if (isMe) ...[
            const SizedBox(width: 8),
            avatar,
          ],
        ],
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 12, fontWeight: FontWeight.w700, height: 1.35),
          ),
        ),
      ),
    );
  }
}

class _InlineSystemCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InlineSystemCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w700, height: 1.35)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowProgressCard extends StatelessWidget {
  final String title;
  final String progressLabel;
  final double progress;
  final VoidCallback onAddPhotos;
  const _FlowProgressCard({required this.title, required this.progressLabel, required this.progress, required this.onAddPhotos});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.fact_check_outlined, color: Colors.white.withValues(alpha: 0.9), size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
                  Text(progressLabel, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
              ),
              const SizedBox(height: 12),
              _PressScale(
                onTap: onAddPhotos,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.72)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_camera_outlined, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Fotos hinzufügen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
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
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onShareLocation;
  final VoidCallback onSendPhoto;
  final VoidCallback onChangeTime;
  final double iconSize;
  final double buttonSize;
  final double sendButtonSize;
  final double cornerRadius;
  final double fieldRadius;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onShareLocation,
    required this.onSendPhoto,
    required this.onChangeTime,
    required this.iconSize,
    required this.buttonSize,
    required this.sendButtonSize,
    required this.cornerRadius,
    required this.fieldRadius,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 2,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(color: Colors.white, height: 1.25),
                    decoration: InputDecoration(
                      hintText: 'Nachricht schreiben…',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontWeight: FontWeight.w600),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(fieldRadius), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(fieldRadius), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(fieldRadius), borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.9))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _PressScale(
                  onTap: onSend,
                  child: Container(
                    width: sendButtonSize,
                    height: sendButtonSize,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(cornerRadius + 2),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Center(child: Icon(Icons.send_rounded, color: Colors.white, size: iconSize)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ComposerIconButton(icon: Icons.my_location_rounded, label: 'Standort', onTap: onShareLocation),
                const SizedBox(width: 8),
                _ComposerIconButton(icon: Icons.photo_camera_outlined, label: 'Foto', onTap: onSendPhoto),
                const SizedBox(width: 8),
                _ComposerIconButton(icon: Icons.schedule_rounded, label: 'Zeit', onTap: onChangeTime),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ComposerIconButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: Semantics(
        label: label,
        button: true,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Center(child: Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 18)),
        ),
      ),
    );
  }
}

class _TransactionComposer extends StatelessWidget {
  final bool showActions;
  final String? primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final String explanationText;
  final VoidCallback onShareLocation;
  final VoidCallback onSendPhoto;
  final VoidCallback onChangeTime;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final double iconSize;
  final double buttonSize;
  final double sendButtonSize;
  final double cornerRadius;
  final double fieldRadius;

  const _TransactionComposer({
    required this.showActions,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    required this.explanationText,
    required this.onShareLocation,
    required this.onSendPhoto,
    required this.onChangeTime,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.iconSize,
    required this.buttonSize,
    required this.sendButtonSize,
    required this.cornerRadius,
    required this.fieldRadius,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showActions) ...[
                    _StickyTransactionCTA(
                      primaryLabel: primaryLabel ?? '',
                      secondaryLabel: secondaryLabel,
                      onPrimary: onPrimary,
                      onSecondary: onSecondary,
                      explanationText: explanationText,
                    ),
                    const SizedBox(height: 10),
                  ],
                  _InputBar(
                    controller: controller,
                    focusNode: focusNode,
                    onSend: onSend,
                    onShareLocation: onShareLocation,
                    onSendPhoto: onSendPhoto,
                    onChangeTime: onChangeTime,
                    iconSize: iconSize,
                    buttonSize: buttonSize,
                    sendButtonSize: sendButtonSize,
                    cornerRadius: cornerRadius,
                    fieldRadius: fieldRadius,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyTransactionCTA extends StatelessWidget {
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final String explanationText;

  const _StickyTransactionCTA({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    required this.explanationText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.handshake_outlined, size: 18, color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Transaktion',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w900),
                  ),
                ),
                if (secondaryLabel != null)
                  _PressScale(
                    onTap: onSecondary,
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Center(
                        child: Text(
                          secondaryLabel!,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _PressScale(
              onTap: onPrimary,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.72)]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        primaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (explanationText.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                explanationText,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontWeight: FontWeight.w700, height: 1.35, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

