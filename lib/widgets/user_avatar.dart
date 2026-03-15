import 'package:flutter/material.dart';
import 'package:lendify/widgets/app_image.dart';

/// Circular avatar that supports http(s), data:image base64, and local file paths
/// (via [AppImage]).
class SitUserAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final IconData placeholderIcon;

  const SitUserAvatar({
    super.key,
    required this.url,
    required this.radius,
    this.borderColor,
    this.borderWidth = 1.6,
    this.placeholderIcon = Icons.person_outline,
  });

  @override
  Widget build(BuildContext context) {
    final has = url != null && url!.trim().isNotEmpty;
    final border = borderColor ?? Colors.white.withValues(alpha: 0.14);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: border, width: borderWidth)),
      child: ClipOval(
        child: has
            ? AppImage(url: url, fit: BoxFit.cover)
            : Center(child: Icon(placeholderIcon, color: Colors.white.withValues(alpha: 0.85), size: radius * 0.85)),
      ),
    );
  }
}
