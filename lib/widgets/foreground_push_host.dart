import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lendify/services/firebase_runtime.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = widget.messengerKey?.currentState ??
          ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Semantics(
            liveRegion: true,
            label: 'Benachrichtigung: ${message.title}. ${message.body}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (message.body.isNotEmpty) Text(message.body),
              ],
            ),
          ),
          action: message.actionUri == null
              ? null
              : SnackBarAction(
                  label: 'Öffnen',
                  onPressed: () => (widget.onOpen ??
                      FirebaseRuntime.openForegroundMessage)(message),
                ),
        ),
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
