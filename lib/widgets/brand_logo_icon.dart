import 'package:flutter/material.dart';

/// BrandLogoIcon renders original app icons (round launcher-style icons).
/// Renders a circular clipped image that looks like the actual app icon on a phone.
class BrandLogoIcon extends StatelessWidget {
  const BrandLogoIcon({super.key, required this.assetPath, required this.fallback, this.fallbackColor, this.size = 22});

  /// Full asset path to the app icon image, e.g. 'assets/images/x_icon.jpg'
  final String assetPath;
  /// Fallback Material icon if asset is not present
  final IconData fallback;
  final Color? fallbackColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(fallback, size: size, color: fallbackColor),
      ),
    );
  }
}
