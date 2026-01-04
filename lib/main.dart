import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:lendify/theme.dart';
import 'package:lendify/navigation/main_navigation.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/services/data_service.dart';

Future<void> main() async {
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
  } catch (e) {
    debugPrint('[Main] ensureOnlyUserItemsOnce failed: ' + e.toString());
  }

  // Wipe all locally stored rentals/bookings so you can retest from a clean state.
  // This clears pending/accepted requests, their timelines/reminders, and saved
  // availability selections. Safe to call when storage is already empty.
  try {
    debugPrint('[Main] Clear rentals/bookings start');
    await DataService.clearAllRentalsAndBookings();
    debugPrint('[Main] Clear rentals/bookings done');
  } catch (e) {
    debugPrint('[Main] Clear rentals/bookings failed: ' + e.toString());
  }

  debugPrint('[Main] runApp(MyApp)');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LocalizationController>(
      create: (_) => LocalizationController()..loadFromPrefs(),
      child: Consumer<LocalizationController>(
        builder: (context, l10n, _) {
          return MaterialApp(
            title: 'ShareItToo',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(context),
            darkTheme: buildDarkTheme(context),
            themeMode: ThemeMode.system,
            builder: (context, child) => AppGradientBackground(child: child ?? const SizedBox.shrink()),
            home: const MainNavigation(),
          );
        },
      ),
    );
  }
}
