import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/message.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/brand_logo_icon.dart';
import 'package:lendify/widgets/modern_datetime_stepper_sheet.dart';
import 'package:lendify/widgets/return_handover_stepper_sheet.dart';
import 'package:lendify/widgets/sit_glass_time_picker.dart';
import 'package:lendify/widgets/user_avatar.dart';
import 'package:lendify/screens/booking_detail_screen.dart';
import 'package:lendify/services/blocked_users_service.dart';
import 'package:lendify/screens/support_flow_screen.dart';
import 'package:lendify/screens/public_profile_screen.dart';

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

/// Ob der Chat aktiv ist (Nachrichten senden erlaubt)
/// Nur accepted/running erlaubt, alles andere ist gesperrt
bool _isChatActiveForState(_ChatState st) {
  switch (st) {
    case _ChatState.confirmed: // accepted
    case _ChatState.running:
    case _ChatState.returnPlanned:
      return true;
    case _ChatState.support:
      return true; // Support immer aktiv
    case _ChatState.requestOpen: // pending
    case _ChatState.completed: // completed/declined/cancelled
      return false;
  }
}

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
    _inputFocus.addListener(_onInputFocusChange);
  }
  
  void _onInputFocusChange() {
    if (_inputFocus.hasFocus && _isAtBottom) {
      // Kurze Verzögerung für Tastatur-Animation
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _scrollToBottom(animate: true);
      });
    }
  }

  @override
  void dispose() {
    _inputFocus.removeListener(_onInputFocusChange);
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
            await DataService.updateMessageThreadBookingStatus(threadId: t.id, status: 'accepted');
            await DataService.addSystemMessageToThread(threadId: t.id, text: 'Anfrage angenommen');
          } else {
            if (!_viewerIsOwner()) return;
            await DataService.updateRentalRequestStatus(requestId: r.id, status: 'accepted');
            await DataService.updateMessageThreadBookingStatus(threadId: t.id, status: 'accepted');
            await DataService.addSystemMessageToThread(threadId: t.id, text: 'Anfrage angenommen');
          }
          break;
        case _ChatState.confirmed:
          if (r == null) {
            AppPopup.toast(context, icon: Icons.error_outline, title: 'Übergabe-Daten fehlen');
            break;
          }
          await DataService.setHandoverActive(r.id, active: true);
          await DataService.addSystemMessageToThread(threadId: t.id, text: 'Übergabe gestartet');
          if (mounted) {
            AppPopup.toast(context, icon: Icons.qr_code_2, title: 'Übergabe gestartet', message: 'Bestätige die Übergabe jetzt im Buchungsdetail per QR-Code oder manuellem Code.');
          }
          break;
        case _ChatState.running:
        case _ChatState.returnPlanned:
          if (r == null) {
            AppPopup.toast(context, icon: Icons.error_outline, title: 'Rückgabe-Daten fehlen');
            break;
          }
          await DataService.setReturnActive(r.id, active: true);
          await DataService.addSystemMessageToThread(threadId: t.id, text: 'Rückgabe gestartet');
          if (mounted) {
            AppPopup.toast(context, icon: Icons.assignment_return_outlined, title: 'Rückgabe gestartet', message: 'Bestätige die Rückgabe jetzt im Buchungsdetail per QR-Code oder manuellem Code.');
          }
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
        await DataService.updateMessageThreadBookingStatus(threadId: t.id, status: 'declined');
        await DataService.addSystemMessageToThread(threadId: t.id, text: 'Anfrage abgelehnt');
      } else {
        await DataService.updateRentalRequestStatus(requestId: r.id, status: 'declined');
        await DataService.updateMessageThreadBookingStatus(threadId: t.id, status: 'declined');
        await DataService.addSystemMessageToThread(threadId: t.id, text: 'Anfrage abgelehnt');
      }
    } catch (e) {
      debugPrint('[MessageThreadScreen] _applySecondaryAction failed: $e');
    } finally {
      await _load();
    }
  }

  ({String primary, String? secondary}) _actionLabels(_ChatState st) {
    switch (st) {
      case _ChatState.requestOpen:
        // Wird nicht mehr gebraucht - Chat ist blockiert für pending
        return (primary: '', secondary: null);
      case _ChatState.confirmed:
        return (primary: 'Übergabe starten', secondary: null);
      case _ChatState.running:
      case _ChatState.returnPlanned:
        return (primary: 'Rückgabe starten', secondary: null);
      case _ChatState.completed:
        // Chat ist blockiert für completed - keine Actions
        return (primary: '', secondary: null);
      case _ChatState.support:
        return (primary: '', secondary: null);
    }
  }

  bool _shouldShowActions(_ChatState st) {
    // Nur aktive Buchungszustände zeigen Aktionen
    switch (st) {
      case _ChatState.confirmed:
      case _ChatState.running:
      case _ChatState.returnPlanned:
        return true;
      case _ChatState.requestOpen: // Chat blockiert
      case _ChatState.completed: // Chat blockiert
      case _ChatState.support:
        return false;
    }
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
        final ok = await ReturnHandoverStepperSheet.push(
          context,
          item: item,
          request: r,
          renterName: (_viewerIsOwner() ? other.displayName : me.displayName),
          ownerName: (_viewerIsOwner() ? me.displayName : other.displayName),
          handoverCode: 'SIT-${r.id}',
          viewerIsOwner: _viewerIsOwner(),
          mode: mode,
        );
        if (ok == true) {
          // Treat as completing 4/4 photos in the active segment.
          if (_handoverReturnState['handoverActive'] == true) {
            for (int i = 0; i < 4; i++) {
              await DataService.incrementHandoverPhotos(r.id);
            }
          }
          if (_handoverReturnState['returnActive'] == true) {
            for (int i = 0; i < 4; i++) {
              await DataService.incrementReturnPhotos(r.id);
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
    final mediaQuery = MediaQuery.of(context);
    final insets = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final viewPadding = mediaQuery.viewPadding.bottom;
    
    // DEBUG: Log keyboard state für Diagnose
    if (insets != _lastViewInsetBottom) {
      debugPrint('[KEYBOARD_DEBUG] viewInsets.bottom: $insets (was: $_lastViewInsetBottom)');
      debugPrint('[KEYBOARD_DEBUG] screen.height: $screenHeight');
      debugPrint('[KEYBOARD_DEBUG] viewPadding.bottom: $viewPadding');
      debugPrint('[KEYBOARD_DEBUG] inputFocused: ${_inputFocus.hasFocus}');
      debugPrint('[KEYBOARD_DEBUG] isWeb: ${kIsWeb}');
      
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
    
    // Chat-Gating: Nur accepted/running erlaubt
    final isChatActive = _isChatActiveForState(st);

    final handoverActive = _handoverReturnState['handoverActive'] == true;
    final returnActive = _handoverReturnState['returnActive'] == true;
    final showInlineFlowCard = (handoverActive || returnActive) && (_request != null);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      appBar: _ThreadHeader(
        isSupport: isSupport,
        avatarUrl: _avatarUrl(),
        title: isSupport ? 'SIT Support' : _displayName(),
        subtitle: isSupport ? 'Hilfe & Sicherheit' : _itemTitle(),
        verified: isSupport ? true : (_otherUser?.isVerified ?? false),
        onBlock: isSupport ? null : _blockUser,
        onViewBooking: isSupport ? null : _navigateToBookingDetail,
        onViewProfile: isSupport ? null : _viewProfile,
        onMuteNotifications: _muteNotifications,
        onArchiveChat: _archiveChat,
        onContactSupport: isSupport ? null : _contactSupport,
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
  
                if (!isSupport) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _CompactBookingCard(
                      itemTitle: _itemTitle(),
                      itemImageUrl: _item?.photos.isNotEmpty == true ? _item!.photos.first : null,
                      otherUserName: _displayName(),
                      request: _request,
                      statusLabel: badge.label,
                      statusBg: badge.bg,
                      statusFg: badge.fg,
                      onTap: () => _navigateToBookingDetail(),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (messages.isEmpty && !showAddressHint && !showInlineFlowCard)
                          ? Center(
                              child: Text(
                                isChatActive ? 'Noch keine Nachrichten' : _chatBlockedReason(st),
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : NotificationListener<UserScrollNotification>(
                              onNotification: (n) {
                                if (n.direction == ScrollDirection.forward && _inputFocus.hasFocus) {
                                  FocusScope.of(context).unfocus();
                                }
                                return false;
                              },
                              child: Builder(
                                builder: (context) {
                                  // A) Hinweistext nur als Empty-State:
                                  // Prüfen ob echte Nachrichten existieren (nicht von System)
                                  final hasRealMessages = messages.any((m) => m.senderId != 'system');
                                  // Filtere Intro-Hinweistext wenn echte Nachrichten vorhanden
                                  final filteredMessages = hasRealMessages
                                      ? messages.where((m) {
                                          // Intro-Hinweis ausblenden sobald echte Nachrichten da sind
                                          if (m.senderId == 'system' && 
                                              (m.text.contains('Starte einen Chat') || 
                                               m.text.contains('um eine Uhrzeit für Übergabe'))) {
                                            return false;
                                          }
                                          return true;
                                        }).toList()
                                      : messages;
                                  
                                  return ListView.builder(
                                    controller: _listController,
                                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                                    itemCount: filteredMessages.length + (showAddressHint ? 1 : 0) + (showInlineFlowCard ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      int i = index;

                                      if (showAddressHint) {
                                        if (i == 0) {
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 10),
                                            child: _InlineSystemCard(icon: Icons.lock_outline, text: _addressHintText()),
                                          );
                                        }
                                        i -= 1;
                                      }

                                      if (i < filteredMessages.length) {
                                        final m = filteredMessages[i];
                                        final isMe = m.senderId == _currentUser?.id;
                                        final isSystem = m.senderId == 'system';
                                        return _AnimatedMessageEntry(
                                          key: ValueKey('msg_${m.id}'),
                                          child: isSystem
                                              ? _SystemMessage(
                                                  text: m.text,
                                                  // Zeit-Anfragen zeigen das Profilbild des aktuellen Users
                                                  senderIsMe: true, 
                                                  senderAvatarUrl: _currentUser?.photoURL,
                                                )
                                              : _AvatarMessageRow(
                                                  isMe: isMe,
                                                  avatarUrl: isMe ? _currentUser?.photoURL : _avatarUrl(),
                                                  isSupport: isSupport,
                                                  child: _ChatBubble(
                                                    text: m.text,
                                                    me: isMe,
                                                    time: _formatTime(m.timestamp),
                                                  ),
                                                ),
                                        );
                                      }
                                      i -= filteredMessages.length;
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
                                  );
                                },
                              ),
                            ),
                ),
                // Chat-Gating: Bei inaktivem Chat nur Hinweis zeigen, kein Composer
                if (!isChatActive) 
                  _ChatBlockedBanner(reason: _chatBlockedReason(st))
                else
                  _TransactionComposer(
                    showActions: showActions,
                    primaryLabel: showActions ? actionLabels.primary : null,
                    secondaryLabel: showActions ? actionLabels.secondary : null,
                    onPrimary: showActions ? _applyPrimaryAction : null,
                    onSecondary: (showActions && actionLabels.secondary != null) ? _applySecondaryAction : null,
                    explanationText: _actionExplanation(st),
                    onShareLocation: _shareLocation,
                    onSendPhoto: _pickCamera,
                    onPickFile: _pickFile,
                    onChangeTime: _changeTime,
                    onProposeHandoverTime: _proposeHandoverTime,
                    onProposeReturnTime: _proposeReturnTime,
                    controller: _controller,
                    focusNode: _inputFocus,
                    onSend: _sendText,
                    iconSize: _composerIconSize,
                    buttonSize: _composerButtonSize,
                    sendButtonSize: _composerSendButtonSize,
                    cornerRadius: _composerCornerRadius,
                    fieldRadius: _composerFieldRadius,
                    chatState: st,
                    // Zeit-Status aus Nachrichten ableiten
                    handoverTimeRequested: _findRequestedTime(messages, isHandover: true),
                    returnTimeRequested: _findRequestedTime(messages, isHandover: false),
                    handoverConfirmed: _handoverReturnState['handoverTimeConfirmed'] == true,
                    returnConfirmed: _handoverReturnState['returnTimeConfirmed'] == true,
                    confirmedHandoverTime: _handoverReturnState['handoverTimeConfirmed'] == true
                        ? (_request?.start ?? DateTime.now().add(const Duration(days: 2)))
                        : null,
                    counterpartyName: _displayName(),
                  ),
              ],
            ),
            if (_showJumpToBottom)
              Positioned(
                right: 16,
                bottom: (MediaQuery.of(context).viewInsets.bottom > 0 ? MediaQuery.of(context).viewInsets.bottom : 0) + 72,
                child: _ScrollToBottomGlassButton(
                  onTap: () => _scrollToBottom(animate: true),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _chatBlockedReason(_ChatState st) {
    switch (st) {
      case _ChatState.requestOpen:
        return 'Der Chat ist erst nach Annahme der Anfrage verfügbar.';
      case _ChatState.completed:
        return 'Diese Buchung ist abgeschlossen.\nFür Fragen nutze den Support.';
      default:
        return 'Der Chat ist derzeit nicht verfügbar.';
    }
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
  
  /// Findet angefragte Zeit in System-Nachrichten
  String? _findRequestedTime(List<Message> messages, {required bool isHandover}) {
    final searchTerm = isHandover ? 'Übergabezeit angefragt' : 'Rückgabezeit angefragt';
    for (final m in messages.reversed) {
      if (m.senderId == 'system' && m.text.contains(searchTerm)) {
        // Extrahiere Zeit aus dem Text (z.B. "Mo, 14:00 Uhr")
        final regex = RegExp(r'([A-Za-z]{2}),?\s*(\d{1,2}:\d{2})');
        final match = regex.firstMatch(m.text);
        if (match != null) {
          return '${match.group(1)}, ${match.group(2)}';
        }
        return 'angefragt';
      }
    }
    return null;
  }

  String _actionExplanation(_ChatState st) {
    switch (st) {
      case _ChatState.requestOpen:
        return 'Anfrage bestätigen, um zu starten.';
      case _ChatState.confirmed:
        return 'Starten wenn ihr euch trefft.';
      case _ChatState.running:
      case _ChatState.returnPlanned:
        return 'Fotos helfen bei Rückfragen.';
      case _ChatState.completed:
        return ''; // Kein Text bei completed - Button spricht für sich
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

  /// Öffnet Auswahl zwischen Übergabe- und Rückgabezeit
  Future<void> _changeTime() async {
    final t = _thread;
    if (t == null) return;
    
    final cs = Theme.of(context).colorScheme;
    
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Zeitabstimmung',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _TimeOptionTile(
                          icon: Icons.inventory_2_outlined,
                          label: 'Übergabezeit',
                          subtitle: 'Wann soll die Übergabe stattfinden?',
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _proposeHandoverTime();
                          },
                        ),
                        const SizedBox(height: 12),
                        _TimeOptionTile(
                          icon: Icons.assignment_return_outlined,
                          label: 'Rückgabezeit',
                          subtitle: 'Wann soll die Rückgabe stattfinden?',
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _proposeReturnTime();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToBookingDetail() async {
    final r = _request;
    final t = _thread;
    if (r == null && t == null) {
      debugPrint('[MessageThreadScreen] No request/thread available for booking navigation');
      AppPopup.toast(context, icon: Icons.info_outline, title: 'Keine Buchung verfügbar');
      return;
    }
    
    // Build booking map from available data
    final booking = <String, dynamic>{
      'id': r?.id ?? t?.requestId ?? '',
      'itemId': r?.itemId ?? t?.itemId ?? '',
      'itemTitle': _itemTitle(),
      'status': r?.status ?? t?.bookingStatus ?? 'pending',
      'start': (r?.start ?? DateTime.now()).toIso8601String(),
      'end': (r?.end ?? DateTime.now()).toIso8601String(),
      'quotedTotalRenter': r?.quotedTotalRenter ?? 0.0,
      'renterId': r?.renterId ?? '',
      'ownerId': r?.ownerId ?? '',
      'deliveryCity': r?.deliveryCity ?? '',
      'deliveryAddressLine': r?.deliveryAddressLine ?? '',
    };
    
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: booking, viewerIsOwner: _viewerIsOwner())),
    );
  }

  Future<void> _blockUser() async {
    final t = _thread;
    final me = _currentUser;
    if (t == null || me == null) {
      AppPopup.toast(context, icon: Icons.info_outline, title: 'Blockieren nicht möglich');
      return;
    }

    // Support-Threads können nicht blockiert werden
    final isSupport = ((t.threadType ?? '').toLowerCase() == 'support') || (t.user1Id == 'support') || (t.user2Id == 'support');
    if (isSupport) {
      AppPopup.toast(context, icon: Icons.info_outline, title: 'Support kann nicht blockiert werden');
      return;
    }

    // Anderen User bestimmen
    final otherUserId = t.user1Id == me.id ? t.user2Id : t.user1Id;
    if (otherUserId.isEmpty) {
      debugPrint('[MessageThreadScreen] Cannot determine other user id for blocking');
      AppPopup.toast(context, icon: Icons.error_outline, title: 'Blockieren fehlgeschlagen');
      return;
    }

    try {
      await BlockedUsersService.blockUser(otherUserId);
      // Thread archivieren
      await DataService.archiveMessageThreadForUser(threadId: t.id, userId: me.id);
      if (mounted) {
        AppPopup.toast(context, icon: Icons.block, title: 'Nutzer blockiert');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('[MessageThreadScreen] _blockUser failed: $e');
      if (mounted) AppPopup.toast(context, icon: Icons.error_outline, title: 'Blockieren fehlgeschlagen');
    }
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $hh:$mm';
  }

  /// Übergabezeit vorschlagen
  Future<void> _proposeHandoverTime() async {
    final t = _thread;
    if (t == null) return;
    
    final now = DateTime.now();
    final initialTime = _request?.start ?? now.add(const Duration(hours: 2));
    
    final picked = await SitGlassTimePicker.show(
      context,
      title: 'Übergabezeit wählen',
      initialTime: TimeOfDay.fromDateTime(initialTime),
    );
    
    if (picked == null || !mounted) return;
    
    final proposedTime = DateTime(
      initialTime.year,
      initialTime.month,
      initialTime.day,
      picked.hour,
      picked.minute,
    );
    
    final dayName = _weekdayName(proposedTime.weekday);
    final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    
    try {
      await DataService.addSystemMessageToThread(
        threadId: t.id,
        text: '📦 Übergabezeit angefragt: $dayName, $timeStr Uhr',
      );
      await _load();
      _scrollToBottom(animate: true);
    } catch (e) {
      debugPrint('[MessageThreadScreen] _proposeHandoverTime failed: $e');
      if (mounted) AppPopup.toast(context, icon: Icons.error_outline, title: 'Fehler beim Senden');
    }
  }

  /// Rückgabezeit vorschlagen
  Future<void> _proposeReturnTime() async {
    final t = _thread;
    if (t == null) return;
    
    final now = DateTime.now();
    final initialTime = _request?.end ?? now.add(const Duration(days: 1));
    
    final picked = await SitGlassTimePicker.show(
      context,
      title: 'Rückgabezeit wählen',
      initialTime: TimeOfDay.fromDateTime(initialTime),
    );
    
    if (picked == null || !mounted) return;
    
    final proposedTime = DateTime(
      initialTime.year,
      initialTime.month,
      initialTime.day,
      picked.hour,
      picked.minute,
    );
    
    final dayName = _weekdayName(proposedTime.weekday);
    final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    
    try {
      await DataService.addSystemMessageToThread(
        threadId: t.id,
        text: '🔄 Rückgabezeit angefragt: $dayName, $timeStr Uhr',
      );
      await _load();
      _scrollToBottom(animate: true);
    } catch (e) {
      debugPrint('[MessageThreadScreen] _proposeReturnTime failed: $e');
      if (mounted) AppPopup.toast(context, icon: Icons.error_outline, title: 'Fehler beim Senden');
    }
  }

  String _weekdayName(int weekday) {
    const days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return days[(weekday - 1) % 7];
  }


Future<void> _viewProfile() async {
  final other = _otherUser;
  final thread = _thread;
  final isSupport = thread != null &&
      (((thread.threadType ?? '').toLowerCase() == 'support') ||
          thread.user1Id == 'support' ||
          thread.user2Id == 'support');
  if (isSupport) {
    AppPopup.toast(
      context,
      icon: Icons.info_outline,
      title: 'Für Support ist kein öffentliches Profil verfügbar.',
    );
    return;
  }
  if (other == null || other.id.trim().isEmpty) {
    AppPopup.toast(context, icon: Icons.info_outline, title: 'Profil nicht verfügbar');
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: other.id)),
  );
}

  Future<void> _muteNotifications() async {
    // TODO: Echte Stummschaltungs-Logik
    AppPopup.toast(context, icon: Icons.notifications_off_outlined, title: 'Benachrichtigungen stummgeschaltet');
  }

  Future<void> _archiveChat() async {
    final t = _thread;
    final me = _currentUser;
    if (t == null || me == null) {
      AppPopup.toast(context, icon: Icons.info_outline, title: 'Archivieren nicht möglich');
      return;
    }
    try {
      await DataService.archiveMessageThreadForUser(threadId: t.id, userId: me.id);
      if (mounted) {
        AppPopup.toast(context, icon: Icons.archive_outlined, title: 'Chat archiviert');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('[MessageThreadScreen] _archiveChat failed: $e');
      if (mounted) AppPopup.toast(context, icon: Icons.error_outline, title: 'Archivieren fehlgeschlagen');
    }
  }

  Future<void> _contactSupport() async {
    final flowContext = SupportFlowContext.fromChat(
      itemTitle: _itemTitle(),
      itemId: _item?.id ?? '',
      requestId: _request?.id ?? '',
      bookingStatus: _request?.status ?? _thread?.bookingStatus ?? '',
      viewerIsOwner: _viewerIsOwner(),
      otherUserName: _displayName(),
      threadId: _thread?.id,
      itemImageUrl: _item?.photos.isNotEmpty == true ? _item!.photos.first : null,
      otherUserImageUrl: _otherUser?.photoURL,
    );

    final result = await Navigator.of(context).push<SupportFlowResult?>(
      MaterialPageRoute(
        builder: (_) => SupportFlowScreen(context: flowContext),
      ),
    );

    if (result == null || !mounted) return;

    final mainCategory = result.mainCategory;
    final subCategory = result.subCategory;
    final userDescription = result.userDescription;

    final supportContext = <String, dynamic>{
      'mainCategory': mainCategory,
      'subCategory': subCategory,
      'userDescription': userDescription,
      'itemTitle': _itemTitle(),
      'itemId': _item?.id ?? '',
      'requestId': _request?.id ?? '',
      'threadId': _thread?.id ?? '',
      'bookingStatus': _request?.status ?? _thread?.bookingStatus ?? '',
      'otherUserName': _displayName(),
      'currentUserRole': _viewerIsOwner() ? 'owner' : 'renter',
      'source': 'booking_chat',
      'createdAt': DateTime.now().toIso8601String(),
    };

    debugPrint('[MessageThreadScreen] Support context prepared: $supportContext');

    try {
      final me = _currentUser;
      if (me == null) {
        AppPopup.toast(context, icon: Icons.error_outline, title: 'Nicht eingeloggt');
        return;
      }

      final threads = await DataService.getMessageThreadsForUser(me.id);
      MessageThread? supportThread = threads.cast<MessageThread?>().firstWhere(
        (t) => t != null && ((t.threadType ?? '').toLowerCase() == 'support' || t.user1Id == 'support' || t.user2Id == 'support'),
        orElse: () => null,
      );

      supportThread ??= await DataService.createSupportThread(userId: me.id);

      if (supportThread == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Support-Fall vorbereitet. Support-Route fehlt noch.'),
              backgroundColor: BrandColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final mainLabel = _supportMainCategoryLabel(mainCategory);
      final descText = userDescription.isNotEmpty ? '\n\nBeschreibung:\n$userDescription' : '';
      final contextMessage = '''📋 Support-Anfrage zu: ${_itemTitle().isNotEmpty ? _itemTitle() : 'Buchung'}
Buchung: ${_request?.id ?? 'N/A'}
Kategorie: $mainLabel
Unterkategorie: $subCategory$descText''';

      await DataService.addSystemMessageToThread(
        threadId: supportThread.id,
        text: contextMessage,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MessageThreadScreen(
              threadId: supportThread!.id,
              participantName: 'SIT Support',
              itemTitle: 'Support',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[MessageThreadScreen] _contactSupport failed: $e');
      if (mounted) {
        AppPopup.toast(context, icon: Icons.error_outline, title: 'Support nicht verfügbar');
      }
    }
  }
  
  String _supportMainCategoryLabel(String category) {
    switch (category) {
      case 'handover': return 'Problem mit Übergabe';
      case 'return': return 'Problem mit Rückgabe';
      case 'item_condition': return 'Problem mit Artikel/Zustand';
      case 'payment': return 'Problem mit Zahlung';
      case 'person': return 'Problem mit anderer Person';
      case 'technical': return 'Technisches Problem';
      case 'other': return 'Sonstiges';
      default: return category;
    }
  }
}

class _ThreadHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool isSupport;
  final String? avatarUrl;
  final String title;
  final String subtitle;
  final bool verified;
  final VoidCallback? onBlock;
  final VoidCallback? onViewBooking;
  final VoidCallback? onViewProfile;
  final VoidCallback? onMuteNotifications;
  final VoidCallback? onArchiveChat;
  final VoidCallback? onContactSupport;

  const _ThreadHeader({
    required this.isSupport,
    required this.avatarUrl,
    required this.title,
    required this.subtitle,
    required this.verified,
    this.onBlock,
    this.onViewBooking,
    this.onViewProfile,
    this.onMuteNotifications,
    this.onArchiveChat,
    this.onContactSupport,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActions = !isSupport || onMuteNotifications != null || onArchiveChat != null;
    
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
      actions: hasActions
          ? [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white.withValues(alpha: 0.85), size: 22),
                color: Colors.grey.shade900,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                offset: const Offset(0, 8),
                onSelected: (value) {
                  switch (value) {
                    case 'booking': onViewBooking?.call(); break;
                    case 'profile': onViewProfile?.call(); break;
                    case 'mute': onMuteNotifications?.call(); break;
                    case 'archive': onArchiveChat?.call(); break;
                    case 'support': onContactSupport?.call(); break;
                    case 'block': onBlock?.call(); break;
                  }
                },
                itemBuilder: (_) => isSupport
                    ? [
                        // Support-Chat: reduziertes Menü
                        PopupMenuItem(value: 'info', enabled: false, height: 38, child: Row(children: [Icon(Icons.support_agent_rounded, size: 16, color: Colors.white.withValues(alpha: 0.6)), const SizedBox(width: 10), Text('SIT Support', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12))])),
                        const PopupMenuDivider(height: 8),
                        PopupMenuItem(value: 'mute', height: 42, child: Row(children: [Icon(Icons.notifications_off_outlined, size: 18, color: Colors.white.withValues(alpha: 0.85)), const SizedBox(width: 10), const Text('Stummschalten', style: TextStyle(fontSize: 13))])),
                        PopupMenuItem(value: 'archive', height: 42, child: Row(children: [Icon(Icons.archive_outlined, size: 18, color: Colors.white.withValues(alpha: 0.85)), const SizedBox(width: 10), const Text('Chat archivieren', style: TextStyle(fontSize: 13))])),
                      ]
                    : [
                        // Normaler Chat: vollständiges Menü
                        if (onViewBooking != null)
                          PopupMenuItem(value: 'booking', height: 42, child: Row(children: [Icon(Icons.receipt_long_outlined, size: 18, color: Colors.white.withValues(alpha: 0.85)), const SizedBox(width: 10), const Text('Buchung ansehen', style: TextStyle(fontSize: 13))])),
                        PopupMenuItem(value: 'profile', height: 42, child: Row(children: [Icon(Icons.person_outline, size: 18, color: Colors.white.withValues(alpha: 0.85)), const SizedBox(width: 10), const Text('Profil ansehen', style: TextStyle(fontSize: 13))])),
                        const PopupMenuDivider(height: 8),
                        PopupMenuItem(value: 'mute', height: 42, child: Row(children: [Icon(Icons.notifications_off_outlined, size: 18, color: Colors.white.withValues(alpha: 0.85)), const SizedBox(width: 10), const Text('Stummschalten', style: TextStyle(fontSize: 13))])),
                        PopupMenuItem(value: 'archive', height: 42, child: Row(children: [Icon(Icons.archive_outlined, size: 18, color: Colors.white.withValues(alpha: 0.85)), const SizedBox(width: 10), const Text('Chat archivieren', style: TextStyle(fontSize: 13))])),
                        const PopupMenuDivider(height: 8),
                        PopupMenuItem(value: 'support', height: 42, child: Row(children: [
                          ClipOval(child: Image.asset('assets/images/icononly_transparent_nobuffer.png', width: 18, height: 18, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.support_agent_rounded, size: 18, color: BrandColors.primary))),
                          const SizedBox(width: 10), Text('Support kontaktieren', style: TextStyle(color: BrandColors.primary, fontSize: 13))])),
                        if (onBlock != null)
                          PopupMenuItem(value: 'block', height: 42, child: Row(children: [Icon(Icons.block, size: 18, color: Colors.red.shade400), const SizedBox(width: 10), Text('Nutzer blockieren', style: TextStyle(color: Colors.red.shade400, fontSize: 13))])),
                      ],
              ),
            ]
          : null,
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
      // 50% größer: radius 16 → 24
      return SitUserAvatar(
        url: avatarUrl,
        radius: 24,
        borderColor: Colors.white.withValues(alpha: 0.16),
        placeholderIcon: Icons.person_outline,
      );
    }

    // Support: always show SIT symbol inside the avatar circle (50% größer: 32 → 48)
    const double size = 48;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BrandColors.primary.withValues(alpha: 0.18),
        border: Border.all(color: BrandColors.primary.withValues(alpha: 0.3), width: 2),
      ),
      child: ClipOval(
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, 2.1), // optische Zentrierung
            child: Image.asset(
              'assets/images/icononly_transparent_nobuffer.png',
              width: size * 0.8,
              height: size * 0.8,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.support_agent_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: size * 0.5,
              ),
            ),
          ),
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

/// Kompakte Buchungskarte oben im Chat - nur Bild, Name, Status, Details-Link
class _CompactBookingCard extends StatelessWidget {
  final String itemTitle;
  final String? itemImageUrl;
  final String otherUserName;
  final RentalRequest? request;
  final String statusLabel;
  final Color statusBg;
  final Color statusFg;
  final VoidCallback? onTap;

  const _CompactBookingCard({
    required this.itemTitle,
    required this.itemImageUrl,
    required this.otherUserName,
    required this.request,
    required this.statusLabel,
    required this.statusBg,
    required this.statusFg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                // Item-Bild
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: Colors.white.withValues(alpha: 0.08),
                    child: itemImageUrl != null && itemImageUrl!.isNotEmpty
                        ? Image.asset(itemImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                ),
                const SizedBox(width: 10),
                // Artikelname + Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        itemTitle.isEmpty ? 'Buchung' : itemTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _StatusBadge(label: statusLabel, bg: statusBg, fg: statusFg),
                        ],
                      ),
                    ],
                  ),
                ),
                // Details-Pfeil
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Details', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600, fontSize: 11)),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.6), size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Center(
    child: Icon(Icons.inventory_2_outlined, color: Colors.white.withValues(alpha: 0.4), size: 20),
  );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: Colors.white.withValues(alpha: 0.45), size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Adresse geschützt · Zahlung nach SIT-Regeln · Übergabe mit Fotos & Code',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500, fontSize: 10, height: 1.3),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(label, style: TextStyle(color: fg.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 10)),
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
    final bg = me ? cs.primary.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.08);
    final maxWidth = MediaQuery.of(context).size.width * 0.72;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 7),
      constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 60),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        // Kein harter Border - saubere moderne Optik
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(color: Colors.white, height: 1.3, fontSize: 14)),
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(time, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 10, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _AvatarMessageRow extends StatelessWidget {
  final bool isMe;
  final String? avatarUrl;
  final bool isSupport;
  final Widget child;
  const _AvatarMessageRow({required this.isMe, required this.avatarUrl, required this.child, this.isSupport = false});

  @override
  Widget build(BuildContext context) {
    // Profilbilder 50% kleiner: radius 18 → 9
    Widget avatar;
    if (isSupport && !isMe) {
      avatar = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: BrandColors.primary.withValues(alpha: 0.18),
          border: Border.all(color: BrandColors.primary.withValues(alpha: 0.3), width: 1),
        ),
        child: ClipOval(
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, 1), // optische Zentrierung
              child: Image.asset(
                'assets/images/icononly_transparent_nobuffer.png',
                width: 14,
                height: 14,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 10,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // 50% kleiner: radius 18 → 9
      avatar = SitUserAvatar(
        url: avatarUrl,
        radius: 9,
        borderColor: Colors.white.withValues(alpha: 0.12),
        placeholderIcon: Icons.person_outline,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            avatar,
            const SizedBox(width: 6),
          ],
          Flexible(child: child),
          if (isMe) ...[
            const SizedBox(width: 6),
            avatar,
          ],
        ],
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final String text;
  final String? senderAvatarUrl;
  final bool senderIsMe;
  const _SystemMessage({
    required this.text, 
    this.senderAvatarUrl,
    this.senderIsMe = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Prüfen ob es eine Zeit-Anfrage ist (Übergabe oder Rückgabe)
    final isHandoverTime = text.contains('Übergabezeit angefragt');
    final isReturnTime = text.contains('Rückgabezeit angefragt');
    
    if (isHandoverTime || isReturnTime) {
      return _TimeRequestCard(
        text: text,
        isReturn: isReturnTime,
        isMe: senderIsMe,
        avatarUrl: senderAvatarUrl,
      );
    }
    
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

/// Schicke Card für Übergabe-/Rückgabezeit-Anfragen
/// Mit braunem Papierkarton-Icon wie in der Nachrichtenübersicht
class _TimeRequestCard extends StatelessWidget {
  final String text;
  final bool isReturn;
  final bool isMe;
  final String? avatarUrl;
  
  const _TimeRequestCard({
    required this.text, 
    this.isReturn = false,
    this.isMe = true,
    this.avatarUrl,
  });
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Text ohne Emoji extrahieren
    final cleanText = text.replaceAll('📦', '').replaceAll('🔄', '').trim();
    final maxWidth = MediaQuery.of(context).size.width * 0.72;
    
    // Kleines Profilbild (wie bei Nachrichten, radius 9)
    Widget avatar = SitUserAvatar(
      url: avatarUrl,
      radius: 9,
      borderColor: Colors.white.withValues(alpha: 0.12),
      placeholderIcon: Icons.person_outline,
    );
    
    // Braune Karton-Farbe wie in der Nachrichtenübersicht
    const cardboardBrown = Color(0xFFB8956C);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            avatar,
            const SizedBox(width: 6),
          ],
          // Dezenter grauer Blur-Hintergrund für beide Parteien
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 60),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Braunes Papierkarton-Icon (konsistent mit Nachrichtenübersicht)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.inventory_2_rounded,
                          color: cardboardBrown,
                          size: 18,
                        ),
                        // Bei Rückgabe: SIT-blauer Return-Pfeil
                        if (isReturn)
                          Positioned(
                            right: -5,
                            bottom: -3,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black.withValues(alpha: 0.2), width: 0.5),
                              ),
                              child: const Icon(
                                Icons.undo_rounded,
                                color: Colors.white,
                                size: 8,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        cleanText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            avatar,
          ],
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.35), size: 12),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.40), fontWeight: FontWeight.w500, fontSize: 11)),
        ],
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
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
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
                    style: const TextStyle(color: Colors.white, height: 1.25, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Nachricht…',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600, fontSize: 14),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(fieldRadius), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(fieldRadius), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(fieldRadius), borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.7))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _PressScale(
                  onTap: onSend,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: _SitSendIcon(size: 22, color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _ComposerIconButton(icon: Icons.my_location_rounded, label: 'Standort', onTap: onShareLocation),
                const SizedBox(width: 6),
                _ComposerIconButton(icon: Icons.photo_camera_outlined, label: 'Foto', onTap: onSendPhoto),
                const SizedBox(width: 6),
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Center(child: Icon(icon, color: Colors.white.withValues(alpha: 0.65), size: 15)),
        ),
      ),
    );
  }
}

/// Banner für blockierten Chat
class _ChatBlockedBanner extends StatelessWidget {
  final String reason;
  const _ChatBlockedBanner({required this.reason});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.4), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionComposer extends StatefulWidget {
  final bool showActions;
  final String? primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final String explanationText;
  final VoidCallback onShareLocation;
  final VoidCallback onSendPhoto;
  final VoidCallback onPickFile;
  final VoidCallback onChangeTime;
  final VoidCallback onProposeHandoverTime;
  final VoidCallback onProposeReturnTime;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final double iconSize;
  final double buttonSize;
  final double sendButtonSize;
  final double cornerRadius;
  final double fieldRadius;
  final _ChatState chatState;
  // Zeit-Status für Buttons
  final String? handoverTimeRequested;
  final String? returnTimeRequested;
  final bool handoverConfirmed;
  final bool returnConfirmed;
  final DateTime? confirmedHandoverTime;
  // Gegenparteiname für Subline
  final String? counterpartyName;

  const _TransactionComposer({
    required this.showActions,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    required this.explanationText,
    required this.onShareLocation,
    required this.onSendPhoto,
    required this.onPickFile,
    required this.onChangeTime,
    required this.onProposeHandoverTime,
    required this.onProposeReturnTime,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.iconSize,
    required this.buttonSize,
    required this.sendButtonSize,
    required this.cornerRadius,
    required this.fieldRadius,
    required this.chatState,
    this.handoverTimeRequested,
    this.returnTimeRequested,
    this.handoverConfirmed = false,
    this.returnConfirmed = false,
    this.confirmedHandoverTime,
    this.counterpartyName,
  });

  @override
  State<_TransactionComposer> createState() => _TransactionComposerState();
}

class _TransactionComposerState extends State<_TransactionComposer> {
  bool _inputFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _TransactionComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    final focused = widget.focusNode.hasFocus;
    if (focused != _inputFocused) {
      setState(() => _inputFocused = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        // Regel: isComposing = Text vorhanden ODER Fokus auf Input
        final isComposing = value.text.trim().isNotEmpty || _inputFocused;
        
        // Wenn isComposing: alle Buttons ausblenden, nur Textfeld + Send
        // Zeitbuttons einzeln ausblenden nach bestätigtem Status:
        // - Übergabezeit-Button: ausblenden wenn running/returnPlanned/completed (Übergabe schon stattgefunden)
        // - Rückgabezeit-Button: ausblenden wenn completed (Rückgabe abgeschlossen)
        final showHandoverTimeButton = !isComposing && widget.chatState == _ChatState.confirmed;
        final showReturnTimeButton = !isComposing && 
            (widget.chatState == _ChatState.confirmed || 
             widget.chatState == _ChatState.running || 
             widget.chatState == _ChatState.returnPlanned);
        final showTimeButtons = showHandoverTimeButton || showReturnTimeButton;
        final showActions = !isComposing && widget.showActions;
        
        // Web-Fallback: Auf Flutter Web bleibt viewInsets.bottom oft bei 0
        // In dem Fall nutzen wir viewPadding.bottom für SafeArea-Padding
        final viewInsets = MediaQuery.of(context).viewInsets.bottom;
        final viewPadding = MediaQuery.of(context).viewPadding.bottom;
        final isWebKeyboardWorkaround = kIsWeb && viewInsets == 0 && _inputFocused;
        
        // Beim Schreiben: Minimale UI ohne äußere Card
        // Sonst: Normale Composer-UI mit Glass-Effekt
        
        if (isComposing) {
          // Minimaler Composer: nur Textfeld + Icons + Send-Button, keine äußere Card
          return Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 8 + viewPadding),
            child: _GlassInputBar(
              controller: widget.controller,
              focusNode: widget.focusNode,
              onSend: widget.onSend,
              onShareLocation: widget.onShareLocation,
              onSendPhoto: widget.onSendPhoto,
              onPickFile: widget.onPickFile,
              onChangeTime: widget.onChangeTime,
              isComposing: isComposing,
              chatState: widget.chatState,
            ),
          );
        }
        
        // Kein äußerer Wrapper mehr - nur Padding + Column
        return Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 10 + viewPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zeitbuttons oben, Primary-Button unten
              // Layout: [Übergabezeit | Rückgabezeit], darunter [Übergabe starten]
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: (showTimeButtons || showActions)
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CombinedActionRow(
                          showHandoverTimeButton: showHandoverTimeButton && !widget.handoverConfirmed,
                          showReturnTimeButton: showReturnTimeButton,
                          showPrimaryAction: showActions && !(widget.handoverConfirmed && widget.chatState == _ChatState.confirmed),
                          handoverTimeRequested: widget.handoverTimeRequested,
                          returnTimeRequested: widget.returnTimeRequested,
                          handoverConfirmed: widget.handoverConfirmed,
                          returnConfirmed: widget.returnConfirmed,
                          primaryLabel: widget.primaryLabel ?? '',
                          primaryEnabled: widget.handoverConfirmed || widget.chatState != _ChatState.confirmed,
                          counterpartyName: widget.counterpartyName,
                          onProposeHandover: widget.onProposeHandoverTime,
                          onProposeReturn: widget.onProposeReturnTime,
                          onPrimary: widget.onPrimary,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              // Countdown anzeigen wenn Übergabezeit bestätigt
              if (widget.handoverConfirmed && widget.confirmedHandoverTime != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HandoverCountdown(
                    confirmedTime: widget.confirmedHandoverTime!,
                    onStartNow: widget.onPrimary,
                  ),
                ),
              _GlassInputBar(
                controller: widget.controller,
                focusNode: widget.focusNode,
                onSend: widget.onSend,
                onShareLocation: widget.onShareLocation,
                onSendPhoto: widget.onSendPhoto,
                onPickFile: widget.onPickFile,
                onChangeTime: widget.onChangeTime,
                isComposing: isComposing,
                chatState: widget.chatState,
              ),
            ],
          ),
        );
        },
      );
    }
  }

/// Layout: Zeile 1: [Übergabezeit | Rückgabezeit], Zeile 2: [Übergabe starten] volle Breite
class _CombinedActionRow extends StatelessWidget {
  final bool showHandoverTimeButton;
  final bool showReturnTimeButton;
  final bool showPrimaryAction;
  final String? handoverTimeRequested;
  final String? returnTimeRequested;
  final bool handoverConfirmed;
  final bool returnConfirmed;
  final String primaryLabel;
  final bool primaryEnabled;
  final String? counterpartyName;
  final VoidCallback onProposeHandover;
  final VoidCallback onProposeReturn;
  final VoidCallback? onPrimary;
  
  const _CombinedActionRow({
    required this.showHandoverTimeButton,
    required this.showReturnTimeButton,
    required this.showPrimaryAction,
    this.handoverTimeRequested,
    this.returnTimeRequested,
    this.handoverConfirmed = false,
    this.returnConfirmed = false,
    required this.primaryLabel,
    this.primaryEnabled = true,
    this.counterpartyName,
    required this.onProposeHandover,
    required this.onProposeReturn,
    this.onPrimary,
  });
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Braune Karton-Farbe wie in der Nachrichtenübersicht
    const cardboardBrown = Color(0xFFB8956C);
    
    // Pendingstatus für Zeitbuttons
    final handoverPending = handoverTimeRequested != null && handoverTimeRequested!.isNotEmpty && !handoverConfirmed;
    final returnPending = returnTimeRequested != null && returnTimeRequested!.isNotEmpty && !returnConfirmed;
    
    // Button-Farben basierend auf Aktivierung
    final isActive = primaryEnabled && onPrimary != null;
    
    final showTimeRow = showHandoverTimeButton || showReturnTimeButton;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zeile 1: Übergabezeit + Rückgabezeit nebeneinander (jeweils halbe Breite)
        if (showTimeRow)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status oberhalb der Zeitbuttons
              if (handoverPending || returnPending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      // Status für Übergabezeit
                      if (showHandoverTimeButton)
                        Expanded(
                          child: handoverPending
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.hourglass_empty_rounded, color: Colors.orange.withValues(alpha: 0.8), size: 10),
                                    const SizedBox(width: 3),
                                    Text(
                                      'wartet auf Bestätigung',
                                      style: TextStyle(color: Colors.orange.withValues(alpha: 0.8), fontWeight: FontWeight.w500, fontSize: 9),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      // Status für Rückgabezeit
                      if (showReturnTimeButton)
                        Expanded(
                          child: returnPending
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.hourglass_empty_rounded, color: Colors.orange.withValues(alpha: 0.8), size: 10),
                                    const SizedBox(width: 3),
                                    Text(
                                      'wartet auf Bestätigung',
                                      style: TextStyle(color: Colors.orange.withValues(alpha: 0.8), fontWeight: FontWeight.w500, fontSize: 9),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
              // Zeitbuttons nebeneinander
              Row(
                children: [
                  // Übergabezeit-Button (links, halbe Breite)
                  if (showHandoverTimeButton)
                    Expanded(
                      child: _PressScale(
                        onTap: onProposeHandover,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: handoverPending 
                                ? cs.primary.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: handoverPending 
                                  ? cs.primary.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_rounded, color: cardboardBrown, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Übergabezeit',
                                style: TextStyle(
                                  color: handoverPending ? cs.primary : Colors.white.withValues(alpha: 0.8), 
                                  fontWeight: FontWeight.w600, 
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Spacing zwischen Zeitbuttons
                  if (showHandoverTimeButton && showReturnTimeButton)
                    const SizedBox(width: 8),
                  // Rückgabezeit-Button (rechts, halbe Breite)
                  if (showReturnTimeButton)
                    Expanded(
                      child: _PressScale(
                        onTap: onProposeReturn,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: returnPending 
                                ? cs.primary.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: returnPending 
                                  ? cs.primary.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Braunes Box-Icon mit SIT-blauem Return-Akzent
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(Icons.inventory_2_rounded, color: cardboardBrown, size: 16),
                                  Positioned(
                                    right: -4,
                                    bottom: -2,
                                    child: Container(
                                      width: 11,
                                      height: 11,
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.undo_rounded, color: Colors.white, size: 7),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Rückgabezeit',
                                style: TextStyle(
                                  color: returnPending ? cs.primary : Colors.white.withValues(alpha: 0.8), 
                                  fontWeight: FontWeight.w600, 
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        // Spacing zwischen Zeitbuttons und Primary-Button
        if (showTimeRow && showPrimaryAction && primaryLabel.isNotEmpty)
          const SizedBox(height: 8),
        // Zeile 2: Übergabe starten (volle Breite)
        if (showPrimaryAction && primaryLabel.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: _PressScale(
              onTap: isActive ? onPrimary : null,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: isActive
                      ? LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.85)])
                      : null,
                  color: isActive ? null : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded, color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      primaryLabel,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5), 
                        fontWeight: FontWeight.w700, 
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Subline: Erklärung wenn Button inaktiv
        if (!primaryEnabled && showPrimaryAction && primaryLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            counterpartyName != null && counterpartyName!.isNotEmpty
                ? 'Erst möglich, wenn $counterpartyName deine Übergabezeit bestätigt.'
                : 'Erst möglich, wenn die Übergabezeit bestätigt ist.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontWeight: FontWeight.w500, height: 1.3, fontSize: 9),
          ),
        ],
      ],
    );
  }
}

/// Zeitabstimmungs-Buttons für Übergabe/Rückgabe - einzeln steuerbar
/// Mit "wartet auf Bestätigung"-Status wenn Zeit angefragt
class _TimeAgreementButtons extends StatelessWidget {
  final VoidCallback onProposeHandover;
  final VoidCallback onProposeReturn;
  final bool showHandoverButton;
  final bool showReturnButton;
  final String? handoverTimeRequested; // z.B. "Mo, 14:00"
  final String? returnTimeRequested;   // z.B. "Fr, 16:00"
  final bool handoverConfirmed;
  final bool returnConfirmed;
  
  const _TimeAgreementButtons({
    required this.onProposeHandover,
    required this.onProposeReturn,
    this.showHandoverButton = true,
    this.showReturnButton = true,
    this.handoverTimeRequested,
    this.returnTimeRequested,
    this.handoverConfirmed = false,
    this.returnConfirmed = false,
  });
  
  @override
  Widget build(BuildContext context) {
    // Wenn beide unsichtbar, nichts anzeigen
    if (!showHandoverButton && !showReturnButton) return const SizedBox.shrink();
    
    // Wenn nur einer sichtbar, zentriert anzeigen
    if (!showHandoverButton) {
      return _buildReturnButton(context);
    }
    if (!showReturnButton) {
      return _buildHandoverButton(context);
    }
    
    // Beide sichtbar
    return Row(
      children: [
        Expanded(child: _buildHandoverButton(context)),
        const SizedBox(width: 8),
        Expanded(child: _buildReturnButton(context)),
      ],
    );
  }
  
  Widget _buildHandoverButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRequested = handoverTimeRequested != null && handoverTimeRequested!.isNotEmpty;
    final isPending = hasRequested && !handoverConfirmed;
    
    // Braune Karton-Farbe wie in der Nachrichtenübersicht
    const cardboardBrown = Color(0xFFB8956C);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status OBERHALB des Buttons
        if (isPending) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_empty_rounded, color: Colors.orange.withValues(alpha: 0.8), size: 10),
              const SizedBox(width: 4),
              Text(
                'wartet auf Bestätigung',
                style: TextStyle(
                  color: Colors.orange.withValues(alpha: 0.8), 
                  fontWeight: FontWeight.w500, 
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        _PressScale(
          onTap: onProposeHandover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isPending 
                  ? cs.primary.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPending 
                    ? cs.primary.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_rounded, color: cardboardBrown, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Übergabezeit',
                  style: TextStyle(
                    color: isPending ? cs.primary : Colors.white.withValues(alpha: 0.8), 
                    fontWeight: FontWeight.w600, 
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildReturnButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRequested = returnTimeRequested != null && returnTimeRequested!.isNotEmpty;
    final isPending = hasRequested && !returnConfirmed;
    
    // Braune Karton-Farbe wie in der Nachrichtenübersicht
    const cardboardBrown = Color(0xFFB8956C);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status OBERHALB des Buttons
        if (isPending) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_empty_rounded, color: Colors.orange.withValues(alpha: 0.8), size: 10),
              const SizedBox(width: 4),
              Text(
                'wartet auf Bestätigung',
                style: TextStyle(
                  color: Colors.orange.withValues(alpha: 0.8), 
                  fontWeight: FontWeight.w500, 
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        _PressScale(
          onTap: onProposeReturn,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isPending 
                  ? cs.primary.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPending 
                    ? cs.primary.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Braunes Box-Icon mit SIT-blauem Return-Akzent
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.inventory_2_rounded, color: cardboardBrown, size: 14),
                    Positioned(
                      right: -4,
                      bottom: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.undo_rounded, color: Colors.white, size: 6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Text(
                  'Rückgabezeit',
                  style: TextStyle(
                    color: isPending ? cs.primary : Colors.white.withValues(alpha: 0.8), 
                    fontWeight: FontWeight.w600, 
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Countdown-Widget für bestätigte Übergabezeit
class _HandoverCountdown extends StatefulWidget {
  final DateTime confirmedTime;
  final VoidCallback? onStartNow;
  
  const _HandoverCountdown({
    required this.confirmedTime,
    this.onStartNow,
  });
  
  @override
  State<_HandoverCountdown> createState() => _HandoverCountdownState();
}

class _HandoverCountdownState extends State<_HandoverCountdown> {
  late Duration _remaining;
  
  @override
  void initState() {
    super.initState();
    _updateRemaining();
    // Einfacher Refresh alle 60 Sekunden
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 60));
      if (!mounted) return false;
      _updateRemaining();
      return true;
    });
  }
  
  void _updateRemaining() {
    final now = DateTime.now();
    final diff = widget.confirmedTime.difference(now);
    if (mounted) {
      setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    }
  }
  
  String _formatCountdown(Duration d) {
    if (d.isNegative || d == Duration.zero) return 'Jetzt';
    
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    
    final parts = <String>[];
    if (days > 0) parts.add('$days ${days == 1 ? 'Tag' : 'Tage'}');
    if (hours > 0) parts.add('$hours ${hours == 1 ? 'Stunde' : 'Stunden'}');
    if (minutes > 0 || parts.isEmpty) parts.add('$minutes ${minutes == 1 ? 'Minute' : 'Minuten'}');
    
    return parts.join(' ');
  }
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final countdownText = _formatCountdown(_remaining);
    final isNow = _remaining == Duration.zero;
    
    return _PressScale(
      onTap: widget.onStartNow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary.withValues(alpha: 0.15),
              cs.primary.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isNow ? Icons.play_circle_outline_rounded : Icons.timer_outlined,
                  color: cs.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isNow ? 'Übergabe jetzt starten' : 'Übergabe in $countdownText',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Antippen, um Übergabe jetzt zu starten',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kompakter CTA-Bereich im Glass-Card-Stil
class _CompactTransactionCTA extends StatelessWidget {
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final String explanationText;
  final bool primaryEnabled;
  final String? counterpartyName;

  const _CompactTransactionCTA({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    required this.explanationText,
    this.primaryEnabled = true,
    this.counterpartyName,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Leeren Button nicht anzeigen
    if (primaryLabel.isEmpty) return const SizedBox.shrink();
    
    // Button-Farben basierend auf Aktivierung
    final isActive = primaryEnabled && onPrimary != null;
    final buttonColors = isActive
        ? [cs.primary, cs.primary.withValues(alpha: 0.85)]
        : [Colors.grey.shade600, Colors.grey.shade700];
    final iconColor = isActive ? Colors.white : Colors.white.withValues(alpha: 0.5);
    final textColor = isActive ? Colors.white : Colors.white.withValues(alpha: 0.5);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _PressScale(
                onTap: isActive ? onPrimary : null,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: buttonColors),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt_rounded, color: iconColor, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          primaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(width: 8),
              _PressScale(
                onTap: onSecondary,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Center(
                    child: Text(
                      secondaryLabel!,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        // Subline: Erklärung wenn Button inaktiv
        if (!primaryEnabled) ...[
          const SizedBox(height: 6),
          Text(
            counterpartyName != null && counterpartyName!.isNotEmpty
                ? 'Erst möglich, wenn $counterpartyName deine Übergabezeit bestätigt.'
                : 'Erst möglich, wenn die Übergabezeit bestätigt ist.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontWeight: FontWeight.w500, height: 1.3, fontSize: 10),
          ),
        ] else if (explanationText.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            explanationText,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w500, height: 1.3, fontSize: 10),
          ),
        ],
      ],
    );
  }
}

/// Glass-Input-Bar im Onboarding-Stil
/// Icons links neben dem Textfeld (idle) oder im Textfeld (composing)
/// Bei mehrzeiligem Text: Icons bleiben oben, Text fließt darunter
class _GlassInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onShareLocation;
  final VoidCallback onSendPhoto;
  final VoidCallback onPickFile;
  final VoidCallback onChangeTime;
  final bool isComposing;
  final _ChatState chatState;

  const _GlassInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onShareLocation,
    required this.onSendPhoto,
    required this.onPickFile,
    required this.onChangeTime,
    required this.chatState,
    this.isComposing = false,
  });

  @override
  State<_GlassInputBar> createState() => _GlassInputBarState();
}

class _GlassInputBarState extends State<_GlassInputBar> with SingleTickerProviderStateMixin {
  static const double _iconSize = 18.0;
  static const Duration _animDuration = Duration(milliseconds: 220);
  
  late AnimationController _animController;
  late Animation<double> _fadeOuterIcons;
  late Animation<double> _fadeInnerIcons;
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: _animDuration);
    _fadeOuterIcons = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _fadeInnerIcons = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );
    
    if (widget.isComposing) _animController.value = 1.0;
  }
  
  @override
  void didUpdateWidget(covariant _GlassInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isComposing != oldWidget.isComposing) {
      if (widget.isComposing) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }
  
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Uhr-Icon nur bei confirmed/running anzeigen
    final showTimeIcon = widget.chatState == _ChatState.confirmed || widget.chatState == _ChatState.running;
    
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final isExpanded = _animController.value > 0.5;
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icons links - Ausblenden im Schreibmodus mit Animation
            AnimatedContainer(
              duration: _animDuration,
              curve: Curves.easeOutCubic,
              width: isExpanded ? 0 : null,
              child: FadeTransition(
                opacity: _fadeOuterIcons,
                child: SizeTransition(
                  axis: Axis.horizontal,
                  sizeFactor: _fadeOuterIcons,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GlassIconButton(icon: Icons.attach_file_rounded, onTap: widget.onPickFile, iconSize: _iconSize),
                      const SizedBox(width: 6),
                      _GlassIconButton(icon: Icons.photo_camera_outlined, onTap: widget.onSendPhoto, iconSize: _iconSize),
                      const SizedBox(width: 6),
                      _GlassIconButton(icon: Icons.my_location_rounded, onTap: widget.onShareLocation, iconSize: _iconSize),
                      if (showTimeIcon) ...[
                        const SizedBox(width: 6),
                        _GlassIconButton(icon: Icons.schedule_rounded, onTap: widget.onChangeTime, iconSize: _iconSize),
                      ],
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              ),
            ),
            // Textfeld - expandiert im Schreibmodus
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    // Inline-Icons: Kamera + Paperclip (nur im Schreibmodus)
                    // Bleiben oben links auf Höhe der ersten Zeile
                    Positioned(
                      left: 10,
                      top: 6,
                      child: FadeTransition(
                        opacity: _fadeInnerIcons,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _InlineIconButton(icon: Icons.photo_camera_outlined, onTap: widget.onSendPhoto),
                            const SizedBox(width: 6),
                            _InlineIconButton(icon: Icons.attach_file_rounded, onTap: widget.onPickFile),
                          ],
                        ),
                      ),
                    ),
                    // TextField - erste Zeile neben Icons, ab Zeile 2 volle Breite
                    TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(color: Colors.white, height: 1.3, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Nachricht…',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontWeight: FontWeight.w500, fontSize: 15),
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.fromLTRB(
                          isExpanded ? 76 : 14, // Platz für Icons in erster Zeile
                          10, 
                          14, 
                          10,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Senden-Button
            _PressScale(
              onTap: widget.onSend,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(child: _SitSendIcon(size: 20, color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Inline-Icon im Textfeld (ohne Rahmen/Hintergrund)
/// Funktioniert auch wenn Feld leer aber fokussiert ist
class _InlineIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  
  const _InlineIconButton({required this.icon, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withValues(alpha: 0.15),
        highlightColor: Colors.white.withValues(alpha: 0.08),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kleine Glass-Icons im Composer
/// Mit Tap-Feedback und einheitlicher Größe
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  const _GlassIconButton({
    required this.icon, 
    required this.onTap,
    this.iconSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.white.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Icon(
              icon, 
              color: Colors.white.withValues(alpha: 0.55), 
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

/// Auswahloption für Zeitabstimmung
class _TimeOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _TimeOptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// Legacy - für Kompatibilität behalten
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
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _PressScale(
                  onTap: onPrimary,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.8)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            primaryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (secondaryLabel != null) ...[
                const SizedBox(width: 8),
                _PressScale(
                  onTap: onSecondary,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Center(
                      child: Text(
                        secondaryLabel!,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (explanationText.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              explanationText,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.52), fontWeight: FontWeight.w600, height: 1.3, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScrollToBottomGlassButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ScrollToBottomGlassButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.arrow_downward_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SIT-style Send Icon (vector, no PNG)
/// Stilisierter Pfeil nach rechts - clean, modern
class _SitSendIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _SitSendIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/images/Send_Icon_For_SIT.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
