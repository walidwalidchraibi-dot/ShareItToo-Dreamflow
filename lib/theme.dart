import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BrandColors {
  static const logoGradientStart = Color(0xFF5868A9);
  static const logoGradientEnd = Color(0xFF6E2B74);
  static const logoAccent = Color(0xFFFFB277);

  // App background gradient (legacy fallback)
  static const appBlueTop = Color(0xFF0B1421);
  static const appBlueBottom = Color(0xFF060A12);

  static const goldLine = Color(0xFFFFD56E);
  static const goldShadow = Color(0xFF8C6A1F);

  static const inactiveNav = Color(0xFF94A3B8);

  static const primary = Color(0xFF0EA5E9);
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFF43F5E);

  // Social brand colors
  static const xBlue = Color(0xFF1DA1F2); // X/Twitter legacy blue for recognizability
  static const instagram = Color(0xFFE1306C);
  static const facebook = Color(0xFF1877F2);
  static const tiktok = Color(0xFFEE1D52);
}

class AppTypography {
  static TextTheme textTheme(BuildContext context) {
    final base = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    const h = 1.25;
    return base.copyWith(
      // Force white as default text color to ensure readability on our dark blurred background
      titleLarge: base.titleLarge?.copyWith(fontSize: 18, height: h, fontWeight: FontWeight.w700, color: Colors.white),
      titleMedium: base.titleMedium?.copyWith(fontSize: 16, height: h, fontWeight: FontWeight.w600, color: Colors.white),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 13, height: h, fontWeight: FontWeight.w500, color: Colors.white),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12, height: h, fontWeight: FontWeight.w500, color: Colors.white),
      labelSmall: base.labelSmall?.copyWith(fontSize: 11, height: h, fontWeight: FontWeight.w600, color: Colors.white),
    );
  }
}

Gradient get appBackgroundGradient => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [BrandColors.appBlueTop, BrandColors.appBlueBottom]);

ThemeData buildLightTheme(BuildContext context) {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  final text = AppTypography.textTheme(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: BrandColors.primary,
      secondary: const Color(0xFF111827),
      tertiary: BrandColors.success,
      error: BrandColors.danger,
      // Use dark surface with white foreground to match our global dark backdrop
      surface: const Color(0xFF0F172A),
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0, centerTitle: false),
    listTileTheme: const ListTileThemeData(iconColor: Colors.white, textColor: Colors.white),
    iconTheme: const IconThemeData(color: Colors.white),
    textTheme: text,
  );
}

ThemeData buildDarkTheme(BuildContext context) {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
  final text = AppTypography.textTheme(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: BrandColors.primary,
      secondary: const Color(0xFFE5E7EB),
      tertiary: BrandColors.success,
      error: BrandColors.danger,
      surface: const Color(0xFF0F172A),
      onSurface: const Color(0xFFE5E7EB),
    ),
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0, centerTitle: false),
    listTileTheme: const ListTileThemeData(iconColor: Colors.white, textColor: Colors.white),
    iconTheme: const IconThemeData(color: Colors.white),
    textTheme: text,
  );
}

class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  const GradientIcon(this.icon, {super.key, this.size = 22});
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => appBackgroundGradient.createShader(bounds),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

// Global background wrapper: use the Fulllogo.jpg colors with a strong blur
class AppGradientBackground extends StatelessWidget {
  final Widget child;
  const AppGradientBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
          child: Image.asset('assets/images/fulllogo.jpg', fit: BoxFit.cover),
        ),
      ),
      Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.30))),
      child,
    ]);
  }
}

class HoverScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;
  const HoverScale({super.key, required this.child, this.scale = 1.07, this.duration = const Duration(milliseconds: 180)});
  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(scale: _hovering ? widget.scale : 1.0, duration: widget.duration, curve: Curves.easeOut, child: widget.child),
    );
  }
}
