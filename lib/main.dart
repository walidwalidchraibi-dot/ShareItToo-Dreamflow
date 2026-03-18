import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:async';
import 'package:lendify/theme.dart';
import 'package:lendify/navigation/main_navigation.dart';
import 'package:lendify/navigation/main_nav_controller.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/developer_preview_service.dart';
import 'package:lendify/screens/onboarding_flow_screen.dart';

Future<void> main() async {
  // Initialize bindings once in the same zone as runApp to avoid zone mismatch warnings.
  WidgetsFlutterBinding.ensureInitialized();

  // Surface synchronous Flutter framework errors to the console
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ' + details.exceptionAsString());
    if (details.stack != null) debugPrint(details.stack.toString());
  };

  // Catch uncaught async errors
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught async error: ' + error.toString());
    debugPrint(stack.toString());
    return true; // handled
  };

  // One-time purge: Remove demo items and keep only listings created by current user
  // so the app logic runs exclusively on newly created listings.
  try {
    debugPrint('[Main] ensureOnlyUserItemsOnce start');
    await DataService.ensureOnlyUserItemsOnce();
    debugPrint('[Main] ensureOnlyUserItemsOnce done');
  } catch (e, st) {
    debugPrint('[Main] ensureOnlyUserItemsOnce failed: ' + e.toString());
    debugPrint(st.toString());
  }

  // Wipe all locally stored rentals/bookings so you can retest from a clean state.
  // This clears pending/accepted requests, their timelines/reminders, and saved
  // availability selections. Safe to call when storage is already empty.
  try {
    debugPrint('[Main] Clear rentals/bookings start');
    await DataService.clearAllRentalsAndBookings();
    debugPrint('[Main] Clear rentals/bookings done');
  } catch (e, st) {
    debugPrint('[Main] Clear rentals/bookings failed: ' + e.toString());
    debugPrint(st.toString());
  }

  debugPrint('[Main] runApp(MyApp)');
  DeveloperUserState? initialPreview;
  try {
    initialPreview = await DeveloperPreviewController.readStateOnce();
  } catch (e) {
    debugPrint('[Main] readStateOnce failed: $e');
  }
  runApp(MyApp(initialPreviewState: initialPreview));
}

class MyApp extends StatelessWidget {
  final DeveloperUserState? initialPreviewState;
  const MyApp({super.key, this.initialPreviewState});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocalizationController>(create: (_) => LocalizationController()..loadFromPrefs()),
        ChangeNotifierProvider<MainNavController>(create: (_) => MainNavController()),
        ChangeNotifierProvider<DeveloperPreviewController>(
          create: (_) => DeveloperPreviewController(initialState: initialPreviewState)..loadFromPrefs(),
        ),
      ],
      child: Consumer<LocalizationController>(
        builder: (context, l10n, _) {
          return MaterialApp(
            title: 'ShareItToo',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(context),
            darkTheme: buildDarkTheme(context),
            themeMode: ThemeMode.system,
            builder: (context, child) => AppGradientBackground(child: child ?? const SizedBox.shrink()),
            home: const AppRoot(),
          );
        },
      ),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final preview = context.watch<DeveloperPreviewController>();
    if (!preview.hydrated) {
      return const Scaffold(backgroundColor: Colors.transparent, body: SizedBox.shrink());
    }
    switch (preview.state) {
      case DeveloperUserState.firstLaunch:
        return FirstLaunchFlowScreen(onFinished: () => preview.setState(DeveloperUserState.loggedOut));
      case DeveloperUserState.loggedOut:
        return const LoggedOutLandingScreen();
      case DeveloperUserState.loggedIn:
      case DeveloperUserState.verifiedUser:
        return const MainNavigation();
    }
  }
}
