import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:lendify/services/firebase_runtime.dart';
import 'package:lendify/widgets/app_popup.dart';

class ForegroundPushHost extends StatefulWidget {
  final Widget child;
  final Stream<ForegroundPushMessage>? messages;
  final void Function(ForegroundPushMessage message)? onOpen;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;

  const ForegroundPushHost({
    super.key,
    required this.child,
    this.messages,
    this.onOpen,
    this.messengerKey,
  });

  @override
  State<ForegroundPushHost> createState() => _ForegroundPushHostState();
}

class _ForegroundPushHostState extends State<ForegroundPushHost> {
  StreamSubscription<ForegroundPushMessage>? _subscription;
  final Queue<ForegroundPushMessage> _pendingMessages = Queue();
  bool _showingMessage = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant ForegroundPushHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages != widget.messages) _subscribe();
  }

  void _subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = (widget.messages ?? FirebaseRuntime.foregroundMessages)
        .listen(_showMessage);
  }

  void _showMessage(ForegroundPushMessage message) {
    _pendingMessages.add(message);
    _presentNextMessage();
  }

  void _presentNextMessage() {
    if (_showingMessage || _pendingMessages.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showingMessage || _pendingMessages.isEmpty) return;
      final message = _pendingMessages.removeFirst();
      _showingMessage = true;
      unawaited(
        AppPopup.showCustom<void>(
          context,
          icon: Icons.notifications_active_outlined,
          title: message.title,
          showCloseIcon: true,
          showAccentLine: true,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                label: 'Benachrichtigung: ${message.title}. ${message.body}',
                child: Text(message.body),
              ),
              if (message.actionUri != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).maybePop();
                    (widget.onOpen ?? FirebaseRuntime.openForegroundMessage)(
                      message,
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Öffnen'),
                ),
              ],
            ],
          ),
        ).whenComplete(() {
          _showingMessage = false;
          if (mounted) _presentNextMessage();
        }),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
