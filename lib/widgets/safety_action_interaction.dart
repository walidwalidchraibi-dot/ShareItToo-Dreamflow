import 'package:flutter/material.dart';
import 'package:lendify/services/safety_action_service.dart';
import 'package:lendify/widgets/tracked_dialog_route.dart';

/// Screen-local principal/epoch and exact-route guard for safety actions.
class SafetyActionInteractionController {
  SafetyActionContext? _context;
  int _actionEpoch = 0;
  Object? _activeRouteIdentity;
  void Function()? _dismissActiveRoute;

  SafetyActionContext? get context => _context;

  void replaceContext(SafetyActionContext? context) {
    invalidate();
    _context = context;
  }

  void invalidate() {
    _actionEpoch += 1;
    _context = null;
    final dismiss = _dismissActiveRoute;
    _activeRouteIdentity = null;
    _dismissActiveRoute = null;
    dismiss?.call();
  }

  SafetyActionOwner? capture() {
    final context = _context;
    if (context == null) return null;
    return SafetyActionOwner(
      context: context,
      actionEpoch: ++_actionEpoch,
    );
  }

  bool isSynchronouslyCurrent(SafetyActionOwner owner) =>
      owner.isSynchronouslyCurrent(
        context: _context,
        actionEpoch: _actionEpoch,
      );

  Future<bool> isCurrent(
    SafetyActionService service,
    SafetyActionOwner owner,
  ) async {
    if (!isSynchronouslyCurrent(owner)) return false;
    final current = await service.isContextCurrent(owner.context);
    return current && isSynchronouslyCurrent(owner);
  }

  void _bindRoute<T>(
    SafetyActionOwner owner,
    Object identity,
    TrackedDialogRouteHandle<T> handle,
  ) {
    if (!isSynchronouslyCurrent(owner)) return;
    _activeRouteIdentity = identity;
    _dismissActiveRoute = handle.dismiss;
  }

  void _releaseRoute(Object identity) {
    if (!identical(identity, _activeRouteIdentity)) return;
    _activeRouteIdentity = null;
    _dismissActiveRoute = null;
  }

  Future<T?> showOwnedDialog<T>({
    required BuildContext context,
    required SafetyActionOwner owner,
    required Widget Function(
      BuildContext context,
      void Function(T? result) dismiss,
    ) builder,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
  }) async {
    if (!isSynchronouslyCurrent(owner)) return null;
    final identity = Object();
    final handle = TrackedDialogRouteHandle<T>();
    _bindRoute(owner, identity, handle);
    try {
      return await showTrackedDialog<T>(
        context: context,
        handle: handle,
        builder: (context) => builder(context, handle.dismiss),
        barrierDismissible: barrierDismissible,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        useRootNavigator: useRootNavigator,
      );
    } finally {
      _releaseRoute(identity);
    }
  }

  Future<T?> showOwnedGeneralDialog<T>({
    required BuildContext context,
    required SafetyActionOwner owner,
    required Widget Function(
      BuildContext context,
      void Function(T? result) dismiss,
    ) builder,
    required RouteTransitionsBuilder transitionBuilder,
    bool barrierDismissible = true,
    String? barrierLabel,
    Color barrierColor = const Color(0x80000000),
    Duration transitionDuration = const Duration(milliseconds: 200),
    bool useRootNavigator = true,
  }) async {
    if (!isSynchronouslyCurrent(owner)) return null;
    final identity = Object();
    final handle = TrackedDialogRouteHandle<T>();
    _bindRoute(owner, identity, handle);
    try {
      return await showTrackedGeneralDialog<T>(
        context: context,
        handle: handle,
        pageBuilder: (context, _, __) => builder(context, handle.dismiss),
        barrierDismissible: barrierDismissible,
        barrierLabel: barrierLabel ??
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: barrierColor,
        transitionDuration: transitionDuration,
        transitionBuilder: transitionBuilder,
        useRootNavigator: useRootNavigator,
      );
    } finally {
      _releaseRoute(identity);
    }
  }

  Future<T?> showOwnedSheet<T>({
    required BuildContext context,
    required SafetyActionOwner owner,
    required Widget Function(
      BuildContext context,
      void Function(T? result) dismiss,
    ) builder,
    bool isScrollControlled = false,
    bool useRootNavigator = false,
    Color? backgroundColor,
    Color? barrierColor,
  }) async {
    if (!isSynchronouslyCurrent(owner)) return null;
    final identity = Object();
    final handle = TrackedDialogRouteHandle<T>();
    _bindRoute(owner, identity, handle);
    try {
      return await showTrackedModalBottomSheet<T>(
        context: context,
        handle: handle,
        builder: (context) => builder(context, handle.dismiss),
        isScrollControlled: isScrollControlled,
        useRootNavigator: useRootNavigator,
        backgroundColor: backgroundColor,
        barrierColor: barrierColor,
      );
    } finally {
      _releaseRoute(identity);
    }
  }

  void dispose() => invalidate();
}
