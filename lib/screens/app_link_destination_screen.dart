import 'package:flutter/material.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/screens/booking_detail_screen.dart';
import 'package:lendify/screens/login_screen.dart';
import 'package:lendify/screens/message_thread_screen.dart';
import 'package:lendify/screens/ongoing_owner_detail_screen.dart';
import 'package:lendify/screens/request_detail_screen.dart';
import 'package:lendify/screens/payment_checkout_screen.dart';
import 'package:lendify/services/app_link_service.dart';
import 'package:lendify/services/auth_service.dart';
import 'package:lendify/services/data_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AppLinkHost extends StatefulWidget {
  final Widget child;

  const AppLinkHost({super.key, required this.child});

  @override
  State<AppLinkHost> createState() => _AppLinkHostState();
}

class _AppLinkHostState extends State<AppLinkHost> {
  AppLinkController? _controller;
  bool _opening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<AppLinkController>();
    if (identical(next, _controller)) return;
    _controller?.removeListener(_handlePending);
    _controller = next..addListener(_handlePending);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePending());
  }

  void _handlePending() {
    if (!mounted || _opening) return;
    final target = _controller?.takePending();
    if (target == null) return;
    _opening = true;
    Navigator.of(context)
        .push<void>(
      MaterialPageRoute(
        builder: (_) => AppLinkDestinationScreen(target: target),
      ),
    )
        .whenComplete(() {
      _opening = false;
      _handlePending();
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_handlePending);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AppLinkDestinationScreen extends StatefulWidget {
  final AppLinkTarget target;

  const AppLinkDestinationScreen({super.key, required this.target});

  @override
  State<AppLinkDestinationScreen> createState() =>
      _AppLinkDestinationScreenState();
}

class _AppLinkDestinationScreenState extends State<AppLinkDestinationScreen> {
  late Future<_ResolvedBooking?> _booking = _resolveBooking();
  bool _externalOpened = false;

  Future<_ResolvedBooking?> _resolveBooking() async {
    if (widget.target.kind != AppLinkKind.booking) return null;
    final session = await AuthService.readSession();
    if (session == null) return null;
    final request = await DataService.getRentalRequestById(widget.target.id!);
    if (request == null) return null;
    final values = await Future.wait<Object?>([
      DataService.getCurrentUser(),
      DataService.getItemById(request.itemId),
      DataService.getUserById(request.ownerId),
    ]);
    return _ResolvedBooking(
      request: request,
      viewer: values[0] as User?,
      item: values[1] as Item?,
      owner: values[2] as User?,
    );
  }

  Future<void> _loginAndRetry() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (!mounted) return;
    setState(() => _booking = _resolveBooking());
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.target.kind) {
      case AppLinkKind.chat:
        return FutureBuilder<AuthSession?>(
          future: AuthService.readSession(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LinkLoadingScreen();
            }
            if (snapshot.data == null) {
              return _LinkErrorScreen(
                title: 'Bitte zuerst anmelden',
                message:
                    'Nach der Anmeldung öffnen wir den sicheren Chat-Kontext.',
                actionLabel: 'Anmelden',
                onAction: _loginAndRetry,
              );
            }
            return MessageThreadScreen(threadId: widget.target.id);
          },
        );
      case AppLinkKind.booking:
        return FutureBuilder<_ResolvedBooking?>(
          future: _booking,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LinkLoadingScreen();
            }
            final resolved = snapshot.data;
            if (resolved == null) {
              return _LinkErrorScreen(
                title: 'Buchung nicht verfügbar',
                message:
                    'Melde dich mit dem zugehörigen Konto an oder prüfe, ob der Link noch gültig ist.',
                actionLabel: 'Anmelden und erneut prüfen',
                onAction: _loginAndRetry,
              );
            }
            if (resolved.request.ownerId == resolved.viewer?.id) {
              if (resolved.request.status == 'pending') {
                return RequestDetailScreen(requestId: resolved.request.id);
              }
              return OngoingOwnerDetailScreen(
                requestId: resolved.request.id,
                titleOverride: 'Vermietung',
              );
            }
            return BookingDetailScreen(
              booking: _bookingMap(resolved),
              viewerIsOwner: false,
            );
          },
        );
      case AppLinkKind.emailVerification:
      case AppLinkKind.passwordReset:
        if (!_externalOpened) {
          _externalOpened = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await launchUrl(widget.target.uri,
                mode: LaunchMode.externalApplication);
          });
        }
        return _LinkErrorScreen(
          title: 'Sicheren Link geöffnet',
          message:
              'Die Bestätigung wird in einer sicheren Browserseite abgeschlossen. Danach kannst du zu ShareItToo zurückkehren.',
          actionLabel: 'Link erneut öffnen',
          onAction: () async {
            await launchUrl(
              widget.target.uri,
              mode: LaunchMode.externalApplication,
            );
          },
        );
      case AppLinkKind.paymentReturn:
        return FutureBuilder<AuthSession?>(
          future: AuthService.readSession(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LinkLoadingScreen();
            }
            if (snapshot.data == null) {
              return _LinkErrorScreen(
                title: 'Bitte zuerst anmelden',
                message:
                    'Nach der Anmeldung wird der sichere Zahlungsstatus neu geladen.',
                actionLabel: 'Anmelden',
                onAction: _loginAndRetry,
              );
            }
            return PaymentCheckoutScreen(bookingId: widget.target.id!);
          },
        );
    }
  }

  Map<String, dynamic> _bookingMap(_ResolvedBooking resolved) {
    final request = resolved.request;
    final item = resolved.item;
    final owner = resolved.owner;
    String category(String status) => switch (status) {
          'pending' => 'pending',
          'accepted' || 'confirmed' => 'upcoming',
          'running' || 'active' || 'returned' => 'ongoing',
          _ => 'completed',
        };
    return {
      'requestId': request.id,
      'itemId': request.itemId,
      'rawStatus': request.status,
      'status': request.status,
      'category': category(request.status),
      'title': item?.title ?? 'Buchung',
      'image': item?.photos.isNotEmpty == true ? item!.photos.first : null,
      'images': item?.photos ?? const <String>[],
      'location': item?.locationText,
      'listerId': request.ownerId,
      'listerName': owner?.displayName ?? 'Vermieter',
      'listerAvatar': owner?.photoURL,
      'quotedTotalRenter': request.quotedTotalRenter,
      'startIso': request.start.toIso8601String(),
      'endIso': request.end.toIso8601String(),
      'requestCreatedAtIso': request.createdAt.toIso8601String(),
    };
  }
}

class _ResolvedBooking {
  final RentalRequest request;
  final User? viewer;
  final Item? item;
  final User? owner;

  const _ResolvedBooking({
    required this.request,
    required this.viewer,
    required this.item,
    required this.owner,
  });
}

class _LinkLoadingScreen extends StatelessWidget {
  const _LinkLoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class _LinkErrorScreen extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _LinkErrorScreen({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ShareItToo')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_outlined, size: 46),
                  const SizedBox(height: 16),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 22),
                  FilledButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ),
            ),
          ),
        ),
      );
}
